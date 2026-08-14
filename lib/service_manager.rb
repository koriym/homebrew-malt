# frozen_string_literal: true

require_relative "services/base_service"
require_relative "services/php_service"
require_relative "services/mysql_service"
require_relative "services/redis_service"
require_relative "services/memcached_service"
require_relative "services/nginx_service"
require_relative "services/httpd_service"

module Malt
  # Service manager orchestrates starting, stopping, and killing services
  class ServiceManager
    def self.start(options)
      config_path = find_config_in_current_dir(options)
      config = Malt::Config.new(config_path)

      ensure_malt_dir_exists(config)
      start_services(config)
    end
    def self.stop(options)
      config_path = find_config_in_current_dir(options)
      config = Malt::Config.new(config_path)

      stop_services(config)
    end

    def self.kill(options)
      # Directly kill services without checking malt.json
      kill_services
    end

    def self.status(options)
      config_path = find_config_in_current_dir(options)
      config = Malt::Config.new(config_path)

      show_status(config)
    end

    class << self
      private

      def find_config_in_current_dir(options)
        return options[:config] if options[:config] && File.exist?(options[:config])

        config_path = File.join(Dir.pwd, "malt.json")
        return config_path if File.exist?(config_path)

        raise "malt.json not found in current directory. Run 'malt init' to create one."
      end

      def ensure_malt_dir_exists(config)
        return if Dir.exist?(config.malt_dir)

        raise "Malt directory '#{config.malt_dir}' not found. Run 'malt create' first to generate configuration files."
      end

      def start_services(config)
        puts "Starting services for #{config.project_name}..."

        # Clean up old temporary config files before starting
        cleanup_old_temp_files(config)

        # Register services
        services = register_services(config)

        # Start each service
        failed = services.reject { |service| service.start(config) }

        unless failed.empty?
          warn "Error: Failed to start: #{failed.map { |s| service_display_name(s) }.join(', ')}"
          return false
        end

        puts "Services started."
        puts "Run 'source <(malt env)' to set up your shell environment."

        # Display web server access URLs
        display_web_server_urls(config)

        puts "See https://koriym.github.io/homebrew-malt/"
        true
      end

      def service_display_name(service)
        key = SERVICE_CLASSES.key(service.class)
        key ? SERVICES[key][0] : service.class.name
      end

      def display_web_server_urls(config)
        web_servers = []
        if config.has_service?("httpd")
          service = HttpdService.new
          config.ports["httpd"].each do |port|
            web_servers << "http://127.0.0.1:#{port}/" if service.running?(config, port)
          end
        end
        if config.has_service?("nginx")
          service = NginxService.new
          config.ports["nginx"].each do |port|
            web_servers << "http://127.0.0.1:#{port}/" if service.running?(config, port)
          end
        end

        return if web_servers.empty?

        puts "Access your site at:"
        web_servers.each do |url|
          puts "  - #{url}"
        end
      end

      def port_in_use?(port)
        Malt::BaseService.port_in_use?(port)
      end

      def stop_services(config)
        puts "Stopping services for #{config.project_name}..."

        # Register services (stop in reverse order)
        services = register_services(config).reverse

        # Stop each service
        services.each do |service|
          service.stop(config)
        end
      end

      # Single source of truth: config_key => [display_name, process_pattern]
      SERVICES = {
        "php" => ["PHP-FPM", "php-fpm"],
        "mysql" => ["MySQL", "mysqld"],
        "redis" => ["Redis", "redis-server"],
        "memcached" => ["Memcached", "memcached"],
        "nginx" => ["Nginx", "nginx"],
        "httpd" => ["Apache HTTPD", "httpd"],
      }.freeze

      # config_key => service class, in startup order
      SERVICE_CLASSES = {
        "php" => PhpService,
        "mysql" => MysqlService,
        "redis" => RedisService,
        "memcached" => MemcachedService,
        "nginx" => NginxService,
        "httpd" => HttpdService,
      }.freeze

      def show_status(config)
        puts "Service status for #{config.project_name}:"
        puts ""

        SERVICE_CLASSES.each do |key, klass|
          next unless config.has_service?(key)

          name = SERVICES[key][0]
          service = klass.new
          config.ports[key].each_with_index do |port, index|
            status =
              if service.running?(config, port, index)
                "running"
              elsif port_in_use?(port)
                "external process on port"
              else
                "stopped"
              end
            puts "  #{name} (port #{port}): #{status}"
          end
        end
      end

      # Forcibly terminate only processes recorded in the Malt pid registry.
      # Each pid's identity is verified against the pattern stored at start
      # time before sending SIGKILL, so foreign processes (e.g. Homebrew
      # services) are never touched. Stale entries are pruned.
      def kill_services
        helper = Malt::BaseService.new
        entries = Malt::BaseService.registry_entries

        # Keep only entries whose process is still running; prune the rest
        running = entries.select { |entry| registry_entry_alive?(entry, helper) }

        # Kill supervisors (entries with a direct pid, e.g. mysqld_safe)
        # before the processes they supervise so they cannot restart them
        running.sort_by! { |entry| entry["pid"] ? 0 : 1 }

        if running.empty?
          puts "No running instances of supported services were found."
          return
        end

        puts "About to forcibly terminate the following malt-managed services:"
        running.each do |entry|
          puts "- #{registry_entry_name(entry)} (pid #{registry_entry_pid(entry, helper)})"
        end
        puts "(Only processes started by malt are terminated; other instances are left untouched)"

        any_killed = running.map { |entry| kill_registry_entry(entry, helper) }.any?
        puts "Forcible termination of services completed." if any_killed
      end

      def registry_entry_alive?(entry, helper)
        pid = registry_entry_pid(entry, helper)
        alive = pid && helper.pid_running?(pid)
        FileUtils.rm_f(entry["_path"]) unless alive
        !!alive
      end

      def registry_entry_pid(entry, helper)
        return entry["pid"] if entry["pid"]

        helper.read_pid_file(entry["pid_file"])
      end

      def registry_entry_name(entry)
        SERVICES.dig(entry["service"], 0) || entry["service"].to_s
      end

      def kill_registry_entry(entry, helper)
        name = registry_entry_name(entry)
        pid = registry_entry_pid(entry, helper)

        unless pid && helper.pid_matches?(pid, entry["pattern"])
          warn "Warning: #{name} pid #{pid || 'unknown'} does not match the expected process. Leaving it untouched."
          FileUtils.rm_f(entry["_path"])
          return false
        end

        puts "Forcibly terminating #{name} (pid #{pid})..."
        Process.kill("KILL", pid)
        helper.wait_for_pid_stop(pid, timeout: 5)

        if helper.pid_running?(pid)
          warn "Warning: Failed to forcibly terminate #{name}"
          return false
        end

        FileUtils.rm_f(entry["_path"])
        true
      rescue Errno::ESRCH
        FileUtils.rm_f(entry["_path"])
        true
      rescue Errno::EPERM => e
        warn "Warning: Failed to terminate #{name}: #{e.message}"
        false
      end

      # Clean up old temporary config files to prevent .tmp.tmp accumulation
      # Only removes known malt config patterns: *.conf.tmp, *.ini.tmp, *.cnf.tmp
      def cleanup_old_temp_files(config)
        return unless config.conf_dir && Dir.exist?(config.conf_dir)

        # Match only malt-managed temp config files
        patterns = ["*.conf.tmp", "*.ini.tmp", "*.cnf.tmp"]
        patterns.each do |pattern|
          Dir.glob(File.join(config.conf_dir, pattern)).each do |tmp_file|
            File.delete(tmp_file)
            puts "Cleaned up old temp file: #{tmp_file}" if ENV["MALT_DEBUG"]
          rescue StandardError => e
            puts "Warning: Failed to delete #{tmp_file}: #{e.message}" if ENV["MALT_DEBUG"]
          end
        end
      end

      def register_services(config)
        SERVICE_CLASSES.filter_map { |key, klass| klass.new if config.has_service?(key) }
      end
    end
  end
end
