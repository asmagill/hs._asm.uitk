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

local USERDATA_TAG = "hs._asm.uitk.element.sceneKit.node"
local uitk         = require("hs._asm.uitk")
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libsceneKit_"))
local fnutils      = require("hs.fnutils")

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
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

    if math.type(key) == "integer" then
        result = self:childNodes()[key]
    end

    return result
end

moduleMT.__len = function(self)
    return #self:childNodes()
end

local _new = module.new
module.new = function(...)
    local args = table.pack(...)

    local lastArg = args[#args]
    if type(lastArg) == "userdata" then
        args[#args] = nil
        args.n = args.n - 1
    else
        lastArg = nil
    end
    local result = _new(table.unpack(args))
    if result and lastArg then
        local resultMT = getmetatable(lastArg)
        if resultMT == hs.getObjectMetatable("hs._asm.uitk.element.sceneKit.light") then
            result:light(lastArg)
        elseif resultMT == hs.getObjectMetatable("hs._asm.uitk.element.sceneKit.camera") then
            result:camera(lastArg)
        else
            result:geometry(lastArg)
        end
    end
    return result
end

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
    __call  = function(self, ...) return self.new(...) end,
    __index = function(self, key)
        if type(subModules[key]) ~= "nil" then
            module[key] = require(USERDATA_TAG .. "." ..key)
            return module[key]
        else
            return nil
        end
    end,
})
