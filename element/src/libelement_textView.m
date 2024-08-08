@import Cocoa ;
@import LuaSkin ;
@import Carbon.HIToolbox.Events ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.textView" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *TEXTVIEW_SELECTION_GRANULARITY ;
static NSDictionary *TEXT_LINEBREAK ;
static NSArray      *TEXTVIEW_ACTIONS ;

#pragma mark - Support Functions and Classes -

static int NSAttributedStringKeyDictionary_toLua(lua_State *L, id obj) ;

static void defineInternalDictionaries(void) {
    TEXTVIEW_SELECTION_GRANULARITY = @{
        @"character" : @(NSSelectByCharacter),
        @"word"      : @(NSSelectByWord),
        @"paragraph" : @(NSSelectByParagraph),
    } ;

    TEXT_LINEBREAK = @{
        @"wordWrap"       : @(NSLineBreakByWordWrapping),
        @"charWrap"       : @(NSLineBreakByCharWrapping),
        @"clip"           : @(NSLineBreakByClipping),
        @"truncateHead"   : @(NSLineBreakByTruncatingHead),
        @"truncateTail"   : @(NSLineBreakByTruncatingTail),
        @"truncateMiddle" : @(NSLineBreakByTruncatingMiddle),
    } ;

    TEXTVIEW_ACTIONS = @[
        @"alignCenter",
        @"alignJustified",
        @"alignLeft",
        @"alignRight",
        @"changeAttributes",                    // TODO: [element convertAttributes:]
        @"changeColor",                         // TODO: [element color]
        @"changeDocumentBackgroundColor",       // TODO: [element color]
        @"changeFont",                          // sends a convertFont: message to the shared NSFontManager
        @"changeLayoutOrientation",
        @"checkSpelling",
        @"checkTextInDocument",                 // Done enabledTextCheckingTypes
        @"checkTextInSelection",                // Done enabledTextCheckingTypes
        @"complete",
        @"copy",
        @"copyFont",
        @"copyRuler",
        @"cut",
        @"delete",
        @"loosenKerning",
        @"lowerBaseline",
        @"orderFrontLinkPanel",
        @"orderFrontListPanel",
        @"orderFrontSharingServicePicker",
        @"orderFrontSpacingPanel",
        @"orderFrontSubstitutionsPanel",
        @"orderFrontTablePanel",
        @"outline",
        @"paste",
        @"pasteAsPlainText",
        @"pasteAsRichText",
        @"pasteFont",
        @"pasteRuler",
        @"performFindPanelAction",
        @"raiseBaseline",
        @"selectAll",
        @"showGuessPanel",
        @"startSpeaking",
        @"stopSpeaking",
        @"subscript",
        @"superscript",
        @"tightenKerning",
        @"toggleAutomaticDashSubstitution",
        @"toggleAutomaticDataDetection",
        @"toggleAutomaticLinkDetection",
        @"toggleAutomaticQuoteSubstitution",
        @"toggleAutomaticSpellingCorrection",
        @"toggleAutomaticTextCompletion",
        @"toggleAutomaticTextReplacement",
        @"toggleContinuousSpellChecking",
        @"toggleGrammarChecking",
//         @"toggleQuickLookPreviewPanel",
        @"toggleSmartInsertDelete",
        @"toggleRuler",
        @"turnOffKerning",
        @"turnOffLigatures",
        @"underline",
        @"unscript",
        @"useAllLigatures",
        @"useStandardKerning",
        @"useStandardLigatures",
    ] ;
}

// Lua treats strings (and therefore indexes within strings) as a sequence of bytes.  Objective-C's
// NSString and NSAttributedString treat them as a sequence of characters.  This works fine until
// Unicode characters are involved.
//
// This function creates a dictionary mapping of this where the keys are the byte positions in the
// Lua string and the values are the corresponding character positions in the NSString.
NSDictionary *luaByteToObjCharMap(NSString *theString) {
    NSMutableDictionary *luaByteToObjChar = [[NSMutableDictionary alloc] init];

    NSUInteger luaPos = 1 ;
    for (NSUInteger i = 0 ; i < theString.length ; i++) {
        NSString *utf16Char = [theString substringWithRange:NSMakeRange(i, 1)] ;
        unichar utf16Unichar = [utf16Char characterAtIndex:0] ;
        if (CFStringIsSurrogateHighCharacter(utf16Unichar)) {
            utf16Char = [theString substringWithRange:NSMakeRange(i, 2)] ;
        }
        NSData     *utf8Data        = [utf16Char dataUsingEncoding:NSUTF8StringEncoding] ;
        NSUInteger dataLength       = utf8Data.length ;
        BOOL       surrogateHandled = (utf16Char.length == 1) ; // false only required if length = 2

        for (NSUInteger j = 0 ; j < dataLength ; j++) {
            // trick for high/low surrogate pairs
            if (!surrogateHandled && j >= (dataLength / 2)) {
                i++ ;
                surrogateHandled = YES ;
            }
            [luaByteToObjChar setObject:[NSNumber numberWithUnsignedInteger:i + 1]
                                 forKey:[NSNumber numberWithUnsignedInteger:luaPos]];
            luaPos++ ;
        }
    }

    return luaByteToObjChar;
}

@interface HSUITKElementTextView : NSTextView <NSTextViewDelegate>
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;
@property            int        editingCallbackRef ;
@property            int        completionsRef ;
@property            BOOL       continuousTextDidChange ;
@end

@implementation HSUITKElementTextView
- (instancetype)initWithFrame:(NSRect)frameRect {
    @try {
        self = [super initWithFrame:frameRect] ;
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:new - %@", USERDATA_TAG, exception.reason]] ;
        self = nil ;
    }

    if (self) {
        _callbackRef             = LUA_NOREF ;
        _editingCallbackRef      = LUA_NOREF ;
        _completionsRef          = LUA_NOREF ;
        _refTable                = refTable ;
        _selfRefCount            = 0 ;
        _continuousTextDidChange = false ;

        self.delegate            = self ;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didChangeSelectionNotification:)
                                                     name:NSTextViewDidChangeSelectionNotification
                                                   object:self] ;
    }
    return self ;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSTextViewDidChangeSelectionNotification
                                                  object:self] ;
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

// FIXME: if len = 0 but old range didn't, we should still call callback (released selection)... look at userInfo dict
- (void)didChangeSelectionNotification:(NSNotification *)notification {
    NSRange selectionRange = self.selectedRange ;
    if (selectionRange.length != 0) {
        NSDictionary *map = luaByteToObjCharMap(self.textStorage.string) ;
        NSInteger i = ((NSNumber *)[[map allKeysForObject:@(selectionRange.location + 1)] firstObject]).integerValue ;
        NSInteger j = ((NSNumber *)[[map allKeysForObject:@(selectionRange.location + selectionRange.length)] firstObject]).integerValue ;
        [self callbackHamster:@[ self, @"didChangeSelection", @(i), @(j) ]] ;
    }
}

// - (BOOL)resignFirstResponder {
//     [self callbackHamster:@[ self, @"resignFirstResponder" ]] ;
//     return [super resignFirstResponder] ;
// }

- (BOOL)textShouldBeginEditing:(NSText *)textObject {
    return [self callbackHamster:@[ self, @"shouldBeginEditing" ] withDefault:YES] ;
}

- (void)textDidBeginEditing:(NSNotification *)notification {
    [self callbackHamster:@[ self, @"didBeginEditing" ]] ;
}

- (void)textDidChange:(NSNotification *)notification {
    if (_continuousTextDidChange) [self callbackHamster:@[ self, @"textDidChange" ]] ;
}

- (void)textDidEndEditing:(NSNotification *)notification {
    [self callbackHamster:@[ self, @"didEndEditing" ]] ;
}

