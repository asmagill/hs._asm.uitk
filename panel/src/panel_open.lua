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

--- --- hs._asm.uitk.panel.open ---
---
--- Stuff

local USERDATA_TAG = "hs._asm.uitk.panel.open"
local uitk         = require("hs._asm.uitk")
local module       = uitk.panel.save._open
local fnutils      = require("hs.fnutils")

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

local sharedModuleKeys = uitk.panel.save._sharedWithOpen

-- Return Module Object --------------------------------------------------

uitk.util._properties.addPropertiesWrapper(moduleMT)

return setmetatable(module, {
    __call = function(self, ...) return self.new(...) end,
    __index = function(self, key)
        if fnutils.contains(sharedModuleKeys, key) then
            return uitk.panel.save[key]
        else
            return nil
        end
    end,
})
