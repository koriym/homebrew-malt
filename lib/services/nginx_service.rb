# frozen_string_literal: true

require_relative "base_service"

module Malt
  # Nginx service class
  class NginxService < BaseService
    def start(config)
      start_nginx(config)
    end

    def stop(config)
      stop_nginx(config)
    end

    private

    def start_nginx(config)
      # Nginx runs on multiple ports, check only the first port
      if config.ports["nginx"]&.first
        port = config.ports["nginx"].first
        if port_in_use?(port)
          puts "[Running] Nginx on port #{port}"
          return
        end
      end

      ports_str = config.ports["nginx"].join(", ")
      puts "Starting Nginx on ports #{ports_str}..."

      # First, expand variables in each port-specific config file
      port_temps = {}
      config.ports["nginx"].each do |port|
        nginx_port_conf = File.join(config.conf_dir, "nginx_#{port}.conf")
        if File.exist?(nginx_port_conf)
          temp_port_conf = create_temp_config(config, nginx_port_conf)
          if temp_port_conf.nil?
            puts "Failed to create temporary config file for port #{port}"
          else
            port_temps[port] = temp_port_conf
          end
        else
          puts "Nginx config file not found for port #{port}: #{nginx_port_conf}"
        end
      end

      # Load main config file
      nginx_conf = File.join(config.conf_dir, "nginx_main.conf")

      # Modify main config content to use temp file includes
      if File.exist?(nginx_conf)
        main_content = File.read(nginx_conf)

        # Replace each port config file reference with temp file
        port_temps.each do |port, temp_file|
          original_include = "include #{config.malt_dir}/conf/nginx_#{port}.conf;"
          temp_include = "include #{temp_file};"
          main_content = main_content.gsub(original_include, temp_include)
        end

        # Substitute template variables
        template_vars = {
          "MALT_DIR" => config.malt_dir,
          "PROJECT_DIR" => config.project_dir,
          "PHP_VERSION" => config.php_version,
          "HOMEBREW_PREFIX" => HOMEBREW_PREFIX
        }
        template_vars.each do |key, value|
          main_content = main_content.gsub("{{#{key}}}", value.to_s)
        end

        # Write to temporary file
        temp_conf = "#{nginx_conf}.tmp"
        File.write(temp_conf, main_content)
      else
        puts "Nginx main config file not found: #{nginx_conf}"
        temp_conf = nil
      end

      # Error if temp file creation failed
      if temp_conf.nil?
        puts "Error: Failed to create temporary config file for Nginx"
        return
      end

      # Start nginx with temporary config
      cmd = "nginx -c #{temp_conf}"
      puts "Running command: #{cmd}"
      puts "Error: Failed to start Nginx" unless system(cmd)
    end

    def stop_nginx(config)
      # Check if Nginx is running (by process presence)
      if system("pgrep -f nginx >/dev/null 2>&1")
        puts "Stopping Nginx..."

        # Stop Nginx server
        stop_success = system("#{HOMEBREW_PREFIX}/bin/nginx -s stop")

        # Delete related temp config files
        if stop_success && !ENV["MALT_DEBUG"]
          # Main config file
          nginx_conf_tmp = File.join(config.conf_dir, "nginx_main.conf.tmp")
          remove_temp_config(nginx_conf_tmp) if File.exist?(nginx_conf_tmp)

          # Port-specific config files
          Dir.glob(File.join(config.conf_dir, "nginx_*.conf.tmp")).each do |tmp_file|
            remove_temp_config(tmp_file)
          end
        end
      else
        puts "[Stopped] Nginx is not running"
      end
    end
  end
end
