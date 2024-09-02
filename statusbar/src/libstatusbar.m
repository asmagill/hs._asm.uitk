@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.statusbar" ;
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
@end

@implementation HSStatusItemWrapper {
    BOOL _lastVisibility ;
    BOOL _installed ;
}

- (instancetype)initWithLength:(CGFloat)width withState:(lua_State *)L {
    self = [super init] ;
    if (self) {
        _item = [[NSStatusBar systemStatusBar] statusItemWithLength:width] ;
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
//             [skin luaRetain:refTable forNSObject:self] ;
        } else {
            self = nil ;
        }
    }
    return self ;
}

- (void)removeFromStatusBarWithState:(lua_State *)L {
    if (_installed) {
//         LuaSkin *skin = [LuaSkin sharedWithState:L] ;

        // store position and visibility, if an autosaveName was set
        [self storeAutosaveData:_item.autosaveName] ;

        // now we can remove it from the statusbar
//         [skin luaRelease:refTable forNSObject:_item] ;
        [[NSStatusBar systemStatusBar] removeStatusItem:_item] ;
        _installed = NO ;
    }
}

// Certain activities clear the saved position data, notably reloading (not relaunching) Hamemrspoon (due to
// removing the item from the statusbar during garbage collection), the user dragging it out if this is allowed,
// the hs._asm.uitk.statusbar:visible method, etc.

- (void)restoreAutosavePosition:(NSString *)autosaveName {
    if (autosaveName) {
        NSString *keyPrefix     = @"NSStatusItem Preferred Position" ;
        NSString *key           = [NSString stringWithFormat:@"HS%@ %@", keyPrefix, autosaveName];;
        NSNumber *autosaveValue = [[NSUserDefaults standardUserDefaults] objectForKey:key];

        // Restore the last saved preferred position
        key = [NSString stringWithFormat:@"%@ %@", keyPrefix, autosaveName];;
        [[NSUserDefaults standardUserDefaults] setObject:autosaveValue forKey:key];
    }
}

- (void)storeAutosavePosition:(NSString *)autosaveName {
    if (autosaveName) {
        NSString *keyPrefix     = @"NSStatusItem Preferred Position" ;
        NSString *key           = [NSString stringWithFormat:@"%@ %@", keyPrefix, autosaveName];;
        NSNumber *autosaveValue = [[NSUserDefaults standardUserDefaults] objectForKey:key];

        // Save it under a different key so that macOS doesn't delete it during a Hammerspoon reload, etc
        key = [NSString stringWithFormat:@"HS%@ %@", keyPrefix, autosaveName];;
        [[NSUserDefaults standardUserDefaults] setObject:autosaveValue forKey:key];
    }
}

- (void)restoreAutosaveVisibility:(NSString *)autosaveName {
    if (autosaveName) {
        NSString *keyPrefix     = @"NSStatusItem Visible" ;
        NSString *key           = [NSString stringWithFormat:@"HS%@ %@", keyPrefix, autosaveName];;
        NSNumber *autosaveValue = [[NSUserDefaults standardUserDefaults] objectForKey:key];

        // Restore the last saved preferred visibility:
        key = [NSString stringWithFormat:@"%@ %@", keyPrefix, autosaveName];;
        [[NSUserDefaults standardUserDefaults] setObject:autosaveValue forKey:key];
    }
}

- (void)storeAutosaveVisibility:(NSString *)autosaveName {
    if (autosaveName) {
        NSString *keyPrefix     = @"NSStatusItem Visible" ;
        NSString *key           = [NSString stringWithFormat:@"%@ %@", keyPrefix, autosaveName];;
        NSNumber *autosaveValue = [[NSUserDefaults standardUserDefaults] objectForKey:key];

        // Save it under a different key so that macOS doesn't delete it during a Hammerspoon reload, etc
        key = [NSString stringWithFormat:@"HS%@ %@", keyPrefix, autosaveName];;
        [[NSUserDefaults standardUserDefaults] setObject:autosaveValue forKey:key];
    }
}

- (void)restoreAutosaveData:(NSString *)autosaveName {
    [self restoreAutosavePosition:autosaveName] ;
    [self restoreAutosaveVisibility:autosaveName] ;
}

- (void)storeAutosaveData:(NSString *)autosaveName {
    [self storeAutosavePosition:autosaveName] ;
    [self storeAutosaveVisibility:autosaveName] ;
}

// callback handling

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

