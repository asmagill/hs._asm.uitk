-- see https://learn.adafruit.com/tft-gizmo-turtle#step-3045344

local uitk = require("hs._asm.uitk")
w = uitk.window{x = 100, y = 100, h = 1000, w = 1000 }:show()
t = uitk.element.turtle{}
w:content(t)

local dot  = function(t, size)
    for i = size, 1, -1 do
        t:arc(360, i)
    end
end

local vert = function(t, x, y, size)
    t:setxy(x, y)
    dot(t, size)
end

t:setscrunch(4, 4)
t:setpensize(4)
t:penup()
t:setpencolor("green")

vert(t, 0, 0, 7)
vert(t, 0, 100, 7)
vert(t, 100, 0, 7)
vert(t, 0, -100, 7)
vert(t, -100, 0, 7)

local x_quad = { 10, 10, -10, -10 }
local y_quad = { 10, -10, -10, 10 }

for q = 1, 4, 1 do
    for i = 0, 10, 1 do
        local x_from = 0
        local y_from = (10 - i) * y_quad[q]
        local x_to = i * x_quad[q]
        local y_to = 0
        t:penup():setxy(x_from, y_from):pendown():setxy(x_to, y_to)
    end
end

t:penup():home():hideturtle()
