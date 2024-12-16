@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.geometry.cone" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

@interface SCNCone (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation SCNCone (HammerspoonAdditions)

+ (instancetype)coneWithName:(NSString *)name topRadius:(CGFloat)topRadius
                                           bottomRadius:(CGFloat)bottomRadius
                                                 height:(CGFloat)height {
    SCNCone *cone = [SCNCone coneWithTopRadius:topRadius bottomRadius:bottomRadius height:height] ;

    if (cone) {
        cone.callbackRef  = LUA_NOREF ;
        cone.selfRefCount = 0 ;
        cone.name         = name ;
    }
    return cone ;
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

static int cone_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK | LS_TVARARG] ;
    NSString *name       = [[NSUUID UUID] UUIDString] ;
    int      numericArgs = 1 ;

    if (lua_type(L, 1) == LUA_TSTRING) {
        [skin checkArgs:LS_TSTRING, LS_TNUMBER, LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;
        name        = [skin toNSObjectAtIndex:1] ;
        numericArgs = 2 ;
    } else {
        [skin checkArgs:LS_TNUMBER, LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;
    }

    CGFloat topRadius    = lua_tonumber(L, numericArgs++) ;
    CGFloat bottomRadius = lua_tonumber(L, numericArgs++) ;
    CGFloat height       = lua_tonumber(L, numericArgs) ;

    SCNCone *cone = [SCNCone coneWithName:name topRadius:topRadius bottomRadius:bottomRadius height:height] ;
    if (cone) {
        [skin pushNSObject:cone] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int cone_topRadius(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCone *cone = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, cone.topRadius) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        cone.topRadius = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int cone_bottomRadius(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCone *cone = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, cone.bottomRadius) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        cone.bottomRadius = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int cone_height(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCone *cone = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, cone.height) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        cone.height = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int cone_heightSegmentCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCone *cone = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, cone.heightSegmentCount) ;
    } else {
        lua_Integer value = lua_tointeger(L, 2) ;
        if (value < 1) return luaL_argerror(L, 2, "must be 1 or greater") ;
        cone.heightSegmentCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int cone_radialSegmentCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCone *cone = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, cone.radialSegmentCount) ;
    } else {
        lua_Integer value = lua_tointeger(L, 2) ;
        if (value < 3) return luaL_argerror(L, 2, "must be 3 or greater") ;
        cone.radialSegmentCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNCone(lua_State *L, id obj) {
    SCNCone *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNCone *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNCone(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNCone *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNCone, L, idx, USERDATA_TAG) ;
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
    {"topRadius",      cone_topRadius},
    {"bottomRadius",   cone_bottomRadius},
    {"height",         cone_height},
    {"heightSegments", cone_heightSegmentCount},
    {"radialSegments", cone_radialSegmentCount},

    // inherits metamethods from geometry
    {NULL,             NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", cone_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libsceneKit_geometry_cone(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushSCNCone  forClass:"SCNCone"];
    [skin registerLuaObjectHelper:toSCNCone forClass:"SCNCone"
                                 withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"topRadius",
        @"bottomRadius",
        @"height",
        @"heightSegments",
        @"radialSegments",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_subclass") ;
    lua_pop(L, 1) ;

    return 1;
}
