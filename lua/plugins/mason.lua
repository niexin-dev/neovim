return {
    {
        "williamboman/mason.nvim",
        cmd = { "Mason", "MasonInstall", "MasonUpdate" },
        opts = {
            ui = {
                icons = {
                    package_installed = "✓",
                    package_pending = "➜",
                    package_uninstalled = "✗",
                },
            },
            -- 将非 LSP 的工具放在这里，让 Mason 来安装它们
            ensure_installed = {
                "clang-format", -- C/C++ 格式化工具
                "prettier",     -- JS/JSON/MD 格式化工具
                "shellcheck",   -- Shell 脚本 linter
                "shfmt",        -- Shell 脚本格式化工具
                "stylua",       -- Lua 格式化工具
            },
        }
    },
    {
        "williamboman/mason-lspconfig.nvim",
        event = "VeryLazy",
        opts = {
            -- 这里只放 nvim-lspconfig 支持的 LSP 服务器名称
            ensure_installed = {
                "bashls", -- nvim-lspconfig 中 bash-language-server 的名称是 bashls
                "clangd",
                "lua_ls", -- nvim-lspconfig 中 lua-language-server 的名称是 lua_ls
                "marksman",
                "taplo",  -- 这会安装 taplo CLI 工具和 LSP 服务器"
            },
        }
    }
}
