require 'net/http'
require 'uri'
require 'json'
require 'ipaddr'

module Wrenchmode
  class Rack
    CLIENT_NAME = "wrenchmode-rack"
    VERSION = '0.1.0'

    # The ENV var set on Heroku where we can retrieve the JWT
    HEROKU_JWT_VAR = "WRENCHMODE_PROJECT_JWT"

    SWITCH_URL_KEY = "switch_url"
    TEST_MODE_KEY = "test_mode"
    IS_SWITCHED_KEY = "is_switched"
    IP_WHITELIST_KEY = "ip_whitelist"
    REVERSE_PROXY_KEY = "reverse_proxy"

    def initialize(app, opts = {})
      @app = app       

      # Symbolize keys
      opts = symbolize_keys(opts)
      opts = {
        force_open: false,
        ignore_test_mode: true,
        disable_local_wrench: false, # LocalWrench is our "brand name", want to avoid scaring people will talk of proxies
        status_protocol: "https",
        status_host: "wrenchmode.com",
        status_path: "/api/projects/status",
        check_delay_secs: 5,
        logging: false,
        read_timeout_secs: 3,
        trust_remote_ip: true
      }.merge(opts)

      # The JWT can be set either explicity, or implicitly if Wrenchmode is added as a Heroku add-on
      # The WRENCHMODE_PROJECT_JWT variable is set as part of the Heroku add-on provisioning process
      @jwt = opts[:jwt] || ENV[HEROKU_JWT_VAR]

      @ignore_test_mode = opts[:ignore_test_mode]
      @disable_reverse_proxy = opts[:disable_local_wrench]
      @force_open = opts[:force_open]
      @status_url = "#{opts[:status_protocol]}://#{opts[:status_host]}#{opts[:status_path]}"
      @check_delay_secs = opts[:check_delay_secs]
      @logging = opts[:logging]
      @read_timeout_secs = opts[:read_timeout_secs]
      @ip_whitelist = []
      @logger = nil
      @trust_remote_ip = opts[:trust_remote_ip]

      @enable_reverse_proxy = false

      @made_contact = false

      # Use a queue with 0 or 1 items to allow the threads to communicate. When a response from the main Wrenchmode server is received,
      # parse the JSON and put the hash in the queue. Then, the main request thread will update the underlying middleware state
      # the next time a request is received.
      @queue = Queue.new
    end

    def call(env)      
      @logger = env['rack.logger'] if @logging && !@logger

      unless @jwt
        log("[Wrenchmode] No JWT specified so bypassing Wrenchmode. Please configure Wrenchmode with a JWT.", Logger::ERROR)
        return @app.call(env)
      end

      # On startup, we need to give it a chance to make contact
      @check_thread ||= start_check_thread()
      sleep(0.01) while !@made_contact

      # If we've gotten a new response from the server, use it
      # to update local status
      json = begin
        @queue.pop(true)
      rescue ThreadError
        nil
      end
      update_status(json) if json

      should_display_wrenchmode = false
      if @switched

        should_display_wrenchmode = !@force_open
        should_display_wrenchmode &&= !ip_whitelisted?(env)
      end

      if should_display_wrenchmode
        if @enable_reverse_proxy
          reverse_proxy
        else
          redirect
        end
      else
        @app.call(env)
      end
    end      

    def update_status(json)
      @switch_url = json[SWITCH_URL_KEY]
      test_mode = json[TEST_MODE_KEY] || false
      @switched = json[IS_SWITCHED_KEY] && !(@ignore_test_mode && test_mode)
      @ip_whitelist = json[IP_WHITELIST_KEY] || []

      @enable_reverse_proxy = false
      if json[REVERSE_PROXY_KEY] && !@disable_reverse_proxy
        @enable_reverse_proxy = json[REVERSE_PROXY_KEY]["enabled"]
        @reverse_proxy_config = symbolize_keys(json[REVERSE_PROXY_KEY])
      end
    end

    private

    def fetch_status
      inner_fetch
    rescue Net::HTTPError => e
      log("Wrenchmode Check HTTP Error: #{e.message}")
      @switched = false
      nil
    rescue JSON::JSONError => e
      log("Wrenchmode Check JSON Error: #{e.message}")
      @switched = false
      nil
    rescue StandardError => e
      log("Wrenchmode Check Unknown Error: #{e.message}")
      @switched = false
      nil
    ensure
      @made_contact = true
    end

    # Split this one out for easier mocking/stubbing in the specs
    def inner_fetch
      payload = JSON.generate(build_update_package)
      body = nil

      uri = URI.parse(@status_url)
      use_ssl = uri.scheme == "https"
      Net::HTTP.start(uri.host, uri.port, open_timeout: @read_timeout_secs, read_timeout: @read_timeout_secs, use_ssl: use_ssl) do |http|
        response = http.post(uri, payload, post_headers)
        body = response.read_body
      end

      JSON.parse(body)
    end

    def post_headers
      {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "Authorization" => @jwt,
        "User-Agent" => "#{CLIENT_NAME}-#{VERSION}"
      }
    end

    def redirect
      [
        302,
        {'Location' => @switch_url, 'Content-Type' => 'text/html', 'Content-Length' => '0'},
        []
      ]
    end

    def reverse_proxy
      [
        @reverse_proxy_config[:http_status],
        @reverse_proxy_config[:response_headers],
        [@reverse_proxy_config[:response_body]]
      ]
    end

    def start_check_thread
      Thread.new do
        while true do
          if json = fetch_status
            @queue.clear()
            @queue.push(json)
          end

          sleep(@check_delay_secs)
        end
      end
    end

    def ip_whitelisted?(env)
      client_ips(env).any? do |client_ip|
        @ip_whitelist.any? do |ip_address|
          IPAddr.new(ip_address).include?(client_ip)
        end
      end
    end

    def client_ips(env)
      request = ::Rack::Request.new(env)
      ips = request.ip ? [request.ip] : []
      if @trust_remote_ip
        ips << env.remote_ip.to_s if env.respond_to?(:remote_ip)
        ips << env["action_dispatch.remote_ip"].to_s if Module.const_defined?("ActionDispatch::RemoteIp") && env["action_dispatch.remote_ip"]
      end
      ips
    end

    def build_update_package
      {
        hostname: guess_hostname,
        ip_address: guess_ip_address,
        pid: guess_pid,
        client_name: CLIENT_NAME,
        client_version: VERSION
      }
    end

    def guess_pid
      Process.pid
    rescue StandardError => e
      log("Wrenchmode error trying to guess PID: #{e.inspect}")
      nil
    end

    def guess_hostname
      Socket.gethostname
    rescue StandardError => e
      log("Wrenchmode error trying to guess the hostname: #{e.inspect}")
      nil
    end

    def guess_ip_address
      address = Socket.ip_address_list.find { |addr| addr.ipv4? && !addr.ipv4_loopback? && !addr.ipv4_private? }
      address ? address.ip_address : nil
    rescue StandardError => e
      log("Wrenchmode error trying to guess the IP address: #{e.inspect}")
      nil
    end

    def log(message, level = nil)
      @logger.add(level || Logger::INFO, message) if @logging && @logger
    end

    def symbolize_keys(hash)
      hash.each_with_object({}) { |(k,v), h| h[k.to_sym] = v }
    end
  end
end