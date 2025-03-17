module Malt
  class Template
    def initialize(template_path)
      unless File.exist?(template_path)
        raise "Template file not found: #{template_path}"
      end

      begin
        @template = File.read(template_path)
        @template_path = template_path
      rescue => e
        raise "Error reading template file #{template_path}: #{e.message}"
      end
    end

    def render(variables = {})
      begin
        result = @template.dup

        # Replace variables in {{variable_name}} format
        variables.each do |key, value|
          result.gsub!(/\{\{#{key}\}\}/, value.to_s)
        end

        result
      rescue => e
        raise "Error rendering template #{@template_path}: #{e.message}"
      end
    end
  end
end