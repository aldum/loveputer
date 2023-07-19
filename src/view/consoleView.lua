require("view/color")
require("view/titleView")
require("view/canvasView")
require("view/inputView")

local G = love.graphics

ConsoleView = {}

function ConsoleView:new(cfg, ctrl)
  local conf = {
    font_size = 18,
    border = 0,
    colors = {
      bg = Color[Color.white],
      border = Color[Color.black + Color.bright],
      fg = Color[Color.blue + Color.bright],
      stat_fg = Color[Color.white + Color.bright],
      debug = Color[Color.yellow],
    }
  }
  for k, v in pairs(cfg) do
    conf[k] = v
  end

  local FAC = 1
  if love.hiDPI then
    FAC = 2
  end
  G.scale(FAC, FAC)

  local font_dir = "assets/fonts/"
  conf.font_main = love.graphics.newFont(
    font_dir .. "ubuntu_mono_bold_nerd.ttf", cfg.font_size * FAC)
  conf.fh = conf.font_main:getHeight()
  conf.font_title = love.graphics.newFont(
    font_dir .. "PressStart2P-Regular.ttf", cfg.font_size * FAC)

  G.setFont(conf.font_main)

  local BORDER = conf.border * FAC
  local FH = conf.fh
  conf.fac = FAC
  conf.border = BORDER
  conf.fh = FH
  conf.width = G.getWidth()
  conf.height = G.getHeight()

  local view = {
    title = TitleView,
    canvas = CanvasView:new(conf),
    input = InputView:new(conf, ctrl),
    controller = ctrl,
    cfg = conf,
  }

  setmetatable(view, self)
  self.__index = self

  return view
end

function ConsoleView:resize(wi, hi)
  local w = wi / self.cfg.fac
  local h = hi / self.cfg.fac

  self.canvas_drawable_height = self.cfg.get_drawable_height(h)

  local inputBox = {
    x = self.cfg.border,
    y = self.cfg.border + self.canvas_drawable_height + 2 * self.cfg.border,
    w = w - 2 * self.cfg.border,
    h = self.cfg.fh,
  }

  love.keyboard.setTextInput(true,
    inputBox.x, inputBox.y, inputBox.w, inputBox.h)
end

function ConsoleView:draw()
  local b = self.cfg.border

  G.scale(self.fac, self.fac)

  local w = self.cfg.width
  local h = self.cfg.height

  local background = {
    draw = function()
      G.setColor(self.cfg.colors.border)
      G.rectangle("fill", 0, 0, w, h)
    end,
  }

  background.draw()
  self.canvas:draw(self.controller:get_result())
  self.input:draw(self.controller:get_input())
end
