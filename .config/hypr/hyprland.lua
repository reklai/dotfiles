-- Minimal Hyprland config for low compositor overhead.

local terminal = "ghostty"
local browser = "zen-browser"
local file_manager = "dolphin"
local menu = "wofi --show drun"
local discord = "discord-screenaudio"
local main_mod = "SUPER"
local home = assert(os.getenv("HOME"), "HOME is not set")
local screenshot_region = home .. "/.local/bin/hypr-screenshot-region"
local hyprgroup = dofile(home .. "/.config/hypr/hyprGroup/lua/hyprgroup.lua")
local gpu_session_env = "__NV_PRIME_RENDER_OFFLOAD __GLX_VENDOR_LIBRARY_NAME __VK_LAYER_NV_optimus LIBVA_DRIVER_NAME"
local systemd_session_env = "WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE "
	.. gpu_session_env
local import_systemd_session_env = "systemctl --user import-environment " .. systemd_session_env
local update_dbus_session_env = "dbus-update-activation-environment --systemd " .. systemd_session_env
local restart_xremap = "sh -lc '"
	.. import_systemd_session_env
	.. "; systemctl --user reset-failed xremap.service; systemctl --user restart xremap.service'"
local restart_noctalia = "sh -lc '"
	.. import_systemd_session_env
	.. "; systemctl --user reset-failed noctalia.service; systemctl --user restart noctalia.service'"
local refresh_screen_share_portals = "sh -lc '"
	.. import_systemd_session_env
	.. "; "
	.. update_dbus_session_env
	.. "; systemctl --user reset-failed xdg-desktop-portal-hyprland.service xdg-desktop-portal.service"
	.. "; systemctl --user restart xdg-desktop-portal-hyprland.service xdg-desktop-portal.service'"
local laptop_monitor = "eDP-1"
local external_mouse = "hp--inc-hyperx-pulsefire-haste-2"

local function external_monitor_present()
	for _, monitor in ipairs(hl.get_monitors()) do
		if monitor.name ~= laptop_monitor then
			return true
		end
	end

	return false
end

local function apply_monitor_setup()
	if external_monitor_present() then
		hl.monitor({
			output = laptop_monitor,
			disabled = true,
		})
	else
		hl.monitor({
			output = laptop_monitor,
			mode = "1920x1200@144.00",
			position = "auto",
			scale = 1.5,
		})
	end
end

hl.monitor({
	output = "",
	mode = "highrr",
	position = "auto",
	scale = 1,
})

apply_monitor_setup()

hl.on("hyprland.start", function()
	hl.exec_cmd(import_systemd_session_env)
	hl.exec_cmd(update_dbus_session_env)
	hl.exec_cmd(refresh_screen_share_portals)
	apply_monitor_setup()
	hl.exec_cmd(restart_xremap)
	hl.exec_cmd(restart_noctalia)
end)

hl.on("monitor.added", function()
	apply_monitor_setup()
end)

hl.on("monitor.removed", function()
	apply_monitor_setup()
end)

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("SHELL", "/usr/bin/bash")
hl.env("__NV_PRIME_RENDER_OFFLOAD", "1")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("__VK_LAYER_NV_optimus", "NVIDIA_only")
hl.env("LIBVA_DRIVER_NAME", "nvidia")

hl.config({
	general = {
		gaps_in = 0,
		gaps_out = 0,
		border_size = 1,
		resize_on_border = false,
		allow_tearing = false,
		layout = "master",
	},

	decoration = {
		rounding = 0,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		shadow = {
			enabled = false,
		},
		blur = {
			enabled = false,
		},
	},

	animations = {
		enabled = false,
	},
})

hl.config({
	dwindle = {
		preserve_split = true,
	},
	master = {
		new_status = "slave",
		mfact = 0.45,
	},
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
	},
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",
		follow_mouse = 1,
		sensitivity = 0,
		scroll_factor = 4.0,
		touchpad = {
			natural_scroll = true,
			scroll_factor = 4.0,
		},
	},
})

hl.device({
	name = external_mouse,
	sensitivity = -0.5,
})

hl.layer_rule({
	name = "wofi-no-shake-layer",
	match = { namespace = "^wofi$" },
	no_anim = true,
})

hl.window_rule({
	name = "wofi-no-shake-window",
	match = { class = "^[Ww]ofi$" },
	float = true,
	center = true,
	no_anim = true,
	no_blur = true,
	no_shadow = true,
	decorate = false,
})

hl.bind(main_mod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(main_mod .. " + SHIFT + V", hl.dsp.exec_cmd("code"))
hl.bind(main_mod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(main_mod .. " + I", hl.dsp.exec_cmd(file_manager))
hl.bind(main_mod .. " + SHIFT + P", hl.dsp.exec_cmd(screenshot_region))

hl.bind(main_mod .. " + C", hl.dsp.send_shortcut({ mods = "CTRL", key = "Insert" }))
hl.bind(main_mod .. " + X", hl.dsp.send_shortcut({ mods = "CTRL", key = "X" }))
hl.bind(main_mod .. " + V", hl.dsp.send_shortcut({ mods = "SHIFT", key = "Insert" }))

hl.bind(main_mod .. " + O", hl.dsp.exec_cmd("obs"))
hl.bind(main_mod .. " + SHIFT + O", hl.dsp.exec_cmd(discord))
hl.bind(main_mod .. " + P", hl.dsp.exec_cmd(menu))
hl.bind(main_mod .. " + F", hl.dsp.window.fullscreen(1))
hl.bind(main_mod .. " + M", hl.dsp.window.close())
hl.bind(main_mod .. " + SHIFT + M", hl.dsp.window.kill())
-- hl.bind(main_mod .. " + A", hl.dsp.layout("focusmaster"))
-- hl.bind(main_mod .. " + S", hl.dsp.layout("swapwithmaster"))

hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hyprgroup.setup({
	main_mod = main_mod,
	script = os.getenv("HOME") .. "/.config/hypr/hyprGroup/bin/hyprgroup",
})

local workspace_keys = { "Q", "W", "E", "R" }
for workspace, key in ipairs(workspace_keys) do
	hl.bind(main_mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
end

hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})
