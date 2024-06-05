require("model.editor.editorModel")
require("controller.editorController")
require("view.editor.editorView")
require("view.editor.visibleContent")

local mock = require("tests.mock")

describe('Editor', function()
  local love = {
    state = {
      --- @type AppState
      app_state = 'ready',
    },
    keyboard = {
      isDown = function() return false end
    }
  }
  mock.mock_love(love)
  local turtle_doc = {
    '',
    'Turtle graphics game inspired the LOGO family of languages.',
    '',
  }

  describe('opens', function()
    it('no wrap needed', function()
      local w = 80
      local mockConf = {
        view = {
          lines = 16,
          drawableChars = w,
        },
      }

      local model = EditorModel(mockConf)
      local controller = EditorController(model)
      EditorView(mockConf.view, controller)

      controller:open('turtle', turtle_doc)
      local buffer = controller:get_active_buffer()
      local bc = buffer:get_content()

      assert.same(turtle_doc, bc)
      assert.same(#turtle_doc, buffer:get_content_length())

      local sel = buffer:get_selection()
      local sel_t = buffer:get_selected_text()
      -- default selection is at the end
      assert.same({ #turtle_doc + 1 }, sel)
      -- and it's an empty line, of course
      assert.same({}, sel_t)
    end)
  end)

  describe('works', function()
    describe('with wrap', function()
      local w = 16
      local mockConf = {
        view = {
          lines = 16,
          drawableChars = w,
        },
      }

      local model = EditorModel(mockConf)
      local controller = EditorController(model)
      local view = EditorView(mockConf.view, controller)

      love.state.app_state = 'editor'
      controller:open('turtle', turtle_doc)
      view.buffer:open(model.buffer)

      local buffer = controller:get_active_buffer()
      local start_sel = #turtle_doc + 1

      it('opens', function()
        local bc = buffer:get_content()

        assert.same(turtle_doc, bc)
        assert.same(#turtle_doc, buffer:get_content_length())

        local sel = buffer:get_selection()
        local sel_t = buffer:get_selected_text()
        -- default selection is at the end
        assert.same({ start_sel }, sel)
        -- and it's an empty line, of course
        assert.same({}, sel_t)
      end)

      --- additional tests
      it('interacts', function()
        -- select middle line
        controller:keypressed('up')
        assert.same({ start_sel - 1 }, buffer:get_selection())
        controller:keypressed('up')
        assert.same({ start_sel - 2 }, buffer:get_selection())
        assert.same({ turtle_doc[2] }, model.buffer:get_selected_text())
        -- load it
        local input = function()
          return controller.input:get_input().text
        end
        controller:keypressed('escape')
        assert.same({ turtle_doc[2] }, input())
        -- moving selection clears input
        controller:keypressed('down')
        assert.same({ start_sel - 1 }, buffer:get_selection())
        assert.same({ '' }, input())
        -- add text
        controller:textinput('t')
        assert.same({ 't' }, input())
        controller:textinput('e')
        controller:textinput('s')
        controller:textinput('t')
        assert.same({ 'test' }, input())
        -- replace line with input content
        controller:keypressed('return')
        assert.same({ '' }, input())
        local bc = buffer:get_content()
        assert.same('test', bc[3])
        -- replace
        controller:textinput('i')
        controller:textinput('n')
        controller:textinput('s')
        controller:textinput('e')
        controller:textinput('r')
        controller:textinput('t')
        assert.same({ 'insert' }, input())
        controller:keypressed('escape')
        assert.same({ 'test' }, input())
      end)
    end)

    local sierpinski = {
      "function sierpinski(depth)",
      "  lines = { '*' }",
      "  for i = 2, depth + 1 do",
      "    sp, tmp = string.rep(' ', 2 ^ (i - 2))",
      "    tmp = {}",
      "    for idx, line in ipairs(lines) do",
      "      tmp[idx] = sp .. line .. sp",
      "      tmp[idx + #lines] = line .. ' ' .. line",
      "    end",
      "    lines = tmp",
      "  end",
      "  return table.concat(lines, '\n')",
      "end",
      "",
      "print(sierpinski(4))",
    }

    describe('with scroll', function()
      local l = 6
      local mockConf = {
        view = {
          lines = l,
          drawableChars = 80,
        },
      }

      local model = EditorModel(mockConf)
      local controller = EditorController(model)
      local view = EditorView(mockConf.view, controller)

      controller:open('sierpinski.lua', sierpinski)
      view.buffer:open(model.buffer)

      local visible = view.buffer.content
      local scroll = view.buffer.SCROLL_BY

      local off = #sierpinski - l + 1
      local start_range = Range(off + 1, #sierpinski + 1)

      it('loads', function()
        -- inital scroll is at EOF, meaning last l lines are visible
        -- plus the phantom line
        assert.same(off, view.buffer.offset)
        assert.same(start_range, visible.range)
      end)
      local base = Range(1, l)
      it('scrolls up', function()
        controller:keypressed('pageup')
        assert.same(start_range:translate(-scroll), visible.range)
        controller:keypressed('pageup')
        assert.same(start_range:translate(-scroll * 2), visible.range)
        controller:keypressed('pageup')
        assert.same(start_range:translate(-scroll * 3), visible.range)
        controller:keypressed('pageup')
      end)
      it('tops out', function()
        assert.same(base, visible.range)
      end)
      it('scrolls down', function()
        controller:keypressed('pagedown')
        assert.same(base:translate(scroll), visible.range)
        controller:keypressed('pagedown')
        assert.same(base:translate(scroll * 2), visible.range)
        controller:keypressed('pagedown')
        assert.same(base:translate(scroll * 3), visible.range)
        controller:keypressed('pagedown')
        assert.same(base:translate(scroll * 4), visible.range)
        controller:keypressed('pagedown')
      end)
      it('bottoms out', function()
        local limit = #sierpinski + visible.overscroll
        assert.same(Range(limit - l + 1, limit), visible.range)
      end)
    end)

    describe('with scroll and wrap', function()
      local l = 6
      local mockConf = {
        view = {
          lines = l,
          drawableChars = 27,
        },
      }

      local model = EditorModel(mockConf)
      local controller = EditorController(model)
      local view = EditorView(mockConf.view, controller)

      controller:open('sierpinski.lua', sierpinski)
      view.buffer:open(model.buffer)

      --- @type VisibleContent
      local visible = view.buffer.content
      local scroll = view.buffer.SCROLL_BY

      local clen = visible:get_content_length()
      local off = clen - l + 1
      local start_range = Range(off + 1, clen + 1)
      it('loads', function()
        -- inital scroll is at EOF, meaning last l lines are visible
        -- plus the phantom line
        assert.same(off, view.buffer.offset)
        assert.same(start_range, visible.range)
      end)
      local base = Range(1, l)
      it('scrolls up', function()
        controller:keypressed('pageup')
        assert.same(start_range:translate(-scroll), visible.range)
        controller:keypressed('pageup')
        assert.same(start_range:translate(-scroll * 2), visible.range)
        controller:keypressed('pageup')
        assert.same(start_range:translate(-scroll * 3), visible.range)
        controller:keypressed('pageup')
        assert.same(start_range:translate(-scroll * 4), visible.range)
      end)
      it('tops out', function()
        controller:keypressed('pageup')
        assert.same(base, visible.range)
      end)
      it('scrolls down', function()
        controller:keypressed('pagedown')
        assert.same(base:translate(scroll), visible.range)
        controller:keypressed('pagedown')
        assert.same(base:translate(scroll * 2), visible.range)
        controller:keypressed('pagedown')
        assert.same(base:translate(scroll * 3), visible.range)
        controller:keypressed('pagedown')
        assert.same(base:translate(scroll * 4), visible.range)
        controller:keypressed('pagedown')
        assert.same(base:translate(scroll * 5), visible.range)
      end)
      it('bottoms out', function()
        controller:keypressed('pagedown')
        local limit = clen + visible.overscroll
        assert.same(Range(limit - l + 1, limit), visible.range)
      end)
    end)
  end)
end)