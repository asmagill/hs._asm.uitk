@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.panel.color" ;
static LSRefTable         refTable     = LUA_NOREF ;

static NSColorPanel *colorPanel ;

static NSDictionary *COLORPANEL_MODES ;

#pragma mark - Support Functions and Classes -

BOOL oneOfOurElementObjects(NSView *obj) {
    return [obj isKindOfClass:[NSView class]]  &&
           [obj respondsToSelector:NSSelectorFromString(@"selfRefCount")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setSelfRefCount:")] &&
           [obj respondsToSelector:NSSelectorFromString(@"refTable")] &&
           [obj respondsToSelector:NSSelectorFromString(@"callbackRef")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setCallbackRef:")] ;
}

static void defineInternalDictionaries(void) {
    COLORPANEL_MODES = @{
//        @"none"    : @(NSColorPanelModeNone), -- only has meaning before colorPanel first instantiated
        @"gray"    : @(NSColorPanelModeGray),
        @"RGB"     : @(NSColorPanelModeRGB),
        @"CMYK"    : @(NSColorPanelModeCMYK),
        @"HSB"     : @(NSColorPanelModeHSB),
        @"palette" : @(NSColorPanelModeCustomPalette),
        @"list"    : @(NSColorPanelModeColorList),
        @"wheel"   : @(NSColorPanelModeWheel),
        @"crayon"  : @(NSColorPanelModeCrayon),
    } ;
}

@interface HSUITKPanelColor : NSObject
@property int callbackRef ;
@end

@implementation HSUITKPanelColor
- (instancetype)init {
    self = [super init] ;
    if (self) {
        _callbackRef      = LUA_NOREF ;
        colorPanel.target = self ;
        colorPanel.action = @selector(colorCallback:) ;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(colorClose:)
                                                     name:NSWindowWillCloseNotification
                                                   object:colorPanel] ;
    }
    return self ;
}

- (void)performCallbackForClose:(BOOL)isClosing {
    if (_callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->_callbackRef != LUA_NOREF) {
                LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
                lua_State *L    = skin.L ;
                _lua_stackguard_entry(L);
                [skin pushLuaRef:refTable ref:self->_callbackRef] ;
                [skin pushNSObject:colorPanel.color] ;
                lua_pushboolean(L, isClosing) ;
                [skin protectedCallAndError:[NSString stringWithFormat:@"%s:callback", USERDATA_TAG]
                                      nargs:2
                                   nresults:0] ;
                _lua_stackguard_exit(L);
            }
        }) ;
    }
}

// Second argument to callback is true indicating this is a close color panel event
- (void)colorClose:(__unused NSNotification*)note {
    [self performCallbackForClose:YES] ;
}
// Second argument to callback is false indicating that the color panel is still open (i.e. they may change color again)
- (void)colorCallback:(NSColorPanel*)colorPanel {
    [self performCallbackForClose:NO] ;
}
@end

static HSUITKPanelColor *colorReceiver ;

#pragma mark - Module Functions -

// - (void)setAction:(SEL)selector;
// - (void)setTarget:(id)target;

/// hs._asm.uitk.panel.color.mode([value]) -> table
/// Function
/// Set or display the currently selected color panel mode.
///
/// Parameters:
///  * [value] - The mode you wish to use as a string from the following options:
///    ** "RGB"    - RGB Sliders
///    ** "CMYK"   - CMYK Sliders
///    ** "HSB"    - HSB Sliders
///    ** "gray"   - Gray Scale Slider
///    ** "palette - Image Palettes
///    ** "list"   - Color Lists
///    ** "crayon" - Crayon Picker
///    ** "wheel"  - Color Wheel
///
/// Returns:
///  * The current mode as a string.
///
/// Notes:
///  * Example:
/// hs._asm.uitk.panel.color.mode("RGB")`
static int color_mode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_gettop(L) == 1) {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = COLORPANEL_MODES[key] ;
        if (value) {
            colorPanel.mode = [value integerValue] ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [COLORPANEL_MODES.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }

    NSNumber *value = @(colorPanel.mode) ;
    NSArray *temp = [COLORPANEL_MODES allKeysForObject:value];
    NSString *answer = [temp firstObject] ;
    if (answer) {
        [skin pushNSObject:answer] ;
    } else {
        [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized colo panel mode %@ -- notify developers", USERDATA_TAG, value]] ;
        lua_pushnil(L) ;
    }

    return 1;
}

/// hs._asm.uitk.panel.color.color([value]) -> table
/// Function
/// Set or display the currently selected color in a color wheel.
///
/// Parameters:
///  * [value] - The color values in a table (as described in `hs._asm.uitk.util.color`).
///
/// Returns:
///  * A table of the currently selected color in the form of `hs._asm.uitk.util.color`.
///
/// Notes:
///  * Example:
///      `hs._asm.uitk.panel.color.color(hs._asm.uitk.util.color.blue)`
static int color_color(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_gettop(L) == 1) {
        NSColor *theColor = [skin luaObjectAtIndex:1 toClass:"NSColor"] ;
        colorPanel.color = theColor ;
    }
    [skin pushNSObject:colorPanel.color] ;
    return 1 ;
}

/// hs._asm.uitk.panel.color.continuous([value]) -> boolean
/// Function
/// Set or display whether or not the callback should be continuously updated when a user drags a color slider or control.
///
/// Parameters:
///  * [value] - `true` if you want to continuously trigger the callback, otherwise `false`.
///
/// Returns:
///  * `true` if continuous is enabled otherwise `false`
///
/// Notes:
///  * Example:
///      `hs._asm.uitk.panel.color.continuous(true)`
static int color_continuous(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_gettop(L) == 1) {
        colorPanel.continuous = (lua_toboolean(L, 1) ? YES : NO) ;
    }
    lua_pushboolean(L, colorPanel.continuous) ;
    return 1 ;
}

