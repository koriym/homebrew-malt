# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "rbconfig"
require "shellwords"
require "project"

class ProjectTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("malt project test")
    @fake_bin = File.join(@temp_dir, "bin")
    FileUtils.mkdir_p(@fake_bin)
    @repo_root = File.expand_path("..", __dir__)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_env_script_is_sourceable_with_space_in_project_path
    config_path = File.join(@temp_dir, "malt.json")
    File.write(config_path, JSON.generate({
      "project_name" => "space_test",
      "dependencies" => ["php@8.4", "mysql@8.0"],
      "ports" => { "php" => [9000], "mysql" => [3306] },
      "php_extensions" => []
    }))
    env_file = File.join(@temp_dir, "malt-env.sh")
    File.write(env_file, Malt::Project.env_script(config: config_path))

    stdout, stderr, status = Open3.capture3(
      "zsh",
      "-c",
      "source #{Shellwords.escape(env_file)}; print -r -- \"$MALT_DIR\"; alias mysql@3306"
    )

    assert status.success?, stderr
    assert_includes stdout, File.join(@temp_dir, "malt")
    assert_includes stdout, "--defaults-file\\=#{File.join(@temp_dir, "malt", "conf", "my_3306.cnf")}"
  end

  def test_install_deps_returns_nonzero_when_brew_install_fails
    write_fake_brew(fail_install: true)
    config_path = File.join(@temp_dir, "malt.json")
    File.write(config_path, JSON.generate({
      "project_name" => "install_fail",
      "dependencies" => ["bad-formula"],
      "ports" => { "php" => [9000] },
      "php_extensions" => []
    }))

    stdout, _stderr, status = run_malt("install", "--config", config_path)

    refute status.success?
    assert_includes stdout, "Error: Failed to install: bad-formula"
  end

  def test_install_deps_handles_php_extensions_without_dependencies
    write_fake_brew(fail_install: false)
    config_path = File.join(@temp_dir, "malt.json")
    File.write(config_path, JSON.generate({
      "project_name" => "extensions_only",
      "ports" => { "php" => [9000] },
      "php_extensions" => ["xdebug"]
    }))

    stdout, stderr, status = run_malt("install", "--config", config_path)

    assert status.success?, stderr
    refute_includes stdout, "undefined method"
    assert_includes stdout, "[Installing] xdebug"
  end

  private

  def run_malt(*args)
    env = { "PATH" => "#{@fake_bin}:#{ENV.fetch("PATH")}" }
    Open3.capture3(env, RbConfig.ruby, File.join(@repo_root, "bin", "malt.rb"), *args, chdir: @temp_dir)
  end

  def write_fake_brew(fail_install:)
    install_result = fail_install ? "exit 42" : "exit 0"
    brew_path = File.join(@fake_bin, "brew")
    File.write(brew_path, <<~SH)
      #!/bin/sh
      case "$1" in
        --prefix)
          printf "/opt/homebrew"
          exit 0
          ;;
        list)
          exit 0
          ;;
        install)
          #{install_result}
          ;;
      esac
      exit 0
    SH
    FileUtils.chmod(0o755, brew_path)
  end
end
