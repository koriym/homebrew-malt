module Malt
  class ServiceManager
    # Homebrew prefix
    HOMEBREW_PREFIX = ENV["HOMEBREW_PREFIX"] || "/opt/homebrew"

    def self.start(options)
      config_path = find_config_in_current_dir(options)
      config = Malt::Config.new(config_path)

      start_services(config)
    end

    def self.stop(options)
      config_path = find_config_in_current_dir(options)
      config = Malt::Config.new(config_path)

      stop_services(config)
    end

    def self.kill(options)
      # Directly kill services without checking malt.json
      kill_services
    end

    class << self
      private

      def find_config_in_current_dir(options)
        return options[:config] if options[:config] && File.exist?(options[:config])

        config_path = File.join(Dir.pwd, 'malt.json')
        if File.exist?(config_path)
          return config_path
        end

        raise "malt.json not found in current directory. Run 'malt init' to create one."
      end

      def start_services(config)
        puts "Starting services for #{config.project_name}..."

        # Register services
        services = register_services(config)

        # Start each service
        services.each do |service|
          service.start(config)
        end
        puts "Services started."
        puts "Run 'source <(malt env)' to set up your shell environment."
        
        # Webサーバーのアクセス情報を表示
        web_servers = []
        if config.has_service?("httpd")
          config.ports["httpd"].each do |port|
            # port_in_use?の代わりに直接チェック
            if is_port_in_use(port)
              web_servers << "http://127.0.0.1:#{port}/"
            end
          end
        end
        if config.has_service?("nginx")
          config.ports["nginx"].each do |port|
            if is_port_in_use(port)
              web_servers << "http://127.0.0.1:#{port}/"
            end
          end
        end

        if !web_servers.empty?
          puts "Access your site at:"
          web_servers.each do |url|
            puts "  - #{url}"
          end
        end
        
        puts "See https://koriym.github.io/homebrew-malt/"
      end
      
      # ServiceManagerクラスメソッドとしてport_in_useチェックを実装
      def is_port_in_use(port)
        # macOSとLinuxで異なるコマンドを使用
        if RUBY_PLATFORM =~ /darwin/
          # macOS
          system("lsof -i :#{port} -sTCP:LISTEN >/dev/null 2>&1")
        else
          # Linux
          system("netstat -tuln | grep :#{port} >/dev/null 2>&1")
        end
      end

      def stop_services(config)
        puts "Stopping services for #{config.project_name}..."

        # Register services (stop in reverse order)
        services = register_services(config).reverse

        # Stop each service
        services.each do |service|
          service.stop(config)
        end
      end
      
      def kill_services
        # First check if any supported services are running
        any_running = false
        any_running ||= system("pgrep -f php-fpm >/dev/null 2>&1")
        any_running ||= system("pgrep -f 'mysqld' >/dev/null 2>&1")
        any_running ||= system("pgrep -f redis-server >/dev/null 2>&1")
        any_running ||= system("pgrep -f memcached >/dev/null 2>&1")
        any_running ||= system("pgrep -f nginx >/dev/null 2>&1")
        any_running ||= system("pgrep -f httpd >/dev/null 2>&1")
        
        # If no services are running, exit early
        unless any_running
          puts "No running instances of supported services were found."
          return
        end
        
        # Display message about what will be terminated
        puts "About to forcibly terminate the following running services:"
        puts "- PHP-FPM" if system("pgrep -f php-fpm >/dev/null 2>&1")
        puts "- MySQL" if system("pgrep -f 'mysqld' >/dev/null 2>&1")
        puts "- Redis" if system("pgrep -f redis-server >/dev/null 2>&1")
        puts "- Memcached" if system("pgrep -f memcached >/dev/null 2>&1")
        puts "- Nginx" if system("pgrep -f nginx >/dev/null 2>&1")
        puts "- Apache HTTPD" if system("pgrep -f httpd >/dev/null 2>&1")
        puts "(This command affects all instances, regardless of malt.json configuration)"
        
        # Proceed with termination
        any_service_killed = false
        
        any_service_killed |= kill_php_fpm
        any_service_killed |= kill_mysql
        any_service_killed |= kill_redis
        any_service_killed |= kill_memcached
        any_service_killed |= kill_nginx
        any_service_killed |= kill_apache
        
        if any_service_killed
          puts "Forcible termination of services completed."
        end
      end
      
      def kill_php_fpm
        return false unless system("pgrep -f php-fpm >/dev/null 2>&1")
        puts "Forcibly terminating PHP-FPM..."
        # Direct forceful termination - SIGKILL for immediate termination
        if system("pkill -9 -f php-fpm")
          true
        else
          puts "Warning: Failed to forcibly terminate PHP-FPM"
          false
        end
      end

      def kill_mysql
        return false unless system("pgrep -f 'mysqld' >/dev/null 2>&1")
        puts "Forcibly terminating MySQL..."

        # For kill command, skip directly to forceful termination with SIGKILL
        puts "Using immediate termination for MySQL (SIGKILL)..."
        success = system("pkill -9 -f 'mysqld'")
        puts "SIGKILL to MySQL processes #{success ? "sent" : "failed"}"
        
        # Wait a moment for processes to terminate
        sleep 0.5
        
        # Double check if processes are gone
        if system("pgrep -f 'mysqld' >/dev/null 2>&1")
          puts "Warning: MySQL processes still running despite SIGKILL"
          # Try one more time
          system("pkill -9 -f 'mysqld'")
          sleep 0.5
          success = !system("pgrep -f 'mysqld' >/dev/null 2>&1")
        end

        puts "MySQL forceful termination #{success ? "successful" : "failed"}"
        success
      end

      def kill_redis
        return false unless system("pgrep -f redis-server >/dev/null 2>&1")
        puts "Forcibly terminating Redis..."

        # For kill command, skip graceful shutdown and use immediate termination
        puts "Using immediate termination for Redis (SIGKILL)..."
        success = system("pkill -9 -f redis-server")
        puts "SIGKILL to Redis processes #{success ? "sent" : "failed"}"
        
        # Wait a moment for processes to terminate
        sleep 0.5
        
        # Double check if processes are gone
        if system("pgrep -f redis-server >/dev/null 2>&1")
          puts "Warning: Redis processes still running despite SIGKILL"
          # Try one more time
          system("pkill -9 -f redis-server")
          sleep 0.5
          success = !system("pgrep -f redis-server >/dev/null 2>&1")
        else
          puts "Redis forceful termination successful"
        end

        success
      end
      
      def kill_memcached
        return false unless system("pgrep -f memcached >/dev/null 2>&1")
        puts "Forcibly terminating Memcached..."
        # Direct forceful termination with SIGKILL
        if system("pkill -9 -f memcached")
          sleep 0.5
          if system("pgrep -f memcached >/dev/null 2>&1")
            puts "Warning: Memcached processes still running despite SIGKILL"
            system("pkill -9 -f memcached")
            sleep 0.5
            !system("pgrep -f memcached >/dev/null 2>&1")
          else
            true
          end
        else
          puts "Warning: Failed to forcibly terminate Memcached"
          false
        end
      end
      
      def kill_nginx
        return false unless system("pgrep -f nginx >/dev/null 2>&1")
        puts "Forcibly terminating Nginx..."
        
        # For kill command, skip graceful shutdown and use immediate termination
        puts "Using immediate termination for Nginx (SIGKILL)..."
        success = system("pkill -9 -f nginx")
        puts "SIGKILL to Nginx processes #{success ? "sent" : "failed"}"
        
        # Wait a moment for processes to terminate
        sleep 0.5
        
        # Double check if processes are gone
        if system("pgrep -f nginx >/dev/null 2>&1")
          puts "Warning: Nginx processes still running despite SIGKILL"
          # Try one more time
          system("pkill -9 -f nginx")
          sleep 0.5
          success = !system("pgrep -f nginx >/dev/null 2>&1")
        else
          puts "Nginx forceful termination successful"
        end
        
        success
      end
      
      def kill_apache
        return false unless system("pgrep -f httpd >/dev/null 2>&1")
        puts "Forcibly terminating Apache HTTPD..."
        # Direct forceful termination with SIGKILL
        if system("pkill -9 -f httpd")
          sleep 0.5
          if system("pgrep -f httpd >/dev/null 2>&1")
            puts "Warning: Apache processes still running despite SIGKILL"
            system("pkill -9 -f httpd")
            sleep 0.5
            !system("pgrep -f httpd >/dev/null 2>&1")
          else
            puts "Apache HTTPD forceful termination successful"
            true
          end
        else
          puts "Warning: Failed to forcibly terminate Apache HTTPD"
          false
        end
      end
      def register_services(config)
        services = []

        # PHP-FPM
        services << PhpService.new if config.has_service?("php")

        # MySQL
        services << MysqlService.new if config.has_service?("mysql")

        # Redis
        services << RedisService.new if config.has_service?("redis")

        # Memcached
        services << MemcachedService.new if config.has_service?("memcached")

        # Nginx
        services << NginxService.new if config.has_service?("nginx")

        # Apache
        services << HttpdService.new if config.has_service?("httpd")

        services
      end
    end

    # Base service class
    class BaseService
      # Create temporary config file with variable expansion
      def create_temp_config(config, config_path)
        return create_temp_config_with_extras(config, config_path, {})
      end

      # Check if a port is already in use
      def port_in_use?(port)
        # Use different commands for macOS and Linux
        if RUBY_PLATFORM =~ /darwin/
          # macOS
          system("lsof -i :#{port} -sTCP:LISTEN >/dev/null 2>&1")
        else
          # Linux
          system("netstat -tuln | grep :#{port} >/dev/null 2>&1")
        end
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
          template_vars[key] = value.to_s if !value.nil?
        end

        # Merge in additional variables
        template_vars.merge!(extra_vars)

        # Temporary file path (in the same directory as the original)
        temp_path = "#{config_path}.tmp"

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
            else
              puts "  Warning: No occurrence of {{#{key}}} found in content" if ENV["MALT_DEBUG"]
            end
          end

          # Optional debug output
          if ENV["MALT_DEBUG"]
            puts "Processed config content:"
            puts content
          end

          # Write to temporary file
          begin
            # Create in the same directory as the original
            puts "Writing temporary file: #{temp_path}" if ENV["MALT_DEBUG"]
            File.write(temp_path, content)
            if File.exist?(temp_path)
              puts "Temporary file created successfully: #{temp_path}" if ENV["MALT_DEBUG"]
              puts "Content written: #{File.read(temp_path)}" if ENV["MALT_DEBUG"]
            else
              puts "Warning: Temporary file was not created!" if ENV["MALT_DEBUG"]
            end
            return temp_path
          rescue => e
            puts "Error writing temporary file: #{e.message}"
            puts e.backtrace.join("\n") if ENV["MALT_DEBUG"]
            return nil
          end
        rescue => e
          puts "Error: Failed to create temporary config file: #{e.message}"
          return nil
        end
      end

      # Remove temporary config file
      def remove_temp_config(temp_path)
        FileUtils.rm(temp_path) if File.exist?(temp_path)
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

    # PHP service class
    class PhpService < BaseService
      def start(config)
        config.ports["php"].each do |port|
          start_php_fpm(config, port)
        end
      end

      def stop(config)
        stop_php_fpm
      end

      private

      def start_php_fpm(config, port)
        # Check if port is already in use
        if port_in_use?(port)
          puts "[Running] PHP-FPM on port #{port}"
          return
        end

        puts "Starting PHP-FPM on port #{port}..."

        # Configuration file paths
        php_fpm_conf = File.join(config.conf_dir, "php-fpm_#{port}.conf")
        php_ini = File.join(config.conf_dir, "php.ini")

        # Verify config file exists
        unless File.exist?(php_fpm_conf)
          puts "PHP-FPM configuration file not found at: #{php_fpm_conf}"
          return
        end

        # Create temporary config files with variable expansion
        temp_conf = create_temp_config(config, php_fpm_conf)
        temp_ini = create_temp_config(config, php_ini)

        # Error if temporary file creation failed
        if temp_conf.nil?
          puts "Error: Failed to create temporary config file for PHP-FPM"
          return
        end

        if temp_ini.nil?
          puts "Error: Failed to create temporary config file for PHP.ini"
          return
        end

        puts "Using PHP-FPM config file: #{temp_conf}"
        puts "Using PHP.ini file: #{temp_ini}"

        # Start using temporary files
        cmd = "#{HOMEBREW_PREFIX}/opt/php@#{config.php_version}/sbin/php-fpm -y #{temp_conf} -c #{temp_ini}"
        system("#{cmd} &")
      end

      def stop_php_fpm
        if system("pgrep -f php-fpm >/dev/null 2>&1")
          puts "Stopping PHP-FPM..."
          system("pkill -f php-fpm")

          # Clean up temporary files
          if Dir.exist?(File.join(Dir.pwd, "malt", "conf"))
            Dir.glob(File.join(Dir.pwd, "malt", "conf", "php-fpm_*.conf.tmp")).each do |tmp_file|
              puts "Cleaning up temporary file: #{tmp_file}" if ENV["MALT_DEBUG"]
              FileUtils.rm(tmp_file) if File.exist?(tmp_file) && !ENV["MALT_DEBUG"]
            end
            
            # Clean up php.ini temporary file
            php_ini_tmp = File.join(Dir.pwd, "malt", "conf", "php.ini.tmp")
            if File.exist?(php_ini_tmp)
              puts "Cleaning up temporary file: #{php_ini_tmp}" if ENV["MALT_DEBUG"]
              FileUtils.rm(php_ini_tmp) unless ENV["MALT_DEBUG"]
            end
          end
        else
          puts "[Stopped] PHP-FPM is not running"
        end
      end
    end

    # MySQL service class
    class MysqlService < BaseService
      def start(config)
        config.ports["mysql"].each_with_index do |port, index|
          start_mysql(config, port, index)
        end
      end

      def stop(config)
        any_mysql_stopped = false

        config.ports["mysql"].each do |port|
          if stop_mysql(config, port)
            any_mysql_stopped = true
          end
        end

        # 実際にMySQLが停止された場合のみ短く待機する
        if any_mysql_stopped
          puts "Finalizing MySQL shutdown..."
          sleep 0.5
        end
      end

      private

      def start_mysql(config, port, index)
        # ポートが既に使用中かチェック
        if port_in_use?(port)
          puts "[Running] MySQL on port #{port}"
          return
        end

        puts "Starting MySQL on port #{port}..."

        my_cnf = File.join(config.conf_dir, "my_#{port}.cnf")

        # 環境変数を追加してcreate_temp_configを呼び出す
        temp_conf = create_temp_config_with_extras(config, my_cnf, { "INDEX" => index.to_s })

        # 一時ファイルの生成に失敗した場合は元のファイルを使用
        if temp_conf.nil?
          puts "Failed to create temporary config file, using original config"
          temp_conf = my_cnf
        end

        if temp_conf
          # MySQL設定ファイルのパスを出力
          puts "MySQL config path: #{temp_conf}"
          puts "Config exists: #{File.exist?(temp_conf)}"

          # データディレクトリを確保（MySQL用）
          data_dir = File.join(config.var_dir, "mysql_#{index}")
          unless File.directory?(data_dir)
            puts "Creating MySQL data directory: #{data_dir}"
            FileUtils.mkdir_p(data_dir)
          end

          # MySQLエラーログファイルのパスを表示
          log_file = File.join(config.logs_dir, "mysql_#{port}_error.log")
          puts "MySQL error log: #{log_file}"

          # MySQL初期化が必要かチェック
          if !File.exist?(File.join(data_dir, "mysql")) || Dir.glob(File.join(data_dir, "*")).empty?
            puts "Initializing MySQL data directory at #{data_dir}..."
            init_cmd = "#{HOMEBREW_PREFIX}/opt/mysql@8.0/bin/mysqld --initialize-insecure --datadir=#{data_dir}"
            system(init_cmd)
            puts "MySQL initialization complete."
          end

          # 一時ファイルの存在を確認
          if !File.exist?(temp_conf)
            puts "Error: MySQL config temp file not found at: #{temp_conf}"
            puts "Using original config file instead"
            temp_conf = my_cnf
          end

          # シェルコマンドの実行（出力をログファイルにリダイレクト）
          cmd = "#{HOMEBREW_PREFIX}/opt/mysql@8.0/bin/mysqld_safe --defaults-file=#{temp_conf} > #{log_file} 2>&1 &"
          system(cmd)
          puts "MySQL starting in background..."
        end
      end

      def stop_mysql(config, port)
        # MySQLが実行中か確認
        if port_in_use?(port)
          puts "Stopping MySQL on port #{port}..."

          my_cnf = File.join(config.conf_dir, "my_#{port}.cnf")
          temp_conf = "#{my_cnf}.tmp"

          # 一時ファイルが存在する場合はそれを使用
          config_file = File.exist?(temp_conf) ? temp_conf : my_cnf

          # 出力をログファイルにリダイレクト
          log_file = File.join(config.logs_dir, "mysql_#{port}_error.log")
          cmd = "#{HOMEBREW_PREFIX}/opt/mysql@8.0/bin/mysqladmin --defaults-file=#{config_file} -uroot -h 127.0.0.1 --port #{port} shutdown > #{log_file} 2>&1"
          system(cmd)

          # デバッグモードでなければ一時ファイルを削除
          remove_temp_config(temp_conf) unless ENV["MALT_DEBUG"]

          return true # MySQLが停止されたことを返す
        else
          puts "[Stopped] MySQL is not running on port #{port}"
          return false # MySQLが既に停止していることを返す
        end
      end
    end

    # Redis service class
    class RedisService < BaseService
      def start(config)
        config.ports["redis"].each do |port|
          start_redis(config, port)
        end
      end

      def stop(config)
        config.ports["redis"].each do |port|
          stop_redis(port)
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

        # Use original config if temporary creation failed
        if temp_conf.nil?
          puts "Error: Failed to create temporary config file for Redis. Using original config."
          temp_conf = redis_conf
        end

        # Start Redis with temporary config
        cmd = "redis-server #{temp_conf}"
        puts "Running command: #{cmd}"
        system("#{cmd} &")
      end

      def stop_redis(port)
        # Check if Redis is running on the specific port
        if port_in_use?(port)
          puts "Stopping Redis on port #{port}..."

          # Find the temporary config file
          redis_conf_tmp = File.join(Dir.pwd, "malt", "conf", "redis_#{port}.conf.tmp")

          # Stop the Redis server on the specific port
          stop_success = system("#{HOMEBREW_PREFIX}/bin/redis-cli -p #{port} shutdown")

          # Clean up temporary file if Redis was stopped successfully
          if stop_success && !ENV["MALT_DEBUG"] && File.exist?(redis_conf_tmp)
            puts "Cleaning up temporary Redis config: #{redis_conf_tmp}" if ENV["MALT_DEBUG"]
            remove_temp_config(redis_conf_tmp)
          end
        else
          puts "[Stopped] Redis is not running on port #{port}"
        end
      end
    end

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
        # ポートが既に使用中かチェック
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
        # Memcachedが実行中か確認
        if system("pgrep -f memcached >/dev/null 2>&1")
          puts "Stopping Memcached..."
          system("pkill -f memcached")
        else
          puts "[Stopped] Memcached is not running"
        end
      end
    end

    # Nginx service class
    class NginxService < BaseService
      def start(config)
        start_nginx(config)
      end

      def stop(config)
        stop_nginx
      end

      private

      def start_nginx(config)
        # Nginxは複数のポートで動作するため、最初のポートだけチェック
        if config.ports["nginx"] && config.ports["nginx"].first
          port = config.ports["nginx"].first
          if port_in_use?(port)
            puts "[Running] Nginx on port #{port}"
            return
          end
        end

        ports_str = config.ports["nginx"].join(", ")
        puts "Starting Nginx on ports #{ports_str}..."

        # デバッグ出力設定を保存
        old_debug = ENV["MALT_DEBUG"]

        # まず各ポートごとの設定ファイルを変数展開
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

        # メイン設定ファイルを読み込み
        nginx_conf = File.join(config.conf_dir, "nginx_main.conf")

        # メイン設定ファイルの内容を修正して一時ファイルのIncludeを使う
        if File.exist?(nginx_conf)
          main_content = File.read(nginx_conf)

          # 各ポート設定ファイルの参照を一時ファイルに置き換え
          port_temps.each do |port, temp_file|
            original_include = "include #{config.malt_dir}/conf/nginx_#{port}.conf;"
            temp_include = "include #{temp_file};"
            main_content = main_content.gsub(original_include, temp_include)
          end

          # HOMEBREW_PREFIXの置換を追加
          if main_content.include?("{{HOMEBREW_PREFIX}}")
            main_content = main_content.gsub("{{HOMEBREW_PREFIX}}", HOMEBREW_PREFIX)
          end

          # 修正したメイン設定内容を使って一時ファイルを作成
          temp_main_path = "#{nginx_conf}.tmp"
          File.write(temp_main_path, main_content)

          # 一時メインファイルにも変数置換を適用
          temp_conf = create_temp_config(config, temp_main_path)
        else
          puts "Nginx main config file not found: #{nginx_conf}"
          temp_conf = nil
        end

        # デバッグ設定を元に戻す
        ENV["MALT_DEBUG"] = old_debug

        # 一時ファイルの生成に失敗した場合はエラー
        if temp_conf.nil?
          puts "Error: Failed to create temporary config file for Nginx"
          return
        end

        # 一時ファイルを使用して起動
        cmd = "nginx -c #{temp_conf}"
        puts "Running command: #{cmd}"
        system(cmd)
      end

      def stop_nginx
        # Nginxが実行中か確認（プロセスの存在をチェック）
        if system("pgrep -f nginx >/dev/null 2>&1")
          puts "Stopping Nginx..."

          # Nginxサーバーを停止
          stop_success = system("#{HOMEBREW_PREFIX}/bin/nginx -s stop")

          # 関連する一時設定ファイルを削除
          if stop_success && !ENV["MALT_DEBUG"]
            # メイン設定ファイル
            nginx_conf_tmp = File.join(Dir.pwd, "malt", "conf", "nginx_main.conf.tmp")
            if File.exist?(nginx_conf_tmp)
              puts "Cleaning up temporary Nginx config: #{nginx_conf_tmp}" if ENV["MALT_DEBUG"]
              remove_temp_config(nginx_conf_tmp)
            end

            # ポートごとの設定ファイル
            Dir.glob(File.join(Dir.pwd, "malt", "conf", "nginx_*.conf.tmp")).each do |tmp_file|
              puts "Cleaning up temporary Nginx config: #{tmp_file}" if ENV["MALT_DEBUG"]
              remove_temp_config(tmp_file)
            end
          end
        else
          puts "[Stopped] Nginx is not running"
        end
      end
    end

    # Apache service class
    class HttpdService < BaseService
      def start(config)
        config.ports["httpd"].each do |port|
          start_httpd(config, port)
        end
      end

      def stop(config)
        config.ports["httpd"].each do |port|
          stop_httpd(config, port)
        end
      end

      private

      def start_httpd(config, port)
        # ポートが既に使用中かチェック
        if port_in_use?(port)
          puts "[Running] Apache HTTPD on port #{port}"
          return
        end

        puts "Starting Apache HTTPD on port #{port}..."

        httpd_conf = File.join(config.conf_dir, "httpd_#{port}.conf")

        # デバッグ出力設定を保存
        old_debug = ENV["MALT_DEBUG"]

        # 設定ファイルを変数展開して一時ファイルを作成
        temp_conf = create_temp_config(config, httpd_conf)

        # デバッグ設定を元に戻す
        ENV["MALT_DEBUG"] = old_debug

        # 一時ファイルの生成に失敗した場合は元のファイルを使用
        if temp_conf.nil?
          puts "Failed to create temporary config file, using original config"
          temp_conf = httpd_conf
        end

        if temp_conf
          # 一時ファイルの存在を確認
          if !File.exist?(temp_conf)
            puts "Error: Apache HTTPD config temp file not found at: #{temp_conf}"
            puts "Using original config file instead"
            temp_conf = httpd_conf
          end

          # 一時ファイルを使用して起動
          cmd = "#{HOMEBREW_PREFIX}/bin/httpd -f #{temp_conf}"
          puts "Running command: #{cmd}"
          system("#{cmd} &")
          puts "Apache HTTPD starting in background..."
        end
      end

      def stop_httpd(config, port)
        # まずポートが使用中かチェック（サービスが実行中かどうか）
        if !port_in_use?(port)
          puts "[Stopped] Apache HTTPD is not running on port #{port}"

          # 一時ファイルのクリーンアップ
          httpd_conf_tmp = File.join(config.malt_dir, "conf", "httpd_#{port}.conf.tmp")
          if !ENV["MALT_DEBUG"] && File.exist?(httpd_conf_tmp)
            puts "Cleaning up temporary Apache config: #{httpd_conf_tmp}" if ENV["MALT_DEBUG"]
            remove_temp_config(httpd_conf_tmp)
          end

          return # サービスが実行されていなければここで終了
        end

        puts "Stopping Apache HTTPD on port #{port}..."

        # 関連する一時設定ファイルのパス
        httpd_conf_tmp = File.join(config.malt_dir, "conf", "httpd_#{port}.conf.tmp")
        original_conf = File.join(config.conf_dir, "httpd_#{port}.conf")

        # 一時ファイルが存在しない場合は作成する (変数置換されたファイルが必要)
        if !File.exist?(httpd_conf_tmp)
          puts "Temporary config file not found, creating one for stop operation..." if ENV["MALT_DEBUG"]
          temp_conf = create_temp_config(config, original_conf)
          if temp_conf.nil?
            puts "Warning: Could not create temporary config file for stopping Apache"
            # 停止を試みる代替手段
            system("pkill -f 'httpd.*#{port}'")
            return
          end
          httpd_conf_tmp = temp_conf
        end

        # apachectlを使用してApacheを停止（出力をリダイレクト）
        cmd = "#{HOMEBREW_PREFIX}/bin/apachectl -f #{httpd_conf_tmp} -k stop > /dev/null 2>&1 &"
        puts "Running command: #{cmd}" if ENV["MALT_DEBUG"]

        # 停止コマンドを実行
        system(cmd)

        if port_in_use?(port)
          puts "Stopping Apache HTTPD on port #{port}..."

          # 短い待機を追加して停止が処理されるのを待つ
          sleep 0.5

          # ポートが解放されたかチェック
          if port_in_use?(port)
            puts "Warning: Apache might still be running, attempting fallback..."
            system("pkill -f 'httpd.*#{port}' > /dev/null 2>&1")
          else
            puts "Apache HTTPD stopped successfully."
          end
        else
          puts "Apache HTTPD stopped."
        end

        # 一時ファイルのクリーンアップ
        if !ENV["MALT_DEBUG"] && File.exist?(httpd_conf_tmp)
          puts "Cleaning up temporary Apache config: #{httpd_conf_tmp}" if ENV["MALT_DEBUG"]
          remove_temp_config(httpd_conf_tmp)
        end
      end
    end
  end
end
