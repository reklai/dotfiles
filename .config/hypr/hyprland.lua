-- Minimal Hyprland config for low compositor overhead.

local terminal = "ghostty"
local browser = "zen-browser"
local file_manager = "dolphin"
local menu = "wofi --show drun"
local discord = "discord"
local clipboard_manager = "qs -c noctalia-shell ipc call launcher clipboard"
local main_mod = "SUPER"
local home = assert(os.getenv("HOME"), "HOME is not set")
local screenshot_region = home .. "/.config/hypr/bin/hypr-screenshot-region"
local hyprCompanion = "enable"
local hyprcompanion_path = home .. "/code/personal/hypr/hyprCompanion/lua/hyprcompanion.lua"

local function command_succeeds(command)
	local ok = os.execute(command .. " >/dev/null 2>&1")
	return ok == true or ok == 0
end

local function path_exists(path)
	local file = io.open(path, "r")
	if file then
		file:close()
		return true
	end

	return command_succeeds("test -e " .. path)
end

local function read_first_line(path)
	local file = io.open(path, "r")
	if not file then
		return nil
	end

	local line = file:read("*l")
	file:close()

	if type(line) == "string" then
		return line:match("^%s*(.-)%s*$")
	end

	return nil
end

local function command_lines(command)
	local handle = io.popen(command)
	local lines = {}

	if not handle then
		return lines
	end

	for line in handle:lines() do
		if line ~= "" then
			table.insert(lines, line)
		end
	end

	handle:close()
	return lines
end

local function resolve_drm_card(path)
	local handle = io.popen("readlink -f " .. path .. " 2>/dev/null")
	if not handle then
		return nil
	end

	local resolved = handle:read("*l")
	handle:close()

	if type(resolved) == "string" and resolved:match("^/dev/dri/card%d+$") then
		return resolved
	end

	return nil
end

local function drm_card_number(path)
	return tonumber(path:match("card(%d+)$")) or math.huge
end

local function drm_vendor_id(card_path)
	local card_name = card_path:match("([^/]+)$")
	if not card_name then
		return nil
	end

	return read_first_line("/sys/class/drm/" .. card_name .. "/device/vendor")
end

local function is_preferred_gpu_vendor(vendor_id)
	return vendor_id == "0x8086" or vendor_id == "0x1002"
end

local function is_nvidia_gpu_vendor(vendor_id)
	return vendor_id == "0x10de"
end

local function vaapi_driver_for_vendor(vendor_id)
	if vendor_id == "0x8086" then
		return "iHD"
	elseif vendor_id == "0x1002" then
		return "radeonsi"
	end

	return nil
end

local function append_all(target, source)
	for _, value in ipairs(source) do
		table.insert(target, value)
	end
end

local function list_drm_cards()
	local cards = {}
	local seen = {}

	for _, path in ipairs(command_lines("ls -1 /dev/dri/card[0-9]* 2>/dev/null")) do
		local card_path = resolve_drm_card(path)
		if card_path and not seen[card_path] then
			seen[card_path] = true
			table.insert(cards, {
				path = card_path,
				vendor_id = drm_vendor_id(card_path),
			})
		end
	end

	table.sort(cards, function(left, right)
		return drm_card_number(left.path) < drm_card_number(right.path)
	end)

	return cards
end

local function build_drm_device_order()
	local preferred = {}
	local nvidia = {}
	local other = {}

	for _, card in ipairs(list_drm_cards()) do
		if is_preferred_gpu_vendor(card.vendor_id) then
			table.insert(preferred, card)
		elseif is_nvidia_gpu_vendor(card.vendor_id) then
			table.insert(nvidia, card)
		else
			table.insert(other, card)
		end
	end

	local ordered = {}
	if #preferred > 0 then
		append_all(ordered, preferred)
		append_all(ordered, nvidia)
		append_all(ordered, other)
	else
		append_all(ordered, nvidia)
		append_all(ordered, other)
	end

	return ordered, #preferred > 0, #nvidia > 0
end

local ordered_drm_cards, has_preferred_gpu, has_nvidia_gpu = build_drm_device_order()
local drm_device_paths = {}

for _, card in ipairs(ordered_drm_cards) do
	table.insert(drm_device_paths, card.path)
end

local default_gpu_vendor_id = ordered_drm_cards[1] and ordered_drm_cards[1].vendor_id or nil
local hyprland_drm_devices = #drm_device_paths > 0 and table.concat(drm_device_paths, ":") or nil
local vaapi_driver_name = vaapi_driver_for_vendor(default_gpu_vendor_id)
local nvidia_optimus_mode = has_preferred_gpu and has_nvidia_gpu and "non_NVIDIA_only" or nil

local function setup_hyprcompanion()
	if hyprCompanion ~= "enable" or not path_exists(hyprcompanion_path) then
		return
	end

	dofile(hyprcompanion_path).setup({
		main_mod = main_mod,
	})
end

local systemd_session_env_names = {
	"WAYLAND_DISPLAY",
	"HYPRLAND_INSTANCE_SIGNATURE",
	"XDG_CURRENT_DESKTOP",
	"XDG_SESSION_TYPE",
}

if hyprland_drm_devices then
	table.insert(systemd_session_env_names, "AQ_DRM_DEVICES")
end

