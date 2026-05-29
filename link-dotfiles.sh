#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
src_config="$repo_dir/.config"
dest_config="${XDG_CONFIG_HOME:-$HOME/.config}"
backup_root="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backup"
timestamp=$(date +%Y%m%d-%H%M%S)
backup_dir="$backup_root/$timestamp"

usage() {
	printf '%s\n' "usage: ./link-dotfiles.sh [--dry-run]"
}

dry_run=0
case "${1:-}" in
	"")
		;;
	--dry-run)
		dry_run=1
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

link_entry() {
	name=$1
	src="$src_config/$name"
	dest="$dest_config/$name"

	if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
		say "already linked: $dest"
		return 0
	fi

	if [ -e "$dest" ] || [ -L "$dest" ]; then
		run mkdir -p "$backup_dir"
		say "backup: $dest -> $backup_dir/$name"
		run mv "$dest" "$backup_dir/$name"
	fi

	run mkdir -p "$dest_config"
	say "link: $dest -> $src"
	run ln -s "$src" "$dest"
}

[ -d "$src_config" ] || {
	printf '%s\n' "missing source directory: $src_config" >&2
	exit 1
}

for entry in "$src_config"/* "$src_config"/.[!.]* "$src_config"/..?*; do
	[ -e "$entry" ] || [ -L "$entry" ] || continue
	name=${entry##*/}
	link_entry "$name"
done

say "done"
