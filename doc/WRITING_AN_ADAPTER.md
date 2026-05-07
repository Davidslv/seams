# Writing an Adapter

Two engines ship adapter contracts: Notifications (email + SMS) and
Billing (payment gateway). The pattern is the same in both.

## The contract

Each engine has an abstract base class that documents the methods
every adapter must implement:

```ruby
# engines/notifications/lib/notifications/adapters/abstract.rb
module Notifications::Adapters
  class Abstract
    def deliver(_to:, _subject:, _body:, **_extras)
      raise NotImplementedError, "#{self.class} must implement #deliver"
    end
  end
end
```

```ruby
# engines/billing/lib/billing/gateways/abstract.rb
module Billing::Gateways
  class Abstract
    def create_subscription(customer_ref:, plan_ref:, **)
      raise NotImplementedError
    end
    def cancel_subscription(subscription_ref:, **);    raise NotImplementedError; end
    def fetch_subscription(subscription_ref:);          raise NotImplementedError; end
    def verify_webhook(payload:, signature:, secret:);  raise NotImplementedError; end
  end
end
```

## Write your adapter

Subclass the abstract base in your host application (typically under
`app/adapters/`):

```ruby
# app/adapters/mailgun_adapter.rb
require "notifications/adapters/abstract"

class MailgunAdapter < Notifications::Adapters::Abstract
  def deliver(to:, subject:, body:, from: nil, **)
    response = mailgun.send_message(domain, {
      from: from || ENV.fetch("MAILGUN_FROM"),
      to: to, subject: subject, text: body
    })
    { ok: true, provider: "mailgun", message_id: response.id }
  end

  private

  def mailgun
    @mailgun ||= Mailgun::Client.new(ENV.fetch("MAILGUN_API_KEY"))
  end

  def domain
    ENV.fetch("MAILGUN_DOMAIN")
  end
end
```

## Verify against the provider's docs

Per the Seams external-API rule, every adapter MUST cite the
provider's official documentation URL inline:

```ruby
class MailgunAdapter < Notifications::Adapters::Abstract
  # Docs: https://documentation.mailgun.com/docs/mailgun/api-reference/sending-messages/
  # Required params: from, to, subject, text or html.
  # Returns: { id, message } on success; raises Mailgun::CommunicationError otherwise.
  def deliver(to:, subject:, body:, from: nil, **)
    # ...
  end
end
```

The Stripe gateway in the canonical Billing engine is the reference
implementation —
[engines/billing/lib/billing/gateways/stripe.rb](#) cites
`docs.stripe.com` for every Stripe API call it makes.

## Wire it up

Configure your engine's `Configuration` to point at your adapter:

```ruby
# config/initializers/notifications.rb
Notifications.configure do |c|
  c.email_adapter = "MailgunAdapter"
end
```

```ruby
# config/initializers/billing.rb
Billing.configure do |c|
  c.gateway = "PaddleGateway"
end
```

The engine resolves the class via `String#constantize` at first use,
not boot time, so a typo only surfaces when the adapter is actually
called (with a clear error message wrapped in `Billing::Error` /
`Notifications::Error`).

## Test your adapter

Adapter tests live in your host application's spec/ directory and
should mock the provider's SDK at the boundary:

```ruby
require "rails_helper"

RSpec.describe MailgunAdapter do
  let(:client) { instance_double(Mailgun::Client) }

  before { allow(Mailgun::Client).to receive(:new).and_return(client) }

  it "calls send_message with the documented params" do
    allow(client).to receive(:send_message).and_return(double(id: "<msg@example>"))

    result = described_class.new.deliver(to: "x@y.com", subject: "Hi", body: "Hello")

    expect(client).to have_received(:send_message).with(
      ENV["MAILGUN_DOMAIN"],
      hash_including(to: "x@y.com", subject: "Hi", text: "Hello")
    )
    expect(result).to include(ok: true, provider: "mailgun")
  end
end
```

For real-API verification, use the provider's test mode plus
recorded fixtures (vcr) — never hit the live API in CI.

## Adapter contracts to extend, not replace

If your provider supports something the contract doesn't cover
(scheduled sends, attachments, multi-recipient batch sends), pass
it via `**extras` first and validate that across providers before
proposing a contract change. The contract should be the smallest
thing every plausible provider can implement.
