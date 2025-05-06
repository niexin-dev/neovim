vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- 插入模式
vim.keymap.set("i", "jk", "<ESC>")

-- 可视模式
-- 单行或多行移动
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- 正常模式

vim.keymap.set("n", "<leader>rn", ":lua vim.lsp.buf.rename()<CR>")

-- 在当前目录下创建新文件
vim.keymap.set("n", "<leader>en", ":new <C-R>=expand(\"%:p:h\") . \"/\" <CR>")

-- 将 k 映射为 gk (向上移动一行屏幕行)
-- noremap = true 表示禁用递归映射，防止映射链的出现
-- silent = true 表示执行映射时不显示消息
vim.keymap.set('n', 'k', 'gk', { noremap = true, silent = true })
-- 将 j 映射为 gj (向下移动一行屏幕行)
vim.keymap.set('n', 'j', 'gj', { noremap = true, silent = true })

