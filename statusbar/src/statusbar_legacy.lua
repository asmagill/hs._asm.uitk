local USERDATA_TAG = "hs.menubar.legacy"
local uitk         = require("hs._asm.uitk")
local module       = {}

local styledtext   = require("hs.styledtext")
local eventtap     = require("hs.eventtap")
local image        = require("hs.image")

local log = require("hs.logger").new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "warning")

-- private variables and methods -----------------------------------------

local legacyMT = {}
-- we're not using weak keys since an explicit delete was part of the legacy module
local internalData = {}

local parseMenuTable
parseMenuTable = function(self, menuTable, targetMenu)
    local obj = internalData[self]
    if menuTable then
        for i, v in ipairs(menuTable) do
            repeat -- stupid missing continue hack
                if type(v) ~= "table" then
                    log.wf("entry %d is not a menu item table", i)
                    break
                end
                local s, item = pcall(uitk.menu.item.new, v.title)
                if not s then
                    log.wf("malformed menu table entry; missing or invalid title string for entry %d (%s)", i, item)
                    break
                end
                targetMenu:insert(item)
                if v.title == "-" then break end -- separator; nothing else matters
                if type(v.menu) ~= "nil" then
                    if type(v.menu) == "table" then
                        local newMenu = uitk.menu.new("HammerspoonSubMenu")
                        parseMenuTable(self, v.menu, newMenu)
                        item:submenu(newMenu)
                    else
                        log.f("expected table for menu key of entry %d", i)
                    end
                end
                if type(v.fn) ~= "nil" then
                    if type(v.fn) == "function" or (type(v.fn) == "table" and (getmetatable(v.fn) or {}).__call) then
                        item:callback(function(itemObj)
                            v.fn(eventtap.checkKeyboardModifiers())
                        end)
                    else
                        log.f("expected table for fn key of entry %d", i)
                    end
                end
                if type(v.disabled) ~= "nil" then
                    if type(v.disabled) == "boolean" then
                        item:enabled(not v.disabled)
                    else
                        log.f("expected boolean for disabled key of entry %d", i)
                    end
                end
                if type(v.checked) ~= "nil" then
                    if type(v.checked) == "boolean" then
                        item:state(v.checked and "on" or "off")
                    else
                        log.f("expected boolean for checked key of entry %d", i)
                    end
                end
                if type(v.state) ~= "nil" then
                    if type(v.state) == "string" then
                        if v.state == "on" or v.state == "off" or v.state == "mixed" then
                            item:state(v.state)
                        else
                            log.f("expected one of on, off, or mixed for state key of entry %d", i)
                        end
                    else
                        log.f("expected string for state key of entry %d", i)
                    end
                end
                if type(v.tooltip) ~= "nil" then
                    if type(v.tooltip) == "string" then
                        item:tooltip(v.tooltip)
                    else
                        log.f("expected string for tooltip key of entry %d", i)
                    end
                end

                if type(v.indent) ~= "nil" then
                    if math.type(v.indent) == "integer" then
                        item:indentationLevel(v.indent)
                    else
                        log.f("expected integer for indent key of entry %d", i)
                    end
                end

                if type(v.image) ~= "nil" then
                    if type(v.image) == "userdata" and getmetatable(v.image).__name == "hs.image" then
                        item:image(v.image)
                    else
                        log.f("expected hs.image object for image key of entry %d", i)
                    end
                end

                if type(v.onStateImage) ~= "nil" then
                    if type(v.onStateImage) == "userdata" and getmetatable(v.onStateImage).__name == "hs.image" then
                        item:onStateImage(v.onStateImage:size(obj._stateImageSize))
                    else
                        log.f("expected hs.image object for onStateImage key of entry %d", i)
                    end
                end

                if type(v.offStateImage) ~= "nil" then
                    if type(v.offStateImage) == "userdata" and getmetatable(v.offStateImage).__name == "hs.image" then
                        item:offStateImage(v.offStateImage:size(obj._stateImageSize))
                    else
                        log.f("expected hs.image object for offStateImage key of entry %d", i)
                    end
                end

                if type(v.mixedStateImage) ~= "nil" then
                    if type(v.mixedStateImage) == "userdata" and getmetatable(v.mixedStateImage).__name == "hs.image" then
                        item:mixedStateImage(v.mixedStateImage:size(obj._stateImageSize))
                    else
                        log.f("expected hs.image object for mixedStateImage key of entry %d", i)
                    end
                end

                if type(v.shortcut) ~= "nil" then
                    if type(v.shortcut) == "string" then
                        item:keyEquivalent(v.shortcut)
                    else
                        log.f("expected string for shortcut key of entry %d", i)
                    end
                end

            until true
        end
    end
