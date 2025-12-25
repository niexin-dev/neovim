-- lua/nx_terminal/init.lua
-- A small local module that provides:
--   - new terminal window creation with smart split strategy
--   - toggle show/hide previously shown terminals
--   - terminal escape mapping helper
--   - tab-based zoom toggle
--
-- Usage:
--   require("nx_terminal").setup()

local M = {}

-- -----------------------------
-- Internal state
-- -----------------------------
local state = {
	hidden_term_buffers = {}, -- buffers of terminals that were hidden
	zoom_tabpage = nil, -- original tabpage before zoom
	last_term_win = nil, -- best-effort "last used terminal window"
}

-- -----------------------------
-- Defaults
-- -----------------------------
local defaults = {
	auto_insert = true, -- TermOpen auto startinsert
	startinsert_on_restore = true, -- when toggling back hidden terminals
	open_cmd = "terminal", -- command to open a terminal
	split_when_no_term = "belowright split", -- when no term exists
	restore_first = "belowright split", -- first restored terminal placement
	restore_next = "vsplit", -- subsequent restored terminal placement
	new_term_when_has_term = "vsplit", -- when term exists, create on the right of last term
	mappings = {
		-- terminal-mode escape
		term_escape = { mode = "t", lhs = "<leader>e", rhs = [[<C-\><C-n>]], desc = "Terminal: exit to Normal" },

		-- create a new terminal
		new_terminal = { mode = "n", lhs = "<leader>fw", desc = "New terminal" },

		-- toggle terminals show/hide/new
		toggle_terminal = { mode = "n", lhs = "<leader>fa", desc = "Toggle terminal" },

		-- tab-zoom
		zoom_toggle = { mode = "n", lhs = "<leader>m", desc = "Toggle maximize current buffer (via tab)" },
	},
}

-- -----------------------------
-- Helpers
-- -----------------------------
local function is_terminal_buf(buf)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return false
	end
	-- Prefer buffer-local option access
	return vim.bo[buf].buftype == "terminal"
end

local function list_terminal_windows()
	local wins = {}
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if is_terminal_buf(buf) then
			wins[#wins + 1] = win
		end
	end
	return wins
end

local function list_terminal_buffers_from_windows(wins)
	local bufs = {}
	for _, win in ipairs(wins) do
		local buf = vim.api.nvim_win_get_buf(win)
		if is_terminal_buf(buf) then
			bufs[#bufs + 1] = buf
		end
	end
	return bufs
end

local function set_last_term_win(win)
	if win and vim.api.nvim_win_is_valid(win) then
		state.last_term_win = win
	end
end

local function best_last_terminal_win()
	-- 1) If we have a remembered win and it is still valid and terminal, use it
	if state.last_term_win and vim.api.nvim_win_is_valid(state.last_term_win) then
		local buf = vim.api.nvim_win_get_buf(state.last_term_win)
		if is_terminal_buf(buf) then
			return state.last_term_win
		end
	end

	-- 2) Otherwise, fall back to the last one in current window list (best-effort)
	local last = nil
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if is_terminal_buf(buf) then
			last = win
		end
	end
	return last
end

local function cmd(c)
	vim.cmd(c)
end

-- -----------------------------
-- Public API
-- -----------------------------

-- terminal-mode escape helper (mostly for consistency)
function M.escape()
	-- same behavior as mapping: <C-\><C-n>
	local keys = vim.api.nvim_replace_termcodes([[<C-\><C-n>]], true, false, true)
	vim.api.nvim_feedkeys(keys, "n", false)
end

-- <leader>fw behavior: create a terminal
function M.new()
	local last_term_win = best_last_terminal_win()

	if last_term_win and vim.api.nvim_win_is_valid(last_term_win) then
		-- already have terminal: create new on the right of last terminal
		vim.api.nvim_set_current_win(last_term_win)
		cmd(M.opts.new_term_when_has_term)
		cmd(M.opts.open_cmd)
		set_last_term_win(vim.api.nvim_get_current_win())
		return
	end

	-- no terminal: open below current buffer
	cmd(M.opts.split_when_no_term)
	cmd(M.opts.open_cmd)
	set_last_term_win(vim.api.nvim_get_current_win())
