return {
    'saghen/blink.cmp',
    event = "InsertEnter",
    dependencies = { "saghen/blink.compat" },
    -- optional: provides snippets for the snippet source
    -- dependencies = {
    --     'rafamadriz/friendly-snippets',
    --     "giuxtaposition/blink-cmp-copilot",
    -- },
    -- use a release tag to download pre-built binaries
    -- version = '*',
    -- AND/OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
    -- build = 'cargo build --release',
    -- If you use nix, you can build from source using latest nightly rust with:
    -- build = 'nix run .#build-plugin',
    build = "cargo build --release",

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
        -- 'default' for mappings similar to built-in completion
        -- 'super-tab' for mappings similar to vscode (tab to accept, arrow keys to navigate)
        -- 'enter' for mappings similar to 'super-tab' but with 'enter' to accept
        -- See the full "keymap" documentation for information on defining your own keymap.
        keymap = {
            preset = 'default',
        },

        appearance = {
            -- Sets the fallback highlight groups to nvim-cmp's highlight groups
            -- Useful for when your theme doesn't support blink.cmp
            -- Will be removed in a future release
            use_nvim_cmp_as_default = true,
            -- Set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
            -- Adjusts spacing to ensure icons are aligned
            nerd_font_variant = 'mono',
        },

        -- Default list of enabled providers defined so that you can extend it
        -- elsewhere in your config, without redefining it, due to `opts_extend`
        sources = {
            default = { 'lsp', 'path', 'snippets', 'buffer', 'cmdline', 'omni', 'codeium' },
            -- default = { 'lsp', 'path', 'snippets', 'buffer', 'cmdline', 'copilot' },
            -- providers = {
            --     copilot = {
            --         name = "copilot",
            --         module = "blink-cmp-copilot",
            --         score_offset = 100,
            --         async = true,
            --     },
            -- },
            --
            providers = {
                codeium = {
                    name = "codeium",
                    module = "blink.compat.source",
                    score_offset = 100,
                    async = true,
                },
                cmdline = {
                    -- ignores cmdline completions when executing shell commands
                    enabled = function()
                        return vim.fn.getcmdtype() ~= ':' or not vim.fn.getcmdline():match("^[%%0-9,'<>%-]*!")
                    end
                },
            },
        },
        -- 配置自动插入
        completion = {
            list = {
                selection = { preselect = true, auto_insert = true }
            },
            accept = { auto_brackets = { enabled = true } },  -- 自动添加括号
            documentation = { auto_show = true, auto_show_delay_ms = 200 },  -- 快速显示文档
			-- 图标在左，文本在右；统一去掉所有来源的前导空格
			menu = {
				draw = {
					-- 第一列：图标/种类（在左边）
					-- 第二列：label 与可选的 label_description（在右边）
					columns = {
						-- { "kind_icon", "kind" },
						{ "kind_icon" },
						{ "label", "label_description", gap = 1 },
					},
					components = {
						-- 图标后面补 1 格，让文本不贴图标
						kind_icon = {
							text = function(ctx)
								return (ctx.kind_icon or "") .. " "
							end,
						},
						-- 去掉 label 的所有前导空白，不再额外补空格
						label = {
							text = function(ctx)
								return (ctx.label or ""):gsub("^%s+", "")
							end,
						},
						-- 可选：描述也去掉前导空白
						label_description = {
							text = function(ctx)
								return (ctx.label_description or ""):gsub("^%s+", "")
							end,
						},
					},
				},
			},
        },
    },
    opts_extend = { "sources.default" }
}
