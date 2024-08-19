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

--- hs._asm.uitk.panel.alert:showsHelp([state]) -> panelObject | boolean
--- Method
--- Get or set whether or not the alert shows a button to request help concerning the alert.
---
--- Parameters:
---  * `state` - an optional boolean, default false, specifying whether or not the help button is displayed.
---
--- Returns:
---  * if an argument is provided, returns the panel object; otherwise returns the current value.
---
--- Notes:
---  * when the Help button is clicked on by the user, the callback function, if defined with [hs._asm.uitk.panel.alert:callback](#callback), will be invoked with the arguments `object, "help"`. The alert will *not* be closed, so you should close it in the callback function with `object:window():hide()` if this is desired.
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

--- hs._asm.uitk.panel.alert:showsSuppressionButton([state]) -> panelObject | boolean
--- Method
--- Get or set whether or not the alert shows a checkbox with the label "Don't ask again" at the bottom of the alert.
---
--- Parameters:
---  * `state` - an optional boolean, default false, specifying whether or not the suppression checkbox should be displayed at the bottom of the alert panel.
---
--- Returns:
---  * if an argument is provided, returns the panel object; otherwise returns the current value.
---
--- Notes:
---  * The suppression checkbox by itself does not ensure that the dialog is or is not shown in the future; see [hs._asm.uitk.panel.alert:suppressionButton](#suppressionButton) for more information.
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

--- hs._asm.uitk.panel.alert:informativeText([text]) -> panelObject | string
--- Method
--- Get or set the informative text displayed in the alert panel.
---
--- Parameters:
---  * `text` - an optional string, default the empty string "", specifying the informative text to display in the alert panel
---
--- Returns:
---  * if an argument is provided, returns the panel object; otherwise returns the current value.
---
--- Notes:
---  * The informative text is expected to contain a more detailed description than [hs._asm.uitk.panel.alert:messageText](#messageText) and can be multiple lines, wrapping on word boundaries within the alert panel if necessary.
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

--- hs._asm.uitk.panel.alert:messageText([text]) -> panelObject | string
--- Method
--- Get or set the message text displayed in the alert panel.
---
--- Parameters:
---  * `text` - an optional string, default "Alert", specifying the message text to display in the alert panel
---
--- Returns:
---  * if an argument is provided, returns the panel object; otherwise returns the current value.
---
--- Notes:
---  * The message text is expected to be short, a few words at most; a more descriptive message can be added with the [hs._asm.uitk.panel.alert:informativeText](#informativeText) method.
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

--- hs._asm.uitk.panel.alert:icon([image]) -> panelObject | hs.image object
--- Method
--- Get or set the icon displayed in the alert panel
---
--- Parameters:
---  * `image` - an optional hs.image object, or explicit nil to revert to the default Hammerspoon icon, specifying the icon to display in the alert panel.
---
--- Returns:
---  * if an argument is provided, returns the panel object; otherwise returns the current value.
---
--- Notes:
---  * the default icon is the Hammerspoon application icon.
---  * if [hs._asm.uitk.panel.alert:alertStyle](#alertStyle) is set to "critical", the icon set by this method will be displayed in the lower left corner of the macOS caution system image (`hs.image.imageFromName(hs.image.systemImageNames.Caution)`).
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

--- hs._asm.uitk.panel.alert:accessory([element | nil]) -> panelObject | element | nil
--- Method
--- Get or set the accessory element displayed in the alert panel
---
--- Parameters:
---  * `element` - an optional `hs._asm.uitk.element` object, or explicit nil to remove, displayed in the alert panel.
---
--- Returns:
---  * if an argument is provided, returns the panel object; otherwise returns the current value.
---
--- Notes:
---  * the default is `nil`, specifying that no accessory is added to the panel.
---
---  * if an accessory is specified, it will appear between the [hs._asm.uitk.panel.alert:informativeText](#informativeText) and the buttons of the alert panel.
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

--- hs._asm.uitk.panel.alert:alertStyle([style]) -> panelObject | string
--- Method
--- Get or set the alert style.
---
--- Parameters:
---  * `style` - an optional string, default "warning", specifying the style of the alert.
---
--- Returns:
---  * if an argument is provided, returns the panel object; otherwise returns the current value.
---
--- Notes:
---  * the accepted values for this method are "warning", "informational", and "critical"
---  * "informational" is included for historical reasons, but currently does not differ in any way from the "warning" style.
---  * "critical" style will cause the alert icon ([hs._asm.uitk.panel.alert:icon](#icon)) image to be displayed in the lower left corner of the macOS caution system image (`hs.image.imageFromName(hs.image.systemImageNames.Caution)`).
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

--- hs._asm.uitk.panel.alert:callback([fn | nil]) -> panelObject | function | nil
--- Method
--- Get or set the callback function for the alert panel.
---
--- Parameters:
---  * `fn` - an optional function, or explicit nil to remove, which will be called when the user clicks on one of the alert panels buttons.
---
--- Returns:
---  * if an argument is provided, returns the panel object; otherwise returns the current value.
---
--- Notes:
---  * the callback function should expect two arguments and return none. The arguments will be the alert object and a string containing the title of the button pressed.
---  * if any button but the help button -- see [hs._asm.uitk.panel.alert:showsHelp](#showsHelp) -- is pressed, the alert will be closed before the callback is invoked.
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

--- hs._asm.uitk.panel.alert:buttons() -> table
--- Method
--- Returns an array of the buttons defined for the alert panel.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table containing zero or more `hs._asm.uitk.element.button` objects corresponding to the buttons defined for this alert.
---
--- Notes:
---  * if no buttons are created with the [hs._asm.uitk.panel.alert:addButtonWithTitle](#addButtonWithTitle) method, one will be automatically created with the title of "OK" and added to this table when the [hs._asm.uitk.panel.alert:layout](#layout) or [hs._asm.uitk.panel.alert:run](#run) methods are invoked.
---
--- * the first button added to an alert panel is always assumed to be the default choice and will be given a key equivalent of the Return key (i.e. if the user taps the Return key, this button is acted upon as if the user had clicked on it.
--- * If any subsequent button is titled "Cancel", it will be assigned the key equivalent of the Escape (ESC) key.
--- * If any subsequent button is titled "Don't Save", it will be assigned the key equivalent of Cmd-D (⌘D).
--- * You can change or remove the key equivalent of any button by use the `hs._asm.uitk.element.button:keyEquivalent` and `hs._asm.uitk.element.button:keyModifierMask` on members of the table returned by this method.
---
--- * if you wish to trigger a button based upon actions taken elsewhere, for example from an action taken within the accessory element, you can use this method to get the list of buttons and use the `hs._asm.uitk.element.button:press` method on the appropriate button.
moduleMT.buttons = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    assert(
        args.n == 0,
        string.format("incorrect number of arguments (expected 0, got %d", args.n)
    )
    return ls.makeConstantsTable(obj.buttons)
end

--- hs._asm.uitk.panel.alert:suppressionButton() -> buttonElement
--- Method
--- Returns an `hs._asm.uitk.element.button` object representing the suppression button for the alert panel.
---
--- Parameters:
---  * None
---
--- Returns:
---  * an `hs._asm.uitk.element.button` object representing the suppression button for the alert panel.
---
--- Notes:
---  * the button will only be visible in the alert if the [hs._asm.uitk.panel.alert:showsSuppressionButton](#showsSuppressionButton) method is set to true.
---
---  * you can use this method to obtain the suppression button checkbox to change it's label with the `hs._asm.uitk.element.button:title` method or to check if the user has checked it in your callback with the `hs._asm.uitk.element.button:state` method.
---
---  * The suppression button is provided as a convenience and is not enforced by this module. If you wish to honor it's setting, you must include code of your own to check this value and store it, possibly with `hs.settings`, so that it can be checked in the future before showing triggering the alert again with your code.
moduleMT.suppressionButton = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    assert(
        args.n == 0,
        string.format("incorrect number of arguments (expected 0, got %d", args.n)
    )
    return obj.suppressionButton
end

--- hs._asm.uitk.panel.alert:window() -> windowElement
--- Method
--- Returns an `hs._asm.uitk.window` object representing the alert panel.
---
--- Parameters:
---  * None
---
--- Returns:
---  * an `hs._asm.uitk.window` object representing the alert panel.
---
--- Notes:
---  * The position and size of this window is determined when the [hs._asm.uitk.panel.alert:layout](#layout) or [hs._asm.uitk.panel.alert:run](#run) methods are invoked. Any change to these properties will be overwritten when these methods are invoked, so if you wish to reposition the alert, do so after it has been presented.
moduleMT.window = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    assert(
        args.n == 0,
        string.format("incorrect number of arguments (expected 0, got %d", args.n)
    )
    return obj.window
end

--- hs._asm.uitk.panel.alert:addButtonWithTitle(title) -> panelObject
--- Method
--- Add a button to the alert panel with the specified label.
---
--- Parameters:
---  * `title` - the label to be displayed on the button added to the alert panel.
---
--- Returns:
---  * the panel object.
---
--- Notes:
---  * if no buttons are created with this method, one will be automatically created with the title of "OK" and added to this table when the [hs._asm.uitk.panel.alert:layout](#layout) or [hs._asm.uitk.panel.alert:run](#run) methods are invoked.
---
--- * the first button added to an alert panel is always assumed to be the default choice and will be given a key equivalent of the Return key (i.e. if the user taps the Return key, this button is acted upon as if the user had clicked on it.
--- * If any subsequent button is titled "Cancel", it will be assigned the key equivalent of the Escape (ESC) key.
--- * If any subsequent button is titled "Don't Save", it will be assigned the key equivalent of Cmd-D (⌘D).
--- * See also [hs._asm.uitk.panel.alert:buttons](#buttons).
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

--- hs._asm.uitk.panel.alert:layout() -> windowElement
--- Method
--- Position the alert elements and adjust the size and position of the alert panel.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the alert object
---
--- Notes:
---  * This method will position the elements within the alert panel, based upon its properties as specified by the other methods. It is invoked automatically by the [hs._asm.uitk.panel.alert:run](#run) method, but its included as its own method in case you make changes to the alert once it has been presented (perhaps based on actions taken by elements in the accessory element).
---
---  * this method will adjust the size and position of the alert so that it is about a third of the way down from the top of the currently active screen and sized appropriately for the buttons and properties specified by this module's methods. If you wish to position the alert in a different location, you can set the position using the [hs._asm.uitk.panel.alert:window](#window) object *after* invoking this method.
---
---  * if no buttons have been defined for this alert panel, a default one with the title of "OK" will be created and inserted into the [hs._asm.uitk.panel.alert:buttons](#buttons) array.
---  * If only two buttons are defined and the[hs._asm.uitk.panel.alert:showsSuppressionButton](#showsSuppressionButton) is false, they will be displayed side by side with the first (default) button on the right. In all other cases, the buttons will be stacked, starting with the first (default) one at the top.
moduleMT.layout = function(self, ...)
    local obj   = moduleMT.__e[self]
    local args  = table.pack(...)
    assert(
        args.n == 0,
        string.format("incorrect number of arguments (expected 0, got %d", args.n)
    )

    if #obj.buttons == 0 then
        self:addButtonWithTitle("OK")
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

--- hs._asm.uitk.panel.alert:run() -> windowElement
--- Method
--- Position and display the alert panel
---
--- Parameters:
---  * None
---
--- Returns:
---  * the alert object
---
--- Notes:
---  * This method invokes [hs._asm.uitk.element.panel.alert:layout](#layout) to position and size the alert panel before showing it.
---
---  * this method will adjust the size and position of the alert so that it is about a third of the way down from the top of the currently active screen and sized appropriately for the buttons and properties specified by this module's methods. If you wish to position the alert in a different location, you can set the position using the [hs._asm.uitk.panel.alert:window](#window) object *after* invoking this method.
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
