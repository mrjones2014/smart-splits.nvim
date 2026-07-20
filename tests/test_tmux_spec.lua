local function fresh_tmux_module()
  package.loaded['smart-splits.mux.tmux'] = nil
  return require('smart-splits.mux.tmux')
end

describe('tmux marker lifecycle', function()
  local original_jobstart
  local original_tmux
  local original_tmux_pane
  local original_flatpak_id

  before_each(function()
    original_jobstart = vim.fn.jobstart
    original_tmux = vim.env.TMUX
    original_tmux_pane = vim.env.TMUX_PANE
    original_flatpak_id = vim.env.FLATPAK_ID
    vim.env.TMUX = '/tmp/tmux-test.sock,123,0'
    vim.env.TMUX_PANE = '%42'
    vim.env.FLATPAK_ID = nil
  end)

  after_each(function()
    vim.fn.jobstart = original_jobstart
    vim.env.TMUX = original_tmux
    vim.env.TMUX_PANE = original_tmux_pane
    vim.env.FLATPAK_ID = original_flatpak_id
    package.loaded['smart-splits.mux.tmux'] = nil
  end)

  it('clears the marker on the pane that owns Neovim', function()
    local command
    local options
    vim.fn.jobstart = function(cmd, opts)
      command = cmd
      options = opts
      return 1
    end

    fresh_tmux_module().on_exit()

    assert.same({
      'tmux',
      '-S',
      '/tmp/tmux-test.sock',
      'set-option',
      '-pt',
      '%42',
      '@pane-is-vim',
      0,
    }, command)
    assert.same({ detach = true }, options)
  end)
end)
