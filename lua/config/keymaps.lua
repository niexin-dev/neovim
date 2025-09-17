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
vim.keymap.set("n", "<leader>fn", ":new <C-R>=expand(\"%:p:h\") . \"/\" <CR>")

-- 将 k 映射为 gk (向上移动一行屏幕行)
-- noremap = true 表示禁用递归映射，防止映射链的出现
-- silent = true 表示执行映射时不显示消息
vim.keymap.set({ 'n', 'v' }, 'k', 'gk', { noremap = true, silent = true })
-- 将 j 映射为 gj (向下移动一行屏幕行)
vim.keymap.set({ 'n', 'v' }, 'j', 'gj', { noremap = true, silent = true })


-- 更好的缩进
--按一次 >，代码会缩进，并且马上自动重新选中刚才的区域。这样你就可以连续按 > 或 < 来快速、反复地调整同一代码块的缩进级别，而无需任何多余的操作
vim.keymap.set("v", "<", "<gv", { desc = "Indent left" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right" })

-- 清除搜索高亮
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- 快速保存
vim.keymap.set("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })
