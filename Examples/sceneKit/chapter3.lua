-- https://github.com/d-ronnqvist/SCNBook-code/tree/master/Chapter%2003%20-%20More%20of%20a%20scene

local uitk     = require("hs._asm.uitk")
local sceneKit = uitk.element.sceneKit
local vector   = uitk.util.vector

local timer    = require("hs.timer")

local module = {}

local barChartNumbers = { 3, 1, 4, 1, 5, 9, 2, 6 }

local baseAnimationDelay = 1.0
local animations         = {}

local animationRunner -- predeclare
killAnimations = false

local w = uitk.window{x = 100, y = 100, h = 750, w = 750 }:show()
local scene = sceneKit{}:allowsCameraControl(true)
w:content(scene)

-- A camera
-- --------
-- The camera is moved back and up from the center of the scene
-- and then rotated so that it looks down to the center
local cameraNode = sceneKit.node():camera(sceneKit.camera())
                                  :position(vector.vector3(0, 20, 40))
                                  :rotation(vector.vector4(1, 0, 0, -math.atan(20, 45)))
scene:rootNode():addChildNode(cameraNode)

-- A spot light
-- ------------
-- The spot light is positioned right next to the camera
-- so it is offset sligthly and added to the camera node
local spotlight = sceneKit.light():type("spot")
                                  :color{ white = 0.4 }
                                  :spotInnerAngle(60)
                                  :spotOuterAngle(100)
                                  :castsShadow(true)
local spotlightNode = sceneKit.node():light(spotlight)
                                     :position(vector.vector3(-30, 25, 30))
scene:rootNode():addChildNode(spotlightNode)

-- make the spotlight look at the center of the scene
spotlightNode:constraints{ sceneKit.constraint.lookAt(scene:rootNode()) }

-- A directional light
-- -------------------
-- Lights up the scene from the side
local directional = sceneKit.light():type("directional")
                                    :color{ white = 0.3 }
local directionalNode = sceneKit.node():light(directional)
                                       :rotation(vector.vector4(0, 1, 0, math.pi))
scene:rootNode():addChildNode(directionalNode)

-- An ambient light
-- ----------------
-- Helps light up the areas that are not illuminated by the directional light
local ambient = sceneKit.light():type("ambient")
                                :color{ white = 0.25 }
local ambNode = sceneKit.node():light(ambient)
scene:rootNode():addChildNode(ambNode)

-- A reflective floor
-- ------------------
local floor = sceneKit.geometry.floor():reflectivity(0.15)
                                       :reflectionFalloffEnd(15)
-- A solid white color, not affected by light
floor:firstMaterial():diffuse():contents{ white = 1 }
floor:firstMaterial():lightingModelName("constant")
local floorNode = sceneKit.node():geometry(floor)
scene:rootNode():addChildNode(floorNode)

--
-- @return The blue shiny material that the cylinders use
--
local makeCylinderMaterial = function()
    local material = sceneKit.material()
    local lightBlueColor = { red = 74/255, green = 165/255, blue = 227/255 }

    material:diffuse():contents(lightBlueColor)
    material:specular():contents{ white = 1 }
    material:shininess(0.15)
    material:locksAmbientWithDiffuse(true)

    return material;
end

local setNumbers = function(value)
    barChartNumbers = value

    if module.chartNode then
        module.chartNode:removeFromParent()
        module.chartNode = nil
    end

    if animationRunner then
        killAnimations = true
        animationRunner()
    end

    local chartNode = sceneKit.node():position(vector.vector3(0, 0.25, 0))
                                     :rotation(vector.vector4(0, 1, 0, -math.pi / 8.3))
    scene:rootNode():addChildNode(chartNode)
    module.chartNode = chartNode

    local barRadius = 2.3
    local margin    = 1.5

