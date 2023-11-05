local uitk   = require("hs._asm.uitk")
local image  = require("hs.image")
local stext  = require("hs.styledtext")
local canvas = uitk.element.canvas

local module = {}

local gui = uitk.window{ x = 100, y = 100, h = 500, w = 500 }:show()
local mgr = gui:content()

mgr[#mgr + 1] = {
    _element = uitk.element.textField.newLabel(stext.new(
        "Drag an image file into the box or\npaste one from the clipboard",
        { paragraphStyle = { alignment = "center" } }
    )),
    containerFrame = {
        cX = "50%",
        y  = 5,
    }
}

local placeholder = canvas.new{ x = 0, y = 0, h = 500, w = 500 }:appendElements{
    {
        type  = "image",
        image = image.imageFromName(image.systemImageNames.ExitFullScreenTemplate)
    }, {
        type  = "image",
        image = image.imageFromName(image.systemImageNames.ExitFullScreenTemplate),
        transformation = canvas.matrix.translate(250,250):rotate(90):translate(-250,-250),
    }
}:imageFromCanvas()

local imageElement = uitk.element.image():image(placeholder)
                                         :allowsCutCopyPaste(true)
                                         :editable(true)
                                         :imageAlignment("center")
                                         :imageFrameStyle("bezel")
                                         :imageScaling("proportionallyUpOrDown")
                                         :callback(function(o)
                                             if module.canvas then module.canvas:delete() end
                                             module.canvas = canvas.new{ x = 700, y = 100, h = 100, w = 100 }:show()
                                             module.canvas[1] = {
                                                 type = "image",
                                                 image = o:image()
                                             }
                                         end)

mgr:insert(imageElement, { w = 450, h = 450 })
imageElement:position("below", mgr(1), 5, "center")

module.gui = gui
module.mgr = mgr

return module
