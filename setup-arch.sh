#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
pacman_file="$repo_dir/packages/arch-pacman.txt"
aur_file="$repo_dir/packages/arch-aur.txt"

dry_run=0
skip_aur=0
no_link=0
aur_helper=""

usage() {
	cat <<'EOF'
usage: ./setup-arch.sh [--dry-run] [--skip-aur] [--no-link] [--aur-helper paru]

Installs official Arch packages, sets the stable Rust toolchain, uses an
installed paru helper when available, installs paru when needed, removes yay
after paru is available, installs AUR packages, then links config files.
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

	say "installing official Arch packages"
	# shellcheck disable=SC2086
	run sudo pacman -Syu --needed $packages
}

setup_rust_toolchain() {
	say "setting Rust default toolchain"

	if [ "$dry_run" -eq 1 ]; then
		run rustup default stable
		return 0
	fi

	if command -v rustup >/dev/null 2>&1; then
		run rustup default stable
	else
		say "warning: rustup not found; skipping Rust toolchain setup"
	fi
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

	say "installing AUR packages with $aur_helper"
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

install_pacman_packages
setup_rust_toolchain
install_aur_packages
link_config

say "done"