--    |    |  |    |
--    |____|  |____|
--    :<----->:
    local stepLength = barRadius * 2.0 + margin

    -- one node to hold all the numbers inside the chart node
    local numbersNode = sceneKit.node()
    chartNode:addChildNode(numbersNode)

    local cylinderMaterial = makeCylinderMaterial()

    -- for each number, create a cylinder and a text element
    for i, v in ipairs(barChartNumbers) do

        -- create one node to position the cylinder and text along the x-axis
        local barNode = sceneKit.node()
        barNode:position(vector.vector3(stepLength * (i - 1), 0, 0))
        numbersNode:addChildNode(barNode)

        -- create a cylinder for the actual "bars"
        local height = v
        local cylinder = sceneKit.geometry.cylinder(barRadius, height)
        cylinder:materials{ cylinderMaterial }

        local cylinderNode = sceneKit.node(cylinder)
        cylinderNode:position(vector.vector3(0, height/2.0, 0))
        barNode:addChildNode(cylinderNode)

        -- create a text element to display on top of each bar
        local numberText = tostring(v)
        local text = sceneKit.geometry.text(numberText, 0.2)
        text:firstMaterial():diffuse():contents{ white = 0.9 }
        text:flatness(0.1):font{ name = ".AppleSystemUIFont", size = 2.5 }

        local textNode = sceneKit.node(text)
        -- invert the rotation of the chart
        textNode:transform(chartNode:worldTransform():invert())
        -- center on top of the bar
        textNode:position(vector.vector3(
            -text:textSize().w / 2.0,
            height-.05,
            0.0
        ))
        barNode:addChildNode(textNode)

        local animationDelay = baseAnimationDelay + 0.5 * (i - 1) / (#barChartNumbers + 1)
        local startTime = timer.secondsSinceEpoch() + animationDelay

        table.insert(animations, {
            start     = startTime,
            fromValue = 0.25,
            toValue   = cylinderNode:geometry():height(),
            setFn     = function(val) cylinderNode:geometry():height(val) end,
            duration  = 1.0,
        })

        table.insert(animations, {
            start     = startTime,
            fromValue = 0,
            toValue   = cylinderNode:position().y,
            setFn     = function(val)
                local t = cylinderNode:position()
                t.y = val
                cylinderNode:position(t)
            end,
            duration  = 1.0,
        })

        table.insert(animations, {
            start     = startTime,
            fromValue = 0,
            toValue   = textNode:position().y,
            setFn     = function(val)
                local t = textNode:position()
                t.y = val
                textNode:position(t)
            end,
            duration  = 1.0,
        })

        -- animate the bar growing as it appears
--         NSTimeInterval animationDelay = baseAnimationDelay +  0.5 * idx / (numbers.count + 1.0);
--
--         [cylinderNode addAnimation:[self growingCylinderAnimationWithDelay:animationDelay]
--                             forKey:@"grow"];
--
--         [textNode addAnimation:[self growTextAnimationWithDelay:animationDelay]
--                         forKey:@"move text updwards"];
    end


    -- Center the numbers in the chart
    local boundingBoxMin, boundingBoxMax = numbersNode:boundingBox()

    local totalWidth = boundingBoxMax.x - boundingBoxMin.x
    local middleX = boundingBoxMin.x - totalWidth / 2.0
    numbersNode:position(vector.vector3(middleX, 0, 0))

    table.insert(animations, {
        start     = timer.secondsSinceEpoch() + baseAnimationDelay,
        fromValue = 0,
        toValue   = chartNode:rotation().w,
        setFn     = function(val)
            local t = chartNode:rotation()
            t.w = val
            chartNode:rotation(t)
        end,
        duration  = 1.5,
    })

    -- Add an animation that rotates the chart
--     [self.chartNode addAnimation:[self chartRotationAnimationWithDelay:baseAnimationDelay]
--               forKey:@"Rotate the entire chart"];

    if not animationRunner then
        animationRunner = coroutine.wrap(function()
            while #animations > 0 and not killAnimations do
                local now = timer.secondsSinceEpoch()
                local remove = {}
                for i, v in ipairs(animations) do
                    if now >= (v.start + v.duration) then
                        v.setFn(v.toValue)
                        table.insert(remove, i)
                    elseif now >= v.start then
                        local multiplier = (now - v.start) / v.duration
                        v.setFn(v.fromValue + (v.toValue - v.fromValue) * multiplier)
                    elseif not v.started then
                        v.started = true
                        v.setFn(v.toValue)
                    end
                end
                for i2 = #remove, 1, -1 do table.remove(animations, remove[i2]) end
                coroutine.applicationYield()
            end

             while #animations > 0 do table.remove(animations) end
             killAnimations = false
             animationRunner = nil
        end)
        animationRunner()
    end
end

module.w               = w
module.scene           = scene
module.cameraNode      = cameraNode
module.spotlight       = spotlight
module.spotlightNode   = spotlightNode
module.directional     = directional
module.directionalNode = directionalNode
module.ambient         = ambient
module.ambNode         = ambNode
module.floor           = floor
module.floorNode       = floorNode
module.setNumbers      = setNumbers
module.animations      = animations

setmetatable(module, {
    __index = function(self, key)
        if key == "barChartNumbers" then
            return barChartNumbers
        else
            return nil
        end
    end,
    __newindex = function(self, key, value)
        local isGood = (key == "barChartNumbers") and
                       (type(value) == "table")   and
                       (#value > 0)
        local idx = 0
        while isGood and idx < #value do
            idx = idx + 1
            isGood = type(value[idx]) == "number"
        end

        if isGood then
            setNumbers(value)
        else
            if key ~= "barChartNumbers" then
                rawset(self, key, value)
            else
                error("expected table of numbers for barChartNumbers")
            end
        end
    end
})

module["barChartNumbers"] = barChartNumbers

return module
