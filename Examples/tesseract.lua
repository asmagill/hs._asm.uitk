local uitk   = require("hs._asm.uitk")
local sk     = uitk.element.sceneKit
local vector = uitk.util.vector
local math   = require("hs.math")

-- I think the matrix-vector product performing the rotation is the next slow spot; will
-- probably need to move util.vector and util.matrix4 product function into C to make
-- a noticeable difference.

-- still, module.rotateYZ(5, 100) produces a cool result...

local module = {}

-- build a tesseract

local fourPoints = {}
for i1, v1 in ipairs{ -1, 1 } do
  for i2, v2 in ipairs{ -1, 1 } do
    for i3, v3 in ipairs{ -1, 1 } do
      for i4, v4 in ipairs{ -1, 1 } do
        table.insert(fourPoints, { v1, v2, v3, v4 })
      end
    end
  end
end

local fourLines = {}
for i = 1, #fourPoints, 1 do
    for j = i, #fourPoints, 1 do
        local diffCount = 0
        local p1, p2 = fourPoints[i], fourPoints[j]
        for c = 1, 4, 1 do
            if p1[c] ~= p2[c] then diffCount = diffCount + 1 end
        end
        if diffCount == 1 then table.insert(fourLines, { i, j }) end
    end
end

-- project 4d to 3d

wEyeD = 1
scale = 2
offset = 3

projectXYZ = function(x,y,z,w)
    return scale * wEyeD * x / (wEyeD + scale * w + offset),
           scale * wEyeD * y / (wEyeD + scale * w + offset),
           scale * wEyeD * z / (wEyeD + scale * w + offset)
end

module.lines = fourLines
module.fourPoints = fourPoints

-- update point positions to reflect their projection into 3space
module.genPoints = function(fp)
    module.points = {}
    for i, v in ipairs(fp) do
        local x, y, z = projectXYZ(v[1], v[2], v[3], v[4])
        table.insert(module.points, { x, y, z })
    end
end

-- cache sin and cos
local oldSin = {}
local oldCos = {}

module.cachedSin = oldSin
module.cachedCos = oldCos

local sin = function(d)
    if not oldSin[d] then oldSin[d] = math.sin(math.rad(d)) end
    return oldSin[d]
end

local cos = function(d)
    if not oldCos[d] then oldCos[d] = math.cos(math.rad(d)) end
    return oldCos[d]
end

-- pre-build
for d = 1, 360, 1 do
    cos(d)
    sin(d)
end

local commonRotater = function(coords, increment, count, delay)
    increment = increment or 5
    count     = count or 1
    delay     = delay or math.minFloat

    local mat = uitk.util.matrix4.identity()
    local fn
    fn = coroutine.wrap(function()
        local c = 0
        while c < count do
            c = c + 1
            local d = 0
            while d < 360 do
                d = d + increment
                local cosOfD = cos(d)
                local sinOfD = sin(d)
                mat[coords[1][1]][coords[1][2]] =  cosOfD
                mat[coords[2][1]][coords[2][2]] = -sinOfD
                mat[coords[3][1]][coords[3][2]] =  sinOfD
                mat[coords[4][1]][coords[4][2]] =  cosOfD
                local n4p = {}
                for i = 1, #fourPoints, 1 do n4p[i] = mat * uitk.util.vector.vector4(fourPoints[i]) end
                module.genPoints(n4p)
                module.reGenerate()

                repeat
                    coroutine.applicationYield(delay)
                    collectgarbage()
                until not module.pause

                if module.stop then
                    d = 361
                    c = count + 1
                    module.stop = nil
                end
            end
        end
        fn = nil
        module.genPoints(fourPoints)
        module.reGenerate()
    end)
    fn()
end

local pointRadius = 0.1
local lineRadius  = 0.05

module.pointGeometry = sk.geometry.sphere("pointG", pointRadius)
module.lineGeometry  = sk.geometry.cylinder("lineG", lineRadius, 1)
module.pointNode     = sk.node("point"):geometry(module.pointGeometry)
module.lineNode      = sk.node("line"):geometry(module.lineGeometry)

module.objectNode  = sk.node("object"):addChildNode(sk.node("points"))
                                      :addChildNode(sk.node("lines"))

module.pointGeometry:firstMaterial():diffuse():contents({blue = 1})
module.pointGeometry:firstMaterial():specular():contents({white = 1})
module.pointGeometry:firstMaterial():shininess(0.15)

module.lineGeometry:firstMaterial():diffuse():contents({green = 1})
module.lineGeometry:firstMaterial():specular():contents({white = 1})
module.lineGeometry:firstMaterial():shininess(0.15)

