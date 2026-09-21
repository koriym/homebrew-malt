# Installing phpcomplete on Intel Macs

Guide for `brew install koriym/malt/phpcomplete` on Intel (x86_64) macOS.
Verified on: macOS 13 (Darwin 22.6), Intel, Command Line Tools with Apple clang 14.0.3 (clang-1403), Homebrew 7.0.4, September 2026.

## Summary

- Homebrew prefix on Intel is `/usr/local`, not `/opt/homebrew`. Use `$(brew --prefix)` in scripts and aliases.
- Old PHP versions (5.6 - 7.4) are built from source on Intel (no usable bottles), so the install takes a long time (roughly 10 minutes per version). Run it and wait.
- `php@7.4` fails to link on Command Line Tools older than Xcode 15.3. It needs a one-line local patch (see below). Other versions build without changes.

## Install

```sh
brew install koriym/malt/phpcomplete
```

If it stops at `php@7.4`, apply the fix below and re-run the same command. Already-built versions are skipped.

## Known failure: php@7.4 link error

### Symptom

```
==> make
ld: symbol(s) not found for architecture x86_64
  "_res_9_dn_expand", referenced from: _zif_dns_get_record in dns.o
  "_res_9_init", ...
  "_res_9_search", ...
collect2: error: ld returned 1 exit status
make: *** [sapi/phpdbg/phpdbg] Error 1
```

Log: `~/Library/Logs/Homebrew/php@7.4/03.make.log`. Also printed: `php@7.4 has been deprecated because it is deprecated upstream` (warning only, not the cause).

### Cause

- The `shivammathur/php/php@7.4` formula declares `fails_with :clang` and builds with Homebrew `gcc` (`collect2` in the error is the GCC linker driver). `unset CC` / changing the compiler does not help.
- The `res_9_*` symbols come from macOS `resolv.h` and need `-lresolv`.
- The formula adds `-lresolv` only when `DevelopmentTools.clang_build_version >= 1500` (Xcode / CLT 15.3+). With older CLT (clang 1403 here) the flag is missing.
- Updating CLT is the proper fix, but `softwareupdate --list` may offer nothing on older macOS (macOS 13), and `xcode-select --install` may not provide 15.3+. The patch below avoids needing it.

### Fix (local patch to the shivammathur tap formula)

Add `-lresolv` unconditionally:

```sh
f="$(brew --repository shivammathur/php)/Formula/php@7.4.rb"
cp "$f" "$f.orig"
sed -i '' 's|    ENV.append "CFLAGS", "-std=gnu17"|    ENV.append "CFLAGS", "-std=gnu17"\
    ENV.append "LDFLAGS", "-lresolv"|' "$f"
grep -n 'lresolv' "$f"     # expect two matches: the new line and the Xcode 15.3 workaround
brew install --build-from-source shivammathur/php/php@7.4
brew install shivammathur/extensions/xdebug@7.4    # bottle, no build
```

Notes:

- The change lives in the tap checkout. `brew update` overwrites it. `brew reinstall php@7.4` or a rebuild after `brew update` needs the patch applied again.
- `brew install koriym/malt/phpcomplete` afterwards succeeds because all dependencies are already installed.
- Do not run two `brew install` for different PHP versions in parallel: build dependencies such as `bison` are locked (`process has already locked /usr/local/Cellar/bison`).

### Alternative: skip PHP 7.4

If 7.4 is not needed, comment out these two lines in the formula and install:

```sh
brew edit koriym/malt/phpcomplete
#   depends_on "shivammathur/php/php@7.4"
#   depends_on "shivammathur/extensions/xdebug@7.4"
```

Remove the `php74` alias as well.

## Verify

```sh
for v in 5.6 7.0 7.1 7.2 7.3 7.4 8.0 8.1 8.2 8.3 8.4; do
  "$(brew --prefix)/opt/php@$v/bin/php" -v | head -1
  "$(brew --prefix)/opt/php@$v/bin/php" -m | grep -i '^xdebug$'
done
php -v    # the unversioned `php` formula is the latest release (8.5)
```

`php@8.5` is an alias of the `php` formula (`/usr/local/opt/php@8.5 -> ../Cellar/php/8.5.x`), so there is no separate `php@8.5` keg.

## Pin versions (optional, for test environments)

Versions 5.6 - 8.4 are end of life or receive security patches only from upstream, and are used for compatibility testing. Pin them so `brew upgrade` leaves them alone; keep `php` (8.5) and `xdebug@8.5` unpinned to follow the latest release.

```sh
for v in 5.6 7.0 7.1 7.2 7.3 7.4 8.0 8.1 8.2 8.3 8.4; do
  brew pin "php@$v" "xdebug@$v"
done
brew list --pinned
```

- `brew pin` only blocks `brew upgrade`. `brew reinstall` and `brew uninstall` still work.
- Release a pin with `brew unpin php@7.4`.
- Under zsh, do not put the version list in a scalar variable (`v="5.6 7.0"; for x in $v`): zsh does not word-split it. Write the list inline as above.

## Aliases on Intel

The aliases in `README.md` use `/opt/homebrew`. On Intel use `$(brew --prefix)`, which resolves to `/usr/local`:

```sh
alias php74='$(brew --prefix)/opt/php@7.4/bin/php'
alias sphp74='export PATH="$(brew --prefix)/opt/php@7.4/bin:$PATH"'
```

## Troubleshooting

| Symptom | Cause | Action |
| --- | --- | --- |
| `php83 -v` prints nothing / command not found | `php@8.3` is not installed yet (the install is still working through the dependency list) or the alias targets a wrong prefix | Wait for `brew install` to finish; check `ls /usr/local/Cellar \| grep php`; use `$(brew --prefix)` in aliases |
| `A ... process has already locked /usr/local/Cellar/bison` | Another `brew install` is building and holds a shared build dependency | Wait for it to finish, then retry |
| `Command Line Tools for Xcode-15.2: No such update` | `softwareupdate` does not offer that package on this macOS | Use the php@7.4 patch above instead of updating CLT |
| `sudo xcode-select -s /Applications/Xcode-15.2.app/...`: `invalid developer directory` | Full Xcode is not installed at that path | Not needed; skip |
