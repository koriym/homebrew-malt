# frozen_string_literal: true

require_relative "base_service"

module Malt
  # MySQL service class
  class MysqlService < BaseService
    def start(config)
      config.ports["mysql"].each_with_index do |port, index|
        start_mysql(config, port, index)
      end
    end

    def stop(config)
      any_mysql_stopped = false

      config.ports["mysql"].each_with_index do |port, index|
        any_mysql_stopped = true if stop_mysql(config, port, index)
      end

      # Only wait briefly if MySQL was actually stopped
      if any_mysql_stopped
        puts "Finalizing MySQL shutdown..."
        sleep 0.5
      end
    end

    private

    def start_mysql(config, port, index)
      pid_file = mysql_pid_file(config, index)
      if pid_running_from_file?(pid_file, expected_pattern: mysql_identity_pattern(config, index))
        puts "[Running] MySQL on port #{port}"
        return
      elsif File.exist?(pid_file)
        remove_stale_pid_file(pid_file)
      end

      # Check if port is already in use
      if port_in_use?(port)
        puts "Error: Port #{port} is already in use by another process"
        return
      end

      puts "Starting MySQL on port #{port}..."

      my_cnf = File.join(config.conf_dir, "my_#{port}.cnf")

      # Add INDEX variable and call create_temp_config
      temp_conf = create_temp_config_with_extras(config, my_cnf, { "INDEX" => index.to_s })

      # Abort if temp config creation failed
      if temp_conf.nil?
        puts "Error: Failed to create temporary config file for MySQL on port #{port}"
        return
      end

      puts "MySQL config path: #{temp_conf}"
      puts "Config exists: #{File.exist?(temp_conf)}"

      # Create MySQL data directory
      data_dir = File.join(config.var_dir, "mysql_#{index}")
      unless File.directory?(data_dir)
        puts "Creating MySQL data directory: #{data_dir}"
        FileUtils.mkdir_p(data_dir)
      end

      log_file = File.join(config.logs_dir, "mysql_#{port}_error.log")
      puts "MySQL error log: #{log_file}"

      # Initialize MySQL if needed
      if !File.exist?(File.join(data_dir, "mysql")) || Dir.glob(File.join(data_dir, "*")).empty?
        puts "Initializing MySQL data directory at #{data_dir}..."
        mysqld = File.join(HOMEBREW_PREFIX, "opt", "mysql@#{config.mysql_version}", "bin", "mysqld")
        unless system(mysqld, "--initialize-insecure", "--datadir=#{data_dir}")
          puts "Error: MySQL initialization failed"
          return
        end
        puts "MySQL initialization complete."
      end

      # Verify temp file exists
      unless File.exist?(temp_conf)
        puts "Error: MySQL config temp file not found at: #{temp_conf}"
        return
      end

      # Start MySQL in background
      mysqld_safe = File.join(HOMEBREW_PREFIX, "opt", "mysql@#{config.mysql_version}", "bin", "mysqld_safe")
      pid = Process.spawn(mysqld_safe, "--defaults-file=#{temp_conf}", out: [log_file, "a"], err: [:child, :out])
      Process.detach(pid)
      puts "MySQL starting in background..."
    rescue SystemCallError => e
      puts "Error: Failed to start MySQL on port #{port}: #{e.message}"
    end

    def stop_mysql(config, port, index)
      pid_file = mysql_pid_file(config, index)
      unless File.exist?(pid_file)
        if port_in_use?(port)
          warn "Warning: MySQL appears to be running on port #{port}, but no Malt pid file was found. Leaving it untouched."
        else
          puts "[Stopped] MySQL is not running on port #{port}"
        end
        cleanup_mysql_temp(config, port)
        return false
      end

      pid = read_pid_file(pid_file)
      unless pid && pid_running?(pid)
        puts "[Stopped] MySQL is not running on port #{port}"
        remove_stale_pid_file(pid_file)
        cleanup_mysql_temp(config, port)
        return false
      end

      puts "Stopping MySQL on port #{port}..."
      temp_conf = mysql_temp_config(config, port, index)
      return stop_pid_file(pid_file, "MySQL on port #{port}", expected_pattern: mysql_identity_pattern(config, index)) if temp_conf.nil?

      log_file = File.join(config.logs_dir, "mysql_#{port}_error.log")
      mysqladmin = File.join(HOMEBREW_PREFIX, "opt", "mysql@#{config.mysql_version}", "bin", "mysqladmin")
      shutdown_sent = system(mysqladmin, "--defaults-file=#{temp_conf}", "-uroot", "shutdown", out: [log_file, "a"], err: [:child, :out])
      if shutdown_sent
        wait_for_pid_stop(pid, timeout: 10)
      else
        warn "Warning: Failed to request MySQL shutdown on port #{port}; falling back to pid termination..."
      end

      stopped = !pid_running?(pid)
      unless stopped
        warn "Warning: MySQL did not stop cleanly, falling back to pid termination..."
        stopped = stop_pid_file(pid_file, "MySQL on port #{port}", expected_pattern: mysql_identity_pattern(config, index))
      end

      remove_stale_pid_file(pid_file) if stopped
      cleanup_mysql_temp(config, port) if stopped || !File.exist?(pid_file)
      stopped
    end

    def mysql_pid_file(config, index)
      File.join(config.var_dir, "mysql_#{index}", "mysqld.pid")
    end

    def mysql_identity_pattern(config, index)
      File.join(config.var_dir, "mysql_#{index}")
    end

    def mysql_temp_config(config, port, index)
      my_cnf = File.join(config.conf_dir, "my_#{port}.cnf")
      temp_conf = "#{my_cnf}.tmp"
      return temp_conf if File.exist?(temp_conf)

      create_temp_config_with_extras(config, my_cnf, { "INDEX" => index.to_s })
    end

    def cleanup_mysql_temp(config, port)
      return if ENV["MALT_DEBUG"]

      remove_temp_config(File.join(config.conf_dir, "my_#{port}.cnf.tmp"))
    end
  end
end
