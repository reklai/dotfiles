vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

vim.keymap.set({ "n","i" }, "<C-h>", "<Cmd>wincmd h<CR>", { desc = "Move focus to the left pane" })
vim.keymap.set({ "n","i" }, "<C-l>", "<Cmd>wincmd l<CR>", { desc = "Move focus to the right pane" })
vim.keymap.set({ "n","i" }, "<C-j>", "<Cmd>wincmd j<CR>", { desc = "Move focus to the bottom pane" })
vim.keymap.set({ "n","i" }, "<C-k>", "<Cmd>wincmd k<CR>", { desc = "Move focus to the top pane" })

-- Double check for information (future self)
-- I believe the use-case worth it for rebinding
vim.keymap.set({ "n" }, "<C-q>", "<Cmd>wincmd q<CR>", { desc = "Quit current window" })
vim.keymap.set({ "n" }, "<C-t>", "<Cmd>vsplit<CR>", { desc = "Split current window" })
-- Unmapped, Ctrl+Shift+U falls back to Ctrl+U; keep it inert beside the split.
vim.keymap.set({ "n" }, "<C-S-u>", "<Nop>")

-- Alternate file stays off Ctrl-P so completion can use Ctrl-P / Ctrl-N.
-- Terminals often send Ctrl-Space
vim.keymap.set("n", "<C-Space>", "<C-^>", { desc = "Alternate file" })

