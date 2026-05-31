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
        services.each do |service|
          service.start(config)
        end
        puts "Services started."
        puts "Run 'source <(malt env)' to set up your shell environment."

        # Display web server access URLs
        display_web_server_urls(config)

        puts "See https://koriym.github.io/homebrew-malt/"
      end

      def display_web_server_urls(config)
        web_servers = []
        if config.has_service?("httpd")
          config.ports["httpd"].each do |port|
            web_servers << "http://127.0.0.1:#{port}/" if port_in_use?(port)
          end
        end
        if config.has_service?("nginx")
          config.ports["nginx"].each do |port|
            web_servers << "http://127.0.0.1:#{port}/" if port_in_use?(port)
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

      def show_status(config)
        puts "Service status for #{config.project_name}:"
        puts ""

        SERVICES.each do |key, (name, _)|
          next unless config.has_service?(key)

          config.ports[key].each do |port|
            status = port_in_use?(port) ? "running" : "stopped"
            puts "  #{name} (port #{port}): #{status}"
          end
        end
      end

      def kill_services
        running = SERVICES.values.select { |_, pattern| process_running?(pattern) }

        if running.empty?
          puts "No running instances of supported services were found."
          return
        end

        puts "About to forcibly terminate the following running services:"
        running.each { |name, _| puts "- #{name}" }
        puts "(This command affects all instances, regardless of malt.json configuration)"

        any_killed = running.map { |name, pattern| kill_service(pattern, name) }.any?
        puts "Forcible termination of services completed." if any_killed
      end

      def process_running?(pattern)
        system("pgrep", "-f", pattern, out: File::NULL, err: File::NULL)
      end

      def kill_service(pattern, name)
        return false unless process_running?(pattern)

        puts "Forcibly terminating #{name}..."
        system("pkill", "-9", "-f", pattern)
        sleep 0.5

        # Retry if still running
        if process_running?(pattern)
          warn "Warning: #{name} processes still running despite SIGKILL, retrying..."
          system("pkill", "-9", "-f", pattern)
          sleep 0.5
        end

        still_running = process_running?(pattern)
        warn "Warning: Failed to forcibly terminate #{name}" if still_running
        !still_running
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
        services = []

        # PHP-FPM
        services << PhpService.new if config.has_service?("php")

        # MySQL
        services << MysqlService.new if config.has_service?("mysql")

        # Redis
        services << RedisService.new if config.has_service?("redis")

        # Memcached
        services << MemcachedService.new if config.has_service?("memcached")

        # Nginx
        services << NginxService.new if config.has_service?("nginx")

        # Apache
        services << HttpdService.new if config.has_service?("httpd")

        services
      end
    end
  end
end
