-- return {
--     'akinsho/toggleterm.nvim',
--     version = "*",
--     opts = {
--         -- size can be a number or function which is passed the current terminal
--         size = function(term)
--             if term.direction == "horizontal" then
--                 return 30
--             elseif term.direction == "vertical" then
--                 return vim.o.columns * 0.4
--             else
--                 return 20 -- 默认大小
--             end
--         end,
--         -- 设置触发快捷键
--         open_mapping = [[<F4>]],
--     }
-- }

return {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
        { "<leader>tt", "<cmd>ToggleTerm<cr>", desc = "Toggle Terminal" },
    },
    config = function()
        require("toggleterm").setup({
            size = 20,
            -- open_mapping is handled by lazy.nvim keys now
            on_create = function(term)
                -- 终端创建时设置键位映射
                vim.schedule(function()
                    local opts = { buffer = term.bufnr }
                    -- 退出终端模式
                    vim.keymap.set('t', '<esc>', [[<C-\><C-n>]], opts)
                end)
            end
        })
    end
}
