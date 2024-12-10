@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;
#import "SKconversions.h"

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.geometry" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
#define get_anyObjectFromUserdata(objType, L, idx) (objType*)*((void**)lua_touserdata(L, idx))

static NSDictionary *SOURCE_SEMANTICS ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    SOURCE_SEMANTICS = @{
        @"boneIndices"  : SCNGeometrySourceSemanticBoneIndices,
        @"boneWeights"  : SCNGeometrySourceSemanticBoneWeights,
        @"color"        : SCNGeometrySourceSemanticColor,
        @"edgeCrease"   : SCNGeometrySourceSemanticEdgeCrease,
        @"normal"       : SCNGeometrySourceSemanticNormal,
        @"tangent"      : SCNGeometrySourceSemanticTangent,
        @"texcoord"     : SCNGeometrySourceSemanticTexcoord,
        @"vertex"       : SCNGeometrySourceSemanticVertex,
        @"vertexCrease" : SCNGeometrySourceSemanticVertexCrease,
    } ;
}

@interface SCNGeometry (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

BOOL oneOfOurGeometryObjects(SCNGeometry *obj) {
    return [obj isKindOfClass:[SCNGeometry class]]  &&
           [obj respondsToSelector:NSSelectorFromString(@"selfRefCount")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setSelfRefCount:")] &&
           [obj respondsToSelector:NSSelectorFromString(@"refTable")] &&
           [obj respondsToSelector:NSSelectorFromString(@"callbackRef")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setCallbackRef:")] ;
}

@implementation SCNGeometry (HammerspoonAdditions)

+ (instancetype)geometryWithName:(NSString *)name {
    SCNGeometry *geometry = [SCNGeometry geometry] ;

    if (geometry) {
        geometry.callbackRef  = LUA_NOREF ;
        geometry.selfRefCount = 0 ;
        geometry.name         = name ;
    }
    return geometry ;
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

static int geometry_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *name = (lua_gettop(L)) == 1 ? [skin toNSObjectAtIndex:1] : [[NSUUID UUID] UUIDString] ;

    SCNGeometry *geometry = [SCNGeometry geometryWithName:name] ;
    if (geometry) {
        [skin pushNSObject:geometry] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

// Probably needed for arbitrary mesh
// + (instancetype)geometryWithSources:(NSArray<SCNGeometrySource *> *)sources elements:(NSArray<SCNGeometryElement *> *)elements;

#pragma mark - Module Methods -

static int geometry_elementCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!geometry || !oneOfOurGeometryObjects(geometry)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
    }

    lua_pushinteger(L, geometry.geometryElementCount) ;
    return 1 ;
}

static int geometry_wantsAdaptiveSubdivision(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!geometry || !oneOfOurGeometryObjects(geometry)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, geometry.wantsAdaptiveSubdivision) ;
    } else {
        geometry.wantsAdaptiveSubdivision = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int geometry_subdivisionLevel(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!geometry || !oneOfOurGeometryObjects(geometry)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, (lua_Integer)geometry.subdivisionLevel) ;
    } else {
        lua_Integer level = lua_tointeger(L, 2) ;
        if (level < 0) {
            return luaL_argerror(L, 2, "subdivision level must be 0 or greater") ;
        }

        geometry.subdivisionLevel = (NSUInteger)lua_tointeger(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int geometry_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!geometry || !oneOfOurGeometryObjects(geometry)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
    }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:geometry.name] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            geometry.name = nil ;
        } else {
            NSString *newName = [skin toNSObjectAtIndex:2] ;
            geometry.name = newName ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int geometry_geometryElements(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!geometry || !oneOfOurGeometryObjects(geometry)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
    }

    [skin pushNSObject:geometry.geometryElements] ;
    return 1 ;
}

static int geometry_geometrySources(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!geometry || !oneOfOurGeometryObjects(geometry)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
    }

    [skin pushNSObject:geometry.geometrySources] ;
    return 1 ;
}

