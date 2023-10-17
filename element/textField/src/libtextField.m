@import Cocoa ;
@import LuaSkin ;
@import Carbon.HIToolbox.Events ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.textField" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
#define get_anyObjectFromUserdata(objType, L, idx) (objType*)*((void**)lua_touserdata(L, idx))

static NSDictionary *LINE_BREAK_STRATEGIES ;
static NSDictionary *BEZEL_STYLES ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaryies(void) {
    if (@available(macOS 11, *)) {
        LINE_BREAK_STRATEGIES = @{
            @"none"       : @(NSLineBreakStrategyNone),
            @"pushOut"    : @(NSLineBreakStrategyPushOut),
            @"hangulWord" : @(NSLineBreakStrategyHangulWordPriority),
            @"standard"   : @(NSLineBreakStrategyStandard),
        } ;
    } else {
        LINE_BREAK_STRATEGIES = @{
            @"none"       : @(NSLineBreakStrategyNone),
            @"pushOut"    : @(NSLineBreakStrategyPushOut),
        } ;
    }
    BEZEL_STYLES = @{
        @"square" : @(NSTextFieldSquareBezel),
        @"round"  : @(NSTextFieldRoundedBezel),
    } ;
}

@interface NSTextField (Hammerspoon)
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;
@property            int        editingCallbackRef ;

- (int)        selfRefCount ;
- (void)       setSelfRefCount:(int)value ;
- (LSRefTable) refTable ;
- (int)        callbackRef ;
- (void)       setCallbackRef:(int)value ;
- (int)        editingCallbackRef ;
- (void)       setEditingCallbackRef:(int)value ;
@end

