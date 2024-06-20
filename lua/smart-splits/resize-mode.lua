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

local function compare_key(a, b)
  return vim.api.nvim_replace_termcodes(a, true, false, true) == vim.api.nvim_replace_termcodes(b, true, false, true)
end

M.__map_cache = {}
---Store any existing mappings to be restored after exit
---@param resize_keys string[]
---@param quit_key string
local function cache_mappings(resize_keys, quit_key)
  local maps = vim.api.nvim_get_keymap('n')
  M.__map_cache = {}
  for _, map in ipairs(maps) do
    if
      compare_key(map.lhs, resize_keys[1])
      or compare_key(map.lhs, resize_keys[2])
      or compare_key(map.lhs, resize_keys[3])
      or compare_key(map.lhs, resize_keys[4])
      or compare_key(map.lhs, quit_key)
    then
      M.__map_cache[map.lhs] = map
    end
  end
end

---Restore mappings from cache on exit
local function restore_maps(resize_keys, quit_key)
  -- delete the keymaps we've set
  vim.api.nvim_del_keymap('n', resize_keys[1])
  vim.api.nvim_del_keymap('n', resize_keys[2])
  vim.api.nvim_del_keymap('n', resize_keys[3])
  vim.api.nvim_del_keymap('n', resize_keys[4])
  vim.api.nvim_del_keymap('n', quit_key)

  -- restore previous ones, if there are any
  for lhs, mapdef in pairs(M.__map_cache) do
    local opts = {
      buffer = mapdef.buffer,
      nowait = mapdef.nowait == 1,
      silent = mapdef.silent == 1,
      script = mapdef.script ~= 0 and mapdef.script or nil,
      expr = mapdef.expr == 1,
      remap = mapdef.noremap == 0,
    }
    local rhs = mapdef.callback or mapdef.rhs
    vim.keymap.set('n', lhs, rhs, opts)
  end
  M.__map_cache = {}
end

function M.start_resize_mode()
  if vim.fn.mode() ~= 'n' then
    log.error('Resize mode must be triggered from normal mode')
    return
  end

  pcall(config.resize_mode.hooks.on_enter)
  -- luacheck:ignore
  vim.g.smart_resize_mode = true

  local resize_keys = config.resize_mode.resize_keys
  local quit_key = config.resize_mode.quit_key
  cache_mappings(resize_keys, quit_key)
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
  local resize_keys = config.resize_mode.resize_keys
  local quit_key = config.resize_mode.quit_key
  restore_maps(resize_keys, quit_key)

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
