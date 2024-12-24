-- https://github.com/d-ronnqvist/SCNBook-code/tree/master/Chapter%2002%20-%20Lights%20%26%20Materials

local uitk = require("hs._asm.uitk")
local sceneKit = uitk.element.sceneKit

useOmniLight         = true
useSpotlight         = not useOmniLight
useAmbientLight      = true
useTwoBoxes          = true
useMultipleMaterials = true

w = uitk.window{x = 100, y = 100, h = 750, w = 750 }:show()
scene = sceneKit{}:allowsCameraControl(true)
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

if useOmniLight then
    -- A omni light that fades in intensity from 15 to 20 units of distance
    -- --------------------------------------------------------------------

    omniLight = sceneKit.light():type("omni")
                                :color(lightBlueColor)
                                :attenuationStartDistance(15)
                                :attenuationEndDistance(20)

    omniLightNode = sceneKit.node():light(omniLight)
    cameraNode:addChildNode(omniLightNode)
end

if useSpotlight then
    -- A very narrow spot light that fades quickly along the edge
    -- ----------------------------------------------------------

    spotlight = sceneKit.light():type("spot")
                                :color(lightBlueColor)
                                :spotInnerAngle(25)
                                :spotOuterAngle(30)

    spotlightNode = sceneKit.node():light(spotlight)
    cameraNode:addChildNode(spotlightNode)

end

if (useAmbientLight) then
    -- An ambient light makes everything in the scene slightly brighter
    -- ----------------------------------------------------------------

    ambientLight = sceneKit.light():type("ambient"):color{ white = 0.25 }

    ambientLightNode = sceneKit.node():light(ambientLight)
    scene:rootNode():addChildNode(ambientLightNode)
end

if useMultipleMaterials then
    -- Each side of the box has its own color
    -- --------------------------------------

    -- All have the same diffuse and ambient colors to show the
    -- effect of the ambient light, even with these materials.

    greenMaterial = sceneKit.material():locksAmbientWithDiffuse(true)
    greenMaterial:diffuse():contents{ green = 1 }

    redMaterial = sceneKit.material():locksAmbientWithDiffuse(true)
    redMaterial:diffuse():contents{ red = 1 }

    blueMaterial = sceneKit.material():locksAmbientWithDiffuse(true)
    blueMaterial:diffuse():contents{ blue = 1 }

    yellowMaterial = sceneKit.material():locksAmbientWithDiffuse(true)
    yellowMaterial:diffuse():contents{ hex = "#FFFF00" }

    purpleMaterial = sceneKit.material():locksAmbientWithDiffuse(true)
    purpleMaterial:diffuse():contents{ hex = "#800080" }

    magentaMaterial = sceneKit.material():locksAmbientWithDiffuse(true)
    magentaMaterial:diffuse():contents{ hex = "#FF00FF" }

    box:materials{
        blueMaterial,
        redMaterial,
        greenMaterial,
        yellowMaterial,
        purpleMaterial,
        magentaMaterial
    }
end

if useTwoBoxes then
    -- Create another box that has a specular material
    -- -----------------------------------------------

    cameraNode:position(uitk.util.vector.vector3(0, 0, 20))

    -- No rotation on the box or the camera; note axis doesn't matter
    noRotation = uitk.util.vector.vector4(1, 0, 0, 0)
    cameraNode:rotation(noRotation)
    boxNode:rotation(noRotation)

    anotherBox = sceneKit.geometry.box(boxSide, boxSide, boxSide, 0)
    anotherBox:firstMaterial():diffuse():contents(lightBlueColor)
    anotherBox:firstMaterial():locksAmbientWithDiffuse(true)
    -- same matarial as the original box but with a specular color
    anotherBox:firstMaterial():specular():contents{ white = 1 }

    anotherBoxNode = sceneKit.node():geometry(anotherBox)
    scene:rootNode():addChildNode(anotherBoxNode)

    -- position the two boxes next to each other
    boxMargin    = 1.0
    boxPositionX = (boxSide + boxMargin) / 2.0
    boxNode:position(uitk.util.vector.vector3(boxPositionX, 0, 0))
    anotherBoxNode:position(uitk.util.vector.vector3(-boxPositionX, 0, 0))
end
