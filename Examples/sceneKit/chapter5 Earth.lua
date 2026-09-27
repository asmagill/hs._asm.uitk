-- https://github.com/d-ronnqvist/SCNBook-code/tree/master/Chapter%2005%20-%20Earth/Code/Chapter%2005%20-%20Earth

local uitk     = require("hs._asm.uitk")
local sceneKit = uitk.element.sceneKit
local image    = require("hs.image")
local timer    = require("hs.timer")

local info = debug.getinfo(1,'S');
local path = info.source:match("@(/.+/)[%w ]+%.lua")

local animationRunner -- predeclare
killAnimations = false

local w = uitk.window{x = 100, y = 100, h = 750, w = 750 }:show()
local scene = sceneKit{}:backgroundColor{ white = 0.05, alpha = 1.0 }
w:content(scene)

cameraNode = sceneKit.node():camera(sceneKit.camera())
                            :position(uitk.util.vector.vector3{0, 0, 8})
scene:rootNode():addChildNode(cameraNode)

-- Create a sphere and use multiple textures to make it look like the earth
local earth = sceneKit.geometry.sphere(3)
local earthMaterial = sceneKit.material()
earthMaterial:diffuse():contents(image.imageFromPath(path .. "earth_diffuse_4k.jpg"))
earthMaterial:specular():contents(image.imageFromPath(path .. "earth_specular_1k.jpg"))
earthMaterial:emission():contents(image.imageFromPath(path .. "earth_lights_4k.jpg"))
earthMaterial:normal():contents(image.imageFromPath(path .. "earth_normal_4k.jpg"))
earthMaterial:multiply():contents{ white = 0.7, alpha = 1.0 }
earthMaterial:shininess(0.05)
-- earth:firstMaterial(earthMaterial)
earth:materials{earthMaterial}
local earthNode = sceneKit.node():geometry(earth)

-- tilt the earth
local axisNode = sceneKit.node():rotation(uitk.util.vector.vector4{1, 0, 0, math.pi / 6})
                                :addChildNode(earthNode)
scene:rootNode():addChildNode(axisNode)

-- Create a larger sphere to look like clouds
local clouds = sceneKit.geometry.sphere(3.075):segments(144)
local cloudsMaterial = sceneKit.material()
cloudsMaterial:diffuse():contents{ white = 1 }
cloudsMaterial:locksAmbientWithDiffuse(true)
--  Use a texture where RGB (or lack thereof) determines transparency of the material
cloudsMaterial:transparent():contents(image.imageFromPath(path .. "clouds_transparent_2k.jpg"))
cloudsMaterial:transparencyMode("rgbZero")
-- Don't have the clouds cast shadows
cloudsMaterial:writesToDepthBuffer(false)

-- --     // ------------------
-- --     // This is a "shader modifier" to create an atmospheric halo effect.
-- --     // We won't go into shader modifiers until Chapter 13. But it adds a nice
-- --     // visual effect to this example.
-- --     NSURL *url = [[NSBundle mainBundle] URLForResource:@"AtmosphereHalo" withExtension:@"glsl"];
-- --     NSError *error;
-- --     NSString *shaderSource = [[NSString alloc] initWithContentsOfURL:url
-- --                                                             encoding:NSUTF8StringEncoding
-- --                                                                error:&error];
-- --     if (!shaderSource) {
-- --         // Handle the error
-- --         NSLog(@"Failed to load shader source code, with error: %@", [error localizedDescription]);
-- --     } else {
-- --         cloudsMaterial.shaderModifiers = @{ SCNShaderModifierEntryPointFragment : shaderSource };
-- --     }
-- --     // ------------------

clouds:materials{ cloudsMaterial }
local cloudNode = sceneKit.node():geometry(clouds)
earthNode:addChildNode(cloudNode)

earthNode:rotation(uitk.util.vector.vector4{0, 1, 0, 0}) -- specify the rataion axis
cloudNode:rotation(uitk.util.vector.vector4{0, 1, 0, 0}) -- specify the rataion axis

-- Animate the rotation of the earth and the clouds
animationRunner = coroutine.wrap(function()
    local earthRadiansPerSecond = math.pi *  2 / 50
    local cloudRadiansPerSecond = math.pi * -2 / 150
    local startTime             = timer.secondsSinceEpoch()
    local lastMoveTime          = timer.secondsSinceEpoch()

    while not killAnimations do
        local now = timer.secondsSinceEpoch()
        if now - lastMoveTime >= 0.01 then
            local earthRotation = earthNode:rotation()
            local cloudRotation = cloudNode:rotation()
            earthRotation.w = earthRotation.w + earthRadiansPerSecond * (now - lastMoveTime)
            cloudRotation.w = cloudRotation.w + cloudRadiansPerSecond * (now - lastMoveTime)
--             print(earthRotation, cloudRotation)
            earthNode:rotation(earthRotation)
            cloudNode:rotation(cloudRotation)

            lastMoveTime = now
        end

        coroutine.applicationYield()
    end

    earthNode:rotation(uitk.util.vector.vector4{0, 1, 0, 0}) -- specify the rataion axis
    cloudNode:rotation(uitk.util.vector.vector4{0, 1, 0, 0}) -- specify the rataion axis

    killAnimations = false
    animationRunner = nil
end)
animationRunner()

--  Create something to light up the earth.
local sun = sceneKit.light():type("spot")
                            :castsShadow(true)
                            :shadowRadius(3)
                            :shadowColor{ white = 0, alpha = 0.75 }
                            :zNear(10)
                            :zFar(40)
local sunNode = sceneKit.node():light(sun)
                               :position(uitk.util.vector.vector3{ -15, 0, 12 })
                               :constraints{ sceneKit.constraint.lookAt(earthNode) }
scene:rootNode():addChildNode(sunNode)

local module = {}

module.w         = w
module.scene     = scene
module.earthNode = earthNode
module.sunNode   = sunNode
module.cloudNode = cloudNode

return setmetatable(module, {
    __gc = function(self) killAnimations = true end,
})

