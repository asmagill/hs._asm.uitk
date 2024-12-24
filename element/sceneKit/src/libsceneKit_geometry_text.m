@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import SceneKit ;

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.sceneKit.geometry.text" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *ALIGNMENT_MODES ;
static NSDictionary *TRUNCATION_MODES ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    ALIGNMENT_MODES = @{
        @"natural"   : kCAAlignmentNatural,
        @"left"      : kCAAlignmentLeft,
        @"right"     : kCAAlignmentRight,
        @"center"    : kCAAlignmentCenter,
        @"justified" : kCAAlignmentJustified,
    } ;

    TRUNCATION_MODES = @{
        @"end"    : kCATruncationEnd,
        @"middle" : kCATruncationMiddle,
        @"none"   : kCATruncationNone,
        @"start"  : kCATruncationStart,
    } ;
}

@interface SCNText (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation SCNText (HammerspoonAdditions)

+ (instancetype)textWithName:(NSString *)name string:(id)string extrusionDepth:(CGFloat)depth {
    SCNText *text = [SCNText textWithString:string extrusionDepth:depth] ;

    if (text) {
        text.callbackRef  = LUA_NOREF ;
        text.selfRefCount = 0 ;
        text.name         = name ;
    }
    return text ;
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

static int text_new(lua_State *L) {
    LuaSkin  *skin  = [LuaSkin sharedWithState:L] ;
    NSString *name  = [[NSUUID UUID] UUIDString] ;
    int      txtIdx = 1 ;

    if (lua_gettop(L) == 3) {
        [skin checkArgs:LS_TSTRING, LS_TANY, LS_TNUMBER, LS_TBREAK] ;
        name = [skin toNSObjectAtIndex:1] ;
        txtIdx++ ;
    } else if (lua_gettop(L) == 2) {
        [skin checkArgs:LS_TANY, LS_TNUMBER, LS_TBREAK] ;
    } else {
        return luaL_error(L, "expected [name,] text, and depth arguments") ;
    }

    NSObject *string = nil ;
    CGFloat  depth   = lua_tonumber(L, -1) ;

    if ((lua_type(L, txtIdx) == LUA_TSTRING) || luaL_testudata(L, txtIdx, "hs.styledtext")) {
        string = [skin toNSObjectAtIndex:txtIdx] ;
    } else if (lua_type(L, txtIdx) == LUA_TTABLE) {
        string = [skin luaObjectAtIndex:txtIdx toClass:"NSAttributedString"] ;
    } else if (lua_type(L, txtIdx) != LUA_TNIL) {
        return luaL_argerror(L, txtIdx, "expected string or hs.styledtext representation") ;
    }

    SCNText *text = [SCNText textWithName:name string:string extrusionDepth:depth] ;
    if (text) {
        [skin pushNSObject:text] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int text_textSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    SCNText *text = [skin toNSObjectAtIndex:1] ;

    [skin pushNSSize:NSSizeFromCGSize(text.textSize)] ;
    return 1 ;
}

static int text_string(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    SCNText *text = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:text.string] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            text.string = nil ;
        } else if ((lua_type(L, 2) == LUA_TSTRING) || luaL_testudata(L, 2, "hs.styledtext")) {
            text.string = [skin toNSObjectAtIndex:2] ;
        } else if (lua_type(L, 2) == LUA_TTABLE) {
            text.string = [skin luaObjectAtIndex:2 toClass:"NSAttributedString"] ;
        } else {
            return luaL_argerror(L, 2, "expected nil, string, or hs.styledtext representation") ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int text_font(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNText *text = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:text.font] ;
    } else {
        text.font = [skin luaObjectAtIndex:2 toClass:"NSFont"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int text_wrapped(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    SCNText *text = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, text.wrapped) ;
    } else {
        BOOL value = (BOOL)(lua_toboolean(L, 2)) ;
        text.wrapped = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int text_chamferRadius(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNText *text = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, text.chamferRadius) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        text.chamferRadius = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int text_extrusionDepth(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNText *text = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, text.extrusionDepth) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        text.extrusionDepth = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int text_flatness(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    SCNText *text = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, text.flatness) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0.0) return luaL_argerror(L, 2, "cannot be negative") ;
        text.flatness = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int text_containerFrame(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    SCNText *text = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSRect:text.containerFrame] ;
    } else {
        NSRect value = [skin tableToRectAtIndex:2] ;
        text.containerFrame = NSRectToCGRect(value) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int text_alignmentMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNText *text = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [ALIGNMENT_MODES allKeysForObject:text.alignmentMode] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %@", text.alignmentMode] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSString *value = ALIGNMENT_MODES[key] ;
        if (value) {
            text.alignmentMode = value ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [ALIGNMENT_MODES.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int text_truncationMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    SCNText *text = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [TRUNCATION_MODES allKeysForObject:text.truncationMode] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %@", text.truncationMode] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSString *value = TRUNCATION_MODES[key] ;
        if (value) {
            text.truncationMode = value ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [TRUNCATION_MODES.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// @property(nonatomic, copy, nullable) NSBezierPath *chamferProfile;

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushSCNText(lua_State *L, id obj) {
    SCNText *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(SCNText *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toSCNText(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    SCNText *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge SCNText, L, idx, USERDATA_TAG) ;
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
    {"textSize",       text_textSize},

    {"string",         text_string},
    {"font",           text_font},
    {"wrapped",        text_wrapped},
    {"chamferRadius",  text_chamferRadius},
    {"extrusionDepth", text_extrusionDepth},
    {"flatness",       text_flatness},
    {"containerFrame", text_containerFrame},
    {"alignmentMode",  text_alignmentMode},
    {"truncationMode", text_truncationMode},

    // inherits metamethods from geometry
    {NULL,             NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", text_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libsceneKit_geometry_text(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushSCNText  forClass:"SCNText"];
    [skin registerLuaObjectHelper:toSCNText forClass:"SCNText"
                                withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"string",
        @"font",
        @"wrapped",
        @"chamferRadius",
        @"extrusionDepth",
        @"flatness",
        @"containerFrame",
        @"alignmentMode",
        @"truncationMode",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_subclass") ;
    lua_pop(L, 1) ;

    return 1;
}
