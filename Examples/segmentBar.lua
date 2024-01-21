uitk = require("hs._asm.uitk")

win = uitk.window{ x = 100, y = 100, h = 500, w = 500 }:show()
grp = win:content()

grp:passthroughCallback(function(...)
        print("Content passthrough callback:", os.date())
        print(require("hs.inspect").inspect({...}))
    end)

grp[1] = { _self = uitk.element.segmentBar.new():segmentCount(5):labels({"a","b","c",nil,"d"}), containerFrame = { cX = "50%", w = "80%" } }

m = uitk.menu.new("myMenu"):passthroughCallback(function(...)
                                print("Menu passthrough callback:", os.date())
                                print(require("hs.inspect").inspect({...}))
                            end)

for i = 1, 10, 1 do m[i] = { _self = uitk.menu.item.new(tostring(i)) } end
grp[1]._properties.menus = { nil, nil, nil, m, nil }
