#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
subject="${repo_root}/bin/hyprgroup"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mock_bin="${tmp_dir}/bin"
runtime_dir="${tmp_dir}/runtime"
active_json="${tmp_dir}/active.json"
active_after_move_json="${tmp_dir}/active-after-move.json"
clients_json="${tmp_dir}/clients.json"
dispatch_log="${tmp_dir}/dispatch.log"
notify_log="${tmp_dir}/notify.log"

mkdir -p "$mock_bin" "$runtime_dir"
: >"$dispatch_log"
: >"$notify_log"
printf '[]\n' >"$clients_json"

cat >"${mock_bin}/hyprctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
	activewindow)
		cat "$HYPRGROUP_TEST_ACTIVE_JSON"
		;;
	clients)
		cat "$HYPRGROUP_TEST_CLIENTS_JSON"
		;;
	dispatch)
		printf '%s\n' "${2:-}" >>"$HYPRGROUP_TEST_DISPATCH_LOG"
		if [[ "${2:-}" =~ address:(0x[0-9a-fA-F]+) ]]; then
			address="${BASH_REMATCH[1]}"
			jq --arg address "$address" '.[] | select(.address == $address)' "$HYPRGROUP_TEST_CLIENTS_JSON" >"$HYPRGROUP_TEST_ACTIVE_JSON"
		elif [[ "${2:-}" =~ workspace[[:space:]]*=[[:space:]]*(-?[0-9]+) ]]; then
			workspace="${BASH_REMATCH[1]}"
			address="$(jq -r '.address' "$HYPRGROUP_TEST_ACTIVE_JSON")"
			tmp="${HYPRGROUP_TEST_CLIENTS_JSON}.$$"
			jq --arg address "$address" --argjson workspace "$workspace" 'map(if .address == $address then (.workspace.id = $workspace) else . end)' "$HYPRGROUP_TEST_CLIENTS_JSON" >"$tmp"
			mv "$tmp" "$HYPRGROUP_TEST_CLIENTS_JSON"
			tmp="${HYPRGROUP_TEST_ACTIVE_JSON}.$$"
			jq --argjson workspace "$workspace" '.workspace.id = $workspace' "$HYPRGROUP_TEST_ACTIVE_JSON" >"$tmp"
			mv "$tmp" "$HYPRGROUP_TEST_ACTIVE_JSON"
		elif [[ "${2:-}" == *"into_or_create_group"* && -n "${HYPRGROUP_TEST_ACTIVE_AFTER_MOVE_JSON:-}" && -f "$HYPRGROUP_TEST_ACTIVE_AFTER_MOVE_JSON" ]]; then
			cat "$HYPRGROUP_TEST_ACTIVE_AFTER_MOVE_JSON" >"$HYPRGROUP_TEST_ACTIVE_JSON"
		fi
		;;
	cursorpos)
		printf '100, 100\n'
		;;
	*)
		printf 'unexpected hyprctl command: %s\n' "$*" >&2
		exit 64
		;;
esac
MOCK

cat >"${mock_bin}/notify-send" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$HYPRGROUP_TEST_NOTIFY_LOG"
MOCK

chmod +x "${mock_bin}/hyprctl" "${mock_bin}/notify-send"

export HYPRGROUP_TEST_ACTIVE_JSON="$active_json"
export HYPRGROUP_TEST_ACTIVE_AFTER_MOVE_JSON="$active_after_move_json"
export HYPRGROUP_TEST_CLIENTS_JSON="$clients_json"
export HYPRGROUP_TEST_DISPATCH_LOG="$dispatch_log"
export HYPRGROUP_TEST_NOTIFY_LOG="$notify_log"
export PATH="${mock_bin}:${PATH}"
export XDG_RUNTIME_DIR="$runtime_dir"

state_file="${runtime_dir}/hyprgroup-containers.tsv"

reset_logs() {
	: >"$dispatch_log"
	: >"$notify_log"
	rm -f "$active_after_move_json"
}

write_active() {
	printf '%s\n' "$1" >"$active_json"
}

