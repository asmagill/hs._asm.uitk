// Uses associated objects to "add" callback and selfRef -- this is done instead of
// subclassing so we don't have to add special code in menu.m to deal with regular
// menu items and separator items; forcing an NSMenuItem for a separator into an
// HSUITKMenuItem object seems... dangerous at best.

@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;
@import Carbon.HIToolbox.Events ;

static const char * const USERDATA_TAG = "hs._asm.uitk.menu.item" ;
static LSRefTable         refTable     = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;
static void *VALIDATEREF_KEY  = @"HS_validateCallbackKey" ;

static NSDictionary *MENU_ITEM_STATES ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

static BOOL oneOfOurElementObjects(NSView *obj) {
    return [obj isKindOfClass:[NSView class]]  &&
           [obj respondsToSelector:NSSelectorFromString(@"selfRefCount")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setSelfRefCount:")] &&
           [obj respondsToSelector:NSSelectorFromString(@"refTable")] &&
           [obj respondsToSelector:NSSelectorFromString(@"callbackRef")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setCallbackRef:")] ;
}

static void defineInternalDictionaries(void) {
    MENU_ITEM_STATES = @{
        @"on"    : @(NSControlStateValueOn),
        @"off"   : @(NSControlStateValueOff),
        @"mixed" : @(NSControlStateValueMixed),
    } ;
}

@interface NSMenuItem (HammerspoonAdditions)
@property (nonatomic) int  callbackRef ;
@property (nonatomic) int  selfRefCount ;
@property (nonatomic) int  validateCallback ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)validateCallback ;
- (void)setValidateCallback:(int)value ;

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;
- (instancetype)copyWithState:(lua_State *)L ;
@end

@implementation NSMenuItem (HammerspoonAdditions)

+ (instancetype)newWithTitle:(NSString *)title {
    NSMenuItem *item = nil ;
    if ([title isEqualToString:@"-"]) {
        item = [NSMenuItem separatorItem] ;
    } else {
        item = [[NSMenuItem alloc] initWithTitle:title action:@selector(itemSelected:) keyEquivalent:@""] ;
    }
    if (item) {
        item.callbackRef      = LUA_NOREF ;
        item.validateCallback = LUA_NOREF ;
        item.selfRefCount     = 0 ;
        item.target           = item ;
    }
    return item ;
}

- (instancetype)copyWithState:(lua_State *)L {
    NSMenuItem *newItem = [self copy] ;
    if (newItem) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        if (self.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:self.callbackRef] ;
            newItem.callbackRef = [skin luaRef:refTable] ;
        } else {
            newItem.callbackRef = LUA_NOREF ;
        }
        if (self.validateCallback != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:self.validateCallback] ;
            newItem.validateCallback = [skin luaRef:refTable] ;
        } else {
            newItem.validateCallback = LUA_NOREF ;
        }
        newItem.selfRefCount = 0 ;
        newItem.target = newItem ;
    }
    return newItem ;
}

- (void)setCallbackRef:(int)value {
    NSNumber *valueWrapper = [NSNumber numberWithInt:value];
    objc_setAssociatedObject(self, CALLBACKREF_KEY, valueWrapper, OBJC_ASSOCIATION_RETAIN);
}

- (int)callbackRef {
    NSNumber *valueWrapper = objc_getAssociatedObject(self, CALLBACKREF_KEY) ;
    if (!valueWrapper) {
        valueWrapper = @(LUA_NOREF) ;
        [self setCallbackRef:valueWrapper.intValue] ;
    }
    return valueWrapper.intValue ;
}

- (void)setValidateCallback:(int)value {
    NSNumber *valueWrapper = [NSNumber numberWithInt:value];
    objc_setAssociatedObject(self, VALIDATEREF_KEY, valueWrapper, OBJC_ASSOCIATION_RETAIN);
}

