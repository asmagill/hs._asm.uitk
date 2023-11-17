if require("hs.settings").get("uitk_wrapCanvas") then
    return require("hs._asm.uitk").element.canvas._legacy
else
    return dofile(hs.processInfo.bundlePath .. "/Contents/Resources/extensions/hs/canvas.lua")
end
