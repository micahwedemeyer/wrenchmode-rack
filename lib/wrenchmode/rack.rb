require 'open-uri'
require 'json'

module Wrenchmode
  class Rack
    def initialize(app, opts = {})
      @app = app       

      # Symbolize keys
      opts = opts.each_with_object({}) { |(k,v), h| h[k.to_sym] = v }
      opts = {
        domain_id: nil,
        jwt: "unauthorized",
        switched: false,
        status_protocol: "http",
        status_host: "localhost:4000",
        status_path: "/api/domains/",
        check_delay_secs: 5,
        logging: false
      }.merge(opts)

      @domain_id = opts[:domain_id]
      @jwt = opts[:jwt]
      @switched = opts[:switched]
      @status_url = "#{opts[:status_protocol]}://#{opts[:status_host]}#{opts[:status_path]}#{@domain_id}"
      @check_delay_secs = opts[:check_delay_secs]
      @logging = opts[:logging]
      @logger = nil

      @check_thread = start_check_thread()
    end

    def call(env)      
      @logger = env['rack.logger'] if @logging && !@logger

      if @switched
        redirect
      else
        @app.call(env)   
      end
    end      

    def update_status
      resp = open(@status_url, open_uri_headers)
      body = resp.read
      json = JSON.parse(body)

      @switch_url = json["switch_url"]

      if json["is_switched"]
        @switched = true
      else
        @switched = false
      end

    rescue OpenURI::HTTPError => e
      log("Maintenance Check HTTP Error: #{e.message}")
      @switched = false
    rescue JSON::JSONError => e
      log("Maintenance Check JSON Error: #{e.message}")
      @switched = false
    rescue StandardError => e
      log("Maintenance Check Unknown Error: #{e.message}")
      @switched = false
    end

    private

    def open_uri_headers
      {
        "Accept" => "application/json",
        "Authorization" => @jwt
      }
    end

    def redirect
      [302, {'Location' => @switch_url, 'Content-Type' => 'text/html', 'Content-Length' => '0'}, []]
    end

    def start_check_thread
      Thread.new do
        while true do
          update_status
          sleep(@check_delay_secs)
        end
      end
    end

    def log(message)
      @logger.info(message) if @logging && @logger
    end
  end
end