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

--- === hs._asm.uitk.panel.color ===
---
--- Provides access to the macOS Color Panel for UTIK.
---
--- Display and control a color panel allowing the user to select a color object for use within `hs._asm.uitk` and other places where Hammerspoon allows the user to select or specify a color.
---
--- Note that the Hamemrspoon application shares one color panel for all uses -- make sure to set any properties or accessory views you require *each-and-every* time you present it for a new use to ensure that it shows the appropriate options required for your current usage.
---
--- Heavily influenced by the `hs.dialog` module.

local USERDATA_TAG = "hs._asm.uitk.panel.color"
local uitk         = require("hs._asm.uitk")
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libpanel_"))

local color        = uitk.util.color -- make sure helpers for NSColor and NSColorList are loaded

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module
