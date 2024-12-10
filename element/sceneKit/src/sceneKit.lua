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

--- === hs._asm.uitk.element.textField ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.element.sceneKit"
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib"))

local uitk    = require("hs._asm.uitk")
local color   = uitk.util.color
local matrix4 = uitk.util.matrix4
local vector  = uitk.util.vector

local fnutils = require("hs.fnutils")

require("hs.image")

local moduleMT = hs.getObjectMetatable(USERDATA_TAG)

local subModules = {
--  name       lua or library?
    node             = true,
    geometry         = true,
    material         = true,
    cameraController = false,
    light            = false,
    camera           = false,
}

-- set up preload for elements so that when they are loaded, the methods from _control and/or
-- __view are also included and the property lists are setup correctly.
local preload = function(m, isLua)
    return function()
        local el = isLua and require(USERDATA_TAG .. "_" .. m)
                         or  require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib") .. "_" .. m)
        local elMT = hs.getObjectMetatable(USERDATA_TAG .. "." .. m)
        if el and elMT then
            local roAdditions
            if elMT._materialProperties then
                roAdditions = {}
                for _, v in ipairs(elMT._materialProperties) do
                    roAdditions[v] = function(self) return (elMT[v](self) or {})._properties end
                end
            end
            if elMT._propertyList then uitk.util._properties.addPropertiesWrapper(elMT, roAdditions) end
        end

        if getmetatable(el) == nil and type(el.new) == "function" then
            el = setmetatable(el, { __call = function(self, ...) return self.new(...) end })
        end

        return el
    end
end


for k, v in pairs(subModules) do
    package.preload[USERDATA_TAG .. "." .. k] = preload(k, v)
end

-- the initial submodules all create types needed by others... safer to just load them all at once
for k, _ in pairs(subModules) do module[k] = require(USERDATA_TAG .. "." .. k) end

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

module.debugMasks = ls.makeConstantsTable(module.debugMasks)

local _debugOptions = moduleMT.debugOptions ;
moduleMT.debugOptions = function(self, ...)
    local args = table.pack(...)

    if args.n == 0 then return _debugOptions(self) end
    if args.n == 1 and type(args[1]) == "table" then args = args[1] end

    local value = 0
    for i = 1, args.n, 1 do
        local item = args[i]
        if math.type(item) == "integer" then
            value = value | item
        elseif type(item) == "string" and module.debugMasks[item] then
            value = value | module.debugMasks[item]
        else
            error("expected integer or string from hs._asm.uitk.element.sceneKit.debugMasks", 3)
        end
    end
    return _debugOptions(self, value)
end

local _cameraControlConfig = moduleMT.cameraControlConfig
moduleMT.cameraControlConfig = function(self, ...)
    local args = table.pack(...)

    if args.n == 0 then
        local tbl = _cameraControlConfig(self)
        return setmetatable({}, {
            _config = tbl,
            __index = function(obj, key)
                return getmetatable(obj)._config[key]
            end,
            __newindex = function(obj, key, value)
                if type(getmetatable(obj)._config[key]) ~= "nil" then
                    return _cameraControlConfig(self, key, value)
                else
                    error("unrecognized key", 3)
                end
            end,
            __pairs = function(obj)
                return function(_, k)
                        local v
                        k, v = next(getmetatable(obj)._config, k)
                        return k, v
                    end, self, nil
            end,
            __tostring = function(obj)
                local str, len = "", 0
                for k, v in pairs(getmetatable(obj)._config) do len = math.max(len, #k) end
                for k, v in pairs(getmetatable(obj)._config) do
                    str = str .. string.format("%-" .. tostring(len) .. "s = %s", k, tostring(v) .. "\n")
                end
                return str
            end,
        })
    else
        return _cameraControlConfig(self, ...)
    end
end

-- Return Module Object --------------------------------------------------

-- add out material.properties to the property wrapper
if moduleMT._materialProperties then
    local roAdditions = {}
    for _, v in ipairs(moduleMT._materialProperties) do
        roAdditions[v] = function(self) return (moduleMT[v](self) or {})._properties end
    end
    uitk.util._properties.addPropertiesWrapper(moduleMT, roAdditions)
end

-- because we're loaded directly rather than through an element preload function, we need to invoke the
-- wrapper manually, but it needs to happen after our local __index and __newindex (if any) methods are defined
uitk.element._elementControlViewWrapper(moduleMT)

return setmetatable(module, {
    __call  = function(self, ...) return self.new(...) end,
})
