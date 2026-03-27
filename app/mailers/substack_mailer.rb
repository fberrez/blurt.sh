# frozen_string_literal: true

class SubstackMailer < ApplicationMailer
  def publish(title:, html_body:, from:, to:, smtp_settings:)
    mail(
      from: from,
      to: to,
      subject: title,
      delivery_method_options: smtp_settings
    ) do |format|
      format.html { render html: html_body.html_safe }
    end
  end
end
