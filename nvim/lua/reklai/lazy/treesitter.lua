-- nvim-treesitter on the `main` branch -- the rewrite is now the stable,
-- maintained plugin (targets Neovim 0.12+; `master` stays frozen for <=0.11).
-- Neovim core still has no parser manager, so this plugin remains the way to
-- install/update parsers. Bump deliberately with :Lazy update nvim-treesitter
-- followed by :TSUpdate to recompile parsers.
--
-- Requires the external `tree-sitter` CLI + a C compiler to build parsers (both
-- present on this machine). Unlike `master`, highlighting is NOT automatic --
-- it's started per buffer via vim.treesitter.start().
return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false, -- the main branch does not support lazy-loading
	build = ":TSUpdate",
	config = function()
		-- Idempotent + async: parsers compile in the background via the tree-sitter
		-- CLI. Run :TSUpdate after upgrading the plugin.
		require("nvim-treesitter").install({
			-- core
			"vim",
			"vimdoc",
			"query",
			"markdown",
			"markdown_inline",
			-- LSP languages
			"lua",
			"c",
			"cpp",
			"go",
			"python",
			"javascript",
			"typescript",
			"tsx",
			"zig",
			"rust",
			"yaml",
			"properties",
			"xml",
		})

		-- Highlighting is opt-in on the main branch: start treesitter for any
		-- buffer whose parser is installed. pcall no-ops for filetypes without a
		-- parser (oil, telescope prompts, etc.).
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("reklai-treesitter", { clear = true }),
			callback = function(args)
				-- Skip treesitter on very large files so it doesn't choke on
				-- huge/minified buffers. Neovim's own ftplugins (lua, help, ...)
				-- auto-start treesitter and run before this autocmd, so for big
				-- files we STOP it rather than merely avoiding start.
				local max_filesize = 100 * 1024 -- 100 KB
				local ok, stats = pcall((vim.uv or vim.loop).fs_stat, vim.api.nvim_buf_get_name(args.buf))
				if ok and stats and stats.size > max_filesize then
					pcall(vim.treesitter.stop, args.buf)
					return
				end
				pcall(vim.treesitter.start, args.buf)
			end,
		})
	end,
}
