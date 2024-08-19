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

--- === hs._asm.uitk.util.gesture ===
---
--- Basic gesture recognizers for UITK elements.
---
--- You can add gestures created by this module to any `hs._asm.uitk.element`, using the element's `gestures` property or `addGesture` method. Likewise, gestures can be removed from an element using the `gestures` property or the `removeGesture` method. See the shared element documentation for more information.

local USERDATA_TAG         = "hs._asm.uitk.util.gesture"
local UD_CLICK_TAG         = USERDATA_TAG .. ".click"
local UD_MAGNIFICATION_TAG = USERDATA_TAG .. ".magnification"
local UD_PAN_TAG           = USERDATA_TAG .. ".pan"
local UD_PRESS_TAG         = USERDATA_TAG .. ".press"
local UD_ROTATION_TAG      = USERDATA_TAG .. ".rotation"

local uitk         = require("hs._asm.uitk")
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libutil_"))

-- private variables and methods -----------------------------------------

local clickMT         = hs.getObjectMetatable(UD_CLICK_TAG)
local magnificationMT = hs.getObjectMetatable(UD_MAGNIFICATION_TAG)
local panMT           = hs.getObjectMetatable(UD_PAN_TAG)
local pressMT         = hs.getObjectMetatable(UD_PRESS_TAG)
local rotationMT      = hs.getObjectMetatable(UD_ROTATION_TAG)

local cancelFn = function(self, ...)
    local args = table.pack(...)
    assert(args.n == 0, "expected 0 arguments")

    local originalState = self:enabled()
    self:enabled(not originalState)
    self:enabled(originalState)

    return self
end

clickMT.cancel         = cancelFn
magnificationMT.cancel = cancelFn
panMT.cancel           = cancelFn
pressMT.cancel         = cancelFn
rotationMT.cancel      = cancelFn

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

uitk.util._properties.addPropertiesWrapper(clickMT)
uitk.util._properties.addPropertiesWrapper(magnificationMT)
uitk.util._properties.addPropertiesWrapper(panMT)
uitk.util._properties.addPropertiesWrapper(pressMT)
uitk.util._properties.addPropertiesWrapper(rotationMT)

return module
