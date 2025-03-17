# PHP Complete

PHP Complete is a Homebrew formula that allows you to install multiple versions of PHP, along with Xdebug and other popular PECL packages. It simplifies the process of setting up a comprehensive PHP development environment.

## Features

- Installs multiple PHP versions (`5.6` to `8.4`) using the shivammathur/php tap
- Installs Xdebug for all PHP versions
- Provides a convenient way to manage PHP extensions and dependencies

## Requirements

- [Homebrew](https://brew.sh/)

## Installation

```shell
brew install koriym/malt/phpcomplete
```

This command will install the specified PHP versions, Xdebug, and the additional PECL packages defined in the formula.

## Customization

You can customize the PHP versions and extensions installed by PHP Complete by modifying the formula file.

```shell
brew edit phpcomplete
```

When you have finished editing, reinstall to reflect the changes.

```shell
brew reinstall phpcomplete
```

## Switching PHP Versions using Aliases

To switch between different PHP versions without using additional tools or modifying terminal profiles, you can set up aliases in your shell's initialization file (~/.bashrc or ~/.zshrc). This approach allows you to quickly switch PHP versions by executing simple commands.

### Step 1: Edit Shell Initialization File

Add the following aliases to your shell's initialization file:

```shell
# ~/.bashrc or ~/.zshrc

# PHP version switcher aliases
alias php56='export PATH="/opt/homebrew/opt/php@5.6/bin:$PATH" && export PATH="/opt/homebrew/opt/php@5.6/sbin:$PATH"'
alias php70='export PATH="/opt/homebrew/opt/php@7.0/bin:$PATH" && export PATH="/opt/homebrew/opt/php@7.0/sbin:$PATH"'
alias php71='export PATH="/opt/homebrew/opt/php@7.1/bin:$PATH" && export PATH="/opt/homebrew/opt/php@7.1/sbin:$PATH"'
alias php72='export PATH="/opt/homebrew/opt/php@7.2/bin:$PATH" && export PATH="/opt/homebrew/opt/php@7.2/sbin:$PATH"'
alias php73='export PATH="/opt/homebrew/opt/php@7.3/bin:$PATH" && export PATH="/opt/homebrew/opt/php@7.3/sbin:$PATH"'
alias php74='export PATH="/opt/homebrew/opt/php@7.4/bin:$PATH" && export PATH="/opt/homebrew/opt/php@7.4/sbin:$PATH"'
alias php80='export PATH="/opt/homebrew/opt/php@8.0/bin:$PATH" && export PATH="/opt/homebrew/opt/php@8.0/sbin:$PATH"'
alias php81='export PATH="/opt/homebrew/opt/php@8.1/bin:$PATH" && export PATH="/opt/homebrew/opt/php@8.1/sbin:$PATH"'
alias php82='export PATH="/opt/homebrew/opt/php@8.2/bin:$PATH" && export PATH="/opt/homebrew/opt/php@8.2/sbin:$PATH"'
alias php83='export PATH="/opt/homebrew/opt/php@8.3/bin:$PATH" && export PATH="/opt/homebrew/opt/php@8.3/sbin:$PATH"'
alias php84='export PATH="/opt/homebrew/opt/php@8.4/bin:$PATH" && export PATH="/opt/homebrew/opt/php@8.4/sbin:$PATH"'
```

### Step 2: Reload Shell

Reload your shell to apply the changes:

```shell
. ~/.bashrc  # or . ~/.zshrc
```
### Step 3: Switch PHP Versions

You can now switch between PHP versions by using the aliases:

```shell
php81  # Switch to PHP 8.1
php74  # Switch to PHP 7.4
```

### Benefits

- **Simple and intuitive**: Quickly switch PHP versions with straightforward commands.
- **No additional tools needed**: Uses only shell features, no need for extra software.

## Switching PHP Versions using Terminal Profiles

Alternatively, you can use terminal profiles to manage different PHP versions, providing a clear and organized way to work with multiple PHP versions simultaneously.

### Step 1: Open Terminal Preferences

1. Open the terminal's preferences.
2. Select the "Profiles" tab.
3. Click the "+" button to create a new profile.
4. Give the profile a name (e.g., "PHP 8.1").

### Step 2: Set Command

In the "Shell" section, select "Command" and enter the following:

```shell
export PATH="/opt/homebrew/opt/php@8.1/bin:$PATH"
```
You can also change the title to `PHP 8.1` in the Window tab.

### Step 4: Save the Profile

Save the profile. Now, whenever you want to use a specific PHP version, you can open a new terminal window or tab and select the corresponding profile from the dropdown menu.

## Benefits

Clear version indication: Each terminal window/tab can be set to a specific PHP version, making it easy to see which version is in use.
Simultaneous use: Allows multiple terminal windows/tabs with different PHP versions open at the same time.

## Conclusion

Both methods offer effective ways to manage multiple PHP versions without relying on additional software or utilities. The alias method is quick and easy to set up, ideal for those who prefer simplicity. The terminal profile method provides better organization and clarity when working with multiple versions simultaneously. Choose the method that best fits your workflow and preferences.

