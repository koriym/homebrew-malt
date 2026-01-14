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

      config.ports["mysql"].each do |port|
        any_mysql_stopped = true if stop_mysql(config, port)
      end

      # Only wait briefly if MySQL was actually stopped
      if any_mysql_stopped
        puts "Finalizing MySQL shutdown..."
        sleep 0.5
      end
    end

    private

    def start_mysql(config, port, index)
      # Check if port is already in use
      if port_in_use?(port)
        puts "[Running] MySQL on port #{port}"
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
        init_cmd = "#{HOMEBREW_PREFIX}/opt/mysql@8.0/bin/mysqld --initialize-insecure --datadir=#{data_dir}"
        unless system(init_cmd)
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
      cmd = "#{HOMEBREW_PREFIX}/opt/mysql@8.0/bin/mysqld_safe --defaults-file=#{temp_conf} > #{log_file} 2>&1 &"
      system(cmd)
      puts "MySQL starting in background..."
    end

    def stop_mysql(config, port)
      # Check if MySQL is running
      if port_in_use?(port)
        puts "Stopping MySQL on port #{port}..."

        my_cnf = File.join(config.conf_dir, "my_#{port}.cnf")
        temp_conf = "#{my_cnf}.tmp"

        # Use temp file if it exists
        config_file = File.exist?(temp_conf) ? temp_conf : my_cnf

        # Redirect output to log file
        log_file = File.join(config.logs_dir, "mysql_#{port}_error.log")
        cmd = "#{HOMEBREW_PREFIX}/opt/mysql@8.0/bin/mysqladmin --defaults-file=#{config_file} -uroot -h 127.0.0.1 --port #{port} shutdown > #{log_file} 2>&1"
        system(cmd)

        # Remove temp file unless in debug mode
        remove_temp_config(temp_conf) unless ENV["MALT_DEBUG"]

        true # MySQL was stopped
      else
        puts "[Stopped] MySQL is not running on port #{port}"
        false # MySQL was already stopped
      end
    end
  end
end
