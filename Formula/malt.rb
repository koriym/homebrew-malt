class Malt < Formula
  desc "JSON-driven Homebrew Dev Services"
  homepage "https://github.com/koriym/homebrew-malt"
  version "1.0.0beta1"
  url "file:///dev/null"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  depends_on "jq"

  def install
    # タップのパス
    tap_path = Tap.fetch("koriym/malt").path
    # ローカル開発用にカレントディレクトリを考慮
    local_path = File.expand_path(File.dirname(__FILE__) + '/..')
    is_local_install = File.exist?("#{local_path}/share/malt/default.json")
    ohai "Installing malt..."

    # ライブラリファイルをコピー - libディレクトリを確実に作成
    (lib / "malt").mkpath
    lib_source = is_local_install ? "#{local_path}/lib/malt" : "#{tap_path}/lib/malt"
    puts("lib_source: #{lib_source}")
    cp_r Dir["#{lib_source}/*"], lib / "malt"

    # デバッグ出力
    system "ls", "-la", lib / "malt"

    # share/malt ディレクトリを作成
    (share / "malt").mkpath
    # ローカルインストール時はローカルパスを優先、タップ時はタップパスを使用
    default_json_source = is_local_install ? "#{local_path}/share/malt/default.json" : "#{tap_path}/share/malt/default.json"
    puts("default_json_source: #{default_json_source}")
    if File.exist?(default_json_source)
      cp default_json_source, share / "malt"
    else
      raise "default.json not found at #{default_json_source}"
    end

    # テンプレートディレクトリをコピー
    (share / "malt/templates").mkpath
    templates_source = is_local_install ? "#{local_path}/templates" : "#{tap_path}/templates"

    puts("templates_source: #{templates_source}")
    if Dir.exist?(templates_source)
      cp_r Dir["#{templates_source}/*"], share / "malt/templates"
    else
      raise "Templates directory not found at #{templates_source}"
    end
    puts("templates copied")

    # bin/maltをコピーして修正
    bin_file = bin / "malt"
    bin_content = is_local_install ? File.read("#{local_path}/bin/malt") : File.read("#{tap_path}/bin/malt")
    puts("templates copied")

    bin_content.gsub!(/HOMEBREW_PREFIX = "{HOMEBREW_PREFIX_PLACEHOLDER}"/, "HOMEBREW_PREFIX = \"#{HOMEBREW_PREFIX}\"")
    bin_content.gsub!(/MALT_SHARE_PATH = "{MALT_SHARE_PATH_PLACEHOLDER}"/, "MALT_SHARE_PATH = \"#{share}/malt\"")
    bin_content.gsub!(/MALT_TEMPLATES_PATH = "{MALT_TEMPLATES_PATH_PLACEHOLDER}"/, "MALT_TEMPLATES_PATH = \"#{share}/malt/templates\"")

    bin_content.sub!(/# 開発環境では.*?end/m, <<~RUBY
      # Homebrew環境のパスを設定
      if HOMEBREW_PREFIX == "{HOMEBREW_PREFIX_PLACEHOLDER}"
        repo_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
        $LOAD_PATH.unshift(File.join(repo_root, "lib"))
      else
        # Cellarのlibディレクトリを直接指定
        cellar_lib = "#{prefix}/lib"
        $LOAD_PATH.unshift(File.join(cellar_lib, "malt"))
        $LOAD_PATH.unshift(cellar_lib)
        
        # デバッグ用にLOAD_PATHを表示
        if ENV["MALT_DEBUG"]
          puts "LOAD_PATH:"
          $LOAD_PATH.each { |path| puts "  - \#{path}" }
        end
      end
    RUBY
    )

    bin_content.gsub!(/share_path = File\.join\(HOMEBREW_PREFIX, "share", "malt"\)/, "share_path = \"#{share}/malt\"")

    bin_file.write bin_content
    chmod 0755, bin_file

    ohai "Full installation completed at #{prefix}"
  end

  def post_install
    ohai "Malt: Installation completed!"
    ohai "Run 'malt help' for usage information"
  end

  def caveats
    <<~EOS
      Malt has been installed!
      
      To use it:
        cd /path/to/your-project
        malt init          # Initialize a project (creates malt.json)
        malt install       # Install dependencies from malt.json
        malt create        # Create environment files
        malt start         # Start services
        malt stop          # Stop services
        malt info          # Project information
        
      Run `malt help` for more information.
    EOS
  end

  test do
    ohai "Development mode - skipping test"
  end
end
