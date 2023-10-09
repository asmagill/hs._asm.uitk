@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.switch" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

@interface HSUITKElementSwitch : NSSwitch
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;
@end

@implementation HSUITKElementSwitch
- (instancetype)initWithFrame:(NSRect)frameRect {
    @try {
        self = [super initWithFrame:frameRect] ;
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:new - %@", USERDATA_TAG, exception.reason]] ;
        self = nil ;
    }

    if (self) {
        _callbackRef    = LUA_NOREF ;
        _refTable       = refTable ;
        _selfRefCount   = 0 ;

        self.target     = self ;
        self.action     = @selector(performCallback:) ;
        self.continuous = NO ;
    }
    return self ;
}

- (void)callbackHamster:(NSArray *)messageParts { // does the "heavy lifting"
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        for (id part in messageParts) [skin pushNSObject:part] ;
        if (![skin protectedCallAndTraceback:(int)messageParts.count nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:callback error:%@", USERDATA_TAG, errorMessage]] ;
        }
    } else {
        // allow next responder a chance since we don't have a callback set
        NSObject *nextInChain = [self nextResponder] ;
        if (nextInChain) {
            SEL passthroughCallback = NSSelectorFromString(@"performPassthroughCallback:") ;
            if ([nextInChain respondsToSelector:passthroughCallback]) {
                [nextInChain performSelectorOnMainThread:passthroughCallback
                                              withObject:messageParts
                                           waitUntilDone:YES] ;
            }
        }
    }
}

- (void)performCallback:(__unused id)sender {
    BOOL isOn = (self.state != NSControlStateValueOff) ;
    [self callbackHamster:@[ self, @(isOn) ]] ;
}

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.switch.new([frame]) -> switchObject
/// Constructor
/// Creates a new switch element for `hs._asm.uitk.panel`.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the frame for the element.
///
/// Returns:
///  * the switchObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a manager or to a `hs._asm.uitk.panel` window.
static int switch_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementSwitch *element = [[HSUITKElementSwitch alloc] initWithFrame:frameRect];
    if (element) {
        if (lua_gettop(L) != 1) [element setFrameSize:[element fittingSize]] ;
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

static int switch_state(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSwitch *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        if (lua_toboolean(L, 2)) {
            element.state = NSControlStateValueOn ;
        } else {
            element.state = NSControlStateValueOff ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (element.state == NSControlStateValueOff) {
            lua_pushboolean(L, false) ;
        } else {
            lua_pushboolean(L, true) ;
        }
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementSwitch(lua_State *L, id obj) {
    HSUITKElementSwitch *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementSwitch *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementSwitchFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementSwitch *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementSwitch, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"state", switch_state},

// other metamethods inherited from _control and _view
    {NULL,    NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", switch_new},
    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_libelement_switch(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSUITKElementSwitch         forClass:"HSUITKElementSwitch"];
    [skin registerLuaObjectHelper:toHSUITKElementSwitchFromLua forClass:"HSUITKElementSwitch"
                                                     withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through content metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[ @"state", ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}
