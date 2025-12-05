return {
	name = "dashboard",
	dir = vim.fn.stdpath("config"),
	lazy = false,
	priority = 1000,

	config = function()
		local api = vim.api
		local fn = vim.fn
		local uv = vim.loop

		-----------------------------------------------------
		-- 用户选项
		-----------------------------------------------------
		-- 是否启用文件类型图标（依赖 nvim-web-devicons）
		-- true  = 显示图标（视觉效果好，略慢一点）
		-- false = 不显示图标（更快，纯文本）
		local USE_ICONS = true

		-----------------------------------------------------
		-- 常量 / 高亮颜色
		-----------------------------------------------------
		local NO_GIT_ROOT = false

		-- 只有在启用图标时才加载 devicons，避免不必要的开销
		local has_devicons, devicons = false, nil
		if USE_ICONS then
			has_devicons, devicons = pcall(require, "nvim-web-devicons")
		end

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

		local HEADER = {
			[[    _   _   _                 _           _           _   _                          _                ]],
			[[   | \ | | (_)   ___  __  __ (_)  _ __   ( )  ___    | \ | |   ___    ___   __   __ (_)  _ __ ___     ]],
			[[   |  \| | | |  / _ \ \ \/ / | | | '_ \  |/  / __|   |  \| |  / _ \  / _ \  \ \ / / | | | '_ ` _ \    ]],
			[[   | |\  | | | |  __/  >  <  | | | | | |     \__ \   | |\  | |  __/ | (_) |  \ V /  | | | | | | | |   ]],
			[[   |_| \_| |_|  \___| /_/\_\ |_| |_| |_|     |___/   |_| \_|  \___|  \___/    \_/   |_| |_| |_| |_|   ]],
		}

		-----------------------------------------------------
		-- 高亮
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

		setup_hl()
		api.nvim_create_autocmd("ColorScheme", {
			callback = setup_hl,
		})

		-----------------------------------------------------
		-- 图标缓存（可开关）
		-----------------------------------------------------
		local icon_cache = {}

		local function get_icon_cached(fname)
			-- 图标关闭：直接返回空
			if not USE_ICONS then
				return "", nil
			end

			-- devicons 是否存在、是否是 table、是否提供 get_icon 方法
			if not has_devicons or type(devicons) ~= "table" or type(devicons.get_icon) ~= "function" then
				return "", nil
			end

			-- 缓存已经存在
			if icon_cache[fname] then
				return icon_cache[fname].icon, icon_cache[fname].hl
			end

			-- 计算扩展名
			local ext = fn.fnamemodify(fname, ":e")

			-- 调用 devicons（可能返回 nil）
			local icon, hl = devicons.get_icon(fname, ext, { default = true })

			-- 防止 nil 引发报错
			icon = icon or ""
			hl = hl or nil -- hl 可以是 nil，不影响后续

			-- 写入缓存
			icon_cache[fname] = { icon = icon, hl = hl }

			return icon, hl
		end

		-----------------------------------------------------
		-- 判断是否本地路径
		-----------------------------------------------------
		local function is_local_path(path)
			return not path:match("^%w[%w+.-]*://")
		end

		-----------------------------------------------------
		-- git root 查找（负缓存 + 避免重复爬）
		-----------------------------------------------------
		local git_root_cache = {}

		local function find_git_root(path)
			if not is_local_path(path) then
				return nil
			end

			local abspath = fn.fnamemodify(path, ":p")
			if abspath == "" then
				return nil
			end

			local dir = fn.isdirectory(abspath) == 1 and abspath or fn.fnamemodify(abspath, ":h")
			if dir == "" then
				return nil
			end

			local visited = {}
			local root = nil
			local cur = dir

			while cur and cur ~= "" do
				local cached = git_root_cache[cur]
				if cached ~= nil then
					root = cached ~= NO_GIT_ROOT and cached or nil
					break
				end

				table.insert(visited, cur)

				-- 目录或文件形式的 .git 都算
				if uv.fs_stat(cur .. "/.git") then
					root = cur
					break
				end

				local parent = fn.fnamemodify(cur, ":h")
				if parent == cur then
					break
				end
				cur = parent
			end

			local cache_value = root or NO_GIT_ROOT
			for _, d in ipairs(visited) do
				git_root_cache[d] = cache_value
			end

			return root
		end

		-----------------------------------------------------
		-- 打开文件（自动 cd 到 git root）
		-----------------------------------------------------
		local function open_oldfile(path)
			if not path or path == "" or not is_local_path(path) then
				return
			end

			local abspath = fn.fnamemodify(path, ":p")
			local dir = fn.fnamemodify(abspath, ":h")

			if dir == "" or fn.isdirectory(dir) == 0 then
				vim.cmd.edit(fn.fnameescape(abspath))
				return
			end

			local root = find_git_root(path)
			local target_dir = root or dir

			vim.cmd("cd " .. fn.fnameescape(target_dir))
			vim.cmd.edit(fn.fnameescape(abspath))
		end

		-----------------------------------------------------
		-- 分拆路径和文件名范围
		-----------------------------------------------------
		local function split_ranges(full_line, path_start)
			local m = fn.matchstrpos(full_line, [[\v[^/\\]+$]])
			local fname_s, fname_e = m[2], m[3]
			if fname_s < 0 then
				return path_start, nil, nil
			end
			return path_start, fname_s, fname_e
		end

		-----------------------------------------------------
		-- j / k 在 entries 中循环移动
		-----------------------------------------------------
		local function move_delta(delta)
			local win = api.nvim_get_current_win()
			local buf = api.nvim_win_get_buf(win)

			local ok, entries = pcall(api.nvim_buf_get_var, buf, "startup_entries")
			if not ok or not entries or #entries == 0 then
				return
			end

			local cur_line = api.nvim_win_get_cursor(win)[1]

			local cur_idx
			for i, e in ipairs(entries) do
				if e.lnum == cur_line then
					cur_idx = i
					break
				end
			end

			local total = #entries
			if not cur_idx then
				cur_idx = delta > 0 and 1 or total
			else
				cur_idx = delta > 0 and (cur_idx % total) + 1 or (cur_idx - 2 + total) % total + 1
			end

			local target_line = entries[cur_idx].lnum
			local line_text = api.nvim_buf_get_lines(buf, target_line - 1, target_line, false)[1]
			local col = line_text and line_text:find("%[[0-9]%]") or 0
			api.nvim_win_set_cursor(win, { target_line, col })
		end

		-----------------------------------------------------
		-- oldfiles 过滤：总共 max_entries，每个 git root 最多 per_root_limit 个
		-----------------------------------------------------
		local function get_filtered_oldfiles(max_entries, per_root_limit)
			max_entries = max_entries or 10
			per_root_limit = per_root_limit or 2

			local seen = {} -- 去重：绝对路径
			local per_root_count = {} -- 每个 git root 已选数量
			local result = {}

			for _, fname in ipairs(vim.v.oldfiles or {}) do
				if #result >= max_entries then
					break
				end

				if is_local_path(fname) and fn.filereadable(fname) == 1 then
					-- 规范化路径，避免同一文件不同写法（相对/绝对/~）重复
					local abspath = fn.fnamemodify(fname, ":p")
					if not seen[abspath] then
						local root = find_git_root(abspath)
						local key = root or "OTHER"

						local cnt = per_root_count[key] or 0
						if cnt < per_root_limit then
							per_root_count[key] = cnt + 1
							seen[abspath] = true
							table.insert(result, fname) -- 保留原始路径，后面还会再做 :~:. 处理
						end
					end
				end
			end

			return result
		end

		-----------------------------------------------------
		-- 按 git root 分组：当前所在仓库的分组排在最前面
		-----------------------------------------------------
		local function group_files_by_root(files)
			local grouped = {}
			local order = {}

			for _, fname in ipairs(files) do
				local root = find_git_root(fname)
				local key = root or "OTHER"
				if not grouped[key] then
					grouped[key] = {}
					table.insert(order, key)
				end
				table.insert(grouped[key], fname)
			end

			-- 当前工作目录所在的 git 仓库 root
			local cwd = fn.getcwd()
			local cwd_root = find_git_root(cwd)

			if cwd_root then
				-- 规范化成绝对路径，避免 ~、结尾 / 等差异
				local cwd_root_abs = fn.fnamemodify(cwd_root, ":p")
				local matched_key = nil

				for _, key in ipairs(order) do
					if fn.fnamemodify(key, ":p") == cwd_root_abs then
						matched_key = key
						break
					end
				end

				-- 找到了对应分组，就把它挪到最前面
				if matched_key then
					local new_order = { matched_key }
					for _, key in ipairs(order) do
						if key ~= matched_key then
							table.insert(new_order, key)
						end
					end
					order = new_order
				end
			end

			return grouped, order
		end

		-----------------------------------------------------
		-- 主渲染函数
		-----------------------------------------------------
		local function render(max_entries)
			max_entries = max_entries or 10

			local old = get_filtered_oldfiles(max_entries, 2)
			local buf = api.nvim_create_buf(false, true)
			local win = api.nvim_get_current_win()
			local lines = {}

			-- HEADER
			for _, l in ipairs(HEADER) do
				table.insert(lines, l)
			end
			table.insert(lines, "")
			local header_count = #HEADER

			-- SECTION
			local section_lnum = #lines + 1
			table.insert(lines, "    Recent files")
			table.insert(lines, "  " .. string.rep("─", math.min(vim.o.columns - 4, 50)))
			table.insert(lines, "")

			-- GROUPED
			local grouped, order = group_files_by_root(old)
			local entries = {}
			local label_index = 1
			local group_header_lnums = {}

			for ri, root_key in ipairs(order) do
				local files = grouped[root_key]

				local title = (root_key == "OTHER") and "    Other files"
					or ("    " .. fn.fnamemodify(root_key, ":~:."))

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
					local icon_part = (USE_ICONS and icon ~= "") and (icon .. " ") or ""
					local full_line = prefix .. icon_part .. path

					table.insert(lines, full_line)

					local lnum = #lines
					local path_start = #prefix + #icon_part
					local ps, pe, fe = split_ranges(full_line, path_start)

					table.insert(entries, {
						lnum = lnum,
						full = full_line,
						ps = ps,
						pe = pe,
						fe = fe,
						icon = icon,
						icon_col = #prefix,
						icon_hl = icon_hl,
						raw = fname,
					})

					label_index = label_index + 1
				end

				if ri < #order then
					table.insert(lines, "")
				end
			end

			if #entries == 0 then
				table.insert(lines, "  (no recent files)")
			end

			table.insert(lines, "")
			local hint_lnum = #lines + 1
			table.insert(lines, "    [1-9,0] Open file · j/k Move · <CR> Current · <Esc> Close")

			-- 写入 buffer
			api.nvim_buf_set_lines(buf, 0, -1, false, lines)
			api.nvim_win_set_buf(win, buf)
			api.nvim_buf_set_name(buf, "dashboard")
			api.nvim_buf_set_var(buf, "startup_entries", entries)

			api.nvim_set_option_value("buftype", "nofile", { buf = buf })
			api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
			api.nvim_set_option_value("swapfile", false, { buf = buf })
			api.nvim_set_option_value("modifiable", false, { buf = buf })
			api.nvim_set_option_value("filetype", "dashboard", { buf = buf })

			-- 高亮
			for i = 0, header_count - 1 do
				api.nvim_buf_add_highlight(buf, -1, "OldfilesHeader", i, 0, -1)
			end
			api.nvim_buf_add_highlight(buf, -1, "OldfilesSection", section_lnum - 1, 0, -1)
			api.nvim_buf_add_highlight(buf, -1, "OldfilesHint", hint_lnum - 1, 0, -1)

			local ns = api.nvim_create_namespace("StartupDashboard")
			for _, lnum in ipairs(group_header_lnums) do
				api.nvim_buf_add_highlight(buf, -1, "OldfilesSection", lnum - 1, 0, -1)
			end

			for _, e in ipairs(entries) do
				local l0 = e.lnum - 1

				api.nvim_buf_add_highlight(buf, -1, "OldfilesIndex", l0, 2, 5)

				if not e.pe then
					api.nvim_buf_add_highlight(buf, -1, "OldfilesPath", l0, e.ps, -1)
				else
					api.nvim_buf_add_highlight(buf, -1, "OldfilesPath", l0, e.ps, e.pe)
					api.nvim_buf_add_highlight(buf, -1, "OldfilesFilename", l0, e.pe, e.fe)
				end

				-- 图标 overlay 也受 USE_ICONS 控制
				if USE_ICONS and e.icon ~= "" and e.icon_hl then
					api.nvim_buf_set_extmark(buf, ns, l0, e.icon_col, {
						virt_text = { { e.icon, e.icon_hl } },
						virt_text_pos = "overlay",
						virt_text_hide = true,
					})
				end
			end

			-- 初始光标
			if entries[1] then
				local l = entries[1].lnum
				local col = (lines[l] or ""):find("%[[0-9]%]") or 0
				api.nvim_win_set_cursor(win, { l, col })
			end

			-- 数字打开
			for i, e in ipairs(entries) do
				local key = (i == 10) and "0" or tostring(i)
				vim.keymap.set("n", key, function()
					open_oldfile(e.raw)
				end, { buffer = buf, silent = true })
			end

			-- 回车打开
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

			-- j / k
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

			-- 透传 i,a,o,s 等
			local function map_pass(key)
				vim.keymap.set("n", key, function()
					local seq = ((vim.v.count > 0) and tostring(vim.v.count) or "") .. key
					vim.cmd("bd!")
					local term = api.nvim_replace_termcodes(seq, true, false, true)
					api.nvim_feedkeys(term, "n", false)
				end, { buffer = buf, silent = true })
			end

			for _, key in ipairs({ "i", "I", "a", "A", "o", "O", "s", "S", "c", "C", "r", "R" }) do
				map_pass(key)
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
