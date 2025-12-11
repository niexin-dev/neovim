-- 自定义简单 dashboard，用「最近项目（按 git 仓库分组）」作为启动页
-- 功能概要：
--   - 最多显示 10 个 git 仓库（项目）
--   - 每个仓库最多显示 5 个最近文件
--   - 数字 1-9/0 跳转到对应仓库，不自动打开文件
--   - j / k 在所有文件行里循环移动（跨仓库）
--   - <CR> 在当前行打开对应文件（会自动 cd 到 git root）
--   - Esc / q 关闭 dashboard
return {
	name = "dashboard",
	dir = vim.fn.stdpath("config"),
	lazy = false,
	priority = 1000,

	config = function()
		-- 常用 API 缩写
		local api = vim.api
		local fn = vim.fn
		local uv = vim.loop

		-----------------------------------------------------
		-- 用户配置项
		-----------------------------------------------------
		local USE_ICONS = true -- 是否启用文件类型图标（依赖 nvim-web-devicons）
		local MAX_ROOTS = 10 -- 最多显示多少个 git 仓库
		local PER_ROOT_FILES = 5 -- 每个仓库展示的最大文件数

		-----------------------------------------------------
		-- 颜色 & 高亮定义
		-----------------------------------------------------
		-- 用于缓存「没有 git 仓库」的标记，避免频繁向上爬目录
		local NO_GIT_ROOT = false

		-- 只有启用图标才去 require devicons，避免无意义的 require 开销
		local has_devicons, devicons = false, nil
		if USE_ICONS then
			has_devicons, devicons = pcall(require, "nvim-web-devicons")
		end

		-- 优先尝试从 tokyonight 里取一套颜色，失败则用兜底颜色
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

		-- 顶部 ASCII 标题
		local HEADER = {
			[[    _   _   _                 _           _           _   _                          _                ]],
			[[   | \ | | (_)   ___  __  __ (_)  _ __   ( )  ___    | \ | |   ___    ___   __   __ (_)  _ __ ___     ]],
			[[   |  \| | | |  / _ \ \ \/ / | | | '_ \  |/  / __|   |  \| |  / _ \  / _ \  \ \ / / | | | '_ ` _ \    ]],
			[[   | |\  | | | |  __/  >  <  | | | | | |     \__ \   | |\  | |  __/ | (_) |  \ V /  | | | | | | | |   ]],
			[[   |_| \_| |_|  \___| /_/\_\ |_| |_| |_|     |___/   |_| \_|  \___|  \___/    \_/   |_| |_| |_| |_|   ]],
		}

		-----------------------------------------------------
		-- 高亮组：统一定义 + ColorScheme 时自动重建
		-----------------------------------------------------
		local function setup_hl()
			local hl = {
				OldfilesHeader = { fg = colors.magenta, bold = true }, -- 顶部大标题
				OldfilesSection = { fg = colors.blue, bold = true }, -- 小节标题（Recent projects / 仓库名）
				OldfilesIndex = { fg = colors.orange, bold = true }, -- [1] [2] 这样的索引
				OldfilesPath = { fg = colors.comment, italic = true }, -- 路径部分
				OldfilesFilename = { fg = colors.cyan, bold = true }, -- 文件名部分
				OldfilesHint = { fg = colors.comment, italic = true }, -- 底部操作提示
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
		-- 图标缓存：避免反复调用 devicons.get_icon
		-----------------------------------------------------
		local icon_cache = {}

		--- 获取文件图标（带缓存）
		---@param fname string 文件路径
		---@return string icon, string|nil hl_group
		local function get_icon_cached(fname)
			-- 全局关闭图标，直接返回空
			if not USE_ICONS then
				return "", nil
			end

			-- devicons 不存在 / require 失败 / 没有 get_icon 方法
			if not has_devicons or type(devicons) ~= "table" or type(devicons.get_icon) ~= "function" then
				return "", nil
			end

			-- 已缓存
			if icon_cache[fname] then
				return icon_cache[fname].icon, icon_cache[fname].hl
			end

			local ext = fn.fnamemodify(fname, ":e")
			local icon, hl = devicons.get_icon(fname, ext, { default = true })

			icon = icon or ""
			hl = hl or nil

			icon_cache[fname] = { icon = icon, hl = hl }

			return icon, hl
		end

		-----------------------------------------------------
		-- 工具函数：判断是否本地路径（排除诸如 scheme:// 的 URI）
		-----------------------------------------------------
		local function is_local_path(path)
			return not path:match("^%w[%w+.-]*://")
		end

		-----------------------------------------------------
		-- 查找 git 仓库根目录（带负缓存）
		-- 从给定 path 一路向上找 .git 目录 / 文件
		-----------------------------------------------------
		local git_root_cache = {}

		--- 查找 path 所在 git 仓库根目录
		---@param path string 文件或目录路径
		---@return string|nil git_root
		local function find_git_root(path)
			if not is_local_path(path) then
				return nil
			end

			local abspath = fn.fnamemodify(path, ":p")
			if abspath == "" then
				return nil
			end

			-- 如果是文件，则取所在目录
			local dir = fn.isdirectory(abspath) == 1 and abspath or fn.fnamemodify(abspath, ":h")
			if dir == "" then
				return nil
			end

			local visited = {} -- 记录向上爬时经过的目录，用于批量写缓存
			local root = nil
			local cur = dir

			while cur and cur ~= "" do
				-- 如果当前目录已经有缓存，直接使用
				local cached = git_root_cache[cur]
				if cached ~= nil then
					root = cached ~= NO_GIT_ROOT and cached or nil
					break
				end

				table.insert(visited, cur)

				-- cur/.git 存在即可视为 git 仓库
				if uv.fs_stat(cur .. "/.git") then
					root = cur
					break
				end

				local parent = fn.fnamemodify(cur, ":h")
				if parent == cur then
					-- 已经到根目录
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
		-- 打开文件：自动 cd 到 git root，然后 :edit 该文件
		-----------------------------------------------------
		local function open_oldfile(path)
			if not path or path == "" or not is_local_path(path) then
				return
			end

			local abspath = fn.fnamemodify(path, ":p")
			local dir = fn.fnamemodify(abspath, ":h")

			-- 父目录不存在时，直接尝试 edit 绝对路径
			if dir == "" or fn.isdirectory(dir) == 0 then
				vim.cmd.edit(fn.fnameescape(abspath))
				return
			end

			local root = find_git_root(path)
			local target_dir = root or dir

			-- 先 cd 到仓库根目录，再打开文件
			vim.cmd("cd " .. fn.fnameescape(target_dir))
			vim.cmd.edit(fn.fnameescape(abspath))
		end

		-----------------------------------------------------
		-- 将一行中的路径，拆分出「路径部分 + 文件名部分」的高亮范围
		-- full_line: 整行文本
		-- path_start: 路径（含 /）在行内的起始列
		-- 返回：path_start, filename_start, filename_end
		-----------------------------------------------------
		local function split_ranges(full_line, path_start)
			-- 匹配最后一个 / 或 \ 后面的部分作为文件名
			local m = fn.matchstrpos(full_line, [[\v[^/\\]+$]])
			local fname_s, fname_e = m[2], m[3]
			if fname_s < 0 then
				return path_start, nil, nil
			end
			return path_start, fname_s, fname_e
		end

		-----------------------------------------------------
		-- 从 vim.v.oldfiles 中筛掉：
		--   - 非本地路径
		--   - 文件已不存在 / 不可读
		-----------------------------------------------------
		local function get_valid_oldfiles()
			local result = {}
			for _, fname in ipairs(vim.v.oldfiles or {}) do
				if is_local_path(fname) and fn.filereadable(fname) == 1 then
					table.insert(result, fname)
				end
			end
			return result
		end

		-----------------------------------------------------
		-- 按 git root 分组：
		--   - 最多 max_roots 个仓库
		--   - 每个仓库最多 per_root_limit 个文件
		--   - 当前 cwd 所在仓库优先排第一个
		--
		-- 返回：
		--   grouped: { [root_key] = { file1, file2, ... } }
		--   order  : { root_key1, root_key2, ... }（分组展示顺序）
		-----------------------------------------------------
		local function group_files_by_root(files, max_roots, per_root_limit)
			max_roots = max_roots or MAX_ROOTS
			per_root_limit = per_root_limit or PER_ROOT_FILES

			local grouped = {}
			local order = {}
			local per_root_count = {} -- 每个 root 已加入多少文件

			for _, fname in ipairs(files) do
				local root = find_git_root(fname)
				local key = root or "OTHER" -- OTHER 代表没有 git 仓库

				-- 尚未出现过的仓库，需要检查是否已达上限
				if not grouped[key] then
					if #order >= max_roots then
						-- 仓库数量到达上限，直接跳过该文件
						goto continue
					end
					grouped[key] = {}
					per_root_count[key] = 0
					table.insert(order, key)
				end

				-- 仓库内文件数未到上限才加入
				if per_root_count[key] < per_root_limit then
					table.insert(grouped[key], fname)
					per_root_count[key] = per_root_count[key] + 1
				end

				::continue::
			end

			-- 将「当前工作目录所在仓库」移动到 order 第一个
			local cwd = fn.getcwd()
			local cwd_root = find_git_root(cwd)

			if cwd_root then
				local cwd_root_abs = fn.fnamemodify(cwd_root, ":p")
				local matched_key = nil

				for _, key in ipairs(order) do
					if key ~= "OTHER" and fn.fnamemodify(key, ":p") == cwd_root_abs then
						matched_key = key
						break
					end
				end

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
		-- j / k：在「所有仓库的所有文件」中循环移动
		--   - entries 是一个扁平数组：{ {lnum=行号, ps=起始列, raw=路径}, ... }
		--   - delta = +1：向下；delta = -1：向上
		--   - 不在文件行上时，自动跳到第一个 / 最后一个文件
		-----------------------------------------------------
		local function move_delta(delta)
			local win = api.nvim_get_current_win()
			local buf = api.nvim_win_get_buf(win)

			local ok, entries = pcall(api.nvim_buf_get_var, buf, "startup_entries")
			if not ok or not entries or #entries == 0 then
				return
			end

			local cur_line = api.nvim_win_get_cursor(win)[1]

			-- 查找当前光标所在文件索引
			local cur_idx
			for i, e in ipairs(entries) do
				if e.lnum == cur_line then
					cur_idx = i
					break
				end
			end

			local total = #entries
			if total == 0 then
				return
			end

			-- 当前不在任何文件行：根据方向跳到第一个 / 最后一个文件
			if not cur_idx then
				cur_idx = (delta > 0) and 1 or total
			else
				if delta > 0 then
					cur_idx = (cur_idx % total) + 1
				else
					cur_idx = (cur_idx - 2 + total) % total + 1
				end
			end

			local e = entries[cur_idx]
			local col = e.ps or 0
			api.nvim_win_set_cursor(win, { e.lnum, col })
		end

		-----------------------------------------------------
		-- 主渲染函数：
		--   - 创建临时 buffer / window
		--   - 渲染标题、项目列表、提示
		--   - 建立高亮 & keymap
		-----------------------------------------------------
		local function render()
			-- 创建无名 scratch buffer
			local buf = api.nvim_create_buf(false, true)
			local win = api.nvim_get_current_win()
			local lines = {}

			-- 顶部 HEADER
			for _, l in ipairs(HEADER) do
				table.insert(lines, l)
			end
			table.insert(lines, "")
			local header_count = #HEADER

			-- SECTION 标题（Recent projects）
			local section_lnum = #lines + 1
			table.insert(lines, "    Recent projects (by git root)")
			table.insert(lines, "  " .. string.rep("─", math.min(vim.o.columns - 4, 50)))
			table.insert(lines, "")

			-- 取 oldfiles 并按 git root 分组
			local valid_files = get_valid_oldfiles()
			local grouped, order = group_files_by_root(valid_files, MAX_ROOTS, PER_ROOT_FILES)

			local groups = {} -- 保存每个仓库的元数据（header 行号、文件列表等）
			local ns = api.nvim_create_namespace("StartupDashboard")
			local group_header_lnums = {}

			local group_index = 0 -- 仓库编号（1~10，对应数字键）

			for _, root_key in ipairs(order) do
				local files = grouped[root_key]
				if files and #files > 0 then
					group_index = group_index + 1
					local label = (group_index == 10) and "0" or tostring(group_index)

					local root_name = (root_key == "OTHER") and "Other files" or fn.fnamemodify(root_key, ":~:.")

					-- 仓库标题行，形如：
					--   [1]    ~/proj/foo
					local title = string.format("  [%s]    %s", label, root_name)
					if root_key == "OTHER" then
						title = string.format("  [%s]    %s", label, root_name)
					end

					local group_lnum = #lines + 1
					table.insert(lines, title)
					table.insert(group_header_lnums, group_lnum)

					local group = {
						key = root_key, -- git root 路径或 "OTHER"
						index = group_index, -- 仓库编号，用于数字键跳转
						header_lnum = group_lnum,
						files = {}, -- 该仓库下的文件 entry 列表
					}

					-- 仓库内文件行
					for _, fname in ipairs(files) do
						local path = fn.fnamemodify(fname, ":~:.")
						local icon, icon_hl = get_icon_cached(fname)
						local prefix = "      " -- 文件行缩进（与 header 区分）
						local icon_part = (USE_ICONS and icon ~= "") and (icon .. " ") or ""
						local full_line = prefix .. icon_part .. path

						table.insert(lines, full_line)

						local lnum = #lines
						local path_start = #prefix + #icon_part
						local ps, pe, fe = split_ranges(full_line, path_start)

						local entry = {
							lnum = lnum, -- 当前文件行号
							full = full_line,
							ps = ps, -- 路径起始列（用于光标定位 / 高亮）
							pe = pe, -- 文件名起始列
							fe = fe, -- 文件名结束列
							icon = icon,
							icon_col = #prefix, -- 图标起始列
							icon_hl = icon_hl,
							raw = fname, -- 原始文件路径
						}
						table.insert(group.files, entry)
					end

					-- 仓库之间加一个空行作为分隔
					table.insert(lines, "")

					table.insert(groups, group)
				end
			end

			-- 没有任何仓库 / 文件时的提示
			if #groups == 0 then
				table.insert(lines, "  (no recent git projects)")
			end

			-- 底部操作提示
			table.insert(lines, "")
			local hint_lnum = #lines + 1
			table.insert(lines, "    [0-9] Jump repo · j/k Move · <CR> Open file · <Esc>/q Close")

			-- 写入 buffer & 基本 buffer 配置
			api.nvim_buf_set_lines(buf, 0, -1, false, lines)
			api.nvim_win_set_buf(win, buf)
			api.nvim_buf_set_name(buf, "dashboard")
			api.nvim_buf_set_var(buf, "startup_groups", groups)

			api.nvim_set_option_value("buftype", "nofile", { buf = buf })
			api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
			api.nvim_set_option_value("swapfile", false, { buf = buf })
			api.nvim_set_option_value("modifiable", false, { buf = buf })
			api.nvim_set_option_value("filetype", "dashboard", { buf = buf })

			-------------------------------------------------
			-- 高亮：标题 / 小节 / 仓库 header / 文件路径
			-------------------------------------------------
			for i = 0, header_count - 1 do
				api.nvim_buf_add_highlight(buf, -1, "OldfilesHeader", i, 0, -1)
			end
			api.nvim_buf_add_highlight(buf, -1, "OldfilesSection", section_lnum - 1, 0, -1)
			api.nvim_buf_add_highlight(buf, -1, "OldfilesHint", hint_lnum - 1, 0, -1)

			for _, lnum in ipairs(group_header_lnums) do
				-- 整个仓库标题行
				api.nvim_buf_add_highlight(buf, -1, "OldfilesSection", lnum - 1, 0, -1)
				-- 标题中的 [n] 索引
				api.nvim_buf_add_highlight(buf, -1, "OldfilesIndex", lnum - 1, 2, 5)
			end

			-- 文件行高亮 + 图标 virt_text
			for _, g in ipairs(groups) do
				for _, e in ipairs(g.files) do
					local l0 = e.lnum - 1

					if not e.pe then
						-- 没找到文件名边界时，全部视为路径
						api.nvim_buf_add_highlight(buf, -1, "OldfilesPath", l0, e.ps, -1)
					else
						-- 路径部分
						api.nvim_buf_add_highlight(buf, -1, "OldfilesPath", l0, e.ps, e.pe)
						-- 文件名部分
						api.nvim_buf_add_highlight(buf, -1, "OldfilesFilename", l0, e.pe, e.fe)
					end

					-- 用 virt_text 覆盖前面打印的文本图标，保持颜色一致
					if USE_ICONS and e.icon ~= "" and e.icon_hl then
						api.nvim_buf_set_extmark(buf, ns, l0, e.icon_col, {
							virt_text = { { e.icon, e.icon_hl } },
							virt_text_pos = "overlay",
							virt_text_hide = true,
						})
					end
				end
			end

			-------------------------------------------------
			-- 将所有文件 entries 扁平化，供 j/k 使用
			-------------------------------------------------
			local entries = {}
			for _, g in ipairs(groups) do
				for _, e in ipairs(g.files) do
					table.insert(entries, e)
				end
			end
			api.nvim_buf_set_var(buf, "startup_entries", entries)

			-------------------------------------------------
			-- 初始光标位置：第一个仓库的第一个文件
			-------------------------------------------------
			for _, g in ipairs(groups) do
				if #g.files > 0 then
					local e = g.files[1]
					local col = e.ps or 0
					api.nvim_win_set_cursor(win, { e.lnum, col })
					break
				end
			end

			-------------------------------------------------
			-- 数字键 1-9,0：跳转到对应仓库（不打开文件）
			--   - 若仓库有文件：跳到该仓库第一个文件
			--   - 若仓库无文件：跳到仓库标题行
			-------------------------------------------------
			for _, g in ipairs(groups) do
				local idx = g.index
				local key = (idx == 10) and "0" or tostring(idx)
				if #g.files > 0 then
					local first = g.files[1]
					vim.keymap.set("n", key, function()
						local col = first.ps or 0
						api.nvim_win_set_cursor(0, { first.lnum, col })
					end, { buffer = buf, silent = true })
				else
					vim.keymap.set("n", key, function()
						api.nvim_win_set_cursor(0, { g.header_lnum, 0 })
					end, { buffer = buf, silent = true })
				end
			end

			-------------------------------------------------
			-- <CR>：在当前文件行上打开文件
			--   - 若光标在 header/空行上，则不做任何事
			-------------------------------------------------
			vim.keymap.set("n", "<CR>", function()
				local cur_line = api.nvim_win_get_cursor(0)[1]
				local ok_g, cur_groups = pcall(api.nvim_buf_get_var, 0, "startup_groups")
				if not ok_g or not cur_groups then
					return
				end

				for _, g in ipairs(cur_groups) do
					for _, e in ipairs(g.files) do
						if e.lnum == cur_line then
							open_oldfile(e.raw)
							return
						end
					end
				end
			end, { buffer = buf, silent = true })

			-------------------------------------------------
			-- j / k：在所有文件行中循环移动（跨仓库）
			-------------------------------------------------
			vim.keymap.set("n", "j", function()
				move_delta(1)
			end, { buffer = buf, silent = true })

			vim.keymap.set("n", "k", function()
				move_delta(-1)
			end, { buffer = buf, silent = true })

			-------------------------------------------------
			-- 关闭 dashboard：<Esc> 或 q
			-------------------------------------------------
			for _, key in ipairs({ "<Esc>", "q" }) do
				vim.keymap.set("n", key, "<cmd>bd!<cr>", { buffer = buf, silent = true })
			end

			-------------------------------------------------
			-- 透传 i / a / o / s / c / r 等按键：
			--   - 关闭 dashboard
			--   - 在原窗口中重新发送相同按键（带 count）
			--   - 用于保持 muscle memory（如进插入模式）
			-------------------------------------------------
			local function map_pass(key)
				vim.keymap.set("n", key, function()
					local seq = ((vim.v.count > 0) and tostring(vim.v.count) or "") .. key
					vim.cmd("bd!") -- 先关掉 dashboard buffer
					local term = api.nvim_replace_termcodes(seq, true, false, true)
					api.nvim_feedkeys(term, "n", false)
				end, { buffer = buf, silent = true })
			end

			for _, key in ipairs({ "i", "I", "a", "A", "o", "O", "s", "S", "c", "C", "r", "R" }) do
				map_pass(key)
			end
		end

		-----------------------------------------------------
		-- 自动在 VimEnter 时显示 dashboard：
		--   - 仅在「不带参数启动」且「当前 buffer 为空」时生效
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
