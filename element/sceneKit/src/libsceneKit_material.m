@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.material" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

static NSDictionary *FOCUSBEHAVIOR ;
static NSDictionary *MOVABILITYHINT ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_anyObjectFromUserdata(objType, L, idx) (objType*)*((void**)lua_touserdata(L, idx))

static NSDictionary *LIGHTING_MODE ;
static NSDictionary *BLEND_MODE ;
static NSDictionary *COLOR_MASK ;
static NSDictionary *CULL_MODE ;
static NSDictionary *FILL_MODE ;
static NSDictionary *TRANSPARENCY_MODE ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    LIGHTING_MODE = @{
        @"blinn"           : SCNLightingModelBlinn,
        @"constant"        : SCNLightingModelConstant,
        @"lambert"         : SCNLightingModelLambert,
        @"phong"           : SCNLightingModelPhong,
        @"physicallyBased" : SCNLightingModelPhysicallyBased,
        @"shadowOnly"      : SCNLightingModelShadowOnly,
    } ;

    BLEND_MODE = @{
        @"add"      : @(SCNBlendModeAdd),
        @"alpha"    : @(SCNBlendModeAlpha),
        @"max"      : @(SCNBlendModeMax),
        @"multiply" : @(SCNBlendModeMultiply),
        @"replace"  : @(SCNBlendModeReplace),
        @"screen"   : @(SCNBlendModeScreen),
        @"subtract" : @(SCNBlendModeSubtract),
    } ;

    CULL_MODE = @{
        @"front" : @(SCNCullFront),
        @"back"  : @(SCNCullModeBack),
    } ;

    FILL_MODE = @{
        @"fill"  : @(SCNFillModeFill),
        @"lines" : @(SCNFillModeLines),
    } ;

    TRANSPARENCY_MODE = @{
        @"aOne"        : @(SCNTransparencyModeAOne),
        @"default"     : @(SCNTransparencyModeDefault),
        @"dualLayer"   : @(SCNTransparencyModeDualLayer),
        @"rgbZero"     : @(SCNTransparencyModeRGBZero),
        @"singleLayer" : @(SCNTransparencyModeSingleLayer),
    } ;
}

@interface SCNMaterial (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation SCNMaterial (HammerspoonAdditions)

+ (instancetype)materialWithName:(NSString *)name {
    SCNMaterial *material = [SCNMaterial material] ;

    if (material) {
        material.callbackRef  = LUA_NOREF ;
        material.selfRefCount = 0 ;
        material.name         = name ;
    }
    return material ;
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

static int material_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *name = (lua_gettop(L)) == 1 ? [skin toNSObjectAtIndex:1] : [[NSUUID UUID] UUIDString] ;

    SCNMaterial *material = [SCNMaterial materialWithName:name] ;
    if (material) {
        [skin pushNSObject:material] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int material_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:material.name] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            material.name = nil ;
        } else {
            NSString *newName = [skin toNSObjectAtIndex:2] ;
            material.name = newName ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int material_doubleSided(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, material.doubleSided) ;
    } else {
        material.doubleSided = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int material_litPerPixel(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, material.litPerPixel) ;
    } else {
        material.litPerPixel = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int material_locksAmbientWithDiffuse(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, material.locksAmbientWithDiffuse) ;
    } else {
        material.locksAmbientWithDiffuse = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int material_readsFromDepthBuffer(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, material.readsFromDepthBuffer) ;
    } else {
        material.readsFromDepthBuffer = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int material_writesToDepthBuffer(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, material.writesToDepthBuffer) ;
    } else {
        material.writesToDepthBuffer = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int material_fresnelExponent(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, material.fresnelExponent) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        material.fresnelExponent = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// FIXME: need to see if this needs to be constrained (e.g. not negative)
static int material_shininess(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, material.shininess) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        material.shininess = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// FIXME: need to see if this needs to be constrained (e.g. not negative)
static int material_transparency(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, material.transparency) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        material.transparency = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int material_lightingModelName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [LIGHTING_MODE allKeysForObject:material.lightingModelName] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %@", material.lightingModelName] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSString *value = LIGHTING_MODE[key] ;
        if (value) {
            material.lightingModelName = value ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [LIGHTING_MODE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int material_cullMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [CULL_MODE allKeysForObject:@(material.cullMode)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", material.cullMode] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = CULL_MODE[key] ;
        if (value) {
            material.cullMode = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [CULL_MODE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int material_fillMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [FILL_MODE allKeysForObject:@(material.fillMode)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", material.fillMode] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = FILL_MODE[key] ;
        if (value) {
            material.fillMode = value.unsignedLongLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [FILL_MODE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int material_transparencyMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [TRANSPARENCY_MODE allKeysForObject:@(material.transparencyMode)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", material.transparencyMode] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = TRANSPARENCY_MODE[key] ;
        if (value) {
            material.transparencyMode = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [TRANSPARENCY_MODE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int material_blendMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [BLEND_MODE allKeysForObject:@(material.blendMode)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", material.blendMode] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = BLEND_MODE[key] ;
        if (value) {
            material.blendMode = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [BLEND_MODE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// description in SCNMaterial.h unclear... let's wait and see if this is useful/needed
// @property(nonatomic) SCNColorMask colorBufferWriteMask;

static int material_ambient(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:material.ambient] ;
    return 1 ;
}

static int material_ambientOcclusion(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:material.ambientOcclusion] ;
    return 1 ;
}

static int material_clearCoat(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:material.clearCoat] ;
    return 1 ;
}

static int material_clearCoatNormal(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:material.clearCoatNormal] ;
    return 1 ;
}

static int material_clearCoatRoughness(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:material.clearCoatRoughness] ;
    return 1 ;
}

static int material_diffuse(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:material.diffuse] ;
    return 1 ;
}

static int material_displacement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:material.displacement] ;
    return 1 ;
}

static int material_emission(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:material.emission] ;
    return 1 ;
}

static int material_metalness(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:material.metalness] ;
    return 1 ;
}

static int material_multiply(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:material.multiply] ;
    return 1 ;
}

static int material_normal(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:material.normal] ;
    return 1 ;
}

static int material_reflective(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:material.reflective] ;
    return 1 ;
}

static int material_roughness(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:material.roughness] ;
    return 1 ;
}

static int material_selfIllumination(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:material.selfIllumination] ;
    return 1 ;
}

static int material_specular(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:material.specular] ;
    return 1 ;
}

