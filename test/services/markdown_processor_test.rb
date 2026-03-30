# frozen_string_literal: true

require "test_helper"

class MarkdownProcessorTest < ActiveSupport::TestCase
  # --- to_plaintext ---

  test "strips heading markers" do
    assert_equal "Hello World", MarkdownProcessor.to_plaintext("## Hello World")
  end

  test "strips bold and italic markers" do
    assert_equal "bold and italic", MarkdownProcessor.to_plaintext("**bold** and *italic*")
  end

  test "strips inline links, keeps text" do
    assert_equal "click here", MarkdownProcessor.to_plaintext("[click here](https://example.com)")
  end

  test "strips images, keeps alt text" do
    assert_equal "photo", MarkdownProcessor.to_plaintext("![photo](image.jpg)")
  end

  test "strips inline code backticks" do
    assert_equal "run rails server", MarkdownProcessor.to_plaintext("run `rails server`")
  end

  test "strips fenced code blocks entirely" do
    md = "before\n```\nputs 'hi'\n```\nafter"
    assert_equal "before\n\nafter", MarkdownProcessor.to_plaintext(md)
  end

  test "strips blockquote markers" do
    assert_equal "quoted text", MarkdownProcessor.to_plaintext("> quoted text")
  end

  test "strips unordered list markers" do
    md = "- item one\n- item two"
    result = MarkdownProcessor.to_plaintext(md)
    assert_includes result, "item one"
    assert_includes result, "item two"
    refute_includes result, "- "
  end

  test "strips ordered list markers" do
    md = "1. first\n2. second"
    result = MarkdownProcessor.to_plaintext(md)
    assert_includes result, "first"
    refute_match(/\d+\./, result)
  end

  test "strips horizontal rules" do
    assert_equal "above\n\nbelow", MarkdownProcessor.to_plaintext("above\n\n---\n\nbelow")
  end

  test "collapses multiple newlines to two" do
    result = MarkdownProcessor.to_plaintext("a\n\n\n\n\nb")
    refute_includes result, "\n\n\n"
  end

  test "strips strikethrough markers" do
    assert_equal "deleted", MarkdownProcessor.to_plaintext("~~deleted~~")
  end

  # --- to_html ---

  test "renders bold as strong tag" do
    html = MarkdownProcessor.to_html("**bold**")
    assert_includes html, "<strong>bold</strong>"
  end

  test "renders italic as em tag" do
    html = MarkdownProcessor.to_html("*italic*")
    assert_includes html, "<em>italic</em>"
  end

  test "renders headings" do
    html = MarkdownProcessor.to_html("# Title")
    assert_includes html, "<h1>Title</h1>"
  end

  test "renders fenced code blocks" do
    html = MarkdownProcessor.to_html("```\ncode\n```")
    assert_includes html, "<code>"
  end

  test "renders links with target blank" do
    html = MarkdownProcessor.to_html("[link](https://example.com)")
    assert_includes html, 'target="_blank"'
    assert_includes html, 'rel="noopener"'
  end

  test "autolinks URLs" do
    html = MarkdownProcessor.to_html("Visit https://example.com today")
    assert_includes html, "<a"
    assert_includes html, "https://example.com"
  end

  test "renders strikethrough" do
    html = MarkdownProcessor.to_html("~~deleted~~")
    assert_includes html, "<del>deleted</del>"
  end

  test "renders tables" do
    md = "| A | B |\n|---|---|\n| 1 | 2 |"
    html = MarkdownProcessor.to_html(md)
    assert_includes html, "<table>"
  end
end
