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

# Load required libraries
require 'optparse'
require 'json'
require 'fileutils'
require 'config'
require 'project'
require 'template'
require 'service_manager'

# Default options
options = {
  config: nil,
  verbose: false,
  debug: false
}

# Parse subcommand and options
command = ARGV.shift

# Help message
def show_help
  puts "Malt - JSON-driven development environment manager"
  puts ""
  puts "Usage: malt COMMAND [OPTIONS]"
  puts ""
  puts "Commands:"
  puts "  init                   Initialize a new malt.json file"
  puts "  install                Install dependencies from malt.json"
  puts "  create                 Create malt environment in project directory"
  puts "  start                  Start services configured in malt.json"
  puts "  stop                   Stop services configured in malt.json"
  puts "  kill                   Forcibly stop all services (not limited to malt.json config)"
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

# Parse options
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

# Show help if no command is specified
if command.nil? || command == "help"
  show_help
  exit
end

# Default config file path
options[:config] ||= File.join(Dir.pwd, 'malt.json')

# Initialize project
begin
  case command
  when "init"
    Malt::Project.init(options)
  when "install"
    Malt::Project.install_deps(options)
  when "create"
    Malt::Project.create(options)
  when "start"
    # Determine the expected malt directory path based on the current directory
    malt_dir_path = File.join(Dir.pwd, 'malt')

    # Check if the malt directory exists
    unless Dir.exist?(malt_dir_path)
      warn "Warning: Malt directory '#{malt_dir_path}' not found."
      warn "Please run `malt create` first to generate configuration files."
      exit 1 # Exit with a non-zero status
    end

    # If the directory exists, proceed with starting services
    Malt::ServiceManager.start(options)
  when "stop"
    Malt::ServiceManager.stop(options)
  when "kill"
    Malt::ServiceManager.kill(options)
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
