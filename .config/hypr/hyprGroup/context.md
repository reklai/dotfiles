# HyprGroup Context

## Purpose

HyprGroup is a small wrapper around Hyprland native groups, positioned as native Hyprland groups controlled like tabs. It uses Hyprland Lua for bindings and group behavior, a Bash command script for dispatch actions, and Quickshell for the popup menu.

The public mental model is that one normal tiled window slot can hold related windows navigated like tabs. The implementation and domain language still use Container, Window, Active Container, Container Menu, and Container List.

## Current Bindings

- `SUPER + G`: toggle the HyprGroup menu.
- `SUPER + mouse_down`: previous window in the active group.
- `SUPER + mouse_up`: next window in the active group.
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

- `Add to Container`: add the active window to the Container only when it is not already in one.
- `Remove from Container`: remove the selected Container Window from its Container, or forget a selected one-window Container.
- `Close Window Inside Container`: close the selected Container Window with a normal close request. This destroys the Window; reopening happens through the app/launcher, and the reopened Window starts outside the Container until added again.
- `Prev` and `Next`: header arrow controls for cycling focus through windows in the active group, or through the remembered visible Container when focus is outside a group.
- Action availability follows current context: Add is disabled when the active Window is already in a Container; Remove and Close are disabled until a Container Window is selected.

## Window List

- The Window List is rendered as a vertical, scrollable tab list in the right pane, under the active window block.
- Each row represents an actual Hyprland grouped window from the active window's native group.
- The remembered Container anchor is command state only; it must not create a list row by itself.
- Group windows are shown as a Ghostty-inspired vertical, scrollable tab list under the active window details: dark gray chrome, soft active row, clear row bounds, readable titles, and a thin neutral active edge. Tab labels prefer Window title, then app class, then `Window N`; raw addresses are not shown as tab labels.
- Dragging a tab inside the Container Menu reorders the grouped Window through `bin/hyprgroup reorder ADDRESS INDEX`; it does not change the native Hyprland groupbar itself.
- Single-clicking a row selects it as the menu target without changing Hyprland focus.
- Double-clicking a row focuses that grouped Window and keeps the menu open.
- The selected grouped Window is highlighted with neutral contrast; destructive actions target this highlighted row.

## Right Pane

- The current window block represents the active grouped window when focus is inside a group.
- When focus is outside a group, the current window block falls back to the most recently focused Window inside the remembered Container if that Container still exists.
- The Window List runs downward from the active window block and scrolls when there are more rows than fit.
- Container state feedback only describes whether the current active Hyprland Window is in a Container; it does not label remembered fallback state as active.
- If no active or remembered Container exists, the active window block says `No Active Window`.

## Command Notes

- `bin/hyprgroup menu`: toggles the Quickshell menu and passes `hyprctl cursorpos` into the IPC call.
- `bin/hyprgroup daemon`: starts the persistent Quickshell process if it is not already running.
- `bin/hyprgroup add`: checks the active window first. If the window is already in the Container, it does nothing. Otherwise it unsets fullscreen/floating state, brings the remembered Container anchor to the active workspace when needed, moves the active window into the Container when possible, and only creates a new Container when none exists. A runtime state file stores the single Container anchor address so the Container follows the real window/group identity instead of being tied to a workspace. After creating or moving into a group, it locks the active group so future windows tile beside the Container instead of auto-entering it. HyprGroup sets `binds.ignore_group_lock = true` so scripted Add can still enter the locked Container intentionally.
- `bin/hyprgroup reorder ADDRESS INDEX`: moves the grouped Window at `ADDRESS` forward or backward until it reaches the zero-based Container `INDEX`.
- `bin/hyprgroup close [ADDRESS]`: focuses the selected Container window when needed, repairs the remembered anchor before closing if the selected Window is the anchor, then dispatches `hl.dsp.window.close({})`. If no address is provided, it closes the active grouped Window or the most recently focused Window in the remembered Container.
- `bin/hyprgroup snapshot`: prints JSON for the focused Container when focus is grouped, otherwise for the remembered Container when it still exists. Remembered snapshots mark the most recently focused grouped Window active, and include per-Window title and class metadata for practical tab labels.
- `bin/hyprgroup remove [ADDRESS]`: if the target Window is in a native Hyprland group, focuses it when needed, dispatches `hl.dsp.window.move({ out_of_group = true })`, and remembers another grouped Window as the Container anchor when the removed Window was the anchor. If the target Window is only the remembered one-window Container, it clears that runtime state instead of dispatching a no-op. If no address is provided and the active Window is outside the Container, it does nothing.
- `bin/hyprgroup jump ADDRESS`: dispatches `hl.dsp.focus({ window = "address:ADDRESS" })`.
- `bin/hyprgroup next` and `bin/hyprgroup prev`: cycle focus through windows in the active group. If focus is outside a group, they first focus the most recently focused Window in the remembered Container so the arrows act on the Container shown in the menu.

## Implementation Notes

- `qs/shell.qml` owns the Quickshell UI, Container snapshot consumption, cursor-relative positioning, and IPC methods.
- `qs/ActionButton.qml` owns the reusable menu action button.
- `lua/hyprgroup.lua` owns Hyprland group config and keybindings.
- `bin/hyprgroup` owns CLI actions, daemon startup, cursor capture, and Hyprland dispatch calls.
- Hyprland group semantics are native Hyprland behavior; this project provides a simpler menu and shortcuts around them.
- Native Hyprland group tabs and group borders use neutral grays. `group.groupbar.gradients` must stay enabled because Hyprland 0.55.2 ignores `groupbar.col.*` for the visible tab fill when gradients are disabled. The groupbar indicator line is disabled so it does not draw a separate colored accent.
