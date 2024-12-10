@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.geometry.tessellator" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *PARTITION_MODE ;
static NSDictionary *SMOOTHING_MODE ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    PARTITION_MODE = @{
        @"pow2"           : @(MTLTessellationPartitionModePow2),
        @"integer"        : @(MTLTessellationPartitionModeInteger),
        @"fractionalOdd"  : @(MTLTessellationPartitionModeFractionalOdd),
        @"fractionalEven" : @(MTLTessellationPartitionModeFractionalEven),
    } ;

    SMOOTHING_MODE = @{
        @"none"        : @(SCNTessellationSmoothingModeNone),
        @"phong"       : @(SCNTessellationSmoothingModePhong),
        @"pnTriangles" : @(SCNTessellationSmoothingModePNTriangles),
    } ;
}

@interface SCNGeometryTessellator (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation SCNGeometryTessellator (HammerspoonAdditions)

- (instancetype)initTessellator {
    self = [self init] ;

    if (self) {
        self.callbackRef  = LUA_NOREF ;
        self.selfRefCount = 0 ;
    }
    return self ;
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

static int tessellator_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    SCNGeometryTessellator *tessellator = [[SCNGeometryTessellator alloc] initTessellator] ;
    if (tessellator) {
        [skin pushNSObject:tessellator] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int tessellator_adaptive(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometryTessellator *tessellator = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, tessellator.adaptive) ;
    } else {
        tessellator.adaptive = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tessellator_screenSpace(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometryTessellator *tessellator = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, tessellator.screenSpace) ;
    } else {
        tessellator.screenSpace = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// FIXME: need to see if this needs to be constrained (e.g. not negative)
static int tessellator_insideTessellationFactor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometryTessellator *tessellator = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, tessellator.insideTessellationFactor) ;
    } else {
        tessellator.insideTessellationFactor = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// FIXME: need to see if this needs to be constrained (e.g. not negative)
static int tessellator_maximumEdgeLength(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometryTessellator *tessellator = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, tessellator.maximumEdgeLength) ;
    } else {
        tessellator.maximumEdgeLength = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// FIXME: need to see if this needs to be constrained (e.g. not negative)
static int tessellator_tessellationFactorScale(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometryTessellator *tessellator = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, tessellator.tessellationFactorScale) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
//         if (value <= 0.0) return luaL_argerror(L, 2, "must be greater than zero") ;
        tessellator.tessellationFactorScale = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// FIXME: need to see if this needs to be constrained (e.g. not negative)
static int tessellator_edgeTessellationFactor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometryTessellator *tessellator = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, tessellator.edgeTessellationFactor) ;
    } else {
        tessellator.edgeTessellationFactor = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tessellator_tessellationPartitionMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometryTessellator *tessellator = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [PARTITION_MODE allKeysForObject:@(tessellator.tessellationPartitionMode)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", tessellator.tessellationPartitionMode] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = PARTITION_MODE[key] ;
        if (value) {
            tessellator.tessellationPartitionMode = value.unsignedLongLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [PARTITION_MODE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tessellator_smoothingMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometryTessellator *tessellator = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [SMOOTHING_MODE allKeysForObject:@(tessellator.smoothingMode)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", tessellator.smoothingMode] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = SMOOTHING_MODE[key] ;
        if (value) {
            tessellator.smoothingMode = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [SMOOTHING_MODE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNGeometryTessellator(lua_State *L, id obj) {
    SCNGeometryTessellator *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNGeometryTessellator *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNGeometryTessellator(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNGeometryTessellator *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNGeometryTessellator, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     SCNGeometryTessellator *obj = [skin luaObjectAtIndex:1 toClass:"SCNGeometryTessellator"] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if ((lua_type(L, 1) == LUA_TUSERDATA) && (lua_type(L, 2) == LUA_TUSERDATA)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        NSObject *obj1 = [skin toNSObjectAtIndex:1] ;
        NSObject *obj2 = [skin toNSObjectAtIndex:2];
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    SCNGeometryTessellator *obj  = get_objectFromUserdata(__bridge_transfer SCNGeometryTessellator, L, 1, USERDATA_TAG) ;

    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:obj.refTable ref:obj.callbackRef] ;
            obj = nil ;
        }
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"adaptive",                  tessellator_adaptive},
    {"screenSpace",               tessellator_screenSpace},
    {"insideTessellationFactor",  tessellator_insideTessellationFactor},
    {"edgeTessellationFactor",    tessellator_edgeTessellationFactor},
    {"maximumEdgeLength",         tessellator_maximumEdgeLength},
    {"tessellationFactorScale",   tessellator_tessellationFactorScale},
    {"tessellationPartitionMode", tessellator_tessellationPartitionMode},
    {"smoothingMode",             tessellator_smoothingMode},

    {"__tostring",                userdata_tostring},
    {"__eq",                      userdata_eq},
    {"__gc",                      userdata_gc},
    {NULL,                        NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", tessellator_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libsceneKit_geometry_tessellator(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushSCNGeometryTessellator  forClass:"SCNGeometryTessellator"];
    [skin registerLuaObjectHelper:toSCNGeometryTessellator forClass:"SCNGeometryTessellator"
                                                withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"adaptive",
        @"screenSpace",
        @"insideTessellationFactor",
        @"edgeTessellationFactor",
        @"maximumEdgeLength",
        @"tessellationFactorScale",
        @"tessellationPartitionMode",
        @"smoothingMode",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pushboolean(L, NO) ; lua_setfield(L, -2, "_subclass") ;
    lua_pop(L, 1) ;

    return 1;
}
