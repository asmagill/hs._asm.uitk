@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.geometry.source" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *SOURCE_SEMANTICS ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    SOURCE_SEMANTICS = @{
        @"vertex"       : SCNGeometrySourceSemanticVertex,
        @"normal"       : SCNGeometrySourceSemanticNormal,
        @"texcoord"     : SCNGeometrySourceSemanticTexcoord,

        @"boneIndices"  : SCNGeometrySourceSemanticBoneIndices,
        @"boneWeights"  : SCNGeometrySourceSemanticBoneWeights,
        @"color"        : SCNGeometrySourceSemanticColor,
        @"edgeCrease"   : SCNGeometrySourceSemanticEdgeCrease,
        @"tangent"      : SCNGeometrySourceSemanticTangent,
        @"vertexCrease" : SCNGeometrySourceSemanticVertexCrease,
    } ;
}

@interface SCNGeometrySource (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation SCNGeometrySource (HammerspoonAdditions)

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

// + (instancetype)geometrySourceWithNormals:(const SCNVector3 *)normals count:(NSInteger)count;
// + (instancetype)geometrySourceWithTextureCoordinates:(const CGPoint *)texcoord count:(NSInteger)count;
// + (instancetype)geometrySourceWithVertices:(const SCNVector3 *)vertices count:(NSInteger)count;

// + (instancetype)geometrySourceWithData:(NSData *)data semantic:(SCNGeometrySourceSemantic)semantic vectorCount:(NSInteger)vectorCount floatComponents:(BOOL)floatComponents componentsPerVector:(NSInteger)componentsPerVector bytesPerComponent:(NSInteger)bytesPerComponent dataOffset:(NSInteger)offset dataStride:(NSInteger)stride;

#pragma mark - Module Methods -

static int source_floatComponents(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNGeometrySource *source = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, source.floatComponents) ;
    return 1 ;
}

static int source_data(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNGeometrySource *source = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:source.data] ;
    return 1 ;
}

static int source_bytesPerComponent(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNGeometrySource *source = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, source.bytesPerComponent) ;
    return 1 ;
}

static int source_componentsPerVector(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNGeometrySource *source = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, source.componentsPerVector) ;
    return 1 ;
}

static int source_dataOffset(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNGeometrySource *source = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, source.dataOffset) ;
    return 1 ;
}

static int source_dataStride(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNGeometrySource *source = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, source.dataStride) ;
    return 1 ;
}

static int source_vectorCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNGeometrySource *source = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, source.vectorCount) ;
    return 1 ;
}

static int source_semantic(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNGeometrySource *source = [skin toNSObjectAtIndex:1] ;

    NSArray  *keys   = [SOURCE_SEMANTICS allKeysForObject:source.semantic] ;
    NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %@", source.semantic] ;
    [skin pushNSObject:answer] ;
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNGeometrySource(lua_State *L, id obj) {
    SCNGeometrySource *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNGeometrySource *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNGeometrySource(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNGeometrySource *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNGeometrySource, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNGeometrySource *obj = [skin luaObjectAtIndex:1 toClass:"SCNGeometrySource"] ;

    NSArray  *keys  = [SOURCE_SEMANTICS allKeysForObject:obj.semantic] ;
    NSString *title = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %@", obj.semantic] ;

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
    SCNGeometrySource *obj  = get_objectFromUserdata(__bridge_transfer SCNGeometrySource, L, 1, USERDATA_TAG) ;

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
    {"bytesPerComponent",   source_bytesPerComponent},
    {"componentsPerVector", source_componentsPerVector},
    {"data",                source_data},
    {"dataOffset",          source_dataOffset},
    {"dataStride",          source_dataStride},
    {"floatComponents",     source_floatComponents},
    {"semantic",            source_semantic},
    {"vectorCount",         source_vectorCount},

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
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

int luaopen_hs__asm_uitk_element_libsceneKit_geometry_source(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushSCNGeometrySource  forClass:"SCNGeometrySource"];
    [skin registerLuaObjectHelper:toSCNGeometrySource forClass:"SCNGeometrySource"
                                           withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    [skin pushNSObject:@[
        @"bytesPerComponent",
        @"componentsPerVector",
        @"dataOffset",
        @"dataStride",
        @"floatComponents",
        @"semantic",
        @"vectorCount",
    ]] ;
    lua_setfield(L, -2, "_readOnlyAdditions") ;
    lua_pushboolean(L, NO) ; lua_setfield(L, -2, "_subclass") ;
    lua_pop(L, 1) ;

    return 1;
}