/// hs._asm.uitk.panel.color.showsAlpha([value]) -> boolean
/// Function
/// Set or display whether or not the color panel should display an opacity slider.
///
/// Parameters:
///  * [value] - `true` if you want to display an opacity slider, otherwise `false`.
///
/// Returns:
///  * `true` if the opacity slider is displayed otherwise `false`
///
/// Notes:
///  * Example:
///      `hs._asm.uitk.panel.color.showsAlpha(true)`
static int color_showsAlpha(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_gettop(L) == 1) {
        colorPanel.showsAlpha = (lua_toboolean(L, 1) ? YES : NO) ;
    }
    lua_pushboolean(L, colorPanel.showsAlpha) ;
    return 1 ;
}

/// hs._asm.uitk.panel.color.alpha([value]) -> number
/// Function
/// Set or display the selected opacity.
///
/// Parameters:
///  * [value] - A opacity value as a number between 0 and 1, where 0 is 100% transparent/see-through.
///
/// Returns:
///  * The current alpha value as a number.
///
/// Notes:
///  * Example:
///      `hs._asm.uitk.panel.color.alpha(0.5)`
static int color_alpha(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_gettop(L) == 1) {
        NSNumber *alpha = [skin toNSObjectAtIndex:1];
        colorPanel.color = [colorPanel.color colorWithAlphaComponent:alpha.doubleValue];
    }

    lua_pushnumber(L, colorPanel.alpha) ;
    return 1 ;
}

/// hs._asm.uitk.panel.color.show() -> none
/// Function
/// Shows the Color Panel.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * Example:
///      `hs._asm.uitk.panel.color.show()`
static int color_show(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    [NSApp orderFrontColorPanel:nil] ;
    return 0 ;
}

/// hs._asm.uitk.panel.color.hide() -> none
/// Function
/// Hides the Color Panel.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * Example:
///      `hs._asm.uitk.panel.color.hide()`
static int color_hide(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    [colorPanel close] ;
    return 0 ;
}

