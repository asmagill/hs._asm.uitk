local uitk = require("hs._asm.uitk")
local finspect = function(...) return (require("hs.inspect")({...}):gsub("%s+", " ")) end

m   = uitk.menu("myMenu"):callback(function(...) print("m", timestamp(), finspect(...)) end)

si  = uitk.menubar(true):callback(function(...) print("si", timestamp(), finspect(...)) end)
                        :title(hs.styledtext.new("yes", { color = { green = 1 } }))
                        :alternateTitle(hs.styledtext.new("no", { color = { red = 1 } }))
                        :tooltip("A menu of things")
                        :menu(m)

local i = 0
for k, v in hs.fnutils.sortByKeys(uitk.menu.item._characterMap) do
    m[#m + 1] = {
        title         = k,
        callback      = (function(...) print("i", timestamp(), finspect(...)) end),
        keyEquivalent = k,
    }

    m[#m + 1] = {
        title         = "Alt " .. k,
        callback      = (function(...) print("i", timestamp(), finspect(...)) end),
        keyEquivalent = k,
        alternate     = true,
        keyModifiers  = { alt = true },
    }

    m[#m + 1] = {
        title         = "Shift " .. k,
        callback      = (function(...) print("i", timestamp(), finspect(...)) end),
        keyEquivalent = k,
        alternate     = true,
        keyModifiers  = { shift = true },
    }

    i = (i + 1) % 10
    if i == 0 then m:insert(uitk.menu.item("-")) end
end
