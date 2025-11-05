return {
	"Exafunction/windsurf.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	event = "VeryLazy",
	config = function()
		require("codeium").setup({
			enable_chat = false, -- 禁用聊天
			enable_cmp_source = false,
		})
	end,
}
