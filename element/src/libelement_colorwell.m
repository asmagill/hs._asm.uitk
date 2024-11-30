@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.colorwell" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *COLORWELL_STYLE ;

#pragma mark - Support Functions and Classes -

@interface HSUITKElementColorWell : NSColorWell
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;
@end

static void defineInternalDictionaries(void) {
    if (@available(macOS 13, *)) {
        COLORWELL_STYLE = @{
            @"default"  : @(NSColorWellStyleDefault),
            @"minimal"  : @(NSColorWellStyleMinimal),
            @"expanded" : @(NSColorWellStyleExpanded),
        } ;
    }
}

@implementation HSUITKElementColorWell
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
        NSResponder *nextInChain = [self nextResponder] ;
        SEL passthroughCallback = NSSelectorFromString(@"performPassthroughCallback:") ;
        while (nextInChain) {
            if ([nextInChain respondsToSelector:passthroughCallback]) {
                [nextInChain performSelectorOnMainThread:passthroughCallback
                                              withObject:messageParts
                                           waitUntilDone:YES] ;
                break ;
            } else {
                nextInChain = nextInChain.nextResponder ;
            }
        }
    }
}

- (void) deactivate {
    [super deactivate] ;
    [self callbackHamster:@[ self, @"didEndEditing", self.color ]] ;
}

- (void) activate:(BOOL)state {
    [super activate:state] ;
    [self callbackHamster:@[ self, @"didBeginEditing" ]] ;
}

- (void)performCallback:(__unused id)sender {
    if (self.continuous) {
        [self callbackHamster:@[ self, @"colorDidChange", self.color ]] ;
    }
}

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.colorwell.new([frame]) -> colorwellObject
/// Constructor
/// Creates a new colorwell element for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the frame for the element.
///
/// Returns:
///  * the colorwellObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a container element or to a `hs._asm.uitk.window`.
///
///  * The colorwell element does not have a default height or width; when assigning the element to a container, be sure to specify them in the frame details or the element may not be visible.
static int colorwell_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementColorWell *well = [[HSUITKElementColorWell alloc] initWithFrame:frameRect];
    if (well) {
        if (lua_gettop(L) != 1) [well setFrameSize:[well fittingSize]] ;
        [skin pushNSObject:well] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

/// hs._asm.uitk.element.colorwell.ignoresAlpha([state]) -> boolean
/// Function
/// Get or set whether or not the alpha component is ignored in the color picker.
///
/// Parameters:
///  * `state` - an optional boolean, default true, indicating whether or not the alpha channel should ignored (suppressed) in the color picker.
///
/// Returns:
///  * a boolean representing the, possibly new, state.
///
/// Note:
///  * When set to true, the alpha channel is not editable. If you assign a color that has an alpha component other than 1.0 with [hs._asm.uitk.element.colorwell:color](#color), the alpha component will be set to 1.0.
///
/// * The color picker is not unique to each element -- if you require the alpha channel for some colorwells but not others, make sure to call this function from the callback when the picker is opened for each specific colorwell element -- see [hs._asm.uitk.element.colorwell:callback](#callback).
static int colorwell_ignoresAlpha(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_gettop(L) == 1) {
        [NSColor setIgnoresAlpha:(BOOL)(lua_toboolean(L, 1))] ;
    }
    lua_pushboolean(L, [NSColor ignoresAlpha]) ;
    return 1 ;
}

// /// hs._asm.uitk.element.colorwell.panelVisible([state]) -> boolean
// /// Function
// /// Get or set whether the color picker panel is currently open and visible or not.
// ///
// /// Parameters:
// ///  * `state` - an optional boolean, default false, specifying whether or not the color picker is currently visible, displaying or closing it as specified.
// ///
// /// Returns:
// ///  * a boolean representing the, possibly new, state
// ///
// /// Notes:
// ///  * if a colorwell is currently the active element, invoking this function with a false argument will trigger the colorwell's close callback -- see [hs._asm.uitk.element.colorwell:callback](#callback).
// static int colorwell_pickerVisible(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
//
//     NSColorPanel *picker = [NSColorPanel sharedColorPanel] ;
//     if (lua_gettop(L) == 1) {
//         if (lua_toboolean(L, 1)) {
//             [picker makeKeyAndOrderFront:nil] ;
//         } else {
//             [picker close] ;
//         }
//     }
//     lua_pushboolean(L, picker.visible) ;
//     return 1 ;
// }

#pragma mark - Module Methods -

static int colorwell_drawWellInside(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    HSUITKElementColorWell *well     = [skin toNSObjectAtIndex:1] ;
    NSRect                  frameRect = [skin tableToRectAtIndex:2] ;

    [well drawWellInside:frameRect] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int colorwell_image(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementColorWell *well = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 13, *)) {
        if (lua_gettop(L) == 1) {
            [skin pushNSObject:well.image] ;
        } else {
            if (lua_type(L, 2) == LUA_TNIL) {
                well.image = nil ;
            } else {
                [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
                well.image = [skin toNSObjectAtIndex:2] ;
            }
            lua_pushvalue(L, 1) ;
        }
    } else {
        static int warningCount = 0 ;
        if (warningCount > 4) {
            [skin logInfo:[NSString stringWithFormat:@"%s:image - only supported in macOS 13 and newer", USERDATA_TAG]] ;
            warningCount++ ;
        }
        if (lua_gettop(L) == 1) {
            lua_pushnil(L) ;
        } else {
            lua_pushvalue(L, 1) ;
        }
    }
    return 1 ;
}

