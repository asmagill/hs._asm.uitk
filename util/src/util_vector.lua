-- REMOVE IF ADDED TO CORE APPLICATION
    repeat
        -- add proper user dylib path if it doesn't already exist
        if not package.cpath:match(hs.configdir .. "/%?.dylib") then
            package.cpath = hs.configdir .. "/?.dylib;" .. package.cpath
        end

        -- load docs file if provided
        local basePath, moduleName = debug.getinfo(1, "S").source:match("^@(.*)/([%w_]+).lua$")
        if basePath and moduleName then
            if moduleName == "init" then
                moduleName = moduleName:match("/([%w_]+)$")
            end

            local docsFileName = basePath .. "/" .. moduleName .. ".docs.json"
            if require"hs.fs".attributes(docsFileName) then
                require"hs.doc".registerJSONFile(docsFileName)
            end
        end

        -- setup loaders for submodules (if any)
        --     copy into Hammerspoon/setup.lua before removing

    until true -- executes once and hides any local variables we create
-- END REMOVE IF ADDED TO CORE APPLICATION

--- === hs._asm.uitk.util.vector ===
---
--- A sub module to `hs._asm.uitk` which provides support vector3, vector4, and quaternion tables.

local USERDATA_TAG = "hs._asm.uitk.util.vector"
local uitk         = require("hs._asm.uitk")
-- local module      = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libutil_"))
local module = {}

local math = require("hs.math")

-- private variables and methods -----------------------------------------

local vector3Methods    = {}
local vector4Methods    = {}
local quaternionMethods = {}

-- these are written to be as reusable as possible, so we access elements by index in most cases

-- shared methods

vector3Methods.isValid = function(self)
    local result, idx = true, 0
    while result and idx < #self do
        idx = idx + 1
        result = not math.isNaN(self[idx])
    end
    return result
end
vector4Methods.isValid    = vector3Methods.isValid
quaternionMethods.isValid = vector3Methods.isValid

vector3Methods.isUnit = function(self)
    return self:magnitude() == 1.0
end
vector4Methods.isUnit    = vector3Methods.isUnit
quaternionMethods.isUnit = vector3Methods.isUnit


vector3Methods.copy = function(self)
    return module.new(self)
end
vector4Methods.copy    = vector3Methods.copy
quaternionMethods.copy = vector3Methods.copy

vector3Methods.magnitude = function(self)
    local magnitude, idx = 0, 0
    while idx < #self do
        idx = idx + 1
        magnitude = magnitude + (self[idx] ^ 2)
    end
    return math.sqrt(magnitude)
end
vector4Methods.magnitude    = vector3Methods.magnitude
quaternionMethods.magnitude = vector3Methods.magnitude

vector3Methods.normalized = function(self)
    return self / self:magnitude()
end
vector4Methods.normalized    = vector3Methods.normalized
quaternionMethods.normalized = vector3Methods.normalized

vector3Methods.dotProduct = function(self, other)
    if getmetatable(self) ~= getmetatable(other) then
        error("both vectors must be of the same type", 3)
    end
    local sum, idx = 0, 0
    while idx < #self do
        idx = idx + 1
        sum = sum + self[idx] * other[idx]
    end
    return sum
end
vector4Methods.dotProduct    = vector3Methods.dotProduct
quaternionMethods.dotProduct = vector3Methods.dotProduct

-- vector3 only methods

vector3Methods.crossProduct = function(self, other)
    if getmetatable(self) ~= getmetatable(other) then
        error("both vectors must be of the same type", 3)
    end
    return module.vector3{
        self[2] * other[3] - self[3] * other[2],
        self[3] * other[1] - self[1] * other[3],
        self[1] * other[2] - self[2] * other[1],
    }
end

vector3Methods.pureQuaternion = function(self)
    return module.quaternion{ 0, self.x, self.y, self.z }
end

-- quaternion only methods

quaternionMethods.product = function(self, other)
    if getmetatable(self) ~= getmetatable(other) then
        error("both vectors must be of the same type", 3)
    end
    local s1, s2 = self.r, other.r
    local v1, v2 = module.vector3{ self.ix, self.iy, self.iz }, module.vector3{ other.ix, other.iy, other.iz }

    local dot   = v1:dotProduct(v2)
    local cross = v1:crossProduct(v2)

    local v3 = v2 * s1 + v1 * s2 + cross
    return module.quaternion{ s1 * s2 - dot, v3.x, v3.y, v3.z }
