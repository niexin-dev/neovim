-- 返回一个Lua表，描述插件配置（符合lazy.nvim规范）
return {
    -- 插件GitHub仓库地址
    "olimorris/codecompanion.nvim",
    -- 自动加载默认配置
    config = true,
    -- 声明依赖的其他插件
    dependencies = {
        "nvim-lua/plenary.nvim",           -- 提供Lua工具函数
        "nvim-treesitter/nvim-treesitter", -- 语法分析
    },
    lazy = false,
    version = "*",
    -- 自定义配置选项
    opts = {
        -- 全局选项
        opts = {
            language = "Chinese", -- 设置默认语言为中文
            -- log_level = "TRACE",  -- TRACE|DEBUG|ERROR|INFO
        },
        -- 定义不同策略使用的适配器
        strategies = {
            chat = {                -- 聊天模式
                adapter = "gemini", -- 使用deepseek适配器
            },
            inline = {              -- 行内编辑模式
                adapter = "gemini",
            },
            cmd = { -- 命令行模式
                adapter = "gemini",
            }
        },
        -- 适配器具体配置
        adapters = {
            deepseek = function() -- deepseek适配器定义
                return require("codecompanion.adapters").extend("deepseek", {
                    env = {
                        api_key = "REDACTED", -- API密钥（建议改用环境变量）
                    },
                    schema = {
                        model = {
                            default = "deepseek-chat" -- 默认模型
                        }
                    },
                })
            end,
            gemini = function()
                return require("codecompanion.adapters").extend("gemini", {
                    env = {
                        api_key = "REDACTED", -- API密钥（建议改用环境变量）
                    },
                    schema = {
                        model = {
                            default = "gemini-2.0-flash-exp" -- 默认模型
                        }
                    },
                })
            end
        },
        -- 预定义提示库
        prompt_library = {
            -- 名为"Generate a Commit Message"的提示
            ["Generate a Commit Message"] = {
                strategy = "chat",                         -- 使用聊天策略
                description = "Generate a commit message", -- 描述
                opts = {
                    index = 10,                            -- 排序位置
                    is_default = true,                     -- 设为默认提示
                    is_slash_cmd = true,                   -- 支持斜杠命令
                    short_name = "nxcmt",                  -- 快捷名称
                    auto_submit = true,                    -- 自动提交
                },
                -- 提示内容定义
                prompts = {
                    {
                        role = "user",       -- 用户角色
                        content = function() -- 动态生成内容
                            return string.format(
                                [[你是一位精通 Conventional Commit 规范的专家。请根据下方提供的 git diff 内容，为我生成符合规范的中文提交信息：

```diff
%s
```
]],
                                vim.fn.system("git diff --no-ext-diff --staged") -- 获取暂存区diff
                            )
                        end,
                        opts = {
                            contains_code = true, -- 标记包含代码
                        },
                    },
                },
            },
        },
        extensions = {
            history = {
                enabled = true,
                opts = {
                    -- Keymap to open history from chat buffer (default: gh)
                    keymap = "gh",
                    -- Keymap to save the current chat manually (when auto_save is disabled)
                    save_chat_keymap = "sc",
                    -- Save all chats by default (disable to save only manually using 'sc')
                    auto_save = true,
                    -- Number of days after which chats are automatically deleted (0 to disable)
                    expiration_days = 0,
                    -- Picker interface (auto resolved to a valid picker)
                    picker = "fzf-lua", --- ("telescope", "snacks", "fzf-lua", or "default")
                    ---Automatically generate titles for new chats
                    auto_generate_title = true,
                    title_generation_opts = {
                        ---Adapter for generating titles (defaults to current chat adapter)
                        adapter = nil,               -- "copilot"
                        ---Model for generating titles (defaults to current chat model)
                        model = nil,                 -- "gpt-4o"
                        ---Number of user prompts after which to refresh the title (0 to disable)
                        refresh_every_n_prompts = 0, -- e.g., 3 to refresh after every 3rd user prompt
                        ---Maximum number of times to refresh the title (default: 3)
                        max_refreshes = 3,
                    },
                    ---On exiting and entering neovim, loads the last chat on opening chat
                    continue_last_chat = false,
                    ---When chat is cleared with `gx` delete the chat from history
                    delete_on_clearing_chat = false,
                    ---Directory path to save the chats
                    dir_to_save = vim.fn.stdpath("data") .. "/codecompanion-history",
                    ---Enable detailed logging for history extension
                    enable_logging = false,
                }
            }
        }
    },
    -- 快捷键绑定
    keys = {
        {
            "<leader>dm",                                -- 快捷键组合
            function()                                   -- 执行函数
                require("codecompanion").prompt("nxcmt") -- 触发nxcmt提示
            end,
            desc = "Generate commit message",            -- 描述
            mode = "n",                                  -- 普通模式生效
            noremap = true,                              -- 非递归映射
            silent = true,                               -- 静默执行
        },
        { "<leader>di", "<cmd>CodeCompanionChat<cr>", desc = "CodeCompanionChat" },
    },
}
