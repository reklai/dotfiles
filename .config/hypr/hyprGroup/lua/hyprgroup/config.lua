local home = assert(os.getenv("HOME"), "HOME is not set")

return {
	main_mod = "SUPER",
	script = home .. "/.config/hypr/hyprGroup/bin/hyprgroup",

	-- Values are appended after main_mod, e.g. "SHIFT + backslash" becomes "SUPER + SHIFT + backslash".
	binds = {
		menu = "G",
		next = "backslash",
		prev = "SHIFT + backslash",
		mouse_next = "mouse_up",
		mouse_prev = "mouse_down",
	},
}
