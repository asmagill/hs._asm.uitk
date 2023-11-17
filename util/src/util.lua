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
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.util"
local uitk         = require("hs._asm.uitk")
local module       = {}

local subModules = {
    _properties = true,
    matrix      = true,
    color       = true,
}

local preload = function(m, isLua)
    return function()
        local el = isLua and require(USERDATA_TAG .. "_" .. m)
                         or  require(USERDATA_TAG:match("^(.+)%.") .. ".lib" ..
                                     USERDATA_TAG:match("^.+%.(.+)$") .. "_" .. m)
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
            module[key] = require(USERDATA_TAG .. "." ..key)
            return module[key]
        else
            return nil
        end
    end,
})
