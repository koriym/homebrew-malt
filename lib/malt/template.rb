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

        # {{変数名}}形式の変数を置換
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