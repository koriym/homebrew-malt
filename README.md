# Malt

**The essential ingredient for your development environment**

<img src="https://koriym.github.io/homebrew-malt/malt.jpg" width="180" alt="Moruko, a young girl holding malt">

Malt is a JSON-driven development environment manager that turns your project into shareable infrastructure code using just the Homebrew ecosystem. Define your stack in one JSON file, and let your team replicate it anywhere with the portable `malt/` directory.

## Overview

Malt takes a declarative approach to local development environments. Define your entire stack in a single JSON file - PHP version, web servers, databases, caching solutions, extensions, and even development tools like git or wget - and Malt handles the rest. No complicated setup scripts, no environment inconsistencies, just simple JSON.

Malt leverages the entire Homebrew formula ecosystem, allowing you to declare and install any Homebrew package as a project dependency. This replaces the traditional approach of manually running individual `brew install` commands and ensures everyone on your team has exactly the same tools and services.

## Key Features
- **Infrastructure as Code**: `malt/` holds your setup and logs, shareable across your team.
- **JSON-driven config**: Ensures consistency across setups.
- **Homebrew-powered**: No extra dependencies needed.
- **Service management**: Handles PHP, MySQL, and more seamlessly.

## Installation

```bash
brew tap shivammathur/php
brew tap shivammathur/extensions
brew tap koriym/malt
brew install malt
```

## Quick Start

### 1. Initialize your project

```bash
cd your-project
malt init
```

This creates a `malt.json` file in your project directory:

```json
{
  "project_name": "myapp",
  "public_dir": "public",
  "dependencies": [
    "php@8.4",
    "mysql@8.0",
    "composer",
    "redis",
    "nginx",
    "wget",
    "wrk"
  ],
  "ports": {
    "php": [9000],
    "redis": [6379],
    "memcached": [11211],
    "nginx": [80, 443],
    "httpd": [8080, 8443],
    "mysql": [3306]
  },
  "php_extensions": [
    "xdebug",
    "redis",
    "apcu"
  ]
}

```

Customize this file to match your project requirements.

### 2. Install dependencies

```bash
malt install
```

This installs all services and extensions defined in your `malt.json`.

### 3. Create environment files

```bash
malt create
```

