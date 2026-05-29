# dotfiles

Personal `.config` dotfiles for a CachyOS/Arch workstation.

## Fresh Arch Machine

From a fresh machine:

```sh
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
./setup-arch.sh
```

`setup-arch.sh` installs packages from:

- `packages/arch-pacman.txt` with `sudo pacman -Syu --needed`
- `packages/arch-aur.txt` with `paru` or `yay`, if one is installed

Then it runs `./link-dotfiles.sh`.

## Dotfile Linking

`link-dotfiles.sh` links each top-level entry in this repo's `.config` directory into
`~/.config`.

For example, after `./link-dotfiles.sh`, this repo's:

```text
~/dotfiles/.config/nvim
```

is linked at:

```text
~/.config/nvim
```

This is a symlink, not a copy. There is no background monitor or daemon. Changes
made through `~/.config/nvim` are changes to the files in `~/dotfiles`, so Git
will see them immediately. Git still does not commit or push anything
automatically.

If a destination already exists and is not already the right symlink, it is moved
to:

```text
~/.local/state/dotfiles/backup/<timestamp>/
```

Preview changes first:

```sh
./link-dotfiles.sh --dry-run
./setup-arch.sh --dry-run
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

## Intentionally Not Tracked

- Browser profile data
- `dconf` binary state
- PulseAudio/PipeWire cookies
- Session restore files
- `node_modules`
- Nested `.git` directories