static int geometry_edgeCreasesElement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TANY | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!geometry || !oneOfOurGeometryObjects(geometry)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
    }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:geometry.edgeCreasesElement] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            if (geometry.edgeCreasesElement) [skin luaRelease:refTable forNSObject:geometry.edgeCreasesElement] ;
            geometry.edgeCreasesElement = nil ;
        } else {
            [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.element.sceneKit.geometry.element", LS_TBREAK] ;
            SCNGeometryElement *element = [skin toNSObjectAtIndex:2] ;
            geometry.edgeCreasesElement = element ;
            [skin luaRetain:refTable forNSObject:geometry.edgeCreasesElement] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int geometry_edgeCreasesSource(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TANY | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!geometry || !oneOfOurGeometryObjects(geometry)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
    }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:geometry.edgeCreasesSource] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            if (geometry.edgeCreasesSource) [skin luaRelease:refTable forNSObject:geometry.edgeCreasesSource] ;
            geometry.edgeCreasesSource = nil ;
        } else {
            [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.element.sceneKit.geometry.source", LS_TBREAK] ;
            SCNGeometrySource *source = [skin toNSObjectAtIndex:2] ;
            geometry.edgeCreasesSource = source ;
            [skin luaRetain:refTable forNSObject:geometry.edgeCreasesSource] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int geometry_tessellator(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TANY | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!geometry || !oneOfOurGeometryObjects(geometry)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
    }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:geometry.tessellator] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            if (geometry.tessellator) [skin luaRelease:refTable forNSObject:geometry.tessellator] ;
            geometry.tessellator = nil ;
        } else {
            [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.element.sceneKit.geometry.tessellator", LS_TBREAK] ;
            SCNGeometryTessellator *tessellator = [skin toNSObjectAtIndex:2] ;
            geometry.tessellator = tessellator ;
            [skin luaRetain:refTable forNSObject:geometry.tessellator] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int geometry_geometrySourcesForSemantic(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TSTRING, LS_TBREAK] ;
    SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!geometry || !oneOfOurGeometryObjects(geometry)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
    }

    NSString *key      = [skin toNSObjectAtIndex:2] ;
    NSString *semantic = SOURCE_SEMANTICS[key] ;
    if (semantic) {
        [skin pushNSObject:[geometry geometrySourcesForSemantic:semantic]] ;
    } else {
        NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [SOURCE_SEMANTICS.allKeys componentsJoinedByString:@", "]] ;
        return luaL_argerror(L, 2, errMsg.UTF8String) ;
    }
    return 1 ;
}

static int geometry_geometryElementAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!geometry || !oneOfOurGeometryObjects(geometry)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
    }

    lua_Integer idx = lua_tointeger(L, 2) - 1 ;
    if (idx < 0 || idx >= geometry.geometryElementCount) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }
    [skin pushNSObject:[geometry geometryElementAtIndex:idx]] ;
    return 1 ;
}

static int geometry_materials(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!geometry || !oneOfOurGeometryObjects(geometry)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
    }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:geometry.materials] ;
    } else {
        NSArray    *materials = [skin toNSObjectAtIndex:2] ;
        BOOL       isGood     = [materials isKindOfClass:[NSArray class]] ;
        NSUInteger count      = 0 ;
        while (isGood && count < materials.count) {
            SCNMaterial *item = materials[count++] ;
            isGood = [item isKindOfClass:[SCNMaterial class]] ;
        }
        if (!isGood) {
            return luaL_argerror(L, 2, "expected array of sceneKit material objects") ;
        }

        for (SCNMaterial *item in geometry.materials) [skin luaRelease:refTable forNSObject:item] ;
        geometry.materials = materials ;
        for (SCNMaterial *item in geometry.materials) [skin luaRetain:refTable forNSObject:item] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// we're treating this as read only since it follows first item of materials array
static int geometry_firstMaterial(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!geometry || !oneOfOurGeometryObjects(geometry)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
    }

    [skin pushNSObject:geometry.firstMaterial] ;
    return 1 ;
}

static int geometry_materialWithName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TSTRING, LS_TBREAK] ;
    SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!geometry || !oneOfOurGeometryObjects(geometry)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
    }
    NSString *name = [skin toNSObjectAtIndex:2] ;

    [skin pushNSObject:[geometry materialWithName:name]] ;
    return 1 ;
}

// NOTE: we can already set the array with materials; these just give a more refined way, so lets see how often it
//       becomes an issue
//     - (void)insertMaterial:(SCNMaterial *)material atIndex:(NSUInteger)index;
//     - (void)removeMaterialAtIndex:(NSUInteger)index;
//     - (void)replaceMaterialAtIndex:(NSUInteger)index withMaterial:(SCNMaterial *)material;

// for setting alternate geometry objects when distance changes; let's see if this even works well enough for
// animation before worrying about it.
// static int geometry_levelsOfDetail(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TANY, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
//     SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
//     if (!geometry || !oneOfOurGeometryObjects(geometry)) {
//         return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
//     }
//
//     if (lua_gettop(L) == 1) {
//         [skin pushNSObject:geometry.levelsOfDetail] ;
//     } else {
//         if (lua_type(L, 2) == LUA_TNIL) {
//             geometry.levelsOfDetail = nil ;
//         } else {
//             NSArray    *levels = [skin toNSObjectAtIndex:2] ;
//             BOOL       isGood  = [levels isKindOfClass:[NSArray class]] ;
//             NSUInteger count      = 0 ;
//             while (isGood && count < levels.count) {
//                 SCNLevelOfDetail *item = levels[count++] ;
//                 isGood = [item isKindOfClass:[SCNLevelOfDetail class]] ;
//             }
//             if (!isGood) {
//                 return luaL_argerror(L, 2, "expected array of sceneKit levelsOfDetail objects or nil to clear") ;
//             }
//
//         geometry.levelsOfDetail = levels ;
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }

