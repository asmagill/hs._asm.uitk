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

--- === hs._asm.uitk.element.container.box ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.element.container.box"
local uitk         = require("hs._asm.uitk")
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libcontainer_"))
local container    = uitk.element.container
local fnutils      = require("hs.fnutils")

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
local settings     = require("hs.settings")
local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

module._new = module.new
module.new = function(...)
    return module._new(...):content(uitk.element.container())
end

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

-- check to see if it's our wrapped way to access content()
    if key == "element" then
        local doc = self:content()
        return doc and ((doc.wrap and doc:wrap()) or doc) or nil
    end

-- unrecognized
    return nil
end

local newindex_applyProperties = function(element, propTable)
    local elementMT  = getmetatable(element) or {}
    local properties = elementMT._propertyList or {}

    for k,v in pairs(propTable) do
        if k ~= "_element" then
            if fnutils.contains(properties, k) then
                element[k](element, v)
            else
                log.wf("__newindex: unrecognized key %s for %s", k, element.__type)
            end
        end
    end
end

moduleMT.__newindex = function(self, key, value)
    if key == "element" then
        if type(value) == "userdata" then value = { _element = value } end

        -- assign content or modify an existing one
        if type(value) == "table" then
            local element = value._element or self:content()
            if uitk.element.isElementType(element) then
                newindex_applyProperties(element, value)
                -- add new content if one was supplied
                if value._element then self:content(element) end
                return
            end

        -- remove content
        elseif type(value) == "nil" then
            self:content(nil)
            return
        end

        error("replacement value does not specify an element or nil", 3)
    else
        error("attempt to index a " .. USERDATA_TAG, 3)
    end
end

-- Return Module Object --------------------------------------------------

-- since we can be a nextResponder, we can provide additional methods to our children
-- moduleMT._inheritableMethods = { }

return module
