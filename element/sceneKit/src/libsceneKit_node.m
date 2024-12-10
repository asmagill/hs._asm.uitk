@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;
#import "SKconversions.h"

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.node" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

static NSDictionary *FOCUSBEHAVIOR ;
static NSDictionary *MOVABILITYHINT ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_anyObjectFromUserdata(objType, L, idx) (objType*)*((void**)lua_touserdata(L, idx))

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    MOVABILITYHINT = @{
        @"fixed"   : @(SCNMovabilityHintFixed),
        @"movable" : @(SCNMovabilityHintMovable),
    } ;

    FOCUSBEHAVIOR = @{
        @"none"      : @(SCNNodeFocusBehaviorNone),
        @"occluding" : @(SCNNodeFocusBehaviorOccluding),
        @"focusable" : @(SCNNodeFocusBehaviorFocusable),
    } ;
}

BOOL oneOfOurGeometryObjects(SCNGeometry *obj) {
    return [obj isKindOfClass:[SCNGeometry class]]  &&
           [obj respondsToSelector:NSSelectorFromString(@"selfRefCount")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setSelfRefCount:")] &&
           [obj respondsToSelector:NSSelectorFromString(@"refTable")] &&
           [obj respondsToSelector:NSSelectorFromString(@"callbackRef")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setCallbackRef:")] ;
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

static int node_localFront(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    return pushSCNVector3(L, SCNNode.localFront) ;
}

static int node_localRight(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    return pushSCNVector3(L, SCNNode.localRight) ;
}

static int node_localUp(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    return pushSCNVector3(L, SCNNode.localUp) ;
}

#pragma mark - Module Methods -

static int node_worldFront(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    return pushSCNVector3(L, node.worldFront) ;
}

static int node_worldRight(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    return pushSCNVector3(L, node.worldRight) ;
}

static int node_worldUp(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    return pushSCNVector3(L, node.worldUp) ;
}

static int node_parentNode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:node.parentNode] ;
    return 1 ;
}

static int node_childNodes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:node.childNodes] ;
    return 1 ;
}

static int node_presentationNode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:node.presentationNode] ;
    return 1 ;
}

