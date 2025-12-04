-- 行号
-- vim.opt.relativenumber = true
vim.opt.number = true

-- 字体
vim.opt.guifont = "Hack Nerd Font Mono Regular 12"

-- 缩进
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.autoindent = true

-- 光标行
vim.opt.cursorline = true

-- 默认新窗口右和下
vim.opt.splitright = true
vim.opt.splitbelow = true

-- 搜索
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- 外观
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"

-- 主题
--vim.cmd[[colorscheme tokyonight-night]]
-- vim.cmd[[colorscheme onedark]]

-- 禁用鼠标
vim.opt.mouse = ""

-- 打开文件时自动跳转到关闭前的光标位置
vim.api.nvim_create_autocmd("BufReadPost", {
	pattern = "*",
	callback = function()
		-- 检查是否为普通文件缓冲区，并且该缓冲区有关联的文件
		if vim.bo.buftype == "" and vim.fn.filereadable(vim.api.nvim_buf_get_name(0)) == 1 then
			local last_pos = vim.fn.line("'\"")
			if last_pos > 1 and last_pos <= vim.fn.line("$") then
				vim.cmd('normal! g`"')
			end
		end
	end,
})

-- 光标会在第10行触发向上滚动，或者在倒数第10行触发向下滚动
vim.opt.scrolloff = math.min(10, math.floor(vim.o.lines * 0.3)) -- 不超过窗口高度的30%

-- 启用持久化的撤销历史
vim.o.undofile = true

-- 设置 undo 文件的保存目录
local undodir = vim.fn.stdpath("cache") .. "/undo"
vim.opt.undodir = undodir .. "//"

-- 确保 undo 目录存在
vim.fn.mkdir(undodir, "p")

-- 禁用交换文件
vim.opt.swapfile = false

-- 设置文件编码格式
vim.opt.fileencodings = "utf-8,euc-cn,ucs-bom,gb18030,gbk,gb2312,cp936"

vim.wo.wrap = true -- 启用换行
vim.wo.linebreak = true -- 在单词边界换行（避免截断单词）
vim.wo.breakindent = true -- 保持缩进
vim.wo.showbreak = "↪ " -- 折行显示前缀符号（可选）

-- 添加错误处理
-- vim.diagnostic.config({ virtual_lines = true })

-- 剪贴板统一配置函数
local function setup_clipboard()
	-- vim.opt.clipboard = "unnamedplus"
	vim.opt.clipboard:append({ "unnamed", "unnamedplus" })

	-- 检查是否在 WSL 环境
	if vim.fn.has("wsl") == 1 then
		-- print("Setting up WSL clipboard") -- 调试信息
		-- 使用 win32yank 实现 Windows 和 WSL 之间的剪贴板共享
		vim.g.clipboard = {
			name = "win32yank-wsl",
			copy = {
				["+"] = "win32yank.exe -i --crlf",
				["*"] = "win32yank.exe -i --crlf",
			},
			paste = {
				["+"] = "win32yank.exe -o --lf",
				["*"] = "win32yank.exe -o --lf",
			},
			cache_enabled = true,
		}
		return
	end

	-- -- 检查是否在 Wayland 环境
	-- if os.getenv("XDG_SESSION_TYPE") == "wayland" then
	--     -- print("Setting up Wayland clipboard") -- 调试信息
	--     vim.g.clipboard = {
	--         name = 'wl-copy',
	--         copy = {
	--             ['+'] = 'wl-copy',
	--             ['*'] = 'wl-copy',
	--         },
	--         paste = {
	--             ['+'] = 'wl-paste',
	--             ['*'] = 'wl-paste',
	--         },
	--         cache_enabled = true,
	--     }
	--     return
	-- end

	-- SSH 环境下使用 OSC52 协议支持远程复制粘贴
	if vim.env.SSH_TTY ~= nil then
		-- print("Setting up OSC52 clipboard") -- 调试信息
		local function osc52_paste()
			local content = vim.fn.getreg("")
			return vim.split(content, "\n")
		end

		vim.g.clipboard = {
			name = "OSC 52",
			copy = {
				["+"] = require("vim.ui.clipboard.osc52").copy("+"),
				["*"] = require("vim.ui.clipboard.osc52").copy("*"),
			},
			paste = {
				["+"] = osc52_paste,
				["*"] = osc52_paste,
			},
		}
		return
	end
end

-- 执行剪贴板设置
setup_clipboard()

-- 性能优化
vim.opt.updatetime = 250 -- 更快的 CursorHold 事件
vim.opt.timeoutlen = 300 -- 更快的按键序列超时
vim.opt.lazyredraw = false -- 不延迟重绘（现代终端性能足够）

-- 更好的补全体验
vim.opt.pumheight = 10 -- 限制补全菜单高度
vim.opt.completeopt = "menu,menuone,noselect"

-- 更好的搜索体验
vim.opt.inccommand = "split" -- 实时预览替换效果

-- 关闭 netrw（用 neo-tree/其他替代）
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- 关闭 matchit（用不到就关）
vim.g.loaded_matchit = 1

-- 关闭 tar/zip 支持（你用不到的话）
vim.g.loaded_tarPlugin = 1
vim.g.loaded_zipPlugin = 1

-- 关闭 tutor
vim.g.loaded_tutor_mode_plugin = 1

