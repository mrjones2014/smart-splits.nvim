local function fresh_modules()
  for key, _ in pairs(package.loaded) do
    if key:match('^smart%-splits') then
      package.loaded[key] = nil
    end
  end
end

--- Create a mock multiplexer that records calls
local function mock_mux(overrides)
  overrides = overrides or {}
  local calls = {}
  return {
    calls = calls,
    mux = {
      type = 'mock',
      current_pane_id = overrides.current_pane_id or function()
        table.insert(calls, 'current_pane_id')
        return 1
      end,
      current_pane_at_edge = overrides.current_pane_at_edge or function(_dir)
        table.insert(calls, 'current_pane_at_edge')
        return false
      end,
      is_in_session = overrides.is_in_session or function()
        table.insert(calls, 'is_in_session')
        return true
      end,
      current_pane_is_zoomed = overrides.current_pane_is_zoomed or function()
        table.insert(calls, 'current_pane_is_zoomed')
        return false
      end,
      next_pane = overrides.next_pane or function(_dir)
        table.insert(calls, 'next_pane')
        return true
      end,
      resize_pane = overrides.resize_pane or function(_dir, _amount)
        table.insert(calls, 'resize_pane')
        return true
      end,
      split_pane = overrides.split_pane or function(_dir, _size)
        table.insert(calls, 'split_pane')
        return true
      end,
      on_init = nil,
      on_exit = nil,
      update_mux_layout_details = function() end,
    },
  }
end

describe('mux delegation', function()
  local mux_api

  before_each(function()
    fresh_modules()
    mux_api = require('smart-splits.mux')
  end)

  after_each(function()
    fresh_modules()
  end)

  it('returns nil when no multiplexer configured', function()
    require('smart-splits.config').setup({ multiplexer_integration = false })
    assert.is_nil(mux_api.get())
  end)

  it('is_enabled returns false when no multiplexer', function()
    require('smart-splits.config').setup({ multiplexer_integration = false })
    assert.is_false(mux_api.is_enabled())
  end)

  describe('with mock multiplexer', function()
    local mock

    before_each(function()
      fresh_modules()
      require('smart-splits.config').setup({ multiplexer_integration = false })
      mux_api = require('smart-splits.mux')
      mock = mock_mux()
      -- inject mock directly
      mux_api.__mux = mock.mux
    end)

    it('resize_pane delegates to multiplexer', function()
      local result = mux_api.resize_pane('right', 3)
      assert.is_true(result)
      assert.truthy(vim.tbl_contains(mock.calls, 'resize_pane'))
    end)

    it('move_pane delegates to multiplexer', function()
      -- mock next_pane returns new pane id
      local pane_id = 1
      mock = mock_mux({
        current_pane_id = function()
          pane_id = pane_id + 1
          return pane_id
        end,
      })
      mux_api.__mux = mock.mux
      local result = mux_api.move_pane('right', false, 'wrap')
      assert.is_true(result)
    end)

    it('move_pane returns false when pane did not change', function()
      mock = mock_mux({
        current_pane_id = function()
          return 1 -- always same pane
        end,
      })
      mux_api.__mux = mock.mux
      local result = mux_api.move_pane('right', false, 'wrap')
      assert.is_false(result)
    end)

    it('resize_pane returns false when not in session', function()
      mock = mock_mux({
        is_in_session = function()
          return false
        end,
      })
      mux_api.__mux = mock.mux
      local result = mux_api.resize_pane('right', 3)
      assert.is_false(result)
    end)

    it('respects disable_multiplexer_nav_when_zoomed', function()
      require('smart-splits.config').setup({
        multiplexer_integration = false,
        disable_multiplexer_nav_when_zoomed = true,
      })
      mock = mock_mux({
        current_pane_is_zoomed = function()
          return true
        end,
      })
      mux_api.__mux = mock.mux
      local result = mux_api.resize_pane('right', 3)
      assert.is_false(result)
    end)
  end)
end)
