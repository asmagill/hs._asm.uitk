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

--- === hs._asm.uitk.element ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.element"
local module       = {}

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- make sure support functions registered
require("hs.drawing.color")
require("hs.image")
require("hs.styledtext")
require("hs.sharing")

local fnutils = require("hs.fnutils")

local _controlMT   = require(USERDATA_TAG:match("^(.+)%.") ..".libelement__control")
local _viewMT      = require(USERDATA_TAG:match("^(.+)%.") ..".libelement__view")

local subModules = {
--  name         lua or library?
    content         = "hs._asm.uitk.element.content",
    switch          = false,
    colorwell       = false,
    progress        = false,
    datepicker      = true,
    slider          = false,
    button          = true,
    popUpButton     = false,
    comboButton     = false,
    levelIndicator  = false,
    stepper         = false,
    image           = true,
    textField       = "hs._asm.uitk.element.textField",
    segmentBar      = true,
    textView        = true,
    table           = false,
}

-- set up preload for elements so that when they are loaded, the methods from _control and/or
-- __view are also included and the property lists are setup correctly.
local preload = function(m, isLua)
    return function()
        local el = isLua and require(USERDATA_TAG .. "_" .. m)
                         or  require(USERDATA_TAG:match("^(.+)%.") .. ".lib" ..
                                     USERDATA_TAG:match("^.+%.(.+)$") .. "_" .. m)
        local elMT = hs.getObjectMetatable(USERDATA_TAG .. "." .. m)
        if el and elMT then
            module._elementControlViewWrapper(elMT)
        end

        if getmetatable(el) == nil and type(el.new) == "function" then
            el = setmetatable(el, { __call = function(self, ...) return self.new(...) end })
        end
        return el
    end
end

for k, v in pairs(subModules) do
    if type(v) == "boolean" then
        package.preload[USERDATA_TAG .. "." .. k] = preload(k, v)
    end
end

-- private variables and methods -----------------------------------------

-- a wrapped userdata is an userdata "converted" into an object that can be modified like
-- a lua key-value table
local wrappedUserdataMT = {
    __e = setmetatable({}, { __mode = "k" })
}

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

-- builtin convenience values
    if key == "_userdata" then
        return userdata
    elseif key == "_type" then
        return obj.userdataMT.__type

-- property methods
    elseif fnutils.contains(obj.userdataMT._propertyList, key) then
        return userdata[key](userdata)

-- if key is an integer and the userdata has a length > 0, treat it as an index
    elseif math.type(key) == "integer" and userdata.__len and #userdata > 0 then
        return userdata[key]

-- unrecognized
    else
        return nil
    end
end

wrappedUserdataMT.__newindex = function(self, key, value)
    local obj = wrappedUserdataMT.__e[self]
    local userdata = obj.userdata

-- builtin convenience read-only values
    if key == "_userdata" or key == "_type" then
        error(key .. " cannot be modified", 3)

-- property methods
    elseif fnutils.contains(obj.userdataMT._propertyList, key) then
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
    local userdata = obj.userdata

    local keys = {  "_userdata", "_type", }
    for i,v in ipairs(obj.userdataMT._propertyList or {}) do table.insert(keys, v) end

    return function(_, k)
        local v = nil
        k = table.remove(keys)
        if k then v = self[k] end
        return k, v
    end, self, nil
end

-- Public interface ------------------------------------------------------

module._elementControlViewWrapper = function(elMT)
    if elMT._inheritControl then
        for k, v in pairs(_controlMT) do
            if type(v) == "function" and not elMT[k] then elMT[k] = v end
        end
        for _, v in ipairs(_controlMT._propertyList) do
            if not fnutils.contains(elMT._propertyList, v) then
                table.insert(elMT._propertyList, v)
            end
        end
    end
    for k, v in pairs(_viewMT) do
        if type(v) == "function" and not elMT[k] then elMT[k] = v end
    end
    for _, v in ipairs(_viewMT._propertyList) do
        if not fnutils.contains(elMT._propertyList, v) then
            table.insert(elMT._propertyList, v)
        end
    end

    if not elMT.wrap then
        elMT.wrap = function(self) return wrapped_userdataWithMT(self) end
    end

    -- allow content to provide inheritable methods
    local old_index = elMT.__index
    elMT.__index = function(self, key)
        local value = nil

        if elMT[key] then
            value = elMT[key]
        elseif type(old_index) == "function" then
            value = old_index(self, key)
        elseif type(old_index) == "table" then
            value = old_index[key]
        end

        if type(value) == "nil" then
            local parent         = self:_nextResponder()
            local parentMT       = getmetatable(parent) or {}
            local inheritedValue = (parentMT._inheritableMethods or {})[key]

            if type(inheritedValue) == "function" then
                value = function(self, ...)
                    local result = inheritedValue(parent, self, ...)
                    return result == parent and self or result
                end
            else
                value = inheritedValue
            end
        end

        return value
    end
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

-- The point was to allow tab completion in hammerspoon to be able to "see" the unloaded
-- submodule entry points in element, but the current implementation of tab completion
-- causes the loading of *ALL* of the submodules, so kinda defeats the purposes of lazy
-- loading...
--
-- same with hs.inspect
--
--     __pairs = function(self)
--         local unloadedSubModules = {}
--         for k,v in pairs(subModules) do
--             if not rawget(self, k) then table.insert(unloadedSubModules, k) end
--         end
--         local firstRun = true
--
--         return function(t, k)
--             local nk, nv
--             if firstRun then
--                 firstRun = false
--                 nk, nv = next(t, k)
--             elseif rawget(t, k) then
--                 nk, nv = next(t, k)
--             end
--
--             if not nk and not nv then
--                 nk, nv = table.remove(unloadedSubModules), nil
--             end
--
--             if nk then
--                 return nk, nv
--             else
--                 return nk
--             end
--         end, self, nil
--     end,
})
