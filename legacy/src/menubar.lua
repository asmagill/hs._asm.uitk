if require("hs.settings").get("uitk_wrapMenubar") then
    return require("hs._asm.uitk").statusbar._legacy
else
    return dofile(hs.processInfo.bundlePath .. "/Contents/Resources/extensions/hs/menubar.lua")
end
