#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
src_config="$repo_dir/.config"
dest_config="${XDG_CONFIG_HOME:-$HOME/.config}"
backup_root="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backup"
timestamp=$(date +%Y%m%d-%H%M%S)
backup_dir="$backup_root/$timestamp"

usage() {
	printf '%s\n' "usage: ./link-config.sh [--dry-run]"
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

canonical_path() {
	if command -v realpath >/dev/null 2>&1; then
		realpath "$1" 2>/dev/null || printf '%s\n' "$1"
	else
		printf '%s\n' "$1"
	fi
}

same_file() {
	src=$1
	dest=$2

	if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
		return 0
	fi

	[ -e "$dest" ] || return 1
	[ "$(canonical_path "$src")" = "$(canonical_path "$dest")" ]
}

link_file() {
	src=$1
	rel=${src#"$src_config"/}
	dest="$dest_config/$rel"
	dest_parent=${dest%/*}
	backup_path="$backup_dir/$rel"
	backup_parent=${backup_path%/*}

	if same_file "$src" "$dest"; then
		say "already linked: $dest"
		return 0
	fi

	if [ -e "$dest" ] || [ -L "$dest" ]; then
		run mkdir -p "$backup_parent"
		say "backup: $dest -> $backup_path"
		run mv "$dest" "$backup_path"
	fi

	run mkdir -p "$dest_parent"
	say "link: $dest -> $src"
	run ln -s "$src" "$dest"
}

[ -d "$src_config" ] || {
	printf '%s\n' "missing source directory: $src_config" >&2
	exit 1
}

find "$src_config" \( -type f -o -type l \) -print | sort | while IFS= read -r src; do
	link_file "$src"
done

say "done"
