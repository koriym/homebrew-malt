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
      FileUtils.mkdir_p(config.var_dir)
      pid_file = nginx_pid_file(config)
      ports_str = config.ports["nginx"].join(", ")

      if pid_running_from_file?(pid_file, expected_pattern: nginx_temp_config(config))
        puts "[Running] Nginx on ports #{ports_str}"
        return
      elsif File.exist?(pid_file)
        remove_stale_pid_file(pid_file)
      end

      conflict_ports = config.ports["nginx"].select { |port| port_in_use?(port) }
      unless conflict_ports.empty?
        puts "Error: Nginx port(s) already in use by another process: #{conflict_ports.join(', ')}"
        return
      end

      puts "Starting Nginx on ports #{ports_str}..."
      temp_conf = create_nginx_temp_configs(config)

      # Error if temp file creation failed
      if temp_conf.nil?
        puts "Error: Failed to create temporary config file for Nginx"
        return
      end

      # Start nginx with temporary config
      nginx_bin = File.join(HOMEBREW_PREFIX, "bin", "nginx")
      puts "Running command: #{nginx_bin} -c #{temp_conf}"
      puts "Error: Failed to start Nginx" unless system(nginx_bin, "-c", temp_conf)
    end

    def stop_nginx(config)
      pid_file = nginx_pid_file(config)
      unless File.exist?(pid_file)
        running_ports = config.ports["nginx"].select { |port| port_in_use?(port) }
        if running_ports.empty?
          puts "[Stopped] Nginx is not running"
          cleanup_nginx_temp_files(config)
        else
          warn "Warning: Nginx appears to be running on port(s) #{running_ports.join(', ')}, but no Malt pid file was found. Leaving it untouched."
        end
        return false
      end

      stopped = stop_nginx_with_config(config, pid_file)
      cleanup_nginx_temp_files(config) if stopped || !File.exist?(pid_file)
      stopped
    end

    def stop_nginx_with_config(config, pid_file)
      temp_conf = File.join(config.conf_dir, "nginx_main.conf.tmp")
      temp_conf = create_nginx_temp_configs(config) unless File.exist?(temp_conf)
      return stop_pid_file(pid_file, "Nginx", expected_pattern: nginx_temp_config(config)) if temp_conf.nil?

      nginx_bin = File.join(HOMEBREW_PREFIX, "bin", "nginx")
      unless system(nginx_bin, "-c", temp_conf, "-s", "stop")
        warn "Warning: Failed to signal Nginx with project config; checking pid state..."
      end
      pid = read_pid_file(pid_file)
      wait_for_pid_stop(pid, timeout: 10) if pid

      if pid && pid_running?(pid)
        warn "Warning: Nginx did not stop cleanly, falling back to pid termination..."
        return stop_pid_file(pid_file, "Nginx", expected_pattern: temp_conf)
      end

      remove_stale_pid_file(pid_file)
      true
    end

    def nginx_pid_file(config)
      File.join(config.var_dir, "nginx.pid")
    end

    def nginx_temp_config(config)
      File.join(config.conf_dir, "nginx_main.conf.tmp")
    end

    def create_nginx_temp_configs(config)
      config.ports["nginx"].each do |port|
        nginx_port_conf = File.join(config.conf_dir, "nginx_#{port}.conf")
        unless File.exist?(nginx_port_conf)
          puts "Nginx config file not found for port #{port}: #{nginx_port_conf}"
          return nil
        end

        temp_port_conf = create_temp_config(config, nginx_port_conf)
        if temp_port_conf.nil?
          puts "Failed to create temporary config file for port #{port}"
          return nil
        end
      end

      nginx_conf = File.join(config.conf_dir, "nginx_main.conf")
      unless File.exist?(nginx_conf)
        puts "Nginx main config file not found: #{nginx_conf}"
        return nil
      end

      create_temp_config(config, nginx_conf)
    end

    def cleanup_nginx_temp_files(config)
      return if ENV["MALT_DEBUG"]

      remove_temp_config(nginx_temp_config(config))
      Dir.glob(File.join(config.conf_dir, "nginx_*.conf.tmp")).each do |tmp_file|
        remove_temp_config(tmp_file)
      end
    end
  end
end
