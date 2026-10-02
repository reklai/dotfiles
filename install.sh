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
	glib2 \
	dconf \
	flatpak \
	btop \
	htop \
	java-25-openjdk-devel \
	java-latest-openjdk-devel \
	python3-numpy \
	python3-opencv \
	python3-pyqt6 \
	egl-utils \
	vulkan-tools

if ! flatpak install -y flathub com.jetbrains.IntelliJ-IDEA-Community com.mattjakeman.ExtensionManager; then
	echo "Flatpak install failed. Enable Flathub, then rerun this script." >&2
fi

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

mkdir -p "${HOME}/.config/btop" "${HOME}/.config/gtk-3.0" "${HOME}/.config/gtk-4.0"
cp "${root}/btop/btop.conf" "${HOME}/.config/btop/btop.conf"
cp "${root}/gtk/settings.ini" "${HOME}/.config/gtk-3.0/settings.ini"
cp "${root}/gtk/settings.ini" "${HOME}/.config/gtk-4.0/settings.ini"
if [[ ! -e "${HOME}/.gitconfig" ]]; then
	cp "${root}/git/gitconfig" "${HOME}/.gitconfig"
fi

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

# Fedora's ~/.bashrc sources every file in ~/.bashrc.d.
mkdir -p "${HOME}/.bashrc.d" "${HOME}/.config/oh-my-posh"
cp "${root}/oh-my-posh/config.json" "${HOME}/.config/oh-my-posh/config.json"
cp "${root}/bash/oh-my-posh.sh" "${HOME}/.bashrc.d/oh-my-posh.sh"

# Session environment. Takes effect at the next login.
mkdir -p "${HOME}/.config/environment.d"
cp "${root}/environment.d/99-gnome-fast.conf" "${HOME}/.config/environment.d/99-gnome-fast.conf"

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

# Shortcuts, appearance, dock and the rest of the GNOME settings.
dconf load / < "${root}/gnome/dconf.ini"

# The share name is this Mac's. Other hypervisors and bare metal skip it.
if [[ "$(systemd-detect-virt 2>/dev/null || true)" == vmware ]]; then
	sudo dnf install -y open-vm-tools-desktop
	mkdir -p "${HOME}/.config/systemd/user"
	cp "${root}/systemd/vmware-share.service" "${HOME}/.config/systemd/user/vmware-share.service"
	systemctl --user daemon-reload
	if ! systemctl --user enable --now vmware-share.service; then
		echo "vmware-share.service did not start. Share a folder named reklai from Fusion, then rerun this script." >&2
	fi
fi

nvim --headless "+Lazy! sync" +qa
if ! nvim --headless "+MasonToolsInstallSync" +qa; then
	echo "Mason reported a failure. clangd has no ARM build there; clang-tools-extra supplies clangd." >&2
fi

cat <<EOF
Installed:
  Ghostty, Oh My Posh, Neovim, Firefox, Files
  btop, htop, OpenJDK 25 and latest, PyQt6, OpenCV, NumPy
  IntelliJ IDEA Community and Extension Manager from Flathub
  Geist Mono, Adwaita Mono, FiraCode Nerd Font Mono
  git, gcc, make, curl, unzip, ripgrep, fd, tree-sitter, wl-clipboard
  Go, Node, Python, ruff, system clangd, Rust, Zig
  prettier and eslint_d in ~/.local
  Neovim plugins and Mason tools

Configs, copied so the shortcuts match this machine:
  ~/.config/nvim
  ~/.config/ghostty
  ~/.config/oh-my-posh
  ~/.bashrc.d/oh-my-posh.sh
  ~/.config/environment.d/99-gnome-fast.conf
    GTK4 apps render with OpenGL. Log out and back in to apply.
  ~/.config/btop/btop.conf
  ~/.config/gtk-3.0/settings.ini and ~/.config/gtk-4.0/settings.ini
  ~/.gitconfig, only if there was none
  GNOME settings from gnome/dconf.ini: dark, slate accent, no animations,
    no hot corners, one workspace, Super alone does nothing.
  ~/vmware-share mounts at login, on VMware guests only.
  Ghostty starts bash. The prompt is Mitchell Hashimoto's Oh My Posh theme.
  Open a new shell to see it.
  Firefox keeps Ctrl, and also gets Ghostty's Super+X/C/V, T, W, Shift+W,
  Shift+E, Q, R, and Shift+R. Super+[ ] is back and forward.
  Super+Shift+[ ] moves between tabs. Not Super+1-4, and not Super+E.
  Ctrl+N and Ctrl+P are Down and Up, replacing New Window and Print.
  Restart Firefox.
  Raise App: Super+S Firefox, Super+A Ghostty, Super+I Files.
    Focuses the app, or launches it if needed.
  Ghostty copy/paste is Super+X / Super+C / Super+V, from the Ghostty config.
  Workspaces: Super+Shift+1 through 4. Tiling: Super+Shift+A left, Super+Shift+S right.
  Super+F opens the Activities overview. Super+Shift+F maximizes.
  Super+Q is left to each app: it quits Firefox and Ghostty.
  Super+P takes a screenshot. Super+=/- zooms.

Remove stock GNOME apps with: bash ${root}/gnome-debloat.sh
EOF
