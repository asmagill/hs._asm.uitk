@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.menubar" ;
static LSRefTable         refTable     = LUA_NOREF ;

static void *myKVOContext = &myKVOContext ; // See http://nshipster.com/key-value-observing/

static NSDictionary *IMAGE_POSITIONS ;
static NSDictionary *IMAGE_SCALING_TYPES ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    IMAGE_SCALING_TYPES = @{
        @"proportionallyDown"     : @(NSImageScaleProportionallyDown),
        @"axesIndependently"      : @(NSImageScaleAxesIndependently),
        @"none"                   : @(NSImageScaleNone),
        @"proportionallyUpOrDown" : @(NSImageScaleProportionallyUpOrDown),
    } ;

    IMAGE_POSITIONS = @{
        @"none"     : @(NSNoImage),
        @"only"     : @(NSImageOnly),
        @"left"     : @(NSImageLeft),
        @"right"    : @(NSImageRight),
        @"below"    : @(NSImageBelow),
        @"above"    : @(NSImageAbove),
        @"overlaps" : @(NSImageOverlaps),
        @"leading"  : @(NSImageLeading),
        @"trailing" : @(NSImageTrailing),
    } ;
}

static inline NSRect RectWithFlippedYCoordinate(NSRect theRect) {
    return NSMakeRect(theRect.origin.x,
                      [[NSScreen screens][0] frame].size.height - theRect.origin.y - theRect.size.height,
                      theRect.size.width,
                      theRect.size.height) ;
}

// https://stackoverflow.com/a/24659795
static NSRect statusItemFrame(NSStatusItem *item) {
    NSStatusBarButton *statusBarButton = item.button ;
    NSRect rectInWindow = [statusBarButton convertRect:statusBarButton.bounds toView:nil] ;
    NSRect screenRect   = [statusBarButton.window convertRectToScreen:rectInWindow] ;
    return RectWithFlippedYCoordinate(screenRect) ;
}

@interface HSStatusItemWrapper : NSObject <NSDraggingDestination, NSWindowDelegate>
@property NSStatusItem *item ;
@property int          selfRefCount ;
@property int          callbackRef ;
@property int          draggingCallbackRef ;
@property BOOL         trackingVisibility ;
@property BOOL         lastVisibility ;
@property BOOL         installed ;
@end

@implementation HSStatusItemWrapper
- (instancetype)initWithLength:(CGFloat)length withState:(lua_State *)L {
    self = [super init] ;
    if (self) {
        _item = [[NSStatusBar systemStatusBar] statusItemWithLength:length] ;
        if (_item) {
            _selfRefCount             = 0 ;
            _callbackRef              = LUA_NOREF ;
            _draggingCallbackRef      = LUA_NOREF ;
            _trackingVisibility       = NO ;
            _installed                = YES ;

            _item.button.target       = self ;
            _item.button.action       = @selector(singleCallback:) ;

            // For drag-and-drop
            _item.button.window.delegate = self ;

            // clearing the autosaveName "resets" it to the automatically generated one and supposedly
            // clears the default saved; however sometimes it slips through and a previously removed
            // menu won't show up even after we restart
            _item.visible      = YES ;
            _item.autosaveName = nil ;
            // see observeValueForKeyPath:ofObject:change:context: below
            _lastVisibility           = _item.visible ;
            [_item addObserver:self forKeyPath:@"visible"
                                       options:NSKeyValueObservingOptionNew
                                       context:myKVOContext] ;

            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            [skin luaRetain:refTable forNSObject:self] ;
        } else {
            self = nil ;
        }
    }
    return self ;
}

- (void)singleCallback:(__unused id)sender {
    [self performCallbackMessage:@"mouseClick" with:nil] ;
}

- (void)performCallbackMessage:(NSString *)message with:(id)data {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
        lua_State *L    = skin.L ;
        int       count = 2 ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
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
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == myKVOContext) {
        if ([keyPath isEqualToString:@"visible"] && _trackingVisibility) {
            NSStatusItem *item = object ;
            // gets triggered twice for some reason, not sure why
            if (_lastVisibility != item.visible) {
                [self performCallbackMessage:@"visibilityChange" with:nil] ;
                _lastVisibility = item.visible ;
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context] ;
    }
}

#pragma mark NSDraggingDestination protocol methods

