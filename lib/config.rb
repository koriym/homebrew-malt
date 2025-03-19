module Malt
  class Config
    attr_reader :project_name, :dependencies, :ports, :php_extensions, :project_dir, :public_dir

    def initialize(config_path)
      unless File.exist?(config_path)
        raise "Config file not found: #{config_path}"
      end

      begin
        config = JSON.parse(File.read(config_path))
      rescue JSON::ParserError => e
        raise "Invalid JSON in config file: #{e.message}"
      end

      @project_name = config["project_name"] || File.basename(File.dirname(config_path))
      @dependencies = config["dependencies"] || []
      @ports = config["ports"] || {}
      @php_extensions = config["php_extensions"] || []
      @project_dir = File.dirname(config_path)
      @config_path = config_path

      # Read public_dir from config if available, otherwise use default "public"
      @public_dir = config["public_dir"] || "public"
    end

    def php_version
      php_dep = @dependencies.find { |dep| dep.start_with?("php@") }
      if php_dep
        php_dep.split('@')[1]
      else
        "8.4" # Default value
      end
    end

    def has_service?(service_name)
      @ports.key?(service_name) && !@ports[service_name].empty?
    end

    def malt_dir
      File.join(@project_dir, "malt")
    end

    def conf_dir
      File.join(malt_dir, "conf")
    end

    def logs_dir
      File.join(malt_dir, "logs")
    end

    def var_dir
      File.join(malt_dir, "var")
    end

    def tmp_dir
      File.join(malt_dir, "tmp")
    end

    def document_root
      # Use the fixed "public" directory, resolved as a relative path from project_dir
      File.join(@project_dir, "public")
    end

    def validate!
      # Verify required fields
      unless @project_name && !@project_name.empty?
        raise "Missing project_name in config"
      end

      # Verify port settings
      unless has_service?("php")
        raise "Missing PHP ports in config"
      end

      true
    end

    def to_json
      {
        project_name: @project_name,
        public_dir: @public_dir,
        dependencies: @dependencies,
        ports: @ports,
        php_extensions: @php_extensions
      }.to_json
    end
  end
end
