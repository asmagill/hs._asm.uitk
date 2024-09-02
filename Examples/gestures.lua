local uitk  = require("hs._asm.uitk")
local image = require("hs.image")
local mouse = require("hs.mouse")

local constrain = function(val, min, max)
    return (val < min) and min or ((val > max) and max or val)
end

local module = {}

local win = uitk.window{ x = 100, y = 100, h = 550, w = 500 }
                :styleMask{ "titled", "closable", "miniaturizable" }
                :show()

local tabNames = { "Click", "Magnification", "Pan", "Press", "Rotation" }

local testImage = image.imageFromName(image.systemImageNames.ApplicationIcon)

local tabs = uitk.element.container.tabs()
win:content(tabs)

-- Most view generation on the mac is lazy -- things like size, etc. aren't
-- figured out until just-in-time.
--
-- Because our positioning of elements in each tab is a combination of
-- absolute *and* relative positioning, and is done *immediately*, we should
-- set the content size for the container tabs as we create them -- otherwise
-- our positioning will be off.

-- set up each tab container
local tabContainers = {}
for i, v in ipairs(tabNames) do
    tabContainers[v] = uitk.element.container(tabs:contentRect())
    tabs[i] = {
        _self   = uitk.element.container.tabs.newItem():label(v),
        element = tabContainers[v],
    }
end

-- set up Click tab container

    local clickContainer = tabContainers["Click"]
    clickContainer[#clickContainer + 1] = {
        _self          = uitk.element.textField.newLabel("Test out the click gesture in this tab"),
        font           = { name = ".AppleSystemUIFont", size = 15 },
        textAlignment  = "center",
        lineBreakMode  = "wordWrap",
        maxWidth       = clickContainer:frameSize().w * .6,
        containerFrame = { cX = "50%", y = 30, w = "60%" }
    }

    clickContainer[#clickContainer + 1] = {
        _self         = uitk.element.textField.newLabel("Try double and quad clicking in the box below:"),
        textAlignment = "center",
        lineBreakMode = "wordWrap",
    }
    clickContainer[#clickContainer]:position(
        "below",
        clickContainer[#clickContainer - 1],
        20,
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
        font           = { name = ".AppleSystemUIFont", size = 15 },
        textAlignment  = "center",
        lineBreakMode  = "wordWrap",
        maxWidth       = magContainer:frameSize().w * .6,
        containerFrame = { cX = "50%", y = 30, w = "60%" }
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
            local newDimension = constrain(startingDimension * obj:magnification(), 25, 750)
            magImage:containerFrame{ h = newDimension, w = newDimension }
        end
    end))

