# frozen_string_literal: true

require "fileutils"

module Malt
  # Homebrew prefix constant shared across services
  HOMEBREW_PREFIX = ENV["HOMEBREW_PREFIX"] || `brew --prefix`.chomp

  # Base service class providing common functionality for all services
  class BaseService
    # Create temporary config file with variable expansion
    def create_temp_config(config, config_path)
      create_temp_config_with_extras(config, config_path, {})
    end

    # Check if a port is already in use
    def port_in_use?(port)
      self.class.port_in_use?(port)
    end

    def self.port_in_use?(port)
      port = Integer(port) # Validate port is numeric
      if RUBY_PLATFORM =~ /darwin/
        system("lsof", "-i", ":#{port}", "-sTCP:LISTEN", out: File::NULL, err: File::NULL)
      else
        system("ss", "-tlnH", "sport", "=", ":#{port}", out: File::NULL, err: File::NULL)
      end
    end

    def pid_running_from_file?(pid_file)
      pid = read_pid_file(pid_file)
      pid && pid_running?(pid)
    end

    def read_pid_file(pid_file)
      return nil unless File.exist?(pid_file)

      pid = File.read(pid_file).strip
      return nil if pid.empty?

      Integer(pid)
    rescue ArgumentError
      nil
    end

    def pid_running?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end

    def stop_pid_file(pid_file, label, timeout: 10)
      pid = read_pid_file(pid_file)
      unless pid
        puts "[Stopped] #{label} is not running"
        remove_stale_pid_file(pid_file)
        return false
      end

      unless pid_running?(pid)
        puts "[Stopped] #{label} is not running"
        remove_stale_pid_file(pid_file)
        return false
      end

      puts "Stopping #{label}..."
      Process.kill("TERM", pid)
      wait_for_pid_stop(pid, timeout: timeout)

      if pid_running?(pid)
        warn "Warning: #{label} still running after SIGTERM, sending SIGKILL..."
        Process.kill("KILL", pid)
        wait_for_pid_stop(pid, timeout: 1)
      end

      if pid_running?(pid)
        warn "Warning: Failed to stop #{label}"
        return false
      end

      remove_stale_pid_file(pid_file)
      true
    rescue Errno::ESRCH
      remove_stale_pid_file(pid_file)
      false
    rescue Errno::EPERM => e
      warn "Warning: Failed to stop #{label}: #{e.message}"
      false
    end

    # Create temporary config file with extra variable substitutions
    def create_temp_config_with_extras(config, config_path, extra_vars = {})
      unless File.exist?(config_path)
        puts "Error: Configuration file not found: #{config_path}"
        return nil
      end

      # Set template variables
      template_vars = {
        "MALT_DIR" => config.malt_dir,
        "PROJECT_DIR" => config.project_dir,
        "PHP_VERSION" => config.php_version,
        "HOMEBREW_PREFIX" => HOMEBREW_PREFIX
      }

      # Debug output - check variable values
      if ENV["MALT_DEBUG"]
        puts "Template variables:"
        template_vars.each do |key, value|
          puts "  #{key}: #{value.inspect}"
        end
      end

      # Treat all absolute paths as strings to ensure they are properly replaced
      template_vars.each do |key, value|
        template_vars[key] = value.to_s unless value.nil?
      end

      # Merge in additional variables
      template_vars.merge!(extra_vars)

      # Temporary file path (in the same directory as the original)
      # Prevent .tmp.tmp by checking if path already ends with .tmp
      temp_path = config_path.end_with?(".tmp") ? config_path : "#{config_path}.tmp"

      # Read the original file and perform variable substitution
      begin
        content = File.read(config_path)

        # Optional debug output
        if ENV["MALT_DEBUG"]
          puts "Original config content:"
          puts content
          puts "Template variables:"
          template_vars.each do |key, value|
            puts "  #{key} => #{value}"
          end
        end

        # Variable substitution
        puts "Replacing template variables in content:" if ENV["MALT_DEBUG"]
        template_vars.each do |key, value|
          # {{VARIABLE}} style substitution
          if content.include?("{{#{key}}}")
            puts "  Replacing {{#{key}}} with '#{value}'" if ENV["MALT_DEBUG"]
            content = content.gsub("{{#{key}}}", value)
          elsif ENV["MALT_DEBUG"]
            puts "  Warning: No occurrence of {{#{key}}} found in content"
          end
        end

        # Optional debug output
        if ENV["MALT_DEBUG"]
          puts "Processed config content:"
          puts content
        end

        # Write to temporary file
        begin
          puts "Writing temporary file: #{temp_path}" if ENV["MALT_DEBUG"]
          File.write(temp_path, content)
          if File.exist?(temp_path)
            puts "Temporary file created successfully: #{temp_path}" if ENV["MALT_DEBUG"]
            puts "Content written: #{File.read(temp_path)}" if ENV["MALT_DEBUG"]
          elsif ENV["MALT_DEBUG"]
            puts "Warning: Temporary file was not created!"
          end
          temp_path
        rescue StandardError => e
          puts "Error writing temporary file: #{e.message}"
          puts e.backtrace.join("\n") if ENV["MALT_DEBUG"]
          nil
        end
      rescue StandardError => e
        puts "Error: Failed to create temporary config file: #{e.message}"
        nil
      end
    end

    # Helper method for DRY startup pattern with temp config
    # Yields the temp config path to the block and handles cleanup on failure
    def with_temp_config(config, config_path, extra_vars = {})
      temp_conf = if extra_vars.empty?
                    create_temp_config(config, config_path)
                  else
                    create_temp_config_with_extras(config, config_path, extra_vars)
                  end

      return nil if temp_conf.nil?

      yield temp_conf
    end

    # Wait for a process matching the pattern to terminate.
    # Sends SIGKILL as a fallback if SIGTERM doesn't work within the timeout.
    def wait_for_process_stop(pattern, timeout: 10)
      timeout.times do
        return unless system("pgrep", "-f", pattern, out: File::NULL, err: File::NULL)
        sleep 1
      end

      return unless system("pgrep", "-f", pattern, out: File::NULL, err: File::NULL)

      warn "Warning: #{pattern} still running after SIGTERM, sending SIGKILL..."
      system("pkill", "-9", "-f", pattern, out: File::NULL, err: File::NULL)
      sleep 1
    end

    def wait_for_pid_stop(pid, timeout: 10)
      (timeout * 10).times do
        return unless pid_running?(pid)

        sleep 0.1
      end
    end

    # Remove temporary config file
    def remove_temp_config(temp_path)
      FileUtils.rm(temp_path) if File.exist?(temp_path)
    end

    def remove_stale_pid_file(pid_file)
      FileUtils.rm_f(pid_file) unless ENV["MALT_DEBUG"]
    end

    # Remove all temporary files matching a pattern
    def cleanup_temp_files(config, pattern)
      temp_files = Dir.glob(File.join(config.conf_dir, pattern))
      temp_files.each do |file|
        puts "Cleaning up temporary file: #{file}" if ENV["MALT_DEBUG"]
        FileUtils.rm(file) if File.exist?(file)
      end
    end
  end
end
