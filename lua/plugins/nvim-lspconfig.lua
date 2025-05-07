return {
    "neovim/nvim-lspconfig",

    lazy = false,

    keys = {
        -- 设置查看头/源文件
        { "<leader>gh", "<cmd>ClangdSwitchSourceHeader<cr>", desc = "Switch Source/Header (C/C++)" },
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
            root_markers = { 'compile_commands.json', '.git' },
            vim.lsp.inlay_hint.enable(true)
        }
        vim.lsp.enable('clangd')
    end
}
