class Malt < Formula
  desc "JSON-driven Homebrew Dev Services"
  homepage "https://github.com/koriym/homebrew-malt"
  version "1.0.0beta2"
  url "https://github.com/koriym/homebrew-malt/archive/refs/tags/1.0.0beta2.tar.gz"
  sha256 "d265998aafceee5a9053f4bc15c237ae9c41d0e011bd72a0ea82546e6abf2d2e"

  depends_on "jq"

  def install
    # タップのパス
    tap_path = Tap.fetch("koriym/malt").path
    puts("tap_path: #{__FILE__}")
    # ローカル開発用にカレントディレクトリを考慮
    local_path = File.expand_path(File.dirname(__FILE__) + '/..')
    is_local_install = File.exist?("#{local_path}/README.md")
    source_root = is_local_install ? local_path : tap_path
    ohai "Installing malt..."
    puts("is_local_install: #{is_local_install}")

    # Copy lib files
    (lib / "malt").mkpath
    cp_r Dir["#{source_root}/lib/*"], lib / "malt"
    puts("lib copied: #{source_root}/lib/*")

    #Copy share files
    (share / "malt").mkpath
    cp_r Dir["#{source_root}/share/*"], share / "malt"
    puts("share copied: #{source_root}/share/*")

    # Copy bin/malt and replace HOMEBREW_PREFIX, MALT_SHARE_PATH, MALT_LIB_PATH
    bin_file = bin / "malt"
    root_dir = is_local_install ? local_path : tap_path
    bin_content = File.read("#{root_dir}/bin/malt.rb")

    bin_content.gsub!(/{{MALT_IS_LOCAL}}/, "#{is_local_install}")
    bin_content.gsub!(/{{MALT_LIB_PATH}}/, "#{root_dir}/lib")
    bin_content.gsub!(/{{MALT_SHARE_PATH}}/, "#{root_dir}/share")
    bin_content.gsub!(/{{MALT_TEMPLATES_PATH}}/, "#{root_dir}/share/templates")
    bin_file.write bin_content
    chmod 0755, bin_file
    puts("bin copied: #{bin_file}")

    ohai "Full installation completed at #{prefix}"
  end

  def post_install
    puts "\n"
    puts "🍺 Malt has been brewed successfully! 🍺"
    puts "\n"
    puts "Get started with your project in 3 simple steps:"
    puts "  🍺 1. #{Tty.bold}cd /path/to/your-project#{Tty.reset}"
    puts "  🍺 2. #{Tty.bold}malt init#{Tty.reset}     # Creates your project's malt.json"
    puts "  🍺 3. #{Tty.bold}malt start#{Tty.reset}    # Sets up and starts your environment"
    puts "\n"
    puts "Need help? Run #{Tty.bold}malt help#{Tty.reset} for all available commands"
    puts "Full documentation: #{Tty.underline}https://github.com/koriym/homebrew-malt#{Tty.reset}"
  end

  def caveats
    <<~EOS
    For documentation and examples, check the README:
    https://github.com/koriym/homebrew-malt
  EOS
  end
  test do
    ohai "Development mode - skipping test"
  end
end
