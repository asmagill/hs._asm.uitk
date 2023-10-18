@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.popUpButton" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *POPUPBUTTON_EDGES ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    POPUPBUTTON_EDGES = @{
        @"left"   : @(NSMinXEdge),
        @"top"    : @(NSMinYEdge),
        @"right"  : @(NSMaxXEdge),
        @"bottom" : @(NSMaxYEdge)
    } ;
}

@interface NSMenu (assignmentSharing)
@property (weak) NSView *assignedTo ;
@end

@interface HSUITKElementPopUpButton : NSPopUpButton
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;
@property            NSMenu     *initialMenu ;
@end

@implementation HSUITKElementPopUpButton

- (instancetype)initWithFrame:(NSRect)frameRect pullsDown:(BOOL)flag {
    @try {
        self = [super initWithFrame:frameRect pullsDown:flag] ;
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:new - %@", USERDATA_TAG, exception.reason]] ;
        self = nil ;
    }

    if (self) {
        _callbackRef    = LUA_NOREF ;
        _refTable       = refTable ;
        _selfRefCount   = 0 ;
        _initialMenu    = self.menu ; // this placeholder will be what we reset it to when
                                      // the user assigns it nil

        self.target       = self ;
        self.action       = @selector(performCallback:) ;
        self.continuous   = NO ;
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
    [self callbackHamster:@[ self ]] ;
}

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.popUpButton.new([menu], [pullsDown]) -> popUpButtonObject
/// Constructor
/// Creates a new popUpButton element for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `menu`      - an optional `hs._asm.uitk.menu` object specifying the menu for the pop up button.
///  * `pullsDown` - an optional boolean, default false, specifying whether the menu is a pulls down menu (true) or a pop up menu (false).
///
/// Returns:
///  * the popUpButtonObject
///
/// Notes:
///  * You can also add or change the menu item later with the [hs._asm.uitk.element.popUpButton:menu](#menu) method.
static int popUpButton_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSMenu *menu     = nil ;
    BOOL   pullsDown = NO ;

    switch(lua_gettop(L)) {
        case 1:
            if (lua_type(L, 1) == LUA_TUSERDATA) {
                [skin checkArgs:LS_TUSERDATA, "hs._asm.uitk.menu", LS_TBREAK] ;
                menu = [skin toNSObjectAtIndex:1] ;
            } else {
                [skin checkArgs:LS_TBOOLEAN, LS_TBREAK] ;
                pullsDown = lua_toboolean(L, 1) ;
            }
            break ;
        case 2:
            [skin checkArgs:LS_TUSERDATA, "hs._asm.uitk.menu", LS_TBREAK] ;
            menu = [skin toNSObjectAtIndex:1] ;
            pullsDown = lua_toboolean(L, 2) ;
            break ;
    }

    HSUITKElementPopUpButton *button = [[HSUITKElementPopUpButton alloc] initWithFrame:NSZeroRect
                                                                               pullsDown:pullsDown] ;

    if (button) {
        if (menu) {
            button.menu  = menu ;
            menu.assignedTo = button ;
            [skin luaRetain:refTable forNSObject:menu] ;
            [button selectItem:nil] ;
        }
        [button setFrameSize:[button fittingSize]] ;

        [skin pushNSObject:button] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

static int popUpButton_menu(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementPopUpButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if ([button.menu isEqualTo:button.initialMenu]) {
            lua_pushnil(L) ;
        } else {
            [skin pushNSObject:button.menu withOptions:LS_NSDescribeUnknownTypes] ;
        }
    } else {
        NSMenu *oldMenu = nil ;

        if (lua_type(L, 2) == LUA_TNIL) {
            oldMenu     = button.menu ;
            button.menu = button.initialMenu ;
        } else {
            [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.menu", LS_TBREAK] ;
            oldMenu      = button.menu ;
            NSMenu *menu = [skin toNSObjectAtIndex:2] ;
            menu.assignedTo = button ;
            button.menu  = menu ;
            [skin luaRetain:refTable forNSObject:menu] ;
        }
        [button selectItem:nil] ;

        if (oldMenu && ![oldMenu isEqualTo:button.initialMenu]) {
            oldMenu.assignedTo = nil ;
            [skin luaRelease:refTable forNSObject:oldMenu] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int popUpButton_pullsDown(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementPopUpButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, button.pullsDown) ;
    } else {
        button.pullsDown = lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }

    return 1 ;
}

static int popUpButton_selectedItem(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementPopUpButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:button.selectedItem] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            [button selectItem:nil] ;
        } else {
            [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.menu.item", LS_TBREAK] ;
            NSMenuItem *item = [skin toNSObjectAtIndex:2] ;
            if ([item.menu isEqualTo:button.menu]) {
                [button selectItem:item] ;
            } else {
                return luaL_argerror(L, 2, "item does not belong to button menu") ;
            }
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int popUpButton_selectedIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementPopUpButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, button.indexOfSelectedItem + 1) ;
    } else {
        NSInteger idx = lua_tointeger(L, 2) ;
        idx-- ;

        if (idx < -1 || idx >= button.numberOfItems) {
            return luaL_argerror(L, 2, "index out of bounds") ;
        }
        [button selectItemAtIndex:idx] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int popUpButton_selectedTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementPopUpButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:button.titleOfSelectedItem] ;
    } else {
        NSString *title = nil ;
        if (lua_type(L, 2) == LUA_TSTRING) {
            title = [skin toNSObjectAtIndex:2] ;
        }
        [button selectItemWithTitle:title] ;
        lua_pushvalue(L, 1) ;
    }

    return 1 ;
}

static int popUpButton_preferredEdge(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementPopUpButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *obj = @(button.preferredEdge) ;
        NSArray *temp = [POPUPBUTTON_EDGES allKeysForObject:obj];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized preferredEdge %@ -- notify developers", USERDATA_TAG, obj]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *obj = POPUPBUTTON_EDGES[key] ;
        if (obj) {
            button.preferredEdge = [obj unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[POPUPBUTTON_EDGES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

// - (void)setTitle:(NSString *)string;

// NSNotificationName NSPopUpButtonWillPopUpNotification;

// TODO: should inherit from NSButton
//       either make this a submodule (like textField stuff) or copy methods here?

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementPopUpButton(lua_State *L, id obj) {
    HSUITKElementPopUpButton *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementPopUpButton *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementPopUpButtonFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementPopUpButton *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementPopUpButton, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_gc(lua_State* L) {
    HSUITKElementPopUpButton *obj  = get_objectFromUserdata(__bridge_transfer HSUITKElementPopUpButton, L, 1, USERDATA_TAG) ;

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
    {"menu",          popUpButton_menu},
    {"pullsDown",     popUpButton_pullsDown},
    {"selectedItem",  popUpButton_selectedItem},
    {"selectedIndex", popUpButton_selectedIndex},
    {"selectedTitle", popUpButton_selectedTitle},
    {"preferredEdge", popUpButton_preferredEdge},

// other metamethods inherited from _control and _view
    {"__gc",          userdata_gc},
    {NULL,            NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", popUpButton_new},
    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_libelement_popUpButton(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKElementPopUpButton         forClass:"HSUITKElementPopUpButton"];
    [skin registerLuaObjectHelper:toHSUITKElementPopUpButtonFromLua forClass:"HSUITKElementPopUpButton"
                                                          withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}
