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

--- === hs._asm.uitk.element.container.text ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.element.container.table"
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libcontainer_"))
local uitk         = require("hs._asm.uitk")
local element      = uitk.element

local tableMT       = hs.getObjectMetatable(USERDATA_TAG)
local tableRowMT    = hs.getObjectMetatable(USERDATA_TAG .. ".row")
local tableColumnMT = hs.getObjectMetatable(USERDATA_TAG .. ".column")

-- row is a View type element, but column isn't
element._elementControlViewWrapper(tableRowMT)

-- -- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- -- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

local fnutils = require("hs.fnutils")

-- private variables and methods -----------------------------------------

-- a wrapped userdata is an userdata "converted" into an object that can be modified like
-- a lua key-value table
local wrappedTableRowMT  = { __e = setmetatable({}, { __mode = "k" }) }
local wrappedTableColMT  = { __e = setmetatable({}, { __mode = "k" }) }

local wrapped_tableRowWithMT = function(userdata)
    if userdata then
        local newItem = {}
        wrappedTableRowMT.__e[newItem] = {
            userdata   = userdata,
            userdataMT = getmetatable(userdata)
        }
        return setmetatable(newItem, wrappedTableRowMT)
    else
        return nil
    end
end

local wrapped_tableColWithMT = function(userdata)
    if userdata then
        local newItem = {}
        wrappedTableColMT.__e[newItem] = {
            userdata   = userdata,
            userdataMT = getmetatable(userdata)
        }
        return setmetatable(newItem, wrappedTableColMT)
    else
        return nil
    end
end

wrappedTableRowMT.__index = function(self, key)
    local obj = wrappedTableRowMT.__e[self]
    local userdata = obj.userdata

-- builtin convenience values
    if key == "_row" then
        return userdata
    elseif key == "_type" then
        return (obj.userdataMT or {}).__type

-- property methods
    elseif fnutils.contains(((obj.userdataMT or {})._propertyList or {}), key) then
        print(key)
        return userdata[key](userdata)

-- cell index
    elseif math.type(key) == "integer" or type(key) == "string" then
        local result = userdata:viewAtColumn(key)
        return result and result:wrap() or nil

-- unrecognized
    else
        return nil
    end
end

wrappedTableColMT.__index = function(self, key)
    local obj = wrappedTableColMT.__e[self]
    local userdata = obj.userdata

-- builtin convenience values
    if key == "_column" then
        return userdata
    elseif key == "_type" then
        return (obj.userdataMT or {}).__type

-- property methods
    elseif fnutils.contains(((obj.userdataMT or {})._propertyList or {}), key) then
        return userdata[key](userdata)

-- cell index
    elseif math.type(key) == "integer" then
        local result = userdata:element(key, userdata:identifier())
        return result and result:wrap() or nil

-- unrecognized
    else
        return nil
    end
end

wrappedTableRowMT.__newindex = function(self, key, value)
    local obj = wrappedTableRowMT.__e[self]
    local userdata = obj.userdata

-- builtin convenience read-only values
    if key == "_row" or key == "_type" then
        error(key .. " cannot be modified", 3)

-- property methods
    elseif fnutils.contains(((obj.userdataMT or {})._propertyList or {}), key) then
        userdata[key](userdata, value)

-- unrecognized
    else
        error(tostring(key) .. " unrecognized property", 3)
    end
end

wrappedTableColMT.__newindex = function(self, key, value)
    local obj = wrappedTableColMT.__e[self]
    local userdata = obj.userdata

-- builtin convenience read-only values
    if key == "_column" or key == "_type" then
        error(key .. " cannot be modified", 3)

-- property methods
    elseif fnutils.contains(((obj.userdataMT or {})._propertyList or {}), key) then
        userdata[key](userdata, value)

-- unrecognized
    else
        error(tostring(key) .. " unrecognized property", 3)
    end
end

wrappedTableRowMT.__tostring = function(self)
    return "(wrapped) " .. tostring(wrappedTableRowMT.__e[self].userdata)
end

wrappedTableColMT.__tostring = function(self)
    return "(wrapped) " .. tostring(wrappedTableColMT.__e[self].userdata)
end

wrappedTableRowMT.__len = function(self) return 0 end
wrappedTableColMT.__len = function(self) return 0 end

wrappedTableRowMT.__pairs = function(self)
    local obj = wrappedTableRowMT.__e[self]
    local userdata = obj.userdata

    local keys = {  "_row", "_type" }
    for i,v in ipairs(obj.userdataMT._propertyList or {}) do table.insert(keys, v) end

    return function(_, k)
        local v = nil
        k = table.remove(keys)
        if k then v = self[k] end
        return k, v
    end, self, nil
end

wrappedTableColMT.__pairs = function(self)
    local obj = wrappedTableColMT.__e[self]
    local userdata = obj.userdata

    local keys = {  "_column", "_type" }
    for i,v in ipairs(obj.userdataMT._propertyList or {}) do table.insert(keys, v) end

    return function(_, k)
        local v = nil
        k = table.remove(keys)
        if k then v = self[k] end
        return k, v
    end, self, nil
end

-- Public interface ------------------------------------------------------

local prev_tableIndex = tableMT.__index
tableMT.__index = function(self, key)
    local result = nil

-- check index as it was prior to this function
    if type(prev_tableIndex) == "function" then
        result =  prev_tableIndex(self, key)
    else
        result = prev_tableIndex[key]
    end

    if type(result) ~= "nil" then return result end

-- check to see if its a row index
    if math.type(key) == "integer" then
        if key == 0 then
            return setmetatable({}, {
                __index = function(_, colKey)
                    if math.type(colKey) == "integer" or type(colKey) == "string" then
                        local result = self:column(colKey)
                        return result and result:wrap() or nil
                    else
                        return nil
                    end
                end,
            })
        else
            local result = self:row(key)
            return result and result:wrap() or nil
        end
    end

-- unrecognized
    return nil
end

tableRowMT.wrap = function(self) return wrapped_tableRowWithMT(self) end

tableColumnMT.wrap = function(self) return wrapped_tableColWithMT(self) end

-- Return Module Object --------------------------------------------------

-- since we can be a nextResponder, we can provide additional methods to our children
-- moduleMT._inheritableMethods = { }

return module
