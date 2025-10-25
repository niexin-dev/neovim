return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPost", "BufNewFile", "BufWritePre" },

	opts = {
		signs = {
			add = { text = "┃" },
			change = { text = "┃" },
			delete = { text = "_" },
			topdelete = { text = "‾" },
			changedelete = { text = "~" },
			untracked = { text = "┆" },
		},
		signs_staged = {
			add = { text = "┃" },
			change = { text = "┃" },
			delete = { text = "_" },
			topdelete = { text = "‾" },
			changedelete = { text = "~" },
			untracked = { text = "┆" },
		},
		signs_staged_enable = true,
		signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
		numhl = true, -- Toggle with `:Gitsigns toggle_numhl`
		linehl = true, -- Toggle with `:Gitsigns toggle_linehl`
		word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
		watch_gitdir = {
			interval = 1000,
			follow_files = true,
		},
		auto_attach = true,
		attach_to_untracked = true,
		current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
		current_line_blame_opts = {
			virt_text = true,
			virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
			delay = 1000,
			ignore_whitespace = false,
			virt_text_priority = 100,
			use_focus = true,
		},
		current_line_blame_formatter = "<author>, <author_time:%R> - <summary>",
		sign_priority = 6,
		update_debounce = 100,
		status_formatter = nil, -- Use default
		max_file_length = 40000, -- Disable if file is longer than this (in lines)
		preview_config = {
			-- Options passed to nvim_open_win
			border = "single",
			style = "minimal",
			relative = "cursor",
			row = 0,
			col = 1,
		},
		on_attach = function(bufnr)
			local gs = package.loaded.gitsigns or require("gitsigns")

			vim.keymap.set("n", "<leader>gj", gs.next_hunk, {
				buffer = bufnr,
				silent = true,
				noremap = true,
				desc = "Next hunk",
			})
			vim.keymap.set("n", "<leader>gk", gs.prev_hunk, {
				buffer = bufnr,
				silent = true,
				noremap = true,
				desc = "Previous hunk",
			})
			vim.keymap.set("n", "<leader>hs", gs.stage_hunk, {
				buffer = bufnr,
				silent = true,
				noremap = true,
				desc = "Stage hunk",
			})
			vim.keymap.set("v", "<leader>hs", function()
				gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end, {
				buffer = bufnr,
				silent = true,
				noremap = true,
				desc = "Stage selected hunk",
			})
			vim.keymap.set("n", "<leader>hr", gs.reset_hunk, {
				buffer = bufnr,
				silent = true,
				noremap = true,
				desc = "Reset hunk",
			})
			vim.keymap.set("v", "<leader>hr", function()
				gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end, {
				buffer = bufnr,
				silent = true,
				noremap = true,
				desc = "Reset selected hunk",
			})
			vim.keymap.set("n", "<leader>hS", gs.stage_buffer, {
				buffer = bufnr,
				silent = true,
				noremap = true,
				desc = "Stage buffer",
			})
			vim.keymap.set("n", "<leader>hu", gs.undo_stage_hunk, {
				buffer = bufnr,
				silent = true,
				noremap = true,
				desc = "Undo stage hunk",
			})
			vim.keymap.set("n", "<leader>hR", gs.reset_buffer, {
				buffer = bufnr,
				silent = true,
				noremap = true,
				desc = "Reset buffer",
			})
			vim.keymap.set("n", "<leader>hp", gs.preview_hunk, {
				buffer = bufnr,
				silent = true,
				noremap = true,
				desc = "Preview hunk",
			})
			vim.keymap.set("n", "<leader>hb", function()
				gs.blame_line({ full = true })
			end, {
				buffer = bufnr,
				silent = true,
				noremap = true,
				desc = "Blame line (full)",
			})
			vim.keymap.set("n", "<leader>tb", gs.toggle_current_line_blame, {
				buffer = bufnr,
				silent = true,
				noremap = true,
				desc = "Toggle current line blame",
			})
			vim.keymap.set("n", "<leader>hd", gs.diffthis, {
				buffer = bufnr,
				silent = true,
				noremap = true,
				desc = "Diff against index",
			})
			vim.keymap.set("n", "<leader>hD", function()
				gs.diffthis("~")
			end, {
				buffer = bufnr,
				silent = true,
				noremap = true,
				desc = "Diff against last commit",
			})
			vim.keymap.set("n", "<leader>td", gs.toggle_deleted, {
				buffer = bufnr,
				silent = true,
				noremap = true,
				desc = "Toggle deleted hunks",
			})
			vim.keymap.set({ "o", "x" }, "ih", gs.select_hunk, {
				buffer = bufnr,
				silent = true,
				noremap = true,
				desc = "Select hunk",
			})
		end,
	},
}
