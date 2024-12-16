@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.geometry.capsule" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

@interface SCNCapsule (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation SCNCapsule (HammerspoonAdditions)

+ (instancetype)capsuleWithName:(NSString *)name capRadius:(CGFloat)capRadius height:(CGFloat)height {
    SCNCapsule *capsule = [SCNCapsule capsuleWithCapRadius:capRadius height:height] ;

    if (capsule) {
        capsule.callbackRef  = LUA_NOREF ;
        capsule.selfRefCount = 0 ;
        capsule.name         = name ;
    }
    return capsule ;
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

static int capsule_new(lua_State *L) {
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

    CGFloat radius = lua_tonumber(L, numericArgs++) ;
    CGFloat height = lua_tonumber(L, numericArgs) ;

    SCNCapsule *capsule = [SCNCapsule capsuleWithName:name capRadius:radius height:height] ;
    if (capsule) {
        [skin pushNSObject:capsule] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int capsule_capRadius(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCapsule *capsule = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, capsule.capRadius) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        capsule.capRadius = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int capsule_height(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCapsule *capsule = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, capsule.height) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        capsule.height = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int capsule_capSegmentCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCapsule *capsule = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, capsule.capSegmentCount) ;
    } else {
        lua_Integer value = lua_tointeger(L, 2) ;
        if (value < 2) return luaL_argerror(L, 2, "must be 2 or greater") ;
        capsule.capSegmentCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int capsule_heightSegmentCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCapsule *capsule = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, capsule.heightSegmentCount) ;
    } else {
        lua_Integer value = lua_tointeger(L, 2) ;
        if (value < 1) return luaL_argerror(L, 2, "must be 1 or greater") ;
        capsule.heightSegmentCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int capsule_radialSegmentCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCapsule *capsule = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, capsule.radialSegmentCount) ;
    } else {
        lua_Integer value = lua_tointeger(L, 2) ;
        if (value < 3) return luaL_argerror(L, 2, "must be 3 or greater") ;
        capsule.radialSegmentCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNCapsule(lua_State *L, id obj) {
    SCNCapsule *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNCapsule *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNCapsule(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNCapsule *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNCapsule, L, idx, USERDATA_TAG) ;
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
    {"radius",         capsule_capRadius},
    {"height",         capsule_height},
    {"capSegments",    capsule_capSegmentCount},
    {"heightSegments", capsule_heightSegmentCount},
    {"radialSegments", capsule_radialSegmentCount},

    // inherits metamethods from geometry
    {NULL,             NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", capsule_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libsceneKit_geometry_capsule(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushSCNCapsule  forClass:"SCNCapsule"];
    [skin registerLuaObjectHelper:toSCNCapsule forClass:"SCNCapsule"
                                    withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"radius",
        @"height",
        @"capSegments",
        @"heightSegments",
        @"radialSegments",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_subclass") ;
    lua_pop(L, 1) ;

    return 1;
}
