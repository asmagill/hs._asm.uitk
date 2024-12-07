@import Cocoa ;
@import LuaSkin ;
@import SceneKit ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.sceneKit" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_anyObjectFromUserdata(objType, L, idx) (objType*)*((void**)lua_touserdata(L, idx))

static NSDictionary *ANTIALIASING_MODE ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    ANTIALIASING_MODE = @{
        @"none" : @(SCNAntialiasingModeNone),
        @"2x"   : @(SCNAntialiasingModeMultisampling2X),
        @"4x"   : @(SCNAntialiasingModeMultisampling4X),
        @"8x"   : @(SCNAntialiasingModeMultisampling8X),
        @"16x"  : @(SCNAntialiasingModeMultisampling16X),
    } ;
}

@interface SCNCameraController (HammerspoonAdditions)
@property (nonatomic) SCNView *ownerView ;
@end

@interface HSUITKElementSCNView : SCNView
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
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
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
    } else {
        NSDictionary *newConfig = [skin toNSObjectAtIndex:2] ;
        if (![newConfig isKindOfClass:[NSDictionary class]]) return luaL_argerror(L, 2, "expected table of key-value pairs") ;
        NSNumber *value = newConfig[@"allowsTranslation"] ;
        if (value) {
            if ([value isKindOfClass:[NSNumber class]]) {
                config.allowsTranslation = value.boolValue ;
            } else {
                [skin logWarn:@"expected boolean value for allowsTranslation; ignoring"] ;
            }
        }
        value = newConfig[@"autoSwitchToFreeCamera"] ;
        if (value) {
            if ([value isKindOfClass:[NSNumber class]]) {
                config.autoSwitchToFreeCamera = value.boolValue ;
            } else {
                [skin logWarn:@"expected boolean value for autoSwitchToFreeCamera; ignoring"] ;
            }
        }
        value = newConfig[@"flyModeVelocity"] ;
        if (value) {
            if ([value isKindOfClass:[NSNumber class]]) {
                config.flyModeVelocity = value.doubleValue ;
            } else {
                [skin logWarn:@"expected number value for flyModeVelocity; ignoring"] ;
            }
        }
        value = newConfig[@"panSensitivity"] ;
        if (value) {
            if ([value isKindOfClass:[NSNumber class]]) {
                config.panSensitivity = value.doubleValue ;
            } else {
                [skin logWarn:@"expected number value for panSensitivity; ignoring"] ;
            }
        }
        value = newConfig[@"rotationSensitivity"] ;
        if (value) {
            if ([value isKindOfClass:[NSNumber class]]) {
                config.rotationSensitivity = value.doubleValue ;
            } else {
                [skin logWarn:@"expected number value for rotationSensitivity; ignoring"] ;
            }
        }
        value = newConfig[@"truckSensitivity"] ;
        if (value) {
            if ([value isKindOfClass:[NSNumber class]]) {
                config.truckSensitivity = value.doubleValue ;
            } else {
                [skin logWarn:@"expected number value for truckSensitivity; ignoring"] ;
            }
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

static int sceneKit_scene_wantsScreenSpaceReflection(lua_State *L) {
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

static int sceneKit_scene_paused(lua_State *L) {
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
static int sceneKit_scene_fogDensityExponent(lua_State *L) {
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
static int sceneKit_scene_fogEndDistance(lua_State *L) {
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
static int sceneKit_scene_fogStartDistance(lua_State *L) {
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
static int sceneKit_scene_screenSpaceReflectionMaximumDistance(lua_State *L) {
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
static int sceneKit_scene_screenSpaceReflectionStride(lua_State *L) {
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
static int sceneKit_scene_screenSpaceReflectionSampleCount(lua_State *L) {
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

static int sceneKit_scene_fogColor(lua_State *L) {
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

static int sceneKit_scene_backgroundMaterial(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;
    SCNScene             *scene = view.scene ;

    [skin pushNSObject:scene.background] ;
    return 1 ;
}

static int sceneKit_scene_lightingEnvironment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;
    SCNScene             *scene = view.scene ;

    [skin pushNSObject:scene.lightingEnvironment] ;
    return 1 ;
}

static int sceneKit_scene_rootNode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementSCNView *view  = [skin toNSObjectAtIndex:1] ;
    SCNScene             *scene = view.scene ;

    [skin pushNSObject:scene.rootNode] ;
    return 1 ;
}

// static int sceneKit_scene_physicsWorld(lua_State *L) {
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

#pragma mark - Module Constants -

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

    {"cameraControlConfig",   sceneKit_cameraControlConfiguration},
    {"defaultCamera",         sceneKit_defaultCameraController},
    {"backgroundMaterial",    sceneKit_scene_backgroundMaterial},
    {"lightingEnvironment",   sceneKit_scene_lightingEnvironment},
    {"rootNode",              sceneKit_scene_rootNode},
//     {"physicsWorld",          sceneKit_scene_physicsWorld},

    {"resizesAsynchronously", sceneKit_drawableResizesAsynchronously},
    {"rendersContinuously",   sceneKit_rendersContinuously},
    {"allowsCameraControl",   sceneKit_allowsCameraControl},
    {"backgroundColor",       sceneKit_backgroundColor},
    {"preferredFPS",          sceneKit_preferredFramesPerSecond},
    {"antialiasingMode",      sceneKit_antialiasingMode},
    {"passthroughCallback",   sceneKit_passthroughCallback},
    {"wantsReflection",       sceneKit_scene_wantsScreenSpaceReflection},
    {"paused",                sceneKit_scene_paused},
    {"fogDensityExponent",    sceneKit_scene_fogDensityExponent},
    {"fogEndDistance",        sceneKit_scene_fogEndDistance},
    {"fogStartDistance",      sceneKit_scene_fogStartDistance},
    {"reflectionMaxDistance", sceneKit_scene_screenSpaceReflectionMaximumDistance},
    {"reflectionStride",      sceneKit_scene_screenSpaceReflectionStride},
    {"reflectionSampleCount", sceneKit_scene_screenSpaceReflectionSampleCount},
    {"fogColor",              sceneKit_scene_fogColor},

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
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pop(L, 1) ;

    return 1;
}
