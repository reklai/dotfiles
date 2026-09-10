return {
	dir = "~/coding/personal/neovim/canvasdiff.nvim",
	name = "canvasdiff",
	cmd = "CanvasDiff",
	keys = {
		{
			"<leader><leader>",
			function()
				require("canvasdiff").toggle()
			end,
			desc = "Toggle git diff canvas",
		},
		-- One key, cycles: all -> unstaged -> staged. Same thing <Tab> does on
		-- the canvas, reachable from anywhere. Deliberately under <leader>l rather
		-- than hanging off <leader><leader> -- a mapping like <leader><leader>l would
		-- make the toggle above wait a full 'timeoutlen' to see whether another key
		-- was coming.
		{
			"<leader>ll",
			function()
				require("canvasdiff").cycle_lens(1)
			end,
			desc = "canvasdiff: cycle the lens (all / unstaged / staged)",
		},
	},
	config = function()
		require("canvasdiff").setup()
	end,
}
