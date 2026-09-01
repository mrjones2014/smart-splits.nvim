local Types = require('smart-splits.types')
local Direction = Types.Direction

---@class SmartSplitsWin
local M = {}

---@enum WinPosition
M.WinPosition = {
  start = 0,
  middle = 1,
  last = 2,
}

---@enum DirectionKeys
M.DirectionKeys = {
  left = 'h',
  right = 'l',
  up = 'k',
  down = 'j',
}

---@enum DirectionKeysReverse
M.DirectionKeysReverse = {
  left = 'l',
  right = 'h',
  up = 'j',
  down = 'k',
}

---@enum WincmdResizeDirection
M.WincmdResizeDirection = {
  bigger = '+',
  smaller = '-',
}

---@param win_id number|nil window ID, defaults to the current window
---@return boolean
function M.is_floating(win_id)
  local cfg = vim.api.nvim_win_get_config(win_id or 0)
  return cfg and cfg.relative ~= ''
end

---Is this a floating window that behaves like a sidebar rather than a popup?
---Neovim's default floating zindex is 50, so anything explicitly set below that
---is meant to sit alongside normal splits, like snacks explorer at 33.
---@param win_id number|nil window ID, defaults to the current window
---@return boolean
function M.is_embedded_float(win_id)
  if not M.is_floating(win_id) then
    return false
  end
  local cfg = vim.api.nvim_win_get_config(win_id or 0)
  return cfg.zindex ~= nil and cfg.zindex < 50
end

---@param direction SmartSplitsDirection
---@param win_id number|nil window ID, defaults to the current window
---@return boolean
function M.is_float_at_screen_edge(direction, win_id)
  win_id = win_id or vim.api.nvim_get_current_win()
  if not M.is_floating(win_id) then
    return false
  end

  local cfg = vim.api.nvim_win_get_config(win_id)
  local col = type(cfg.col) == 'number' and cfg.col or 0
  local row = type(cfg.row) == 'number' and cfg.row or 0
  if direction == Direction.left then
    return col <= 0
  elseif direction == Direction.right then
    return col + cfg.width >= vim.o.columns
  elseif direction == Direction.up then
    return row <= 0
  end
  return row + cfg.height >= vim.o.lines - vim.o.cmdheight
end

---@param bufnr number|nil buffer number, defaults to the current buffer
---@param buftypes string[]
---@param filetypes string[]
---@return boolean
function M.is_ignored(bufnr, buftypes, filetypes)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.tbl_contains(buftypes, vim.bo[bufnr].buftype) or vim.tbl_contains(filetypes, vim.bo[bufnr].filetype)
end

---@param winnr number|nil window ID, defaults to the current window
---@return boolean
function M.is_full_height(winnr)
  local height = vim.o.lines - vim.o.cmdheight
  if (vim.o.laststatus == 1 and #vim.api.nvim_tabpage_list_wins(0) > 1) or vim.o.laststatus > 1 then
    height = height - 1
  end
  if (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1) or vim.o.showtabline == 2 then
    height = height - 1
  end
  return vim.api.nvim_win_get_height(winnr or 0) == height
end

---@param winnr number|nil window ID, defaults to the current window
---@return boolean
function M.is_full_width(winnr)
  return vim.api.nvim_win_get_width(winnr or 0) == vim.o.columns
end

---@return boolean
function M.at_top_edge()
  return vim.fn.winnr() == vim.fn.winnr('k')
end

---@return boolean
function M.at_bottom_edge()
  return vim.fn.winnr() == vim.fn.winnr('j')
end

---@return boolean
function M.at_left_edge()
  return vim.fn.winnr() == vim.fn.winnr('h')
end

---@return boolean
function M.at_right_edge()
  return vim.fn.winnr() == vim.fn.winnr('l')
end

---@param direction SmartSplitsDirection
---@return WinPosition
function M.win_position(direction)
  if direction == Direction.left or direction == Direction.right then
    if M.at_left_edge() then
      return M.WinPosition.start
    end
    if M.at_right_edge() then
      return M.WinPosition.last
    end
    return M.WinPosition.middle
  end

  if M.at_top_edge() then
    return M.WinPosition.start
  end
  if M.at_bottom_edge() then
    return M.WinPosition.last
  end
  return M.WinPosition.middle
end

---Move to the neighboring window, staying put if it turns out to be one we
---ignore while resizing.
---@param dir_key DirectionKeys
---@param skip_ignore_lists boolean|nil defaults to false
---@param is_resizing boolean|nil
---@return table|nil view the saved view of the window moved into, for horizontal moves
function M.next_window(dir_key, skip_ignore_lists, is_resizing)
  local Config = require('smart-splits.config')
  local cur_win = vim.api.nvim_get_current_win()

  local function moved_into_ignored()
    if skip_ignore_lists or not is_resizing then
      return false
    end
    local buftypes, filetypes = Config.ignores('resize')
    return M.is_ignored(nil, buftypes, filetypes)
  end

  if dir_key == M.DirectionKeys.down or dir_key == M.DirectionKeys.up then
    vim.cmd('wincmd ' .. dir_key)
    if moved_into_ignored() then
      vim.api.nvim_set_current_win(cur_win)
    end
    return nil
  end

  local offset = vim.fn.winline() + vim.api.nvim_win_get_position(0)[1]
  vim.cmd('wincmd ' .. dir_key)
  if moved_into_ignored() then
    vim.api.nvim_set_current_win(cur_win)
    return nil
  end

  local view = vim.fn.winsaveview()
  offset = offset - vim.api.nvim_win_get_position(0)[1]
  vim.cmd('normal! ' .. offset .. 'H')
  return view
end

---Floating windows have no meaningful neighbors, so operations run against the
---previously focused window instead. Returns `true` when there is nothing
---sensible to fall back to and the caller should give up.
---@return boolean handled
function M.handle_floating_window()
  if not M.is_floating() then
    return false
  end

  local prev_win = vim.fn.win_getid(vim.fn.winnr('#'))
  if M.is_floating(prev_win) then
    return true
  end

  vim.api.nvim_set_current_win(prev_win)
  return false
end

---Add the configured events to `eventignore` for the duration of a resize.
---@return string original the previous value of `eventignore`
function M.set_eventignore()
  local original = vim.o.eventignore
  local eventignore = original
  if #eventignore > 0 and not vim.endswith(eventignore, ',') then
    eventignore = eventignore .. ','
  end
  -- luacheck:ignore
  vim.o.eventignore = eventignore .. table.concat(require('smart-splits.config').resize.ignored_events or {}, ',')
  return original
end

---@param wrap boolean jump to the far side rather than the immediate neighbor
---@param dir_key DirectionKeys
function M.next_win_or_wrap(wrap, dir_key)
  -- doing this inside the cmdline window sometimes leaves nvim in an invalid
  -- state, see https://github.com/mrjones2014/smart-splits.nvim/issues/463
  if vim.fn.getcmdwintype() ~= '' then
    return
  end
  local target = vim.fn.winnr(('%s%s'):format(wrap and '99999' or vim.v.count1, dir_key))
  vim.api.nvim_set_current_win(vim.fn.win_getid(target))
end

---@param direction SmartSplitsDirection
function M.split(direction)
  if direction == Direction.left or direction == Direction.right then
    vim.cmd('vsp')
    if vim.o.splitright and direction == Direction.left then
      vim.cmd('wincmd h')
    end
    return
  end

  vim.cmd('sp')
  if vim.o.splitbelow and direction == Direction.up then
    vim.cmd('wincmd k')
  end
end

return M