- (BOOL)draggingCallback:(NSString *)message with:(id<NSDraggingInfo>)sender {
    BOOL isAllGood = NO ;
    if (_draggingCallbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        lua_State *L = skin.L ;
        int argCount = 2 ;
        [skin pushLuaRef:refTable ref:_draggingCallbackRef] ;
        [skin pushNSObject:self] ;
        [skin pushNSObject:message] ;
        if (sender) {
            lua_newtable(L) ;
            NSPasteboard *pasteboard = [sender draggingPasteboard] ;
            if (pasteboard) {
                [skin pushNSObject:pasteboard.name] ; lua_setfield(L, -2, "pasteboard") ;
            }
            lua_pushinteger(L, [sender draggingSequenceNumber]) ; lua_setfield(L, -2, "sequence") ;
            [skin pushNSPoint:[sender draggingLocation]] ; lua_setfield(L, -2, "mouse") ;
            NSDragOperation operation = [sender draggingSourceOperationMask] ;
            lua_newtable(L) ;
            if (operation == NSDragOperationNone) {
                lua_pushstring(L, "none") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
            } else {
                if ((operation & NSDragOperationCopy) == NSDragOperationCopy) {
                    lua_pushstring(L, "copy") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationLink) == NSDragOperationLink) {
                    lua_pushstring(L, "link") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationGeneric) == NSDragOperationGeneric) {
                    lua_pushstring(L, "generic") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationPrivate) == NSDragOperationPrivate) {
                    lua_pushstring(L, "private") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationMove) == NSDragOperationMove) {
                    lua_pushstring(L, "move") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationDelete) == NSDragOperationDelete) {
                    lua_pushstring(L, "delete") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
            }
            lua_setfield(L, -2, "operation") ;
            argCount += 1 ;
        }
        if ([skin protectedCallAndTraceback:argCount nresults:1]) {
            isAllGood = lua_isnoneornil(L, -1) ? YES : (BOOL)(lua_toboolean(skin.L, -1)) ;
        } else {
            [skin logError:[NSString stringWithFormat:@"%s:draggingCallback error: %@", USERDATA_TAG, [skin toNSObjectAtIndex:-1]]] ;
        }
        lua_pop(L, 1) ;
    }
    return isAllGood ;
}

- (BOOL)wantsPeriodicDraggingUpdates {
    return NO ;
}

- (BOOL)prepareForDragOperation:(__unused id<NSDraggingInfo>)sender {
    return YES ;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    return [self draggingCallback:@"enter" with:sender] ? NSDragOperationGeneric : NSDragOperationNone ;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
    [self draggingCallback:@"exit" with:sender] ;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    return [self draggingCallback:@"receive" with:sender] ;
}

// - (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender ;
// - (void)concludeDragOperation:(id<NSDraggingInfo>)sender ;
// - (void)draggingEnded:(id<NSDraggingInfo>)sender ;
// - (void)updateDraggingItemsForDrag:(id<NSDraggingInfo>)sender

@end

#pragma mark - Module Functions -

