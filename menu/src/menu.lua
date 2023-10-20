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
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.menu"
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib"))

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
local settings     = require("hs.settings")
local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

local fnutils = require("hs.fnutils")

-- private variables and methods -----------------------------------------

local subModules = {
--  name   lua or library?
    item = false,
}

local preload = function(m, isLua)
    return function()
        local sm = isLua and require(USERDATA_TAG .. "_" .. m)
                         or  require(USERDATA_TAG:match("^(.+)%.") .. ".lib" ..
                                     USERDATA_TAG:match("^.+%.(.+)$") .. "_" .. m)
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

local wrappedItemMT = { __i = setmetatable({}, { __mode = "k" }) }

local wrappedItemWithMT = function(menu, item)
    local newItem = {}
    wrappedItemMT.__i[newItem] = { menu = menu, item = item }
    return setmetatable(newItem, wrappedItemMT)
end

wrappedItemMT.__index = function(self, key)
    local obj = wrappedItemMT.__i[self]
    local menu, item = obj.menu, obj.item

-- this key doesn't correspond to a method
    if key == "_item" then
        return item

-- convenience lookup
    elseif key == "_type" then
        return getmetatable(item).__type

-- try property methods
    elseif fnutils.contains(menuItemMT._propertyList, key) then
        return item[key](item)
    else
        return nil
    end
end

wrappedItemMT.__newindex = function(self, key, value)
    local obj = wrappedItemMT.__i[self]
    local menu, item = obj.menu, obj.item

    if key == "_item" or key == "_type" then
        error(key .. " cannot be modified", 2)

-- try property methods
    elseif fnutils.contains(menuItemMT._propertyList, key) then
        item[key](item, value)
    else
        error(tostring(key) .. ": unrecognized property", 2)
    end
end

wrappedItemMT.__pairs = function(self)
    local obj = wrappedItemMT.__i[self]
    local menu, item = obj.menu, obj.item
    local keys = {}
    for i,v in ipairs(menuItemMT._propertyList or {}) do table.insert(keys, v) end
    local builtin = { "_item", "_type" }
    table.move(builtin, 1, #builtin, #keys + 1, keys)

    return function(_, k)
        local v = nil
        k = table.remove(keys)
        if k then v = self[k] end
        return k, v
    end, self, nil
end

wrappedItemMT.__tostring = function(self)
    local obj = wrappedItemMT.__i[self]
    local menu, item = obj.menu, obj.item
    return "(wrapped) " .. tostring(obj.item)
end

wrappedItemMT.__len = function(self) return 0 end

moduleMT.__index = function(self, key)
    if moduleMT[key] then
        return moduleMT[key]
    else
        local item = self(key)
        if item then
            return wrappedItemWithMT(self, item)
        end
    end
    return nil
end

moduleMT.__newindex = function(self, key, value)
    local idx = nil
    if math.type(key) == "integer" then
        if key < 1 or key > (#self + 1) then
            error("index out of bounds", 3)
        else
            idx = key
        end
    else
        local item = self(key)
        if item then
            idx = self:indexOfItem(item)
        end
    end

    if idx then
        local newItem = nil
        if type(value) ~= "nil"  then
            if type(value) == "userdata" then value = { _item = value } end
            if type(value) == "table" and type(value._item) == "nil" then
                local newValue = {}
                -- shallow copy so we don't modify a table the user might re-use
                for k,v in pairs(value) do newValue[k] = v end
                newValue._item = module.item.new(USERDATA_TAG .. ".item")
                value = newValue
            end
            if type(value) == "table" and value._item.__type == USERDATA_TAG .. ".item" then
                newItem = value._item
                for k, v in pairs(value) do
                    if k ~= "_item" and k ~= "_type" then
                        if fnutils.contains(menuItemMT._propertyList, k) then
                            newItem[k](newItem, v)
                        else
                            log.wf("insert metamethod, unrecognized key %s for %s", k, newItem.__type)
                        end
                    end
                end
            else
                error("value does not specify an item for assignment", 2)
            end
        end

        -- insert could fail because menuitem already belongs to a menu, so do it first
        if newItem then
            self:insert(newItem, idx)
            if self:itemAtIndex(idx + 1) then self:remove(idx + 1) end
        else
            if self:itemAtIndex(idx) then self:remove(idx) end
        end
    else
        error("invalid identifier for item assignment", 2)
    end
end

-- moduleMT.__len = function(self) return self:itemCount() end

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

-- FIXME: what about the other searches in __index, __newindex, and __call?
--     {"indexOfItem",         menu_indexOfItem},
--     {"indexWithAttachment", menu_indexOfItemWithRepresentedObject}, -- require to be string and use as id?
--     {"indexWithSubmenu",    menu_indexOfItemWithSubmenu}, -- probably not
--     {"indexWithTag",        menu_indexOfItemWithTag}, -- probably not since integer and idx confusion
--     {"indexWithTitle",      menu_indexOfItemWithTitle}, -- then confused with id string
moduleMT.__call = function(self, key)
    local idx = (math.type(key) == "integer") and key or self:indexWithAttachment(key)
    return idx and self:itemAtIndex(idx) or nil
end

-- Public interface ------------------------------------------------------

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
        for k, v in pairs(module.item._characterMap) do
            if choice:lower() == k then
                choice = v
                break
            end
        end
        return _originalMenuItemMTkeyEquivalent(self, choice)
    else
        return _originalMenuItemMTkeyEquivalent(self, ...) -- allow normal error to occur
    end
end

moduleMT.itemPropertyList = function(self, item, ...)
    local args = table.pack(...)
    if args.n == 0 then
        local results = {}
        local propertiesList = menuItemMT._propertyList or {}
        for i,v in ipairs(propertiesList) do results[v] = item[v](item) end
        results._item = item
        results._type = getmetatable(item).__type
        return results
    else
        error("unexpected arguments", 2)
    end
end

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
    __call = function(self, ...) return self.new(...) end,
})
