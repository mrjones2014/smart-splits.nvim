local lazy = require('smart-splits.lazy')
local log = lazy.require_on_exported_call('smart-splits.log') --[[@as SmartSplitsLogger]]
local config = lazy.require_on_index('smart-splits.config') --[[@as SmartSplitsConfig]]

local M = {}

local function wrap(fn)
  return function()
    local count = vim.v.count1 or 1
    fn((require('smart-splits.config').default_amount or 1) * count)
  end
end

function M.start_resize_mode()
  if vim.fn.mode() ~= 'n' then
    log.error('Resize mode must be triggered from normal mode')
    return
  end

  pcall(config.resize_mode.hooks.on_enter)
  -- luacheck:ignore
  vim.g.smart_resize_mode = true

  local quit_key = config.resize_mode.quit_key
  local resize_keys = config.resize_mode.resize_keys
  vim.keymap.set('n', resize_keys[1], wrap(require('smart-splits').resize_left), { silent = true })
  vim.keymap.set('n', resize_keys[2], wrap(require('smart-splits').resize_down), { silent = true })
  vim.keymap.set('n', resize_keys[3], wrap(require('smart-splits').resize_up), { silent = true })
  vim.keymap.set('n', resize_keys[4], wrap(require('smart-splits').resize_right), { silent = true })
  vim.keymap.set('n', quit_key, ":lua require('smart-splits.resize-mode').end_resize_mode()<CR>", { silent = true })

  if config.resize_mode.silent then
    return
  end

  local msg = string.format(
    'Persistent resize mode enabled. Use %s to resize, and %s to finish.',
    vim.inspect(resize_keys),
    quit_key
  )
  log.info(msg, vim.log.levels.INFO)
end

function M.end_resize_mode()
  local quit_key = config.resize_mode.quit_key
  local resize_keys = config.resize_mode.resize_keys
  vim.api.nvim_del_keymap('n', resize_keys[1])
  vim.api.nvim_del_keymap('n', resize_keys[2])
  vim.api.nvim_del_keymap('n', resize_keys[3])
  vim.api.nvim_del_keymap('n', resize_keys[4])
  vim.api.nvim_del_keymap('n', quit_key)

  pcall(config.resize_mode.hooks.on_leave)
  -- luacheck:ignore
  vim.g.smart_resize_mode = false

  if config.resize_mode.silent then
    return
  end

  local msg = 'Persistent resize mode disabled. Normal keymaps have been restored.'
  log.info(msg)
end

return M
