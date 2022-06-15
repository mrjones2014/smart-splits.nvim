local M = {}
local on_enter = require('smart-splits.config').resize_mode.hooks.on_enter
local on_leave = require('smart-splits.config').resize_mode.hooks.on_leave

function M.start_resize_mode()
  if vim.fn.mode() ~= 'n' then
    vim.notify('Resize mode must be triggered from normal mode', vim.log.levels.ERROR)
    return
  end

  if type(on_enter) == 'function' then
    on_enter()
  end

  local quit_key = require('smart-splits.config').resize_mode_quit_key
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

  if require('smart-splits.config').resize_mode_silent then
    return
  end

  local msg = string.format('Persistent resize mode enabled. Use h/j/k/l to resize, and %s to finish.', quit_key)
  vim.notify(msg, vim.log.levels.INFO)
end

function M.end_resize_mode()
  local quit_key = require('smart-splits.config').resize_mode_quit_key
  vim.api.nvim_del_keymap('n', 'h')
  vim.api.nvim_del_keymap('n', 'l')
  vim.api.nvim_del_keymap('n', 'j')
  vim.api.nvim_del_keymap('n', 'k')
  vim.api.nvim_del_keymap('n', quit_key)

  if require('smart-splits.config').resize_mode_silent then
    return
  end

  local msg = 'Persistent resize mode disabled. Normal keymaps have been restored.'
  vim.notify(msg, vim.log.levels.INFO)
end

if type(on_leave) == 'function' then
  on_enter()
end

return M
