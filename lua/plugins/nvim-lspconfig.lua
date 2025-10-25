return {
    "neovim/nvim-lspconfig",

    -- 仅在读取 / 创建文件缓冲区时加载，避免在启动时抢占资源
    event = { "BufReadPre", "BufNewFile" },

    keys = {
        -- 设置查看头/源文件
        { "<leader>gh", "<cmd>LspClangdSwitchSourceHeader<cr>", desc = "Switch Source/Header (C/C++)" },
    },

    config = function()
        local blink_capabilities = {}

        local ok, blink_cmp = pcall(require, "blink.cmp")
        if ok and blink_cmp.get_lsp_capabilities then
            blink_capabilities = blink_cmp.get_lsp_capabilities()
        end

        local capabilities = vim.tbl_deep_extend("force", blink_capabilities, {
            textDocument = {
                semanticTokens = {
                    multilineTokenSupport = true,
                }
            }
        })

        vim.lsp.config('*', {
            capabilities = capabilities,
        })

        -- stylua 仅作为外部格式化器使用，避免其通过 LSP 再次附着到 Lua 缓冲区
        local stylua_cfg = vim.lsp.config['stylua']
        if stylua_cfg then
            stylua_cfg.autostart = false
            stylua_cfg.cmd = nil
        end

        local uv = vim.uv or vim.loop

        vim.lsp.config['clangd'] = {
            cmd = {
                'clangd',
                '--background-index',
                '--clang-tidy',
                '--completion-style=detailed',
                '--function-arg-placeholders',
                '--header-insertion=never',
            },
            -- 修复在中文注释行下方插入新行导致的Change's rangeLength (1) doesn't match the computed range length (5)错误，造成error: -32602: trying to get AST for non-added document
            offset_encoding = 'utf-8',
            init_options = {
                clangdFileStatus = true,
            },
            root_markers = {
                'compile_commands.json',
                'compile_flags.txt',
                '.clangd',
                '.clang-tidy',
                '.git',
            },
            on_new_config = function(new_config, root_dir)
                local candidate_dirs = {
                    root_dir,
                    vim.fs.joinpath(root_dir, 'build'),
                    vim.fs.joinpath(root_dir, 'cmake-build-debug'),
                    vim.fs.joinpath(root_dir, 'cmake-build-release'),
                }

                for _, dir in ipairs(candidate_dirs) do
                    local compile_commands = vim.fs.joinpath(dir, 'compile_commands.json')
                    if uv.fs_stat(compile_commands) then
                        new_config.cmd = vim.deepcopy(new_config.cmd)
                        table.insert(new_config.cmd, '--compile-commands-dir=' .. dir)
                        break
                    end
                end
            end,
        }

        -- 兼容 0.10 之前与之后的 enable 调用方式（旧版传 bufnr，新版传 opts 表）
        local function enable_inlay_hints(bufnr)
            local hint = vim.lsp.inlay_hint
            if not (hint and hint.enable) then
                return
            end

            if not pcall(hint.enable, true, bufnr) then
                hint.enable(true, { bufnr = bufnr })
            end
        end

        -- semantic tokens 同样在不同版本之间存在签名差异
        local function enable_semantic_tokens(client, bufnr)
            local semantic = vim.lsp.semantic_tokens
            if not (semantic and semantic.enable) then
                return
            end

            if not pcall(semantic.enable, true, bufnr) then
                semantic.enable(true, { bufnr = bufnr, client = client })
            end
        end

        local augroup = vim.api.nvim_create_augroup('UserLspCapabilities', { clear = true })
        vim.api.nvim_create_autocmd('LspAttach', {
            group = augroup,
            desc = '按需启用 LSP 功能，避免在不支持的服务器上浪费资源',
            callback = function(event)
                local client = vim.lsp.get_client_by_id(event.data.client_id)
                if not client then
                    return
                end

                local bufnr = event.buf

                if client.name == 'stylua' then
                    client:stop()
                    return
                end

                if client:supports_method('textDocument/inlayHint') then
                    enable_inlay_hints(bufnr)
                end

                if client:supports_method('textDocument/semanticTokens/full')
                    or client:supports_method('textDocument/semanticTokens/range') then
                    enable_semantic_tokens(client, bufnr)
                end
            end,
        })
        -- mason-lspconfig会自动使能对应的lsp
        -- vim.lsp.enable('clangd')
    end
}
