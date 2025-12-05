return {
	"fei6409/log-highlight.nvim",
	event = "BufReadPre", -- 或 "VeryLazy"
	config = function()
		require("log-highlight").setup({
			extension = { "log", "txt" },
		})
	end,
}