assert_file_equals() {
	local file="$1"
	local expected="$2"
	local actual

	actual="$(cat "$file" 2>/dev/null || true)"

	if [[ "$actual" != "$expected" ]]; then
		printf 'Expected %s to contain:\n%s\nActual:\n%s\n' "$file" "$expected" "$actual" >&2
		return 1
	fi
}

assert_no_notifications() {
	assert_file_equals "$notify_log" ""
}

test_remove_remembered_one_window_container() {
	reset_logs
	write_active '{"address":"0xaaa","monitor":1,"workspace":{"id":1},"grouped":[]}'
	printf 'anchor\t0xaaa\n' >"$state_file"
	printf '[{"address":"0xaaa","workspace":{"id":1}}]\n' >"$clients_json"

	bash "$subject" remove

	assert_file_equals "$dispatch_log" ""
	assert_file_equals "$state_file" ""
	assert_no_notifications
}

test_remove_native_group_remembers_remaining_window() {
	reset_logs
	write_active '{"address":"0xaaa","monitor":1,"workspace":{"id":1},"grouped":["0xaaa","0xbbb"]}'
	printf 'anchor\t0xaaa\n' >"$state_file"
	printf '[{"address":"0xaaa","workspace":{"id":1}},{"address":"0xbbb","workspace":{"id":1}}]\n' >"$clients_json"

	bash "$subject" remove

	assert_file_equals "$dispatch_log" 'hl.dsp.window.move({ out_of_group = true })'
	assert_file_equals "$state_file" $'anchor\t0xbbb'
	assert_no_notifications
}

test_remove_outside_container_is_noop() {
	reset_logs
	write_active '{"address":"0xccc","monitor":1,"workspace":{"id":1},"grouped":[]}'
	printf '[{"address":"0xccc","workspace":{"id":1}}]\n' >"$clients_json"
	: >"$state_file"

	bash "$subject" remove

	assert_file_equals "$dispatch_log" ""
	assert_file_equals "$state_file" ""
	assert_no_notifications
}

test_remove_selected_remembered_anchor_remembers_remaining_window() {
	reset_logs
	write_active '{"address":"0x999","monitor":1,"workspace":{"id":1},"grouped":[]}'
	printf '%s\n' \
		'[{"address":"0x111","workspace":{"id":2},"grouped":["0x111","0x222"]},' \
		'{"address":"0x222","workspace":{"id":2},"grouped":["0x111","0x222"]},' \
		'{"address":"0x999","workspace":{"id":1},"grouped":[]}]' \
		>"$clients_json"
	printf 'anchor\t0x111\n' >"$state_file"

	bash "$subject" remove 0x111

	assert_file_equals "$dispatch_log" $'hl.dsp.focus({ window = "address:0x111" })\nhl.dsp.window.move({ out_of_group = true })'
	assert_file_equals "$state_file" $'anchor\t0x222'
	assert_no_notifications
}

test_remove_rejects_selected_window_outside_container() {
	reset_logs
	write_active '{"address":"0xaaa","monitor":1,"workspace":{"id":1},"grouped":["0xaaa","0xbbb"]}'
	printf '%s\n' \
		'[{"address":"0xaaa","workspace":{"id":1},"grouped":["0xaaa","0xbbb"]},' \
		'{"address":"0xbbb","workspace":{"id":1},"grouped":["0xaaa","0xbbb"]},' \
		'{"address":"0x999","workspace":{"id":1},"grouped":[]}]' \
		>"$clients_json"
	printf 'anchor\t0xaaa\n' >"$state_file"

	if bash "$subject" remove 0x999; then
		printf 'Expected remove outside Container to fail.\n' >&2
		return 1
	fi

	assert_file_equals "$dispatch_log" ""
	assert_file_equals "$state_file" $'anchor\t0xaaa'
	assert_file_equals "$notify_log" "HyprGroup Window is not in the Container."
}

