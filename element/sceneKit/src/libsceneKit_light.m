@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;
#import "SKconversions.h"

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.light" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_anyObjectFromUserdata(objType, L, idx) (objType*)*((void**)lua_touserdata(L, idx))

static NSDictionary *LIGHT_TYPE ;
static NSDictionary *LIGHT_AREA_TYPE ;
static NSDictionary *LIGHT_PROBE_TYPE ;
static NSDictionary *LIGHT_PROBE_UPDATE ;
static NSDictionary *SHADOW_MODE ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    LIGHT_TYPE = @{
        @"ambient"     : SCNLightTypeAmbient,
        @"area"        : SCNLightTypeArea,
        @"directional" : SCNLightTypeDirectional,
        @"IES"         : SCNLightTypeIES,
        @"omni"        : SCNLightTypeOmni,
        @"probe"       : SCNLightTypeProbe,
        @"spot"        : SCNLightTypeSpot,
    } ;

    LIGHT_AREA_TYPE = @{
        @"polygon"   : @(SCNLightAreaTypePolygon),
        @"rectangle" : @(SCNLightAreaTypeRectangle),
    } ;

    LIGHT_PROBE_TYPE = @{
        @"irradiance" : @(SCNLightProbeTypeIrradiance),
        @"radiance"   : @(SCNLightProbeTypeRadiance),
    } ;

    LIGHT_PROBE_UPDATE = @{
        @"never"    : @(SCNLightProbeUpdateTypeNever),
        @"realtime" : @(SCNLightProbeUpdateTypeRealtime),
    } ;

    SHADOW_MODE = @{
        @"forward"   : @(SCNShadowModeForward),
        @"deferred"  : @(SCNShadowModeDeferred),
        @"modulated" : @(SCNShadowModeModulated),
    } ;
}

@interface SCNLight (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation SCNLight (HammerspoonAdditions)

+ (instancetype)lightWithName:(NSString *)name {
    SCNLight *light = [SCNLight light] ;

    if (light) {
        light.callbackRef  = LUA_NOREF ;
        light.selfRefCount = 0 ;
        light.name         = name ;
    }
    return light ;
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

static int light_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *name = (lua_gettop(L)) == 1 ? [skin toNSObjectAtIndex:1] : [[NSUUID UUID] UUIDString] ;

    SCNLight *light = [SCNLight lightWithName:name] ;
    if (light) {
        [skin pushNSObject:light] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int light_sphericalHarmonicsCoefficients(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:light.sphericalHarmonicsCoefficients] ;
    return 1 ;
}

static int light_gobo(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:light.gobo] ;
    return 1 ;
}

static int light_probeEnvironment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:light.probeEnvironment] ;
    return 1 ;
}

static int light_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:light.name] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            light.name = nil ;
        } else {
            NSString *newName = [skin toNSObjectAtIndex:2] ;
            light.name = newName ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_color(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:light.color] ;
    } else {
        light.color = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_shadowColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:light.shadowColor] ;
    } else {
        light.shadowColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_automaticallyAdjustsShadowProjection(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, light.automaticallyAdjustsShadowProjection) ;
    } else {
        light.automaticallyAdjustsShadowProjection = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_castsShadow(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, light.castsShadow) ;
    } else {
        light.castsShadow = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_doubleSided(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, light.doubleSided) ;
    } else {
        light.doubleSided = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_drawsArea(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, light.drawsArea) ;
    } else {
        light.drawsArea = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_forcesBackFaceCasters(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, light.forcesBackFaceCasters) ;
    } else {
        light.forcesBackFaceCasters = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_parallaxCorrectionEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, light.parallaxCorrectionEnabled) ;
    } else {
        light.parallaxCorrectionEnabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_sampleDistributedShadowMaps(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, light.sampleDistributedShadowMaps) ;
    } else {
        light.sampleDistributedShadowMaps = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_attenuationEndDistance(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, light.attenuationEndDistance) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        light.attenuationEndDistance = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_attenuationFalloffExponent(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, light.attenuationFalloffExponent) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        light.attenuationFalloffExponent = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_attenuationStartDistance(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, light.attenuationStartDistance) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        light.attenuationStartDistance = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_intensity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, light.intensity) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        light.intensity = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_maximumShadowDistance(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, light.maximumShadowDistance) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        light.maximumShadowDistance = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_orthographicScale(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, light.orthographicScale) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        light.orthographicScale = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// FIXME: should this be constrained?
