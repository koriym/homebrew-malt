class Malt < Formula
  desc "JSON-driven Homebrew Dev Services"
  homepage "https://github.com/koriym/homebrew-malt"
  version "1.0.0beta4"
  url "file:///dev/null"

  depends_on "jq"

  def install
    # タップのパス
    tap_path = Tap.fetch("koriym/malt").path
    puts("tap_path: #{__FILE__}")
    # ローカル開発用にカレントディレクトリを考慮
    local_path = File.expand_path(File.dirname(__FILE__) + '/..')
    puts("local_path: #{local_path}")
    puts("tap_path: #{tap_path}")
    ohai "Installing malt..."

    # Copy lib files
    (lib / "malt").mkpath
    cp_r Dir["#{tap_path}/lib/*"], lib / "malt"
    puts("lib copied: #{tap_path}/lib/*")

    #Copy share files
    (share / "malt").mkpath
    cp_r Dir["#{tap_path}/share/*"], share / "malt"
    puts("share copied: #{tap_path}/share/*")

    # Copy bin/malt and replace HOMEBREW_PREFIX, MALT_SHARE_PATH, MALT_LIB_PATH
    bin_file = bin / "malt"
    bin_content = File.read("#{tap_path}/bin/malt.rb")

    bin_content.gsub!(/MALT_IS_LOCAL = true/, "MALT_IS_LOCAL = false")
    # Set with the tap path
    bin_content.gsub!(/{{MALT_LIB_PATH}}/, "#{tap_path}/lib")
    bin_content.gsub!(/{{MALT_SHARE_PATH}}/, "#{tap_path}/share")
    bin_content.gsub!(/{{MALT_CONFIG_PATH}}/, "#{tap_path}/share/default.json")
    bin_content.gsub!(/{{MALT_TEMPLATES_PATH}}/, "#{tap_path}/share/templates")
    bin_file.write bin_content
    if File.exist?(bin_file)
      chmod 0755, bin_file
    else
      odie "Failed to write bin file: #{bin_file}"
    end
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
