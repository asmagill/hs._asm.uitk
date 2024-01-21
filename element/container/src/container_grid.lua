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

--- === hs._asm.uitk.element.container.grid ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.element.container.grid"
local uitk         = require("hs._asm.uitk")
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libcontainer_"))

local moduleMT   = hs.getObjectMetatable(USERDATA_TAG)
local gridRowMT  = hs.getObjectMetatable(USERDATA_TAG .. ".row")
local gridColMT  = hs.getObjectMetatable(USERDATA_TAG .. ".column")
local gridCellMT = hs.getObjectMetatable(USERDATA_TAG .. ".cell")

-- -- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- -- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

local prev_gridIndex = moduleMT.__index
moduleMT.__index = function(self, key)
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
        if key == 0 then -- placeholder so we can capture a column with the next index
            return setmetatable({}, {
                __index = function(_, colKey)
                    if math.type(colKey) == "integer" then
                        return self:column(colKey)
                    else
                        return nil
                    end
                end,
            })
        else
            return self:row(key)
        end
    end

-- unrecognized
    return nil
end

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

local prev_gridRowIndex = gridRowMT.__index
gridRowMT.__index = function(self, key)
    local result = nil

-- check index as it was prior to this function
    if type(prev_gridRowIndex) == "function" then
        result =  prev_gridRowIndex(self, key)
    else
        result = prev_gridRowIndex[key]
    end

    if type(result) ~= "nil" then return result end

    if math.type(key) == "integer" then
        return self:cell(key)
    end

-- unrecognized
    return nil
end

gridRowMT.__len = function(self)
    local parent = self:grid()
    return parent and parent:columns() or 0
end

local prev_gridColIndex = gridColMT.__index
gridColMT.__index = function(self, key)
    local result = nil

-- check index as it was prior to this function
    if type(prev_gridColIndex) == "function" then
        result =  prev_gridColIndex(self, key)
    else
        result = prev_gridColIndex[key]
    end

    if type(result) ~= "nil" then return result end

    if math.type(key) == "integer" then
        return self:cell(key)
    end

-- unrecognized
    return nil
end

gridColMT.__len = function(self)
    local parent = self:grid()
    return parent and parent:rows() or 0
end

gridCellMT.rowIndex = function(self) return self:row():index() end

gridCellMT.columnIndex = function(self) return self:column():index() end

-- Return Module Object --------------------------------------------------

-- since we can be a nextResponder, we can provide additional methods to our children
-- moduleMT._inheritableMethods = { }
-- moduleMT._inheritableProperties = { ... }

uitk.util._properties.addPropertiesWrapper(gridRowMT)
uitk.util._properties.addPropertiesWrapper(gridColMT)
uitk.util._properties.addPropertiesWrapper(gridCellMT, { _row = gridCellMT.row, _column = gridCellMT.column })

return module
