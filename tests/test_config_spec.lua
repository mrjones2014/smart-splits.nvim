local function fresh_config()
  -- clear cached modules so config resets to defaults
  for key, _ in pairs(package.loaded) do
    if key:match('^smart%-splits') then
      package.loaded[key] = nil
    end
  end
  return require('smart-splits.config')
end

describe('smart-splits.config', function()
  local config
  local original_env = {}

  before_each(function()
    original_env.HERDR_ENV = vim.env.HERDR_ENV
    original_env.TERM_PROGRAM = vim.env.TERM_PROGRAM
    original_env.ZELLIJ = vim.env.ZELLIJ
    original_env.KITTY_LISTEN_ON = vim.env.KITTY_LISTEN_ON
    config = fresh_config()
  end)

  after_each(function()
    vim.env.HERDR_ENV = original_env.HERDR_ENV
    vim.env.TERM_PROGRAM = original_env.TERM_PROGRAM
    vim.env.ZELLIJ = original_env.ZELLIJ
    vim.env.KITTY_LISTEN_ON = original_env.KITTY_LISTEN_ON
  end)

  describe('setup', function()
    it('uses default values', function()
      assert.equals(3, config.default_amount)
      assert.equals(false, config.move_cursor_same_row)
      assert.equals(false, config.cursor_follows_swapped_bufs)
    end)

    it('merges user config', function()
      config.setup({ default_amount = 5 })
      assert.equals(5, config.default_amount)
    end)

    it('preserves defaults for unset keys', function()
      config.setup({ default_amount = 10 })
      assert.equals(false, config.cursor_follows_swapped_bufs)
    end)

    it('handles ignored_buftypes override', function()
      config.setup({ ignored_buftypes = { 'terminal' } })
      assert.same({ 'terminal' }, config.ignored_buftypes)
    end)

    it('handles ignored_filetypes override', function()
      config.setup({ ignored_filetypes = { 'neo-tree' } })
      assert.same({ 'neo-tree' }, config.ignored_filetypes)
    end)

    it('sets at_edge', function()
      config.setup({ at_edge = 'stop' })
      assert.equals('stop', config.at_edge)
    end)

    it('sets float_win_behavior', function()
      config.setup({ float_win_behavior = 'mux' })
      assert.equals('mux', config.float_win_behavior)
    end)

    it('sets move_cursor_same_row', function()
      config.setup({ move_cursor_same_row = true })
      assert.is_true(config.move_cursor_same_row)
    end)

    it('sets cursor_follows_swapped_bufs', function()
      config.setup({ cursor_follows_swapped_bufs = true })
      assert.is_true(config.cursor_follows_swapped_bufs)
    end)

    it('can disable multiplexer integration', function()
      config.setup({ multiplexer_integration = false })
      assert.equals(false, config.multiplexer_integration)
    end)
  end)

  describe('set_default_multiplexer', function()
    it('auto-detects herdr from HERDR_ENV', function()
      vim.env.HERDR_ENV = '1'
      vim.env.TERM_PROGRAM = ''
      vim.env.ZELLIJ = nil
      vim.env.KITTY_LISTEN_ON = nil

      config.set_default_multiplexer()

      assert.equals('herdr', config.multiplexer_integration)
    end)
  end)
end)
