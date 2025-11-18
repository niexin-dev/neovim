return {
	"ibhagwan/fzf-lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },

	init = function()
		vim.api.nvim_create_autocmd("VimEnter", {
			callback = function()
				if vim.fn.argc() == 0 then
					vim.schedule(function()
						require("fzf-lua").oldfiles()
					end)
				end
			end,
		})
	end,

	keys = {
		{ "<leader>b", "<cmd>FzfLua buffers sort_mru=true sort_lastused=true<cr>", desc = "Buffers" },
		{ "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Files" },
		{ "<leader>fl", "<cmd>FzfLua blines<cr>", desc = "Lines" },
		{ "<leader>ft", "<cmd>FzfLua treesitter<cr>", desc = "Treesitter" },
		-- search
		{ "<leader>fs", "<cmd>FzfLua live_grep<cr>", desc = "Grep" },
		{ "<leader>fr", "<cmd>FzfLua grep_cword<cr>", desc = "Grep word" },
		{ "<leader>fa", "<cmd>FzfLua resume<cr>", desc = "Resuse" },
		{ "<leader>fq", "<cmd>FzfLua oldfiles<cr>", desc = "Old files" },
		-- git
		{ "<leader>Gc", "<cmd>FzfLua git_commits<CR>", desc = "Git Commits" },
		{ "<leader>Gs", "<cmd>FzfLua git_status<CR>", desc = "Git Status" },
		-- lsp
		{ "<leader>gd", "<cmd>FzfLua lsp_definitions<CR>", desc = "LSP Definitions" },
		{ "<leader>gr", "<cmd>FzfLua lsp_references<CR>", desc = "LSP References" },
		{ "<leader>gD", "<cmd>FzfLua lsp_declarations<CR>", desc = "LSP Declarations" },
		{ "<leader>gs", "<cmd>FzfLua lsp_live_workspace_symbols<CR>", desc = "LSP Symbols" },
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
			preview = {
				wrap = true,
				layout = "vertical",
				vertical = "up:50%",
			},
		},
	},

	config = function(_, opts)
		local fzf = require("fzf-lua")
		local actions = fzf.actions

		-- 给 oldfiles 配一个自定义的 <CR> 行为
		opts.oldfiles = opts.oldfiles or {}
		opts.oldfiles.actions = opts.oldfiles.actions or {}

		opts.oldfiles.actions["enter"] = function(selected, o)
			-- 先用原来的行为打开文件 / quickfix
			actions.file_edit_or_qf(selected, o)

			-- 当前 buffer 的完整路径
			local path = vim.api.nvim_buf_get_name(0)
			if not path or path == "" then
				return
			end

			-- 文件所在目录
			local dir = vim.fn.fnamemodify(path, ":p:h")

			-- 尝试查 git 根目录
			local result = vim.fn.systemlist({
				"git",
				"-C",
				dir,
				"rev-parse",
				"--show-toplevel",
			})
			local git_root = result[1]

			if vim.v.shell_error == 0 and git_root and git_root ~= "" then
				-- 找到 git 仓库，cd 到仓库根目录
				vim.cmd("cd " .. vim.fn.fnameescape(git_root))
			else
				-- 不在 git 仓库里，就 cd 到文件所在目录
				vim.cmd("cd " .. vim.fn.fnameescape(dir))
			end
		end

		-- 原来的 setup + ui_select
		fzf.setup(opts)
		fzf.register_ui_select()
	end,
}
