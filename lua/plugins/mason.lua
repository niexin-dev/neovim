return {
    {
        "williamboman/mason.nvim",
        opts = {
            ui = {
                icons = {
                    package_installed = "✓",
                    package_pending = "➜",
                    package_uninstalled = "✗",
                },
            },
        }
    },
    {
        -- ✓ bash-language-server bashls
        -- ✓ clang-format
        -- ✓ clangd
        -- ✓ lua-language-server lua_ls
        -- ✓ shellcheck
        -- ✓ shfmt

        "williamboman/mason-lspconfig.nvim",
        opts = {
            ensure_installed = { "clangd", "bashls", "lua_ls" },
        }
    },
}
