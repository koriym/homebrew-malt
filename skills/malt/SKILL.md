---
name: malt
description: Malt development environment manager. Use when setting up, starting, stopping, troubleshooting, or customizing Homebrew-based dev environments with malt.json.
---

# Malt - JSON-driven Homebrew Dev Services

Malt creates project-specific development environments using only Homebrew. Define your stack in `malt.json`, and Malt handles installation, configuration, and service management with native performance and port-based isolation.

## Command Reference

| Command | Description |
|---------|-------------|
| `malt init` | Create `malt.json` from default template (skips if exists) |
| `malt install` | Install Homebrew packages and PHP extensions from `malt.json` |
| `malt create` | Generate `malt/` directory with service configs (skips if exists) |
| `malt start` | Create temp configs with variable substitution and start services |
| `malt stop` | Stop services and clean up temp files |
| `malt status` | Show running status of all configured services |
| `malt kill` | Force-kill all Malt service processes (SIGKILL) |
| `malt env` | Output shell script for env vars and aliases. Usage: `source <(malt env)` |
| `malt info` | Show project name, directory, and configured ports |

## Setup Guide

### Setup Flow

#### When `composer.json` exists (PHP project)

1. Read `composer.json` to auto-detect requirements:

| Dependency Pattern | Service |
|-------------------|---------|
| `php` require constraint | PHP version (e.g., `^8.1` -> `php@8.1`) |
| `ext-redis` or `predis/predis` | Redis |
| `ext-memcached` | Memcached |
| `ext-pdo_mysql` or `doctrine/*` | MySQL |
| `.htaccess` file exists | Apache (`httpd`); otherwise Nginx |

2. Report detected dependencies and generate `malt.json`:

```text
Detected these external dependencies from composer.json. Adding to malt.json:
- PHP 8.4 (port: 9000)
- MySQL 8.0 (port: 3306)
- Redis (port: 6379)
- Nginx (port: 80)
- Extensions: xdebug, redis
```

3. Generate `malt.json` and run setup commands.

#### When `composer.json` does not exist

Ask the user what services they need in natural language. Example interactions:

- "MySQL and Redis are needed" -> generate `malt.json` with MySQL and Redis
- "Set up a PHP 8.4 environment with Nginx" -> generate accordingly

Then confirm the proposed `malt.json` with `AskUserQuestion` before proceeding.

### Setup Commands

```bash
cd your-project
malt init              # 1. Create malt.json
# Edit malt.json to match your project
malt install           # 2. Install Homebrew packages and PHP extensions
malt create            # 3. Generate malt/ directory with service configs
malt start             # 4. Start all configured services
source <(malt env)     # 5. Set up PATH, env vars, and aliases
```

## Joining Existing Project

For projects with `malt.json` already committed:

```bash
malt install && malt start && source <(malt env)
```

## malt.json Schema

All fields are required. Schema: `docs/schema.json`

