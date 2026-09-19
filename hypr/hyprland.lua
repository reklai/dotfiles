-- Primary Hyprland config (0.55+). The sibling hyprland.conf is hyprlang
-- fallback for an already-running session and is ignored at startup.
-- Load order matters: later files can override earlier settings.
-- Paths must be ./relative: Lua require() treats dots as module separators,
-- so the conf.d directory cannot be loaded as "conf.d.env".
require("./conf.d/env.lua")
require("./conf.d/input.lua")
require("./conf.d/layout.lua")
require("./conf.d/appearance.lua")
require("./conf.d/monitors.lua")
require("./conf.d/autostart.lua")
require("./conf.d/keybinds.lua")
require("./conf.d/mouse.lua")
require("./conf.d/rules.lua")
