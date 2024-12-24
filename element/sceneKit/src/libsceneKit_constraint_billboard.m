@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;
#import "SKconversions.h"

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.constraint.billboard" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

@interface SCNBillboardConstraint (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation SCNBillboardConstraint (HammerspoonAdditions)

+ (instancetype)setupConstraint {
    SCNBillboardConstraint *constraint = [SCNBillboardConstraint billboardConstraint] ;

    if (constraint) {
        constraint.callbackRef  = LUA_NOREF ;
        constraint.selfRefCount = 0 ;
    }
    return constraint ;
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

static int constraint_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    SCNBillboardConstraint *constraint = [SCNBillboardConstraint setupConstraint] ;
    if (constraint) {
        [skin pushNSObject:constraint] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int constraint_freeAxes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    SCNBillboardConstraint *constraint = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_newtable(L) ;
        lua_pushboolean(L, ((constraint.freeAxes & SCNBillboardAxisX) == SCNBillboardAxisX) ? YES : NO) ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushboolean(L, ((constraint.freeAxes & SCNBillboardAxisY) == SCNBillboardAxisY) ? YES : NO) ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushboolean(L, ((constraint.freeAxes & SCNBillboardAxisZ) == SCNBillboardAxisZ) ? YES : NO) ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    } else {
        BOOL xFree = ((constraint.freeAxes & SCNBillboardAxisX) == SCNBillboardAxisX) ? YES : NO ;
        BOOL yFree = ((constraint.freeAxes & SCNBillboardAxisY) == SCNBillboardAxisY) ? YES : NO ;
        BOOL zFree = ((constraint.freeAxes & SCNBillboardAxisZ) == SCNBillboardAxisZ) ? YES : NO ;

        if (lua_type(L, 2) == LUA_TTABLE) {
            [skin checkArgs:LS_TANY, LS_TTABLE, LS_TBREAK] ;
            if (lua_geti(L, 2, 1) == LUA_TBOOLEAN) {
                xFree = (BOOL)(lua_toboolean(L, -1)) ;
            } else if (lua_type(L, -1) != LUA_TNIL) {
                return luaL_argerror(L, 2, "expected table of boolean or nil values") ;
            }
            lua_pop(L, 1) ;
            if (lua_geti(L, 2, 2) == LUA_TBOOLEAN) {
                yFree = (BOOL)(lua_toboolean(L, -1)) ;
            } else if (lua_type(L, -1) != LUA_TNIL) {
                return luaL_argerror(L, 2, "expected table of boolean or nil values") ;
            }
            lua_pop(L, 1) ;
            if (lua_geti(L, 2, 3) == LUA_TBOOLEAN) {
                zFree = (BOOL)(lua_toboolean(L, -1)) ;
            } else if (lua_type(L, -1) != LUA_TNIL) {
                return luaL_argerror(L, 2, "expected table of boolean or nil values") ;
            }
            lua_pop(L, 1) ;
        } else {
            [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TNIL,
                                     LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                                     LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                                     LS_TBREAK] ;
            if (lua_type(L, 2) == LUA_TBOOLEAN) xFree = (BOOL)(lua_toboolean(L, 2)) ;
            if (lua_type(L, 3) == LUA_TBOOLEAN) yFree = (BOOL)(lua_toboolean(L, 3)) ;
            if (lua_type(L, 4) == LUA_TBOOLEAN) zFree = (BOOL)(lua_toboolean(L, 4)) ;
        }
        SCNBillboardAxis newValue = 0 ;
        if (xFree) newValue |= SCNBillboardAxisX ;
        if (yFree) newValue |= SCNBillboardAxisY ;
        if (zFree) newValue |= SCNBillboardAxisZ ;
        constraint.freeAxes = newValue ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNBillboardConstraint(lua_State *L, id obj) {
    SCNBillboardConstraint *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNBillboardConstraint *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNBillboardConstraint(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNBillboardConstraint *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNBillboardConstraint, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"freeAxes", constraint_freeAxes},
    // inherits metamethods from constraint
    {NULL,       NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", constraint_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libsceneKit_constraint_billboard(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushSCNBillboardConstraint  forClass:"SCNBillboardConstraint"];
    [skin registerLuaObjectHelper:toSCNBillboardConstraint forClass:"SCNBillboardConstraint"
                                                withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"freeAxes",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