- (BOOL)textShouldEndEditing:(NSText *)textObject {
    return [self callbackHamster:@[ self, @"shouldEndEditing" ] withDefault:YES] ;
}

- (NSArray<NSString *> *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index {
    if (_completionsRef == LUA_NOREF) {
        return [super completionsForPartialWordRange:charRange indexOfSelectedItem:index] ;
    } else {
        NSArray   *completions = [NSArray array] ;
        NSString  *prefix      = [self.string substringWithRange:charRange] ;
        LuaSkin   *skin        = [LuaSkin sharedWithState:NULL] ;
        lua_State *L           = skin.L ;

        *index = 0 ;

        [skin pushLuaRef:refTable ref:_completionsRef] ;

        BOOL isFunction = (lua_type(L, -1) == LUA_TFUNCTION) ;
        if (!isFunction && lua_getmetatable(L, -1)) {
            lua_getfield(L, -1, "__call") ;
            isFunction = (lua_type(L, -1) != LUA_TNIL) ;
            lua_pop(L, 2) ;
        }

        if (isFunction) {
            [skin pushNSObject:self] ;
            [skin pushNSObject:prefix] ;
            if ([skin protectedCallAndTraceback:2 nresults:2]) {
                if (lua_type(L, -2) == LUA_TTABLE) {
// FIXME validate array and in setup function
                    completions = [skin toNSObjectAtIndex:-2] ;
                }
                if (lua_type(L, -1) == LUA_TNUMBER && lua_isinteger(L, -1)) {
                    *index = lua_tointeger(L, -1) ;
                }
                lua_pop(L, 2) ;
            } else {
                [skin logError:[NSString stringWithFormat:@"%s:completions error:%s", USERDATA_TAG, lua_tostring(L, -1)]] ;
                lua_pop(L, 1) ;
            }
        } else {
            NSMutableArray *found = [NSMutableArray array] ;
            NSArray        *list  = [skin toNSObjectAtIndex:-1] ;
            lua_pop(L, 1) ;

            [list enumerateObjectsUsingBlock:^(NSString *value, __unused NSUInteger idx, __unused BOOL *stop) {
                if ([value hasPrefix:prefix]) [found addObject:value] ;
            }] ;
            completions = [found copy] ;
        }

        NSObject<NSTextViewDelegate> *delegate = self.delegate ;
        if (delegate && [delegate respondsToSelector:NSSelectorFromString(@"textView:completions:forPartialWordRange:indexOfSelectedItem:")]) {
            return [delegate textView:self
                               completions:completions
                       forPartialWordRange:charRange
                       indexOfSelectedItem:index] ;
        }
        return completions ;
    }
}

// NOTE: NSTextViewDelegate Stuff

// FIXME: *are* there any editing callbacks we want to implement? (i.e. ones that return a boolean affecting behavior?

// - (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)link atIndex:(NSUInteger)charIndex;
// - (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)link;
// - (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector;
// - (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString;
// - (BOOL)textView:(NSTextView *)textView shouldChangeTextInRanges:(NSArray<NSValue *> *)affectedRanges replacementStrings:(NSArray<NSString *> *)replacementStrings;
// - (BOOL)textView:(NSTextView *)textView shouldSelectCandidateAtIndex:(NSUInteger)index;
// - (BOOL)textView:(NSTextView *)view writeCell:(id<NSTextAttachmentCell>)cell atIndex:(NSUInteger)charIndex toPasteboard:(NSPasteboard *)pboard type:(NSPasteboardType)type;

// - (NSArray *)textView:(NSTextView *)textView candidatesForSelectedRange:(NSRange)selectedRange;
// - (NSArray<NSPasteboardType> *)textView:(NSTextView *)view writablePasteboardTypesForCell:(id<NSTextAttachmentCell>)cell atIndex:(NSUInteger)charIndex;
// - (NSArray<NSString *> *)textView:(NSTextView *)textView completions:(NSArray<NSString *> *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
// - (NSArray<NSTextCheckingResult *> *)textView:(NSTextView *)textView candidates:(NSArray<NSTextCheckingResult *> *)candidates forSelectedRange:(NSRange)selectedRange;
// - (NSArray<NSTextCheckingResult *> *)textView:(NSTextView *)view didCheckTextInRange:(NSRange)range types:(NSTextCheckingTypes)checkingTypes options:(NSDictionary<NSTextCheckingOptionKey, id> *)options results:(NSArray<NSTextCheckingResult *> *)results orthography:(NSOrthography *)orthography wordCount:(NSInteger)wordCount;
// - (NSArray<NSTouchBarItemIdentifier> *)textView:(NSTextView *)textView shouldUpdateTouchBarItemIdentifiers:(NSArray<NSTouchBarItemIdentifier> *)identifiers;
// - (NSArray<NSValue *> *)textView:(NSTextView *)textView willChangeSelectionFromCharacterRanges:(NSArray<NSValue *> *)oldSelectedCharRanges toCharacterRanges:(NSArray<NSValue *> *)newSelectedCharRanges;
// - (NSDictionary<NSAttributedStringKey, id> *)textView:(NSTextView *)textView shouldChangeTypingAttributes:(NSDictionary<NSString *,id> *)oldTypingAttributes toAttributes:(NSDictionary<NSAttributedStringKey, id> *)newTypingAttributes;
// - (NSDictionary<NSTextCheckingOptionKey, id> *)textView:(NSTextView *)view willCheckTextInRange:(NSRange)range options:(NSDictionary<NSTextCheckingOptionKey, id> *)options types:(NSTextCheckingTypes *)checkingTypes;
// - (NSInteger)textView:(NSTextView *)textView shouldSetSpellingState:(NSInteger)value range:(NSRange)affectedCharRange;
// - (NSMenu *)textView:(NSTextView *)view menu:(NSMenu *)menu forEvent:(NSEvent *)event atIndex:(NSUInteger)charIndex;
// - (NSRange)textView:(NSTextView *)textView willChangeSelectionFromCharacterRange:(NSRange)oldSelectedCharRange toCharacterRange:(NSRange)newSelectedCharRange;
// - (NSSharingServicePicker *)textView:(NSTextView *)textView willShowSharingServicePicker:(NSSharingServicePicker *)servicePicker forItems:(NSArray *)items;
// - (NSString *)textView:(NSTextView *)textView willDisplayToolTip:(NSString *)tooltip forCharacterAtIndex:(NSUInteger)characterIndex;
// - (NSUndoManager *)undoManagerForTextView:(NSTextView *)view;
// - (NSURL *)textView:(NSTextView *)textView URLForContentsOfTextAttachment:(NSTextAttachment *)textAttachment atIndex:(NSUInteger)charIndex;
// - (void)textView:(NSTextView *)textView clickedOnCell:(id<NSTextAttachmentCell>)cell inRect:(NSRect)cellFrame atIndex:(NSUInteger)charIndex;
// - (void)textView:(NSTextView *)textView clickedOnCell:(id<NSTextAttachmentCell>)cell inRect:(NSRect)cellFrame;
// - (void)textView:(NSTextView *)textView doubleClickedOnCell:(id<NSTextAttachmentCell>)cell inRect:(NSRect)cellFrame atIndex:(NSUInteger)charIndex;
// - (void)textView:(NSTextView *)textView doubleClickedOnCell:(id<NSTextAttachmentCell>)cell inRect:(NSRect)cellFrame;
// - (void)textView:(NSTextView *)view draggedCell:(id<NSTextAttachmentCell>)cell inRect:(NSRect)rect event:(NSEvent *)event atIndex:(NSUInteger)charIndex;
// - (void)textView:(NSTextView *)view draggedCell:(id<NSTextAttachmentCell>)cell inRect:(NSRect)rect event:(NSEvent *)event;
// - (void)textViewDidChangeSelection:(NSNotification *)notification;
// - (void)textViewDidChangeTypingAttributes:(NSNotification *)notification;

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.textView.new([frame]) -> textViewObject
/// Constructor
/// Creates a new textView element for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the frame for the element.
///
/// Returns:
///  * the textViewObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a container element or to a `hs._asm.uitk.window`.
static int textView_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementTextView *element = [[HSUITKElementTextView alloc] initWithFrame:frameRect];
    if (element) {
        if (lua_gettop(L) != 1) [element setFrameSize:[element fittingSize]] ;
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

static int textView_completions(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        element.completionsRef = [skin luaUnref:refTable ref:element.completionsRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            element.completionsRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (element.completionsRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:element.completionsRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int textView_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        element.callbackRef = [skin luaUnref:refTable ref:element.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            element.callbackRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (element.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:element.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int textView_editingCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

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

static int textView_continuousTextDidChange(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.continuousTextDidChange) ;
    } else {
        element.continuousTextDidChange = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_acceptsGlyphInfo(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.acceptsGlyphInfo) ;
    } else {
        element.acceptsGlyphInfo = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_allowsCharacterPickerTouchBarItem(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.allowsCharacterPickerTouchBarItem) ;
    } else {
        element.allowsCharacterPickerTouchBarItem = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_allowsDocumentBackgroundColorChange(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.allowsDocumentBackgroundColorChange) ;
    } else {
        element.allowsDocumentBackgroundColorChange = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_allowsImageEditing(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.allowsImageEditing) ;
    } else {
        element.allowsImageEditing = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_allowsUndo(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.allowsUndo) ;
    } else {
        element.allowsUndo = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_displaysLinkToolTips(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.displaysLinkToolTips) ;
    } else {
        element.displaysLinkToolTips = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_drawsBackground(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.drawsBackground) ;
    } else {
        element.drawsBackground = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_importsGraphics(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.importsGraphics) ;
    } else {
        element.importsGraphics = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_smartInsertDeleteEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.smartInsertDeleteEnabled) ;
    } else {
        element.smartInsertDeleteEnabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_usesAdaptiveColorMappingForDarkAppearance(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.usesAdaptiveColorMappingForDarkAppearance) ;
    } else {
        element.usesAdaptiveColorMappingForDarkAppearance = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_usesFindBar(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.usesFindBar) ;
    } else {
        element.usesFindBar = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_usesFindPanel(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.usesFindPanel) ;
    } else {
        element.usesFindPanel = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_usesFontPanel(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.usesFontPanel) ;
    } else {
        element.usesFontPanel = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_usesInspectorBar(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.usesInspectorBar) ;
    } else {
        element.usesInspectorBar = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_usesRolloverButtonForSelection(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.usesRolloverButtonForSelection) ;
    } else {
        element.usesRolloverButtonForSelection = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_usesRuler(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.usesRuler) ;
    } else {
        element.usesRuler = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_automaticDashSubstitutionEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.automaticDashSubstitutionEnabled) ;
    } else {
        element.automaticDashSubstitutionEnabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_automaticDataDetectionEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.automaticDataDetectionEnabled) ;
    } else {
        element.automaticDataDetectionEnabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_automaticLinkDetectionEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.automaticLinkDetectionEnabled) ;
    } else {
        element.automaticLinkDetectionEnabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_automaticQuoteSubstitutionEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.automaticQuoteSubstitutionEnabled) ;
    } else {
        element.automaticQuoteSubstitutionEnabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_automaticSpellingCorrectionEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.automaticSpellingCorrectionEnabled) ;
    } else {
        element.automaticSpellingCorrectionEnabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_automaticTextCompletionEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.automaticTextCompletionEnabled) ;
    } else {
        element.automaticTextCompletionEnabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_automaticTextReplacementEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.automaticTextReplacementEnabled) ;
    } else {
        element.automaticTextReplacementEnabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_continuousSpellCheckingEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.continuousSpellCheckingEnabled) ;
    } else {
        element.continuousSpellCheckingEnabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_editable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.editable) ;
    } else {
        element.editable = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_fieldEditor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.fieldEditor) ;
    } else {
        element.fieldEditor = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_grammarCheckingEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.grammarCheckingEnabled) ;
    } else {
        element.grammarCheckingEnabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_incrementalSearchingEnabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.incrementalSearchingEnabled) ;
    } else {
        element.incrementalSearchingEnabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_richText(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.richText) ;
    } else {
        element.richText = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_rulerVisible(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.rulerVisible) ;
    } else {
        element.rulerVisible = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_selectable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.selectable) ;
    } else {
        element.selectable = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_backgroundColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:element.backgroundColor] ;
    } else {
        element.backgroundColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_insertionPointColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:element.insertionPointColor] ;
    } else {
        element.insertionPointColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_defaultParagraphStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:element.defaultParagraphStyle] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            element.defaultParagraphStyle = nil ;
        } else {
            element.defaultParagraphStyle = [skin luaObjectAtIndex:2 toClass:"NSParagraphStyle"] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_layoutManager_showsInvisibleCharacters(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.layoutManager.showsInvisibleCharacters) ;
    } else {
        element.layoutManager.showsInvisibleCharacters = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_layoutManager_showsControlCharacters(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.layoutManager.showsControlCharacters) ;
    } else {
        element.layoutManager.showsControlCharacters = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_layoutManager_usesFontLeading(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.layoutManager.usesFontLeading) ;
    } else {
        element.layoutManager.usesFontLeading = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_layoutManager_usesDefaultHyphenation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.layoutManager.usesDefaultHyphenation) ;
    } else {
        element.layoutManager.usesDefaultHyphenation = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_selectionGranularity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(element.selectionGranularity) ;
        NSArray  *temp   = [TEXTVIEW_SELECTION_GRANULARITY allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized selection granularity %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = TEXTVIEW_SELECTION_GRANULARITY[key] ;
        if (value) {
            element.selectionGranularity = value.unsignedIntegerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[TEXTVIEW_SELECTION_GRANULARITY allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int textView_textContainer_widthTracksTextView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.textContainer.widthTracksTextView) ;
    } else {
        element.textContainer.widthTracksTextView = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_textContainer_heightTracksTextView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.textContainer.heightTracksTextView) ;
    } else {
        element.textContainer.heightTracksTextView = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_textContainer_maximumNumberOfLines(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, (lua_Integer)element.textContainer.maximumNumberOfLines) ;
    } else {
        NSInteger value = lua_tointeger(L, 2) ;
        if (value < 0) {
            return luaL_argerror(L, 2, "lines must be 0 or greater") ;
        }
        element.textContainer.maximumNumberOfLines = (NSUInteger)value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_textContainer_lineFragmentPadding(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.textContainer.lineFragmentPadding) ;
    } else {
        element.textContainer.lineFragmentPadding = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_textContainer_size(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:element.textContainer.size] ;
    } else {
        element.textContainer.size = [skin tableToSizeAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_textContainerInset(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:element.textContainerInset] ;
    } else {
        element.textContainerInset = [skin tableToSizeAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_textContainer_lineBreakMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(element.textContainer.lineBreakMode) ;
        NSArray  *temp   = [TEXT_LINEBREAK allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized line break mode %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = TEXT_LINEBREAK[key] ;
        if (value) {
            element.textContainer.lineBreakMode = value.unsignedIntegerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[TEXT_LINEBREAK allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int textView_selectedTextAttributes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;
    BOOL                   replace  = (lua_gettop(L) == 3) ? ((BOOL)(lua_toboolean(L, 3))) : NO ;

    if (lua_gettop(L) == 1) {
        NSAttributedStringKeyDictionary_toLua(L, element.selectedTextAttributes) ;
    } else {
        NSDictionary *attributes = [skin luaObjectAtIndex:2 toClass:"NSAttributedStringKeyDictionary"] ;
        if (!replace) {
            NSMutableDictionary *newDictionary = [element.selectedTextAttributes mutableCopy] ;
            [attributes enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSObject *value, __unused BOOL *stop) {
                newDictionary[key] = value ;
            }] ;
            attributes = [newDictionary copy] ;
        }
        element.selectedTextAttributes = attributes ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_markedTextAttributes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;
    BOOL                   replace  = (lua_gettop(L) == 3) ? ((BOOL)(lua_toboolean(L, 3))) : NO ;

    if (lua_gettop(L) == 1) {
        NSAttributedStringKeyDictionary_toLua(L, element.markedTextAttributes) ;
    } else {
        NSDictionary *attributes = [skin luaObjectAtIndex:2 toClass:"NSAttributedStringKeyDictionary"] ;
        if (!replace) {
            NSMutableDictionary *newDictionary = [element.markedTextAttributes mutableCopy] ;
            [attributes enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSObject *value, __unused BOOL *stop) {
                newDictionary[key] = value ;
            }] ;
            attributes = [newDictionary copy] ;
        }
        element.markedTextAttributes = attributes ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_linkTextAttributes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;
    BOOL                   replace  = (lua_gettop(L) == 3) ? ((BOOL)(lua_toboolean(L, 3))) : NO ;

    if (lua_gettop(L) == 1) {
        NSAttributedStringKeyDictionary_toLua(L, element.linkTextAttributes) ;
    } else {
        NSDictionary *attributes = [skin luaObjectAtIndex:2 toClass:"NSAttributedStringKeyDictionary"] ;
        if (!replace) {
            NSMutableDictionary *newDictionary = [element.linkTextAttributes mutableCopy] ;
            [attributes enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSObject *value, __unused BOOL *stop) {
                newDictionary[key] = value ;
            }] ;
            attributes = [newDictionary copy] ;
        }
        element.linkTextAttributes = attributes ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_typingAttributes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;
    BOOL                   replace  = (lua_gettop(L) == 3) ? ((BOOL)(lua_toboolean(L, 3))) : NO ;

    if (lua_gettop(L) == 1) {
        NSAttributedStringKeyDictionary_toLua(L, element.typingAttributes) ;
    } else {
        NSDictionary *attributes = [skin luaObjectAtIndex:2 toClass:"NSAttributedStringKeyDictionary"] ;
        if (!replace) {
            NSMutableDictionary *newDictionary = [element.typingAttributes mutableCopy] ;
            [attributes enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSObject *value, __unused BOOL *stop) {
                newDictionary[key] = value ;
            }] ;
            attributes = [newDictionary copy] ;
        }
        element.typingAttributes = attributes ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_contentLength(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    // second arg optional so this can be used as __len for userdata
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    NSDictionary *map = luaByteToObjCharMap(element.textStorage.string);

    lua_pushinteger(L, (lua_Integer)[map count]);
    return 1;
}

// static int textView_contentMap(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
//     HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;
//
//     NSDictionary *map = luaByteToObjCharMap(element.textStorage.string);
//
//     [skin pushNSObject:map] ;
//     return 1;
// }

static int textView_contentSubString(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    NSAttributedString *subString     = nil ;
    BOOL               withAttributes = NO ;
    int                idx = (lua_gettop(L) == 1 || lua_type(L, 2) != LUA_TSTRING) ? 2 : 3 ;

    if (lua_gettop(L) == 1 || lua_type(L, 2) != LUA_TSTRING) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                        LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                        LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                        LS_TBREAK];
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                        LS_TANY,
                        LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                        LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                        LS_TBOOLEAN | LS_TOPTIONAL,
                        LS_TBREAK];

        withAttributes = lua_isboolean(L, lua_gettop(L)) ? (BOOL)(lua_toboolean(L, lua_gettop(L))) :
                         (((lua_type(L, 2) == LUA_TSTRING) || (lua_type(L, 2) == LUA_TNUMBER)) ? NO
                                                                                               : YES) ;
        subString = [skin luaObjectAtIndex:2 toClass:"NSAttributedString"];
    }

    // Lua indexes strings by byte, objective-c by char
    NSDictionary *map = luaByteToObjCharMap(element.textStorage.string) ;
    lua_Integer  len  = (lua_Integer)[map count] ;

    lua_Integer i     = lua_isnumber(L, idx) ? lua_tointeger(L, idx) : 1;
    lua_Integer j     = lua_isnumber(L, idx + 1) ? lua_tointeger(L, idx + 1) : len;

    // keep lua indexing and method of specifying range (index starts at 1, j is also an index, not the length
    if (i < 0) {    // if i is negative, then it is indexed from the end of the string
        i = len + 1 + i;
    }
    if (j < 0) {    // if j is negative, then it is indexed from the end of the string
        j = len + 1 + j;
    }
    if (i < 1) {    // if i is still < 1, then silently coerce to beginning of string
        i = 1;
    }
    if (j > len) {  // if j is > length,  then silently coerce to string length (end)
        j = len;
    }

    if (!subString) {   // no replacement provided, so we're returning a (sub)string
        if (i > j) {
            [skin pushNSObject:[[NSAttributedString alloc] initWithString:@""]];
        } else {
            // convert i and j into their obj-c equivalents
            i = ((NSNumber *)[map objectForKey:[NSNumber numberWithInteger:i]]).integerValue ;
            j = ((NSNumber *)[map objectForKey:[NSNumber numberWithInteger:j]]).integerValue ;
            // finally convert to Objective-C's practice of 0 indexing and j as length, not index
            NSRange theRange = NSMakeRange((NSUInteger)(i - 1), (NSUInteger)(j - (i - 1)));
            [skin pushNSObject:[element.textStorage attributedSubstringFromRange:theRange]];
        }
    } else {            // else it's a substring replacement or insert
        BOOL insert = (j == 0);

        // if inserting, the check of i > j will be skipped
        if (insert) {
            if (i > len + 1) {  // but if i > length, then silently coerce to string length (end)
                i = len + 1;
            }
        } else {
            if (i > j) {        // not inserting, so i > j is an error
                return luaL_argerror(L, 3, "starts index must be < ends index");
            }
        }

        // convert i and j into their obj-c equivalents
        i = ((NSNumber *)[map objectForKey:[NSNumber numberWithInteger:i]]).integerValue ;
        j = ((NSNumber *)[map objectForKey:[NSNumber numberWithInteger:j]]).integerValue ;
        // finally convert to Objective-C's practice of 0 indexing and j as length, not index
        NSRange theRange = insert ? NSMakeRange((NSUInteger)(i - 1), 0)
                                  : NSMakeRange((NSUInteger)(i - 1), (NSUInteger)(j - (i - 1)));

        // special case for when i == j == 0 (i.e. an empty storage)
        if (i == 0 && j == 0) {
            theRange = NSMakeRange(0, 0) ;
            if (lua_type(L, 2) == LUA_TSTRING || lua_type(L, 2) == LUA_TNUMBER) {
                withAttributes = YES ;
                NSMutableAttributedString *newString = [subString mutableCopy] ;
                [newString setAttributes:element.typingAttributes range:NSMakeRange(0, subString.length)] ;
                subString = newString ;
            }
        }

        if (withAttributes) {
            [element.textStorage replaceCharactersInRange:theRange withAttributedString:subString] ;
        } else {
            [element.textStorage replaceCharactersInRange:theRange withString:subString.string] ;
        }

        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_selection(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    NSDictionary *map = luaByteToObjCharMap(element.textStorage.string) ;
    lua_Integer  len  = (lua_Integer)[map count] ;

    if (lua_gettop(L) == 1) {
        NSRange selectionRange = element.selectedRange ;
        NSInteger i = ((NSNumber *)[[map allKeysForObject:@(selectionRange.location + 1)] firstObject]).integerValue ;
        if (i == 0 && selectionRange.location >= (NSUInteger)len) i = len + 1 ;
        NSInteger j = ((NSNumber *)[[map allKeysForObject:@(selectionRange.location + selectionRange.length)] firstObject]).integerValue ;
        if (j < i) j = 0 ;
        lua_pushinteger(L, i) ;
        lua_pushinteger(L, j) ;

        return 2 ;
    } else {
        lua_Integer i   = lua_isnumber(L, 2) ? lua_tointeger(L, 2) : 1 ;
        lua_Integer j   = lua_isnumber(L, 3) ? lua_tointeger(L, 3) : i ;

        BOOL jPresent   = (BOOL)(lua_isnumber(L, 3)) ;

        // keep lua indexing and method of specifying range (index starts at 1, j is also an index, not the length
        if (i < 0) {    // if i is negative, then it is indexed from the end of the string
            i = len + 1 + i;
        }
        if (i < 1) {    // if i is still < 1, then silently coerce to beginning of string
            i = 1;
        }

        if (j < 0) {    // if j is negative, then it is indexed from the end of the string
            j = len + 1 + j;
        }
        if (j > len) {  // if j is > len,  then silently coerce to len
            j = len;
        }

        if (j < i) {    // if j < i, silently coerce j to i and treat as cursor only
            j = i ;
            jPresent = NO ;
        }

        if (i > (jPresent ? len : (len + 1))) {  // if i is > len, (or len + 1, if cursor movement) then silently coerce to len
            i = (jPresent ? len : (len + 1)) ;
        }

        // convert i and j into their obj-c equivalents
        //
        // since this code is similar to substring code, we have to take into account that lua semantics
        // means that if i == j, then we are actually selecting the single letter at position i...
        // the selection range in Objective-C also accounts for cursor position, with a 0 length, so
        // we ignore the calculation that would otherwise select a character if only 1 number is
        // provided (i.e. we force a zero length)
        if (jPresent || (i <= len)) {
            i = ((NSNumber *)[map objectForKey:[NSNumber numberWithInteger:i]]).integerValue ;
        }
        if (jPresent) {
            j = ((NSNumber *)[map objectForKey:[NSNumber numberWithInteger:j]]).integerValue ;
        } else {
            j = i - 1 ; // this forces it to 0 in NSMakeRange below
        }
        // finally convert to Objective-C's practice of 0 indexing and j as length, not index
        NSRange range = NSMakeRange((NSUInteger)(i - 1), (NSUInteger)(j - (i - 1))) ;
        element.selectedRange = range ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int textView_scrollToRange(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    NSDictionary *map = luaByteToObjCharMap(element.textStorage.string) ;
    lua_Integer len = (lua_Integer)[map count] ;
    lua_Integer i   = lua_isnumber(L, 2) ? lua_tointeger(L, 2) : 1 ;
    lua_Integer j   = lua_isnumber(L, 3) ? lua_tointeger(L, 3) : len ;

    if (lua_gettop(L) == 1) {
        NSRange selectionRange = element.selectedRange ;
        i = ((NSNumber *)[[map allKeysForObject:@(selectionRange.location + 1)] firstObject]).integerValue ;
        if (i == 0 && selectionRange.location >= (NSUInteger)len) i = len + 1 ;
        j = ((NSNumber *)[[map allKeysForObject:@(selectionRange.location + selectionRange.length)] firstObject]).integerValue ;
        if (j < i) j = i - 1 ; // this forces it to 0 in NSMakeRange below
    } else {
        BOOL jPresent   = (BOOL)(lua_isnumber(L, 3)) ;

        // keep lua indexing and method of specifying range (index starts at 1, j is also an index, not the length
        if (i < 0) {    // if i is negative, then it is indexed from the end of the string
            i = len + 1 + i;
        }
        if (i < 1) {    // if i is still < 1, then silently coerce to beginning of string
            i = 1;
        }

        if (j < 0) {    // if j is negative, then it is indexed from the end of the string
            j = len + 1 + j;
        }
        if (j > len) {  // if j is > len,  then silently coerce to len
            j = len;
        }

        if (j < i) {    // if j < i, silently coerce j to i and treat as cursor only
            j = i ;
            jPresent = NO ;
        }

        if (i > (jPresent ? len : (len + 1))) {  // if i is > len, (or len + 1, if cursor movement) then silently coerce to len
            i = (jPresent ? len : (len + 1)) ;
        }

        // convert i and j into their obj-c equivalents
        if (jPresent || (i <= len)) {
            i = ((NSNumber *)[map objectForKey:[NSNumber numberWithInteger:i]]).integerValue ;
        }
        if (jPresent) {
            j = ((NSNumber *)[map objectForKey:[NSNumber numberWithInteger:j]]).integerValue ;
        } else {
            j = i - 1 ; // this forces it to 0 in NSMakeRange below
        }
    }

    [element scrollRangeToVisible:NSMakeRange((NSUInteger)(i - 1), (NSUInteger)(j - (i - 1)))];
    lua_pushvalue(L, 1) ;
    return 1 ;
}

// see https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextLayout/Tasks/CountLines.html
static int textView_rangesForLines(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    lua_Integer startLine =  1 ;
    lua_Integer endLine   = -1 ; // end of document
    BOOL        hardLines = NO ;

    switch(lua_gettop(L)) {
    case 2:
        [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TINTEGER | LS_TBOOLEAN, LS_TBREAK] ;
        if (lua_type(L, 2) == LUA_TBOOLEAN) {
            hardLines = (BOOL)(lua_toboolean(L, 2)) ;
        } else {
            startLine = lua_tointeger(L, 2) ;
            endLine   = startLine ;
        }
        break ;
    case 3:
        [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TINTEGER | LS_TBOOLEAN, LS_TBREAK] ;
        startLine = lua_tointeger(L, 2) ;
        if (lua_type(L, 3) == LUA_TBOOLEAN) {
            hardLines = (BOOL)(lua_toboolean(L, 3)) ;
            endLine   = startLine ;
        } else {
            endLine = lua_tointeger(L, 3) ;
        }
        break ;
    case 4:
        [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TINTEGER, LS_TBOOLEAN, LS_TBREAK] ;
        startLine = lua_tointeger(L, 2) ;
        endLine   = lua_tointeger(L, 3) ;
        hardLines = (BOOL)(lua_toboolean(L, 4)) ;
        break ;
    }

    if (startLine != endLine) lua_newtable(L) ;

    NSDictionary *map = luaByteToObjCharMap(element.textStorage.string) ;
//     lua_Integer len = (lua_Integer)[map count] ;

    startLine-- ;
    endLine-- ;

    if (hardLines) {
        NSString *string = element.textStorage.string ;

        NSUInteger currentLine  = 0 ;
        NSUInteger idx          = 0 ;
        NSUInteger stringLength = string.length ;

        for (idx = 0, currentLine = 0; idx < stringLength; currentLine++) {
            NSRange lineRange = [string lineRangeForRange:NSMakeRange(idx, 0)] ;
            idx = NSMaxRange(lineRange) ;

            if (currentLine < (NSUInteger)startLine) continue ;
            if (endLine >= 0 && currentLine > (NSUInteger)endLine) break ;

            NSInteger i = ((NSNumber *)[[map allKeysForObject:@(lineRange.location + 1)] firstObject]).integerValue ;
            NSInteger j = ((NSNumber *)[[map allKeysForObject:@(lineRange.location + lineRange.length)] firstObject]).integerValue ;
            lua_newtable(L) ;
            lua_pushinteger(L, i) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            lua_pushinteger(L, j) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            if (startLine != endLine) lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    } else {

        NSLayoutManager *layoutManager = element.layoutManager ;
        NSUInteger      currentLine    = 0 ;
        NSUInteger      idx            = 0 ;
        NSUInteger      numOfGlyphs    = layoutManager.numberOfGlyphs ;
        NSRange         lineRange ;

        for (currentLine = 0, idx = 0; idx < numOfGlyphs; currentLine++){
            [layoutManager lineFragmentRectForGlyphAtIndex:idx effectiveRange:&lineRange];
            idx = NSMaxRange(lineRange) ;

            if (currentLine < (NSUInteger)startLine) continue ;
            if (endLine >= 0 && currentLine > (NSUInteger)endLine) break ;

            NSInteger i = ((NSNumber *)[[map allKeysForObject:@(lineRange.location + 1)] firstObject]).integerValue ;
            NSInteger j = ((NSNumber *)[[map allKeysForObject:@(lineRange.location + lineRange.length)] firstObject]).integerValue ;
            lua_newtable(L) ;
            lua_pushinteger(L, i) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            lua_pushinteger(L, j) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            if (startLine != endLine) lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }

    }

    return 1 ;
}

static int textView_performAction(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;
    NSString               *action  = [skin toNSObjectAtIndex:2] ;

    if ([TEXTVIEW_ACTIONS containsObject:action]) {
        [element performSelectorOnMainThread:NSSelectorFromString([NSString stringWithFormat:@"%@:", action])
                                  withObject:element
                               waitUntilDone:YES] ;
        lua_pushvalue(L, 1) ;
    } else {
        return luaL_argerror(L, 2, [[NSString stringWithFormat:@"invalid action - expected one of %@", [TEXTVIEW_ACTIONS componentsJoinedByString:@", "]] UTF8String]) ;
    }
    return 1 ;
}

static int textView_enabledTextCheckingTypes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementTextView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, (lua_Integer)(element.enabledTextCheckingTypes)) ;
    } else {
        element.enabledTextCheckingTypes = (NSTextCheckingTypes)(lua_tointeger(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

static int textView_actions(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:TEXTVIEW_ACTIONS] ;
    return 1 ;
}

static int textView_findPanelActions(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSTextFinderActionShowFindInterface) ;     lua_setfield(L, -2, "showFindInterface") ;
    lua_pushinteger(L, NSTextFinderActionNextMatch) ;             lua_setfield(L, -2, "nextMatch") ;
    lua_pushinteger(L, NSTextFinderActionPreviousMatch) ;         lua_setfield(L, -2, "previousMatch") ;
    lua_pushinteger(L, NSTextFinderActionReplaceAll) ;            lua_setfield(L, -2, "replaceAll") ;
    lua_pushinteger(L, NSTextFinderActionReplace) ;               lua_setfield(L, -2, "replace") ;
    lua_pushinteger(L, NSTextFinderActionReplaceAndFind) ;        lua_setfield(L, -2, "replaceAndFind") ;
    lua_pushinteger(L, NSTextFinderActionSetSearchString) ;       lua_setfield(L, -2, "setSearchString") ;
    lua_pushinteger(L, NSTextFinderActionReplaceAllInSelection) ; lua_setfield(L, -2, "replaceAllInSelection") ;
    lua_pushinteger(L, NSTextFinderActionSelectAll) ;             lua_setfield(L, -2, "selectAll") ;
    lua_pushinteger(L, NSTextFinderActionSelectAllInSelection) ;  lua_setfield(L, -2, "selectAllInSelection") ;
    lua_pushinteger(L, NSTextFinderActionHideFindInterface) ;     lua_setfield(L, -2, "hideFindInterface") ;
    lua_pushinteger(L, NSTextFinderActionShowReplaceInterface) ;  lua_setfield(L, -2, "showReplaceInterface") ;
    lua_pushinteger(L, NSTextFinderActionHideReplaceInterface) ;  lua_setfield(L, -2, "hideReplaceInterface") ;
    return 1 ;
}

static int textView_layoutOrientations(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSTextLayoutOrientationHorizontal) ; lua_setfield(L, -2, "horizontal") ;
    lua_pushinteger(L, NSTextLayoutOrientationVertical) ;   lua_setfield(L, -2, "vertical") ;
    return 1 ;
}

static int textView_textCheckingTypes(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSTextCheckingTypeSpelling) ;           lua_setfield(L, -2, "spelling") ;
    lua_pushinteger(L, NSTextCheckingTypeGrammar) ;            lua_setfield(L, -2, "grammar") ;
    lua_pushinteger(L, NSTextCheckingTypeDate) ;               lua_setfield(L, -2, "date") ;
    lua_pushinteger(L, NSTextCheckingTypeAddress) ;            lua_setfield(L, -2, "address") ;
    lua_pushinteger(L, NSTextCheckingTypeLink) ;               lua_setfield(L, -2, "link") ;
    lua_pushinteger(L, NSTextCheckingTypeQuote) ;              lua_setfield(L, -2, "quote") ;
    lua_pushinteger(L, NSTextCheckingTypeDash) ;               lua_setfield(L, -2, "dash") ;
    lua_pushinteger(L, NSTextCheckingTypeReplacement) ;        lua_setfield(L, -2, "replacement") ;
    lua_pushinteger(L, NSTextCheckingTypeCorrection) ;         lua_setfield(L, -2, "correction") ;
    lua_pushinteger(L, NSTextCheckingTypeRegularExpression) ;  lua_setfield(L, -2, "regularExpression") ;
    lua_pushinteger(L, NSTextCheckingTypePhoneNumber) ;        lua_setfield(L, -2, "phoneNumber") ;
    lua_pushinteger(L, NSTextCheckingTypeTransitInformation) ; lua_setfield(L, -2, "transitInformation") ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementTextView(lua_State *L, id obj) {
    HSUITKElementTextView *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementTextView *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementTextView(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementTextView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementTextView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

// NSDictionary *attrDict = [skin luaObjectAtIndex:idx toClass:"NSAttributedStringKeyDictionary"];
// C-API
// A helper function for the "Pseudo class" AttributesDictionary.
//
// This is a Pseudo class because it is in reality just an NSDictionary; however, the key names used in the
// lua version of the table differ from the keys needed for use with NSAttributedStringKey dictionaries, so
// a straight NSDictionary conversion would require going through it again anyways.
//
// Probably needs more value error checking
//
// Will require additional converters... let's see if the need comes up
//         NSAttachmentAttributeName           // NSTextAttachment
//         NSCursorAttributeName;              // NSCursor
//         NSGlyphInfoAttributeName;           // NSGlyphInfo
//         NSTextAlternativesAttributeName     // NSTextAlternatives
static id lua_toNSAttributedStringKeyDictionary(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    NSMutableDictionary *theAttributes = [[NSMutableDictionary alloc] init];

    if (lua_type(L, idx) ==  LUA_TTABLE) {
        if (lua_getfield(L, idx, "font") == LUA_TTABLE) {
            [theAttributes setObject:[skin luaObjectAtIndex:-1 toClass:"NSFont"] forKey:NSFontAttributeName];
        } else if (lua_type(L, -1) == LUA_TSTRING) {
            [theAttributes setObject:[skin luaObjectAtIndex:-1 toClass:"NSFont"] forKey:NSFontAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "paragraphStyle") == LUA_TTABLE) {
            [theAttributes setObject:[skin luaObjectAtIndex:-1 toClass:"NSParagraphStyle"] forKey:NSParagraphStyleAttributeName];
        }
        lua_pop(L, 1);

        if (lua_getfield(L, idx, "underlineStyle") == LUA_TNUMBER) {
            [theAttributes setObject:@(lua_tointeger(L, -1)) forKey:NSUnderlineStyleAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "superscript") == LUA_TNUMBER) {
            [theAttributes setObject:@(lua_tointeger(L, -1)) forKey:NSSuperscriptAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "ligature") == LUA_TNUMBER) {
            [theAttributes setObject:@(lua_tointeger(L, -1)) forKey:NSLigatureAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "strikethroughStyle") == LUA_TNUMBER) {
            [theAttributes setObject:@(lua_tointeger(L, -1)) forKey:NSStrikethroughStyleAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "baselineOffset") == LUA_TNUMBER) {
            [theAttributes setObject:@(lua_tonumber(L, -1)) forKey:NSBaselineOffsetAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "kerning") == LUA_TNUMBER) {
            [theAttributes setObject:@(lua_tonumber(L, -1)) forKey:NSKernAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "strokeWidth") == LUA_TNUMBER) {
            [theAttributes setObject:@(lua_tonumber(L, -1)) forKey:NSStrokeWidthAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "obliqueness") == LUA_TNUMBER) {
            [theAttributes setObject:@(lua_tonumber(L, -1)) forKey:NSObliquenessAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "expansion") == LUA_TNUMBER) {
            [theAttributes setObject:@(lua_tonumber(L, -1)) forKey:NSExpansionAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "color") == LUA_TTABLE) {
            [theAttributes setObject:[skin luaObjectAtIndex:-1 toClass:"NSColor"] forKey:NSForegroundColorAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "backgroundColor") == LUA_TTABLE) {
            [theAttributes setObject:[skin luaObjectAtIndex:-1 toClass:"NSColor"] forKey:NSBackgroundColorAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "strokeColor") == LUA_TTABLE) {
            [theAttributes setObject:[skin luaObjectAtIndex:-1 toClass:"NSColor"] forKey:NSStrokeColorAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "underlineColor") == LUA_TTABLE) {
            [theAttributes setObject:[skin luaObjectAtIndex:-1 toClass:"NSColor"] forKey:NSUnderlineColorAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "strikethroughColor") == LUA_TTABLE) {
            [theAttributes setObject:[skin luaObjectAtIndex:-1 toClass:"NSColor"] forKey:NSStrikethroughColorAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "shadow") == LUA_TTABLE) {
            [theAttributes setObject:[skin luaObjectAtIndex:-1 toClass:"NSShadow"] forKey:NSShadowAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "textEffect") == LUA_TSTRING) {
            [theAttributes setObject:[skin toNSObjectAtIndex:-1] forKey:NSTextEffectAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "link") == LUA_TSTRING) {
            [theAttributes setObject:[skin toNSObjectAtIndex:-1] forKey:NSLinkAttributeName];
        } else if (lua_type(L, -1) == LUA_TTABLE) {
            [theAttributes setObject:[skin luaObjectAtIndex:-1 toClass:"NSURL"] forKey:NSLinkAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "toolTip") == LUA_TSTRING) {
            [theAttributes setObject:[skin toNSObjectAtIndex:-1] forKey:NSToolTipAttributeName];
        }
        lua_pop(L, 1);
        if (@available(macOS 11, *)) {
            if (lua_getfield(L, idx, "tracking") == LUA_TNUMBER) {
                [theAttributes setObject:@(lua_tonumber(L, -1)) forKey:NSTrackingAttributeName];
            }
            lua_pop(L, 1);
        }
        if (lua_getfield(L, idx, "verticalGlyphForm") == LUA_TBOOLEAN) {
            if (lua_toboolean(L, -1)) {
                [theAttributes setObject:@(1) forKey:NSVerticalGlyphFormAttributeName];
            } else {
                [theAttributes setObject:@(0) forKey:NSVerticalGlyphFormAttributeName];
            }
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "markedClauseSegment") == LUA_TNUMBER) {
            [theAttributes setObject:@(lua_tointeger(L, -1)) forKey:NSMarkedClauseSegmentAttributeName];
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "writingDirection") == LUA_TTABLE) {
            NSArray *value = [skin toNSObjectAtIndex:-1] ;
            if ([value isKindOfClass:[NSArray class]]) {
                for (NSUInteger i = 0 ; i < value.count ; i++) {
                    if (![((NSObject *)value[i]) isKindOfClass:[NSNumber class]]) {
                        [skin logError:@"lua_toNSAttributedStringKeyDictionary.writingDirection - expected array of numbers"] ;
                        value = @[] ;
                        break ;
                    }
                }
            } else {
                [skin logError:@"lua_toNSAttributedStringKeyDictionary.writingDirection - expected array of numbers"] ;
                value = @[] ;
            }
            [theAttributes setObject:value forKey:NSWritingDirectionAttributeName];

        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "spellingState") == LUA_TNUMBER) {
            [theAttributes setObject:@(lua_tointeger(L, -1)) forKey:NSSpellingStateAttributeName];
        }
        lua_pop(L, 1);
    } else {
        [skin logError:[NSString stringWithFormat:@"lua_toNSAttributedStringKeyDictionary - invalid attributes dictionary: expected table, found %s", lua_typename(L, lua_type(L, idx))]] ;
    }

    return theAttributes;
}

static int NSAttributedStringKeyDictionary_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    NSDictionary *dict = obj ;

    lua_newtable(L);
    [dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSObject *value, __unused BOOL *stop) {
        if ([key isEqualToString:NSFontAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "font") ;
        } else if ([key isEqualToString:NSParagraphStyleAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "paragraphStyle") ;
        } else if ([key isEqualToString:NSForegroundColorAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "color") ;
        } else if ([key isEqualToString:NSBackgroundColorAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "backgroundColor") ;
        } else if ([key isEqualToString:NSLigatureAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "ligature") ;
        } else if ([key isEqualToString:NSKernAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "kerning") ;
        } else if ([key isEqualToString:NSStrikethroughStyleAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "strikethroughStyle") ;
        } else if ([key isEqualToString:NSUnderlineStyleAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "underlineStyle") ;
        } else if ([key isEqualToString:NSStrokeColorAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "strokeColor") ;
        } else if ([key isEqualToString:NSStrokeWidthAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "strokeWidth") ;
        } else if ([key isEqualToString:NSShadowAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "shadow") ;
        } else if ([key isEqualToString:NSBaselineOffsetAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "baselineOffset") ;
        } else if ([key isEqualToString:NSUnderlineColorAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "underlineColor") ;
        } else if ([key isEqualToString:NSStrikethroughColorAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "strikethroughColor") ;
        } else if ([key isEqualToString:NSObliquenessAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "obliqueness") ;
        } else if ([key isEqualToString:NSExpansionAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "expansion") ;
        } else if ([key isEqualToString:NSSuperscriptAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "superscript") ;
        } else if ([key isEqualToString:NSTextEffectAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "textEffect") ;
        } else if ([key isEqualToString:NSLinkAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "link") ;
        } else if ([key isEqualToString:NSWritingDirectionAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "writingDirection") ;
        } else if ([key isEqualToString:NSVerticalGlyphFormAttributeName]) {
            lua_pushboolean(L, (((NSNumber *)value).integerValue == 1)) ;
            lua_setfield(L, -2, "verticalGlyphForm") ;
        } else if ([key isEqualToString:NSToolTipAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "toolTip") ;
        } else if ([key isEqualToString:NSMarkedClauseSegmentAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "markedClauseSegment") ;
        } else if ([key isEqualToString:NSSpellingStateAttributeName]) {
            [skin pushNSObject:value] ; lua_setfield(L, -2, "spellingState") ;
//         } else if ([key isEqualToString:NSAttachmentAttributeName]) {
//         } else if ([key isEqualToString:NSCursorAttributeName]) {
//         } else if ([key isEqualToString:NSGlyphInfoAttributeName]) {
//         } else if ([key isEqualToString:NSTextAlternativesAttributeName]) {
        } else {
            BOOL isOK = NO ;
            if (@available(macOS 11, *)) {
                if ([key isEqualToString:NSTrackingAttributeName]) {
                    [skin pushNSObject:value] ; lua_setfield(L, -2, "tracking") ;
                    isOK = YES ;
                }
            }
            if (!isOK) {
                [skin logVerbose:[NSString stringWithFormat:@"NSAttributedStringKeyDictionary_toLua - unhandled attribute %@", key]] ;
                [skin pushNSObject:value withOptions:LS_NSDescribeUnknownTypes] ;
                lua_setfield(L, -2, key.UTF8String) ;
            }
        }
    }] ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_gc(lua_State* L) {
    HSUITKElementTextView *obj  = get_objectFromUserdata(__bridge_transfer HSUITKElementTextView, L, 1, USERDATA_TAG) ;

    obj.selfRefCount-- ;
    if (obj.selfRefCount == 0) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        obj.callbackRef        = [skin luaUnref:obj.refTable ref:obj.callbackRef] ;
        obj.editingCallbackRef = [skin luaUnref:obj.refTable ref:obj.editingCallbackRef] ;
        obj.completionsRef     = [skin luaUnref:obj.refTable ref:obj.completionsRef] ;
        obj = nil ;
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"acceptsGlyphInfo",            textView_acceptsGlyphInfo},
    {"characterPicker",             textView_allowsCharacterPickerTouchBarItem},
    {"allowsBackgroundColorChange", textView_allowsDocumentBackgroundColorChange},
    {"allowsImageEditing",          textView_allowsImageEditing},
    {"allowsUndo",                  textView_allowsUndo},
    {"displaysLinkToolTips",        textView_displaysLinkToolTips},
    {"drawsBackground",             textView_drawsBackground},
    {"importsGraphics",             textView_importsGraphics},
    {"smartInsertDelete",           textView_smartInsertDeleteEnabled},
    {"adaptiveColorMapping",        textView_usesAdaptiveColorMappingForDarkAppearance},
    {"usesFindBar",                 textView_usesFindBar},
    {"usesFindPanel",               textView_usesFindPanel},
    {"usesFontPanel",               textView_usesFontPanel},
    {"usesInspectorBar",            textView_usesInspectorBar},
    {"rolloverButtonForSelection",  textView_usesRolloverButtonForSelection},
    {"usesRuler",                   textView_usesRuler},
    {"autoDashSubstitution",        textView_automaticDashSubstitutionEnabled},
    {"autoDataDetection",           textView_automaticDataDetectionEnabled},
    {"autoLinkDetection",           textView_automaticLinkDetectionEnabled},
    {"autoQuoteSubstitution",       textView_automaticQuoteSubstitutionEnabled},
    {"autoSpellingCorrection",      textView_automaticSpellingCorrectionEnabled},
    {"autoTextCompletion",          textView_automaticTextCompletionEnabled},
    {"autoTextReplacement",         textView_automaticTextReplacementEnabled},
    {"continuousSpellChecking",     textView_continuousSpellCheckingEnabled},
    {"editable",                    textView_editable},
    {"fieldEditor",                 textView_fieldEditor},
    {"grammarChecking",             textView_grammarCheckingEnabled},
    {"incrementalSearching",        textView_incrementalSearchingEnabled},
    {"richText",                    textView_richText},
    {"rulerVisible",                textView_rulerVisible},
    {"selectable",                  textView_selectable},
    {"backgroundColor",             textView_backgroundColor},
    {"insertionPointColor",         textView_insertionPointColor},
    {"defaultParagraphStyle",       textView_defaultParagraphStyle},
    {"showsInvisibleCharacters",    textView_layoutManager_showsInvisibleCharacters},
    {"showsControlCharacters",      textView_layoutManager_showsControlCharacters},
    {"usesFontLeading",             textView_layoutManager_usesFontLeading},
    {"usesDefaultHyphenation",      textView_layoutManager_usesDefaultHyphenation},
    {"selectionGranularity",        textView_selectionGranularity},
    {"widthTracksTextView",         textView_textContainer_widthTracksTextView},
    {"heightTracksTextView",        textView_textContainer_heightTracksTextView},
    {"maximumNumberOfLines",        textView_textContainer_maximumNumberOfLines},
    {"lineFragmentPadding",         textView_textContainer_lineFragmentPadding},
    {"containerSize",               textView_textContainer_size},
    {"containerInset",              textView_textContainerInset},
    {"lineBreakMode",               textView_textContainer_lineBreakMode},
    {"selectedTextAttributes",      textView_selectedTextAttributes},
    {"markedTextAttributes",        textView_markedTextAttributes},
    {"linkTextAttributes",          textView_linkTextAttributes},
    {"typingAttributes",            textView_typingAttributes},
    {"callback",                    textView_callback},
    {"editingCallback",             textView_editingCallback},
    {"completions",                 textView_completions},
    {"continuous",                  textView_continuousTextDidChange},
    {"selection",                   textView_selection},
    {"enabledCheckingTypes",        textView_enabledTextCheckingTypes},

//     {"contentMap",                  textView_contentMap},

    {"contentLength",               textView_contentLength},
    {"content",                     textView_contentSubString},
    {"scrollTo",                    textView_scrollToRange},
    {"rangeForLine",                textView_rangesForLines},
    {"performAction",               textView_performAction},

// other metamethods inherited from _control and _view
    {"__len",                       textView_contentLength},
    {"__gc",                        userdata_gc},
    {NULL,                          NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", textView_new},
    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_libelement_textView(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    textView_actions(L) ;            lua_setfield(L, -2, "actions") ;
    textView_findPanelActions(L) ;   lua_setfield(L, -2, "findPanelActions") ;
    textView_layoutOrientations(L) ; lua_setfield(L, -2, "layoutOrientations") ;
    textView_textCheckingTypes(L) ;  lua_setfield(L, -2, "textCheckingTypes") ;

    [skin registerPushNSHelper:pushHSUITKElementTextView  forClass:"HSUITKElementTextView"];
    [skin registerLuaObjectHelper:toHSUITKElementTextView forClass:"HSUITKElementTextView"
                                               withUserdataMapping:USERDATA_TAG];

    [skin registerLuaObjectHelper:lua_toNSAttributedStringKeyDictionary
                         forClass:"NSAttributedStringKeyDictionary"] ;

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"acceptsGlyphInfo",
        @"characterPicker",
        @"allowsBackgroundColorChange",
        @"allowsImageEditing",
        @"allowsUndo",
        @"displaysLinkToolTips",
        @"drawsBackground",
        @"importsGraphics",
        @"smartInsertDelete",
        @"adaptiveColorMapping",
        @"usesFindBar",
        @"usesFindPanel",
        @"usesFontPanel",
        @"usesInspectorBar",
        @"rolloverButtonForSelection",
        @"usesRuler",
        @"autoDashSubstitution",
        @"autoDataDetection",
        @"autoLinkDetection",
        @"autoQuoteSubstitution",
        @"autoSpellingCorrection",
        @"autoTextCompletion",
        @"autoTextReplacement",
        @"continuousSpellChecking",
        @"editable",
        @"fieldEditor",
        @"grammarChecking",
        @"incrementalSearching",
        @"richText",
        @"rulerVisible",
        @"selectable",
        @"backgroundColor",
        @"insertionPointColor",
        @"defaultParagraphStyle",
        @"showsInvisibleCharacters",
        @"showsControlCharacters",
        @"usesFontLeading",
        @"usesDefaultHyphenation",
        @"selectionGranularity",
        @"widthTracksTextView",
        @"heightTracksTextView",
        @"maximumNumberOfLines",
        @"lineFragmentPadding",
        @"containerSize",
        @"containerInset",
        @"lineBreakMode",
        @"selectedTextAttributes",
        @"markedTextAttributes",
        @"linkTextAttributes",
        @"typingAttributes",
        @"callback",
        @"editingCallback",
        @"completions",
        @"continuous",
        @"selection",
        @"enabledCheckingTypes",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pop(L, 1) ;

    return 1;
}
