@import Cocoa ;
@import LuaSkin ;
@import SceneKit ;
#import "SKconversions.h"

static const char * const USERDATA_TAG = "hs._asm.uitk.element.sceneKit" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_anyObjectFromUserdata(objType, L, idx) (objType*)*((void**)lua_touserdata(L, idx))

static NSDictionary *ANTIALIASING_MODE ;
static NSDictionary *DEBUG_OPTIONS ;
static NSDictionary *RENDERING_API ;

static const NSUInteger scnDebugOptionAll = (1 << 11) - 1 ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    ANTIALIASING_MODE = @{
        @"none" : @(SCNAntialiasingModeNone),
        @"2x"   : @(SCNAntialiasingModeMultisampling2X),
        @"4x"   : @(SCNAntialiasingModeMultisampling4X),
        @"8x"   : @(SCNAntialiasingModeMultisampling8X),
        @"16x"  : @(SCNAntialiasingModeMultisampling16X),
    } ;

    DEBUG_OPTIONS = @{
        @"none"                : @(SCNDebugOptionNone),
        @"showPhysicsShapes"   : @(SCNDebugOptionShowPhysicsShapes),
        @"showBoundingBoxes"   : @(SCNDebugOptionShowBoundingBoxes),
        @"showLightInfluences" : @(SCNDebugOptionShowLightInfluences),
        @"showLightExtents"    : @(SCNDebugOptionShowLightExtents),
        @"showPhysicsFields"   : @(SCNDebugOptionShowPhysicsFields),
        @"showWireframe"       : @(SCNDebugOptionShowWireframe),
        @"renderAsWireframe"   : @(SCNDebugOptionRenderAsWireframe),
        @"showSkeletons"       : @(SCNDebugOptionShowSkeletons),
        @"showCreases"         : @(SCNDebugOptionShowCreases),
        @"showConstraints"     : @(SCNDebugOptionShowConstraints),
        @"showCameras"         : @(SCNDebugOptionShowCameras),
        @"all"                  :@(scnDebugOptionAll),
    } ;

    RENDERING_API = @{
        @"metal"        : @(SCNRenderingAPIMetal),
        @"openGLCore32" : @(SCNRenderingAPIOpenGLCore32),
        @"openGLCore41" : @(SCNRenderingAPIOpenGLCore41),
        @"openGLLegacy" : @(SCNRenderingAPIOpenGLLegacy),
    } ;
}

@interface SCNCameraController (HammerspoonAdditions)
@property (nonatomic) SCNView *ownerView ;
@end

@interface HSUITKElementSCNView : SCNView <SCNSceneRendererDelegate>
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;
@end

@implementation HSUITKElementSCNView

- (instancetype)initWithFrame:(NSRect)frame options:(NSDictionary<NSString *,id> *)options
                                          withState:(lua_State *)L {
    @try {
        self = [super initWithFrame:frame options:options] ;
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:new - %@", USERDATA_TAG, exception.reason]] ;
        self = nil ;
    }

    if (self) {
        _selfRefCount = 0 ;
        _callbackRef  = LUA_NOREF ;
        _refTable     = refTable ;

        self.scene    = [SCNScene scene] ;
        self.delegate = self ;

        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        [skin luaRetain:refTable forNSObject:self.scene.rootNode] ;
        self.scene.rootNode.name = @"rootNode" ;
    }

    return self ;
}

// // Follow the Hammerspoon convention
// - (BOOL)isFlipped { return YES; }

// NOTE: Passthrough Callback Support

// allow next responder a chance since we don't have a callback set
- (void)passCallbackUpWith:(NSArray *)arguments {
    NSResponder *nextInChain = [self nextResponder] ;

    SEL passthroughCallback = NSSelectorFromString(@"performPassthroughCallback:") ;
    while(nextInChain) {
        if ([nextInChain respondsToSelector:passthroughCallback]) {
            [nextInChain performSelectorOnMainThread:passthroughCallback
                                          withObject:arguments
                                       waitUntilDone:YES] ;
            break ;
        } else {
            nextInChain = nextInChain.nextResponder ;
        }
    }
}

