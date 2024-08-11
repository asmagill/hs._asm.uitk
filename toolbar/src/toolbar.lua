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

--- === hs._asm.uitk.toolbar ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.toolbar"

local uitk         = require("hs._asm.uitk")
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib"))

-- local fnutils = require("hs.fnutils")
-- module._legacy     = require(USERDATA_TAG .. "_legacy")

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)
local dictionaryMT = hs.getObjectMetatable(USERDATA_TAG .. ".dictionary")
local itemMT       = hs.getObjectMetatable(USERDATA_TAG .. ".item")

-- create pass-throughs in toolbar for source dictionary
for k, v in pairs(dictionaryMT) do
    if not moduleMT[k] then
        moduleMT[k] = function(self, ...)
            local dict = self:dictionary()
            local results = table.pack(dictionaryMT[k](dict, ...))
            if results[1] == dict then results[1] = self end
            return table.unpack(results)
        end
    end
end

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

uitk.util._properties.addPropertiesWrapper(moduleMT)
-- uitk.util._properties.addPropertiesWrapper(dictionaryMT)
uitk.util._properties.addPropertiesWrapper(itemMT)

module.systemToolbarItems = ls.makeConstantsTable(module.systemToolbarItems)
module.itemPriorities     = ls.makeConstantsTable(module.itemPriorities)

-- Return Module Object --------------------------------------------------

getmetatable(module).__call = function(self, ...) return self.new(...) end

return module
