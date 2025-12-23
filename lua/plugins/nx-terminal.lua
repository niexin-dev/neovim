return {
	name = "nx-terminal",
	dir = vim.fn.stdpath("config") .. "/lua/nx/nx-terminal",
	keys = {
		{
			"<leader>fw",
			function()
				require("nx-terminal").new()
			end,
			desc = "New terminal",
		},
		{
			"<leader>fa",
			function()
				require("nx-terminal").toggle()
			end,
			desc = "Toggle terminal",
		},
		{
			"<leader>m",
			function()
				require("nx-terminal").zoom_toggle()
			end,
			desc = "Zoom",
		},
		{ "<C-j>", [[<C-\><C-n>]], mode = "t", desc = "Terminal escape" },
	},
	config = function()
		require("nx-terminal").setup()
	end,
}
