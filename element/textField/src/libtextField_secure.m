@import Cocoa ;
@import LuaSkin ;
@import Carbon.HIToolbox.Events ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.textField.secure" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

@interface HSUITKElementSecureTextField : NSSecureTextField <NSTextFieldDelegate>
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        editingCallbackRef ;
@property            int        callbackRef ;
@end

@implementation HSUITKElementSecureTextField

- (void)commonInit {
    _callbackRef        = LUA_NOREF ;
    _editingCallbackRef = LUA_NOREF ;
    _refTable           = refTable ;
    _selfRefCount       = 0 ;
    self.delegate       = self ;
//     self.target         = self ;
//     self.action         = @selector(performCallback:) ;
}

+ (instancetype)textFieldFromString:(NSString *)stringValue {
    HSUITKElementSecureTextField *textField = [HSUITKElementSecureTextField textFieldWithString:stringValue] ;

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

// - (void)performCallback:(__unused id)sender {
//     [self callbackHamster:@[ self, self.stringValue ]] ;
// }

- (BOOL)performKeyEquivalent:(NSEvent *)event {
    unsigned short       keyCode       = event.keyCode ;
//     NSEventModifierFlags modifierFlags = event.modifierFlags & NSDeviceIndependentModifierFlagsMask ;
//     [LuaSkin logWarn:[NSString stringWithFormat:@"%s:performKeyEquivalent: key:%3d, mods:0x%08lx %@", USERDATA_TAG, keyCode, (unsigned long)modifierFlags, event]] ;

    NSString *keyName = nil ;
    switch (keyCode) {
        case kVK_Return:     keyName = @"return" ; break ;
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

static int secureTextField_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *string = (lua_gettop(L) == 0) ? nil : [skin toNSObjectAtIndex:1] ;
    HSUITKElementSecureTextField *element = [HSUITKElementSecureTextField textFieldFromString:string] ;

    if (element) {
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int secureTextField_echosBullets(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSecureTextField *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, ((NSSecureTextFieldCell *)element.cell).echosBullets) ;
    } else {
        ((NSSecureTextFieldCell *)element.cell).echosBullets = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementSecureTextField(lua_State *L, id obj) {
    HSUITKElementSecureTextField *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementSecureTextField *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementSecureTextField(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementSecureTextField *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementSecureTextField, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"echosBullets",            secureTextField_echosBullets},

// other metamethods inherited from _control and _view
    {NULL,                      NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", secureTextField_new},
    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_element_libtextField_secure(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSUITKElementSecureTextField  forClass:"HSUITKElementSecureTextField"];
    [skin registerLuaObjectHelper:toHSUITKElementSecureTextField forClass:"HSUITKElementSecureTextField"
                                                      withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"echosBullets",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}
