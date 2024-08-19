@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.window" ;
static LSRefTable         refTable     = LUA_NOREF ;

static NSArray *windowNotifications ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *TOOLBAR_STYLES ;
static NSDictionary *WINDOW_APPEARANCES ;
static NSDictionary *ANIMATION_BEHAVIORS ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    if (@available(macOS 11.0, *)) {
        TOOLBAR_STYLES = @{
            @"automatic"      : @(NSWindowToolbarStyleAutomatic),
            @"expanded"       : @(NSWindowToolbarStyleExpanded),
            @"preference"     : @(NSWindowToolbarStylePreference),
            @"unified"        : @(NSWindowToolbarStyleUnified),
            @"unifiedCompact" : @(NSWindowToolbarStyleUnifiedCompact),
        } ;
    }

    WINDOW_APPEARANCES = @{
        @"aqua"                 : NSAppearanceNameAqua,
        @"darkAqua"             : NSAppearanceNameDarkAqua,
        @"light"                : NSAppearanceNameVibrantLight,
        @"dark"                 : NSAppearanceNameVibrantDark,
        @"highContrastAqua"     : NSAppearanceNameAccessibilityHighContrastAqua,
        @"highContrastDarkAqua" : NSAppearanceNameAccessibilityHighContrastDarkAqua,
        @"highContrastLight"    : NSAppearanceNameAccessibilityHighContrastVibrantLight,
        @"highContrastDark"     : NSAppearanceNameAccessibilityHighContrastVibrantDark
    } ;

    ANIMATION_BEHAVIORS = @{
        @"default"        : @(NSWindowAnimationBehaviorDefault),
        @"none"           : @(NSWindowAnimationBehaviorNone),
        @"documentWindow" : @(NSWindowAnimationBehaviorDocumentWindow),
        @"utilityWindow"  : @(NSWindowAnimationBehaviorUtilityWindow),
        @"alertPanel"     : @(NSWindowAnimationBehaviorAlertPanel),
    } ;
}

BOOL oneOfOurElementObjects(NSView *obj) {
    return [obj isKindOfClass:[NSView class]]  &&
           [obj respondsToSelector:NSSelectorFromString(@"selfRefCount")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setSelfRefCount:")] &&
           [obj respondsToSelector:NSSelectorFromString(@"refTable")] &&
           [obj respondsToSelector:NSSelectorFromString(@"callbackRef")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setCallbackRef:")] ;
}

static inline NSRect RectWithFlippedYCoordinate(NSRect theRect) {
    return NSMakeRect(theRect.origin.x,
                      [[NSScreen screens][0] frame].size.height - theRect.origin.y - theRect.size.height,
                      theRect.size.width,
                      theRect.size.height) ;
}

@interface NSToolbar (Hammerspoon)
@property (weak)     NSWindow            *window ;

- (NSWindow *)window ;
- (void)setWindow:(NSWindow *)window ;
@end

@interface HSUITKWindow : NSPanel <NSWindowDelegate>
@property        int          selfRefCount ;
@property        BOOL         allowKeyboardEntry ;
@property        BOOL         closeOnEscape ;
@property        int          passthroughCallbackRef ;
@property        int          notificationCallback ;
@property        NSNumber     *animationTime ;
@property        NSMutableSet *notifyFor ;
@property (weak) NSResponder  *lastFirstResponder ;
@end

@implementation HSUITKWindow
- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)windowStyle {
    if (!(isfinite(contentRect.origin.x) && isfinite(contentRect.origin.y) && isfinite(contentRect.size.height) && isfinite(contentRect.size.width))) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:coordinates must be finite numbers", USERDATA_TAG]] ;
        self = nil ;
    } else {
        self = [super initWithContentRect:contentRect
                                styleMask:windowStyle
                                  backing:NSBackingStoreBuffered
                                    defer:YES] ;
    }

    if (self) {
        contentRect = RectWithFlippedYCoordinate(contentRect) ;
        [self setFrameOrigin:contentRect.origin] ;

        self.autorecalculatesKeyViewLoop      = YES ;
        self.releasedWhenClosed               = NO ;
        self.ignoresMouseEvents               = NO ;
        self.restorable                       = NO ;
        self.hidesOnDeactivate                = NO ;
        self.animationBehavior                = NSWindowAnimationBehaviorNone ;
        self.level                            = NSNormalWindowLevel ;
        self.displaysWhenScreenProfileChanges = YES ;

        _selfRefCount           = 0 ;
        _passthroughCallbackRef = LUA_NOREF ;
        _notificationCallback   = LUA_NOREF ;
        _allowKeyboardEntry     = YES ;
        _closeOnEscape          = NO ;
        _animationTime          = nil ;
        _lastFirstResponder     = nil ;
        _notifyFor              = [[NSMutableSet alloc] initWithArray:@[
                                                                          @"willClose",
                                                                          @"didBecomeKey",
                                                                          @"didResignKey",
                                                                          @"didResize",
                                                                          @"didMove",
                                                                      ]] ;
        self.delegate           = self ;
    }
    return self ;
}

// - (void)dealloc {
//     NSLog(@"%s dealloc invoked", USERDATA_TAG) ;
// }

// perform callback for subviews which don't have a callback defined; see button.m for how to allow this chaining
- (void)performPassthroughCallback:(NSArray *)arguments {
    if (_passthroughCallbackRef != LUA_NOREF) {
        LuaSkin *skin    = [LuaSkin sharedWithState:NULL] ;
        int     argCount = 1 ;

        [skin pushLuaRef:refTable ref:_passthroughCallbackRef] ;
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
    }
}

- (NSTimeInterval)animationResizeTime:(NSRect)newWindowFrame {
    if (_animationTime) {
        return [_animationTime doubleValue] ;
    } else {
        return [super animationResizeTime:newWindowFrame] ;
    }
}

// see canvas version if we need to do something a little more complex and check views/subviews
- (BOOL)canBecomeKeyWindow {
    return _allowKeyboardEntry ;
}

- (BOOL)canBecomeMainWindow {
    return _allowKeyboardEntry ;
}

#pragma mark * Custom for Hammerspoon

- (void)fadeIn:(NSTimeInterval)fadeTime {
    CGFloat alphaSetting = self.alphaValue ;
    [self setAlphaValue:0.0] ;
    [self makeKeyAndOrderFront:nil] ;
    [NSAnimationContext beginGrouping] ;
        [[NSAnimationContext currentContext] setDuration:fadeTime] ;
        [[self animator] setAlphaValue:alphaSetting] ;
    [NSAnimationContext endGrouping] ;
}

- (void)fadeOut:(NSTimeInterval)fadeTime andClose:(BOOL)closeWindow {
    CGFloat alphaSetting = self.alphaValue ;
    [NSAnimationContext beginGrouping] ;
      __weak HSUITKWindow *bself = self ;
      [[NSAnimationContext currentContext] setDuration:fadeTime] ;
      [[NSAnimationContext currentContext] setCompletionHandler:^{
          // unlikely that bself will go to nil after this starts, but this keeps the
          // warnings down from [-Warc-repeated-use-of-weak]
          HSUITKWindow *mySelf = bself ;
          if (mySelf) {
              if (closeWindow) {
                  [mySelf close] ; // trigger callback, if set, then cleanup
              } else {
                  [mySelf orderOut:mySelf] ;
                  [mySelf setAlphaValue:alphaSetting] ;
              }
          }
      }] ;
      [[self animator] setAlphaValue:0.0] ;
    [NSAnimationContext endGrouping] ;
}

#pragma mark * NSStandardKeyBindingResponding protocol methods

- (void)cancelOperation:(id)sender {
    if (_closeOnEscape) [super cancelOperation:sender] ;
}

#pragma mark * NSWindowDelegate protocol methods

// - (BOOL)window:(NSWindow *)window shouldDragDocumentWithEvent:(NSEvent *)event from:(NSPoint)dragImageLocation withPasteboard:(NSPasteboard *)pasteboard ;
// - (BOOL)window:(NSWindow *)window shouldPopUpDocumentPathMenu:(NSMenu *)menu ;
// - (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)client ;
// - (NSApplicationPresentationOptions)window:(NSWindow *)window willUseFullScreenPresentationOptions:(NSApplicationPresentationOptions)proposedOptions ;
// - (NSArray<NSWindow *> *)customWindowsToEnterFullScreenForWindow:(NSWindow *)window onScreen:(NSScreen *)screen ;
// - (NSArray<NSWindow *> *)customWindowsToEnterFullScreenForWindow:(NSWindow *)window ;
// - (NSArray<NSWindow *> *)customWindowsToExitFullScreenForWindow:(NSWindow *)window ;
// - (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect ;
// - (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)newFrame ;
// - (NSSize)window:(NSWindow *)window willResizeForVersionBrowserWithMaxPreferredSize:(NSSize)maxPreferredFrameSize maxAllowedSize:(NSSize)maxAllowedFrameSize ;
// - (NSSize)window:(NSWindow *)window willUseFullScreenContentSize:(NSSize)proposedSize ;
// - (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize ;
// - (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window ;
// - (BOOL)windowShouldZoom:(NSWindow *)window toFrame:(NSRect)newFrame {}

