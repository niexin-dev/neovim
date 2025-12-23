return {
	name = "nx-dashboard",
	dir = vim.fn.stdpath("config") .. "/lua/nx/nx-dashboard",
	lazy = false,
	priority = 1000,
	config = function()
		require("nx-dashboard").setup({
			-- 这里可覆盖你的配置
			-- use_icons = true,
			-- auto_open_on_uienter = true,
			-- map_open = "<leader>fd",
			-- cmd_open = "Dashboard", -- 想改成 NxDashboard 也可以
		})
	end,
}
