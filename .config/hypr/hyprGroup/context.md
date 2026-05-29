# HyprGroup Context

## Purpose

HyprGroup is a small wrapper around Hyprland native groups, positioned as native Hyprland groups controlled like tabs. It uses Hyprland Lua for bindings and group behavior, a Bash command script for dispatch actions, and Quickshell for the popup menu.

The public mental model is that one normal tiled window slot can hold related windows navigated like tabs. The implementation and domain language still use Container, Window, Active Container, Container Menu, and Container List.

## Current Bindings

- `SUPER + G`: toggle the HyprGroup menu.
- `SUPER + mouse_down`: next window in the active group.
- `SUPER + mouse_up`: previous window in the active group.
- `SUPER + backslash`: next window in the active group.
- `SUPER + SHIFT + backslash`: previous window in the active group.
- `SUPER + T`: terminal.
- `SUPER + B`: browser.

## Menu Behavior

- The menu is a resident Quickshell daemon and is toggled through IPC for fast open and close.
- The menu opens near the current cursor position and centers the cursor on the menu top edge when there is room.
- The menu is centered on the active monitor when no cursor position is available.
- The menu uses black and gray surfaces, white text, and neutral active accents.
- The overlay is transparent and input-masked while hidden, so it should not behave like another workspace.
- Close paths are `Esc`, the top-right `X`, or clicking outside the menu.

## Menu Actions

- `Add`: add the active window to the Container only when it is not already in one.
- `Remove`: remove the active window from its Container, or forget a one-window Container.
- `Prev` and `Next`: header arrow controls for moving through windows in the active group.

## Window List

- The Window List is rendered under the active window block in the right pane.
- Each row represents an actual Hyprland grouped window from the active window's native group.
- The remembered Container anchor is command state only; it must not create a list row by itself.
- Group windows are shown as a Ghostty-inspired horizontal tab rail inside the same Container panel as the active window details: dark gray chrome, soft active tab, clear separators, centered titles, and a thin neutral active edge. Tab labels prefer Window title, then app class, then `Window N`; raw addresses are not shown as tab labels.
- Dragging a tab inside the Container Menu reorders the grouped Window through `bin/hyprgroup reorder ADDRESS INDEX`; it does not change the native Hyprland groupbar itself.
- Clicking a row focuses that grouped window and keeps the menu open.
- The active grouped window is highlighted with neutral contrast.

## Right Pane

- The current window block only represents the active window when it is inside a group.
- When focus is outside a group, the current window block falls back to the remembered Container anchor if that Window still exists.
- The Window List sits directly under the active window block.
- If no active or remembered Container exists, the active window block says `No Active Window`.

## Command Notes

- `bin/hyprgroup menu`: toggles the Quickshell menu and passes `hyprctl cursorpos` into the IPC call.
- `bin/hyprgroup daemon`: starts the persistent Quickshell process if it is not already running.
- `bin/hyprgroup add`: checks the active window first. If the window is already in the Container, it does nothing. Otherwise it unsets fullscreen/floating state, brings the remembered Container anchor to the active workspace when needed, moves the active window into the Container when possible, and only creates a new Container when none exists. A runtime state file stores the single Container anchor address so the Container follows the real window/group identity instead of being tied to a workspace. After creating or moving into a group, it locks the active group so future windows tile beside the Container instead of auto-entering it. HyprGroup sets `binds.ignore_group_lock = true` so scripted Add can still enter the locked Container intentionally.
- `bin/hyprgroup reorder ADDRESS INDEX`: moves the grouped Window at `ADDRESS` forward or backward until it reaches the zero-based Container `INDEX`.
- `bin/hyprgroup snapshot`: prints JSON for the focused Container when focus is grouped, otherwise for the remembered Container anchor when it still exists. It includes per-Window title and class metadata for practical tab labels.
- `bin/hyprgroup remove`: if the active window is in a native Hyprland group, dispatches `hl.dsp.window.move({ out_of_group = true })` and remembers another grouped window as the Container anchor. If the active window is only the remembered one-window Container, it clears that runtime state instead of dispatching a no-op. If the active window is outside the Container, it does nothing.
- `bin/hyprgroup jump ADDRESS`: dispatches `hl.dsp.focus({ window = "address:ADDRESS" })`.
- `bin/hyprgroup next` and `bin/hyprgroup prev`: move through windows in the active group.

## Implementation Notes

- `qs/shell.qml` owns the Quickshell UI, Container snapshot consumption, cursor-relative positioning, and IPC methods.
- `qs/ActionButton.qml` owns the reusable menu action button.
- `lua/hyprgroup.lua` owns Hyprland group config and keybindings.
- `bin/hyprgroup` owns CLI actions, daemon startup, cursor capture, and Hyprland dispatch calls.
- Hyprland group semantics are native Hyprland behavior; this project provides a simpler menu and shortcuts around them.
- Native Hyprland group tabs and group borders use neutral grays. `group.groupbar.gradients` must stay enabled because Hyprland 0.55.2 ignores `groupbar.col.*` for the visible tab fill when gradients are disabled. The groupbar indicator line is disabled so it does not draw a separate colored accent.
