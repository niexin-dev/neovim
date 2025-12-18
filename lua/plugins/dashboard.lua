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
		-- 用户配置项
		-----------------------------------------------------
		local USE_ICONS = true
		local MAX_ROOTS = 10
		local PER_ROOT_FILES = 5
		local MAX_OLDFILES_SCAN = 100

		-- A) 后台预热 git root（用于 shada 很大/仓库很多时）
		local PREHEAT_GIT_ROOT = true
		local PREHEAT_GIT_ROOT_MAX = 200 -- 预热最多多少个文件的 git root
		local PREHEAT_GIT_ROOT_BATCH = 50 -- 分批处理，避免一次性卡顿

		-- C) Debug/Profiling
		local DEBUG = false

		-----------------------------------------------------
		-- Debug/Profiling helpers
		-----------------------------------------------------
		local stats = {
			renders = 0,
			render_ms_total = 0,

			oldfiles_sig_changes = 0,
			oldfiles_top_builds = 0,
			oldfiles_all_builds = 0,
			oldfiles_top_ms_total = 0,
			oldfiles_all_ms_total = 0,

			git_root_calls = 0,
			git_root_file_hit = 0,
			git_root_dir_hit = 0,
			git_root_fs_checks = 0,
			git_root_ms_total = 0,

			preheat_runs = 0,
			preheat_git_root_runs = 0,
		}

		local function now_ms()
			return uv.hrtime() / 1e6
		end

		local function dbg(msg)
			if not DEBUG then
				return
			end
			vim.schedule(function()
				vim.notify(msg, vim.log.levels.INFO, { title = "dashboard" })
			end)
		end

		local function print_stats()
			local avg_render = stats.renders > 0 and (stats.render_ms_total / stats.renders) or 0
			local avg_git = stats.git_root_calls > 0 and (stats.git_root_ms_total / stats.git_root_calls) or 0

			local msg = table.concat({
				("renders=%d, render_total=%.1fms, render_avg=%.2fms"):format(
					stats.renders,
					stats.render_ms_total,
					avg_render
				),
				("oldfiles_sig_changes=%d"):format(stats.oldfiles_sig_changes),
				("oldfiles_top_builds=%d, top_total=%.1fms"):format(
					stats.oldfiles_top_builds,
					stats.oldfiles_top_ms_total
				),
				("oldfiles_all_builds=%d, all_total=%.1fms"):format(
					stats.oldfiles_all_builds,
					stats.oldfiles_all_ms_total
				),
				("git_root_calls=%d, git_total=%.1fms, git_avg=%.3fms"):format(
					stats.git_root_calls,
					stats.git_root_ms_total,
					avg_git
				),
				("git_cache_hit_file=%d, git_cache_hit_dir=%d, git_fs_checks=%d"):format(
					stats.git_root_file_hit,
					stats.git_root_dir_hit,
					stats.git_root_fs_checks
				),
				("preheat_runs=%d, preheat_git_root_runs=%d"):format(stats.preheat_runs, stats.preheat_git_root_runs),
			}, "\n")

			vim.notify(msg, vim.log.levels.INFO, { title = "dashboard stats" })
		end

		-----------------------------------------------------
		-- 状态
		-----------------------------------------------------
		local expanded_root = nil -- nil / "OTHER" / "/abs/git/root"
		local pending_cursor = nil -- { root=..., path=/abs/file or nil }
		local startup_cwd = fn.getcwd()

		-- 单 buffer 复用
		local dashboard_buf = nil
		local ns_dashboard = api.nvim_create_namespace("StartupDashboard")

		-----------------------------------------------------
		-- devicons
		-----------------------------------------------------
		local has_devicons, devicons = false, nil
		if USE_ICONS then
			has_devicons, devicons = pcall(require, "nvim-web-devicons")
		end

		-----------------------------------------------------
		-- colors & highlight
		-----------------------------------------------------
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
		api.nvim_create_autocmd("ColorScheme", { callback = setup_hl })

		-----------------------------------------------------
		-- 轻量工具函数
		-----------------------------------------------------
		local function is_local_path(path)
			return not path:match("^%w[%w+.-]*://")
		end

		local function is_on_windows_mount(path)
			return path:match("^/mnt/[a-zA-Z]/")
		end

		-----------------------------------------------------
		-- icon 缓存
		-----------------------------------------------------
		local icon_cache = {}
		local function get_icon_cached(fname)
			if not USE_ICONS then
				return "", nil
			end
			if not has_devicons or type(devicons) ~= "table" or type(devicons.get_icon) ~= "function" then
				return "", nil
			end

			local c = icon_cache[fname]
			if c then
				return c.icon, c.hl
			end

			local ext = fn.fnamemodify(fname, ":e")
			local icon, hl = devicons.get_icon(fname, ext, { default = true })
			icon = icon or ""
			hl = hl or nil
			icon_cache[fname] = { icon = icon, hl = hl }
			return icon, hl
		end

		-----------------------------------------------------
		-- git root：目录缓存 + 文件缓存
		-----------------------------------------------------
		local NO_GIT_ROOT = false
		local git_root_cache = {} -- dir -> root|NO_GIT_ROOT
		local file_root_cache = {} -- file(abs) -> root|false

		local function find_git_root(path)
			stats.git_root_calls = stats.git_root_calls + 1
			local t0 = now_ms()

			if not path or path == "" then
				stats.git_root_ms_total = stats.git_root_ms_total + (now_ms() - t0)
				return nil
			end
			if not is_local_path(path) or is_on_windows_mount(path) then
				stats.git_root_ms_total = stats.git_root_ms_total + (now_ms() - t0)
				return nil
			end

			local abspath = fn.fnamemodify(path, ":p")
			if abspath == "" then
				stats.git_root_ms_total = stats.git_root_ms_total + (now_ms() - t0)
				return nil
			end

			local cached_file = file_root_cache[abspath]
			if cached_file ~= nil then
				stats.git_root_file_hit = stats.git_root_file_hit + 1
				stats.git_root_ms_total = stats.git_root_ms_total + (now_ms() - t0)
				return cached_file or nil
			end

			local dir = (fn.isdirectory(abspath) == 1) and abspath or fn.fnamemodify(abspath, ":h")
			if dir == "" then
				file_root_cache[abspath] = false
				stats.git_root_ms_total = stats.git_root_ms_total + (now_ms() - t0)
				return nil
			end

			local visited = {}
			local cur = dir
			local root = nil

			while cur and cur ~= "" do
				local cached_dir = git_root_cache[cur]
				if cached_dir ~= nil then
					stats.git_root_dir_hit = stats.git_root_dir_hit + 1
					root = cached_dir ~= NO_GIT_ROOT and cached_dir or nil
					break
				end

				table.insert(visited, cur)
				stats.git_root_fs_checks = stats.git_root_fs_checks + 1
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

			file_root_cache[abspath] = root or false
			stats.git_root_ms_total = stats.git_root_ms_total + (now_ms() - t0)
			return root
		end

		-----------------------------------------------------
		-- oldfiles 缓存策略 + 后台预热
		-----------------------------------------------------
		local oldfiles_cache_top = nil
		local oldfiles_cache_all = nil
		local oldfiles_sig_cached = nil

		local preheat_scheduled = false

		local function oldfiles_signature(list)
			if type(list) ~= "table" then
				return "nil"
			end
			local n = #list
			if n == 0 then
				return "0"
			end
			local function at(i)
				local v = list[i]
				return v or ""
			end
			local mid = math.floor(n / 2)
			return table.concat({
				tostring(n),
				at(1),
				at(2),
				at(3),
				at(mid),
				at(n - 2),
				at(n - 1),
				at(n),
			}, "\n")
		end

		local function invalidate_oldfiles_cache_if_needed()
			local sig = oldfiles_signature(vim.v.oldfiles or {})
			if sig ~= oldfiles_sig_cached then
				oldfiles_sig_cached = sig
				oldfiles_cache_top = nil
				oldfiles_cache_all = nil
				preheat_scheduled = false
				stats.oldfiles_sig_changes = stats.oldfiles_sig_changes + 1
			end
		end

		local function get_valid_oldfiles_cached(scan_all)
			invalidate_oldfiles_cache_if_needed()

			if scan_all then
				if oldfiles_cache_all ~= nil then
					return oldfiles_cache_all
				end
			else
				if oldfiles_cache_top ~= nil then
					return oldfiles_cache_top
				end
			end

			local t0 = now_ms()
			local result = {}
			local count = 0

			for _, fname in ipairs(vim.v.oldfiles or {}) do
				count = count + 1
				if (not scan_all) and count > MAX_OLDFILES_SCAN then
					break
				end

				if is_local_path(fname) and not is_on_windows_mount(fname) and fn.filereadable(fname) == 1 then
					table.insert(result, fname)
				end
			end

			local dt = now_ms() - t0
			if scan_all then
				oldfiles_cache_all = result
				stats.oldfiles_all_builds = stats.oldfiles_all_builds + 1
				stats.oldfiles_all_ms_total = stats.oldfiles_all_ms_total + dt
			else
				oldfiles_cache_top = result
				stats.oldfiles_top_builds = stats.oldfiles_top_builds + 1
				stats.oldfiles_top_ms_total = stats.oldfiles_top_ms_total + dt
			end

			return result
		end

		-- A) 分批预热 git root（避免一次性卡）
		local function preheat_git_roots_batch(files)
			if not PREHEAT_GIT_ROOT then
				return
			end
			if type(files) ~= "table" or #files == 0 then
				return
			end

			stats.preheat_git_root_runs = stats.preheat_git_root_runs + 1

			local maxn = math.min(#files, PREHEAT_GIT_ROOT_MAX)
			local i = 1

			local function step()
				local end_i = math.min(i + PREHEAT_GIT_ROOT_BATCH - 1, maxn)
				for j = i, end_i do
					find_git_root(files[j])
				end
				i = end_i + 1
				if i <= maxn then
					vim.schedule(step)
				end
			end

			vim.schedule(step)
		end

		-- 后台预热：首次进入 dashboard 后，延迟构建全量缓存 + 可选预填充 git root
		local function schedule_preheat_all_oldfiles()
			invalidate_oldfiles_cache_if_needed()

			if oldfiles_cache_all ~= nil or preheat_scheduled then
				return
			end

			preheat_scheduled = true
			stats.preheat_runs = stats.preheat_runs + 1

			vim.schedule(function()
				invalidate_oldfiles_cache_if_needed()
				if oldfiles_cache_all ~= nil then
					return
				end

				-- 构建全量缓存
				local ok = pcall(function()
					get_valid_oldfiles_cached(true)
				end)
				if not ok then
					return
				end

				-- A) 可选：预热 git root（分批）
				preheat_git_roots_batch(oldfiles_cache_all)
				dbg(
					("preheat done: all_oldfiles=%d, preheat_git_root=%s"):format(
						oldfiles_cache_all and #oldfiles_cache_all or 0,
						tostring(PREHEAT_GIT_ROOT)
					)
				)
			end)
		end

		-----------------------------------------------------
		-- 显示路径：相对当前分组 root（OTHER 退化）
		-----------------------------------------------------
		local function display_path_for_root(root_key, fname)
			local abs = fn.fnamemodify(fname, ":p")
			if abs == "" then
				return fn.fnamemodify(fname, ":~:.")
			end

			if root_key == "OTHER" then
				return fn.fnamemodify(abs, ":~:.")
			end

			local root_abs = fn.fnamemodify(root_key, ":p")
			if root_abs == "" then
				return fn.fnamemodify(abs, ":~:.")
			end
			if not root_abs:match("/$") then
				root_abs = root_abs .. "/"
			end

			if abs:sub(1, #root_abs) == root_abs then
				local rel = abs:sub(#root_abs + 1)
				return rel ~= "" and rel or "."
			end

			return fn.fnamemodify(abs, ":~:.")
		end

		-----------------------------------------------------
		-- 分组：展开 root 全量、其它 root 5 条；并对展开 root 做前缀快路径
		-----------------------------------------------------
		local function group_files_by_root(files)
			local grouped = {}
			local order = {}
			local per_root_count = {}

			local expanded_abs_prefix = nil
			if expanded_root and expanded_root ~= "OTHER" then
				local expanded_abs = fn.fnamemodify(expanded_root, ":p")
				if expanded_abs ~= "" then
					expanded_abs_prefix = expanded_abs:match("/$") and expanded_abs or (expanded_abs .. "/")
				end
			end

			for _, fname in ipairs(files) do
				local abspath = fn.fnamemodify(fname, ":p")
				if abspath == "" then
					goto continue
				end

				local key
				if expanded_abs_prefix and abspath:sub(1, #expanded_abs_prefix) == expanded_abs_prefix then
					key = expanded_root
					file_root_cache[abspath] = expanded_root
				else
					local root = find_git_root(abspath)
					key = root or "OTHER"
				end

				if not grouped[key] then
					local reached = (#order >= MAX_ROOTS)
					local must_keep = (expanded_root ~= nil and key == expanded_root)
					if reached and not must_keep then
						goto continue
					end
					grouped[key] = {}
					per_root_count[key] = 0
					table.insert(order, key)
				end

				local limit = (expanded_root ~= nil and key == expanded_root) and math.huge or PER_ROOT_FILES
				if per_root_count[key] < limit then
					table.insert(grouped[key], abspath)
					per_root_count[key] = per_root_count[key] + 1
				end

				::continue::
			end

			local cwd_root = find_git_root(startup_cwd)
			if cwd_root then
				local cwd_root_abs = fn.fnamemodify(cwd_root, ":p")
				local matched
				for _, k in ipairs(order) do
					if k ~= "OTHER" and fn.fnamemodify(k, ":p") == cwd_root_abs then
						matched = k
						break
					end
				end
				if matched then
					local new_order = { matched }
					for _, k in ipairs(order) do
						if k ~= matched then
							table.insert(new_order, k)
						end
					end
					order = new_order
				end
			end

			return grouped, order
		end

		-----------------------------------------------------
		-- 光标辅助
		-----------------------------------------------------
		local function get_current_file_under_cursor()
			if not dashboard_buf or not api.nvim_buf_is_valid(dashboard_buf) then
				return nil
			end
			local cur_line = api.nvim_win_get_cursor(0)[1]
			local ok_g, cur_groups = pcall(api.nvim_buf_get_var, dashboard_buf, "startup_groups")
			if not ok_g or not cur_groups then
				return nil
			end
			for _, g in ipairs(cur_groups) do
				for _, e in ipairs(g.files) do
					if e.lnum == cur_line then
						return e.raw
					end
				end
			end
			return nil
		end

		local function restore_cursor_to_root(win, groups, root, prefer_path)
			if not root or not groups then
				return
			end

			if prefer_path then
				local prefer_abs = fn.fnamemodify(prefer_path, ":p")
				for _, g in ipairs(groups) do
					if g.key == root then
						for _, e in ipairs(g.files) do
							if fn.fnamemodify(e.raw, ":p") == prefer_abs then
								api.nvim_win_set_cursor(win, { e.lnum, e.ps or 0 })
								return
							end
						end
					end
				end
			end

			for _, g in ipairs(groups) do
				if g.key == root and #g.files > 0 then
					api.nvim_win_set_cursor(win, { g.files[1].lnum, g.files[1].ps or 0 })
					return
				end
			end
		end

		-----------------------------------------------------
		-- 打开文件：cd 到 root 再 edit
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

			local root = find_git_root(abspath)
			local target_dir = root or dir
			vim.cmd("cd " .. fn.fnameescape(target_dir))
			vim.cmd.edit(fn.fnameescape(abspath))
		end

		-----------------------------------------------------
		-- j/k 循环移动（跨仓库）
		-----------------------------------------------------
		local function move_delta(delta)
			if not dashboard_buf or not api.nvim_buf_is_valid(dashboard_buf) then
				return
			end

			local ok, entries = pcall(api.nvim_buf_get_var, dashboard_buf, "startup_entries")
			if not ok or not entries or #entries == 0 then
				return
			end

			local cur_line = api.nvim_win_get_cursor(0)[1]
			local cur_idx
			for i, e in ipairs(entries) do
				if e.lnum == cur_line then
					cur_idx = i
					break
				end
			end

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

			local e = entries[cur_idx]
			api.nvim_win_set_cursor(0, { e.lnum, e.ps or 0 })
		end

		-----------------------------------------------------
		-- Buffer 初始化（只做一次）
		-----------------------------------------------------
		local function ensure_dashboard_buf()
			if dashboard_buf and api.nvim_buf_is_valid(dashboard_buf) then
				return dashboard_buf
			end

			dashboard_buf = api.nvim_create_buf(false, true)
			api.nvim_buf_set_name(dashboard_buf, "dashboard")
			api.nvim_set_option_value("buftype", "nofile", { buf = dashboard_buf })
			api.nvim_set_option_value("bufhidden", "wipe", { buf = dashboard_buf })
			api.nvim_set_option_value("swapfile", false, { buf = dashboard_buf })
			api.nvim_set_option_value("filetype", "dashboard", { buf = dashboard_buf })

			local function map(lhs, rhs)
				vim.keymap.set("n", lhs, rhs, { buffer = dashboard_buf, silent = true })
			end

			for _, k in ipairs({ "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }) do
				map(k, function()
					local idx = (k == "0") and 10 or tonumber(k)
					local ok_g, groups = pcall(api.nvim_buf_get_var, dashboard_buf, "startup_groups")
					if not ok_g or not groups then
						return
					end
					local g = groups[idx]
					if not g then
						return
					end

					local cur_path = get_current_file_under_cursor()
					pending_cursor = { root = g.key, path = cur_path }

					if expanded_root == g.key then
						expanded_root = nil
						vim.cmd("Dashboard")
						return
					end

					expanded_root = g.key
					if g.key ~= "OTHER" then
						vim.cmd("cd " .. fn.fnameescape(g.key))
					end
					vim.cmd("Dashboard")
				end)
			end

			map("<CR>", function()
				local cur_line = api.nvim_win_get_cursor(0)[1]
				local ok_g, groups = pcall(api.nvim_buf_get_var, dashboard_buf, "startup_groups")
				if not ok_g or not groups then
					return
				end
				for _, g in ipairs(groups) do
					for _, e in ipairs(g.files) do
						if e.lnum == cur_line then
							open_oldfile(e.raw)
							return
						end
					end
				end
			end)

			map("j", function()
				move_delta(1)
			end)
			map("k", function()
				move_delta(-1)
			end)

			for _, k in ipairs({ "<Esc>", "q" }) do
				map(k, "<cmd>bd!<cr>")
			end

			local function map_pass(key)
				map(key, function()
					local seq = ((vim.v.count > 0) and tostring(vim.v.count) or "") .. key
					vim.cmd("bd!")
					local term = api.nvim_replace_termcodes(seq, true, false, true)
					api.nvim_feedkeys(term, "n", false)
				end)
			end
			for _, k in ipairs({ "i", "I", "a", "A", "o", "O", "s", "S", "c", "C", "r", "R" }) do
				map_pass(k)
			end

			return dashboard_buf
		end

		-----------------------------------------------------
		-- 主渲染：只更新 buffer 内容
		-----------------------------------------------------
		local function render()
			stats.renders = stats.renders + 1
			local t0 = now_ms()

			local buf = ensure_dashboard_buf()
			api.nvim_win_set_buf(0, buf)
			api.nvim_buf_clear_namespace(buf, ns_dashboard, 0, -1)

			local lines = {}
			for _, l in ipairs(HEADER) do
				table.insert(lines, l)
			end
			table.insert(lines, "")

			local section_lnum = #lines + 1
			if expanded_root ~= nil then
				local show = (expanded_root == "OTHER") and "Other files" or fn.fnamemodify(expanded_root, ":~:.")
				table.insert(lines, ("    Recent projects (expanded: %s)"):format(show))
			else
				table.insert(lines, "    Recent projects (by git root)")
			end
			table.insert(lines, "  " .. string.rep("─", math.min(vim.o.columns - 4, 50)))
			table.insert(lines, "")

			-- 未展开：只扫100；展开：全量（并缓存）
			local valid_files = get_valid_oldfiles_cached(expanded_root ~= nil)
			local grouped, order = group_files_by_root(valid_files)

			local groups = {}
			local group_header_lnums = {}
			local group_index = 0

			for _, root_key in ipairs(order) do
				local files = grouped[root_key]
				if files and #files > 0 then
					group_index = group_index + 1
					local label = (group_index == 10) and "0" or tostring(group_index)

					local root_name = (root_key == "OTHER") and "Other files" or fn.fnamemodify(root_key, ":~:.")
					local title
					if root_key == "OTHER" then
						title = string.format("  [%s]    %s", label, root_name)
					else
						title = string.format("  [%s]    %s", label, root_name)
					end
					if expanded_root ~= nil and root_key == expanded_root then
						title = title .. "  (expanded)"
					end

					local group_lnum = #lines + 1
					table.insert(lines, title)
					table.insert(group_header_lnums, group_lnum)

					local group = {
						key = root_key,
						index = group_index,
						header_lnum = group_lnum,
						files = {},
					}

					for _, abspath in ipairs(files) do
						local path = display_path_for_root(root_key, abspath)
						local icon, icon_hl = get_icon_cached(abspath)

						local prefix = "      "
						local icon_part = (USE_ICONS and icon ~= "") and (icon .. " ") or ""
						local full_line = prefix .. icon_part .. path
						table.insert(lines, full_line)

						local lnum = #lines
						local entry = {
							lnum = lnum,
							ps = #prefix + #icon_part,
							raw = abspath,
							icon = icon,
							icon_col = #prefix,
							icon_hl = icon_hl,
						}
						table.insert(group.files, entry)
					end

					table.insert(lines, "")
					table.insert(groups, group)
				end
			end

			if #groups == 0 then
				table.insert(lines, "  (no recent git projects)")
			end

			table.insert(lines, "")
			local hint_lnum = #lines + 1
			table.insert(lines, "    [0-9] Expand/Collapse · j/k Move · <CR> Open file · <Esc>/q Close")

			api.nvim_set_option_value("modifiable", true, { buf = buf })
			api.nvim_buf_set_lines(buf, 0, -1, false, lines)
			api.nvim_set_option_value("modifiable", false, { buf = buf })

			api.nvim_buf_set_var(buf, "startup_groups", groups)

			local entries = {}
			for _, g in ipairs(groups) do
				for _, e in ipairs(g.files) do
					table.insert(entries, e)
				end
			end
			api.nvim_buf_set_var(buf, "startup_entries", entries)

			for i = 0, #HEADER - 1 do
				api.nvim_buf_add_highlight(buf, ns_dashboard, "OldfilesHeader", i, 0, -1)
			end
			api.nvim_buf_add_highlight(buf, ns_dashboard, "OldfilesSection", section_lnum - 1, 0, -1)
			api.nvim_buf_add_highlight(buf, ns_dashboard, "OldfilesHint", hint_lnum - 1, 0, -1)

			for _, lnum in ipairs(group_header_lnums) do
				api.nvim_buf_add_highlight(buf, ns_dashboard, "OldfilesSection", lnum - 1, 0, -1)
				api.nvim_buf_add_highlight(buf, ns_dashboard, "OldfilesIndex", lnum - 1, 2, 5)
			end

			for _, g in ipairs(groups) do
				for _, e in ipairs(g.files) do
					local l0 = e.lnum - 1
					local line = lines[e.lnum]
					local last_slash = line:match(".*()/")

					if last_slash and last_slash >= e.ps then
						api.nvim_buf_add_highlight(buf, ns_dashboard, "OldfilesPath", l0, e.ps, last_slash)
						api.nvim_buf_add_highlight(buf, ns_dashboard, "OldfilesFilename", l0, last_slash, -1)
					else
						api.nvim_buf_add_highlight(buf, ns_dashboard, "OldfilesFilename", l0, e.ps, -1)
					end

					if USE_ICONS and e.icon ~= "" and e.icon_hl then
						api.nvim_buf_set_extmark(buf, ns_dashboard, l0, e.icon_col, {
							virt_text = { { e.icon, e.icon_hl } },
							virt_text_pos = "overlay",
							virt_text_hide = true,
						})
					end
				end
			end

			if pending_cursor ~= nil then
				restore_cursor_to_root(0, groups, pending_cursor.root, pending_cursor.path)
				pending_cursor = nil
			else
				for _, g in ipairs(groups) do
					if #g.files > 0 then
						api.nvim_win_set_cursor(0, { g.files[1].lnum, g.files[1].ps or 0 })
						break
					end
				end
			end

			-- 未展开时触发后台预热（全量 oldfiles + 可选 git root）
			if expanded_root == nil then
				schedule_preheat_all_oldfiles()
			end

			local dt = now_ms() - t0
			stats.render_ms_total = stats.render_ms_total + dt
			dbg(("render: expanded=%s, dt=%.2fms"):format(tostring(expanded_root), dt))
		end

		-----------------------------------------------------
		-- 用户命令
		-----------------------------------------------------
		api.nvim_create_user_command("Dashboard", function()
			render()
		end, { desc = "Open startup dashboard" })

		-- C) stats & debug toggle
		api.nvim_create_user_command("DashboardStats", function()
			print_stats()
		end, { desc = "Show dashboard profiling stats" })

		api.nvim_create_user_command("DashboardDebugToggle", function()
			DEBUG = not DEBUG
			vim.notify(("dashboard DEBUG=%s"):format(tostring(DEBUG)), vim.log.levels.INFO, { title = "dashboard" })
		end, { desc = "Toggle dashboard debug logs" })

		vim.keymap.set("n", "<leader>fd", "<cmd>Dashboard<CR>", { desc = "Open startup dashboard" })

		-----------------------------------------------------
		-- 自动在 UIEnter 显示
		-----------------------------------------------------
		api.nvim_create_autocmd("UIEnter", {
			once = true,
			callback = function()
				if fn.argc() == 0 and api.nvim_buf_get_name(0) == "" then
					render()
				end
			end,
		})
	end,
}
