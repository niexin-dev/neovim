return {
	name = "startup-dashboard",
	dir = vim.fn.stdpath("config"),
	lazy = false,
	priority = 1000,

	config = function()
		local api = vim.api
		local fn = vim.fn

		-----------------------------------------------------
		-- devicons / tokyonight 安全加载
		-----------------------------------------------------
		local has_devicons, devicons = pcall(require, "nvim-web-devicons")

		local ok_colors, tn_colors = pcall(function()
			return require("tokyonight.colors").setup()
		end)

		local colors = ok_colors and tn_colors
			or {
				magenta = "#ff79c6",
				blue = "#61afef",
				orange = "#d19a66",
				cyan = "#56b6c2",
				comment = "#5c6370",
			}

		-----------------------------------------------------
		-- 高亮定义
		-----------------------------------------------------
		local function setup_hl()
			local hl = {
				OldfilesHeader = { fg = colors.magenta, bold = true },
				OldfilesSection = { fg = colors.blue, bold = true },
				OldfilesIndex = { fg = colors.orange, bold = true },
				OldfilesPath = { fg = colors.comment, italic = true },
				OldfilesFilename = { fg = colors.cyan, bold = true },
				OldfilesHint = { fg = colors.comment, italic = true },
			}
			for k, v in pairs(hl) do
				api.nvim_set_hl(0, k, v)
			end
		end

		-----------------------------------------------------
		-- 图标缓存（使用 devicons 自带 hl_group）
		-----------------------------------------------------
		local icon_cache = {}
		local function get_icon_cached(fname)
			if not has_devicons then
				return "", nil
			end
			if icon_cache[fname] then
				return icon_cache[fname].icon, icon_cache[fname].hl
			end
			local ext = fn.fnamemodify(fname, ":e")
			local icon, hl = devicons.get_icon(fname, ext, { default = true })
			icon_cache[fname] = { icon = icon or "", hl = hl }
			return icon_cache[fname].icon, icon_cache[fname].hl
		end

		-----------------------------------------------------
		-- 拆分路径 / 文件名范围（用 Vim 的 matchstrpos）
		-----------------------------------------------------
		local function split_ranges(full_line, path_start)
			local m = fn.matchstrpos(full_line, [[\v[^/\\]+$]])
			local fname_s, fname_e = m[2], m[3]
			if fname_s < 0 then
				return path_start, nil, nil
			end
			local path_end = fname_s
			return path_start, path_end, fname_e
		end

		-----------------------------------------------------
		-- 打开文件并 cd 到 git root
		-----------------------------------------------------
		local function open_oldfile(path)
			if not path or path == "" then
				return
			end
			local dir = fn.fnamemodify(path, ":p:h")
			local root = fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })[1]

			if vim.v.shell_error == 0 and root and root ~= "" then
				vim.cmd("cd " .. fn.fnameescape(root))
			else
				vim.cmd("cd " .. fn.fnameescape(dir))
			end

			vim.cmd.edit(fn.fnameescape(path))
		end

		-----------------------------------------------------
		-- 查找所有 entry 行（形如 "  [1]  ..."）
		-----------------------------------------------------
		local function get_entry_lines(buf)
			local total = api.nvim_buf_line_count(buf)
			local list = {}
			for l = 1, total do
				local text = api.nvim_buf_get_lines(buf, l - 1, l, false)[1]
				if text and text:match("^%s*%[[0-9]%]") then
					table.insert(list, l)
				end
			end
			return list
		end

		-----------------------------------------------------
		-- j / k：只在 entry 行之间循环移动
		-----------------------------------------------------
		local function move_delta(delta)
			local win = api.nvim_get_current_win()
			local buf = api.nvim_win_get_buf(win)

			local entry_lines = get_entry_lines(buf)
			if #entry_lines == 0 then
				return
			end

			local pos = api.nvim_win_get_cursor(win)
			local line = pos[1]

			local cur_idx
			for i, l in ipairs(entry_lines) do
				if l == line then
					cur_idx = i
					break
				end
			end

			if not cur_idx then
				cur_idx = delta > 0 and 1 or #entry_lines
			else
				if delta > 0 then
					cur_idx = (cur_idx % #entry_lines) + 1
				else
					cur_idx = (cur_idx - 2 + #entry_lines) % #entry_lines + 1
				end
			end

			local target = entry_lines[cur_idx]
			api.nvim_win_set_cursor(win, { target, 0 })

			-- 让光标落在数字上
			local line_text = api.nvim_buf_get_lines(buf, target - 1, target, false)[1]
			local l = line_text and line_text:find("%[[0-9]%]")
			if l then
				api.nvim_win_set_cursor(win, { target, l })
			end
		end

		-----------------------------------------------------
		-- ASCII header
		-----------------------------------------------------
		local HEADER = {
			[[    _   _   _                 _           _           _   _                          _                ]],
			[[   | \ | | (_)   ___  __  __ (_)  _ __   ( )  ___    | \ | |   ___    ___   __   __ (_)  _ __ ___     ]],
			[[   |  \| | | |  / _ \ \ \/ / | | | '_ \  |/  / __|   |  \| |  / _ \  / _ \  \ \ / / | | | '_ ` _ \    ]],
			[[   | |\  | | | |  __/  >  <  | | | | | |     \__ \   | |\  | |  __/ | (_) |  \ V /  | | | | | | | |   ]],
			[[   |_| \_| |_|  \___| /_/\_\ |_| |_| |_|     |___/   |_| \_|  \___|  \___/    \_/   |_| |_| |_| |_|   ]],
		}

		-----------------------------------------------------
		-- 主渲染函数
		-----------------------------------------------------
		local function render(max_entries)
			max_entries = max_entries or 10

			local old = vim.v.oldfiles or {}
			local buf = api.nvim_create_buf(false, true)
			local win = api.nvim_get_current_win()

			setup_hl()
			api.nvim_create_autocmd("ColorScheme", {
				buffer = buf,
				callback = setup_hl,
			})

			local lines = {}

			---------------- HEADER ----------------
			for _, l in ipairs(HEADER) do
				table.insert(lines, l)
			end
			table.insert(lines, "")
			local header_count = #HEADER

			---------------- SECTION ----------------
			local section_lnum = #lines + 1
			table.insert(lines, "    Recent files")
			table.insert(lines, "  " .. string.rep("─", math.min(vim.o.columns - 4, 50)))
			table.insert(lines, "")

			---------------- ENTRIES ----------------
			local entries = {}
			for i = 1, math.min(#old, max_entries) do
				local label = (i == 10) and "0" or tostring(i)
				local prefix = "  [" .. label .. "]  "

				local fname = old[i]
				local path = fn.fnamemodify(fname, ":~:.")
				local icon, icon_hl = get_icon_cached(fname)
				local icon_part = icon ~= "" and (icon .. " ") or ""
				local full_line = prefix .. icon_part .. path

				table.insert(lines, full_line)

				local lnum = #lines
				local path_start = #prefix + #icon_part
				local ps, pe, fe = split_ranges(full_line, path_start)

				entries[#entries + 1] = {
					lnum = lnum, -- 1-based 行号
					full = full_line,
					ps = ps, -- path 起始列（0-based）
					pe = pe, -- path 结束列（0-based，filename 起点）
					fe = fe, -- filename 结束列
					icon = icon,
					icon_col = #prefix, -- icon overlay 列
					icon_hl = icon_hl,
					raw = fname,
				}
			end

			if #entries == 0 then
				table.insert(lines, "  (no recent files)")
			end

			---------------- FOOTER ----------------
			table.insert(lines, "")
			local hint_lnum = #lines + 1
			table.insert(lines, "    [1-9,0] Open file · j/k Move · <CR> Current · <Esc> Close")

			---------------- 写入 BUFFER ----------------
			api.nvim_buf_set_lines(buf, 0, -1, false, lines)
			api.nvim_win_set_buf(win, buf)

			-----------------------------------------------------
			-- 设置 Dashboard 专用的 buffer 选项
			-----------------------------------------------------
			api.nvim_set_option_value("buftype", "nofile", { buf = buf })
			api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
			api.nvim_set_option_value("swapfile", false, { buf = buf })
			api.nvim_set_option_value("modifiable", false, { buf = buf })
			api.nvim_set_option_value("filetype", "startup-dashboard", { buf = buf })

			---------------- 高亮（用 add_highlight，安全） ----------------

			-- Header 整行
			for i = 0, header_count - 1 do
				api.nvim_buf_add_highlight(buf, -1, "OldfilesHeader", i, 0, -1)
			end

			-- Section / Hint 整行
			api.nvim_buf_add_highlight(buf, -1, "OldfilesSection", section_lnum - 1, 0, -1)
			api.nvim_buf_add_highlight(buf, -1, "OldfilesHint", hint_lnum - 1, 0, -1)

			-- Entries
			local ns = api.nvim_create_namespace("StartupDashboard")
			for _, e in ipairs(entries) do
				local l0 = e.lnum - 1
				local line = lines[e.lnum] or ""
				local len = #line

				-- [x] 索引
				api.nvim_buf_add_highlight(buf, -1, "OldfilesIndex", l0, 2, 5)

				-- 路径 / 文件名
				if not e.pe then
					-- 没找到文件名（比如 fugitive://），整段当路径
					api.nvim_buf_add_highlight(buf, -1, "OldfilesPath", l0, e.ps, len)
				else
					api.nvim_buf_add_highlight(buf, -1, "OldfilesPath", l0, e.ps, e.pe)
					api.nvim_buf_add_highlight(buf, -1, "OldfilesFilename", l0, e.pe, e.fe)
				end

				-- 彩色图标 overlay（使用 devicons 自带 hl_group）
				if e.icon ~= "" and e.icon_hl then
					api.nvim_buf_set_extmark(buf, ns, l0, e.icon_col, {
						virt_text = { { e.icon, e.icon_hl } },
						virt_text_pos = "overlay",
						virt_text_hide = true,
					})
				end
			end

			---------------- 初始光标位置：第一条 entry ----------------
			if entries[1] then
				local l = entries[1].lnum
				local col = (lines[l] or ""):find("%[[0-9]%]") or 0
				api.nvim_win_set_cursor(win, { l, col })
			end

			---------------- KEYMAPS ----------------

			-- 数字打开
			for i, e in ipairs(entries) do
				local key = (i == 10) and "0" or tostring(i)
				vim.keymap.set("n", key, function()
					open_oldfile(e.raw)
				end, { buffer = buf, silent = true })
			end

			-- <CR> 打开当前行
			vim.keymap.set("n", "<CR>", function()
				local line = api.nvim_get_current_line()
				local key = line:match("%[(%d)%]")
				if not key then
					return
				end
				local idx = (key == "0") and 10 or tonumber(key)
				local e = entries[idx]
				if e then
					open_oldfile(e.raw)
				end
			end, { buffer = buf, silent = true })

			-- j / k 循环移动
			vim.keymap.set("n", "j", function()
				move_delta(1)
			end, { buffer = buf, silent = true })
			vim.keymap.set("n", "k", function()
				move_delta(-1)
			end, { buffer = buf, silent = true })

			-- 关闭
			vim.keymap.set("n", "<Esc>", "<cmd>bd!<cr>", { buffer = buf, silent = true })

			-- 在 dashboard buffer 里 “透传” i/o/a/...：
			-- 先 bd! 关闭 dashboard，再在新 buffer 里执行原本的命令
			local function map_pass_through(key)
				vim.keymap.set("n", key, function()
					-- 记录 count（3i、2o 等），如果不关心可以去掉这几行
					local count = vim.v.count
					local seq = (count > 0 and tostring(count) or "") .. key

					-- 先关闭当前 dashboard buffer
					vim.cmd("bd!")

					-- 把原始按键序列送到新的当前 buffer
					local term = vim.api.nvim_replace_termcodes(seq, true, false, true)
					vim.api.nvim_feedkeys(term, "n", false)
				end, { buffer = buf, silent = true })
			end

			for _, key in ipairs({ "i", "I", "a", "A", "o", "O", "s", "S", "c", "C", "r", "R" }) do
				map_pass_through(key)
			end
		end

		-----------------------------------------------------
		-- 启动自动显示
		-----------------------------------------------------
		api.nvim_create_autocmd("VimEnter", {
			once = true,
			callback = function()
				if fn.argc() == 0 and api.nvim_buf_get_name(0) == "" then
					render(10)
				end
			end,
		})
	end,
}
