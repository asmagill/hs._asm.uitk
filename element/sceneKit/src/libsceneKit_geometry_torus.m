@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.geometry.torus" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

@interface SCNTorus (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation SCNTorus (HammerspoonAdditions)

+ (instancetype)torusWithName:(NSString *)name ringRadius:(CGFloat)ringRadius pipeRadius:(CGFloat)pipeRadius {
    SCNTorus *torus = [SCNTorus torusWithRingRadius:ringRadius pipeRadius:pipeRadius] ;

    if (torus) {
        torus.callbackRef  = LUA_NOREF ;
        torus.selfRefCount = 0 ;
        torus.name         = name ;
    }
    return torus ;
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

static int torus_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK | LS_TVARARG] ;
    NSString *name       = [[NSUUID UUID] UUIDString] ;
    int      numericArgs = 1 ;

    if (lua_type(L, 1) == LUA_TSTRING) {
        [skin checkArgs:LS_TSTRING, LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;
        name        = [skin toNSObjectAtIndex:1] ;
        numericArgs = 2 ;
    } else {
        [skin checkArgs:LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;
    }

    CGFloat ringRadius = lua_tonumber(L, numericArgs++) ;
    CGFloat pipeRadius = lua_tonumber(L, numericArgs) ;

    SCNTorus *torus = [SCNTorus torusWithName:name ringRadius:ringRadius pipeRadius:pipeRadius] ;
    if (torus) {
        [skin pushNSObject:torus] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int torus_ringRadius(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNTorus *torus = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, torus.ringRadius) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        torus.ringRadius = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int torus_pipeRadius(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNTorus *torus = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, torus.pipeRadius) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        torus.pipeRadius = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int torus_ringSegmentCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNTorus *torus = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, torus.ringSegmentCount) ;
    } else {
        lua_Integer value = lua_tointeger(L, 2) ;
        if (value < 3) return luaL_argerror(L, 2, "must be 3 or greater") ;
        torus.ringSegmentCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int torus_pipeSegmentCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNTorus *torus = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, torus.pipeSegmentCount) ;
    } else {
        lua_Integer value = lua_tointeger(L, 2) ;
        if (value < 3) return luaL_argerror(L, 2, "must be 3 or greater") ;
        torus.pipeSegmentCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNTorus(lua_State *L, id obj) {
    SCNTorus *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNTorus *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNTorus(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNTorus *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNTorus, L, idx, USERDATA_TAG) ;
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
    {"ringRadius",   torus_ringRadius},
    {"pipeRadius",   torus_pipeRadius},
    {"ringSegments", torus_ringSegmentCount},
    {"pipeSegments", torus_pipeSegmentCount},

    // inherits metamethods from geometry
    {NULL,           NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", torus_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libsceneKit_geometry_torus(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushSCNTorus  forClass:"SCNTorus"];
    [skin registerLuaObjectHelper:toSCNTorus forClass:"SCNTorus"
                                  withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"ringRadius",
        @"pipeRadius",
        @"ringSegments",
        @"pipeSegments",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_subclass") ;
    lua_pop(L, 1) ;

    return 1;
}
