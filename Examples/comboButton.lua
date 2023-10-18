uitk    = require("hs._asm.uitk")
local finspect = function(...) return (require("hs.inspect")({...}):gsub("%s+", " ")) end

p = uitk.window{x = 100, y = 100, h = 100, w = 100 }:show()
content = p:content():passthroughCallback(function(...)
    print("content passthrough:", finspect(...))
end)

content[1] = uitk.element.comboButton.buttonWithTitle("booyah")

m = uitk.menu("cb menu"):passthroughCallback(function(...)
    print("menu passthrough:", finspect(...))
end)
for i = 1, 10, 1 do
    m[#m + 1] = {
        title = "Item " .. tostring(i),
    }
end
content[1].menu = m
