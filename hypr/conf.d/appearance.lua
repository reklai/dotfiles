-- Gaps, borders, rounding (ported from mango appearance.conf).
hl.config({
    general = {
        gaps_in = 8,
        gaps_out = 10,
        border_size = 1,
        col = {
            active_border = "rgba(7b8494ff)",
            inactive_border = "rgba(2b3038ff)",
        },
    },
    decoration = {
        rounding = 12,
        blur = {
            enabled = false,
        },
        shadow = {
            enabled = false,
        },
    },
    -- Animations disabled for the performance profile.
    animations = {
        enabled = false,
    },
    misc = {
        background_color = "rgba(191d24ff)",
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})

-- mango no_border_when_single=1: single tiled window gets no border.
hl.workspace_rule({ workspace = "w[tv1]", border_size = 0 })
