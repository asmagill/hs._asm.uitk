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

local moduleMT      = hs.getObjectMetatable(USERDATA_TAG)
local tableRowMT    = hs.getObjectMetatable(USERDATA_TAG .. ".row")
local tableColumnMT = hs.getObjectMetatable(USERDATA_TAG .. ".column")

-- -- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- -- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

local prev_tableIndex = moduleMT.__index
moduleMT.__index = function(self, key)
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

moduleMT.__len = function(self)
    return self:rows()
end

local prev_rowIndex = tableRowMT.__index
tableRowMT.__index = function(self, key)
    local result = nil

-- check index as it was prior to this function
    if type(prev_rowIndex) == "function" then
        result =  prev_rowIndex(self, key)
    else
        result = prev_rowIndex[key]
    end

    if type(result) ~= "nil" then return result end

-- check to see if it's a column index or identifier
    if math.type(key) == "integer" or type(key) == "string" then
        local parent = self:_nextResponder()
        return parent and self:cell(key) or nil
    else
        return nil
    end
end

tableRowMT.__len = function(self)
    local parent = self:_nextResponder()
    return parent and parent:columns() or 0
end

local prev_colIndex = tableColumnMT.__index
tableColumnMT.__index = function(self, key)
    local result = nil

-- check index as it was prior to this function
    if type(prev_colIndex) == "function" then
        result =  prev_colIndex(self, key)
    else
        result = prev_colIndex[key]
    end

    if type(result) ~= "nil" then return result end

-- check to see if it's a row index
    if math.type(key) == "integer" then
        local parent = self:table()
        return parent and parent:cell(key, self:identifier()) or nil
    else
        return nil
    end
end

tableColumnMT.__len = function(self)
    local parent = self:table()
    return parent and parent:rows() or 0
end

-- Return Module Object --------------------------------------------------

-- since we can be a nextResponder, we can provide additional methods to our children
-- moduleMT._inheritableMethods = { }
-- moduleMT._inheritableProperties = { ... }

-- row is a View type element, but column isn't
uitk.element._elementControlViewWrapper(tableRowMT)
uitk.util._properties.addPropertiesWrapper(tableColumnMT)

return module
