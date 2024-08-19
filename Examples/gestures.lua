local uitk  = require("hs._asm.uitk")
local image = require("hs.image")
local stext = require("hs.styledtext")

local finspect = function(...) return (require("hs.inspect")({...}):gsub("%s+", " ")) end

local module = {}

local win = uitk.window{ x = 100, y = 100, h = 550, w = 500 }
                :styleMask{ "titled", "closable", "miniaturizable" }
                :show()

local tabNames = { "Click", "Magnification", "Pan", "Press", "Rotation" }

local testImage = image.imageFromName(image.systemImageNames.ApplicationIcon)

local tabs = uitk.element.container.tabs()
win:content(tabs)

-- set up each tab container
local tabContainers = {}
for i, v in ipairs(tabNames) do
    tabContainers[v] = uitk.element.container()
    tabs[i] = {
        _self   = uitk.element.container.tabs.newItem():label(v),
        element = tabContainers[v],
    }
end

-- set up Click tab container

    local clickContainer = tabContainers["Click"]
    clickContainer[#clickContainer + 1] = {
        _self          = uitk.element.textField.newLabel("Test out the click gesture in this tab"),
        containerFrame = { cX = "50%", y = 30, }
    }

    clickContainer[#clickContainer + 1] = {
        _self = uitk.element.textField.newLabel("Try double and quad clicking in the box below:"),
    }
    clickContainer[#clickContainer]:position(
        "below",
        clickContainer[#clickContainer - 1],
        10,
        "center"
    )

    clickContainer[#clickContainer + 1] = {
        id             = "gestureBox",
        _self          = uitk.element.canvas.new():insertElement({
                             type        = "rectangle",
                             action      = "strokeAndFill",
                             strokeWidth = 5,
                             strokeColor = { white = 0 },
                             fillColor   = { white = 1 },
                         }),
        containerFrame = { h = 200, w = "50%" },
    }
    clickContainer[#clickContainer]:position(
        "below",
        clickContainer[#clickContainer - 1],
        50,
        "center"
    )

    clickContainer[#clickContainer + 1] = {
        id    = "double",
        _self = uitk.element.button.buttonType("pushOnPushOff"):title("Double"),
        containerFrame = { x = "10%", bY = "90%", h = 100, w = "35%" },
    }

    clickContainer[#clickContainer + 1] = {
        id    = "quad",
        _self = uitk.element.button.buttonType("pushOnPushOff"):title("Quad"),
        containerFrame = { rX = "90%", bY = "90%", h = 100, w = "35%" },
    }

-- the actual gesture recognition code
    clickContainer("gestureBox"):gestures({
        uitk.util.gesture.click():clicks(2):callback(function(obj, state)
            if state == "ended" then
                clickContainer("double"):press()
            else
                print(string.format("unexpected state: %s", state))
            end
        end),
        uitk.util.gesture.click():clicks(4):callback(function(obj, state)
            if state == "ended" then
                clickContainer("quad"):press()
            else
                print(string.format("unexpected state: %s", state))
            end
        end)
    })

-- set up Magnification tab container

    local magContainer = tabContainers["Magnification"]
    magContainer[#magContainer + 1] = {
        _self          = uitk.element.textField.newLabel("Test out the magnification gesture in this tab"),
        containerFrame = { cX = "50%", y = 30, }
    }

    magContainer[#magContainer + 1] = {
        id             = "magImage",
        _self          = uitk.element.image():imageScaling("proportionallyUpOrDown")
                                             :image(testImage),
        containerFrame = { cX = "50%", cY = "50%", h = 100, w = 100 }
    }

-- the actual gesture recognition code
    local startingDimension = 0
    magContainer:addGesture(uitk.util.gesture.magnification():callback(function(obj, state)
        local magImage      = magContainer("magImage")
        if state == "begin" then
            startingDimension = magImage:containerFrame().h
        elseif state == "changed" then
            local magnification = obj:magnification()
            local newDimension = startingDimension * obj:magnification()
            newDimension = (newDimension < 25) and 25 or
                           ((newDimension > 750) and 750 or newDimension)
            magImage:containerFrame{ h = newDimension, w = newDimension }
        end
    end))

-- set up Pan tab container

-- set up Press tab container

-- set up Rotation tab container

    local rotContainer = tabContainers["Rotation"]
    rotContainer[#rotContainer + 1] = {
        _self          = uitk.element.textField.newLabel("Test out the rotation gesture in this tab"),
        containerFrame = { cX = "50%", y = 30, }
    }

    rotContainer[#rotContainer + 1] = {
        id             = "rotImage",
        _self          = uitk.element.image():imageScaling("proportionallyUpOrDown")
                                             :image(testImage),
        containerFrame = { cX = "50%", cY = "50%", h = 250, w = 250 }
    }

-- the actual gesture recognition code
    local startingRotation = 0
    rotContainer:addGesture(uitk.util.gesture.rotation():callback(function(obj, state)
        local rotImage = rotContainer("rotImage")
        if state == "begin" then
            startingRotation = rotImage:rotationAngle()
        elseif state == "changed" then
            local rotation = obj:rotation()
            rotImage:rotationAngle(startingRotation + rotation)
        end
    end))






module.win = win
return module
