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
      config.ports["php"].each do |port|
        stop_php_fpm(config, port)
      end
      cleanup_php_ini(config)
    end

    private

    def start_php_fpm(config, port)
      pid_file = File.join(config.var_dir, "php-fpm_#{port}.pid")
      if pid_running_from_file?(pid_file)
        puts "[Running] PHP-FPM on port #{port}"
        return
      end

      # Check if port is already in use
      if port_in_use?(port)
        puts "Error: Port #{port} is already in use by another process"
        return
      end

      puts "Starting PHP-FPM on port #{port}..."
      FileUtils.mkdir_p(config.var_dir)

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
      php_fpm_bin = File.join(HOMEBREW_PREFIX, "opt", "php@#{config.php_version}", "sbin", "php-fpm")
      pid = Process.spawn(php_fpm_bin, "-y", temp_conf, "-c", temp_ini)
      Process.detach(pid)
      File.write(pid_file, pid.to_s)
    rescue SystemCallError => e
      puts "Error: Failed to start PHP-FPM on port #{port}: #{e.message}"
    end

    def stop_php_fpm(config, port)
      pid_file = File.join(config.var_dir, "php-fpm_#{port}.pid")
      unless File.exist?(pid_file)
        if port_in_use?(port)
          warn "Warning: PHP-FPM appears to be running on port #{port}, but no Malt pid file was found. Leaving it untouched."
        else
          puts "[Stopped] PHP-FPM is not running on port #{port}"
        end
        cleanup_php_fpm_temp(config, port)
        return false
      end

      stopped = stop_pid_file(pid_file, "PHP-FPM on port #{port}")
      cleanup_php_fpm_temp(config, port) if stopped || !File.exist?(pid_file)
      stopped
    end

    def cleanup_php_fpm_temp(config, port)
      return if ENV["MALT_DEBUG"]

      remove_temp_config(File.join(config.conf_dir, "php-fpm_#{port}.conf.tmp"))
    end

    def cleanup_php_ini(config)
      return if ENV["MALT_DEBUG"]

      remove_temp_config(File.join(config.conf_dir, "php.ini.tmp"))
    end
  end
end
