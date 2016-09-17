# Wrenchmode Rack

[![Gem Version](https://badge.fury.io/rb/wrenchmode-rack.svg)](https://badge.fury.io/rb/wrenchmode-rack)

This is a [Rack Middleware](http://rack.github.io/) for managing maintenance mode on your Ruby/Rack/Rails web application using [Wrenchmode](http://wrenchmode.com).

## Installation: Heroku Add-on (Coming soon...)

(Note: We are still waiting on final approval from Heroku for our add-on)

Add the [Wrenchmode Heroku add-on](https://elements.heroku.com/addons) to your application's list of add-ons.

And then add this line to your application's Gemfile:

```ruby
gem 'wrenchmode-rack'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install wrenchmode-rack

The gem will automatically pull everything it needs from your application's Heroku environment.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'wrenchmode-rack'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install wrenchmode-rack

## Usage: Heroku Add-on (Coming soon...)

(Note: We are still waiting on final approval from Heroku for our add-on)

Add the [Wrenchmode Heroku add-on](https://elements.heroku.com/addons) to your application's list of add-ons. Deploy your application after installing the gem (see Installation above).

On deployment, the wrenchmode-rack gem will automatically pick up everything it needs from your application's Heroku environment.

## Usage: Manual Installation

### In a Rails application

```ruby
# config/environments/production.rb
config.middleware.insert_before 0, Wrenchmode::Rack, jwt: "your-long-jwt"

# If you want to test in staging prior to deploying to production.
# (Coming soon, still not implemented...)
# config/environments/staging.rb
config.middleware.use Wrenchmode::Rack, ignore_test_mode: false, jwt: "your-long-jwt"
```

### In a vanilla Rack application

```ruby
# your-app.rb
require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

use Wrenchmode::Rack, jwt: "your-long-jwt"
```

## IP Whitelisting and Proxies (including Heroku)

If you are behind a proxy (ie. you are on Heroku, Amazon ELB, nginx proxy, etc.) then you will most likely need to use the `ActionDispatch::RemoteIp` Rack middleware to correctly retrieve the client's IP address. This is included automatically for Rails, but not for vanilla Rack applications.

To use Wrenchmode with a proxy, configure it as follows:

```ruby
# config/environments/production.rb
config.middleware.insert_after ActionDispatch::RemoteIp, Wrenchmode::Rack, jwt: "your-long-jwt"
```

Note: The `jwt` option is not necessary on Heroku, as this is automatically set when you install the Add-on.

## Advanced Configuration Options

You can also specify the following options to the middleware layer:

`force_open` - Set to true to force the middlware layer to allow all requests through, regardless of project status on Wrenchmode.com. Effectively disables the middleware. (Default false)

`ignore_test_mode` - (Coming soon...) Set to false to if you want the middleware to respond to a project that is in Test mode on Wrenchmode.com This can be useful if you want to test Wrenchmode in a development or staging environment prior to deploying to production. (Default true)

`disable_local_wrench` - (Coming soon...) Set to true if you want to disable LocalWrench mode, where the Wrenchmode page is served on your domain. Disabling it will instead force a redirect to the Wrenchmode.com domain. Note: Unless you explicitly want this behavior, it's best to leave this at the default. (Default false)

`trust_remote_ip` - Set to false to ignore the IP addresses in the X-Forwarded-For header. This setting only matters for IP whitelisting. If you are behind a proxy (ie. Heroku, Amazon ELB, and many others) then this must be true for IP whitelisting to work. In addition, you must install the ActionDispatch::RemoteIp Rack layer. This is automatic if you are using Rails. (Default true)

`check_delay_secs` - Change this to modify the rate at which the middleware polls Wrenchmode for updates. Unlikely that this needs anything faster than the default. (Default 5)

`logging` - Set to true in order to log information from the middleware layer to your logging facility. (Default false)

## FAQ

### Does every request to my server get proxied through Wrenchmode? Isn't that slow?

No. The middleware does not function as a proxy at all in that fashion. Instead, the middleware spins up a separate thread that periodically checks the Wrenchmode API for changes and updates its own internal state. In other words, the middleware adds zero performance impact on requests to your server.

### What if the Wrenchmode service is down? Will my project be brought down as well?

No. The middleware is designed to fail open, meaning that if it encounters any errors or cannot contact the Wrenchmode API, it will automatically revert to "open" mode where it allows all requests to pass through normally to your server.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/micahwedemeyer/wrenchmode-rack. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

