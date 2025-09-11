return {
    "neovim/nvim-lspconfig",

    event = "VeryLazy",

    keys = {
        -- 设置查看头/源文件
        { "<leader>gh", "<cmd>LspClangdSwitchSourceHeader<cr>", desc = "Switch Source/Header (C/C++)" },
    },

    config = function()
        vim.lsp.config('*', {
            capabilities = {
                textDocument = {
                    semanticTokens = {
                        multilineTokenSupport = true,
                    }
                }
            },
            root_markers = { '.git' },
        })
        vim.lsp.config['clangd'] = {
            cmd = { 'clangd' },
            -- 修复在中文注释行下方插入新行导致的Change's rangeLength (1) doesn't match the computed range length (5)错误，造成error: -32602: trying to get AST for non-added document
            offset_encoding = 'utf-8',
            root_markers = { 'compile_commands.json', '.git' },
            vim.lsp.inlay_hint.enable(true)
        }
        -- mason-lspconfig会自动使能对应的lsp
        -- vim.lsp.enable('clangd')
    end
}