module.reGenerate = function()
    -- in case it's changed
    module.pointGeometry:radius(pointRadius)
    module.lineGeometry:radius(lineRadius)

    local points = module.objectNode:childWithName("points")
    local lines  = module.objectNode:childWithName("lines")

    -- clear old data
    while #points:childNodes() > 0 do points:removeChildNode(#points) end
    while #lines:childNodes() > 0  do lines:removeChildNode(#lines) end

    -- add points
    for i, v in pairs(module.points) do
        local x, y, z = v[1], v[2], v[3]
        local newPoint = module.pointNode:clone()
                                         :name("point" .. tostring(i))
                                         :worldPosition{ x = x, y = y, z = z }
        points:addChildNode(newPoint)
    end

    -- default orientation for lines
    local unitY = vector.unitY()

    -- add lines
    for i, v in pairs(module.lines) do
        local p1, p2 = v[1], v[2]
        local v1 = vector.vector3(module.points[p1])
        local v2 = vector.vector3(module.points[p2])
        local height = (v2 - v1):magnitude()

        local newLine = module.lineNode:clone():name("line" .. tostring(i))
        newLine:geometry(newLine:geometry():copy())
        newLine:geometry():height(height)
        newLine:worldPosition((v1 + v2) / 2)

        -- see https://stackoverflow.com/a/1171995 and https://stackoverflow.com/a/11741520
        local dir = (v2 - v1):normalized()
        local q
        if dir == -unitY then -- if 180 degrees, gimbal lock, so handle separately
            local t = v1:crossProduct(unitY):normalized()
            q = vector.quaternion(0, t.x, t.y, t.z)
        else
            q = unitY:crossProduct(dir):pureQuaternion()
            q.r = dir:magnitude() * unitY:magnitude() + unitY:dotProduct(dir)
        end
        newLine:orientation(q:normalized())
        lines:addChildNode(newLine)
    end
end

local scene = sk{}:allowsCameraControl(true)
                  :enableDefaultLighting(true)
                  :showsStatistics(true)

-- A camera
-- --------
-- The camera is moved back and up from the center of the scene
-- and then rotated so that it looks down to the center
local cameraNode = sk.node():camera(sk.camera())
                            :position(vector.vector3(0, 2.0, 4.0))
                            :rotation(vector.vector4(1, 0, 0, -math.atan(20, 45)))
scene:rootNode():addChildNode(cameraNode)

-- A spot light
-- ------------
-- The spot light is positioned right next to the camera
-- so it is offset sligthly and added to the camera node
local spotlight = sk.light():type("spot")
                            :color{ white = 0.4 }
                            :spotInnerAngle(60)
                            :spotOuterAngle(100)
                            :castsShadow(true)
local spotlightNode = sk.node():light(spotlight)
                               :position(vector.vector3(-3.0, 2.5, 3.0))
scene:rootNode():addChildNode(spotlightNode)

-- make the spotlight look at the center of the scene
spotlightNode:constraints{ sk.constraint.lookAt(scene:rootNode()) }

-- A directional light
-- -------------------
-- Lights up the scene from the side
local directional = sk.light():type("directional")
                              :color{ white = 0.3 }
local directionalNode = sk.node():light(directional)
                                 :rotation(vector.vector4(0, 1, 0, math.pi))
scene:rootNode():addChildNode(directionalNode)

-- An ambient light
-- ----------------
-- Helps light up the areas that are not illuminated by the directional light
local ambient = sk.light():type("ambient")
                          :color{ white = 0.25 }
local ambNode = sk.node():light(ambient)
scene:rootNode():addChildNode(ambNode)


module.scene = scene

module.w = uitk.window{x = 100, y = 100, h = 500, w = 500 }:content(module.scene):show()
module.scene:rootNode():addChildNode(module.objectNode)

module.rotateZW = function(...)
    local coords = { { 1, 1 }, { 1, 2 }, { 2, 1 }, { 2, 2 } }
    commonRotater(coords, ...)
end

module.rotateYW = function(...)
    local coords = { { 1, 1 }, { 1, 3 }, { 3, 1 }, { 3, 3 } }
    commonRotater(coords, ...)
end

module.rotateYZ = function(...)
    local coords = { { 1, 1 }, { 1, 4 }, { 4, 1 }, { 4, 4 } }
    commonRotater(coords, ...)
end

module.rotateXW = function(...)
    local coords = { { 2, 2 }, { 2, 3 }, { 3, 2 }, { 3, 3 } }
    commonRotater(coords, ...)
end

module.rotateXZ = function(...)
    local coords = { { 2, 2 }, { 2, 4 }, { 4, 2 }, { 4, 4 } }
    commonRotater(coords, ...)
end

module.rotateXY = function(...)
    local coords = { { 3, 3 }, { 3, 4 }, { 4, 3 }, { 4, 4 } }
    commonRotater(coords, ...)
end

module.genPoints(fourPoints)
module.reGenerate()

return module

