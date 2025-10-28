return {
	"ggandor/leap.nvim",
	dependencies = { "tpope/vim-repeat" }, -- enable '.' repeat support
	-- lazy-load when user presses these keys (use <Plug> mappings provided by leap)
	keys = {
		-- 's' in normal/visual/operator-pending modes -> <Plug>(leap)
		{
			"s",
			"<Plug>(leap)",
			mode = { "n", "x", "o" },
			desc = "Leap: jump (forward)",
			noremap = true,
			silent = true,
		},

		-- 'S' in normal mode -> <Plug>(leap-from-window)
		{
			"S",
			"<Plug>(leap-from-window)",
			mode = "n",
			desc = "Leap: jump from window",
			noremap = true,
			silent = true,
		},
	},
	opts = {},
}
