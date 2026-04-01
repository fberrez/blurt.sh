# frozen_string_literal: true

require "test_helper"

class Publishers::SubstackPublisherTest < ActiveSupport::TestCase
  setup do
    @config = {
      smtp_host: "smtp.gmail.com",
      smtp_port: 587,
      smtp_user: "test@gmail.com",
      smtp_password: "password",
      from_address: "author@example.com",
      to_address: "import@substack.com"
    }
    @post = Post.new(
      title: "My Substack Draft",
      content: "# Hello\n\nThis is **bold** text.",
      filename: "test.md",
      platforms: %w[substack]
    )
    ActionMailer::Base.deliveries.clear
  end

  test "sends email and returns message-id URL" do
    result = Publishers::SubstackPublisher.publish(@post, config: @config)

    assert_equal 1, ActionMailer::Base.deliveries.size

    email = ActionMailer::Base.deliveries.last
    assert_equal "My Substack Draft", email.subject
    assert_equal [ "author@example.com" ], email.from
    assert_equal [ "import@substack.com" ], email.to

    assert result[:url].start_with?("message-id:")
    assert_kind_of Time, result[:published_at]
  end

  test "sends HTML body rendered from markdown" do
    Publishers::SubstackPublisher.publish(@post, config: @config)

    email = ActionMailer::Base.deliveries.last
    assert_includes email.body.to_s, "<strong>bold</strong>"
  end

  test "uses title as subject line" do
    Publishers::SubstackPublisher.publish(@post, config: @config)

    email = ActionMailer::Base.deliveries.last
    assert_equal "My Substack Draft", email.subject
  end
end
