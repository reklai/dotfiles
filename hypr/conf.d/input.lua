-- Keyboard and pointer behavior (ported from mango input.conf).
hl.config({
    input = {
        kb_layout = "us",
        natural_scroll = false,
        touchpad = {
            tap_to_click = true,
            tap_and_drag = true,
            drag_lock = true,
            disable_while_typing = true,
            natural_scroll = false,
        },
    },
    -- mango warpcursor=1: closest Hyprland equivalent; full focus-warp
    -- parity is a rollout spot-check.
    cursor = {
        warp_on_change_workspace = true,
    },
})
