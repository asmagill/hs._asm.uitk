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

--- === hs._asm.uitk.element.textView ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.element.textView"
local uitk         = require("hs._asm.uitk")
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libelement_"))

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

module.actions            = ls.makeConstantsTable(module.actions)
module.findPanelActions   = ls.makeConstantsTable(module.findPanelActions)
module.layoutOrientations = ls.makeConstantsTable(module.layoutOrientations)
module.textCheckingTypes  = ls.makeConstantsTable(module.textCheckingTypes)

-- the initial value for enabledCheckingTypes has at least one flag that Apple doesn't document enabled...
-- create a mask that we can use to match all of these so we can make sure we don't inadvertently change
-- something important...
local otherCheckingMask = 0
for _, v in pairs(module.textCheckingTypes) do otherCheckingMask = otherCheckingMask | v end
otherCheckingMask = ~otherCheckingMask

local core_enabledCheckingTypes = moduleMT.enabledCheckingTypes
moduleMT.enabledCheckingTypes = function(self, ...)
    local args  = table.pack(...)
    local value = core_enabledCheckingTypes(self)

    if args.n == 1 and type(args[1]) == "table" then args = table.pack(table.unpack(args[1])) end

    if args.n == 0 then
        local answer = { _raw = value }
        for k, v in pairs(module.textCheckingTypes) do
            if value & v == v then table.insert(answer, k) end
        end
        return answer
    else
        -- initialize with any flags set that we don't know about -- see comment above
        local newValue = value & otherCheckingMask
        if args.n == 1 and math.type(args[1]) == "integer" then
            -- special case -- if they send us a single integer, then assume it's the merged set of flags wanted
            newValue = args[1]
        else
            local err = false
            for i = 1, args.n, 1 do
                local flag = args[i]
                if type(flag) == "string" then
                    flag = module.textCheckingTypes[flag]
                    if flag == 0 then
                        err = true
                        break
                    end
                end
                if math.type(flag) == "integer" then
                    newValue = newValue | flag
                else
                    err = true
                    break
                end
            end

            if err then
                return error(string.format("expected integer or string from %s.textCheckingTypes", USERDATA_TAG), 3)
            end
        end
        return core_enabledCheckingTypes(self, newValue)
    end
end

-- Return Module Object --------------------------------------------------

return module
