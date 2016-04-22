RSpec::Matchers.define :be_standard_response do
  match do |response|
    response.status == 200 &&
    response.body == "Hello, world."
  end

  # Optional failure messages
  failure_message do |actual|
    "expected #{actual.inspect} to be a 200 Hello World"
  end

  failure_message_when_negated do |actual|
    "expected #{actual.inspect} to not be a 200 Hellow World"
  end

  # Optional method description
  description do
    "checks if the response is passed through to the rest of the Rack stack as normal"
  end
end