# frozen_string_literal: true

require_relative "test_helper"
require "socket"

class KillRegistryTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("malt_test")
    @registry_dir = File.join(@temp_dir, "registry")
    @saved_registry_dir = ENV["MALT_REGISTRY_DIR"]
    ENV["MALT_REGISTRY_DIR"] = @registry_dir

    File.write(File.join(@temp_dir, "malt.json"), <<~JSON)
      {
        "project_name": "test_project",
        "dependencies": ["php@8.4", "redis"],
        "ports": {
          "php": [9000],
          "redis": [6379]
        },
        "php_extensions": []
      }
    JSON
    FileUtils.mkdir_p(File.join(@temp_dir, "malt", "conf"))
    FileUtils.mkdir_p(File.join(@temp_dir, "malt", "logs"))
    FileUtils.mkdir_p(File.join(@temp_dir, "malt", "var"))

    @config = Malt::Config.new(File.join(@temp_dir, "malt.json"))
    @service = Malt::BaseService.new
  end

  def teardown
    ENV["MALT_REGISTRY_DIR"] = @saved_registry_dir
    FileUtils.rm_rf(@temp_dir)
  end

  def test_register_and_unregister_process_roundtrip
    key = File.join(@temp_dir, "malt", "var", "redis_6379.pid")
    @service.register_process("redis", key, ["redis-server", "6379"], pid_file: key)

    entries = Malt::BaseService.registry_entries
    assert_equal 1, entries.size
    assert_equal "redis", entries[0]["service"]
    assert_equal ["redis-server", "6379"], entries[0]["pattern"]
    assert_equal key, entries[0]["pid_file"]

    @service.unregister_process(key)
    assert_empty Malt::BaseService.registry_entries
  end

  def test_kill_terminates_registered_matching_process
    pid = Process.spawn("sleep", "30")
    Process.detach(pid)
    key = File.join(@temp_dir, "sleep.pid")
    @service.register_process("redis", key, ["sleep"], pid: pid)

    out, = capture_io { Malt::ServiceManager.send(:kill_services) }

    assert_includes out, "Forcibly terminating Redis (pid #{pid})"
    refute @service.pid_running?(pid), "expected sleep process to be killed"
    assert_empty Malt::BaseService.registry_entries
  ensure
    Process.kill("KILL", pid) rescue nil
  end

  def test_kill_leaves_process_alive_when_command_does_not_match
    pid = Process.spawn("sleep", "30")
    Process.detach(pid)
    key = File.join(@temp_dir, "fake-mysql.pid")
    @service.register_process("mysql", key, ["mysqld"], pid: pid)

    _, err = capture_io { Malt::ServiceManager.send(:kill_services) }

    assert @service.pid_running?(pid), "foreign process must not be killed"
    assert_includes err, "does not match the expected process"
    assert_empty Malt::BaseService.registry_entries
  ensure
    Process.kill("KILL", pid) rescue nil
  end

  def test_registry_entries_ignores_entry_without_pattern
    pid = Process.spawn("sleep", "30")
    Process.detach(pid)
    FileUtils.mkdir_p(@registry_dir)
    File.write(File.join(@registry_dir, "malformed.json"), JSON.generate({ "service" => "redis", "pid" => pid }))

    assert_empty Malt::BaseService.registry_entries
  ensure
    Process.kill("KILL", pid) rescue nil
  end

  def test_kill_prunes_stale_entries_and_reports_nothing_running
    key = File.join(@temp_dir, "stale.pid")
    @service.register_process("redis", key, ["sleep"], pid: 2_147_483_000)

    out, = capture_io { Malt::ServiceManager.send(:kill_services) }

    assert_includes out, "No running instances of supported services were found."
    assert_empty Malt::BaseService.registry_entries
  end

  def test_status_reports_external_process_when_port_occupied_by_foreign_process
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    write_ports("redis" => [port])

    config = Malt::Config.new(File.join(@temp_dir, "malt.json"))
    out, = capture_io { Malt::ServiceManager.send(:show_status, config) }

    assert_includes out, "Redis (port #{port}): external process on port"
  ensure
    server.close
  end

  def test_status_reports_stopped_when_port_free_and_no_pid_file
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close
    write_ports("redis" => [port])

    config = Malt::Config.new(File.join(@temp_dir, "malt.json"))
    out, = capture_io { Malt::ServiceManager.send(:show_status, config) }

    assert_includes out, "Redis (port #{port}): stopped"
  end

  def test_status_reports_running_when_service_confirms_malt_process
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    write_ports("redis" => [port])

    fake = Object.new
    def fake.running?(_config, _port, _index = nil)
      true
    end

    config = Malt::Config.new(File.join(@temp_dir, "malt.json"))
    out, = Malt::RedisService.stub(:new, fake) do
      capture_io { Malt::ServiceManager.send(:show_status, config) }.first
    end

    assert_includes out, "Redis (port #{port}): running"
  ensure
    server.close
  end

  def test_start_returns_false_and_reports_failure_when_port_in_use
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    write_ports("php" => [port])

    _, err = capture_io do
      result = Malt::ServiceManager.start(config: File.join(@temp_dir, "malt.json"))
      assert_equal false, result
    end

    assert_includes err, "Failed to start: PHP-FPM"
  ensure
    server.close
  end

  def test_service_start_returns_false_when_port_in_use
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]

    assert_equal false, Malt::PhpService.new.start(config_with_ports("php" => [port]))
    assert_equal false, Malt::RedisService.new.start(config_with_ports("redis" => [port]))
    assert_equal false, Malt::MemcachedService.new.start(config_with_ports("memcached" => [port]))
  ensure
    server.close
  end

  def test_display_web_server_urls_skips_external_process
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    write_ports("httpd" => [port])

    config = Malt::Config.new(File.join(@temp_dir, "malt.json"))
    out, = capture_io { Malt::ServiceManager.send(:display_web_server_urls, config) }

    refute_includes out, "Access your site at"
  ensure
    server.close
  end

  private

  def write_ports(ports)
    File.write(File.join(@temp_dir, "malt.json"), JSON.generate({
      "project_name" => "test_project",
      "dependencies" => ["php@8.4"],
      "ports" => ports,
      "php_extensions" => []
    }))
  end

  def config_with_ports(ports)
    write_ports(ports)
    Malt::Config.new(File.join(@temp_dir, "malt.json"))
  end
end
