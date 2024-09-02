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

--- === hs._asm.uitk.menu ===
---
--- This submodule is used to create drop-down or pop-up menus which are usable by various `hs._asm.uitk.element` objects. Attaching these to the element is described in the documentation for the element.

--- === hs._asm.uitk.menu.item ===
---
--- This submodule is used to create menu items for use with `hs._asm.uitk.menu`.

local USERDATA_TAG = "hs._asm.uitk.menu"
local uitk         = require("hs._asm.uitk")
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib"))
local fnutils = require("hs.fnutils")
local host         = require("hs.host")

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)

local subModules = {
--  name   lua or library?
    item = false,
}

local preload = function(m, isLua)
    return function()
        local sm = isLua and require(USERDATA_TAG .. "_" .. m)
                         or  require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib") .. "_" .. m)
        if getmetatable(sm) == nil and type(sm.new) == "function" then
            sm = setmetatable(sm, { __call = function(self, ...) return self.new(...) end })
        end
        return sm
    end
end

for k, v in pairs(subModules) do
    package.preload[USERDATA_TAG .. "." .. k] = preload(k, v)
end

module.item = require(USERDATA_TAG .. ".item")
local menuItemMT = hs.getObjectMetatable(USERDATA_TAG .. ".item")

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

-- check to see if its an index or key to an element of this container
    local item = self(key)
    if item then return item end

-- unrecognized
    return nil
end

moduleMT.__newindex = function(self, key, value)
    local idx = (math.type(key) == "integer") and key or nil
    if type(key) == "string" then idx = self:indexWithID(key) end

    if idx then
       if idx < 1 or idx > #self + 1 then error("index out of bounds", 3) end

        if getmetatable(value) == menuItemMT then value = { _self = value } end

        if type(value) == "table" then
            local item = value._self or module.item(value.title or host.globallyUniqueString())
        -- add/insert new menu item
            if getmetatable(item) == menuItemMT then
                -- insert could fail for some reason, so do it first
                self:insert(item, idx)
                if self:itemAtIndex(idx + 1) then self:remove(idx + 1) end
                item._properties = value
                return
            end
        -- remove menu item
        elseif type(value) == "nil" then
            if idx == #self + 1 then error("index out of bounds", 3) end
            self:remove(idx)
            return
        end

        error("value does not specify a menu item", 3)
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

moduleMT.__call = function(self, key)
    local idx = (math.type(key) == "integer") and key or self:indexWithID(key)
    return idx and self:itemAtIndex(idx) or nil
end

module.item._characterMap = ls.makeConstantsTable(module.item._characterMap)

local _originalMenuItemMTkeyEquivalent = menuItemMT.keyEquivalent
menuItemMT.keyEquivalent = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        local answer = _originalMenuItemMTkeyEquivalent(self)
        for k, v in pairs(module.item._characterMap) do
            if answer == v then
                answer = k
                break
            end
        end
        return answer
    elseif args.n == 1 and type(args[1]) == "string" then
        local choice = args[1]
        return _originalMenuItemMTkeyEquivalent(self, module.item._characterMap[choice] or choice)
    else
        return _originalMenuItemMTkeyEquivalent(self, ...) -- allow normal error to occur
    end
end

uitk.util._properties.addPropertiesWrapper(moduleMT)
uitk.util._properties.addPropertiesWrapper(menuItemMT)

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
    __call = function(self, ...) return self.new(...) end,
})
