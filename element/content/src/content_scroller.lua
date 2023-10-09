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

--- === hs._asm.uitk.element.content.scroller ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.element.content.scroller"
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libcontent_"))

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)
local content      = require("hs._asm.uitk.element.content")

local fnutils = require("hs.fnutils")

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
local settings     = require("hs.settings")
local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- -- a wrapped element is an element "converted" into an object that can be modified like
-- -- a lua key-value table
-- local wrappedElementMT = {
--     __e = setmetatable({}, { __mode = "k" })
-- }
--
-- local wrappedElementWithMT = function(element)
--     local newItem = {}
--     wrappedElementMT.__e[newItem] = {
--         element   = element,
--         elementMT = getmetatable(element)
--     }
--     return setmetatable(newItem, wrappedElementMT)
-- end
--
-- wrappedElementMT.__index = function(self, key)
--     local obj = wrappedElementMT.__e[self]
--     local element = obj.element
--
-- -- builtin convenience values
--     if key == "_userdata" then
--         return element
--     elseif key == "_type" then
--         return (obj.elementMT or {}).__type
--
-- -- property methods
--     elseif fnutils.contains(((obj.elementMT or {})._propertyList or {}), key) then
--         return element[key](element)
--
-- -- unrecognized
--     else
--         return nil
--     end
-- end
--
-- wrappedElementMT.__newindex = function(self, key, value)
--     local obj = wrappedElementMT.__e[self]
--     local element = obj.element
--
-- -- builtin convenience read-only values
--     if key == "_userdata" or key == "_type" then
--         error(key .. " cannot be modified", 3)
--
-- -- property methods
--     elseif fnutils.contains(((obj.elementMT or {})._propertyList or {}), key) then
--         element[key](element, value)
--
-- -- unrecognized
--     else
--         error(tostring(key) .. " unrecognized property", 3)
--     end
-- end
--
-- wrappedElementMT.__tostring = function(self)
--     return "(wrapped) " .. tostring(wrappedElementMT.__e[self].element)
-- end
--
-- wrappedElementMT.__len = function(self) return 0 end
--
-- wrappedElementMT.__pairs = function(self)
--     local obj = wrappedElementMT.__e[self]
--     local element = obj.element
--
--     local keys = {  "_userdata", "_type" }
--     for i,v in ipairs(obj.elementMT._propertyList or {}) do table.insert(keys, v) end
--
--     return function(_, k)
--         local v = nil
--         k = table.remove(keys)
--         if k then v = self[k] end
--         return k, v
--     end, self, nil
-- end

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

-- check to see if it's our wrapped way to access document()
    if key == "element" then
        local doc = self:document()
        return doc and ((doc._wrap and doc:wrap()) or doc) or nil
    end

-- unrecognized
    return nil
end

local newindex_applyProperties = function(element, propTable)
    local elementMT  = getmetatable(element) or {}
    local properties = elementMT._propertyList or {}

    for k,v in pairs(propTable) do
        if k ~= "_userdata" then
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
        if type(value) == "userdata" then value = { _userdata = value } end

        -- assign document or modify an existing one
        if type(value) == "table" then
            local element = value._userdata or self:document()
            if content._isElementType(element) then
                newindex_applyProperties(element, value)
                -- add new document if one was supplied
                if value._userdata then self:document(element) end
                return
            end

        -- remove document
        elseif type(value) == "nil" then
            self:document(nil)
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