end

quaternionMethods.conjugate = function(self)
    return module.quaternion{ self.r, -self.ix, -self.iy, -self.iz }
end

quaternionMethods.inverse = function(self)
    return self:conjugate() / (self:magnitude() ^ 2)
end

-- common metamethods

local common_mul = function(self, multiplicand)
    if type(self) == "number" then
        self, multiplicand = multiplicand, self
    end
    if type(multiplicand) ~= "number" then
        error("multiplicand must be a scaler", 3)
    end
    local answer = self:copy()
    for i = 1, #self, 1 do answer[i] = self[i] * multiplicand end
    return answer
end

local common_div = function(self, divisor)
    if type(divisor) == "number" then
        return self * (1 / divisor)
    else
        error("dividend cannot be a scaler", 3)
    end
end

local common_add = function(self, addend)
    if getmetatable(self) ~= getmetatable(addend) then
        error("both vectors must be of the same type", 3)
    end
    local answer = self:copy()
    for i = 1, #self, 1 do answer[i] = self[i] + addend[i] end
    return answer
end

local common_unm = function(self) return self * -1 end

local common_sub = function(self, subtrahend) return self + -subtrahend end

local common_eq = function(self, other)
    local result = (getmetatable(self) == getmetatable(other)) and (#self == #other)
    local idx = 0
    while result and idx < #self do
        idx = idx + 1
        result = self[idx] == other[idx]
    end
    return result
end

-- store these in the registry so we can easily set it both from Lua and from C functions

debug.getregistry()[USERDATA_TAG .. ".vector3"] = {
    __type     = USERDATA_TAG .. ".vector3",
    __name     = USERDATA_TAG .. ".vector3",
    __tostring = function(_)
        return string.format("[ x = %.4f, y = %.4f, z = %.4f ]", _.x, _.y, _.z)
    end,
    __index = function(self, key)
        if vector3Methods[key] then return vector3Methods[key]
        elseif key == 1 then return self.x
        elseif key == 2 then return self.y
        elseif key == 3 then return self.z
        else
            return nil
        end
    end,
    __newindex = function(self, key, value)
        if type(value) ~= "number" then error("value must be a number", 3) end
        if     key == 1 then self.x = value
        elseif key == 2 then self.y = value
        elseif key == 3 then self.z = value
        else
            error("invalid index", 3)
        end
    end,
    __len = function(self) return 3 end,
    __mul = common_mul,
    __div = common_div,
    __add = common_add,
    __unm = common_unm,
    __sub = common_sub,
    __eq  = common_eq,
}

debug.getregistry()[USERDATA_TAG .. ".vector4"] = {
    __type     = USERDATA_TAG .. ".vector4",
    __name     = USERDATA_TAG .. ".vector4",
    __tostring = function(_)
        return string.format("[ x = %.4f, y = %.4f, z = %.4f, w = %.4f ]", _.x, _.y, _.z, _.w)
    end,
    __index = function(self, key)
        if vector4Methods[key] then return vector4Methods[key]
        elseif key == 1 then return self.x
        elseif key == 2 then return self.y
        elseif key == 3 then return self.z
        elseif key == 4 then return self.w
        else
            return nil
        end
    end,
    __newindex = function(self, key, value)
        if type(value) ~= "number" then error("value must be a number", 3) end
        if     key == 1 then self.x = value
        elseif key == 2 then self.y = value
        elseif key == 3 then self.z = value
        elseif key == 4 then self.w = value
        else
            error("invalid index", 3)
        end
    end,
    __len = function(self) return 4 end,
    __mul = common_mul,
    __div = common_div,
    __add = common_add,
    __unm = common_unm,
    __sub = common_sub,
    __eq  = common_eq,
}

debug.getregistry()[USERDATA_TAG .. ".quaternion"] = {
    __type     = USERDATA_TAG .. ".quaternion",
    __name     = USERDATA_TAG .. ".quaternion",
    __tostring = function(_)
        return string.format("[ r = %.4f, ix = %.4f, iy = %.4f, iz = %.4f ]", _.r, _.ix, _.iy, _.iz)
    end,
    __index = function(self, key)
        if quaternionMethods[key] then return quaternionMethods[key]
        elseif key == 1 then return self.r
        elseif key == 2 then return self.ix
        elseif key == 3 then return self.iy
        elseif key == 4 then return self.iz
        else
            return nil
        end
    end,
    __newindex = function(self, key, value)
        if type(value) ~= "number" then error("value must be a number", 3) end
        if     key == 1 then self.r  = value
        elseif key == 2 then self.ix = value
        elseif key == 3 then self.iy = value
        elseif key == 4 then self.iz = value
        else
            error("invalid index", 3)
        end
    end,
    __len = function(self) return 4 end,
    __mul = function(self, multiplicand)
        if type(self) == "number" then
            self, multiplicand = multiplicand, self
        end
        if type(multiplicand) == "number" then
            return common_mul(self, multiplicand)
        elseif getmetatable(self) == getmetatable(multiplicand) then
            return self:product(multiplicand)
        else
            error("multiplicand must be a quaternion or scaler", 3)
        end
    end,
    __div = common_div,
    __add = common_add,
    __unm = common_unm,
    __sub = common_sub,
    __eq  = common_eq,
}

-- Public interface ------------------------------------------------------

local vector3MT    = hs.getObjectMetatable(USERDATA_TAG .. ".vector3")
local vector4MT    = hs.getObjectMetatable(USERDATA_TAG .. ".vector4")
local quaternionMT = hs.getObjectMetatable(USERDATA_TAG .. ".quaternion")

module.vector3 = function(...)
    local args = table.pack(...)
    if args.n == 1 and type(args[1]) == "table" then args = args[1] end
    local result = { x = 0/0, y = 0/0, z = 0/0 }
    if #args == 3 then
        result.x = args[1]
        result.y = args[2]
        result.z = args[3]
    elseif args.x and args.y and args.z then
        result.x = args.x
        result.y = args.y
        result.z = args.z
    else
        error("arguments not recognized as a valid vector3", 3)
    end
    if type(result.x) == "number" and type(result.y) == "number" and type(result.z) == "number" then
        return setmetatable(result, vector3MT)
    else
        error("vector members must be numbers")
    end
end

module.vector4 = function(...)
    local args = table.pack(...)
    if args.n == 1 and type(args[1]) == "table" then args = args[1] end
    local result = { x = 0/0, y = 0/0, z = 0/0, w = 0/0 }
    if #args == 4 then
        result.x = args[1]
        result.y = args[2]
        result.z = args[3]
        result.w = args[4]
    elseif args.x and args.y and args.z and args.w then
        result.x = args.x
        result.y = args.y
        result.z = args.z
        result.w = args.w
    else
        error("arguments not recognized as a valid vector4", 3)
    end
    if type(result.x) == "number" and type(result.y) == "number" and type(result.z) == "number" and type(result.w) == "number" then
        return setmetatable(result, vector4MT)
    else
        error("vector members must be numbers")
    end
end

module.quaternion = function(...)
    local args = table.pack(...)
    if args.n == 1 and type(args[1]) == "table" then args = args[1] end
    local result = { ix = 0/0, iy = 0/0, iz = 0/0, r = 0/0 }
--     print(#args, inspect(args, { newline = " ", indent = "" }))
    if #args == 4 then
        result.r  = args[1]
        result.ix = args[2]
        result.iy = args[3]
        result.iz = args[4]
    elseif args.ix and args.iy and args.iz and args.r then
        result.r  = args.r
        result.ix = args.ix
        result.iy = args.iy
        result.iz = args.iz
    else
        error("arguments not recognized as a valid quaternion", 3)
    end
    if type(result.ix) == "number" and type(result.iy) == "number" and type(result.iz) == "number" and type(result.r) == "number" then
        return setmetatable(result, quaternionMT)
    else
        error("vector members must be numbers")
    end
end

module.new = function(...)
    local args = table.pack(...)
    if args.n == 1 and type(args[1]) == "table" then args = args[1] end

    if #args == 3 or (#args == 0 and args.x and args.y and args.z) then                -- vector3
        return module.vector3(...)
    elseif args.r and args.ix and args.iy and args.iz then                             -- quaternion
        return module.quaternion(...)
    elseif #args == 4 or (#args == 0 and args.x and args.y and args.z and args.w) then -- vector4
        return module.vector4(...)
    else
        error("arguments not recognized as a valid vector3, vector4, or quaternion", 3)
    end
end

module.unitX = function() return module.vector3(1, 0, 0) end

module.unitY = function() return module.vector3(0, 1, 0) end

module.unitZ = function() return module.vector3(0, 0, 1) end

module.quaternionIdentity = function() return module.quaternion(1, 0, 0, 0) end

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
    __call = function(self, ...) return module.new(...) end,
})