-- Buffer diagnostics on Ctrl+Shift+J/K (next/previous), replacing the default
-- ]d / [d. Ctrl+Shift+N/P walk every buffer's diagnostics (below).
vim.keymap.set("n", "<C-S-k>", function()
	vim.diagnostic.jump({ count = -vim.v.count1 })
end, { desc = "Previous diagnostic in buffer" })
vim.keymap.set("n", "<C-S-j>", function()
	vim.diagnostic.jump({ count = vim.v.count1 })
end, { desc = "Next diagnostic in buffer" })
pcall(vim.keymap.del, "n", "[d")
pcall(vim.keymap.del, "n", "]d")

-- Global diagnostics on Ctrl+Shift+N/P (next/previous): one stop per diagnostic
-- line across all buffers, ordered by severity, file, then line. Native rather
-- than Trouble's next/prev, which opens its panel and throws "Invalid cursor
-- line" when a stale diagnostic points past the end of the file.
local function diagnostic_stops()
	local stops, by_line = {}, {}
	for _, diag in ipairs(vim.diagnostic.get(nil)) do
		if vim.api.nvim_buf_is_valid(diag.bufnr) then
			local key = diag.bufnr .. ":" .. diag.lnum
			local stop = by_line[key]
			if not stop then
				stop = {
					buf = diag.bufnr,
					name = vim.api.nvim_buf_get_name(diag.bufnr),
					lnum = diag.lnum,
					col = diag.col,
					severity = diag.severity,
				}
				by_line[key] = stop
				table.insert(stops, stop)
			else
				stop.severity = math.min(stop.severity, diag.severity)
				stop.col = math.min(stop.col, diag.col)
			end
		end
	end
	table.sort(stops, function(a, b)
		if a.severity ~= b.severity then
			return a.severity < b.severity
		end
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.lnum < b.lnum
	end)
	return stops
end

local function jump_global_diagnostic(step)
	local stops = diagnostic_stops()
	if #stops == 0 then
		vim.notify("No diagnostics", vim.log.levels.INFO)
		return
	end

	-- Stale stops are compared at the line they clamp to, so stepping moves on.
	local buf = vim.api.nvim_get_current_buf()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local last = vim.api.nvim_buf_line_count(buf)
	local current
	for i, stop in ipairs(stops) do
		if stop.buf == buf and math.min(stop.lnum + 1, last) == row then
			current = i
			break
		end
	end

	local index = step > 0 and 1 or #stops
	if current then
		index = (current - 1 + step) % #stops + 1
	end
	local target = stops[index]

	if not vim.api.nvim_buf_is_loaded(target.buf) then
		pcall(vim.fn.bufload, target.buf)
	end
	vim.bo[target.buf].buflisted = true
	vim.cmd("normal! m'")
	vim.api.nvim_win_set_buf(0, target.buf)
	local line = math.min(target.lnum + 1, vim.api.nvim_buf_line_count(target.buf))
	local text = vim.api.nvim_buf_get_lines(target.buf, line - 1, line, false)[1] or ""
	vim.api.nvim_win_set_cursor(0, { line, math.min(target.col, #text) })
	vim.cmd("normal! zzzv")
end

vim.keymap.set("n", "<C-S-n>", function()
	jump_global_diagnostic(1)
end, { desc = "Next global diagnostic" })
vim.keymap.set("n", "<C-S-p>", function()
	jump_global_diagnostic(-1)
end, { desc = "Previous global diagnostic" })

-- Full diagnostic for the cursor line; virtual text truncates in narrow splits.
-- Pairs with <C-e> hover and <C-s> signature help. <C-g> toggles it: the
-- second press closes the float instead of entering it.
local diag_float_win
vim.keymap.set({ "n", "i" }, "<C-g>", function()
	if diag_float_win and vim.api.nvim_win_is_valid(diag_float_win) then
		vim.api.nvim_win_close(diag_float_win, true)
		diag_float_win = nil
		return
	end
	local _, win = vim.diagnostic.open_float({
		scope = "line",
		source = "if_many",
		border = "rounded",
		focusable = false,
	})
	diag_float_win = win
end, { desc = "Toggle line diagnostics" })

-- Signature help: <C-s> opens, enters an existing float, and cycles overloads
-- from inside the float. Keep Neovim's Markdown scaffolding visually concealed.
local sig_opts = {
	max_width = 80,
	max_height = 20,
	border = "rounded",
	focus = true,
	focusable = true,
}

local sig_help_method = "textDocument/signatureHelp"
local sig_cycle_plug = "<Plug>(nvim.lsp.ctrl-s)"
local sig_cycle_alias = "<Plug>(reklai.signature-cycle)"

local function decorate_signature_floats(buf)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local float_buf = vim.api.nvim_win_get_buf(win)
		if (not buf or float_buf == buf) and vim.w[win][sig_help_method] then
			vim.wo[win].conceallevel = 2
			vim.wo[win].concealcursor = "n"
			vim.keymap.set("n", "<C-s>", sig_cycle_plug, {
				buffer = float_buf,
				desc = "Cycle LSP signature",
			})

			if not vim.treesitter.highlighter.active[float_buf] then
				pcall(vim.treesitter.start, float_buf, "markdown")
			end

			if not vim.b[float_buf].reklai_signature_float_attached then
				vim.b[float_buf].reklai_signature_float_attached = true
				vim.api.nvim_buf_attach(float_buf, false, {
					on_lines = function()
						vim.schedule(function()
							if vim.api.nvim_buf_is_valid(float_buf) then
								decorate_signature_floats(float_buf)
							end
						end)
					end,
				})
			end
		end
	end
end

local sig_group = vim.api.nvim_create_augroup("reklai-signature-help", { clear = true })

vim.api.nvim_create_autocmd("WinNew", {
	group = sig_group,
	callback = function()
		-- The signature marker is assigned just after the window is created.
		vim.schedule(decorate_signature_floats)
	end,
})

local signature_callbacks = {}

local function map_signature_help(buf)
	local callback = function()
		vim.lsp.buf.signature_help(sig_opts)
	end
	signature_callbacks[buf] = callback

	vim.keymap.set({ "n", "i" }, "<C-s>", callback, {
		buffer = buf,
		desc = "LSP signature help / focus",
	})
	-- This real mapping to Neovim's documented <Plug> action makes hasmapto()
	-- suppress its fallback <C-s> float mapping without stealing a user key.
	vim.keymap.set("n", sig_cycle_alias, sig_cycle_plug, {
		buffer = buf,
		desc = "Cycle LSP signature",
	})
end

local function client_supports_signature(client, buf)
	return client and client:supports_method(sig_help_method, buf)
end

local function map_signature_help_if_supported(client, buf)
	if client_supports_signature(client, buf) then
		map_signature_help(buf)
	end
end

local function unmap_signature_help(buf)
	local callback = signature_callbacks[buf]
	if not callback or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	for _, mode in ipairs({ "n", "i" }) do
		local map = vim.api.nvim_buf_call(buf, function()
			return vim.fn.maparg("<C-s>", mode, false, true)
		end)
		if type(map) == "table" and map.callback == callback then
			vim.keymap.del(mode, "<C-s>", { buffer = buf })
		end
	end

	local alias = vim.api.nvim_buf_call(buf, function()
		return vim.fn.maparg(sig_cycle_alias, "n", false, true)
	end)
	if type(alias) == "table" and alias.rhs == sig_cycle_plug then
		vim.keymap.del("n", sig_cycle_alias, { buffer = buf })
	end
	signature_callbacks[buf] = nil
end

local function reconcile_signature_help(buf, ignored_client_id)
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
		if client.id ~= ignored_client_id and client_supports_signature(client, buf) then
			if not signature_callbacks[buf] then
				map_signature_help(buf)
			end
			return
		end
	end
	unmap_signature_help(buf)
end

vim.api.nvim_create_autocmd("LspAttach", {
	group = sig_group,
	callback = function(event)
		map_signature_help_if_supported(vim.lsp.get_client_by_id(event.data.client_id), event.buf)
	end,
})

vim.api.nvim_create_autocmd("LspDetach", {
	group = sig_group,
	callback = function(event)
		reconcile_signature_help(event.buf, event.data.client_id)
	end,
})

-- Keep this reload-safe for buffers whose LSP attached before this file ran.
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
	reconcile_signature_help(buf)
end

-- Dynamic capabilities may arrive after LspAttach. Wrap Neovim's handler as
-- documented, then re-check every buffer attached to the registering client.
local register_capability = vim.lsp.handlers["client/registerCapability"]
vim.lsp.handlers["client/registerCapability"] = function(err, result, context, config)
	local response = register_capability(err, result, context, config)
	local client = vim.lsp.get_client_by_id(context.client_id)
	if client then
		for buf in pairs(client.attached_buffers) do
			reconcile_signature_help(buf)
		end
	end
	return response
end

local unregister_capability = vim.lsp.handlers["client/unregisterCapability"]
vim.lsp.handlers["client/unregisterCapability"] = function(err, result, context, config)
	local response = unregister_capability(err, result, context, config)
	local client = vim.lsp.get_client_by_id(context.client_id)
	if client then
		for buf in pairs(client.attached_buffers) do
			reconcile_signature_help(buf)
		end
	end
	return response
end

-- Take highlight text and move it up/down
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Indent/dedent the selection and keep it selected for repeated presses
vim.keymap.set("x", "<Tab>", ">gv", { desc = "Indent selection" })
vim.keymap.set("x", "<S-Tab>", "<gv", { desc = "Dedent selection" })
vim.keymap.set("n", "<Tab>", ">>", { desc = "Indent line" })
vim.keymap.set("n", "<S-Tab>", "<<", { desc = "Dedent line" })

-- Take line below and put it in front of the current line
vim.keymap.set("n", "J", "mzJ`z")

-- Keep cursor on same spot while going up/down pages
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")

-- Q = exmode and K = either lsp hover information or man pages (help docs)
vim.keymap.set("n", "Q", "<nop>")
vim.keymap.set("n", "K", "<nop>")

-- Delete without yanking into clipboard
vim.keymap.set({ "n", "x" }, "<leader>d", [["_d]], { desc = "Delete without yanking" })

-- Replace selected text without overwriting clipboard
vim.keymap.set("x", "p", "P", { desc = "Paste while sending it void register" })
