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

--- === hs._asm.uitk.panel.alert ===
---
--- This module provides an alert like dialog that can be used to provide information or warnings. You can use the `accessory` method wo attach other elements to extend the dialog. A common example would be to use an `hs._asm.uitk.element.textField` for simple text input.
---
--- Because the macOS default alert is blocking (i.e. most background Hammerspoon activity is paused while it is being displayed), this module is actually a lua based replica of the NSAlert class as it is presented in macOS 14.5. It's likely not an exact match, but should still convey the expected look and feel users expect from alert dialogs.

local USERDATA_TAG = "hs._asm.uitk.panel.alert"
local uitk         = require("hs._asm.uitk")
local module       = {}

local image    = require("hs.image")
local screen   = require("hs.screen")
local event    = require("hs.eventtap").event

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- currently there is no difference between warning and informational, but in case we decide to mimic other macOS
-- version styles for NSAlert, it may come up.
local ALERT_STYLES = {
    warning       = 0,
    informational = 1,
    critical      = 2,
}
local ALERT_STYLES_KEYS = {}
for k, _ in pairs(ALERT_STYLES) do table.insert(ALERT_STYLES_KEYS, k) end

-- most obvious critical difference is icon is hs.image.imageFromName("NSCaution") with alert icon overlaying it in
-- the lower right corner

local defaultIcon  = image.imageFromName(image.systemImageNames.ApplicationIcon)
local criticalIcon = image.imageFromName(image.systemImageNames.Caution)

local defaultHeight = 368
local defaultWidth  = 260
local inset         = 16
local padding       = 16

local actionCallback = function(object, message, close)
    return function(...)
        local callback = object:callback()
        if close    then object:window():hide() end
        if callback then callback(object, message) end
    end
end

local moduleMT = { __e = setmetatable({}, { __mode = "k" }) }

moduleMT.__index = moduleMT
moduleMT.__name  = USERDATA_TAG
moduleMT.__type  = USERDATA_TAG

moduleMT.showsHelp = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    if args.n == 0 then
        return obj.showsHelp
    else
        assert(
            type(args[1]) == "boolean",
            string.format("incorrect type %s for argument 1 (expected boolean)", type(args[1]))
        )
        assert(
            args.n == 1,
            string.format("incorrect number of arguments (expected 1, got %d", args.n)
        )
        obj.showsHelp = args[1]
        return self
    end
end

moduleMT.showsSuppressionButton = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    if args.n == 0 then
        return obj.showsSuppressionButton
    else
        assert(
            type(args[1]) == "boolean",
            string.format("incorrect type %s for argument 1 (expected boolean)", type(args[1]))
        )
        assert(
            args.n == 1,
            string.format("incorrect number of arguments (expected 1, got %d", args.n)
        )
        obj.showsSuppressionButton = args[1]
        return self
    end
end

moduleMT.informativeText = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    if args.n == 0 then
        return obj.informativeText
    else
        assert(
            type(args[1]) == "string",
            string.format("incorrect type %s for argument 1 (expected string)", type(args[1]))
        )
        assert(
            args.n == 1,
            string.format("incorrect number of arguments (expected 1, got %d", args.n)
        )
        obj.informativeText = args[1]
        return self
    end
end

moduleMT.messageText = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    if args.n == 0 then
        return obj.messageText
    else
        assert(
            type(args[1]) == "string",
            string.format("incorrect type %s for argument 1 (expected string)", type(args[1]))
        )
        assert(
            args.n == 1,
            string.format("incorrect number of arguments (expected 1, got %d", args.n)
        )
        obj.messageText = args[1]
        return self
    end
end

moduleMT.icon = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    if args.n == 0 then
        return obj.icon
    else
        assert(
            type(args[1]) == "nil" or getmetatable(args[1]) == hs.getObjectMetatable("hs.image"),
            string.format("incorrect type %s for argument 1 (expected hs.image userdata or nil)", type(args[1]))
        )
        assert(
            args.n == 1,
            string.format("incorrect number of arguments (expected 1, got %d", args.n)
        )
        if args[1] then
            obj.icon = args[1]
        else
            obj.icon = defaultIcon
        end
        return self
    end
end

moduleMT.accessory = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    if args.n == 0 then
        return obj.accessory
    else
        assert(
            type(args[1]) == "nil" or uitk.element.isElementType(args[1]),
            string.format("incorrect type %s for argument 1 (expected userdata representing a uitk element or nil)", type(args[1]))
        )
        assert(
            args.n == 1,
            string.format("incorrect number of arguments (expected 1, got %d", args.n)
        )
        obj.accessory = args[1]
        return self
    end
end

moduleMT.alertStyle = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    if args.n == 0 then
        local msg = string.format("*** %d", obj.alertStyle)
        for k, v in pairs(ALERT_STYLES) do
            if obj.alertStyle == v then
                msg = k
                break
            end
        end
        return msg
    else
        assert(
            type(args[1]) == "string",
            string.format("incorrect type %s for argument 1 (expected string)", type(args[1]))
        )
        assert(
            args.n == 1,
            string.format("incorrect number of arguments (expected 1, got %d", args.n)
        )
        local val = ALERT_STYLES[args[1]]
        assert(
            val,
            string.format("expected one of %s", table.concat(ALERT_STYLES_KEYS, ", "))
        )
        obj.alertStyle = val
        return self
    end
