local function notify_build_result(code, stderr)
	if code == 0 then
		vim.notify("blink.cmp: cargo build succeeded", vim.log.levels.INFO)
	else
		vim.notify(string.format("blink.cmp: cargo build failed (%d)\n%s", code, stderr or ""), vim.log.levels.ERROR)
	end
end

local function build_from_source(plugin)
	if vim.fn.executable("cargo") ~= 1 then
		vim.notify("blink.cmp: cargo executable not found, skipped source build", vim.log.levels.WARN)
		return
	end

	local command = { "cargo", "build", "--release" }
	if vim.system then
		local result = vim.system(command, { text = true, cwd = plugin.dir }):wait()
		notify_build_result(result.code, result.stderr)
		return
	end

	local prev_cwd = vim.fn.getcwd()
	local ok = pcall(vim.fn.chdir, plugin.dir)
	local output = vim.fn.system(command)
	if ok then
		pcall(vim.fn.chdir, prev_cwd)
	end
	notify_build_result(vim.v.shell_error, output)
end

return {
	"saghen/blink.cmp",
	event = "InsertEnter",
	-- dependencies = { "saghen/blink.compat" },
	-- 设为 false 以始终拉取 main 分支的最新源码
	version = false,
	-- 如需 snippet 来源，可在此添加相应依赖
	-- dependencies = {
	--     'rafamadriz/friendly-snippets',
	--     "giuxtaposition/blink-cmp-copilot",
	-- },
	-- 使用发布标签来下载预构建的二进制文件
	-- 或者从源码构建，需要 nightly 版 Rust：https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
	-- 如果使用 Nix，可以通过最新的 nightly Rust 执行下列命令构建：
	-- build = 'nix run .#build-plugin', -- Nix 构建示例
	build = build_from_source,

	---@module 'blink.cmp'
	---@type blink.cmp.Config
	opts = {
		-- “default”：与内置补全类似的按键映射
		-- “super-tab”：与 VS Code 类似的按键映射（Tab 接受、方向键导航）
		-- “enter”：类似于 “super-tab”，但使用 Enter 接受补全
		-- 可前往完整的 “keymap” 文档了解如何自定义映射。
		keymap = {
			preset = "default",
		},

		appearance = {
			-- 将后备高亮组设置为 nvim-cmp 的高亮组
			-- 当主题不支持 blink.cmp 时非常有用
			-- 计划在未来的版本中移除
			use_nvim_cmp_as_default = true,
			-- 设为 “mono” 以匹配 Nerd Font Mono，或设为 “normal” 以匹配 Nerd Font
			-- 调整间距以确保图标对齐
			nerd_font_variant = "mono",
		},

		-- 默认启用的来源列表，方便在其他配置中扩展
		-- 当前不需要 snippet 功能，故未启用相关来源
		-- 借助 `opts_extend`，无需重新定义即可在其他地方扩展
		sources = {
			default = { "lsp", "path", "buffer", "cmdline", "omni", "codeium" },
			-- default = { 'lsp', 'path', 'snippets', 'buffer', 'cmdline', 'copilot' }, -- 示例
			-- providers = { -- 其他来源示例
			--     copilot = {
			--         name = "copilot",
			--         module = "blink-cmp-copilot",
			--         score_offset = 100,
			--         async = true,
			--     },
			-- },
			-- 示例结束
			providers = {
				codeium = {
					name = "codeium",
					module = "codeium.blink",
					score_offset = 100,
					async = true,
					-- ⬇⬇⬇ 新增：在无名 buffer / 特殊 buftype 里禁用 codeium
					enabled = function(ctx)
						local bufnr = ctx and ctx.bufnr or vim.api.nvim_get_current_buf()
						local name = vim.api.nvim_buf_get_name(bufnr)
						if name == nil or name == "" then
							return false
						end

						-- 可选：只在普通文件里启用（避免在 help / quickfix 里请求）
						local bt = vim.bo[bufnr].buftype
						return bt == "" -- normal buffers only
					end,
				},
				cmdline = {
					-- 在执行 shell 命令时忽略命令行补全
					enabled = function()
						return vim.fn.getcmdtype() ~= ":" or not vim.fn.getcmdline():match("^[%%0-9,'<>%-]*!")
					end,
				},
			},
		},
		-- 配置自动插入
		completion = {
			list = {
				selection = { preselect = true, auto_insert = true },
			},
			accept = { auto_brackets = { enabled = true } }, -- 自动添加括号
			documentation = { auto_show = true, auto_show_delay_ms = 200 }, -- 快速显示文档
		},
	},
	opts_extend = { "sources.default" },
}
