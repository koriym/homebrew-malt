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
      stop_memcached
    end

    private

    def start_memcached(config, port)
      # Check if port is already in use
      if port_in_use?(port)
        puts "[Running] Memcached on port #{port}"
        return
      end

      puts "Starting Memcached on port #{port}..."

      pid_file = "/tmp/memcached_#{port}.pid"

      cmd = "memcached -d -m 64 -p #{port} -u memcached -c 1024 -P #{pid_file} -l 127.0.0.1"

      system(cmd)
    end

    def stop_memcached
      # Check if Memcached is running
      if system("pgrep -f memcached >/dev/null 2>&1")
        puts "Stopping Memcached..."
        system("pkill -f memcached")
        wait_for_process_stop("memcached")
      else
        puts "[Stopped] Memcached is not running"
      end
    end
  end
end