end

-- <leader>fa behavior: show/hide/new
function M.toggle()
	local term_wins = list_terminal_windows()

	-- Case 1: terminals are currently shown -> hide them and remember buffers
	if #term_wins > 0 then
		state.hidden_term_buffers = list_terminal_buffers_from_windows(term_wins)
		for _, win in ipairs(term_wins) do
			-- Hide window without killing job
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_hide(win)
			end
		end
		return
	end

	-- Case 2: none shown but we have hidden buffers -> restore them
	if #state.hidden_term_buffers > 0 then
		local first = true
		for _, buf in ipairs(state.hidden_term_buffers) do
			if vim.api.nvim_buf_is_valid(buf) and is_terminal_buf(buf) then
				if first then
					cmd(M.opts.restore_first)
					first = false
				else
					cmd(M.opts.restore_next)
				end

				vim.api.nvim_win_set_buf(0, buf)
				set_last_term_win(vim.api.nvim_get_current_win())

				if M.opts.startinsert_on_restore then
					cmd("startinsert")
				end
			end
		end
		state.hidden_term_buffers = {}
		return
	end

	-- Case 3: none shown and none hidden -> create new
	M.new()
end

-- <leader>m behavior: tab-based zoom toggle
function M.zoom_toggle()
	local current_tab = vim.api.nvim_get_current_tabpage()
	local wins = vim.api.nvim_tabpage_list_wins(current_tab)

	-- If only one window and not already zoomed: do nothing
	if #wins == 1 and state.zoom_tabpage == nil then
		return
	end

	-- Enter zoom
	if state.zoom_tabpage == nil then
		state.zoom_tabpage = current_tab
		cmd("tab split")
		return
	end

	-- Exit zoom
	if current_tab ~= state.zoom_tabpage then
		cmd("tabclose")
	end

	state.zoom_tabpage = nil
end

-- -----------------------------
-- Setup
-- -----------------------------
local function apply_mappings()
	local map = vim.keymap.set
	local m = M.opts.mappings

	if m.term_escape and m.term_escape.lhs and m.term_escape.rhs then
		map(
			m.term_escape.mode,
			m.term_escape.lhs,
			m.term_escape.rhs,
			{ noremap = true, silent = true, desc = m.term_escape.desc }
		)
	end

	if m.new_terminal and m.new_terminal.lhs then
		map(
			m.new_terminal.mode,
			m.new_terminal.lhs,
			M.new,
			{ noremap = true, silent = true, desc = m.new_terminal.desc }
		)
	end

	if m.toggle_terminal and m.toggle_terminal.lhs then
		map(
			m.toggle_terminal.mode,
			m.toggle_terminal.lhs,
			M.toggle,
			{ noremap = true, silent = true, desc = m.toggle_terminal.desc }
		)
	end

	if m.zoom_toggle and m.zoom_toggle.lhs then
		map(
			m.zoom_toggle.mode,
			m.zoom_toggle.lhs,
			M.zoom_toggle,
			{ noremap = true, silent = true, desc = m.zoom_toggle.desc }
		)
	end
end

local function apply_autocmds()
	if not M.opts.auto_insert then
		return
	end

	vim.api.nvim_create_autocmd("TermOpen", {
		callback = function(args)
			-- Update "last term win" best-effort
			local win = vim.api.nvim_get_current_win()
			set_last_term_win(win)

			-- Always startinsert on TermOpen (configurable)
			cmd("startinsert")
		end,
	})

	-- Optional: track last used terminal window more reliably when entering terminal
	vim.api.nvim_create_autocmd({ "TermEnter", "BufEnter" }, {
		callback = function()
			local win = vim.api.nvim_get_current_win()
			local buf = vim.api.nvim_win_get_buf(win)
			if is_terminal_buf(buf) then
				set_last_term_win(win)
			end
		end,
	})
end

function M.setup(opts)
	M.opts = vim.tbl_deep_extend("force", {}, defaults, opts or {})
	apply_mappings()
	apply_autocmds()
end

return M
