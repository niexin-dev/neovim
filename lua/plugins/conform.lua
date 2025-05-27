return {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
        {
            -- Customize or remove this keymap to your liking
            "<leader>df",
            function()
                require("conform").format({ async = true })
            end,
            mode = "",
            desc = "Format buffer",
        },
    },
    -- This will provide type hinting with LuaLS
    ---@module "conform"
    ---@type conform.setupOpts
    opts = {
        -- Set the log level. Use `:ConformInfo` to see the location of the log file.
        -- log_level = vim.log.levels.DEBUG,
        -- Define your formatters
        formatters_by_ft = {
            lua = { "stylua" },
            python = { "isort", "black" },
            javascript = { "prettierd", "prettier", stop_after_first = true },
            c = { "clang_format" },
            cpp = { "clang_format" },
            markdown = { "prettier" },

        },
        -- Set default options
        default_format_opts = {
            lsp_format = "fallback",
        },
        -- Set up format-on-save
        -- format_on_save = { timeout_ms = 500 },
        -- Customize formatters
        formatters = {
            shfmt = {
                prepend_args = { "-i", "2" },
            },
            clang_format = {
                command = "clang-format",
                prepend_args = { "--style=file:" .. vim.fs.joinpath(vim.fn.stdpath("config"), "nx-clang-format") },
                range_args = function(self, ctx)
                    return { "--lines", string.format("%d:%d", ctx.range.start[1], ctx.range["end"][1]) }
                end,
                stdin = true
            },
        },
    },
    init = function()
        -- If you want the formatexpr, here is the place to set it
        vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
}
