return {
	"windwp/nvim-autopairs",
	event = "InsertEnter",
	opts = {
		check_ts = true, -- 使用 treesitter 检查语法
		ts_config = {
			lua = { "string" }, -- 在 lua 字符串中不自动配对
			javascript = { "template_string" },
			c = { "string", "comment" }, -- 在 C 字符串和注释中不自动配对
			cpp = { "string", "comment" }, -- 在 C++ 字符串和注释中不自动配对
		},
	},
}
