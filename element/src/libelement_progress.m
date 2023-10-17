@import Cocoa ;
@import LuaSkin ;
@import CoreImage.CIFilter ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.progress" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *PROGRESS_SIZE ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaryies(void) {
    if (@available(macOS 11, *)) {
        PROGRESS_SIZE = @{
            @"regular" : @(NSControlSizeRegular),
            @"small"   : @(NSControlSizeSmall),
            @"mini"    : @(NSControlSizeMini),
            @"large"   : @(NSControlSizeLarge),
        } ;
    } else {
        PROGRESS_SIZE = @{
            @"regular" : @(NSControlSizeRegular),
            @"small"   : @(NSControlSizeSmall),
            @"mini"    : @(NSControlSizeMini),
        } ;
    }
}

@interface HSUITKElementProgress : NSProgressIndicator
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;
@end

@implementation HSUITKElementProgress
- (instancetype)initWithFrame:(NSRect)frameRect {
    @try {
        self = [super initWithFrame:frameRect] ;
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:new - %@", USERDATA_TAG, exception.reason]] ;
        self = nil ;
    }

    if (self) {
        _selfRefCount   = 0 ;
        self.usesThreadedAnimation = YES ;

        // unused, but the fields are how other code identifies us as a member view or control
        _callbackRef    = LUA_NOREF ;
        _refTable       = refTable ;
    }
    return self ;
}

- (BOOL)isFlipped {
    return YES ;
}

// Code from http://stackoverflow.com/a/32396595
//
// Color works for spinner (both indeterminate and determinate) and partially for bar:
//    indeterminate bar becomes a solid, un-animating color; determinate bar looks fine.
- (void)setCustomColor:(NSColor *)aColor {
    if (aColor) {
        CIFilter *colorPoly = [CIFilter filterWithName:@"CIColorPolynomial"];
        [colorPoly setDefaults];

        CIVector *redVector   = [CIVector vectorWithX:aColor.redComponent   Y:0 Z:0 W:0] ;
        CIVector *greenVector = [CIVector vectorWithX:aColor.greenComponent Y:0 Z:0 W:0] ;
        CIVector *blueVector  = [CIVector vectorWithX:aColor.blueComponent  Y:0 Z:0 W:0] ;
        [colorPoly setValue:redVector   forKey:@"inputRedCoefficients"];
        [colorPoly setValue:greenVector forKey:@"inputGreenCoefficients"];
        [colorPoly setValue:blueVector  forKey:@"inputBlueCoefficients"];
        [self setContentFilters:[NSArray arrayWithObject:colorPoly]];
    } else {
        [self setContentFilters:[NSArray array]];
    }
}

- (NSColor *)customColor {
    CIFilter *colorPoly = self.contentFilters.firstObject ;
    if (colorPoly) {
        CIVector *redVector   = [colorPoly valueForKey:@"inputRedCoefficients"] ;
        CIVector *greenVector = [colorPoly valueForKey:@"inputGreenCoefficients"] ;
        CIVector *blueVector  = [colorPoly valueForKey:@"inputBlueCoefficients"] ;
        return [NSColor colorWithSRGBRed:redVector.X green:greenVector.X blue:blueVector.X alpha:1.0] ;
    } else {
        return nil ;
    }
}

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.progress.new([frame]) -> progressObject
/// Constructor
/// Creates a new progress element for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the frame for the element.
///
/// Returns:
///  * the progressObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a content element or to a `hs._asm.uitk.window`.
///
///  * The bar progress indicator type does not have a default width; if you are assigning the progress element to an `hs._asm.uitk.element.content`, be sure to specify a width in the frame details or the element may not be visible.
static int progress_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementProgress *element = [[HSUITKElementProgress alloc] initWithFrame:frameRect];
    if (element) {
        if (lua_gettop(L) != 1) [element setFrameSize:[element fittingSize]] ;
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

/// hs._asm.guitk.element.progress:start() -> progressObject
/// Method
/// If the progress indicator is indeterminate, starts the animation for the indicator.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the progress indicator object
///
/// Notes:
///  * This method has no effect if the indicator is not indeterminate.
static int progress_start(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementProgress *progress = [skin toNSObjectAtIndex:1] ;
    [progress startAnimation:nil];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.guitk.element.progress:stop() -> progressObject
/// Method
/// If the progress indicator is indeterminate, stops the animation for the indicator.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the progress indicator object
///
/// Notes:
///  * This method has no effect if the indicator is not indeterminate.
static int progress_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementProgress *progress = [skin toNSObjectAtIndex:1] ;
    [progress stopAnimation:nil];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.guitk.element.progress:threaded([flag]) -> progressObject | boolean
/// Method
/// Get or set whether or not the animation for an indicator occurs in a separate process thread.
///
/// Parameters:
///  * `flag` - an optional boolean indicating whether or not the animation for the indicator should occur in a separate thread.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is true.
///  * If this flag is set to false, the indicator animation speed may fluctuate as Hammerspoon performs other activities, though not reliably enough to provide an "activity level" feedback indicator.
static int progress_threaded(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementProgress *progress = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        progress.usesThreadedAnimation = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, progress.usesThreadedAnimation) ;
    }
    return 1;
}

