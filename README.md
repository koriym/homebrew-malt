# Malt

**One JSON. Native speed. Zero containers.**

Define your dev services in `malt.json`, run `malt start`, and get PHP, MySQL, Nginx, Redis — all running natively via Homebrew with project-isolated ports. No Docker overhead, no VM, no volume mount lag.

```bash
malt init      # Generate malt.json
malt install   # brew install everything
malt create    # Generate service configs
malt start     # Start all services
malt stop      # Stop all services
```

## Installation

```bash
brew tap shivammathur/php
brew tap shivammathur/extensions
brew tap koriym/malt
brew install malt
```

## Quick Start

```bash
cd your-project
malt init
```

Edit `malt.json` to define your stack:

```json
{
  "project_name": "myapp",
  "dependencies": ["php@8.4", "mysql@8.0", "composer", "redis", "nginx"],
  "ports": {
    "php": [9000],
    "redis": [6379],
    "nginx": [80],
    "mysql": [3306]
  },
  "php_extensions": ["xdebug", "redis", "apcu"]
}
```

Then:

```bash
malt install   # Install all dependencies
malt create    # Generate configs into malt/conf/
malt start     # Start services
```

### Joining an existing project

```bash
malt install && malt start && source <(malt env)
```

`source <(malt env)` sets up `PATH`, `MALT_DIR`, `DOCUMENT_ROOT`, and port-specific aliases like `mysql@3306`, `redis-cli@6379`.

## Commands

| Command | Description |
|---------|-------------|
| `malt init` | Create `malt.json` from template |
| `malt install` | Install dependencies from `malt.json` |
| `malt create` | Generate service configs in `malt/conf/` |
| `malt start` | Start all services |
| `malt stop` | Stop all services |
| `malt kill` | Force-kill all service processes |
| `malt status` | Show running/stopped state per port |
| `malt env` | Output shell env setup script |
| `malt info` | Show project information |

## Project Structure

```text
your-project/
├── malt.json        # Infrastructure definition (commit this)
├── malt/
│   ├── conf/        # Service configs (commit this)
│   ├── logs/        # Log files (gitignore)
│   ├── tmp/         # Temporary files (gitignore)
│   └── var/         # Data files (gitignore)
└── public/          # Document root
```

Recommended `.gitignore`:

```text
malt/logs/
malt/tmp/
malt/var/
malt/conf/*.tmp
```

## Supported Services

PHP-FPM, Nginx, Apache HTTPD, MySQL, Redis, Memcached — each supporting multiple instances on different ports.

Customize generated configs in `malt/conf/` directly. See the [Customization Guide](docs/customization_guide.md).

## Claude Code Skill

Malt is available as a [Claude Code](https://claude.ai/code) skill for setup, troubleshooting, and format conversion (Docker Compose, Kubernetes, Terraform, etc.).

```text
/plugin marketplace add koriym/homebrew-malt
/plugin install malt@koriym-homebrew-malt
```

## Documentation

- [Full documentation](https://koriym.github.io/homebrew-malt/index.html)
- [llms.txt](docs/llms.txt) / [llms-full.txt](docs/llms-full.txt) — LLM-friendly references

## License

MIT