// perform callback for subviews which don't have a callback defined
- (void)performPassthroughCallback:(NSArray *)arguments {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin    = [LuaSkin sharedWithState:NULL] ;
        int     argCount = 1 ;

        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:self] ;
        if (arguments) {
            [skin pushNSObject:arguments] ;
            argCount += 1 ;
        }
        if (![skin protectedCallAndTraceback:argCount nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:passthroughCallback error:%@", USERDATA_TAG, errorMessage]] ;
        }
    } else {
        [self passCallbackUpWith:@[ self, arguments ]] ;
    }
}

// NOTE - SCNSceneRendererDelegate methods -

// - (void)renderer:(id<SCNSceneRenderer>)renderer didApplyAnimationsAtTime:(NSTimeInterval)time;
// - (void)renderer:(id<SCNSceneRenderer>)renderer didApplyConstraintsAtTime:(NSTimeInterval)time;
// - (void)renderer:(id<SCNSceneRenderer>)renderer didRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time;
// - (void)renderer:(id<SCNSceneRenderer>)renderer didSimulatePhysicsAtTime:(NSTimeInterval)time;
// - (void)renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time;
// - (void)renderer:(id<SCNSceneRenderer>)renderer willRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time;

@end

#pragma mark - Module Functions -

static int sceneKit_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = NSZeroRect ;
    BOOL   lowPower  = YES ;
    if (lua_gettop(L) > 0) {
        if (lua_type(L, 1) == LUA_TTABLE) {
            frameRect = [skin tableToRectAtIndex:1] ;
        }
        if (lua_type(L, -1) == LUA_TBOOLEAN) {
            lowPower = (BOOL)(lua_toboolean(L, -1)) ;
        }
    }

    NSDictionary *options = @{
        SCNPreferLowPowerDeviceKey  : @(lowPower),
        SCNPreferredRenderingAPIKey : @(SCNRenderingAPIMetal), // will fall back if necessary
//         SCNPreferredDeviceKey       : allows choosing GPU, default is best for Metal
    } ;

    HSUITKElementSCNView *view = [[HSUITKElementSCNView alloc] initWithFrame:frameRect
                                                                     options:options
                                                                   withState:L] ;

    if (view) {
        if (lua_type(L, 1) != LUA_TTABLE) [view setFrameSize:[view fittingSize]] ;
        [skin pushNSObject:view] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods - SCNView -

static int sceneKit_pause(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementSCNView *view = [skin toNSObjectAtIndex:1] ;

    [view pause:view] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int sceneKit_play(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementSCNView *view = [skin toNSObjectAtIndex:1] ;

    [view play:view] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int sceneKit_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementSCNView *view = [skin toNSObjectAtIndex:1] ;

    [view stop:view] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int sceneKit_snapshot(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementSCNView *view = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:[view snapshot]] ;
    return 1 ;
}

static int sceneKit_drawableResizesAsynchronously(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, view.drawableResizesAsynchronously) ;
    } else {
        view.drawableResizesAsynchronously = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int sceneKit_rendersContinuously(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, view.rendersContinuously) ;
    } else {
        view.rendersContinuously = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int sceneKit_allowsCameraControl(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, view.allowsCameraControl) ;
    } else {
        view.allowsCameraControl = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int sceneKit_backgroundColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:view.backgroundColor] ;
    } else {
        NSColor *newColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        if ([newColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace]) {
            view.backgroundColor = newColor ;
        } else {
            return luaL_argerror(L, 2, "color must be representable in the RGBA color space") ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int sceneKit_preferredFramesPerSecond(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementSCNView *view = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, view.preferredFramesPerSecond) ;
    } else {
        NSInteger fps = lua_tointeger(L, 2) ;
        if (fps > 0) {
            view.preferredFramesPerSecond = fps ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, "preferred fps must be positive") ;
        }
    }
    return 1 ;
}

