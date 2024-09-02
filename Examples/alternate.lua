local uitk = require("hs._asm.uitk")
local finspect = function(...) return (require("hs.inspect")({...}):gsub("%s+", " ")) end

m   = uitk.menu("myMenu"):callback(function(...) print("m", timestamp(), finspect(...)) end)

si  = uitk.statusbar(true):callback(function(...) print("si", timestamp(), finspect(...)) end)
                          :title(hs.styledtext.new("yes", { color = { green = 1 } }))
                          :alternateTitle(hs.styledtext.new("no", { color = { red = 1 } }))
                          :tooltip("A menu of alternates")
                          :menu(m)

local modifiers = { "cmd", "alt", "shift", "ctrl" }
local i = 0
for k, v in hs.fnutils.sortByKeys(uitk.menu.item._characterMap) do
    m[#m + 1] = {
        title         = k,
        callback      = function(...) print("i", timestamp(), finspect(...)) end,
        keyEquivalent = k,
        keyModifiers  = { },
    }

    for i = 1, #modifiers, 1 do
        m[#m + 1] = {
            title         = modifiers[i].. " " .. k,
            callback      = function(...) print("i", timestamp(), finspect(...)) end,
            keyEquivalent = k,
            alternate     = true,
            keyModifiers  = { [modifiers[i]] = true },
        }
        for j = i + 1, #modifiers, 1 do
            m[#m + 1] = {
                title         = modifiers[i].. " " .. modifiers[j] .. " " .. k,
                callback      = function(...) print("i", timestamp(), finspect(...)) end,
                keyEquivalent = k,
                alternate     = true,
                keyModifiers  = { [modifiers[i]] = true, [modifiers[j]] = true },
            }
            for l = j + 1, #modifiers, 1 do
                m[#m + 1] = {
                    title         = modifiers[i].. " " .. modifiers[j] .. " " .. modifiers[l] .. " " .. k,
                    callback      = function(...) print("i", timestamp(), finspect(...)) end,
                    keyEquivalent = k,
                    alternate     = true,
                    keyModifiers  = { [modifiers[i]] = true, [modifiers[j]] = true, [modifiers[l]] = true },
                }
                for n = l + 1, #modifiers, 1 do
                    m[#m + 1] = {
                        title         = modifiers[i].. " " .. modifiers[j] .. " " .. modifiers[l] .. " " .. modifiers[n] .. " " .. k,
                        callback      = function(...) print("i", timestamp(), finspect(...)) end,
                        keyEquivalent = k,
                        alternate     = true,
                        keyModifiers  = { [modifiers[i]] = true, [modifiers[j]] = true, [modifiers[l]] = true, [modifiers[n]] = true },
                    }
                end
            end
        end
    end

    i = (i + 1) % 10
    if i == 0 then m:insert(uitk.menu.item("-")) end
end
