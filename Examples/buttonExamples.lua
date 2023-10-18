local uitk    = require("hs._asm.uitk")
local image   = require("hs.image")

local finspect = function(...) return (require("hs.inspect")({...}):gsub("%s+", " ")) end

local module = {}

local display = uitk.window{ x = 100, y = 100, h = 100, w = 100 }:show():passthroughCallback(function(...) print(finspect(...)) end)
local grp = display:content()

-- TODO:
-- need to add code to display bezel types as well and code to display those in their best form
-- e.g. the disclosure bezels only make sense with the onOff or pushOnPushOff types
local types = {
    "momentaryLight",
    "toggle",
    "switch",
    "radio",
    "momentaryChange",
    "multiLevelAccelerator",
    "onOff",
    "pushOnPushOff",
    "accelerator",
    "momentaryPushIn"
}

for i, v in ipairs(types) do
    grp[#grp + 1] = uitk.element.button.buttonType(v):title(v):alternateTitle("not " .. v):tooltip("button type " .. v)
end

local lastFrame = grp[#grp].frame._effective

-- 10.12 constructors; approximations are used if 10.11 or 10.10 detected; included here so I can determine what to mimic
grp[#grp + 1] = {
    _userdata = uitk.element.button.buttonWithImage(image.imageFromName(image.systemImageNames.ApplicationIcon)),
    frame     = { y = lastFrame.y + 2 * lastFrame.h }
}
grp[#grp + 1] = uitk.element.button.buttonWithTitle("buttonWithTitle")
grp[#grp + 1] = uitk.element.button.buttonWithTitleAndImage("buttonWithTitleAndImage", image.imageFromName(image.systemImageNames.ApplicationIcon))
grp[#grp + 1] = uitk.element.button.checkbox("checkbox")
grp[#grp + 1] = uitk.element.button.radioButton("radioButton")

-- radio buttons within the same view (content element) only allow one at a time to be selected (they automatically unselect the others)
-- to have multiple sets of radio buttons they need to be in different views
local radio = uitk.element.content():tooltip("grouped radiobuttons")
radio:insert(uitk.element.button.radioButton("A"):tooltip("A"))
radio:insert(uitk.element.button.radioButton("B"):tooltip("not A"))
radio:insert(uitk.element.button.radioButton("C"):tooltip("also not A"))
-- then add the new view to the main one just like any other element
grp:insert(radio, { x = 200, y = 200 })
grp:sizeToFit(20, 10)

module.display  = display

return module