- (int)validateCallback {
    NSNumber *valueWrapper = objc_getAssociatedObject(self, VALIDATEREF_KEY) ;
    if (!valueWrapper) {
        valueWrapper = @(LUA_NOREF) ;
        [self setValidateCallback:valueWrapper.intValue] ;
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

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    // ??? Paranoia? I don't do this kind of checking elsewhere...
    if (self != menuItem) {
        [LuaSkin logVerbose:[NSString stringWithFormat:@"%s:validateMenuItem - message for menuItem which is not self: %@ != %@", USERDATA_TAG, menuItem, self]] ;
    }
    if (self.validateCallback == LUA_NOREF) {
        return self.enabled ;
    } else {
        LuaSkin   *skin  = [LuaSkin sharedWithState:NULL] ;
        lua_State *L     = skin.L ;
        BOOL      answer = NO ;
        [skin pushLuaRef:refTable ref:self.validateCallback] ;
        [skin pushNSObject:self] ;
        if (![skin protectedCallAndTraceback:1 nresults:1]) {
            [skin logError:[NSString stringWithFormat:@"%s:validateMenuItem error - %s", USERDATA_TAG, lua_tostring(L, -1)]] ;
        } else {
            answer = (BOOL)(lua_toboolean(L, -1)) ;
        }
        lua_pop(L, 1) ;

        return answer ;
    }
}

- (void) itemSelected:(__unused id)sender { [self performCallbackWith:nil] ; }

- (void)performCallbackWith:(NSObject *)data {
    if (self.callbackRef != LUA_NOREF) {
        LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
        lua_State *L    = skin.L ;
        int       count = 1 ;
        [skin pushLuaRef:refTable ref:self.callbackRef] ;
        [skin pushNSObject:self] ;
        if (data) {
            if ([data isKindOfClass:[NSArray class]]) {
                for (NSObject *item in (NSArray *)data) {
                    [skin pushNSObject:item] ;
                    count++ ;
                }
            } else {
                [skin pushNSObject:data] ;
                count++ ;
            }
        }
        if (![skin protectedCallAndTraceback:count nresults:0]) {
            [skin logError:[NSString stringWithFormat:@"%s:callback error - %s", USERDATA_TAG, lua_tostring(L, -1)]] ;
            lua_pop(L, 1) ;
        }
    } else {
        NSMenu *parent = self.menu ;
        SEL passthroughCallback = NSSelectorFromString(@"performPassthroughCallback:") ;
        if ([parent respondsToSelector:passthroughCallback]) {
            NSArray *arguments = nil ;
            if (data) {
                if ([data isKindOfClass:[NSArray class]]) {
                    arguments = [@[ self ] arrayByAddingObjectsFromArray:(NSArray *)data] ;
                } else {
                    arguments = @[ self, data] ;
                }
            } else {
                arguments = @[ self ] ;
            }
            [parent performSelectorOnMainThread:passthroughCallback
                                     withObject:arguments
                                  waitUntilDone:YES] ;
        }
    }
}
@end

#pragma mark - Module Functions -

/// hs._asm.uitk.menu.item.new(title) -> menuItemObject
/// Constructor
/// Create a new menu item with the specified title
///
/// Parameters:
///  * `title` - the title of the new menu item, specified as a string or as an `hs.styledtext` object
///
/// Returns:
///  * a new menuItemObject
static int menuitem_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;

    NSString           *title ;
    NSAttributedString *attributedTitle ;

    if (lua_type(L, 1) == LUA_TUSERDATA) {
        [skin checkArgs:LS_TUSERDATA, "hs.styledtext", LS_TBREAK] ;
        attributedTitle = [skin toNSObjectAtIndex:1] ;
        title = attributedTitle.string ;
    } else {
        [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
        title = [skin toNSObjectAtIndex:1] ;
    }

    NSMenuItem *item = [NSMenuItem newWithTitle:title] ;
    if (item) {
        if (attributedTitle) item.attributedTitle = attributedTitle ;
        [skin pushNSObject:item] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

/// hs._asm.uitk.menu.item:state([state]) -> menuItemObject | string
/// Method
/// Get or set the state to display for the menu item.
///
/// Parameters:
///  * `state` - an optional string, default "off", specifying the state to display for the menu item.
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
///
/// Notes:
///  * the state may be one of the following: "on", "off", "mixed"
///  * the state determines which image is displayed to the left of the menu item in the menu; see [hs._asm.uitk.menu.item:offStateImage](#offStateImage), [hs._asm.uitk.menu.item:onStateImage](#onStateImage), and [hs._asm.uitk.menu.item:mixedStateImage](#mixedStateImage)
///
///  * if the menu the item belongs to has it's `hs._asm.uitk.menu:showsState()` set to false, no image will be displayed, no matter what state is specified.
static int menuitem_state(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        NSNumber *state = @(item.state) ;
        NSArray *temp = [MENU_ITEM_STATES allKeysForObject:state];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized state %@ -- notify developers", USERDATA_TAG, state]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *state = MENU_ITEM_STATES[key] ;
        if (state) {
            item.state = [state integerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [MENU_ITEM_STATES.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:indentLevel([indent]) -> menuItemObject | integer
/// Method
/// Get or set the indent level of the menu item.
///
/// Parameters:
///  * `indent` - an optional integer, default 0, specifying the indent level of the menu item.
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
///
/// Notes:
///  * The minimum indent level is 0 and the maximum is 15; if you specify an integer outside this range, the number will be coerced to whichever endpoint is closest
static int menuitem_indentationLevel(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, item.indentationLevel) ;
    } else {
        NSInteger level = lua_tointeger(L, 2) ;
        item.indentationLevel = (level < 0) ? 0 : ((level > 15) ? 15 : level) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:tooltip([tooltip]) -> menuItemObject | string | nil
/// Method
/// Get or set the tooltip for the menu item.
///
/// Parameters:
///  * `tooltip` - an optional string, or explicit nil to remove, specifying the tooltip to display if the user hovers the mouse over the menu item. Defaults to nil.
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
static int menuitem_toolTip(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.toolTip] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            item.toolTip = nil ;
        } else {
            item.toolTip = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:image([image]) -> menuItemObject | hs.image object | nil
/// Method
/// Get or set the image for the menu item.
///
/// Parameters:
///  * `image` - an optional hs.image object, or explicit nil to remove, specifying the image for the menu item.
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
static int menuitem_image(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,  LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.image] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            item.image = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            item.image = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:mixedStateImage([image]) -> menuItemObject | hs.image object | nil
/// Method
/// Get or set the image used when the menu state is set to mixed for the menu item.
///
/// Parameters:
///  * `image` - an optional hs.image object, or explicit nil to remove, specifying the image to display for the mixed state. Defaults to an image that looks like a dash.
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
///
/// Notes:
///  * see also [hs._asm.uitk.menu.item:state](#state)
static int menuitem_mixedStateImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,  LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.mixedStateImage] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            item.mixedStateImage = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            item.mixedStateImage = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:offStateImage([image]) -> menuItemObject | hs.image object | nil
/// Method
/// Get or set the image used when the menu state is set to off for the menu item.
///
/// Parameters:
///  * `image` - an optional hs.image object, or explicit nil to remove, specifying the image to display for the off state. Defaults to nil.
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
///
/// Notes:
///  * see also [hs._asm.uitk.menu.item:state](#state)
static int menuitem_offStateImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,  LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.offStateImage] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            item.offStateImage = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            item.offStateImage = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:onStateImage([image]) -> menuItemObject | hs.image object | nil
/// Method
/// Get or set the image used when the menu state is set to on for the menu item.
///
/// Parameters:
///  * `image` - an optional hs.image object, or explicit nil to remove, specifying the image to display for the on state. Defaults to an image that looks like a checkmark.
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
///
/// Notes:
///  * see also [hs._asm.uitk.menu.item:state](#state)
static int menuitem_onStateImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,  LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.onStateImage] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            item.onStateImage = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            item.onStateImage = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:title([title | style]) -> menuItemObject | string | hs.styledtext object | nil
/// Method
/// Get or set the menu title
///
/// Parameters:
///  * `title` - an optional string or `hs.styledtext` object specifying the title for the menu item. You cannot specify this argument and `style` at the same time.
///  * `style` - an optional boolean, default false, specifying whether or not the value returned should be as an `hs.styledtext` object (true) or as a string (false). You cannot specify this argument and `title` at the same time.
///
/// Returns:
///  * if the argument is a string or an `hs.styledtext` object, returns the menuItemObject; if no arguments are specified returns a string; otherwise returns an `hs.styledtext` object if `style` is true, or a string if `style` is false. If the title was previously set with a string, and `style` is falseor not specified, may return nil.
///
/// Notes:
///  * if you do not specify an `hs.styledtext` object, the title will inherit the font defined for the menu with `hs._asm.uitk.menu:font` when displayed.
///  * if you wish to clear the style from a previous title that was added as an `hs.styledtext` object, but retain the same text, you can do something like `item:title(item:title(true):getString())`
static int menuitem_title(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushstring(L, "-") ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.title] ;
    } else if (lua_type(L, 2) == LUA_TBOOLEAN) {
        [skin pushNSObject:(lua_toboolean(L, 1) ? item.attributedTitle : item.title)] ;
    } else {
        if (lua_type(L, 2) == LUA_TUSERDATA) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.styledtext", LS_TBREAK] ;
            NSAttributedString *title = [skin toNSObjectAtIndex:2] ;
            item.title = title.string ;
            item.attributedTitle = title ;
        } else if (lua_type(L, 2) == LUA_TNIL) {
            item.attributedTitle = nil ;
            item.title = @"" ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
            item.attributedTitle = nil ;
            item.title = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:hidden([state]) -> menuItemObject | boolean
/// Method
/// Get or set whether the menu item is hidden or not when the menu is displayed
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not the menu item should be hidden
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
static int menuitem_hidden(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, item.hidden) ;
    } else {
        item.hidden = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:element([element]) -> menuItemObject | uitk element | nil
/// Method
/// Get or set the element assigned to the menu item
///
/// Parameters:
///  * `element` - an optional uitk element object, or explicit nil to clear, specifying a uitk element the menu item should display in the menu
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
///
/// Notes:
///  * if you assign an element to the menu item, it will not display its title, state, or other visual attributes defined by these methods.
static int menuitem_view(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        if (item.view && [skin canPushNSObject:item.view]) {
            [skin pushNSObject:item.view] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            if (item.view && [skin canPushNSObject:item.view]) [skin luaRelease:refTable forNSObject:item.view] ;
            item.view = nil ;
        } else {
            NSView *view = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
            if (!(view && oneOfOurElementObjects(view))) {
                return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
            }
            if (item.view && [skin canPushNSObject:item.view]) [skin luaRelease:refTable forNSObject:item.view] ;
            [skin luaRetain:refTable forNSObject:view] ;
            item.view = view ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:submenu([menu | nil]) -> menuItemObject | menuObject | nil
/// Method
/// Get or set the submenu for this menu item
///
/// Parameters:
///  * `menu` - an optional `hs._asm.uitk.menu` object, or explicit nil to remove, specifying the menu to attach as a submenu to this item.
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
///
/// Notes:
///  * you cannot create loops - an error will be generated if you specify the item's menu or a menu that is already a submenu somewhere else.
static int menuitem_submenu(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.submenu] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            if (item.submenu && [skin canPushNSObject:item.submenu]) [skin luaRelease:refTable forNSObject:item.submenu] ;
            item.menu = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs._asm.uitk.menu", LS_TBREAK] ;
            NSMenu *newMenu = [skin toNSObjectAtIndex:2] ;
            if (newMenu.supermenu) {
                return luaL_argerror(L, 2, "menu is already assigned somewhere else") ;
            } else if (item.menu && [item.menu isEqualTo:newMenu]) {
                return luaL_argerror(L, 2, "can't assign the item's menu as a submenu") ;
            }
            if (item.submenu) [skin luaRelease:refTable forNSObject:item.submenu] ;
            [skin luaRetain:refTable forNSObject:newMenu] ;
            item.submenu = newMenu ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:callback([fn | nil]) -> menuItemObject | function | nil
/// Method
/// Get or set the callback function for the menu item
///
/// Parameters:
///  * `fn` - an optional function, or explicit nil to remove, specifying the callback function to be invoked when the user selects this menu item.
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
///
/// Notes:
///  * the callback function should expect one argument (the menu item)
static int menuitem_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 2) {
        item.callbackRef = [skin luaUnref:refTable ref:item.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            item.callbackRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (item.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:item.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:enabled([state | fn]) -> menuItemObject | boolean | function
/// Method
/// Get or set whether or not the menu item is enabled
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether the menu item is enabled or not.
///  * `fn` - an optional function, instead of a boolean, specifying a callback function to be invoked to determine if the item is enabled or not.
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
///
/// Notes:
///  * A disabled item appears greyed out in the menu. See also [hs._asm.uitk.menu.item:hidden](#hidden).
///
///  * you can only specify `state` or `fn`, not both, to determine how the enabled status of the item is determined.
///  * if you specify a callback function, it should expect 1 argument (the menu item) and return a boolean value indicating whether the item should be considered enabled (true) or not (false).
static int menuitem_enabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        if (item.validateCallback == LUA_NOREF) {
            lua_pushboolean(L, item.enabled) ;
        } else {
            [skin pushLuaRef:refTable ref:item.validateCallback] ;
        }
    } else {
        item.validateCallback = [skin luaUnref:refTable ref:item.validateCallback] ;
        if (lua_type(L, 2) == LUA_TBOOLEAN) {
            item.enabled = (BOOL)(lua_toboolean(L, 2)) ;
        } else {
            lua_pushvalue(L, 2) ;
            item.validateCallback = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:tag([tag]) -> menuItemObject | integer
/// Method
/// Get or set the tag associated with this menu item
///
/// Parameters:
///  * `tag` - an optional integer, default 0, specifying a value for the menu item's tag
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
///
/// Notes:
///  * This is for storing your own information only and has no effect on how the menu is represented or treated by the macOS.
static int menuitem_tag(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, item.tag) ;
    } else {
        item.tag = lua_tointeger(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:id([identifier | nil]) -> menuItemObject | string | nil
/// Method
/// Get or set the id associated with this menu item
///
/// Parameters:
///  * `identifier` - an optional string, or explicit nil to clear, specifying an identifier for this menu item
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
///
/// Notes:
///  * This is for storing your own information only and has no effect on how the menu is represented or treated by the macOS.
///  * The metamethods of this module and `hs._asm.uitk.menu` use this identifier as an optional way to refer to a specific menu item without knowing their index value; if you do use these metamethods, it is recommended that each item have a unique identifier as otherwise, referring to an item by it's id will only affect the first item with that identifier.
static int menuitem_representedObject(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.representedObject] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            item.representedObject = nil ;
        } else {
            item.representedObject = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:allowedWhenHidden([state]) -> menuItemObject | boolean
/// Method
/// Get or set whether the menu item can be triggered by its key equivalent when hidden
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not the menu item can be triggered by its key equivalent when it is hidden
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
///
/// Notes:
///  * see also [hs._asm.uitk.menu.item:hidden](#hidden)
static int menuitem_allowsKeyEquivalentWhenHidden(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, item.allowsKeyEquivalentWhenHidden) ;
    } else {
        item.allowsKeyEquivalentWhenHidden = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:alternate([state]) -> menuItemObject | boolean
/// Method
/// Get or set whether the menu item is an alternate to the nearest non-alternate menu item that precedes it
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not this item is an alternate to the nearest non-alternate menu item that precedes it
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
///
/// Notes:
///  * Alternate items specify menu items that should replace another item when different keyboard modifiers are pressed. The alternate items must appear sequentially and have identical key assignments, but different keyboard modifiers. See [hs._asm.uitk.menu.item:keyEquivalent](#keyEquivalent) and [hs._asm.uitk.menu.item:keyModifiers](#keyModifiers.
///  * When an item is marked as an alternate but its key equivalent doesn't match its predecessor, the result is undefined -- it may be displayed, or it may not.
static int menuitem_alternate(lua_State *L) {
// see https://stackoverflow.com/questions/33764644/option-context-menu-in-cocoa
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, item.alternate) ;
    } else {
        item.alternate = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:keyEquivalent([key]) -> menuItemObject | string
/// Method
/// Get or set the key equivalent for the menu item
///
/// Parameters:
///  * `key` - an optional string, or explicit nil to remove`, the key equivalent for the menu item
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
///
/// Notes:
///  * if you provide a string that is more than one character long, only the first character is used
///  * see also [hs._asm.uitk.menu.item:keyModifiers](#keyModifiers)
///  * see [hs._asm.uitk.menu.item._characterMap](#_characterMap) for specific values to use for some of the special keys found on the macOS keyboard.
///
///  * some key equivalent and modifier combinations do not seem to work, even when the menu is being presented and has key focus; this is being investigated and the documentation should evolve as my understanding of how and when these are checked for progress.
static int menuitem_keyEquivalent(lua_State *L) {
// do mapping to special characters in lua
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.keyEquivalent] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            item.keyEquivalent = @"" ;
        } else {
            item.keyEquivalent = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:keyModifiers([modifiers]) -> menuItemObject | table
/// Method
/// Get or set the key modifiers used with the key equivalent assigned for this menu item
///
/// Parameters:
///  * `modifiers` - an optional table of key-value pairs specifying the key modifiers for this menu item and its key equivalent.
///
/// Returns:
///  * if an argument is provided, returns the menuItemObject; otherwise returns the current value
///
/// Notes:
///  * `modifiers` is a key-value table with zero or more of the following keys set to true: "cmd", "alt", "ctrl", and "shift"
///  * the default value is `{ cmd = true }` indicating that only the command key modifier is combined with the key equivalent to trigger this menu item
///
///  * you can use this method to differentiate alternate menu items even when the value of [hs._asm.uitk.menu.item:keyEquivalent](#keyEquivalent) is not specified -- see [hs._asm.uitk.menu.item:alternate](#alternate) for more information
///
///  * some key equivalent and modifier combinations do not seem to work, even when the menu is being presented and has key focus; this is being investigated and the documentation should evolve as my understanding of how and when these are checked for progress.
static int menuitem_keyEquivalentModifierMask(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

//     if (item.separatorItem) {
//         if (lua_gettop(L) == 1) {
//             lua_pushnil(L) ;
//         } else {
//             lua_pushvalue(L, 1) ;
//         }
//         return 1 ;
//     }

    if (lua_gettop(L) == 1) {
        NSEventModifierFlags flags = item.keyEquivalentModifierMask ;
        lua_newtable(L) ;
        if ((flags & NSEventModifierFlagShift) == NSEventModifierFlagShift) {
            lua_pushboolean(L, YES) ; lua_setfield(L, -2, "shift") ;
        }
        if ((flags & NSEventModifierFlagControl) == NSEventModifierFlagControl) {
            lua_pushboolean(L, YES) ; lua_setfield(L, -2, "ctrl") ;
        }
        if ((flags & NSEventModifierFlagOption) == NSEventModifierFlagOption) {
            lua_pushboolean(L, YES) ; lua_setfield(L, -2, "alt") ;
        }
        if ((flags & NSEventModifierFlagCommand) == NSEventModifierFlagCommand) {
            lua_pushboolean(L, YES) ; lua_setfield(L, -2, "cmd") ;
        }
//         if ((flags & NSEventModifierFlagFunction) == NSEventModifierFlagFunction) {
//             lua_pushboolean(L, YES) ; lua_setfield(L, -2, "fn") ;
//         }
    } else {
        NSEventModifierFlags flags = 0 ; //(NSEventModifierFlags)0 ;
        if ((lua_getfield(L, 2, "shift") != LUA_TNIL) && lua_toboolean(L, -1)) flags |= NSEventModifierFlagShift ;
        if ((lua_getfield(L, 2, "ctrl")  != LUA_TNIL) && lua_toboolean(L, -1)) flags |= NSEventModifierFlagControl ;
        if ((lua_getfield(L, 2, "alt")   != LUA_TNIL) && lua_toboolean(L, -1)) flags |= NSEventModifierFlagOption ;
        if ((lua_getfield(L, 2, "cmd")   != LUA_TNIL) && lua_toboolean(L, -1)) flags |= NSEventModifierFlagCommand ;
//         if ((lua_getfield(L, 2, "fn")    != LUA_TNIL) && lua_toboolean(L, -1)) flags |= NSEventModifierFlagFunction ;
        item.keyEquivalentModifierMask = flags ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:menu() -> menuObject | nil
/// Method
/// Get the menu the item has been assigned to
///
/// Parameters:
///  * None
///
/// Returns:
///  * the menuObject this item belongs to, or nil if it is not currently assigned to a menu
static int menuitem_menu(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    if (item.menu) {
        [skin pushNSObject:item.menu] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.item:parentItem() -> menuItemObject | nil
/// Method
/// Get the menu whose submenu contains this item
///
/// Parameters:
///  * None
///
/// Returns:
///  * the menuItemObject for the item whose submenu contains this item, or nil if this item is not in a submenu
static int menuitem_parentItem(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    if (item.parentItem) {
        [skin pushNSObject:item.parentItem] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.menu.isHidden:parentItem() -> boolean
/// Method
/// Get whether or not this item is hidden or has a hidden ancestor
///
/// Parameters:
///  * None
///
/// Returns:
///  * true if this item is hidden -- see [hs._asm.uitk.menu.item:hidden](#hidden) -- or has a hidden ancestor (i.e. is in a submenu of a hidden item, however many layers deep that may be). Otherwise returns false.
static int menuitem_hiddenOrHasHiddenAncestor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, item.hiddenOrHasHiddenAncestor) ;
    return 1 ;
}

/// hs._asm.uitk.menu.isHidden:isHighlighted() -> boolean
/// Method
/// Get whether or not this item is currently highlighted in the menu
///
/// Parameters:
///  * None
///
/// Returns:
///  * true if the item is currently highlighted in its menu; otherwise false
static int menuitem_highlighted(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, item.highlighted) ;
    return 1 ;
}

#pragma mark - Module Constants -

/// hs._asm.uitk.menu.item._characterMap[]
/// Constant
/// A table containing the key equivalent values to use for the special (i.e. non alpha-numeric) keys on your keyboard.
///
/// This table is a key-value table where the key refers to a human readable label while the value contains the "key" that should be supplied to the [hs._asm.uitk.menu.item:keyEquivalent](#keyEquivalent) method. This table currently contains values for the following:
///
///  * the function keys `f1` through `f20`
///  * the arrow keys `left`, `right`, `up`, and `down`
///  * `home` and `end`
///  * `help`
///  * `fn`
///  * `enter`
///  * `tab`
///  * `return`
///  * `escape`
///  * `space`
///  * `delete`
///
/// Some of the key equivalents don't seem to be triggering the corresponding menu item when they are assigned, even when the menu is presented and has key focus. This is being investigated and the table may change over time as this is refined. In the mean time, if you find that a menu item isn't being triggered by its key equivalent even when the menu is being presented, you may have better luck setting up a hotkey with `hs.hotkey` and thinking of the key equivalents here as more of a visual reminder.

static int pushSpecialCharacters(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
    unichar c ;

    c = NSF1FunctionKey           ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f1") ;
    c = NSF2FunctionKey           ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f2") ;
    c = NSF3FunctionKey           ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f3") ;
    c = NSF4FunctionKey           ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f4") ;
    c = NSF5FunctionKey           ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f5") ;
    c = NSF6FunctionKey           ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f6") ;
    c = NSF7FunctionKey           ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f7") ;
    c = NSF8FunctionKey           ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f8") ;
    c = NSF9FunctionKey           ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f9") ;
    c = NSF10FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f10") ;
    c = NSF11FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f11") ;
    c = NSF12FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f12") ;
    c = NSF13FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f13") ;
    c = NSF14FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f14") ;
    c = NSF15FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f15") ;
    c = NSF16FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f16") ;
    c = NSF17FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f17") ;
    c = NSF18FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f18") ;
    c = NSF19FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f19") ;
    c = NSF20FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f20") ;

    c = NSHomeFunctionKey         ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "home") ;
    c = NSEndFunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "end") ;
    c = NSHelpFunctionKey         ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "help") ;
    c = NSModeSwitchFunctionKey   ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "fn") ;

    c = NSEnterCharacter          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "enter") ;
    c = NSTabCharacter            ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "tab") ;
    c = NSCarriageReturnCharacter ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "return") ;

    c = kEscapeCharCode           ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "escape") ;
    c = kSpaceCharCode            ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "space") ;

    c = 0x232B ;                  ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "delete") ;

// FIXME: see following comments:

// wrong glyph
    c = NSUpArrowFunctionKey      ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "up") ;     // should be thinner
    c = NSDownArrowFunctionKey    ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "down") ;   // should be thinner
    c = NSLeftArrowFunctionKey    ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "left") ;   // should be thinner
    c = NSRightArrowFunctionKey   ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "right") ;  // should be thinner