// - (void)window:(NSWindow *)window didDecodeRestorableState:(NSCoder *)state ;
// - (void)window:(NSWindow *)window startCustomAnimationToEnterFullScreenOnScreen:(NSScreen *)screen withDuration:(NSTimeInterval)duration ;
// - (void)window:(NSWindow *)window startCustomAnimationToEnterFullScreenWithDuration:(NSTimeInterval)duration ;
// - (void)window:(NSWindow *)window startCustomAnimationToExitFullScreenWithDuration:(NSTimeInterval)duration ;
// - (void)window:(NSWindow *)window willEncodeRestorableState:(NSCoder *)state ;

- (BOOL)windowShouldClose:(__unused NSWindow *)sender {
    if ((self.styleMask & NSWindowStyleMaskClosable) != 0) {
        return YES ;
    } else {
        return NO ;
    }
}

- (void)performNotificationCallbackFor:(NSString *)message with:(NSNotification *)notification {
    if (_notificationCallback != LUA_NOREF && [_notifyFor containsObject:message]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->_notificationCallback != LUA_NOREF) {
                LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
                [skin pushLuaRef:refTable ref:self->_notificationCallback] ;
// TODO: should be the window object itself, but need to test for all of them as the docs only mention it for some of the delegate calls
                [skin pushNSObject:notification.object] ;
                [skin pushNSObject:message] ;
                [skin pushNSObject:notification.userInfo] ;
                if (![skin protectedCallAndTraceback:3 nresults:0]) {
                    NSString *errorMsg = [skin toNSObjectAtIndex:-1] ;
                    lua_pop([skin L], 1) ;
                    [skin logError:[NSString stringWithFormat:@"%s:%@ notification callback error:%@", USERDATA_TAG, message, errorMsg]] ;
                }
            }
        }) ;
    }
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    NSResponder *lastFirstResponder = _lastFirstResponder ;
    if (lastFirstResponder) [self makeFirstResponder:lastFirstResponder] ;
    _lastFirstResponder = nil ;
    [self performNotificationCallbackFor:@"didBecomeKey" with:notification] ;
}
- (void)windowDidBecomeMain:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didBecomeMain" with:notification] ;
}
- (void)windowDidChangeBackingProperties:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didChangeBackingProperties" with:notification] ;
}
- (void)windowDidChangeOcclusionState:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didChangeOcclusionState" with:notification] ;
}
- (void)windowDidChangeScreen:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didChangeScreen" with:notification] ;
}
- (void)windowDidChangeScreenProfile:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didChangeScreenProfile" with:notification] ;
}
- (void)windowDidDeminiaturize:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didDeminiaturize" with:notification] ;
}
- (void)windowDidEndLiveResize:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didEndLiveResize" with:notification] ;
}
- (void)windowDidEndSheet:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didEndSheet" with:notification] ;
}
- (void)windowDidEnterFullScreen:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didEnterFullScreen" with:notification] ;
}
- (void)windowDidEnterVersionBrowser:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didEnterVersionBrowser" with:notification] ;
}
- (void)windowDidExitFullScreen:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didExitFullScreen" with:notification] ;
}
- (void)windowDidExitVersionBrowser:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didExitVersionBrowser" with:notification] ;
}
- (void)windowDidExpose:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didExpose" with:notification] ;
}
- (void)windowDidMiniaturize:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didMiniaturize" with:notification] ;
}
- (void)windowDidMove:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didMove" with:notification] ;
}
- (void)windowDidResignKey:(NSNotification *)notification {
    _lastFirstResponder = self.firstResponder ;
    [self makeFirstResponder:nil] ;
    [self performNotificationCallbackFor:@"didResignKey" with:notification] ;
}
- (void)windowDidResignMain:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didResignMain" with:notification] ;
}
- (void)windowDidResize:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didResize" with:notification] ;
}
- (void)windowDidUpdate:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"didUpdate" with:notification] ;
}
- (void)windowWillBeginSheet:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willBeginSheet" with:notification] ;
}
- (void)windowWillClose:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willClose" with:notification] ;
}
- (void)windowWillEnterFullScreen:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willEnterFullScreen" with:notification] ;
}
- (void)windowWillEnterVersionBrowser:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willEnterVersionBrowser" with:notification] ;
}
- (void)windowWillExitFullScreen:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willExitFullScreen" with:notification] ;
}
- (void)windowWillExitVersionBrowser:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willExitVersionBrowser" with:notification] ;
}
- (void)windowWillMiniaturize:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willMiniaturize" with:notification] ;
}
- (void)windowWillMove:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willMove" with:notification] ;
}
- (void)windowWillStartLiveResize:(NSNotification *)notification {
    [self performNotificationCallbackFor:@"willStartLiveResize" with:notification] ;
}

- (void)windowDidFailToEnterFullScreen:(NSWindow *)window {
    [self performNotificationCallbackFor:@"didFailToEnterFullScreen"
                                    with:[NSNotification notificationWithName:@"didFailToEnterFullScreen"
                                                                       object:window]] ;
}
- (void)windowDidFailToExitFullScreen:(NSWindow *)window {
    [self performNotificationCallbackFor:@"didFailToExitFullScreen"
                                    with:[NSNotification notificationWithName:@"didFailToExitFullScreen"
                                                                       object:window]] ;
}

@end

static NSWindowStyleMask defaultWindowMask = NSWindowStyleMaskTitled         |
                                             NSWindowStyleMaskClosable       |
                                             NSWindowStyleMaskResizable      |
                                             NSWindowStyleMaskMiniaturizable ;

static int window_orderHelper(lua_State *L, NSWindowOrderingMode mode) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;
    NSInteger relativeTo = 0 ;

    if (lua_gettop(L) > 1) {
        if (lua_type(L, 2) == LUA_TNIL) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNIL, LS_TBREAK] ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                            LS_TUSERDATA, USERDATA_TAG,
                            LS_TBREAK] ;
            HSUITKWindow *otherWindow = [skin toNSObjectAtIndex:2] ;
            if (otherWindow) relativeTo = [otherWindow windowNumber] ;
        }
    }
    if (window) [window orderWindow:mode relativeTo:relativeTo] ;
    return 1 ;
}

#pragma mark - Module Functions -

/// hs._asm.uitk.window.uitk.window.minimumWidth(title, [styleMask]) -> number
/// Function
/// Returns the minimum width to fully show a window with the given title and style mask.
///
/// Parameters:
///  * `title`     - the proposed title for the window
///  * `styleMask` - an optional integer specifying the style mask for the window as a combination of logically or'ed values from the [hs._asm.uitk.window.masks](#masks) table.  Defaults to `titled | closable | resizable | miniaturizable` (a standard macOS window with the appropriate titlebar and decorations).
///
/// Returns:
///  * the width for the window to fully display the given title with the specified window style.
///
/// Notes:
///  * this width is just a suggestion -- you can still create the window with a smaller width, but the title may be truncated or not visible.
static int window_minFrameWidthWithTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    NSString   *title = [skin toNSObjectAtIndex:1] ;
    NSUInteger style  = (lua_gettop(L) == 2) ? (NSUInteger)lua_tointeger(L, 2) : defaultWindowMask ;

    lua_pushnumber(L, [NSWindow minFrameWidthWithTitle:title styleMask:style]) ;
    return 1 ;
}

/// hs._asm.uitk.window.uitk.contentRectForFrame(rect, [styleMask]) -> number
/// Function
/// Returns a rect table with the height and width available for content (elements) in a window with the given size and style mask.
///
/// Parameters:
///  * `rect`      - a rect-table specifying the initial location and size of the window.
///  * `styleMask` - an optional integer specifying the style mask for the window as a combination of logically or'ed values from the [hs._asm.uitk.window.masks](#masks) table.  Defaults to `titled | closable | resizable | miniaturizable` (a standard macOS window with the appropriate titlebar and decorations).
///
/// Returns:
///  * a rect table, in screen coordinates, specifying the height and width of the area available for content (elements) in a window with the specified frame and style mask.
///
///  * if you leave out the `x` and `y` keys (i.e. use a size table) for `rect`, the result will assign 0 to the `x` and `y` keys in the return value.
static int window_contentRectForFrameRect(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    NSRect     fRect  = [skin tableToRectAtIndex:1] ;
    NSUInteger style  = (lua_gettop(L) == 2) ? (NSUInteger)lua_tointeger(L, 2) : defaultWindowMask ;

    [skin pushNSRect:[NSWindow contentRectForFrameRect:fRect styleMask:style]] ;
    return 1 ;
}