test_select_group_window_restores_original_focus_when_focus_is_outside_container() {
	reset_logs
	write_active '{"address":"0x999","monitor":1,"workspace":{"id":1},"grouped":[]}'
	printf '%s\n' \
		'[{"address":"0x111","workspace":{"id":2},"grouped":["0x111","0x222"]},' \
		'{"address":"0x222","workspace":{"id":2},"grouped":["0x111","0x222"]},' \
		'{"address":"0x999","workspace":{"id":1},"grouped":[]}]' \
		>"$clients_json"
	printf 'anchor\t0x111\n' >"$state_file"

	bash "$subject" select 0x222

	assert_file_equals "$dispatch_log" $'hl.dsp.focus({ window = "address:0x222" })\nhl.dsp.focus({ window = "address:0x999" })'
	assert_file_equals "$state_file" $'anchor\t0x111'
	assert_no_notifications
}

test_select_group_window_keeps_focus_when_active_is_same_container() {
	reset_logs
	write_active '{"address":"0x111","monitor":1,"workspace":{"id":1},"grouped":["0x111","0x222"]}'
	printf '%s\n' \
		'[{"address":"0x111","workspace":{"id":1},"grouped":["0x111","0x222"]},' \
		'{"address":"0x222","workspace":{"id":1},"grouped":["0x111","0x222"]}]' \
		>"$clients_json"
	printf 'anchor\t0x111\n' >"$state_file"

	bash "$subject" select 0x222

	assert_file_equals "$dispatch_log" 'hl.dsp.focus({ window = "address:0x222" })'
	assert_file_equals "$state_file" $'anchor\t0x111'
	assert_no_notifications
}

test_select_rejects_window_outside_container() {
	reset_logs
	write_active '{"address":"0xaaa","monitor":1,"workspace":{"id":1},"grouped":["0xaaa","0xbbb"]}'
	printf '%s\n' \
		'[{"address":"0xaaa","workspace":{"id":1},"grouped":["0xaaa","0xbbb"]},' \
		'{"address":"0xbbb","workspace":{"id":1},"grouped":["0xaaa","0xbbb"]},' \
		'{"address":"0x999","workspace":{"id":1},"grouped":[]}]' \
		>"$clients_json"
	printf 'anchor\t0xaaa\n' >"$state_file"

	if bash "$subject" select 0x999; then
		printf 'Expected select outside Container to fail.\n' >&2
		return 1
	fi

	assert_file_equals "$dispatch_log" ""
	assert_file_equals "$state_file" $'anchor\t0xaaa'
	assert_file_equals "$notify_log" "HyprGroup Window is not in the Container."
}

test_add_remembered_one_window_container_is_noop() {
	reset_logs
	write_active '{"address":"0xddd","monitor":1,"workspace":{"id":1},"grouped":[]}'
	printf 'anchor\t0xddd\n' >"$state_file"
	printf '[{"address":"0xddd","workspace":{"id":1}}]\n' >"$clients_json"

	bash "$subject" add

	assert_file_equals "$dispatch_log" ""
	assert_file_equals "$state_file" $'anchor\t0xddd'
	assert_no_notifications
}

test_add_new_container_remembers_global_anchor() {
	reset_logs
	write_active '{"address":"0xeee","monitor":1,"workspace":{"id":2},"at":[0,0],"size":[100,100],"floating":false,"fullscreen":0,"grouped":[]}'
	printf '[{"address":"0xeee","workspace":{"id":2},"monitor":1,"at":[0,0],"size":[100,100],"grouped":[]}]\n' >"$clients_json"
	: >"$state_file"

	bash "$subject" add

	assert_file_equals "$dispatch_log" $'hl.dsp.window.fullscreen({ action = "unset" })\nhl.dsp.window.float({ action = "off" })\nhl.dsp.group.toggle({})\nhl.dsp.group.lock_active({ action = "lock" })'
	assert_file_equals "$state_file" $'anchor\t0xeee'
	assert_no_notifications
}

