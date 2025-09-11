return {
    "danymat/neogen",
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = true,
    cmd = "Neogen",
    keys = {
        {
            "<leader>ge", -- 生成注释
            function()
                require("neogen").generate({})
            end,
            desc = "Generate Annotation (Neogen)", -- 快捷键描述
        },
    },
}
