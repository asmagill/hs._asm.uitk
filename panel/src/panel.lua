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

--- === hs._asm.uitk.panel ===
---
--- A basic container within which complex windows and graphical elements can be combined.
---
--- This module provides a basic container within which Hammerspoon can build more complex windows and graphical elements. The approach taken with this module is to create a "window" or rectangular space within which a content manager from one of the submodules of `hs._asm.uitk.panel` can be assigned. Canvas, WebView, and other visual or GUI elements can then be assigned to the content manager and will be positioned and auto-arranged as determined by the rules governing the chosen manager.
---
--- This approach allows concentrating the common code necessary for managing macOS window and panel containers in one place while leveraging content view managers within macOS to easily encorporate different GUI elements. This will allow the creation of significantly more complex and varied displays and input mechanisms than are currently difficult or impossible to create with just `hs.canvas` or `hs.webview`.
---
--- This is a work in progress and is still extremely experimental.

local USERDATA_TAG = "hs._asm.uitk.panel"
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)([%w_]+)$") }, "lib"))
module.element     = require(USERDATA_TAG:match("^(.+)%.") .. ".element")

local panelMT = hs.getObjectMetatable(USERDATA_TAG)

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- make sure support functions registered
require("hs.drawing.color")
require("hs.image")
require("hs.window")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

module._new = module.new
module.new = function(...)
    return module._new(...):content(module.element.content())
end

module.behaviors     = ls.makeConstantsTable(module.behaviors)
module.levels        = ls.makeConstantsTable(module.levels)
module.masks         = ls.makeConstantsTable(module.masks)
module.notifications = ls.makeConstantsTable(module.notifications)