This generates all necessary configuration files in a [**malt** directory](https://github.com/koriym/homebrew-malt/tree/1.x/malt) within your project.

### 4. Start services

```bash
malt start
```

All of your services will start with configurations tailored to your project.

### 5. Stop services

```bash
malt stop
```

### For existing projects

For projects that already have `malt.json` and the `malt` directory set up (e.g., when joining an existing team or setting up a second development machine), you only need three commands:

```bash
malt install    # Install dependencies
malt start      # Start services
source <(malt env)  # Set up environment variables and aliases
```

This makes onboarding new team members incredibly fast and ensures consistent development environments across the entire team and across multiple machines. The `source <(malt env)` command gives immediate access to all the correct binary versions and simplified service connections for the project.

## Directory Structure

Malt creates the following directory structure in your project:

```
your-project/
├── malt/
│   ├── conf/       # Configuration files for all services
│   ├── logs/       # Log files
│   ├── tmp/        # Temporary files
│   └── var/        # Data files (MySQL, etc.)
├── public/         # Document root (public_dir)
└── malt.json       # Your environment definition
```

The `malt/` directory, paired with `malt.json`, acts as portable infrastructure code. Using project-relative placeholders, your team can clone it and deploy the same setup anywhere—no path tweaks needed.

### Version Control Considerations

When using version control like Git, you should commit your `malt.json` file but ignore most of the generated content. Here's a recommended `.gitignore` pattern:

```
# Ignore Malt generated content except base configs
malt/logs/
malt/tmp/
malt/var/
malt/conf/*.tmp
malt/conf/*.temp
```

This ensures that your environment definition is shared with the team, but temporary files, logs, and runtime data aren't included in your repository.

## Commands

- `malt init` - Create a new malt.json configuration
- `malt install` - Install dependencies from malt.json
- `malt create` - Set up the environment
- `malt start` - Start services
- `malt stop` - Stop services
- `malt env` - Show environment variables
- `malt info` - Show information about the current project

## Service Configuration

Malt manages the following services:

- **PHP-FPM** - Multiple PHP versions with custom extensions
- **Nginx** - Multiple virtual hosts
- **Apache HTTPD** - Multiple ports and virtual hosts
- **MySQL** - Custom configurations
- **Redis** - Caching server
- **Memcached** - Distributed memory caching

## Environment Variables

Use the following command (compatible with bash, zsh, and similar shells) to set up environment variables for your project:

```bash
source <(malt env)
```

This command sets up convenient path aliases and service connections:

### Path Aliases
Malt automatically creates symlinks to the specific versions of each binary you've defined in your `malt.json`:

- `php` → `php@8.4` (your project's specific PHP version)
- `mysql` → `mysql@8.0` (the MySQL version specified in your project)
- `redis-cli` → Your project's Redis version
- And so on for all defined dependencies

This ensures that you're always using the correct version for your project without having to specify it manually.

### Service Connection Aliases
Malt also creates convenient port-specific aliases for connecting to services with the correct configuration:

```bash
alias mysql@3306="mysql --defaults-file=/Users/username/your-project/malt/conf/my_3306.cnf -h 127.0.0.1"
alias mysql@3307="mysql --defaults-file=/Users/username/your-project/malt/conf/my_3307.cnf -h 127.0.0.1"
alias redis-cli@6379="redis-cli -h 127.0.0.1 -p 6379"
```

This is particularly useful when working with multiple instances of the same service (e.g., `mysql@3306`, `mysql@3307`) simultaneously. You can easily switch between different database instances without having to remember complex connection strings or configuration file paths. Just use the port-specific alias and you're immediately connected to the right instance with all the correct settings.

## Why Malt?

Unlike other development environment solutions, Malt:

- Is dramatically lighter than alternatives - no VMs or containers means:
  - Minimal memory footprint compared to Docker or VMs
  - Native file system performance (especially important on macOS)
  - Direct access to logs, data, and configuration files without abstraction layers
  - No port mapping complexity or networking layers
  - Instant startup times with no virtualization overhead
  - Direct access to native binaries and tools
- Has virtually zero dependencies - just Homebrew, which is already standard for macOS developers
- Uses the native packages you already know, not wrapped in containers
- Provides full configuration flexibility through simple JSON
- Creates consistent environments across the team
- Follows infrastructure-as-code principles without the complexity

### Resource Usage Comparison

| Solution | Memory Usage | Disk Space | Startup Time | File I/O Performance |
|----------|--------------|------------|--------------|----------------------|
| Malt     | Low          | Low        | Instant      | Native               |
| Docker   | Medium-High  | Medium     | Seconds      | Reduced (especially on macOS) |
| VM       | High         | High       | Minutes      | Significantly reduced |

### Development Focus vs Container Isolation

While Docker excels in production environments and specific development scenarios, Malt was born from questioning whether such complete isolation is really necessary for all development environments:

- Almost all web services (Apache, MySQL, etc.) are already designed to run multiple instances with different configurations
- We realized that the difficulty in using traditional native services stemmed from their dependence on global configurations, so we decided to set up configurations and logs for each project
- Port separation is often sufficient isolation for development purposes
- Direct access to a comfortable file system is possible, with organized configurations, logs, and data directories
- Easy configuration of xdebug and hot reload, which can often become complicated
- Naturally, all virtualization issues can be fundamentally avoided

Does container virtualization overhead actually provide special benefits for development workflows? If not, Malt might be what you need.
Malt provides minimal abstraction and maximum transparency so developers can focus on what matters most.

### Production Migration Path

One of Malt's significant advantages is its usefulness when creating production deployment configurations:

- The JSON configuration serves as a single source of truth for your environment requirements
- Easily generate Dockerfiles, Docker Compose files, Kubernetes manifests, or other deployment configs by providing your `malt.json` to AI tools
- The declarative nature of Malt's configuration makes it ideal for AI-assisted conversion to various deployment formats
- Dependency versions, service configurations, and environment variables are already clearly defined, making translation straightforward
- This approach bridges the gap between development and production environments more effectively than starting from scratch

This workflow is clearer and more straightforward than migrating a traditional development environment setup to containerized or orchestrated environments, and facilitates consistency across your infrastructure.

#### 🍺Malt Prompt Brewery

Brew infrastructure code from your malt.json using our [Malt Prompt Brewery](https://koriym.github.io/homebrew-malt/prompt.html). 

## Documentation

Full documentation is available at [https://koriym.github.io/homebrew-malt/index.html](https://koriym.github.io/homebrew-malt/index.html)


## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
