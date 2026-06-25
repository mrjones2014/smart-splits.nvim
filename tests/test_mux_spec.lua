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
  local original_env = {}

  before_each(function()
    original_env.HERDR_ENV = vim.env.HERDR_ENV
    original_env.HERDR_PANE_ID = vim.env.HERDR_PANE_ID
    fresh_modules()
    mux_api = require('smart-splits.mux')
  end)

  after_each(function()
    vim.env.HERDR_ENV = original_env.HERDR_ENV
    vim.env.HERDR_PANE_ID = original_env.HERDR_PANE_ID
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

  describe('with herdr backend', function()
    before_each(function()
      fresh_modules()
      require('smart-splits.config').setup({ multiplexer_integration = 'herdr' })
      mux_api = require('smart-splits.mux')
      vim.env.HERDR_ENV = '1'
      vim.env.HERDR_PANE_ID = 'ws1:p2'
    end)

    it('loads the herdr backend when configured', function()
      local backend = mux_api.get()

      assert.is_not_nil(backend)
      assert.equals('herdr', backend.type)
    end)

    it('maps herdr CLI operations correctly', function()
      local original_system = vim.system
      local calls = {}

      vim.system = function(cmd, opts)
        table.insert(calls, vim.deepcopy(cmd))
        local stdout = ''

        if cmd[1] == 'herdr' and cmd[2] == 'pane' and cmd[3] == 'list' then
          stdout = vim.json.encode({
            ok = true,
            result = {
              panes = {
                { pane_id = 'ws1:p2', focused = true },
                { pane_id = 'ws1:p3', focused = false },
              },
            },
          })
        elseif cmd[1] == 'herdr' and cmd[2] == 'pane' and cmd[3] == 'edges' then
          stdout = vim.json.encode({
            ok = true,
            result = {
              edges = {
                left = false,
                right = true,
                up = false,
                down = false,
              },
            },
          })
        elseif cmd[1] == 'herdr' and cmd[2] == 'pane' and cmd[3] == 'focus' then
          stdout = vim.json.encode({
            ok = true,
            result = {
              focus = {
                changed = true,
              },
            },
          })
        elseif cmd[1] == 'herdr' and cmd[2] == 'pane' and cmd[3] == 'resize' then
          stdout = vim.json.encode({
            ok = true,
            result = {
              resize = {
                changed = true,
              },
            },
          })
        elseif cmd[1] == 'herdr' and cmd[2] == 'pane' and cmd[3] == 'split' then
          stdout = vim.json.encode({
            ok = true,
            result = {
              pane = {
                pane_id = 'ws1:p3',
              },
            },
          })
        elseif cmd[1] == 'herdr' and cmd[2] == 'pane' and cmd[3] == 'swap' then
          stdout = vim.json.encode({
            ok = true,
            result = {
              swap = {
                changed = true,
              },
            },
          })
        end

        return {
          wait = function()
            return { code = 0, stdout = stdout, stderr = '', opts = opts }
          end,
        }
      end

      local backend = mux_api.get()
      assert.is_true(backend.is_in_session())
      assert.equals('ws1:p2', backend.current_pane_id())
      assert.is_true(backend.current_pane_at_edge('right'))
      assert.is_true(backend.next_pane('left'))
      assert.is_true(backend.resize_pane('left', 3))
      assert.is_true(backend.split_pane('right'))

      assert.same({ 'herdr', 'pane', 'list' }, calls[1])
      assert.same({ 'herdr', 'pane', 'edges', '--current' }, calls[2])
      assert.same({ 'herdr', 'pane', 'focus', '--direction', 'left', '--current' }, calls[3])
      assert.same({ 'herdr', 'pane', 'resize', '--direction', 'left', '--amount', '3', '--current' }, calls[4])
      assert.same({ 'herdr', 'pane', 'split', '--direction', 'right', '--current', '--focus' }, calls[5])

      vim.system = original_system
    end)

    it('maps left splits to split-then-swap', function()
      local original_system = vim.system
      local calls = {}

      vim.system = function(cmd)
        table.insert(calls, vim.deepcopy(cmd))
        local stdout = ''

        if cmd[1] == 'herdr' and cmd[2] == 'pane' and cmd[3] == 'split' then
          stdout = vim.json.encode({
            ok = true,
            result = {
              pane = {
                pane_id = 'ws1:p3',
              },
            },
          })
        elseif cmd[1] == 'herdr' and cmd[2] == 'pane' and cmd[3] == 'swap' then
          stdout = vim.json.encode({
            ok = true,
            result = {
              swap = {
                changed = true,
              },
            },
          })
        end

        return {
          wait = function()
            return { code = 0, stdout = stdout, stderr = '' }
          end,
        }
      end

      local backend = mux_api.get()
      assert.is_true(backend.split_pane('left'))

      assert.same({ 'herdr', 'pane', 'split', '--direction', 'right', '--current', '--focus' }, calls[1])
      assert.same({ 'herdr', 'pane', 'swap', '--direction', 'right', '--current' }, calls[2])

      vim.system = original_system
    end)

    it('reports a successful mux move when herdr focus changes the focused pane', function()
      local original_system = vim.system
      local focused_pane = 'ws1:p2'

      vim.system = function(cmd)
        local stdout = ''

        if cmd[1] == 'herdr' and cmd[2] == 'pane' and cmd[3] == 'list' then
          stdout = vim.json.encode({
            ok = true,
            result = {
              panes = {
                { pane_id = 'ws1:p2', focused = focused_pane == 'ws1:p2' },
                { pane_id = 'ws1:p3', focused = focused_pane == 'ws1:p3' },
              },
            },
          })
        elseif cmd[1] == 'herdr' and cmd[2] == 'pane' and cmd[3] == 'focus' then
          focused_pane = 'ws1:p3'
          stdout = vim.json.encode({
            ok = true,
            result = {
              focus = {
                changed = true,
                focused_pane_id = focused_pane,
              },
            },
          })
        end

        return {
          wait = function()
            return { code = 0, stdout = stdout, stderr = '' }
          end,
        }
      end

      local result = mux_api.move_pane('right', false, 'wrap')
      assert.is_true(result)

      vim.system = original_system
    end)
  end)
end)
