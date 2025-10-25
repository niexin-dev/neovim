local tools = {
	"clang-format", -- C/C++ 格式化工具
	"checkmake", -- Makefile linter
	"prettierd", -- 更快的 Prettier 守护进程
	"shellcheck", -- Shell 脚本 linter
	"shfmt", -- Shell 脚本格式化工具
	"stylua", -- Lua 格式化工具
	"isort", -- Python import 排序工具
	"black", -- Python 代码格式化工具
	-- taplo 由下方 LSP 安装，确保 CLI 与服务器一并提供
}

local servers = {
	"bashls", -- nvim-lspconfig 中 bash-language-server 的名称是 bashls
	"clangd",
	"lua_ls", -- nvim-lspconfig 中 lua-language-server 的名称是 lua_ls
	"marksman",
	"taplo", -- 这会安装 taplo CLI 工具和 LSP 服务器
}

return {
	{
		"williamboman/mason.nvim",
		cmd = { "Mason", "MasonInstall", "MasonUpdate" },
		-- mason.nvim 负责提供统一的安装界面与基础设施
		opts = {
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		},
	},
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		dependencies = { "williamboman/mason.nvim" },
		cmd = { "MasonToolsInstall", "MasonToolsUpdate", "MasonToolsClean", "MasonToolsCheck" },
		-- mason-tool-installer.nvim 用于确保通用开发工具按需安装与更新
		opts = {
			ensure_installed = tools,
			run_on_start = false,
			auto_update = false,
		},
	},
	{
		"williamboman/mason-lspconfig.nvim",
		event = { "BufReadPre", "BufNewFile" },
		opts = {
			-- 这里只放 nvim-lspconfig 支持的 LSP 服务器名称
			ensure_installed = servers,
		},
	},
}
