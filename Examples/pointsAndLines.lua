local uitk   = require("hs._asm.uitk")
local sk     = uitk.element.sceneKit
local vector = uitk.util.vector

local module = {}

module.points = {
    {  1,  1,  1 },
    {  1,  1, -1 },
    {  1, -1, -1 },
    {  1, -1,  1 },
    { -1,  1,  1 },
    { -1,  1, -1 },
    { -1, -1, -1 },
    { -1, -1,  1 },
}

module.lines = {
    { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 },
    { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 },
    { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 },
}

local pointRadius = 0.25
local lineRadius  = 0.1

module.pointGeometry = sk.geometry.sphere("pointG", pointRadius)
module.lineGeometry  = sk.geometry.cylinder("lineG", lineRadius, 1)
module.pointNode     = sk.node("point"):geometry(module.pointGeometry)
module.lineNode      = sk.node("line"):geometry(module.lineGeometry)

module.objectNode  = sk.node("object"):addChildNode(sk.node("points"))
                                      :addChildNode(sk.node("lines"))

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

module.scene = sk{}:allowsCameraControl(true)
                   :enableDefaultLighting(true)
                   :showsStatistics(true)

module.w = uitk.window{x = 100, y = 100, h = 500, w = 500 }:content(module.scene):show()
module.scene:rootNode():addChildNode(module.objectNode)

module.reGenerate()

return module

