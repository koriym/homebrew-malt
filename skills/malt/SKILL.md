---
name: malt
description: Comprehensive Malt development environment management. Set up PHP projects (analyzes composer.json), check prerequisites (Homebrew), troubleshoot services, customize configurations, and convert malt.json to other formats (Docker Compose, Devbox, .env, GitHub Actions). Use when user mentions "malt", "development environment", "local server", or needs help with PHP project environment.
---

# Malt Skill

Comprehensive skill for managing Malt development environments - setup, troubleshooting, and customization.

## When to Use

- User wants to set up a development environment
- User mentions "malt", "malt init", "malt setup"
- User wants to run PHP project locally
- User asks about Redis, MySQL, Memcached for their project
- User has trouble starting/stopping services
- User needs help with configuration customization
- User wants to convert malt.json to other formats (Docker, Devbox, .env, CI)

## Workflow Overview

```
1. Check Prerequisites
   └─ Homebrew installed? → Guide installation if missing

2. Setup (if requested)
   └─ Analyze composer.json → Generate malt.json

3. Troubleshoot (if issues)
   └─ Check ports, logs, configs

4. Customize (if needed)
   └─ Guide configuration file editing

5. Convert (if requested)
   └─ malt.json → Docker Compose, Devbox, .env, GitHub Actions
```

---

## 1. Prerequisites Check

### Homebrew Installation

Before any malt operation, check if Homebrew is installed:

```bash
which brew
```

**If Homebrew is NOT installed**, guide the user:

```
Homebrew is required for Malt. Install it from https://brew.sh/

Homebrew supports:
- macOS (Intel and Apple Silicon)
- Linux (x86_64 and ARM)
- Windows Subsystem for Linux (WSL)

Installation command:
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Malt Installation

Check if malt is installed:

```bash
which malt
```

**If Malt is NOT installed**:

```
Install Malt with:
  brew tap shivammathur/php
  brew tap shivammathur/extensions
  brew tap koriym/malt
  brew install malt

