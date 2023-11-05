if require("hs.settings").get("uitk_wrapColor") then
    return require("hs._asm.uitk").util.color
else
    return dofile(hs.processInfo.bundlePath .. "/Contents/Resources/extensions/hs/drawing_color.lua")
end
