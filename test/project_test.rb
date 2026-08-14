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
    @brew_install_log = File.join(@temp_dir, "brew-installs.log")
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
    assert_equal ["xdebug@8.4"], brew_install_calls
  end

  def test_install_deps_tries_php_extension_formula_candidates_until_success
    write_fake_brew(fail_install: false, failed_installs: ["xdebug@8.4"])
    config_path = File.join(@temp_dir, "malt.json")
    File.write(config_path, JSON.generate({
      "project_name" => "extensions_fallback",
      "dependencies" => ["php@8.4"],
      "ports" => { "php" => [9000] },
      "php_extensions" => ["xdebug"]
    }))

    _stdout, stderr, status = run_malt("install", "--config", config_path)

    assert status.success?, stderr
    assert_equal ["php@8.4", "xdebug@8.4", "phpxdebug@8.4"], brew_install_calls
  end

  def test_start_with_config_uses_config_project_malt_dir
    write_fake_brew(fail_install: false)
    project_dir = File.join(@temp_dir, "configured project")
    outside_dir = File.join(@temp_dir, "outside")
    FileUtils.mkdir_p(project_dir)
    FileUtils.mkdir_p(outside_dir)
    config_path = File.join(project_dir, "malt.json")
    File.write(config_path, JSON.generate({
      "project_name" => "configured_project",
      "dependencies" => ["php@8.4"],
      "ports" => { "php" => [19090] },
      "php_extensions" => []
    }))
    %w(conf logs tmp var).each do |dir|
      FileUtils.mkdir_p(File.join(project_dir, "malt", dir))
    end

    env = { "PATH" => "#{@fake_bin}:#{ENV.fetch("PATH")}" }
    stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, File.join(@repo_root, "bin", "malt.rb"), "start", "--config", config_path, chdir: outside_dir)

    # The PHP-FPM config file is missing, so start reports failure with a non-zero exit
    refute status.success?, stderr
    refute_includes stderr, File.join(outside_dir, "malt")
    assert_includes stderr, "Failed to start: PHP-FPM"
    assert_includes stdout, File.join(project_dir, "malt", "conf", "php-fpm_19090.conf")
  end

  private

  def run_malt(*args)
    env = { "PATH" => "#{@fake_bin}:#{ENV.fetch("PATH")}" }
    Open3.capture3(env, RbConfig.ruby, File.join(@repo_root, "bin", "malt.rb"), *args, chdir: @temp_dir)
  end

  def write_fake_brew(fail_install:, failed_installs: [])
    install_result = fail_install ? "exit 42" : "exit 0"
    failed_install_cases = failed_installs.map { |name| "#{name}) exit 42 ;;" }.join("\n    ")
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
          printf "%s\\n" "$2" >> "#{@brew_install_log}"
          case "$2" in
            #{failed_install_cases}
            *) ;;
          esac
          #{install_result}
          ;;
      esac
      exit 0
    SH
    FileUtils.chmod(0o755, brew_path)
  end

  def brew_install_calls
    return [] unless File.exist?(@brew_install_log)

    File.read(@brew_install_log).split("\n")
  end
end
