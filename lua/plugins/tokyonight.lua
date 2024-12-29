return {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
        -- 设置主题
        vim.cmd[[colorscheme tokyonight]]
    end
}
