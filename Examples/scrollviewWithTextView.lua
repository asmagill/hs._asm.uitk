uitk = require("hs._asm.uitk")

p = uitk.window{x = 100, y = 100, h = 500, w = 500 }:show():passthroughCallback(cbinspect)
c = p:content()
s = uitk.element.content.scroller{}
t = uitk.element.textView{}
s.element = {
    _userdata        = t,
    allowsUndo       = true,
    usesInspectorBar = true,
    callback         = function(...) print("callback", finspect(...)) end,
    editingCallback  = function(...) print("editingCallback", finspect(...)) end,
    typingAttributes = { font = { name = "Courier New", size = 10 } },
}
c[1] = {
    _userdata        = s,
    frame            = { h = "100%", w = "100%" },
    verticalScroller = true,
    horizontalRuler  = true,
    rulersVisible    = true,
}

f = io.open(hs.configdir .. "/init.lua", "r")
if f then
    t:content(f:read("a"))
    f:close()
else
    error("unable to open " .. hs.configdir .. "/init.lua")
end
