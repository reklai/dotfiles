# HyprGroup

Native Hyprland groups, controlled like tabs.

HyprGroup makes one normal tiled window slot behave like a tabbed Container for related windows. Hyprland remains the real container layer; this project adds focused keybinds, a fast Quickshell Container Menu, and a Ghostty-inspired tab rail for the Active Container.

Use it when a task needs several windows, but not several workspace slots. For example, keep an editor, test terminal, and docs window inside one Container, then cycle between them while the rest of the desktop stays fully tiled.

## What It Looks Like

```text
+-------------------------------+-------------------------------+
| Terminal                      | Browser                       |
|                               |                               |
+-------------------------------+-------------------------------+
| [ editor ] [ tests ] [ docs ]                                 |
|                                                               |
|              Active window inside the Container               |
|                                                               |
+---------------------------------------------------------------+
```

The Container still occupies one regular Hyprland tile. Inside that tile, Hyprland's native grouped windows are navigated like tabs.

`SUPER + G` opens the cursor-near Container Menu for controlling the Active Container:

```text
+------------------------------------------------+
| HyprGroup                         <   2 / 3   > |
+-------------+----------------------------------+
| Add         | [ editor ] [ tests ] [ docs ]    |
| Remove      +----------------------------------+
|             | Active Window                    |
|             | tests                            |
+-------------+----------------------------------+
```

The menu only describes the Active Container. If focus is outside any group, HyprGroup falls back to the remembered Container, even when that Container is on another workspace. It is not a launcher, workspace switcher, or list of every open window.

## Bindings

Defaults live in `lua/hyprgroup/config.lua`, so key changes stay inside this folder:

- `SUPER + mouse_down`: previous window in the active group
- `SUPER + mouse_up`: next window in the active group
- `SUPER + backslash`: next window in the active group
- `SUPER + SHIFT + backslash`: previous window in the active group
- `SUPER + G`: toggle the HyprGroup menu instantly through a persistent Quickshell daemon

Add this once in `hyprland.lua`:

```lua
dofile(os.getenv("HOME") .. "/.config/hypr/hyprGroup/lua/hyprgroup.lua").setup()
```

The split menu opens near the cursor, stays clamped inside the monitor, uses black and gray surfaces with neutral active accents, and closes with `Esc`, the top-right `X`, or a click outside the panel.

## Project Layout

```text
bin/hyprgroup                  CLI actions and Quickshell daemon launcher
lua/hyprgroup.lua              Stable Hyprland entry shim
lua/hyprgroup/init.lua         Setup orchestration
lua/hyprgroup/config.lua       User-facing keybinds and paths
lua/hyprgroup/binds.lua        Hyprland bind registration
lua/hyprgroup/group.lua        Native group and groupbar config
qs/shell.qml                   Quickshell overlay
qs/components/ActionButton.qml Reusable QML action control
tests/                         CLI regression tests
```

## Menu Actions

- Add to Container, moving the focused window into the single remembered Container when possible
- Add first normalizes fullscreen/floating windows back into the tiled layout
- The Container is tracked by anchor window address, not by workspace
- Containers are locked after Add so new windows tile beside them instead of auto-entering them
- Add can still intentionally enter the locked Container
- Move Container Here, moving the remembered Container to the current active workspace without adding the active window
- Remove from Container, either moving the selected grouped window out or forgetting a one-window Container
- Close Window Inside Container, closing the selected Container window with a normal close request
- Previous and next arrows that cycle focus inside the visible Container without reordering the list
- Active window details for the selected grouped window, while Container state feedback only reflects the current active Hyprland window
- Ghostty-inspired vertical, scrollable tab list under the active-window preview with practical labels: Window title, app class, then `Window N`
- Single click selects a row and updates the Container's active member without staying focused there when you are outside it
- Double click focuses that grouped window and keeps you there; drag reorders rows
- Remove and Close target the selected highlighted row
- If no active or remembered Container exists, the active block says `No Active Window`

## CLI

```sh
bin/hyprgroup --help
bin/hyprgroup daemon
bin/hyprgroup menu
bin/hyprgroup add
bin/hyprgroup move-here
bin/hyprgroup close
bin/hyprgroup remove 0x123456
bin/hyprgroup reorder 0x123456 1
bin/hyprgroup snapshot
bin/hyprgroup prev
bin/hyprgroup next
bin/hyprgroup jump 0x123456
bin/hyprgroup remove
```
