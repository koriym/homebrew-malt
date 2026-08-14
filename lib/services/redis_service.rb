# frozen_string_literal: true

require_relative "base_service"

module Malt
  # Redis service class
  class RedisService < BaseService
    def start(config)
      results = config.ports["redis"].map { |port| start_redis(config, port) }
      results.all?
    end

    # Check whether Redis on the given port is running under Malt management
    def running?(config, port, _index = nil)
      pid_running_from_file?(redis_pid_file(config, port), expected_pattern: redis_identity_pattern(port))
    end

    def stop(config)
      config.ports["redis"].each do |port|
        stop_redis(config, port)
      end
    end

    private

    def start_redis(config, port)
      FileUtils.mkdir_p(config.var_dir)
      pid_file = redis_pid_file(config, port)
      if pid_running_from_file?(pid_file, expected_pattern: redis_identity_pattern(port))
        puts "[Running] Redis on port #{port}"
        register_process("redis", pid_file, redis_identity_pattern(port), pid_file: pid_file)
        return true
      elsif File.exist?(pid_file)
        remove_stale_pid_file(pid_file)
      end

      # Check if port is already in use
      if port_in_use?(port)
        puts "Error: Port #{port} is already in use by another process"
        return false
      end

      puts "Starting Redis on port #{port}..."

      redis_conf = File.join(config.conf_dir, "redis_#{port}.conf")

      # Verify config file exists
      unless File.exist?(redis_conf)
        puts "Redis configuration file not found at: #{redis_conf}"
        return false
      end

      # Ensure tmp directory exists for Redis
      FileUtils.mkdir_p(File.join(config.malt_dir, "tmp"))

      # Ensure logs directory exists
      FileUtils.mkdir_p(config.logs_dir)

      # Create temporary config file with variable expansion
      temp_conf = create_temp_config(config, redis_conf)

      # Abort if temp config creation failed
      if temp_conf.nil?
        puts "Error: Failed to create temporary config file for Redis on port #{port}"
        return false
      end

      # Start Redis with temporary config (redirect output so the daemon doesn't hold the caller's pipes open)
      puts "Running command: redis-server #{temp_conf}"
      log_file = File.join(config.logs_dir, "redis_#{port}.log")
      pid = nil
      pid = Process.spawn("redis-server", temp_conf, out: [log_file, "a"], err: [:child, :out])
      File.write(pid_file, pid.to_s)
      Process.detach(pid)
      register_process("redis", pid_file, redis_identity_pattern(port), pid_file: pid_file)
      true
    rescue SystemCallError => e
      terminate_pid(pid, "Redis on port #{port}") if pid
      puts "Error: Failed to start Redis on port #{port}: #{e.message}"
      false
    rescue StandardError => e
      terminate_pid(pid, "Redis on port #{port}") if pid
      puts "Error: Failed to persist Redis pid file for port #{port}: #{e.message}"
      false
    end

    def stop_redis(config, port)
      port = Integer(port) # Validate port is numeric
      pid_file = redis_pid_file(config, port)
      unless File.exist?(pid_file)
        if port_in_use?(port)
          warn "Warning: Redis appears to be running on port #{port}, but no Malt pid file was found. Leaving it untouched."
        else
          puts "[Stopped] Redis is not running on port #{port}"
        end
        cleanup_redis_temp(config, port)
        unregister_process(pid_file)
        return false
      end

      stopped = stop_pid_file(pid_file, "Redis on port #{port}", expected_pattern: redis_identity_pattern(port))
      cleanup_redis_temp(config, port) if stopped || !File.exist?(pid_file)
      unregister_process(pid_file) if stopped
      stopped
    end

    def redis_pid_file(config, port)
      File.join(config.var_dir, "redis_#{port}.pid")
    end

    def redis_identity_pattern(port)
      ["redis-server", port.to_s]
    end

    def cleanup_redis_temp(config, port)
      return if ENV["MALT_DEBUG"]

      remove_temp_config(File.join(config.conf_dir, "redis_#{port}.conf.tmp"))
    end
  end
end
