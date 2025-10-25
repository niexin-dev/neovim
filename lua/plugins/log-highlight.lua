return {
	"fei6409/log-highlight.nvim",
	ft = { "log", "txt" },
	config = function()
		require("log-highlight").setup({
			extension = { "log", "txt" },
		})
	end,
}
