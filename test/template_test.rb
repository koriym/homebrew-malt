# frozen_string_literal: true

require_relative "test_helper"
require "template"

class TemplateTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("malt_test")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def create_template(content)
    path = File.join(@temp_dir, "test.conf.erb")
    File.write(path, content)
    path
  end

  def test_initialize_reads_template_file
    path = create_template("hello")

    template = Malt::Template.new(path)

    assert_instance_of Malt::Template, template
  end

  def test_initialize_raises_for_missing_file
    assert_raises RuntimeError do
      Malt::Template.new("/nonexistent/template.erb")
    end
  end

  def test_render_substitutes_variables
    path = create_template("listen {{PORT}}\nroot {{MALT_DIR}}")

    template = Malt::Template.new(path)
    result = template.render({ PORT: 9000, MALT_DIR: "/path/to/malt" })

    assert_equal "listen 9000\nroot /path/to/malt", result
  end

  def test_render_with_no_variables
    path = create_template("static content")

    template = Malt::Template.new(path)
    result = template.render

    assert_equal "static content", result
  end

  def test_render_preserves_unmatched_placeholders
    path = create_template("{{PORT}} and {{UNKNOWN}}")

    template = Malt::Template.new(path)
    result = template.render({ PORT: 8080 })

    assert_equal "8080 and {{UNKNOWN}}", result
  end

  def test_render_converts_values_to_string
    path = create_template("port={{PORT}}")

    template = Malt::Template.new(path)
    result = template.render({ PORT: 9000 })

    assert_equal "port=9000", result
  end

  def test_render_does_not_mutate_template
    path = create_template("{{PORT}}")

    template = Malt::Template.new(path)
    result1 = template.render({ PORT: 9000 })
    result2 = template.render({ PORT: 8080 })

    assert_equal "9000", result1
    assert_equal "8080", result2
  end

  def test_render_handles_multiple_occurrences
    path = create_template("{{PORT}} and {{PORT}} again")

    template = Malt::Template.new(path)
    result = template.render({ PORT: 9000 })

    assert_equal "9000 and 9000 again", result
  end
end
