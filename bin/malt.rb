#!/usr/bin/env ruby

HOMEBREW_PREFIX = `brew --prefix`.strip

# Replace MAL_IS_LOCAL with the actual value by the installer
# Or you can run directly in the local file (eg, `ruby bin/malt.rb`)
MALT_IS_LOCAL = true

# If MALT_IS_LOCAL is not set, use the local files
if MALT_IS_LOCAL
  repo_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
  $LOAD_PATH.unshift(File.join(repo_root, "lib"))
  MALT_SHARE_PATH = "#{repo_root}/share"
  MALT_CONFIG_PATH = "#{repo_root}/share/default.json"
  MALT_TEMPLATES_PATH = "#{repo_root}/share/templates"
else
  MALT_SHARE_PATH = "{{MALT_SHARE_PATH}}"
  MALT_CONFIG_PATH = "{{MALT_CONFIG_PATH}}"
  MALT_TEMPLATES_PATH = "{{MALT_TEMPLATES_PATH}}"
  $LOAD_PATH.unshift("{{MALT_LIB_PATH}}")
end

# 必要なライブラリを読み込み
require 'optparse'
require 'json'
require 'fileutils'
require 'config'
require 'project'
require 'template'
require 'service_manager'

# デフォルトのオプション
options = {
  config: nil,
  verbose: false,
  debug: false
}

# サブコマンドとオプションの解析
command = ARGV.shift

# ヘルプメッセージ
def show_help
  puts "Malt - JSON-driven development environment manager"
  puts ""
  puts "Usage: malt COMMAND [OPTIONS]"
  puts ""
  puts "Commands:"
  puts "  init                   Initialize a new malt.json file"
  puts "  install                Install dependencies from malt.json"
  puts "  create                 Create malt environment in project directory"
  puts "  start                  Start services"
  puts "  stop                   Stop services"
  puts "  source <(malt env)     Set up service paths"
  puts "  info                   Show information about the current project"
  puts "  help                   Show this help message"
  puts ""
  puts "Options:"
  puts "  --config=FILE, -c      Specify a config file (default: ./malt.json)"
  puts "  --verbose, -v          Verbose output"
  puts "  --debug, -d            Debug mode"
  puts "  --help, -h             Show this help message"
end

# オプションの解析
OptionParser.new do |opts|
  opts.on("-c", "--config=FILE", "Specify config file") do |file|
    options[:config] = file
  end

  opts.on("-v", "--verbose", "Verbose output") do
    options[:verbose] = true
  end

  opts.on("-d", "--debug", "Debug mode (keep temp files and show debug info)") do
    options[:debug] = true
    ENV["MALT_DEBUG"] = "1"
  end

  opts.on("-h", "--help", "Show help") do
    show_help
    exit
  end
end.parse!(ARGV)

# コマンドが指定されていない場合はヘルプを表示
if command.nil? || command == "help"
  show_help
  exit
end

# デフォルトの設定ファイルパス
options[:config] ||= File.join(Dir.pwd, 'malt.json')

# プロジェクトの初期化
begin
  case command
  when "init"
    Malt::Project.init(options)
  when "install"
    Malt::Project.install_deps(options)
  when "create"
    Malt::Project.create(options)
  when "start"
    Malt::ServiceManager.start(options)
  when "stop"
    Malt::ServiceManager.stop(options)
  when "env"
    puts Malt::Project.env_script(options)
  when "info"
    Malt::Project.info(options)
  else
    puts "Unknown command: #{command}"
    puts "Run 'malt help' for usage information."
    exit 1
  end
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace if options[:verbose]
  exit 1
end
