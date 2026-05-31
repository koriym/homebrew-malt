class Malt < Formula
  desc "JSON-driven Homebrew Dev Services"
  homepage "https://github.com/koriym/homebrew-malt"
  version "1.0.0beta10"
  url "file:///dev/null"

  depends_on "jq"

  def install
    local_path = File.expand_path(File.dirname(__FILE__) + '/..')
    ohai "Installing malt..."

    # Copy lib files
    (lib / "malt").mkpath
    cp_r Dir["#{local_path}/lib/*"], lib / "malt"

    #Copy share files
    (share / "malt").mkpath
    cp_r Dir["#{local_path}/share/*"], share / "malt"

    # Copy bin/malt and replace HOMEBREW_PREFIX, MALT_SHARE_PATH, MALT_LIB_PATH
    bin_file = bin / "malt"
    bin_content = File.read("#{local_path}/bin/malt.rb")
    bin_content.gsub!(/MALT_IS_LOCAL = true/, "MALT_IS_LOCAL = false")
    # Runtime paths must point at the installed keg, not the tap checkout.
    bin_content.gsub!(/{{MALT_LIB_PATH}}/, (lib / "malt").to_s)
    bin_content.gsub!(/{{MALT_SHARE_PATH}}/, (share / "malt").to_s)
    bin_content.gsub!(/{{MALT_CONFIG_PATH}}/, (share / "malt" / "default.json").to_s)
    bin_content.gsub!(/{{MALT_TEMPLATES_PATH}}/, (share / "malt" / "templates").to_s)
    bin_file.write bin_content
    if File.exist?(bin_file)
      chmod 0755, bin_file
    else
      odie "Failed to write bin file: #{bin_file}"
    end

    ohai "Full installation completed at #{prefix}"
  end

  def post_install
    puts "\n"
    puts "🍺 Malt has been brewed successfully! 🍺"
    puts "\n"
    puts "Get started with your project:"
    puts "  🍺 1. #{Tty.bold}cd /path/to/your-project#{Tty.reset}"
    puts "  🍺 2. #{Tty.bold}malt init#{Tty.reset}     # Creates your project's malt.json"
    puts "  🍺 3. #{Tty.bold}malt install#{Tty.reset}  # Installs dependencies"
    puts "  🍺 4. #{Tty.bold}malt create#{Tty.reset}   # Generates service configs"
    puts "  🍺 5. #{Tty.bold}malt start#{Tty.reset}    # Starts your environment"
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
