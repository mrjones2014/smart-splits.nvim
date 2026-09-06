---@module 'busted'

local helpers = require('tests.helpers')

describe('move_cursor', function()
  local ss

  before_each(function()
    helpers.reset_plugin()
    ss = require('smart-splits')
  end)

  after_each(function()
    helpers.reset_editor()
    helpers.reset_plugin()
  end)

  describe('horizontal movement', function()
    it('moves right to the next split', function()
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[1])
      ss.move_cursor_right()
      assert.equals(wins[2], helpers.curwin())
    end)

    it('moves left to the previous split', function()
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      ss.move_cursor_left()
      assert.equals(wins[1], helpers.curwin())
    end)

    it('moves through 3 splits', function()
      local wins = helpers.create_vsplits(3)
      helpers.focus(wins[1])
      ss.move_cursor_right()
      assert.equals(wins[2], helpers.curwin())
      ss.move_cursor_right()
      assert.equals(wins[3], helpers.curwin())
    end)
  end)

  describe('vertical movement', function()
    it('moves down to the next split', function()
      local wins = helpers.create_hsplits(2)
      helpers.focus(wins[1])
      ss.move_cursor_down()
      assert.equals(wins[2], helpers.curwin())
    end)

    it('moves up to the previous split', function()
      local wins = helpers.create_hsplits(2)
      helpers.focus(wins[2])
      ss.move_cursor_up()
      assert.equals(wins[1], helpers.curwin())
    end)
  end)

  describe('at_edge = wrap', function()
    it('wraps right to the leftmost split', function()
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      ss.move_cursor_right()
      assert.equals(wins[1], helpers.curwin())
    end)

    it('wraps left to the rightmost split', function()
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[1])
      ss.move_cursor_left()
      assert.equals(wins[2], helpers.curwin())
    end)

    it('wraps down to the topmost split', function()
      local wins = helpers.create_hsplits(2)
      helpers.focus(wins[2])
      ss.move_cursor_down()
      assert.equals(wins[1], helpers.curwin())
    end)

    it('wraps up to the bottommost split', function()
      local wins = helpers.create_hsplits(2)
      helpers.focus(wins[1])
      ss.move_cursor_up()
      assert.equals(wins[2], helpers.curwin())
    end)
  end)

  describe('at_edge = stop', function()
    before_each(function()
      ss.setup({ move = { at_edge = 'stop' } })
    end)

    it('stays at the rightmost split', function()
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      ss.move_cursor_right()
      assert.equals(wins[2], helpers.curwin())
    end)

    it('stays at the leftmost split', function()
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[1])
      ss.move_cursor_left()
      assert.equals(wins[1], helpers.curwin())
    end)
  end)

  describe('at_edge = split', function()
    before_each(function()
      ss.setup({ move = { at_edge = 'split' } })
    end)

    it('creates a split when moving right at the edge', function()
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      local before = #vim.api.nvim_tabpage_list_wins(0)
      ss.move_cursor_right()
      assert.equals(before + 1, #vim.api.nvim_tabpage_list_wins(0))
    end)

    it('creates a split when moving down at the edge', function()
      local wins = helpers.create_hsplits(2)
      helpers.focus(wins[2])
      local before = #vim.api.nvim_tabpage_list_wins(0)
      ss.move_cursor_down()
      assert.equals(before + 1, #vim.api.nvim_tabpage_list_wins(0))
    end)

    it('does nothing in an ignored buffer', function()
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      helpers.set_buftype(wins[2], 'nofile')
      local before = #vim.api.nvim_tabpage_list_wins(0)
      ss.move_cursor_right()
      assert.equals(before, #vim.api.nvim_tabpage_list_wins(0))
    end)

    it('respects a move specific ignore list', function()
      ss.setup({ move = { at_edge = 'split', ignored_filetypes = { 'only-move' } } })
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      helpers.set_filetype(wins[2], 'only-move')
      local before = #vim.api.nvim_tabpage_list_wins(0)
      ss.move_cursor_right()
      assert.equals(before, #vim.api.nvim_tabpage_list_wins(0))
    end)
  end)

  describe('single window', function()
    it('wraps to itself with at_edge = wrap', function()
      helpers.reset_editor()
      local win = helpers.curwin()
      ss.move_cursor_right()
      assert.equals(win, helpers.curwin())
    end)

    it('stays with at_edge = stop', function()
      ss.setup({ move = { at_edge = 'stop' } })
      helpers.reset_editor()
      local win = helpers.curwin()
      ss.move_cursor_right()
      assert.equals(win, helpers.curwin())
    end)
  end)

  describe('per call options', function()
    it('overrides at_edge for a single call', function()
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      ss.move_cursor_right({ at_edge = 'stop' })
      assert.equals(wins[2], helpers.curwin())
    end)
  end)

  describe('backend delegation', function()
    it('does not consult the backend away from an edge', function()
      local backend, calls = helpers.mock_backend()
      ss.setup({ mux = { backend = backend } })
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[1])
      ss.move_cursor_right()
      assert.equals(wins[2], helpers.curwin())
      assert.is_false(vim.tbl_contains(helpers.ops(calls), 'move'))
    end)

    it('consults the backend at an edge', function()
      local backend, calls = helpers.mock_backend()
      ss.setup({ mux = { backend = backend } })
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      ss.move_cursor_right()
      assert.is_true(vim.tbl_contains(helpers.ops(calls), 'move'))
    end)

    it('passes at_edge to the backend', function()
      local backend, calls = helpers.mock_backend()
      ss.setup({ mux = { backend = backend }, move = { at_edge = 'wrap' } })
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      ss.move_cursor_right()
      assert.same({ 'move', 'right', { at_edge = 'wrap' } }, helpers.find_call(calls, 'move'))
    end)

    it('passes at_edge = stop to the backend', function()
      local backend, calls = helpers.mock_backend()
      ss.setup({ mux = { backend = backend }, move = { at_edge = 'stop' } })
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      ss.move_cursor_right()
      assert.same({ 'move', 'right', { at_edge = 'stop' } }, helpers.find_call(calls, 'move'))
    end)

    it('takes at_edge from a per call override', function()
      local backend, calls = helpers.mock_backend()
      ss.setup({ mux = { backend = backend }, move = { at_edge = 'wrap' } })
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      ss.move_cursor_right({ at_edge = 'stop' })
      assert.same({ 'move', 'right', { at_edge = 'stop' } }, helpers.find_call(calls, 'move'))
    end)

    it('passes at_edge = split to the backend', function()
      local backend, calls = helpers.mock_backend()
      ss.setup({ mux = { backend = backend }, move = { at_edge = 'split' } })
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      ss.move_cursor_right()
      assert.same({ 'move', 'right', { at_edge = 'split' } }, helpers.find_call(calls, 'move'))
    end)

    it('stops when the backend handles the move', function()
      local backend = helpers.mock_backend({
        move = function()
          return true
        end,
      })
      ss.setup({ mux = { backend = backend } })
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      ss.move_cursor_right()
      assert.equals(wins[2], helpers.curwin())
    end)

    it('falls back to at_edge when the backend declines', function()
      ss.setup({ mux = { backend = helpers.mock_backend() }, move = { at_edge = 'wrap' } })
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      ss.move_cursor_right()
      assert.equals(wins[1], helpers.curwin())
    end)

    it('falls back to at_edge when the backend throws', function()
      local backend = helpers.mock_backend({
        move = function()
          error('backend exploded')
        end,
      })
      ss.setup({ mux = { backend = backend }, move = { at_edge = 'wrap' } })
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      ss.move_cursor_right()
      assert.equals(wins[1], helpers.curwin())
    end)

    it('lets the backend handle split via at_edge', function()
      local backend = helpers.mock_backend({
        move = function()
          return true
        end,
      })
      ss.setup({ mux = { backend = backend }, move = { at_edge = 'split' } })
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      local before = #vim.api.nvim_tabpage_list_wins(0)
      ss.move_cursor_right()
      assert.equals(before, #vim.api.nvim_tabpage_list_wins(0))
    end)

    it('splits in nvim when the backend declines at_edge = split', function()
      ss.setup({ mux = { backend = helpers.mock_backend() }, move = { at_edge = 'split' } })
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      local before = #vim.api.nvim_tabpage_list_wins(0)
      ss.move_cursor_right()
      assert.equals(before + 1, #vim.api.nvim_tabpage_list_wins(0))
    end)
  end)

  describe('at_edge as a function', function()
    it('receives the direction and the resolved backend', function()
      local backend = helpers.mock_backend()
      local ctx
      ss.setup({
        mux = { backend = backend },
        move = {
          at_edge = function(context)
            ctx = context
          end,
        },
      })
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      ss.move_cursor_right()

      assert.equals('right', ctx.direction)
      assert.equals(backend, ctx.backend)
      assert.equals('function', type(ctx.split))
      assert.equals('function', type(ctx.wrap))
    end)

    it('receives a nil backend when none resolved', function()
      local ctx
      ss.setup({
        move = {
          at_edge = function(context)
            ctx = context
          end,
        },
      })
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      ss.move_cursor_right()
      assert.is_nil(ctx.backend)
    end)

    it('splits through ctx.split', function()
      ss.setup({
        move = {
          at_edge = function(ctx)
            ctx.split()
          end,
        },
      })
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      local before = #vim.api.nvim_tabpage_list_wins(0)
      ss.move_cursor_right()
      assert.equals(before + 1, #vim.api.nvim_tabpage_list_wins(0))
    end)

    it('wraps through ctx.wrap', function()
      ss.setup({
        move = {
          at_edge = function(ctx)
            ctx.wrap()
          end,
        },
      })
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[2])
      ss.move_cursor_right()
      assert.equals(wins[1], helpers.curwin())
    end)

    it('is not called away from an edge', function()
      local called = false
      ss.setup({
        move = {
          at_edge = function()
            called = true
          end,
        },
      })
      local wins = helpers.create_vsplits(2)
      helpers.focus(wins[1])
      ss.move_cursor_right()
      assert.is_false(called)
    end)
  end)
end)
