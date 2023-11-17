local uitk = require("hs._asm.uitk")
w = uitk.window{x = 100, y = 100, h = 1000, w = 1000 }:show()
t = uitk.element.turtle{}
w:content(t)

tgFern = function(turtle, size, sign)
    local tgFern2
    tgFern2 = function(turtle, size, sign)
        if size < 1 then return end
        turtle:forward(size)
        turtle:right(70 * sign)
        tgFern2(turtle, size * .5, -sign)
        turtle:left(70 * sign)

        turtle:forward(size)
        turtle:left(70 * sign)
        tgFern2(turtle, size * .5, sign)
        turtle:right(70 * sign)

        turtle:right(7 * sign)
        tgFern2(turtle, size -1, sign)
        turtle:left(7 * sign)

        turtle:back(size * 2)
    end

    turtle:penup():back(150):pendown()
    tgFern2(turtle, size, sign)
end

-- t:cs()
-- tgFern(t, 25, 1)

-- for i = 0, 359, 45 do t:home():rt(i) ; tgFern(t, 25, 2) end

fern = function(turtle, size, sign)
    if (size >= 1) then
        turtle:forward(size):right(70 * sign)
        fern(turtle, size * 0.5, sign * -1)
        turtle:left(70 * sign):forward(size):left(70 * sign)
        fern(turtle, size * 0.5, sign)
        turtle:right(70 * sign):right(7 * sign)
        fern(turtle, size - 1, sign)
        turtle:left(7 * sign):back(size * 2)
    end
end

wheel = function(turtle, _step)
    local t = os.time()
    for i = 0, 359, (_step or 90) do
        turtle:penup():home():setheading(i):back(150):pendown()
        fern(turtle, 25, 1)
        fern(turtle, 25, -1)
    end
    print("Completed in", os.time() - t)
end

t:cs()
wheel(t, 90)