static int sceneKit_antialiasingMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [ANTIALIASING_MODE allKeysForObject:@(view.antialiasingMode)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", view.antialiasingMode] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = ANTIALIASING_MODE[key] ;
        if (value) {
            view.antialiasingMode = value.unsignedLongLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [ANTIALIASING_MODE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int sceneKit_passthroughCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        view.callbackRef = [skin luaUnref:refTable ref:view.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            view.callbackRef = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (view.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:view.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int sceneKit_cameraControlConfiguration(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TSTRING | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementSCNView *view = [skin toNSObjectAtIndex:1] ;

    id<SCNCameraControlConfiguration> config = view.cameraControlConfiguration ;
    if (lua_gettop(L) == 1) {
        lua_newtable(L) ;
        lua_pushboolean(L, config.allowsTranslation) ;      lua_setfield(L, -2, "allowsTranslation") ;
        lua_pushboolean(L, config.autoSwitchToFreeCamera) ; lua_setfield(L, -2, "autoSwitchToFreeCamera") ;
        lua_pushnumber(L, config.flyModeVelocity) ;         lua_setfield(L, -2, "flyModeVelocity") ;
        lua_pushnumber(L, config.panSensitivity) ;          lua_setfield(L, -2, "panSensitivity") ;
        lua_pushnumber(L, config.rotationSensitivity) ;     lua_setfield(L, -2, "rotationSensitivity") ;
        lua_pushnumber(L, config.truckSensitivity) ;        lua_setfield(L, -2, "truckSensitivity") ;
    } else if (lua_gettop(L) == 2) {
        [skin checkArgs:LS_TANY, LS_TTABLE, LS_TBREAK] ;
        NSDictionary *newConfig = [skin toNSObjectAtIndex:2] ;
        if (![newConfig isKindOfClass:[NSDictionary class]]) return luaL_argerror(L, 2, "expected table of key-value pairs") ;

        BOOL    allowsTranslation      = config.allowsTranslation ;
        BOOL    autoSwitchToFreeCamera = config.autoSwitchToFreeCamera ;
        CGFloat flyModeVelocity        = config.flyModeVelocity ;
        CGFloat panSensitivity         = config.panSensitivity ;
        CGFloat rotationSensitivity    = config.rotationSensitivity ;
        CGFloat truckSensitivity       = config.truckSensitivity ;

        NSNumber *value = newConfig[@"allowsTranslation"] ;
        if (value) {
            if ([value isKindOfClass:[NSNumber class]]) {
                allowsTranslation = value.boolValue ;
            } else {
                return luaL_argerror(L, 2, "expected boolean value for allowsTranslation") ;
            }
        }
        value = newConfig[@"autoSwitchToFreeCamera"] ;
        if (value) {
            if ([value isKindOfClass:[NSNumber class]]) {
                autoSwitchToFreeCamera = value.boolValue ;
            } else {
                return luaL_argerror(L, 2, "expected boolean value for autoSwitchToFreeCamera") ;
            }
        }
        value = newConfig[@"flyModeVelocity"] ;
        if (value) {
            if ([value isKindOfClass:[NSNumber class]]) {
                flyModeVelocity = value.doubleValue ;
            } else {
                return luaL_argerror(L, 2, "expected number value for flyModeVelocity") ;
            }
        }
        value = newConfig[@"panSensitivity"] ;
        if (value) {
            if ([value isKindOfClass:[NSNumber class]]) {
                panSensitivity = value.doubleValue ;
            } else {
                return luaL_argerror(L, 2, "expected number value for panSensitivity") ;
            }
        }
        value = newConfig[@"rotationSensitivity"] ;
        if (value) {
            if ([value isKindOfClass:[NSNumber class]]) {
                rotationSensitivity = value.doubleValue ;
            } else {
                return luaL_argerror(L, 2, "expected number value for rotationSensitivity") ;
            }
        }
        value = newConfig[@"truckSensitivity"] ;
        if (value) {
            if ([value isKindOfClass:[NSNumber class]]) {
                truckSensitivity = value.doubleValue ;
            } else {
                return luaL_argerror(L, 2, "expected number value for truckSensitivity") ;
            }
        }

        config.allowsTranslation      = allowsTranslation ;
        config.autoSwitchToFreeCamera = autoSwitchToFreeCamera ;
        config.flyModeVelocity        = flyModeVelocity ;
        config.panSensitivity         = panSensitivity ;
        config.rotationSensitivity    = rotationSensitivity ;
        config.truckSensitivity       = truckSensitivity ;

        lua_pushvalue(L, 1) ;
    } else {
        [skin checkArgs:LS_TANY, LS_TSTRING, LS_TBOOLEAN | LS_TNUMBER, LS_TBREAK] ;
        NSString *attribute = [skin toNSObjectAtIndex:2] ;
        NSNumber *value     = [skin toNSObjectAtIndex:3] ;

        if ([attribute isEqualToString:@"allowsTranslation"]) {
            config.allowsTranslation = value.boolValue ;
        } else if ([attribute isEqualToString:@"autoSwitchToFreeCamera"]) {
            config.autoSwitchToFreeCamera = value.boolValue ;
        } else if ([attribute isEqualToString:@"flyModeVelocity"]) {
            config.flyModeVelocity = value.doubleValue ;
        } else if ([attribute isEqualToString:@"panSensitivity"]) {
            config.panSensitivity = value.doubleValue ;
        } else if ([attribute isEqualToString:@"rotationSensitivity"]) {
            config.rotationSensitivity = value.doubleValue ;
        } else if ([attribute isEqualToString:@"truckSensitivity"]) {
            config.truckSensitivity = value.doubleValue ;
        } else {
            return luaL_argerror(L, 2, "unrecognized attribute name") ;
        }

        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int sceneKit_defaultCameraController(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementSCNView *view = [skin toNSObjectAtIndex:1] ;

    view.defaultCameraController.ownerView = view ;
    [skin pushNSObject:view.defaultCameraController] ;
    return 1 ;
}

#pragma mark - Module Methods - SCNScene -

static int scene_wantsScreenSpaceReflection(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;
    SCNScene             *scene = view.scene ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, scene.wantsScreenSpaceReflection) ;
    } else {
        scene.wantsScreenSpaceReflection = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scene_paused(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;
    SCNScene             *scene = view.scene ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, scene.paused) ;
    } else {
        scene.paused = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// FIXME: need to see if this needs to be constrained (e.g. not negative)
static int scene_fogDensityExponent(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;
    SCNScene             *scene = view.scene ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, scene.fogDensityExponent) ;
    } else {
        scene.fogDensityExponent = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// FIXME: need to see if this needs to be constrained (e.g. not negative)
static int scene_fogEndDistance(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;
    SCNScene             *scene = view.scene ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, scene.fogEndDistance) ;
    } else {
        scene.fogEndDistance = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// FIXME: need to see if this needs to be constrained (e.g. not negative)
static int scene_fogStartDistance(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;
    SCNScene             *scene = view.scene ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, scene.fogStartDistance) ;
    } else {
        scene.fogStartDistance = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// FIXME: need to see if this needs to be constrained (e.g. not negative)
static int scene_screenSpaceReflectionMaximumDistance(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;
    SCNScene             *scene = view.scene ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, scene.screenSpaceReflectionMaximumDistance) ;
    } else {
        scene.screenSpaceReflectionMaximumDistance = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// FIXME: need to see if this needs to be constrained (e.g. not negative)
static int scene_screenSpaceReflectionStride(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;
    SCNScene             *scene = view.scene ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, scene.screenSpaceReflectionStride) ;
    } else {
        scene.screenSpaceReflectionStride = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// FIXME: need to see if this needs to be constrained (e.g. not negative)
static int scene_screenSpaceReflectionSampleCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;
    SCNScene             *scene = view.scene ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, scene.screenSpaceReflectionSampleCount) ;
    } else {
        scene.screenSpaceReflectionSampleCount = lua_tointeger(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scene_fogColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;
    SCNScene             *scene = view.scene ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:scene.fogColor] ;
    } else {
        scene.fogColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scene_background(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;
    SCNScene             *scene = view.scene ;

    [skin pushNSObject:scene.background] ;
    return 1 ;
}

static int scene_lightingEnvironment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;
    SCNScene             *scene = view.scene ;

    [skin pushNSObject:scene.lightingEnvironment] ;
    return 1 ;
}

static int scene_rootNode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;
    SCNScene             *scene = view.scene ;

    [skin pushNSObject:scene.rootNode] ;
    return 1 ;
}

// static int scene_physicsWorld(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
//     HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;
//     SCNScene             *scene = view.scene ;
//
//     [skin pushNSObject:scene.physicsWorld] ;
//     return 1 ;
// }

// - (id)attributeForKey:(NSString *)key;
// - (void)setAttribute:(id)attribute forKey:(NSString *)key;
//
// Let's see if we need these first
//     SCNSceneEndTimeAttributeKey
//        A floating-point value (in an NSNumber object) for the end time of the scene.
//     SCNSceneStartTimeAttributeKey
//        A floating-point value (in an NSNumber object) for the start time of the scene.
//
// Has no effect on scene processing (from imported file, which we're not supporting)
//     SCNSceneFrameRateAttributeKey
//        A floating-point value (in an NSNumber object) for the frame rate of the scene.
//     SCNSceneUpAxisAttributeKey
//        An SCNVector3 structure (in an NSValue object) specifying the orientation of the scene.

// Let's see if we're going to support SCNParticleSystem
//     - (void)addParticleSystem:(SCNParticleSystem *)system withTransform:(SCNMatrix4)transform;
//     - (void)removeAllParticleSystems;
//     - (void)removeParticleSystem:(SCNParticleSystem *)system;
//     @property(readonly) NSArray<SCNParticleSystem *> *particleSystems;

#pragma mark - SCNSceneRenderer Protocol Methods -

static int sceneRenderer_autoenablesDefaultLighting(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, view.autoenablesDefaultLighting) ;
    } else {
        view.autoenablesDefaultLighting = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int sceneRenderer_loops(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, view.loops) ;
    } else {
        view.loops = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int sceneRenderer_showsStatistics(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, view.showsStatistics) ;
    } else {
        view.showsStatistics = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int sceneRenderer_usesReverseZ(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, view.usesReverseZ) ;
    } else {
        view.usesReverseZ = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int sceneRenderer_playing(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, view.playing) ;
    } else {
        view.playing = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int sceneRenderer_jitteringEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, view.jitteringEnabled) ;
    } else {
        view.jitteringEnabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int sceneRenderer_temporalAntialiasingEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, view.temporalAntialiasingEnabled) ;
    } else {
        view.temporalAntialiasingEnabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int sceneRenderer_pointOfView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:view.pointOfView] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            view.pointOfView = nil ;
        } else {
            [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.element.sceneKit.node", LS_TBREAK] ;
            SCNNode *node = [skin toNSObjectAtIndex:2] ;
            if (!(node.camera || (node.light && node.light.type == SCNLightTypeSpot))) {
                return luaL_argerror(L, 2, "node must have a camera or a spotlight assigned") ;
            }
            view.pointOfView = node ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int sceneRenderer_debugOptions(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, (lua_Integer)view.debugOptions) ;
    } else {
        view.debugOptions = (NSUInteger)(lua_tointeger(L, 2)) & scnDebugOptionAll ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int sceneRenderer_currentViewport(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;

    [skin pushNSRect:NSRectFromCGRect(view.currentViewport)] ;
    return 1 ;
}

static int sceneRenderer_renderingAPI(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSCNView *view = [skin toNSObjectAtIndex:1] ;

    NSArray  *keys   = [RENDERING_API allKeysForObject:@(view.renderingAPI)] ;
    NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", view.renderingAPI] ;
    [skin pushNSObject:answer] ;
    return 1 ;
}

static int sceneRenderer_projectPoint(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    HSUITKElementSCNView *view = [skin toNSObjectAtIndex:1] ;

    SCNVector3 point  = pullSCNVector3(L, 2) ;
    pushSCNVector3(L, [view projectPoint:point]) ;
    return 1 ;
}

static int sceneRenderer_unprojectPoint(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    HSUITKElementSCNView *view = [skin toNSObjectAtIndex:1] ;

    SCNVector3 point  = pullSCNVector3(L, 2) ;
    pushSCNVector3(L, [view unprojectPoint:point]) ;
    return 1 ;
}

// // probably
// - (BOOL)isNodeInsideFrustum:(SCNNode *)node withPointOfView:(SCNNode *)pointOfView;
// - (NSArray<SCNNode *> *)nodesInsideFrustumWithPointOfView:(SCNNode *)pointOfView;

// // maybe
// - (NSArray<SCNHitTestResult *> *)hitTest:(CGPoint)point options:(NSDictionary<SCNHitTestOption, id> *)options;

// // if we add SCNAnimation* support, then maybe; see SCNSceneEndTimeAttributeKey and
// //     SCNSceneStartTimeAttributeKey above
// @property(nonatomic) NSTimeInterval sceneTime;

// // if we add SCNAudioPlayer/Source, then maybe
// @property(nonatomic, retain, nullable) SCNNode *audioListener;

// // if we ever add SpriteKit support to uitk, then maybe
// @property(nonatomic, retain, nullable) SKScene *overlaySKScene;

// // at present, we're merging scnview and scnscene, so no way to change scene; if that changes...
// - (void)presentScene:(SCNScene *)scene withTransition:(SKTransition *)transition incomingPointOfView:(SCNNode *)pointOfView completionHandler:(void (^)(void))completionHandler;

// // probably not useful; informational only anyways
// @property(nonatomic, readonly, nullable) id<MTLCommandQueue> commandQueue;
// @property(nonatomic, readonly, nullable) id<MTLDevice> device;
// @property(nonatomic, readonly, nullable) id<MTLRenderCommandEncoder> currentRenderCommandEncoder;
// @property(nonatomic, readonly, nullable) void *context;
// @property(nonatomic, readonly) AVAudioEngine *audioEngine;
// @property(nonatomic, readonly) AVAudioEnvironmentNode *audioEnvironmentNode;
// @property(nonatomic, readonly) CGColorSpaceRef workingColorSpace;
// @property(nonatomic, readonly) MTLPixelFormat colorPixelFormat;
// @property(nonatomic, readonly) MTLPixelFormat depthPixelFormat;
// @property(nonatomic, readonly) MTLPixelFormat stencilPixelFormat;
// @property(nonatomic, readonly) MTLRenderPassDescriptor *currentRenderPassDescriptor;

// - (BOOL)prepareObject:(id)object shouldAbortBlock:(BOOL (^)(void))block;
// - (void)prepareObjects:(NSArray *)objects withCompletionHandler:(void (^)(BOOL success))completionHandler;

#pragma mark - Module Constants -

static int sceneRenderer_debugMasks(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:DEBUG_OPTIONS] ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementSCNView(lua_State *L, id obj) {
    HSUITKElementSCNView *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementSCNView *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementSCNView(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementSCNView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementSCNView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_gc(lua_State* L) {
    HSUITKElementSCNView *obj = get_objectFromUserdata(__bridge_transfer HSUITKElementSCNView, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef      = [skin luaUnref:refTable ref:obj.callbackRef] ;

            [skin luaRelease:refTable forNSObject:obj.scene.rootNode] ;
            obj = nil ;
        }
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"pause",                 sceneKit_pause},
    {"play",                  sceneKit_play},
    {"stop",                  sceneKit_stop},
    {"snapshot",              sceneKit_snapshot},

    {"defaultCamera",         sceneKit_defaultCameraController},
    {"background",            scene_background},
    {"lightingEnvironment",   scene_lightingEnvironment},
    {"rootNode",              scene_rootNode},
//     {"physicsWorld",          scene_physicsWorld},
    {"currentViewport",       sceneRenderer_currentViewport},
    {"renderingAPI",          sceneRenderer_renderingAPI},
    {"projectPoint",          sceneRenderer_projectPoint},
    {"unprojectPoint",        sceneRenderer_unprojectPoint},

    {"resizesAsynchronously", sceneKit_drawableResizesAsynchronously},
    {"rendersContinuously",   sceneKit_rendersContinuously},
    {"allowsCameraControl",   sceneKit_allowsCameraControl},
    {"backgroundColor",       sceneKit_backgroundColor},
    {"cameraControlConfig",   sceneKit_cameraControlConfiguration},
    {"preferredFPS",          sceneKit_preferredFramesPerSecond},
    {"antialiasingMode",      sceneKit_antialiasingMode},
    {"passthroughCallback",   sceneKit_passthroughCallback},
    {"wantsReflection",       scene_wantsScreenSpaceReflection},
    {"paused",                scene_paused},
    {"fogDensityExponent",    scene_fogDensityExponent},
    {"fogEndDistance",        scene_fogEndDistance},
    {"fogStartDistance",      scene_fogStartDistance},
    {"reflectionMaxDistance", scene_screenSpaceReflectionMaximumDistance},
    {"reflectionStride",      scene_screenSpaceReflectionStride},
    {"reflectionSampleCount", scene_screenSpaceReflectionSampleCount},
    {"fogColor",              scene_fogColor},
    {"enableDefaultLighting", sceneRenderer_autoenablesDefaultLighting},
    {"loops",                 sceneRenderer_loops},
    {"showsStatistics",       sceneRenderer_showsStatistics},
    {"usesReverseZ",          sceneRenderer_usesReverseZ},
    {"playing",               sceneRenderer_playing},
    {"jitteringEnabled",      sceneRenderer_jitteringEnabled},
    {"temporalAntialiasing",  sceneRenderer_temporalAntialiasingEnabled},
    {"pointOfView",           sceneRenderer_pointOfView},
    {"debugOptions",          sceneRenderer_debugOptions},

// other metamethods inherited from _control and _view
    {"__gc",                  userdata_gc},
    {NULL,                    NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", sceneKit_new},
    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_element_libsceneKit(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKElementSCNView  forClass:"HSUITKElementSCNView"];
    [skin registerLuaObjectHelper:toHSUITKElementSCNView forClass:"HSUITKElementSCNView"
                                              withUserdataMapping:USERDATA_TAG];

    sceneRenderer_debugMasks(L) ; lua_setfield(L, -2, "debugMasks") ;

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"resizesAsynchronously",
        @"rendersContinuously",
        @"allowsCameraControl",
        @"backgroundColor",
        @"cameraControlConfig",
        @"preferredFPS",
        @"antialiasingMode",
        @"passthroughCallback",
        @"wantsReflection",
        @"paused",
        @"fogDensityExponent",
        @"fogEndDistance",
        @"fogStartDistance",
        @"reflectionMaxDistance",
        @"reflectionStride",
        @"reflectionSampleCount",
        @"fogColor",
        @"enableDefaultLighting",
        @"loops",
        @"showsStatistics",
        @"usesReverseZ",
        @"playing",
        @"jitteringEnabled",
        @"temporalAntialiasing",
        @"pointOfView",
        @"debugOptions",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)

    [skin pushNSObject:@[
        @"background",
        @"lightingEnvironment",
    ]] ;
    lua_setfield(L, -2, "_materialProperties") ;
    lua_pop(L, 1) ;

    return 1;
}
