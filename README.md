# Malt

**JSON-driven Homebrew Dev Services**

<img src="https://koriym.github.io/homebrew-malt/malt.jpg" width="180" alt="Moruko, a young girl holding malt">

Malt is a JSON-driven development environment manager that creates project-specific development environments (IaC) using only Homebrew.
Define your stack in one JSON file, and let your team replicate it anywhere with the portable `malt/` directory.

## Motivation

Docker is an excellent containerization tool, but we questioned whether its full isolation approach is always necessary for local development:

- macOS developers often face performance issues (slow filesystem I/O through volume mounts)
- Full containers can be overkill for many development workflows
- Tools like Devbox.json are emerging specifically for development environments

Malt offers a lightweight alternative that:
- Creates project-specific environments with minimal overhead
- Runs services natively while maintaining isolation between projects
- Works alongside Docker when needed for complex integration scenarios

Rather than replacing containers, Malt complements them by focusing on what matters during the development phase: speed, transparency, and simplicity.

## Overview

Malt takes a declarative approach to local development environments. Define your entire stack in a single JSON file - PHP version, web servers, databases, caching solutions, extensions, and even development tools like git or wget - and Malt handles the rest. No complicated setup scripts, no environment inconsistencies, just simple JSON.

Malt focuses specifically on service installation and control, rather than trying to be a complete development environment solution. This focused approach helps keep it lightweight and straightforward.

Think of `malt.json` as your infrastructure's `composer.json` - it serves as the Single Source of Truth for your project's infrastructure dependencies. Just as `composer install` pulls in your PHP dependencies, `malt install && malt start` sets up your infrastructure dependencies.

Malt leverages the entire Homebrew formula ecosystem, allowing you to declare and install any Homebrew package as a project dependency. This replaces the traditional approach of manually running individual `brew install` commands and ensures everyone on your team has exactly the same tools and services.

## Key Features
- **Infrastructure as Code**: `malt/` holds your setup and logs, shareable across your team.
- **JSON-driven config**: Ensures consistency across setups.
- **Homebrew-powered**: No extra dependencies needed.
- **Service management**: Handles PHP, MySQL, and more seamlessly.
- **Native performance**: Direct filesystem access without virtualization overhead.
- **Selective isolation**: Port-based separation without heavy containers.

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
    "nginx": [80],
    "httpd": [8080],
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

## Document Root

By default, Malt uses the `public` directory as the document root for web services. This is automatically configured in the generated configuration files.

For projects requiring multiple web endpoints (e.g., a main application and an admin interface), you can manually edit the configuration files for each port to specify different document roots.

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

### Setting up HTTPS

By default, Malt configures HTTP for development simplicity. To enable HTTPS:

1. Make sure your `malt.json` includes HTTPS ports:
   ```json
   "ports": {
     "nginx": [80, 443],
     "httpd": [8080, 8443]
   }
   ```

2. After running `malt create`, the configuration files for HTTPS will be generated in the `malt/conf/` directory.

3. For self-signed certificates (development only):
   ```bash
   # For Nginx
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout malt/conf/nginx-selfsigned.key \
     -out malt/conf/nginx-selfsigned.crt \
     -subj "/CN=localhost"

   # For Apache
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout malt/conf/httpd-selfsigned.key \
     -out malt/conf/httpd-selfsigned.crt \
     -subj "/CN=localhost"
   ```

4. Edit the respective configuration files in `malt/conf/` to reference these certificates.

5. Restart services with `malt stop` followed by `malt start`.

Note: When using self-signed certificates, browsers will display security warnings. This is normal for development environments.

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
- `redis-cli` → Your project's Redis port
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

## FAQ

### How does Malt solve the "works on my machine" problem?

For well-structured applications, Malt addresses most environment inconsistencies without Docker's full isolation:

1. **Version consistency** - Same versions of services and tools via `malt.json`
2. **Configuration consistency** - Standardized settings in the `malt/` directory
3. **Project isolation** - Clear separation between different projects

This approach is sufficient for most modern applications, while maintaining better performance and transparency than containers. For highly coupled systems with complex OS dependencies, Docker might still be necessary - and can be used alongside Malt when needed.

### Is Malt an alternative to Docker?

No, they serve different purposes and can coexist:

- Use **Malt** for daily development when you need speed and transparency
- Use **Docker** for integration testing, staging, and production environments

Many teams use both: Malt for rapid development cycles and Docker for ensuring production similarity in later stages.

### Can I use Malt alongside Docker in the same project?

Absolutely! You can:
- Develop core components with Malt for speed
- Run integration tests with Docker
- Use Malt-generated configurations as a base for creating Dockerfiles

This combined approach gives you the best of both worlds.

## Why Malt?

Unlike other development environment solutions, Malt:

- Is dramatically lighter than alternatives - no VMs or containers means:
  - Minimal memory footprint compared to Docker or VMs
  - Native file system performance (especially important on macOS)
  - Direct access to logs, data, and configuration files without abstraction layers
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

### Malt vs Devbox.json

Both Malt and Devbox.json use JSON to define development environments, but with different approaches:

| Feature | Malt | Devbox.json |
|---------|------|------------|
| **Ecosystem** | Homebrew packages | Nix packages |
| **Focus** | Service installation and control | Broader development environment |
| **Configuration** | Simple JSON structure | More complex schema |
| **Service Management** | Built-in service controls | Less focus on running services |
| **Project Structure** | Creates `malt/` with configs/logs | Minimal filesystem changes |

Malt is ideal for:
- Projects with multiple interdependent services needing management
- Teams seeking direct access to logs and configurations
- Simpler service-oriented development environments

Devbox.json may be better for:
- Teams looking for broader environment management
- Projects with complex dependency graphs
- More comprehensive development environments

Both tools are cross-platform and offer declarative configuration.

## 🍺Malt Prompt Brewery

Brew infrastructure code from your malt.json using our [Malt Prompt Brewery](https://koriym.github.io/homebrew-malt/prompt.html).

## Documentation

Full documentation is available at [https://koriym.github.io/homebrew-malt/index.html](https://koriym.github.io/homebrew-malt/index.html)

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
