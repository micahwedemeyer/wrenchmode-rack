# Wrenchmode Rack

[![Gem Version](https://badge.fury.io/rb/wrenchmode-rack.svg)](https://badge.fury.io/rb/wrenchmode-rack)

This is a [Rack Middleware](http://rack.github.io/) for managing maintenance mode on your Ruby/Rack/Rails web application using [Wrenchmode](http://wrenchmode.com).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'wrenchmode-rack'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install wrenchmode-rack

## Usage

### In a Rails application

```ruby
# config/environments/production.rb
config.middleware.use Wrenchmode::Rack, jwt: "your-long-jwt"

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

## Advanced Configuration Options

You can also specify the following options to the middleware layer:

`force_open` - Set to true to force the middlware layer to allow all requests through, regardless of project status on Wrenchmode.com. Effectively disables the middleware. (Default false)

`ignore_test_mode` - (Coming soon...) Set to false to if you want the middleware to respond to a project that is in Test mode on Wrenchmode.com This can be useful if you want to test Wrenchmode in a development or staging environment prior to deploying to production. (Default true)

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

