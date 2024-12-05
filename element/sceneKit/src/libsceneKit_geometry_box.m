@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.geometry.box" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
}

@interface SCNBox (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation SCNBox (HammerspoonAdditions)

+ (instancetype)boxWithName:(NSString *)name width:(CGFloat)width
                                            height:(CGFloat)height
                                            length:(CGFloat)length
                                     chamferRadius:(CGFloat)chamferRadius {

    SCNBox *box = [SCNBox boxWithWidth:width height:height length:length chamferRadius:chamferRadius] ;

    if (box) {
        box.callbackRef  = LUA_NOREF ;
        box.selfRefCount = 0 ;
        box.name         = name ;
    }
    return box ;
}

- (void)setCallbackRef:(int)value {
    NSNumber *valueWrapper = [NSNumber numberWithInt:value];
    objc_setAssociatedObject(self, CALLBACKREF_KEY, valueWrapper, OBJC_ASSOCIATION_RETAIN);
}

- (int)callbackRef {
    NSNumber *valueWrapper = objc_getAssociatedObject(self, CALLBACKREF_KEY) ;
    if (!valueWrapper) {
        [self setCallbackRef:LUA_NOREF] ;
        valueWrapper = @(LUA_NOREF) ;
    }
    return valueWrapper.intValue ;
}

- (void)setSelfRefCount:(int)value {
    NSNumber *valueWrapper = [NSNumber numberWithInt:value];
    objc_setAssociatedObject(self, SELFREFCOUNT_KEY, valueWrapper, OBJC_ASSOCIATION_RETAIN);
}

- (int)selfRefCount {
    NSNumber *valueWrapper = objc_getAssociatedObject(self, SELFREFCOUNT_KEY) ;
    if (!valueWrapper) {
        [self setSelfRefCount:0] ;
        valueWrapper = @(0) ;
    }
    return valueWrapper.intValue ;
}

- (int)refTable {
    return refTable ;
}
@end

#pragma mark - Module Functions -

static int box_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK | LS_TVARARG] ;
    NSString *name       = [[NSUUID UUID] UUIDString] ;
    int      numericArgs = 1 ;

    if (lua_type(L, 1) == LUA_TSTRING) {
        [skin checkArgs:LS_TSTRING, LS_TNUMBER, LS_TNUMBER, LS_TNUMBER, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
        name        = [skin toNSObjectAtIndex:1] ;
        numericArgs = 2 ;
    } else {
        [skin checkArgs:LS_TNUMBER, LS_TNUMBER, LS_TNUMBER, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    }

    CGFloat width   = lua_tonumber(L, numericArgs++) ;
    CGFloat height  = lua_tonumber(L, numericArgs++) ;
    CGFloat length  = lua_tonumber(L, numericArgs++) ;
    CGFloat chamfer = (lua_gettop(L) == numericArgs) ? lua_tonumber(L, numericArgs) : 0.0 ;

    if (width <= 0.0)  return luaL_argerror(L, numericArgs - 3, "width must be larger than zero") ;
    if (height <= 0.0) return luaL_argerror(L, numericArgs - 2, "height must be larger than zero") ;
    if (length <= 0.0) return luaL_argerror(L, numericArgs - 1, "length must be larger than zero") ;
    if (chamfer < 0.0) return luaL_argerror(L, numericArgs,     "chamfer cannot be negative") ;

    SCNBox *box = [SCNBox boxWithName:name width:width height:height length:length chamferRadius:chamfer] ;
    if (box) {
        [skin pushNSObject:box] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int box_chamferRadius(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, box.chamferRadius) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) {
            return luaL_argerror(L, 2, "cannot be negative") ;
        }
        box.chamferRadius = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int box_width(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, box.width) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value <= 0.0) {
            return luaL_argerror(L, 2, "must be larger than zero") ;
        }
        box.width = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int box_height(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, box.height) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value <= 0.0) {
            return luaL_argerror(L, 2, "must be larger than zero") ;
        }
        box.height = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int box_length(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, box.length) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value <= 0.0) {
            return luaL_argerror(L, 2, "must be larger than zero") ;
        }
        box.length = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int box_chamferSegmentCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, box.chamferSegmentCount) ;
    } else {
        lua_Integer value = lua_tointeger(L, 2) ;
        if (value < 1) {
            return luaL_argerror(L, 2, "must be 1 or greater") ;
        }
        box.chamferSegmentCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int box_widthSegmentCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, box.widthSegmentCount) ;
    } else {
        lua_Integer value = lua_tointeger(L, 2) ;
        if (value < 1) {
            return luaL_argerror(L, 2, "must be 1 or greater") ;
        }
        box.widthSegmentCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int box_heightSegmentCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, box.heightSegmentCount) ;
    } else {
        lua_Integer value = lua_tointeger(L, 2) ;
        if (value < 1) {
            return luaL_argerror(L, 2, "must be 1 or greater") ;
        }
        box.heightSegmentCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int box_lengthSegmentCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, box.lengthSegmentCount) ;
    } else {
        lua_Integer value = lua_tointeger(L, 2) ;
        if (value < 1) {
            return luaL_argerror(L, 2, "must be 1 or greater") ;
        }
        box.lengthSegmentCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNBox(lua_State *L, id obj) {
    SCNBox *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNBox *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNBox(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNBox *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNBox, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"chamferRadius",   box_chamferRadius},
    {"width",           box_width},
    {"height",          box_height},
    {"length",          box_length},
    {"chamferSegments", box_chamferSegmentCount},
    {"widthSegments",   box_widthSegmentCount},
    {"heightSegments",  box_heightSegmentCount},
    {"lengthSegments",  box_lengthSegmentCount},

    // inherits metamethods from geometry
    {NULL,              NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", box_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libsceneKit_geometry_box(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushSCNBox  forClass:"SCNBox"];
    [skin registerLuaObjectHelper:toSCNBox forClass:"SCNBox"
                                withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"chamferRadius",
        @"width",
        @"height",
        @"length",
        @"chamferSegments",
        @"widthSegments",
        @"heightSegments",
        @"lengthSegments",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_subclass") ;
    lua_pop(L, 1) ;

    return 1;
}
