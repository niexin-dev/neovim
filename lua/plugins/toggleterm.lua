return {
    'akinsho/toggleterm.nvim',
    version = "*",
    opts = {
        -- size can be a number or function which is passed the current terminal
        size = function(term)
            if term.direction == "horizontal" then
                return 30
            elseif term.direction == "vertical" then
                return vim.o.columns * 0.4
            else
                return 20 -- 默认大小
            end
        end,
        -- 设置触发快捷键
        open_mapping = [[<F4>]],
    }
}
