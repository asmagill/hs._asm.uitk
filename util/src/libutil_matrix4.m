@import Cocoa ;
@import LuaSkin ;
@import SceneKit ;

static const char * const USERDATA_TAG = "hs._asm.uitk.util.matrix4" ;
static LSRefTable         refTable     = LUA_NOREF ;

// #define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

// NOTE: Copy these two where needed
//       As SCNMatrix4 is a structure and not an object, the current LuaSkin's helper
//       support can't help us -- we'll need to replicate these two functions in every
//       submodule that requires SCNMatrix4 support.

static int pushSCNMatrix4(lua_State *L, SCNMatrix4 matrix4) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
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
    luaL_getmetatable(L, "hs._asm.uitk.util.matrix4" ) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static SCNMatrix4 toSCNMatrix4(lua_State *L, int idx) {
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
        [skin logError:[NSString stringWithFormat:@"expected SCNMatrix4 table, found %s",
                                                  lua_typename(L, lua_type(L, idx))]] ;
    }

    return matrix4 ;
}

#pragma mark - Module Functions -

/// hs._asm.uitk.util.matrix4.identity() -> matrix4Object
/// Constructor
/// Specifies the identity matrix4.  Resets all existing transformations when applied as a method to an existing matrix4Object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the 4x4 identity matrix.
///
/// Notes:
///  * The identity matrix4 can be thought of as "apply no transformations at all" or "render as specified".
///  * Mathematically this is represented as:
/// ~~~
/// [ 1,  0,  0, 0 ]
/// [ 0,  1,  0, 0 ]
/// [ 0,  0,  1, 0 ]
/// [ 0,  0,  0, 1 ]
/// ~~~
static int matrix4_identity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL,
                    LS_TBREAK] ;
    pushSCNMatrix4(L, SCNMatrix4Identity) ;
    return 1;
}

#pragma mark - Module Methods -

/// hs._asm.uitk.util.matrix4:invert() -> matrix4Object
/// Method
/// Generates the mathematical inverse of the matrix.  This method cannot be used as a constructor.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the inverted matrix, or the original matrix if it is not invertible.
///
/// Notes:
///  * Inverting a matrix which represents a series of transformations has the effect of reversing or undoing the original transformations.
static int matrix4_invert(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;

    SCNMatrix4 matrix4 = toSCNMatrix4(L, 1) ;
    return pushSCNMatrix4(L, SCNMatrix4Invert(matrix4)) ;
}

/// hs._asm.uitk.util.matrix4:append(matrix) -> matrix4Object
/// Method
/// Appends the specified matrix transformations to the matrix and returns the new matrix.  This method cannot be used as a constructor.
///
/// Parameters:
///  * `matrix` - the table to append to the current matrix.
///
/// Returns:
///  * the new matrix
///
/// Notes:
///  * Mathematically this method multiples the original matrix by the new one and returns the result of the multiplication.
///  * You can use this method to "stack" additional transformations on top of existing transformations, without having to know what the existing transformations in effect are.
static int matrix4_append(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TTABLE, LS_TBREAK] ;

    SCNMatrix4 matrixA = toSCNMatrix4(L, 1) ;
    SCNMatrix4 matrixB = toSCNMatrix4(L, 2) ;
    return pushSCNMatrix4(L, SCNMatrix4Mult(matrixA, matrixB)) ;
}

/// hs._asm.uitk.util.matrix4:prepend(matrix) -> matrix4Object
/// Method
/// Prepends the specified matrix transformations to the matrix and returns the new matrix.  This method cannot be used as a constructor.
///
/// Parameters:
///  * `matrix` - the table to append to the current matrix.
///
/// Returns:
///  * the new matrix
///
/// Notes:
///  * Mathematically this method multiples the new matrix by the original one and returns the result of the multiplication.
///  * You can use this method to apply a transformation *before* the currently applied transformations, without having to know what the existing transformations in effect are.
static int matrix4_prepend(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TTABLE, LS_TBREAK] ;

    SCNMatrix4 matrixA = toSCNMatrix4(L, 1) ;
    SCNMatrix4 matrixB = toSCNMatrix4(L, 2) ;
    return pushSCNMatrix4(L, SCNMatrix4Mult(matrixB, matrixA)) ;
}

