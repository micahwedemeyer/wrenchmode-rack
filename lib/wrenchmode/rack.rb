require 'open-uri'
require 'json'

module Wrenchmode
  class Rack
    VERSION = '0.0.6'

    def initialize(app, opts = {})
      @app = app       

      # Symbolize keys
      opts = opts.each_with_object({}) { |(k,v), h| h[k.to_sym] = v }
      opts = {
        force_open: false,
        ignore_test_mode: true,
        status_protocol: "https",
        status_host: "api.wrenchmode.com",
        status_path: "/api/projects/status",
        check_delay_secs: 5,
        logging: false,
        read_timeout_secs: 3
      }.merge(opts)

      @jwt = opts[:jwt]
      @ignore_test_mode = opts[:ignore_test_mode] # Not implemented yet...
      @force_open = opts[:force_open]
      @status_url = "#{opts[:status_protocol]}://#{opts[:status_host]}#{opts[:status_path]}"
      @check_delay_secs = opts[:check_delay_secs]
      @logging = opts[:logging]
      @read_timeout_secs = opts[:read_timeout_secs]
      @logger = nil

      @made_contact = false
      @check_thread = start_check_thread()
    end

    def call(env)      
      @logger = env['rack.logger'] if @logging && !@logger

      unless @jwt
        log(Logger::ERROR, "[Wrenchmode] No JWT specified so bypassing Wrenchmode. Please configure Wrenchmode with a JWT.")
        return @app.call(env)
      end

      # On startup, we need to give it a chance to make contact
      sleep(0.1) while !@made_contact

      if !@force_open && @switched
        redirect
      else
        @app.call(env)   
      end
    end      

    def update_status
      resp = open(@status_url, open_uri_headers.merge(read_timeout: @read_timeout_secs))
      body = resp.read
      json = JSON.parse(body)

      @switch_url = json["switch_url"]

      if json["is_switched"]
        @switched = true
      else
        @switched = false
      end

    rescue OpenURI::HTTPError => e
      log("Wrenchmode Check HTTP Error: #{e.message}")
      @switched = false
    rescue JSON::JSONError => e
      log("Wrenchmode Check JSON Error: #{e.message}")
      @switched = false
    rescue StandardError => e
      log("Wrenchmode Check Unknown Error: #{e.message}")
      @switched = false
    ensure
      @made_contact = true
    end

    private

    def open_uri_headers
      {
        "Accept" => "application/json",
        "Authorization" => @jwt,
        "User-Agent" => "wrenchmode-rack-#{VERSION}"
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

    def log(message, level = nil)
      @logger.add(level || Logger::INFO, message) if @logging && @logger
    end
  end
end