require 'spec_helper'

describe Wrenchmode::Rack do
  it 'has a version number' do
    expect(Wrenchmode::Rack::VERSION).not_to be nil
  end

  let(:response_body) { "Hello, world." }
  let(:app) { proc{[200,{},[response_body]]} }
  let(:stack) { Wrenchmode::Rack.new(app, jwt: "my-jwt") }
  let(:request) { Rack::MockRequest.new(stack) }
  let(:response) { request.get("/") }

  let(:default_status_response) { {"is_switched" => true, "switch_url" => "http://myapp.wrenchmode.com/maintenance"} }

  describe "basic setup" do
    it "allows requests all the way through" do
      expect(response).to be_standard_response
    end
  end

  describe "an error contacting the wrenchmode server" do
    before do
      allow(stack).to receive(:fetch_status).and_raise(StandardError.new("Some error occurred"))
    end

    it "passes the request all the way through" do
      expect(response).to be_standard_response
    end
  end

  describe "in wrenchmode" do
    let(:status_response) { default_status_response }

    before do
      allow(stack).to receive(:fetch_status).and_return(status_response)
    end

    it "redirects over to wrenchmode" do
      expect(response).to be_wrenchmode_redirect
    end

    describe "in test mode" do
      describe "with test mode ignored" do
        let(:stack) { Wrenchmode::Rack.new(app, jwt: "my-jwt") } # Ignore test mode is true by default
        let(:status_response) { default_status_response.merge("test_mode" => true) }

        it "passes the request all the way through" do
          expect(response).to be_standard_response
        end
      end

      describe "with test mode not ignored" do
        let(:stack) { Wrenchmode::Rack.new(app, jwt: "my-jwt", ignore_test_mode: false) }
        let(:status_response) { default_status_response.merge("test_mode" => true) }

        it "redirects to wrenchmode" do
          expect(response).to be_wrenchmode_redirect
        end
      end
    end
  end
end
