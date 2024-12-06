@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;
@import AVKit ;
#import "SKconversions.h"

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.material.property" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_anyObjectFromUserdata(objType, L, idx) (objType*)*((void**)lua_touserdata(L, idx))

static NSDictionary *COLOR_MASK ;
static NSDictionary *FILTER_MODE ;
static NSDictionary *WRAP_MODE ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    COLOR_MASK = @{
        @"all"   : @(SCNColorMaskAll),
        @"alpha" : @(SCNColorMaskAlpha),
        @"blue"  : @(SCNColorMaskBlue),
        @"green" : @(SCNColorMaskGreen),
        @"none"  : @(SCNColorMaskNone),
        @"red"   : @(SCNColorMaskRed),
    } ;

    FILTER_MODE = @{
        @"linear"  : @(SCNFilterModeLinear),
        @"nearest" : @(SCNFilterModeNearest),
        @"none"    : @(SCNFilterModeNone),
    } ;

    WRAP_MODE = @{
        @"clamp"         : @(SCNWrapModeClamp),
        @"repeat"        : @(SCNWrapModeRepeat),
        @"clampToBorder" : @(SCNWrapModeClampToBorder),
        @"mirror"        : @(SCNWrapModeMirror),
    } ;
}

@interface SCNMaterialProperty (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation SCNMaterialProperty (HammerspoonAdditions)

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

#pragma mark - Module Methods -

static int property_contents(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterialProperty *property = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:property.contents] ;
    } else {
//         NSObject *previousContents = property.contents ;

        if (lua_type(L, 2) == LUA_TNIL) {
            property.contents = nil ;
        } else if (lua_type(L, 2) == LUA_TNUMBER) {
            CGFloat value = lua_tonumber(L, 2) ;
            if (value < 0.0 || value > 1.0) {
                return luaL_argerror(L, 2, "number must be between 0.0 and 1.0 inclusive") ;
            }
            property.contents = @(value) ;
        } else if (lua_type(L, 2) == LUA_TSTRING) {
            NSString *path = [skin toNSObjectAtIndex:2] ;
            property.contents = [path stringByStandardizingPath] ;
        } else if (lua_type(L, 2) == LUA_TUSERDATA) {
            lua_getmetatable(L, 2) ;
            lua_getfield(L, 2, "__name") ;
            NSString *type = [NSString stringWithUTF8String:lua_tostring(L, -1)] ;
            lua_pop(L, 2) ;
// FIXME: Nope, not the view, but the player object. Need to decide if breaking avplayer element into two parts is worth it
//             if ([type isEqualToString:@"hs.image"] || [type isEqualToString:@"hs._asm.uitk.element.avplayer"]) {
//                 NSObject *contents = [skin toNSObjectAtIndex:2] ;
//                 if ([contents isKindOfClass:[AVPlayerView class]]) {
//                     [skin luaRetain:refTable forNSObject:contents] ;
//                 }
//                 property.contents = contents ;
//             } else {
//                 return luaL_argerror(L, 2, "userdata must be image or avplayer") ;
//             }
            if ([type isEqualToString:@"hs.image"]) {
                property.contents = [skin toNSObjectAtIndex:2] ;
            } else {
                return luaL_argerror(L, 2, "userdata must be image") ;
            }
        } else if (lua_type(L, 2) == LUA_TTABLE) {
            NSArray *value = [skin toNSObjectAtIndex:2] ;
            if ([value isKindOfClass:[NSArray class]]) {
                BOOL       isGood = (value.count == 6) ;
                NSUInteger idx    = 0 ;

                while (isGood && idx < value.count) {
                    NSImage *image = value[idx++] ;
                    isGood = [image isKindOfClass:[NSImage class]] ;
                }
                if (!isGood) return luaL_argerror(L, 2, "expected array of 6 images") ;
                property.contents = value ;
            } else {
                property.contents = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
            }
        } else {
            return luaL_argerror(L, 2, "invalid content type") ;
        }
//         if (previousContents && [previousContents isKindOfClass:[AVPlayerView class]]) {
//             [skin luaRelease:refTable forNSObject:previousContents] ;
//         }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int property_intensity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterialProperty *property = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, property.intensity) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0 || value > 1.0) {
            return luaL_argerror(L, 2, "must be between 0.0 and 1.0 inclusive") ;
        }
        property.intensity = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int property_maxAnisotropy(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterialProperty *property = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, property.maxAnisotropy) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 1.0) {
            return luaL_argerror(L, 2, "must be equal to or greater than 1.0") ;
        }
        property.maxAnisotropy = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int property_textureComponents(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterialProperty *property = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, property.textureComponents) ;
    } else {
        property.textureComponents = lua_tointeger(L, 2) & SCNColorMaskAll ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// TODO ? chooses SCNGeometrySource with texture semantics from SCNGeometry... not implemented yet, so...
// @property(nonatomic) NSInteger mappingChannel;

static int property_magnificationFilter(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterialProperty *property = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [FILTER_MODE allKeysForObject:@(property.magnificationFilter)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", property.magnificationFilter] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = FILTER_MODE[key] ;
        if (value) {
            property.magnificationFilter = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [FILTER_MODE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int property_minificationFilter(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterialProperty *property = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [FILTER_MODE allKeysForObject:@(property.minificationFilter)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", property.minificationFilter] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = FILTER_MODE[key] ;
        if (value) {
            property.minificationFilter = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [FILTER_MODE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int property_mipFilter(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterialProperty *property = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [FILTER_MODE allKeysForObject:@(property.mipFilter)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", property.mipFilter] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = FILTER_MODE[key] ;
        if (value) {
            property.mipFilter = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [FILTER_MODE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int property_contentsTransform(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterialProperty *property = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        pushSCNMatrix4(L, property.contentsTransform) ;
    } else {
        SCNMatrix4 matrix = pullSCNMatrix4(L, 2) ;
        property.contentsTransform = matrix ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int property_wrapS(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterialProperty *property = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [WRAP_MODE allKeysForObject:@(property.wrapS)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", property.wrapS] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = WRAP_MODE[key] ;
        if (value) {
            property.wrapS = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [WRAP_MODE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int property_wrapT(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNMaterialProperty *property = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [WRAP_MODE allKeysForObject:@(property.wrapT)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", property.wrapT] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = WRAP_MODE[key] ;
        if (value) {
            property.wrapT = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [WRAP_MODE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

static int property_colorMask(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:COLOR_MASK] ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNMaterialProperty(lua_State *L, id obj) {
    SCNMaterialProperty *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNMaterialProperty *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNMaterialProperty(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNMaterialProperty *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNMaterialProperty, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     SCNMaterialProperty *obj = [skin luaObjectAtIndex:1 toClass:"SCNMaterialProperty"] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        SCNMaterialProperty *obj1 = [skin luaObjectAtIndex:1 toClass:"SCNMaterialProperty"] ;
        SCNMaterialProperty *obj2 = [skin luaObjectAtIndex:2 toClass:"SCNMaterialProperty"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    SCNMaterialProperty *obj = get_objectFromUserdata(__bridge_transfer SCNMaterialProperty, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            if (obj.contents) {
//                 NSObject *contents = obj.contents ;
//                 if ([contents isKindOfClass:[AVPlayerView class]]) {
//                     [skin luaRelease:refTable forNSObject:contents] ;
//                 }
            }
            obj.contents = nil ;
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
    {"contents",            property_contents},
    {"intensity",           property_intensity},
    {"maxAnisotropy",       property_maxAnisotropy},
    {"textureComponents",   property_textureComponents},
    {"magnificationFilter", property_magnificationFilter},
    {"minificationFilter",  property_minificationFilter},
    {"mipFilter",           property_mipFilter},
    {"contentsTransform",   property_contentsTransform},
    {"wrapS",               property_wrapS},
    {"wrapT",               property_wrapT},

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
int luaopen_hs__asm_uitk_element_libsceneKit_material_property(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushSCNMaterialProperty  forClass:"SCNMaterialProperty"];
    [skin registerLuaObjectHelper:toSCNMaterialProperty forClass:"SCNMaterialProperty"
                                             withUserdataMapping:USERDATA_TAG];

    property_colorMask(L) ; lua_setfield(L, -2, "colorMask") ;

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"contents",
        @"intensity",
        @"maxAnisotropy",
        @"textureComponents",
        @"magnificationFilter",
        @"minificationFilter",
        @"mipFilter",
        @"contentsTransform",
        @"wrapS",
        @"wrapT",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
