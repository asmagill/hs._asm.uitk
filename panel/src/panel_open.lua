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
local savePanel    = uitk.panel.save
local module       = savePanel._open
local fnutils      = require("hs.fnutils")
local settings     = require("hs.settings")

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

local sharedModuleKeys = savePanel._sharedWithOpen

-- a wrapped userdata is an userdata "converted" into an object that can be modified like
-- a lua key-value table
local wrappedUserdataMT = { __e = setmetatable({}, { __mode = "k" }) }

local wrapped_userdataWithMT = function(userdata)
    local newItem = {}
    wrappedUserdataMT.__e[newItem] = {
        userdata   = userdata,
        userdataMT = getmetatable(userdata)
    }
    return setmetatable(newItem, wrappedUserdataMT)
end

wrappedUserdataMT.__index = function(self, key)
    local obj = wrappedUserdataMT.__e[self]
    local userdata = obj.userdata

-- property methods
    if fnutils.contains(obj.userdataMT._propertyList, key) then
        return userdata[key](userdata)

-- unrecognized
    else
        return nil
    end
end

wrappedUserdataMT.__newindex = function(self, key, value)
    local obj = wrappedUserdataMT.__e[self]
    local userdata = obj.userdata

-- property methods
    if fnutils.contains(obj.userdataMT._propertyList, key) then
        userdata[key](userdata, value)

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

    local keys = {}
    for i,v in ipairs(obj.userdataMT._propertyList or {}) do table.insert(keys, v) end

    return function(_, k)
        local v = nil
        k = table.remove(keys)
        if k then v = self[k] end
        return k, v
    end, self, nil
end

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

    -- check to see if it's the properties table shortcut
    if key == "properties" then
        return wrapped_userdataWithMT(self)
    end

-- unrecognized
    return nil
end

moduleMT.__newindex = function(self, key, value)
    -- check to see if it's the properties table shortcut
    if key == "properties" and type(value) == "table" then
        local properties = moduleMT._propertyList or {}
        for k, v in pairs(value) do
            if fnutils.contains(properties, k) then
                self[k](self, v)
            else
                log.wf("__newindex: unrecognized key %s for %s", k, moduleMT.__type)
            end
        end
    else
        error("attempt to index a " .. USERDATA_TAG, 3)
    end
end

local _contentTypes = moduleMT.contentTypes
moduleMT.contentTypes = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return _contentTypes(self)
    else
        local passUntested = nil
        if args.n > 1 and type(args[args.n]) == "boolean" then
            passUntested = table.remove(args)
            args.n = args.n - 1
        end
        if args.n == 1 and type(args[1]) == "table" then
            args = args[1]
        end
        args.n = nil

        if not passUntested then
            local good = true
            for i, v in ipairs(args) do
                good = fnutils.contains(savePanel.mimeTypes, v) or
                       fnutils.contains(savePanel.utiTypes, v) or
                       fnutils.contains(savePanel.fileExtensions, v)
                if not good then
                    error(string.format("%s at index %d is not a recognized MIME Type, UTI, or file extension", v, i), 3)
                end
            end
        end

        return _contentTypes(self, args)
    end
end

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
    __call = function(self, ...) return self.new(...) end,
    __index = function(self, key)
        if fnutils.contains(sharedModuleKeys, key) then
            return savePanel[key]
        else
            return nil
        end
    end,
})
