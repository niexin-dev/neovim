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
            http = {
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
                                default = "gemini-2.5-flash-preview-05-20" -- 默认模型
                            }
                        },
                    })
                end,
                openai = function()
                    return require("codecompanion.adapters").extend("openai", {
                        env = {
                            api_key =
                            "REDACTED", -- API密钥（建议改用环境变量）
                        },
                        schema = {
                            model = {
                                default = "gpt-4o" -- 默认模型
                            }
                        },
                    })
                end
            },
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
                                [[
你是一位精通 Conventional Commits 的软件工程师和代码分析专家。请基于下方提供的 git diff，生成一份符合规范的中文 Git 提交信息。

输出必须包含：提交头（Header）、正文（Body）、脚注（Footer 可选）。严格遵循以下结构与规则，不要输出任何思考过程或解释。

[输入]
git diff:
```diff
%s
```

[提交头（Header）]
- 类型：从 feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert 中选择最精确者
- 范围：可选，(module) 形式，依据主要受影响模块/路径
- 主题：首字母小写，祈使句，≤50 字，末尾无标点，不含实现细节

[正文（Body）]
按以下小节输出，每小节需要换行，每项 1–3 句，聚焦高层逻辑：
问题根源：

解决方案：

影响面：
• 对用户：
• 对开发者：
• 潜在风险：

关键变更点：
• ...
• ...
• ...

[脚注（Footer，可选）]
- BREAKING CHANGE: 若存在不兼容变更，描述影响与迁移方案
- 关联 Issue: Closes #...
- 关联 PR/MR: Refs !...

[判定准则]
- 若 diff 涉及多关注点：在正文首段说明“检测到多关注点，建议拆分提交”，当前输出仅覆盖主轴变更
- 类型选择：按新增能力→feat；缺陷修复→fix；性能→perf；重构不改行为→refactor；测试→test；文档→docs；构建/依赖/流水线→build/ci；杂项→chore；回滚→revert
- 范围推断：依据路径公共前缀（如 src/auth/→(auth)；packages/api/→(api)）
- 风险识别：若出现接口签名/默认值/配置键/协议格式/数据模式/版本约束的破坏性变更，必须给出 BREAKING CHANGE 与迁移提示
- 不确定项：无法从 diff 明确判断时，使用“无明显变化/不影响对外接口/风险有限”等客观表述补齐
- 关键变更点：使用“• ”作为每条要点前缀，3–6 条为宜

---
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
