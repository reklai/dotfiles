#!/usr/bin/env bash
# Recreate this desktop and the Neovim/Ghostty dev environment.
# Run:  bash ~/dotfiles/install.sh
# Needs sudo for dnf. gnome-debloat.sh is separate and also needs sudo.
set -euo pipefail

# `sudo bash install.sh` would look for dotfiles in /root.
if [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != root ]]; then
	exec runuser -u "${SUDO_USER}" -- bash "$0" "$@"
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "${root}/nvim" || ! -f "${root}/ghostty/config" ]]; then
	echo "This script must live next to nvim/ and ghostty/." >&2
	exit 1
fi

sudo dnf copr enable -y scottames/ghostty

sudo dnf install -y \
	ghostty \
	neovim \
	nushell \
	firefox \
	nautilus \
	git \
	gcc \
	make \
	curl \
	unzip \
	ripgrep \
	fd-find \
	wl-clipboard \
	tree-sitter-cli \
	adwaita-mono-fonts \
	golang \
	nodejs \
	npm \
	python3 \
	ruff \
	clang-tools-extra \
	rust \
	cargo \
	rustfmt \
	clippy \
	zig \
	glib2

font_dir="${HOME}/.local/share/fonts/FiraCodeNerd"
if ! fc-list : family | grep -q "FiraCode Nerd Font Mono"; then
	tmp="$(mktemp -d)"
	curl -fL --retry 3 -o "${tmp}/FiraCode.tar.xz" \
		"https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/FiraCode.tar.xz"
	mkdir -p "${font_dir}"
	tar -xJf "${tmp}/FiraCode.tar.xz" -C "${font_dir}"
	rm -rf "${tmp}"
	fc-cache -f "${font_dir}"
fi

# Ghostty's font. Not packaged for Fedora.
geist_dir="${HOME}/.local/share/fonts/GeistMono"
if ! fc-list : family | grep -q "Geist Mono"; then
	tmp="$(mktemp -d)"
	curl -fL --retry 3 -o "${tmp}/geist.zip" \
		"https://github.com/vercel/geist-font/releases/download/v1.7.2/geist-font-v1.7.2.zip"
	mkdir -p "${geist_dir}"
	unzip -joq "${tmp}/geist.zip" 'geist-font/GeistMono/ttf/*.ttf' -d "${geist_dir}"
	rm -rf "${tmp}"
	fc-cache -f "${geist_dir}"
fi

mkdir -p "${HOME}/.config" "${HOME}/.vim/undodir" "${HOME}/.local/bin"
rm -rf "${HOME}/.config/nvim" "${HOME}/.config/ghostty"
cp -a "${root}/nvim" "${HOME}/.config/nvim"
cp -a "${root}/ghostty" "${HOME}/.config/ghostty"

case "$(uname -m)" in
	aarch64 | arm64) posh_asset="posh-linux-arm64" ;;
	x86_64) posh_asset="posh-linux-amd64" ;;
	*)
		echo "No Oh My Posh build for $(uname -m)." >&2
		exit 1
		;;
esac
curl -fL --retry 3 -o "${HOME}/.local/bin/oh-my-posh" \
	"https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v31.3.0/${posh_asset}"
chmod +x "${HOME}/.local/bin/oh-my-posh"

mkdir -p "${HOME}/.config/nushell" "${HOME}/.config/oh-my-posh"
cp "${root}/nushell/config.nu" "${root}/nushell/env.nu" "${HOME}/.config/nushell/"
cp "${root}/oh-my-posh/config.json" "${HOME}/.config/oh-my-posh/config.json"
"${HOME}/.local/bin/oh-my-posh" init nu --print -c "${HOME}/.config/oh-my-posh/config.json" \
	>"${HOME}/.config/oh-my-posh/init.nu"

npm install -g --prefix "${HOME}/.local" prettier eslint_d

