return {
    "Exafunction/codeium.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    event = "VeryLazy",
    priority = 1000,
    config = function()
        require("codeium").setup({
            enable_chat = false, -- 禁用聊天
        })
    end,
}
