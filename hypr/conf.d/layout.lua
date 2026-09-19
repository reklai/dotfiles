-- Master-stack tile layout (mango tile -> Hyprland master).
hl.config({
    general = {
        layout = "master",
    },
    master = {
        mfact = 0.5,
        new_status = "slave",
        new_on_top = false,
    },
})
