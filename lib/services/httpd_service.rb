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
      # Check if port is already in use
      if port_in_use?(port)
        puts "[Running] Apache HTTPD on port #{port}"
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
      # First check if port is in use (service is running)
      unless port_in_use?(port)
        puts "[Stopped] Apache HTTPD is not running on port #{port}"

        # Clean up temp file
        httpd_conf_tmp = File.join(config.malt_dir, "conf", "httpd_#{port}.conf.tmp")
        if !ENV["MALT_DEBUG"] && File.exist?(httpd_conf_tmp)
          remove_temp_config(httpd_conf_tmp)
        end

        return # Service is not running, exit here
      end

      puts "Stopping Apache HTTPD on port #{port}..."

      # Paths for temp config file
      httpd_conf_tmp = File.join(config.malt_dir, "conf", "httpd_#{port}.conf.tmp")
      original_conf = File.join(config.conf_dir, "httpd_#{port}.conf")

      # Create temp file if it doesn't exist (need variable-substituted file)
      unless File.exist?(httpd_conf_tmp)
        puts "Temporary config file not found, creating one for stop operation..." if ENV["MALT_DEBUG"]
        temp_conf = create_temp_config(config, original_conf)
        if temp_conf.nil?
          puts "Warning: Could not create temporary config file for stopping Apache"
          # Try alternative stop method
          system("pkill", "-f", "httpd.*#{port}")
          return
        end
        httpd_conf_tmp = temp_conf
      end

      # Use apachectl to stop Apache (redirect output)
      apachectl = File.join(HOMEBREW_PREFIX, "bin", "apachectl")
      puts "Running command: #{apachectl} -f #{httpd_conf_tmp} -k stop" if ENV["MALT_DEBUG"]

      # Execute stop command
      system(apachectl, "-f", httpd_conf_tmp, "-k", "stop", out: File::NULL, err: File::NULL)

      if port_in_use?(port)
        puts "Stopping Apache HTTPD on port #{port}..."

        # Add short wait for stop to be processed
        sleep 0.5

        # Check if port was released
        if port_in_use?(port)
          puts "Warning: Apache might still be running, attempting fallback..."
          system("pkill", "-f", "httpd.*#{port}", out: File::NULL, err: File::NULL)
        else
          puts "Apache HTTPD stopped successfully."
        end
      else
        puts "Apache HTTPD stopped."
      end

      # Clean up temp file
      if !ENV["MALT_DEBUG"] && File.exist?(httpd_conf_tmp)
        remove_temp_config(httpd_conf_tmp)
      end
    end
  end
end
