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

  test do
    assert_match "phpcomplete installation successful", shell_output("cat #{prefix}/INSTALLED")
  end
end
