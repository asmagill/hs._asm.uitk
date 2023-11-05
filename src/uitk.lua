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

--- === hs._asm.uitk ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk"
local module       = {}

local settings = require("hs.settings")

local legacyWrappers = { "canvas", "webview", "color", "menubar" }

local subModules = {
    element = USERDATA_TAG:match("^([%w%._]+%.)") .. ".element",
    menu    = USERDATA_TAG:match("^([%w%._]+%.)") .. ".menu",
    menubar = USERDATA_TAG:match("^([%w%._]+%.)") .. ".menubar",
    window  = USERDATA_TAG:match("^([%w%._]+%.)") .. ".window",
    panel   = USERDATA_TAG:match("^([%w%._]+%.)") .. ".panel",
    util    = USERDATA_TAG:match("^([%w%._]+%.)") .. ".util",
}

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

for _, v in ipairs(legacyWrappers) do
    local upperV = v:sub(1,1):upper() .. v:sub(2)
    local fnName = "wrap" .. upperV
    local tag    = "uitk_" .. fnName

    module[fnName] = function(...)
        local args = table.pack(...)

        if args.n == 1 then
            if type(args[1]) == "boolean" or type(args[1]) == "nil" then
                settings.set(tag, args[1])
            else
                error(string.format("incorrect type '%s' for argument 1 (expected boolean or nil)", type(args[1])), 3)
            end
        elseif args.n > 1 then
            error(string.format("incorrect number of arguments. Expected 1, got %d", args.n), 3)
        end

        return settings.get(tag)
    end
end

module.wrapperStatus = function()
    for _, v in ipairs(legacyWrappers) do
        print(v, settings.get("uitk_wrap" .. v:sub(1,1):upper() .. v:sub(2)))
    end
end

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
--     __call  = function(self, ...) return self.new(...) end,
    __index = function(self, key)
        if type(subModules[key]) ~= "nil" then
            module[key] = require(USERDATA_TAG .. "." ..key)
            return module[key]
        else
            return nil
        end
    end,
})
