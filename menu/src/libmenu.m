@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.menu" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

static inline NSPoint PointWithFlippedYCoordinate(NSPoint thePoint) {
    return NSMakePoint(thePoint.x, [[NSScreen screens][0] frame].size.height - thePoint.y) ;
}

@interface NSMenuItem (HammerspoonAdditions)
- (instancetype)copyWithState:(lua_State *)L ;
@end

@interface HSUITKMenu : NSMenu <NSMenuDelegate>
@property        int         callbackRef ;
@property        int         passthroughCallback ;
@property        int         selfRefCount ;
@property        BOOL        trackOpen ;
@property        BOOL        trackClose ;
@property        BOOL        trackUpdate ;
@property        BOOL        trackHighlight ;
@property (weak) NSResponder *assignedTo ;
@end

@implementation HSUITKMenu
- (instancetype)initWithTitle:(NSString *)title {
    self = [super initWithTitle:title] ;
    if (self) {
        _callbackRef          = LUA_NOREF ;
        _passthroughCallback  = LUA_NOREF ;
        _selfRefCount         = 0 ;
        _trackOpen            = NO ;
        _trackClose           = NO ;
        _trackUpdate          = YES ;
        _trackHighlight       = NO ;
        _assignedTo           = nil ;

        self.autoenablesItems = YES ;
        self.delegate         = self ;
    }
    return self ;
}

- (instancetype)copyWithState:(lua_State *)L {
    HSUITKMenu *newMenu = [[HSUITKMenu alloc] initWithTitle:self.title] ;
    if (newMenu) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;

        if (_callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:_callbackRef] ;
            newMenu.callbackRef = [skin luaRef:refTable] ;
        }
        if (_passthroughCallback != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:_passthroughCallback] ;
            newMenu.passthroughCallback = [skin luaRef:refTable] ;
        }

        newMenu.trackOpen                    = _trackOpen ;
        newMenu.trackClose                   = _trackClose ;
        newMenu.trackUpdate                  = _trackUpdate ;
        newMenu.trackHighlight               = _trackHighlight ;

        newMenu.allowsContextMenuPlugIns     = self.allowsContextMenuPlugIns ;
        newMenu.showsStateColumn             = self.showsStateColumn ;
        newMenu.minimumWidth                 = self.minimumWidth ;
        newMenu.title                        = self.title ;
        newMenu.font                         = self.font ;

        // may implement later, so copy them just in case
        if (@available(macos 14.0, *)) {
            newMenu.presentationStyle        = self.presentationStyle ;
            newMenu.selectionMode            = self.selectionMode ;
        }
        newMenu.userInterfaceLayoutDirection = self.userInterfaceLayoutDirection ;

        NSMutableArray *newItemArray = [NSMutableArray arrayWithCapacity:self.itemArray.count] ;
        for (NSMenuItem *item in self.itemArray) {
            NSMenuItem *newItem = [item copyWithState:L] ;
            [newItemArray addObject:newItem] ;
            [skin luaRetain:refTable forNSObject:newItem] ;
        }
        newMenu.itemArray = newItemArray.copy ;
    }
    return newMenu ;
}

- (void)passCallbackUpWith:(NSArray *)arguments {
    NSMenu *nextMenu = self.supermenu ;
    SEL passthroughCallback = NSSelectorFromString(@"performPassthroughCallback:") ;
    while (nextMenu && [nextMenu isKindOfClass:[HSUITKMenu class]]) {
        if ([nextMenu respondsToSelector:passthroughCallback]) {
            [nextMenu performSelectorOnMainThread:passthroughCallback
                                          withObject:arguments
                                       waitUntilDone:YES] ;
            break ;
        } else {
            nextMenu = nextMenu.supermenu ;
        }
    }

    if (!nextMenu) {
        NSResponder *nextInChain = _assignedTo ;
        // allow next responder a chance since we don't have a callback set
        while (nextInChain) {
            if ([nextInChain respondsToSelector:passthroughCallback]) {
                [nextInChain performSelectorOnMainThread:passthroughCallback
                                              withObject:arguments
                                           waitUntilDone:YES] ;
                break ;
            } else {
                nextInChain = nextInChain.nextResponder ;
            }
        }
    }
}

