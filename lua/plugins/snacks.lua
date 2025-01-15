return {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
        bigfile = { enabled = true },
        dashboard = {
            enabled = true,
            formats = {
                key = function(item)
                    return { { "[", hl = "special" }, { item.key, hl = "key" }, { "]", hl = "special" } }
                end,
            },
            sections = {
                { title = "Recent",         padding = 1 },
                { section = "recent_files", limit = 8,                            padding = 1 },
                { title = "MRU ",           file = vim.fn.fnamemodify(".", ":~"), padding = 1 },
                { section = "recent_files", cwd = true,                           limit = 8,  padding = 1 },
                { title = "Sessions",       padding = 1 },
                { section = "projects",     padding = 1 },
                { title = "Bookmarks",      padding = 1 },
                { section = "keys" },
            },
        },
        indent = { enabled = true },
        input = { enabled = true },
        notifier = { enabled = true },
        quickfile = { enabled = true },
        scroll = { enabled = true },
        statuscolumn = { enabled = true },
        words = { enabled = true },
        lazygit = {},
    },
    init = function()
        vim.g.snacks_animate = false
    end,
    keys = {
        -- 添加lazygit/快捷键
        { "<leader>lg", "<cmd>lua Snacks.lazygit.open(opts)<CR>",   desc = "Open Lazygit" },
        { "<leader>ll", "<cmd>lua Snacks.lazygit.log(opts)<CR>",    desc = "Open Lazygit log view" },
        { "<leader>lf", "<cmd>lua Snacks.lazygit.log(opts)<CR>",    desc = "Open Lazygit log of current file" },
        -- 添加dashboard快捷键
        { "<leader>ds", "<cmd>lua Snacks.dashboard.open(opts)<CR>", desc = "Open dashboard" },
    }
}
