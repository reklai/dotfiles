#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
src_config="$repo_dir/.config"
dest_config="${XDG_CONFIG_HOME:-$HOME/.config}"
backup_root="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backup"
timestamp=$(date +%Y%m%d-%H%M%S)
backup_dir="$backup_root/$timestamp"

usage() {
	printf '%s\n' "usage: ./copy-config.sh [--dry-run]"
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

copy_file() {
	src=$1
	rel=${src#"$src_config"/}
	dest="$dest_config/$rel"
	dest_parent=${dest%/*}
	backup_path="$backup_dir/$rel"
	backup_parent=${backup_path%/*}

	if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
		say "already copied: $dest"
		return 0
	fi

	if [ -e "$dest" ] || [ -L "$dest" ]; then
		run mkdir -p "$backup_parent"
		say "backup: $dest -> $backup_path"
		run mv "$dest" "$backup_path"
	fi

	run mkdir -p "$dest_parent"
	say "copy: $src -> $dest"
	run cp -a "$src" "$dest"
}

[ -d "$src_config" ] || {
	printf '%s\n' "missing source directory: $src_config" >&2
	exit 1
}

find "$src_config" \( -type f -o -type l \) -print | sort | while IFS= read -r src; do
	copy_file "$src"
done

say "done"
