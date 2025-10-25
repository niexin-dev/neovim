return {
	"mhinz/vim-startify",
	event = "VimEnter", -- 延迟加载时机
	init = function()
		-- 基础兼容性设置
		vim.g.startify_session_dir = vim.fn.stdpath("data") .. "/sessions" -- 标准化会话存储路径
		vim.g.startify_change_to_dir = 1
		vim.g.startify_change_to_vcs_root = 1
		vim.g.startify_custom_header = {
			[[    _   _   _                 _           _           _   _                          _                ]],
			[[   | \ | | (_)   ___  __  __ (_)  _ __   ( )  ___    | \ | |   ___    ___   __   __ (_)  _ __ ___     ]],
			[[   |  \| | | |  / _ \ \ \/ / | | | '_ \  |/  / __|   |  \| |  / _ \  / _ \  \ \ / / | | | '_ ` _ \    ]],
			[[   | |\  | | | |  __/  >  <  | | | | | |     \__ \   | |\  | |  __/ | (_) |  \ V /  | | | | | | | |   ]],
			[[   |_| \_| |_|  \___| /_/\_\ |_| |_| |_|     |___/   |_| \_|  \___|  \___/    \_/   |_| |_| |_| |_|   ]],
		}

		-- 高性能会话管理配置
		vim.g.startify_session_persistence = 1

		-- 对应 autocmd User Startified setlocal cursorline
		vim.opt.cursorline = true
		vim.api.nvim_create_autocmd("User", {
			pattern = "Startified", -- 监听 Startify 完成事件
			callback = function()
				if vim.bo.filetype == "startify" then -- 仅在 startify 文件类型生效
					vim.wo.cursorline = true -- 设置窗口局部选项
				end
			end,
		})
	end,
}