// perform callback for menu items which don't have a callback defined; see button.m for how to allow this chaining
- (void)performPassthroughCallback:(NSArray *)arguments {
    if (_passthroughCallback != LUA_NOREF) {
        LuaSkin *skin    = [LuaSkin sharedWithState:NULL] ;
        int     argCount = 1 ;

        [skin pushLuaRef:refTable ref:_passthroughCallback] ;
        [skin pushNSObject:self] ;
        if (arguments) {
            [skin pushNSObject:arguments] ;
            argCount += 1 ;
        }
        if (![skin protectedCallAndTraceback:argCount nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:passthroughCallback error:%@", USERDATA_TAG, errorMessage]] ;
        }
    } else {
        [self passCallbackUpWith:@[ self, arguments ]] ;
    }
}

- (void)performCallbackMessage:(NSString *)message with:(id)data {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
        lua_State *L    = skin.L ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        [skin pushNSObject:self] ;
        [skin pushNSObject:message] ;
        if (data) {
            [skin pushNSObject:data] ;
        } else {
            lua_pushnil(L) ;
        }
        if (![skin protectedCallAndTraceback:3 nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s:callback error - %s", USERDATA_TAG, lua_tostring(L, -1)]] ;
            lua_pop(L, 1) ;
        }
    }
}

- (void)menuWillOpen:(__unused NSMenu *)menu {
    if (_trackOpen) [self performCallbackMessage:@"open" with:nil] ;
}

- (void)menuDidClose:(__unused NSMenu *)menu {
    if (_trackClose) [self performCallbackMessage:@"close" with:nil] ;
}

- (void) menuNeedsUpdate:(__unused NSMenu *)menu {
    if (_trackUpdate) [self performCallbackMessage:@"update" with:nil] ;
}

- (void)menu:(__unused NSMenu *)menu willHighlightItem:(NSMenuItem *)item {
    if (_trackHighlight) [self performCallbackMessage:@"highlight" with:item] ;
}

// - (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action;
// - (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel;
// - (NSRect)confinementRectForMenu:(NSMenu *)menu onScreen:(NSScreen *)screen;
// - (NSInteger)numberOfItemsInMenu:(NSMenu *)menu;

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.menu.new([title]) -> menuObject
/// Constructor
/// Create a new menu with the specified title
///
/// Parameters:
///  * `title` - an optional string specifying the new menu's title.
///
/// Returns:
///  * a new menuObject
///
/// Notes:
///  * id you do not specify a title, one will be generated from a new uuid, similar to `hs.host.uuid()`.
///
///  * most of the elements which use menuObjects will not actually display the menu title, so the name is usually unimportant. There are exceptions, though, so check the relevant element documentation to be certain.
static int menu_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *title = (lua_gettop(L)) == 1 ? [skin toNSObjectAtIndex:1] : [[NSUUID UUID] UUIDString] ;

    HSUITKMenu *menu = [[HSUITKMenu alloc] initWithTitle:title] ;
    if (menu) {
        [skin pushNSObject:menu] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.menubarVisible([state]) -> boolean
/// Function
/// Get or set whether the menubar should be visible when Hammerspoon has focus
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether the menubar should be visible or not when Hammerspoon has focus.
///
/// Returns:
///  * a boolean indicating whether the menubar is currently visible or not when Hammerspoon has focus
///
/// Notes:
///  * this function only affects the menubar when Hammerspoon is the active application (i.e. has focus) *and* the Hammerspoon preferences are set to show the Hammerspoon Dock icon. (see `hs.dockIcon`)
static int menu_menubarVisible(lua_State *L) {
// we may allow the creation of actual hammerspoon specific menus at some point, so go ahead and include this
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_gettop(L) == 1) {
        NSMenu.menuBarVisible = (BOOL)(lua_toboolean(L, 1)) ;
    }

    lua_pushboolean(L, NSMenu.menuBarVisible) ;
    return 1 ;
}


#pragma mark - Module Methods -

/// hs._asm.uitk.menu:callbackFlags([update], [open], [close], [highlight]) -> menuObject | boolean, boolean, boolean, boolean
/// Method
/// Get or set what menu events trigger a callback.
///
/// Parameters:
///  * `update`    - an optional boolean, or nil to leave unchanged, indicating whether or not to generate a callback when the menu requires updating because it is about to be displayed or otherwise traversed. Defaults to true.
///  * `open`      - an optional boolean, or nil to leave unchanged, indicating whether or not to generate a callback when the menu is about to be opened. Defaults to false.
///  * `close`     - an optional boolean, or nil to leave unchanged, indicating whether or not to generate a callback when the menu has been closed. Defaults to false.
///  * `highlight` - an optional boolean, or nil to leave unchanged, indicating whether or not to generate a callback when the highlighted item in the menu is about to change. Defaults to false.
///
/// Returns:
///  * if one or more arguments are provided, returns the menu object; otherwise returns the current values
///
/// Notes:
///  * `update` callbacks are enabled by default because this is when you should make any changes to a dynamicly generated menu. Do not make changes to the menu itself during any other callback phase (though changing any specific item's properties in the menu is still allowed).
///
///  * you only need to include arguments up to the callback type you wish to set; for example, if you want to enable callbacks for `open`, but don't want to change any of the other flags, the arguments would be `(nil, true)`.
static int menu_callbackFlags(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, menu.trackUpdate) ;
        lua_pushboolean(L, menu.trackOpen) ;
        lua_pushboolean(L, menu.trackClose) ;
        lua_pushboolean(L, menu.trackHighlight) ;
        return 4 ;
    } else {
        // this works because an absent item will be LUA_TNONE
        if (lua_type(L, 2) == LUA_TBOOLEAN) menu.trackUpdate    = (BOOL)(lua_toboolean(L, 2)) ;
        if (lua_type(L, 3) == LUA_TBOOLEAN) menu.trackOpen      = (BOOL)(lua_toboolean(L, 3)) ;
        if (lua_type(L, 4) == LUA_TBOOLEAN) menu.trackClose     = (BOOL)(lua_toboolean(L, 4)) ;
        if (lua_type(L, 5) == LUA_TBOOLEAN) menu.trackHighlight = (BOOL)(lua_toboolean(L, 5)) ;
        lua_pushvalue(L, 1) ;
        return 1 ;
    }
}

