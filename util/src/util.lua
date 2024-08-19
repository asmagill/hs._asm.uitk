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

--- === hs._asm.uitk.util ===
---
--- This module contains some utility functions that are used within `hs._asm.uitk`. They may also prove useful in other contexts, so they are collected and exposed here and in the attached submodules.

local USERDATA_TAG = "hs._asm.uitk.util"
local uitk         = require("hs._asm.uitk")
local module       = {}

local subModules = {
    _properties = true,
    matrix      = true,
    color       = true,
    gesture     = true,
}

local preload = function(m, isLua)
    return function()
        local el = isLua and require(USERDATA_TAG .. "_" .. m)
                         or  require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib") .. "_" .. m)
--         if getmetatable(el) == nil and type(el.new) == "function" then
--             el = setmetatable(el, { __call = function(self, ...) return self.new(...) end })
--         end
        return el
    end
end

for k, v in pairs(subModules) do
    if type(v) == "boolean" then
        package.preload[USERDATA_TAG .. "." .. k] = preload(k, v)
    end
end


-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

--- hs._asm.uitk.util.masksToInt(stringTable, masksTable) -> integer | nil, string
--- Function
--- Return an integer representing the value of the masks specified for the given `masksTable`
---
--- Parameters:
---  * `stringTable` - a table of string values representing the human readable form of a list of masks to be logically or'ed together.
---  * `masksTable`  - a table of key-value pairs where the key represents the human readble version of a specific value, and the value is an integer to be combined with the other masks to create a combined integer value representing all of the masks combined.
---
--- Returns:
---  * an integer, if all of the strings in the `stringTable` correspond to mask values in the `masksTable`; otherwise nil and an error message string detailing which mask value was unrecognized.
---
--- Notes:
---  * this function is used internally to allow the user to provide a table of strings using human readable names and convert them into an integer mask used by many internal macOS methods and functions.
---    * as a couple of examples, see the documentation for `hs._asm.uitk.window:styleMask` and `hs._asm.uitk.window:collectionBehavior`.
module.masksToInt = function(stringTable, masksTable)
    local result = 0

    for _, v in ipairs(stringTable) do
        if type(v) == "string" and masksTable[v] then
            result = result | masksTable[v]
        else
            return nil, string.format("unrecognized mask key %s", v)
        end
    end
    return result
end

--- hs._asm.uitk.util.intToMasks(maskValue, masksTable) -> table
--- Function
--- Convert an integer mask value into a table of strings containing human readable labels for the different values that make up the combined mask value.
---
--- Parameters:
---  * `mask` - an integer created by logically or'ing one or more mask values.
---  * `masksTable`  - a table of key-value pairs where the key represents the human readble version of a specific value, and the value is an integer to be combined with the other masks to create a combined integer value representing all of the masks combined.
---
--- Returns:
---  * a table of string values representing the human readable labels of the masks used to combine and create the `mask` value.
---
--- Notes:
---  * the original integer value will be added to the table with the key `_value`.
---  * if there is any unrecognized portion of the `mask` value once all of the keys in the `masksTable` have been accounted for, it will be returned in the table with the `_remainder` key. If this key is not present, then the `mask` value is completely accounted for by the masks represented by the strings found in the returned table.
---
---  * you can use this function to convert the results of methods like `hs._asm.uitk.window:styleMask` and `hs._asm.uitk.window:collectionBehavior` (when invoked with no paramters) into a more human readable form.
module.intToMasks = function(intValue, masksTable)
    local result = { _value = intValue }

    for k,v in pairs(masksTable) do
        if v == 0 and result._value == 0 then
            table.insert(result, k)
            break
        elseif (intValue & v) == v then
            table.insert(result, k)
            intValue = intValue - v
        end
    end

    if intValue ~= 0 then result["_remainder"] = intValue end
    return result
end

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
    __index = function(self, key)
        if type(subModules[key]) ~= "nil" then
            local mod = require(USERDATA_TAG .. "." ..key)
            -- this should probably remain hidden
            if key ~= "_properties" then module[key] = mod end
            return mod
        else
            return nil
        end
    end,
})
