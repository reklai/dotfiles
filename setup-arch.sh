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
usage: ./setup-arch.sh [--dry-run] [--skip-aur] [--no-link] [--aur-helper paru|yay]

Installs official Arch packages, uses an installed AUR helper when available,
asks which helper to install when needed, installs AUR packages, then links
config files.
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
			[ "$#" -gt 0 ] || die "--aur-helper requires paru or yay"
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
	""|paru|yay)
		;;
	*)
		die "--aur-helper must be paru or yay"
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

choose_aur_helper() {
	[ -z "$aur_helper" ] || return 0

	if command -v paru >/dev/null 2>&1; then
		aur_helper=paru
		return 0
	elif command -v yay >/dev/null 2>&1; then
		aur_helper=yay
		return 0
	fi

	if [ "$dry_run" -eq 1 ]; then
		aur_helper=paru
		return 0
	fi

	if [ ! -t 0 ]; then
		die "no AUR helper found; rerun with --aur-helper paru or --aur-helper yay"
		return 0
	fi

	while :; do
		printf '%s' "Choose AUR helper: [1] paru [2] yay > "
		read -r answer
		case "$answer" in
			""|1|paru)
				aur_helper=paru
				return 0
				;;
			2|yay)
				aur_helper=yay
				return 0
				;;
			*)
				say "enter 1, 2, paru, or yay"
				;;
		esac
	done
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

install_aur_packages() {
	[ "$skip_aur" -eq 0 ] || {
		say "skipping AUR packages"
		return 0
	}

	packages=$(package_words "$aur_file")
	[ -n "$packages" ] || return 0

	choose_aur_helper
	install_aur_helper

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
install_aur_packages
link_config

say "done"
