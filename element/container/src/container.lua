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

--- === hs._asm.uitk.element.container ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.element.container"
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib"))
local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)

local element = require("hs._asm.uitk.element")

local fnutils = require("hs.fnutils")

local subModules = {
--  name       lua or library?
    scroller = true,
    grid     = true,
    table    = true,
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
            element._elementControlViewWrapper(elMT)
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

element._elementControlViewWrapper(moduleMT)

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
local settings     = require("hs.settings")
local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")


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
    elseif key == "_fittingSize" then
        return userdata:fittingSize()

-- because we can't add them to the property list of each element
    elseif key == "frame" then
        local result = userdata:frame()
        result.id = nil
        return result
    elseif key == "id" then
        return userdata:id()

-- property methods
    elseif fnutils.contains(obj.userdataMT._propertyList, key) then
        return userdata[key](userdata)

-- unrecognized
    else
        return nil
    end
end

wrappedUserdataMT.__newindex = function(self, key, value)
    local obj = wrappedUserdataMT.__e[self]
    local userdata = obj.userdata

-- builtin convenience read-only values
    if key == "_userdata" or key == "_type" or key == "_fittingSize" then
        error(key .. " cannot be modified", 3)

-- because we can't add them to the property list of each element
    elseif key == "frame" then
        userdata:frame(value)
    elseif key == "id" then
        userdata:id(value)

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

    local keys = {  "_userdata", "_fittingSize", "_type", "frame", "id" }
    for i,v in ipairs(obj.userdataMT._propertyList or {}) do table.insert(keys, v) end

    return function(_, k)
        local v = nil
        k = table.remove(keys)
        if k then v = self[k] end
        return k, v
    end, self, nil
end

-- Public interface ------------------------------------------------------

moduleMT.wrap = function(self)
    return wrapped_userdataWithMT(self)
end

-- shortcut so ...:container(id | idx) returns element or nil
moduleMT.__call  = function(self, ...) return self:element(...) end

-- moduleMT.__len   = function(self) return #self:elements() end

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
    local element = self(key)
    if element then
        return wrapped_userdataWithMT(element)
    end

-- unrecognized
    return nil
end

local newindex_applyProperties = function(element, propTable)
    local elementMT  = getmetatable(element) or {}
    local properties = elementMT._propertyList or {}

    for k, v in pairs(propTable) do
        if k ~= "_userdata" and k ~= "frame" then
            if fnutils.contains(properties, k) then
                element[k](element, v)
            else
                log.wf("__newindex: unrecognized key %s for %s", k, element.__type)
            end
        end
    end
end

moduleMT.__newindex = function(self, key, value)
    if type(value) == "nil" and (type(key) == "string" or math.type(key) == "integer") then
        return self:remove(key)
    end

    if type(key) == "string" then
        local idx = 0
        for i = 1, #self, 1 do
            if key == self:element(i):id() then
                idx = i
                break
            end
        end
        if idx ~= 0 then key = idx end
    end

    if math.type(key) == "integer" then
        if key < 1 or key > (#self + 1) then
            error("index out of bounds", 3)
        end

        if type(value) == "userdata" then value = { _userdata = value } end

        -- add/insert new element
        if type(value) == "table" and value._userdata then
            if module._isElementType(value._userdata) then
                local details = value.frame or {}
                if value.id then
                    details.id = value.id
                    value.id   = nil
                end

                local element   = value._userdata
                newindex_applyProperties(element, value)
                if self:element(key) then self:remove(key) end
                self:insert(element, details, key)
                return
            end
        -- update existing element
        elseif type(value) == "table" then
            local element = self:element(key)
            if element and module._isElementType(element) then
                newindex_applyProperties(element, value)
                return
            end
        -- remove element
        elseif type(value) == "nil" then
            if self:element(key) then self:remove(key) end
            return
        end

        error("replacement value does not specify an element", 3)
    else
        error("attempt to index a " .. USERDATA_TAG, 3)
    end
end

moduleMT.__pairs = function(self)
    local keys = {}
    -- id is optional and it would just be a second way to access the same object, so stick with indicies
    for i = #self, 1, -1 do table.insert(keys, i) end

    return function(_, k)
        local v = nil
        k = table.remove(keys)
        if k then v = self[k] end
        return k, v
    end, self, nil
end

--- hs._asm.uitk.element.container:elementPropertyList(element) -> containerObject
--- Method
--- Return a table of key-value pairs containing the properties for the specified element
---
--- Parameters:
---  * `element` - the element userdata to create the property list for
---
--- Returns:
---  * a table containing key-value pairs describing the properties of the element.
---
--- Notes:
---  * The table returned by this method does not support modifying the property values as can be done through the `hs._asm.uitk.element.container` metamethods (see the top-level documentation for `hs._asm.uitk.element.container`).
---
---  * This method is wrapped so that elements which are assigned to a container can access this method as `hs._asm.uitk.element:propertyList()`
moduleMT.elementPropertyList = function(self, element, ...)
    local args = table.pack(...)
    if args.n == 0 then
        local results = {}
        local propertiesList = getmetatable(element)["_propertyList"] or {}
        for i,v in ipairs(propertiesList) do results[v] = element[v](element) end
        results._userdata    = element
        results.frame        = self:elementFrame(element)
        results.id           = results.frame.id
        results.frame.id     = nil
        results._fittingSize = self:elementFittingSize(element)
        results._type        = getmetatable(element).__type
        return results
    else
        error("unexpected arguments", 3)
    end
end


--- hs._asm.uitk.element.container:remove([item]) -> containerObject
--- Method
--- Remove an element from the container.
---
--- Parameters:
---  * `item` - the index position specifying the element to remove, a string specifying the `id` of the element to remove, or the userdata of the element itself.  Defaults to `#hs._asm.uitk.element.container:elements()` (the last element)
---
--- Returns:
---  * the container object
---
--- Notes:
---  * This method is wrapped so that elements which are assigned to a container can access this method as `hs._asm.uitk.element:removeFromGroup()`
local originalRemove = moduleMT.remove
moduleMT.remove = function(self, ...)
    local args = { ... }
    if type(args[1]) == "string" then
        for i, v in ipairs(self:elements()) do
            if args[1] == v:id() then
                args[1] = i
                break
            end
        end
    elseif type(args[1]) == "userdata" then
        for i, v in ipairs(self:elements()) do
            if args[1] == v then
                args[1] = i
                break
            end
        end
    end

    return originalRemove(self, table.unpack(args))
end

--- hs._asm.uitk.element.container:elementID(element, [id]) -> containerObject | string
--- Method
--- Get or set the string identifier for the specified element.
---
--- Parameters:
---  * `element` - the element userdata to get or set the id of.
---  * `id`      - an optional string, or explicit nil to remove, to change the element's identifier to
---
--- Returns:
---  * If an argument is provided, the container object; otherwise the current value.
---
--- Notes:
---
---  * This method is syntactic sugar for [hs._asm.uitk.element.container:elementFrame().id](#elementFrame) and [hs._asm.uitk.element.container:elementFrame({ id = "string" })](#elementFrame)
---
---  * This method is wrapped so that elements which are assigned to a container can access this method as `hs._asm.uitk.element:id([id])`
moduleMT.elementID = function(self, element, ...)
    local args = table.pack(...)
    local details = self:elementFrame(element)
    if args.n == 0 then
        return details.id
    elseif args.n == 1 and (type(args[1]) == "string" or type(args[1]) == "nil") then
        details.id = args[1] or false
        return self:elementFrame(element, details)
    else
        error("expected a single string as an argument", 3)
    end
end

-- Return Module Object --------------------------------------------------

-- since we can be a nextResponder, we can provide additional methods to our children
moduleMT._inheritableMethods = {
    frame           = moduleMT.elementFrame,
    position        = moduleMT.positionElement,
    id              = moduleMT.elementID,
    removeFromGroup = moduleMT.remove,
    propertyList    = moduleMT.elementPropertyList,
}

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
