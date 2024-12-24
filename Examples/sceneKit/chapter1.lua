-- https://github.com/d-ronnqvist/SCNBook-code/tree/master/Chapter%2001%20-%20The%20First%20Scene

local uitk = require("hs._asm.uitk")
local sceneKit = uitk.element.sceneKit

w = uitk.window{x = 100, y = 100, h = 500, w = 500 }:show()
scene = sceneKit{}
w:content(scene)

boxSide = 10.0
box     = sceneKit.geometry.box(boxSide, boxSide, boxSide, 0.0)
boxNode = sceneKit.node():geometry(box)
scene:rootNode():addChildNode(boxNode)
boxNode:rotation(uitk.util.vector.vector4{ 0, 1, 0, math.pi / 5})

cameraNode = sceneKit.node():camera(sceneKit.camera())
                            :position(uitk.util.vector.vector3{0, 10, 20})
                            :rotation(uitk.util.vector.vector4{1, 0, 0, -math.atan(10, 20)})
scene:rootNode():addChildNode(cameraNode)

lightBlueColor = { red = 4.0/255.0, green = 120.0/255.0, blue = 255.0/255.0, alpha = 1.0 }
light = sceneKit.light():type("directional"):color(lightBlueColor)
lightNode = sceneKit.node():light(light)
cameraNode:addChildNode(lightNode)
