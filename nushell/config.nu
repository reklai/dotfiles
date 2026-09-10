$env.config.show_banner = false
$env.config.highlight_resolved_externals = true

# Ensure we can use the terminal for GPG signing
if (is-terminal --stdin) {
  $env.GPG_TTY = (tty)
}

# Override some commands to use 1password
alias amp = op run -- amp
alias codex = op run -- codex

# Mitchell Hashimoto's Oh My Posh prompt (nixos-config users/mitchellh/omp.json)
source ~/.config/oh-my-posh/init.nu
