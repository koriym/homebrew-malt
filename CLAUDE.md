# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Malt is a JSON-driven development environment manager that creates project-specific development environments using Homebrew. It's a lightweight alternative to Docker for local development, focusing on native performance while maintaining project isolation through port-based separation.

## Architecture

### Core Components

- **bin/malt.rb** - Main CLI entry point. `MALT_IS_LOCAL = true` flag enables running from source; the Formula replaces this with `false` and substitutes path placeholders at install time.
- **lib/config.rb** - `Malt::Config` parses `malt.json`. `validate!` requires `php` ports even for non-PHP projects.
- **lib/project.rb** - Project setup: `init`, `install_deps`, `create`, `env_script`, `info`. Contains `resolve_extension_path` for PHP extension `.so` lookup.
- **lib/service_manager.rb** - Orchestrates start/stop/kill/status. Services start in declaration order, stop in reverse.
- **lib/template.rb** - `Malt::Template` renders files with `{{VARIABLE}}` substitution. Despite `.erb` extensions, templates do NOT use ERB (`<%= %>`).
- **lib/services/** - Individual service classes (`PhpService`, `MysqlService`, `RedisService`, `MemcachedService`, `NginxService`, `HttpdService`) all inherit from `BaseService`.
- **share/templates/** - Template files (`.erb` extension) using `{{VARIABLE}}` placeholders for `malt create`.
- **share/default.json** - Default `malt.json` template. Schema at `docs/schema.json`.

### Two-Phase Variable Substitution

Config generation happens in two phases:

1. **`malt create`** (Project.generate_config_files): Renders ERB templates with port/index values resolved immediately. Runtime variables (`{{MALT_DIR}}`, `{{HOMEBREW_PREFIX}}`, `{{PHP_VERSION}}`, `{{PROJECT_DIR}}`) are written as literal `{{VARIABLE}}` strings into the output files in `malt/conf/`.

2. **`malt start`** (BaseService.create_temp_config): Reads conf files from `malt/conf/`, expands the remaining `{{VARIABLE}}` placeholders with actual runtime values, and writes `.tmp` files (e.g., `nginx_80.conf.tmp`). These `.tmp` files are passed to the actual service processes. Cleanup happens on `malt stop` unless `MALT_DEBUG=1`.

### Key Implementation Details

- `HOMEBREW_PREFIX` is resolved once at load time: `ENV["HOMEBREW_PREFIX"] || \`brew --prefix\`.chomp`
- MySQL version is **hardcoded to `8.0`** in `mysql_service.rb` (initialization and startup commands). PHP version is read from `dependencies` (defaults to `8.4`).
- PHP extension `.so` paths are resolved by `resolve_extension_path`: tries `{ext}@{php_version}`, `php{ext}@{php_version}`, `php-{ext}@{php_version}` under `HOMEBREW_PREFIX/opt/`.
- Port-in-use check: `lsof` on macOS, `ss` on Linux.
- Multiple instances of a service run on different ports (e.g., `"php": [9000, 9001]`).
- Nginx uses a main config (`nginx_main.conf`) that includes per-port `.conf.tmp` files.
- MySQL requires data directory initialization on first start (`--initialize-insecure`). Each MySQL instance gets its own data dir `malt/var/mysql_{index}/`.

## Development Commands

### Running Malt Locally (Development Mode)

```bash
# Run malt directly from source (MALT_IS_LOCAL = true in bin/malt.rb)
ruby bin/malt.rb init
ruby bin/malt.rb install
ruby bin/malt.rb create
ruby bin/malt.rb start
ruby bin/malt.rb stop
ruby bin/malt.rb status
```

### Debugging

```bash
# Keep .tmp files and show variable substitution details
MALT_DEBUG=1 ruby bin/malt.rb start
```

### Testing the Homebrew Formula

```bash
brew install --build-from-source Formula/malt.rb
brew reinstall malt
```

## Malt Workflow

1. **malt init** - Creates `malt.json` from `share/default.json`
2. **malt install** - Installs Homebrew packages and PHP extensions listed in `malt.json`
3. **malt create** - Creates `malt/` directory, generates service configs from templates (phase 1 substitution)
4. **malt start** - Expands runtime variables into `.tmp` configs and starts services (phase 2 substitution)
5. **malt stop** - Stops services and removes `.tmp` files
6. **malt kill** - Force-kills all recognized service processes (SIGKILL), ignores `malt.json`
7. **malt status** - Shows running/stopped state per port
8. **malt env** - Outputs shell script (`source <(malt env)`) to set `MALT_DIR`, `DOCUMENT_ROOT`, `PATH`, and CLI aliases for MySQL/Redis

## Adding a New Service

1. Create template files in `share/templates/[service]/` using `{{VARIABLE}}` syntax
2. Add service class in `lib/services/[service]_service.rb` inheriting from `BaseService`
3. Add `require_relative` in `lib/service_manager.rb` and register in `register_services`
4. Add generation logic in `lib/project.rb` (`generate_config_files` and its helpers)
5. Add entry to `SERVICES` hash in `service_manager.rb` for kill/status support
6. Update `share/default.json` and `docs/schema.json`
