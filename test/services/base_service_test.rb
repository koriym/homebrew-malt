# frozen_string_literal: true

require_relative "../test_helper"

class BaseServiceTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("malt_test")
    @config_content = <<~JSON
      {
        "project_name": "test_project",
        "dependencies": ["php@8.4"],
        "ports": {
          "php": [9000]
        },
        "php_extensions": []
      }
    JSON

    # Create malt.json
    File.write(File.join(@temp_dir, "malt.json"), @config_content)

    # Create malt/conf directory
    @conf_dir = File.join(@temp_dir, "malt", "conf")
    FileUtils.mkdir_p(@conf_dir)

    @config = Malt::Config.new(File.join(@temp_dir, "malt.json"))
    @service = Malt::BaseService.new
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_create_temp_config_creates_tmp_file
    # Create a test config file with template variables
    config_path = File.join(@conf_dir, "test.conf")
    File.write(config_path, "malt_dir={{MALT_DIR}}")

    result = @service.create_temp_config(@config, config_path)

    assert_equal "#{config_path}.tmp", result
    assert File.exist?(result)
  end

  def test_create_temp_config_performs_variable_substitution
    config_path = File.join(@conf_dir, "test.conf")
    File.write(config_path, "malt_dir={{MALT_DIR}}\nphp_version={{PHP_VERSION}}")

    result = @service.create_temp_config(@config, config_path)

    content = File.read(result)
    assert_includes content, @config.malt_dir
    assert_includes content, @config.php_version
    refute_includes content, "{{MALT_DIR}}"
    refute_includes content, "{{PHP_VERSION}}"
  end

  def test_create_temp_config_prevents_tmp_tmp_accumulation
    config_path = File.join(@conf_dir, "test.conf.tmp")
    File.write(config_path, "content")

    result = @service.create_temp_config(@config, config_path)

    # Should return same path, not test.conf.tmp.tmp
    assert_equal config_path, result
    refute File.exist?("#{config_path}.tmp")
  end

  def test_create_temp_config_with_extras_adds_extra_variables
    config_path = File.join(@conf_dir, "test.conf")
    File.write(config_path, "index={{INDEX}}")

    result = @service.create_temp_config_with_extras(@config, config_path, { "INDEX" => "0" })

    content = File.read(result)
    assert_includes content, "index=0"
    refute_includes content, "{{INDEX}}"
  end

  def test_create_temp_config_returns_nil_for_missing_file
    result = @service.create_temp_config(@config, "/nonexistent/file.conf")

    assert_nil result
  end

  def test_remove_temp_config_deletes_file
    temp_path = File.join(@conf_dir, "test.conf.tmp")
    File.write(temp_path, "content")

    assert File.exist?(temp_path)
    @service.remove_temp_config(temp_path)
    refute File.exist?(temp_path)
  end

  def test_remove_temp_config_handles_nonexistent_file
    # Should not raise an error
    @service.remove_temp_config("/nonexistent/file.conf.tmp")
  end

  def test_cleanup_temp_files_removes_matching_files
    # Create some temp files
    File.write(File.join(@conf_dir, "php.conf.tmp"), "content")
    File.write(File.join(@conf_dir, "mysql.conf.tmp"), "content")
    File.write(File.join(@conf_dir, "keep.conf"), "content")

    @service.cleanup_temp_files(@config, "*.conf.tmp")

    refute File.exist?(File.join(@conf_dir, "php.conf.tmp"))
    refute File.exist?(File.join(@conf_dir, "mysql.conf.tmp"))
    assert File.exist?(File.join(@conf_dir, "keep.conf"))
  end

  def test_port_in_use_returns_boolean
    result = @service.port_in_use?(99999)

    assert_includes [true, false], result
  end

  def test_with_temp_config_yields_temp_path
    config_path = File.join(@conf_dir, "test.conf")
    File.write(config_path, "content")

    yielded_path = nil
    @service.with_temp_config(@config, config_path) do |temp_path|
      yielded_path = temp_path
    end

    assert_equal "#{config_path}.tmp", yielded_path
  end

  def test_with_temp_config_returns_nil_on_failure
    result = @service.with_temp_config(@config, "/nonexistent/file.conf") do |_temp_path|
      flunk "Should not yield for nonexistent file"
    end

    assert_nil result
  end
end
