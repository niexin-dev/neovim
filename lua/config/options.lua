local opt = vim.opt

-- 行号
opt.relativenumber = true
opt.number = true

-- 字体
opt.guifont="Hack Nerd Font Mono Regular 12"

-- 缩进
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.autoindent = true

-- 防止包裹
opt.wrap = false

-- 光标行
opt.cursorline = true

-- 设置剪贴板使用系统剪贴板
opt.clipboard:append("unnamedplus")

-- 默认新窗口右和下
opt.splitright = true
opt.splitbelow = true

-- 搜索
opt.ignorecase = true
opt.smartcase = true

-- 外观
opt.termguicolors = true
opt.signcolumn = "yes"

-- 主题
--vim.cmd[[colorscheme tokyonight-night]]
-- vim.cmd[[colorscheme onedark]]

-- 禁用鼠标
opt.mouse = ""
