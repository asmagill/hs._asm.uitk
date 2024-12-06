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

--- === hs._asm.uitk.util._properties ===
---
--- This submodule is used internally by `hs._asm.uitk`. It is not expected that you will need to access it directly under normal usage.

local USERDATA_TAG = "hs._asm.uitk.util._properties"
local uitk         = require("hs._asm.uitk")
local module       = {}

local inspect      = require("hs.inspect")
local fnutils      = require("hs.fnutils")
local settings     = require("hs.settings")

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- a wrapped userdata is an userdata "converted" into an object that can be modified like
-- a lua key-value table
local wrappedUserdataMT = { __e = setmetatable({}, { __mode = "k" }) }

local wrapped_userdataWithMT = function(userdata, readonlyAdditions)
    local newItem = {}
    wrappedUserdataMT.__e[newItem] = {
        userdata          = userdata,
        userdataMT        = getmetatable(userdata),
        readonlyAdditions = readonlyAdditions or {},
    }
    return setmetatable(newItem, wrappedUserdataMT)
end

wrappedUserdataMT.__index = function(self, key)
    local obj = wrappedUserdataMT.__e[self]
    local userdata = obj.userdata

-- builtin convenience values
    if key == "_self" then
        return userdata
    elseif key == "_type" then
        return obj.userdataMT.__type

-- readonly additions from element
    elseif obj.readonlyAdditions[key] then
        return obj.readonlyAdditions[key](userdata)

-- property methods
    elseif fnutils.contains(obj.userdataMT._propertyList, key) then
        return userdata[key](userdata)

-- inheritable properties
    elseif userdata._nextResponder then
        local inheritedProperties = (getmetatable(userdata:_nextResponder()) or {})._inheritableProperties
        if inheritedProperties and fnutils.contains(inheritedProperties, key) then
            return userdata[key](userdata)
        end

-- if key is an integer and the userdata has a length, treat it as an index
    elseif math.type(key) == "integer" and userdata.__len then
        local result = userdata[key]
        -- since we're wrapped, child should be wrapped as well
        if result and type(result) == "userdata" then result = result._properties end
        return result

-- unrecognized
    else
        return nil
    end
end

wrappedUserdataMT.__newindex = function(self, key, value)
    local obj = wrappedUserdataMT.__e[self]
    local userdata = obj.userdata

-- builtin convenience read-only values
    if key == "_self" or key == "_type" then
        error(key .. " cannot be modified", 3)

-- readonly additions from element
    elseif obj.readonlyAdditions[key] then
        error(key .. " cannot be modified", 3)

-- property methods
    elseif fnutils.contains(obj.userdataMT._propertyList, key) then
        userdata[key](userdata, value)

-- inheritable properties
    elseif userdata._nextResponder then
        local inheritedProperties = (getmetatable(userdata:_nextResponder()) or {})._inheritableProperties
        if inheritedProperties and fnutils.contains(inheritedProperties, key) then
            userdata[key](userdata, value)
        end

-- unrecognized
    else
        error(tostring(key) .. " unrecognized property", 3)
    end
end

wrappedUserdataMT.__tostring = function(self)
    return "(wrapped) " .. tostring(wrappedUserdataMT.__e[self].userdata)
end

wrappedUserdataMT.__len = function(self) return 0 end

wrappedUserdataMT.__pairs = function(self)
    local obj = wrappedUserdataMT.__e[self]
    local userdata = obj.userdata

    local keys = {  "_self", "_type", }
    for k,_ in pairs(obj.readonlyAdditions) do table.insert(keys, k) end
    for _,v in ipairs(obj.userdataMT._propertyList or {}) do table.insert(keys, v) end

    if userdata._nextResponder then
        local parentMT = getmetatable(userdata:_nextResponder()) or {}
        for _,v in ipairs(parentMT._inheritableProperties or {}) do table.insert(keys, v) end
    end

    return function(_, k)
        local v = nil
        k = table.remove(keys)
        if k then v = self[k] end
        return k, v
    end, self, nil
end

-- Public interface ------------------------------------------------------

-- ??? separate legacy canvas and do for new canvas?

module.addPropertiesWrapper = function(objMT, readonlyAdditions)
    local readonlyAdditions = readonlyAdditions or {}
    local objType = objMT.__type or objMT.__name or tostring(obj)
    local _propertyList = objMT._propertyList
    if not (_propertyList and type(_propertyList) == "table") then
        log.f("userdata type %s does not have an attached property list table (%s)", objType, type(_propertyList))
        return obj
    end

    -- already invoked, so don't repeat
    if objMT._propertiesWrapperAdded then return end

    local old_index = objMT.__index
    objMT.__index = function(self, key)
        local value = nil

        if objMT[key] then
            value = objMT[key]
        elseif type(old_index) == "function" then
            value = old_index(self, key)
        elseif type(old_index) == "table" then
            value = old_index[key]
        end

        -- check for inheritable methods from immediate container
        if type(value) == "nil" and objMT._nextResponder then
--         print(inspect(objMT, { newline = " ", indent = "" }))
            local parent          = self:_nextResponder()
            local inheritedMethod = ((getmetatable(parent) or {})._inheritableMethods or {})[key]

            if type(inheritedMethod) == "function" then
                value = function(self, ...)
                    local results = table.pack(inheritedMethod(parent, self, ...))
                    if results[1] == parent then results[1] = self end
                    return table.unpack(results)
                end
            end
        end

        if type(value) == "nil" then -- still!
            if key == "_properties" then
                value = wrapped_userdataWithMT(self, readonlyAdditions)
            end
        end

        return value
    end

    local old_newindex = objMT.__newindex
    objMT.__newindex = function(self, key, value)
        if key == "_properties" and type(value) == "table" then
            local inheritedProperties = self._nextResponder and (getmetatable(self:_nextResponder()) or {})._inheritableProperties or {}
            for k,v in pairs(value) do
                if not(k == "_self" or k == "_type" or readonlyAdditions[k]) then
                    if fnutils.contains(objMT._propertyList, k) or fnutils.contains(inheritedProperties, k) then
--                     if type(self[k]) == "function" then
                        self[k](self, v)
                    else
                        log.wf("__newindex: unrecognized property %s for %s", k, objType)
                    end
                end
            end
        elseif old_newindex then
            old_newindex(self, key, value)
        else
            error("attempt to index a " .. objType .. " value", 3)
        end
    end

    -- prevent repat if previously invoked to add readonlyAdditions
    objMT._propertiesWrapperAdded = true
end

-- Return Module Object --------------------------------------------------

return module