```json
{
  "project_name": "myapp",
  "dependencies": [
    "php@8.4",
    "mysql@8.0",
    "composer",
    "redis",
    "nginx",
    "memcached"
  ],
  "ports": {
    "php": [9000],
    "mysql": [3306],
    "nginx": [80, 443],
    "httpd": [8080],
    "redis": [6379],
    "memcached": [11211]
  },
  "php_extensions": [
    "xdebug",
    "pcov",
    "redis",
    "memcached",
    "apcu"
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `project_name` | string | Project identifier |
| `dependencies` | string[] | Homebrew formula names (services, tools, PHP version) |
| `ports` | object | Service name -> port array. Keys: `php`, `mysql`, `nginx`, `httpd`, `redis`, `memcached`, `postgresql`. Multiple ports create multiple instances |
| `php_extensions` | string[] | PHP extensions to install via `shivammathur/extensions` tap |

## Troubleshooting Guide

### Port Already in Use

```bash
# Check what's using a port
lsof -i :PORT_NUMBER
# Kill process on port
kill -9 $(lsof -t -i :PORT_NUMBER)
```

Or change the port in `malt.json`, then `rm -rf malt/ && malt create && malt start`.

### MySQL First Start Fails

MySQL auto-initializes its data directory on first start (`--initialize-insecure`). If it fails:

```bash
rm -rf malt/var/mysql_*
malt start  # Will reinitialize
```

### PHP Extension Load Failure

Extensions are resolved from Homebrew opt directories. If an extension fails to load:

1. Check it's listed in `malt.json` `php_extensions`
2. Run `malt install` to ensure it's installed
3. Check `malt/conf/php.ini` for correct paths
4. Extension resolution order: `{HOMEBREW_PREFIX}/opt/{ext}@{php_version}/{ext}.so`, then `php{ext}@...`, then `php-{ext}@...`

### Service Won't Stop

```bash
malt kill  # Force-kill all Malt processes
```

### `malt create` Does Nothing

The `malt/` directory already exists. To regenerate:

```bash
rm -rf malt/
malt create
# Re-apply any customizations
```

### Debug Mode

```bash
MALT_DEBUG=1 malt start   # Keep temp files, show variable substitution details
MALT_DEBUG=1 malt stop
```

### Check Logs

Service logs are in `malt/logs/`:
- `php-fpm_9000.log`
- `mysql_3306_error.log`
- `nginx_error_80.log`
- `httpd_error_8080.log`

## Customization

Edit files in `malt/conf/` directly, then restart with `malt stop && malt start`.

### Change Document Root

Edit `root` in `malt/conf/nginx_*.conf`:

```nginx
root "{{PROJECT_DIR}}/webroot";  # instead of public
```

Or `DocumentRoot` in `malt/conf/httpd_*.conf`:

```apache
DocumentRoot "{{PROJECT_DIR}}/webroot"
<Directory "{{PROJECT_DIR}}/webroot">
```

### PHP Settings

Edit `malt/conf/php.ini`:

```ini
memory_limit = 512M
upload_max_filesize = 100M
post_max_size = 100M
display_errors = On
error_reporting = E_ALL
```

### Xdebug Configuration

Append to `malt/conf/php.ini`:

```ini
[xdebug]
xdebug.mode = debug,develop
xdebug.start_with_request = yes
xdebug.client_host = 127.0.0.1
xdebug.client_port = 9003
```

### MySQL Character Set

Edit `malt/conf/my_*.cnf`:

```ini
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
```

### Re-generating Configs

After changing `dependencies` or `ports` in `malt.json`:

```bash
malt install           # Install new dependencies
rm -rf malt/           # Remove old configs
malt create            # Regenerate
# Re-apply customizations
malt start
```

## Template Variables

Config files in `malt/conf/` use `{{VARIABLE}}` placeholders, expanded at `malt start` into `.tmp` files:

| Variable | Description | Example |
|----------|-------------|---------|
| `{{MALT_DIR}}` | Absolute path to malt/ directory | `/Users/dev/myapp/malt` |
| `{{PROJECT_DIR}}` | Absolute path to project root | `/Users/dev/myapp` |
| `{{HOMEBREW_PREFIX}}` | Homebrew installation prefix | `/opt/homebrew` |
| `{{PHP_VERSION}}` | PHP version from dependencies | `8.4` |
| `{{PORT}}` | Service port number | `9000` |
| `{{INDEX}}` | Zero-based index (multi-instance) | `0` |
| `{{PHP_EXTENSIONS}}` | Generated extension directives | `extension=...` |
| `{{NGINX_INCLUDES}}` | Generated include statements | `include ...;` |
| `{{PHP_PORT}}` | First configured PHP port | `9000` |
| `{{PHP_LIB_PATH}}` | Path to Apache PHP module | `/opt/homebrew/opt/php@8.4/...` |

## Directory Structure

```
your-project/
├── malt.json              # Environment definition (commit this)
├── malt/                  # Generated by malt create
│   ├── conf/              # Service config files (commit these)
│   │   ├── php-fpm_9000.conf
│   │   ├── php.ini
│   │   ├── nginx_80.conf
│   │   ├── nginx_main.conf
│   │   ├── httpd_8080.conf
│   │   ├── my_3306.cnf
│   │   ├── redis_6379.conf
│   │   ├── memcached_11211.conf
│   │   └── *.tmp           # Temporary files (gitignore)
│   ├── logs/               # Service log files (gitignore)
│   ├── tmp/                # Temporary/socket files (gitignore)
│   └── var/                # Data files like MySQL data (gitignore)
└── public/                 # Document root for web servers
```

### Recommended .gitignore

```text
malt/logs/
malt/tmp/
malt/var/
malt/conf/*.tmp
```

## Format Conversion

Use `malt.json` as Single Source of Truth to generate other formats.

### Mapping Table

| malt.json | Docker Compose | GitHub Actions | .env |
|-----------|----------------|----------------|------|
| `php@8.4` | `php:8.4-fpm` | `shivammathur/setup-php` php-version: 8.4 | `PHP_VERSION=8.4` |
| `mysql@8.0` | `mysql:8.0` | `services.mysql` image: mysql:8.0 | `MYSQL_PORT=3306` |
| `redis` | `redis:latest` | `services.redis` | `REDIS_PORT=6379` |
| `nginx` | `nginx:latest` | N/A | `NGINX_PORT=80` |
| `memcached` | `memcached:latest` | `services.memcached` | `MEMCACHED_PORT=11211` |

### Docker Compose

Read `malt.json` and generate `docker-compose.yml` mapping each service to its Docker image, ports from `ports`, and appropriate volumes.

### .env

Generate environment variables from `malt.json`: version numbers, ports, and `127.0.0.1` as host for all services.

### GitHub Actions

Generate CI workflow using `shivammathur/setup-php` for PHP and GitHub Actions `services` for MySQL, Redis, etc.
