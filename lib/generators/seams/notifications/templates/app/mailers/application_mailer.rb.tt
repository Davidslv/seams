# frozen_string_literal: true

module Notifications
  # Engine-scoped mailer parent so NotificationMailer doesn't reach
  # into the host's ::ApplicationMailer at autoload time. Hosts that
  # want a layout add `layout "mailer"` here (or per mailer); we don't
  # ship one because the dummy app has no `app/views/layouts/mailer.*`
  # to render and forcing one would crash dummy specs.
  class ApplicationMailer < ::ApplicationMailer
    default from: -> { Notifications.configuration.default_from }
  end
end
