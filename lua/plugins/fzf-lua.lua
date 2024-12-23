return {
    "ibhagwan/fzf-lua",
    lazy = false,
    keys={
        { "<leader>fb", "<cmd>FzfLua buffers sort_mru=true sort_lastused=true<cr>", desc = "Buffers" },
        { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Files" },
        { "<leader>fl", "<cmd>FzfLua blines<cr>", desc = "Files" },
        -- search
        { "<leader>fs", "<cmd>FzfLua grep<cr>", desc = "Grep" },
        { "<leader>fr", "<cmd>FzfLua grep_cword<cr>", desc = "Grep word" },
        -- git
        { "<leader>gc", "<cmd>FzfLua git_commits<CR>", desc = "Commits" },
        { "<leader>gs", "<cmd>FzfLua git_status<CR>", desc = "Status" },
    },
    opts = {},
}
