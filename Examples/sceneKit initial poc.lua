local uitk = require("hs._asm.uitk")
local sceneKit = uitk.element.sceneKit

w = uitk.window{x = 100, y = 100, h = 500, w = 500 }:show()
scene = sceneKit{}:allowsCameraControl(true)
w:content(scene)

material = sceneKit.material():fillMode("lines")
material:diffuse():contents({ blue = 1 })
box      = sceneKit.geometry.box("box", 1.0, 1.0, 1.0, 0.0):materials{material}
node     = sceneKit.node():geometry(box)

box._properties.chamferRadius = .2
node._properties.position = { x = 0, y = 0, z = -5 }

scene:rootNode():addChildNode(node)