static int menubar_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    CGFloat length = NSVariableStatusItemLength ;
    if (lua_gettop(L) == 1) {
        if (lua_type(L, 1) == LUA_TBOOLEAN) {
            length = lua_toboolean(L, 1) ? NSVariableStatusItemLength : NSSquareStatusItemLength ;
        } else {
            length = fmax(0, lua_tonumber(L, 1)) ;
        }
    }
    HSStatusItemWrapper *wrapper = [[HSStatusItemWrapper alloc] initWithLength:length withState:L] ;
    if (wrapper) {
        [skin pushNSObject:wrapper] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

// only affects HS and then only when "Show in Dock" is true; also show/hides Dock, again only in HS
// static int menubar_isVisible(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
//
//     if (lua_gettop(L) == 1) {
//         NSMenu.menuBarVisible = (BOOL)(lua_toboolean(L, 1)) ;
//     }
//
//     lua_pushboolean(L, NSMenu.menuBarVisible) ;
//     return 1 ;
// }

#pragma mark - Module Methods -

static int menubar_length(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;

    if (lua_gettop(L) == 1) {
        CGFloat length = item.length ;
        if (length < 0) {
            lua_pushboolean(L, length > NSSquareStatusItemLength) ;
        } else {
            lua_pushnumber(L, length) ;
        }
    } else {
        if (lua_type(L, 2) == LUA_TBOOLEAN) {
            item.length = lua_toboolean(L, 2) ? NSVariableStatusItemLength : NSSquareStatusItemLength ;
        } else {
            item.length = fmax(0, lua_tonumber(L, 2)) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menubar_frame(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;
    [skin pushNSRect:statusItemFrame(item)] ;
    return 1 ;
}

static int menubar_menu(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.menu] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            if (item.menu && [skin canPushNSObject:item.menu]) [skin luaRelease:refTable forNSObject:item.menu] ;
            item.menu = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs._asm.uitk.menu", LS_TBREAK] ;
            if (item.menu && [skin canPushNSObject:item.menu]) [skin luaRelease:refTable forNSObject:item.menu] ;
            item.menu = [skin toNSObjectAtIndex:2] ;
            [skin luaRetain:refTable forNSObject:item.menu] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menubar_title(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;
    NSStatusBarButton   *button = item.button ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:button.title] ;
    } else if (lua_type(L, 1) == LUA_TBOOLEAN) {
        [skin pushNSObject:(lua_toboolean(L, 1) ? button.attributedTitle : button.title)] ;
    } else {
        if (lua_type(L, 2) == LUA_TUSERDATA) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.styledtext", LS_TBREAK] ;
            button.attributedTitle = [skin toNSObjectAtIndex:2] ;
        } else if (lua_type(L, 2) == LUA_TNIL) {
            button.title = @"" ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
            button.title = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menubar_image(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,  LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;
    NSStatusBarButton   *button = item.button ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:button.image] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            button.image = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            button.image = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menubar_alternateTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;
    NSStatusBarButton   *button = item.button ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:button.alternateTitle] ;
    } else if (lua_type(L, 1) == LUA_TBOOLEAN) {
        [skin pushNSObject:(lua_toboolean(L, 1) ? button.attributedAlternateTitle : button.alternateTitle)] ;
    } else {
        if (lua_type(L, 2) == LUA_TUSERDATA) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.styledtext", LS_TBREAK] ;
            button.attributedAlternateTitle = [skin toNSObjectAtIndex:2] ;
        } else if (lua_type(L, 2) == LUA_TNIL) {
                button.alternateTitle = @"" ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
            button.alternateTitle = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menubar_alternateImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,  LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;
    NSStatusBarButton   *button = item.button ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:button.alternateImage] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            button.alternateImage = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            button.alternateImage = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menubar_sound(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;
    NSStatusBarButton   *button = item.button ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:button.sound] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            button.sound = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.sound", LS_TBREAK] ;
            button.sound = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menubar_imagePosition(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;
    NSStatusBarButton   *button = item.button ;

    if (lua_gettop(L) == 1) {
        NSNumber *imagePosition = @(button.imagePosition) ;
        NSArray *temp = [IMAGE_POSITIONS allKeysForObject:imagePosition];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized image position %@ -- notify developers", USERDATA_TAG, imagePosition]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *imagePosition = IMAGE_POSITIONS[key] ;
        if (imagePosition) {
            button.imagePosition = [imagePosition unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [IMAGE_POSITIONS.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int menubar_imageScaling(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;
    NSStatusBarButton   *button = item.button ;

    if (lua_gettop(L) == 1) {
        NSNumber *imageScaling = @(button.imageScaling) ;
        NSArray *temp = [IMAGE_SCALING_TYPES allKeysForObject:imageScaling];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized image scaling %@ -- notify developers", USERDATA_TAG, imageScaling]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *imageScaling = IMAGE_SCALING_TYPES[key] ;
        if (imageScaling) {
            button.imageScaling = [imageScaling unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [IMAGE_SCALING_TYPES.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int menubar_appearsDisabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;
    NSStatusBarButton   *button = item.button ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, button.appearsDisabled) ;
    } else {
        button.appearsDisabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menubar_visible(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, item.visible) ;
    } else {
        item.visible = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menubar_allowRemoval(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, (item.behavior & NSStatusItemBehaviorRemovalAllowed) == NSStatusItemBehaviorRemovalAllowed) ;
    } else {
        wrapper.trackingVisibility = (BOOL)(lua_toboolean(L, 2)) ;
        if (wrapper.trackingVisibility) {
            item.behavior = item.behavior | NSStatusItemBehaviorRemovalAllowed ;
        } else {
            item.behavior = item.behavior & ~NSStatusItemBehaviorRemovalAllowed ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menubar_enabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;
    NSStatusBarButton   *button = item.button ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, button.enabled) ;
    } else {
        button.enabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menubar_toolTip(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;
    NSStatusBarButton   *button = item.button ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:button.toolTip] ;
    } else {
        if (lua_type(L, 2) != LUA_TSTRING) {
            button.toolTip = nil ;
        } else {
            button.toolTip = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menubar_autosaveName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;
//     NSStatusBarButton   *button = item.button ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.autosaveName] ;
    } else {
        if (lua_type(L, 2) != LUA_TSTRING) {
            item.autosaveName = nil ;
        } else {
            item.autosaveName = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menubar_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        wrapper.callbackRef = [skin luaUnref:refTable ref:wrapper.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            wrapper.callbackRef = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (wrapper.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:wrapper.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int menubar_draggingCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        // We're either removing callback(s), or setting new one(s). Either way, remove existing.
        wrapper.draggingCallbackRef = [skin luaUnref:refTable ref:wrapper.draggingCallbackRef];
        [wrapper.item.button.window unregisterDraggedTypes] ;
        if ([skin luaTypeAtIndex:2] != LUA_TNIL) {
            lua_pushvalue(L, 2);
            wrapper.draggingCallbackRef = [skin luaRef:refTable] ;
            [wrapper.item.button.window registerForDraggedTypes:@[ (__bridge NSString *)kUTTypeItem ]] ;
        }
        lua_pushvalue(L, 1);
    } else {
        if (wrapper.draggingCallbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:wrapper.draggingCallbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }

    return 1;
}

// NOTE: really more of a removeFromMenubar -- delete occurs when __gc does...
//       need to add "stillValid" or similar so remaining existant userdata can know
//       when this has been called. Menu won't be released till final userdata is
//       collected, but NSObject still exists anyway and other methods will still
//       return/change info even if it has no visible effect.
static int menubar_delete(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;

    if (wrapper.installed) {
        [skin luaRelease:refTable forNSObject:wrapper.item] ;
        [[NSStatusBar systemStatusBar] removeStatusItem:wrapper.item] ;
        wrapper.installed = NO ;
    }

    lua_pushnil(L);
    return 1;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSStatusItemWrapper(lua_State *L, id obj) {
    HSStatusItemWrapper *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSStatusItemWrapper *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSStatusItemWrapper(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSStatusItemWrapper *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSStatusItemWrapper, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSStatusItemWrapper *obj = [skin luaObjectAtIndex:1 toClass:"HSStatusItemWrapper"] ;
    NSString *title = NSStringFromRect(statusItemFrame(obj.item)) ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSStatusItemWrapper *obj1 = [skin luaObjectAtIndex:1 toClass:"HSStatusItemWrapper"] ;
        HSStatusItemWrapper *obj2 = [skin luaObjectAtIndex:2 toClass:"HSStatusItemWrapper"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSStatusItemWrapper *obj = get_objectFromUserdata(__bridge_transfer HSStatusItemWrapper, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef         = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj.draggingCallbackRef = [skin luaUnref:refTable ref:obj.draggingCallbackRef];

            obj.trackingVisibility = NO ;
            [obj.item removeObserver:obj forKeyPath:@"visible" context:myKVOContext] ;

            // in case __gc from reload
            if (obj.installed) {
                [skin luaRelease:refTable forNSObject:obj.item] ;
                [[NSStatusBar systemStatusBar] removeStatusItem:obj.item] ;
                obj.installed = NO ;
            }

            if (obj.item.menu) {
                if ([skin canPushNSObject:obj.item.menu]) [skin luaRelease:refTable forNSObject:obj.item.menu] ;
                obj.item.menu = nil ;
            }

            obj.item      = nil ;
            obj           = nil ;
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
    {"allowsRemoval",    menubar_allowRemoval},
    {"menu",             menubar_menu},
    {"visible",          menubar_visible},
    {"length",           menubar_length},
    {"autosaveName",     menubar_autosaveName},

    {"frame",            menubar_frame},
    {"title",            menubar_title},
    {"alternateTitle",   menubar_alternateTitle},
    {"image",            menubar_image},
    {"alternateImage",   menubar_alternateImage},
    {"imagePosition",    menubar_imagePosition},
    {"imageScaling",     menubar_imageScaling},
    {"sound",            menubar_sound},
    {"enabled",          menubar_enabled},
    {"tooltip",          menubar_toolTip},
    {"appearsDisabled",  menubar_appearsDisabled},
    {"remove",           menubar_delete},
    {"callback",         menubar_callback},
    {"draggingCallback", menubar_draggingCallback},

    {"__tostring",       userdata_tostring},
    {"__eq",             userdata_eq},
    {"__gc",             userdata_gc},
    {NULL,               NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", menubar_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_libmenubar(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSStatusItemWrapper  forClass:"HSStatusItemWrapper"];
    [skin registerLuaObjectHelper:toHSStatusItemWrapper forClass:"HSStatusItemWrapper"
                                             withUserdataMapping:USERDATA_TAG];


    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"allowsRemoval",
        @"menu",
        @"visible",
        @"length",
        @"autosaveName",
        @"title",
        @"alternateTitle",
        @"image",
        @"alternateImage",
        @"imagePosition",
        @"imageScaling",
        @"sound",
        @"enabled",
        @"tooltip",
        @"appearsDisabled",
        @"remove",
        @"callback",
        @"draggingCallback",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