static int material_transparent(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNMaterial *material = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:material.transparent] ;
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNMaterial(lua_State *L, id obj) {
    SCNMaterial *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNMaterial *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNMaterial(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNMaterial *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNMaterial, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNMaterial *obj = [skin luaObjectAtIndex:1 toClass:"SCNMaterial"] ;
    NSString *title = obj.name ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        SCNMaterial *obj1 = [skin luaObjectAtIndex:1 toClass:"SCNMaterial"] ;
        SCNMaterial *obj2 = [skin luaObjectAtIndex:2 toClass:"SCNMaterial"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    SCNMaterial *obj = get_objectFromUserdata(__bridge_transfer SCNMaterial, L, 1, USERDATA_TAG) ;
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
    {"name", material_name},
    {"doubleSided", material_doubleSided},
    {"litPerPixel", material_litPerPixel},
    {"locksAmbientWithDiffuse", material_locksAmbientWithDiffuse},
    {"readsFromDepthBuffer", material_readsFromDepthBuffer},
    {"writesToDepthBuffer", material_writesToDepthBuffer},
    {"fresnelExponent", material_fresnelExponent},
    {"shininess", material_shininess},
    {"transparency", material_transparency},
    {"lightingModelName", material_lightingModelName},
    {"cullMode", material_cullMode},
    {"fillMode", material_fillMode},
    {"transparencyMode", material_transparencyMode},
    {"blendMode", material_blendMode},

    {"ambient", material_ambient},
    {"ambientOcclusion", material_ambientOcclusion},
    {"clearCoat", material_clearCoat},
    {"clearCoatNormal", material_clearCoatNormal},
    {"clearCoatRoughness", material_clearCoatRoughness},
    {"diffuse", material_diffuse},
    {"displacement", material_displacement},
    {"emission", material_emission},
    {"metalness", material_metalness},
    {"multiply", material_multiply},
    {"normal", material_normal},
    {"reflective", material_reflective},
    {"roughness", material_roughness},
    {"selfIllumination", material_selfIllumination},
    {"specular", material_specular},
    {"transparent", material_transparent},

    {"__tostring",       userdata_tostring},
    {"__eq",             userdata_eq},
    {"__gc",             userdata_gc},
    {NULL,               NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", material_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libsceneKit_material(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushSCNMaterial  forClass:"SCNMaterial"];
    [skin registerLuaObjectHelper:toSCNMaterial forClass:"SCNMaterial"
                                     withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"name",
        @"doubleSided",
        @"litPerPixel",
        @"locksAmbientWithDiffuse",
        @"readsFromDepthBuffer",
        @"writesToDepthBuffer",
        @"fresnelExponent",
        @"shininess",
        @"transparency",
        @"lightingModelName",
        @"cullMode",
        @"fillMode",
        @"transparencyMode",
        @"blendMode",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    [skin pushNSObject:@[
        @"diffuse",
        @"ambient",
        @"specular",
        @"emission",
        @"transparent",
        @"reflective",
        @"multiply",
        @"normal",
        @"displacement",
        @"ambientOcclusion",
        @"selfIllumination",
        @"metalness",
        @"roughness",
        @"clearCoat",
        @"clearCoatRoughness",
        @"clearCoatNormal",
    ]] ;
    lua_setfield(L, -2, "_materialProperties") ;
    lua_pop(L, 1) ;

    return 1;
}
