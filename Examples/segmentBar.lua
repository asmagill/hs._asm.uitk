uitk = require("hs._asm.uitk")

win = uitk.panel{ x = 100, y = 100, h = 500, w = 500 }:show()
grp = win:content()

grp[1] = { _userdata = uitk.element.segmentBar.new():segmentCount(5):labels({"a","b","c",nil,"d"}), frame = { cX = "50%", w = "80%" } }

m = uitk.menu.new("myMenu"):passthroughCallback(function(...)
                                print("Menu passthrough callback:", os.date())
                                print(require("hs.inspect").inspect({...}))
                            end)

for i = 1, 10, 1 do m[i] = { _item = uitk.menu.item.new(tostring(i)) } end
grp[1].menus = { nil, nil, nil, m, nil }
