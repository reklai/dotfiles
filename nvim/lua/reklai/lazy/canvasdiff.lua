-- CanvasDiff from the local checkout, not GitHub: edits under
-- ~/coding/personal/lua/canvasdiff.nvim are live after a restart.
--
-- Loaded lazily on the command or the keys below, which therefore have to own
-- every global entry point (see README "Lazy-loading correctly").
return {
	dir = vim.fn.expand("~/coding/personal/lua/canvasdiff.nvim"),
	name = "canvasdiff.nvim",
	cmd = "CanvasDiff",
	keys = {
		{
			"<leader>gd",
			function()
				require("canvasdiff").toggle()
			end,
			desc = "Git diff canvas",
		},
		{
			"<leader>gb",
			function()
				require("canvasdiff").compare()
			end,
			desc = "Git compare branches",
		},
		{
			"<leader>gc",
			function()
				require("canvasdiff").checkout()
			end,
			desc = "Git checkout branch",
		},
	},
	opts = {
		keymaps = {
			-- The keys above own compare/checkout; the plugin's own <leader>lb and
			-- <leader>lc would only duplicate them once it has loaded.
			global = { compare = false, checkout = false },
			-- g? is the help key in oil and most plugin buffers.
			canvas = { help = "g?" },
			sidebar = { help = "g?" },
			-- The default <C-Space> is already the alternate-file key in remap.lua.
			-- Backspace is otherwise idle in normal mode and reads as "back".
			file = { back = "<BS>" },
		},
	},
}
