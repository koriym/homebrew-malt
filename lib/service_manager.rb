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

    class << self
      private

      def find_config_in_current_dir(options)
        return options[:config] if options[:config] && File.exist?(options[:config])

        config_path = File.join(Dir.pwd, "malt.json")
        return config_path if File.exist?(config_path)

        raise "malt.json not found in current directory. Run 'malt init' to create one."
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
            web_servers << "http://127.0.0.1:#{port}/" if is_port_in_use(port)
          end
        end
        if config.has_service?("nginx")
          config.ports["nginx"].each do |port|
            web_servers << "http://127.0.0.1:#{port}/" if is_port_in_use(port)
          end
        end

        return if web_servers.empty?

        puts "Access your site at:"
        web_servers.each do |url|
          puts "  - #{url}"
        end
      end

      # Port in use check for ServiceManager class method
      def is_port_in_use(port)
        # Use different commands for macOS and Linux
        if RUBY_PLATFORM =~ /darwin/
          system("lsof -i :#{port} -sTCP:LISTEN >/dev/null 2>&1")
        else
          system("netstat -tuln | grep :#{port} >/dev/null 2>&1")
        end
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

      def kill_services
        # First check if any supported services are running
        any_running = false
        any_running ||= system("pgrep -f php-fpm >/dev/null 2>&1")
        any_running ||= system("pgrep -f 'mysqld' >/dev/null 2>&1")
        any_running ||= system("pgrep -f redis-server >/dev/null 2>&1")
        any_running ||= system("pgrep -f memcached >/dev/null 2>&1")
        any_running ||= system("pgrep -f nginx >/dev/null 2>&1")
        any_running ||= system("pgrep -f httpd >/dev/null 2>&1")

        # If no services are running, exit early
        unless any_running
          puts "No running instances of supported services were found."
          return
        end

        # Display message about what will be terminated
        puts "About to forcibly terminate the following running services:"
        puts "- PHP-FPM" if system("pgrep -f php-fpm >/dev/null 2>&1")
        puts "- MySQL" if system("pgrep -f 'mysqld' >/dev/null 2>&1")
        puts "- Redis" if system("pgrep -f redis-server >/dev/null 2>&1")
        puts "- Memcached" if system("pgrep -f memcached >/dev/null 2>&1")
        puts "- Nginx" if system("pgrep -f nginx >/dev/null 2>&1")
        puts "- Apache HTTPD" if system("pgrep -f httpd >/dev/null 2>&1")
        puts "(This command affects all instances, regardless of malt.json configuration)"

        # Proceed with termination
        any_service_killed = false

        any_service_killed |= kill_php_fpm
        any_service_killed |= kill_mysql
        any_service_killed |= kill_redis
        any_service_killed |= kill_memcached
        any_service_killed |= kill_nginx
        any_service_killed |= kill_apache

        puts "Forcible termination of services completed." if any_service_killed
      end

      def kill_php_fpm
        return false unless system("pgrep -f php-fpm >/dev/null 2>&1")

        puts "Forcibly terminating PHP-FPM..."
        if system("pkill -9 -f php-fpm")
          true
        else
          puts "Warning: Failed to forcibly terminate PHP-FPM"
          false
        end
      end

      def kill_mysql
        return false unless system("pgrep -f 'mysqld' >/dev/null 2>&1")

        puts "Forcibly terminating MySQL..."
        puts "Using immediate termination for MySQL (SIGKILL)..."
        success = system("pkill -9 -f 'mysqld'")
        puts "SIGKILL to MySQL processes #{success ? 'sent' : 'failed'}"

        # Wait a moment for processes to terminate
        sleep 0.5

        # Double check if processes are gone
        if system("pgrep -f 'mysqld' >/dev/null 2>&1")
          puts "Warning: MySQL processes still running despite SIGKILL"
          system("pkill -9 -f 'mysqld'")
          sleep 0.5
          success = !system("pgrep -f 'mysqld' >/dev/null 2>&1")
        end

        puts "MySQL forceful termination #{success ? 'successful' : 'failed'}"
        success
      end

      def kill_redis
        return false unless system("pgrep -f redis-server >/dev/null 2>&1")

        puts "Forcibly terminating Redis..."
        puts "Using immediate termination for Redis (SIGKILL)..."
        success = system("pkill -9 -f redis-server")
        puts "SIGKILL to Redis processes #{success ? 'sent' : 'failed'}"

        # Wait a moment for processes to terminate
        sleep 0.5

        # Double check if processes are gone
        if system("pgrep -f redis-server >/dev/null 2>&1")
          puts "Warning: Redis processes still running despite SIGKILL"
          system("pkill -9 -f redis-server")
          sleep 0.5
          success = !system("pgrep -f redis-server >/dev/null 2>&1")
        else
          puts "Redis forceful termination successful"
        end

        success
      end

      def kill_memcached
        return false unless system("pgrep -f memcached >/dev/null 2>&1")

        puts "Forcibly terminating Memcached..."
        if system("pkill -9 -f memcached")
          sleep 0.5
          if system("pgrep -f memcached >/dev/null 2>&1")
            puts "Warning: Memcached processes still running despite SIGKILL"
            system("pkill -9 -f memcached")
            sleep 0.5
            !system("pgrep -f memcached >/dev/null 2>&1")
          else
            true
          end
        else
          puts "Warning: Failed to forcibly terminate Memcached"
          false
        end
      end

      def kill_nginx
        return false unless system("pgrep -f nginx >/dev/null 2>&1")

        puts "Forcibly terminating Nginx..."
        puts "Using immediate termination for Nginx (SIGKILL)..."
        success = system("pkill -9 -f nginx")
        puts "SIGKILL to Nginx processes #{success ? 'sent' : 'failed'}"

        # Wait a moment for processes to terminate
        sleep 0.5

        # Double check if processes are gone
        if system("pgrep -f nginx >/dev/null 2>&1")
          puts "Warning: Nginx processes still running despite SIGKILL"
          system("pkill -9 -f nginx")
          sleep 0.5
          success = !system("pgrep -f nginx >/dev/null 2>&1")
        else
          puts "Nginx forceful termination successful"
        end

        success
      end

      def kill_apache
        return false unless system("pgrep -f httpd >/dev/null 2>&1")

        puts "Forcibly terminating Apache HTTPD..."
        if system("pkill -9 -f httpd")
          sleep 0.5
          if system("pgrep -f httpd >/dev/null 2>&1")
            puts "Warning: Apache processes still running despite SIGKILL"
            system("pkill -9 -f httpd")
            sleep 0.5
            !system("pgrep -f httpd >/dev/null 2>&1")
          else
            puts "Apache HTTPD forceful termination successful"
            true
          end
        else
          puts "Warning: Failed to forcibly terminate Apache HTTPD"
          false
        end
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
