return {
    "olimorris/codecompanion.nvim",
    dependencies = {
        --other plugins
        "ravitemer/codecompanion-history.nvim"
    },
    keys = {
        { "<leader>dh", "<cmd>CodeCompanionHistory<cr>", desc = "CodeCompanionHistory" },
    },
}
