# frozen_string_literal: true

require_relative "test_helper"

class ServiceManagerTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("malt_test")
    @original_pwd = Dir.pwd

    @config_content = <<~JSON
      {
        "project_name": "test_project",
        "dependencies": ["php@8.4", "mysql@8.0", "redis"],
        "ports": {
          "php": [9000],
          "mysql": [3306],
          "redis": [6379]
        },
        "php_extensions": []
      }
    JSON

    # Create malt.json
    File.write(File.join(@temp_dir, "malt.json"), @config_content)

    # Create malt directories
    @conf_dir = File.join(@temp_dir, "malt", "conf")
    @logs_dir = File.join(@temp_dir, "malt", "logs")
    FileUtils.mkdir_p(@conf_dir)
    FileUtils.mkdir_p(@logs_dir)

    # Change to temp directory for tests
    Dir.chdir(@temp_dir)
  end

  def teardown
    Dir.chdir(@original_pwd)
    FileUtils.rm_rf(@temp_dir)
  end

  def test_register_services_returns_php_service_when_configured
    config = Malt::Config.new(File.join(@temp_dir, "malt.json"))

    services = Malt::ServiceManager.send(:register_services, config)

    assert services.any? { |s| s.is_a?(Malt::PhpService) }
  end

  def test_register_services_returns_mysql_service_when_configured
    config = Malt::Config.new(File.join(@temp_dir, "malt.json"))

    services = Malt::ServiceManager.send(:register_services, config)

    assert services.any? { |s| s.is_a?(Malt::MysqlService) }
  end

  def test_register_services_returns_redis_service_when_configured
    config = Malt::Config.new(File.join(@temp_dir, "malt.json"))

    services = Malt::ServiceManager.send(:register_services, config)

    assert services.any? { |s| s.is_a?(Malt::RedisService) }
  end

  def test_register_services_does_not_return_unconfigured_services
    config_content = <<~JSON
      {
        "project_name": "test_project",
        "dependencies": ["php@8.4"],
        "ports": {
          "php": [9000]
        },
        "php_extensions": []
      }
    JSON
    File.write(File.join(@temp_dir, "malt.json"), config_content)
    config = Malt::Config.new(File.join(@temp_dir, "malt.json"))

    services = Malt::ServiceManager.send(:register_services, config)

    refute services.any? { |s| s.is_a?(Malt::MysqlService) }
    refute services.any? { |s| s.is_a?(Malt::NginxService) }
    refute services.any? { |s| s.is_a?(Malt::HttpdService) }
  end

  def test_cleanup_old_temp_files_removes_conf_tmp
    File.write(File.join(@conf_dir, "test.conf.tmp"), "content")
    config = Malt::Config.new(File.join(@temp_dir, "malt.json"))

    Malt::ServiceManager.send(:cleanup_old_temp_files, config)

    refute File.exist?(File.join(@conf_dir, "test.conf.tmp"))
  end

  def test_cleanup_old_temp_files_removes_ini_tmp
    File.write(File.join(@conf_dir, "php.ini.tmp"), "content")
    config = Malt::Config.new(File.join(@temp_dir, "malt.json"))

    Malt::ServiceManager.send(:cleanup_old_temp_files, config)

    refute File.exist?(File.join(@conf_dir, "php.ini.tmp"))
  end

  def test_cleanup_old_temp_files_removes_cnf_tmp
    File.write(File.join(@conf_dir, "my.cnf.tmp"), "content")
    config = Malt::Config.new(File.join(@temp_dir, "malt.json"))

    Malt::ServiceManager.send(:cleanup_old_temp_files, config)

    refute File.exist?(File.join(@conf_dir, "my.cnf.tmp"))
  end

  def test_cleanup_old_temp_files_does_not_remove_non_tmp_files
    File.write(File.join(@conf_dir, "test.conf"), "content")
    config = Malt::Config.new(File.join(@temp_dir, "malt.json"))

    Malt::ServiceManager.send(:cleanup_old_temp_files, config)

    assert File.exist?(File.join(@conf_dir, "test.conf"))
  end

  def test_find_config_in_current_dir_finds_malt_json
    result = Malt::ServiceManager.send(:find_config_in_current_dir, {})

    # Use realpath to handle macOS /var -> /private/var symlink
    assert_equal File.realpath(File.join(@temp_dir, "malt.json")), File.realpath(result)
  end

  def test_find_config_in_current_dir_uses_option_config
    custom_path = File.join(@temp_dir, "custom.json")
    File.write(custom_path, @config_content)

    result = Malt::ServiceManager.send(:find_config_in_current_dir, { config: custom_path })

    assert_equal custom_path, result
  end

  def test_find_config_in_current_dir_raises_when_not_found
    FileUtils.rm(File.join(@temp_dir, "malt.json"))

    assert_raises RuntimeError do
      Malt::ServiceManager.send(:find_config_in_current_dir, {})
    end
  end
end
