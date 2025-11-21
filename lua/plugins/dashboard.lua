return {
	name = "startup-dashboard",
	dir = vim.fn.stdpath("config"),
	lazy = false,
	priority = 1000,
	config = function()
		local function open_oldfile(path)
			if not path or path == "" then
				return
			end

			local dir = vim.fn.fnamemodify(path, ":p:h")
			local result = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
			local git_root = result[1]

			if vim.v.shell_error == 0 and git_root and git_root ~= "" then
				vim.cmd("cd " .. vim.fn.fnameescape(git_root))
			elseif dir and dir ~= "" then
				vim.cmd("cd " .. vim.fn.fnameescape(dir))
			end

			vim.cmd.edit(vim.fn.fnameescape(path))
		end

		local function render_oldfiles_dashboard()
			if vim.fn.argc() ~= 0 or vim.api.nvim_buf_get_name(0) ~= "" then
				return
			end

			local max_items = 26
			local oldfiles = {}

			for _, path in ipairs(vim.v.oldfiles or {}) do
				oldfiles[#oldfiles + 1] = path

				if #oldfiles >= max_items then
					break
				end
			end

			local buf = vim.api.nvim_create_buf(false, true)
			local win = vim.api.nvim_get_current_win()

			local setopt = vim.api.nvim_set_option_value
			setopt("bufhidden", "wipe", { buf = buf })
			setopt("buftype", "nofile", { buf = buf })
			setopt("swapfile", false, { buf = buf })
			setopt("filetype", "OldfilesDashboard", { buf = buf })
			setopt("modifiable", true, { buf = buf })

			local header = {
				[[    _   _   _                 _           _           _   _                          _                ]],
				[[   | \ | | (_)   ___  __  __ (_)  _ __   ( )  ___    | \ | |   ___    ___   __   __ (_)  _ __ ___     ]],
				[[   |  \| | | |  / _ \ \ \/ / | | | '_ \  |/  / __|   |  \| |  / _ \  / _ \  \ \ / / | | | '_ ` _ \    ]],
				[[   | |\  | | | |  __/  >  <  | | | | | |     \__ \   | |\  | |  __/ | (_) |  \ V /  | | | | | | | |   ]],
				[[   |_| \_| |_|  \___| /_/\_\ |_| |_| |_|     |___/   |_| \_|  \___|  \___/    \_/   |_| |_| |_| |_|   ]],
			}

			local lines = {}
			vim.list_extend(lines, header)
			table.insert(lines, "")
			table.insert(lines, "  Recent files")

			if vim.tbl_isempty(oldfiles) then
				table.insert(lines, "   (no recent files)")
			else
				for index, path in ipairs(oldfiles) do
					local label = string.char(string.byte("a") + index - 1)
					table.insert(lines, string.format("  %s  %s", label, vim.fn.fnamemodify(path, ":~:.")))
				end
			end

			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
			setopt("modifiable", false, { buf = buf })
			vim.api.nvim_win_set_buf(win, buf)

			local function open_index(target_index)
				if target_index > 0 and target_index <= #oldfiles then
					open_oldfile(oldfiles[target_index])
				end
			end

			for i = 1, math.min(#oldfiles, max_items) do
				local label = string.char(string.byte("a") + i - 1)

				vim.keymap.set("n", label, function()
					open_index(i)
				end, { buffer = buf, silent = true })
			end

			vim.keymap.set("n", "<CR>", function()
				local line = vim.api.nvim_get_current_line()
				local key = line:match("^%s*([a-z])%s")

				if key then
					local index = string.byte(key) - string.byte("a") + 1
					open_index(index)
				end
			end, { buffer = buf, silent = true })

			vim.keymap.set("n", "<Esc>", "<cmd>bd!<cr>", { buffer = buf, silent = true })
		end

		if vim.fn.argc() == 0 and vim.api.nvim_buf_get_name(0) == "" then
			if not vim.tbl_contains(vim.opt.shortmess:get(), "I") then
				vim.opt.shortmess:append("I")
			end
		end

		vim.api.nvim_create_autocmd("VimEnter", {
			callback = render_oldfiles_dashboard,
			once = true,
		})
	end,
}