if vaapi_driver_name then
	table.insert(systemd_session_env_names, "LIBVA_DRIVER_NAME")
end

if nvidia_optimus_mode then
	table.insert(systemd_session_env_names, "__VK_LAYER_NV_optimus")
end

local systemd_session_env = table.concat(systemd_session_env_names, " ")
local import_systemd_session_env = "systemctl --user import-environment " .. systemd_session_env
local update_dbus_session_env = "dbus-update-activation-environment --systemd " .. systemd_session_env
local stale_nvidia_session_env_names = {
	"GBM_BACKEND",
	"__NV_PRIME_RENDER_OFFLOAD",
	"__GLX_VENDOR_LIBRARY_NAME",
}

if not vaapi_driver_name then
	table.insert(stale_nvidia_session_env_names, "LIBVA_DRIVER_NAME")
end

if not nvidia_optimus_mode then
	table.insert(stale_nvidia_session_env_names, "__VK_LAYER_NV_optimus")
end

if not hyprland_drm_devices then
	table.insert(stale_nvidia_session_env_names, "AQ_DRM_DEVICES")
end

local stale_nvidia_session_env = table.concat(stale_nvidia_session_env_names, " ")
local unset_stale_nvidia_session_env = "systemctl --user unset-environment " .. stale_nvidia_session_env
local restart_xremap = "sh -lc '"
	.. unset_stale_nvidia_session_env
	.. "; "
	.. import_systemd_session_env
	.. "; systemctl --user reset-failed xremap.service; systemctl --user restart xremap.service'"
local restart_noctalia = "sh -lc '"
	.. unset_stale_nvidia_session_env
	.. "; "
	.. import_systemd_session_env
	.. "; systemctl --user reset-failed noctalia.service; systemctl --user restart noctalia.service'"
local refresh_screen_share_portals = "sh -lc '"
	.. unset_stale_nvidia_session_env
	.. "; "
	.. import_systemd_session_env
	.. "; "
	.. update_dbus_session_env
	.. "; systemctl --user reset-failed xdg-desktop-portal-hyprland.service xdg-desktop-portal.service"
	.. "; systemctl --user restart xdg-desktop-portal-hyprland.service xdg-desktop-portal.service'"
local internal_monitor

local function get_monitors()
	local ok, monitors = pcall(hl.get_monitors)
	if not ok or type(monitors) ~= "table" then
		return {}
	end

	return monitors
end

local function is_internal_monitor(name)
	return name:match("^eDP") or name:match("^LVDS") or name:match("^DSI")
end

local function find_internal_monitor()
	for _, monitor in ipairs(get_monitors()) do
		if type(monitor.name) == "string" and is_internal_monitor(monitor.name) then
			internal_monitor = monitor.name
			return internal_monitor
		end
	end

	return internal_monitor
end

local function external_monitor_present(internal_name)
	for _, monitor in ipairs(get_monitors()) do
		if type(monitor.name) == "string" and monitor.name ~= internal_name then
			return true
		end
	end

	return false
end

local function apply_monitor_setup()
	local internal_name = find_internal_monitor()
	if not internal_name then
		return
	end

	if external_monitor_present(internal_name) then
		hl.monitor({
			output = internal_name,
			disabled = true,
		})
	else
		hl.monitor({
			output = internal_name,
			mode = "highrr",
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
	hl.exec_cmd(unset_stale_nvidia_session_env)
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

if hyprland_drm_devices then
	hl.env("AQ_DRM_DEVICES", hyprland_drm_devices)
end

if vaapi_driver_name then
	hl.env("LIBVA_DRIVER_NAME", vaapi_driver_name)
end

if nvidia_optimus_mode then
	hl.env("__VK_LAYER_NV_optimus", nvidia_optimus_mode)
end

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
		sensitivity = -0.5,
		scroll_factor = 4.0,
		touchpad = {
			natural_scroll = true,
			scroll_factor = 4.0,
		},
	},
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
hl.bind(main_mod .. " + SHIFT + V", hl.dsp.exec_cmd(clipboard_manager))
hl.bind(main_mod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(main_mod .. " + I", hl.dsp.exec_cmd(file_manager))
hl.bind(main_mod .. " + SHIFT + P", hl.dsp.exec_cmd(screenshot_region))

hl.bind(main_mod .. " + C", hl.dsp.send_shortcut({ mods = "CTRL", key = "Insert" }))
hl.bind(main_mod .. " + X", hl.dsp.send_shortcut({ mods = "CTRL", key = "X" }))
hl.bind(main_mod .. " + V", hl.dsp.send_shortcut({ mods = "SHIFT", key = "Insert" }))

hl.bind(main_mod .. " + O", hl.dsp.exec_cmd(discord))
hl.bind(main_mod .. " + SHIFT + O", hl.dsp.exec_cmd("obs"))
hl.bind(main_mod .. " + P", hl.dsp.exec_cmd(menu))
hl.bind(main_mod .. " + F", hl.dsp.window.fullscreen(1))
hl.bind(main_mod .. " + M", hl.dsp.window.close())
hl.bind(main_mod .. " + SHIFT + M", hl.dsp.window.kill())
-- hl.bind(main_mod .. " + A", hl.dsp.layout("focusmaster"))
-- hl.bind(main_mod .. " + S", hl.dsp.layout("swapwithmaster"))

hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

setup_hyprcompanion()

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
