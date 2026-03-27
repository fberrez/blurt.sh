# frozen_string_literal: true

module Publishers
  class SubstackPublisher < Base
    def call(post, _images)
      log("Publishing '#{post.title}' to Substack via email")

      html_body = MarkdownProcessor.to_html(post.content)

      message = SubstackMailer.publish(
        title: post.title,
        html_body: html_body,
        from: @config[:from_address],
        to: @config[:to_address],
        smtp_settings: smtp_settings
      ).deliver_now

      message_id = message.message_id
      log("Email sent with Message-ID: #{message_id}")

      { url: "message-id:#{message_id}", published_at: Time.current }
    end

    private

    def smtp_settings
      {
        address: @config[:smtp_host],
        port: @config[:smtp_port],
        user_name: @config[:smtp_user],
        password: @config[:smtp_password],
        authentication: :plain,
        enable_starttls_auto: @config[:smtp_port] != 465,
        tls: @config[:smtp_port] == 465
      }
    end
  end
end
