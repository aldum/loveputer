require("model.editor.content")
require("model.interpreter.eval.luaEval")

require('util.table')
require('util.range')
require('util.string')
require('util.dequeue')

--- @alias Block Empty|Chunk
--- @alias Content Dequeue<string>|Dequeue<Block>

--- @alias Chunker fun(s: string[], s: boolean?): Dequeue<Block>
--- @alias Highlighter fun(c: string[]): SyntaxColoring
--- @alias Printer fun(c: string[]): string[]?

--- @class BufferModel
--- @field name string
--- @field content Dequeue -- Content
--- @field content_type ContentType
--- @field selection integer
--- @field readonly boolean
--- @field revmap table
---
--- @field chunker Chunker
--- @field highlighter Highlighter
--- @field printer Printer
--- @field move_selection function
--- @field get_selection function
--- @field get_selected_text function
--- @field delete_selected_text function
--- @field replace_selected_text function
BufferModel = {}
BufferModel.__index = BufferModel

setmetatable(BufferModel, {
  __call = function(cls, ...)
    return cls.new(...)
  end,
})

--- @param name string
--- @param content string[]
--- @param chunker Chunker
--- @param highlighter Highlighter
--- @param printer function
--- @return BufferModel?
function BufferModel.new(name, content, chunker, highlighter, printer)
  local _content, sel, ct
  local readonly = false

  if type(chunker) == "function" then
    ct = 'lua'
    local ok, blocks = chunker(content)
    if ok then
      local len = #blocks
      sel = len + 1
    else
      readonly = true
      sel = 1
    end
    _content = blocks
  else
    ct = 'plain'
    _content = Dequeue(content, 'string')
    sel = #_content + 1
  end

  local self = setmetatable({
    name = name or 'untitled',
    content = _content,
    content_type = ct,
    chunker = chunker,
    highlighter = highlighter,
    printer = printer,
    selection = sel,
    readonly = readonly
  }, BufferModel)

  return self
end

--- @return Dequeue
function BufferModel:get_content()
  return self.content
end

--- @return string[]
function BufferModel:get_text_content()
  if self.content_type == 'lua'
  then
    return self:render_blocks(self.content)
  elseif self.content_type == 'plain'
  then
    return self.content
  end
  return {}
end

--- @return string[]
function BufferModel:render_blocks(blocks)
  local ret = Dequeue.typed('string')
  for _, v in ipairs(blocks) do
    if v.tag == 'chunk' then
      ret:append_all(v.lines)
    elseif v.tag == 'empty' then
      ret:append('')
    end
  end
  return ret
end

--- @return integer
function BufferModel:get_content_length()
  return #(self.content) or 0
end

--- @param dir VerticalDir
--- @param by integer
--- @param warp boolean?
--- @return boolean moved
function BufferModel:move_selection(dir, by, warp)
  local last = self:get_content_length() + 1
  if warp then
    if dir == 'up' then
      self.selection = 1
      return true
    end
    if dir == 'down' then
      self.selection = last
      return true
    end
    return false
  end

  local cur = self.selection
  local by = by or 1
  if dir == 'up' then
    if (cur - by) >= 1 then
      self.selection = cur - by
      return true
    end
  end
  if dir == 'down' then
    if (cur + by) <= last then
      self.selection = cur + by
      return true
    end
  end
  return false
end

--- @return integer
function BufferModel:get_selection()
  return self.selection
end

--- @return string[]
function BufferModel:get_selected_text()
  local sel = self.selection
  if self.content_type == 'lua' then
    --- @type Block
    local s = self.content[sel]
    if table.is_instance(s, 'chunk') then
      return table.clone(s.lines)
    else
      return {}
    end
  else
    return self.content[sel] or {}
  end
end

function BufferModel:delete_selected_text()
  local sel = self.selection
  if self.content_type == 'lua' then
    local sb = self.content[sel]
    if not sb then return end
    local l = sb.pos:len()
    self.content:remove(sel)
    for i = sel, self:get_content_length() do
      local b = self.content[i]
      local r = b.pos
      b.pos = r:translate(-l)
    end
  else
    self.content:remove(sel)
  end
end

--- @param t string[]|Block[]
--- @return boolean insert
--- @return integer? inserted_lines
function BufferModel:replace_selected_text(t)
  if self.content_type == 'lua' then
    local chunks = t
    local n = #chunks
    if n == 0 then
      return false
    end
    local sel = self.selection
    local cs = (function()
      local current = self.content[sel]
      if current then return current.pos.start end
      return self.content:last().pos.fin + 1
    end)()

    self.content:remove(sel)
    for i = #chunks, 1, -1 do
      local c = chunks[i]
      local nr = c.pos:translate(cs - 1)
      c.pos = nr
      self.content:insert(c, sel)
    end
    local diff = chunks[n].pos.fin - cs
    for i = sel + diff + 1, self:get_content_length() do
      local b = self.content[i]
      b.pos = b.pos:translate(diff)
    end

    return true, n
  else
    local sel = self.selection
    local clen = #(self.content)
    local ti = sel
    if #t == 1 then
      self.content[ti] = t[1]
      if ti > clen then
        return true, 1
      end
    else
      self.content:remove(ti)
      for i = #t, 1, -1 do
        self.content:insert(t[i], ti)
      end
      return true, #t
    end
    return false
  end
end
