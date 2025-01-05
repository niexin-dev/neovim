vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- 插入模式
vim.keymap.set("i", "jk", "<ESC>")

-- 可视模式
-- 单行或多行移动
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- 正常模式
-- 取消高亮
vim.keymap.set("n", "<leader>nl", ":nohl<CR>")

vim.keymap.set("n", "<leader>rn", ":lua vim.lsp.buf.rename()<CR>")
