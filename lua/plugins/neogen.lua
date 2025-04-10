return {
    "danymat/neogen",
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = true,
    cmd = "Neogen",
    keys = {
        {
            "<leader>dc", -- 设置快捷键为 <leader>cn（你可以根据需要更改）
            function()
                require("neogen").generate({})
            end,
            desc = "Generate Annotation (Neogen)", -- 快捷键描述
        },
    },
}
