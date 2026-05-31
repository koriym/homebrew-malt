# frozen_string_literal: true

require_relative "../test_helper"

class ScopedLifecycleTest < Minitest::Test
  class CapturingPhpService < Malt::PhpService
    attr_reader :pid_files

    def initialize
      @pid_files = []
    end

    def stop_pid_file(pid_file, _label, timeout: 10, expected_pattern: nil)
      @pid_files << pid_file
      true
    end

    def port_in_use?(_port)
      false
    end
  end

  class CapturingMemcachedService < Malt::MemcachedService
    attr_reader :pid_files

    def initialize
      @pid_files = []
    end

    def stop_pid_file(pid_file, _label, timeout: 10, expected_pattern: nil)
      @pid_files << pid_file
      true
    end

    def port_in_use?(_port)
      false
    end
  end

  class CapturingRedisService < Malt::RedisService
    attr_reader :pid_files, :system_calls

    def initialize(port_in_use: false)
      @pid_files = []
      @system_calls = []
      @port_in_use = port_in_use
    end

    def stop_pid_file(pid_file, _label, timeout: 10, expected_pattern: nil)
      @pid_files << pid_file
      true
    end

    def port_in_use?(_port)
      @port_in_use
    end

    def system(*args)
      @system_calls << args
      true
    end
  end

  class CapturingMysqlService < Malt::MysqlService
    attr_reader :system_calls

    def initialize(port_in_use: false)
      @system_calls = []
      @port_in_use = port_in_use
      @pid_running_checks = 0
    end

    def port_in_use?(_port)
      @port_in_use
    end

    def pid_running?(_pid)
      @pid_running_checks += 1
      @pid_running_checks == 1
    end

    def wait_for_pid_stop(_pid, timeout: 10)
    end

    def system(*args)
      @system_calls << args
      true
    end
  end

  class CapturingHttpdService < Malt::HttpdService
    attr_reader :system_calls

    def initialize(port_in_use: false)
      @system_calls = []
      @port_in_use = port_in_use
      @pid_running_checks = 0
    end

    def port_in_use?(_port)
      @port_in_use
    end

    def pid_running?(_pid)
      @pid_running_checks += 1
      @pid_running_checks == 1
    end

    def wait_for_pid_stop(_pid, timeout: 10)
    end

    def system(*args)
      @system_calls << args
      true
    end
  end

  class CapturingNginxService < Malt::NginxService
    attr_reader :pid_files, :system_calls

    def initialize
      @pid_files = []
      @system_calls = []
    end

    def stop_pid_file(pid_file, _label, timeout: 10, expected_pattern: nil)
      @pid_files << pid_file
      true
    end

    def pid_running_from_file?(_pid_file, expected_pattern: nil)
      false
    end

    def read_pid_file(_pid_file)
      12_345
    end

    def wait_for_pid_stop(_pid, timeout: 10)
    end

    def pid_running?(_pid)
      false
    end

    def port_in_use?(_port)
      false
    end

    def system(*args)
      @system_calls << args
      true
    end
  end

  def setup
    @temp_dir = Dir.mktmpdir("malt lifecycle test")
    @config_path = File.join(@temp_dir, "malt.json")
    File.write(@config_path, JSON.generate({
      "project_name" => "lifecycle_test",
      "dependencies" => ["php@8.4", "nginx", "memcached", "redis", "mysql@8.0", "httpd"],
      "ports" => {
        "php" => [9000],
        "nginx" => [8080],
        "memcached" => [11211],
        "redis" => [6379],
        "mysql" => [3306],
        "httpd" => [8080]
      },
      "php_extensions" => []
    }))
    @config = Malt::Config.new(@config_path)
    FileUtils.mkdir_p(@config.conf_dir)
    FileUtils.mkdir_p(@config.var_dir)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_php_stop_uses_project_pid_file_and_config_conf_cleanup
    pid_file = File.join(@config.var_dir, "php-fpm_9000.pid")
    tmp_file = File.join(@config.conf_dir, "php-fpm_9000.conf.tmp")
    ini_tmp = File.join(@config.conf_dir, "php.ini.tmp")
    File.write(pid_file, "12345")
    File.write(tmp_file, "tmp")
    File.write(ini_tmp, "tmp")

    service = CapturingPhpService.new
    service.stop(@config)

    assert_equal [pid_file], service.pid_files
    refute File.exist?(tmp_file)
    refute File.exist?(ini_tmp)
  end

  def test_memcached_stop_uses_project_pid_file
    pid_file = File.join(@config.var_dir, "memcached_11211.pid")
    File.write(pid_file, "12345")

    service = CapturingMemcachedService.new
    service.stop(@config)

    assert_equal [pid_file], service.pid_files
  end

  def test_redis_stop_leaves_port_without_project_pid_untouched
    service = CapturingRedisService.new(port_in_use: true)

    service.stop(@config)

    assert_empty service.pid_files
    assert_empty service.system_calls
  end

  def test_redis_stop_uses_project_pid_file
    pid_file = File.join(@config.var_dir, "redis_6379.pid")
    File.write(pid_file, "12345")

    service = CapturingRedisService.new
    service.stop(@config)

    assert_equal [pid_file], service.pid_files
  end

  def test_mysql_stop_leaves_port_without_project_pid_untouched
    service = CapturingMysqlService.new(port_in_use: true)

    service.stop(@config)

    assert_empty service.system_calls
  end

  def test_mysql_stop_uses_project_defaults_file_without_tcp_port
    data_dir = File.join(@config.var_dir, "mysql_0")
    FileUtils.mkdir_p(data_dir)
    File.write(File.join(data_dir, "mysqld.pid"), "12345")
    File.write(File.join(@config.conf_dir, "my_3306.cnf"), <<~CNF)
      [client]
      socket = {{MALT_DIR}}/tmp/mysql_3306.sock
    CNF

    service = CapturingMysqlService.new
    service.stop(@config)

    expected_conf = File.join(@config.conf_dir, "my_3306.cnf.tmp")
    assert_equal File.join(Malt::HOMEBREW_PREFIX, "opt", "mysql@8.0", "bin", "mysqladmin"), service.system_calls[0][0]
    assert_includes service.system_calls[0], "--defaults-file=#{expected_conf}"
    refute_includes service.system_calls[0], "-h"
    refute_includes service.system_calls[0], "--port"
  end

  def test_httpd_stop_leaves_port_without_project_pid_untouched
    service = CapturingHttpdService.new(port_in_use: true)

    service.stop(@config)

    assert_empty service.system_calls
  end

  def test_httpd_stop_uses_project_config_and_pid_file
    pid_file = File.join(@config.var_dir, "httpd_8080.pid")
    File.write(pid_file, "12345")
    File.write(File.join(@config.conf_dir, "httpd_8080.conf"), "PidFile \"{{MALT_DIR}}/var/httpd_8080.pid\"")

    service = CapturingHttpdService.new
    service.stop(@config)

    expected_conf = File.join(@config.conf_dir, "httpd_8080.conf.tmp")
    assert_equal [[File.join(Malt::HOMEBREW_PREFIX, "bin", "apachectl"), "-f", expected_conf, "-k", "stop", { out: File::NULL, err: File::NULL }]], service.system_calls
  end

  def test_nginx_stop_uses_project_temp_config_and_pid_file
    pid_file = File.join(@config.var_dir, "nginx.pid")
    File.write(File.join(@config.conf_dir, "nginx_8080.conf"), "root {{PROJECT_DIR}}/public;")
    File.write(File.join(@config.conf_dir, "nginx_main.conf"), <<~CONF)
      pid "{{MALT_DIR}}/var/nginx.pid";
      events {}
      http {
        include {{MALT_DIR}}/conf/nginx_8080.conf.tmp;
      }
    CONF
    File.write(pid_file, "12345")

    service = CapturingNginxService.new
    service.stop(@config)

    expected_conf = File.join(@config.conf_dir, "nginx_main.conf.tmp")
    assert_equal [[File.join(Malt::HOMEBREW_PREFIX, "bin", "nginx"), "-c", expected_conf, "-s", "stop"]], service.system_calls
    refute File.exist?(pid_file)
  end

  def test_nginx_start_uses_project_temp_config
    File.write(File.join(@config.conf_dir, "nginx_8080.conf"), "root {{PROJECT_DIR}}/public;")
    File.write(File.join(@config.conf_dir, "nginx_main.conf"), <<~CONF)
      pid "{{MALT_DIR}}/var/nginx.pid";
      events {}
      http {
        include {{MALT_DIR}}/conf/nginx_8080.conf.tmp;
      }
    CONF

    service = CapturingNginxService.new
    service.start(@config)

    expected_conf = File.join(@config.conf_dir, "nginx_main.conf.tmp")
    assert_equal [[File.join(Malt::HOMEBREW_PREFIX, "bin", "nginx"), "-c", expected_conf]], service.system_calls
    assert_includes File.read(expected_conf), File.join(@config.var_dir, "nginx.pid")
  end
end