/// hs._asm.guitk.element.progress:indeterminate([flag]) -> progressObject | boolean
/// Method
/// Get or set whether or not the progress indicator is indeterminate.  A determinate indicator displays how much of the task has been completed. An indeterminate indicator shows simply that the application is busy.
///
/// Parameters:
///  * `flag` - an optional boolean indicating whether or not the indicator is indeterminate.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is true.
///  * If this setting is set to false, you should also take a look at [hs._asm.guitk.element.progress:min](#min) and [hs._asm.guitk.element.progress:max](#max), and periodically update the status with [hs._asm.guitk.element.progress:value](#value) or [hs._asm.guitk.element.progress:increment](#increment)
static int progress_indeterminate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementProgress *progress = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        progress.indeterminate = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, progress.indeterminate) ;
    }
    return 1;
}

/// hs._asm.guitk.element.progress:bezeled([flag]) -> progressObject | boolean
/// Method
/// Get or set whether or not the progress indicator’s frame has a three-dimensional bezel.
///
/// Parameters:
///  * `flag` - an optional boolean indicating whether or not the indicator's frame is bezeled.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is true.
///  * In my testing, this setting does not seem to have much, if any, effect on the visual aspect of the indicator and is provided in this module in case this changes in a future OS X update (there are some indications that it may have had a greater effect in previous versions).
static int progress_bezeled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementProgress *progress = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        progress.bezeled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, progress.bezeled) ;
    }
    return 1;
}

/// hs._asm.guitk.element.progress:visibleWhenStopped([flag]) -> progressObject | boolean
/// Method
/// Get or set whether or not the progress indicator is visible when animation has been stopped.
///
/// Parameters:
///  * `flag` - an optional boolean indicating whether or not the progress indicator is visible when animation has stopped.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is true.
static int progress_displayedWhenStopped(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementProgress *progress = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        progress.displayedWhenStopped = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, progress.displayedWhenStopped) ;
    }
    return 1;
}

/// hs._asm.guitk.element.progress:circular([flag]) -> progressObject | boolean
/// Method
/// Get or set whether or not the progress indicator is circular or a in the form of a progress bar.
///
/// Parameters:
///  * `flag` - an optional boolean indicating whether or not the indicator is circular (true) or a progress bar (false)
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is false.
///  * An indeterminate circular indicator is displayed as the spinning star seen during system startup.
///  * A determinate circular indicator is displayed as a pie chart which fills up as its value increases.
///  * An indeterminate progress indicator is displayed as a rounded rectangle with a moving pulse.
///  * A determinate progress indicator is displayed as a rounded rectangle that fills up as its value increases.
static int progress_circular(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementProgress *progress = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        progress.style = (BOOL)(lua_toboolean(L, 2)) ? NSProgressIndicatorStyleSpinning : NSProgressIndicatorStyleBar ;
//         [progress sizeToFit] ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, (progress.style == NSProgressIndicatorStyleSpinning)) ;
    }
    return 1;
}

/// hs._asm.guitk.element.progress:value([value]) -> progressObject | number
/// Method
/// Get or set the current value of the progress indicator's completion status.
///
/// Parameters:
///  * `value` - an optional number indicating the current extent of the progress.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default value for this is 0.0
///  * This value has no effect on the display of an indeterminate progress indicator.
///  * For a determinate indicator, this will affect how "filled" the bar or circle is.  If the value is lower than [hs._asm.guitk.element.progress:min](#min), then it will be set to the current minimum value.  If the value is greater than [hs._asm.guitk.element.progress:max](#max), then it will be set to the current maximum value.
static int progress_value(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementProgress *progress = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        progress.doubleValue = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnumber(L, progress.doubleValue) ;
    }
    return 1;
}

/// hs._asm.guitk.element.progress:min([value]) -> progressObject | number
/// Method
/// Get or set the minimum value (the value at which the progress indicator should display as empty) for the progress indicator.
///
/// Parameters:
///  * `value` - an optional number indicating the minimum value.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default value for this is 0.0
///  * This value has no effect on the display of an indeterminate progress indicator.
///  * For a determinate indicator, the behavior is undefined if this value is greater than [hs._asm.guitk.element.progress:max](#max).
static int progress_min(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementProgress *progress = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        progress.minValue = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnumber(L, progress.minValue) ;
    }
    return 1;
}

