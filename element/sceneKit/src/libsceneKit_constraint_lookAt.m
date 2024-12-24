@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;
#import "SKconversions.h"

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.constraint.lookAt" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

@interface SCNLookAtConstraint (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation SCNLookAtConstraint (HammerspoonAdditions)

+ (instancetype)setupConstraintWithTarget:(SCNNode *)target {
    SCNLookAtConstraint *constraint = [SCNLookAtConstraint lookAtConstraintWithTarget:target] ;

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
    SCNNode *node = nil ;
    if (lua_gettop(L) != 1 || lua_type(L, 1) != LUA_TNIL) {
        [skin checkArgs:LS_TUSERDATA, "hs._asm.uitk.element.sceneKit.node", LS_TBREAK] ;
        node = [skin toNSObjectAtIndex:1] ;
    }

    SCNLookAtConstraint *constraint = [SCNLookAtConstraint setupConstraintWithTarget:node] ;
    if (constraint) {
        if (node) [skin luaRetain:refTable forNSObject:node] ;
        [skin pushNSObject:constraint] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int constraint_localFront(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLookAtConstraint *constraint = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        pushSCNVector3(L, constraint.localFront) ;
    } else {
        SCNVector3 vector = pullSCNVector3(L, 2) ;
        constraint.localFront = vector ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int constraint_targetOffset(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLookAtConstraint *constraint = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        pushSCNVector3(L, constraint.targetOffset) ;
    } else {
        SCNVector3 vector = pullSCNVector3(L, 2) ;
        constraint.targetOffset = vector ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int constraint_worldUp(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLookAtConstraint *constraint = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        pushSCNVector3(L, constraint.worldUp) ;
    } else {
        SCNVector3 vector = pullSCNVector3(L, 2) ;
        constraint.worldUp = vector ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int constraint_target(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLookAtConstraint *constraint = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:constraint.target] ;
    } else {
        SCNNode *oldTarget = constraint.target ;
        if (lua_type(L, 2) == LUA_TNIL) {
            constraint.target = nil ;
        } else {
            [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.element.sceneKit.node", LS_TBREAK] ;
            constraint.target = [skin toNSObjectAtIndex:2] ;
            [skin luaRetain:refTable forNSObject:constraint.target] ;
        }
        if (oldTarget) [skin luaRelease:refTable forNSObject:oldTarget] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int constraint_gimbalLockEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNLookAtConstraint *constraint = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, constraint.gimbalLockEnabled) ;
    } else {
        constraint.gimbalLockEnabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNLookAtConstraint(lua_State *L, id obj) {
    SCNLookAtConstraint *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNLookAtConstraint *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNLookAtConstraint(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNLookAtConstraint *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNLookAtConstraint, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int userdata_gc(lua_State* L) {
    SCNLookAtConstraint *obj  = get_objectFromUserdata(__bridge_transfer SCNLookAtConstraint, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:obj.refTable ref:obj.callbackRef] ;
            if (obj.target) [skin luaRelease:refTable forNSObject:obj.target] ;
            obj.target = nil ;
            obj = nil ;
        }
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"localFront",        constraint_localFront},
    {"targetOffset",      constraint_targetOffset},
    {"worldUp",           constraint_worldUp},
    {"target",            constraint_target},
    {"gimbalLockEnabled", constraint_gimbalLockEnabled},

    // inherits metamethods from constraint
    {"__gc",              userdata_gc},
    {NULL,                NULL}
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

int luaopen_hs__asm_uitk_element_libsceneKit_constraint_lookAt(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushSCNLookAtConstraint  forClass:"SCNLookAtConstraint"];
    [skin registerLuaObjectHelper:toSCNLookAtConstraint forClass:"SCNLookAtConstraint"
                                             withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"localFront",
        @"targetOffset",
        @"worldUp",
        @"target",
        @"gimbalLockEnabled",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