test_add_brings_global_container_to_active_workspace() {
	reset_logs
	write_active '{"address":"0x222","monitor":1,"workspace":{"id":2},"at":[300,0],"size":[100,100],"floating":false,"fullscreen":0,"grouped":[]}'
	printf '%s\n' \
		'[{"address":"0x111","workspace":{"id":1},"monitor":1,"at":[0,0],"size":[100,100],"grouped":["0x111"]},' \
		'{"address":"0x222","workspace":{"id":2},"monitor":1,"at":[300,0],"size":[100,100],"grouped":[]}]' \
		>"$clients_json"
	printf '{"address":"0x222","monitor":1,"workspace":{"id":2},"at":[300,0],"size":[100,100],"floating":false,"fullscreen":0,"grouped":["0x111","0x222"]}\n' >"$active_after_move_json"
	printf 'anchor\t0x111\n' >"$state_file"

	bash "$subject" add

	assert_file_equals "$dispatch_log" $'hl.dsp.window.fullscreen({ action = "unset" })\nhl.dsp.window.float({ action = "off" })\nhl.dsp.focus({ window = "address:0x111" })\nhl.dsp.window.move({ workspace = 2 })\nhl.dsp.focus({ window = "address:0x222" })\nhl.dsp.window.move({ into_or_create_group = "l" })\nhl.dsp.group.lock_active({ action = "lock" })'
	assert_file_equals "$state_file" $'anchor\t0x222'
	assert_no_notifications
}

test_move_container_here_moves_remembered_container_to_active_workspace() {
	reset_logs
	write_active '{"address":"0x999","monitor":1,"workspace":{"id":2},"grouped":[]}'
	printf '%s\n' \
		'[{"address":"0x111","workspace":{"id":1},"grouped":["0x111","0x222"]},' \
		'{"address":"0x222","workspace":{"id":1},"grouped":["0x111","0x222"]},' \
		'{"address":"0x999","workspace":{"id":2},"grouped":[]}]' \
		>"$clients_json"
	printf 'anchor\t0x111\n' >"$state_file"

	bash "$subject" move-here

	assert_file_equals "$dispatch_log" $'hl.dsp.focus({ window = "address:0x111" })\nhl.dsp.window.move({ workspace = 2 })\nhl.dsp.focus({ window = "address:0x999" })'
	assert_file_equals "$state_file" $'anchor\t0x111'
	assert_no_notifications
}

test_move_container_here_is_noop_when_container_is_already_here() {
	reset_logs
	write_active '{"address":"0x999","monitor":1,"workspace":{"id":1},"grouped":[]}'
	printf '%s\n' \
		'[{"address":"0x111","workspace":{"id":1},"grouped":["0x111","0x222"]},' \
		'{"address":"0x222","workspace":{"id":1},"grouped":["0x111","0x222"]},' \
		'{"address":"0x999","workspace":{"id":1},"grouped":[]}]' \
		>"$clients_json"
	printf 'anchor\t0x111\n' >"$state_file"

	bash "$subject" move-here

	assert_file_equals "$dispatch_log" ""
	assert_file_equals "$state_file" $'anchor\t0x111'
	assert_no_notifications
}

test_move_container_here_rejects_without_remembered_container() {
	reset_logs
	write_active '{"address":"0x999","monitor":1,"workspace":{"id":1},"grouped":[]}'
	printf '[{"address":"0x999","workspace":{"id":1},"grouped":[]}]\n' >"$clients_json"
	: >"$state_file"

	if bash "$subject" move-here; then
		printf 'Expected move-here without remembered Container to fail.\n' >&2
		return 1
	fi

	assert_file_equals "$dispatch_log" ""
	assert_file_equals "$state_file" ""
	assert_file_equals "$notify_log" "HyprGroup No Container to move."
}

