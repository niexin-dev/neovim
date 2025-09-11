return {
    "dhananjaylatkar/cscope_maps.nvim",
    event = { "BufReadPost", "BufNewFile" },

    dependencies = {
        "ibhagwan/fzf-lua", -- optional [for picker="fzf-lua"]
        "nvim-lua/plenary.nvim"
    },
    -- config = function()
    --     require("cscope_maps").setup({
    --         skip_input_prompt = true,     -- "true" doesn't ask for input
    --         cscope = {
    --             picker = "fzf-lua"
    --         }
    --     })
    -- end,
    opts = {
        skip_input_prompt = true, -- "true" doesn't ask for input
        cscope = {
            picker = "fzf-lua",
            db_build_cmd = { script = "default", args = { "-bqR" } },
        },
    }
}
