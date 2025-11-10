return {
	"ibhagwan/fzf-lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	keys = {
		{ "<leader>b", "<cmd>FzfLua buffers sort_mru=true sort_lastused=true<cr>", desc = "Buffers" },
		{ "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Files" },
		{ "<leader>fl", "<cmd>FzfLua blines<cr>", desc = "Lines" },
		{ "<leader>ft", "<cmd>FzfLua treesitter<cr>", desc = "Treesitter" },
		-- search
		{ "<leader>fs", "<cmd>FzfLua live_grep<cr>", desc = "Grep" },
		{ "<leader>fr", "<cmd>FzfLua grep_cword<cr>", desc = "Grep word" },
		{ "<leader>fa", "<cmd>FzfLua resume<cr>", desc = "Resuse" },
		-- git
		{ "<leader>Gc", "<cmd>FzfLua git_commits<CR>", desc = "Git Commits" },
		{ "<leader>Gs", "<cmd>FzfLua git_status<CR>", desc = "Git Status" },
		-- lsp
		{ "<leader>gd", "<cmd>FzfLua lsp_definitions<CR>", desc = "LSP Definitions" },
		{ "<leader>gr", "<cmd>FzfLua lsp_references<CR>", desc = "LSP References" },
		{ "<leader>gD", "<cmd>FzfLua lsp_declarations<CR>", desc = "LSP Declarations" },
		{ "<leader>gs", "<cmd>FzfLua lsp_live_workspace_symbols<CR>", desc = "LSP Symbols" },
		-- { "<leader>gi", "<cmd>FzfLua lsp_incoming_calls<CR>", desc = "LSP Incoming" },
		-- { "<leader>go", "<cmd>FzfLua lsp_outgoing_calls<CR>", desc = "LSP Outgoing" },
		{ "<leader>gx", "<cmd>FzfLua lsp_document_diagnostics<CR>", desc = "LSP Diagnostics" },
		{ "<leader>qf", "<cmd>FzfLua lsp_code_actions<CR>", desc = "LSP Code action" },
	},
	opts = {
		files = {
			git_icons = false,
			find_opts = "-type f -not -path '*/\\.git/*' -printf '%P\n'",
			fd_opts = "--color=never --type f --hidden --follow --exclude .git",
			winopts = { preview = { winopts = { cursorline = true } } },
			no_ignore = false,
		},
		winopts = {
			-- split = "belowright 10new",
			preview = {
				wrap = true, -- 允许文本换行
				layout = "vertical", -- horizontal|vertical|flex
				vertical = "up:50%", -- up|down:size
				-- hidden = "hidden", -- 隐藏预览窗口
			},
			-- fzf-lua 的 ui_select 配置（可选）
			-- ui_select = { silent = true },
		}, -- UI Options
	},
	config = function(_, opts)
		local fzf = require("fzf-lua")
		fzf.setup(opts)
		-- 🔹 自动注册成 vim.ui.select 后端
		fzf.register_ui_select()
	end,
}
