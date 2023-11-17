uitk = require("hs._asm.uitk")
local finspect = function(...) return (require("hs.inspect")({...}):gsub("%s+", " ")) end

p = uitk.window{x = 100, y = 100, h = 500, w = 500 }:show():passthroughCallback(function(...) print("window", finspect(...)) end)
c = p:content()

s = uitk.element.container.scroller{}
s._properties.document = uitk.element.textView{}
s._properties.document._properties = {
    allowsUndo       = true,
    usesInspectorBar = true,
    callback         = function(...) print("callback", finspect(...)) end,
    editingCallback  = function(...) print("editingCallback", finspect(...)) end,
    typingAttributes = { font = { name = "Courier New", size = 10 } },
}

c[1] = {
    _element         = s,
    containerFrame   = { h = "100%", w = "100%" },
    verticalScroller = true,
    horizontalRuler  = true,
    rulersVisible    = true,
}

f = io.open(hs.configdir .. "/init.lua", "r")
if f then
    s._properties.document:content(f:read("a"))
    f:close()
else
    error("unable to open " .. hs.configdir .. "/init.lua")
end
