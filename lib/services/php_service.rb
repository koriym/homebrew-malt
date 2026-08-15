# frozen_string_literal: true

require_relative "base_service"

module Malt
  # PHP-FPM service class
  class PhpService < BaseService
    def start(config)
      results = config.ports["php"].map { |port| start_php_fpm(config, port) }
      results.all?
    end

    # Check whether PHP-FPM on the given port is running under Malt management
    def running?(config, port, _index = nil)
      pid_file = File.join(config.var_dir, "php-fpm_#{port}.pid")
      pid_running_from_file?(pid_file, expected_pattern: php_fpm_temp_conf(config, port))
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
      if pid_running_from_file?(pid_file, expected_pattern: php_fpm_temp_conf(config, port))
        puts "[Running] PHP-FPM on port #{port}"
        register_process("php", pid_file, php_fpm_temp_conf(config, port), pid_file: pid_file)
        return true
      elsif File.exist?(pid_file)
        remove_stale_pid_file(pid_file)
      end

      # Check if port is already in use
      if port_in_use?(port)
        puts "Error: Port #{port} is already in use by another process"
        return false
      end

      puts "Starting PHP-FPM on port #{port}..."
      FileUtils.mkdir_p(config.var_dir)
      FileUtils.mkdir_p(config.logs_dir)

      # Configuration file paths
      php_fpm_conf = File.join(config.conf_dir, "php-fpm_#{port}.conf")
      php_ini = File.join(config.conf_dir, "php.ini")

      # Verify config file exists
      unless File.exist?(php_fpm_conf)
        puts "PHP-FPM configuration file not found at: #{php_fpm_conf}"
        return false
      end

      # Create temporary config files with variable expansion
      temp_conf = create_temp_config(config, php_fpm_conf)
      temp_ini = create_temp_config(config, php_ini)

      # Error if temporary file creation failed
      if temp_conf.nil?
        puts "Error: Failed to create temporary config file for PHP-FPM"
        return false
      end

      if temp_ini.nil?
        puts "Error: Failed to create temporary config file for PHP.ini"
        return false
      end

      puts "Using PHP-FPM config file: #{temp_conf}"
      puts "Using PHP.ini file: #{temp_ini}"

      # Start using temporary files (redirect output so daemons don't hold the caller's pipes open)
      php_fpm_bin = File.join(HOMEBREW_PREFIX, "opt", "php@#{config.php_version}", "sbin", "php-fpm")
      log_file = File.join(config.logs_dir, "php-fpm_#{port}.log")
      pid = nil
      pid = Process.spawn(php_fpm_bin, "-y", temp_conf, "-c", temp_ini, out: [log_file, "a"], err: [:child, :out])
      File.write(pid_file, pid.to_s)
      Process.detach(pid)
      register_process("php", pid_file, php_fpm_temp_conf(config, port), pid_file: pid_file)
      true
    rescue SystemCallError, StandardError => e
      terminate_pid(pid, "PHP-FPM on port #{port}") if pid
      puts "Error: Failed to start PHP-FPM on port #{port}: #{e.message}"
      false
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
        unregister_process(pid_file)
        return false
      end

      stopped = stop_pid_file(pid_file, "PHP-FPM on port #{port}", expected_pattern: php_fpm_temp_conf(config, port))
      cleanup_php_fpm_temp(config, port) if stopped || !File.exist?(pid_file)
      unregister_process(pid_file) if stopped
      stopped
    end

    def php_fpm_temp_conf(config, port)
      File.join(config.conf_dir, "php-fpm_#{port}.conf.tmp")
    end

    def cleanup_php_fpm_temp(config, port)
      return if ENV["MALT_DEBUG"]

      remove_temp_config(php_fpm_temp_conf(config, port))
    end

    def cleanup_php_ini(config)
      return if ENV["MALT_DEBUG"]

      remove_temp_config(File.join(config.conf_dir, "php.ini.tmp"))
    end
  end
end
