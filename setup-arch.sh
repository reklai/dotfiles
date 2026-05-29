#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
pacman_file="$repo_dir/packages/arch-pacman.txt"
aur_file="$repo_dir/packages/arch-aur.txt"

dry_run=0
skip_aur=0
no_link=0

usage() {
	cat <<'EOF'
usage: ./setup-arch.sh [--dry-run] [--skip-aur] [--no-link]

Installs Arch packages, installs AUR packages with paru/yay when available,
then runs ./link-dotfiles.sh to link dotfiles into ~/.config.
EOF
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

	command -v pacman >/dev/null 2>&1 || {
		printf '%s\n' "pacman not found; this bootstrap script expects Arch Linux." >&2
		exit 1
	}

	say "installing official Arch packages"
	# shellcheck disable=SC2086
	run sudo pacman -Syu --needed $packages
}

aur_helper() {
	if command -v paru >/dev/null 2>&1; then
		printf '%s\n' "paru"
	elif command -v yay >/dev/null 2>&1; then
		printf '%s\n' "yay"
	fi
}

install_aur_packages() {
	[ "$skip_aur" -eq 0 ] || {
		say "skipping AUR packages"
		return 0
	}

	packages=$(package_words "$aur_file")
	[ -n "$packages" ] || return 0

	helper=$(aur_helper || true)
	if [ -z "$helper" ]; then
		if [ "$dry_run" -eq 1 ]; then
			say "AUR helper not found; showing intended paru command"
			helper="paru"
		else
			printf '%s\n' "AUR helper not found. Install paru or yay, then rerun:" >&2
			printf '  %s\n' $packages >&2
			exit 1
		fi
	fi

	say "installing AUR packages with $helper"
	# shellcheck disable=SC2086
	run "$helper" -S --needed $packages
}

link_dotfiles() {
	[ "$no_link" -eq 0 ] || {
		say "skipping dotfile linking"
		return 0
	}

	if [ "$dry_run" -eq 1 ]; then
		"$repo_dir/link-dotfiles.sh" --dry-run
	else
		run "$repo_dir/link-dotfiles.sh"
	fi
}

install_pacman_packages
install_aur_packages
link_dotfiles

say "done"
