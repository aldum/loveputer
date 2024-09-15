require("view.input.statusline")
require("util.debug")
require("util.view")

--- @class InputView
--- @field cfg ViewConfig
--- @field controller InputController
--- @field statusline table
--- @field oneshot boolean
--- @field draw function
InputView = {}
InputView.__index = InputView

setmetatable(InputView, {
  __call = function(cls, ...)
    return cls.new(...)
  end,
})

--- @param cfg ViewConfig
--- @param ctrl InputController
function InputView.new(cfg, ctrl)
  local self = setmetatable({
    cfg = cfg,
    controller = ctrl,
    statusline = Statusline:new(cfg),
    oneshot = ctrl.model.oneshot,
  }
  , InputView)

  return self
end

--- @param input InputDTO
--- @param time number
function InputView:draw(input, time)
  local G = love.graphics

  local cfg = self.cfg
  local status = self.controller:get_status()
  local cf_colors = cfg.colors
  local colors = (function()
    if love.state.app_state == 'inspect' then
      return cf_colors.input.inspect
    elseif love.state.app_state == 'running' then
      return cf_colors.input.user
    else
      return cf_colors.input.console
    end
  end)()

  local fh = cfg.fh
  local fw = cfg.fw
  local h = cfg.h
  local drawableWidth = cfg.drawableWidth
  local drawableChars = cfg.drawableChars
  -- drawtest hack
  if drawableWidth < love.fixWidth / 3 then
    drawableChars = drawableChars * 2
  end

  local text = input.text
  local vc = input.visible
  local inLines = math.min(vc:get_content_length(), cfg.input_max)
  local apparentLines = inLines
  local inHeight = inLines * fh
  local apparentHeight = inHeight
  local y = h - (#text * fh)

  local wt = input.wrapped_text
  local wrap_forward = wt.wrap_forward
  local wrap_reverse = wt.wrap_reverse

  local start_y = h - apparentLines * fh

  local drawBackground = function()
    G.setColor(colors.bg)
    G.rectangle("fill",
      0,
      start_y,
      drawableWidth,
      apparentHeight * fh)
  end

  start_y = h - apparentLines * fh

  local function drawCursor()
    local cursorInfo = self.controller:get_cursor_info()
    local cl, cc = cursorInfo.cursor.l, cursorInfo.cursor.c
    local y_offset = math.floor((cc - 1) / drawableChars)
    local yi = y_offset + 1
    local acl = (wrap_forward[cl] or { 1 })[yi] or 1
    local vcl = acl - vc.offset

    if vcl < 1 then return end

    local ch = start_y + (vcl - 1) * fh
    local x_offset = (function()
      if cc > drawableChars then
        return math.fmod(cc, drawableChars)
      else
        return cc
      end
    end)()

    G.push('all')
    G.setColor(cf_colors.input.cursor)
    G.print('|', (x_offset - 1.5) * fw, ch)
    G.pop()
  end

  local highlight = input.highlight
  local visible = vc:get_visible()
  G.push('all')
  G.setFont(self.cfg.font)
  drawBackground()
  self.statusline:draw(status, apparentLines, time)

  if highlight then
    local perr = highlight.parse_err
    local el, ec
    if perr then
      el = perr.l
      ec = perr.c
    end
    for l, s in ipairs(visible) do
      local ln = l + vc.offset
      for c = 1, string.ulen(s) do
        local char = string.usub(s, c, c)
        local hl_li = wrap_reverse[ln]
        local hl_ci = (function()
          if #(wrap_forward[hl_li]) > 1 then
            local offset = l - hl_li
            return c + drawableChars * offset
          else
            return c
          end
        end)()
        local row = highlight.hl[hl_li] or {}
        local ttype = row[hl_ci]
        local color
        if perr and ln > el or
            (ln == el and (c > ec or ec == 1)) then
          color = cf_colors.input.error
        else
          color = cf_colors.input.syntax[ttype] or colors.fg
        end
        local selected = (function()
          local sel = input.selection
          local startl = sel.start and sel.start.l
          local endl = sel.fin and sel.fin.l
          if startl then
            local startc = sel.start.c
            local endc = sel.fin.c
            if startc and endc then
              if startl == endl then
                local sc = math.min(sel.start.c, sel.fin.c)
                local endi = math.max(sel.start.c, sel.fin.c)
                return l == startl and c >= sc and c < endi
              else
                return
                    (l == startl and c >= sel.start.c) or
                    (l > startl and l < endl) or
                    (l == endl and c < sel.fin.c)
              end
            end
          end
        end)()
        --- number of lines back from EOF
        local diffset = #text - vc.range.fin
        local dy = y - (-ln - diffset + 1) * fh
        local dx = (c - 1) * fw
        ViewUtils.write_token(dy, dx, char, color, colors.bg, selected)
      end
    end
  else
    for l, str in ipairs(visible) do
      G.setColor(colors.fg)
      ViewUtils.write_line(l, str, start_y, 0, self.cfg)
    end
  end
  drawCursor()
  G.pop()
end