// Renders in menu as unicode unknown char glyph
//     c = NSBeginFunctionKey        ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "begin") ;
//     c = NSBreakFunctionKey        ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "break") ;
//     c = NSExecuteFunctionKey      ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "execute") ;
//     c = NSF21FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f21") ;
//     c = NSF22FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f22") ;
//     c = NSF23FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f23") ;
//     c = NSF24FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f24") ;
//     c = NSF25FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f25") ;
//     c = NSF26FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f26") ;
//     c = NSF27FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f27") ;
//     c = NSF28FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f28") ;
//     c = NSF29FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f29") ;
//     c = NSF30FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f30") ;
//     c = NSF31FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f31") ;
//     c = NSF32FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f32") ;
//     c = NSF33FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f33") ;
//     c = NSF34FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f34") ;
//     c = NSF35FunctionKey          ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "f35") ;
//     c = NSFindFunctionKey         ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "find") ;
//     c = NSInsertFunctionKey       ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "insert") ;
//     c = NSMenuFunctionKey         ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "menu") ;
//     c = NSNextFunctionKey         ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "next") ;
//     c = NSPauseFunctionKey        ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "pause") ;
//     c = NSPrintFunctionKey        ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "print") ;
//     c = NSPrevFunctionKey         ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "prev") ;
//     c = NSRedoFunctionKey         ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "redo") ;
//     c = NSResetFunctionKey        ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "reset") ;
//     c = NSSelectFunctionKey       ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "select") ;
//     c = NSStopFunctionKey         ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "stop") ;
//     c = NSUserFunctionKey         ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "user") ;
//     c = NSSystemFunctionKey       ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "system") ;
//     c = NSUndoFunctionKey         ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "undo") ;

