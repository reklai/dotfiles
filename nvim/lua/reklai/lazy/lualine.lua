-- Stock lualine layout; greyscale only (does not follow the colorscheme).
local ink = {
	bg = "#1a1a1a",
	bg2 = "#2a2a2a",
	bg3 = "#3a3a3a",
	fg = "#c4c4c4",
	dim = "#888888",
	bright = "#e8e8e8",
	ink = "#111111",
}

local mono = {
	normal = {
		a = { fg = ink.ink, bg = "#b8b8b8", gui = "bold" },
		b = { fg = ink.fg, bg = ink.bg2 },
		c = { fg = ink.dim, bg = ink.bg },
	},
	insert = {
		a = { fg = ink.ink, bg = ink.bright, gui = "bold" },
		b = { fg = ink.bright, bg = ink.bg2 },
		c = { fg = ink.dim, bg = ink.bg },
	},
	visual = {
		a = { fg = ink.bright, bg = ink.bg3, gui = "bold" },
		b = { fg = ink.fg, bg = ink.bg2 },
		c = { fg = ink.dim, bg = ink.bg },
	},
	replace = {
		a = { fg = ink.bright, bg = "#4a4a4a", gui = "bold" },
		b = { fg = ink.fg, bg = ink.bg2 },
		c = { fg = ink.dim, bg = ink.bg },
	},
	command = {
		a = { fg = ink.ink, bg = "#9a9a9a", gui = "bold" },
		b = { fg = ink.fg, bg = ink.bg2 },
		c = { fg = ink.dim, bg = ink.bg },
	},
	inactive = {
		a = { fg = ink.dim, bg = ink.bg },
		b = { fg = ink.dim, bg = ink.bg },
		c = { fg = ink.dim, bg = ink.bg },
	},
}

return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	event = "VeryLazy",
	opts = {
		options = {
			icons_enabled = true,
			theme = mono,
			component_separators = { left = "", right = "" },
			section_separators = { left = "", right = "" },
		},
		sections = {
			lualine_a = { "mode" },
			lualine_b = { "filename" },
			lualine_c = {},
			lualine_x = { "encoding", "fileformat", "filetype" },
			lualine_y = { "progress" },
			lualine_z = { "location" },
		},
	},
}
