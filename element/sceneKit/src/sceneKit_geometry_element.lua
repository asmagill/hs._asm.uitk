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

--- === hs._asm.uitk.element.textField ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.element.sceneKit.geometry.element"
local uitk         = require("hs._asm.uitk")
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.[%w_]+%.([%w_]+)$") }, "libsceneKit_geometry_"))
local fnutils      = require("hs.fnutils")

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

local _data = moduleMT.data
moduleMT.data = function(self, ...)
    local args = table.pack(...)
    local raw  = _data(self)
    if args.n == 1 and args[1] then
        return raw
    end

    local I     = "I" .. tostring(self:bytesPerIndex())
    local count = self:primitiveCount()
    local pType = self:primitiveType()

    local primitiveSize = (pType == "line" and 2) or (pType == "triangles" and 3) or 1

    local answer, offset = {}, 0
    if pType ~= "polygon" then
        local idx = 0
        while idx < count do
            idx = idx + 1
            if pType == "triangleStrip" and idx == 1 then primitiveSize = 3 end

            local encoding = string.rep(I, primitiveSize)
            local chunk = { string.unpack(encoding, raw, offset) }
            offset = table.remove(chunk)

            -- lua starts indexing at 1; Obj-C at 0
            for i = 1, #chunk, 1 do chunk[i] = chunk[i] + 1 end

            if #chunk == 1 then
                table.insert(answer, chunk[1])
            else
                table.insert(answer, chunk)
            end

            if pType == "triangleStrip" and idx == 1 then primitiveSize = 1 end
        end
    else -- gonna take some thought
        error("not implemented for polygon type yet", 3)
    end

    return answer
end

-- Return Module Object --------------------------------------------------

return module
