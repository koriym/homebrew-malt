class Phpcomplete < Formula
  desc "Install multiple versions of PHP with XDebug"
  homepage "https://www.php.net/"
  version "0.2.0"
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
  depends_on "shivammathur/php/php@8.5"

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
  depends_on "shivammathur/extensions/xdebug@8.5"

  def install
    (prefix/"INSTALLED").write "phpcomplete installation successful"
  end

  def caveats
    <<~EOS
  Multiple PHP versions have been installed. To use a specific version, you can:

  1. Create shell aliases (add to your .bashrc or .zshrc):
     ```shell
     # Switch PHP version for current session (changes PATH)
     alias sphp56='export PATH="/opt/homebrew/opt/php@5.6/bin:$PATH" && echo "Switched to PHP 5.6"'
     alias sphp70='export PATH="/opt/homebrew/opt/php@7.0/bin:$PATH" && echo "Switched to PHP 7.0"'
     alias sphp71='export PATH="/opt/homebrew/opt/php@7.1/bin:$PATH" && echo "Switched to PHP 7.1"'
     alias sphp72='export PATH="/opt/homebrew/opt/php@7.2/bin:$PATH" && echo "Switched to PHP 7.2"'
     alias sphp73='export PATH="/opt/homebrew/opt/php@7.3/bin:$PATH" && echo "Switched to PHP 7.3"'
     alias sphp74='export PATH="/opt/homebrew/opt/php@7.4/bin:$PATH" && echo "Switched to PHP 7.4"'
     alias sphp80='export PATH="/opt/homebrew/opt/php@8.0/bin:$PATH" && echo "Switched to PHP 8.0"'
     alias sphp81='export PATH="/opt/homebrew/opt/php@8.1/bin:$PATH" && echo "Switched to PHP 8.1"'
     alias sphp82='export PATH="/opt/homebrew/opt/php@8.2/bin:$PATH" && echo "Switched to PHP 8.2"'
     alias sphp83='export PATH="/opt/homebrew/opt/php@8.3/bin:$PATH" && echo "Switched to PHP 8.3"'
     alias sphp84='export PATH="/opt/homebrew/opt/php@8.4/bin:$PATH" && echo "Switched to PHP 8.4"'
     alias sphp85='export PATH="/opt/homebrew/opt/php@8.5/bin:$PATH" && echo "Switched to PHP 8.5"'

     # Run specific PHP version directly (without changing PATH)
     alias php56='/opt/homebrew/opt/php@5.6/bin/php'
     alias php70='/opt/homebrew/opt/php@7.0/bin/php'
     alias php71='/opt/homebrew/opt/php@7.1/bin/php'
     alias php72='/opt/homebrew/opt/php@7.2/bin/php'
     alias php73='/opt/homebrew/opt/php@7.3/bin/php'
     alias php74='/opt/homebrew/opt/php@7.4/bin/php'
     alias php80='/opt/homebrew/opt/php@8.0/bin/php'
     alias php81='/opt/homebrew/opt/php@8.1/bin/php'
     alias php82='/opt/homebrew/opt/php@8.2/bin/php'
     alias php83='/opt/homebrew/opt/php@8.3/bin/php'
     alias php84='/opt/homebrew/opt/php@8.4/bin/php'
     alias php85='/opt/homebrew/opt/php@8.5/bin/php'
     ```

  2. Usage examples:
     # Switch session to PHP 8.2
     sphp82
     php -v      # Now using PHP 8.2

     # Run PHP 7.4 directly (one-time)
     php74 -v    # Shows PHP 7.4 version
     php74 script.php

  For more detailed instructions, see:
  https://github.com/koriym/homebrew-malt/phpcomplete/
  EOS
  end

  test do
    assert_match "phpcomplete installation successful", shell_output("cat #{prefix}/INSTALLED")
  end
end
