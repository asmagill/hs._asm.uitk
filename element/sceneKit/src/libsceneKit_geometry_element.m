@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.geometry.element" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *PRIMITIVE_TYPES ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    PRIMITIVE_TYPES = @{
        @"line"          : @(SCNGeometryPrimitiveTypeLine),
        @"point"         : @(SCNGeometryPrimitiveTypePoint),
        @"polygon"       : @(SCNGeometryPrimitiveTypePolygon),
        @"triangles"     : @(SCNGeometryPrimitiveTypeTriangles),
        @"triangleStrip" : @(SCNGeometryPrimitiveTypeTriangleStrip),
    } ;
}

@interface SCNGeometryElement (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation SCNGeometryElement (HammerspoonAdditions)

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

// + (instancetype)geometryElementWithData:(NSData *)data primitiveType:(SCNGeometryPrimitiveType)primitiveType primitiveCount:(NSInteger)primitiveCount bytesPerIndex:(NSInteger)bytesPerIndex;

#pragma mark - Module Methods -

static int element_data(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNGeometryElement *element = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:element.data] ;
    return 1 ;
}

static int element_bytesPerIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNGeometryElement *element = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, element.bytesPerIndex) ;
    return 1 ;
}

static int element_primitiveCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNGeometryElement *element = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, element.primitiveCount) ;
    return 1 ;
}

static int element_primitiveType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNGeometryElement *element = [skin toNSObjectAtIndex:1] ;

    NSArray  *keys   = [PRIMITIVE_TYPES allKeysForObject:@(element.primitiveType)] ;
    NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", element.primitiveType] ;
    [skin pushNSObject:answer] ;
    return 1 ;
}

static int element_maximumPointScreenSpaceRadius(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometryElement *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.maximumPointScreenSpaceRadius) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value <= 0.0) return luaL_argerror(L, 2, "must be greater than zero") ;
        element.maximumPointScreenSpaceRadius = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int element_minimumPointScreenSpaceRadius(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometryElement *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.minimumPointScreenSpaceRadius) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value <= 0.0) return luaL_argerror(L, 2, "must be greater than zero") ;
        element.minimumPointScreenSpaceRadius = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int element_pointSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometryElement *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.pointSize) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value <= 0.0) return luaL_argerror(L, 2, "must be greater than zero") ;
        element.pointSize = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int element_primitiveRange(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TNIL | LS_TTABLE | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    SCNGeometryElement *element = [skin toNSObjectAtIndex:1] ;

    NSUInteger loc = (NSUInteger)NSNotFound ;
    NSUInteger len = 0 ;
    if (lua_gettop(L) == 1) {
        NSRange range = element.primitiveRange ;
        if (range.location == NSNotFound && range.length == 0) {
            range.location = 0 ;
            range.length   = (NSUInteger)element.primitiveCount ;
        }
        lua_newtable(L) ;
        lua_pushinteger(L, (NSInteger)range.location + 1) ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushinteger(L, (NSInteger)(range.location + range.length)) ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    } else {
        if (lua_gettop(L) == 2) {
            [skin checkArgs:LS_TANY, LS_TNIL | LS_TTABLE, LS_TBREAK] ;
            if (lua_type(L, 2) == LUA_TTABLE) {
                if (lua_rawlen(L, 2) != 2) return luaL_argerror(L, 2, "expected table of two integer indices") ;
                lua_rawgeti(L, 2, 1) ;
                lua_rawgeti(L, 2, 2) ;
                if (!(lua_isinteger(L, -2) && lua_isinteger(L, -1))) return luaL_argerror(L, 2, "expected table of two integer indices") ;
                loc = (NSUInteger)(lua_tointeger(L, -2)) - 1 ;
                len = (NSUInteger)(lua_tointeger(L, -1)) - loc ;
                lua_pop(L, 2) ;
            }
        }
        if (lua_gettop(L) == 3) {
            [skin checkArgs:LS_TANY, LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;
            loc = (NSUInteger)(lua_tointeger(L, 2)) - 1 ;
            len = (NSUInteger)(lua_tointeger(L, 3)) - loc ;
        }

        if (loc != (NSUInteger)NSNotFound && (loc + len) > (NSUInteger)element.primitiveCount)
            return luaL_argerror(L, 2, "indices out of bounds") ;

        element.primitiveRange = NSMakeRange(loc, len) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNGeometryElement(lua_State *L, id obj) {
    SCNGeometryElement *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNGeometryElement *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNGeometryElement(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNGeometryElement *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNGeometryElement, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNGeometryElement *obj = [skin luaObjectAtIndex:1 toClass:"SCNGeometryElement"] ;

    NSArray  *keys  = [PRIMITIVE_TYPES allKeysForObject:@(obj.primitiveType)] ;
    NSString *title = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", obj.primitiveType] ;

    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
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
    SCNGeometryElement *obj  = get_objectFromUserdata(__bridge_transfer SCNGeometryElement, L, 1, USERDATA_TAG) ;

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
    {"data",                 element_data},
    {"bytesPerIndex",        element_bytesPerIndex},
    {"primitiveCount",       element_primitiveCount},
    {"primitiveType",        element_primitiveType},

    {"maxPointScreenRadius", element_maximumPointScreenSpaceRadius},
    {"minPointScreenRadius", element_minimumPointScreenSpaceRadius},
    {"pointSize",            element_pointSize},
    {"primitiveRange",       element_primitiveRange},

    {"__tostring",           userdata_tostring},
    {"__eq",                 userdata_eq},
    {"__gc",                 userdata_gc},
    {NULL,                   NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libsceneKit_geometry_element(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushSCNGeometryElement  forClass:"SCNGeometryElement"];
    [skin registerLuaObjectHelper:toSCNGeometryElement forClass:"SCNGeometryElement"
                                            withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"maxPointScreenRadius",
        @"minPointScreenRadius",
        @"pointSize",
        @"primitiveRange",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    [skin pushNSObject:@[
        @"bytesPerIndex",
        @"primitiveCount",
        @"primitiveType",
    ]] ;
    lua_setfield(L, -2, "_readOnlyAdditions") ;
    lua_pushboolean(L, NO) ; lua_setfield(L, -2, "_subclass") ;
    lua_pop(L, 1) ;

    return 1;
}
