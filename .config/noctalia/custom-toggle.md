# Noctalia Custom Toggle Helper

Use this with Noctalia's CustomButton widget.

Control Center CustomButton:

- `onClicked`: `/home/reklai/.local/bin/noctalia-toggle my-toggle toggle`
- `enableOnStateLogic`: `true`
- `stateChecksJson`: `[{"command":"/home/reklai/.local/bin/noctalia-toggle my-toggle check","icon":"keyboard"}]`
- `icon`: `keyboard`

Bar CustomButton:

- `leftClickExec`: `/home/reklai/.local/bin/noctalia-toggle my-toggle toggle; qs -c noctalia-shell ipc call cb refresh my-toggle`
- `leftClickUpdateText`: `false`
- `textCommand`: `/home/reklai/.local/bin/noctalia-toggle my-toggle json`
- `parseJson`: `true`
- `textIntervalMs`: `1000`
- `ipcIdentifier`: `my-toggle`

Optional command hooks:

```sh
NOCTALIA_TOGGLE_ON_CMD='notify-send Enabled' \
NOCTALIA_TOGGLE_OFF_CMD='notify-send Disabled' \
/home/reklai/.local/bin/noctalia-toggle my-toggle toggle
```
