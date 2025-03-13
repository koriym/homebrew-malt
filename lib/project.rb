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
        puts "Config file not found: #{config_path}"
        puts "Run 'malt init' to create a config file"
        return
      end

      puts "Installing dependencies from: #{config_path}"
      begin
        json_data = JSON.parse(File.read(config_path))

        if json_data["dependencies"] && !json_data["dependencies"].empty?
          puts "Checking dependencies:"
          installed_formulas = `brew list --formula`.split("\n")
          deps_to_install = json_data["dependencies"].reject do |dep|
            is_installed = installed_formulas.include?(dep)
            puts "[Installed] #{dep}" if is_installed
            is_installed
          end

          deps_to_install.each do |dep|
            puts "[Installing] #{dep}"
            system "brew", "install", dep, "--quiet"
            puts "    Warning: Installation of #{dep} failed" unless $?.success?
          end
        else
          puts "No dependencies specified in config"
        end

        if json_data["php_extensions"] && !json_data["php_extensions"].empty?
          puts "PHP extensions:"
          php_dep = json_data["dependencies"].find { |dep| dep.start_with?("php@") }
          php_version = php_dep ? php_dep.split('@')[1] : "8.4"
          installed_formulas = `brew list --formula`.split("\n")

          json_data["php_extensions"].each do |ext|
            ext_lower = ext.downcase
            formula_name = "#{ext_lower}@#{php_version}"
            formula_installed = installed_formulas.include?(formula_name)

            if formula_installed
              puts " [Installed] #{ext}"
            else
              puts " [Installing] #{ext}"
              system "brew", "install", formula_name, "--quiet"
              puts "    Warning: Installation of #{formula_name} failed." unless $?.success?
            end
          end
          puts "Note: Run 'php -m' to verify that extensions are properly loaded in PHP"
          puts "All dependencies have been installed."
          puts "Run 'malt create' to generate configuration files."
        end
      rescue JSON::ParserError => e
        puts "Invalid JSON in #{config_path}: #{e.message}"
      rescue => e
        puts "Error installing dependencies: #{e.message}"
      end
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
      unless File.directory?(public_dir)
        FileUtils.mkdir_p(public_dir)
        # Copy public files from template
        template_dir = File.join(MALT_SHARE_PATH, "public")
        FileUtils.cp_r("#{template_dir}/.", public_dir)
        puts "Created public directory and dashboard: #{public_dir}"
      end

      generate_config_files(config)
      puts "Created malt files in: #{malt_dir}"
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
      project_dir = config.project_dir
      document_root = config.document_root
      project_name = config.project_name

      php_dep = config.dependencies.find { |dep| dep.start_with?("php@") }
      php_version = php_dep ? php_dep.split('@')[1] : "8.4"
      mysql_dep = config.dependencies.find { |dep| dep.start_with?("mysql@") }
      mysql_version = mysql_dep ? mysql_dep.split('@')[1] : "8.0"

      aliases = []
      if config.has_service?("mysql")
        config.ports["mysql"].each do |port|
          aliases << "alias mysql@#{port}=\"mysql --defaults-file=#{malt_dir}/conf/my_#{port}.cnf -h 127.0.0.1\""
        end
      end
      if config.has_service?("postgresql")
        config.ports["postgresql"].each do |port|
          aliases << "alias psql@#{port}=\"psql -p #{port}\""
        end
      end
      if config.has_service?("redis")
        config.ports["redis"].each do |port|
          aliases << "alias redis-cli@#{port}=\"redis-cli -p #{port}\""
        end
      end

      <<~SCRIPT
        export MALT_DIR="#{malt_dir}"
        export DOCUMENT_ROOT="#{document_root}"
        export PATH="#{HOMEBREW_PREFIX}/opt/php@#{php_version}/bin:#{HOMEBREW_PREFIX}/opt/mysql@#{mysql_version}/bin:$PATH"
        
        #{aliases.join("\n")}
      SCRIPT
    end

    def self.info(options)
      config = Malt::Config.new(options[:config])
      config.validate!

      puts "Project: #{config.project_name}"
      puts "Directory: #{config.project_dir}"
      puts "Malt Directory: #{config.malt_dir}"
      puts "Document Root: #{config.document_root}"
      puts "Services:"
      puts "  PHP-FPM: #{config.ports["php"].join(', ')}" if config.ports["php"]
      puts "  Nginx: #{config.ports["nginx"].join(', ')}" if config.ports["nginx"]
      puts "  Apache: #{config.ports["httpd"].join(', ')}" if config.ports["httpd"]
      puts "  Redis: #{config.ports["redis"].join(', ')}" if config.ports["redis"]
      puts "  MySQL: #{config.ports["mysql"].join(', ')}" if config.ports["mysql"]
      puts "  PostgreSQL: #{config.ports["postgresql"].join(', ')}" if config.ports["postgresql"]
    end

    private

    def self.generate_config_files(config)
      generate_php_configs(config)
      generate_webserver_configs(config)
      generate_database_configs(config)
      generate_cache_configs(config)
    end

    def self.generate_php_configs(config)
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
      php_extensions = config.php_extensions.map { |ext| ext == "xdebug" ? "zend_extension=#{ext}.so" : "extension=#{ext}.so" }.join("\n")
      content = php_ini_template.render({ MALT_DIR: "{{MALT_DIR}}", PHP_EXTENSIONS: php_extensions })
      File.write(File.join(config.malt_dir, "conf", "php.ini"), content)
    end

    def self.generate_webserver_configs(config)
      if config.ports["nginx"]
        nginx_template = Malt::Template.new(File.join(templates_dir, "nginx", "nginx.conf.erb"))
        nginx_main_template = Malt::Template.new(File.join(templates_dir, "nginx", "nginx_main.conf.erb"))

        nginx_includes = config.ports["nginx"].map { |port| "include {{MALT_DIR}}/conf/nginx_#{port}.conf.tmp;" }.join("\n  ")
        config.ports["nginx"].each do |port|
          content = nginx_template.render({
                                            PORT: port,
                                            MALT_DIR: "{{MALT_DIR}}",
                                            DOCUMENT_ROOT: "{{PUBLIC_DIR}}",
                                            HOMEBREW_PREFIX: "{{HOMEBREW_PREFIX}}",
                                            PHP_PORT: config.ports["php"].first
                                          })
          File.write(File.join(config.malt_dir, "conf", "nginx_#{port}.conf"), content)
        end

        content = nginx_main_template.render({ HOMEBREW_PREFIX: "{{HOMEBREW_PREFIX}}", NGINX_INCLUDES: nginx_includes })
        File.write(File.join(config.malt_dir, "conf", "nginx_main.conf"), content)
      end

      if config.ports["httpd"]
        httpd_template = Malt::Template.new(File.join(templates_dir, "httpd", "httpd.conf.erb"))
        php_lib_path = "{{HOMEBREW_PREFIX}}/opt/php@#{config.php_version}/lib/httpd/modules/libphp.so"

        config.ports["httpd"].each do |port|
          content = httpd_template.render({
                                            PORT: port,
                                            MALT_DIR: "{{MALT_DIR}}",
                                            DOCUMENT_ROOT: "{{PUBLIC_DIR}}",
                                            HOMEBREW_PREFIX: "{{HOMEBREW_PREFIX}}",
                                            PHP_LIB_PATH: php_lib_path
                                          })
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

      if config.has_service?("postgresql")
        postgresql_template = Malt::Template.new(File.join(templates_dir, "postgresql", "postgresql.conf.erb"))
        config.ports["postgresql"].each do |port|
          content = postgresql_template.render({ PORT: port, MALT_DIR: "{{MALT_DIR}}" })
          File.write(File.join(config.malt_dir, "conf", "postgresql_#{port}.conf"), content)
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

      if config.ports["memcached"]
        memcached_template = Malt::Template.new(File.join(templates_dir, "memcached", "memcached.conf.erb"))
        config.ports["memcached"].each do |port|
          content = memcached_template.render({ PORT: port, MALT_DIR: "{{MALT_DIR}}" })
          File.write(File.join(config.malt_dir, "conf", "memcached_#{port}.conf"), content)
        end
      end
    end
  end
end
