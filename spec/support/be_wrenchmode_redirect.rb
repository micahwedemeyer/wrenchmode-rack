RSpec::Matchers.define :be_wrenchmode_redirect do
  match do |response|
    response.status == 302 &&
    response.headers["Location"] =~ /wrenchmode.com/
  end

  # Optional failure messages
  failure_message do |actual|
    "expected #{actual.inspect} to 302 redirect to wrenchmode"
  end

  failure_message_when_negated do |actual|
    "expected #{actual.inspect} to not 302 redirect to wrenchmode"
  end

  # Optional method description
  description do
    "checks if the response is a redirect to wrenchmode"
  end
end