/// hs._asm.uitk.menu:callback([fn | nil]) -> menuObject | function | nil
/// Method
/// Get or set the menu's callback function.
///
/// Parameters:
///  * `fn` - an optional function, or explicit nil to remove, that will be called back during menu events.
///
/// Returns:
///  * if an argument is provided, returns the menuObject; otherwise returns the current value
///
/// Notes:
///  * see also [hs._asm.uitk.menu:callbackFlags](#callbackFlags)
///
///  * an update callback should expect two arguments and return none:
///    * `menuObject`, "update"
///    * during this callback, you can make any changes to the menu that you wish, including regenerating all of it's items
///  * an open callback should expect two arguments and return none:
///    * `menuObject`, "open"
///    * changes to the menu itself should not be made during this callback (see update)
///  * a close callback should expect two arguments and return none:
///    * `menuObject`, "close"
///  * an highlight callback should expect three arguments and return none:
///    * `menuObject`, "highlight", `menuItemObject`
///    *  if `menuItemObject` then all items are about to become unhighlighted (i.e. no item will be highlighted).
static int menu_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        menu.callbackRef = [skin luaUnref:refTable ref:menu.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            menu.callbackRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (menu.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:menu.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.menu:passthroughCallback([fn | nil]) -> menuObject | function | nil
/// Method
/// Get or set the menu's passthrough callback function.
///
/// Parameters:
///  * `fn` - an optional function, or explicit nil to remove, that will be called back during menu events.
///
/// Returns:
///  * if an argument is provided, returns the menuObject; otherwise returns the current value
///
/// Notes:
///  * The passthrough callback will catch the callback generated by selecting any menu item that doesn't have an explicit callback assigned -- see `hs._asm.uitk.menu.item`
///  * the passthrough callback will receive two arguments:
///    * `menuObject`, table
///    * `table` will be a table containing all of the arguments that would normally be sent to the `menuItemObject` callback. See `hs._asm.uitk.menu.item:callback` for further details.
static int menu_passthroughCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        menu.passthroughCallback = [skin luaUnref:refTable ref:menu.passthroughCallback] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            menu.passthroughCallback = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (menu.passthroughCallback != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:menu.passthroughCallback] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.menu:passthroughCallback([state]) -> menuObject | boolean
/// Method
/// Get or set whether the menu displays the state image next to each menu item
///
/// Parameters:
///  * `state` - an optional boolean, default true, indicating whether or not the menu displays the state image next to each menu item.
///
/// Returns:
///  * if an argument is provided, returns the menuObject; otherwise returns the current value
///
/// Notes:
///  * see `hs._asm.uitk.menu.item:state`
static int menu_showsStateColumn(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, menu.showsStateColumn) ;
    } else {
        menu.showsStateColumn = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu:highlightedItem() -> menuItemObject | nil
/// Method
/// Get the currently highlighted item in the menu
///
/// Parameters:
///  * None
///
/// Returns:
///  * if a menu item is currently highlighted, returns that item; otherwise returns nil
///
/// Notes:
///  * see `hs._asm.uitk.menu.item`
static int menu_highlightedItem(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;

    if (menu.highlightedItem) {
        [skin pushNSObject:menu.highlightedItem] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu:size() -> sizeTable
/// Method
/// Get the size of the menu
///
/// Parameters:
///  * None
///
/// Returns:
///  * returns a sizeTable representing the size of the menu.
///
/// Notes:
///  * a size table is a table with key-value pairs for `h` (height) and `w` (width).
static int menu_size(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;

    [skin pushNSSize:menu.size] ;
    return 1 ;
}

/// hs._asm.uitk.menu:update() -> menuObject
/// Method
/// Force the menu to validate that all of it's items are enabled or disabled as defined by their properties.
///
/// Parameters:
///  * None
///
/// Returns:
///  * returns the menuObject
///
/// Notes:
///  * In general, this method should not be necessary, as the menu will auto-validate its items before the menu opens. However, it may be necessary to invoke directly if the enable status of your menu items change while the menu is being displayed (i.e. open).
static int menu_update(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;

    [menu update] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.menu:popUpMenu(loc, [dark], [item]) -> boolean
/// Method
/// Displays the menu as a pop-up menu at the specified location
///
/// Parameters:
///  * `loc`  - a pointTable specifying the location to display the pop-up menu.
///  * `dark` - an optional boolean or nil, default nil, specifying whether or not the menu should be shown with a Dark appearance (true) or Light appearance (false). `nil`, or leaving this argument out, indicates that the system appearance should be followed.
///  * `item` - an optional integer or menuItem object specifying the menu item that should be highlighted in the popup menu. No item will be highlighted if this argument is left out.
///
/// Returns:
///  * returns true if the user selected an item from the popup menu; otherwise false
///
/// Notes:
///  * a pointTable is a key-value table with `x` and `y` keys specifying the location in screen coordinates.
///  * this method will block the Hammerspoon main thread which may delay the callback functions for some activites, e.g. timers, etc.
///    * this includes the callback for the item selected; you should end your currently running code quickly to allow the callback function to run.
static int menu_popupMenu(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK | LS_TVARARG] ;
    HSUITKMenu *menu    = [skin toNSObjectAtIndex:1] ;
    NSPoint    location = PointWithFlippedYCoordinate([skin tableToPointAtIndex:2]) ;
    NSMenuItem *item    = nil ;

    NSString *ifStyle = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"] ;
    BOOL darkMode = (ifStyle && [ifStyle isEqualToString:@"Dark"]) ;
    int itemIdx = 3 ;

    if (lua_gettop(L) > 2) {
        if ((lua_type(L, 3) == LUA_TBOOLEAN) || (lua_type(L, 3) == LUA_TNIL)) {
            if (lua_type(L, 3) == LUA_TBOOLEAN) {
                darkMode = (BOOL)(lua_toboolean(L, 3)) ;
            }
            itemIdx++ ;
        }
    }
    if (lua_gettop(L) > (itemIdx - 1)) {
        switch(lua_type(L, itemIdx)) {
            case LUA_TUSERDATA:
                if (itemIdx == 3) {
                    [skin checkArgs:LS_TANY, LS_TANY, LS_TUSERDATA, "hs._asm.uitk.menu.item", LS_TBREAK] ;
                } else {
                    [skin checkArgs:LS_TANY, LS_TANY, LS_TANY, LS_TUSERDATA, "hs._asm.uitk.menu.item", LS_TBREAK] ;
                }
                item = [skin toNSObjectAtIndex:itemIdx] ;
                break ;
            case LUA_TNUMBER:
                if (itemIdx == 3) {
                    [skin checkArgs:LS_TANY, LS_TANY, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
                } else {
                    [skin checkArgs:LS_TANY, LS_TANY, LS_TANY, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
                }
                NSInteger idx = lua_tointeger(L, itemIdx) ;
                if ((idx < 1) || (idx > menu.numberOfItems)) {
                    return luaL_argerror(L, itemIdx, "index out of bounds") ;
                }
                item = [menu itemAtIndex:(idx - 1)] ;
                break ;
            default:
                return luaL_argerror(L, itemIdx, "expected integer index or hs._asm.uitk.menu.item userdata") ;
        }
    }
    if (item && ![menu isEqualTo:item.menu]) return luaL_argerror(L, itemIdx, "specified item is not in this menu") ;

    // support darkMode for popup menus
    NSRect contentRect = NSMakeRect(location.x, location.y, 0, 0) ;
    NSWindow *tmpWindow = [[NSWindow alloc] initWithContentRect:contentRect
                                                      styleMask:0
                                                        backing:NSBackingStoreBuffered
                                                          defer:NO] ;
    tmpWindow.releasedWhenClosed = NO ;
    tmpWindow.appearance = [NSAppearance appearanceNamed:(darkMode ? NSAppearanceNameVibrantDark : NSAppearanceNameVibrantLight)] ;
    [tmpWindow orderFront:nil] ;
    BOOL didSelect = [menu popUpMenuPositioningItem:item atLocation:NSMakePoint(0, 0) inView:tmpWindow.contentView] ;
    [tmpWindow close] ;

    lua_pushboolean(L, didSelect) ;
    return 1 ;
}

/// hs._asm.uitk.menu:minimumWidth([width]) -> menuObject | number
/// Method
/// Get or set the minimum width of the menu
///
/// Parameters:
///  * `width` - an optional number, default 0, specifying the minimum width of the menu when it is being displayed.
///
/// Returns:
///  * if an argument is provided, returns the menuObject; otherwise returns the current value
///
/// Notes:
///  * The menu may draw wider than this, depending upon item lengths, location on screen, etc. This is just the minimum allowed.
static int menu_minimumWidth(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKMenu *menu    = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, menu.minimumWidth) ;
    } else {
        CGFloat width = lua_tonumber(L, 2) ;
        menu.minimumWidth = (width < 0) ? 0 : width ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu:title([title]) -> menuObject | string
/// Method
/// Get or set the title of the menu
///
/// Parameters:
///  * `title` - an optional string indicating the new title for the menu.
///
/// Returns:
///  * if an argument is provided, returns the menuObject; otherwise returns the current value
///
/// Notes:
///  * The title is generally set with the [hs._asm.uitk.menu.new](#new) constructor, but you can use this to change it at a later point.
static int menu_title(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKMenu *menu    = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:menu.title] ;
    } else {
        menu.title = [skin toNSObjectAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu:font([font]) -> menuObject | fontTable
/// Method
/// Get or set the default font for the menu and its submenus.
///
/// Parameters:
///  * `font` - an optional fontTable specifying the default font for the menu items and submenus
///
/// Returns:
///  * if an argument is provided, returns the menuObject; otherwise returns the current value
///
/// Notes:
///  * the font will be used for all items in the menu that don't explicitly set their own font.
///
///  * a `fontTable` - is a tabel with key-value pairs specifying a font. The table should contain a `name` key, specifying the font name, and a `size` key, specifying the font size. See `hs.styledtext` for more information about what fonts are available.
static int menu_font(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:menu.font] ;
    } else {
        menu.font = [skin luaObjectAtIndex:2 toClass:"NSFont"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu:supermenu() -> menuObject | nil
/// Method
/// Get the supermenu for this object
///
/// Parameters:
///  * None
///
/// Returns:
///  * the menuObject for the supermenu of this menoObject, or nil if this menu has no supermenu
static int menu_supermenu(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;

    if (menu.supermenu) {
        [skin pushNSObject:menu.supermenu] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu:itemCount() -> integer
/// Method
/// Get the number of items assigned to the menu
///
/// Parameters:
///  * None
///
/// Returns:
///  * an integer specifying the number of items assigned to the menu.
///
/// Notes:
///  * the number of items in the menu may not be the number of items that the menu will show at any given time -- see `hs._asm.uitk.menu.item:alternate`.
static int menu_numberOfItems(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, menu.numberOfItems) ;
    return 1 ;
}

/// hs._asm.uitk.menu:items() -> table
/// Method
/// Get the items of the menu and return them in a table
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the menu items as individual menuItemObjects in index order
static int menu_itemArray(lua_State *L) {
// ??? technically read-write; should we allow setting them all at once?
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;

    if (menu.itemArray) {
        [skin pushNSObject:menu.itemArray] ;
    } else {
        lua_newtable(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu:insert(item, [idx]) -> menuObject
/// Method
/// Insert a menu item into the menu at the specified index
///
/// Parameters:
///  * `item` - an `hs._asm.uitk.menu.item` object that you wish to insert into the menu
///  * `idx`  - an optional integer, default one greater than the number of items currently in the menu, specifying where you wish the item inserted.
///
/// Returns:
///  * the menuObject
///
/// Notes:
///  * returns an error if the index is out of bounds (i.e. not between 1 and the current number of items + 1 inclusive).
static int menu_insertItemAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TUSERDATA, "hs._asm.uitk.menu.item",
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:2] ;
    NSInteger idx = (lua_type(L, -1) == LUA_TNUMBER) ? (lua_tointeger(L, -1) - 1) : menu.numberOfItems ;
    if ((idx < 0) || (idx > menu.numberOfItems)) return luaL_argerror(L, lua_gettop(L), "index out of bounds") ;

    if (item.menu) {
        return luaL_argerror(L, 2, "item already assigned to a menu") ;
    }

    [skin luaRetain:refTable forNSObject:item] ;
    [menu insertItem:item atIndex:idx] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.menu:itemAtIndex(idx) -> menuItemObject | nil
/// Method
/// Returns the item at the specified index or nil if no item at that index exists
///
/// Parameters:
///  * `idx`  - an integer specifying the index of the menu item you want
///
/// Returns:
///  * the menuItemObject or nil if no item exists at that index
static int menu_itemAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;
    NSInteger  idx   = lua_tointeger(L, 2) ;
    NSMenuItem *item = nil ;

    if (!((idx < 1) || (idx > menu.numberOfItems))) item = [menu itemAtIndex:(idx - 1)] ;

    if (item) {
        [skin pushNSObject:item] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu:remove([idx]) -> menuObject
/// Method
/// Remove the meun item at the specified index from the menu
///
/// Parameters:
///  * `idx`  - an optional integer, default the number of items in the menu, specifying the index of the menu item to remove
///
/// Returns:
///  * the menuObject
///
/// Notes:
///  * returns an error if the index is out of bounds (i.e. not between 1 and the current number of items inclusive).
static int menu_removeItemAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;
    NSInteger idx = ((lua_type(L, -1) == LUA_TNUMBER) ? lua_tointeger(L, -1) : menu.numberOfItems) - 1 ;
    if ((idx < 0) || (idx >= menu.numberOfItems)) return luaL_argerror(L, lua_gettop(L), "index out of bounds") ;

    NSMenuItem *item = [menu itemAtIndex:idx] ;
    [skin luaRelease:refTable forNSObject:item] ;
    [menu removeItem:item] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.menu:removeAll() -> menuObject
/// Method
/// Remove all items from the menu
///
/// Parameters:
///  * None
///
/// Returns:
///  * the menuObject
static int menu_removeAll(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;

    if (menu.itemArray) {
        for (NSMenuItem *item in menu.itemArray) [skin luaRelease:refTable forNSObject:item] ;
        [menu removeAllItems] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.menu:indexOfItem(item) -> integer | nil
/// Method
/// Get the index of the specified item within the menu.
///
/// Paramters:
///  * `item` - the item to find in the menu and return the index of
///
/// Returns:
///  * if the item is currently in the menu, returns its index; otherwise returns nil
static int menu_indexOfItem(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs._asm.uitk.menu.item", LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:2] ;

    NSInteger idx = [menu indexOfItem:item] + 1 ;
    if (idx > 0) {
        lua_pushinteger(L, idx) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu:indexWithID(identifier) -> integer | nil
/// Method
/// Get the index of the item with the specified id
///
/// Paramters:
///  * `identifier` - a string that has been assigned as the items identifier
///
/// Returns:
///  * if an item with the specified identifier is in the menu, returns its index; otherwise returns nil
///
/// Notes:
///  * if multiple items in the menu share the identifier, this method will only return the first one (i.e. the one with the lowest index number)
static int menu_indexOfItemWithRepresentedObject(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL, LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;
    NSString   *obj  = (lua_type(L, 2) != LUA_TNIL) ? [skin toNSObjectAtIndex:2] : nil ;

    NSInteger idx = [menu indexOfItemWithRepresentedObject:obj] + 1 ;
    if (idx > 0) {
        lua_pushinteger(L, idx) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu:indexWithSubmenu(submenu) -> integer | nil
/// Method
/// Get the index of the item with the specified menu as a submenu
///
/// Paramters:
///  * `submenu` - a menuObject representing a submenu of the menu object
///
/// Returns:
///  * if an item with the specified submenu is in the menu, returns its index; otherwise returns nil
static int menu_indexOfItemWithSubmenu(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;
    HSUITKMenu *item = [skin toNSObjectAtIndex:2] ;

    NSInteger idx = [menu indexOfItemWithSubmenu:item] + 1 ;
    if (idx > 0) {
        lua_pushinteger(L, idx) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu:indexWithTag(tag) -> integer | nil
/// Method
/// Get the index of the item with the specified tag value
///
/// Paramters:
///  * `tag` - an integer specifying the tag value
///
/// Returns:
///  * if an item with the specified tag value is in the menu, returns its index; otherwise returns nil
///
/// Notes:
///  * if multiple items in the menu share the same tag value, this method will only return the first one (i.e. the one with the lowest index number)
static int menu_indexOfItemWithTag(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;
    NSInteger  tag   = lua_tointeger(L, 2) ;

    NSInteger idx = [menu indexOfItemWithTag:tag] + 1 ;
    if (idx > 0) {
        lua_pushinteger(L, idx) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu:indexWithTitle(title) -> integer | nil
/// Method
/// Get the index of the item with the specified title
///
/// Paramters:
///  * `title` - a string specifying the title of the item to locate
///
/// Returns:
///  * if an item with the specified title is in the menu, returns its index; otherwise returns nil
///
/// Notes:
///  * if multiple items in the menu share the same title, this method will only return the first one (i.e. the one with the lowest index number)
static int menu_indexOfItemWithTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    HSUITKMenu *menu  = [skin toNSObjectAtIndex:1] ;
    NSString   *title = [skin toNSObjectAtIndex:2] ;

    NSInteger idx = [menu indexOfItemWithTitle:title] + 1 ;
    if (idx > 0) {
        lua_pushinteger(L, idx) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu:chooseItem(idx) -> menuObject
/// Method
/// Simulate the user selecting the item in the menu at the specified index.
///
/// Parameters:
///  * `idx` - the index of the item to be selected
///
/// Returns:
///  * the menuObject
///
/// Notes:
///  * returns an error if the index is out of bounds (i.e. not between 1 and the current number of items + 1 inclusive).
///
///  * this method will trigger the callback, if defined, for the specified item.
static int menu_performActionForItemAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKMenu *menu = [skin toNSObjectAtIndex:1] ;
    NSInteger idx = lua_tointeger(L, 2) - 1 ;
    if ((idx < 0) || (idx >= menu.numberOfItems)) return luaL_argerror(L, lua_gettop(L), "index out of bounds") ;

    [menu performActionForItemAtIndex:idx] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKMenu(lua_State *L, id obj) {
    HSUITKMenu *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKMenu *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKMenu(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKMenu *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKMenu, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKMenu *obj = [skin luaObjectAtIndex:1 toClass:"HSUITKMenu"] ;
    NSString *title = obj.title ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSUITKMenu *obj1 = [skin luaObjectAtIndex:1 toClass:"HSUITKMenu"] ;
        HSUITKMenu *obj2 = [skin luaObjectAtIndex:2 toClass:"HSUITKMenu"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSUITKMenu *obj = get_objectFromUserdata(__bridge_transfer HSUITKMenu, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef         = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj.passthroughCallback = [skin luaUnref:refTable ref:obj.passthroughCallback] ;
            obj.delegate = nil ;
            obj.assignedTo = nil ;
            if (obj.itemArray) {
                for (NSMenuItem *item in obj.itemArray) [skin luaRelease:refTable forNSObject:item] ;
                [obj removeAllItems] ;
            }
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
    {"highlightedItem",     menu_highlightedItem},
    {"callback",            menu_callback},
    {"showsState",          menu_showsStateColumn},
    {"popupMenu",           menu_popupMenu},
    {"size",                menu_size},
    {"minimumWidth",        menu_minimumWidth},
    {"title",               menu_title},
    {"font",                menu_font},
    {"supermenu",           menu_supermenu},
    {"items",               menu_itemArray},
    {"itemCount",           menu_numberOfItems},
    {"insert",              menu_insertItemAtIndex},
    {"itemAtIndex",         menu_itemAtIndex},
    {"remove",              menu_removeItemAtIndex},
    {"removeAll",           menu_removeAll},
    {"indexOfItem",         menu_indexOfItem},
    {"indexWithID",         menu_indexOfItemWithRepresentedObject},
    {"indexWithSubmenu",    menu_indexOfItemWithSubmenu},
    {"indexWithTag",        menu_indexOfItemWithTag},
    {"indexWithTitle",      menu_indexOfItemWithTitle},
    {"callbackFlags",       menu_callbackFlags},
    {"passthroughCallback", menu_passthroughCallback},
    {"update",              menu_update},
    {"chooseItem",          menu_performActionForItemAtIndex},

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",            menu_new},
    {"menubarVisible", menu_menubarVisible},
    {NULL,             NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_libmenu(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSUITKMenu  forClass:"HSUITKMenu"];
    [skin registerLuaObjectHelper:toHSUITKMenu forClass:"HSUITKMenu"
                                    withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"callback",
        @"showsState",
        @"minimumWidth",
        @"title",
        @"font",
//         @"callbackFlags",
        @"passthroughCallback",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