firefox_root="${HOME}/.config/mozilla/firefox"
if [[ -f "${firefox_root}/profiles.ini" ]]; then
	profile="$(awk -F= '
		/^\[Install/ { install = 1; next }
		/^\[/ { install = 0 }
		install && $1 == "Default" { print $2; exit }
	' "${firefox_root}/profiles.ini")"
	if [[ -n "${profile}" ]]; then
		[[ "${profile}" != /* ]] && profile="${firefox_root}/${profile}"
		mkdir -p "${profile}/chrome"
		cp "${root}/firefox/user.js" "${profile}/user.js"
		cp "${root}/firefox/userChrome.js" "${profile}/chrome/userChrome.js"
	else
		echo "No Firefox install profile yet. Open Firefox once, then rerun this script." >&2
	fi
else
	echo "Firefox has not created a profile yet. Open Firefox once, then rerun this script." >&2
fi

# Loads chrome/userChrome.js, which adds the Ghostty Super shortcuts beside Ctrl.
sudo cp "${root}/firefox/autoconfig.js" /usr/lib64/firefox/defaults/pref/ghostty-keys.js
sudo cp "${root}/firefox/firefox.cfg" /usr/lib64/firefox/firefox.cfg

raise_dest="${HOME}/.local/share/gnome-shell/extensions/raise-app@local"
rm -rf "${raise_dest}"
mkdir -p "${raise_dest}/schemas"
cp "${root}/gnome/raise-app/extension.js" "${root}/gnome/raise-app/metadata.json" "${raise_dest}/"
cp "${root}/gnome/raise-app/schemas/org.gnome.shell.extensions.raise-app.gschema.xml" "${raise_dest}/schemas/"
glib-compile-schemas "${raise_dest}/schemas"
if ! gnome-extensions enable raise-app@local; then
	echo "Raise App is installed. Log out and back in, then run: gnome-extensions enable raise-app@local" >&2
fi

# Super+Shift+1 through 4 switch workspaces. Super+1 through 4 stay free for Ghostty tabs.
for i in 1 2 3 4; do
	gsettings set org.gnome.desktop.wm.keybindings "switch-to-workspace-${i}" "['<Shift><Super>${i}']"
	gsettings set org.gnome.desktop.wm.keybindings "move-to-workspace-${i}" "[]"
done
gsettings set org.gnome.shell.keybindings switch-to-application-2 "[]"
gsettings set org.gnome.shell.keybindings switch-to-application-3 "[]"
# Super+A and Super+S belong to Raise App, so tiling takes the Shift chords.
gsettings set org.gnome.mutter.keybindings toggle-tiled-left "['<Shift><Super>a']"
gsettings set org.gnome.mutter.keybindings toggle-tiled-right "['<Shift><Super>s']"
gsettings set org.gnome.shell.keybindings toggle-overview "['<Super>f']"
gsettings set org.gnome.desktop.wm.keybindings toggle-maximized "['<Shift><Super>f']"

nvim --headless "+Lazy! sync" +qa
if ! nvim --headless "+MasonToolsInstallSync" +qa; then
	echo "Mason reported a failure. clangd has no ARM build there; clang-tools-extra supplies clangd." >&2
fi

cat <<EOF
Installed:
  Ghostty, Nushell, Oh My Posh, Neovim, Firefox, Files
  Geist Mono, Adwaita Mono, FiraCode Nerd Font Mono
  git, gcc, make, curl, unzip, ripgrep, fd, tree-sitter, wl-clipboard
  Go, Node, Python, ruff, system clangd, Rust, Zig
  prettier and eslint_d in ~/.local
  Neovim plugins and Mason tools

Configs, copied so the shortcuts match this machine:
  ~/.config/nvim
  ~/.config/ghostty
  ~/.config/nushell
  ~/.config/oh-my-posh
  Ghostty starts Nushell. The prompt is Mitchell Hashimoto's Oh My Posh theme.
  Open a new shell to see it.
  Firefox keeps Ctrl, and also gets Ghostty's Super+X/C/V, T, W, Shift+W,
  Shift+E, Q, R, and Shift+R. Super+[ ] is back and forward.
  Super+Shift+[ ] moves between tabs. Not Super+1-4, and not Super+E.
  Restart Firefox. The Nushell startup banner is off.
  Raise App: Super+S Firefox, Super+A Ghostty, Super+I Files.
    Focuses the app, or launches it if needed.
  Ghostty copy/paste is Super+X / Super+C / Super+V, from the Ghostty config.
  Workspaces: Super+Shift+1 through 4. Tiling: Super+Shift+A left, Super+Shift+S right.
  Super+F opens the Activities overview. Super+Shift+F maximizes.

Remove stock GNOME apps with: bash ${root}/gnome-debloat.sh
EOF
