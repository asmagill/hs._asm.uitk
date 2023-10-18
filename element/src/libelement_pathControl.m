@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.pathControl" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *PATHCONTROL_STYLES ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    PATHCONTROL_STYLES = @{
        @"standard"   : @(NSPathStyleStandard),
        @"popUp"      : @(NSPathStylePopUp),
    } ;
}

@interface NSMenu (assignmentSharing)
@property (weak) NSView *assignedTo ;
@end

@interface HSUITKElementPathControl : NSPathControl <NSPathControlDelegate>
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;
@end

@implementation HSUITKElementPathControl
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

        self.target       = self ;
        self.action       = @selector(performCallback:) ;
        self.doubleAction = @selector(performDoubleCallback:) ;
        self.continuous   = NO ;

        self.delegate     = self ;
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
        SEL passthroughCallback = NSSelectorFromString(@"performPassthroughCallback:") ;
        while (nextInChain) {
            if ([nextInChain respondsToSelector:passthroughCallback]) {
                [nextInChain performSelectorOnMainThread:passthroughCallback
                                              withObject:messageParts
                                           waitUntilDone:YES] ;
                break ;
            } else {
                nextInChain = [(NSResponder *)nextInChain nextResponder] ;
            }
        }
    }
}

- (void)performCallback:(__unused id)sender {
    NSObject *item = self.clickedPathItem ;
    if (!item) item = (NSObject *)[NSNull null] ;

    [self callbackHamster:@[ self, item ]] ;
}

- (void)performDoubleCallback:(__unused id)sender {
    [self callbackHamster:@[ self, @"doubleAction" ]] ;
}

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.pathControl.new([frame]) -> pathControlObject
/// Constructor
/// Creates a new path control element for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the frame for the element.
///
/// Returns:
///  * the pathControlObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a container element or to a `hs._asm.uitk.window`.
static int pathControl_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementPathControl *element = [[HSUITKElementPathControl alloc] initWithFrame:frameRect];
    if (element) {
        if (lua_gettop(L) != 1) [element setFrameSize:[element fittingSize]] ;
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

static int pathControl_pathStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementPathControl *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(element.pathStyle) ;
        NSArray  *temp   = [PATHCONTROL_STYLES allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized path control style %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = PATHCONTROL_STYLES[key] ;
        if (value) {
            element.pathStyle = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[PATHCONTROL_STYLES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int pathControl_pathItems(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementPathControl *element = [skin toNSObjectAtIndex:1] ;

// technically can set through this, so maybe we'll add it in the future:
// @property(copy) NSArray<NSPathControlItem *> *pathItems;

    [skin pushNSObject:element.pathItems] ;
    return 1 ;
}

static int pathControl_editable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementPathControl *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.editable) ;
    } else {
        element.editable = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int pathControl_url(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementPathControl *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:element.URL] ;
    } else {
        NSURL *url = [skin luaObjectAtIndex:2 toClass:"NSURL"] ;
        element.URL = url ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int pathControl_menu(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementPathControl *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
//         if ([element.menu isEqualTo:element.initialMenu]) {
//             lua_pushnil(L) ;
//         } else {
            [skin pushNSObject:element.menu withOptions:LS_NSDescribeUnknownTypes] ;
//         }
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            if (element.menu) [skin luaRelease:refTable forNSObject:element.menu] ;
//             element.menu = element.initialMenu ;
            element.menu = nil ;
        } else {
            [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.menu", LS_TBREAK] ;
            if (element.menu) {
                [skin luaRelease:refTable forNSObject:element.menu] ;
                element.menu.assignedTo = nil ;
            }
            NSMenu *menu = [skin toNSObjectAtIndex:2] ;
            menu.assignedTo = element ;
            [skin luaRetain:refTable forNSObject:menu] ;
            element.menu = menu ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int pathControl_backgroundColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementPathControl *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:element.backgroundColor] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            element.backgroundColor = nil ;
        } else {
            element.backgroundColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int pathControl_placeholder(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementPathControl *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1 || lua_type(L, 2) == LUA_TBOOLEAN) {
        if (lua_type(L, 2) == LUA_TBOOLEAN && lua_toboolean(L, 2)) {
            [skin pushNSObject:element.placeholderAttributedString] ;
        } else {
            [skin pushNSObject:element.placeholderString] ;
        }
    } else {
        if (lua_type(L, 2) == LUA_TSTRING) {
            element.placeholderString = [skin toNSObjectAtIndex:2] ;
        } else {
            [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs.styledtext", LS_TBREAK] ;
            element.placeholderAttributedString = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// /* Specifies the allowed types when the control isEditable. The allowedTypes can contain a file extension (without the period that begins the extension) or UTI (Uniform Type Identifier). To allow folders, include the UTI 'public.folder'. To allow all types, use 'nil'. If allowedTypes is an empty array, nothing will be allowed. The default value is 'nil', allowing all types.
//  */
// @property(copy) NSArray<NSString *> *allowedTypes;


#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementPathControl(lua_State *L, id obj) {
    HSUITKElementPathControl *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementPathControl *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementPathControlFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementPathControl *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementPathControl, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_gc(lua_State* L) {
    HSUITKElementPathControl *obj  = get_objectFromUserdata(__bridge_transfer HSUITKElementPathControl, L, 1, USERDATA_TAG) ;

    obj.selfRefCount-- ;
    if (obj.selfRefCount == 0) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        obj.callbackRef = [skin luaUnref:obj.refTable ref:obj.callbackRef] ;
        if (obj.menu) {
            obj.menu.assignedTo = nil ;
            [skin luaRelease:refTable forNSObject:obj.menu] ;
        }
        obj = nil ;
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"style",           pathControl_pathStyle},
    {"items",           pathControl_pathItems},
    {"editable",        pathControl_editable},
    {"url",             pathControl_url},
    {"menu",            pathControl_menu},
    {"backgroundColor", pathControl_backgroundColor},
    {"placeholder",     pathControl_placeholder},

// other metamethods inherited from _control and _view
    {"__gc",            userdata_gc},
    {NULL,              NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", pathControl_new},
    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_libelement_pathControl(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKElementPathControl         forClass:"HSUITKElementPathControl"];
    [skin registerLuaObjectHelper:toHSUITKElementPathControlFromLua forClass:"HSUITKElementPathControl"
                                                          withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"style",
        @"editable",
        @"url",
        @"menu",
        @"backgroundColor",
        @"placeholder",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}
