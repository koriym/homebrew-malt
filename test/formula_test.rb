# frozen_string_literal: true

require_relative "test_helper"

class FormulaTest < Minitest::Test
  def setup
    @formula = File.read(File.expand_path("../Formula/malt.rb", __dir__))
  end

  def test_formula_substitutes_installed_keg_paths
    assert_includes @formula, 'bin_content.gsub!(/{{MALT_LIB_PATH}}/, (lib / "malt").to_s)'
    assert_includes @formula, 'bin_content.gsub!(/{{MALT_SHARE_PATH}}/, (share / "malt").to_s)'
    assert_includes @formula, 'bin_content.gsub!(/{{MALT_CONFIG_PATH}}/, (share / "malt" / "default.json").to_s)'
    assert_includes @formula, 'bin_content.gsub!(/{{MALT_TEMPLATES_PATH}}/, (share / "malt" / "templates").to_s)'
  end

  def test_formula_copies_lib_and_share_from_local_checkout
    assert_includes @formula, 'cp_r Dir["#{local_path}/lib/*"], lib / "malt"'
    assert_includes @formula, 'cp_r Dir["#{local_path}/share/*"], share / "malt"'
    refute_includes @formula, "Tap.fetch"
  end

  def test_formula_post_install_includes_create_step
    assert_includes @formula, "malt install"
    assert_includes @formula, "malt create"
    assert_includes @formula, "malt start"
  end
end
