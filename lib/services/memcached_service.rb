# frozen_string_literal: true

require_relative "base_service"

module Malt
  # Memcached service class
  class MemcachedService < BaseService
    def start(config)
      config.ports["memcached"].each do |port|
        start_memcached(config, port)
      end
    end

    def stop(config)
      config.ports["memcached"].each do |port|
        stop_memcached(config, port)
      end
    end

    private

    def start_memcached(config, port)
      FileUtils.mkdir_p(config.var_dir)
      pid_file = File.join(config.var_dir, "memcached_#{port}.pid")
      if pid_running_from_file?(pid_file)
        puts "[Running] Memcached on port #{port}"
        return
      end

      # Check if port is already in use
      if port_in_use?(port)
        puts "Error: Port #{port} is already in use by another process"
        return
      end

      puts "Starting Memcached on port #{port}..."

      system("memcached", "-d", "-m", "64", "-p", port.to_s, "-u", "memcached", "-c", "1024", "-P", pid_file, "-l", "127.0.0.1")
    end

    def stop_memcached(config, port)
      pid_file = File.join(config.var_dir, "memcached_#{port}.pid")
      unless File.exist?(pid_file)
        if port_in_use?(port)
          warn "Warning: Memcached appears to be running on port #{port}, but no Malt pid file was found. Leaving it untouched."
        else
          puts "[Stopped] Memcached is not running on port #{port}"
        end
        return false
      end

      stop_pid_file(pid_file, "Memcached on port #{port}")
    end
  end
end
