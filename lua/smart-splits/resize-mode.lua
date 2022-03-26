local M = {}

function M.start_resize_mode()
  if vim.fn.mode() ~= 'n' then
    vim.notify('Resize mode must be triggered from normal mode', vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_set_keymap('n', 'h', ":lua require('smart-splits').resize_left()<CR>", {})
  vim.api.nvim_set_keymap('n', 'l', ":lua require('smart-splits').resize_right()<CR>", {})
  vim.api.nvim_set_keymap('n', 'j', ":lua require('smart-splits').resize_down()<CR>", {})
  vim.api.nvim_set_keymap('n', 'k', ":lua require('smart-splits').resize_up()<CR>", {})
  vim.api.nvim_set_keymap('n', '<ESC>', ":lua require('smart-splits.resize-mode').end_resize_mode()<CR>", {})
end

function M.end_resize_mode()
  vim.api.nvim_del_keymap('n', 'h')
  vim.api.nvim_del_keymap('n', 'l')
  vim.api.nvim_del_keymap('n', 'j')
  vim.api.nvim_del_keymap('n', 'k')
  vim.api.nvim_del_keymap('n', '<ESC>')
end

return M
