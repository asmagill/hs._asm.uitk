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

--- === hs._asm.uitk.element.content.grid ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.element.content.grid"
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libcontent_"))

local content      = require("hs._asm.uitk.element.content")

local gridMT     = hs.getObjectMetatable(USERDATA_TAG)
local gridRowMT  = hs.getObjectMetatable(USERDATA_TAG .. ".row")
local gridColMT  = hs.getObjectMetatable(USERDATA_TAG .. ".column")
local gridCellMT = hs.getObjectMetatable(USERDATA_TAG .. ".cell")

local fnutils = require("hs.fnutils")

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
local settings     = require("hs.settings")
local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- a wrapped userdata is an userdata "converted" into an object that can be modified like
-- a lua key-value table
local wrappedGridRowMT  = { __e = setmetatable({}, { __mode = "k" }) }
local wrappedGridColMT  = { __e = setmetatable({}, { __mode = "k" }) }
local wrappedGridCellMT = { __e = setmetatable({}, { __mode = "k" }) }

local wrapped_gridRowWithMT = function(userdata)
    if userdata then
        local newItem = {}
        wrappedGridRowMT.__e[newItem] = {
            userdata   = userdata,
            userdataMT = getmetatable(userdata)
        }
        return setmetatable(newItem, wrappedGridRowMT)
    else
        return nil
    end
end

local wrapped_gridColWithMT = function(userdata)
    if userdata then
        local newItem = {}
        wrappedGridColMT.__e[newItem] = {
            userdata   = userdata,
            userdataMT = getmetatable(userdata)
        }
        return setmetatable(newItem, wrappedGridColMT)
    else
        return nil
    end
end

local wrapped_gridCellWithMT = function(userdata)
    if userdata then
        local newItem = {}
        wrappedGridCellMT.__e[newItem] = {
            userdata   = userdata,
            userdataMT = getmetatable(userdata)
        }
        return setmetatable(newItem, wrappedGridCellMT)
    else
        return nil
    end
end

wrappedGridRowMT.__index = function(self, key)
    local obj = wrappedGridRowMT.__e[self]
    local userdata = obj.userdata

-- builtin convenience values
    if key == "_row" then
        return userdata
    elseif key == "_type" then
        return (obj.userdataMT or {}).__type

-- property methods
    elseif fnutils.contains(((obj.userdataMT or {})._propertyList or {}), key) then
        return userdata[key](userdata)

-- cell index
    elseif math.type(key) == "integer" then
        return userdata:cell(key):wrap()

-- unrecognized
    else
        return nil
    end
end

wrappedGridColMT.__index = function(self, key)
    local obj = wrappedGridColMT.__e[self]
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
        return userdata:cell(key):wrap()

-- unrecognized
    else
        return nil
    end
end

wrappedGridCellMT.__index = function(self, key)
    local obj = wrappedGridCellMT.__e[self]
    local userdata = obj.userdata

-- builtin convenience values
    if key == "_cell" then
        return userdata
    elseif key == "_row" then
        return userdata:row()
    elseif key == "_column" then
        return userdata:column()
    elseif key == "_type" then
        return (obj.userdataMT or {}).__type

-- property methods
    elseif fnutils.contains(((obj.userdataMT or {})._propertyList or {}), key) then
        return userdata[key](userdata)

-- unrecognized
    else
        return nil
    end
end

wrappedGridRowMT.__newindex = function(self, key, value)
    local obj = wrappedGridRowMT.__e[self]
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

wrappedGridColMT.__newindex = function(self, key, value)
    local obj = wrappedGridColMT.__e[self]
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

wrappedGridCellMT.__newindex = function(self, key, value)
    local obj = wrappedGridCellMT.__e[self]
    local userdata = obj.userdata

-- builtin convenience read-only values
    if key == "_cell" or key == "_type" then
        error(key .. " cannot be modified", 3)

-- property methods
    elseif fnutils.contains(((obj.userdataMT or {})._propertyList or {}), key) then
        userdata[key](userdata, value)

-- unrecognized
    else
        error(tostring(key) .. " unrecognized property", 3)
    end
end

wrappedGridRowMT.__tostring = function(self)
    return "(wrapped) " .. tostring(wrappedGridRowMT.__e[self].userdata)
end

wrappedGridColMT.__tostring = function(self)
    return "(wrapped) " .. tostring(wrappedGridColMT.__e[self].userdata)
end

wrappedGridCellMT.__tostring = function(self)
    return "(wrapped) " .. tostring(wrappedGridCellMT.__e[self].userdata)
end

wrappedGridRowMT.__len = function(self) return 0 end
wrappedGridColMT.__len = function(self) return 0 end
wrappedGridCellMT.__len = function(self) return 0 end

wrappedGridRowMT.__pairs = function(self)
    local obj = wrappedGridRowMT.__e[self]
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

wrappedGridColMT.__pairs = function(self)
    local obj = wrappedGridColMT.__e[self]
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

wrappedGridCellMT.__pairs = function(self)
    local obj = wrappedGridCellMT.__e[self]
    local userdata = obj.userdata

    local keys = {  "_cell", "_type", "_row", "_column" }
    for i,v in ipairs(obj.userdataMT._propertyList or {}) do table.insert(keys, v) end

    return function(_, k)
        local v = nil
        k = table.remove(keys)
        if k then v = self[k] end
        return k, v
    end, self, nil
end

-- Public interface ------------------------------------------------------

local prev_gridIndex = gridMT.__index
gridMT.__index = function(self, key)
    local result = nil

-- check index as it was prior to this function
    if type(prev_gridIndex) == "function" then
        result =  prev_gridIndex(self, key)
    else
        result = prev_gridIndex[key]
    end

    if type(result) ~= "nil" then return result end

-- check to see if its a row index
    if math.type(key) == "integer" then
        if key == 0 then
            return setmetatable({}, {
                __index = function(_, colKey)
                    if math.type(colKey) == "integer" then
                        return self:column(colKey):wrap()
                    else
                        return nil
                    end
                end,
            })
        else
            return self:row(key):wrap()
        end
    end

-- unrecognized
    return nil
end

gridRowMT.wrap = function(self) return wrapped_gridRowWithMT(self) end

gridColMT.wrap = function(self) return wrapped_gridColWithMT(self) end

gridCellMT.wrap = function(self) return wrapped_gridCellWithMT(self) end

gridCellMT.rowIndex = function(self) return self:row():index() end

gridCellMT.columnIndex = function(self) return self:column():index() end

-- Return Module Object --------------------------------------------------

-- since we can be a nextResponder, we can provide additional methods to our children
-- gridMT._inheritableMethods = { }

return module
