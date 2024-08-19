// Uses associated objects to "add" callback and selfRef -- this is done instead of
// subclassing so we don't have to add special code in menu.m to deal with regular
// menu items and separator items; forcing an NSMenuItem for a separator into an
// HSUITKMenuItem object seems... disingenuous at best.

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

- (void) itemSelected:(__unused id)sender { [self performCallbackMessage:@"select" with:nil] ; }

- (void)performCallbackMessage:(NSString *)message with:(id)data {
    if (self.callbackRef != LUA_NOREF) {
        LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
        lua_State *L    = skin.L ;
        int       count = 2 ;
        [skin pushLuaRef:refTable ref:self.callbackRef] ;
        [skin pushNSObject:self] ;
        [skin pushNSObject:message] ;
        if (data) {
            count++ ;
            [skin pushNSObject:data] ;
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
                arguments = @[ self, message, data] ;
            } else {
                arguments = @[ self, message ] ;
            }
            [parent performSelectorOnMainThread:passthroughCallback
                                     withObject:arguments
                                  waitUntilDone:YES] ;
        }
    }
}
@end

#pragma mark - Module Functions -

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
    } else if (lua_type(L, 1) == LUA_TBOOLEAN) {
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
//             if (!view || ![view isKindOfClass:[NSView class]]) {
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
            }
            if (item.submenu && [skin canPushNSObject:item.submenu]) [skin luaRelease:refTable forNSObject:item.submenu] ;
            [skin luaRetain:refTable forNSObject:newMenu] ;
            item.submenu = newMenu ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

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

// see https://stackoverflow.com/questions/33764644/option-context-menu-in-cocoa
static int menuitem_alternate(lua_State *L) {
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
        if ((flags & NSEventModifierFlagFunction) == NSEventModifierFlagFunction) {
            lua_pushboolean(L, YES) ; lua_setfield(L, -2, "fn") ;
        }
    } else {
        NSEventModifierFlags flags = 0 ; //(NSEventModifierFlags)0 ;
        if ((lua_getfield(L, 2, "shift") != LUA_TNIL) && lua_toboolean(L, -1)) flags |= NSEventModifierFlagShift ;
        if ((lua_getfield(L, 2, "ctrl")  != LUA_TNIL) && lua_toboolean(L, -1)) flags |= NSEventModifierFlagControl ;
        if ((lua_getfield(L, 2, "alt")   != LUA_TNIL) && lua_toboolean(L, -1)) flags |= NSEventModifierFlagOption ;
        if ((lua_getfield(L, 2, "cmd")   != LUA_TNIL) && lua_toboolean(L, -1)) flags |= NSEventModifierFlagCommand ;
        if ((lua_getfield(L, 2, "fn")    != LUA_TNIL) && lua_toboolean(L, -1)) flags |= NSEventModifierFlagFunction ;
        item.keyEquivalentModifierMask = flags ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

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

static int menuitem_hiddenOrHasHiddenAncestor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, item.hiddenOrHasHiddenAncestor) ;
    return 1 ;
}

static int menuitem_highlighted(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSMenuItem *item = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, item.highlighted) ;
    return 1 ;
}

#pragma mark - Module Constants -

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

// unicode unknown char glyph
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

// Render in menu as first letter of item title...
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
    {"state",            menuitem_state},
    {"indentationLevel", menuitem_indentationLevel},
    {"tooltip",          menuitem_toolTip},
    {"image",            menuitem_image},
    {"mixedStateImage",  menuitem_mixedStateImage},
    {"offStateImage",    menuitem_offStateImage},
    {"onStateImage",     menuitem_onStateImage},
    {"title",            menuitem_title},
    {"enabled",          menuitem_enabled},
    {"hidden",           menuitem_hidden},
    {"element",          menuitem_view},
    {"submenu",          menuitem_submenu},
    {"callback",         menuitem_callback},
    {"tag",              menuitem_tag},
    {"id",               menuitem_representedObject},
    {"keyWhenHidden",    menuitem_allowsKeyEquivalentWhenHidden},
    {"alternate",        menuitem_alternate},
    {"keyEquivalent",    menuitem_keyEquivalent},
    {"keyModifiers",     menuitem_keyEquivalentModifierMask},

    {"menu",             menuitem_menu},
    {"parentItem",       menuitem_parentItem},
    {"isHidden",         menuitem_hiddenOrHasHiddenAncestor},
    {"highlighted",      menuitem_highlighted},

    {"__tostring",       userdata_tostring},
    {"__eq",             userdata_eq},
    {"__gc",             userdata_gc},
    {NULL,               NULL}
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
        @"indentationLevel",
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
        @"keyWhenHidden",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
