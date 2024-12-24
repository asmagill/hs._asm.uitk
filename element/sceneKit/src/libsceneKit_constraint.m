@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;
#import "SKconversions.h"

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.constraint" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
#define get_anyObjectFromUserdata(objType, L, idx) (objType*)*((void**)lua_touserdata(L, idx))

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
}

@interface SCNConstraint (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

BOOL oneOfOurConstraintObjects(SCNConstraint *obj) {
    return [obj isKindOfClass:[SCNConstraint class]]  &&
           [obj respondsToSelector:NSSelectorFromString(@"selfRefCount")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setSelfRefCount:")] &&
           [obj respondsToSelector:NSSelectorFromString(@"refTable")] &&
           [obj respondsToSelector:NSSelectorFromString(@"callbackRef")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setCallbackRef:")] ;
}

@implementation SCNConstraint (HammerspoonAdditions)

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

static int constraint_influenceFactor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNConstraint *constraint = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!constraint || !oneOfOurConstraintObjects(constraint)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit constraint object") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, constraint.influenceFactor) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0 || value > 1.0) return luaL_argerror(L, 2, "value must be between 0.0 and 1.0 inclusive") ;
        constraint.influenceFactor = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int constraint_enabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNConstraint *constraint = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!constraint || !oneOfOurConstraintObjects(constraint)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit constraint object") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, constraint.enabled) ;
    } else {
        constraint.enabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int constraint_incremental(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNConstraint *constraint = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!constraint || !oneOfOurConstraintObjects(constraint)) {
        return luaL_argerror(L, 1, "expected userdata representing a sceneKit constraint object") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, constraint.incremental) ;
    } else {
        constraint.incremental = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNConstraint(lua_State *L, id obj) {
    SCNConstraint *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNConstraint *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNConstraint(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNConstraint *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNConstraint, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     SCNConstraint *obj  = [skin toNSObjectAtIndex:1] ;

    NSString *title = @"<not userdata>" ;
    if (lua_getmetatable(L, -1)) {
        lua_getfield(L, -1, "__name") ;
        title = [NSString stringWithUTF8String:lua_tostring(L, -1)] ;
        lua_pop(L, 2) ;
    }

    [skin pushNSObject:[NSString stringWithFormat:@"%@: (%p)", title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if ((lua_type(L, 1) == LUA_TUSERDATA) && (lua_type(L, 2) == LUA_TUSERDATA)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        NSObject *obj1 = [skin toNSObjectAtIndex:1] ;
        NSObject *obj2 = [skin toNSObjectAtIndex:2];
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    SCNConstraint *obj  = get_anyObjectFromUserdata(__bridge_transfer SCNConstraint, L, 1) ;

    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:obj.refTable ref:obj.callbackRef] ;
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
    {"influenceFactor", constraint_influenceFactor},
    {"enabled",         constraint_enabled},
    {"incremental",     constraint_incremental},

    {"__tostring",      userdata_tostring},
    {"__eq",            userdata_eq},
    {"__gc",            userdata_gc},
    {NULL,              NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {NULL,         NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libsceneKit_constraint(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushSCNConstraint  forClass:"SCNConstraint"];
    [skin registerLuaObjectHelper:toSCNConstraint forClass:"SCNConstraint"
                                       withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"influenceFactor",
        @"enabled",
        @"incremental",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
