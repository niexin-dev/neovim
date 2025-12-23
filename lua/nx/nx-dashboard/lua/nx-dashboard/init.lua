-- local_plugins/nx-dashboard/lua/nx_dashboard/init.lua
local M = {}

local defaults = {
  use_icons = true,
  max_roots = 10,
  per_root_files = 5,
  max_oldfiles_scan = 100,

  preheat_git_root = true,
  preheat_git_root_max = 200,
  preheat_git_root_batch = 50,

  debug = false,

  -- keymaps / commands
  map_open = "<leader>fd",
  auto_open_on_uienter = true,

  cmd_open = "NxDashboard",
  cmd_stats = "NxDashboardStats",
  cmd_debug_toggle = "NxDashboardDebugToggle",
}

function M.setup(opts)
  local api = vim.api
  local fn = vim.fn
  local uv = vim.loop

  local O = vim.tbl_deep_extend("force", {}, defaults, opts or {})

  -----------------------------------------------------
  -- 用户配置项（来自 opts）
  -----------------------------------------------------
  local USE_ICONS = O.use_icons
  local MAX_ROOTS = O.max_roots
  local PER_ROOT_FILES = O.per_root_files
  local MAX_OLDFILES_SCAN = O.max_oldfiles_scan

  local PREHEAT_GIT_ROOT = O.preheat_git_root
  local PREHEAT_GIT_ROOT_MAX = O.preheat_git_root_max
  local PREHEAT_GIT_ROOT_BATCH = O.preheat_git_root_batch

  local DEBUG = O.debug

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

    abs_cache_hit = 0,
    abs_cache_miss = 0,
  }

  local function now_ms()
    return uv.hrtime() / 1e6
  end

  local function dbg(msg)
    if not DEBUG then
      return
    end
    vim.schedule(function()
      vim.notify(msg, vim.log.levels.INFO, { title = "nx-dashboard" })
    end)
  end

  local function print_stats()
    local avg_render = stats.renders > 0 and (stats.render_ms_total / stats.renders) or 0
    local avg_git = stats.git_root_calls > 0 and (stats.git_root_ms_total / stats.git_root_calls) or 0

    local msg = table.concat({
      ("renders=%d, render_total=%.1fms, render_avg=%.2fms"):format(stats.renders, stats.render_ms_total, avg_render),
      ("oldfiles_sig_changes=%d"):format(stats.oldfiles_sig_changes),
      ("oldfiles_top_builds=%d, top_total=%.1fms"):format(stats.oldfiles_top_builds, stats.oldfiles_top_ms_total),
      ("oldfiles_all_builds=%d, all_total=%.1fms"):format(stats.oldfiles_all_builds, stats.oldfiles_all_ms_total),
      ("git_root_calls=%d, git_total=%.1fms, git_avg=%.3fms"):format(stats.git_root_calls, stats.git_root_ms_total, avg_git),
      ("git_cache_hit_file=%d, git_cache_hit_dir=%d, git_fs_checks=%d"):format(
        stats.git_root_file_hit,
        stats.git_root_dir_hit,
        stats.git_root_fs_checks
      ),
      ("preheat_runs=%d, preheat_git_root_runs=%d"):format(stats.preheat_runs, stats.preheat_git_root_runs),
      ("abs_cache_hit=%d, abs_cache_miss=%d"):format(stats.abs_cache_hit, stats.abs_cache_miss),
    }, "\n")

    vim.notify(msg, vim.log.levels.INFO, { title = "nx-dashboard stats" })
  end

  -----------------------------------------------------
  -- 状态
  -----------------------------------------------------
  local expanded_root = nil
  local pending_cursor = nil
  local startup_cwd = fn.getcwd()

  local dashboard_buf = nil
  local ns_dashboard = api.nvim_create_namespace("NxDashboard")

  -----------------------------------------------------
  -- 工具函数
  -----------------------------------------------------
  local function is_local_path(path)
    return not path:match("^%w[%w+.-]*://")
  end

  local function is_on_windows_mount(path)
    return path:match("^/mnt/[a-zA-Z]/")
  end

  -----------------------------------------------------
  -- to_abs 缓存
  -----------------------------------------------------
  local abs_cache = {}

  local function looks_abs_clean(p)
    return type(p) == "string"
      and p:sub(1, 1) == "/"
      and not p:find("/%./")
      and not p:find("/%.%./")
      and not p:find("//")
  end

  local function to_abs(path)
    if not path or path == "" then
      return ""
    end

    local cached = abs_cache[path]
    if cached ~= nil then
      stats.abs_cache_hit = stats.abs_cache_hit + 1
      return cached
    end

    stats.abs_cache_miss = stats.abs_cache_miss + 1

    local abs
    if looks_abs_clean(path) then
      abs = path
    else
      abs = fn.fnamemodify(path, ":p")
    end

    abs = abs or ""
    abs_cache[path] = abs
    return abs
  end

  -----------------------------------------------------
  -- root_prefix 缓存
  -----------------------------------------------------
  local root_prefix_cache = {}

  local function root_prefix(root_key)
    if root_key == "OTHER" or not root_key or root_key == "" then
      return nil
    end

    local cached = root_prefix_cache[root_key]
    if cached ~= nil then
      return cached or nil
    end

    local abs = to_abs(root_key)
    if abs == "" then
      root_prefix_cache[root_key] = false
      return nil
    end

    if not abs:match("/$") then
      abs = abs .. "/"
    end

    root_prefix_cache[root_key] = abs
    return abs
  end

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
  local git_root_cache = {}
  local file_root_cache = {}

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

    local abspath = to_abs(path)
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

      abs_cache = {}
      root_prefix_cache = {}
      dbg("oldfiles changed: caches invalidated")
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

      local ok = pcall(function()
        get_valid_oldfiles_cached(true)
      end)
      if not ok then
        return
      end

      preheat_git_roots_batch(oldfiles_cache_all)
      dbg(("preheat done: all_oldfiles=%d, preheat_git_root=%s"):format(
        oldfiles_cache_all and #oldfiles_cache_all or 0,
        tostring(PREHEAT_GIT_ROOT)
      ))
    end)
  end

  -----------------------------------------------------
  -- 显示路径
  -----------------------------------------------------
  local function display_path_for_root(root_key, fname)
    local abs = to_abs(fname)
    if abs == "" then
      return fn.fnamemodify(fname, ":~:.")
    end

    if root_key == "OTHER" then
      return fn.fnamemodify(abs, ":~:.")
    end

    local prefix = root_prefix(root_key)
    if not prefix then
      return fn.fnamemodify(abs, ":~:.")
    end

    if abs:sub(1, #prefix) == prefix then
      local rel = abs:sub(#prefix + 1)
      return rel ~= "" and rel or "."
    end

    return fn.fnamemodify(abs, ":~:.")
  end

  -----------------------------------------------------
  -- 分组
  -----------------------------------------------------
  local function group_files_by_root(files)
    local grouped = {}
    local order = {}
    local per_root_count = {}

    local expanded_prefix = nil
    if expanded_root and expanded_root ~= "OTHER" then
      expanded_prefix = root_prefix(expanded_root)
    end

    for _, fname in ipairs(files) do
      local abspath = to_abs(fname)
      if abspath == "" then
        goto continue
      end

      local key
      if expanded_prefix and abspath:sub(1, #expanded_prefix) == expanded_prefix then
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
      local cwd_root_abs = to_abs(cwd_root)
      local matched
      for _, k in ipairs(order) do
        if k ~= "OTHER" and to_abs(k) == cwd_root_abs then
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
      local prefer_abs = to_abs(prefer_path)
      for _, g in ipairs(groups) do
        if g.key == root then
          for _, e in ipairs(g.files) do
            if to_abs(e.raw) == prefer_abs then
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
  -- 打开文件
  -----------------------------------------------------
  local function open_oldfile(path)
    if not path or path == "" or not is_local_path(path) then
      return
    end

    local abspath = to_abs(path)
    if abspath == "" then
      return
    end

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
  -- j/k 循环移动
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
  -- Buffer 初始化
  -----------------------------------------------------
  local function ensure_dashboard_buf()
    if dashboard_buf and api.nvim_buf_is_valid(dashboard_buf) then
      return dashboard_buf
    end

    dashboard_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_name(dashboard_buf, "nx-dashboard")
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
          vim.cmd(O.cmd_open)
          return
        end

        expanded_root = g.key
        if g.key ~= "OTHER" then
          vim.cmd("cd " .. fn.fnameescape(g.key))
        end
        vim.cmd(O.cmd_open)
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

    map("j", function() move_delta(1) end)
    map("k", function() move_delta(-1) end)

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
  -- 主渲染
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

        local group = { key = root_key, index = group_index, header_lnum = group_lnum, files = {} }

        for _, abspath in ipairs(files) do
          local path = display_path_for_root(root_key, abspath)
          local icon, icon_hl = get_icon_cached(abspath)

          local prefix = "      "
          local icon_part = (USE_ICONS and icon ~= "") and (icon .. " ") or ""
          local full_line = prefix .. icon_part .. path
          table.insert(lines, full_line)

          local lnum = #lines
          table.insert(group.files, {
            lnum = lnum,
            ps = #prefix + #icon_part,
            raw = abspath,
            icon = icon,
            icon_col = #prefix,
            icon_hl = icon_hl,
          })
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

    if expanded_root == nil then
      schedule_preheat_all_oldfiles()
    end

    local dt = now_ms() - t0
    stats.render_ms_total = stats.render_ms_total + dt
    dbg(("render: expanded=%s, dt=%.2fms"):format(tostring(expanded_root), dt))
  end

  -----------------------------------------------------
  -- 命令与自动打开
  -----------------------------------------------------
  api.nvim_create_user_command(O.cmd_open, function() render() end, { desc = "Open startup dashboard" })
  api.nvim_create_user_command(O.cmd_stats, function() print_stats() end, { desc = "Show dashboard profiling stats" })
  api.nvim_create_user_command(O.cmd_debug_toggle, function()
    DEBUG = not DEBUG
    vim.notify(("nx-dashboard DEBUG=%s"):format(tostring(DEBUG)), vim.log.levels.INFO, { title = "nx-dashboard" })
  end, { desc = "Toggle dashboard debug logs" })

  if O.map_open and O.map_open ~= "" then
    vim.keymap.set("n", O.map_open, ("<cmd>%s<CR>"):format(O.cmd_open), { desc = "Open startup dashboard" })
  end

  if O.auto_open_on_uienter then
    api.nvim_create_autocmd("UIEnter", {
      once = true,
      callback = function()
        if fn.argc() == 0 and api.nvim_buf_get_name(0) == "" then
          render()
        end
      end,
    })
  end
end

return M

