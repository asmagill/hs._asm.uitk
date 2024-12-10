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
local uitk         = require("hs._asm.uitk")
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib"))
local fnutils      = require("hs.fnutils")
local settings     = require("hs.settings")

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)

local subModules = {
--  name       lua or library?
    scroller = true,
    grid     = true,
    table    = true,
    tabs     = true,
}

-- set up preload for elements so that when they are loaded, the methods from _control and/or
-- __view are also included and the property lists are setup correctly.
local preload = function(m, isLua)
    return function()
        local el = isLua and require(USERDATA_TAG .. "_" .. m)
                         or  require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib") .. "_" .. m)
        local elMT = hs.getObjectMetatable(USERDATA_TAG .. "." .. m)
        if el and elMT then
            uitk.element._elementControlViewWrapper(elMT)
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

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")


-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- shortcut so ...:container(id | idx) returns element or nil
moduleMT.__call  = function(self, ...) return self:element(...) end

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
    if element then return element end

-- unrecognized
    return nil
end

moduleMT.__newindex = function(self, key, value)
    local idx = (math.type(key) == "integer") and key or nil
    if type(key) == "string" then idx = self:indexOf(key) end

    if idx then
        if idx < 1 or idx > #self + 1 then error("index out of bounds", 3) end

        if uitk.element.isElementType(value) then value = { _self = value } end

        if type(value) == "table" then
            local element = value._self
        -- add/insert new element
            if uitk.element.isElementType(element) then
                -- insert could fail for some reason, so do it first
                self:insert(element, value.containerFrame or {}, idx)
                if self:element(idx + 1) then self:remove(idx + 1) end
                element._properties = value
                return
            end
        -- remove element
        elseif type(value) == "nil" then
            if idx == #self + 1 then error("index out of bounds", 3) end
            self:remove(idx)
            return
        end

        error("value does not specify an element", 3)
    end

    error("attempt to index a " .. USERDATA_TAG, 3)
end

--- hs._asm.uitk.element.container:indexOf(item) -> integer | nil
--- Method
--- Returns the index of the specified element in the container
---
--- Parameters:
---  * `item` - a string specifying the `id` of the element or the userdata of the element itself
---
--- Returns:
---  * the index of the specified element, or nil if the element id or userdata is not a member of this container.
moduleMT.indexOf = function(self, ...)
    local args = table.pack(...)
    local id   = args[1]

    if args.n == 1 then
        local idx = nil
        if type(id) == "string" then
            for i, v in ipairs(self:elements()) do
                if id == v:id() then
                    idx = i
                    break
                end
            end
            return idx
        elseif uitk.element.isElementType(id) then
            for i, v in ipairs(self:elements()) do
                if id == v then
                    idx = i
                    break
                end
            end
            return idx
        end
    end
    error("expected a single string or element userdata argument", 3)
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
    local idx = args[1]
    if type(idx) == "userdata" or type(idx) == "string" then idx = self:indexOf(idx) end
    args[1] = idx

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


module.suppressZeroSizeWarnings = function(...)
    local args = table.pack(...)

    if args.n == 1 then
        if type(args[1]) == "boolean" or type(args[1]) == "nil" then
            settings.set("uitk_containerSuppressZeroWarnings", args[1])
        else
            error(string.format("incorrect type '%s' for argument 1 (expected boolean or nil)", type(args[1])), 3)
        end
    elseif args.n > 1 then
        error(string.format("incorrect number of arguments. Expected 1, got %d", args.n), 3)
    end

    return settings.get("uitk_containerSuppressZeroWarnings")
end

-- Return Module Object --------------------------------------------------

-- since we can be a nextResponder, we can provide additional methods to our children
moduleMT._inheritableMethods = {
    containerFrame  = moduleMT.elementFrame,
    position        = moduleMT.positionElement,
    id              = moduleMT.elementID,
    removeFromGroup = moduleMT.remove,
}

moduleMT._inheritableProperties = { "containerFrame", "id" }

-- it's nil here anyways, since it's inherited through shared view methods
-- -- normally handled by _elementControlViewWrapper, but we want to add fittingSize, so we invoke separately
-- uitk.util._properties.addPropertiesWrapper(moduleMT, { _fittingSize = moduleMT.fittingSize })

-- because we're loaded directly rather than through an element preload function, we need to invoke the
-- wrapper manually, but it needs to happen after our local __index and __newindex (if any) methods are defined
uitk.element._elementControlViewWrapper(moduleMT)

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
