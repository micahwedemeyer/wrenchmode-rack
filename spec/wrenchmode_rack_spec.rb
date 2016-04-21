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

  describe "basic setup" do
    it "allows requests all the way through" do
      expect(response.status).to eq(200)
      expect(response.body).to eq(response_body)
    end
  end

  describe "an error contacting the wrenchmode server" do
    before do
      allow(stack).to receive(:fetch_status).and_raise(StandardError.new("Some error occurred"))
    end

    it "passes the request all the way through" do
      expect(response.status).to eq(200)
      expect(response.body).to eq(response_body)
    end
  end

  describe "in wrenchmode" do
    let(:status_response) { {"is_switched" => true, "switch_url" => "http://myapp.wrenchmode.com/maintenance"} }

    before do
      allow(stack).to receive(:fetch_status).and_return(status_response)
    end

    it "redirects over to wrenchmode" do
      expect(response.status).to eq(302)
      expect(response.headers["Location"]).to eq("http://myapp.wrenchmode.com/maintenance")
    end
  end

end
