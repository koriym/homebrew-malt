class Phpcomplete < Formula
  desc "Install multiple versions of PHP with XDebug"
  homepage "https://www.php.net/"
  version "0.1.0"
  url "file:///dev/null"
  sha256 ""
  license "MIT"

  # Please comment out any unnecessary PHP versions.
  depends_on "shivammathur/php/php@5.6"
  depends_on "shivammathur/php/php@7.0"
  depends_on "shivammathur/php/php@7.1"
  depends_on "shivammathur/php/php@7.2"
  depends_on "shivammathur/php/php@7.3"
  depends_on "shivammathur/php/php@7.4"
  depends_on "shivammathur/php/php@8.0"
  depends_on "shivammathur/php/php@8.1"
  depends_on "shivammathur/php/php@8.2"
  depends_on "shivammathur/php/php@8.3"
  depends_on "shivammathur/php/php@8.4"

  # See full list here: https://github.com/shivammathur/homebrew-extensions
  depends_on "shivammathur/extensions/xdebug@5.6"
  depends_on "shivammathur/extensions/xdebug@7.0"
  depends_on "shivammathur/extensions/xdebug@7.1"
  depends_on "shivammathur/extensions/xdebug@7.2"
  depends_on "shivammathur/extensions/xdebug@7.3"
  depends_on "shivammathur/extensions/xdebug@7.4"
  depends_on "shivammathur/extensions/xdebug@8.0"
  depends_on "shivammathur/extensions/xdebug@8.1"
  depends_on "shivammathur/extensions/xdebug@8.2"
  depends_on "shivammathur/extensions/xdebug@8.3"
  depends_on "shivammathur/extensions/xdebug@8.4"

  def install
    (prefix/"INSTALLED").write "phpcomplete installation successful"
  end

  def caveats
    <<~EOS
  Multiple PHP versions have been installed. To use a specific version, you can:

  1. Create shell aliases (add to your .bashrc or .zshrc):
     ```shell
     alias php56='export PATH="/opt/homebrew/opt/php@5.6/bin:$PATH" && echo "Switched to PHP 5.6"'
     alias php70='export PATH="/opt/homebrew/opt/php@7.0/bin:$PATH" && echo "Switched to PHP 7.0"'
     alias php71='export PATH="/opt/homebrew/opt/php@7.1/bin:$PATH" && echo "Switched to PHP 7.1"'
     alias php72='export PATH="/opt/homebrew/opt/php@7.2/bin:$PATH" && echo "Switched to PHP 7.2"'
     alias php73='export PATH="/opt/homebrew/opt/php@7.3/bin:$PATH" && echo "Switched to PHP 7.3"'
     alias php74='export PATH="/opt/homebrew/opt/php@7.4/bin:$PATH" && echo "Switched to PHP 7.4"'
     alias php80='export PATH="/opt/homebrew/opt/php@8.0/bin:$PATH" && echo "Switched to PHP 8.0"'
     alias php81='export PATH="/opt/homebrew/opt/php@8.1/bin:$PATH" && echo "Switched to PHP 8.1"'
     alias php82='export PATH="/opt/homebrew/opt/php@8.2/bin:$PATH" && echo "Switched to PHP 8.2"'
     alias php83='export PATH="/opt/homebrew/opt/php@8.3/bin:$PATH" && echo "Switched to PHP 8.3"'
     alias php84='export PATH="/opt/homebrew/opt/php@8.4/bin:$PATH" && echo "Switched to PHP 8.4"'
     ```

  2. Use version switcher commands:
     php8.2
     php -v   # Now using PHP 8.2
     
     php7.4
     php -v   # Now using PHP 7.4

  For more detailed instructions, see:
  https://github.com/koriym/homebrew-malt/phpcpmplete/
  EOS
  end

  test do
    assert_match "phpcomplete installation successful", shell_output("cat #{prefix}/INSTALLED")
  end
end
