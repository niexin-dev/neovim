return {
    "Exafunction/codeium.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    event = { "BufReadPost", "InsertEnter" },
    config = function()
        require("codeium").setup({
        })
    end
}
