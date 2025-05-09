return {
    'tpope/vim-fugitive',
    lazy = false,

    keys = {
        { "<leader>gg", "<cmd>Git<cr>",       desc = "vim-fugitive" },
        { "<leader>gb", "<cmd>Git blame<cr>", desc = "Git blame" }
    }
}
