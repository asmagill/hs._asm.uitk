@import Cocoa ;
@import LuaSkin ;
@import Carbon.HIToolbox.Events ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.textField.searchField" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

@interface NSMenu (assignmentSharing)
@property (weak) NSView *assignedTo ;
@end

@interface HSUITKElementSearchField : NSSearchField <NSTextFieldDelegate, NSSearchFieldDelegate>
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        editingCallbackRef ;
@property            int        callbackRef ;
@end

@implementation HSUITKElementSearchField

- (void)commonInit {
    _callbackRef        = LUA_NOREF ;
    _editingCallbackRef = LUA_NOREF ;
    _refTable           = refTable ;
    _selfRefCount       = 0 ;

    self.delegate       = self ;
    self.target         = self ;
    self.action         = @selector(performCallback:) ;
}

+ (instancetype)textFieldFromString:(NSString *)stringValue {
    HSUITKElementSearchField *textField = [HSUITKElementSearchField textFieldWithString:stringValue] ;

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

// // a callback expecting a boolean return value
// - (BOOL)callbackHam\ster:(NSArray *)messageParts withDefault:(BOOL)defaultResult {
//     BOOL result = defaultResult ;
//
//     if (_editingCallbackRef != LUA_NOREF) {
//         LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
//         lua_State *L    = skin.L ;
//         [skin pushLuaRef:refTable ref:_editingCallbackRef] ;
//         for (id part in messageParts) [skin pushNSObject:part] ;
//         lua_pushboolean(L, defaultResult) ;
//         if (![skin protectedCallAndTraceback:((int)messageParts.count + 1) nresults:1]) {
//             NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
//             [skin logError:[NSString stringWithFormat:@"%s:editingCallback error:%@", USERDATA_TAG, errorMessage]] ;
//         } else {
//             if (lua_type(L, -1) != LUA_TNIL) result = (BOOL)(lua_toboolean(L, -1)) ;
//         }
//         lua_pop(skin.L, 1) ;
//     }
//     return result ;
// }

- (void)performCallback:(__unused id)sender {
    [self callbackHamster:@[ self, self.stringValue ]] ;
}

// - (BOOL)performKeyEquivalent:(NSEvent *)event {
//     unsigned short       keyCode       = event.keyCode ;
// //     NSEventModifierFlags modifierFlags = event.modifierFlags & NSDeviceIndependentModifierFlagsMask ;
// //     [LuaSkin logWarn:[NSString stringWithFormat:@"%s:performKeyEquivalent: key:%3d, mods:0x%08lx %@", USERDATA_TAG, keyCode, (unsigned long)modifierFlags, event]] ;
//
//     NSString *keyName = nil ;
//     switch (keyCode) {
//         case kVK_Return:     keyName = @"return" ; break ;
//         case kVK_LeftArrow:  keyName = @"left" ;   break ;
//         case kVK_RightArrow: keyName = @"right" ;  break ;
//         case kVK_DownArrow:  keyName = @"down" ;   break ;
//         case kVK_UpArrow:    keyName = @"up" ;     break ;
//         case kVK_Escape:     keyName = @"escape" ; break ;
//     }
//
//     if (keyName) {
//         if ([self callbackHamster:@[ self, @"keyPress", keyName ] withDefault:NO]) return YES ;
//     }
//
//     return [super performKeyEquivalent:event] ;
// }

// can this be replaced by checking for escape in performKeyEquivalent?
// - (void)cancelOperation:(__unused id)sender {
// }

// - (BOOL)textShouldBeginEditing:(NSText *)textObject {
//     return [self callbackHamster:@[ self, @"shouldBeginEditing" ]
//                      withDefault:[super textShouldBeginEditing:textObject]] ;
// }

// - (BOOL)textShouldEndEditing:(NSText *)textObject {
//     return [self callbackHamster:@[ self, @"shouldEndEditing" ]
//                      withDefault:[super textShouldEndEditing:textObject]] ;
// }

// - (void)selectText:(id)sender;

// - (void)controlTextDidBeginEditing:(__unused NSNotification *)notification {
// - (void)textDidBeginEditing:(__unused NSNotification *)notification {
//     [self callbackHamster:@[ self, @"didBeginEditing"]] ;
// }

// - (void)controlTextDidChange:(__unused NSNotification *)notification {
// - (void)textDidChange:(__unused NSNotification *)notification {
//     if (self.continuous) [self callbackHamster:@[ self, @"textDidChange", self.stringValue]] ;
// }

// - (void)controlTextDidEndEditing:(NSNotification *)notification {
// - (void)textDidEndEditing:(NSNotification *)notification {
//     NSNumber   *reasonCodeNumber = notification.userInfo[@"NSTextMovement"] ;
//     NSUInteger reasonCode        = reasonCodeNumber ? reasonCodeNumber.unsignedIntValue : NSTextMovementOther ;
//     NSString   *reason           = [NSString stringWithFormat:@"unknown reasonCode:%lu", reasonCode] ;
//
//     switch(reasonCode) {
//         case NSTextMovementOther:   reason = @"other" ;   break ;
//         case NSTextMovementTab:     reason = @"tab" ;     break ;
//         case NSTextMovementBacktab: reason = @"backTab" ; break ;
//
// // maybe used in NSTextView, NSText, matrix, or row/cell based text field? Not seen in this one yet...
//         case NSTextMovementReturn:  reason = @"return" ;  break ;
//         case NSTextMovementLeft:    reason = @"left" ;    break ;
//         case NSTextMovementRight:   reason = @"right" ;   break ;
//         case NSTextMovementUp:      reason = @"up" ;      break ;
//         case NSTextMovementDown:    reason = @"down" ;    break ;
//         case NSTextMovementCancel:  reason = @"cancel" ;  break ;
//     }
//
//     [self callbackHamster:@[ self, @"didEndEditing", self.stringValue, reason]] ;
// }

// NOTE: NSTextFieldDelegate
//
// - (NSArray<NSTextCheckingResult *> *)textField:(NSTextField *)textField textView:(NSTextView *)textView candidates:(NSArray<NSTextCheckingResult *> *)candidates forSelectedRange:(NSRange)selectedRange;
// - (NSArray *)textField:(NSTextField *)textField textView:(NSTextView *)textView candidatesForSelectedRange:(NSRange)selectedRange;
// - (BOOL)textField:(NSTextField *)textField textView:(NSTextView *)textView shouldSelectCandidateAtIndex:(NSUInteger)index;

// NOTE: NSSearchFieldDelegate

// - (void)searchFieldDidStartSearching:(__unused NSSearchField *)sender {
//     [self callbackHamster:@[ self, @"startSearch", self.stringValue]] ;
// }
//
// - (void)searchFieldDidEndSearching:(__unused NSSearchField *)sender {
//     [self callbackHamster:@[ self, @"endSearch", self.stringValue]] ;
// }

@end

#pragma mark - Module Functions -

static int searchField_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *string = (lua_gettop(L) == 0) ? nil : [skin toNSObjectAtIndex:1] ;
    HSUITKElementSearchField *element = [HSUITKElementSearchField textFieldFromString:string] ;

    if (element) {
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int searchField_sendsSearchStringImmediately(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSearchField *field = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, field.sendsSearchStringImmediately) ;
    } else {
        field.sendsSearchStringImmediately = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int searchField_sendsWholeSearchString(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSearchField *field = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, field.sendsWholeSearchString) ;
    } else {
        field.sendsWholeSearchString = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int searchField_maximumRecents(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSearchField *field = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, field.maximumRecents) ;
    } else {
        NSInteger value = lua_tointeger(L, 2) ;
        if (value < 0) return luaL_argerror(L, 2, "integer must be positive or zero") ;

        field.maximumRecents = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int searchField_recentsAutosaveName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSearchField *field = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:field.recentsAutosaveName] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            field.recentsAutosaveName = nil ;
        } else {
            field.recentsAutosaveName = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int searchField_recentSearches(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSearchField *field = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:field.recentSearches] ;
    } else {
        NSArray *searches = [skin toNSObjectAtIndex:2] ;
        if (![searches isKindOfClass:[NSArray class]]) return luaL_argerror(L, 2, "expected array of strings") ;
        BOOL isGood = YES ;
        for (NSString *word in searches) {
            isGood = [word isKindOfClass:[NSString class]] ;
            if (!isGood) break ;
        }
        if (isGood) {
            field.recentSearches = searches ;
        } else {
            return luaL_argerror(L, 2, "expected array of strings") ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int searchField_searchMenuTemplate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSearchField *field = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:field.searchMenuTemplate withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        NSMenu *oldMenu = field.searchMenuTemplate ;

        if (lua_type(L, 2) == LUA_TNIL) {
            field.searchMenuTemplate = nil ;
        } else {
            [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.menu", LS_TBREAK] ;
            NSMenu *menu             = [skin toNSObjectAtIndex:2] ;
            menu.assignedTo          = field ;
            field.searchMenuTemplate = menu ;
            [skin luaRetain:refTable forNSObject:menu] ;
        }

        if (oldMenu) {
            oldMenu.assignedTo = nil ;
            [skin luaRelease:refTable forNSObject:oldMenu] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int searchField_cancelButtonBounds(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementSearchField *field = [skin toNSObjectAtIndex:1] ;
    if (@available(macOS 11, *)) {
        [skin pushNSRect:[field convertRect:field.cancelButtonBounds toView:field.superview]] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int searchField_searchButtonBounds(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementSearchField *field = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 11, *)) {
        [skin pushNSRect:[field convertRect:field.searchButtonBounds toView:field.superview]] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int searchField_searchTextBounds(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementSearchField *field = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 11, *)) {
        [skin pushNSRect:[field convertRect:field.searchTextBounds toView:field.superview]] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

static int searchField_menuConstants(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:@{
        @"clearRecents"  : @(NSSearchFieldClearRecentsMenuItemTag),
        @"noRecentItems" : @(NSSearchFieldNoRecentsMenuItemTag),
        @"recentItems"   : @(NSSearchFieldRecentsMenuItemTag),
        @"recentsTitle"  : @(NSSearchFieldRecentsTitleMenuItemTag),
    }] ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementSearchField(lua_State *L, id obj) {
    HSUITKElementSearchField *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementSearchField *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementSearchField(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementSearchField *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementSearchField, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_gc(lua_State* L) {
    HSUITKElementSearchField *obj  = get_objectFromUserdata(__bridge_transfer HSUITKElementSearchField, L, 1, USERDATA_TAG) ;

    obj.selfRefCount-- ;
    if (obj.selfRefCount == 0) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        obj.callbackRef = [skin luaUnref:obj.refTable ref:obj.callbackRef] ;
        if (obj.searchMenuTemplate) {
            obj.searchMenuTemplate.assignedTo = nil ;
            [skin luaRelease:refTable forNSObject:obj.searchMenuTemplate] ;
        }
        obj = nil ;
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"sendsImmediately",  searchField_sendsSearchStringImmediately},
    {"sendsWhenComplete", searchField_sendsWholeSearchString},
    {"maxRecents",        searchField_maximumRecents},
    {"autosaveName",      searchField_recentsAutosaveName},
    {"recentSearches",    searchField_recentSearches},
    {"menu",              searchField_searchMenuTemplate},

    {"cancelButtonFrame", searchField_cancelButtonBounds},
    {"searchButtonFrame", searchField_searchButtonBounds},
    {"searchTextFrame",   searchField_searchTextBounds},

// other metamethods inherited from _control and _view
    {"__gc",              userdata_gc},
    {NULL, NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", searchField_new},
    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_element_libtextField_searchField(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    searchField_menuConstants(L) ; lua_setfield(L, -2, "recentMenuConstants") ;

    [skin registerPushNSHelper:pushHSUITKElementSearchField  forClass:"HSUITKElementSearchField"];
    [skin registerLuaObjectHelper:toHSUITKElementSearchField forClass:"HSUITKElementSearchField"
                                                  withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"sendsImmediately",
        @"sendsWhenComplete",
        @"maxRecents",
        @"autosaveName",
        @"recentSearches",
        @"menu",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}
