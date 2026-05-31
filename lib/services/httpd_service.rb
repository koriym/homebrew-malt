# frozen_string_literal: true

require_relative "base_service"

module Malt
  # Apache HTTPD service class
  class HttpdService < BaseService
    def start(config)
      config.ports["httpd"].each do |port|
        start_httpd(config, port)
      end
    end

    def stop(config)
      config.ports["httpd"].each do |port|
        stop_httpd(config, port)
      end
    end

    private

    def start_httpd(config, port)
      FileUtils.mkdir_p(config.var_dir)
      pid_file = httpd_pid_file(config, port)
      if pid_running_from_file?(pid_file, expected_pattern: httpd_temp_config_path(config, port))
        puts "[Running] Apache HTTPD on port #{port}"
        return
      elsif File.exist?(pid_file)
        remove_stale_pid_file(pid_file)
      end

      # Check if port is already in use
      if port_in_use?(port)
        puts "Error: Port #{port} is already in use by another process"
        return
      end

      puts "Starting Apache HTTPD on port #{port}..."

      httpd_conf = File.join(config.conf_dir, "httpd_#{port}.conf")

      # Create temp file with variable expansion
      temp_conf = create_temp_config(config, httpd_conf)

      # Abort if temp config creation failed
      if temp_conf.nil?
        puts "Error: Failed to create temporary config file for Apache HTTPD on port #{port}"
        return
      end

      # Verify temp file exists
      unless File.exist?(temp_conf)
        puts "Error: Apache HTTPD config temp file not found at: #{temp_conf}"
        return
      end

      # Start with temporary config
      httpd = File.join(HOMEBREW_PREFIX, "bin", "httpd")
      puts "Running command: #{httpd} -f #{temp_conf}"
      begin
        pid = Process.spawn(httpd, "-f", temp_conf)
        Process.detach(pid)
      rescue SystemCallError => e
        puts "Error: Failed to start Apache HTTPD on port #{port}"
        puts e.message if ENV["MALT_DEBUG"]
        return
      end
      puts "Apache HTTPD starting in background..."
    end

    def stop_httpd(config, port)
      pid_file = httpd_pid_file(config, port)
      unless File.exist?(pid_file)
        if port_in_use?(port)
          warn "Warning: Apache HTTPD appears to be running on port #{port}, but no Malt pid file was found. Leaving it untouched."
        else
          puts "[Stopped] Apache HTTPD is not running on port #{port}"
        end
        cleanup_httpd_temp(config, port)
        return false
      end

      pid = read_pid_file(pid_file)
      unless pid && pid_running?(pid)
        puts "[Stopped] Apache HTTPD is not running on port #{port}"
        remove_stale_pid_file(pid_file)
        cleanup_httpd_temp(config, port)
        return false
      end

      puts "Stopping Apache HTTPD on port #{port}..."

      httpd_conf_tmp = httpd_temp_config(config, port)
      return stop_pid_file(pid_file, "Apache HTTPD on port #{port}", expected_pattern: httpd_temp_config_path(config, port)) if httpd_conf_tmp.nil?

      # Use apachectl to stop Apache (redirect output)
      apachectl = File.join(HOMEBREW_PREFIX, "bin", "apachectl")
      puts "Running command: #{apachectl} -f #{httpd_conf_tmp} -k stop" if ENV["MALT_DEBUG"]

      # Execute stop command
      system(apachectl, "-f", httpd_conf_tmp, "-k", "stop", out: File::NULL, err: File::NULL)
      wait_for_pid_stop(pid, timeout: 10)

      stopped = !pid_running?(pid)
      if stopped
        puts "Apache HTTPD stopped."
      else
        warn "Warning: Apache HTTPD did not stop cleanly, falling back to pid termination..."
        stopped = stop_pid_file(pid_file, "Apache HTTPD on port #{port}", expected_pattern: httpd_conf_tmp)
      end

      remove_stale_pid_file(pid_file) if stopped
      cleanup_httpd_temp(config, port) if stopped || !File.exist?(pid_file)
      stopped
    end

    def httpd_pid_file(config, port)
      File.join(config.var_dir, "httpd_#{port}.pid")
    end

    def httpd_temp_config_path(config, port)
      File.join(config.conf_dir, "httpd_#{port}.conf.tmp")
    end

    def httpd_temp_config(config, port)
      httpd_conf_tmp = httpd_temp_config_path(config, port)
      return httpd_conf_tmp if File.exist?(httpd_conf_tmp)

      puts "Temporary config file not found, creating one for stop operation..." if ENV["MALT_DEBUG"]
      create_temp_config(config, File.join(config.conf_dir, "httpd_#{port}.conf"))
    end

    def cleanup_httpd_temp(config, port)
      return if ENV["MALT_DEBUG"]

      remove_temp_config(httpd_temp_config_path(config, port))
    end
  end
end
