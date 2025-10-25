# 我的 Neovim 配置

这是一套基于 **lazy.nvim** 的 Neovim 配置，默认主题为 Tokyo Night，针对 C/C++、Lua、Python、前端等语言做了语法高亮、LSP、格式化、AI 辅助、Git 工作流等优化，日常使用中追求“开箱即用 + 清晰可维护”。

## 环境要求

| 依赖 | 说明 |
| --- | --- |
| Neovim ≥ 0.10 | 使用 `vim.loader`、新的 LSP API 以及 `lazy.nvim` 等能力。|
| Git | 自动安装插件、更新依赖。|
| Nerd Font 字体 | 状态栏、文件树、Git 标记等图标需要 Nerd Font。|
| Rust 工具链 | `blink.cmp` 需要 `cargo build --release` 编译。|
| Node / Python / Go 等运行时（按需） | `mason.nvim` 安装的语言服务器、格式化器会依赖对应运行时。|
| （可选）win32yank / OSC52 等 | 已内置 WSL、SSH 剪贴板逻辑，按需准备外部工具即可。|

> Nerd Font 下载：https://www.nerdfonts.com/font-downloads
>
> Lazygit 安装（可选）：
> ```bash
> LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
> curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
> tar xf lazygit.tar.gz lazygit
> sudo install lazygit -D -t /usr/local/bin/
> ```

## 快速开始

```bash
git clone https://github.com/<your-name>/neovim ~/.config/nvim
cd ~/.config/nvim
nvim
```

1. 第一次启动时 `lazy.nvim` 会自动下载并安装所有插件。
2. 通过 `:Mason` 查看/安装语言服务器与格式化器，`mason-tool-installer` 已配置自动安装常用工具。
3. 打开项目后，LSP、Treesitter、补全、格式化等能力会自动启用。

## 目录结构

- `init.lua`：入口文件，依次加载选项、按键、插件。
- `lua/config/`：
  - `options.lua`：行号、光标行、分屏、剪贴板、持久化 undo、编码等通用设置。
  - `keymaps.lua`：统一设置 `<leader>`（默认为 `,`）、常用操作、可视模式缩进等。
  - `lazy.lua`：lazy.nvim 引导与全局配置。
- `lua/plugins/`：按 Lazy 规范拆分的插件配置文件，可按需增删。
- `nx-clang-format`：供 `clang-format` 使用的格式化模板。

## 常用快捷键

> `<leader>` 被设置为 `,`。

| 模式 | 按键 | 功能 |
| --- | --- | --- |
| 插入 | `jk` | 返回正常模式。|
| 正常 | `<leader>w` | 保存当前文件。|
| 正常 | `<Esc>` | 清除搜索高亮。|
| 正常 | `<leader>rn` | LSP 重命名符号。|
| 正常 | `<leader>fn` | 在当前目录下创建新文件。|
| 正常/可视 | `j`/`k` | 智能处理换行的移动（映射到 `gj`/`gk`）。|
| 可视 | `<` / `>` | 调整缩进后自动保留选区。|
| 正常 | `s` | `leap.nvim` 单窗口跳转。|
| 正常 | `<leader>fe` / `<leader>fE` | 打开 / 聚焦 Neo-tree 文件侧边栏。|
| 正常 | `<leader>ff` / `<leader>fs` | 使用 Fzf-lua 搜索文件 / 全局模糊搜索。|
| 正常 | `<leader>gd` / `<leader>gr` | Fzf-lua 跳转到定义 / 查看引用。|
| 正常 | `<leader>tt` / `<leader>tv` / `<leader>tf` | ToggleTerm 打开终端（默认 / 垂直 / 浮动）。|
| 正常 | `<leader>sr` / `<leader>sw` | Spectre 全局搜索替换 / 搜索选中文本。|
| 正常 | `<leader>ge` | Neogen 自动生成函数注释。|
| 正常 | `<leader>gj` / `<leader>gk` | Gitsigns 跳转到下一 / 上一处变更。|
| 正常 | `<leader>gg` | 打开 Fugitive Git 面板。|
| 正常 | `<leader>?` | Which-key 查看当前缓冲区可用按键。|
| 普通/可视 | `<leader>fm` | Conform.nvim 异步格式化当前缓冲区或选区。|
| 正常 | `<leader>dm` | CodeCompanion 生成符合规范的提交信息。|
| 可视 | `<leader>de` / `<leader>do` / `<leader>dc` / `<leader>dx` / `<leader>dt` | CodeCompanion 解释、优化、注释、修复、生成测试。|

更多 Git 相关快捷键（如阶段 / 回滚 hunk）、书签管理命令等可参考对应插件的 `lua/plugins/*.lua` 文件。

## 插件概览

### 界面与交互
- **folke/tokyonight.nvim**：默认主题，启动即应用夜色方案。
- **nvim-lualine/lualine.nvim**：状态栏集成 Git、诊断、Treesitter 结构等信息。
- **lukas-reineke/indent-blankline.nvim**：渲染缩进参考线。
- **nvim-neo-tree/neo-tree.nvim**：文件树、缓冲区、Git 状态浏览。
- **mhinz/vim-startify**：美观的启动页及会话管理。
- **folke/which-key.nvim**：可视化提示快捷键。
- **ibhagwan/fzf-lua**：模糊搜索、LSP、Git、命令等统一入口。
- **ggandor/leap.nvim**：快速跳转光标位置。
- **akinsho/toggleterm.nvim**：多终端布局快捷切换。

