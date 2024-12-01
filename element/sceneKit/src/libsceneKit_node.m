@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.node" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_anyObjectFromUserdata(objType, L, idx) (objType*)*((void**)lua_touserdata(L, idx))

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
}

static int pushSCNMatrix4(lua_State *L, SCNMatrix4 matrix4) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
      lua_pushnumber(L, matrix4.m11) ; lua_setfield(L, -2, "m11") ;
      lua_pushnumber(L, matrix4.m12) ; lua_setfield(L, -2, "m12") ;
      lua_pushnumber(L, matrix4.m13) ; lua_setfield(L, -2, "m13") ;
      lua_pushnumber(L, matrix4.m14) ; lua_setfield(L, -2, "m14") ;
      lua_pushnumber(L, matrix4.m21) ; lua_setfield(L, -2, "m21") ;
      lua_pushnumber(L, matrix4.m22) ; lua_setfield(L, -2, "m22") ;
      lua_pushnumber(L, matrix4.m23) ; lua_setfield(L, -2, "m23") ;
      lua_pushnumber(L, matrix4.m24) ; lua_setfield(L, -2, "m24") ;
      lua_pushnumber(L, matrix4.m31) ; lua_setfield(L, -2, "m31") ;
      lua_pushnumber(L, matrix4.m32) ; lua_setfield(L, -2, "m32") ;
      lua_pushnumber(L, matrix4.m33) ; lua_setfield(L, -2, "m33") ;
      lua_pushnumber(L, matrix4.m34) ; lua_setfield(L, -2, "m34") ;
      lua_pushnumber(L, matrix4.m41) ; lua_setfield(L, -2, "m41") ;
      lua_pushnumber(L, matrix4.m42) ; lua_setfield(L, -2, "m42") ;
      lua_pushnumber(L, matrix4.m43) ; lua_setfield(L, -2, "m43") ;
      lua_pushnumber(L, matrix4.m44) ; lua_setfield(L, -2, "m44") ;
    luaL_getmetatable(L, "hs._asm.uitk.util.matrix4" ) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

static SCNMatrix4 toSCNMatrix4(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNMatrix4 matrix4 = SCNMatrix4Identity ;

    if (lua_type(L, idx) == LUA_TTABLE) {
        idx = lua_absindex(L, idx) ;

        if (lua_getfield(L, idx, "m11") == LUA_TNUMBER) {
            matrix4.m11 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m11 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m11 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m12") == LUA_TNUMBER) {
            matrix4.m12 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m12 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m12 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m13") == LUA_TNUMBER) {
            matrix4.m13 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m13 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m13 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m14") == LUA_TNUMBER) {
            matrix4.m14 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m14 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m14 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;

        if (lua_getfield(L, idx, "m21") == LUA_TNUMBER) {
            matrix4.m21 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m21 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m21 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m22") == LUA_TNUMBER) {
            matrix4.m22 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m22 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m22 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m23") == LUA_TNUMBER) {
            matrix4.m23 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m23 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m23 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m24") == LUA_TNUMBER) {
            matrix4.m24 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m24 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m24 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;

        if (lua_getfield(L, idx, "m31") == LUA_TNUMBER) {
            matrix4.m31 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m31 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m31 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m32") == LUA_TNUMBER) {
            matrix4.m32 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m32 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m32 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m33") == LUA_TNUMBER) {
            matrix4.m33 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m33 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m33 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m34") == LUA_TNUMBER) {
            matrix4.m34 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m34 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m34 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;

        if (lua_getfield(L, idx, "m41") == LUA_TNUMBER) {
            matrix4.m41 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m41 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m41 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m42") == LUA_TNUMBER) {
            matrix4.m42 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m42 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m42 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m43") == LUA_TNUMBER) {
            matrix4.m43 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m43 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m43 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "m44") == LUA_TNUMBER) {
            matrix4.m44 = lua_tonumber(L, -1) ;
        } else {
            matrix4.m44 = 0.0 ;
            [skin logError:@"SCNMatrix4 field m44 is not a number; setting to 0"] ;
        }
        lua_pop(L, 1) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected SCNMatrix4 table, found %s",
                                                  lua_typename(L, lua_type(L, idx))]] ;
    }

    return matrix4 ;
}

