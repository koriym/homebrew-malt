# Changelog

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
