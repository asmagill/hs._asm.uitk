@import Cocoa ;
@import LuaSkin ;

// TODO:
//     if (@available(macOS 11, *)) {
//         @property(copy) NSImageSymbolConfiguration *symbolConfiguration;
//         @property BOOL hasDestructiveAction;
//     }

static const char * const USERDATA_TAG = "hs._asm.uitk.element.button" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *BUTTON_STYLES ;
static NSDictionary *BEZEL_STYLES ;
static NSDictionary *IMAGE_POSITIONS ;
static NSDictionary *BUTTON_STATES ;
static NSDictionary *IMAGE_SCALING_TYPES ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaryies(void) {
    BUTTON_STYLES = @{
        @"momentaryLight"        : @(NSButtonTypeMomentaryLight),
        @"pushOnPushOff"         : @(NSButtonTypePushOnPushOff),
        @"toggle"                : @(NSButtonTypeToggle),
        @"switch"                : @(NSButtonTypeSwitch),
        @"radio"                 : @(NSButtonTypeRadio),
        @"momentaryChange"       : @(NSButtonTypeMomentaryChange),
        @"onOff"                 : @(NSButtonTypeOnOff),
        @"momentaryPushIn"       : @(NSButtonTypeMomentaryPushIn),
        @"accelerator"           : @(NSButtonTypeAccelerator),
        @"multiLevelAccelerator" : @(NSButtonTypeMultiLevelAccelerator),
    } ;


    BEZEL_STYLES = @{
        @"rounded"           : @(NSBezelStyleRounded),
        @"regularSquare"     : @(NSBezelStyleRegularSquare),
        @"disclosure"        : @(NSBezelStyleDisclosure),
        @"shadowlessSquare"  : @(NSBezelStyleShadowlessSquare),
        @"circular"          : @(NSBezelStyleCircular),
        @"texturedSquare"    : @(NSBezelStyleTexturedSquare),
        @"helpButton"        : @(NSBezelStyleHelpButton),
        @"smallSquare"       : @(NSBezelStyleSmallSquare),
        @"texturedRounded"   : @(NSBezelStyleTexturedRounded),
        @"roundRect"         : @(NSBezelStyleRoundRect),
        @"recessed"          : @(NSBezelStyleRecessed),
        @"roundedDisclosure" : @(NSBezelStyleRoundedDisclosure),
        @"inline"            : @(NSBezelStyleInline),
    } ;

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

    BUTTON_STATES = @{
        @"on"    : @(NSControlStateValueOn),
        @"off"   : @(NSControlStateValueOff),
        @"mixed" : @(NSControlStateValueMixed),
    } ;
}

@interface HSUITKElementButton : NSButton
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;
@end

@implementation HSUITKElementButton

- (void)commonInit {
    _callbackRef    = LUA_NOREF ;
    _refTable       = refTable ;
    _selfRefCount   = 0 ;

    self.target     = self ;
    self.action     = @selector(performCallback:) ;
    self.continuous = NO ;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    @try {
        self = [super initWithFrame:frameRect] ;
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:new - %@", USERDATA_TAG, exception.reason]] ;
        self = nil ;
    }

    if (self) [self commonInit] ;

    return self ;
}

+ (instancetype)buttonWithTitle:(NSString *)title {
    HSUITKElementButton *button = [HSUITKElementButton buttonWithTitle:title
                                                                  target:nil
                                                                  action:nil] ;

    if (button) [button commonInit] ;

    return button ;
}

+ (instancetype)buttonWithTitle:(NSString *)title withImage:(NSImage *)image {
    HSUITKElementButton *button = [HSUITKElementButton buttonWithTitle:title
                                                                   image:image
                                                                  target:nil
                                                                  action:nil] ;

    if (button) [button commonInit] ;

    return button ;
}

+ (instancetype)buttonWithImage:(NSImage *)image {
    HSUITKElementButton *button = [HSUITKElementButton buttonWithImage:image
                                                                  target:nil
                                                                  action:nil] ;

    if (button) [button commonInit] ;

    return button ;
}