/// hs._asm.uitk.statusbar.new([size]) -> statusbarObject
/// Constructor
/// Create a new statusbar item for display in the status bar area of the macOS menubar
///
/// Parameters:
///  * `size` - an optional boolean or number specifying the width of the statusbar item. See notes, defaults to true.
///
/// Returns:
///  * a new statusbarObject
///
/// Notes:
///  * if you specify the size as a boolean, a true value indicates that the statusbar item will adjust its width dynamically as the title and image change, while a false value means that the size will be constrained to a square with sides equal to the height of the statusbar.
///  * if you specify the size as a number, the width of the statusbar item will be set to the specified width.
static int statusbar_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    CGFloat width = NSVariableStatusItemLength ;
    if (lua_gettop(L) == 1) {
        if (lua_type(L, 1) == LUA_TBOOLEAN) {
            width = lua_toboolean(L, 1) ? NSVariableStatusItemLength : NSSquareStatusItemLength ;
        } else {
            width = fmax(0, lua_tonumber(L, 1)) ;
        }
    }
    HSStatusItemWrapper *wrapper = [[HSStatusItemWrapper alloc] initWithLength:width withState:L] ;
    if (wrapper) {
        [skin pushNSObject:wrapper] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

/// hs._asm.uitk.statusbar:width([size]) -> statusbarObject | boolean | number
/// Method
/// Get or set the width of the statusbar item.
///
/// Parameters:
///  * `size` - an optional boolean or number specifying the width of the statusbar item. See notes, defaults to true.
///
/// Returns:
///  * if an argument was provided, returns the statusbarObject; otherwise returns the current value
///
/// Notes:
///  * if you specify the size as a boolean, a true value indicates that the statusbar item will adjust its width dynamically as the title and image change, while a false value means that the size will be constrained to a square with sides equal to the height of the statusbar.
///  * if you specify the size as a number, the width of the statusbar item will be set to the specified width.
static int statusbar_length(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;

    if (lua_gettop(L) == 1) {
        CGFloat width = item.length ;
        if (width < 0) {
            lua_pushboolean(L, width > NSSquareStatusItemLength) ;
        } else {
            lua_pushnumber(L, width) ;
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

/// hs._asm.uitk.statusbar:frame() -> table
/// Method
/// Get the frame of the statusbar item.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table with key-value pairs representing the location (keys `x` and `y`) and size (keys `h` and `w`) the statusbar item takes in the statusbar.
static int statusbar_frame(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;
    [skin pushNSRect:statusItemFrame(item)] ;
    return 1 ;
}

/// hs._asm.uitk.statusbar:menu([menu | nil]) -> statusbarObject | `hs._asm.uitk.menu` object | nil
/// Method
/// Get or set the menu displayed when the user clicks on the statusbar item.
///
/// Parameters:
///  * `menu` - an `hs._asm.uitk.menu` object, or explicit nil to remove, containing the menu that the statusbar item will show.
///
/// Returns:
///  * if an argument was provided, returns the statusbarObject; otherwise returns the current value
static int statusbar_menu(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.menu] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            if (item.menu) [skin luaRelease:refTable forNSObject:item.menu] ;
            item.menu = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs._asm.uitk.menu", LS_TBREAK] ;
            if (item.menu) [skin luaRelease:refTable forNSObject:item.menu] ;
            item.menu = [skin toNSObjectAtIndex:2] ;
            [skin luaRetain:refTable forNSObject:item.menu] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.statusbar:title([title | style | nil]) -> statusbarObject | string | `hs.styledtext` object | nil
/// Method
/// Get or set the title for the statusbar item.
///
/// Parameters:
///  * `title` - an optional string, `hs.styledtext` object, or explicit nil to remove, specifying the title to display for the statusbar item. You cannot specify this argument and `style` at the same time.
///  * `style` - an optional boolean, default false, specifying whether or not the value returned should be as an `hs.styledtext` object (true) or as a string (false). You cannot specify this argument and `title` at the same time.
///
/// Returns:
///  * if the argument is a string or an `hs.styledtext` object, returns the statusbarObject; if no arguments are specified, returns a string; otherwise returns an `hs.styledtext` object if `style` is true, or a string if `style` is false. If the title was previously set with a string, and `style` is false or not specified, may return nil.
///
/// Notes:
///  * see also [hs._asm.uitk.statusbar:alternateTitle](#alternateTitle)
static int statusbar_title(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;
    NSStatusBarButton   *button = item.button ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:button.title] ;
    } else if (lua_type(L, 2) == LUA_TBOOLEAN) {
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

/// hs._asm.uitk.statusbar:image([image]) -> statusbarObject | hs.image object | nil
/// Method
/// Get or set the image for the statusbar item.
///
/// Parameters:
///  * `image` - an optional hs.image object, or explicit nil to remove, specifying the image for the statusbar item.
///
/// Returns:
///  * if an argument is provided, returns the statusbarObject; otherwise returns the current value
///
/// Notes:
///  * see also [hs._asm.uitk.statusbar:alternateImage](#alternateImage)
static int statusbar_image(lua_State *L) {
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

/// hs._asm.uitk.statusbar:imagePosition([position]) -> statusbarObject | string
/// Method
/// Get or set the image position relative to the title text for the statusbar item
///
/// Parameters:
///  * an optional string, default "leading", specifying the images position relative to the text for the statusbar item
///
/// Returns:
///  * if an argument is provided, returns the statusbarObject; otherwise returns the current value
///
/// Notes:
///  * the following strings are recognized as valid values for `position`:
///    * "none"     - don't show the image
///    * "only"     - only show the image, not the title
///    * "leading"  - show the image before the title
///    * "trailing" - show the image after the title
///    * "left"     - show the image to the left of the title
///    * "right"    - show the image to the right of the title
///    * "below"    - show the image below the title
///    * "above"    - show the image above the title
///    * "overlaps" - show the image on top of the title
static int statusbar_imagePosition(lua_State *L) {
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

/// hs._asm.uitk.statusbar:imageScaling([scaling]) -> statusbarObject | string
/// Method
/// Get or set the how an image is scaled within the statusbar item
///
/// Parameters:
///  * an optional string, default "none", specifying how the image is scaled within the statusbar item
///
/// Returns:
///  * if an argument is provided, returns the statusbarObject; otherwise returns the current value
///
/// Notes:
///  * the following strings are recognized as valid values for `scaling`:
///    * "axesIndependently"      - the image will be scaled to fill the statusbar item space, ignoring the aspect ratio
///    * "none"                   - no scaling is performed
///    * "proportionallyDown"     - if the image is too large, it will be scaled down to fit, maintaining the aspect ratio
///    * "proportionallyUpOrDown" - the image will be scaled up or down to fit the space allowed, maintaining the aspect ratio
static int statusbar_imageScaling(lua_State *L) {
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

// seems to have issues when styledtext used; have to decide if tracking down all of the possible variants is worth it...
//
// /// hs._asm.uitk.statusbar:appearsDisabled([state]) -> statusbarObject | boolean
// /// Method
// /// Get or set whether the statusbar item appears disabled or not.
// ///
// /// Parameters:
// ///  * `state` - an optional boolean, default false, specifying whether or not the item appears disabled in the statusbar.
// ///
// /// Returns:
// ///  * if an argument is provided, returns the statusbarObject; otherwise returns the current value
// ///
// /// Notes:
// ///  * a statusbar item that appears disabled will appear greyed out
// ///  * this will not actually disable the status item; if the user clicks on it, the appropriate action (callback or menu) will still occur.
// ///  * to actually disable the item, see [hs._asm.uitk.statusbar:enabled](#enabled)
// static int statusbar_appearsDisabled(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
//     HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
//     NSStatusItem        *item    = wrapper.item ;
//     NSStatusBarButton   *button = item.button ;
//
//     if (lua_gettop(L) == 1) {
//         lua_pushboolean(L, button.appearsDisabled) ;
//     } else {
//         button.appearsDisabled = (BOOL)(lua_toboolean(L, 2)) ;
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }

/// hs._asm.uitk.statusbar:visible([state]) -> statusbarObject | boolean
/// Method
/// Get or set whether the statusbar item is displayed in the statusbar or not.
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether or not the statusbar item is displayed in the statusbar.
///
/// Returns:
///  * if an argument is provided, returns the statusbarObject; otherwise returns the current value
///
/// Notes:
///  * see also [hs._asm.uitk.statusbar:remove](#remove)
static int statusbar_visible(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, item.visible) ;
    } else {
        BOOL toBeVisible = (BOOL)(lua_toboolean(L, 2)) ;

        if (toBeVisible) {
            // restore position because being not visible cleared it
            [wrapper restoreAutosavePosition:item.autosaveName] ;
        } else {
            // setting visible to NO will clear this, so save it first
            [wrapper storeAutosavePosition:item.autosaveName] ;
        }

        item.visible = toBeVisible ;

        // we want to save the visibility status in any case
        [wrapper storeAutosaveVisibility:item.autosaveName] ;

        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.statusbar:allowsRemoval([state]) -> statusbarObject | boolean
/// Method
/// Get or set whether the user can remoce the statusbar item by holding down the command key while clicking it.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not the statusbar item can be removed by the user.
///
/// Returns:
///  * if an argument is provided, returns the statusbarObject; otherwise returns the current value
///
/// Notes:
///  * user removal of the statusbar item is equivalent to setting the `visible` property to false. You can programmatically return the item by using [hs._asm.uitk.statusbar:visible](#visible) and setting it to true again.
///
///  * see also [hs._asm.uitk.statusbar:trackVisibility](#trackVisibility)
static int statusbar_allowRemoval(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
    NSStatusItem        *item    = wrapper.item ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, (item.behavior & NSStatusItemBehaviorRemovalAllowed) == NSStatusItemBehaviorRemovalAllowed) ;
    } else {
        if (lua_toboolean(L, 2)) {
            item.behavior = item.behavior | NSStatusItemBehaviorRemovalAllowed ;
        } else {
            item.behavior = item.behavior & ~NSStatusItemBehaviorRemovalAllowed ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.statusbar:trackVisibility([state]) -> statusbarObject | boolean
/// Method
/// Get or set whether a callback is generated when the visibility status of the statusbar item changes.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not a callback is generated when the visibility status of the statusbar item changes.
///
/// Returns:
///  * if an argument is provided, returns the statusbarObject; otherwise returns the current value
///
/// Notes:
///  * if set to true, a callback will be triggered when the user removes the item from the statusbar (see [hs._asm.uitk.statusbar:allowsRemoval](#allowsRemoval)) or the [hs._asm.uitk.statusbar:visible](#visible) method is used to change the statusbar item's visibility.
///    * a callback will *NOT* be triggered when [hs._asm.uitk.statusbar:remove](#remove) is invoked.
///
///  * the callback function should expect two arguments, `statusbarObject, "visibilityChange"`, and return none.
///  * see also [hs._asm.uitk.statusbar:callback](#callback)
static int statusbar_trackVisibility(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, wrapper.trackingVisibility) ;
    } else {
        wrapper.trackingVisibility = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.statusbar:enabled([state]) -> statusbarObject | boolean
/// Method
/// Get or set whether the statusbar item is enabled or not.
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether or not statusbar item is enabled or not.
///
/// Returns:
///  * if an argument is provided, returns the statusbarObject; otherwise returns the current value
///
/// Notes:
///  * a statusbar item that is disabled will appear greyed out
static int statusbar_enabled(lua_State *L) {
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

/// hs._asm.uitk.statusbar:tooltip([tooltip]) -> statusbarObject | string | nil
/// Method
/// Get or set the tooltip for the statusbar item.
///
/// Parameters:
///  * `tooltip` - an optional string, or explicit nil to remove, specifying the tooltip to display when the user hovers the mouse pointer over the statusbar item.
///
/// Returns:
///  * if an argument is provided, returns the statusbarObject; otherwise returns the current value
static int statusbar_toolTip(lua_State *L) {
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

/// hs._asm.uitk.statusbar:autosaveName([name]) -> statusbarObject | string | nil
/// Method
/// Get ot set the autosavename for the statusbar item.
///
/// Parameters:
///  * `name` - an optional string, or `nil` to reset to the default (see Notes), specifying the autosave name used by the statusbar item.
///
/// Returns:
///  * if an argument is provided, returns the statusbarObject; otherwise returns the current value
///
/// Notes:
///  * the autosave name is used to store the user's preferences for item location and item visibility.
///  * if you wish to honor these, it works best to assign the autosave name shortly after creating the item with [hs._asm.uitk.statusbar.new](#new) within the same codeblock before the macOS has a chance to actually place the item in the statusbar.
///
///  * If you do not assign an autosave name, one will automatically be generated, likely in the format of "Item-#". If you pass an explicit nil to this method, the name will be reset to this value.
static int statusbar_autosaveName(lua_State *L) {
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
            NSString *autosaveName = [skin toNSObjectAtIndex:2] ;
            // restore position and visibility
            [wrapper restoreAutosaveData:autosaveName] ;
            item.autosaveName = autosaveName;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.statusbar:callback([fn | nil]) -> statusbarObject | function | nil
/// Method
/// Get or set the callback function for the statusbar item.
///
/// Parameters:
///  * an optional callback function, or explicit nil to remove, that will be assigned to statusbar item
///
/// Returns:
///  * if an argument is provided, returns the statusbarObject; otherwise returns the current value
///
/// Notes:
///  * the callback function will be called whenever the user clicks on the statusbar item and should expect two arguments, `statusbarObject, "mouseClick"`, and return none.
///  * if you have enabled visibility tracking with [hs._asm.uitk.statusbar:trackVisibility](#trackVisibility), you will also receive the callback described in its documentation.
///
///  * this is independant of displaying the menu if you have set one with [hs._asm.uitk.statusbar:men](#menu) -- if both have been assigned, both will be triggered when the user clicks on the statusbar item.
static int statusbar_callback(lua_State *L) {
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

/// hs._asm.uitk.statusbar:draggingCallback([fn | nil]) -> statusbarObject | function | nil
/// Method
/// Get or set the callback function that is triggered when something is dragged to the statusbar item.
///
/// Parameters:
///  * an optional callback function, or explicit nil to remove, that will be assigned to statusbar item for dragging operations
///
/// Returns:
///  * if an argument is provided, returns the statusbarObject; otherwise returns the current value
///
/// Notes:
///  * The callback function should expect 3 arguments and optionally return 1: the statusbar item itself, a message specifying the type of dragging event, and a table containing details about the item(s) being dragged.  The key-value pairs of the details table will be the following:
///    * `pasteboard` - the name of the pasteboard that contains the items being dragged
///    * `sequence`   - an integer that uniquely identifies the dragging session.
///    * `mouse`      - a point table containing the location of the mouse pointer within the status item corresponding to when the callback occurred.
///    * `operation`  - a table containing string descriptions of the type of dragging the source application supports. Potentially useful for determining if your callback function should accept the dragged item or not.
///
/// * The possible messages the callback function may receive are as follows:
///    * "enter"   - the user has dragged an item onto the statusbar item.  When your callback receives this message, you can optionally return false to indicate that you do not wish to accept the item being dragged.
///    * "exit"    - the user has moved the item off of the statusbar item; if the previous "enter" callback returned false, this message will also occur when the user finally releases the items being dragged.
///    * "receive" - indicates that the user has released the dragged object while it is still within the statusbar item frame.  When your callback receives this message, you can optionally return false to indicate to the sending application that you do not want to accept the dragged item -- this may affect the animations provided by the sending application.
///
///  * You can use the sequence number in the details table to match up an "enter" with an "exit" or "receive" message.
///
///  * You should capture the details you require from the drag-and-drop operation during the callback for "receive" by using the pasteboard field of the details table and the `hs.pasteboard` module.  Because of the nature of "promised items", it is not guaranteed that the items will still be on the pasteboard after your callback completes handling this message.
static int statusbar_draggingCallback(lua_State *L) {
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

/// hs._asm.uitk.statusbar:remove() -> nil
/// Method
/// Removes the statusbar item from the statusbar
///
/// Parameters:
///  * None
///
/// Returns:
///  * nil
///
/// Notes:
///  * this method should only be used when you truly are done with the statusbar item and want to remove it for good
///    * You cannot return the statusbar item to the statusbar after invoking this method, you will have to recreate it completely. See [hs._asm.uitk.statusbar:visibile](#visible) for a way to temporarily hide the statusbar item.
///    * this method will *not* trigger a callback if visibility tracking is enabled with [hs._asm.uitk.statusbar:trackVisibility](#trackVisibility).
static int statusbar_delete(lua_State *L) {
// NOTE: really more of a removeFromMenubar -- delete occurs when __gc does...
//       need to add "stillValid" or similar so remaining existant userdata can know
//       when this has been called. Menu won't be released till final userdata is
//       collected, but NSObject still exists anyway and other methods will still
//       return/change info even if it has no visible effect.
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;

    [wrapper removeFromStatusBarWithState:L] ;

    lua_pushnil(L);
    return 1;
}

/// hs._asm.uitk.statusbar:alternateTitle([title | style | nil]) -> statusbarObject | string | `hs.styledtext` object | nil
/// Method
/// Get or set the title that is displayed when the user clicks on the statusbar item.
///
/// Parameters:
///  * `title` - an optional string, `hs.styledtext` object, or explicit nil to remove, specifying the title to display for the statusbar item when the user clicks on it. You cannot specify this argument and `style` at the same time.
///  * `style` - an optional boolean, default false, specifying whether or not the value returned should be as an `hs.styledtext` object (true) or as a string (false). You cannot specify this argument and `title` at the same time.
///
/// Returns:
///  * if the argument is a string or an `hs.styledtext` object, returns the statusbarObject; if no arguments are specified, returns a string; otherwise returns an `hs.styledtext` object if `style` is true, or a string if `style` is false. If the title was previously set with a string, and `style` is false or not specified, may return nil.
///
/// Notes:
///  * see also [hs._asm.uitk.statusbar:title](#title)
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
        if (lua_type(L, 2) == LUA_TNIL) {
            button.alternateTitle = @"" ;
        } else {
            // necessary for the alternate title to appear when the mouse button is down
            [button setButtonType:NSButtonTypeMomentaryChange] ;

            if (lua_type(L, 2) == LUA_TUSERDATA) {
                [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.styledtext", LS_TBREAK] ;
                button.attributedAlternateTitle = [skin toNSObjectAtIndex:2] ;
            } else {
                [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
                button.alternateTitle = [skin toNSObjectAtIndex:2] ;
            }
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.statusbar:alternateImage([image]) -> statusbarObject | hs.image object | nil
/// Method
/// Get or set the image displayed when the user clicks on the statusbar item.
///
/// Parameters:
///  * `image` - an optional hs.image object, or explicit nil to remove, specifying the image for the statusbar item when the user clicks on it.
///
/// Returns:
///  * if an argument is provided, returns the statusbarObject; otherwise returns the current value
///
/// Notes:
///  * see also [hs._asm.uitk.statusbar:image](#image)
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
            // necessary for the alternate image to appear when the mouse button is down
            [button setButtonType:NSButtonTypeMomentaryChange] ;

            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            button.alternateImage = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// doesn't seem to be working; play around with in element.button and see if it's tied to specific settings
// like alternateTitle/alternateImage or if it's something that Apple broke overtime but is used so seldom
// no one really noticed...
//
// static int menubar_sound(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
//     HSStatusItemWrapper *wrapper = [skin toNSObjectAtIndex:1] ;
//     NSStatusItem        *item    = wrapper.item ;
//     NSStatusBarButton   *button = item.button ;
//
//     if (lua_gettop(L) == 1) {
//         [skin pushNSObject:button.sound] ;
//     } else {
//         if (lua_type(L, 2) == LUA_TNIL) {
//             button.sound = nil ;
//         } else {
//             [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.sound", LS_TBREAK] ;
//             button.sound = [skin toNSObjectAtIndex:2] ;
//         }
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }

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
            [obj removeFromStatusBarWithState:L] ;

            if (obj.item.menu) {
                [skin luaRelease:refTable forNSObject:obj.item.menu] ;
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
    {"allowsRemoval",    statusbar_allowRemoval},
    {"menu",             statusbar_menu},
    {"visible",          statusbar_visible},
    {"width",            statusbar_length},
    {"autosaveName",     statusbar_autosaveName},
    {"title",            statusbar_title},
    {"image",            statusbar_image},
    {"imagePosition",    statusbar_imagePosition},
    {"imageScaling",     statusbar_imageScaling},
    {"enabled",          statusbar_enabled},
    {"tooltip",          statusbar_toolTip},
//     {"appearsDisabled",  statusbar_appearsDisabled},
    {"callback",         statusbar_callback},
    {"draggingCallback", statusbar_draggingCallback},
    {"trackVisibility",  statusbar_trackVisibility},

    {"alternateTitle",   menubar_alternateTitle},
    {"alternateImage",   menubar_alternateImage},
//     {"sound",            menubar_sound},

    {"frame",            statusbar_frame},
    {"remove",           statusbar_delete},

    {"__tostring",       userdata_tostring},
    {"__eq",             userdata_eq},
    {"__gc",             userdata_gc},
    {NULL,               NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",       statusbar_new},
    {NULL,        NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_libstatusbar(lua_State* L) {
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
        @"width",
        @"autosaveName",
        @"title",
        @"image",
        @"imagePosition",
        @"imageScaling",
        @"enabled",
        @"tooltip",
//         @"appearsDisabled",
        @"callback",
        @"draggingCallback",
        @"trackVisibility",

        @"alternateTitle",
        @"alternateImage",
//         @"sound",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
