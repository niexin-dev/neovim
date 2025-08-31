return {
    "nvim-pack/nvim-spectre",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
        {
            "<leader>sr",
            '<cmd>lua require("spectre").toggle()<CR>',
            mode = "n",
            desc = "Toggle Spectre",
        },
        {
            "<leader>sw",
            '<cmd>lua require("spectre").open_visual({select_word=true})<CR>',
            mode = "n",
            desc = "Search current word",
        },
        {
            "<leader>sw",
            '<esc><cmd>lua require("spectre").open_visual()<CR>',
            mode = "v",
            desc = "Search current word",
        },
        {
            "<leader>sp",
            '<cmd>lua require("spectre").open_file_search({select_word=true})<CR>',
            mode = "n",
            desc = "Search on current file",
        },
    },
}
