return {
	name = "startup-dashboard",
	dir = vim.fn.stdpath("config"),
	lazy = false,
	priority = 1000,

	config = function()
		local api = vim.api
		local fn = vim.fn
		local uv = vim.loop

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
		-- 判断是否为本地文件路径（排除 fugitive:// 等虚拟 URI）
		-----------------------------------------------------
		local function is_local_path(path)
			-- 匹配 xxx:// 开头的路径，如 fugitive://, term://, http:// 等
			return not path:match("^%w[%w+.-]*://")
		end

		-----------------------------------------------------
		-- 查找 git root（带缓存，整棵项目树只爬一次）
		-----------------------------------------------------
		local git_root_cache = {}
		local NO_GIT_KEY = "__NO_GIT_ROOT__"

		local function find_git_root(path)
			if not is_local_path(path) then
				return nil
			end

			-- 统一用绝对路径
			local abspath = fn.fnamemodify(path, ":p")
			if abspath == "" then
				return nil
			end

			-- 如果传进来的是目录，就从目录本身开始；否则从父目录开始
			local dir = fn.isdirectory(abspath) == 1 and abspath or fn.fnamemodify(abspath, ":h")
			if dir == "" then
				return nil
			end

			local visited = {}
			local root = nil
			local cur = dir

			while cur and cur ~= "" do
				-- 命中缓存（这一步可以省很多遍历）
				if git_root_cache[cur] ~= nil then
					root = git_root_cache[cur]
					break
				end

				table.insert(visited, cur)

				-- 检查 cur/.git 是否存在（目录或文件都算）
				local stat = uv.fs_stat(cur .. "/.git")
				if stat then
					root = cur
					break
				end

				-- 向上一层
				local parent = fn.fnamemodify(cur, ":h")
				if parent == cur then
					break
				end
				cur = parent
			end

			-- 把这次路径上所有目录都写进缓存
			for _, d in ipairs(visited) do
				git_root_cache[d] = root
			end

			return root
		end

		-----------------------------------------------------
		-- 打开文件并 cd 到 git root（复用 find_git_root）
		-----------------------------------------------------
		local function open_oldfile(path)
			if not path or path == "" then
				return
			end

			-- 虚拟 URI（fugitive://、term:// 等）直接忽略
			if not is_local_path(path) then
				return
			end

			local abspath = fn.fnamemodify(path, ":p")
			local dir = fn.fnamemodify(abspath, ":h")

			-- 目录不存在就不要 cd，直接试着打开文件
			if dir == "" or fn.isdirectory(dir) == 0 then
				vim.cmd.edit(fn.fnameescape(path))
				return
			end

			local root = find_git_root(path)
			local target_dir = (root and fn.isdirectory(root) == 1) and root or dir

			vim.cmd("cd " .. fn.fnameescape(target_dir))
			vim.cmd.edit(fn.fnameescape(path))
		end

		-----------------------------------------------------
		-- j / k：只在 entry 行之间循环移动
		-----------------------------------------------------
		local function move_delta(delta)
			local win = api.nvim_get_current_win()
			local buf = api.nvim_win_get_buf(win)

			local ok, entries = pcall(api.nvim_buf_get_var, buf, "startup_entries")
			if not ok or not entries or #entries == 0 then
				return
			end

			-- 当前行号
			local cur_line = api.nvim_win_get_cursor(win)[1]

			-- 找当前行对应的 entry 下标
			local cur_idx
			for i, e in ipairs(entries) do
				if e.lnum == cur_line then
					cur_idx = i
					break
				end
			end

			-- 计算目标下标（循环）
			local total = #entries
			if not cur_idx then
				cur_idx = (delta > 0) and 1 or total
			else
				if delta > 0 then
					cur_idx = (cur_idx % total) + 1
				else
					cur_idx = (cur_idx - 2 + total) % total + 1
				end
			end

			local target_entry = entries[cur_idx]
			local target_line = target_entry.lnum

			-- 先把光标移到行首
			api.nvim_win_set_cursor(win, { target_line, 0 })

			-- 再把光标对齐到 [x]
			local line_text = api.nvim_buf_get_lines(buf, target_line - 1, target_line, false)[1]
			local col = line_text and line_text:find("%[[0-9]%]") or 0
			api.nvim_win_set_cursor(win, { target_line, col })
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

		local function get_filtered_oldfiles(max_entries)
			local seen = {}
			local result = {}
			for _, fname in ipairs(vim.v.oldfiles or {}) do
				if #result >= max_entries then
					break
				end
				if not seen[fname] and is_local_path(fname) and fn.filereadable(fname) == 1 then
					seen[fname] = true
					table.insert(result, fname)
				end
			end
			return result
		end

		local ns = api.nvim_create_namespace("StartupDashboard")

		setup_hl()
		local augroup = api.nvim_create_augroup("StartupDashboardHighlight", {})
		api.nvim_create_autocmd("ColorScheme", {
			group = augroup,
			callback = setup_hl,
		})

		-----------------------------------------------------
		-- 小工具：按 git root 分组
		-----------------------------------------------------
		local function group_files_by_root(files)
			local grouped = {}
			local roots_order = {}

			for _, fname in ipairs(files) do
				local root = find_git_root(fname)
				local key = root or NO_GIT_KEY
				if not grouped[key] then
					grouped[key] = {}
					table.insert(roots_order, key)
				end
				table.insert(grouped[key], fname)
			end

			return grouped, roots_order
		end

		-----------------------------------------------------
		-- 主渲染函数（按 git root 分组）
		-----------------------------------------------------
		local function render(max_entries)
			max_entries = max_entries or 10

			local old = get_filtered_oldfiles(max_entries)
			local buf = api.nvim_create_buf(false, true)
			local win = api.nvim_get_current_win()

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

			---------------- 按 git root 分组 ----------------
			local grouped, roots_order = group_files_by_root(old)

			local entries = {}
			local label_index = 1
			local group_header_lnums = {}

			for ri, root_key in ipairs(roots_order) do
				local files = grouped[root_key]

				local title
				if root_key == NO_GIT_KEY then
					title = "    Other files"
				else
					title = "    " .. fn.fnamemodify(root_key, ":~:.")
				end

				local group_lnum = #lines + 1
				table.insert(lines, title)
				table.insert(group_header_lnums, group_lnum)

				for _, fname in ipairs(files) do
					if label_index > 10 then
						break
					end

					local label = (label_index == 10) and "0" or tostring(label_index)
					local prefix = "  [" .. label .. "]  "

					local path = fn.fnamemodify(fname, ":~:.")
					local icon, icon_hl = get_icon_cached(fname)
					local icon_part = icon ~= "" and (icon .. " ") or ""
					local full_line = prefix .. icon_part .. path

					table.insert(lines, full_line)

					local lnum = #lines
					local path_start = #prefix + #icon_part
					local ps, pe, fe = split_ranges(full_line, path_start)

					entries[#entries + 1] = {
						lnum = lnum,
						full = full_line,
						ps = ps,
						pe = pe,
						fe = fe,
						icon = icon,
						icon_col = #prefix,
						icon_hl = icon_hl,
						raw = fname,
					}

					label_index = label_index + 1
				end

				if ri < #roots_order then
					table.insert(lines, "")
				end
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
			api.nvim_buf_set_name(buf, "startup-dashboard")

			-- 把 entries 存到 buffer 变量上，方便其他函数拿
			api.nvim_buf_set_var(buf, "startup_entries", entries)

			-----------------------------------------------------
			-- 设置 Dashboard 专用的 buffer 选项
			-----------------------------------------------------
			api.nvim_set_option_value("buftype", "nofile", { buf = buf })
			api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
			api.nvim_set_option_value("swapfile", false, { buf = buf })
			api.nvim_set_option_value("modifiable", false, { buf = buf })
			api.nvim_set_option_value("filetype", "startup-dashboard", { buf = buf })

			---------------- 高亮 ----------------

			-- Header 整行
			for i = 0, header_count - 1 do
				api.nvim_buf_add_highlight(buf, -1, "OldfilesHeader", i, 0, -1)
			end

			-- Section / Hint 整行
			api.nvim_buf_add_highlight(buf, -1, "OldfilesSection", section_lnum - 1, 0, -1)
			api.nvim_buf_add_highlight(buf, -1, "OldfilesHint", hint_lnum - 1, 0, -1)

			for _, lnum in ipairs(group_header_lnums) do
				api.nvim_buf_add_highlight(buf, -1, "OldfilesSection", lnum - 1, 0, -1)
			end

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
			for _, key in ipairs({ "<Esc>", "q" }) do
				vim.keymap.set("n", key, "<cmd>bd!<cr>", { buffer = buf, silent = true })
			end

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
					render()
				end
			end,
		})
	end,
}