end

moduleMT.callback = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    if args.n == 0 then
        return obj.callback
    else
        assert(
            type (args[1]) == "nil" or type(args[1]) == "function" or (getmetatable(args[1]) or {}).__call,
            string.format("incorrect type %s for argument 1 (expected function or nil)", type(args[1]))
        )
        assert(
            args.n == 1,
            string.format("incorrect number of arguments (expected 1, got %d", args.n)
        )
        obj.callback = args[1]
        return self
    end
end

moduleMT.buttons = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    assert(
        args.n == 0,
        string.format("incorrect number of arguments (expected 0, got %d", args.n)
    )
    return ls.makeConstantsTable(obj.buttons)
end

moduleMT.suppressionButton = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    assert(
        args.n == 0,
        string.format("incorrect number of arguments (expected 0, got %d", args.n)
    )
    return obj.suppressionButton
end

moduleMT.window = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    assert(
        args.n == 0,
        string.format("incorrect number of arguments (expected 0, got %d", args.n)
    )
    return obj.window
end

moduleMT.addButtonWithTitle = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    assert(
        type(args[1]) == "string",
        string.format("incorrect type %s for argument 1 (expected string)", type(args[1]))
    )
    assert(
        args.n == 1,
        string.format("incorrect number of arguments (expected 1, got %d", args.n)
    )

    local title = args[1]
    local newButton = uitk.element.button.buttonWithTitle(title):bezelStyle("regularSquare")
                                                                :callback(actionCallback(self, title, true))
    if #obj.buttons == 0 then
        newButton:keyEquivalent(string.char(13)):keyModifierMask(0)
    elseif title == "Cancel" then
        newButton:keyEquivalent(string.char(27)):keyModifierMask(0)
    elseif title == "Don’t Save" then
        newButton:keyEquivalent("D"):keyModifierMask(event.rawFlagMasks.command)
    end

    table.insert(obj.buttons, newButton)

    return self
end