static int node_eulerAngles(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        pushSCNVector3(L, node.eulerAngles) ;
    } else {
        SCNVector3 vector = pullSCNVector3(L, 2) ;
        node.eulerAngles = vector ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_position(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        pushSCNVector3(L, node.position) ;
    } else {
        SCNVector3 vector = pullSCNVector3(L, 2) ;
        node.position = vector ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_scale(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        pushSCNVector3(L, node.scale) ;
    } else {
        SCNVector3 vector = pullSCNVector3(L, 2) ;
        node.scale = vector ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_worldPosition(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        pushSCNVector3(L, node.worldPosition) ;
    } else {
        SCNVector3 vector = pullSCNVector3(L, 2) ;
        node.worldPosition = vector ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_rotation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        pushSCNVector4(L, node.rotation) ;
    } else {
        SCNVector4 vector = pullSCNVector4(L, 2) ;
        node.rotation = vector ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_orientation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        pushSCNQuaternion(L, node.orientation) ;
    } else {
        SCNQuaternion quaternion = pullSCNQuaternion(L, 2) ;
        node.orientation = quaternion ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_worldOrientation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        pushSCNQuaternion(L, node.worldOrientation) ;
    } else {
        SCNQuaternion quaternion = pullSCNQuaternion(L, 2) ;
        node.worldOrientation = quaternion ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_pivot(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        pushSCNMatrix4(L, node.pivot) ;
    } else {
        SCNMatrix4 matrix = pullSCNMatrix4(L, 2) ;
        node.pivot = matrix ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_transform(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        pushSCNMatrix4(L, node.transform) ;
    } else {
        SCNMatrix4 matrix = pullSCNMatrix4(L, 2) ;
        node.transform = matrix ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_worldTransform(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        pushSCNMatrix4(L, node.worldTransform) ;
    } else {
        SCNMatrix4 matrix = pullSCNMatrix4(L, 2) ;
        node.worldTransform = matrix ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:node.name] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            node.name = nil ;
        } else {
            NSString *newName = [skin toNSObjectAtIndex:2] ;
            node.name = newName ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_hidden(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, node.hidden) ;
    } else {
        node.hidden = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_paused(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, node.paused) ;
    } else {
        node.paused = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_castsShadow(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, node.castsShadow) ;
    } else {
        node.castsShadow = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_opacity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, node.opacity) ;
    } else {
        node.opacity = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// FIXME: need to see if this needs to be constrained (e.g. not negative)
static int node_renderingOrder(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, node.renderingOrder) ;
    } else {
        node.renderingOrder = lua_tointeger(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_categoryBitMask(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, (lua_Integer)node.categoryBitMask) ;
    } else {
        node.categoryBitMask = (NSUInteger)lua_tointeger(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_camera(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:node.camera] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            if (node.camera) [skin luaRelease:refTable forNSObject:node.camera] ;
            node.camera = nil ;
        } else {
            [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.element.sceneKit.camera", LS_TBREAK] ;
            SCNCamera *camera = [skin toNSObjectAtIndex:2] ;
            if (node.camera) [skin luaRelease:refTable forNSObject:node.camera] ;
            node.camera = camera ;
            [skin luaRetain:refTable forNSObject:node.camera] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_geometry(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:node.geometry] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            if (node.geometry) [skin luaRelease:refTable forNSObject:node.geometry] ;
            node.geometry = nil ;
        } else {
            SCNGeometry *geometry = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
            if (!geometry || !oneOfOurGeometryObjects(geometry)) {
                return luaL_argerror(L, 1, "expected userdata representing a sceneKit geometry object") ;
            }
            if (node.geometry) [skin luaRelease:refTable forNSObject:node.geometry] ;
            node.geometry = geometry ;
            [skin luaRetain:refTable forNSObject:node.geometry] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_light(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:node.light] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            if (node.light) [skin luaRelease:refTable forNSObject:node.light] ;
            node.light = nil ;
        } else {
            [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.element.sceneKit.light", LS_TBREAK] ;
            SCNLight *light = [skin toNSObjectAtIndex:2] ;
            if (node.light) [skin luaRelease:refTable forNSObject:node.light] ;
            node.light = light ;
            [skin luaRetain:refTable forNSObject:node.light] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_movabilityHint(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [MOVABILITYHINT allKeysForObject:@(node.movabilityHint)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", node.movabilityHint] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = MOVABILITYHINT[key] ;
        if (value) {
            node.movabilityHint = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [MOVABILITYHINT.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int node_focusBehavior(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [FOCUSBEHAVIOR allKeysForObject:@(node.focusBehavior)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", node.focusBehavior] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = FOCUSBEHAVIOR[key] ;
        if (value) {
            node.focusBehavior = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [FOCUSBEHAVIOR.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// static int node_morpher(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
//     SCNNode *node = [skin toNSObjectAtIndex:1] ;
//
//     if (lua_gettop(L) == 1) {
//         [skin pushNSObject:node.morpher] ;
//     } else {
//         if (lua_type(L, 2) == LUA_TNIL) {
//             if (node.morpher) [skin luaRelease:refTable forNSObject:node.morpher] ;
//             node.morpher = nil ;
//         } else {
//             [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.element.sceneKit.morpher", LS_TBREAK] ;
//             SCNMorpher *morpher = [skin toNSObjectAtIndex:2] ;
//             if (node.morpher) [skin luaRelease:refTable forNSObject:node.morpher] ;
//             node.morpher = morpher ;
//             [skin luaRetain:refTable forNSObject:node.morpher] ;
//         }
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }
//
// static int node_skinner(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
//     SCNNode *node = [skin toNSObjectAtIndex:1] ;
//
//     if (lua_gettop(L) == 1) {
//         [skin pushNSObject:node.skinner] ;
//     } else {
//         if (lua_type(L, 2) == LUA_TNIL) {
//             if (node.skinner) [skin luaRelease:refTable forNSObject:node.skinner] ;
//             node.skinner = nil ;
//         } else {
//             [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.element.sceneKit.skinner", LS_TBREAK] ;
//             SCNSkinner *skinner = [skin toNSObjectAtIndex:2] ;
//             if (node.skinner) [skin luaRelease:refTable forNSObject:node.skinner] ;
//             node.skinner = skinner ;
//             [skin luaRetain:refTable forNSObject:node.skinner] ;
//         }
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }
//
// static int node_physicsBody(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
//     SCNNode *node = [skin toNSObjectAtIndex:1] ;
//
//     if (lua_gettop(L) == 1) {
//         [skin pushNSObject:node.physicsBody] ;
//     } else {
//         if (lua_type(L, 2) == LUA_TNIL) {
//             if (node.physicsBody) [skin luaRelease:refTable forNSObject:node.physicsBody] ;
//             node.physicsBody = nil ;
//         } else {
//             [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.element.sceneKit.physicsBody", LS_TBREAK] ;
//             SCNPhysicsBody *physicsBody = [skin toNSObjectAtIndex:2] ;
//             if (node.physicsBody) [skin luaRelease:refTable forNSObject:node.physicsBody] ;
//             node.physicsBody = physicsBody ;
//             [skin luaRetain:refTable forNSObject:node.physicsBody] ;
//         }
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }
//
// static int node_physicsField(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
//     SCNNode *node = [skin toNSObjectAtIndex:1] ;
//
//     if (lua_gettop(L) == 1) {
//         [skin pushNSObject:node.physicsField] ;
//     } else {
//         if (lua_type(L, 2) == LUA_TNIL) {
//             if (node.physicsField) [skin luaRelease:refTable forNSObject:node.physicsField] ;
//             node.physicsField = nil ;
//         } else {
//             [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.element.sceneKit.physicsField", LS_TBREAK] ;
//             SCNPhysicsField *physicsField = [skin toNSObjectAtIndex:2] ;
//             if (node.physicsField) [skin luaRelease:refTable forNSObject:node.physicsField] ;
//             node.physicsField = physicsField ;
//             [skin luaRetain:refTable forNSObject:node.physicsField] ;
//         }
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }

// - (void)localRotateBy:(SCNVector4)rotation;
// - (void)localTranslateBy:(SCNVector3)translation;
// - (void)lookAt:(SCNVector3)worldTarget up:(SCNVector3)worldUp localFront:(SCNVector3)localFront;
// - (void)lookAt:(SCNVector3)worldTarget;
// - (void)rotateBy:(SCNVector4)worldRotation aroundTarget:(SCNVector3)worldTarget;

// FIXME: list
//    do we need to check for loops?
//    do we need to make sure parentNode of child is nil?
//    if child is geometry or light, make sure fields aren't already filled for this one?
static int node_addChildNode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    SCNNode     *node  = [skin toNSObjectAtIndex:1] ;
    SCNNode     *child = [skin toNSObjectAtIndex:2] ;

    if (lua_gettop(L) == 2) {
        [node addChildNode:child] ;
    } else {
        lua_Integer idx = lua_tointeger(L, 3) - 1 ;
        if (idx >= 0 && idx <= (lua_Integer)node.childNodes.count) {
            [node insertChildNode:child atIndex:(NSUInteger)idx] ;
        } else {
            return luaL_argerror(L, 3, "index out of bounds") ;
        }
    }
    [skin luaRetain:refTable forNSObject:child] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int node_removeChildNode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK] ;
    SCNNode *node = [skin toNSObjectAtIndex:1] ;

    SCNNode *targetNode = nil ;

    if (lua_type(L, 2) == LUA_TNUMBER) {
        [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
        lua_Integer idx = lua_tointeger(L, 2) - 1 ;
        if (idx < 0 || idx >= (lua_Integer)node.childNodes.count) {
            return luaL_argerror(L, 2, "index out of bounds") ;
        } else {
            targetNode = node.childNodes[(NSUInteger)idx] ;
        }
    } else {
        [skin checkArgs:LS_TANY, LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
        targetNode = [skin toNSObjectAtIndex:2] ;
        if (![targetNode.parentNode isEqualTo:node]) {
            return luaL_argerror(L, 2, "target node is not a child of this node") ;
        }
    }

    if (targetNode) {
        [targetNode removeFromParentNode] ;
        [skin luaRelease:refTable forNSObject:targetNode] ;
    } else {
        return luaL_argerror(L, 2, "unable to identify target node") ;
    }
    return 1 ;
}

static int node_clone(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode *node     = [skin toNSObjectAtIndex:1] ;
    BOOL    flattened = (lua_gettop(L) == 2) ? (BOOL)(lua_toboolean(L, 2)) : NO ;

    if (flattened) {
        [skin pushNSObject:[node flattenedClone]] ;
    } else {
        [skin pushNSObject:[node clone]] ;
    }
    return 1 ;
}

static int node_copy(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNNode *node     = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:[node copy]] ;
    return 1 ;
}

static int node_childNodeWithName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNNode  *node       = [skin toNSObjectAtIndex:1] ;
    NSString *name       = [skin toNSObjectAtIndex:2] ;
    BOOL     recursively = (lua_gettop(L) == 3) ? (BOOL)(lua_toboolean(L, 3)) : NO ;

    [skin pushNSObject:[node childNodeWithName:name recursively:recursively]] ;
    return 1 ;
}

// - (void)replaceChildNode:(SCNNode *)oldChild with:(SCNNode *)newChild;
// - (NSArray<SCNNode *> *)childNodesPassingTest:(BOOL (^)(SCNNode *child, BOOL *stop))predicate;

// - (SCNVector3)convertPosition:(SCNVector3)position fromNode:(SCNNode *)node;
// - (SCNVector3)convertPosition:(SCNVector3)position toNode:(SCNNode *)node;
// - (SCNVector3)convertVector:(SCNVector3)vector fromNode:(SCNNode *)node;
// - (SCNVector3)convertVector:(SCNVector3)vector toNode:(SCNNode *)node;
// - (SCNMatrix4)convertTransform:(SCNMatrix4)transform fromNode:(SCNNode *)node;
// - (SCNMatrix4)convertTransform:(SCNMatrix4)transform toNode:(SCNNode *)node;

// @property(readonly) NSArray<SCNParticleSystem *> *particleSystems;
// - (void)addParticleSystem:(SCNParticleSystem *)system;
// - (void)removeAllParticleSystems;
// - (void)removeParticleSystem:(SCNParticleSystem *)system;

// @property(nonatomic, readonly) NSArray<SCNAudioPlayer *> *audioPlayers;
// - (void)addAudioPlayer:(SCNAudioPlayer *)player;
// - (void)removeAllAudioPlayers;
// - (void)removeAudioPlayer:(SCNAudioPlayer *)player;

// @property(copy) NSArray<SCNConstraint *> *constraints;
// @property(nonatomic, copy, nullable) NSArray<CIFilter *> *filters;
// @property(nonatomic, weak) GKEntity *entity;

// - (void)enumerateChildNodesUsingBlock:(void (^)(SCNNode *child, BOOL *stop))block;
// - (void)enumerateHierarchyUsingBlock:(void (^)(SCNNode *node, BOOL *stop))block;

// - (NSArray<SCNHitTestResult *> *)hitTestWithSegmentFromPoint:(SCNVector3)pointA toPoint:(SCNVector3)pointB options:(NSDictionary<NSString *,id> *)options;

#pragma mark - SCNBoundingVolume Protocol Methods -

static int node_boundingBox(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    SCNNode    *node = [skin toNSObjectAtIndex:1] ;
    SCNVector3 min, max ;

    // For now, skip overriding as I can think of ways to abuse this and not so much
    // where it's useful -- let's wait and see...
    // - (void)setBoundingBoxMin:(SCNVector3 *)min max:(SCNVector3 *)max;

    if ([node getBoundingBoxMin:&min max:&max]) {
        pushSCNVector3(L, min) ;
        pushSCNVector3(L, max) ;
        return 2 ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int node_boundingSphere(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNNode    *node = [skin toNSObjectAtIndex:1] ;
    SCNVector3 center ;
    CGFloat    radius ;

    if ([node getBoundingSphereCenter:&center radius:&radius]) {
        pushSCNVector3(L, center) ;
        lua_pushnumber(L, radius) ;
        return 2 ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

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
            if (obj.geometry)     [skin luaRelease:refTable forNSObject:obj.geometry] ;
            if (obj.light)        [skin luaRelease:refTable forNSObject:obj.light] ;
            if (obj.camera)       [skin luaRelease:refTable forNSObject:obj.camera] ;
            if (obj.morpher)      [skin luaRelease:refTable forNSObject:obj.morpher] ;
            if (obj.skinner)      [skin luaRelease:refTable forNSObject:obj.skinner] ;
            if (obj.physicsBody)  [skin luaRelease:refTable forNSObject:obj.physicsBody] ;
            if (obj.physicsField) [skin luaRelease:refTable forNSObject:obj.physicsField] ;
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
    {"worldFront",       node_worldFront},
    {"worldRight",       node_worldRight},
    {"worldUp",          node_worldUp},
    {"parentNode",       node_parentNode},
    {"childNodes",       node_childNodes},
    {"presentationNode", node_presentationNode},
    {"addChildNode",     node_addChildNode},
    {"removeChildNode",  node_removeChildNode},
    {"boundingBox",      node_boundingBox},
    {"boundingSphere",   node_boundingSphere},
    {"clone",            node_clone},
    {"copy",             node_copy},
    {"childWithName",    node_childNodeWithName},

    {"eulerAngles",      node_eulerAngles},
    {"position",         node_position},
    {"scale",            node_scale},
    {"worldPosition",    node_worldPosition},
    {"rotation",         node_rotation},
    {"orientation",      node_orientation},
    {"worldOrientation", node_worldOrientation},
    {"pivot",            node_pivot},
    {"transform",        node_transform},
    {"worldTransform",   node_worldTransform},
    {"name",             node_name},
    {"hidden",           node_hidden},
    {"paused",           node_paused},
    {"castsShadow",      node_castsShadow},
    {"opacity",          node_opacity},
    {"renderingOrder",   node_renderingOrder},
    {"categoryBitMask",  node_categoryBitMask},
    {"camera",           node_camera},
    {"geometry",         node_geometry},
    {"light",            node_light},
    {"movabilityHint",   node_movabilityHint},
    {"focusBehavior",    node_focusBehavior},

    {"__tostring",       userdata_tostring},
    {"__eq",             userdata_eq},
    {"__gc",             userdata_gc},
    {NULL,               NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",        node_new},
    {"localFront", node_localFront},
    {"localRight", node_localRight},
    {"localUp",    node_localUp},
    {NULL,         NULL}
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
        @"eulerAngles",
        @"position",
        @"scale",
        @"worldPosition",
        @"rotation",
        @"orientation",
        @"worldOrientation",
        @"pivot",
        @"transform",
        @"worldTransform",
        @"name",
        @"hidden",
        @"paused",
        @"castsShadow",
        @"opacity",
        @"renderingOrder",
        @"categoryBitMask",
        @"camera",
        @"geometry",
        @"light",
        @"movabilityHint",
        @"focusBehavior",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
