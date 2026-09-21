require "shellwords"

module Malt
  class Project
    def self.templates_dir
      if ENV["MALT_DEBUG"]
        puts "Templates directory: #{MALT_TEMPLATES_PATH}"
        puts "Templates exist: #{Dir.exist?(MALT_TEMPLATES_PATH)}"
        puts "Template files: #{Dir.glob(File.join(MALT_TEMPLATES_PATH, '**', '*')).join(', ')}"
      end
      MALT_TEMPLATES_PATH
    end

    def self.examples_dir
      if ENV["MALT_DEBUG"]
        puts "Examples directory: #{MALT_SHARE_PATH}"
        puts "Examples exist: #{Dir.exist?(MALT_SHARE_PATH)}"
        puts "Example files: #{Dir.glob(File.join(MALT_SHARE_PATH, '*.json')).join(', ')}"
      end
      MALT_SHARE_PATH
    end

    def self.list_templates
      puts "Available templates:"
      if Dir.exist?(examples_dir)
        Dir.glob(File.join(examples_dir, "*.json")).each do |file|
          puts "  - #{File.basename(file, ".json")}"
        end
      else
        puts "  No templates found"
      end
    end

    def self.init(options)
      config_path = options[:config]
      if File.exist?(config_path)
        puts "Config file already exists: #{config_path}."
        puts "Run 'malt create' to create malt files."
        return
      end
      template_path = MALT_CONFIG_PATH

      if File.exist?(template_path)
        json_content = File.read(template_path)
        File.write(config_path, json_content)
      else
        puts "Error: Default template not found at #{template_path}"
        exit 1
      end

      puts "Config file created: #{config_path}"
      puts "Edit malt.json to customize your environment, then run 'malt install'."
    end

    def self.install_deps(options)
      config_path = options[:config]
      unless File.exist?(config_path)
        raise "Config file not found: #{config_path}. Run 'malt init' to create a config file"
      end

      puts "Installing dependencies from: #{config_path}"
      json_data = JSON.parse(File.read(config_path))
      dependencies = Array(json_data["dependencies"])
      php_extensions = Array(json_data["php_extensions"])
      failures = []

      if dependencies.empty?
        puts "No dependencies specified in config"
      else
        puts "Checking dependencies:"
        installed_formulas = brew_installed_formulas
        deps_to_install = dependencies.reject do |dep|
          is_installed = installed_formulas.include?(dep)
          puts "[Installed] #{dep}" if is_installed
          is_installed
        end

        deps_to_install.each do |dep|
          puts "[Installing] #{dep}"
          next if system("brew", "install", dep, "--quiet")

          puts "    Warning: Installation of #{dep} failed"
          failures << dep
        end
      end

      unless php_extensions.empty?
        puts "PHP extensions:"
        php_dep = dependencies.find { |dep| dep.start_with?("php@") }
        php_version = php_dep ? php_dep.split('@')[1] : "8.4"
        formulas = brew_installed_formulas

        php_extensions.each do |ext|
          ext_lower = ext.downcase
          candidates = ["#{ext_lower}@#{php_version}", "php#{ext_lower}@#{php_version}", "php-#{ext_lower}@#{php_version}"]
          formula_name = candidates.find { |name| formulas.include?(name) }

          if formula_name
            puts " [Installed] #{ext}"
          else
            puts " [Installing] #{ext}"
            installed_name = candidates.find { |candidate| system("brew", "install", candidate, "--quiet") }
            if installed_name
              formulas << installed_name
            else
              puts "    Warning: Installation of #{ext} failed. Tried: #{candidates.join(', ')}"
              failures << ext
            end
          end
        end
      end

      raise "Failed to install: #{failures.join(', ')}" unless failures.empty?

      puts "Note: Run 'php -m' to verify that extensions are properly loaded in PHP" unless php_extensions.empty?
      puts "All dependencies have been installed."
      puts "Run 'malt create' to generate configuration files."
    end

    def self.create(options)
      config = Malt::Config.new(options[:config])
      config.validate!
      malt_dir = config.malt_dir

      if Dir.exist?(malt_dir)
        puts "Malt directory already exists: #{malt_dir}"
        puts "Run 'malt start' to start services."
        return
      end

      %w(conf logs tmp var).each do |dir|
        dir_path = File.join(malt_dir, dir)
        FileUtils.mkdir_p(dir_path)
      end

      public_dir = config.document_root
      if File.directory?(public_dir)
        # Public directory already exists
        puts "Existing 'public/' directory found. It will be used as the document root."
        puts "No files were copied into it by Malt."
      else
        # Public directory does not exist, create it and copy dashboard
        FileUtils.mkdir_p(public_dir)
        template_dir = File.join(MALT_SHARE_PATH, "public")
        FileUtils.cp_r("#{template_dir}/.", public_dir)
        puts "Created 'public/' directory and copied default dashboard files."
        puts "Feel free to edit or delete these files."
      end

      generate_config_files(config)
      puts "Created malt configuration files in: #{malt_dir}" # Slightly updated message
      puts "Run 'malt start' to start services."
    end

    def self.start(options)
      Malt::ServiceManager.start(options)
    end

    def self.stop(options)
      Malt::ServiceManager.stop(options)
    end

    def self.env_script(options)
      config = Malt::Config.new(options[:config])
      config.validate!

      malt_dir = config.malt_dir
      document_root = config.document_root

      php_version = config.php_version
      mysql_version = config.mysql_version

      aliases = []
      if config.has_service?("mysql")
        config.ports["mysql"].each do |port|
          mysql_defaults_file = File.join(malt_dir, "conf", "my_#{port}.cnf")
          aliases << shell_alias("mysql@#{port}", ["mysql", "--defaults-file=#{mysql_defaults_file}", "-h", "127.0.0.1"])
        end
      end
      if config.has_service?("redis")
        config.ports["redis"].each do |port|
          aliases << shell_alias("redis-cli@#{port}", ["redis-cli", "-p", port.to_s])
        end
      end

      php_bin = File.join(HOMEBREW_PREFIX, "opt", "php@#{php_version}", "bin")
      mysql_bin = File.join(HOMEBREW_PREFIX, "opt", "mysql@#{mysql_version}", "bin")

      <<~SCRIPT
        export MALT_DIR=#{Shellwords.escape(malt_dir)}
        export DOCUMENT_ROOT=#{Shellwords.escape(document_root)}
        export PATH=#{Shellwords.escape(php_bin)}:#{Shellwords.escape(mysql_bin)}:$PATH
        
        #{aliases.join("\n")}
      SCRIPT
    end

    def self.info(options)
      config = Malt::Config.new(options[:config])
      config.validate!

      puts "Project: #{config.project_name}"
      puts "Directory: #{config.project_dir}"
      puts "Malt Directory: #{config.malt_dir}"
      puts "Services:"
      puts "  PHP-FPM: #{config.ports["php"].join(', ')}" if config.ports["php"]
      puts "  Nginx: #{config.ports["nginx"].join(', ')}" if config.ports["nginx"]
      puts "  Apache: #{config.ports["httpd"].join(', ')}" if config.ports["httpd"]
      puts "  Redis: #{config.ports["redis"].join(', ')}" if config.ports["redis"]
      puts "  MySQL: #{config.ports["mysql"].join(', ')}" if config.ports["mysql"]
    end

    private

    def self.generate_config_files(config)
      generate_php_configs(config)
      generate_webserver_configs(config)
      generate_database_configs(config)
      generate_cache_configs(config)
    end

    def self.generate_php_configs(config)
      return unless config.has_service?("php")

      template_dir_path = MALT_TEMPLATES_PATH
      puts "Using templates from: #{template_dir_path}" if ENV["MALT_DEBUG"]

      php_fpm_template_path = File.join(template_dir_path, "php", "php-fpm.conf.erb")
      raise "Template file not found: #{php_fpm_template_path}" unless File.exist?(php_fpm_template_path)

      php_fpm_template = Malt::Template.new(php_fpm_template_path)
      config.ports["php"].each do |port|
        content = php_fpm_template.render({ PORT: port, MALT_DIR: "{{MALT_DIR}}" })
        File.write(File.join(config.malt_dir, "conf", "php-fpm_#{port}.conf"), content)
      end

      php_ini_template_path = File.join(template_dir_path, "php", "php.ini.erb")
      raise "Template file not found: #{php_ini_template_path}" unless File.exist?(php_ini_template_path)

      php_ini_template = Malt::Template.new(php_ini_template_path)
      php_extensions = config.php_extensions.map { |ext|
        ext_lower = ext.downcase
        so_path = resolve_extension_path(ext_lower, config.php_version)
        ext_lower == "xdebug" ? "zend_extension=#{so_path}" : "extension=#{so_path}"
      }.join("\n")
      content = php_ini_template.render({ MALT_DIR: "{{MALT_DIR}}", PHP_EXTENSIONS: php_extensions })
      File.write(File.join(config.malt_dir, "conf", "php.ini"), content)
    end

    def self.generate_webserver_configs(config)
      has_php = config.has_service?("php")

      if config.ports["nginx"]
        nginx_template_name = has_php ? "nginx.conf.erb" : "nginx-static.conf.erb"
        nginx_template = Malt::Template.new(File.join(templates_dir, "nginx", nginx_template_name))
        nginx_main_template = Malt::Template.new(File.join(templates_dir, "nginx", "nginx_main.conf.erb"))

        nginx_includes = config.ports["nginx"].map { |port| "include {{MALT_DIR}}/conf/nginx_#{port}.conf.tmp;" }.join("\n  ")
        config.ports["nginx"].each do |port|
          vars = { PORT: port, MALT_DIR: "{{MALT_DIR}}", HOMEBREW_PREFIX: "{{HOMEBREW_PREFIX}}" }
          vars[:PHP_PORT] = config.ports["php"].first if has_php
          content = nginx_template.render(vars)
          File.write(File.join(config.malt_dir, "conf", "nginx_#{port}.conf"), content)
        end

        content = nginx_main_template.render({ HOMEBREW_PREFIX: "{{HOMEBREW_PREFIX}}", NGINX_INCLUDES: nginx_includes })
        File.write(File.join(config.malt_dir, "conf", "nginx_main.conf"), content)
      end

      if config.ports["httpd"]
        httpd_template_name = has_php ? "httpd.conf.erb" : "httpd-static.conf.erb"
        httpd_template = Malt::Template.new(File.join(templates_dir, "httpd", httpd_template_name))

        config.ports["httpd"].each do |port|
          vars = { PORT: port, MALT_DIR: "{{MALT_DIR}}", HOMEBREW_PREFIX: "{{HOMEBREW_PREFIX}}" }
          vars[:PHP_LIB_PATH] = "{{HOMEBREW_PREFIX}}/opt/php@#{config.php_version}/lib/httpd/modules/libphp.so" if has_php
          content = httpd_template.render(vars)
          File.write(File.join(config.malt_dir, "conf", "httpd_#{port}.conf"), content)
        end
      end
    end

    def self.generate_database_configs(config)
      if config.has_service?("mysql")
        mysql_template = Malt::Template.new(File.join(templates_dir, "mysql", "my.cnf.erb"))
        config.ports["mysql"].each_with_index do |port, index|
          content = mysql_template.render({ PORT: port, INDEX: index, MALT_DIR: "{{MALT_DIR}}" })
          File.write(File.join(config.malt_dir, "conf", "my_#{port}.cnf"), content)
        end
      end

    end

    def self.generate_cache_configs(config)
      if config.ports["redis"]
        redis_template = Malt::Template.new(File.join(templates_dir, "redis", "redis.conf.erb"))
        config.ports["redis"].each do |port|
          content = redis_template.render({ PORT: port, MALT_DIR: "{{MALT_DIR}}" })
          File.write(File.join(config.malt_dir, "conf", "redis_#{port}.conf"), content)
        end
      end

    end

    def self.resolve_extension_path(ext, php_version)
      candidates = [
        File.join(HOMEBREW_PREFIX, "opt", "#{ext}@#{php_version}", "#{ext}.so"),
        File.join(HOMEBREW_PREFIX, "opt", "php#{ext}@#{php_version}", "#{ext}.so"),
        File.join(HOMEBREW_PREFIX, "opt", "php-#{ext}@#{php_version}", "#{ext}.so"),
      ]
      found = candidates.find { |path| File.exist?(path) }
      if found
        found
      else
        puts "  Warning: Could not find #{ext}.so in Homebrew opt paths, using bare name"
        "#{ext}.so"
      end
    end

    def self.brew_installed_formulas
      `brew list --formula`.split("\n")
    end

    def self.shell_alias(name, command_parts)
      "alias #{name}=#{shell_single_quote(command_parts.shelljoin)}"
    end

    def self.shell_single_quote(value)
      "'#{value.gsub("'", "'\"'\"'")}'"
    end
  end
end
