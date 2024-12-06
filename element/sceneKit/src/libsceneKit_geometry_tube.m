@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.geometry.tube" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

@interface SCNTube (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation SCNTube (HammerspoonAdditions)

+ (instancetype)tubeWithName:(NSString *)name innerRadius:(CGFloat)innerRadius
                                              outerRadius:(CGFloat)outerRadius
                                                   height:(CGFloat)height {
    SCNTube *tube = [SCNTube tubeWithInnerRadius:innerRadius outerRadius:outerRadius height:height] ;

    if (tube) {
        tube.callbackRef  = LUA_NOREF ;
        tube.selfRefCount = 0 ;
        tube.name         = name ;
    }
    return tube ;
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

static int tube_new(lua_State *L) {
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

    CGFloat innerRadius = lua_tonumber(L, numericArgs++) ;
    CGFloat outerRadius = lua_tonumber(L, numericArgs++) ;
    CGFloat height      = lua_tonumber(L, numericArgs) ;
    if (innerRadius >= outerRadius) return luaL_argerror(L, numericArgs - 2, "outerRadius must be greater than innerRadius") ;
    if (innerRadius <= 0.0) return luaL_argerror(L, numericArgs - 2, "innerRadius must be larger than zero") ;
    if (outerRadius <= 0.0) return luaL_argerror(L, numericArgs - 1, "outerRadius must be larger than zero") ;
    if (height <= 0.0)      return luaL_argerror(L, numericArgs,     "height must be larger than zero") ;

    SCNTube *tube = [SCNTube tubeWithName:name innerRadius:innerRadius outerRadius:outerRadius height:height] ;
    if (tube) {
        [skin pushNSObject:tube] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int tube_innerRadius(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNTube *tube = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, tube.innerRadius) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0)               return luaL_argerror(L, 2, "cannot be negative") ;
        if (value >= tube.outerRadius) return luaL_argerror(L, 2, "cannot be equal to or greater than the outerRadius") ;
        tube.innerRadius = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tube_outerRadius(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNTube *tube = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, tube.outerRadius) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0)               return luaL_argerror(L, 2, "cannot be negative") ;
        if (value <= tube.innerRadius) return luaL_argerror(L, 2, "cannot be equal to or less than the innerRadius") ;
        tube.outerRadius = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tube_height(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNTube *tube = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, tube.height) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0)               return luaL_argerror(L, 2, "cannot be negative") ;
        tube.height = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tube_radialSegmentCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNTube *tube = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, tube.radialSegmentCount) ;
    } else {
        lua_Integer value = lua_tointeger(L, 2) ;
        if (value < 3) return luaL_argerror(L, 2, "must be 3 or greater") ;
        tube.radialSegmentCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tube_heightSegmentCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNTube *tube = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, tube.heightSegmentCount) ;
    } else {
        lua_Integer value = lua_tointeger(L, 2) ;
        if (value < 1) return luaL_argerror(L, 2, "must be 1 or greater") ;
        tube.heightSegmentCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNTube(lua_State *L, id obj) {
    SCNTube *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNTube *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNTube(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNTube *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNTube, L, idx, USERDATA_TAG) ;
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
    {"innerRadius",    tube_innerRadius},
    {"outerRadius",    tube_outerRadius},
    {"height",         tube_height},
    {"radialSegments", tube_radialSegmentCount},
    {"heightSegments", tube_heightSegmentCount},

    // inherits metamethods from geometry
    {NULL,             NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", tube_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libsceneKit_geometry_tube(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushSCNTube  forClass:"SCNTube"];
    [skin registerLuaObjectHelper:toSCNTube forClass:"SCNTube"
                                  withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"innerRadius",
        @"outerRadius",
        @"height",
        @"radialSegments",
        @"heightSegments",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_subclass") ;
    lua_pop(L, 1) ;

    return 1;
}