test_reorder_moves_group_window_forward_to_index() {
	reset_logs
	write_active '{"address":"0xaaa","monitor":1,"workspace":{"id":1},"grouped":["0xaaa","0xbbb","0xccc"]}'
	printf '%s\n' \
		'[{"address":"0xaaa","workspace":{"id":1},"grouped":["0xaaa","0xbbb","0xccc"]},' \
		'{"address":"0xbbb","workspace":{"id":1},"grouped":["0xaaa","0xbbb","0xccc"]},' \
		'{"address":"0xccc","workspace":{"id":1},"grouped":["0xaaa","0xbbb","0xccc"]}]' \
		>"$clients_json"

	bash "$subject" reorder 0xaaa 2

	assert_file_equals "$dispatch_log" $'hl.dsp.group.move_window({ forward = true, window = "address:0xaaa" })\nhl.dsp.group.move_window({ forward = true, window = "address:0xaaa" })'
	assert_no_notifications
}

test_reorder_moves_group_window_backward_to_index() {
	reset_logs
	write_active '{"address":"0xccc","monitor":1,"workspace":{"id":1},"grouped":["0xaaa","0xbbb","0xccc"]}'
	printf '%s\n' \
		'[{"address":"0xaaa","workspace":{"id":1},"grouped":["0xaaa","0xbbb","0xccc"]},' \
		'{"address":"0xbbb","workspace":{"id":1},"grouped":["0xaaa","0xbbb","0xccc"]},' \
		'{"address":"0xccc","workspace":{"id":1},"grouped":["0xaaa","0xbbb","0xccc"]}]' \
		>"$clients_json"

	bash "$subject" reorder 0xccc 0

	assert_file_equals "$dispatch_log" $'hl.dsp.group.move_window({ forward = false, window = "address:0xccc" })\nhl.dsp.group.move_window({ forward = false, window = "address:0xccc" })'
	assert_no_notifications
}

test_reorder_single_window_container_is_noop() {
	reset_logs
	write_active '{"address":"0xaaa","monitor":1,"workspace":{"id":1},"grouped":[]}'
	printf '[{"address":"0xaaa","workspace":{"id":1},"grouped":[]}]\n' >"$clients_json"

	bash "$subject" reorder 0xaaa 0

	assert_file_equals "$dispatch_log" ""
	assert_no_notifications
}

test_close_active_grouped_window_keeps_anchor() {
	reset_logs
	write_active '{"address":"0xaaa","monitor":1,"workspace":{"id":1},"grouped":["0xaaa","0xbbb"]}'
	printf '[{"address":"0xaaa","workspace":{"id":1},"grouped":["0xaaa","0xbbb"]},{"address":"0xbbb","workspace":{"id":1},"grouped":["0xaaa","0xbbb"]}]\n' >"$clients_json"
	printf 'anchor\t0xbbb\n' >"$state_file"

	bash "$subject" close 0xaaa

	assert_file_equals "$dispatch_log" 'hl.dsp.window.close({})'
	assert_file_equals "$state_file" $'anchor\t0xbbb'
	assert_no_notifications
}

test_close_remembered_anchor_remembers_remaining_window() {
	reset_logs
	write_active '{"address":"0x999","monitor":1,"workspace":{"id":1},"grouped":[]}'
	printf '%s\n' \
		'[{"address":"0x111","workspace":{"id":2},"grouped":["0x111","0x222"]},' \
		'{"address":"0x222","workspace":{"id":2},"grouped":["0x111","0x222"]},' \
		'{"address":"0x999","workspace":{"id":1},"grouped":[]}]' \
		>"$clients_json"
	printf 'anchor\t0x111\n' >"$state_file"

	bash "$subject" close 0x111

	assert_file_equals "$dispatch_log" $'hl.dsp.focus({ window = "address:0x111" })\nhl.dsp.window.close({})'
	assert_file_equals "$state_file" $'anchor\t0x222'
	assert_no_notifications
}

test_close_remembered_active_when_focus_is_outside_group() {
	reset_logs
	write_active '{"address":"0x999","monitor":1,"workspace":{"id":1},"grouped":[],"focusHistoryID":0}'
	printf '%s\n' \
		'[{"address":"0x111","workspace":{"id":2},"grouped":["0x111","0x222"],"focusHistoryID":8},' \
		'{"address":"0x222","workspace":{"id":2},"grouped":["0x111","0x222"],"focusHistoryID":2},' \
		'{"address":"0x999","workspace":{"id":1},"grouped":[],"focusHistoryID":0}]' \
		>"$clients_json"
	printf 'anchor\t0x111\n' >"$state_file"

	bash "$subject" close

	assert_file_equals "$dispatch_log" $'hl.dsp.focus({ window = "address:0x222" })\nhl.dsp.window.close({})'
	assert_file_equals "$state_file" $'anchor\t0x111'
	assert_no_notifications
}

