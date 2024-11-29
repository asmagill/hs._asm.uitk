-- see https://learn.adafruit.com/tft-gizmo-turtle#step-3045342

local uitk = require("hs._asm.uitk")
w = uitk.window{x = 100, y = 100, h = 1000, w = 1000 }:show()
t = uitk.element.turtle{}
w:content(t)

local frameSize = t:frameSize()
local benzsize = math.min(frameSize.w, frameSize.h) * 0.5

local colors = { "red", "orange", "yellow", "green", "blue", "purple" }

t:pendown()

for x = 0, (benzsize - 1), 1 do
    t:setpencolor(colors[x % #colors + 1])
    t:forward(x)
    t:left(59)
end
