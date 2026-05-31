# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "rbconfig"

class CliTest < Minitest::Test
  def setup
    @repo_root = File.expand_path("..", __dir__)
    @malt_bin = File.join(@repo_root, "bin", "malt.rb")
    @version = File.read(File.join(@repo_root, "Formula", "malt.rb"))[/version "([^"]+)"/, 1]
  end

  def test_no_command_shows_help_with_version
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, @malt_bin)

    assert status.success?, stderr
    assert_includes stdout, "Malt #{@version} - JSON-driven development environment manager"
    assert_includes stdout, "Usage: malt COMMAND [OPTIONS]"
  end

  def test_global_help_shows_help_with_version
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, @malt_bin, "--help")

    assert status.success?, stderr
    assert_includes stdout, "Malt #{@version} - JSON-driven development environment manager"
    refute_includes stdout, "Unknown command"
  end
end
