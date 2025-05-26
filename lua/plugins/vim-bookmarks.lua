return {
    'MattesGroeger/vim-bookmarks',
    name = 'bookmarks',
    lazy = false,
    config = function()
        vim.g.bookmark_sign = '⚑'
        vim.g.bookmark_highlight_group = 'BookmarkLine'
        vim.g.bookmark_highlight_lines = 1
        vim.opt.termguicolors = true
        vim.api.nvim_set_hl(0, 'BookmarkLine', {
            -- 对于真彩色终端 (termguicolors 开启时):
            -- 使用十六进制颜色值设置背景和前景
            bg = '#0087ff', -- 蓝色背景
            fg = '#000135', -- 黑色前景
            -- 对于 256 色终端 (termguicolors 关闭时):
            -- 使用预定义颜色名称设置背景和前景
            ctermbg = 'blue',  -- 蓝色背景
            ctermfg = 'black', -- 黑色前景
            -- 你还可以添加其他属性，例如 'bold = true'
            -- bold = true,
        })
    end,
}