### 语法、补全与 LSP
- **nvim-treesitter/nvim-treesitter**（附 textobjects / context）：增量解析、选区扩展、代码上下文浮动窗口。
- **saghen/blink.cmp**：Rust 编写的高性能补全引擎，集成 LSP、缓冲区、路径、命令行、Codeium 等来源。
- **windwp/nvim-autopairs**、**kylechui/nvim-surround**、**numToStr/Comment.nvim**：配对括号、包裹、快速注释。
- **neovim/nvim-lspconfig** + **williamboman/mason.nvim** 系列：统一安装与配置 `clangd`、`lua_ls`、`bashls`、`marksman`、`taplo` 等语言服务器；在 `BufReadPre` / `BufNewFile` 事件触发时懒加载，并于 `LspAttach` 针对当前服务器声明的能力（如内联提示、语义高亮）逐项启用，确保无关能力不会额外消耗资源。
- **stevearc/conform.nvim**：统一格式化入口，整合 `stylua`、`isort`、`black`、`prettierd`、`clang-format`、`taplo` 等工具。
- **danymat/neogen**：一键生成函数注释模板。
- **rachartier/tiny-inline-diagnostic.nvim**：LSP 诊断信息以内联气泡显示，关闭默认虚拟文本。

### AI 协作
- **Exafunction/codeium.nvim**：AI 辅助补全，可在 `blink.cmp` 中作为补全来源。
- **olimorris/codecompanion.nvim**（含 history 扩展）：提供聊天、内联编辑、命令三种工作流，内置多种中文提示模板并支持 DeepSeek、Gemini、OpenAI 等适配器；默认提供生成提交信息、解释代码、优化、注释、修复 Bug、生成测试等快捷键。

### Git 与版本控制
- **lewis6991/gitsigns.nvim**：边栏与行内 Git diff 标记、跳转、暂存 / 回滚。
- **tpope/vim-fugitive**：Git 命令的 Neovim 终端封装。
- **MattesGroeger/vim-bookmarks**：以 ⚑ 图标展示书签，并自定义高亮。
- **dhananjaylatkar/cscope_maps.nvim**：为 C/C++ 项目提供 cscope 代码索引，默认结合 Fzf-lua 作为 picker。

### 文本、Markdown 与其他工具
- **nvim-pack/nvim-spectre**：项目级搜索替换。
- **OXY2DEV/markview.nvim**：Markdown / CodeCompanion 缓冲区实时预览。
- **fei6409/log-highlight.nvim**：优化日志文件关键字高亮。
- **nvim-tree/nvim-web-devicons**：统一图标库，配合状态栏、文件树展示文件类型图标。

### C/C++ 定制增强

- `clangd` 默认附加 `--background-index`、`--clang-tidy`、`--completion-style=detailed`、`--function-arg-placeholders` 等参数，保证索引、补全与诊断信息充足且保持一致格式。
- 自动探测 `compile_commands.json` 所在目录（支持仓库根目录、`build/`、`cmake-build-debug/`、`cmake-build-release/` 等常见路径），并通过 `--compile-commands-dir` 显式传递给 `clangd`，减少手动同步编译数据库的需求。
- 启用了 `clangdFileStatus`，在状态栏显示当前编译单元索引进度；并提供 `<leader>gh` 快捷键，在源文件与头文件之间一键切换。
- 与 `clang-format`、`cscope_maps.nvim` 等工具协同，形成“格式化 + 语义补全 + 全局索引”的 C/C++ 工作流。

## 日常操作建议

- 插件管理：执行 `Lazy`、`:Lazy sync`、`:Lazy check` 查看或更新插件。
- 语言工具：执行 `Mason`、`:MasonToolsUpdate` 统一管理语言服务器与格式化器。
- 格式化：使用 `<leader>fm` 或 `:Format`（Conform 会优先调用外部工具，回退到 LSP）。
- 搜索 / 跳转：优先使用 `FzfLua` 与 `leap.nvim`，可显著提升效率。
- Git：`<leader>gg` 打开 Fugitive，`<leader>gj/gk` 快速浏览改动，配合 `lazygit` 使用体验更佳。
- AI：在 shell 中设置 `DEEPSEEK_API_KEY` / `GEMINI_API_KEY` / `OPENAI_API_KEY` 后即可使用 CodeCompanion；Codeium 需登录其官方服务。

## 其它说明

- `options.lua` 已启用持久化 undo、关闭 swapfile、智能滚动、WSL / SSH 剪贴板适配等优化，可按需调整。
- 插件配置均拆分在 `lua/plugins/*.lua`，删除某个插件只需移除对应文件并在 `:Lazy clean` 后重启。
- `clang-format` 样式保存在仓库根目录的 `nx-clang-format`，可根据团队规范自定义。

如需扩展新的语言或工具，建议优先通过 `mason.nvim` 管理；保持 `cargo`、`npm`、`pip` 等环境可用能让自动安装更加顺利。