/// hs._asm.uitk.util.matrix4:rotate(radians, x, y, z) -> matrix4Object
/// Method
/// Applies a rotation of the specified number of radians to the matrix.  This method can be used as a constructor or a method.
///
/// Parameters:
///  * `radians` - the amount of rotation, in radians, measured counterclockwise around the rotation axis.
///  * `x`       - the x-component of the rotation axis
///  * `y`       - the y-component of the rotation axis
///  * `z`       - the z-component of the rotation axis
///
/// Returns:
///  * the new matrix
static int matrix4_rotate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    if (lua_type(L, 1) == LUA_TTABLE) {
        [skin checkArgs:LS_TTABLE, LS_TNUMBER, LS_TNUMBER, LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;
        SCNMatrix4 matrix4 = toSCNMatrix4(L, 1) ;
        CGFloat angle = lua_tonumber(L, 2) ;
        CGFloat x     = lua_tonumber(L, 3) ;
        CGFloat y     = lua_tonumber(L, 4) ;
        CGFloat z     = lua_tonumber(L, 5) ;
        return pushSCNMatrix4(L, SCNMatrix4Rotate(matrix4, angle, x, y, z)) ;
    } else {
        [skin checkArgs:LS_TNUMBER, LS_TNUMBER, LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;
        CGFloat angle = lua_tonumber(L, 1) ;
        CGFloat x     = lua_tonumber(L, 2) ;
        CGFloat y     = lua_tonumber(L, 3) ;
        CGFloat z     = lua_tonumber(L, 4) ;
        return pushSCNMatrix4(L, SCNMatrix4MakeRotation(angle, x, y, z)) ;
    }
}

/// hs._asm.uitk.util.matrix4:scale(sX, sY, sZ) -> matrix4Object
/// Method
/// Applies a scaling transformation to the matrix.  This method can be used as a constructor or a method.
///
/// Parameters:
///  * `sX` - the scale factor in the x-axis direction
///  * `sY` - the scale factor in the y-axis direction
///  * `sZ` - the scale factor in the z-axis direction
///
/// Returns:
///  * the new matrix
static int matrix4_scale(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    if (lua_type(L, 1) == LUA_TTABLE) {
        [skin checkArgs:LS_TTABLE, LS_TNUMBER, LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;
        SCNMatrix4 matrix4 = toSCNMatrix4(L, 1) ;
        CGFloat sX = lua_tonumber(L, 2) ;
        CGFloat sY = lua_tonumber(L, 3) ;
        CGFloat sZ = lua_tonumber(L, 4) ;
        return pushSCNMatrix4(L, SCNMatrix4Scale(matrix4, sX, sY, sZ)) ;
    } else {
        [skin checkArgs:LS_TNUMBER, LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;
        CGFloat sX = lua_tonumber(L, 1) ;
        CGFloat sY = lua_tonumber(L, 2) ;
        CGFloat sZ = lua_tonumber(L, 3) ;
        return pushSCNMatrix4(L, SCNMatrix4MakeScale(sX, sY, sZ)) ;
    }
}

/// hs._asm.uitk.util.matrix4:translate(tX, tY, tZ) -> matrix4Object
/// Method
/// Applies a translation transformation to the matrix.  This method can be used as a constructor or a method.
///
/// Parameters:
///  * `tX` - the translation distance in the x-axis direction
///  * `tY` - the translation distance in the y-axis direction
///  * `tZ` - the translation distance in the z-axis direction
///
/// Returns:
///  * the new matrix
static int matrix4_translate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    if (lua_type(L, 1) == LUA_TTABLE) {
        [skin checkArgs:LS_TTABLE, LS_TNUMBER, LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;
        SCNMatrix4 matrix4 = toSCNMatrix4(L, 1) ;
        CGFloat tX = lua_tonumber(L, 2) ;
        CGFloat tY = lua_tonumber(L, 3) ;
        CGFloat tZ = lua_tonumber(L, 4) ;
        return pushSCNMatrix4(L, SCNMatrix4Translate(matrix4, tX, tY, tZ)) ;
    } else {
        [skin checkArgs:LS_TNUMBER, LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;
        CGFloat tX = lua_tonumber(L, 1) ;
        CGFloat tY = lua_tonumber(L, 2) ;
        CGFloat tZ = lua_tonumber(L, 3) ;
        return pushSCNMatrix4(L, SCNMatrix4MakeTranslation(tX, tY, tZ)) ;
    }
}

/// hs._asm.uitk.util.matrix4:isIdentity() -> boolean
/// Method
/// Returns a boolean indicating whether or not the matrix is the identity matrix.
///
/// Parameters:
///  * None
///
/// Returns:
///  * true if the matrix is equal to the identity matrix, otherwise false.
///
/// Notes:
///  * see also [hs._asm.uitk.util.matrix4.identity](#identity)
static int matrix4_isIdentity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;

    SCNMatrix4 matrix4 = toSCNMatrix4(L, 1) ;
    lua_pushboolean(L, SCNMatrix4IsIdentity(matrix4)) ;
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_eq(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    if (lua_type(L, 1) == LUA_TTABLE && lua_type(L, 2) == LUA_TTABLE) {
        SCNMatrix4 matrixA = toSCNMatrix4(L, 1) ;
        SCNMatrix4 matrixB = toSCNMatrix4(L, 2) ;
        lua_pushboolean(L, SCNMatrix4EqualToMatrix4(matrixA, matrixB)) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"identity",   matrix4_identity},
    {"invert",     matrix4_invert},
    {"append",     matrix4_append},
    {"prepend",    matrix4_prepend},
    {"isIdentity", matrix4_isIdentity},
    {"rotate",     matrix4_rotate},
    {"translate",  matrix4_translate},
    {"scale",      matrix4_scale},

    {"__eq",      userdata_eq},
    {NULL,        NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_libutil_matrix4(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibrary:USERDATA_TAG
                           functions:moduleLib
                       metaFunctions:NULL] ; // or module_metaLib

    return 1;
}