static int light_shadowBias(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, light.shadowBias) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        light.shadowBias = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_shadowCascadeSplittingFactor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, light.shadowCascadeSplittingFactor) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0 || value > 1.0) return luaL_argerror(L, 2, "must be between 0.0 and 1.0 inclusive") ;

        light.shadowCascadeSplittingFactor = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_shadowRadius(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, light.shadowRadius) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value <= 0.0) return luaL_argerror(L, 2, "must be greater than zero") ;
        light.shadowRadius = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_spotInnerAngle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, light.spotInnerAngle) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        light.spotInnerAngle = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_spotOuterAngle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, light.spotOuterAngle) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        light.spotOuterAngle = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_temperature(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, light.temperature) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        light.temperature = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_zFar(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, light.zFar) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value <= 0.0) return luaL_argerror(L, 2, "must be greater than zero") ;
        light.zFar = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_zNear(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, light.zNear) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value <= 0.0) return luaL_argerror(L, 2, "must be greater than zero") ;
        light.zNear = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_shadowMapSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:NSSizeFromCGSize(light.shadowMapSize)] ;
    } else {
        NSDictionary *size = [skin toNSObjectAtIndex:2] ;
        if ([size isKindOfClass:[NSDictionary class]]) {
            light.shadowMapSize = NSSizeToCGSize([skin tableToSizeAtIndex:2]) ;
        } else {
            return luaL_argerror(L, 2, "expected size table") ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_categoryBitMask(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, (lua_Integer)light.categoryBitMask) ;
    } else {
        NSUInteger value = (NSUInteger)lua_tointeger(L, 2) ;
        light.categoryBitMask = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_shadowSampleCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, (lua_Integer)light.shadowSampleCount) ;
    } else {
        NSUInteger value = (NSUInteger)lua_tointeger(L, 2) ;
        light.shadowSampleCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_shadowCascadeCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, (lua_Integer)light.shadowCascadeCount) ;
    } else {
        NSUInteger value = (NSUInteger)lua_tointeger(L, 2) ;
        if (value > 4) value = 4 ;
        light.shadowCascadeCount = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_areaType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [LIGHT_AREA_TYPE allKeysForObject:@(light.areaType)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", light.areaType] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = LIGHT_AREA_TYPE[key] ;
        if (value) {
            light.areaType = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [LIGHT_AREA_TYPE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_probeType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [LIGHT_PROBE_TYPE allKeysForObject:@(light.probeType)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", light.probeType] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = LIGHT_PROBE_TYPE[key] ;
        if (value) {
            light.probeType = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [LIGHT_PROBE_TYPE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_probeUpdateType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [LIGHT_PROBE_UPDATE allKeysForObject:@(light.probeUpdateType)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", light.probeUpdateType] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = LIGHT_PROBE_UPDATE[key] ;
        if (value) {
            light.probeUpdateType = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [LIGHT_PROBE_UPDATE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_shadowMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [SHADOW_MODE allKeysForObject:@(light.shadowMode)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", light.shadowMode] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = SHADOW_MODE[key] ;
        if (value) {
            light.shadowMode = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [SHADOW_MODE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_type(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [LIGHT_TYPE allKeysForObject:light.type] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %@", light.type] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSString *value = LIGHT_TYPE[key] ;
        if (value) {
            light.type = value ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [LIGHT_TYPE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_areaExtents(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        push_simd_float3(L, light.areaExtents) ;
    } else {
        light.areaExtents = pull_simd_float3(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_parallaxCenterOffset(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        push_simd_float3(L, light.parallaxCenterOffset) ;
    } else {
        light.parallaxCenterOffset = pull_simd_float3(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_parallaxExtentsFactor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        push_simd_float3(L, light.parallaxExtentsFactor) ;
    } else {
        light.parallaxExtentsFactor = pull_simd_float3(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_probeExtents(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        push_simd_float3(L, light.probeExtents) ;
    } else {
        light.probeExtents = pull_simd_float3(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_probeOffset(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        push_simd_float3(L, light.probeOffset) ;
    } else {
        light.probeOffset = pull_simd_float3(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int light_areaPolygonVertices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLight *light = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:light.areaPolygonVertices] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            light.areaPolygonVertices = nil ;
        } else {
            NSArray    *vertices         = [skin toNSObjectAtIndex:2] ;
            NSMutableArray *goodVertices = [NSMutableArray array] ;
            BOOL       isGood            = [vertices isKindOfClass:[NSArray class]] ;
            NSUInteger idx               = 0 ;

            while (isGood && idx < vertices.count) {
                NSDictionary *item = vertices[idx++] ;
                isGood = [item isKindOfClass:[NSDictionary class]] && item[@"x"] && item[@"y"] &&
                                [(NSNumber *)item[@"x"] isKindOfClass:[NSNumber class]] &&
                                [(NSNumber *)item[@"y"] isKindOfClass:[NSNumber class]] ;
                if (isGood) {
                    [goodVertices addObject:[NSValue valueWithPoint:CGPointMake(
                                                    [(NSNumber *)item[@"x"] doubleValue],
                                                    [(NSNumber *)item[@"y"] doubleValue])]] ;
                }
            }

            if (isGood) {
                light.areaPolygonVertices = goodVertices.copy ;
            } else {
                return luaL_argerror(L, 2, "expected array of point tables") ;
            }
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// @property(nonatomic, retain, nullable) NSURL *IESProfileURL;

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNLight(lua_State *L, id obj) {
    SCNLight *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNLight *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNLight(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNLight *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNLight, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNLight *obj = [skin luaObjectAtIndex:1 toClass:"SCNLight"] ;
    NSString *title = obj.name ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        SCNLight *obj1 = [skin luaObjectAtIndex:1 toClass:"SCNLight"] ;
        SCNLight *obj2 = [skin luaObjectAtIndex:2 toClass:"SCNLight"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    SCNLight *obj = get_objectFromUserdata(__bridge_transfer SCNLight, L, 1, USERDATA_TAG) ;
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
    {"sphericalHarmonics",           light_sphericalHarmonicsCoefficients},
    {"gobo",                         light_gobo},
    {"probeEnvironment",             light_probeEnvironment},

    {"name",                         light_name},
    {"color",                        light_color},
    {"shadowColor",                  light_shadowColor},
    {"autoAdjustsShadowProjection",  light_automaticallyAdjustsShadowProjection},
    {"castsShadow",                  light_castsShadow},
    {"doubleSided",                  light_doubleSided},
    {"drawsArea",                    light_drawsArea},
    {"forcesBackFaceCasters",        light_forcesBackFaceCasters},
    {"parallaxCorrection",           light_parallaxCorrectionEnabled},
    {"sampleDistributedShadowMaps",  light_sampleDistributedShadowMaps},
    {"attenuationEndDistance",       light_attenuationEndDistance},
    {"attenuationFalloffExponent",   light_attenuationFalloffExponent},
    {"attenuationStartDistance",     light_attenuationStartDistance},
    {"intensity",                    light_intensity},
    {"maximumShadowDistance",        light_maximumShadowDistance},
    {"orthographicScale",            light_orthographicScale},
    {"shadowBias",                   light_shadowBias},
    {"shadowCascadeSplittingFactor", light_shadowCascadeSplittingFactor},
    {"shadowRadius",                 light_shadowRadius},
    {"spotInnerAngle",               light_spotInnerAngle},
    {"spotOuterAngle",               light_spotOuterAngle},
    {"temperature",                  light_temperature},
    {"zFar",                         light_zFar},
    {"zNear",                        light_zNear},
    {"shadowMapSize",                light_shadowMapSize},
    {"categoryBitMask",              light_categoryBitMask},
    {"shadowSampleCount",            light_shadowSampleCount},
    {"shadowCascadeCount",           light_shadowCascadeCount},
    {"areaType",                     light_areaType},
    {"probeType",                    light_probeType},
    {"probeUpdateType",              light_probeUpdateType},
    {"shadowMode",                   light_shadowMode},
    {"type",                         light_type},
    {"areaExtents",                  light_areaExtents},
    {"parallaxCenterOffset",         light_parallaxCenterOffset},
    {"parallaxExtentsFactor",        light_parallaxExtentsFactor},
    {"probeExtents",                 light_probeExtents},
    {"probeOffset",                  light_probeOffset},
    {"areaPolygonVertices",          light_areaPolygonVertices},

    {"__tostring",                   userdata_tostring},
    {"__eq",                         userdata_eq},
    {"__gc",                         userdata_gc},
    {NULL,                           NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",        light_new},
    {NULL,         NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libsceneKit_light(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushSCNLight  forClass:"SCNLight"];
    [skin registerLuaObjectHelper:toSCNLight forClass:"SCNLight"
                                  withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"name",
        @"color",
        @"shadowColor",
        @"autoAdjustsShadowProjection",
        @"castsShadow",
        @"doubleSided",
        @"drawsArea",
        @"forcesBackFaceCasters",
        @"parallaxCorrection",
        @"sampleDistributedShadowMaps",
        @"attenuationEndDistance",
        @"attenuationFalloffExponent",
        @"attenuationStartDistance",
        @"intensity",
        @"maximumShadowDistance",
        @"orthographicScale",
        @"shadowBias",
        @"shadowCascadeSplittingFactor",
        @"shadowRadius",
        @"spotInnerAngle",
        @"spotOuterAngle",
        @"temperature",
        @"zFar",
        @"zNear",
        @"shadowMapSize",
        @"categoryBitMask",
        @"shadowSampleCount",
        @"shadowCascadeCount",
        @"areaType",
        @"probeType",
        @"probeUpdateType",
        @"shadowMode",
        @"type",
        @"areaExtents",
        @"parallaxCenterOffset",
        @"parallaxExtentsFactor",
        @"probeExtents",
        @"probeOffset",
        @"areaPolygonVertices",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    [skin pushNSObject:@[
        @"probeEnvironment",
        @"gobo",
    ]] ;
    lua_setfield(L, -2, "_materialProperties") ;
    lua_pop(L, 1) ;

    return 1;
}
