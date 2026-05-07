# frozen_string_literal: true

module Notifications
  # Single mailer used by Notifications::Adapters::ActionMailer.
  # Renders multipart/alternative (text + HTML) when both formats are
  # present in the host/engine template lookup chain. Falls back to a
  # single-part text email when only the text template exists.
  class NotificationMailer < ApplicationMailer
    def notify(notification)
      @notification = notification
      text_body     = notification.rendered_content(format: :text)
      html_body     =
        if notification.template_exists?(format: :html)
          notification.rendered_content(format: :html)
        end

      mail(to: notification.recipient, subject: notification.template.to_s.titleize) do |format|
        format.text { render plain: text_body, layout: "notifications/mailer" }
        format.html { render html: html_body.html_safe, layout: "notifications/mailer" } if html_body
      end
    end
  end
end
