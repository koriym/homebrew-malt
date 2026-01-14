# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "json"

# Add lib to load path
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "config"
require "service_manager"
