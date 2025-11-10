return {
	{
		"niexin-dev/litee.nvim",
		event = "VeryLazy",
		opts = {
			notify = { enabled = false },
			panel = {
				orientation = "bottom",
				panel_size = 10,
			},
		},
		config = function(_, opts)
			require("litee.lib").setup(opts)
		end,
	},

	{
		"niexin-dev/litee-calltree.nvim",
		dependencies = "niexin-dev/litee.nvim",
		event = "VeryLazy",
		opts = {
			-- panel 在bottom显示窗口
			-- popout 弹出浮动窗口
			on_open = "popout",
			map_resize_keys = false,
			keymaps = {
				toggle = "<tab>",
			},
		},
		keys = {
			-- Incoming / Outgoing 调用树
			{
				"<leader>gi",
				function()
					vim.lsp.buf.incoming_calls()
				end,
				desc = "LSP: Incoming Calls (Calltree)",
			},
			{
				"<leader>go",
				function()
					vim.lsp.buf.outgoing_calls()
				end,
				desc = "LSP: Outgoing Calls (Calltree)",
			},
			{ "<leader>gp", "<cmd>LTPopOutCalltree<CR>", desc = "LSP: Calltree PopOut" },
		},
		config = function(_, opts)
			require("litee.calltree").setup(opts)
		end,
	},
}