@interface SCNNode (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation SCNNode (HammerspoonAdditions)

+ (instancetype)nodeWithName:(NSString *)name {
    SCNNode *node = [SCNNode node] ;

    if (node) {
        node.callbackRef  = LUA_NOREF ;
        node.selfRefCount = 0 ;
        node.name         = name ;
    }
    return node ;
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

static int node_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *name = (lua_gettop(L)) == 1 ? [skin toNSObjectAtIndex:1] : [[NSUUID UUID] UUIDString] ;

    SCNNode *node = [SCNNode nodeWithName:name] ;
    if (node) {
        [skin pushNSObject:node] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

// @property(class, readonly, nonatomic) SCNVector3 localFront;
// @property(class, readonly, nonatomic) SCNVector3 localRight;
// @property(class, readonly, nonatomic) SCNVector3 localUp;
// @property(copy) NSArray<SCNConstraint *> *constraints;
// @property(nonatomic, assign, nullable) id<SCNNodeRendererDelegate> rendererDelegate;
// @property(nonatomic, copy, nullable) NSArray<CIFilter *> *filters;
// @property(nonatomic, copy, nullable) NSString *name;
// @property(nonatomic, getter=isHidden) BOOL hidden;
// @property(nonatomic, getter=isPaused) BOOL paused;
// @property(nonatomic, readonly, nullable) SCNNode *parentNode;
// @property(nonatomic, readonly) NSArray<SCNAudioPlayer *> *audioPlayers;
// @property(nonatomic, readonly) NSArray<SCNNode *> *childNodes;
// @property(nonatomic, readonly) SCNMatrix4 worldTransform;
// @property(nonatomic, readonly) SCNNode *presentationNode;
// @property(nonatomic, retain, nullable) SCNCamera *camera;
// @property(nonatomic, retain, nullable) SCNGeometry *geometry;
// @property(nonatomic, retain, nullable) SCNLight *light;
// @property(nonatomic, retain, nullable) SCNMorpher *morpher;
// @property(nonatomic, retain, nullable) SCNPhysicsBody *physicsBody;
// @property(nonatomic, retain, nullable) SCNPhysicsField *physicsField;
// @property(nonatomic, retain, nullable) SCNSkinner *skinner;
// @property(nonatomic, weak) GKEntity *entity;
// @property(nonatomic) BOOL castsShadow;
// @property(nonatomic) CGFloat opacity;
// @property(nonatomic) NSInteger renderingOrder;
// @property(nonatomic) NSUInteger categoryBitMask;
// @property(nonatomic) SCNMatrix4 pivot;
// @property(nonatomic) SCNMatrix4 transform;
// @property(nonatomic) SCNMovabilityHint movabilityHint;
// @property(nonatomic) SCNNodeFocusBehavior focusBehavior;
// @property(nonatomic) SCNQuaternion orientation;
// @property(nonatomic) SCNQuaternion worldOrientation;
// @property(nonatomic) SCNVector3 eulerAngles;
// @property(nonatomic) SCNVector3 position;
// @property(nonatomic) SCNVector3 scale;
// @property(nonatomic) SCNVector3 worldPosition;
// @property(nonatomic) SCNVector4 rotation;
// @property(readonly, nonatomic) SCNVector3 worldFront;
// @property(readonly, nonatomic) SCNVector3 worldRight;
// @property(readonly, nonatomic) SCNVector3 worldUp;
// @property(readonly) NSArray<SCNParticleSystem *> *particleSystems;
//
// - (instancetype)clone;
// - (instancetype)flattenedClone;
// - (NSArray<SCNHitTestResult *> *)hitTestWithSegmentFromPoint:(SCNVector3)pointA toPoint:(SCNVector3)pointB options:(NSDictionary<NSString *,id> *)options;
// - (NSArray<SCNNode *> *)childNodesPassingTest:(BOOL (^)(SCNNode *child, BOOL *stop))predicate;
// - (SCNMatrix4)convertTransform:(SCNMatrix4)transform fromNode:(SCNNode *)node;
// - (SCNMatrix4)convertTransform:(SCNMatrix4)transform toNode:(SCNNode *)node;
// - (SCNNode *)childNodeWithName:(NSString *)name recursively:(BOOL)recursively;
// - (SCNVector3)convertPosition:(SCNVector3)position fromNode:(SCNNode *)node;
// - (SCNVector3)convertPosition:(SCNVector3)position toNode:(SCNNode *)node;
// - (SCNVector3)convertVector:(SCNVector3)vector fromNode:(SCNNode *)node;
// - (SCNVector3)convertVector:(SCNVector3)vector toNode:(SCNNode *)node;
// - (void)addAudioPlayer:(SCNAudioPlayer *)player;
// - (void)addChildNode:(SCNNode *)child;
// - (void)addParticleSystem:(SCNParticleSystem *)system;
// - (void)duplicateNode:(SCNNode *)node withMaterial:(SCNMaterial *)material
// - (void)enumerateChildNodesUsingBlock:(void (^)(SCNNode *child, BOOL *stop))block;
// - (void)enumerateHierarchyUsingBlock:(void (^)(SCNNode *node, BOOL *stop))block;
// - (void)insertChildNode:(SCNNode *)child atIndex:(NSUInteger)index;
// - (void)localRotateBy:(SCNQuaternion)rotation;
// - (void)localTranslateBy:(SCNVector3)translation;
// - (void)lookAt:(SCNVector3)worldTarget up:(SCNVector3)worldUp localFront:(SCNVector3)localFront;
// - (void)lookAt:(SCNVector3)worldTarget;
// - (void)removeAllAudioPlayers;
// - (void)removeAllParticleSystems;
// - (void)removeAudioPlayer:(SCNAudioPlayer *)player;
// - (void)removeFromParentNode;
// - (void)removeParticleSystem:(SCNParticleSystem *)system;
// - (void)replaceChildNode:(SCNNode *)oldChild with:(SCNNode *)newChild;
// - (void)rotateBy:(SCNQuaternion)worldRotation aroundTarget:(SCNVector3)worldTarget;
// - (void)setWorldTransform:(SCNMatrix4)worldTransform;
//
// // @property(class, readonly, nonatomic) simd_float3 simdLocalFront;
// // @property(class, readonly, nonatomic) simd_float3 simdLocalRight;
// // @property(class, readonly, nonatomic) simd_float3 simdLocalUp;
// // @property(nonatomic) simd_float3 simdEulerAngles;
// // @property(nonatomic) simd_float3 simdPosition;
// // @property(nonatomic) simd_float3 simdScale;
// // @property(nonatomic) simd_float3 simdWorldPosition;
// // @property(nonatomic) simd_float4 simdRotation;
// // @property(nonatomic) simd_float4x4 simdPivot;
// // @property(nonatomic) simd_float4x4 simdTransform;
// // @property(nonatomic) simd_float4x4 simdWorldTransform;
// // @property(nonatomic) simd_quatf simdOrientation;
// // @property(nonatomic) simd_quatf simdWorldOrientation;
// // @property(readonly, nonatomic) simd_float3 simdWorldFront;
// // @property(readonly, nonatomic) simd_float3 simdWorldRight;
// // @property(readonly, nonatomic) simd_float3 simdWorldUp;
//
// // - (simd_float3)simdConvertPosition:(simd_float3)position fromNode:(SCNNode *)node;
// // - (simd_float3)simdConvertPosition:(simd_float3)position toNode:(SCNNode *)node;
// // - (simd_float3)simdConvertVector:(simd_float3)vector fromNode:(SCNNode *)node;
// // - (simd_float3)simdConvertVector:(simd_float3)vector toNode:(SCNNode *)node;
// // - (simd_float4x4)simdConvertTransform:(simd_float4x4)transform fromNode:(SCNNode *)node;
// // - (simd_float4x4)simdConvertTransform:(simd_float4x4)transform toNode:(SCNNode *)node;
// // - (void)simdLocalRotateBy:(simd_quatf)rotation;
// // - (void)simdLocalTranslateBy:(simd_float3)translation;
// // - (void)simdLookAt:(simd_float3)worldTarget up:(simd_float3)worldUp localFront:(simd_float3)localFront;
// // - (void)simdLookAt:(simd_float3)worldTarget;
// // - (void)simdRotateBy:(simd_quatf)worldRotation aroundTarget:(simd_float3)worldTarget;

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNNode(lua_State *L, id obj) {
    SCNNode *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNNode *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNNode(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNNode *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNNode, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNNode *obj = [skin luaObjectAtIndex:1 toClass:"SCNNode"] ;
    NSString *title = obj.name ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        SCNNode *obj1 = [skin luaObjectAtIndex:1 toClass:"SCNNode"] ;
        SCNNode *obj2 = [skin luaObjectAtIndex:2 toClass:"SCNNode"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    SCNNode *obj = get_objectFromUserdata(__bridge_transfer SCNNode, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;

            for (SCNNode *child in obj.childNodes) [skin luaRelease:refTable forNSObject:child] ;
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
    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", node_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libsceneKit_node(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushSCNNode  forClass:"SCNNode"];
    [skin registerLuaObjectHelper:toSCNNode forClass:"SCNNode"
                                    withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
