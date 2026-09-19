-- Hand the session env to systemd and start the session units. Only
-- compositor-coupled startup lives here; daemons are systemd user units.
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE && systemctl --user start hyprland-session.target")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/waybar/scripts/wallpaper.sh restore")
end)
