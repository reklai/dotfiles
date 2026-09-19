-- Window-rule grammar (Hyprland 0.56+ lua): effects are fields, matchers
-- live in `match`.

-- Steam has mixed normal and floating windows.
hl.window_rule({
    match = { class = "[Ss]team" },
    float = true,
})
hl.window_rule({
    match = { class = "[Ss]team", title = "^Steam$" },
    tile = true,
})
hl.window_rule({
    match = { class = "steam", title = "Steam Settings" },
    float = true,
})

-- Keep the audio mixer as a centered terminal-sized utility panel.
hl.window_rule({
    match = { class = ".*[Pp]avucontrol" },
    float = true,
    size = { 760, 520 },
    center = true,
})

-- Selection overlays should not animate.
hl.layer_rule({
    match = { namespace = "selection" },
    no_anim = true,
})
