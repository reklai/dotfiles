return {
	"folke/trouble.nvim",
	opts = {}, -- for default options, refer to the configuration section for custom setup.
	cmd = "Trouble",
	keys = {
		{
			"]t",
			function()
				require("trouble").next({ mode = "diagnostics", focus = false, jump = true })
			end,
			desc = "Next Global Diagnostic (Trouble)",
		},
		{
			"[t",
			function()
				require("trouble").prev({ mode = "diagnostics", focus = false, jump = true })
			end,
			desc = "Previous Global Diagnostic (Trouble)",
		},
		{
			"<leader>tt",
			"<cmd>Trouble diagnostics toggle<cr>",
			desc = "Global Diagnostics (Trouble)",
		},
		{
			"<leader>tb",
			"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
			desc = "Buffer Diagnostics (Trouble)",
		},
	},
}
