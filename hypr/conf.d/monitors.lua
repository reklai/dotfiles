-- Best-mode policy: highest refresh rate, Hyprland's own tie-breaking and
-- failed-modeset fallback. Values from the retired displays.conf: pos 0x0,
-- no transform. Scale 1.5 (1920x1200 -> 1280x800 logical). In a pinned
-- session only one GPU's connectors are visible, so no eDP-disable rule
-- is needed.
hl.monitor({
    output = "",
    mode = "highrr",
    position = "0x0",
    scale = 1.5,
})
