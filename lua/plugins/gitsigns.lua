return {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPost", "BufNewFile", "BufWritePre" },

    opts = {
        signs                        = {
            add          = { text = '┃' },
            change       = { text = '┃' },
            delete       = { text = '_' },
            topdelete    = { text = '‾' },
            changedelete = { text = '~' },
            untracked    = { text = '┆' },
        },
        signs_staged                 = {
            add          = { text = '┃' },
            change       = { text = '┃' },
            delete       = { text = '_' },
            topdelete    = { text = '‾' },
            changedelete = { text = '~' },
            untracked    = { text = '┆' },
        },
        signs_staged_enable          = true,
        signcolumn                   = true,  -- Toggle with `:Gitsigns toggle_signs`
        numhl                        = true,  -- Toggle with `:Gitsigns toggle_numhl`
        linehl                       = true,  -- Toggle with `:Gitsigns toggle_linehl`
        word_diff                    = false, -- Toggle with `:Gitsigns toggle_word_diff`
        watch_gitdir                 = {
            interval = 1000,
            follow_files = true
        },
        auto_attach                  = true,
        attach_to_untracked          = true,
        current_line_blame           = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
        current_line_blame_opts      = {
            virt_text = true,
            virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
            delay = 1000,
            ignore_whitespace = false,
            virt_text_priority = 100,
            use_focus = true,
        },
        current_line_blame_formatter = '<author>, <author_time:%R> - <summary>',
        sign_priority                = 6,
        update_debounce              = 100,
        status_formatter             = nil,   -- Use default
        max_file_length              = 40000, -- Disable if file is longer than this (in lines)
        preview_config               = {
            -- Options passed to nvim_open_win
            border = 'single',
            style = 'minimal',
            relative = 'cursor',
            row = 0,
            col = 1
        },
        on_attach                    = function()
            vim.api.nvim_set_keymap("n", "<leader>gj", "<cmd>Gitsigns next_hunk<CR>", { silent = true, noremap = true })
            vim.api.nvim_set_keymap("n", "<leader>gk", "<Cmd>Gitsigns prev_hhunk<CR>", { silent = true, noremap = true })
            vim.api.nvim_set_keymap('n', '<leader>hs', ':Gitsigns stage_hunk<CR>', { silent = true, noremap = true })
            vim.api.nvim_set_keymap('v', '<leader>hs', ':Gitsigns stage_hunk<CR>', { silent = true, noremap = true })
            vim.api.nvim_set_keymap('n', '<leader>hr', ':Gitsigns reset_hunk<CR>', { silent = true, noremap = true })
            vim.api.nvim_set_keymap('v', '<leader>hr', ':Gitsigns reset_hunk<CR>', { silent = true, noremap = true })
            vim.api.nvim_set_keymap('n', '<leader>hS', '<cmd>Gitsigns stage_buffer<CR>',
                { silent = true, noremap = true })
            vim.api.nvim_set_keymap('n', '<leader>hu', '<cmd>Gitsigns undo_stage_hunk<CR>',
                { silent = true, noremap = true })
            vim.api.nvim_set_keymap('n', '<leader>hR', '<cmd>Gitsigns reset_buffer<CR>',
                { silent = true, noremap = true })
            vim.api.nvim_set_keymap('n', '<leader>hp', '<cmd>Gitsigns preview_hunk<CR>',
                { silent = true, noremap = true })
            vim.api.nvim_set_keymap('n', '<leader>hb', '<cmd>lua require"gitsigns".blame_line{full=true}<CR>',
                { silent = true, noremap = true })
            vim.api.nvim_set_keymap('n', '<leader>tb', '<cmd>Gitsigns toggle_current_line_blame<CR>',
                { silent = true, noremap = true })
            vim.api.nvim_set_keymap('n', '<leader>hd', '<cmd>Gitsigns diffthis<CR>', { silent = true, noremap = true })
            vim.api.nvim_set_keymap('n', '<leader>hD', '<cmd>lua require"gitsigns".diffthis("~")<CR>',
                { silent = true, noremap = true })
            vim.api.nvim_set_keymap('n', '<leader>td', '<cmd>Gitsigns toggle_deleted<CR>',
                { silent = true, noremap = true })
            vim.api.nvim_set_keymap('o', 'ih', ':<C-U>Gitsigns select_hunk<CR>', { silent = true, noremap = true })
            vim.api.nvim_set_keymap('x', 'ih', ':<C-U>Gitsigns select_hunk<CR>', { silent = true, noremap = true })
        end
    },
}
