Setup fresh Arch machine:

```sh
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
./setup-arch.sh
```

`setup-arch.sh` installs pacman packages from:

- `packages/arch-pacman.txt`

Then it checks for an AUR helper:

- `paru`
- `yay`

If one exists, it uses it. If none exists, it asks which one to install.

AUR packages come from:

- `packages/arch-aur.txt`

Then it runs:

```sh
./link-config.sh
```

Official packages installed:

```text
base-devel bash-completion git less openssh rsync sudo which wget
bat eza fd fzf jq ripgrep starship tmux tree tree-sitter-cli
brightnessctl code dolphin ghostty grim hyprland libnotify obs-studio
pavucontrol pipewire pipewire-alsa pipewire-pulse playerctl slurp uwsm
wireplumber wl-clipboard wofi xdg-desktop-portal xdg-desktop-portal-hyprland
noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-dejavu
ttf-jetbrains-mono-nerd ttf-meslo-nerd
bear clang cmake eslint_d gdb go gopls lldb lua-language-server neovim ninja
nodejs npm pyright python python-pip python-pynvim ruff rustup stylua zig
```

AUR packages installed:

```text
nerd-fonts-sf-mono noctalia-qs noctalia-shell prettierd xremap-hypr-bin
zen-browser-bin
```

For noninteractive setup:

```sh
./setup-arch.sh --aur-helper paru
./setup-arch.sh --aur-helper yay
```

Useful preview:

```sh
./setup-arch.sh --dry-run --aur-helper paru
```

## Dotfile Linking

Prefer symlink over copy:

```sh
./link-config.sh
```

Links tracked files from:

```text
~/dotfiles/.config
```

to:

```text
~/.config
```

Example:

```text
~/dotfiles/.config/nvim/init.lua -> ~/.config/nvim/init.lua
```

Symlink means edits through `~/.config` are edits inside `~/dotfiles`.

No monitor. No daemon. Git sees changes, but nothing commits automatically.

Existing files get backed up to:

```text
~/.local/state/dotfiles/backup/<timestamp>/
```

Preview first:

```sh
./link-config.sh --dry-run
./setup-arch.sh --dry-run --aur-helper paru
```

## Plain Copy

Prefer real copied files over symlinks:

```sh
./copy-config.sh
```

Copies:

```text
~/dotfiles/.config
```

to:

```text
~/.config
```

## Included

- `ghostty`
- `hypr`
- `noctalia`
- `nvim`
- `starship.toml`
- `systemd/user`
- `wofi`
- `xremap`
