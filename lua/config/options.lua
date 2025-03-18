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

-- 防止包裹
vim.opt.wrap = false

-- 光标行
vim.opt.cursorline = true

-- 配置OSC 52
-- https://zhuanlan.zhihu.com/p/701934619
-- 定义OSC52粘贴函数
local function osc52_paste()
    -- 获取 "" 寄存器的内容并按行分割
    local content = vim.fn.getreg("")
    return vim.split(content, '\n')
end

-- 检查是否在SSH环境中
if vim.env.SSH_TTY == nil then
    -- 本地环境，包括WSL，设置剪贴板使用系统剪贴板
    vim.opt.clipboard:append("unnamedplus")
else
    -- SSH环境，设置剪贴板使用OSC52
    vim.opt.clipboard:append("unnamedplus")
    vim.g.clipboard = {
        name = 'OSC 52',
        copy = {
            ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
            ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
        },
        paste = {
            ["+"] = osc52_paste,
            ["*"] = osc52_paste,
        },
    }
end

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
vim.cmd([[
  augroup restore_cursor_position
    autocmd!
    autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
  augroup END
]])

-- 光标会在第7行触发向上滚动，或者在倒数第7行触发向下滚动
vim.opt.scrolloff = 7

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

