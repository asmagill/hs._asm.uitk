local module = {}

local uitk = require("hs._asm.uitk")

local finspect = function(...) return (require("hs.inspect")({...}):gsub("%s+", " ")) end

local pickCallback = function(...)
    print("You chose: " .. finspect(uitk.panel.color.color()))
    uitk.panel.color.accessory(nil)
    uitk.panel.color.hide()
end

local cancelCallback = function(...)
    print("Cancelled")
    uitk.panel.color.accessory(nil)
    uitk.panel.color.hide()
end

-- 220 seems to be the maximum width, but the height can be larger
local accessoryView = uitk.element.container{ w = 220, h = 30 }
local button = uitk.element.button.buttonType("momentaryPushIn"):title("Pick")
                                                                :bezelStyle("rounded")
                                                                :callback(pickCallback)

local cancelButton = uitk.element.button.buttonType("momentaryPushIn"):title("Cancel")
                                                                      :bezelStyle("rounded")
                                                                      :callback(cancelCallback)
accessoryView[1] = button
accessoryView[2] = { _element = cancelButton, containerFrame = { rX = "100%", y = 0 } }

module.show = function()
    uitk.panel.color.accessory(accessoryView)
    uitk.panel.color.show()
    return module
end

module.hide = function()
    uitk.panel.color.accessory(nil)
    uitk.panel.color.hide()
    return module
end

return module:show()