--- hs._asm.uitk.panel:styleMask([mask]) -> panelObject | integer
--- Method
--- Get or set the window display style
---
--- Parameters:
---  * `mask` - if present, this mask should be a combination of values found in [hs._asm.uitk.panel.masks](#masks) describing the window style.  The mask should be provided as one of the following:
---    * integer - a number representing the style which can be created by combining values found in [hs._asm.uitk.panel.masks](#masks) with the logical or operator (e.g. `value1 | value2 | ... | valueN`).
---    * string  - a single key from [hs._asm.uitk.panel.masks](#masks) which will be toggled in the current window style.
---    * table   - a list of keys from [hs._asm.uitk.panel.masks](#masks) which will be combined to make the final style by combining their values with the logical or operator.
---
--- Returns:
---  * if a parameter is specified, returns the panel object, otherwise the current value
panelMT._styleMask = panelMT.styleMask -- save raw version
panelMT.styleMask = function(self, ...) -- add nice wrapper version
    local arg = table.pack(...)
    local theMask = panelMT._styleMask(self)

    if arg.n ~= 0 then
        if math.type(arg[1]) == "integer" then
            theMask = arg[1]
        elseif type(arg[1]) == "string" then
            if module.masks[arg[1]] then
                theMask = theMask ~ module.masks[arg[1]]
            else
                return error("unrecognized style specified: "..arg[1])
            end
        elseif type(arg[1]) == "table" then
            theMask = 0
            for i,v in ipairs(arg[1]) do
                if module.masks[v] then
                    theMask = theMask | module.masks[v]
                else
                    return error("unrecognized style specified: "..v)
                end
            end
        else
            return error("integer, string, or table expected, got "..type(arg[1]))
        end
        return panelMT._styleMask(self, theMask)
    else
        return theMask
    end
end

--- hs._asm.uitk.panel:collectionBehavior([behaviorMask]) -> panelObject | integer
--- Method
--- Get or set the panel window collection behavior with respect to Spaces and Exposé.
---
--- Parameters:
---  * `behaviorMask` - if present, this mask should be a combination of values found in [hs._asm.uitk.panel.behaviors](#behaviors) describing the collection behavior.  The mask should be provided as one of the following:
---    * integer - a number representing the desired behavior which can be created by combining values found in [hs._asm.uitk.panel.behaviors](#behaviors) with the logical or operator (e.g. `value1 | value2 | ... | valueN`).
---    * string  - a single key from [hs._asm.uitk.panel.behaviors](#behaviors) which will be toggled in the current collection behavior.
---    * table   - a list of keys from [hs._asm.uitk.panel.behaviors](#behaviors) which will be combined to make the final collection behavior by combining their values with the logical or operator.
---
--- Returns:
---  * if a parameter is specified, returns the panel object, otherwise the current value
---
--- Notes:
---  * Collection behaviors determine how the panel window is handled by Spaces and Exposé. See [hs._asm.uitk.panel.behaviors](#behaviors) for more information.
panelMT._collectionBehavior = panelMT.collectionBehavior -- save raw version
panelMT.collectionBehavior = function(self, ...)          -- add nice wrapper version
    local arg = table.pack(...)
    local theBehavior = panelMT._collectionBehavior(self)

    if arg.n ~= 0 then
        if math.type(arg[1]) == "integer" then
            theBehavior = arg[1]
        elseif type(arg[1]) == "string" then
            if module.behaviors[arg[1]] then
                theBehavior = theBehavior ~ module.behaviors[arg[1]]
            else
                return error("unrecognized behavior specified: "..arg[1])
            end
        elseif type(arg[1]) == "table" then
            theBehavior = 0
            for i,v in ipairs(arg[1]) do
                if module.behaviors[v] then
                    theBehavior = theBehavior | ((type(v) == "string") and module.behaviors[v] or v)
                else
                    return error("unrecognized behavior specified: "..v)
                end
            end
        else
            return error("integer, string, or table expected, got "..type(arg[1]))
        end
        return panelMT._collectionBehavior(self, theBehavior)
    else
        return theBehavior
    end
end

--- hs._asm.uitk.panel:level([theLevel]) -> panelObject | integer
--- Method
--- Get or set the panel window level
---
--- Parameters:
---  * `theLevel` - an optional parameter specifying the desired level as an integer or as a string matching a label in [hs._asm.uitk.panel.levels](#levels)
---
--- Returns:
---  * if a parameter is specified, returns the panel object, otherwise the current value
---
--- Notes:
---  * See the notes for [hs._asm.uitk.panel.levels](#levels) for a description of the available levels.
---
---  * Recent versions of macOS have made significant changes to the way full-screen apps work which may prevent placing Hammerspoon elements above some full screen applications.  At present the exact conditions are not fully understood and no work around currently exists in these situations.
panelMT._level = panelMT.level     -- save raw version
panelMT.level = function(self, ...) -- add nice wrapper version
    local arg = table.pack(...)
    local theLevel = panelMT._level(self)

    if arg.n ~= 0 then
        if math.type(arg[1]) == "integer" then
            theLevel = arg[1]
        elseif type(arg[1]) == "string" then
            if module.levels[arg[1]] then
                theLevel = module.levels[arg[1]]
            else
                return error("unrecognized level specified: "..arg[1])
            end
        else
            return error("integer or string expected, got "..type(arg[1]))
        end
        return panelMT._level(self, theLevel)
    else
        return theLevel
    end
end

--- hs._asm.uitk.panel:bringToFront([aboveEverything]) -> panelObject
--- Method
--- Places the panel window on top of normal windows
---
--- Parameters:
---  * `aboveEverything` - An optional boolean value that controls how far to the front the panel window should be placed. True to place the window on top of all windows (including the dock and menubar and fullscreen windows), false to place the webview above normal windows, but below the dock, menubar and fullscreen windows. Defaults to false.
---
--- Returns:
---  * The webview object
---
--- Notes:
---  * Recent versions of macOS have made significant changes to the way full-screen apps work which may prevent placing Hammerspoon elements above some full screen applications.  At present the exact conditions are not fully understood and no work around currently exists in these situations.
panelMT.bringToFront = function(self, ...)
    local args = table.pack(...)

    if args.n == 0 then
        return self:level(module.levels.floating)
    elseif args.n == 1 and type(args[1]) == "boolean" then
        return self:level(module.levels[(args[1] and "screenSaver" or "floating")])
    elseif args.n > 1 then
        error("bringToFront method expects 0 or 1 arguments", 2)
    else
        error("bringToFront method argument must be boolean", 2)
    end
end

--- hs._asm.uitk.panel:sendToBack() -> panelObject
--- Method
--- Places the panel window behind normal windows, between the desktop wallpaper and desktop icons
---
--- Parameters:
---  * None
---
--- Returns:
---  * The panel object
panelMT.sendToBack = function(self, ...)
    local args = table.pack(...)

    if args.n == 0 then
        return self:level(module.levels.desktopIcon - 1)
    else
        error("sendToBack method expects 0 arguments", 2)
    end
end

--- hs._asm.uitk.panel:isVisible() -> boolean
--- Method
--- Returns whether or not the panel window is currently showing and is (at least partially) visible on screen.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a boolean indicating whether or not the panel window is currently visible.
---
--- Notes:
---  * This is syntactic sugar for `not hs._asm.uitk.panel:isOccluded()`.
---  * See [hs._asm.uitk.panel:isOccluded](#isOccluded) for more details.
panelMT.isVisible = function(self, ...) return not self:isOccluded(...) end

-- Return Module Object --------------------------------------------------

-- since we can be a nextResponder, we can provide additional methods to our children
-- panelMT._inheritableMethods = { }

return setmetatable(module, {
    __call = function(self, ...) return self.new(...) end,
})

