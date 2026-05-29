# HyprGroup

HyprGroup is a personal window-management context for controlling a small set of grouped windows from keyboard shortcuts and a cursor-near menu. Public positioning may describe it as native Hyprland groups controlled like tabs, but the product language stays centered on Containers.

## Language

**Container**:
A user-facing set of windows that should be navigated, reordered, and changed together. In Hyprland terms, a Container maps to a native group and is tracked by an anchor Window address, not by workspace.
_Avoid_: stack, workspace, tab set

**Tabs**:
Public shorthand for explaining that grouped Windows inside one tiled Container can be navigated like tabs. Do not use Tabs as the domain object name; use Container for the actual grouped-window object.
_Avoid_: browser tabs, tab set, workspace tabs

**Window**:
An individual application surface that can be added to or removed from a Container.
_Avoid_: app, client, pane

**Active Container**:
The Container that contains the currently focused Window, or the remembered Container anchor when focus is outside any Container. HyprGroup keeps one remembered Container anchor so the Container can be shown in the menu and brought to the active workspace when adding a Window.
_Avoid_: current group, selected group

**Container Menu**:
The small action surface for changing the Active Container and jumping between its Windows.
_Avoid_: launcher, dashboard, control panel

**Container List**:
The ordered list of Windows inside the Active Container.
_Avoid_: window list, group list, switcher

Container List rows may be displayed as tabs in public UI copy. Dragging these tabs in the Container Menu reorders Windows inside the native Hyprland group; this is a menu interaction, not a replacement for Hyprland's native groupbar.

## Example Dialogue

Dev: "When I press `SUPER + G`, should the Container Menu show every open Window?"

Domain expert: "No. It should show the Active Container only. If the focused Window is not inside a Container, show the remembered Container when its anchor still exists; otherwise say that there is no Active Container."

Dev: "When I click a row in the Container List, am I switching workspace?"

Domain expert: "No. You are jumping focus to that Window inside the same Container."
