uitk = require("hs._asm.uitk")
local finspect = function(...) return (require("hs.inspect")({...}):gsub("%s+", " ")) end

p = uitk.window{x = 100, y = 100, h = 500, w = 500 }:show():passthroughCallback(function(...) print("window", finspect(...)) end)

s1 = uitk.element.container.split{ h = 500, w = 500 }:vertical(true)
s2 = uitk.element.container.split{ h = 500, w = 200 }

p:content(s1)

sc = uitk.element.container.scroller{}
sc._properties = {
    document = uitk.element.textView{},
    verticalScroller = true,
    horizontalRuler  = true,
    rulersVisible    = true,
}

sc._properties.document._properties = {
    allowsUndo       = true,
    usesInspectorBar = true,
    callback         = function(...) print("callback", finspect(...)) end,
    editingCallback  = function(...) print("editingCallback", finspect(...)) end,
    typingAttributes = { font = { name = "Courier New", size = 10 } },
}

s1[1] = sc
s1[2] = s2

radio = uitk.element.container{ h = 250, w = 200 }:tooltip("grouped radiobuttons")
radio:insert(uitk.element.button.radioButton("A"):tooltip("A"))
radio:insert(uitk.element.button.radioButton("B"):tooltip("not A"))
radio:insert(uitk.element.button.radioButton("C"):tooltip("also not A"))


s2[1] = radio
s2[2] = uitk.element.progress.new():circular(true):start()

f = io.open(hs.configdir .. "/init.lua", "r")
if f then
    sc._properties.document:content(f:read("a"))
    f:close()
else
    error("unable to open " .. hs.configdir .. "/init.lua")
end
