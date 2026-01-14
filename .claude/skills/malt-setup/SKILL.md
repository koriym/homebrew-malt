---
name: malt-setup
description: Set up Malt development environment for PHP projects. Analyzes composer.json to detect required services (MySQL, Redis, Memcached) and generates optimized malt.json. Use when user mentions "malt", "development environment", "local server", or wants to set up PHP project environment.
---

# Malt Setup Skill

Automatically analyze PHP projects and set up Malt development environment with optimal configuration.

## When to Use

- User wants to set up a development environment
- User mentions "malt", "malt init", "malt setup"
- User wants to run PHP project locally
- User asks about Redis, MySQL, Memcached for their project

## Workflow

### Step 1: Analyze Project

Read `composer.json` to detect:

| Dependency Pattern | Service |
|-------------------|---------|
| `php` require | PHP version |
| `ext-redis` or `predis/predis` | Redis |
| `ext-memcached` | Memcached |
| `ext-pdo_mysql` or `doctrine/*` | MySQL |
| `ext-pdo_pgsql` | PostgreSQL |

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

## Example Session

**User:** "Set up development environment for this PHP project"

**Claude:**
1. Reads `composer.json`
2. Detects: PHP 8.2, MySQL (doctrine/orm), Redis (predis/predis)
3. Checks: No `.htaccess` → Nginx
4. Proposes configuration
5. After confirmation, runs malt commands
6. Reports: "Environment ready at http://127.0.0.1:80/"

## Error Handling

- No `composer.json`: Ask user for manual configuration
- Malt not installed: Provide installation instructions
- Port conflict: Suggest alternative ports

## Prerequisites

- Homebrew installed
- Malt installed (`brew install koriym/malt/malt`)
