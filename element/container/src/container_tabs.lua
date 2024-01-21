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

--- === hs._asm.uitk.element.container.text ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.element.container.tabs"
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libcontainer_"))
local uitk         = require("hs._asm.uitk")

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)
local itemMT       = hs.getObjectMetatable(USERDATA_TAG .. ".item")

-- -- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- -- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

local mt_prevIndex = moduleMT.__index
moduleMT.__index = function(self, key)
    local result = nil

-- check index as it was prior to this function
    if type(mt_prevIndex) == "function" then
        result =  mt_prevIndex(self, key)
    else
        result = mt_prevIndex[key]
    end

    if type(result) ~= "nil" then return result end

-- check to see if its an index to an item of this container
    if math.type(key) == "integer" then
        local item = self:tabAtIndex(key)
        if item then return item end
    end

-- unrecognized
    return nil
end

moduleMT.__newindex = function(self, key, value)
    local idx = (math.type(key) == "integer") and key or nil

    if idx then
       if idx < 1 or idx > #self + 1 then error("index out of bounds", 3) end

        if getmetatable(value) == itemMT then value = { _self = value } end

        if type(value) == "table" then
            local item = value._self or module.newItem()
        -- add/insert new tabs item
            if getmetatable(item) == itemMT then
                -- insert could fail for some reason, so do it first
                self:insert(item, idx)
                if self:tabAtIndex(idx + 1) then self:remove(idx + 1) end
                item._properties = value
                return
            end
        -- remove tabs item
        elseif type(value) == "nil" then
            if idx == #self + 1 then error("index out of bounds", 3) end
            self:remove(idx)
            return
        end

        error("value does not specify a tabs item", 3)
    end

    error("attempt to index a " .. USERDATA_TAG, 3)
end

moduleMT.__len = function(self) return self:itemCount() end

moduleMT.__pairs = function(self)
    local keys = {}
    for i = #self, 1, -1 do table.insert(keys, i) end

    return function(_, k)
        local v = nil
        k = table.remove(keys)
        if k then v = self[k] end
        return k, v
    end, self, nil
end

-- Return Module Object --------------------------------------------------

-- since we can be a nextResponder, we can provide additional methods to our children
-- moduleMT._inheritableMethods = { }
-- moduleMT._inheritableProperties = { ... }

uitk.util._properties.addPropertiesWrapper(itemMT)

return module