/// hs._asm.uitk.panel.color.accessory([element | nil]) -> element | nil
/// Function
/// Get or set an accessory element to be displayed within the color panel.
///
/// Parameters:
///  * `element` - an `hs._asm.uitk.element` object, or explicit nil to clear` that will be displayed within the color panel when it is visible.
///
/// Returns:
///  * the current element, or nil if one has not been assigned, assigned to the color panel.
///
/// Notes:
///  * through experimentation, the maximum width of the accessory seems to be around 220 pixels wide, but it may be taller.
///  * when the color panel is closed, to ensure future use of the color panel doesn't display the incorrect accessory, this property should be set to nil. Failure to do so may result in unexpected changes or callbacks having nothing to do with the later intended usage of the color panel.
static int color_accessoryView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_gettop(L) > 0) {
        if (lua_type(L, 1) == LUA_TNIL) {
            if (colorPanel.accessoryView) {
                [skin luaRelease:refTable forNSObject:colorPanel.accessoryView] ;
            }
            colorPanel.accessoryView = nil ;
        } else {
            NSView *container = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
            if (!container || !oneOfOurElementObjects(container)) {
                return luaL_argerror(L, 1, "expected userdata representing a uitk element") ;
            }
            if (colorPanel.accessoryView) {
                [skin luaRelease:refTable forNSObject:colorPanel.accessoryView] ;
            }
            [skin luaRetain:refTable forNSObject:container] ;
            colorPanel.accessoryView = container ;
        }
    }

    if (colorPanel.accessoryView) {
        [skin pushNSObject:colorPanel.accessoryView] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

/// hs._asm.uitk.panel.color.callback([fn | nil]) -> function | nil
/// Function
/// Get or set the callback function invoked as the user interacts with the color panel.
///
/// Parameters:
///  * `fn` - an optional function, or explicit nil to remove, which will be called as the user interacts with the color panel.
///
/// Returns:
///  * the currently assigned callback function, or nil if no callback function is currently assigned.
///
/// Notes:
///  * the callback function will receive two arguments:
///    * the current color value selected in the color panel as an `hs._asm.uitk.util.color` table
///    * a boolean value indicating whether or not the color panel is being closed.
///
///  * Because a single color panel is shared across all uses of the panel within Hammerspoon, the callback function should clean up when the second argument is true; e.g. the callback function should be set back to nil and the accessory element, if one was assigned, should be removed. This will prevent an accidental call or change if the panel is reopened but the new usage hasn't yet set these properties for its new usage.
static int color_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_gettop(L) > 0) {
        // either way, lets release any function which may already be stored in the registry
        colorReceiver.callbackRef = [skin luaUnref:refTable ref:colorReceiver.callbackRef] ;
        if (lua_type(L, 1) != LUA_TNIL) {
            lua_pushvalue(L, 1) ;
            colorReceiver.callbackRef = [skin luaRef:refTable] ;
        }
    }

    if (colorReceiver.callbackRef == LUA_NOREF) {
        lua_pushnil(L) ;
    } else {
        [skin pushLuaRef:refTable ref:colorReceiver.callbackRef] ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.color.attachColorList(list) -> None
/// Function
/// Attach a new color list to the color panel.
///
/// Parameters:
///  * `list` - a list defined by the `hs._asm.uitk.util.color.list` module to add to the color panel.
///
/// Returns:
///  * None
///
/// Notes:
///  * the new color list will be selectable from the color panel when the user has selected the "list" mode.
static int color_attachColorList(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, "hs._asm.uitk.util.color.list", LS_TBREAK] ;

    NSColorList *list = [skin toNSObjectAtIndex:1] ;
    [colorPanel attachColorList:list] ;
    return 0 ;
}

/// hs._asm.uitk.panel.color.detachColorList(list) -> None
/// Function
/// Detach a color list from the color panel.
///
/// Parameters:
///  * `list` - a list defined by the `hs._asm.uitk.util.color.list` module to add to the color panel.
///
/// Returns:
///  * None
///
/// Notes:
///  * only color lists defined by the `hs._asm.uitk.util.color.list` module that have been previously attached can be removed; system lists and lists defined by files in the users personal `~/Library/Colors` directory are not removable.
static int color_detachColorList(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, "hs._asm.uitk.util.color.list", LS_TBREAK] ;

    NSColorList *list = [skin toNSObjectAtIndex:1] ;
    [colorPanel detachColorList:list] ;
    return 0 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int meta_gc(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    [[NSNotificationCenter defaultCenter] removeObserver:colorReceiver
                                                    name:NSWindowWillCloseNotification
                                                  object:colorPanel] ;

    colorReceiver.callbackRef = [skin luaUnref:refTable ref:colorReceiver.callbackRef] ;
    colorReceiver = nil ;

    if (colorPanel.accessoryView) {
        [skin luaRelease:refTable forNSObject:colorPanel.accessoryView] ;
    }
    colorPanel.accessoryView = nil ;

    [colorPanel close] ;
    colorPanel = nil ;

    return 0 ;
}

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"mode",            color_mode},
    {"color",           color_color},
    {"continuous",      color_continuous},
    {"showsAlpha",      color_showsAlpha},
    {"alpha",           color_alpha},
    {"show",            color_show},
    {"hide",            color_hide},
    {"accessory",       color_accessoryView},
    {"callback",        color_callback},
    {"attachColorList", color_attachColorList},
    {"detachColorList", color_detachColorList},
    {NULL,              NULL}
} ;

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs__asm_uitk_libpanel_color(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibrary:USERDATA_TAG
                           functions:moduleLib
                       metaFunctions:module_metaLib] ;

    defineInternalDictionaries() ;

    [NSColorPanel setPickerMask:NSColorPanelAllModesMask] ;

    colorPanel    = NSColorPanel.sharedColorPanel ;
    colorReceiver = [[HSUITKPanelColor alloc] init] ;

    return 1;
}
