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

--- === hs._asm.uitk.util.matrix ===
---
--- A sub module to `hs._asm.uitk` which provides support for basic 4x4 matrix manipulations.
---
--- For mathematical reasons that are beyond the scope of this document, a 4x4 matrix4 can be used to represent a series of manipulations to be applied to the coordinates of a 3 dimensional object.  These manipulations can include one or more of a combination of translations, rotations, and scaling. This module represents the matrix as a lua table with the following keys: `m11`, `m12`, `m13`, `m14`, `m21`, `m22`, `m23`, `m24`, `m31`, `m32`, `m33`, `m34`, `m41`, `m42`, `m43`, and `m44`. For those of a mathematical bent, the 4x4 matrix4 used within this module can be visualized as follows:
---
---     [  m11,  m12,  m13,  m14  ]
---     [  m21,  m22,  m23,  m24  ]
---     [  m31,  m32,  m33,  m34  ]
---     [  m41,  m42,  m43,  m44  ]
---
--- This module allows you to generate the table which can represent one or more of the recognized transformations without having to understand the math behind the manipulations or specify the matrix4 values directly.
---
--- Many of the methods defined in this module can be used both as constructors and as methods chained to a previous method or constructor. Chaining the methods in this manner allows you to combine multiple transformations into one combined table which can then be assigned to an element in your canvas.

local USERDATA_TAG = "hs._asm.uitk.util.matrix4"
local uitk         = require("hs._asm.uitk")
local methods      = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libutil_"))

local vector       = uitk.util.vector

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

local module = {
    translate = methods.translate,
    rotate    = methods.rotate,
    scale     = methods.scale,
    identity  = methods.identity,
}

local matrixVectorProduct = function(mat, vec)
    local valid = (getmetatable(mat) or {}).__name == USERDATA_TAG and
                  (getmetatable(vec) or {}).__name == "hs._asm.uitk.util.vector.vector4"
    if valid then
        local ans = { 0, 0, 0, 0 }
        for i = 1, 4, 1 do
            for j = 1, 4, 1 do
                ans[i] = ans[i] + mat[i][j] * vec[j]
            end
        end
        return vector.vector4(ans)
    else
        error("product only valid between matrix4 and vector4", 3)
    end
end

local matrixRow = function(self, i)
    local newTable = {}
    return setmetatable(newTable, {
        __index = function(_, j)
            local key = "m" .. tostring(i) .. tostring(j)
            return self[key]
        end,
        __newindex = function(_, j, value)
            if math.type(j) == "integer" and j > 0 and j < 5 then
                if type(value) == "number" then
                    local key = "m" .. tostring(i) .. tostring(j)
                    self[key] = value
                else
                    error("value must be a number", 3)
                end
            else
                error("expected integer key between 1 and 4 inclusive", 3)
            end
        end,
        __tostring = function(_)
            local str = "[ "
            for j = 1, 4, 1 do
                local key = "m" .. tostring(i) .. tostring(j)
                print(key)
                str = str .. string.format("% 10.4f ", self[key])
            end
            str = str .. "]"
            return str
        end,
    })
end

-- store this in the registry so we can easily set it both from Lua and from C functions
debug.getregistry()[USERDATA_TAG] = {
    __type     = USERDATA_TAG,
    __name     = USERDATA_TAG,
    __index    = function(self, key)
        if methods[key] then
            return mathods[key]
        elseif math.type(key) == "integer" then
            if key < 1 or key > 4 then
                return nil
            else
                return matrixRow(self, key)
            end
        else
            return nil
        end
    end,
    __mul      = matrixVectorProduct,
    __tostring = function(_)
        return string.format(
            "[ % 10.4f % 10.4f % 10.4f % 10.4f ]\n" ..
            "[ % 10.4f % 10.4f % 10.4f % 10.4f ]\n" ..
            "[ % 10.4f % 10.4f % 10.4f % 10.4f ]\n" ..
            "[ % 10.4f % 10.4f % 10.4f % 10.4f ]",
            _.m11, _.m12, _.m13, _.m14,
            _.m21, _.m22, _.m23, _.m24,
            _.m31, _.m32, _.m33, _.m34,
            _.m41, _.m42, _.m43, _.m44
        )
    end,
}

-- Return Module Object --------------------------------------------------

return module
