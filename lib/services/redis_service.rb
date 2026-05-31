# frozen_string_literal: true

require_relative "base_service"

module Malt
  # Redis service class
  class RedisService < BaseService
    def start(config)
      config.ports["redis"].each do |port|
        start_redis(config, port)
      end
    end

    def stop(config)
      config.ports["redis"].each do |port|
        stop_redis(config, port)
      end
    end

    private

    def start_redis(config, port)
      # Check if port is already in use
      if port_in_use?(port)
        puts "[Running] Redis on port #{port}"
        return
      end

      puts "Starting Redis on port #{port}..."

      redis_conf = File.join(config.conf_dir, "redis_#{port}.conf")

      # Verify config file exists
      unless File.exist?(redis_conf)
        puts "Redis configuration file not found at: #{redis_conf}"
        return
      end

      # Ensure tmp directory exists for Redis
      FileUtils.mkdir_p(File.join(config.malt_dir, "tmp"))

      # Ensure logs directory exists
      FileUtils.mkdir_p(File.join(config.malt_dir, "logs"))

      # Create temporary config file with variable expansion
      temp_conf = create_temp_config(config, redis_conf)

      # Abort if temp config creation failed
      if temp_conf.nil?
        puts "Error: Failed to create temporary config file for Redis on port #{port}"
        return
      end

      # Start Redis with temporary config
      puts "Running command: redis-server #{temp_conf}"
      pid = Process.spawn("redis-server", temp_conf)
      Process.detach(pid)
    rescue SystemCallError => e
      puts "Error: Failed to start Redis on port #{port}: #{e.message}"
    end

    def stop_redis(config, port)
      port = Integer(port) # Validate port is numeric

      # Check if Redis is running on the specific port
      if port_in_use?(port)
        puts "Stopping Redis on port #{port}..."

        # Find the temporary config file
        redis_conf_tmp = File.join(config.conf_dir, "redis_#{port}.conf.tmp")

        # Stop the Redis server on the specific port
        redis_cli = File.join(HOMEBREW_PREFIX, "bin", "redis-cli")
        stop_success = system(redis_cli, "-p", port.to_s, "shutdown")

        # Clean up temporary file if Redis was stopped successfully
        if stop_success && !ENV["MALT_DEBUG"] && File.exist?(redis_conf_tmp)
          remove_temp_config(redis_conf_tmp)
        end
      else
        puts "[Stopped] Redis is not running on port #{port}"
      end
    end
  end
end