+ (instancetype)checkboxWithTitle:(NSString *)title {
    HSUITKElementButton *button = [HSUITKElementButton checkboxWithTitle:title
                                                                    target:nil
                                                                    action:nil] ;

    if (button) [button commonInit] ;

    return button ;
}

+ (instancetype)radioButtonWithTitle:(NSString *)title {
    HSUITKElementButton *button = [HSUITKElementButton radioButtonWithTitle:title
                                                                       target:nil
                                                                       action:nil] ;

    if (button) [button commonInit] ;

    return button ;
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
        if (nextInChain) {
            SEL passthroughCallback = NSSelectorFromString(@"performPassthroughCallback:") ;
            if ([nextInChain respondsToSelector:passthroughCallback]) {
                [nextInChain performSelectorOnMainThread:passthroughCallback
                                              withObject:messageParts
                                           waitUntilDone:YES] ;
            }
        }
    }
}

- (void)performCallback:(__unused id)sender {
    BOOL isOn = (self.state != NSControlStateValueOff) ;
    [self callbackHamster:@[ self, @(isOn) ]] ;
}

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.button.buttonType(type, [frame]) -> buttonObject
/// Constructor
/// Creates a new button element of the specified type for `hs._asm.uitk.panel`.
///
/// Parameters:
///  * `button` - a string specifying the type of button to create. The string must be one of the following:
///    * "momentaryLight"        - When the button is clicked (on state), it appears illuminated. If the button has borders, it may also appear recessed. When the button is released, it returns to its normal (off) state. This type of button is best for simply triggering actions because it doesn’t show its state; it always displays its normal image or title.
///    * "pushOnPushOff"         - When the button is clicked (on state), it appears illuminated. If the button has borders, it may also appear recessed. A second click returns it to its normal (off) state.
///    * "toggle"                - After the first click, the button displays its alternate image or title (on state); a second click returns the button to its normal (off) state.
///    * "switch"                - This style is a variant of "toggle" that has no border and is typically used to represent a checkbox.
///    * "radio"                 - This style is similar to "switch", but it is used to constrain a selection to a single element from several elements.
///    * "momentaryChange"       - When the button is clicked, the alternate (on state) image and alternate title are displayed. Otherwise, the normal (off state) image and title are displayed.
///    * "onOff"                 - The first click highlights the button; a second click returns it to the normal (unhighlighted) state.
///    * "momentaryPushIn"       - When the user clicks the button (on state), the button appears illuminated. Most buttons in macOS, such as Cancel button in many dialogs, are momentary light buttons. If you click one, it highlights briefly, triggers an action, and returns to its original state.
///    * "accelerator"           - On pressure-sensitive systems, such as systems with the Force Touch trackpad, an accelerator button sends repeating actions as pressure changes occur. It stops sending actions when the user releases pressure entirely. Only available in macOS 10.12 and newer.
///    * "multiLevelAccelerator" - A multilevel accelerator button is a variation of a normal accelerator button that allows for a configurable number of stepped pressure levels. As each one is reached, the user receives light tactile feedback and an action is sent. Only available in macOS 10.12 and newer.
///  * `frame` - an optional frame table specifying the position and size of the frame for the button.
///
/// Returns:
///  * a new buttonObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a manager or to a `hs._asm.uitk.panel` window.
///
///  * See also:
///    * [hs._asm.uitk.element.button.buttonWithTitle](#buttonWithTitle)
///    * [hs._asm.uitk.element.button.buttonWithTitleAndImage](#buttonWithTitleAndImage)
///    * [hs._asm.uitk.element.button.buttonWithImage](#buttonWithImage)
///    * [hs._asm.uitk.element.button.checkbox](#checkbox)
///    * [hs._asm.uitk.element.button.radioButton](#radioButton)
static int button_newButtonType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSString *key = [skin toNSObjectAtIndex:1] ;
    NSNumber *buttonStyle = BUTTON_STYLES[key] ;
    if (buttonStyle) {
        NSRect frameRect = (lua_gettop(L) == 2) ? [skin tableToRectAtIndex:2] : NSZeroRect ;
        HSUITKElementButton *button = [[HSUITKElementButton alloc] initWithFrame:frameRect] ;
        if (button) {
            [button setButtonType:[buttonStyle unsignedIntegerValue]] ;
            button.action     = @selector(performCallback:) ;
            button.target     = button ;
            button.bezelStyle = NSBezelStyleRounded ;
            ((NSButtonCell *)button.cell).imageScaling = NSImageScaleProportionallyDown ;
            if (lua_gettop(L) != 2) [button setFrameSize:[button fittingSize]] ;
            [skin pushNSObject:button] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[BUTTON_STYLES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.button.buttonWithTitle(title) -> buttonObject
/// Constructor
/// Creates a new button element of the specified of type "momentaryPushIn" with the specified title for `hs._asm.uitk.panel`.
///
/// Parameters:
///  * `title` - the title which will be displayed in the button
///
/// Returns:
///  * a new buttonObject
///
/// Notes:
///  * This creates a standard macOS push button with the title centered within the button.
///  * The default frame created will be the minimum size necessary to display the button with its title. If you need to adjust the button's size further, do so with the element frame details options available once the button element is attached to a panel manager (see `hs._asm.uitk.panel.manager`)
///
///  * See also:
///    * [hs._asm.uitk.element.button.buttonType](#buttonType)
///    * [hs._asm.uitk.element.button.buttonWithTitleAndImage](#buttonWithTitleAndImage)
///    * [hs._asm.uitk.element.button.buttonWithImage](#buttonWithImage)
static int button_newButtonWithTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *title = [skin toNSObjectAtIndex:1] ;

    HSUITKElementButton *button = [HSUITKElementButton buttonWithTitle:title] ;

    if (button) {
        [skin pushNSObject:button] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.button.buttonWithTitleAndImage(title, image) -> buttonObject
/// Constructor
/// Creates a new button element of the specified of type "momentaryPushIn" with the specified title and image for `hs._asm.uitk.panel`.
///
/// Parameters:
///  * `title` - the title which will be displayed in the button
///  * `image` - the `hs.image` object specifying the image to display preceding the button title.
///
/// Returns:
///  * a new buttonObject
///
/// Notes:
///  * This creates a standard macOS push button with an image at the left and the title centered within the button.
///  * The default frame created will be the minimum size necessary to display the button with its image and title. If you need to adjust the button's size further, do so with the element frame details options available once the button element is attached to a panel manager (see `hs._asm.uitk.panel.manager`)
///
///  * See also:
///    * [hs._asm.uitk.element.button.buttonType](#buttonType)
///    * [hs._asm.uitk.element.button.buttonWithTitle](#buttonWithTitle)
///    * [hs._asm.uitk.element.button.buttonWithImage](#buttonWithImage)
static int button_newButtonWithTitleAndImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
    NSString *title = [skin toNSObjectAtIndex:1] ;
    NSImage  *image = [skin toNSObjectAtIndex:2] ;

    HSUITKElementButton *button = [HSUITKElementButton buttonWithTitle:title
                                                               withImage:image] ;

    if (button) {
        [skin pushNSObject:button] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.button.buttonWithImage(image) -> buttonObject
/// Constructor
/// Creates a new button element of the specified of type "momentaryPushIn" with the specified title for `hs._asm.uitk.panel`.
///
/// Parameters:
///  * `image` - the `hs.image` object specifying the image to display in the button.
///
/// Returns:
///  * a new buttonObject
///
/// Notes:
///  * This creates a standard macOS push button with the image centered within the button.
///  * The default frame created will be the minimum size necessary to display the button with the image. If you need to adjust the button's size further, do so with the element frame details options available once the button element is attached to a panel manager (see `hs._asm.uitk.panel.manager`)
///
///  * See also:
///    * [hs._asm.uitk.element.button.buttonType](#buttonType)
///    * [hs._asm.uitk.element.button.buttonWithTitle](#buttonWithTitle)
///    * [hs._asm.uitk.element.button.buttonWithTitleAndImage](#buttonWithTitleAndImage)
static int button_newButtonWithImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, "hs.image", LS_TBREAK] ;
    NSImage  *image = [skin toNSObjectAtIndex:1] ;

    HSUITKElementButton *button = [HSUITKElementButton buttonWithImage:image] ;

    if (button) {
        [skin pushNSObject:button] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.button.checkbox(title) -> buttonObject
/// Constructor
/// Creates a new checkbox button element of the specified of type "switch" with the specified title for `hs._asm.uitk.panel`.
///
/// Parameters:
///  * `title` - the title which will be displayed next to the checkbox
///
/// Returns:
///  * a new buttonObject
///
/// Notes:
///  * This creates a standard macOS checkbox with the title next to it.
///  * The default frame created will be the minimum size necessary to display the checkbox with its title. If you need to adjust the button's size further, do so with the element frame details options available once the button element is attached to a panel manager (see `hs._asm.uitk.panel.manager`)
///
///  * See also [hs._asm.uitk.element.button.buttonType](#buttonType)
static int button_newButtonWithCheckbox(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *title = [skin toNSObjectAtIndex:1] ;

    HSUITKElementButton *button = [HSUITKElementButton checkboxWithTitle:title] ;

    if (button) {
        [skin pushNSObject:button] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.button.radioButton(title) -> buttonObject
/// Constructor
/// Creates a new radio button element of the specified of type "radio" with the specified title for `hs._asm.uitk.panel`.
///
/// Parameters:
///  * `title` - the title which will be displayed next to the radio button
///
/// Returns:
///  * a new buttonObject
///
/// Notes:
///  * This creates a standard macOS radio button with the title next to it.
///    * Only one radio button in the same manager can be active (selected) at one time; multiple radio buttons in the same manager are treated as a content or set.
///    * To display multiple independent radio button sets in the same window or view (manager), each content must be in a separate `hs._asm.uitk.panel.manager` object and these separate objects may then be assigned as elements to a "parent" manager which is assigned to the `hs._asm.uitk.panel` window; alternatively use [hs._asm.uitk.element.button.radioButtonSet](#radioBUttonSet)
///
///  * The default frame created will be the minimum size necessary to display the checkbox with its title. If you need to adjust the button's size further, do so with the element frame details options available once the button element is attached to a panel manager (see `hs._asm.uitk.panel.manager`)
///
///  * See also:
///    * [hs._asm.uitk.element.button.radioButtonSet](#radioBUttonSet)
///    * [hs._asm.uitk.element.button.buttonType](#buttonType)
static int button_newButtonWithRadiobutton(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *title = [skin toNSObjectAtIndex:1] ;

    HSUITKElementButton *button = [HSUITKElementButton radioButtonWithTitle:title] ;

    if (button) {
        [skin pushNSObject:button] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

/// hs._asm.uitk.element.button:title([title] | [type]) -> buttonObject | string | hs.styledtext object
/// Method
/// Get or set the title displayed for the button
///
/// Parameters:
///  * to set the title:
///    * `title` - an optional string or `hs.styledtext` object specifying the title to set for the button.
///  * to get the current title:
///    * `type`  - an optional boolean, default false, specifying if the value retrieved should be as an `hs.styledtext` object (true) or as a string (false).
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
///
/// Notes:
///  * For buttons which change their appearance based upon their state, this is the title which will be displayed when the button is in its "off" state.
///
///  * The button constructors which allow specifying a title require a string; if you wish to change to a styled text object, you'll need to invoke this method on the new object after it is constructed.
static int button_title(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

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

/// hs._asm.uitk.element.button:alternateTitle([title] | [type]) -> buttonObject | string | hs.styledtext object
/// Method
/// Get or set the alternate title displayed by button types which support this
///
/// Parameters:
///  * to set the alternate title:
///    * `title` - an optional string or `hs.styledtext` object specifying the alternate title to set for the button.
///  * to get the current alternate title:
///    * `type`  - an optional boolean, default false, specifying if the value retrieved should be as an `hs.styledtext` object (true) or as a string (false).
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
///
/// Notes:
///  * For buttons which change their appearance based upon their state, this is the title which will be displayed when the button is in its "on" state.
///
///  * Observation shows that the alternateTitle value is used by the following button types:
///    * "toggle"          - the button will alternate between the title and the alternateTitle
///    * "momentaryChange" - if the button is not bordered, the alternate title will be displayed while the user is clicking on the button and will revert back to the title once the user has released the mouse button.
///    * "switch"          - when the checkbox is checked, it will display its alternateTitle, if one has been assigned
///    * "radio"           - when the radio button is selected, it will display its alternateTitle, if one has been assigned
///  * Other button types have not been observed to use this attribute; if you believe you have discovered something we have missed here, please submit an issue to the Hamemrspoon github web site.
static int button_alternateTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

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

/// hs._asm.uitk.element.button:bordered([state]) -> buttonObject | boolean
/// Method
/// Get or set whether a border is displayed around the button.
///
/// Parameters:
///  * `state` - an optional boolean specifying whether the button should display a border around the button area or not.
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
///
/// Notes:
///  * setting this to true for the "switch" or "radio" button types will prevent the alternate image, if defined, from being displayed.
static int button_bordered(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, button.bordered) ;
    } else {
        button.bordered = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.button:transparent([state]) -> buttonObject | boolean
/// Method
/// Get or set whether the button's background is transparent.
///
/// Parameters:
///  * `state` - an optional boolean specifying whether the button's background is transparent.
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
static int button_transparent(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, button.transparent) ;
    } else {
        button.transparent = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.button:borderOnHover([state]) -> buttonObject | boolean
/// Method
/// Get or set whether the button's border is toggled when the mouse hovers over the button
///
/// Parameters:
///  * `state` - an optional boolean specifying whether the button's border is toggled when the mouse hovers over the button
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
///
/// Notes:
///  * Has no effect on buttons of type "switch" or "radio"
///  * Changing this value will not affect whether or not the border is currently being displayed until the cursor actually hovers over the button or the button is clicked by the user. To keep the visual display in sync, make sure to set this value before displaying the panel (e.g. `hs._asm.uitk.panel:show()`) or set the border manually to the initial state you wish with [hs._asm.uitk.element.button:bordered](#bordered).
static int button_borderOnHover(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, button.showsBorderOnlyWhileMouseInside) ;
    } else {
        button.showsBorderOnlyWhileMouseInside = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.button:allowsMixedState([state]) -> buttonObject | boolean
/// Method
/// Get or set whether the button allows for a mixed state in addition to "on" and "off"
///
/// Parameters:
///  * `state` - an optional boolean specifying whether the button allows for a mixed state
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
///
/// Notes:
///  * Mixed state is typically useful only with buttons of type "switch" or "radio" and is primarily used to indicate that something is only applied partially, e.g. when part of a selection of text is bold but not all of it. When a checkbox or radio button is in the "mixed" state, it is displayed with a dash instead of an X or a filled in radio button.
///  * See also [hs._asm.uitk.element.button:state](#state)
static int button_allowsMixedState(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, button.allowsMixedState) ;
    } else {
        button.allowsMixedState = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.button:bezelStyle([style]) -> buttonObject | string
/// Method
/// Get or set the bezel style for the button
///
/// Parameters:
///  * `style` - an optional string specifying the bezel style for the button. Must be one of the following strings:
///    * "rounded"           - A rounded rectangle button, designed for text.
///    * "regularSquare"     - A rectangular button with a two-point border, designed for icons.
///    * "disclosure"        - A bezel style for use with a disclosure triangle. Works best with a button of type "onOff".
///    * "shadowlessSquare"  - Similar to "regularSquare", but has no shadow, so you can abut the buttons without overlapping shadows. This style would be used in a tool palette, for example.
///    * "circular"          - A round button with room for a small icon or a single character.
///    * "texturedSquare"    - A bezel style appropriate for use with textured (metal) windows.
///    * "helpButton"        - A round button with a question mark providing the standard help button look.
///    * "smallSquare"       - A simple square bezel style. Buttons using this style can be scaled to any size.
///    * "texturedRounded"   - A textured (metal) bezel style similar in appearance to the Finder’s action (gear) button.
///    * "roundRect"         - A bezel style that matches the search buttons in Finder and Mail.
///    * "recessed"          - A bezel style that matches the recessed buttons in Mail, Finder and Safari.
///    * "roundedDisclosure" - Similar to "disclosure", but appears as an up or down caret within a small rectangular button. Works best with a button of type "onOff".
///    * "inline"            - The inline bezel style contains a solid round-rect border background. It can be used to create an "unread" indicator in an outline view, or another inline button in a tableview, such as a stop progress button in a download panel. Use text for an unread indicator, and a template image for other buttons.
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
static int button_bezelStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *bezelStyle = @(button.bezelStyle) ;
        NSArray *temp = [BEZEL_STYLES allKeysForObject:bezelStyle];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized bezel style %@ -- notify developers", USERDATA_TAG, bezelStyle]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *bezelStyle = BEZEL_STYLES[key] ;
        if (bezelStyle) {
            button.bezelStyle = [bezelStyle unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[BEZEL_STYLES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.button:imagePosition([position]) -> buttonObject | string
/// Method
/// Get or set the position of the image relative to its title for the button
///
/// Parameters:
///  * `position` - an optional string specifying the position of the image relative to its title for the button. Must be one of the following strings:
///    * "none"     - The button doesn’t display an image.
///    * "only"     - The button displays an image, but not a title.
///    * "left"     - The image is to the left of the title.
///    * "right"    - The image is to the right of the title.
///    * "below"    - The image is below the title.
///    * "above"    - The image is above the title.
///    * "overlaps" - The image overlaps the title.
///
///    * "leading"  - The image leads the title as defined for the current language script direction. Available in macOS 10.12+.
///    * "trailing" - The image trails the title as defined for the current language script direction. Available in macOS 10.12+.
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
static int button_imagePosition(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

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
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[IMAGE_POSITIONS allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.button:imageScaling([scale]) -> buttonObject | string
/// Method
/// Get or set the scaling mode applied to the image for the button
///
/// Parameters:
///  * `scale` - an optional string specifying the scaling mode applied to the image for the button. Must be one of the following strings:
///    * "proportionallyDown"     - If it is too large for the destination, scale the image down while preserving the aspect ratio.
///    * "axesIndependently"      - Scale each dimension to exactly fit destination.
///    * "none"                   - Do not scale the image.
///    * "proportionallyUpOrDown" - Scale the image to its maximum possible dimensions while both staying within the destination area and preserving its aspect ratio.
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
static int button_imageScaling(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *imageScaling = @(((NSButtonCell *)button.cell).imageScaling) ;
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
            ((NSButtonCell *)button.cell).imageScaling = [imageScaling unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[IMAGE_SCALING_TYPES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.button:image([image]) -> buttonObject | hs.image object | nil
/// Method
/// Get or set the image displayed for the button
///
/// Parameters:
///  * `image` - an optional hs.image object, or explicit nil to remove, specifying the image for the button.
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
///
/// Notes:
///  * For buttons which change their appearance based upon their state, this is the image which will be displayed when the button is in its "off" state.
static int button_image(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

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

/// hs._asm.uitk.element.button:sound([sound]) -> buttonObject | hs.sound object | nil
/// Method
/// Get or set the sound played when the user clicks on the button
///
/// Parameters:
///  * `sound` - an optional hs.sound object, or explicit nil to remove, specifying the sound played when the user clicks on the button
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
static int button_sound(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

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

/// hs._asm.uitk.element.button:alternateImage([image]) -> buttonObject | hs.image object | nil
/// Method
/// Get or set the alternate image displayed by button types which support this
///
/// Parameters:
///  * `image` - an optional hs.image object, or explicit nil to remove, specifying the alternate image for the button.
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
///
/// Notes:
///  * For buttons which change their appearance based upon their state, this is the image which will be displayed when the button is in its "on" state.
///
///  * Observation shows that the alternateImage value is used by the following button types:
///    * "toggle"          - the button will alternate between the image and the alternateImage
///    * "momentaryChange" - if the button is not bordered, the alternate image will be displayed while the user is clicking on the button and will revert back to the image once the user has released the mouse button.///    * "switch"               - when the checkbox is checked, it will display its alternateImage as the checked box, if one has been assigned
///    * "radio"           - when the radio button is selected, it will display its alternateImage as the filled in radio button, if one has been assigned
///  * Other button types have not been observed to use this attribute; if you believe you have discovered something we have missed here, please submit an issue to the Hamemrspoon github web site.
static int button_alternateImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

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

/// hs._asm.uitk.element.button:state([state]) -> buttonObject | string
/// Method
/// Get or set the current state of the button.
///
/// Parameters:
///  * `state` - an optional string used to set the current state of the button. Must be one of "on", "off", or "mixed".
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
///
/// Notes:
///  * Setting the state to "mixed" is only valid when [hs._asm.uitk.element.button:allowsMixedState](#allowsMixedState) is set to true.
///  * Mixed state is typically useful only with buttons of type "switch" or "radio" and is primarily used to indicate that something is only applied partially, e.g. when part of a selection of text is bold but not all of it. When a checkbox or radio button is in the "mixed" state, it is displayed with a dash instead of an X or a filled in radio button.
static int button_state(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *state = @(button.state) ;
        NSArray *temp = [BUTTON_STATES allKeysForObject:state];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized button state %@ -- notify developers", USERDATA_TAG, state]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        if ([key isEqualToString:@"next"]) {
            [button setNextState] ;
        } else {
            NSNumber *state = BUTTON_STATES[key] ;
            if (state) {
                button.state = [state integerValue] ;
            } else {
                return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@, or next", [[BUTTON_STATES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
            }
            lua_pushvalue(L, 1) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.button:highlighted([state]) -> buttonObject | boolean
/// Method
/// Get or set whether the button is currently highlighted.
///
/// Parameters:
///  * `state` - an optional boolean specifying whether or not the button is currently highlighted.
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
///
/// Notes:
///  * Highlighting makes the button appear recessed, displays its alternate title or image, or causes the button to appear illuminated.
static int button_highlighted(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementButton *button = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, button.highlighted) ;
    } else {
        [button highlight:(BOOL)(lua_toboolean(L, 2))] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}
/// hs._asm.uitk.element.button:value([float]) -> integer | double
/// Method
/// Get the current value represented by the button's state
///
/// Parameters:
///  * `float` - an optional boolean specifying whether or not the value should be returned as a number (true) or as an integer (false). Defaults to false.
///
/// Returns:
///  * The current value of the button as represented by its state.
///
/// Notes:
///  * In general, this method will return 0 when the button's state is "off" and 1 when the button's state is "on" -- see [hs._asm.uitk.element.button:state](#state).
///  * If [hs._asm.uitk.element.button:allowsMixedState](#allowsMixedState) has been set to true for this button, this method will return -1 when the button's state is "mixed".
///
///  * If the button is of the "accelerator" type and the user is using a Force Touch capable trackpad, you can pass `true` to this method to get a relative measure of the amount of pressure being applied; this method will return a number between 1.0 and 2.0 representing the amount of pressure being applied when `float` is set to true.  If `float` is false or left out, then an "accelerator" type button will just return 1 as long as any pressure is being applied to the button.
///
///  * If the button is of the "multiLevelAccelerator" type and the user is using a Force Touch capable trackpad, this method will return a number between 0 (not being pressed) up to the value set for [hs._asm.uitk.element.button:maxAcceleratorLevel](#maxAcceleratorLevel), depending upon how much pressure is being applied to the button.
static int button_value(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if ((lua_type(L, 2) == LUA_TBOOLEAN) && lua_toboolean(L, 2)) {
        lua_pushnumber(L, [button doubleValue]) ;
    } else {
        lua_pushinteger(L, [button integerValue]) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.button:maxAcceleratorLevel([level]) -> buttonObject | integer
/// Method
/// Get or set the number of discrete pressure levels recognized by a button of type "multiLevelAccelerator"
///
/// Parameters:
///  * `level` - an optional integer specifying the number of discrete pressure levels recognized by a button of type "multiLevelAccelerator". Must be an integer between 1 and 5 inclusive.
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
///
/// Notes:
///  * This method and the "multiLevelAccelerator" button type are only supported in macOS 10.12 and newer.
static int button_maxAcceleratorLevel(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, button.maxAcceleratorLevel) ;
    } else {
        lua_Integer level = lua_tointeger(L, 2) ;
        if (level < 1 || level > 5) {
            return luaL_argerror(L, 2, "must be an integer between 1 and 5 inclusive") ;
        }
        button.maxAcceleratorLevel = level ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static float fclamp(float d, float min, float max) {
  const float t = d < min ? min : d;
  return t > max ? max : t;
}

/// hs._asm.uitk.element.button:periodicDelay([table]) -> buttonObject | table
/// Method
/// Get or set the delay and interval periods for the callbacks of a continuous button.
///
/// Parameters:
///  * `table` - an optional table specifying the delay and interval periods for the callbacks of a continuous button. The default is { 0.4, 0.075 }.
///
/// Returns:
///  * if a value is provided, returns the buttonObject ; otherwise returns the current value.
///
/// Notes:
///  * To make a button continuous, see `hs._asm.uitk.element._control:continuous`. By default, buttons are *not* continuous.
///
///  * The table passed in as an argument or returned by this method should contain two numbers:
///    * the delay in seconds before the callback will be first invoked for the continuous button
///    * the interval in seconds between subsequent callbacks after the first one has been invoked.
///  * Once the user releases the mouse button, a final callback will be invoked for the button and will reflect the new [hs._asm.uitk.element.button:state](#state) for the button.
static int button_periodicDelay(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        float delay    = 0.0f ;
        float interval = 0.0f ;
        [button getPeriodicDelay:&delay interval:&interval] ;
        lua_newtable(L) ;
        lua_pushnumber(L, (lua_Number)delay) ;    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushnumber(L, (lua_Number)interval) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    } else {
        float delay    = 0.4f ;
        float interval = 0.075f ;
        if (lua_geti(L, 2, 1) == LUA_TNUMBER) {
            delay = fclamp((float)lua_tonumber(L, -1), 0.0, 60.0) ;
        } else if (lua_type(L, -1) != LUA_TNIL) {
            return luaL_argerror(L, 2, "expected number for delay at index position 1") ;
        }
        lua_pop(L, 1) ;
        if (lua_geti(L, 2, 2) == LUA_TNUMBER) {
            interval = fclamp((float)lua_tonumber(L, -1), 0.0, 60.0) ;
        } else if (lua_type(L, -1) != LUA_TNIL) {
            return luaL_argerror(L, 2, "expected number for interval at index position 2") ;
        }
        lua_pop(L, 1) ;
        [button setPeriodicDelay:delay interval:interval] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementButton(lua_State *L, id obj) {
    HSUITKElementButton *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementButton *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementButtonFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementButton *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementButton, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"title",               button_title},
    {"alternateTitle",      button_alternateTitle},
    {"bordered",            button_bordered},
    {"transparent",         button_transparent},
    {"borderOnHover",       button_borderOnHover},
    {"allowsMixedState",    button_allowsMixedState},
    {"bezelStyle",          button_bezelStyle},
    {"image",               button_image},
    {"alternateImage",      button_alternateImage},
    {"imagePosition",       button_imagePosition},
    {"imageScaling",        button_imageScaling},
    {"state",               button_state},
    {"highlighted",         button_highlighted},
    {"sound",               button_sound},
    {"value",               button_value},
    {"maxAcceleratorLevel", button_maxAcceleratorLevel},
    {"periodicDelay",       button_periodicDelay},

// other metamethods inherited from _control and _view
    {NULL,    NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"buttonType",              button_newButtonType},
    {"buttonWithTitle",         button_newButtonWithTitle},
    {"buttonWithTitleAndImage", button_newButtonWithTitleAndImage},
    {"buttonWithImage",         button_newButtonWithImage},
    {"checkbox",                button_newButtonWithCheckbox},
    {"radioButton",             button_newButtonWithRadiobutton},
    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_libelement_button(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaryies() ;

    [skin registerPushNSHelper:pushHSUITKElementButton         forClass:"HSUITKElementButton"];
    [skin registerLuaObjectHelper:toHSUITKElementButtonFromLua forClass:"HSUITKElementButton"
                                                     withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through content metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"title",
        @"alternateTitle",
        @"bordered",
        @"transparent",
        @"borderOnHover",
        @"allowsMixedState",
        @"bezelStyle",
        @"imagePosition",
        @"imageScaling",
        @"image",
        @"sound",
        @"alternateImage",
        @"state",
        @"periodicDelay",
        @"highlighted",
        @"maxAcceleratorLevel",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}
