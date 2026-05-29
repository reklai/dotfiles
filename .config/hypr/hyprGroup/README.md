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
| Swap        +----------------------------------+
| Remove      | Active Window                    |
|             | tests                            |
+-------------+----------------------------------+
```

The menu only describes the Active Container. If focus is outside any group, HyprGroup falls back to the remembered Container anchor, even when that Container is on another workspace. It is not a launcher, workspace switcher, or list of every open window.

## Bindings

- `SUPER + mouse_down`: next window in the active group
- `SUPER + mouse_up`: previous window in the active group
- `SUPER + backslash`: next window in the active group
- `SUPER + SHIFT + backslash`: previous window in the active group
- `SUPER + G`: toggle the HyprGroup menu instantly through a persistent Quickshell daemon

The split menu opens near the cursor, stays clamped inside the monitor, uses black and gray surfaces with neutral active accents, and closes with `Esc`, the top-right `X`, or a click outside the panel.

## Menu Actions

- Add, moving the focused window into the single remembered Container when possible
- Add first normalizes fullscreen/floating windows back into the tiled layout
- The Container is tracked by anchor window address, not by workspace
- Containers are locked after Add so new windows tile beside them instead of auto-entering them
- Add can still intentionally enter the locked Container
- Swap
- Remove, either moving the focused grouped window out or forgetting a one-window Container
- Previous and next arrows
- Active window details for the focused grouped window, or the remembered Container anchor when focus is outside any group
- Ghostty-inspired tab rail inside the Container panel with only actual Hyprland grouped windows
- Drag tabs in the Container Menu to reorder grouped windows
- If no active or remembered Container exists, the active block says `No Active Window`

## CLI

```sh
bin/hyprgroup --help
bin/hyprgroup daemon
bin/hyprgroup menu
bin/hyprgroup add
bin/hyprgroup swap
bin/hyprgroup reorder 0x123456 1
bin/hyprgroup snapshot
bin/hyprgroup prev
bin/hyprgroup next
bin/hyprgroup jump 0x123456
bin/hyprgroup remove
```
