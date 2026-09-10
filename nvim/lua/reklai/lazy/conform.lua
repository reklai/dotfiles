return { -- Autoformat
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo" },
	keys = {
		{
			"<leader>f",
			function()
				require("conform").format({ async = true, lsp_format = "fallback" })
			end,
			mode = "",
			desc = "[F]ormat buffer",
		},
	},
	opts = {
		notify_on_error = false,
		format_on_save = function(bufnr)
			-- google-java-format is a JVM tool: cold-start easily blows the
			-- default budget, so give Java saves a longer leash.
			local timeout_ms = vim.bo[bufnr].filetype == "java" and 5000 or 1000
			return {
				timeout_ms = timeout_ms,
				lsp_format = "fallback",
			}
		end,
		formatters_by_ft = {
			lua = { "stylua" },
			go = { "goimports", "gofumpt" },
			zig = { "zigfmt" },
			rust = { "rustfmt" },
			c = { "clang_format" },
			cpp = { "clang_format" },
			java = { "google-java-format" },
			javascript = { "prettier", "eslint_d" },
			javascriptreact = { "prettier", "eslint_d" },
			typescript = { "prettier", "eslint_d" },
			typescriptreact = { "prettier", "eslint_d" },
			json = { "prettier" },
			jsonc = { "prettier" },
			python = { "ruff_fix", "ruff_format", "ruff_organize_imports" },
		},
	},
}