test_close_one_window_container_forgets_anchor() {
	reset_logs
	write_active '{"address":"0xaaa","monitor":1,"workspace":{"id":1},"grouped":[]}'
	printf '[{"address":"0xaaa","workspace":{"id":1},"grouped":[]}]\n' >"$clients_json"
	printf 'anchor\t0xaaa\n' >"$state_file"

	bash "$subject" close

	assert_file_equals "$dispatch_log" 'hl.dsp.window.close({})'
	assert_file_equals "$state_file" ""
	assert_no_notifications
}

test_close_rejects_window_outside_container() {
	reset_logs
	write_active '{"address":"0xaaa","monitor":1,"workspace":{"id":1},"grouped":["0xaaa","0xbbb"]}'
	printf '%s\n' \
		'[{"address":"0xaaa","workspace":{"id":1},"grouped":["0xaaa","0xbbb"]},' \
		'{"address":"0xbbb","workspace":{"id":1},"grouped":["0xaaa","0xbbb"]},' \
		'{"address":"0x999","workspace":{"id":1},"grouped":[]}]' \
		>"$clients_json"
	printf 'anchor\t0xaaa\n' >"$state_file"

	if bash "$subject" close 0x999; then
		printf 'Expected close outside Container to fail.\n' >&2
		return 1
	fi

	assert_file_equals "$dispatch_log" ""
	assert_file_equals "$state_file" $'anchor\t0xaaa'
	assert_file_equals "$notify_log" "HyprGroup Window is not in the Container."
}

test_next_focuses_remembered_container_when_focus_is_outside_group() {
	reset_logs
	write_active '{"address":"0x999","title":"Loose terminal","class":"foot","monitor":1,"workspace":{"id":1},"grouped":[]}'
	printf '%s\n' \
		'[{"address":"0x111","title":"Editor","class":"code","workspace":{"id":2},"grouped":["0x111","0x222"],"focusHistoryID":8},' \
		'{"address":"0x222","title":"Tests","class":"foot","workspace":{"id":2},"grouped":["0x111","0x222"],"focusHistoryID":2},' \
		'{"address":"0x999","title":"Loose terminal","class":"foot","workspace":{"id":1},"grouped":[],"focusHistoryID":0}]' \
		>"$clients_json"
	printf 'anchor\t0x111\n' >"$state_file"

	bash "$subject" next

	assert_file_equals "$dispatch_log" $'hl.dsp.focus({ window = "address:0x222" })\nhl.dsp.group.next({})'
	assert_no_notifications
}

test_prev_focuses_remembered_container_when_focus_is_outside_group() {
	reset_logs
	write_active '{"address":"0x999","title":"Loose terminal","class":"foot","monitor":1,"workspace":{"id":1},"grouped":[]}'
	printf '%s\n' \
		'[{"address":"0x111","title":"Editor","class":"code","workspace":{"id":2},"grouped":["0x111","0x222"],"focusHistoryID":8},' \
		'{"address":"0x222","title":"Tests","class":"foot","workspace":{"id":2},"grouped":["0x111","0x222"],"focusHistoryID":2},' \
		'{"address":"0x999","title":"Loose terminal","class":"foot","workspace":{"id":1},"grouped":[],"focusHistoryID":0}]' \
		>"$clients_json"
	printf 'anchor\t0x111\n' >"$state_file"

	bash "$subject" prev

	assert_file_equals "$dispatch_log" $'hl.dsp.focus({ window = "address:0x222" })\nhl.dsp.group.prev({})'
	assert_no_notifications
}

