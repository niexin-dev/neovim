return {
	"folke/tokyonight.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		-- 设置主题
		-- colorscheme tokyonight-night
		-- colorscheme tokyonight-storm
		-- colorscheme tokyonight-day
		-- colorscheme tokyonight-moon
		vim.cmd([[colorscheme tokyonight-night]])
	end,
}