/// hs._asm.guitk.element.progress:max([value]) -> progressObject | number
/// Method
/// Get or set the maximum value (the value at which the progress indicator should display as full) for the progress indicator.
///
/// Parameters:
///  * `value` - an optional number indicating the maximum value.
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default value for this is 100.0
///  * This value has no effect on the display of an indeterminate progress indicator.
///  * For a determinate indicator, the behavior is undefined if this value is less than [hs._asm.guitk.element.progress:min](#min).
static int progress_max(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementProgress *progress = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        progress.maxValue = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnumber(L, progress.maxValue) ;
    }
    return 1;
}

/// hs._asm.guitk.element.progress:increment(value) -> progressObject
/// Method
/// Increment the current value of a progress indicator's progress by the amount specified.
///
/// Parameters:
///  * `value` - the value by which to increment the progress indicator's current value.
///
/// Returns:
///  * the progress indicator object
///
/// Notes:
///  * Programmatically, this is equivalent to `hs._asm.guitk.element.progress:value(hs._asm.guitk.element.progress:value() + value)`, but is faster.
static int progress_increment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK] ;
    HSUITKElementProgress *progress = [skin toNSObjectAtIndex:1] ;
    [progress incrementBy:lua_tonumber(L, 2)] ;
    lua_pushvalue(L, 1) ;
    return 1;
}

/// hs._asm.guitk.element.progress:indicatorSize([size]) -> progressObject | string
/// Method
/// Get or set the indicator's size.
///
/// Parameters:
///  * `size` - an optional string specifying the size of the progress indicator object.  May be one of "regular", "small", or "mini".
///
/// Returns:
///  * if a value is provided, returns the progress indicator object ; otherwise returns the current value.
///
/// Notes:
///  * The default setting for this is "regular".
///  * For circular indicators, the sizes seem to be 32x32, 16x16, and 10x10 in 10.11.
///  * For bar indicators, the height seems to be 20 and 12; the mini size seems to be ignored, at least in 10.11.
static int progress_controlSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementProgress *progress = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *controlSize = PROGRESS_SIZE[key] ;
        if (controlSize) {
            progress.controlSize = [controlSize unsignedIntegerValue] ;
//             [progress sizeToFit] ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[PROGRESS_SIZE allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        NSNumber *controlSize = @(progress.controlSize) ;
        NSArray *temp = [PROGRESS_SIZE allKeysForObject:controlSize];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized control size %@ -- notify developers", USERDATA_TAG, controlSize]] ;
            lua_pushnil(L) ;
        }
    }
    return 1;
}

/// hs._asm.guitk.element.progress:color(color) -> progressObject | table | nil
/// Method
/// Get or set the fill color for a progress indicator.
///
/// Parameters:
///  * `color` - an optional table specifying a color as defined in `hs.drawing.color` indicating the color to use for the progress indicator, or an explicit nil to reset the behavior to macOS default.
///
/// Returns:
///  * the progress indicator object
///
/// Notes:
///  * This method is not based upon the methods inherent in the NSProgressIndicator Objective-C class, but rather on code found at http://stackoverflow.com/a/32396595 utilizing a CIFilter object to adjust the view's output.
///  * When a color is applied to a bar indicator, the visible pulsing of the bar is no longer visible; this is a side effect of applying the filter to the view and no workaround is currently known.
static int progress_customColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementProgress *progress = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:progress.customColor] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            progress.customColor = nil ;
        } else {
            NSColor *argColor = [skin luaObjectAtIndex:2 toClass:"NSColor"]  ;
            NSColor *theColor = [argColor colorUsingColorSpace:NSColorSpace.genericRGBColorSpace] ;
            if (theColor) {
                progress.customColor = theColor ;
            } else {
                return luaL_error(L, "color must be expressible in the RGB color space") ;
            }
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementProgress(lua_State *L, id obj) {
    HSUITKElementProgress *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementProgress *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementProgressFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementProgress *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementProgress, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"start",              progress_start},
    {"stop",               progress_stop},
    {"threaded",           progress_threaded},
    {"indeterminate",      progress_indeterminate},
    {"circular",           progress_circular},
    {"bezeled",            progress_bezeled},
    {"visibleWhenStopped", progress_displayedWhenStopped},
    {"value",              progress_value},
    {"min",                progress_min},
    {"max",                progress_max},
    {"increment",          progress_increment},
    {"indicatorSize",      progress_controlSize},
    {"color",              progress_customColor},

// other metamethods inherited from _control and _view
    {NULL,    NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", progress_new},
    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_libelement_progress(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaryies() ;

    [skin registerPushNSHelper:pushHSUITKElementProgress         forClass:"HSUITKElementProgress"];
    [skin registerLuaObjectHelper:toHSUITKElementProgressFromLua forClass:"HSUITKElementProgress"
                                                       withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through content metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"threaded",
        @"indeterminate",
        @"circular",
        @"bezeled",
        @"visibleWhenStopped",
        @"value",
        @"min",
        @"max",
        @"indicatorSize",
        @"color",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
//     lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}
