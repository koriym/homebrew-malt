---
name: malt
description: Comprehensive Malt development environment management. Set up PHP projects (analyzes composer.json), check prerequisites (Homebrew), troubleshoot services, and customize configurations. Use when user mentions "malt", "development environment", "local server", or needs help with PHP project environment.
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

## Error Handling

- **No `composer.json`**: Ask user for manual configuration or create minimal malt.json
- **Homebrew not installed**: Provide installation instructions for user's platform
- **Malt not installed**: Provide brew tap and install commands
- **Port conflict**: Identify conflicting process and suggest alternatives
- **Service crash**: Check logs and suggest fixes
