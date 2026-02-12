# frozen_string_literal: true

require_relative "base_service"

module Malt
  # PHP-FPM service class
  class PhpService < BaseService
    def start(config)
      config.ports["php"].each do |port|
        start_php_fpm(config, port)
      end
    end

    def stop(config)
      stop_php_fpm
    end

    private

    def start_php_fpm(config, port)
      # Check if port is already in use
      if port_in_use?(port)
        puts "[Running] PHP-FPM on port #{port}"
        return
      end

      puts "Starting PHP-FPM on port #{port}..."

      # Configuration file paths
      php_fpm_conf = File.join(config.conf_dir, "php-fpm_#{port}.conf")
      php_ini = File.join(config.conf_dir, "php.ini")

      # Verify config file exists
      unless File.exist?(php_fpm_conf)
        puts "PHP-FPM configuration file not found at: #{php_fpm_conf}"
        return
      end

      # Create temporary config files with variable expansion
      temp_conf = create_temp_config(config, php_fpm_conf)
      temp_ini = create_temp_config(config, php_ini)

      # Error if temporary file creation failed
      if temp_conf.nil?
        puts "Error: Failed to create temporary config file for PHP-FPM"
        return
      end

      if temp_ini.nil?
        puts "Error: Failed to create temporary config file for PHP.ini"
        return
      end

      puts "Using PHP-FPM config file: #{temp_conf}"
      puts "Using PHP.ini file: #{temp_ini}"

      # Start using temporary files
      cmd = "#{HOMEBREW_PREFIX}/opt/php@#{config.php_version}/sbin/php-fpm -y #{temp_conf} -c #{temp_ini}"
      system("#{cmd} &")
    end

    def stop_php_fpm
      if system("pgrep -f php-fpm >/dev/null 2>&1")
        puts "Stopping PHP-FPM..."
        system("pkill -f php-fpm")
        wait_for_process_stop("php-fpm")

        # Clean up temporary files
        if Dir.exist?(File.join(Dir.pwd, "malt", "conf"))
          Dir.glob(File.join(Dir.pwd, "malt", "conf", "php-fpm_*.conf.tmp")).each do |tmp_file|
            puts "Cleaning up temporary file: #{tmp_file}" if ENV["MALT_DEBUG"]
            FileUtils.rm(tmp_file) if File.exist?(tmp_file) && !ENV["MALT_DEBUG"]
          end

          # Clean up php.ini temporary file
          php_ini_tmp = File.join(Dir.pwd, "malt", "conf", "php.ini.tmp")
          if File.exist?(php_ini_tmp)
            puts "Cleaning up temporary file: #{php_ini_tmp}" if ENV["MALT_DEBUG"]
            FileUtils.rm(php_ini_tmp) unless ENV["MALT_DEBUG"]
          end
        end
      else
        puts "[Stopped] PHP-FPM is not running"
      end
    end
  end
end