end

local updateMenu = function(self)
    local obj = internalData[self]
    if obj._menuCallback then
        obj._menu:removeAll()
        parseMenuTable(self, obj._menuCallback(eventtap.checkKeyboardModifiers()), obj._menu)
    end
end

local menubarClick = function(self)
    local obj = internalData[self]
    if not obj._menubar:menu() and obj._clickCallback then
        obj._clickCallback(eventtap.checkKeyboardModifiers())
    end
end

-- Public interface ------------------------------------------------------

legacyMT.__index = legacyMT
legacyMT.__name  = USERDATA_TAG
legacyMT.__type  = USERDATA_TAG

legacyMT.__tostring = function(self, ...)
    local obj = internalData[self]
    return USERDATA_TAG .. ": " .. (obj._title or "") .. " " .. tostring(obj._menu):match("%(0x.*%)$")
end

legacyMT.setMenu = function(self, ...)
    local obj, args = internalData[self], table.pack(...)

    if args.n == 1 then
        local theMenu = args[1]
        if type(theMenu) == "function" or (type(theMenu) == "table" and (getmetatable(theMenu) or {}).__call) then
            obj._menuCallback = theMenu
            if obj._menubar then
                obj._menubar:menu(obj._menu)
            end
            return self
        elseif type(theMenu) == "table" then
            obj._menu:removeAll()
            parseMenuTable(self, theMenu, obj._menu)
            obj._menuCallback = false
            if obj._menubar then
                obj._menubar:menu(obj._menu)
            end
            return self
        elseif type(theMenu) == "nil" then
            obj._menuCallback = nil
            if obj._menubar then
                obj._menubar:menu(nil)
            end
            return self
        end
    end
    error("expected callback function, menu table, or explicit nil", 2)
end

legacyMT.setClickCallback = function(self, ...)
    local obj, args = internalData[self], table.pack(...)

    if args.n == 1 then
        local callback = args[1]
        if type(callback) == "function" or
           type(callback) == "nil" or
           (type(callback) == "table" and (getmetatable(callback) or {}).__call) then
                obj._menubar:callback(callback)
                return self
        end
    end
    error("expected function or explicit nil", 2)
end

legacyMT.popupMenu = function(self, loc, ...)
    local obj, args = internalData[self], table.pack(...)

    -- they may have specified nil, so we can't do the `expr and val or val2` shorthand
    local dark = false -- legacy version didn't support dark mode popups, so that's the default
    if args.n > 0 then dark = args[1] end

    if type(obj._menuCallback) ~= "nil" then
        obj._menu:popupMenu(loc, dark)
    else
        menubarClick(self)
    end
    return self
end

legacyMT.stateImageSize = function(self, ...)
    local obj, args = internalData[self], table.pack(...)

    if args.n == 0 then
        return obj._stateImageSize
    elseif args.n == 1 and type(args[1]) == "table" and type(args[1].h) == "number" and type(args[1].w) == "number" then
        obj._stateImageSize = args[1]
        return self
    else
        error("expected optional size table", 2)
    end
end

legacyMT.setTooltip = function(self, tooltip)
    local obj = internalData[self]
    if obj._menubar then obj._menubar:tooltip(tooltip) end
    obj._tooltip = tooltip or ""
    return self
end

legacyMT.setIcon = function(self, icon, template)
    local obj = internalData[self]

    if type(icon) == "string" then
        if string.sub(icon, 1, 6) == "ASCII:" then
            icon = image.imageFromASCII(string.sub(icon, 7, -1))
        else
            icon = image.imageFromPath(icon)
        end
    end
    if icon then
        if type(template) == "boolean" then
            icon:template(template)
        else
            icon:template(true)
        end
    end

    if obj._menubar then obj._menubar:image(icon) end
    obj._icon = icon
    return self
