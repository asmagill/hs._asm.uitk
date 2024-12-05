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

local USERDATA_TAG = "hs._asm.uitk.element.sceneKit"
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib"))

local uitk    = require("hs._asm.uitk")
local color   = uitk.util.color
local matrix4 = uitk.util.matrix4
local fnutils = require("hs.fnutils")

require("hs.image")

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)

local subModules = {
--  name       lua or library?
    node          = false,
    geometry      = true,
--     material      = false,
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

-- we need the node definition to exist so `new` can retain the root node
module.node = require(USERDATA_TAG .. ".node")

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- store this in the registry so we can easily set it both from Lua and from C functions
debug.getregistry()["hs._asm.uitk.element.sceneKit.vector3"] = {
    __type     = "hs._asm.uitk.element.sceneKit.vector3",
    __name     = "hs._asm.uitk.element.sceneKit.vector3",
    __tostring = function(_)
        return string.format("[ % 10.4f % 10.4f % 10.4f ]", _.x, _.y, _.z)
    end,
}

-- store this in the registry so we can easily set it both from Lua and from C functions
debug.getregistry()["hs._asm.uitk.element.sceneKit.vector4"] = {
    __type     = "hs._asm.uitk.element.sceneKit.vector4",
    __name     = "hs._asm.uitk.element.sceneKit.vector4",
    __tostring = function(_)
        return string.format("[ % 10.4f % 10.4f % 10.4f % 10.4f ]", _.x, _.y, _.z, _.w)
    end,
}

-- store this in the registry so we can easily set it both from Lua and from C functions
debug.getregistry()["hs._asm.uitk.element.sceneKit.quaternion"] = {
    __type     = "hs._asm.uitk.element.sceneKit.quaternion",
    __name     = "hs._asm.uitk.element.sceneKit.quaternion",
    __tostring = function(_)
        return string.format("[ % 10.4f % 10.4f % 10.4f % 10.4f ]", _.ix, _.iy, _.iz, _.r)
    end,
}

-- Return Module Object --------------------------------------------------

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
