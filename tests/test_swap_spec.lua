---@module 'busted'

local helpers = require('tests.helpers')

describe('swap_buf', function()
  local ss

  before_each(function()
    helpers.reset_plugin()
    ss = require('smart-splits')
  end)

  after_each(function()
    helpers.reset_editor()
    helpers.reset_plugin()
  end)

  describe('horizontal swaps', function()
    it('swaps buffers between left and right splits', function()
      local wins = helpers.create_vsplits(2)
      helpers.unique_buffers(wins)
      local buf_1 = vim.api.nvim_win_get_buf(wins[1])
      local buf_2 = vim.api.nvim_win_get_buf(wins[2])
      helpers.focus(wins[1])
      ss.swap_buf_right()
      assert.equals(buf_2, vim.api.nvim_win_get_buf(wins[1]))
      assert.equals(buf_1, vim.api.nvim_win_get_buf(wins[2]))
    end)

    it('leaves the cursor in the original window by default', function()
      local wins = helpers.create_vsplits(2)
      helpers.unique_buffers(wins)
      helpers.focus(wins[1])
      ss.swap_buf_right()
      assert.equals(wins[1], helpers.curwin())
    end)

    it('follows the buffer when swap.move_cursor is set', function()
      ss.setup({ swap = { move_cursor = true } })
      local wins = helpers.create_vsplits(2)
      helpers.unique_buffers(wins)
      helpers.focus(wins[1])
      ss.swap_buf_right()
      assert.equals(wins[2], helpers.curwin())
    end)

    it('follows the buffer with a per call override', function()
      local wins = helpers.create_vsplits(2)
      helpers.unique_buffers(wins)
      helpers.focus(wins[1])
      ss.swap_buf_right({ move_cursor = true })
      assert.equals(wins[2], helpers.curwin())
    end)

    it('stays put with a per call override against the config', function()
      ss.setup({ swap = { move_cursor = true } })
      local wins = helpers.create_vsplits(2)
      helpers.unique_buffers(wins)
      helpers.focus(wins[1])
      ss.swap_buf_right({ move_cursor = false })
      assert.equals(wins[1], helpers.curwin())
    end)

    it('preserves scroll position when move_cursor is true', function()
      ss.setup({ swap = { move_cursor = true } })
      local wins = helpers.create_vsplits(2)
      helpers.unique_buffers(wins)

      -- Fill buffers with enough lines to scroll
      local lines = {}
      for i = 1, 100 do
        table.insert(lines, 'Line ' .. i)
      end
      vim.api.nvim_buf_set_lines(vim.api.nvim_win_get_buf(wins[1]), 0, -1, false, lines)
      vim.api.nvim_buf_set_lines(vim.api.nvim_win_get_buf(wins[2]), 0, -1, false, lines)

      -- Scroll each window to different positions
      helpers.focus(wins[1])
      vim.api.nvim_win_set_cursor(wins[1], { 50, 0 })
      vim.cmd('normal! zz')
      local view_1_before = vim.fn.winsaveview()

      helpers.focus(wins[2])
      vim.api.nvim_win_set_cursor(wins[2], { 75, 0 })
      vim.cmd('normal! zz')
      local view_2_before = vim.fn.winsaveview()

      -- Swap with move_cursor
      helpers.focus(wins[1])
      ss.swap_buf_right()

      -- Cursor should be in win_2 (following buf_1)
      assert.equals(wins[2], helpers.curwin())

      -- Scroll position should be preserved
      local view_1_after = vim.fn.winsaveview()
      assert.equals(view_1_before.topline, view_1_after.topline)
      assert.equals(view_1_before.lnum, view_1_after.lnum)

      -- Check win_1 as well
      helpers.focus(wins[1])
      local view_2_after = vim.fn.winsaveview()
      assert.equals(view_2_before.topline, view_2_after.topline)
      assert.equals(view_2_before.lnum, view_2_after.lnum)
    end)

    it('preserves scroll position when move_cursor is false', function()
      -- default: move_cursor = false
      local wins = helpers.create_vsplits(2)
      helpers.unique_buffers(wins)

      local lines = {}
      for i = 1, 100 do
        table.insert(lines, 'Line ' .. i)
      end
      vim.api.nvim_buf_set_lines(vim.api.nvim_win_get_buf(wins[1]), 0, -1, false, lines)
      vim.api.nvim_buf_set_lines(vim.api.nvim_win_get_buf(wins[2]), 0, -1, false, lines)

      helpers.focus(wins[1])
      vim.api.nvim_win_set_cursor(wins[1], { 50, 0 })
      vim.cmd('normal! zz')
      local view_1_before = vim.fn.winsaveview()

      helpers.focus(wins[2])
      vim.api.nvim_win_set_cursor(wins[2], { 75, 0 })
      vim.cmd('normal! zz')
      local view_2_before = vim.fn.winsaveview()

      -- Swap without move_cursor (default)
      helpers.focus(wins[1])
      ss.swap_buf_right()

      -- Cursor should stay in win_1
      assert.equals(wins[1], helpers.curwin())

      -- win_1 now has buf_2, so it should have view_2's scroll position
      local view_1_after = vim.fn.winsaveview()
      assert.equals(view_2_before.topline, view_1_after.topline)

      -- win_2 now has buf_1, so it should have view_1's scroll position
      helpers.focus(wins[2])
      local view_2_after = vim.fn.winsaveview()
      assert.equals(view_1_before.topline, view_2_after.topline)
    end)
  end)

  describe('vertical swaps', function()
    it('swaps buffers between top and bottom splits', function()
      local wins = helpers.create_hsplits(2)
      helpers.unique_buffers(wins)
      local buf_1 = vim.api.nvim_win_get_buf(wins[1])
      local buf_2 = vim.api.nvim_win_get_buf(wins[2])
      helpers.focus(wins[1])
      ss.swap_buf_down()
      assert.equals(buf_2, vim.api.nvim_win_get_buf(wins[1]))
      assert.equals(buf_1, vim.api.nvim_win_get_buf(wins[2]))
    end)
  end)

  describe('wrapping', function()
    it('wraps from the rightmost to the leftmost split', function()
      local wins = helpers.create_vsplits(2)
      helpers.unique_buffers(wins)
      local buf_1 = vim.api.nvim_win_get_buf(wins[1])
      local buf_2 = vim.api.nvim_win_get_buf(wins[2])
      helpers.focus(wins[2])
      ss.swap_buf_right()
      assert.equals(buf_2, vim.api.nvim_win_get_buf(wins[1]))
      assert.equals(buf_1, vim.api.nvim_win_get_buf(wins[2]))
    end)

    it('wraps from the leftmost to the rightmost split', function()
      local wins = helpers.create_vsplits(2)
      helpers.unique_buffers(wins)
      local buf_1 = vim.api.nvim_win_get_buf(wins[1])
      local buf_2 = vim.api.nvim_win_get_buf(wins[2])
      helpers.focus(wins[1])
      ss.swap_buf_left()
      assert.equals(buf_2, vim.api.nvim_win_get_buf(wins[1]))
      assert.equals(buf_1, vim.api.nvim_win_get_buf(wins[2]))
    end)
  end)

  describe('3 splits', function()
    it('swaps the middle with the right', function()
      local wins = helpers.create_vsplits(3)
      helpers.unique_buffers(wins)
      local buf_2 = vim.api.nvim_win_get_buf(wins[2])
      local buf_3 = vim.api.nvim_win_get_buf(wins[3])
      helpers.focus(wins[2])
      ss.swap_buf_right()
      assert.equals(buf_3, vim.api.nvim_win_get_buf(wins[2]))
      assert.equals(buf_2, vim.api.nvim_win_get_buf(wins[3]))
    end)
  end)

  describe('backend', function()
    it('never consults the backend, swapping is a pure Neovim operation', function()
      local backend, calls = helpers.mock_backend()
      ss.setup({ mux = { backend = backend } })
      local wins = helpers.create_vsplits(2)
      helpers.unique_buffers(wins)
      helpers.focus(wins[2])
      ss.swap_buf_right()
      assert.is_false(vim.tbl_contains(helpers.ops(calls), 'move'))
      assert.is_false(vim.tbl_contains(helpers.ops(calls), 'split'))
    end)
  end)
end)
