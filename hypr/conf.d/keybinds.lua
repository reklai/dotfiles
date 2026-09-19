local super = "SUPER"

-- Applications.
hl.bind(super .. " + Z", hl.dsp.exec_cmd("zen-browser"))
hl.bind(super .. " + SHIFT + Z", hl.dsp.exec_cmd("flatpak run com.google.Chrome"))
hl.bind(super .. " + G", hl.dsp.exec_cmd("ghostty"))
hl.bind(super .. " + I", hl.dsp.exec_cmd("thunar"))
hl.bind(super .. " + O", hl.dsp.exec_cmd("ghostty -e btop"))

-- Launchers and tools.
hl.bind(super .. " + P", hl.dsp.exec_cmd("fuzzel"))
hl.bind(super .. " + SHIFT + M", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/wlogout/launch.sh"))
hl.bind(super .. " + SHIFT + P", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/screenshot.sh"))
hl.bind(super .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

-- Workspaces.
hl.bind(super .. " + Q", hl.dsp.focus({ workspace = 1 }))
hl.bind(super .. " + W", hl.dsp.focus({ workspace = 2 }))
hl.bind(super .. " + E", hl.dsp.focus({ workspace = 3 }))
hl.bind(super .. " + R", hl.dsp.focus({ workspace = 4 }))
-- mango's `tag` moves the window without following it -> silent variant.
hl.bind(super .. " + 1", hl.dsp.window.move({ workspace = 1, follow = false }))
hl.bind(super .. " + 2", hl.dsp.window.move({ workspace = 2, follow = false }))
hl.bind(super .. " + 3", hl.dsp.window.move({ workspace = 3, follow = false }))
hl.bind(super .. " + 4", hl.dsp.window.move({ workspace = 4, follow = false }))

-- Focus movement.
hl.bind(super .. " + D", hl.dsp.layout("rollnext"))
hl.bind(super .. " + A", hl.dsp.layout("rollprev"))
hl.bind(super .. " + S", hl.dsp.layout("cyclenext"))
hl.bind(super .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(super .. " + J", hl.dsp.focus({ direction = "d" }))
hl.bind(super .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(super .. " + L", hl.dsp.focus({ direction = "r" }))

-- Master-stack layout.
hl.bind(super .. " + minus", hl.dsp.exec_cmd("wtype -M ctrl -k minus -m ctrl"))
hl.bind(super .. " + equal", hl.dsp.exec_cmd("wtype -M ctrl -k equal -m ctrl"))
hl.bind(super .. " + SHIFT + minus", hl.dsp.layout("mfact -0.05"))
hl.bind(super .. " + SHIFT + equal", hl.dsp.layout("mfact +0.05"))

-- Window actions.
hl.bind(super .. " + M", hl.dsp.window.close())
hl.bind(super .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
