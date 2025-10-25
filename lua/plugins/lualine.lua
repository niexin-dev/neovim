return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	event = "VeryLazy",
	opts = {
		icons_enabled = true,
		theme = "tokyonight",
		component_separators = { left = "", right = "" },
		section_separators = { left = "", right = "" },
		disabled_filetypes = {
			statusline = {},
			winbar = {},
		},
		ignore_focus = {},
		always_divide_middle = true,
		always_show_tabline = true,
		globalstatus = false,
		refresh = {
			statusline = 100,
			tabline = 100,
			winbar = 100,
		},
		sections = {
			lualine_a = { "mode" },
			lualine_b = { "branch", "diff", "diagnostics" },
			lualine_c = {
				{ "filename", path = 1 },
				function()
					return require("nvim-treesitter").statusline({
						indicator_size = 100,
						type_patterns = { "class", "function", "method" },
						transform_fn = function(line, node)
							local node_type = node:type()

							-- 检查节点类型，如果是存储类别指示符、类型指示符或基本类型等，则返回空字符串，不包含在状态行中
							if
								node_type == "storage_class_specifier"
								or node_type == "type_specifier"
								or node_type == "primitive_type"
								or node_type == "struct_specifier"
							then
								return ""
							end

							-- 从行中提取函数名：
							-- 1. 匹配到第一个开括号 '(' 之前的所有内容
							local before_params = line:match("^(.-)%s*%(")
							if not before_params then
								-- 如果没有括号，就取整行内容
								before_params = line
							end

							-- 2. 从“类型 函数名”部分中提取最后一个单词（即函数名）
							local func_name = before_params:match("[%w_]+$")

							return func_name or ""
						end,

						separator = " -> ",
						allow_duplicates = false,
					})
				end,
			},
			lualine_x = { "encoding", "fileformat", "filetype" },
			lualine_y = { "progress" },
			lualine_z = { "location" },
		},
		inactive_sections = {
			lualine_a = {},
			lualine_b = {},
			lualine_c = { { "filename", path = 1 } },
			lualine_x = { "location" },
			lualine_y = {},
			lualine_z = {},
		},
		tabline = {},
		winbar = {},
		inactive_winbar = {},
		extensions = {},
	},
}
