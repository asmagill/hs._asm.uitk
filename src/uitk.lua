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
-- local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib"))

local module = {}

local subModules = {
    element = USERDATA_TAG:match("^([%w%._]+%.)") .. ".element",
    menu    = USERDATA_TAG:match("^([%w%._]+%.)") .. ".menu",
    menubar = USERDATA_TAG:match("^([%w%._]+%.)") .. ".menubar",
    window  = USERDATA_TAG:match("^([%w%._]+%.)") .. ".window",
}

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

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
