return {
    "ibhagwan/fzf-lua",
    lazy = false,
    keys={
        { "<leader>fb", "<cmd>FzfLua buffers sort_mru=true sort_lastused=true<cr>", desc = "Buffers" },
        { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Files" },
        { "<leader>fl", "<cmd>FzfLua blines<cr>", desc = "Lines" },
        -- search
        { "<leader>fs", "<cmd>FzfLua grep<cr>", desc = "Grep" },
        { "<leader>fr", "<cmd>FzfLua grep_cword<cr>", desc = "Grep word" },
        -- git
        { "<leader>gc", "<cmd>FzfLua git_commits<CR>", desc = "Commits" },
        { "<leader>gs", "<cmd>FzfLua git_status<CR>", desc = "Status" },
        -- lsp
        {"<leader>gd", "<cmd>FzfLua lsp_definitions<CR>", desc = "LSP Definitions"},
        {"<leader>gr", "<cmd>FzfLua lsp_references<CR>", desc = "LSP References"},
        {"<leader>gD", "<cmd>FzfLua lsp_declarations<CR>", desc = "LSP Declarations"},
        {"<leader>gs", "<cmd>FzfLua lsp_live_workspace_symbols<CR>", desc = "LSP Symbols"},

    },
    opts = {},
}
