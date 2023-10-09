-- REMOVE IF ADDED TO CORE APPLICATION
    repeat
        -- add proper user dylib path if it doesn't already exist
        if not package.cpath:match(hs.configdir .. "/%?.dylib") then
            package.cpath = hs.configdir .. "/?.dylib;" .. package.cpath
        end

        -- load docs file if provided
        local basePath, moduleName = debug.getinfo(1, "S").source:match("^@(.*)/([%w_]+).lua$")
        if basePath and moduleName then
            if moduleName == "init" then
                moduleName = moduleName:match("/([%w_]+)$")
            end

            local docsFileName = basePath .. "/" .. moduleName .. ".docs.json"
            if require"hs.fs".attributes(docsFileName) then
                require"hs.doc".registerJSONFile(docsFileName)
            end
        end

        -- setup loaders for submodules (if any)
        --     copy into Hammerspoon/setup.lua before removing

    until true -- executes once and hides any local variables we create
-- END REMOVE IF ADDED TO CORE APPLICATION

--- === hs._asm.uitk.element.image ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.element.image"
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libelement_"))

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

moduleMT.rotateLeft = function(self)
    self:rotationAngle(self:rotationAngle() - 90)
    return self
end

moduleMT.rotateRight = function(self)
    self:rotationAngle(self:rotationAngle() + 90)
    return self
end

moduleMT.zoomIn = function(self, factor)
    local factor = factor or 0.1
    local zoom   = self:zoom()
    return self:zoom(zoom * (1 + factor))
end

moduleMT.zoomOut = function(self, factor)
    local factor = factor or 0.1
    local zoom   = self:zoom()
    return self:zoom(zoom * (1 - factor))
end

moduleMT.resetZoom = function(self)
    return self:imageScaling("none"):imageAlignment("center"):zoom(1.0)
end

moduleMT.makeFit = function(self)
    return self:imageScaling("proportionallyUpOrDown"):imageAlignment("center"):zoomToFit()
end

-- Return Module Object --------------------------------------------------

return module
