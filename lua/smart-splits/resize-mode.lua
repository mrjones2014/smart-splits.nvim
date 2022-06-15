local M = {}

function M.start_resize_mode()
  local config = require('smart-splits.config').config
  if vim.fn.mode() ~= 'n' then
    vim.notify('Resize mode must be triggered from normal mode', vim.log.levels.ERROR)
    return
  end

  local on_enter = config.resize_mode.hooks.on_enter
  if type(on_enter) == 'function' then
    on_enter()
  end

  local quit_key = config.resize_mode.quit_key
  vim.api.nvim_set_keymap('n', 'h', ":lua require('smart-splits').resize_left()<CR>", { silent = true })
  vim.api.nvim_set_keymap('n', 'l', ":lua require('smart-splits').resize_right()<CR>", { silent = true })
  vim.api.nvim_set_keymap('n', 'j', ":lua require('smart-splits').resize_down()<CR>", { silent = true })
  vim.api.nvim_set_keymap('n', 'k', ":lua require('smart-splits').resize_up()<CR>", { silent = true })
  vim.api.nvim_set_keymap(
    'n',
    quit_key,
    ":lua require('smart-splits.resize-mode').end_resize_mode()<CR>",
    { silent = true }
  )

  if config.resize_mode.silent then
    return
  end

  local msg = string.format('Persistent resize mode enabled. Use h/j/k/l to resize, and %s to finish.', quit_key)
  vim.notify(msg, vim.log.levels.INFO)
end

function M.end_resize_mode()
  local config = require('smart-splits.config').config
  local quit_key = config.resize_mode.quit_key
  vim.api.nvim_del_keymap('n', 'h')
  vim.api.nvim_del_keymap('n', 'l')
  vim.api.nvim_del_keymap('n', 'j')
  vim.api.nvim_del_keymap('n', 'k')
  vim.api.nvim_del_keymap('n', quit_key)

  local on_leave = config.resize_mode.hooks.on_leave
  if type(on_leave) == 'function' then
    on_leave()
  end

  if config.resize_mode.silent then
    return
  end

  local msg = 'Persistent resize mode disabled. Normal keymaps have been restored.'
  vim.notify(msg, vim.log.levels.INFO)
end

return M
