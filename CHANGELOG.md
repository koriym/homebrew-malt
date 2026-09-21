# Changelog

## 1.0.0beta12

### Upgrade Path
- Read `HOMEBREW_PREFIX/var/malt/pids/` as well, under the same ownership and permission checks, so `malt kill` still reaches services started by 1.0.0beta10 or earlier. Without this, upgrading left already-running services with no way to force-kill them, since 1.0.0beta11 only looks at `~/.malt/pids`. The old directory is never written to, so it drains as those services are stopped.

### Installation
- Document `brew trust` for the third-party taps. Homebrew 7 refuses to load formulae from an untrusted tap, so `brew install malt` and `malt install` both fail without it.

## 1.0.0beta11

### Scoped `malt kill`
- Replace pattern-matching `pkill -f` with a pid registry: `malt kill` only SIGKILLs processes malt recorded at start, after re-checking each pid's live command line against the identity stored with it. Homebrew-managed services are never touched.
- Store the registry in `~/.malt/pids` instead of `HOMEBREW_PREFIX/var`, which is group-writable on a default install. Both directories are forced to `0700`, entries are written atomically with `0600`, and a registry directory or entry that is not a plain directory/file owned by the current user and writable only by them is ignored.
- Kill the service process group instead of enumerating children with `pgrep`, so php-fpm and nginx workers cannot be orphaned when child discovery fails.
- Identify every service by a project-unique token: Memcached now matches on its pid file and `mysqld_safe` on its defaults file, so another project's or Homebrew's instance can never match.
- Keep a registry entry when a pid cannot be verified, and distinguish an unreadable pid file from a genuine identity mismatch.

### Service Status And Startup
- `malt status` is pid based and reports `running` / `stopped` / `external process on port`.
- `malt start` exits non-zero when any service fails to start.
- Persist the `mysqld_safe` pid so a lost supervisor registration is restored on the next `malt start`, and stop a surviving supervisor before dropping its entry: `mysqld_safe` restarts `mysqld`, and an entry-less supervisor is unreachable by `malt kill`.

### PHP-free Projects
- `php` ports are no longer required. Projects without PHP use `nginx-static.conf.erb` / `httpd-static.conf.erb`, so no `fastcgi_pass` or `LoadModule php_module` is emitted.

## 1.0.0beta10

### Service Lifecycle Safety
- Scope PHP-FPM, Nginx, Memcached, Redis, MySQL, and HTTPD lifecycle operations to project pid/config files.
- Add PID validation and process identity checks before sending stop signals.
- Harden startup/stop failure handling for PHP-FPM, MySQL, Redis, Memcached, Nginx, and HTTPD.
- Fix `malt start --config` so it checks the configured project's `malt/` directory rather than the current working directory.

### Formula And Install Reliability
- Fix installed `malt` runtime paths so the generated executable points to the installed keg instead of the tap checkout.
- Try PHP extension Homebrew formula candidates in order during install.
- Remove debug-style path logging from the Formula installer.

### Documentation
- Document the explicit `malt install` / `malt create` / `malt start` workflow.
- Clarify project-scoped `malt stop` versus global `malt kill`.
- Update LLM-facing docs and remove stale Memcached config/template references.

### Tests
- Add coverage for Formula path substitution, env quoting, dependency install failures, PHP extension formula fallback, `--config` start behavior, MySQL version parsing, and scoped lifecycle behavior.

## 1.0.0beta9

### Service Stop Race Condition Fix
- Add `wait_for_process_stop` to BaseService: polls up to 10 seconds after SIGTERM, falls back to SIGKILL.
- Apply shutdown waiting to PHP-FPM and Memcached stop methods.
- Use array-form `system()` calls for shell-injection safety.

### SKILL.md Rewrite
- Rewrite malt skill as concise reference guide.
- Narrow MySQL detection to `ext-pdo_mysql` only.
