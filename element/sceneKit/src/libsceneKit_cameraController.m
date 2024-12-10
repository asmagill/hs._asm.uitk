@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;
@import AVKit ;
#import "SKconversions.h"

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.cameraController" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;
static void *OWNERVIEW_KEY    = @"HS_OwnerViewKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_anyObjectFromUserdata(objType, L, idx) (objType*)*((void**)lua_touserdata(L, idx))

static NSDictionary *INTERACTION_MODE ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    INTERACTION_MODE = @{
        @"fly"                  : @(SCNInteractionModeFly),
        @"orbitAngleMapping"    : @(SCNInteractionModeOrbitAngleMapping),
        @"orbitArcball"         : @(SCNInteractionModeOrbitArcball),
        @"orbitCenteredArcball" : @(SCNInteractionModeOrbitCenteredArcball),
        @"orbitTurntable"       : @(SCNInteractionModeOrbitTurntable),
        @"pan"                  : @(SCNInteractionModePan),
        @"truck"                : @(SCNInteractionModeTruck),
    } ;
}

@interface SCNCameraController (HammerspoonAdditions)
@property (nonatomic)           int     callbackRef ;
@property (nonatomic)           int     selfRefCount ;
@property (nonatomic, readonly) int     refTable ;
@property (nonatomic)           SCNView *ownerView ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;

- (SCNView *)ownerView ;
- (void)setOwnerView:(SCNView *)value ;
@end

@implementation SCNCameraController (HammerspoonAdditions)

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

- (SCNView *)ownerView {
    SCNView *view = objc_getAssociatedObject(self, OWNERVIEW_KEY) ;
    return view ;
}

- (void)setOwnerView:(SCNView *)value {
    objc_setAssociatedObject(self, OWNERVIEW_KEY, value, OBJC_ASSOCIATION_RETAIN) ;
}

@end

#pragma mark - Module Functions -

#pragma mark - Module Methods -

// @property(nonatomic, assign, nullable) id<SCNCameraControllerDelegate> delegate;

static int controller_inertiaRunning(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, controller.inertiaRunning) ;
    return 1 ;
}

