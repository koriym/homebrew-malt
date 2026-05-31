# frozen_string_literal: true

require_relative "test_helper"

class ConfigTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("malt_test")
    @config_path = File.join(@temp_dir, "malt.json")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def write_config(data)
    File.write(@config_path, JSON.generate(data))
  end

  def test_initialize_reads_config_file
    write_config({
      "project_name" => "test_app",
      "dependencies" => ["php@8.4"],
      "ports" => { "php" => [9000] },
      "php_extensions" => ["xdebug"]
    })

    config = Malt::Config.new(@config_path)

    assert_equal "test_app", config.project_name
    assert_equal ["php@8.4"], config.dependencies
    assert_equal({ "php" => [9000] }, config.ports)
    assert_equal ["xdebug"], config.php_extensions
  end

  def test_initialize_raises_for_missing_file
    assert_raises RuntimeError do
      Malt::Config.new("/nonexistent/malt.json")
    end
  end

  def test_initialize_raises_for_invalid_json
    File.write(@config_path, "not valid json{")

    assert_raises RuntimeError do
      Malt::Config.new(@config_path)
    end
  end

  def test_initialize_defaults_for_missing_fields
    write_config({})

    config = Malt::Config.new(@config_path)

    assert_equal File.basename(@temp_dir), config.project_name
    assert_equal [], config.dependencies
    assert_equal({}, config.ports)
    assert_equal [], config.php_extensions
  end

  def test_php_version_extracts_from_dependencies
    write_config({
      "dependencies" => ["php@8.3", "mysql@8.0"],
      "ports" => {}
    })

    config = Malt::Config.new(@config_path)

    assert_equal "8.3", config.php_version
  end

  def test_php_version_defaults_to_8_4
    write_config({
      "dependencies" => ["mysql@8.0"],
      "ports" => {}
    })

    config = Malt::Config.new(@config_path)

    assert_equal "8.4", config.php_version
  end

  def test_mysql_version_extracts_from_dependencies
    write_config({
      "dependencies" => ["php@8.4", "mysql@8.1"],
      "ports" => {}
    })

    config = Malt::Config.new(@config_path)

    assert_equal "8.1", config.mysql_version
  end

  def test_mysql_version_defaults_to_8_0
    write_config({
      "dependencies" => ["php@8.4"],
      "ports" => {}
    })

    config = Malt::Config.new(@config_path)

    assert_equal "8.0", config.mysql_version
  end

  def test_has_service_returns_true_for_configured_service
    write_config({
      "ports" => { "php" => [9000], "redis" => [6379] }
    })

    config = Malt::Config.new(@config_path)

    assert config.has_service?("php")
    assert config.has_service?("redis")
  end

  def test_has_service_returns_false_for_unconfigured_service
    write_config({
      "ports" => { "php" => [9000] }
    })

    config = Malt::Config.new(@config_path)

    refute config.has_service?("mysql")
    refute config.has_service?("nginx")
  end

  def test_has_service_returns_false_for_empty_ports
    write_config({
      "ports" => { "php" => [] }
    })

    config = Malt::Config.new(@config_path)

    refute config.has_service?("php")
  end

  def test_malt_dir
    write_config({ "ports" => {} })
    config = Malt::Config.new(@config_path)

    assert_equal File.join(@temp_dir, "malt"), config.malt_dir
  end

  def test_conf_dir
    write_config({ "ports" => {} })
    config = Malt::Config.new(@config_path)

    assert_equal File.join(@temp_dir, "malt", "conf"), config.conf_dir
  end

  def test_logs_dir
    write_config({ "ports" => {} })
    config = Malt::Config.new(@config_path)

    assert_equal File.join(@temp_dir, "malt", "logs"), config.logs_dir
  end

  def test_var_dir
    write_config({ "ports" => {} })
    config = Malt::Config.new(@config_path)

    assert_equal File.join(@temp_dir, "malt", "var"), config.var_dir
  end

  def test_tmp_dir
    write_config({ "ports" => {} })
    config = Malt::Config.new(@config_path)

    assert_equal File.join(@temp_dir, "malt", "tmp"), config.tmp_dir
  end

  def test_document_root
    write_config({ "ports" => {} })
    config = Malt::Config.new(@config_path)

    assert_equal File.join(@temp_dir, "public"), config.document_root
  end

  def test_project_dir
    write_config({ "ports" => {} })
    config = Malt::Config.new(@config_path)

    assert_equal @temp_dir, config.project_dir
  end

  def test_validate_passes_with_valid_config
    write_config({
      "project_name" => "test",
      "ports" => { "php" => [9000] }
    })

    config = Malt::Config.new(@config_path)

    assert config.validate!
  end

  def test_validate_raises_for_missing_project_name
    write_config({
      "project_name" => "",
      "ports" => { "php" => [9000] }
    })

    config = Malt::Config.new(@config_path)

    assert_raises RuntimeError do
      config.validate!
    end
  end

  def test_validate_raises_for_missing_php_ports
    write_config({
      "project_name" => "test",
      "ports" => { "mysql" => [3306] }
    })

    config = Malt::Config.new(@config_path)

    assert_raises RuntimeError do
      config.validate!
    end
  end
end
