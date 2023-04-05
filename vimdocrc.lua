vim.cmd([[
  set rtp+=.
  set rtp+=vendor/nvim-treesitter
  set rtp+=vendor/ts-vimdoc.nvim
  runtime plugin/nvim-treesitter.lua
]])

require('nvim-treesitter.configs').setup({
  ensure_installed = {
    'markdown',
    'markdown_inline',
  },
})
