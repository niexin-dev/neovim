return {
	"dhananjaylatkar/cscope_maps.nvim",
	ft = { "c", "cpp", "h", "hpp" },

	dependencies = {
		"ibhagwan/fzf-lua", -- optional [for picker="fzf-lua"]
		"nvim-lua/plenary.nvim",
	},
	-- config = function()
	--     require("cscope_maps").setup({
	--         skip_input_prompt = true,     -- "true" doesn't ask for input
	--         cscope = {
	--             picker = "fzf-lua"
	--         }
	--     })
	-- end,
	keys = {
		{ "<leader>cj", "<cmd>CsStackView open down<cr>", desc = "Cscope StackView Down" },
		{ "<leader>ck", "<cmd>CsStackView open up<cr>", desc = "Cscope StackView Up" },
	},
	opts = {
		skip_input_prompt = true, -- "true" doesn't ask for input
		cscope = {
			picker = "fzf-lua",
			db_build_cmd = { script = "default", args = { "-bqR" } },
		},
	},
}
