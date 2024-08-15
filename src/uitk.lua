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
--- A module providing submodules and methods for creating user interface elements for use with Hammerspoon.
---
--- This is the base module that coordinates the submodules and ensures that the necessary supporting modules are loaded and initialized properly.
---
--- When using this module and its submodules, you should always load this module first with `require` and access the submodule components as members of this module -- Using `require` to load a submodule directly is not supported and may result in errors or unexpected results.
---
--- e.g.
---     local uitk   = require("hs._asm.uitk")
---     local window = uitk.window
---
--- instead of:
---     local window = require("hs._asm.uitk.window")
---

local USERDATA_TAG = "hs._asm.uitk"
local module       = {}

local settings = require("hs.settings")

local legacyWrappers = { "canvas", "webview", "color", "menubar", "toolbar" }

local subModules = {
    element = USERDATA_TAG:match("^([%w%._]+%.)") .. ".element",
    menu    = USERDATA_TAG:match("^([%w%._]+%.)") .. ".menu",
    menubar = USERDATA_TAG:match("^([%w%._]+%.)") .. ".menubar",
    window  = USERDATA_TAG:match("^([%w%._]+%.)") .. ".window",
    panel   = USERDATA_TAG:match("^([%w%._]+%.)") .. ".panel",
    util    = USERDATA_TAG:match("^([%w%._]+%.)") .. ".util",
    toolbar = USERDATA_TAG:match("^([%w%._]+%.)") .. ".toolbar",
}

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

--- hs._asm.uitk.wrapCanvas([state]) -> bool | nil
--- Function
--- Get or set whether the built-in `hs.canvas` module is emulated by this module.
---
--- Parameters:
---  * `state` - an optional boolean specifying whether or not the built-in module should be emulated.
---
--- Returns:
---  * a boolean or nil indicating whether or not the module should be emulated by `hs._asm.uitk`. A nil response indicates that you have never set a preference, and is equivalent to false.
---
--- Notes:
---  * the emulation provided strives to provide as close to a drop-in replacement as possible -- the goal is that you shouldn't have to make any changes to existing code that is using the specified module; however, the emulation may not be perfect, and where there are known discrepancies, this will be noted.
---  * the emulation will also likely provide additional features or functionality not found in the core module.

--- hs._asm.uitk.wrapWebview([state]) -> bool | nil
--- Function
--- Get or set whether the built-in `hs.webview` module is emulated by this module.
---
--- Parameters:
---  * `state` - an optional boolean specifying whether or not the built-in module should be emulated.
---
--- Returns:
---  * a boolean or nil indicating whether or not the module should be emulated by `hs._asm.uitk`. A nil response indicates that you have never set a preference, and is equivalent to false.
---
--- Notes:
---  * the emulation provided strives to provide as close to a drop-in replacement as possible -- the goal is that you shouldn't have to make any changes to existing code that is using the specified module; however, the emulation may not be perfect, and where there are known discrepancies, this will be noted.
---  * the emulation will also likely provide additional features or functionality not found in the core module.

--- hs._asm.uitk.wrapColor([state]) -> bool | nil
--- Function
--- Get or set whether the built-in `hs.drawing.color` module is emulated by this module.
---
--- Parameters:
---  * `state` - an optional boolean specifying whether or not the built-in module should be emulated.
---
--- Returns:
---  * a boolean or nil indicating whether or not the module should be emulated by `hs._asm.uitk`. A nil response indicates that you have never set a preference, and is equivalent to false.
---
--- Notes:
---  * the emulation provided strives to provide as close to a drop-in replacement as possible -- the goal is that you shouldn't have to make any changes to existing code that is using the specified module; however, the emulation may not be perfect, and where there are known discrepancies, this will be noted.
---  * the emulation will also likely provide additional features or functionality not found in the core module.

--- hs._asm.uitk.wrapMenubar([state]) -> bool | nil
--- Function
--- Get or set whether the built-in `hs.menubar` module is emulated by this module.
---
--- Parameters:
---  * `state` - an optional boolean specifying whether or not the built-in module should be emulated.
---
--- Returns:
---  * a boolean or nil indicating whether or not the module should be emulated by `hs._asm.uitk`. A nil response indicates that you have never set a preference, and is equivalent to false.
---
--- Notes:
---  * the emulation provided strives to provide as close to a drop-in replacement as possible -- the goal is that you shouldn't have to make any changes to existing code that is using the specified module; however, the emulation may not be perfect, and where there are known discrepancies, this will be noted.
---  * the emulation will also likely provide additional features or functionality not found in the core module.

--- hs._asm.uitk.wrapToolbar([state]) -> bool | nil
--- Function
--- Get or set whether the built-in `hs.webview.toolbar` module is emulated by this module.
---
--- Parameters:
---  * `state` - an optional boolean specifying whether or not the built-in module should be emulated.
---
--- Returns:
---  * a boolean or nil indicating whether or not the module should be emulated by `hs._asm.uitk`. A nil response indicates that you have never set a preference, and is equivalent to false.
---
--- Notes:
---  * the emulation provided strives to provide as close to a drop-in replacement as possible -- the goal is that you shouldn't have to make any changes to existing code that is using the specified module; however, the emulation may not be perfect, and where there are known discrepancies, this will be noted.
---  * the emulation will also likely provide additional features or functionality not found in the core module.

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

--- hs._asm.uitk.wrapperStatus() -> table
--- Function
--- Get the current status of the core module wrappers provided by this module.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table containing key-value pairs indicating which, if any, wrappers provided by this module are currently in effect.
---
--- Notes:
---  * the table returned will have a __tostring metamethod that displays the status of each key, so the results can easily be viewed in the Hammerspoon console by simply invoking this function.
module.wrapperStatus = function()
    local results = {}
    local output = ""
    for _, v in ipairs(legacyWrappers) do
        local status = settings.get("uitk_wrap" .. v:sub(1,1):upper() .. v:sub(2))
        results[v] = status
        output = output .. string.format("%-10s %s\n", v, tostring(status))
    end
    return setmetatable(results, { __tostring = function(...) return output end })
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