/// hs._asm.uitk.window.uitk.frameRectForContent(rect, [styleMask]) -> number
/// Function
/// Returns a rect table with the height and width a window would require to fully display content (elements) with the given size in a window with the specified style mask.
///
/// Parameters:
///  * `rect`      - a rect-table specifying the initial location and size of the content.
///  * `styleMask` - an optional integer specifying the style mask for the window as a combination of logically or'ed values from the [hs._asm.uitk.window.masks](#masks) table.  Defaults to `titled | closable | resizable | miniaturizable` (a standard macOS window with the appropriate titlebar and decorations).
///
/// Returns:
///  * a rect table, in screen coordinates, specifying the the height and width of the window necessary for the content size.
///
///  * if you leave out the `x` and `y` keys (i.e. use a size table) for `rect`, the result will assign 0 to the `x` and `y` keys in the return value.
static int window_frameRectForContentRect(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    NSRect     cRect  = [skin tableToRectAtIndex:1] ;
    NSUInteger style  = (lua_gettop(L) == 2) ? (NSUInteger)lua_tointeger(L, 2) : defaultWindowMask ;

    [skin pushNSRect:[NSWindow frameRectForContentRect:cRect styleMask:style]] ;
    return 1 ;
}

/// hs._asm.uitk.window.new(rect, [styleMask]) -> windowObject
/// Constructor
/// Creates a new empty window.
///
/// Parameters:
///  * `rect`      - a rect-table specifying the initial location and size of the window.
///  * `styleMask` - an optional integer specifying the style mask for the window as a combination of logically or'ed values from the [hs._asm.uitk.window.masks](#masks) table.  Defaults to `titled | closable | resizable | miniaturizable` (a standard macOS window with the appropriate titlebar and decorations).
///
/// Returns:
///  * the window object, or nil if there was an error creating the window.
///
/// Notes:
///  * a rect-table is a table with key-value pairs specifying the top-left coordinate on the screen of the window (keys `x`  and `y`) and the size (keys `h` and `w`). The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
///
///  * the window will have an initial content element of `hs._asm.uitk.element.container`, to which other elements can be assigned. See [hs._asm.uitk.window:content](#content).
static int window_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;

    NSUInteger windowStyle = (lua_gettop(L) == 2) ? (NSUInteger)lua_tointeger(L, 2) : defaultWindowMask ;

    HSUITKWindow *window = [[HSUITKWindow alloc] initWithContentRect:[skin tableToRectAtIndex:1]
                                                             styleMask:windowStyle] ;
    if (window) {
        [skin pushNSObject:window] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

/// hs._asm.uitk.window:allowTextEntry([value]) -> windowObject | boolean
/// Method
/// Get or set whether or not the window object can accept keyboard entry. Defaults to true.
///
/// Parameters:
///  * `value` - an optional boolean, default true, which sets whether or not the window will accept keyboard input.
///
/// Returns:
///  * If a value is provided, then this method returns the window object; otherwise the current value
///
/// Notes:
///  * Most controllable elements require keybaord focus even if they do not respond directly to keyboard input.
static int window_allowTextEntry(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.allowKeyboardEntry) ;
    } else {
        window.allowKeyboardEntry = (BOOL)(lua_toboolean(L, 2)) ;
        lua_settop(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.window:alpha([alpha]) -> windowObject | number
/// Method
/// Get or set the alpha level of the window representing the window object.
///
/// Parameters:
///  * `alpha` - an optional number, default 1.0, specifying the alpha level (0.0 - 1.0, inclusive) for the window.
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
static int window_alphaValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, window.alphaValue) ;
    } else {
        CGFloat newAlpha = luaL_checknumber(L, 2);
        window.alphaValue = ((newAlpha < 0.0) ? 0.0 : ((newAlpha > 1.0) ? 1.0 : newAlpha)) ;
        lua_pushvalue(L, 1);
    }
    return 1 ;
}

