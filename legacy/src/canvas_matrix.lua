if require("hs.settings").get("uitk_wrapCanvas") then
    return require("hs._asm.uitk").util.matrix
else
    return dofile(hs.processInfo.bundlePath .. "/Contents/Resources/extensions/hs/canvas_matrix.lua")
end