// Renders in menu as first letter of item title...
//     c = NSBackspaceCharacter      ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "backSpace") ;       // B
//     c = NSBackTabCharacter        ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "backTab") ;         // B
//     c = NSClearLineFunctionKey    ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "clearLine") ;       // C
//     c = NSDeleteCharFunctionKey   ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "deleteChar") ;      // D
//     c = NSDeleteCharacter         ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "deleteCharacter") ; // D
//     c = NSDeleteLineFunctionKey   ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "deleteLine") ;      // D
//     c = NSInsertLineFunctionKey   ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "insertLine") ;      // I
//     c = NSInsertCharFunctionKey   ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "insertChar") ;      // I
//     c = NSPageUpFunctionKey       ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "pageUp") ;          // P
//     c = NSPageDownFunctionKey     ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "pageDown") ;        // P
//     c = NSClearDisplayFunctionKey ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "padClear") ;        // P
//     c = NSPrintScreenFunctionKey  ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "printScreen") ;     // P
//     c = NSScrollLockFunctionKey   ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "scrollLock") ;      // S
//     c = NSSysReqFunctionKey       ; [skin pushNSObject:[NSString stringWithCharacters:&c length:1]] ; lua_setfield(L, -2, "sysReq") ;          // S

    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushNSMenuItem(lua_State *L, id obj) {
    NSMenuItem *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(NSMenuItem *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toNSMenuItem(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSMenuItem *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge NSMenuItem, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSMenuItem *obj = [skin luaObjectAtIndex:1 toClass:"NSMenuItem"] ;
    NSString *title = obj.title ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        NSMenuItem *obj1 = [skin luaObjectAtIndex:1 toClass:"NSMenuItem"] ;
        NSMenuItem *obj2 = [skin luaObjectAtIndex:2 toClass:"NSMenuItem"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    NSMenuItem *obj = get_objectFromUserdata(__bridge_transfer NSMenuItem, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef      = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj.validateCallback = [skin luaUnref:refTable ref:obj.validateCallback] ;
            if (obj.view) {
                if ([skin canPushNSObject:obj.view]) [skin luaRelease:refTable forNSObject:obj.view] ;
                obj.view = nil ;
            }
            if (obj.submenu) {
                if ([skin canPushNSObject:obj.submenu]) [skin luaRelease:refTable forNSObject:obj.submenu] ;
                obj.submenu = nil ;
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
    {"state",             menuitem_state},
    {"indentLevel",       menuitem_indentationLevel},
    {"tooltip",           menuitem_toolTip},
    {"image",             menuitem_image},
    {"mixedStateImage",   menuitem_mixedStateImage},
    {"offStateImage",     menuitem_offStateImage},
    {"onStateImage",      menuitem_onStateImage},
    {"title",             menuitem_title},
    {"enabled",           menuitem_enabled},
    {"hidden",            menuitem_hidden},
    {"element",           menuitem_view},
    {"submenu",           menuitem_submenu},
    {"callback",          menuitem_callback},
    {"tag",               menuitem_tag},
    {"id",                menuitem_representedObject},
    {"allowedWhenHidden", menuitem_allowsKeyEquivalentWhenHidden},
    {"alternate",         menuitem_alternate},
    {"keyEquivalent",     menuitem_keyEquivalent},
    {"keyModifiers",      menuitem_keyEquivalentModifierMask},

    {"menu",              menuitem_menu},
    {"parentItem",        menuitem_parentItem},
    {"isHidden",          menuitem_hiddenOrHasHiddenAncestor},
    {"isHighlighted",     menuitem_highlighted},

    {"__tostring",        userdata_tostring},
    {"__eq",              userdata_eq},
    {"__gc",              userdata_gc},
    {NULL,                NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", menuitem_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_libmenu_item(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushNSMenuItem  forClass:"NSMenuItem"];
    [skin registerLuaObjectHelper:toNSMenuItem forClass:"NSMenuItem"
                                    withUserdataMapping:USERDATA_TAG];

    pushSpecialCharacters(L) ; lua_setfield(L, -2, "_characterMap") ;

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"state",
        @"indentLevel",
        @"tooltip",
        @"image",
        @"mixedStateImage",
        @"offStateImage",
        @"onStateImage",
        @"title",
        @"enabled",
        @"hidden",
        @"element",
        @"submenu",
        @"callback",
        @"tag",
        @"id",
        @"alternate",
        @"keyEquivalent",
        @"keyModifiers",
        @"allowedWhenHidden",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