/// hs._asm.uitk.window:backgroundColor([color]) -> windowObject | color table
/// Method
/// Get or set the color for the background of window.
///
/// Parameters:
/// * `color` - an optional table containing color keys as described in `hs.drawing.color`
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
static int window_backgroundColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:window.backgroundColor] ;
    } else {
        window.backgroundColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.window:hasShadow([state]) -> windowObject | boolean
/// Method
/// Get or set whether the window displays a shadow.
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether or not the window draws a shadow.
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
static int window_hasShadow(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.hasShadow) ;
    } else {
        window.hasShadow = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.window:opaque([state]) -> windowObject | bool
/// Method
/// Get or set whether the window is opaque.
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether or not the window is opaque.
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
static int window_opaque(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.opaque) ;
    } else {
        window.opaque = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.window:ignoresMouseEvents([state]) -> windowObject | bool
/// Method
/// Get or set whether the window ignores mouse events.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not the window receives mouse events.
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
///
/// Notes:
///  * Setting this to true will prevent elements in the window from receiving mouse button events or mouse movement events which affect the focus of the window or its elements. For elements which accept keyboard entry, this *may* also prevent the user from focusing the element for keyboard input unless the element is focused programmatically with [hs._asm.uitk.window:activeElement](#activeElement).
///  * Mouse tracking events (see `hs._asm.uitk.element.container:mouseCallback`) will still occur, even if this is true; however if two windows at the same level (see [hs._asm.uitk.window:level](#level)) both occupy the current mouse location and one or both of the windows have this attribute set to false, spurious and unpredictable mouse callbacks may occur as the "frontmost" window changes based on which is acting on the event at that instant in time.
static int window_ignoresMouseEvents(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.ignoresMouseEvents) ;
    } else {
        window.ignoresMouseEvents = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_styleMask(lua_State *L) {
// NOTE:  This method is wrapped in window.lua
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    NSString   *theTitle = window.title ;     // NSPanel resets title when style changes
    NSUInteger oldStyle  = window.styleMask ; // in case we have to reset it

    if (lua_type(L, 2) == LUA_TNONE) {
        lua_pushinteger(L, (lua_Integer)oldStyle) ;
    } else {
        // ??? can we determine this through logic or do we have to use try/catch?
        @try {
            window.styleMask = 0 ;  // some styles don't get properly set unless we start from a clean slate
            window.styleMask = (NSUInteger)luaL_checkinteger(L, 2) ;
            if (theTitle) window.title = theTitle ;
        }
        @catch (NSException *exception) {
            window.styleMask = oldStyle ;
            if (theTitle) window.title = theTitle ;
            NSString *errMsg = [NSString stringWithFormat:@"invalid style mask: %@, %@", exception.name, exception.reason] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_settop(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.window:title([title]) -> windowObject | string
/// Method
/// Get or set the window's title.
///
/// Parameters:
///  * `title` - an optional string specifying the title to assign to the window.
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
static int window_title(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
      [skin pushNSObject:window.title] ;
    } else {
        window.title = [skin toNSObjectAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.window:titlebarAppearsTransparent([state]) -> windowObject | boolean
/// Method
/// Get or set whether the window's title bar draws its background.
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether or not the window's title bar draws its background.
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
static int window_titlebarAppearsTransparent(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.titlebarAppearsTransparent) ;
    } else {
        window.titlebarAppearsTransparent = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.window:titleVisibility([state]) -> windowObject | boolean
/// Method
/// Get or set whether or not the title is displayed in the window titlebar.
///
/// Parameters:
///  * `state` - an optional boolean specifying whether or not the window's title text appears in the window titlebar area, if present.
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
///
/// Notes:
///  * When a toolbar is attached to the window (see the `hs.webview.toolbar` module documentation), this function can be used to specify whether the Toolbar appears underneath the window's title (true) or in the window's title bar itself, as seen in applications like Safari (false).
static int window_titleVisibility(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, (window.titleVisibility == NSWindowTitleVisible)) ;
    } else {
        window.titleVisibility = lua_toboolean(L, 2) ? NSWindowTitleVisible : NSWindowTitleHidden ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.window:toolbar([toolbar]) -> windowObject | toolbarObject | nil
/// Method
/// Get or set the toolbar for the window.
///
/// Parameters:
///  * `toolbar` - an optional `hs._asm.uitk.toolbar` object, to attach as the window's toolbar or an explici nil to remove the existing toolbar.
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value, which may be nil if no toolbar is attached.
///
/// Notes:
///  * a window can only have one toolbar object attached at a time.
static int window_toolbar(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:window.toolbar withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        NSToolbar *toolbar = nil ;
        switch(lua_type(L, 2)) {
            case LUA_TNIL:
                break ;
            case LUA_TUSERDATA:
                [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs._asm.uitk.toolbar", LS_TBREAK] ;
                toolbar = [skin toNSObjectAtIndex:2] ;
                [skin luaRetain:refTable forNSObject:toolbar] ;
                toolbar.window = window ;
                break ;
            default:
                return luaL_argerror(L, 2, "expected nil or hs._asm.uitk.toolbar userdata") ;
        }

        if (window.toolbar) {
            [skin luaRelease:refTable forNSObject:window.toolbar] ;
            window.toolbar.window = nil ;
        }
        window.toolbar = toolbar ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.window:toggleToolbar() -> windowObject
/// Method
/// Toggle whether the window's toolbar is currently visible or hidden.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the windowObject
///
/// Notes:
///  * you can determine if the toolbar is currently visible or hidden by using `hs._asm.uitk.window:toolbar():visible()`.
static int window_toggleToolbarShown(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    [window toggleToolbarShown:window] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.window:toolbarStyle([style]) -> windowObject | string
/// Method
/// Get or set the window's toolbar style.
///
/// Parameters:
///  * style - an optional string to set the toolbar style of the window.
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value
///
/// Notes:
///  * This is only available for macOS 11.0+ and is a no-op for earlier macOS versions.
///
///  * Currently recognizes the following styles:
///     * `automatic`      - the system determines the toolbar’s appearance and location.
///     * `expanded`       - the toolbar appears below the window title.
///     * `preference`     - the toolbar appears below the window title with toolbar items centered in the toolbar.
///     * `unified`        - the toolbar appears next to the window title.
///     * `unifiedCompact` - the toolbar appears next to the window title with reduced margins.
static int window_toolbarStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if (@available(macOS 11.0, *)) {
            NSNumber *value = @(window.toolbarStyle) ;
            NSArray *temp = [TOOLBAR_STYLES allKeysForObject:value];
            NSString *answer = [temp firstObject] ;
            if (answer) {
                [skin pushNSObject:answer] ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized toolbar style %@ -- notify developers", USERDATA_TAG, value]] ;
                lua_pushnil(L) ;
            }
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (@available(macOS 11.0, *)) {
            NSString *key = [skin toNSObjectAtIndex:2] ;
            NSNumber *value = TOOLBAR_STYLES[key] ;
            if (value) {
                window.toolbarStyle = value.integerValue ;
                lua_pushvalue(L, 1) ;
            } else {
                return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [TOOLBAR_STYLES.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
            }
        } else {
            lua_pushvalue(L, 1) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.window:appearance([appearance]) -> windowObject | string
/// Method
/// Get or set the appearance name applied to the window decorations for the window.
///
/// Parameters:
///  * `appearance` - an optional string specifying the name of the appearance style to apply to the window frame and decorations.
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
///
/// Notes:
///  * The following appearance names are know to work:
///    * `aqua`     - The standard light system appearance; default if your system apearance is currenlty set to Light.
///    * `darkAqua` - The standard dark system appearance; default if your system apearance is currenlty set to Dark.
///
///  * The following appearance names are defined, but only allowed for views or other situations we don't currently directly support. Assigning them will effectively assign the closest of "aqua" or "darkAqua", but may be supported in elements in the future.
///    * `light`                - The light vibrant appearance, available only in visual effect views.
///    * `dark`                 - A dark vibrant appearance, available only in visual effect views.
///    * `highContrastAqua`     - A high-contrast version of the standard light system appearance.
///    * `highContrastDarkAqua` - A high-contrast version of the standard dark system appearance.
///    * `highContrastLight`    - A high-contrast version of the light vibrant appearance.
///    * `highContrastDark`     - A high-contrast version of the dark vibrant appearance.
///
///  * Other string values are allowed for forwards compatibility if Apple or third party software adds additional appearances.
///  * This method will return an error if the string provided does not correspond to a recognized appearance theme.
static int appearanceCustomization_appearance(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSString *actual   = window.effectiveAppearance.name ;
        NSString *returned = [[WINDOW_APPEARANCES allKeysForObject:actual] firstObject] ;
        if (!returned) returned = actual ;
        [skin pushNSObject:returned] ;
    } else {
        NSString *name = [skin toNSObjectAtIndex:2] ;
        NSString *appearanceName = WINDOW_APPEARANCES[name] ;
        if (!appearanceName) appearanceName = name ;
        NSAppearance *appearance = [NSAppearance appearanceNamed:appearanceName] ;
        if (appearance) {
            window.appearance = appearance ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of '%@'", [WINDOW_APPEARANCES.allKeys componentsJoinedByString:@"', '"]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.window:closeOnEscape([flag]) -> windowObject | boolean
/// Method
/// If the window is titled and closable, this will get or set whether or not the Escape key is allowed to close the window.
///
/// Parameters:
///  * `flag` - an optional boolean value which indicates whether the window, when it's style includes `closable` and `titled` (see [hs._asm.uitk.window:styleMask](#styleMask)), should allow the Escape key to be a shortcut for closing the window.  Defaults to false.
///
/// Returns:
///  * If a value is provided, then this method returns the window object; otherwise the current value
///
/// Notes:
///  * If this is set to true, Escape will only close the window if no other element responds to the Escape key first (e.g. if you are editing a textField element, the Escape will be captured by the text field, not by the window.)
static int window_closeOnEscape(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, window.closeOnEscape) ;
    } else {
        window.closeOnEscape = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.window:frame([rect], [animated]) -> windowObject | rect-table
/// Method
/// Get or set the frame of the window.
///
/// Parameters:
///  * `rect`     - An optional rect-table containing the co-ordinates and size the window should be moved and set to
///  * `animated` - an optional boolean, default false, indicating whether the frame change should be performed with a smooth transition animation (true) or not (false).
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
///
/// Notes:
///  * a rect-table is a table with key-value pairs specifying the new top-left coordinate on the screen of the window (keys `x`  and `y`) and the new size (keys `h` and `w`). The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
///
///  * See also [hs._asm.uitk.window:animationDuration](#animationDuration).
static int window_frame(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    NSRect oldFrame = RectWithFlippedYCoordinate(window.frame);
    if (lua_gettop(L) == 1) {
        [skin pushNSRect:oldFrame] ;
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
        NSRect newFrame = RectWithFlippedYCoordinate([skin tableToRectAtIndex:2]) ;
        BOOL animate = (lua_gettop(L) == 3) ? (BOOL)(lua_toboolean(L, 3)) : NO ;
        [window setFrame:newFrame display:YES animate:animate];
        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs._asm.uitk.window:topLeft([point], [animated]) -> windowObject | rect-table
/// Method
/// Get or set the top left corner of the window.
///
/// Parameters:
///  * `point`     - An optional point-table specifying the new coordinate the top-left of the window should be moved to
///  * `animated` - an optional boolean, default false, indicating whether the frame change should be performed with a smooth transition animation (true) or not (false).
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
///
/// Notes:
///  * a point-table is a table with key-value pairs specifying the new top-left coordinate on the screen of the window (keys `x`  and `y`). The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
///
///  * See also [hs._asm.uitk.window:animationDuration](#animationDuration).
static int window_topLeft(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    NSRect oldFrame = RectWithFlippedYCoordinate(window.frame);
    if (lua_gettop(L) == 1) {
        [skin pushNSPoint:oldFrame.origin] ;
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
        NSPoint newCoord = [skin tableToPointAtIndex:2] ;
        BOOL animate = (lua_gettop(L) == 3) ? (BOOL)(lua_toboolean(L, 3)) : NO ;
        NSRect  newFrame = RectWithFlippedYCoordinate(NSMakeRect(newCoord.x, newCoord.y, oldFrame.size.width, oldFrame.size.height)) ;
        [window setFrame:newFrame display:YES animate:animate];
        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs._asm.uitk.window:size([size], [animated]) -> windowObject | rect-table
/// Method
/// Get or set the size of the window.
///
/// Parameters:
///  * `size`     - an optional size-table specifying the width and height the window should be resized to
///  * `animated` - an optional boolean, default false, indicating whether the frame change should be performed with a smooth transition animation (true) or not (false).
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
///
/// Notes:
///  * a size-table is a table with key-value pairs specifying the size (keys `h` and `w`) the window should be resized to. The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
///
///  * See also [hs._asm.uitk.window:animationDuration](#animationDuration).
static int window_size(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    NSRect oldFrame = window.frame;
    if (lua_gettop(L) == 1) {
        [skin pushNSSize:oldFrame.size] ;
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
        NSSize newSize  = [skin tableToSizeAtIndex:2] ;
        BOOL animate = (lua_gettop(L) == 3) ? (BOOL)(lua_toboolean(L, 3)) : NO ;
        NSRect newFrame = NSMakeRect(oldFrame.origin.x, oldFrame.origin.y + oldFrame.size.height - newSize.height, newSize.width, newSize.height) ;
        [window setFrame:newFrame display:YES animate:animate] ;
        lua_pushvalue(L, 1) ;
    }
    return 1;
}

/// hs._asm.uitk.window:animationBehavior([behavior]) -> windowObject | string
/// Method
/// Get or set the macOS animation behavior used when the window is shown or hidden.
///
/// Parameters:
///  * `behavior` - an optional string specifying the animation behavior. The string should be one of the following:
///    * "default"        - The automatic animation that’s appropriate to the window type.
///    * "none"           - No automatic animation used. This is the default which makes window appearance immediate unless you use the fade time argument with [hs._asm.uitk.window:show](#show), [hs._asm.uitk.window:hide](#hide), or [hs._asm.uitk.window:delete](#delete).
///    * "documentWindow" - The animation behavior that’s appropriate to a document window.
///    * "utilityWindow"  - The animation behavior that’s appropriate to a utility window.
///    * "alertPanel"     - The animation behavior that’s appropriate to an alert window.
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
///
/// Notes:
///  * This animation is separate from the fade-in and fade-out options provided with the [hs._asm.uitk.window:show](#show), [hs._asm.uitk.window:hide](#hide), and [hs._asm.uitk.window:delete](#delete) methods and is provided by the macOS operating system itself.
static int window_animationBehavior(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *animationBehavior = @(window.animationBehavior) ;
        NSString *value = [[ANIMATION_BEHAVIORS allKeysForObject:animationBehavior] firstObject] ;
        if (value) {
            [skin pushNSObject:value] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized animationBehavior %@ -- notify developers", USERDATA_TAG, animationBehavior]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSNumber *value = ANIMATION_BEHAVIORS[[skin toNSObjectAtIndex:2]] ;
        if (value) {
            window.animationBehavior = [value integerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of '%@'", [ANIMATION_BEHAVIORS.allKeys componentsJoinedByString:@"', '"]] UTF8String]) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.window:animationDuration([duration | nil]) -> windowObject | number | nil
/// Method
/// Get or set the macOS animation duration for smooth frame transitions used when the window is moved or resized.
///
/// Parameters:
///  * `duration` - a number or nil, default nil, specifying the time in seconds to move or resize by 150 pixels when the `animated` flag is set for [hs._asm.uitk.window:frame](#frame), [hs._asm.uitk.window:topLeft](#topLeft), or [hs._asm.uitk.window:size](#size). An explicit `nil` defaults to the macOS default, which is currently 0.2.
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
static int window_animationDuration(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:window.animationTime] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            window.animationTime = nil ;
        } else {
            window.animationTime = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int window_collectionBehavior(lua_State *L) {
// NOTE:  This method is wrapped in window.lua
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    NSWindowCollectionBehavior oldBehavior = window.collectionBehavior ;
    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, (lua_Integer)oldBehavior) ;
    } else {
// ??? can we check this through logic or do we have to use try/catch?
        @try {
            window.collectionBehavior = (NSUInteger)lua_tointeger(L, 2) ;
        }
        @catch ( NSException *theException ) {
            window.collectionBehavior = oldBehavior ;
            return luaL_error(L, "invalid collection behavior: %s, %s", [[theException name] UTF8String], [[theException reason] UTF8String]) ;
        }
        lua_pushvalue(L, 1);
    }
    return 1 ;
}

/// hs._asm.uitk.window:hide([fadeOut]) -> windowObject
/// Method
/// Hides the window object
///
/// Parameters:
///  * `fadeOut` - An optional number of seconds over which to fade out the window object. Defaults to zero (i.e. immediate).
///
/// Returns:
///  * The window object
static int window_hide(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [window orderOut:window];
    } else {
        [window fadeOut:lua_tonumber(L, 2) andClose:NO];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.uitk.window:show([fadeIn]) -> windowObject
/// Method
/// Displays the window object
///
/// Parameters:
///  * `fadeIn` - An optional number of seconds over which to fade in the window object. Defaults to zero (i.e. immediate).
///
/// Returns:
///  * The window object
static int window_show(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [window makeKeyAndOrderFront:nil];
    } else {
        [window fadeIn:lua_tonumber(L, 2)];
    }
    lua_pushvalue(L, 1);
    return 1;
}

/// hs._asm.uitk.window:orderAbove([window2]) -> windowObject
/// Method
/// Moves the window above window2, or all windows in the same presentation level, if window2 is not given.
///
/// Parameters:
///  * `window2` -An optional window object to place the window above.
///
/// Returns:
///  * The window object
///
/// Notes:
///  * If the window and window2 are not at the same presentation level, this method will will move the window as close to the desired relationship as possible without changing the object's presentation level. See [hs._asm.uitk.window.level](#level).
static int window_orderAbove(lua_State *L) {
    return window_orderHelper(L, NSWindowAbove) ;
}

/// hs._asm.uitk.window:orderBelow([window2]) -> windowObject
/// Method
/// Moves the window below window2, or all windows in the same presentation level, if window2 is not given.
///
/// Parameters:
///  * `window2` - An optional window object to place the window below.
///
/// Returns:
///  * The window object
///
/// Notes:
///  * If the window and window2 are not at the same presentation level, this method will will move the window as close to the desired relationship as possible without changing the object's presentation level. See [hs._asm.uitk.window.level](#level).
static int window_orderBelow(lua_State *L) {
    return window_orderHelper(L, NSWindowBelow) ;
}

static int window_level(lua_State *L) {
// NOTE:  This method is wrapped in window.lua
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, window.level) ;
    } else {
        lua_Integer targetLevel = lua_tointeger(L, 2) ;
        lua_Integer minLevel = CGWindowLevelForKey(kCGMinimumWindowLevelKey) ;
        lua_Integer maxLevel = CGWindowLevelForKey(kCGMaximumWindowLevelKey) ;
        window.level = (targetLevel < minLevel) ? minLevel : ((targetLevel > maxLevel) ? maxLevel : targetLevel) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.window:isShowing() -> boolean
/// Method
/// Returns whether or not the window is currently being shown.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean indicating whether or not the window is currently being shown (true) or is currently hidden (false).
///
/// Notes:
///  * This method only determines whether or not the window is being shown or is hidden -- it does not indicate whether or not the window is currently off screen or is occluded by other objects.
///  * See also [hs._asm.uitk.window:isOccluded](#isOccluded).
static int window_isShowing(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, [window isVisible]) ;
    return 1 ;
}

/// hs._asm.uitk.window:isOccluded() -> boolean
/// Method
/// Returns whether or not the window is currently occluded (hidden by other windows, off screen, etc).
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean indicating whether or not the window is currently being occluded.
///
/// Notes:
///  * If any part of the window is visible (even if that portion of the window does not contain any elements), then the window is not considered occluded.
///  * a window which is completely covered by one or more opaque windows is considered occluded; however, if the windows covering the window are not opaque, then the window is not occluded.
///  * a window that is currently hidden or that has a height of 0 or a width of 0 is considered occluded.
///  * See also [hs._asm.uitk.window:isShowing](#isShowing).
static int window_isOccluded(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, ([window occlusionState] & NSWindowOcclusionStateVisible) != NSWindowOcclusionStateVisible) ;
    return 1 ;
}

/// hs._asm.uitk.window:notificationCallback([fn | nil]) -> windowObject | fn | nil
/// Method
/// Get or set the notification callback for the window.
///
/// Parameters:
///  * `fn` - a function, or explicit nil to remove, that should be invoked whenever a registered notification concerning the window occurs.  See [hs._asm.uitk.window:notificationMessages](#notificationMessages) for information on registering for specific notifications.
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
///
/// Notes:
///  * The function should expect two arguments: the windowObject itself and a string specifying the type of notification. See [hs._asm.uitk.window:notificationMessages](#notificationMessages) and [hs._asm.uitk.window.notifications](#notifications).
///  * [hs._asm.uitk.window:simplifiedWindowCallback](#simplifiedWindowCallback) provides a wrapper to this method which conforms to the window notifications currently offered by `hs.webview`.
static int window_notificationCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if (window.notificationCallback == LUA_NOREF) {
            lua_pushnil(L) ;
        } else {
            [skin pushLuaRef:refTable ref:window.notificationCallback] ;
        }
    } else {
        // either way, lets release any function which may already be stored in the registry
        window.notificationCallback = [skin luaUnref:refTable ref:window.notificationCallback] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            window.notificationCallback = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.window:passthroughCallback([fn | nil]) -> windowObject | function | nil
/// Method
/// Get or set the passthrough callback for the window.
///
/// Parameters:
///  * `fn` - a function, or explicit nil to remove, that should be invoked whenever an element contained within this window does not have a more specific callback registered.
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
///
/// Notes:
///  * this function is provided as a fallback for capturing informational events or actions that trigger callbacks within assigned elements, but were not handled by a closer or more specific callback.
///
///  * The function should expect two arguments (the windowObject itself and a table contianing the arguments provided to the previous container or element that didn't provide a callback) and return none. The specific contents of the argument array will depend upon the element and intervening containers or elements, but should follow the general form of:
///      * `{ window, { container, { ..., {element, <element specific> } ... }, }, }`
static int window_passthroughCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if (window.passthroughCallbackRef == LUA_NOREF) {
            lua_pushnil(L) ;
        } else {
            [skin pushLuaRef:refTable ref:window.passthroughCallbackRef] ;
        }
    } else {
        // either way, lets release any function which may already be stored in the registry
        window.passthroughCallbackRef = [skin luaUnref:refTable ref:window.passthroughCallbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            window.passthroughCallbackRef = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.window:notificationMessages([notifications, [replace]]) -> windowObject | table
/// Method
/// Get or set the specific notifications which should trigger a callback set with [hs._asm.uitk.window:notificationCallback](#notificationCallback).
///
/// Parameters:
///  * `notifications` - a string, to specify one, or a table of strings to specify multiple notifications which are to trigger a callback when they occur.
///  * `replace`       - an optional boolean, default false, specifying whether the notifications listed should be added to the current set (false) or replace the existing set with new values (true).
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
///
/// Notes:
///  * When a new windowObject is created, the messages are initially set to `{ "didBecomeKey", "didResignKey", "didResize", "didMove" }`
///  * See [hs._asm.uitk.window.notifications](#notifications) for possible notification messages that can be watched for.
static int window_notificationWatchFor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TSTRING | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:window.notifyFor] ;
    } else {
        NSArray *watchingFor ;
        if (lua_type(L, 2) == LUA_TSTRING) {
            watchingFor = @[ [skin toNSObjectAtIndex:2] ] ;
        } else {
            watchingFor = [skin toNSObjectAtIndex:2] ;
        }

        BOOL isGood = YES ;
        if ([watchingFor isKindOfClass:[NSArray class]]) {
            for (NSString *item in watchingFor) {
                if (![item isKindOfClass:[NSString class]]) {
                    isGood = NO ;
                    break ;
                }
            }
        } else {
            isGood = NO ;
        }
        if (!isGood) {
            return luaL_argerror(L, 2, "expected a string or an array of strings") ;
        }

        BOOL willAdd = (lua_gettop(L) == 2) ? YES : (BOOL)(lua_toboolean(L, 3)) ;
        for (NSString *item in watchingFor) {
            if (![windowNotifications containsObject:item]) {
                return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one or more of the following:%@", [windowNotifications componentsJoinedByString:@", "]] UTF8String]) ;
            }
        }
        if (willAdd) {
            for (NSString *item in watchingFor) {
                [window.notifyFor addObject:item] ;
            }
        } else {
            window.notifyFor = [[NSMutableSet alloc] initWithArray:watchingFor] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.window:content([view | nil]) -> windowObject | element userdata
/// Method
/// Get or set the content element for the window.
///
/// Parameters:
///  * `view` - a userdata representing a container element, individual element, or an explcit nil to remove, to assign to the window.
///
/// Returns:
///  * If an argument is provided, the window object; otherwise the current value.
///
/// Notes:
///  * This module provides the window or "frame" for displaying visual or user interface elements, however the container itself is provided by other modules. This method allows you to assign a container element or single element directly to the window for display and user interaction.
///
///  * A container element allows for attaching multiple elements to the same window, for example a series of buttons and text fields for user input.
///  * If the window is being used to display a single element, you can by skip using the container element and assign the element directly with this method. This works especially well for fully contained elements like `hs._asm.uitk.element.avplayer` or `hs.canvas`, but may be useful at times with other elements as well.  The following should be kept in mind when not using a container element:
///    * The element's size is the window's size -- you cannot specify a specific location for the element within the window or make it smaller than the window to give it a visual border.
///    * Only one element can be assigned at a time. For canvas, which has its own methods for handling multiple visual elements, this isn't necessarily an issue.
static int window_contentView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if ([skin canPushNSObject:window.contentView]) {
            [skin pushNSObject:window.contentView] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            [skin luaRelease:refTable forNSObject:window.contentView] ;
            // placeholder, since a window always has one after init, let's follow that pattern
            window.contentView = [[NSView alloc] initWithFrame:window.contentView.bounds] ;
        } else {
            NSView *container = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
            if (!container || !oneOfOurElementObjects(container)) {
                return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
            }
            [skin luaRelease:refTable forNSObject:window.contentView] ;
            [skin luaRetain:refTable forNSObject:container] ;
            window.contentView = container ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.window:activeElement([view | nil]) -> boolean | userdata
/// Method
/// Get or set the active element for the window.
///
/// Parameters:
///  * `view` - a userdata representing an element in the window to make the active element, or an explcit nil to make no element active.
///
/// Returns:
///  * If an argument is provided, returns true or false indicating whether or not the current active element (if any) relinquished focus; otherwise the current value.
///
/// Notes:
///  * The active element of a window is the element which is currently receiving mouse or keyboard activity from the user when the window is focused.
///
///  * Not all elements can become the active element, for example textField elements which are neither editable or selectable. If you try to make such an element active, the container element or window itself will become the active element.
///  * Passing an explicit nil to this method will make the container element or window itself the active element.
///    * Making the container element or window itself the active element has the visual effect of making no element active but leaving the window focus unchanged.
static int window_firstResponder(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKWindow *window = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSResponder *trying = window.firstResponder ;
        while (trying && ![skin canPushNSObject:trying]) trying = trying.nextResponder ;
        [skin pushNSObject:trying] ; // will either be a responder we can work with or nil
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            lua_pushboolean(L, [window makeFirstResponder:nil]) ;
        } else {
            NSView *view = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
            if (!view || !oneOfOurElementObjects(view)) {
                return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
            }
            lua_pushboolean(L, [window makeFirstResponder:view]) ;
        }
    }
    return 1 ;
}

#pragma mark - Module Constants -

/// hs._asm.uitk.window.windowBehaviors[]
/// Constant
/// Array of window behavior labels for determining how an window is handled in Spaces and Exposé
///
/// * `default`                   - The window can be associated to one space at a time.
/// * `canJoinAllSpaces`          - The window appears in all spaces. The menu bar behaves this way.
/// * `moveToActiveSpace`         - Making the window active does not cause a space switch; the window switches to the active space.
///
/// Only one of these may be active at a time:
///
/// * `managed`                   - The window participates in Spaces and Exposé. This is the default behavior if windowLevel is equal to NSNormalWindowLevel.
/// * `transient`                 - The window floats in Spaces and is hidden by Exposé. This is the default behavior if windowLevel is not equal to NSNormalWindowLevel.
/// * `stationary`                - The window is unaffected by Exposé; it stays visible and stationary, like the desktop window.
///
/// Only one of these may be active at a time:
///
/// * `participatesInCycle`       - The window participates in the window cycle for use with the Cycle Through Windows Window menu item.
/// * `ignoresCycle`              - The window is not part of the window cycle for use with the Cycle Through Windows Window menu item.
///
/// Only one of these may be active at a time:
///
/// * `fullScreenPrimary`         - A window with this collection behavior has a fullscreen button in the upper right of its titlebar.
/// * `fullScreenAuxiliary`       - Windows with this collection behavior can be shown on the same space as the fullscreen window.
/// * `fullScreenNone`            - The window can not be made fullscreen
///
/// Only one of these may be active at a time:
///
/// * `fullScreenAllowsTiling`    - A window with this collection behavior be a full screen tile window and does not have to have `fullScreenPrimary` set.
/// * `fullScreenDisallowsTiling` - A window with this collection behavior cannot be made a fullscreen tile window, but it can have `fullScreenPrimary` set.  You can use this setting to prevent other windows from being placed in the window’s fullscreen tile.
static int window_collectionTypeTable(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSWindowCollectionBehaviorDefault) ;                   lua_setfield(L, -2, "default") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorCanJoinAllSpaces) ;          lua_setfield(L, -2, "canJoinAllSpaces") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorMoveToActiveSpace) ;         lua_setfield(L, -2, "moveToActiveSpace") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorManaged) ;                   lua_setfield(L, -2, "managed") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorTransient) ;                 lua_setfield(L, -2, "transient") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorStationary) ;                lua_setfield(L, -2, "stationary") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorParticipatesInCycle) ;       lua_setfield(L, -2, "participatesInCycle") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorIgnoresCycle) ;              lua_setfield(L, -2, "ignoresCycle") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenPrimary) ;         lua_setfield(L, -2, "fullScreenPrimary") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenAuxiliary) ;       lua_setfield(L, -2, "fullScreenAuxiliary") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenNone) ;            lua_setfield(L, -2, "fullScreenNone") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenAllowsTiling) ;    lua_setfield(L, -2, "fullScreenAllowsTiling") ;
    lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenDisallowsTiling) ; lua_setfield(L, -2, "fullScreenDisallowsTiling") ;
    return 1 ;
}

/// hs._asm.uitk.window.levels
/// Constant
/// A table of predefined window levels usable with [hs._asm.uitk.window:level](#level)
///
/// Predefined levels are:
///  * _MinimumWindowLevelKey - lowest allowed window level. If you specify a level lower than this, it will be set to this value.
///  * desktop
///  * desktopIcon            - [hs._asm.uitk.window:sendToBack](#sendToBack) is equivalent to this level - 1
///  * normal                 - normal application windows
///  * floating               - equivalent to [hs._asm.uitk.window:bringToFront(false)](#bringToFront); where "Always Keep On Top" windows are usually set
///  * tornOffMenu
///  * modalPanel             - modal alert dialog
///  * utility
///  * dock                   - level of the Dock
///  * mainMenu               - level of the Menubar
///  * status
///  * popUpMenu              - level of a menu when displayed (open)
///  * overlay
///  * help
///  * dragging
///  * screenSaver            - equivalent to [hs._asm.uitk.window:bringToFront(true)](#bringToFront)
///  * assistiveTechHigh
///  * cursor
///  * _MaximumWindowLevelKey - highest allowed window level. If you specify a level larger than this, it will be set to this value.
///
/// Notes:
///  * These key names map to the constants used in CoreGraphics to specify window levels and may not actually be used for what the name might suggest. For example, tests suggest that an active screen saver actually runs at a level of 2002, rather than at 1000, which is the window level corresponding to `hs._asm.uitk.window.levels.screenSaver`.
///
///  * Each window level is sorted separately and [hs._asm.uitk.window:orderAbove](#orderAbove) and [hs._asm.uitk.window:orderBelow](#orderBelow) only arrange windows within the same level.
///
///  * If you use Dock hiding (or in 10.11+, Menubar hiding) please note that when the Dock (or Menubar) is popped up, it is done so with an implicit orderAbove, which will place it above any items you may also draw at the Dock (or MainMenu) level.
///
///  * Recent versions of macOS have made significant changes to the way full-screen apps work which may prevent placing Hammerspoon elements above some full screen applications.  At present the exact conditions are not fully understood and no work around currently exists in these situations.
static int window_windowLevels(lua_State *L) {
    lua_newtable(L) ;
//       lua_pushinteger(L, CGWindowLevelForKey(kCGBaseWindowLevelKey)) ;              lua_setfield(L, -2, "kCGBaseWindowLevelKey") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGMinimumWindowLevelKey)) ;           lua_setfield(L, -2, "_MinimumWindowLevelKey") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDesktopWindowLevelKey)) ;           lua_setfield(L, -2, "desktop") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDesktopIconWindowLevelKey)) ;       lua_setfield(L, -2, "desktopIcon") ;
//       lua_pushinteger(L, CGWindowLevelForKey(kCGBackstopMenuLevelKey)) ;            lua_setfield(L, -2, "backstopMenuLevel") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGNormalWindowLevelKey)) ;            lua_setfield(L, -2, "normal") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGFloatingWindowLevelKey)) ;          lua_setfield(L, -2, "floating") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGTornOffMenuWindowLevelKey)) ;       lua_setfield(L, -2, "tornOffMenu") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGModalPanelWindowLevelKey)) ;        lua_setfield(L, -2, "modalPanel") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGUtilityWindowLevelKey)) ;           lua_setfield(L, -2, "utility") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDockWindowLevelKey)) ;              lua_setfield(L, -2, "dock") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGMainMenuWindowLevelKey)) ;          lua_setfield(L, -2, "mainMenu") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGStatusWindowLevelKey)) ;            lua_setfield(L, -2, "status") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGPopUpMenuWindowLevelKey)) ;         lua_setfield(L, -2, "popUpMenu") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGOverlayWindowLevelKey)) ;           lua_setfield(L, -2, "overlay") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGHelpWindowLevelKey)) ;              lua_setfield(L, -2, "help") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDraggingWindowLevelKey)) ;          lua_setfield(L, -2, "dragging") ;
//       lua_pushinteger(L, CGWindowLevelForKey(kCGNumberOfWindowLevelKeys)) ;         lua_setfield(L, -2, "kCGNumberOfWindowLevelKeys") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGScreenSaverWindowLevelKey)) ;       lua_setfield(L, -2, "screenSaver") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGAssistiveTechHighWindowLevelKey)) ; lua_setfield(L, -2, "assistiveTechHigh") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGCursorWindowLevelKey)) ;            lua_setfield(L, -2, "cursor") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGMaximumWindowLevelKey)) ;           lua_setfield(L, -2, "_MaximumWindowLevelKey") ;
    return 1 ;
}
/// hs._asm.uitk.window.masks[]
/// Constant
/// A table containing valid masks for the window.
///
/// Table Keys:
///  * `borderless`             - The window has no border decorations
///  * `titled`                 - The window title bar is displayed
///  * `closable`               - The window has a close button
///  * `miniaturizable`         - The window has a minimize button
///  * `resizable`              - The window is resizable
///  * `texturedBackground`     - The window has a texturized background
///  * `fullSizeContentView`    - If titled, the titlebar is within the frame size specified at creation, not above it.  Shrinks actual content area by the size of the titlebar, if present.
///  * `utility`                - If titled, the window shows a utility window titlebar (thinner than normal)
///  * `nonactivating`          - If the window is activated, it won't bring other Hammerspoon windows forward as well
///  * `HUD`                    - Requires utility; the window titlebar is shown dark and can only show the close button and title (if they are set)
///
/// The following are still being evaluated and may require additional support or specific methods to be in effect before use. Use with caution.
///  * `unifiedTitleAndToolbar` -
///  * `fullScreen`             -
///  * `docModal`               -
///
/// Notes:
///  * The Maximize button in the window title is enabled when Resizable is set.
///  * The Close, Minimize, and Maximize buttons are only visible when the Window is also Titled.
///
///  * Not all combinations of masks are valid and will throw an error if set with [hs._asm.uitk.window:mask](#mask).
static int window_windowMasksTable(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSWindowStyleMaskBorderless) ;             lua_setfield(L, -2, "borderless") ;
    lua_pushinteger(L, NSWindowStyleMaskTitled) ;                 lua_setfield(L, -2, "titled") ;
    lua_pushinteger(L, NSWindowStyleMaskClosable) ;               lua_setfield(L, -2, "closable") ;
    lua_pushinteger(L, NSWindowStyleMaskMiniaturizable) ;         lua_setfield(L, -2, "miniaturizable") ;
    lua_pushinteger(L, NSWindowStyleMaskResizable) ;              lua_setfield(L, -2, "resizable") ;
    lua_pushinteger(L, NSWindowStyleMaskTexturedBackground) ;     lua_setfield(L, -2, "texturedBackground") ;
    lua_pushinteger(L, NSWindowStyleMaskUnifiedTitleAndToolbar) ; lua_setfield(L, -2, "unifiedTitleAndToolbar") ;
    lua_pushinteger(L, NSWindowStyleMaskFullScreen) ;             lua_setfield(L, -2, "fullScreen") ;
    lua_pushinteger(L, NSWindowStyleMaskFullSizeContentView) ;    lua_setfield(L, -2, "fullSizeContentView") ;
    lua_pushinteger(L, NSWindowStyleMaskUtilityWindow) ;          lua_setfield(L, -2, "utility") ;
    lua_pushinteger(L, NSWindowStyleMaskDocModalWindow) ;         lua_setfield(L, -2, "docModal") ;
    lua_pushinteger(L, NSWindowStyleMaskNonactivatingPanel) ;     lua_setfield(L, -2, "nonactivating") ;
    lua_pushinteger(L, NSWindowStyleMaskHUDWindow) ;              lua_setfield(L, -2, "HUD") ;
    return 1 ;
}

/// hs._asm.uitk.window.notifications[]
/// Constant
/// An array containing all of the notifications which can be enabled with [hs._asm.uitk.window:notificationMessages](#notificationMessages).
///
/// Array values:
///  * `didBecomeKey`               - The window has become the key window; controls or elements of the window can now be manipulated by the user and keyboard entry (if appropriate) will be captured by the relevant elements.
///  * `didBecomeMain`              - The window has become the main window of Hammerspoon. In most cases, this is equivalent to the window becoming key and both notifications may be sent if they are being watched for.
///  * `didChangeBackingProperties` - The backing properties of the window have changed. This will be posted if the scaling factor of color space for the window changes, most likely because it moved to a different screen.
///  * `didChangeOcclusionState`    - The window's occlusion state has changed (i.e. whether or not at least part of the window is currently visible)
///  * `didChangeScreen`            - Part of the window has moved onto or off of the current screens
///  * `didChangeScreenProfile`     - The screen the window is on has changed its properties or color profile
///  * `didDeminiaturize`           - The window has been de-miniaturized
///  * `didEndLiveResize`           - The user resized the window
///  * `didEndSheet`                - The window has closed an attached sheet
///  * `didEnterFullScreen`         - The window has entered full screen mode
///  * `didEnterVersionBrowser`     - The window will enter version browser mode
///  * `didExitFullScreen`          - The window has exited full screen mode
///  * `didExitVersionBrowser`      - The window will exit version browser mode
///  * `didExpose`                  - Posted whenever a portion of a nonretained window is exposed - may not be applicable to the way Hammerspoon manages windows; will have to evaluate further
///  * `didFailToEnterFullScreen`   - The window failed to enter full screen mode
///  * `didFailToExitFullScreen`    - The window failed to exit full screen mode
///  * `didMiniaturize`             - The window was miniaturized
///  * `didMove`                    - The window was moved
///  * `didResignKey`               - The window has stopped being the key window
///  * `didResignMain`              - The window has stopped being the main window
///  * `didResize`                  - The window did resize
///  * `didUpdate`                  - The window received an update message (a request to redraw all content and the content of its subviews)
///  * `willBeginSheet`             - The window is about to open an attached sheet
///  * `willClose`                  - The window is about to close; the window has not closed yet, so its userdata is still valid, even if it's set to be deleted on close, so do any clean up at this time.
///  * `willEnterFullScreen`        - The window is about to enter full screen mode but has not done so yet
///  * `willEnterVersionBrowser`    - The window will enter version browser mode but has not done so yet
///  * `willExitFullScreen`         - The window will exit full screen mode but has not done so yet
///  * `willExitVersionBrowser`     - The window will exit version browser mode but has not done so yet
///  * `willMiniaturize`            - The window will miniaturize but has not done so yet
///  * `willMove`                   - The window will move but has not done so yet
///  * `willStartLiveResize`        - The window is about to be resized by the user
///
/// Notes:
///  * Not all of the notifications here are currently fully supported and the specific details and support will change as this module and its submodules evolve and get fleshed out. Some may be removed if it is determined they will never be supported by this module while others may lead to additions when the need arises. Please post an issue or pull request if you would like to request specific support or provide additions yourself.
static int window_notifications(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    windowNotifications = @[
        @"didBecomeKey",
        @"didBecomeMain",
        @"didChangeBackingProperties",
        @"didChangeOcclusionState",
        @"didChangeScreen",
        @"didChangeScreenProfile",
        @"didDeminiaturize",
        @"didEndLiveResize",
        @"didEndSheet",
        @"didEnterFullScreen",
        @"didEnterVersionBrowser",
        @"didExitFullScreen",
        @"didExitVersionBrowser",
        @"didExpose",
        @"didFailToEnterFullScreen",
        @"didFailToExitFullScreen",
        @"didMiniaturize",
        @"didMove",
        @"didResignKey",
        @"didResignMain",
        @"didResize",
        @"didUpdate",
        @"willBeginSheet",
        @"willClose",
        @"willEnterFullScreen",
        @"willEnterVersionBrowser",
        @"willExitFullScreen",
        @"willExitVersionBrowser",
        @"willMiniaturize",
        @"willMove",
        @"willStartLiveResize",
    ] ;
    [skin pushNSObject:windowNotifications] ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKWindow(lua_State *L, id obj) {
    HSUITKWindow *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKWindow *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKWindow(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKWindow *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKWindow, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKWindow *obj = [skin luaObjectAtIndex:1 toClass:"HSUITKWindow"] ;
    NSString *title = obj.title ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ @%@ (%p)", USERDATA_TAG, title, NSStringFromRect(RectWithFlippedYCoordinate(obj.frame)), lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSUITKWindow *obj1 = [skin luaObjectAtIndex:1 toClass:"HSUITKWindow"] ;
        HSUITKWindow *obj2 = [skin luaObjectAtIndex:2 toClass:"HSUITKWindow"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

// The monster, in his consternation, demonstrates defenestration... -- Bill Waterson
static int userdata_gc(lua_State* L) {
    HSUITKWindow *obj = get_objectFromUserdata(__bridge_transfer HSUITKWindow, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L];
            obj.notificationCallback   = [skin luaUnref:refTable ref:obj.notificationCallback] ;
            obj.delegate               = nil ;
           [skin luaRelease:refTable forNSObject:obj.contentView] ;
            obj.contentView            = nil ;
            if (obj.toolbar) {
                [skin luaRelease:refTable forNSObject:obj.toolbar] ;
                obj.toolbar = nil ;
            }
// causes crash in autoreleasepool during reload or quit; did confirm dealloc invoked on gc, though,
// so I guess it doesn't matter. May need to consider wrapper to mimic drawing/canvas/webview behavior of
// requiring explicit delete since this implementation could have multiple ud for the same object still
// floating around
//             obj.releasedWhenClosed     = YES ;
            [obj close] ;
            obj                        = nil ;
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
    {"appearance",                 appearanceCustomization_appearance},

    {"allowTextEntry",             window_allowTextEntry},
    {"closeOnEscape",              window_closeOnEscape},
    {"animationDuration",          window_animationDuration},
    {"hide",                       window_hide},
    {"show",                       window_show},
    {"toggleToolbar",              window_toggleToolbarShown},

    {"alpha",                      window_alphaValue},
    {"animationBehavior",          window_animationBehavior},
    {"backgroundColor",            window_backgroundColor},
    {"collectionBehavior",         window_collectionBehavior},
    {"frame",                      window_frame},
    {"hasShadow",                  window_hasShadow},
    {"ignoresMouseEvents",         window_ignoresMouseEvents},
    {"level",                      window_level},
    {"opaque",                     window_opaque},
    {"orderAbove",                 window_orderAbove},
    {"orderBelow",                 window_orderBelow},
    {"size",                       window_size},
    {"styleMask",                  window_styleMask},
    {"title",                      window_title},
    {"titlebarAppearsTransparent", window_titlebarAppearsTransparent},
    {"titleVisibility",            window_titleVisibility},
    {"topLeft",                    window_topLeft},
    {"isOccluded",                 window_isOccluded},
    {"isShowing",                  window_isShowing},
    {"notificationCallback",       window_notificationCallback},
    {"notificationMessages",       window_notificationWatchFor},
    {"passthroughCallback",        window_passthroughCallback},
    {"content",                    window_contentView},
    {"activeElement",              window_firstResponder},
    {"toolbar",                    window_toolbar},
    {"toolbarStyle",               window_toolbarStyle},

    {"__tostring",                 userdata_tostring},
    {"__eq",                       userdata_eq},
    {"__gc",                       userdata_gc},
    {NULL,                         NULL}
} ;

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"minimumWidth",        window_minFrameWidthWithTitle},
    {"contentRectForFrame", window_contentRectForFrameRect},
    {"frameRectForContent", window_frameRectForContentRect},
    {"new",                 window_new},
    {NULL,                  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_libwindow(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKWindow  forClass:"HSUITKWindow"];
    [skin registerLuaObjectHelper:toHSUITKWindow forClass:"HSUITKWindow"
                                      withUserdataMapping:USERDATA_TAG];

    window_collectionTypeTable(L) ; lua_setfield(L, -2, "behaviors") ;
    window_windowLevels(L) ;        lua_setfield(L, -2, "levels") ;
    window_windowMasksTable(L) ;    lua_setfield(L, -2, "masks") ;
    window_notifications(L) ;       lua_setfield(L, -2, "notifications") ;

    // properties for this item that can be modified through metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"appearance",
        @"allowTextEntry",
        @"closeOnEscape",
        @"animationDuration",
        @"alpha",
        @"animationBehavior",
        @"backgroundColor",
        @"collectionBehavior",
        @"frame",
        @"hasShadow",
        @"ignoresMouseEvents",
        @"level",
        @"opaque",
        @"size",
        @"styleMask",
        @"title",
        @"titlebarAppearsTransparent",
        @"titleVisibility",
        @"topLeft",
        @"notificationCallback",
        @"notificationMessages",
        @"passthroughCallback",
        @"content",
        @"activeElement",
        @"toolbar",
        @"toolbarStyle",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