test_snapshot_uses_remembered_container_when_focus_is_outside_group() {
	local output

	reset_logs
	write_active '{"address":"0x999","title":"Loose terminal","class":"foot","monitor":1,"workspace":{"id":1},"grouped":[]}'
	printf '%s\n' \
		'[{"address":"0x111","title":"Editor","class":"code","workspace":{"id":2},"grouped":["0x111","0x222"]},' \
		'{"address":"0x222","title":"Tests","class":"foot","workspace":{"id":2},"grouped":["0x111","0x222"]},' \
		'{"address":"0x999","title":"Loose terminal","class":"foot","workspace":{"id":1},"grouped":[]}]' \
		>"$clients_json"
	printf 'anchor\t0x111\n' >"$state_file"

	output="$(bash "$subject" snapshot)"

	if [[ "$output" != '{"hasContainer":true,"address":"0x111","title":"Editor","className":"code","grouped":["0x111","0x222"],"windows":[{"address":"0x111","title":"Editor","className":"code"},{"address":"0x222","title":"Tests","className":"foot"}],"source":"remembered"}' ]]; then
		printf 'Unexpected snapshot:\n%s\n' "$output" >&2
		return 1
	fi

	assert_file_equals "$dispatch_log" ""
	assert_no_notifications
}

test_snapshot_uses_recent_remembered_group_member_as_active_window() {
	local output

	reset_logs
	write_active '{"address":"0x999","title":"Loose terminal","class":"foot","monitor":1,"workspace":{"id":1},"grouped":[],"focusHistoryID":0}'
	printf '%s\n' \
		'[{"address":"0x111","title":"Editor","class":"code","workspace":{"id":2},"grouped":["0x111","0x222"],"focusHistoryID":8},' \
		'{"address":"0x222","title":"Tests","class":"foot","workspace":{"id":2},"grouped":["0x111","0x222"],"focusHistoryID":2},' \
		'{"address":"0x999","title":"Loose terminal","class":"foot","workspace":{"id":1},"grouped":[],"focusHistoryID":0}]' \
		>"$clients_json"
	printf 'anchor\t0x111\n' >"$state_file"

	output="$(bash "$subject" snapshot)"

	if [[ "$output" != '{"hasContainer":true,"address":"0x222","title":"Tests","className":"foot","grouped":["0x111","0x222"],"windows":[{"address":"0x111","title":"Editor","className":"code"},{"address":"0x222","title":"Tests","className":"foot"}],"source":"remembered"}' ]]; then
		printf 'Unexpected snapshot:\n%s\n' "$output" >&2
		return 1
	fi

	assert_file_equals "$dispatch_log" ""
	assert_no_notifications
}

test_remove_remembered_one_window_container
test_remove_native_group_remembers_remaining_window
test_remove_outside_container_is_noop
test_remove_selected_remembered_anchor_remembers_remaining_window
test_remove_rejects_selected_window_outside_container
test_select_group_window_restores_original_focus_when_focus_is_outside_container
test_select_group_window_keeps_focus_when_active_is_same_container
test_select_rejects_window_outside_container
test_add_remembered_one_window_container_is_noop
test_add_new_container_remembers_global_anchor
test_add_brings_global_container_to_active_workspace
test_move_container_here_moves_remembered_container_to_active_workspace
test_move_container_here_is_noop_when_container_is_already_here
test_move_container_here_rejects_without_remembered_container
test_reorder_moves_group_window_forward_to_index
test_reorder_moves_group_window_backward_to_index
test_reorder_single_window_container_is_noop
test_close_active_grouped_window_keeps_anchor
test_close_remembered_anchor_remembers_remaining_window
test_close_remembered_active_when_focus_is_outside_group
test_close_one_window_container_forgets_anchor
test_close_rejects_window_outside_container
test_next_focuses_remembered_container_when_focus_is_outside_group
test_prev_focuses_remembered_container_when_focus_is_outside_group
test_snapshot_uses_remembered_container_when_focus_is_outside_group
test_snapshot_uses_recent_remembered_group_member_as_active_window

printf 'hyprgroup CLI tests passed\n'
