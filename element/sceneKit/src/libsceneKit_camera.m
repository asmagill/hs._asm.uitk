@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;
#import "SKconversions.h"

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.camera" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_anyObjectFromUserdata(objType, L, idx) (objType*)*((void**)lua_touserdata(L, idx))

static NSDictionary *PROJECTION_DIRECTION ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    PROJECTION_DIRECTION = @{
        @"vertical"   : @(SCNCameraProjectionDirectionVertical),
        @"horizontal" : @(SCNCameraProjectionDirectionHorizontal),
    } ;
}

@interface SCNCamera (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation SCNCamera (HammerspoonAdditions)

+ (instancetype)cameraWithName:(NSString *)name {
    SCNCamera *camera = [SCNCamera camera] ;

    if (camera) {
        camera.callbackRef  = LUA_NOREF ;
        camera.selfRefCount = 0 ;
        camera.name         = name ;
    }
    return camera ;
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

static int camera_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *name = (lua_gettop(L)) == 1 ? [skin toNSObjectAtIndex:1] : [[NSUUID UUID] UUIDString] ;

    SCNCamera *camera = [SCNCamera cameraWithName:name] ;
    if (camera) {
        [skin pushNSObject:camera] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int camera_gobo(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:camera.colorGrading] ;
    return 1 ;
}


static int camera_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:camera.name] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            camera.name = nil ;
        } else {
            NSString *newName = [skin toNSObjectAtIndex:2] ;
            camera.name = newName ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_automaticallyAdjustsZRange(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, camera.automaticallyAdjustsZRange) ;
    } else {
        camera.automaticallyAdjustsZRange = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_grainIsColored(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, camera.grainIsColored) ;
    } else {
        camera.grainIsColored = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_usesOrthographicProjection(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, camera.usesOrthographicProjection) ;
    } else {
        camera.usesOrthographicProjection = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_wantsDepthOfField(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, camera.wantsDepthOfField) ;
    } else {
        camera.wantsDepthOfField = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_wantsExposureAdaptation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, camera.wantsExposureAdaptation) ;
    } else {
        camera.wantsExposureAdaptation = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_wantsHDR(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, camera.wantsHDR) ;
    } else {
        camera.wantsHDR = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// FIXME: should this be constrained?
static int camera_averageGray(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.averageGray) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        camera.averageGray = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_bloomBlurRadius(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.bloomBlurRadius) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.bloomBlurRadius = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_bloomIntensity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.bloomIntensity) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.bloomIntensity = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_bloomIterationSpread(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.bloomIterationSpread) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.bloomIterationSpread = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// FIXME: should this be constrained?
static int camera_bloomThreshold(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.bloomThreshold) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        camera.bloomThreshold = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}