BOOL oneOfOurs(NSTextField *obj) {
    return [obj isKindOfClass:[NSView class]]  &&
           [obj respondsToSelector:NSSelectorFromString(@"selfRefCount")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setSelfRefCount:")] &&
           [obj respondsToSelector:NSSelectorFromString(@"refTable")] &&
           [obj respondsToSelector:NSSelectorFromString(@"callbackRef")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setCallbackRef:")] &&
           [obj respondsToSelector:NSSelectorFromString(@"editingCallbackRef")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setEditingCallbackRef:")] ;
}

@interface HSUITKElementTextField : NSTextField <NSTextFieldDelegate>
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        editingCallbackRef ;
@property            int        callbackRef ;
@end

@implementation HSUITKElementTextField

- (void)commonInit {
    _callbackRef        = LUA_NOREF ;
    _editingCallbackRef = LUA_NOREF ;
    _refTable           = refTable ;
    _selfRefCount       = 0 ;

    self.delegate       = self ;
    self.target         = self ;
    self.action         = @selector(performCallback:) ;
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

+ (instancetype)labelFromAttributedString:(NSAttributedString *)attributedStringValue {
    HSUITKElementTextField *textField = [HSUITKElementTextField labelWithAttributedString:attributedStringValue] ;

    if (textField) [textField commonInit] ;
    return textField ;
}

+ (instancetype)labelFromString:(NSString *)stringValue {
    HSUITKElementTextField *textField = [HSUITKElementTextField labelWithString:stringValue] ;

    if (textField) [textField commonInit] ;
    return textField ;
}

+ (instancetype)textFieldFromString:(NSString *)stringValue {
    HSUITKElementTextField *textField = [HSUITKElementTextField textFieldWithString:stringValue] ;

    if (textField) [textField commonInit] ;
    return textField ;
}

+ (instancetype)wrappingLabelFromString:(NSString *)stringValue {
    HSUITKElementTextField *textField = [HSUITKElementTextField wrappingLabelWithString:stringValue] ;

    if (textField) [textField commonInit] ;
    return textField ;
}

// a callback that doesn't have a return value
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
        SEL passthroughCallback = NSSelectorFromString(@"performPassthroughCallback:") ;
        while (nextInChain) {
            if ([nextInChain respondsToSelector:passthroughCallback]) {
                [nextInChain performSelectorOnMainThread:passthroughCallback
                                              withObject:messageParts
                                           waitUntilDone:YES] ;
                break ;
            } else {
                nextInChain = [(NSResponder *)nextInChain nextResponder] ;
            }
        }
    }
}

// a callback expecting a boolean return value
- (BOOL)callbackHamster:(NSArray *)messageParts withDefault:(BOOL)defaultResult {
    BOOL result = defaultResult ;

    if (_editingCallbackRef != LUA_NOREF) {
        LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
        lua_State *L    = skin.L ;
        [skin pushLuaRef:refTable ref:_editingCallbackRef] ;
        for (id part in messageParts) [skin pushNSObject:part] ;
        lua_pushboolean(L, defaultResult) ;
        if (![skin protectedCallAndTraceback:((int)messageParts.count + 1) nresults:1]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            [skin logError:[NSString stringWithFormat:@"%s:editingCallback error:%@", USERDATA_TAG, errorMessage]] ;
        } else {
            if (lua_type(L, -1) != LUA_TNIL) result = (BOOL)(lua_toboolean(L, -1)) ;
        }
        lua_pop(skin.L, 1) ;
    }
    return result ;
}

- (void)performCallback:(__unused id)sender {
    [self callbackHamster:@[ self, self.stringValue ]] ;
}

- (BOOL)performKeyEquivalent:(NSEvent *)event {
    unsigned short       keyCode       = event.keyCode ;
//     NSEventModifierFlags modifierFlags = event.modifierFlags & NSDeviceIndependentModifierFlagsMask ;
//     [LuaSkin logWarn:[NSString stringWithFormat:@"%s:performKeyEquivalent: key:%3d, mods:0x%08lx %@", USERDATA_TAG, keyCode, (unsigned long)modifierFlags, event]] ;

    NSString *keyName = nil ;
    switch (keyCode) {
        case kVK_Return:     keyName = @"return" ; break ; // TODO: test -- I think target/action gets this one
        case kVK_LeftArrow:  keyName = @"left" ;   break ;
        case kVK_RightArrow: keyName = @"right" ;  break ;
        case kVK_DownArrow:  keyName = @"down" ;   break ;
        case kVK_UpArrow:    keyName = @"up" ;     break ;
        case kVK_Escape:     keyName = @"escape" ; break ;
    }

    if (keyName) {
        if ([self callbackHamster:@[ self, @"keyPress", keyName ] withDefault:NO]) return YES ;
    }

    return [super performKeyEquivalent:event] ;
}

// can this be replaced by checking for escape in performKeyEquivalent?
// - (void)cancelOperation:(__unused id)sender {
// }

- (BOOL)textShouldBeginEditing:(NSText *)textObject {
    return [self callbackHamster:@[ self, @"shouldBeginEditing" ]
                     withDefault:[super textShouldBeginEditing:textObject]] ;
}

- (BOOL)textShouldEndEditing:(NSText *)textObject {
    return [self callbackHamster:@[ self, @"shouldEndEditing" ]
                     withDefault:[super textShouldEndEditing:textObject]] ;
}

// - (void)selectText:(id)sender;

// - (void)controlTextDidBeginEditing:(__unused NSNotification *)notification {
- (void)textDidBeginEditing:(__unused NSNotification *)notification {
    [self callbackHamster:@[ self, @"didBeginEditing"]] ;
}

// - (void)controlTextDidChange:(__unused NSNotification *)notification {
- (void)textDidChange:(__unused NSNotification *)notification {
    if (self.continuous) [self callbackHamster:@[ self, @"textDidChange", self.stringValue]] ;
}

// - (void)controlTextDidEndEditing:(NSNotification *)notification {
- (void)textDidEndEditing:(NSNotification *)notification {
    NSNumber   *reasonCodeNumber = notification.userInfo[@"NSTextMovement"] ;
    NSUInteger reasonCode        = reasonCodeNumber ? reasonCodeNumber.unsignedIntValue : NSTextMovementOther ;
    NSString   *reason           = [NSString stringWithFormat:@"unknown reasonCode:%lu", reasonCode] ;

    switch(reasonCode) {
        case NSTextMovementOther:   reason = @"other" ;   break ;
        case NSTextMovementTab:     reason = @"tab" ;     break ;
        case NSTextMovementBacktab: reason = @"backTab" ; break ;

// maybe used in NSTextView, NSText, matrix, or row/cell based text field? Not seen in this one yet...
        case NSTextMovementReturn:  reason = @"return" ;  break ;
        case NSTextMovementLeft:    reason = @"left" ;    break ;
        case NSTextMovementRight:   reason = @"right" ;   break ;
        case NSTextMovementUp:      reason = @"up" ;      break ;
        case NSTextMovementDown:    reason = @"down" ;    break ;
        case NSTextMovementCancel:  reason = @"cancel" ;  break ;
    }

    [self callbackHamster:@[ self, @"didEndEditing", self.stringValue, reason]] ;
}

// NOTE: NSTextFieldDelegate

// - (NSArray<NSTextCheckingResult *> *)textField:(NSTextField *)textField textView:(NSTextView *)textView candidates:(NSArray<NSTextCheckingResult *> *)candidates forSelectedRange:(NSRange)selectedRange;
// - (NSArray *)textField:(NSTextField *)textField textView:(NSTextView *)textView candidatesForSelectedRange:(NSRange)selectedRange;
// - (BOOL)textField:(NSTextField *)textField textView:(NSTextView *)textView shouldSelectCandidateAtIndex:(NSUInteger)index;

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.textField.new([frame]) -> textFieldObject
/// Constructor
/// Creates a new textField element for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the frame for the element.
///
/// Returns:
///  * the textFieldObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a content or to a `hs._asm.uitk.window`.
///
///  * The textField element does not have a default width unless you assign a value to it with [hs._asm.uitk.element.textField:value](#value); if you are assigning an empty textField element to an `hs._asm.uitk.element.content`, be sure to specify a width in the frame details or the element may not be visible.
static int textField_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementTextField *textField = [[HSUITKElementTextField alloc] initWithFrame:frameRect] ;
    if (textField) {
        if (lua_gettop(L) != 1) [textField setFrameSize:[textField fittingSize]] ;
        [skin pushNSObject:textField] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField.newLabel(text) -> textFieldObject
/// Constructor
/// Creates a new textField element usable as a label for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `text` - a string or `hs.styledtext` object specifying the text to assign to the label.
///
/// Returns:
///  * the textFieldObject
///
/// Notes:
///  * This constructor creates a non-editable, non-selectable text field, often used as a label for another element.
///    * If you specify `text` as a string, the label is non-wrapping and appears in the default system font.
///    * If you specify `text` as an `hs.styledtext` object, the line break mode and font are determined by the style attributes of the object.
static int textField_label(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA | LS_TSTRING, "hs.styledtext", LS_TBREAK] ;
    HSUITKElementTextField *element = nil ;

    if (lua_type(L, 1) == LUA_TUSERDATA) {
        element = [HSUITKElementTextField labelFromAttributedString:[skin toNSObjectAtIndex:1]] ;
    } else {
        element = [HSUITKElementTextField labelFromString:[skin toNSObjectAtIndex:1]] ;
    }

    if (element) {
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField.newTextField([text]) -> textFieldObject
/// Constructor
/// Creates a new editable textField element for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `text` - an optional string specifying the text to assign to the text field.
///
/// Returns:
///  * the textFieldObject
///
/// Notes:
///  * This constructor creates a non-wrapping, editable text field, suitable for accepting user input.
static int textField_textField(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *string = (lua_gettop(L) == 0) ? nil : [skin toNSObjectAtIndex:1] ;
    HSUITKElementTextField *element = [HSUITKElementTextField textFieldFromString:string] ;

    if (element) {
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField.newWrappingLabel(text) -> textFieldObject
/// Constructor
/// Creates a new textField element usable as a label for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `text` - a string specifying the text to assign to the label.
///
/// Returns:
///  * the textFieldObject
///
/// Notes:
///  * This constructor creates a wrapping, selectable, non-editable text field, that is suitable for use as a label or informative text. The text defaults to the system font.
static int textField_wrappingLabel(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *string = [skin toNSObjectAtIndex:1] ;
    HSUITKElementTextField *element = [HSUITKElementTextField wrappingLabelFromString:string] ;

    if (element) {
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

/// hs._asm.uitk.element.textField:callback([fn | nil]) -> textFieldObject | fn | nil
/// Method
/// Get or set the callback function which will be invoked whenever the user interacts with the textField element.
///
/// Parameters:
///  * `fn` - a lua function, or explicit nil to remove, which will be invoked when the user interacts with the textField
///
/// Returns:
///  * if a value is provided, returns the textFieldObject ; otherwise returns the current value.
///
/// Notes:
///  * The callback function should expect arguments as described below and return none:
///    * When the user starts typing in the text field, the callback will receive the following arguments:
///      * the textField userdata object
///      * the message string "didBeginEditing" indicating that the user has started editing the textField element
///    * When the focus leaves the text field element, the callback will receive the following arguments (note that it is possible to receive this callback without a corresponding "didBeginEditing" callback if the user makes no changes to the textField):
///      * the textField userdata object
///      * the message string "didEndEditing" indicating that the textField element is no longer active
///      * the current string value of the textField -- see [hs._asm.uitk.element.textField:value](#value)
///      * a string specifying why editing terminated:
///        * "other"    - another element has taken focus or the user has clicked outside of the text field
///        * "return"   - the user has hit the enter or return key. Note that this does not take focus away from the textField by default so if the user types again, another "didBeginEditing" callback for the textField will be generated.
///        * "tab"     - the user used the tab key to move to the next textField element
///        * "backTab" - the user user the tab key with the shift modifier to move to the previous textField element
///
///        * "cancel"  - unknown -- this may belong to textFields or views not yet added
///        * "left"    - unknown -- this may belong to textFields or views not yet added
///        * "right"   - unknown -- this may belong to textFields or views not yet added
///        * "up"      - unknown -- this may belong to textFields or views not yet added
///        * "down"    - unknown -- this may belong to textFields or views not yet added
///
///    * If the `hs._asm.uitk.element._control:continuous` is set to true for the textField element, a callback with the following arguments will occur each time the user presses a key:
///      * the textField userdata object
///      * the string "textDidChange" indicating that the user has typed or deleted something in the textField
///      * the current string value of the textField -- see [hs._asm.uitk.element.textField:value](#value)

/// hs._asm.uitk.element.textField:styleEditable([state]) -> textFieldObject | boolean
/// Method
/// Get or set whether the style (font, color, etc.) of the text in an editable textField can be changed by the user
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not the style of the text can be edited in the textField
///
/// Returns:
///  * if a value is provided, returns the textFieldObject ; otherwise returns the current value.
///
/// Notes:
///  * If the style of a textField element can be edited, the user will be able to access the font and color panels by right-clicking in the text field and selecting the Font submenu from the menu that is shown.
static int textField_allowsEditingTextAttributes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.allowsEditingTextAttributes) ;
    } else {
        element.allowsEditingTextAttributes = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:allowsCharacterPicker([state]) -> textFieldObject | boolean
/// Method
/// Get or set whether the textField allows the use of the touchbar character picker when the textField is editable and is being edited.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether the textField allows the use of the touchbar character picker when the textField is editable and is being edited.
///
/// Returns:
///  * if a value is provided, returns the textFieldObject ; otherwise returns the current value.
static int textField_allowsCharacterPickerTouchBarItem(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.allowsCharacterPickerTouchBarItem) ;
    } else {
        element.allowsCharacterPickerTouchBarItem = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:tighteningForTruncation([state]) -> textFieldObject | boolean
/// Method
/// Get or set whether the system may tighten inter-character spacing in the text field before truncating text.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether the system may tighten inter-character spacing in the text field before truncating text. Has no effect when the textField is assigned an `hs.styledtext` object.
///
/// Returns:
///  * if a value is provided, returns the textFieldObject ; otherwise returns the current value.
static int textField_allowsDefaultTighteningForTruncation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.allowsDefaultTighteningForTruncation) ;
    } else {
        element.allowsDefaultTighteningForTruncation = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:drawsBackground([state]) -> textFieldObject | boolean
/// Method
/// Get or set whether the background of the textField is shown
///
/// Parameters:
///  * `state` - an optional boolean specifying whether the background of the textField is shown (true) or transparent (false). Defaults to `true` for editable textFields created with [hs._asm.uitk.element.textField.newTextField](#newTextField), otherwise false.
///
/// Returns:
///  * if a value is provided, returns the textFieldObject ; otherwise returns the current value.
static int textField_drawsBackground(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.drawsBackground) ;
    } else {
        element.drawsBackground = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:importsGraphics([state]) -> textFieldObject | boolean
/// Method
/// Get or set whether an editable textField whose style is editable allows image files to be dragged into it
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether the textField allows image files to be dragged into it
///
/// Returns:
///  * if a value is provided, returns the textFieldObject ; otherwise returns the current value.
///
/// Notes:
///  * [hs._asm.uitk.element.textField:styleEditable](#styleEditable) must also be true for this method to have any effect.
static int textField_importsGraphics(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.importsGraphics) ;
    } else {
        element.importsGraphics = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:bezeled([state]) -> textFieldObject | boolean
/// Method
/// Get or set whether the textField draws a bezeled border around its contents.
///
/// Parameters:
///  * `state` - an optional boolean specifying whether the textField draws a bezeled border around its contents. Defaults to `true` for editable textFields created with [hs._asm.uitk.element.textField.newTextField](#newTextField), otherwise false.
///
/// Returns:
///  * if a value is provided, returns the textFieldObject ; otherwise returns the current value.
///
/// Notes:
///  * If you set this to true, [hs._asm.uitk.element.textField:bordered](#bordered) is set to false.
static int textField_bezeled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.bezeled) ;
    } else {
        element.bezeled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:bordered([state]) -> textFieldObject | boolean
/// Method
/// Get or set whether the textField draws a black border around its contents.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether the textField draws a black border around its contents.
///
/// Returns:
///  * if a value is provided, returns the textFieldObject ; otherwise returns the current value.
///
/// Notes:
///  * If you set this to true, [hs._asm.uitk.element.textField:bezeled](#bezeled) is set to false.
static int textField_bordered(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.bordered) ;
    } else {
        element.bordered = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:editable([state]) -> textFieldObject | boolean
/// Method
/// Get or set whether the textField is editable.
///
/// Parameters:
///  * `state` - an optional boolean specifying whether the textField contents are editable. Defaults to `true` for editable textFields created with [hs._asm.uitk.element.textField.newTextField](#newTextField), otherwise false.
///
/// Returns:
///  * if a value is provided, returns the textFieldObject ; otherwise returns the current value.
///
/// Notes:
///  * Setting this to true automatically sets [hs._asm.uitk.element.textField:selectable](#selectable) to true.
static int textField_editable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.editable) ;
    } else {
        element.editable = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:selectable([state]) -> textFieldObject | boolean
/// Method
/// Get or set whether the contents of the textField is selectable.
///
/// Parameters:
///  * `state` - an optional boolean specifying whether the textField contents are selectable. Defaults to `true` for textFields created with [hs._asm.uitk.element.textField.newTextField](#newTextField) or [hs._asm.uitk.element.textField.newWrappingLabel](#newWrappingLabel), otherwise false.
///
/// Returns:
///  * if a value is provided, returns the textFieldObject ; otherwise returns the current value.
///
/// Notes:
///  * Setting this to false automatically sets [hs._asm.uitk.element.textField:editable](#editable) to false.
static int textField_selectable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.selectable) ;
    } else {
        element.selectable = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:expandIntoTooltip([state]) -> textFieldObject | boolean
/// Method
/// Get or set whether the textField contents will be expanded into a tooltip if the contents are longer than the textField is wide and the mouse pointer hovers over the textField.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether the textField contents will be expanded into a tooltip if the contents are longer than the textField is wide.
///
/// Returns:
///  * if a value is provided, returns the textFieldObject ; otherwise returns the current value.
///
/// Notes:
///  * If a tooltip is set with `hs._asm.uitk.element._control:tooltip` then this method has no effect.
static int textField_allowsExpansionToolTips(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.allowsExpansionToolTips) ;
    } else {
        element.allowsExpansionToolTips = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:automaticTextCompletion([state]) -> textFieldObject | boolean
/// Method
/// Get or set whether automatic text completion is enabled when the textField is being edited.
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether automatic text completion is enabled when the textField is being edited.
///
/// Returns:
///  * if a value is provided, returns the textFieldObject ; otherwise returns the current value.
static int textField_automaticTextCompletionEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.automaticTextCompletionEnabled) ;
    } else {
        element.automaticTextCompletionEnabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textField_truncatesLastVisibleLine(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.cell.truncatesLastVisibleLine) ;
    } else {
        element.cell.truncatesLastVisibleLine = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:preferredMaxWidth([width]) -> textFieldObject | number
/// Method
/// Get or set the preferred layout width for the textField
///
/// Parameters:
///  * `width` - an optional number, default 0.0, specifying the preferred width of the textField
///
/// Returns:
///  * if a value is provided, returns the textFieldObject ; otherwise returns the current value.
static int textField_preferredMaxLayoutWidth(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.preferredMaxLayoutWidth) ;
    } else {
        CGFloat newWidth = lua_tonumber(L, 2) ;
        if (newWidth < 0) newWidth = 0 ;
        element.preferredMaxLayoutWidth = newWidth ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:maximumNumberOfLines([lines]) -> textFieldObject | integer
/// Method
/// Get or set the maximum number of lines that can be displayed in the textField.
///
/// Parameters:
///  * `lines` - an optional integer, default 0, specifying the maximum number of lines that can be displayed in the textField. A value of 0 indicates that there is no limit.
///
/// Returns:
///  * if a value is provided, returns the textFieldObject ; otherwise returns the current value.
///
/// Notes:
///  * If the text reaches the number of lines allowed, or the height of the container cannot accommodate the number of lines needed, the text will be clipped or truncated.
///    * Affects the default fitting size when the textField is assigned to an `hs._asm.uitk.element.content` object if the textField element's height and width are not specified when assigned.
static int textField_maximumNumberOfLines(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, element.maximumNumberOfLines) ;
    } else {
        NSInteger maxLines = lua_tointeger(L, 2) ;
        if (maxLines < 0) maxLines = 0 ;
        element.maximumNumberOfLines = maxLines ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:backgroundColor([color]) -> textFieldObject | color table
/// Method
/// Get or set the color for the background of the textField element.
///
/// Parameters:
/// * `color` - an optional table containing color keys as described in `hs.drawing.color`
///
/// Returns:
///  * If an argument is provided, the textFieldObject; otherwise the current value.
///
/// Notes:
///  * The background color will only be drawn when [hs._asm.uitk.element.textField:drawsBackground](#drawsBackground) is true.
static int textField_backgroundColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:element.backgroundColor] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            element.backgroundColor = nil ;
        } else {
            element.backgroundColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:textColor([color]) -> textFieldObject | color table
/// Method
/// Get or set the color for the the text in a textField element.
///
/// Parameters:
/// * `color` - an optional table containing color keys as described in `hs.drawing.color`
///
/// Returns:
///  * If an argument is provided, the textFieldObject; otherwise the current value.
///
/// Notes:
///  * Has no effect on portions of an `hs.styledtext` value that specifies the text color for the object
static int textField_textColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:element.textColor] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            element.textColor = nil ;
        } else {
            element.textColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:selectAll() -> textFieldObject
/// Method
/// Selects the text of a selectable or editable textField and makes it the active element in the window.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the textFieldObject
///
/// Notes:
///  * This method has no effect if the textField is not editable or selectable.  Use `hs._asm.uitk.window:activeElement` if you wish to remove the focus from any textField that is currently selected.
static int textField_selectText(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    [element selectText:element] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.element.textField:editingCallback([fn | nil]) -> textFieldObject | fn | nil
/// Method
/// Get or set the callback function which will is invoked to make editing decisions about the textField
///
/// Parameters:
///  * `fn` - a lua function, or explicit nil to remove, which will be invoked to make editing decisions about the textField
///
/// Returns:
///  * if a value is provided, returns the textFieldObject ; otherwise returns the current value.
///
/// Notes:
///  * The callback function should expect multiple arguments and return a boolean as described below (a return value of none or nil will use the default as specified for each callback below):
///    * When the user attempts to edit the textField, the callback will be invoked with the following arguments and the boolean return value should indicate whether editing is to be allowed:
///      * the textField userdata object
///      * the string "shouldBeginEditing" indicating that the callback is asking permission to allow editing of the textField at this time
///      * the default return value as determined by the current state of the the textField and its location in the window/view hierarchy (usually this will be true)
///    * When the user attempts to finish editing the textField, the callback will be invoked with the following arguments and the boolean return value should indicate whether focus is allowed to leave the textField:
///      * the textField userdata object
///      * the string "shouldEndEditing" indicating that the callback is asking permission to complete editing of the textField at this time
///      * the default return value as determined by the current state of the the textField and its location in the window/view hierarchy (usually this will be true)
///    * When the return (or enter) key or escape key are pressed, the callback will be invoked with the following arguments and the return value should indicate whether or not the keypress was handled by the callback or should be passed further up the window/view hierarchy:
///      * the textField userdata object
///      * the string "keyPress"
///      * the string "return" or "escape"
///      * the default return value of false indicating that the callback is not interested in this keypress.
///    * Note that the specification allows for the additional keys "left", "right", "up", and "down" to trigger this callback, but at present it is not known how to enable this for a textField element. It is surmised that they may be applicable to text based elements that are not currently supported by `hs._asm.uitk.window`. If you do manage to receive a callback for one of these keys, please submit an issue with sample code so we can determine how to properly document them.
static int textField_editingCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 2) {
        element.editingCallbackRef = [skin luaUnref:refTable ref:element.editingCallbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            element.editingCallbackRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (element.editingCallbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:element.editingCallbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:bezelStyle([style]) -> textFieldObject | string
/// Method
/// Get or set whether the corners of a bezeled textField are rounded or square
///
/// Parameters:
///  * `style` - an optional string, default "square", specifying whether the corners of a bezeled textField are rounded or square. Must be one of "square" or "round".
///
/// Returns:
///  * if a value is provided, returns the textFieldObject ; otherwise returns the current value.
///
/// Notes:
///  * only has an effect if [hs._asm.uitk.element.textField:bezeled](#bezeled) is true.
static int textField_bezelStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        NSNumber *number = @(element.bezelStyle) ;
        NSArray  *temp   = [BEZEL_STYLES allKeysForObject:number];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized bezel style %@ -- notify developers", USERDATA_TAG, number]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key    = [skin toNSObjectAtIndex:2] ;
        NSNumber *number = BEZEL_STYLES[key] ;
        if (number) {
            element.bezelStyle = [number unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[BEZEL_STYLES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int textField_lineBreakStrategy(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1) {
        NSNumber *number = @(element.lineBreakStrategy) ;
        NSArray  *temp   = [LINE_BREAK_STRATEGIES allKeysForObject:number];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized line break strategy %@ -- notify developers", USERDATA_TAG, number]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key    = [skin toNSObjectAtIndex:2] ;
        NSNumber *number = LINE_BREAK_STRATEGIES[key] ;
        if (number) {
            element.lineBreakStrategy = [number unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[LINE_BREAK_STRATEGIES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:placeholderString([placeholder]) -> textFieldObject | string
/// Method
/// Get or set the placeholder string for the textField.
///
/// Parameters:
/// * `placeholder` - an optional string or `hs.styledtext` object, or an explicit nil to remove, specifying the placeholder string for a textField. The place holder string is displayed in a light color when the content of the textField is empty (i.e. is set to nil or the empty string "")
///
/// Returns:
///  * If an argument is provided, the textFieldObject; otherwise the current value.
static int textField_placeholder(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1 || lua_type(L, 2) == LUA_TBOOLEAN) {
        if (lua_type(L, 2) == LUA_TBOOLEAN && lua_toboolean(L, 2)) {
            [skin pushNSObject:element.placeholderAttributedString] ;
        } else {
            [skin pushNSObject:element.placeholderString] ;
        }
    } else {
        if (lua_type(L, 2) == LUA_TSTRING) {
            element.placeholderString = [skin toNSObjectAtIndex:2] ;
        } else {
            [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs.styledtext", LS_TBREAK] ;
            element.placeholderAttributedString = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.textField:value([value] | [type]) -> textFieldObject | string | styledtextObject
/// Method
/// Get or set the contents of the textField.
///
/// Parameters:
///  * to set the textField content:
///    * `value` - an optional string or `hs.styledtext` object specifying the contents to display in the textField
///  * to get the current content of the textField:
///    * `type`  - an optional boolean, default false, specifying if the value retrieved should be as an `hs.styledtext` object (true) or a string (false).
///
/// Returns:
///  * If a string or `hs.styledtext` object is assigned with this method, returns the textFieldObject; otherwise returns the value in the type requested or most recently assigned.
static int textField_value(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    NSTextField *element = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!element || !oneOfOurs(element)) {
        return luaL_argerror(L, 1, "expected userdata representing a textField element") ;
    }

    if (lua_gettop(L) == 1 || lua_type(L, 2) == LUA_TBOOLEAN) {
        if (lua_type(L, 2) == LUA_TBOOLEAN && lua_toboolean(L, 2)) {
            [skin pushNSObject:element.attributedStringValue] ;
        } else {
            [skin pushNSObject:element.stringValue] ;
        }
    } else {
        if (lua_type(L, 2) == LUA_TSTRING) {
            element.stringValue = [skin toNSObjectAtIndex:2] ;
        } else {
            [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs.styledtext", LS_TBREAK] ;
            element.attributedStringValue = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementTextField(lua_State *L, id obj) {
    HSUITKElementTextField *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementTextField *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementTextFieldFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementTextField *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementTextField, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_gc(lua_State* L) {
    NSTextField *obj  = get_anyObjectFromUserdata(__bridge_transfer NSTextField, L, 1) ;

    obj.selfRefCount-- ;
    if (obj.selfRefCount == 0) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        obj.callbackRef        = [skin luaUnref:obj.refTable ref:obj.callbackRef] ;
        obj.editingCallbackRef = [skin luaUnref:obj.refTable ref:obj.editingCallbackRef] ;
        obj = nil ;
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"styleEditable",           textField_allowsEditingTextAttributes},
    {"characterPicker",         textField_allowsCharacterPickerTouchBarItem},
    {"tightenBeforeTruncation", textField_allowsDefaultTighteningForTruncation},
    {"drawBackground",          textField_drawsBackground},
    {"importGraphics",          textField_importsGraphics},
    {"bezeled",                 textField_bezeled},
    {"bordered",                textField_bordered},
    {"editable",                textField_editable},
    {"selectable",              textField_selectable},
    {"expansionToolTip",        textField_allowsExpansionToolTips},
    {"textCompletion",          textField_automaticTextCompletionEnabled},
    {"truncateLastLine",        textField_truncatesLastVisibleLine},
    {"maxWidth",                textField_preferredMaxLayoutWidth},
    {"maxLines",                textField_maximumNumberOfLines},
    {"backgroundColor",         textField_backgroundColor},
    {"textColor",               textField_textColor},
    {"selectAll",               textField_selectText},
    {"editingCallback",         textField_editingCallback},
    {"bezelStyle",              textField_bezelStyle},
    {"lineBreakStrategy",       textField_lineBreakStrategy},
    {"placeholder",             textField_placeholder},
    {"value",                   textField_value},

// other metamethods inherited from _control and _view
    {"__gc",                    userdata_gc},
    {NULL,                      NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",              textField_new},
    {"newLabel",         textField_label},
    {"newTextField",     textField_textField},
    {"newWrappingLabel", textField_wrappingLabel},
    {NULL,               NULL}
};

int luaopen_hs__asm_uitk_element_libtextField(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaryies() ;

    [skin registerPushNSHelper:pushHSUITKElementTextField         forClass:"HSUITKElementTextField"];
    [skin registerLuaObjectHelper:toHSUITKElementTextFieldFromLua forClass:"HSUITKElementTextField"
                                                        withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through content metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"styleEditable",
        @"characterPicker",
        @"tightenBeforeTruncation",
        @"drawBackground",
        @"importGraphics",
        @"bezeled",
        @"bordered",
        @"editable",
        @"selectable",
        @"expansionToolTip",
        @"textCompletion",
        @"truncateLastLine",
        @"maxWidth",
        @"maxLines",
        @"backgroundColor",
        @"textColor",
        @"editingCallback",
        @"bezelStyle",
        @"lineBreakStrategy",
        @"placeholder",
        @"value",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}
