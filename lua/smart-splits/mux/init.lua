local M = {}

function M.get()
  local mux = require('smart-splits.config').multiplexer_integration
  if mux == 'tmux' then
    return require('smart-splits.mux.tmux')
  elseif mux == 'wezterm' then
    return require('smart-splits.mux.wezterm')
  elseif mux == 'kitty' then
    return require('smart-splits.mux.kitty')
  else
    return nil
  end
end

return M
