return {
	name = "startup-dashboard",
	dir = vim.fn.stdpath("config"),
	lazy = false,
	priority = 1000,

	config = function()
		vim.opt.termguicolors = true

		-- icons
		local has_devicons, devicons = pcall(require, "nvim-web-devicons")

		-- Tokyonight colors
		local function get_colors()
			return require("tokyonight.colors").setup()
		end

		-- Apply custom highlights
		local function setup_hl()
			local c = get_colors()
			vim.api.nvim_set_hl(0, "OldfilesHeader", { fg = c.magenta, bold = true, force = true }) -- ASCII 标题
			vim.api.nvim_set_hl(0, "OldfilesSection", { fg = c.blue, bold = true, force = true }) -- “Recent files”
			vim.api.nvim_set_hl(0, "OldfilesIndex", { fg = c.orange, bold = true, force = true }) -- [1] [2]
			vim.api.nvim_set_hl(0, "OldfilesPath", { fg = c.comment, italic = true, force = true }) -- 路径
			vim.api.nvim_set_hl(0, "OldfilesFilename", { fg = c.cyan, bold = true, force = true }) -- 文件名
			vim.api.nvim_set_hl(0, "OldfilesHint", { fg = c.comment, italic = true, force = true }) -- 底部提示
		end

		-- Helper: find path + filename ranges（现在用 path_start，而不是 label）
		local function split_ranges(full_line, path_start)
			-- 找出最后一段非 / 或 \ 的部分（文件名）
			local m = vim.fn.matchstrpos(full_line, [[\v[^/\\]+$]])
			local fname_s, fname_e = m[2], m[3]

			if fname_s < 0 then
				-- 没有文件名（如 fugitive://…//），整段都是路径
				return path_start, nil, nil
			end

			local path_end = fname_s
			return path_start, path_end, fname_e
		end

		-- 打开文件（自动 cd 到 git root）
		local function open_oldfile(path)
			if not path or path == "" then
				return
			end
			local dir = vim.fn.fnamemodify(path, ":p:h")
			local root = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })[1]

			if vim.v.shell_error == 0 and root and root ~= "" then
				vim.cmd("cd " .. vim.fn.fnameescape(root))
			else
				vim.cmd("cd " .. vim.fn.fnameescape(dir))
			end

			vim.cmd.edit(vim.fn.fnameescape(path))
		end

		-- 将光标对齐到当前行的 [digit] 中的数字上
		local function center_on_index(win, line_nr)
			line_nr = line_nr or vim.api.nvim_win_get_cursor(win)[1]
			local line = vim.api.nvim_buf_get_lines(0, line_nr - 1, line_nr, false)[1]
			if not line then
				return
			end

			-- 找到 "[3]" 这种模式
			local l, r = line:find("%[[0-9]%]")
			if l and r then
				-- 数字在 "[" 后面一位，Neovim 的 col 是 0-based
				-- 这里推导：digit_pos = l + 1, col = digit_pos - 1 = l
				vim.api.nvim_win_set_cursor(win, { line_nr, l })
			else
				-- 找不到就放在行首
				vim.api.nvim_win_set_cursor(win, { line_nr, 0 })
			end
		end

		-- j/k 移动时，保持光标在数字上
		local function move_delta(delta)
			local win = vim.api.nvim_get_current_win()
			local pos = vim.api.nvim_win_get_cursor(win)
			local new_line = pos[1] + delta
			local line_count = vim.api.nvim_buf_line_count(0)

			if new_line < 1 then
				new_line = 1
			elseif new_line > line_count then
				new_line = line_count
			end

			-- 先移动到目标行，再对齐到 [digit]
			vim.api.nvim_win_set_cursor(win, { new_line, 0 })
			center_on_index(win, new_line)
		end

		-- Main renderer
		local function render()
			if vim.fn.argc() ~= 0 or vim.api.nvim_buf_get_name(0) ~= "" then
				return
			end

			local old = vim.v.oldfiles
			if not old or vim.tbl_isempty(old) then
				old = {}
			end
			local max = 10

			local buf = vim.api.nvim_create_buf(false, true)
			local win = vim.api.nvim_get_current_win()
			vim.wo[win].winhighlight = ""

			setup_hl()
			vim.api.nvim_create_autocmd("ColorScheme", { buffer = buf, callback = setup_hl })

			local lines = {}
			local entries = {}

			-- header ASCII
			local header = {
				[[    _   _   _                 _           _           _   _                          _                ]],
				[[   | \ | | (_)   ___  __  __ (_)  _ __   ( )  ___    | \ | |   ___    ___   __   __ (_)  _ __ ___     ]],
				[[   |  \| | | |  / _ \ \ \/ / | | | '_ \  |/  / __|   |  \| |  / _ \  / _ \  \ \ / / | | | '_ ` _ \    ]],
				[[   | |\  | | | |  __/  >  <  | | | | | |     \__ \   | |\  | |  __/ | (_) |  \ V /  | | | | | | | |   ]],
				[[   |_| \_| |_|  \___| /_/\_\ |_| |_| |_|     |___/   |_| \_|  \___|  \___/    \_/   |_| |_| |_| |_|   ]],
			}
			vim.list_extend(lines, header)

			lines[#lines + 1] = ""

			-- section title: Recent files
			local section_line = #lines -- 0-based 时再减 1
			lines[#lines + 1] = "    Recent files"
			lines[#lines + 1] =
				"  ───────────────────────────────────────────────"

			lines[#lines + 1] = ""

			local first_line

			-- entries
			for i = 1, math.min(#old, max) do
				local label = (i == 10) and "0" or tostring(i)
				local path = vim.fn.fnamemodify(old[i], ":~:.")
				local prefix = "  [" .. label .. "]  "

				-- 文件图标（nvim-web-devicons）
				local icon_part = ""
				if has_devicons then
					local ext = vim.fn.fnamemodify(old[i], ":e")
					local icon = devicons.get_icon(old[i], ext, { default = true })
					if icon then
						icon_part = icon .. " "
					end
				end

				local full_line = prefix .. icon_part .. path
				lines[#lines + 1] = full_line

				if not first_line then
					first_line = #lines
				end

				entries[#entries + 1] = {
					line = #lines - 1,
					label = label,
					full = full_line,
					raw = old[i],
					path_start = #prefix + #icon_part,
				}
			end

			-- 没有 recent files 时给个提示
			if #entries == 0 then
				lines[#lines + 1] = "  (no recent files)"
			end

			-- 底部操作提示
			lines[#lines + 1] = ""
			local hint_line = #lines
			lines[#lines + 1] = "    [1-9,0] Open file · j/k Move · <CR> Current · <Esc> Close"

			-- write lines
			vim.api.nvim_buf_set_option(buf, "modifiable", true)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
			vim.api.nvim_buf_set_option(buf, "modifiable", false)
			vim.api.nvim_win_set_buf(win, buf)

			-- header highlight
			for i = 0, #header - 1 do
				vim.api.nvim_buf_add_highlight(buf, -1, "OldfilesHeader", i, 0, -1)
			end

			-- section title highlight
			vim.api.nvim_buf_add_highlight(buf, -1, "OldfilesSection", section_line, 0, -1)

			-- hint highlight
			vim.api.nvim_buf_add_highlight(buf, -1, "OldfilesHint", hint_line, 0, -1)

			-- entries highlight
			for _, e in ipairs(entries) do
				-- index highlight [x]
				vim.api.nvim_buf_add_highlight(buf, -1, "OldfilesIndex", e.line, 2, 5)

				local ps, pe, fe = split_ranges(e.full, e.path_start)
				if not pe then
					-- 全路径
					vim.api.nvim_buf_add_highlight(buf, -1, "OldfilesPath", e.line, ps, -1)
				else
					vim.api.nvim_buf_add_highlight(buf, -1, "OldfilesPath", e.line, ps, pe)
					vim.api.nvim_buf_add_highlight(buf, -1, "OldfilesFilename", e.line, pe, fe)
				end
			end

			-- cursor at first entry（没有 entries 就不移动光标）
			if first_line then
				center_on_index(win, first_line)
			end

			-- keymaps: 数字 -> 对应文件
			for i, e in ipairs(entries) do
				local key = (i == 10) and "0" or tostring(i)
				vim.keymap.set("n", key, function()
					open_oldfile(e.raw)
				end, { buffer = buf, silent = true })
			end

			-- <CR> 当前行
			vim.keymap.set("n", "<CR>", function()
				local line = vim.api.nvim_get_current_line()
				local key = line:match("%[(%d)%]")
				if key then
					local idx = (key == "0") and 10 or tonumber(key)
					local e = entries[idx]
					if e then
						open_oldfile(e.raw)
					end
				end
			end, { buffer = buf, silent = true })

			-- j/k：移动并保持光标在 [digit] 中间
			vim.keymap.set("n", "j", function()
				move_delta(1)
			end, { buffer = buf, silent = true })

			vim.keymap.set("n", "k", function()
				move_delta(-1)
			end, { buffer = buf, silent = true })

			-- 关闭 dashboard
			vim.keymap.set("n", "<Esc>", "<cmd>bd!<cr>", { buffer = buf, silent = true })
		end

		if vim.fn.argc() == 0 and vim.api.nvim_buf_get_name(0) == "" then
			if not vim.tbl_contains(vim.opt.shortmess:get(), "I") then
				vim.opt.shortmess:append("I")
			end
		end

		vim.api.nvim_create_autocmd("VimEnter", { callback = render, once = true })
	end,
}
