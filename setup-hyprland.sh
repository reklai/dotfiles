#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
pacman_file="$repo_dir/packages/hyprland-pacman.txt"
aur_file="$repo_dir/packages/hyprland-aur.txt"
user_services="xremap.service noctalia.service polkit-agent.service"
session_env_names="WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DISPLAY DBUS_SESSION_BUS_ADDRESS"

dry_run=0
skip_aur=0
no_link=0
no_sddm=0
aur_helper=""

usage() {
	cat <<'EOF'
usage: ./setup-hyprland.sh [--dry-run] [--skip-aur] [--no-link] [--no-sddm] [--aur-helper paru]

Install Hyprland desktop pieces, prefer the hyprland.lua config, enable needed
system/user services, use paru for AUR packages, replace yay with paru, and
link config files.
EOF
}

die() {
	printf '%s\n' "$*" >&2
	exit 1
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--dry-run)
			dry_run=1
			;;
		--skip-aur)
			skip_aur=1
			;;
		--no-link)
			no_link=1
			;;
		--no-sddm)
			no_sddm=1
			;;
		--aur-helper)
			shift
			[ "$#" -gt 0 ] || die "--aur-helper requires paru"
			aur_helper=$1
			;;
		--aur-helper=*)
			aur_helper=${1#*=}
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			usage >&2
			exit 2
			;;
	esac
	shift
done

case "$aur_helper" in
	""|paru)
		;;
	*)
		die "--aur-helper must be paru; yay is replaced with paru"
		;;
esac

say() {
	printf '%s\n' "$*"
}

run() {
	if [ "$dry_run" -eq 1 ]; then
		printf 'dry-run:'
		printf ' %s' "$@"
		printf '\n'
	else
		"$@"
	fi
}

read_packages() {
	sed -e 's/[[:space:]]*#.*//' -e '/^[[:space:]]*$/d' "$1"
}

package_words() {
	read_packages "$1" | tr '\n' ' '
}

install_pacman_packages() {
	packages=$(package_words "$pacman_file")
	[ -n "$packages" ] || return 0

	command -v pacman >/dev/null 2>&1 || die "pacman not found; this script expects Arch Linux."

	say "installing Hyprland pacman packages"
	# shellcheck disable=SC2086
	run sudo pacman -Syu --needed $packages
}

choose_aur_helper() {
	[ -z "$aur_helper" ] || return 0
	aur_helper=paru
}

install_aur_helper() {
	command -v "$aur_helper" >/dev/null 2>&1 && {
		say "using existing AUR helper: $aur_helper"
		return 0
	}

	say "$aur_helper is not installed; installing it from AUR"
	if [ "$dry_run" -eq 1 ]; then
		say "dry-run: tmpdir=\$(mktemp -d)"
		say "dry-run: git clone https://aur.archlinux.org/$aur_helper.git \"\$tmpdir/$aur_helper\""
		say "dry-run: cd \"\$tmpdir/$aur_helper\" && makepkg -si"
		return 0
	fi

	command -v git >/dev/null 2>&1 || die "git is required to install $aur_helper"
	command -v makepkg >/dev/null 2>&1 || die "makepkg is required to install $aur_helper"

	tmpdir=$(mktemp -d)
	trap 'rm -rf "$tmpdir"' 0 HUP INT TERM
	git clone "https://aur.archlinux.org/$aur_helper.git" "$tmpdir/$aur_helper"
	(
		cd "$tmpdir/$aur_helper"
		makepkg -si
	)
}

remove_replaced_yay_helper() {
	command -v yay >/dev/null 2>&1 || return 0
	if [ "$dry_run" -eq 0 ]; then
		command -v paru >/dev/null 2>&1 ||
			die "paru is not available; refusing to remove yay"
	fi

	yay_path=$(command -v yay 2>/dev/null || true)
	case "${yay_path##*/}" in
		yay)
			;;
		*)
			die "refusing to remove unexpected yay path: $yay_path"
			;;
	esac

	yay_package=""

	if [ -n "$yay_path" ] && command -v pacman >/dev/null 2>&1; then
		yay_package=$(pacman -Qoq "$yay_path" 2>/dev/null || true)
	fi

	if [ -z "$yay_package" ]; then
		say "removing unowned yay binary: $yay_path"
		run sudo rm -f "$yay_path"
		return 0
	fi

	say "removing replaced AUR helper: $yay_package"
	run sudo pacman -R --noconfirm "$yay_package"
}

install_aur_packages() {
	[ "$skip_aur" -eq 0 ] || {
		say "skipping AUR packages"
		return 0
	}

	packages=$(package_words "$aur_file")
	[ -n "$packages" ] || return 0

	choose_aur_helper
	install_aur_helper
	remove_replaced_yay_helper

	say "installing Hyprland AUR packages with $aur_helper"
	# shellcheck disable=SC2086
	run "$aur_helper" -S --needed $packages
}

link_config() {
	[ "$no_link" -eq 0 ] || {
		say "skipping config linking"
		return 0
	}

	if [ "$dry_run" -eq 1 ]; then
		"$repo_dir/link-config.sh" --dry-run
	else
		run "$repo_dir/link-config.sh"
	fi
}

enable_system_services() {
	say "enabling system services"
	run sudo systemctl enable --now NetworkManager.service

	if [ "$no_sddm" -eq 0 ]; then
		run sudo systemctl enable sddm.service
	else
		say "skipping sddm"
	fi
}

enable_user_services() {
	say "enabling user services"

	if [ "$dry_run" -eq 0 ]; then
		systemctl --user show-environment >/dev/null 2>&1 ||
			die "systemd user manager is not available; run this as your normal logged-in user, not with sudo."
	fi

	run systemctl --user daemon-reload

	for service in $user_services; do
		if [ "$dry_run" -eq 0 ]; then
			systemctl --user cat "$service" >/dev/null 2>&1 ||
				die "missing user service: $service. Make sure config linking finished first."
		fi

		run systemctl --user enable "$service"
	done

	say "xremap and noctalia start with the Hyprland graphical session"
}

start_user_services_if_session_available() {
	if [ "$dry_run" -eq 1 ]; then
		say "dry-run: if WAYLAND_DISPLAY is set, start user services now"
		# shellcheck disable=SC2086
		run systemctl --user import-environment $session_env_names
		for service in $user_services; do
			run systemctl --user start "$service"
		done
		return 0
	fi

	if [ -z "${WAYLAND_DISPLAY:-}" ]; then
		say "user services will start with the next Hyprland session"
		return 0
	fi

	say "starting user services for current Hyprland session"
	# shellcheck disable=SC2086
	run systemctl --user import-environment $session_env_names
	if command -v dbus-update-activation-environment >/dev/null 2>&1; then
		# shellcheck disable=SC2086
		run dbus-update-activation-environment --systemd $session_env_names
	fi

	for service in $user_services; do
		run systemctl --user start "$service"
	done
}

check_lua_config() {
	config_home=${XDG_CONFIG_HOME:-$HOME/.config}

	if [ -f "$config_home/hypr/hyprland.lua" ] || [ "$dry_run" -eq 1 ]; then
		say "hyprland.lua is the preferred config"
	else
		say "warning: $config_home/hypr/hyprland.lua is missing"
	fi
}

install_pacman_packages
install_aur_packages
link_config
enable_system_services
enable_user_services
start_user_services_if_session_available
check_lua_config

say "done"
say "TTY start: uwsm start hyprland"
if [ "$no_sddm" -eq 0 ]; then
	say "Display manager: reboot and choose Hyprland from sddm"
fi
