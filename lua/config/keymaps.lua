vim.g.mapleader = ","
vim.g.maplocalleader = ","

local keymap = vim.keymap

-- 插入模式
keymap.set("i", "jk", "<ESC>")

-- 可视模式
-- 单行或多行移动
keymap.set("v", "J", ":m '>+1<CR>gv=gv")
keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- 正常模式
-- 取消高亮
keymap.set("n", "<leader>nl", ":nohl<CR>")