-- set up Pan tab container

    local panContainer = tabContainers["Pan"]
    panContainer[#panContainer + 1] = {
        _self          = uitk.element.textField.newLabel("Test out the pan gesture in this tab"),
        font           = { name = ".AppleSystemUIFont", size = 15 },
        textAlignment  = "center",
        lineBreakMode  = "wordWrap",
        maxWidth       = panContainer:frameSize().w * .6,
        containerFrame = { cX = "50%", y = 30, w = "60%" }
    }

    panContainer[#panContainer + 1] = {
        _self          = uitk.element.textField.newLabel("Press the mouse button on the image and drag it while still holding down the mouse button."),
        textAlignment  = "center",
        lineBreakMode  = "wordWrap",
        maxWidth       = panContainer:frameSize().w * .8,
        containerFrame = { w = "80%" },
    }
    panContainer[#panContainer]:position(
        "below",
        panContainer[#panContainer - 1],
        20,
        "center"
    )

    panContainer[#panContainer + 1] = {
        id             = "panImage",
        _self          = uitk.element.image():imageScaling("proportionallyUpOrDown")
                                             :image(testImage),
        containerFrame = { cX = "50%", cY = "50%", h = 100, w = 100 }
    }

    -- the actual gesture recognition code

    local panImage     = panContainer("panImage")
    local initialPos = {}
    panImage:addGesture(uitk.util.gesture.pan():callback(function(obj, state)
        if state == "begin" then
            -- may be percentages, so get it's effective frame
            initialPos = panImage:containerFrame()._effective

        elseif state == "changed" then
            local translation = obj:translation()
            local velocity    = obj:velocity()

            panImage:containerFrame({
                x = initialPos.x + translation.x,
                y = initialPos.y + translation.y
            })

            local t = math.sqrt(translation.x ^ 2 + translation.y ^ 2)
            local v = math.sqrt(velocity.x ^ 2 + velocity.y ^ 2)

            print(string.format("Translation: %.2f, Velocity: %.2f pps", t, v))
        else -- assume ended or cancelled, so return image to regular position
            panImage:containerFrame({ cX = "50%", cY = "50%" })
        end
    end))

-- set up Press tab container

    local pressContainer = tabContainers["Press"]
    pressContainer[#pressContainer + 1] = {
        _self          = uitk.element.textField.newLabel("Test out the press gesture in this tab"),
        font           = { name = ".AppleSystemUIFont", size = 15 },
        textAlignment  = "center",
        lineBreakMode  = "wordWrap",
        maxWidth       = pressContainer:frameSize().w * .6,
        containerFrame = { cX = "50%", y = 30, w = "60%" }
    }

    pressContainer[#pressContainer + 1] = {
        _self          = uitk.element.textField.newLabel("Press and hold the mouse button on the image for 2 seconds, then drag it while still holding down the mouse button."),
        textAlignment  = "center",
        lineBreakMode  = "wordWrap",
        maxWidth       = pressContainer:frameSize().w * .8,
        containerFrame = { w = "80%" },
    }
    pressContainer[#pressContainer]:position(
        "below",
        pressContainer[#pressContainer - 1],
        20,
        "center"
    )

    pressContainer[#pressContainer + 1] = {
        id             = "pressImage",
        _self          = uitk.element.image():imageScaling("proportionallyUpOrDown")
                                             :image(testImage),
        containerFrame = { cX = "50%", cY = "50%", h = 100, w = 100 }
    }

    -- the actual gesture recognition code

    local pressImage   = pressContainer("pressImage")
    local lastLocation = {}
    pressImage:addGesture(uitk.util.gesture.press():duration(2):callback(function(obj, state)
        if state == "begin" then
            -- first time will be percentages, so get it's effective frame
            local position = pressImage:containerFrame()._effective
            -- expand a little to show we've "selected" it
            position = {
                x = position.x - 10,
                y = position.y - 10,
                h = position.h * 1.2,
                w = position.h * 1.2,
            }
            pressImage:containerFrame(position)
            -- capture initial location so we can calculate delta
            lastLocation = mouse.absolutePosition()

        elseif state == "changed" then
            local position = pressImage:containerFrame()
            local location = mouse.absolutePosition()
            local tabSize  = pressContainer:frameSize()
            local dX, dY = location.x - lastLocation.x, location.y - lastLocation.y
            position.x = constrain(position.x + dX, 0, tabSize.w - position.w)
            position.y = constrain(position.y + dY, 0, tabSize.h - position.h)

            pressImage:containerFrame(position)
            lastLocation = location

        else -- assume ended or cancelled, so return image to regular size
            local position = pressImage:containerFrame()
            -- return to normal size
            position = {
                x = position.x + 10,
                y = position.y + 10,
                h = position.h / 1.2,
                w = position.h / 1.2,
            }
            pressImage:containerFrame(position)
        end
    end))

-- set up Rotation tab container

    local rotContainer = tabContainers["Rotation"]
    rotContainer[#rotContainer + 1] = {
        _self          = uitk.element.textField.newLabel("Test out the rotation gesture in this tab"),
        font           = { name = ".AppleSystemUIFont", size = 15 },
        textAlignment  = "center",
        lineBreakMode  = "wordWrap",
        maxWidth       = rotContainer:frameSize().w * .6,
        containerFrame = { cX = "50%", y = 30, w = "60%" }
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