static int colorwell_colorWellStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementColorWell *well = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 13, *)) {
        if (lua_gettop(L) == 2) {
            NSString *key = [skin toNSObjectAtIndex:2] ;
            NSNumber *wellStyle = COLORWELL_STYLE[key] ;
            if (wellStyle) {
                well.colorWellStyle = [wellStyle integerValue] ;
            } else {
                return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [COLORWELL_STYLE.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
            }
            lua_pushvalue(L, 1) ;
        } else {
            NSNumber *wellStyle = @(well.colorWellStyle) ;
            NSArray *temp = [COLORWELL_STYLE allKeysForObject:wellStyle];
            NSString *answer = [temp firstObject] ;
            if (answer) {
                [skin pushNSObject:answer] ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized colorwell style %@ -- notify developers", USERDATA_TAG, wellStyle]] ;
                lua_pushnil(L) ;
            }
        }
    } else {
        static int warningCount = 0 ;
        if (warningCount > 5) {
            [skin logInfo:[NSString stringWithFormat:@"%s:style - only supported in macOS 13 and newer", USERDATA_TAG]] ;
            warningCount++ ;
        }
        if (lua_gettop(L) == 1) {
            lua_pushnil(L) ;
        } else {
            lua_pushvalue(L, 1) ;
        }
    }
    return 1;
}

/// hs._asm.uitk.element.colorwell:bordered([enabled]) -> colorwellObject | boolean
/// Method
/// Get or set whether the colorwell element has a rectangular border around it.
///
/// Parameters:
///  * `enabled` - an optional boolean, default true, specifying whether or not a border should be drawn around the colorwell element.
///
/// Returns:
///  * if a value is provided, returns the colorwellObject ; otherwise returns the current value.
static int colorwell_bordered(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementColorWell *well = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, well.bordered) ;
    } else {
        well.bordered = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.colorwell:active([state], [exclusive]) -> colorwellObject | boolean
/// Method
/// Get or set whether the colorwell element is the currently active element.
///
/// Parameters:
///  * `state` - an optional boolean, specifying whether the colorwell element should be activated (true) or deactivated (false).
///  * `exclusive` - an optional boolean, default true, specifying whether or not any other active colorwells should be deactivated when this one is activated (true) or left active as well (false). Note that this argument is ignored if `state` is false.
///
/// Returns:
///  * if a value is provided, returns the colorwellObject ; otherwise returns the whether or not the specified color well is currently active or not.
///
/// Notes:
///  * if you pass true to this method and the color picker panel is not currently visible, it will be made visible.
///  * however, it won't be dismissed when you pass false; to achieve this, use [hs._asm.uitk.element.colorwell:callback](#callback) like this:
///
///  ~~~lua
///  colorwell:callback(function(obj, msg, color)
///      if msg == "didBeginEditing" then
///         -- do what you want when the color picker is opened
///       elseif msg == "colorDidChange" then
///         -- do what you want with the color as it changes
///       elseif msg == "didEndEditing" then
///         hs._asm.uitk.element.colorwell.panelVisible(false)
///         -- now do what you want with the newly chosen color
///       end
///  end)
///  ~~~
static int colorwell_active(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementColorWell *well = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, well.active) ;
    } else {
        if (lua_toboolean(L, 2)) {
            BOOL exclusive = (lua_gettop(L) > 2) ? (BOOL)(lua_toboolean(L, 3)) : YES ;
            [well activate:exclusive] ;
        } else {
            [well deactivate] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.colorwell:color([color]) -> colorwellObject | table
/// Method
/// Get or set the color currently being displayed by the colorwell element
///
/// Parameters:
///  * an optional table defining a color as specified in the `hs._asm.uitk.util.color` module to set the colorwell to.
///
/// Returns:
///  * if a value is provided, returns the colorwellObject ; otherwise returns the current value.
///
/// Notes:
///  * if assigning a new color and [hs._asm.uitk.element.colorwell.ignoresAlpha](#ignoresAlpha) is currently true, the alpha channel of the color will be ignored and internally changed to 1.0.
static int colorwell_color(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementColorWell *well = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:well.color] ;
    } else {
        well.color = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementColorWell(lua_State *L, id obj) {
    HSUITKElementColorWell *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementColorWell *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementColorWell(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementColorWell *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementColorWell, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

// TODO: worth pursuing?
//    @property SEL pulldownAction;
//    @property(weak) id pulldownTarget;

#pragma mark - Hammerspoon/Lua Infrastructure -

// handled in uitk.panel.color now
// static int meta_gc(lua_State* __unused L) {
//     [[NSColorPanel sharedColorPanel] close] ;
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"bordered",   colorwell_bordered},
    {"active",     colorwell_active},
    {"color",      colorwell_color},
    {"image",      colorwell_image},
    {"style",      colorwell_colorWellStyle},

    {"drawWellInside", colorwell_drawWellInside},

// other metamethods inherited from _control and _view
    {NULL,    NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",          colorwell_new},
    {"ignoresAlpha", colorwell_ignoresAlpha},
//     {"panelVisible", colorwell_pickerVisible},
    {NULL,           NULL}
};

// Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc",   meta_gc},
//     {NULL,     NULL}
// };

int luaopen_hs__asm_uitk_libelement_colorwell(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:NULL // module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKElementColorWell  forClass:"HSUITKElementColorWell"];
    [skin registerLuaObjectHelper:toHSUITKElementColorWell forClass:"HSUITKElementColorWell"
                                                withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"bordered",
        @"active",
        @"color",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}