moduleMT.layout = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    assert(
        args.n == 0,
        string.format("incorrect number of arguments (expected 0, got %d", args.n)
    )

    if #obj.buttons == 0 then
        table.insert(obj.buttons, uitk.element.button.buttonWithTitle("OK"):bezelStyle("regularSquare")
                                                                           :callback(actionCallback(self, "OK", true)))
    end

    -- start with a clean slate
    local container = uitk.element.container()
    while #obj.window:content() > 0 do obj.window:content():remove() end

    -- From top to bottom (centered, except for help):
    --       icon     help
    --    messageText
    --  informativeText
    --     accessory
    --     button(s)
    -- suppressionButton

    local stackButtons = (#obj.buttons ~= 2)
    local width = defaultWidth - 2 * inset

    if obj.accessory then
        local testWidth = obj.accessory:fittingSize().w
        if testWidth > width then width = testWidth end
    end

    for _, btn in ipairs(obj.buttons) do
        local testWidth = btn:fittingSize().w
        if testWidth > width then width = testWidth end
    end

    local iconElement = uitk.element.image.new()
    iconElement._properties.image        = (obj.alertStyle == ALERT_STYLES.critical) and criticalIcon or obj.icon
    iconElement._properties.imageScaling = "proportionallyUpOrDown"
    local iconOverlayElement = (obj.alertStyle == ALERT_STYLES.critical) and uitk.element.image.new() or nil
    if iconOverlayElement then
        iconOverlayElement._properties.image        = obj.icon
        iconOverlayElement._properties.imageScaling = "proportionallyUpOrDown"
    end

    local messageElement = uitk.element.textField.newLabel(obj.messageText)
    messageElement._properties.font          = { name = ".AppleSystemUIFontBold", size = 13 }
    messageElement._properties.textAlignment = "center"

    if messageElement:fittingSize().w > width then width = messageElement:fittingSize().w end

    local informativeElement = uitk.element.textField.newLabel(obj.informativeText)
    informativeElement._properties.font          = { name = ".AppleSystemUIFont", size = 11 }
    informativeElement._properties.lineBreakMode = "wordWrap"
    informativeElement._properties.maxWidth      = width
    informativeElement._properties.textAlignment = "center"

    if obj.showsHelp then
        container[#container + 1] = {
            id             = "help",
            _self          = uitk.element.button.buttonWithTitle(""):bezelStyle("helpButton")
                                                                    :callback(actionCallback(self, "help")),
            containerFrame = { rX = width, y  = 0, },
        }
    end

    container[#container + 1] = {
        id             = "icon",
        _self          = iconElement,
        containerFrame = {
            cX = width / 2,
            y  = 0,
            h  = 64,
            w  = 64,
        },
    }

    if iconOverlayElement then
        container[#container + 1] = {
            id             = "iconOverlay",
            _self          = iconOverlayElement,
            containerFrame = {
                cX = width / 2 + 16,
                y  = 32,
                h  = 32,
                w  = 32,
            },
        }
    end

    container[#container + 1] = {
        id             = "messageText",
        _self          = messageElement,
    }
    messageElement:position("below", iconElement, padding, "center")

    container[#container + 1] = {
        id             = "informativeText",
        _self          = informativeElement,
    }
    informativeElement:position("below", messageElement, padding, "center")

    if obj.accessory then
        container[#container + 1] = {
            id             = "accessory",
            _self          = obj.accessory,
            containerFrame = { w = width },
        }
        obj.accessory:position("below", informativeElement, padding, "center")
    end

    local previousElement = obj.accessory or informativeElement
    local nextPadding = padding

    if #obj.buttons == 2 and not obj.showsSuppressionButton then
        local btnRow = uitk.element.container.new()
        btnRow[1] = {
            id             = "button_1",
            _self          = obj.buttons[2],
            containerFrame = { w = width / 2, h = 36 },
        }
        btnRow[2] = {
            id             = "button_2",
            _self          = obj.buttons[1],
            containerFrame = { w = width / 2, h = 36 },
        }
        obj.buttons[1]:position("after", obj.buttons[2], 0, "center")
        container[#container + 1] = {
            id             = "twoButtons",
            _self          = btnRow,
            containerFrame = { w = width, h = 36 },
        }
        btnRow:position("below", previousElement, nextPadding, "center")
        previousElement = btnRow
    else
        for i, btn in ipairs(obj.buttons) do
            container[#container + 1] = {
                id             = "button_" .. tostring(i),
                _self          = btn,
                containerFrame = { w = width, h = 36 },
            }
            btn:position("below", previousElement, nextPadding, "center")
            nextPadding     = 0
            previousElement = btn
        end
    end

    if obj.showsSuppressionButton then
        container[#container + 1] = {
            id             = "suppressionButton",
            _self          = obj.suppressionButton,
            containerFrame = { cX = width / 2 },
        }
        obj.suppressionButton:position("below", previousElement, padding / 2, "center")
        previousElement = obj.suppressionButton
    end

    local screenFrame = screen.mainScreen():fullFrame()
    local newWinFrame = container:fittingSize()
    newWinFrame.h     = newWinFrame.h + inset * 2
    newWinFrame.w     = newWinFrame.w + inset * 2
    newWinFrame.x     = screenFrame.x + (screenFrame.w - newWinFrame.w) / 2
    newWinFrame.y     = screenFrame.y + screenFrame.h / 3 - newWinFrame.w / 2

    obj.window:frame(newWinFrame):show()

    obj.window:content()[1] = {
        id             = "content",
        _self          = container,
        containerFrame = { x = inset, y = inset, }
    }

    -- if it's nil, then the alert window itself becomes the active element
    obj.window:activeElement(obj.accessory)

    return self
end

moduleMT.run = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    assert(
        args.n == 0,
        string.format("incorrect number of arguments (expected 0, got %d", args.n)
    )

    self:layout()
    obj.window:show()

    return self
end

moduleMT.__tostring = function(self)
    local obj   = moduleMT.__e[self]
    local title = obj.messageText:sub(1,10) .. (#obj.messageText > 10 and "..." or "")
    local ptr   = tostring(obj):match(": (.+)$")
    return string.format("%s: %s (%s)", USERDATA_TAG, title, ptr)
end

-- moduleMT.__gc

moduleMT._propertyList = {
    "showsHelp",
    "showsSuppressionButton",
    "informativeText",
    "messageText",
    "icon",
    "accessory",
    "alertStyle",
    "callback",
}

local windowStyleMask = uitk.window.masks.titled | uitk.window.masks.fullSizeContentView | uitk.window.masks.nonactivating

-- Public interface ------------------------------------------------------

module.new = function()
    local newAlert = {}

    local screenFrame = screen.mainScreen():fullFrame()

    moduleMT.__e[newAlert] = {
        showsHelp              = false,
        showsSuppressionButton = false,
        alertStyle             = ALERT_STYLES.warning,
        informativeText        = "",                    -- "System Font Regular", size = 11 (".SFNS-Regular")
        messageText            = "Alert",               -- "System Font Bold", size = 13 (".SFNS-Bold")
        icon                   = defaultIcon,
        accessory              = nil,

        -- readonly
        buttons                = {},
        suppressionButton      = uitk.element.button.checkbox("Don't ask again"):callback(function(...) end),
        window                 = uitk.window.new({
                                    x = screenFrame.x + (screenFrame.w - defaultWidth) / 2,
                                    y = screenFrame.y + screenFrame.h / 3 - defaultHeight / 2,
                                    h = defaultHeight,
                                    w = defaultWidth,
                                }, windowStyleMask)
                                :titlebarAppearsTransparent(true)
                                :level(uitk.window.levels.modalPanel),

        -- unique to us
        callback               = nil,
    }

    return setmetatable(newAlert, moduleMT)
end

-- Return Module Object --------------------------------------------------

uitk.util._properties.addPropertiesWrapper(moduleMT)

return setmetatable(module, {
    __call = function(self, ...) return self.new(...) end,
})