static int camera_colorFringeIntensity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.colorFringeIntensity) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0 || value > 1.0) return luaL_argerror(L, 2, "must be between 0.0 and 1.0 inclusive") ;
        camera.colorFringeIntensity = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_colorFringeStrength(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.colorFringeStrength) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.colorFringeStrength = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_contrast(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.contrast) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.contrast = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_exposureAdaptationBrighteningSpeedFactor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.exposureAdaptationBrighteningSpeedFactor) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.exposureAdaptationBrighteningSpeedFactor = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_exposureAdaptationDarkeningSpeedFactor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.exposureAdaptationDarkeningSpeedFactor) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.exposureAdaptationDarkeningSpeedFactor = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_exposureOffset(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.exposureOffset) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        camera.exposureOffset = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_fieldOfView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.fieldOfView) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.fieldOfView = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_focalLength(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.focalLength) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.fieldOfView = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_focusDistance(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.focusDistance) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.focusDistance = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_fStop(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.fStop) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value <= 0.0) return luaL_argerror(L, 2, "must be greater than zero") ;
        camera.fStop = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_grainIntensity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.grainIntensity) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.grainIntensity = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_grainScale(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.grainScale) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        camera.grainScale = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_maximumExposure(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.maximumExposure) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        camera.maximumExposure = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_minimumExposure(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.minimumExposure) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        camera.minimumExposure = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_motionBlurIntensity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.motionBlurIntensity) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0 || value > 1.0) return luaL_argerror(L, 2, "must be between 0.0 and 1.0 inclusive") ;
        camera.motionBlurIntensity = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_saturation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.saturation) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.saturation = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_screenSpaceAmbientOcclusionIntensity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.screenSpaceAmbientOcclusionIntensity) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.screenSpaceAmbientOcclusionIntensity = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_screenSpaceAmbientOcclusionRadius(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.screenSpaceAmbientOcclusionRadius) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value <= 0.0) return luaL_argerror(L, 2, "must be greater than zero") ;
        camera.screenSpaceAmbientOcclusionRadius = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_screenSpaceAmbientOcclusionBias(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.screenSpaceAmbientOcclusionBias) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        camera.screenSpaceAmbientOcclusionBias = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_screenSpaceAmbientOcclusionDepthThreshold(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.screenSpaceAmbientOcclusionDepthThreshold) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.screenSpaceAmbientOcclusionDepthThreshold = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_screenSpaceAmbientOcclusionNormalThreshold(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.screenSpaceAmbientOcclusionNormalThreshold) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.screenSpaceAmbientOcclusionNormalThreshold = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_sensorHeight(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.sensorHeight) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value <= 0.0) return luaL_argerror(L, 2, "must be greater than zero") ;
        camera.sensorHeight = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_vignettingIntensity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.vignettingIntensity) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.vignettingIntensity = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_vignettingPower(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.vignettingPower) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.vignettingPower = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_whiteBalanceTemperature(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.whiteBalanceTemperature) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.whiteBalanceTemperature = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_whiteBalanceTint(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.whiteBalanceTint) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.whiteBalanceTint = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_whitePoint(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.whitePoint) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        camera.whitePoint = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_orthographicScale(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.orthographicScale) ;
    } else {
        double value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.orthographicScale = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_zNear(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.zNear) ;
    } else {
        double value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.zNear = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_zFar(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, camera.zFar) ;
    } else {
        double value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        camera.zFar = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_apertureBladeCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, camera.apertureBladeCount) ;
    } else {
        NSInteger value = lua_tointeger(L, 2) ;
        if (value < 1) return luaL_argerror(L, 2, "must be greater than zero") ;
        camera.apertureBladeCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_bloomIterationCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, camera.bloomIterationCount) ;
    } else {
        NSInteger value = lua_tointeger(L, 2) ;
        camera.bloomIterationCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_focalBlurSampleCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, camera.focalBlurSampleCount) ;
    } else {
        NSInteger value = lua_tointeger(L, 2) ;
        if (value < 1) return luaL_argerror(L, 2, "must be greater than zero") ;
        camera.focalBlurSampleCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_categoryBitMask(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, (lua_Integer)camera.categoryBitMask) ;
    } else {
        NSUInteger value = (NSUInteger)(lua_tointeger(L, 2)) ;
        camera.categoryBitMask = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_projectionDirection(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [PROJECTION_DIRECTION allKeysForObject:@(camera.projectionDirection)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", camera.projectionDirection] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = PROJECTION_DIRECTION[key] ;
        if (value) {
            camera.projectionDirection = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [PROJECTION_DIRECTION.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_projectionTransform(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        pushSCNMatrix4(L, camera.projectionTransform) ;
    } else {
        SCNMatrix4 matrix = pullSCNMatrix4(L, 2) ;
        camera.projectionTransform = matrix ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int camera_projectionTransformWithViewportSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    SCNCamera *camera = [skin toNSObjectAtIndex:1] ;

    NSSize viewport = [skin tableToSizeAtIndex:2] ;
    pushSCNMatrix4(L, [camera projectionTransformWithViewportSize:NSSizeToCGSize(viewport)]) ;
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNCamera(lua_State *L, id obj) {
    SCNCamera *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNCamera *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNCamera(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNCamera *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNCamera, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNCamera *obj = [skin luaObjectAtIndex:1 toClass:"SCNCamera"] ;
    NSString *title = obj.name ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        SCNCamera *obj1 = [skin luaObjectAtIndex:1 toClass:"SCNCamera"] ;
        SCNCamera *obj2 = [skin luaObjectAtIndex:2 toClass:"SCNCamera"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    SCNCamera *obj = get_objectFromUserdata(__bridge_transfer SCNCamera, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
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
    {"gobo",                           camera_gobo},
    {"projectionTransformForViewport", camera_projectionTransformWithViewportSize},

    {"apertureBladeCount",             camera_apertureBladeCount},
    {"autoAdjustsZRange",              camera_automaticallyAdjustsZRange},
    {"averageGray",                    camera_averageGray},
    {"bloomBlurRadius",                camera_bloomBlurRadius},
    {"bloomIntensity",                 camera_bloomIntensity},
    {"bloomIterationCount",            camera_bloomIterationCount},
    {"bloomIterationSpread",           camera_bloomIterationSpread},
    {"bloomThreshold",                 camera_bloomThreshold},
    {"categoryBitMask",                camera_categoryBitMask},
    {"colorFringeIntensity",           camera_colorFringeIntensity},
    {"colorFringeStrength",            camera_colorFringeStrength},
    {"contrast",                       camera_contrast},
    {"exposureAdaptBrighteningSpeed",  camera_exposureAdaptationBrighteningSpeedFactor},
    {"exposureAdaptDarkeningSpeed",    camera_exposureAdaptationDarkeningSpeedFactor},
    {"exposureOffset",                 camera_exposureOffset},
    {"fieldOfView",                    camera_fieldOfView},
    {"focalBlurSampleCount",           camera_focalBlurSampleCount},
    {"focalLength",                    camera_focalLength},
    {"focusDistance",                  camera_focusDistance},
    {"fStop",                          camera_fStop},
    {"grainIntensity",                 camera_grainIntensity},
    {"grainIsColored",                 camera_grainIsColored},
    {"grainScale",                     camera_grainScale},
    {"maximumExposure",                camera_maximumExposure},
    {"minimumExposure",                camera_minimumExposure},
    {"motionBlurIntensity",            camera_motionBlurIntensity},
    {"name",                           camera_name},
    {"orthographicScale",              camera_orthographicScale},
    {"projectionDirection",            camera_projectionDirection},
    {"projectionTransform",            camera_projectionTransform},
    {"saturation",                     camera_saturation},
    {"ssaoBias",                       camera_screenSpaceAmbientOcclusionBias},
    {"ssaoDepthThreshold",             camera_screenSpaceAmbientOcclusionDepthThreshold},
    {"ssaoIntensity",                  camera_screenSpaceAmbientOcclusionIntensity},
    {"ssaoNormalThreshold",            camera_screenSpaceAmbientOcclusionNormalThreshold},
    {"ssaoRadius",                     camera_screenSpaceAmbientOcclusionRadius},
    {"sensorHeight",                   camera_sensorHeight},
    {"usesOrthographicProjection",     camera_usesOrthographicProjection},
    {"vignettingIntensity",            camera_vignettingIntensity},
    {"vignettingPower",                camera_vignettingPower},
    {"wantsDepthOfField",              camera_wantsDepthOfField},
    {"wantsExposureAdaptation",        camera_wantsExposureAdaptation},
    {"wantsHDR",                       camera_wantsHDR},
    {"whiteBalanceTemperature",        camera_whiteBalanceTemperature},
    {"whiteBalanceTint",               camera_whiteBalanceTint},
    {"whitePoint",                     camera_whitePoint},
    {"zFar",                           camera_zFar},
    {"zNear",                          camera_zNear},

    {"__tostring",                     userdata_tostring},
    {"__eq",                           userdata_eq},
    {"__gc",                           userdata_gc},
    {NULL,                             NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",        camera_new},
    {NULL,         NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libsceneKit_camera(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushSCNCamera  forClass:"SCNCamera"];
    [skin registerLuaObjectHelper:toSCNCamera forClass:"SCNCamera"
                                   withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"apertureBladeCount",
        @"autoAdjustsZRange",
        @"averageGray",
        @"bloomBlurRadius",
        @"bloomIntensity",
        @"bloomIterationCount",
        @"bloomIterationSpread",
        @"bloomThreshold",
        @"categoryBitMask",
        @"colorFringeIntensity",
        @"colorFringeStrength",
        @"contrast",
        @"exposureAdaptBrighteningSpeed",
        @"exposureAdaptDarkeningSpeed",
        @"exposureOffset",
        @"fieldOfView",
        @"focalBlurSampleCount",
        @"focalLength",
        @"focusDistance",
        @"fStop",
        @"grainIntensity",
        @"grainIsColored",
        @"grainScale",
        @"maximumExposure",
        @"minimumExposure",
        @"motionBlurIntensity",
        @"name",
        @"orthographicScale",
        @"projectionDirection",
        @"projectionTransform",
        @"saturation",
        @"ssaoBias",
        @"ssaoDepthThreshold",
        @"ssaoIntensity",
        @"ssaoNormalThreshold",
        @"ssaoRadius",
        @"sensorHeight",
        @"usesOrthographicProjection",
        @"vignettingIntensity",
        @"vignettingPower",
        @"wantsDepthOfField",
        @"wantsExposureAdaptation",
        @"wantsHDR",
        @"whiteBalanceTemperature",
        @"whiteBalanceTint",
        @"whitePoint",
        @"zFar",
        @"zNear",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    [skin pushNSObject:@[
        @"colorGrading",
    ]] ;
    lua_setfield(L, -2, "_materialProperties") ;
    lua_pop(L, 1) ;

    return 1;
}