#pragma mark - SCNBoundingVolume Protocol Methods -

static int geometry_boundingBox(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK];
    SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!geometry || !oneOfOurGeometryObjects(geometry)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
    }
    SCNVector3  min, max ;

    // For now, skip overriding as I can think of ways to abuse this and not so much
    // where it's useful -- let's wait and see...
    // - (void)setBoundingBoxMin:(SCNVector3 *)min max:(SCNVector3 *)max;

    if ([geometry getBoundingBoxMin:&min max:&max]) {
        pushSCNVector3(L, min) ;
        pushSCNVector3(L, max) ;
        return 2 ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int geometry_boundingSphere(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK];
    SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!geometry || !oneOfOurGeometryObjects(geometry)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
    }
    SCNVector3  center ;
    CGFloat     radius ;

    if ([geometry getBoundingSphereCenter:&center radius:&radius]) {
        pushSCNVector3(L, center) ;
        lua_pushnumber(L, radius) ;
        return 2 ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int geometry_copy(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK];
    SCNGeometry *geometry = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!geometry || !oneOfOurGeometryObjects(geometry)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
    }

    [skin pushNSObject:[geometry copy]] ;
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNGeometry(lua_State *L, id obj) {
    SCNGeometry *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNGeometry *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNGeometry(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNGeometry *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNGeometry, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSString *title = @"<not userdata>" ;
    if (lua_getmetatable(L, -1)) {
        lua_getfield(L, -1, "__name") ;
        title = [NSString stringWithUTF8String:lua_tostring(L, -1)] ;
        lua_pop(L, 2) ;
    }
    SCNGeometry *obj  = [skin toNSObjectAtIndex:1] ;
    NSString    *name = obj.name ;
    [skin pushNSObject:[NSString stringWithFormat:@"%@: %@ (%p)", title, name, lua_topointer(L, 1)]] ;
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
    SCNGeometry *obj  = get_anyObjectFromUserdata(__bridge_transfer SCNGeometry, L, 1) ;

    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:obj.refTable ref:obj.callbackRef] ;
            if (obj.edgeCreasesElement) [skin luaRelease:refTable forNSObject:obj.edgeCreasesElement] ;
            if (obj.edgeCreasesSource)  [skin luaRelease:refTable forNSObject:obj.edgeCreasesSource] ;
            if (obj.tessellator)        [skin luaRelease:refTable forNSObject:obj.tessellator] ;
            for (SCNMaterial *item in obj.materials) [skin luaRelease:refTable forNSObject:item] ;
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
    {"elementCount",        geometry_elementCount},
    {"elements",            geometry_geometryElements},
    {"sources",             geometry_geometrySources},
    {"sourcesForSemantic",  geometry_geometrySourcesForSemantic},
    {"elementAtIndex",      geometry_geometryElementAtIndex},
    {"firstMaterial",       geometry_firstMaterial},
    {"boundingBox",         geometry_boundingBox},
    {"boundingSphere",      geometry_boundingSphere},
    {"materialWithName",    geometry_materialWithName},
    {"copy",                geometry_copy},

    {"adaptiveSubdivision", geometry_wantsAdaptiveSubdivision},
    {"subdivisionLevel",    geometry_subdivisionLevel},
    {"name",                geometry_name},
    {"edgeCreasesElement",  geometry_edgeCreasesElement},
    {"edgeCreasesSource",   geometry_edgeCreasesSource},
    {"tessellator",         geometry_tessellator},
    {"materials",           geometry_materials},
//     {"levelsOfDetail",      geometry_levelsOfDetail},

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",        geometry_new},
    {NULL,         NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libsceneKit_geometry(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushSCNGeometry  forClass:"SCNGeometry"];
    [skin registerLuaObjectHelper:toSCNGeometry forClass:"SCNGeometry"
                                     withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"adaptiveSubdivision",
        @"subdivisionLevel",
        @"name",
        @"edgeCreasesElement",
        @"edgeCreasesSource",
        @"tessellator",
        @"materials",
//         @"levelsOfDetail",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // our subclasses need to set this
    // lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_subclass") ;
    lua_pop(L, 1) ;

    return 1;
}
