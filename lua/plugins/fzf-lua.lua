return {
    "ibhagwan/fzf-lua",
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    lazy = false,
    keys={
        { "<leader>b", "<cmd>FzfLua buffers sort_mru=true sort_lastused=true<cr>", desc = "Buffers" },
        { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Files" },
        { "<leader>fl", "<cmd>FzfLua blines<cr>", desc = "Lines" },
        { "<leader>ft", "<cmd>FzfLua treesitter<cr>", desc = "Treesitter" },
        -- search
        { "<leader>fw", "<cmd>FzfLua grep<cr>", desc = "Grep" },
        { "<leader>fr", "<cmd>FzfLua grep_cword<cr>", desc = "Grep word" },
        { "<leader>fs", "<cmd>FzfLua tags<cr>", desc = "Tags" },
        -- git
        -- { "<leader>Gc", "<cmd>FzfLua git_commits<CR>", desc = "Commits" },
        -- { "<leader>Gs", "<cmd>FzfLua git_status<CR>", desc = "Status" },
        -- lsp
        {"<leader>gd", "<cmd>FzfLua lsp_definitions<CR>", desc = "LSP Definitions"},
        {"<leader>gr", "<cmd>FzfLua lsp_references<CR>", desc = "LSP References"},
        {"<leader>gD", "<cmd>FzfLua lsp_declarations<CR>", desc = "LSP Declarations"},
        {"<leader>gs", "<cmd>FzfLua lsp_live_workspace_symbols<CR>", desc = "LSP Symbols"},
        {"<leader>gi", "<cmd>FzfLua lsp_incoming_calls<CR>", desc = "LSP Incoming"},
        {"<leader>go", "<cmd>FzfLua lsp_outgoing_calls<CR>", desc = "LSP Outgoing"},
        {"<leader>qf", "<cmd>FzfLua lsp_code_actions<CR>", desc = "LSP Code action"},

    },
    opts = {},
}
