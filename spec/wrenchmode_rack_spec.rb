require 'spec_helper'
require 'socket'

class RemoteIp
  def initialize(app, remote_ip)
    @app = app
    @remote_ip = remote_ip
  end

  def call(env)
    env.stub(:remote_ip) { @remote_ip }
    @app.call(env)
  end
end

describe Wrenchmode::Rack do
  it 'has a version number' do
    expect(Wrenchmode::Rack::VERSION).not_to be nil
  end

  let(:response_body) { "Hello, world." }
  let(:app) { proc{ [200,{},[response_body]] } }
  let(:wrenchmode_middleware) { Wrenchmode::Rack.new(app, jwt: "my-jwt") }
  let(:stack) { wrenchmode_middleware }
  let(:linted_stack) { Rack::Lint.new(stack) }
  let(:request) { Rack::MockRequest.new(linted_stack) }
  let(:response) { request.get("/") }

  let(:default_status_response) do
    {
      "is_switched" => true,
      "switch_url" => "http://myapp.wrenchmode.com/maintenance",
      "test_mode" => false,
      "ip_whitelist" => []
    }
  end

  describe "basic setup" do
    it "allows requests all the way through" do
      expect(response).to be_standard_response
    end
  end

  describe "an error contacting the wrenchmode server" do
    before do
      allow(stack).to receive(:inner_fetch).and_raise(StandardError.new("Some error occurred"))
    end

    it "passes the request all the way through" do
      expect(response).to be_standard_response
    end
  end

  describe "in wrenchmode" do
    let(:status_response) { default_status_response }

    before do
      allow(wrenchmode_middleware).to receive(:inner_fetch).and_return(status_response)
    end

    it "redirects over to wrenchmode" do
      expect(response).to be_wrenchmode_redirect
    end

    describe "in test mode" do
      describe "with test mode ignored" do
        let(:wrenchmode_middleware) { Wrenchmode::Rack.new(app, jwt: "my-jwt") } # Ignore test mode is true by default
        let(:status_response) { default_status_response.merge("test_mode" => true) }

        it "passes the request all the way through" do
          expect(response).to be_standard_response
        end
      end

      describe "with test mode not ignored" do
        let(:wrenchmode_middleware) { Wrenchmode::Rack.new(app, jwt: "my-jwt", ignore_test_mode: false) }
        let(:status_response) { default_status_response.merge("test_mode" => true) }

        it "redirects to wrenchmode" do
          expect(response).to be_wrenchmode_redirect
        end
      end
    end

    describe "with an IP whitelist" do
      let(:ip_whitelist) do
        [
          "192.168.0.1/24",
          "10.20.0.0/32"
        ]
      end
      let(:allowed_ips) do
        [
          "192.168.0.1",
          "192.168.0.20",
          "192.168.0.255",
          "10.20.0.0"
        ]
      end
      let(:rejected_ips) do
        [
          "127.0.0.1",
          "192.168.1.0",
          "10.20.0.1"
        ]
      end
      let(:status_response) { default_status_response.merge("ip_whitelist" => ip_whitelist) }
      let(:wrenchmode_middleware) { Wrenchmode::Rack.new(app, jwt: "my-jwt") }

      describe "with a request from inside the whitelist" do
        it "passes through to the app" do
          allowed_ips.each do |ip|
            response = request.get("/", "REMOTE_ADDR" => ip)
            expect(response).to be_standard_response
          end
        end
      end

      describe "with a request from outside the whitelist" do
        it "redirects to wrenchmode" do
          rejected_ips.each do |ip|
            response = request.get("/", "REMOTE_ADDR" => ip)
            expect(response).to be_wrenchmode_redirect
          end
        end
      end

      describe "with a proxied IP address from inside the whitelist" do
        let(:stack) do
          RemoteIp.new(wrenchmode_middleware, allowed_ips[0])
        end

        it "passes through the proxy IP" do
          allowed_ips.each do |ip|
            response = request.get("/", "REMOTE_ADDR" => rejected_ips[0])
            expect(response).to be_standard_response
          end
        end
      end

      describe "with a proxied IP address from outside the whitelist" do
        let(:stack) do
          RemoteIp.new(wrenchmode_middleware, rejected_ips[0])
        end

        it "redirects to wrenchmode" do
          rejected_ips.each do |ip|
            response = request.get("/", "REMOTE_ADDR" => ip)
            expect(response).to be_wrenchmode_redirect
          end
        end
      end

      describe "with a proxied IP address from inside the whitelist, but remote_ip is untrusted" do
        let(:wrenchmode_middleware) { Wrenchmode::Rack.new(app, jwt: "my-jwt", trust_remote_ip: false) }
        let(:stack) do
          RemoteIp.new(wrenchmode_middleware, allowed_ips[0])
        end

        it "redirects to wrenchmode" do
          allowed_ips.each do |ip|
            response = request.get("/", "REMOTE_ADDR" => rejected_ips[0])
            expect(response).to be_wrenchmode_redirect
          end
        end
      end
    end

    describe "in reverse proxy mode" do
      let(:status_response) do
        default_status_response.merge(
          "reverse_proxy" => {
            "enabled" => true,
            "http_status" => 500, # Normally, it would be a 503, but we're testing the ability to override
            "response_body" => "<h1>This is the maintenance page!</h1>",
            "response_headers" => {
              "X-Custom-Header" => "foo",
              "X-Other-Header" => "bar"
            }
          }
        )
      end

      before do
        allow(wrenchmode_middleware).to receive(:inner_fetch).and_return(status_response)
      end

      it "responds with the status code" do
        expect(response.status).to eq(500)
      end

      it "responds with the proxy body" do
        expect(response.body).to match(/This is the maintenance page/)
      end

      it "responds with the custom headers" do
        expect(response.headers["X-Custom-Header"]).to eq("foo")
        expect(response.headers["X-Other-Header"]).to eq("bar")
      end

      describe "with reverse proxy disabled" do
        let(:wrenchmode_middleware) { Wrenchmode::Rack.new(app, disable_local_wrench: true, jwt: "my-jwt") }

        it "redirects instead of reverse proxy response" do
          expect(response).to be_wrenchmode_redirect
        end
      end
    end
  end

  describe "on Heroku" do
    # Do not set a specific JWT. It will be introspected from the ENV vars
    let(:wrenchmode_middleware) { Wrenchmode::Rack.new(app) }
    let(:status_response) { default_status_response }

    before do
      ENV[Wrenchmode::Rack::HEROKU_JWT_VAR] = "my-jwt"
      allow(stack).to receive(:inner_fetch).and_return(status_response)
    end

    after do
      ENV.delete(Wrenchmode::Rack::HEROKU_JWT_VAR)
    end

    it "redirects over to wrenchmode" do
      expect(response).to be_wrenchmode_redirect
    end
  end

  describe "status update to the wrenchmode server" do
    it "builds the correct update package" do
      package = wrenchmode_middleware.send(:build_update_package)
      expect(package[:hostname]).to eq(Socket.gethostname)
      expect(package[:pid]).to eq(Process.pid)
      expect(package[:client_name]).to eq("wrenchmode-rack")
      expect(package[:client_version]).to eq(Wrenchmode::Rack::VERSION)

      # Not really sure how to test this, since it will never be right on the test machine...
      expect(package[:ip_address]).to be_nil
    end
  end
end
