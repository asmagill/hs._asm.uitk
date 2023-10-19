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

local container    = require("hs._asm.uitk.element.container")

local tableMT       = hs.getObjectMetatable(USERDATA_TAG)
local tableColumnMT = hs.getObjectMetatable(USERDATA_TAG .. ".column")

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
local settings     = require("hs.settings")
local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

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
                        return self:column(colKey) -- :wrap()
                    else
                        return nil
                    end
                end,
            })
        else
            return self:row(key) -- :wrap()
        end
    end

-- unrecognized
    return nil
end

-- gridRowMT.wrap = function(self) return wrapped_gridRowWithMT(self) end
--
-- gridColMT.wrap = function(self) return wrapped_gridColWithMT(self) end

-- Return Module Object --------------------------------------------------

return module