Documentation: https://koriym.github.io/homebrew-malt/
```

---

## 2. Environment Setup

### Step 1: Analyze Project

Read `composer.json` to detect:

| Dependency Pattern | Service |
|-------------------|---------|
| `php` require | PHP version |
| `ext-redis` or `predis/predis` | Redis |
| `ext-memcached` | Memcached |
| `ext-pdo_mysql` or `doctrine/*` | MySQL |
| `ext-pdo_pgsql` | PostgreSQL (note: not yet supported by malt) |

Check for `.htaccess` file to determine web server.

### Step 2: Determine Configuration

**Web Server Selection:**
- `.htaccess` exists → Apache (httpd)
- Otherwise → Nginx (default, modern choice)

**PHP Version:**
- Extract from `composer.json` `require.php` field
- Parse constraint (e.g., `^8.1` → `8.1`, `>=8.2` → `8.2`)
- Default: `8.4`

**Default Ports:**
| Service | Port |
|---------|------|
| PHP-FPM | 9000 |
| MySQL | 3306 |
| Redis | 6379 |
| Memcached | 11211 |
| Nginx | 80 |
| Apache | 8080 |

### Step 3: Propose Configuration

Present the detected configuration to the user:

```
Detected configuration for [project-name]:

Services:
- PHP 8.4 (port: 9000)
- MySQL 8.0 (port: 3306)
- Redis (port: 6379)
- Nginx (port: 80)

PHP Extensions:
- xdebug, pcov (from require-dev)

Proceed with this configuration?
```

Use `AskUserQuestion` tool to confirm.

### Step 4: Generate and Execute

After user confirmation:

1. Generate `malt.json`:
```json
{
  "project_name": "detected-name",
  "dependencies": ["php@8.4", "mysql@8.0", "redis", "nginx", "composer"],
  "ports": {
    "php": [9000],
    "mysql": [3306],
    "redis": [6379],
    "nginx": [80]
  },
  "php_extensions": ["xdebug", "pcov"]
}
```

2. Run commands:
```bash
malt install  # Install Homebrew packages
malt create   # Generate config files
malt start    # Start services
```

3. Report success with access URLs.

---

## 3. Troubleshooting

### Common Issues

#### Port Already in Use

```bash
# Check what's using a port
lsof -i :PORT_NUMBER

# Kill process on port
kill -9 $(lsof -t -i :PORT_NUMBER)
```

#### Service Won't Start

1. Check logs in `malt/logs/`:
   - `php-fpm_9000.log`
   - `mysql_3306_error.log`
   - `nginx_error_80.log`
   - `httpd_error_8080.log`

2. Verify config files in `malt/conf/`:
   - Syntax errors in nginx/httpd configs
   - Missing directories referenced in configs

3. Check Homebrew service status:
```bash
brew services list
```

#### MySQL Initialization Failed

If MySQL data directory is corrupted:
```bash
rm -rf malt/var/mysql_*
malt start  # Will reinitialize
```

#### Permission Issues

```bash
# Check malt directory permissions
ls -la malt/

# Fix if needed
chmod -R 755 malt/
```

### Debug Mode

Run with debug output:
```bash
MALT_DEBUG=1 malt start
MALT_DEBUG=1 malt stop
```

---

## 4. Customization Guide

### Configuration Files Location

After `malt create`, config files are in `malt/conf/`:

```
malt/conf/
├── php-fpm_9000.conf    # PHP-FPM configuration
├── php.ini              # PHP settings
├── nginx_main.conf      # Main Nginx config
├── nginx_80.conf        # Nginx virtual host
├── httpd_8080.conf      # Apache config
├── my_3306.cnf          # MySQL config
└── redis_6379.conf      # Redis config
```

### How to Customize

1. **Edit the generated files directly** (not templates)
2. Run `malt stop` then `malt start` to apply changes
3. Check logs if service fails to start

### Common Customizations

#### Change Document Root

Edit nginx config (`nginx_80.conf` or `httpd_8080.conf`):
```nginx
root /path/to/your/public;
```

#### Add PHP Extensions

Edit `malt.json` and re-run:
```bash
malt install
malt stop && malt start
```

#### Multiple Ports

Edit `malt.json`:
```json
"ports": {
  "nginx": [80, 8080],
  "mysql": [3306, 3307]
}
```

Then recreate configs:
```bash
rm -rf malt/
malt create
malt start
```

### Reference

Full customization guide: https://koriym.github.io/homebrew-malt/customization_guide.html

---

## Detection Logic

### PHP Version Parsing

```ruby
# Examples:
# "^8.1" → "8.1"
# ">=8.2" → "8.2"
# "8.3.*" → "8.3"
# "~8.1.0" → "8.1"
```

### Extension Detection

Check `composer.json`:
- `require` section for runtime extensions
- `require-dev` section for development extensions (xdebug, pcov)

### Framework Detection (informational)

| Framework | Indicators |
|-----------|------------|
| Laravel | `laravel/framework` |
| Symfony | `symfony/framework-bundle` |
| BEAR.Sunday | `bear/sunday` |

---

## Example Sessions

### Setup Example

**User:** "Set up development environment for this PHP project"

**Claude:**
1. Checks Homebrew and Malt installation
2. Reads `composer.json`
3. Detects: PHP 8.2, MySQL (doctrine/orm), Redis (predis/predis)
4. Checks: No `.htaccess` → Nginx
5. Proposes configuration
6. After confirmation, runs malt commands
7. Reports: "Environment ready at http://127.0.0.1:80/"

### Troubleshooting Example

**User:** "malt start fails with port error"

**Claude:**
1. Checks which port is in use: `lsof -i :PORT`
2. Identifies conflicting process
3. Suggests: kill process or change port in malt.json
4. Helps restart services

---

## 5. Format Conversion (malt.json as SSOT)

Use `malt.json` as the Single Source of Truth to generate other configuration formats.

### Convert to Docker Compose

**User:** "Generate docker-compose.yml from malt.json"

Read `malt.json` and generate equivalent `docker-compose.yml`:

```yaml
# Generated from malt.json
version: '3.8'
services:
  php:
    image: php:8.4-fpm
    ports:
      - "9000:9000"
    volumes:
      - .:/var/www/html

  mysql:
    image: mysql:8.0
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: app
    volumes:
      - mysql_data:/var/lib/mysql

  redis:
    image: redis:latest
    ports:
      - "6379:6379"

  nginx:
    image: nginx:latest
    ports:
      - "80:80"
    volumes:
      - .:/var/www/html
      - ./docker/nginx.conf:/etc/nginx/conf.d/default.conf

volumes:
  mysql_data:
```

### Convert to Devbox

**User:** "Generate devbox.json from malt.json"

```json
{
  "$schema": "https://raw.githubusercontent.com/jetify-com/devbox/main/.schema/devbox.schema.json",
  "packages": [
    "php84",
    "mysql80",
    "redis",
    "nginx"
  ],
  "shell": {
    "scripts": {
      "start": "malt start",
      "stop": "malt stop"
    }
  }
}
```

### Convert to .env

**User:** "Generate .env from malt.json"

```env
# Generated from malt.json
PHP_VERSION=8.4
PHP_PORT=9000

MYSQL_VERSION=8.0
MYSQL_PORT=3306
MYSQL_HOST=127.0.0.1
MYSQL_DATABASE=app
MYSQL_USER=root
MYSQL_PASSWORD=

REDIS_PORT=6379
REDIS_HOST=127.0.0.1

NGINX_PORT=80
```

### Convert to GitHub Actions

**User:** "Generate CI workflow from malt.json"

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: root
          MYSQL_DATABASE: test
        ports:
          - 3306:3306
      redis:
        image: redis
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with:
          php-version: '8.4'
          extensions: redis, pdo_mysql
      - run: composer install
      - run: composer test
```

### Conversion Mapping Table

| malt.json | Docker Compose | Devbox | GitHub Actions |
|-----------|----------------|--------|----------------|
| `php@8.4` | `php:8.4-fpm` | `php84` | `shivammathur/setup-php` |
| `mysql@8.0` | `mysql:8.0` | `mysql80` | `services.mysql` |
| `redis` | `redis:latest` | `redis` | `services.redis` |
| `nginx` | `nginx:latest` | `nginx` | N/A (action runner) |
| `memcached` | `memcached:latest` | `memcached` | `services.memcached` |

---

## Error Handling

- **No `composer.json`**: Ask user for manual configuration or create minimal malt.json
- **Homebrew not installed**: Provide installation instructions for user's platform
- **Malt not installed**: Provide brew tap and install commands
- **Port conflict**: Identify conflicting process and suggest alternatives
- **Service crash**: Check logs and suggest fixes
