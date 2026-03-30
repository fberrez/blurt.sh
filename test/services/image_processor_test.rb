# frozen_string_literal: true

require "test_helper"

class ImageProcessorTest < ActiveSupport::TestCase
  setup do
    @test_dir = Rails.root.join("tmp", "test_images_#{SecureRandom.hex(4)}")
    FileUtils.mkdir_p(@test_dir)
  end

  teardown do
    FileUtils.rm_rf(@test_dir)
  end

  test "read_and_resize returns original bytes when under max" do
    path = create_test_image("small.jpg", 500)
    attachment = ImageAttachment.new(
      file_path: path, filename: "small.jpg", alt: "A small image", mime_type: "image/jpeg"
    )

    result = ImageProcessor.read_and_resize(attachment, max_bytes: 1_000)

    assert_equal 500, result[:byte_size]
    assert_equal "small.jpg", result[:filename]
    assert_equal "A small image", result[:alt]
    assert_equal "image/jpeg", result[:mime_type]
    assert_kind_of StringIO, result[:io]
  end

  test "read_and_resize raises for missing file" do
    attachment = ImageAttachment.new(
      file_path: "/nonexistent/image.jpg", filename: "image.jpg", mime_type: "image/jpeg"
    )

    assert_raises(ArgumentError) do
      ImageProcessor.read_and_resize(attachment)
    end
  end

  test "read_and_resize skips resize for GIF (preserves animation)" do
    path = create_test_image("anim.gif", 2_000_000)
    attachment = ImageAttachment.new(
      file_path: path, filename: "anim.gif", alt: "", mime_type: "image/gif"
    )

    result = ImageProcessor.read_and_resize(attachment, max_bytes: 1_000_000)

    assert_equal 2_000_000, result[:byte_size]
  end

  test "read_and_resize passes alt text through" do
    path = create_test_image("alt.jpg", 100)
    attachment = ImageAttachment.new(
      file_path: path, filename: "alt.jpg", alt: "Description here", mime_type: "image/jpeg"
    )

    result = ImageProcessor.read_and_resize(attachment, max_bytes: 1_000)

    assert_equal "Description here", result[:alt]
  end

  private

  def create_test_image(filename, size_bytes)
    path = File.join(@test_dir, filename)
    File.binwrite(path, "\x00" * size_bytes)
    path
  end
end
