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

--- === hs._asm.uitk.element ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.element"
local uitk         = require("hs._asm.uitk")
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib"))

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
local settings     = require("hs.settings")
local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- make sure support functions registered
require("hs.drawing.color")
require("hs.image")
require("hs.styledtext")
require("hs.sharing")

local fnutils = require("hs.fnutils")

local _controlMT   = require(USERDATA_TAG:match("^(.+)%.") ..".libelement__control")
local _viewMT      = require(USERDATA_TAG:match("^(.+)%.") ..".libelement__view")

local subModules = {
--  name         lua or library?
    avplayer        = false,
    button          = true,
    canvas          = USERDATA_TAG .. ".canvas",
    colorwell       = false,
    comboButton     = false,
    container       = USERDATA_TAG .. ".container",
    datepicker      = true,
    image           = true,
    levelIndicator  = false,
    popUpButton     = false,
    progress        = false,
    segmentBar      = true,
    slider          = false,
    stepper         = false,
    switch          = false,
    textField       = USERDATA_TAG .. ".textField",
    textView        = true,
    turtle          = true,
}

-- set up preload for elements so that when they are loaded, the methods from _control and/or
-- __view are also included and the property lists are setup correctly.
local preload = function(m, isLua)
    return function()
        local el = isLua and require(USERDATA_TAG .. "_" .. m)
                         or  require(USERDATA_TAG:match("^(.+)%.") .. ".lib" ..
                                     USERDATA_TAG:match("^.+%.(.+)$") .. "_" .. m)
        local elMT = hs.getObjectMetatable(USERDATA_TAG .. "." .. m)
        if el and elMT then
            module._elementControlViewWrapper(elMT)
        end

        if getmetatable(el) == nil and type(el.new) == "function" then
            el = setmetatable(el, { __call = function(self, ...) return self.new(...) end })
        end
        return el
    end
end

for k, v in pairs(subModules) do
    if type(v) == "boolean" then
        package.preload[USERDATA_TAG .. "." .. k] = preload(k, v)
    end
end

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

module.windowFor = _viewMT._window

module.nextResponder = _viewMT._nextResponder

module._elementControlViewWrapper = function(elMT)
    if elMT._inheritControl then
        for k, v in pairs(_controlMT) do
            if type(v) == "function" and not elMT[k] then
                elMT[k] = v
                if fnutils.contains(_controlMT._propertyList, k) and not fnutils.contains(elMT._propertyList, k) then
                    table.insert(elMT._propertyList, k)
                end
            end
        end
    end
    for k, v in pairs(_viewMT) do
        if type(v) == "function" and not elMT[k] then
            elMT[k] = v
            if fnutils.contains(_viewMT._propertyList, k) and not fnutils.contains(elMT._propertyList, k) then
                table.insert(elMT._propertyList, k)
            end
        end
    end

    uitk.util._properties.addPropertiesWrapper(elMT)
end

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
    __index = function(self, key)
        if type(subModules[key]) ~= "nil" then
            module[key] = require(USERDATA_TAG .. "." ..key)
            return module[key]
        else
            return nil
        end
    end,
})