static int controller_inertiaEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, controller.inertiaEnabled) ;
    } else {
        controller.inertiaEnabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int controller_automaticTarget(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, controller.automaticTarget) ;
    } else {
        controller.automaticTarget = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int controller_inertiaFriction(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, (lua_Number)controller.inertiaFriction) ;
    } else {
        float value = (float)(lua_tonumber(L, 2)) ;
        if (value < 0.0f || value > 1.0f) return luaL_argerror(L, 2, "must be between 0.0 and 1.0 inclusive") ;
        controller.inertiaFriction = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int controller_maximumHorizontalAngle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, (lua_Number)controller.maximumHorizontalAngle) ;
    } else {
        float value = (float)(lua_tonumber(L, 2)) ;
        if (value <= controller.minimumHorizontalAngle && value != 0.0f && controller.minimumHorizontalAngle != 0.0f) {
            return luaL_argerror(L, 2, "must be larger than minimumHorizontalAngle") ;
        }
        if (value < -180.0f || value > 180.0f) return luaL_argerror(L, 2, "must be between -180 and 180 inclusive") ;
        controller.maximumHorizontalAngle = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int controller_minimumHorizontalAngle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, (lua_Number)controller.minimumHorizontalAngle) ;
    } else {
        float value = (float)(lua_tonumber(L, 2)) ;
        if (value >= controller.maximumHorizontalAngle && value != 0.0f && controller.minimumHorizontalAngle != 0.0f) {
            return luaL_argerror(L, 2, "must be less than maximumHorizontalAngle") ;
        }
        if (value < -180.0f || value > 180.0f) return luaL_argerror(L, 2, "must be between -180 and 180 inclusive") ;
        controller.minimumHorizontalAngle = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int controller_maximumVerticalAngle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, (lua_Number)controller.maximumVerticalAngle) ;
    } else {
        float value = (float)(lua_tonumber(L, 2)) ;
        if (value <= controller.minimumVerticalAngle && value != 0.0f && controller.minimumVerticalAngle != 0.0f) {
            return luaL_argerror(L, 2, "must be larger than minimumVerticalAngle") ;
        }
        if (value < -90.0f || value > 90.0f) return luaL_argerror(L, 2, "must be between -90 and 90 inclusive") ;
        controller.maximumVerticalAngle = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int controller_minimumVerticalAnglee(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, (lua_Number)controller.minimumVerticalAngle) ;
    } else {
        float value = (float)(lua_tonumber(L, 2)) ;
        if (value >= controller.maximumVerticalAngle && value != 0.0f && controller.minimumVerticalAngle != 0.0f) {
            return luaL_argerror(L, 2, "must be less than maximumVerticalAngle") ;
        }
        if (value < -90.0f || value > 90.0f) return luaL_argerror(L, 2, "must be between -90 and 90 inclusive") ;
        controller.minimumVerticalAngle = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int controller_target(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        pushSCNVector3(L, controller.target) ;
    } else {
        SCNVector3 vector = pullSCNVector3(L, 2) ;
        controller.target = vector ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int controller_worldUp(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        pushSCNVector3(L, controller.worldUp) ;
    } else {
        SCNVector3 vector = pullSCNVector3(L, 2) ;
        controller.worldUp = vector ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int controller_interactionMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [INTERACTION_MODE allKeysForObject:@(controller.interactionMode)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", controller.interactionMode] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = INTERACTION_MODE[key] ;
        if (value) {
            controller.interactionMode = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [INTERACTION_MODE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// ??? - does this need to release/retain? node initially assigned by os won't be retained by us, so...?
static int controller_pointOfView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:controller.pointOfView] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            controller.pointOfView = nil ;
        } else {
            [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.element.sceneKit.node", LS_TBREAK] ;
            controller.pointOfView = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int controller_dollyToTarget(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;
    float               delta       = (float)(lua_tonumber(L, 2)) ;

    [controller dollyToTarget:delta] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int controller_rollAroundTarget(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;
    float               delta       = (float)(lua_tonumber(L, 2)) ;

    [controller rollAroundTarget:delta] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int controller_rotateByX(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;
    float               deltaX      = (float)(lua_tonumber(L, 2)) ;
    float               deltaY      = (float)(lua_tonumber(L, 3)) ;

    [controller rotateByX:deltaX Y:deltaY] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int controller_translateInCameraSpaceByX(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;
    float               deltaX      = (float)(lua_tonumber(L, 2)) ;
    float               deltaY      = (float)(lua_tonumber(L, 3)) ;
    float               deltaZ      = (float)(lua_tonumber(L, 4)) ;

    [controller translateInCameraSpaceByX:deltaX Y:deltaY Z:deltaZ] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int controller_clearRoll(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;

    [controller clearRoll] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int controller_stopInertia(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;

    [controller stopInertia] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

// ??? - does this need to release/retain? node initially assigned by os won't be retained by us, so...?
static int controller_frameNodes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;

    NSArray    *nodes = [skin toNSObjectAtIndex:2] ;
    BOOL       isGood = [nodes isKindOfClass:[NSArray class]] ;
    NSUInteger count  = 0 ;
    while (isGood && count < nodes.count) {
        SCNNode *item = nodes[count++] ;
        isGood = [item isKindOfClass:[SCNNode class]] ;
    }
    if (!isGood) {
        return luaL_argerror(L, 2, "expected array of sceneKit node objects") ;
    }

    [controller frameNodes:nodes] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

// static int controller_beginInteraction(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
//     SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;
//     NSPoint             location    = [skin tableToPointAtIndex:2] ;
//     NSSize              viewport ;
//     if (lua_gettop(L) == 3) {
//         viewport = [skin tableToSizeAtIndex:3] ;
//     } else {
//         SCNView *view = controller.ownerView ;
//         if (view) {
//             viewport = view.frame.size ;
//         } else {
//             return luaL_argerror(L, 3, "no view captured and no viewport specified") ;
//         }
//     }
//
//     [controller beginInteraction:NSPointToCGPoint(location) withViewport:NSSizeToCGSize(viewport)] ;
//
//     lua_pushvalue(L, 1) ;
//     return 1 ;
// }
//
// static int controller_endInteraction(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TTABLE, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
//     SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;
//     NSPoint             location    = [skin tableToPointAtIndex:2] ;
//     NSPoint             velocity    = [skin tableToPointAtIndex:3] ;
//     NSSize              viewport ;
//     if (lua_gettop(L) == 4) {
//         viewport = [skin tableToSizeAtIndex:4] ;
//     } else {
//         SCNView *view = controller.ownerView ;
//         if (view) {
//             viewport = view.frame.size ;
//         } else {
//             return luaL_argerror(L, 4, "no view captured and no viewport specified") ;
//         }
//     }
//
//     [controller endInteraction:NSPointToCGPoint(location)
//                   withViewport:NSSizeToCGSize(viewport)
//                       velocity:NSPointToCGPoint(velocity)] ;
//
//     lua_pushvalue(L, 1) ;
//     return 1 ;
// }
//
// static int controller_continueInteraction(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TNUMBER, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
//     SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;
//     NSPoint             location    = [skin tableToPointAtIndex:2] ;
//     CGFloat             sensitivity = lua_tonumber(L, 3) ;
//     NSSize              viewport ;
//     if (lua_gettop(L) == 4) {
//         viewport = [skin tableToSizeAtIndex:4] ;
//     } else {
//         SCNView *view = controller.ownerView ;
//         if (view) {
//             viewport = view.frame.size ;
//         } else {
//             return luaL_argerror(L, 4, "no view captured and no viewport specified") ;
//         }
//     }
//
//     [controller continueInteraction:NSPointToCGPoint(location)
//                        withViewport:NSSizeToCGSize(viewport)
//                         sensitivity:sensitivity] ;
//
//     lua_pushvalue(L, 1) ;
//     return 1 ;
// }
//
// static int controller_dollyBy(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TTABLE, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
//     SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;
//     float               delta       = (float)(lua_tonumber(L, 2)) ;
//     NSPoint             location    = [skin tableToPointAtIndex:3] ;
//     NSSize              viewport ;
//
//     SCNView *view = controller.ownerView ;
//     if (view && view.window) {
//         viewport = view.frame.size ;
//         location = [view convertPoint:location toView:nil] ;     // convert to window coordinates
//         location = [view.window convertPointToScreen:location] ; // convert to screen coordinates
//         // now invert because HS has 0,0 in top-left, not bottom-left
//         location.y = [[NSScreen screens][0] frame].size.height - location.y ;
//     } else {
//         return luaL_argerror(L, 3, "no view captured; cannot convert to screen point") ;
//     }
//
//     if (lua_gettop(L) == 4) {
//         viewport = [skin tableToSizeAtIndex:4] ;
//     }
//     [skin logInfo:@"location = %@", NSStringFromPoint(location)] ;
//
//     [controller dollyBy:delta onScreenPoint:NSPointToCGPoint(location) viewport:NSSizeToCGSize(viewport)] ;
//
//     lua_pushvalue(L, 1) ;
//     return 1 ;
// }
//
// static int controller_rollBy(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TTABLE, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
//     SCNCameraController *controller = [skin toNSObjectAtIndex:1] ;
//     float               delta       = (float)(lua_tonumber(L, 2)) ;
//     NSPoint             location    = [skin tableToPointAtIndex:3] ;
//     NSSize              viewport ;
//
//     SCNView *view = controller.ownerView ;
//     if (view && view.window) {
//         viewport = view.frame.size ;
//         location = [view convertPoint:location toView:nil] ;     // convert to window coordinates
//         location = [view.window convertPointToScreen:location] ; // convert to screen coordinates
//         // now invert because HS has 0,0 in top-left, not bottom-left
//         location.y = [[NSScreen screens][0] frame].size.height - location.y ;
//     } else {
//         return luaL_argerror(L, 3, "no view captured; cannot convert to screen point") ;
//     }
//
//     if (lua_gettop(L) == 4) {
//         viewport = [skin tableToSizeAtIndex:4] ;
//     }
//     [skin logInfo:@"location = %@", NSStringFromPoint(location)] ;
//
//     [controller rollBy:delta aroundScreenPoint:NSPointToCGPoint(location) viewport:NSSizeToCGSize(viewport)] ;
//
//     lua_pushvalue(L, 1) ;
//     return 1 ;
// }

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNCameraController(lua_State *L, id obj) {
    SCNCameraController *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNCameraController *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNCameraController(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNCameraController *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNCameraController, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     SCNCameraController *obj = [skin luaObjectAtIndex:1 toClass:"SCNCameraController"] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        SCNCameraController *obj1 = [skin luaObjectAtIndex:1 toClass:"SCNCameraController"] ;
        SCNCameraController *obj2 = [skin luaObjectAtIndex:2 toClass:"SCNCameraController"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    SCNCameraController *obj = get_objectFromUserdata(__bridge_transfer SCNCameraController, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj.ownerView = nil ;
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
    {"inertiaRunning",           controller_inertiaRunning},
    {"dollyToTarget",            controller_dollyToTarget},
    {"rollAroundTarget",         controller_rollAroundTarget},
    {"rotateBy",                 controller_rotateByX},
    {"translateInCameraSpaceBy", controller_translateInCameraSpaceByX},
    {"clearRoll",                controller_clearRoll},
    {"stopInertia",              controller_stopInertia},
    {"frameNodes",               controller_frameNodes},

    {"inertiaEnabled",           controller_inertiaEnabled},
    {"automaticTarget",          controller_automaticTarget},
    {"inertiaFriction",          controller_inertiaFriction},
    {"maximumHorizontalAngle",   controller_maximumHorizontalAngle},
    {"minimumHorizontalAngle",   controller_minimumHorizontalAngle},
    {"maximumVerticalAngle",     controller_maximumVerticalAngle},
    {"minimumVerticalAnglee",    controller_minimumVerticalAnglee},
    {"target",                   controller_target},
    {"worldUp",                  controller_worldUp},
    {"interactionMode",          controller_interactionMode},
    {"pointOfView",              controller_pointOfView},

// // not really sure how to control them or what they do...
//     {"beginInteraction",         controller_beginInteraction},
//     {"endInteraction",           controller_endInteraction},
//     {"continueInteraction",      controller_continueInteraction},
//     {"dollyBy",                  controller_dollyBy},
//     {"rollBy",                   controller_rollBy},

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
int luaopen_hs__asm_uitk_element_libsceneKit_cameraController(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushSCNCameraController  forClass:"SCNCameraController"];
    [skin registerLuaObjectHelper:toSCNCameraController forClass:"SCNCameraController"
                                             withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"inertiaEnabled",
        @"automaticTarget",
        @"inertiaFriction",
        @"maximumHorizontalAngle",
        @"minimumHorizontalAngle",
        @"maximumVerticalAngle",
        @"minimumVerticalAnglee",
        @"target",
        @"worldUp",
        @"interactionMode",
        @"pointOfView",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
