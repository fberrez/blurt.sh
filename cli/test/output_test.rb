# frozen_string_literal: true

require "test_helper"

class OutputTest < Minitest::Test
  def test_success_outputs_to_stdout
    output = capture_io { Blurt::Output.success("It worked") }.first
    assert_includes output, "It worked"
    assert_includes output, "[ok]"
  end

  def test_error_outputs_to_stderr
    err_output = capture_io { Blurt::Output.error("Bad thing") }.last
    assert_includes err_output, "Bad thing"
    assert_includes err_output, "[error]"
  end

  def test_warn_outputs_to_stderr
    err_output = capture_io { Blurt::Output.warn("Watch out") }.last
    assert_includes err_output, "Watch out"
    assert_includes err_output, "!"
  end

  def test_info_outputs_to_stdout
    output = capture_io { Blurt::Output.info("Just info") }.first
    assert_includes output, "Just info"
  end

  def test_colorize_returns_plain_text_when_not_tty
    result = Blurt::Output.colorize("hello", :green)
    assert_equal "hello", result
  end

  def test_checkmark_degrades_when_not_tty
    assert_equal "[ok]", Blurt::Output.checkmark
  end

  def test_cross_degrades_when_not_tty
    assert_equal "[error]", Blurt::Output.cross
  end
end
