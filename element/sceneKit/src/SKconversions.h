#pragma once

@import SceneKit ;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"

// TODO: create util module for these datatypes?

static int pushSCNMatrix4(lua_State *L, SCNMatrix4 matrix4) {
    lua_newtable(L) ;
      lua_pushnumber(L, matrix4.m11) ; lua_setfield(L, -2, "m11") ;
      lua_pushnumber(L, matrix4.m12) ; lua_setfield(L, -2, "m12") ;
      lua_pushnumber(L, matrix4.m13) ; lua_setfield(L, -2, "m13") ;
      lua_pushnumber(L, matrix4.m14) ; lua_setfield(L, -2, "m14") ;
      lua_pushnumber(L, matrix4.m21) ; lua_setfield(L, -2, "m21") ;
      lua_pushnumber(L, matrix4.m22) ; lua_setfield(L, -2, "m22") ;
      lua_pushnumber(L, matrix4.m23) ; lua_setfield(L, -2, "m23") ;
      lua_pushnumber(L, matrix4.m24) ; lua_setfield(L, -2, "m24") ;
      lua_pushnumber(L, matrix4.m31) ; lua_setfield(L, -2, "m31") ;
      lua_pushnumber(L, matrix4.m32) ; lua_setfield(L, -2, "m32") ;
      lua_pushnumber(L, matrix4.m33) ; lua_setfield(L, -2, "m33") ;
      lua_pushnumber(L, matrix4.m34) ; lua_setfield(L, -2, "m34") ;
      lua_pushnumber(L, matrix4.m41) ; lua_setfield(L, -2, "m41") ;
      lua_pushnumber(L, matrix4.m42) ; lua_setfield(L, -2, "m42") ;
      lua_pushnumber(L, matrix4.m43) ; lua_setfield(L, -2, "m43") ;
      lua_pushnumber(L, matrix4.m44) ; lua_setfield(L, -2, "m44") ;
    luaL_getmetatable(L, "hs._asm.uitk.util.matrix4") ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static SCNMatrix4 pullSCNMatrix4(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNMatrix4 matrix4 = SCNMatrix4Identity ;

    if (lua_type(L, idx) == LUA_TTABLE) {
        idx = lua_absindex(L, idx) ;

        if (lua_getfield(L, idx, "m11") == LUA_TNUMBER) {
            matrix4.m11 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m11 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m11 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m12") == LUA_TNUMBER) {
            matrix4.m12 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m12 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m12 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m13") == LUA_TNUMBER) {
            matrix4.m13 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m13 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m13 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m14") == LUA_TNUMBER) {
            matrix4.m14 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m14 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m14 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;

        if (lua_getfield(L, idx, "m21") == LUA_TNUMBER) {
            matrix4.m21 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m21 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m21 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m22") == LUA_TNUMBER) {
            matrix4.m22 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m22 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m22 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m23") == LUA_TNUMBER) {
            matrix4.m23 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m23 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m23 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m24") == LUA_TNUMBER) {
            matrix4.m24 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m24 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m24 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;

        if (lua_getfield(L, idx, "m31") == LUA_TNUMBER) {
            matrix4.m31 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m31 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m31 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m32") == LUA_TNUMBER) {
            matrix4.m32 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m32 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m32 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m33") == LUA_TNUMBER) {
            matrix4.m33 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m33 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m33 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m34") == LUA_TNUMBER) {
            matrix4.m34 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m34 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m34 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;

        if (lua_getfield(L, idx, "m41") == LUA_TNUMBER) {
            matrix4.m41 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m41 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m41 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m42") == LUA_TNUMBER) {
            matrix4.m42 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m42 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m42 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m43") == LUA_TNUMBER) {
            matrix4.m43 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m43 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m43 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m44") == LUA_TNUMBER) {
            matrix4.m44 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m44 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m44 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected 4x4 matrix table, found %s",
                                                  lua_typename(L, lua_type(L, idx))]] ;
    }

    return matrix4 ;
}

static int pushSCNVector3(lua_State *L, SCNVector3 vector3) {
    lua_newtable(L) ;
      lua_pushnumber(L, vector3.x) ; lua_setfield(L, -2, "x") ;
      lua_pushnumber(L, vector3.y) ; lua_setfield(L, -2, "y") ;
      lua_pushnumber(L, vector3.z) ; lua_setfield(L, -2, "z") ;
    luaL_getmetatable(L, "hs._asm.uitk.util.vector.vector3") ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static SCNVector3 pullSCNVector3(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNVector3 vector3 = SCNVector3Zero ;

    if (lua_type(L, idx) == LUA_TTABLE) {
        idx = lua_absindex(L, idx) ;

        if (lua_getfield(L, idx, "x") == LUA_TNUMBER) {
            vector3.x = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"SCNVector3 field x is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "y") == LUA_TNUMBER) {
            vector3.y = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"SCNVector3 field y is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "z") == LUA_TNUMBER) {
            vector3.z = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"SCNVector3 field z is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected vector3 table, found %s",
                                                  lua_typename(L, lua_type(L, idx))]] ;
    }

    return vector3 ;
}

static int pushSCNVector4(lua_State *L, SCNVector4 vector4) {
    lua_newtable(L) ;
      lua_pushnumber(L, vector4.x) ; lua_setfield(L, -2, "x") ;
      lua_pushnumber(L, vector4.y) ; lua_setfield(L, -2, "y") ;
      lua_pushnumber(L, vector4.z) ; lua_setfield(L, -2, "z") ;
      lua_pushnumber(L, vector4.w) ; lua_setfield(L, -2, "w") ;
    luaL_getmetatable(L, "hs._asm.uitk.util.vector.vector4") ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static SCNVector4 pullSCNVector4(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNVector4 vector4 = SCNVector4Zero ;

    if (lua_type(L, idx) == LUA_TTABLE) {
        idx = lua_absindex(L, idx) ;

        if (lua_getfield(L, idx, "x") == LUA_TNUMBER) {
            vector4.x = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"SCNVector4 field x is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "y") == LUA_TNUMBER) {
            vector4.y = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"SCNVector4 field y is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "z") == LUA_TNUMBER) {
            vector4.z = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"SCNVector4 field z is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "w") == LUA_TNUMBER) {
            vector4.w = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"SCNVector4 field z is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected vector4 table, found %s",
                                                  lua_typename(L, lua_type(L, idx))]] ;
    }

    return vector4 ;
}

static int pushSCNQuaternion(lua_State *L, SCNQuaternion quaternion) {
    lua_newtable(L) ;
      lua_pushnumber(L, quaternion.x) ; lua_setfield(L, -2, "ix") ;
      lua_pushnumber(L, quaternion.y) ; lua_setfield(L, -2, "iy") ;
      lua_pushnumber(L, quaternion.z) ; lua_setfield(L, -2, "iz") ;
      lua_pushnumber(L, quaternion.w) ; lua_setfield(L, -2, "r") ;
    luaL_getmetatable(L, "hs._asm.uitk.util.vector.quaternion") ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static SCNQuaternion pullSCNQuaternion(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNQuaternion quaternion = SCNVector4Zero ;

    if (lua_type(L, idx) == LUA_TTABLE) {
        idx = lua_absindex(L, idx) ;

        if (lua_getfield(L, idx, "ix") == LUA_TNUMBER) {
            quaternion.x = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"SCNQuaternion field ix is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "iy") == LUA_TNUMBER) {
            quaternion.y = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"SCNQuaternion field iy is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "iz") == LUA_TNUMBER) {
            quaternion.z = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"SCNQuaternion field iz is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "r") == LUA_TNUMBER) {
            quaternion.w = lua_tonumber(L, -1) ;
        } else {
            [skin logError:@"SCNQuaternion field r is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected quaternion table, found %s",
                                                  lua_typename(L, lua_type(L, idx))]] ;
    }

    return quaternion ;
}

// NOTE: in case I ever switch to the simd versions

static int push_simd_float4x4(lua_State *L, simd_float4x4 matrix) {
    return pushSCNMatrix4(L, SCNMatrix4FromMat4(matrix)) ;
}

static simd_float4x4 pull_simd_float4x4(lua_State *L, int idx) {
    return SCNMatrix4ToMat4(pullSCNMatrix4(L, idx)) ;
}

static int push_simd_float3(lua_State *L, simd_float3 vector3) {
    return pushSCNVector3(L, SCNVector3FromFloat3(vector3)) ;
}

static simd_float3 pull_simd_float3(lua_State *L, int idx) {
    return SCNVector3ToFloat3(pullSCNVector3(L, idx)) ;
}

static int push_simd_float4(lua_State *L, simd_float4 vector4) {
    return pushSCNVector4(L, SCNVector4FromFloat4(vector4)) ;
}

static simd_float4 pull_simd_float4(lua_State *L, int idx) {
    return SCNVector4ToFloat4(pullSCNVector4(L, idx)) ;
}

static int push_simd_quatf(lua_State *L, simd_quatf quaternion) {
    return pushSCNQuaternion(L, SCNVector4FromFloat4(quaternion.vector)) ;
}

static simd_quatf pull_simd_quatf(lua_State *L, int idx) {
    return simd_quaternion(SCNVector4ToFloat4(pullSCNQuaternion(L, idx))) ;
}

#pragma clang diagnostic pop
