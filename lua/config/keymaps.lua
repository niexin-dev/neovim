----------------------------------------------------------------------
--  Leader Key 设置
----------------------------------------------------------------------
vim.g.mapleader = ","
vim.g.maplocalleader = ","

----------------------------------------------------------------------
--  插入模式映射
----------------------------------------------------------------------
-- 插入模式按 "jk" 快速切换到 Normal 模式
vim.keymap.set("i", "jk", "<ESC>")

----------------------------------------------------------------------
--  可视模式映射
----------------------------------------------------------------------
-- 可视模式：将所选行向下移动一行
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")

-- 可视模式：将所选行向上移动两行
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

----------------------------------------------------------------------
--  Normal 模式映射
----------------------------------------------------------------------

-- LSP 重命名
vim.keymap.set("n", "<leader>rn", ":lua vim.lsp.buf.rename()<CR>")

-- 在当前文件所在目录创建新文件（自动填充路径）
vim.keymap.set("n", "<leader>fn", ':new <C-R>=expand("%:p:h") . "/" <CR>')

----------------------------------------------------------------------
--  屏幕行导航（处理换行后的多行显示）
----------------------------------------------------------------------
-- k 映射为 gk，按屏幕行移动，而不是按实际行
vim.keymap.set({ "n", "v" }, "k", "gk", { noremap = true, silent = true })

-- j 映射为 gj
vim.keymap.set({ "n", "v" }, "j", "gj", { noremap = true, silent = true })

----------------------------------------------------------------------
--  更好的缩进：操作后保持可视模式
----------------------------------------------------------------------
vim.keymap.set("v", "<", "<gv", { desc = "Indent left" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right" })

----------------------------------------------------------------------
-- 清除搜索高亮
----------------------------------------------------------------------
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

----------------------------------------------------------------------
-- 快速保存
----------------------------------------------------------------------
vim.keymap.set("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file", silent = true })

----------------------------------------------------------------------
-- Terminal 模式下快速返回 Normal 模式
----------------------------------------------------------------------
-- Ctrl-j → 退出 terminal-mode（不传给 Shell）
vim.keymap.set("t", "<C-j>", [[<C-\><C-n>]], { noremap = true, silent = true })

----------------------------------------------------------------------
-- <leader>fw: 创建终端
--  - 如果已经有终端窗口：在“最后一个终端”的右边再创建一个终端（vsplit）
--  - 如果还没有终端窗口：在当前 buffer 下方创建一个终端
----------------------------------------------------------------------
vim.keymap.set("n", "<leader>fw", function()
	local last_term_win = nil

	-- 找到当前所有终端窗口中“最后一个”
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		local bt = vim.api.nvim_buf_get_option(buf, "buftype")
		if bt == "terminal" then
			last_term_win = win
		end
	end

	if last_term_win ~= nil and vim.api.nvim_win_is_valid(last_term_win) then
		-- 已经有终端：在这个终端的右边再开一个终端
		vim.api.nvim_set_current_win(last_term_win)
		vim.cmd("vsplit")
		vim.cmd("terminal")
	else
		-- 没有终端：保持原来的行为，在当前 buffer 下方开一个终端
		vim.cmd("belowright split | terminal")
	end
end, { noremap = true, silent = true, desc = "New terminal" })

----------------------------------------------------------------------
-- <leader>fa: 智能 Toggle Terminal（显示/隐藏/新建）
----------------------------------------------------------------------
-- 保存“被隐藏终端”的 buffer 列表
local hidden_term_buffers = {}

vim.keymap.set("n", "<leader>fa", function()
	local term_wins = {} -- 当前显示中的终端窗口
	local term_bufs = {} -- 当前显示中的终端 buffer
	local has_term_shown = false

	------------------------------------------------------------------
	-- 第一步：检查当前是否有终端窗口显示
	------------------------------------------------------------------
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		local bt = vim.api.nvim_buf_get_option(buf, "buftype")

		if bt == "terminal" then
			has_term_shown = true
			term_wins[#term_wins + 1] = win
			term_bufs[#term_bufs + 1] = buf
		end
	end

	------------------------------------------------------------------
	-- 情况 1：当前有终端 → 隐藏所有终端，并记录它们的 buffer
	------------------------------------------------------------------
	if has_term_shown then
		hidden_term_buffers = term_bufs
		for _, win in ipairs(term_wins) do
			vim.api.nvim_win_hide(win) -- 隐藏窗口但不关闭进程
		end
		return
	end

	------------------------------------------------------------------
	-- 情况 2：当前没有终端，但之前隐藏过 → 重新显示它们
	------------------------------------------------------------------
	if #hidden_term_buffers > 0 then
		local first = true
		for _, buf in ipairs(hidden_term_buffers) do
			if vim.api.nvim_buf_is_valid(buf) then
				if first then
					-- 第一个终端：在当前 buffer 下方
					vim.cmd("belowright split")
					first = false
				else
					-- 后续终端：在当前终端右边开 vsplit
					vim.cmd("vsplit")
				end
				vim.api.nvim_win_set_buf(0, buf)
				-- 如果你想恢复后直接输入，加这一句：
				vim.cmd("startinsert")
			end
		end
		hidden_term_buffers = {}
		return
	end

	------------------------------------------------------------------
	-- 情况 3：没有终端，也没有隐藏过 → 创建一个新的终端
	------------------------------------------------------------------
	vim.cmd("belowright split | terminal")
end, { noremap = true, silent = true, desc = "Toggle terminal" })

vim.api.nvim_create_autocmd("TermOpen", {
	callback = function()
		vim.cmd("startinsert")
	end,
})

-- 用 tab 模拟“最大化当前窗口”的 toggle
local zoom_tabpage = nil

vim.keymap.set("n", "<leader>m", function()
	local current_tab = vim.api.nvim_get_current_tabpage()
	local wins = vim.api.nvim_tabpage_list_wins(current_tab)

	--------------------------------------------------------------------
	-- 如果只有 1 个窗口，则不进行 zoom（保持静默）
	--------------------------------------------------------------------
	if #wins == 1 and zoom_tabpage == nil then
		return
	end

	--------------------------------------------------------------------
	-- 进入 zoom 模式
	--------------------------------------------------------------------
	if zoom_tabpage == nil then
		zoom_tabpage = current_tab
		vim.cmd("tab split") -- 在新 tab 中最大化当前 buffer
		return
	end

	--------------------------------------------------------------------
	-- 退出 zoom 模式
	--------------------------------------------------------------------
	if current_tab ~= zoom_tabpage then
		-- 当前在 zoom tab：关闭它
		vim.cmd("tabclose") -- 自动切回 zoom_tabpage
	end

	-- 清除状态
	zoom_tabpage = nil
end, { desc = "Toggle maximize current buffer (via tab)" })