end

legacyMT.icon = function(self)
    local obj = internalData[self]
    return obj._icon
end

legacyMT.setTitle = function(self, title)
    local obj = internalData[self]
        if obj._menubar then obj._menubar:title(title) end
    obj._title = title or ""
    return self
end

legacyMT.title = function(self)
    local obj = internalData[self]
    return obj._title or ""
end

legacyMT.frame = function(self)
    local obj = internalData[self]
    if obj._menubar then
        return obj._menubar:frame()
    else
        return obj._frame
    end
end

legacyMT.isInMenubar = function(self)
    local obj = internalData[self]
    return obj._menubar and true or false
end

local imagePositionLookup = {
    [0] = "none",
    [1] = "only",
    [2] = "left",
    [3] = "right",
    [4] = "below",
    [5] = "above",
    [6] = "overlaps",
    [7] = "leading",
    [8] = "trailing",
}

legacyMT.imagePosition = function(self, ...)
    local obj = internalData[self]
    local args = table.pack(...)

    if args.n == 0 then
        local pos = obj._menubar:imagePosition()
        for k, v in pairs(imagePositionLookup) do
            if pos == v then return k end
        end
        return -1
    else
        local pos = args[1]
        if type(pos) ~= "string" then pos = imagePositionLookup[pos] end
        obj._menubar:imagePosition(pos)
        return self
    end
end

legacyMT.returnToMenuBar = function(self)
    local obj = internalData[self]
    if not obj._menubar then
        obj._menubar = uitk.statusbar(true):title(obj._title)
                                           :tooltip(obj._tooltip)
                                           :menu(obj._menu)

        if obj._icon then obj._menubar:image(obj._icon) end
        if obj._autosavename then obj._menubar(obj._autosavename) end

        obj._frame = nil
    end
    return self
end

legacyMT.removeFromMenuBar = function(self)
    local obj = internalData[self]
    if obj._menubar then
        obj._title        = obj._menubar:title()
        obj._icon         = obj._menubar:image()
        obj._tooltip      = obj._menubar:tooltip()
        obj._frame        = obj._menubar:frame()
        obj._autosavename = obj._menubar:autosaveName()
        obj._menubar:remove()
        obj._menubar      = nil
    end
    return self
end

legacyMT.delete = function(self)
    local obj = internalData[self]
    if obj._menubar then obj._menubar:remove() end
    obj._menubar       = nil
    obj._menu          = nil
    obj._clickCallback = nil
    internalData[self] = nil
end

legacyMT.autosaveName = function(self, ...)
    local obj = internalData[self]
    if obj._menubar then
        local response = obj._menubar:autosaveName(...)
        return (response == obj._menubar) and self or response
    end
    return self
end

legacyMT._frame   = legacyMT.frame
legacyMT._setIcon = legacyMT.setIcon
legacyMT.__gc     = legacyMT.delete

module.new = function(inMenuBar, autosavename)
    inMenuBar = type(inMenuBar) == "nil" and true or inMenuBar
    assert(type(autosavename) == "nil" or type(autosavename) == "string", "if autosavename is specified, it must be a string")

    local newMenu = {}
    internalData[newMenu] = {
        _menubar    = uitk.statusbar(true):callback(function(_, msg, ...)
            if msg == "mouseClick" then menubarClick(newMenu) end
        end),
        _menu          = uitk.menu.new("HammerspoonPlaceholderMenu"):callback(function(_, msg, ...)
            if msg == "update" then updateMenu(newMenu) end
        end),
        _menuCallback   = nil,
        _clickCallback  = nil,
        _stateImageSize = { h = styledtext.defaultFonts.menu.size, w = styledtext.defaultFonts.menu.size }
    }
    newMenu = setmetatable(newMenu, legacyMT)
    if autosavename then newMenu:autosaveName(autosavename) end

    -- mimics approach used in original module; frame will match the legacy behavior as well
    if not inMenuBar then newMenu:removeFromMenuBar() end

    return newMenu
end

-- assign to the registry in case we ever need to access the metatable from the C side
debug.getregistry()[USERDATA_TAG] = legacyMT

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
    _internalData = internalData,
})

