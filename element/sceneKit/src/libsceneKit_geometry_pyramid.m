@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.geometry.pyramid" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

@interface SCNPyramid (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation SCNPyramid (HammerspoonAdditions)

+ (instancetype)pyramidWithName:(NSString *)name width:(CGFloat)width height:(CGFloat)height length:(CGFloat)length {
    SCNPyramid *pyramid = [SCNPyramid pyramidWithWidth:width height:height length:length] ;

    if (pyramid) {
        pyramid.callbackRef  = LUA_NOREF ;
        pyramid.selfRefCount = 0 ;
        pyramid.name         = name ;
    }
    return pyramid ;
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

static int pyramid_new(lua_State *L) {
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

    CGFloat width  = lua_tonumber(L, numericArgs++) ;
    CGFloat height = lua_tonumber(L, numericArgs++) ;
    CGFloat length = lua_tonumber(L, numericArgs) ;

    SCNPyramid *pyramid = [SCNPyramid pyramidWithName:name width:width height:height length:length] ;
    if (pyramid) {
        [skin pushNSObject:pyramid] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int pyramid_width(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNPyramid *pyramid = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, pyramid.width) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        pyramid.width = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int pyramid_height(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNPyramid *pyramid = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, pyramid.height) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        pyramid.height = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int pyramid_length(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNPyramid *pyramid = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, pyramid.length) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        pyramid.length = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int pyramid_widthSegmentCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNPyramid *pyramid = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, pyramid.widthSegmentCount) ;
    } else {
        lua_Integer value = lua_tointeger(L, 2) ;
        if (value < 1) return luaL_argerror(L, 2, "must be 1 or greater") ;
        pyramid.widthSegmentCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int pyramid_heightSegmentCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNPyramid *pyramid = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, pyramid.heightSegmentCount) ;
    } else {
        lua_Integer value = lua_tointeger(L, 2) ;
        if (value < 1) return luaL_argerror(L, 2, "must be 1 or greater") ;
        pyramid.heightSegmentCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int pyramid_lengthSegmentCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNPyramid *pyramid = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, pyramid.lengthSegmentCount) ;
    } else {
        lua_Integer value = lua_tointeger(L, 2) ;
        if (value < 1) return luaL_argerror(L, 2, "must be 1 or greater") ;
        pyramid.lengthSegmentCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNPyramid(lua_State *L, id obj) {
    SCNPyramid *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNPyramid *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNPyramid(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNPyramid *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNPyramid, L, idx, USERDATA_TAG) ;
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
    {"width",          pyramid_width},
    {"height",         pyramid_height},
    {"length",         pyramid_length},
    {"widthSegments",  pyramid_widthSegmentCount},
    {"heightSegments", pyramid_heightSegmentCount},
    {"lengthSegments", pyramid_lengthSegmentCount},

    // inherits metamethods from geometry
    {NULL,             NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", pyramid_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libsceneKit_geometry_pyramid(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushSCNPyramid  forClass:"SCNPyramid"];
    [skin registerLuaObjectHelper:toSCNPyramid forClass:"SCNPyramid"
                                    withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"width",
        @"height",
        @"length",
        @"widthSegments",
        @"heightSegments",
        @"lengthSegments",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_subclass") ;
    lua_pop(L, 1) ;

    return 1;
}
