@import Cocoa ;
@import LuaSkin ;
@import Carbon.HIToolbox.Events ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.textField.comboBox" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

@interface HSUITKElementComboBox : NSComboBox <NSComboBoxDelegate>
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        editingCallbackRef ;
@property            int        callbackRef ;
@property            BOOL       testingControls ;
@end

@implementation HSUITKElementComboBox

- (void)commonInit {
    _callbackRef        = LUA_NOREF ;
    _editingCallbackRef = LUA_NOREF ;
    _refTable           = refTable ;
    _testingControls    = NO ;

    _selfRefCount       = 0 ;

    self.delegate       = self ;
//     self.target         = self ;
//     self.action         = @selector(performCallback:) ;

    self.usesDataSource = NO ;
    self.dataSource     = nil ;
}

+ (instancetype)textFieldFromString:(NSString *)stringValue {
    HSUITKElementComboBox *textField = [HSUITKElementComboBox textFieldWithString:stringValue] ;

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

// - (void)performCallback:(__unused id)sender {
//     [self callbackHamster:@[ self, self.stringValue ]] ;
// }

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    BOOL     result   = NO ; // assume we don't handle it
    NSString *keyName = nil ;

    if (commandSelector == @selector(insertNewline:)) {
        keyName = @"return" ;
    } else if (commandSelector == @selector(cancelOperation:)) {
        keyName = @"escape" ;
    } else if (commandSelector == @selector(moveUp:)) {
        keyName = @"up" ;
    } else if (commandSelector == @selector(moveDown:)) {
        keyName = @"down" ;
    } else if (commandSelector == @selector(moveLeft:)) {
        keyName = @"left" ;
    } else if (commandSelector == @selector(moveRight:)) {
        keyName = @"right" ;
    } else if (commandSelector == @selector(insertTab:)) {
        keyName = @"tab" ;
    } else if (commandSelector == @selector(insertBacktab:)) {
        keyName = @"backTab" ;
    }

    if (keyName) {
        result = [self callbackHamster:@[ self, @"keyPress", keyName ] withDefault:NO] ;
    } else if (_testingControls) {
        result = [self callbackHamster:@[ self, @"other", NSStringFromSelector(commandSelector) ] withDefault:NO] ;
    }

    return result ;
}

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

// NOTE: NSComboBoxDelegate

// - (void)comboBoxSelectionDidChange:(NSNotification *)notification;
// - (void)comboBoxSelectionIsChanging:(NSNotification *)notification;
// - (void)comboBoxWillDismiss:(NSNotification *)notification;
// - (void)comboBoxWillPopUp:(NSNotification *)notification;
//
// - (NSArray<NSTextCheckingResult *> *)textField:(NSTextField *)textField textView:(NSTextView *)textView candidates:(NSArray<NSTextCheckingResult *> *)candidates forSelectedRange:(NSRange)selectedRange;
// - (NSArray *)textField:(NSTextField *)textField textView:(NSTextView *)textView candidatesForSelectedRange:(NSRange)selectedRange;
// - (BOOL)textField:(NSTextField *)textField textView:(NSTextView *)textView shouldSelectCandidateAtIndex:(NSUInteger)index;

@end

#pragma mark - Module Functions -

static int comboBox_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *string = (lua_gettop(L) == 0) ? nil : [skin toNSObjectAtIndex:1] ;
    HSUITKElementComboBox *element = [HSUITKElementComboBox textFieldFromString:string] ;

    if (element) {
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int comboBox_completes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementComboBox *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.completes) ;
    } else {
        element.completes = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int comboBox_hasVerticalScroller(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementComboBox *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.hasVerticalScroller) ;
    } else {
        element.hasVerticalScroller = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int comboBox_buttonBordered(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementComboBox *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.buttonBordered) ;
    } else {
        element.buttonBordered = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int comboBox_itemHeight(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementComboBox *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.itemHeight) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value < 0) value = 0 ;
        element.itemHeight = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int comboBox_numberOfVisibleItems(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementComboBox *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, element.numberOfVisibleItems) ;
    } else {
        NSInteger value = lua_tointeger(L, 2) ;
        if (value < 0) value = 0 ;
        element.numberOfVisibleItems = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int comboBox_intercellSpacing(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementComboBox *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:element.intercellSpacing] ;
    } else {
        element.intercellSpacing = [skin tableToSizeAtIndex:2] ;
        lua_pushvalue(L, 1);
    }
    return 1;
}

static int comboBox_objects(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementComboBox *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:element.objectValues] ;
    } else {
        NSArray *objects = element.objectValues ;
        if ([objects isKindOfClass:[NSArray class]]) {
            [element removeAllItems] ;
            [element addItemsWithObjectValues:objects] ;

            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, "expected array of elements") ;
        }
    }
    return 1 ;
}

static int comboBox_numberOfItems(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementComboBox *element = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, element.numberOfItems) ;
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementComboBox(lua_State *L, id obj) {
    HSUITKElementComboBox *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementComboBox *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementComboBox(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementComboBox *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementComboBox, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"completes",        comboBox_completes},
    {"verticalScroller", comboBox_hasVerticalScroller},
    {"buttonBorder",     comboBox_buttonBordered},
    {"itemHeight",       comboBox_itemHeight},
    {"visibleLines",     comboBox_numberOfVisibleItems},
    {"intercellSpacing", comboBox_intercellSpacing},
    {"objects",          comboBox_objects},
    {"numberOfObjects",  comboBox_numberOfItems},

// other metamethods inherited from _control and _view
    {NULL,                      NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", comboBox_new},
    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_element_libtextField_comboBox(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSUITKElementComboBox  forClass:"HSUITKElementComboBox"];
    [skin registerLuaObjectHelper:toHSUITKElementComboBox forClass:"HSUITKElementComboBox"
                                               withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"completes",
        @"verticalScroller",
        @"buttonBorder",
        @"itemHeight",
        @"visibleLines",
        @"intercellSpacing",
        @"objects",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}
