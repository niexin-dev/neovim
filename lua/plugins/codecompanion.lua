return {
    "olimorris/codecompanion.nvim",
    config = true,
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
    },
    opts = {
        opts = {
            language = "Chinese",
        },
        prompt_library = {
            ["Generate a Commit Message"] = {
                strategy = "chat",
                description = "Generate a commit message",
                opts = {
                    index = 10,
                    is_default = true,
                    is_slash_cmd = true,
                    short_name = "nxcmt",
                    auto_submit = true,
                },
                prompts = {
                    {
                        role = "user",
                        content = function()
                            return string.format(
                                [[你是一位精通 Conventional Commit 规范的专家。请根据下方提供的 git diff 内容，为我生成符合规范的中文提交信息：

```diff
%s
```
]],
                                vim.fn.system("git diff --no-ext-diff --staged")
                            )
                        end,
                        opts = {
                            contains_code = true,
                        },
                    },
                },
            },

        },
    },
    keys = {
        {
            "<leader>dm", -- 你可以自定义快捷键
            function()
                require("codecompanion").prompt("nxcmt")
            end,
            desc = "Generate commit message",
            mode = "n",
            noremap = true,
            silent = true,
        },
    },
}
