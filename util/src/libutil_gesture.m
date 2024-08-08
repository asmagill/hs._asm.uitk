@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG         = "hs._asm.uitk.util.gesture" ;
static const char * const UD_CLICK_TAG         = "hs._asm.uitk.util.gesture.click" ;
static const char * const UD_MAGNIFICATION_TAG = "hs._asm.uitk.util.gesture.magnification" ;
static const char * const UD_PAN_TAG           = "hs._asm.uitk.util.gesture.pan" ;
static const char * const UD_PRESS_TAG         = "hs._asm.uitk.util.gesture.press" ;
static const char * const UD_ROTATION_TAG      = "hs._asm.uitk.util.gesture.rotation" ;

static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
#define get_anyObjectFromUserdata(objType, L, idx) (objType*)*((void**)lua_touserdata(L, idx))

static NSDictionary *RECOGNIZER_STATE ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    RECOGNIZER_STATE = @{
        @(NSGestureRecognizerStateBegan)     : @"begin",
        @(NSGestureRecognizerStateCancelled) : @"cancelled",
        @(NSGestureRecognizerStateChanged)   : @"changed",
        @(NSGestureRecognizerStateEnded)     : @"ended",
        @(NSGestureRecognizerStateFailed)    : @"failed",
        @(NSGestureRecognizerStatePossible)  : @"possible",
    } ;
}

@interface HSUITKUtilGestureClick : NSClickGestureRecognizer <NSGestureRecognizerDelegate>
@property int selfRefCount ;
@property int callbackRef ;
@end

@interface HSUITKUtilGestureMagnification : NSMagnificationGestureRecognizer <NSGestureRecognizerDelegate>
@property int selfRefCount ;
@property int callbackRef ;
@end

@interface HSUITKUtilGesturePan : NSPanGestureRecognizer <NSGestureRecognizerDelegate>
@property int selfRefCount ;
@property int callbackRef ;
@end

@interface HSUITKUtilGesturePress : NSPressGestureRecognizer <NSGestureRecognizerDelegate>
@property int selfRefCount ;
@property int callbackRef ;
@end

@interface HSUITKUtilGestureRotation : NSRotationGestureRecognizer <NSGestureRecognizerDelegate>
@property int selfRefCount ;
@property int callbackRef ;
@end

@implementation HSUITKUtilGestureClick

- (instancetype)init {
    self = [super initWithTarget:self action:NSSelectorFromString(@"handleGesture:")] ;
    if (self) {
        _selfRefCount = 0 ;
        _callbackRef  = LUA_NOREF ;

        self.delegate = self ;
    }
    return self ;
}

- (void)handleGesture:(NSGestureRecognizer *)gestureRecognizer {
    NSString *state = RECOGNIZER_STATE[@(self.state)] ;
    if (!state) state = [NSString stringWithFormat:@"unrecognized: %@", @(self.state)] ;
    [self callbackHamster:@[ self, state ]] ;
}

- (void)callbackHamster:(NSArray *)messageParts { // does the "heavy lifting"
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        for (id part in messageParts) [skin pushNSObject:part] ;
        if (![skin protectedCallAndTraceback:(int)messageParts.count nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:callback error:%@", UD_CLICK_TAG, errorMessage]] ;
        }
    } else {
        // allow next responder a chance since we don't have a callback set
        NSObject *nextInChain = self.view ;
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

// Delegate methods
//
// - (BOOL)gestureRecognizerShouldBegin:(NSGestureRecognizer *)gestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldAttemptToRecognizeWithEvent:(NSEvent *)event;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(NSTouch *)touch;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;

@end

@implementation HSUITKUtilGestureMagnification
- (instancetype)init {
    self = [super initWithTarget:self action:NSSelectorFromString(@"handleGesture:")] ;
    if (self) {
        _selfRefCount = 0 ;
        _callbackRef  = LUA_NOREF ;

        self.delegate = self ;
    }
    return self ;
}

- (void)handleGesture:(NSGestureRecognizer *)gestureRecognizer {
    NSString *state = RECOGNIZER_STATE[@(self.state)] ;
    if (!state) state = [NSString stringWithFormat:@"unrecognized: %@", @(self.state)] ;
    [self callbackHamster:@[ self, state ]] ;
}

- (void)callbackHamster:(NSArray *)messageParts { // does the "heavy lifting"
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        for (id part in messageParts) [skin pushNSObject:part] ;
        if (![skin protectedCallAndTraceback:(int)messageParts.count nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:callback error:%@", UD_MAGNIFICATION_TAG, errorMessage]] ;
        }
    } else {
        // allow next responder a chance since we don't have a callback set
        NSObject *nextInChain = self.view ;
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

// Delegate methods
//
// - (BOOL)gestureRecognizerShouldBegin:(NSGestureRecognizer *)gestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldAttemptToRecognizeWithEvent:(NSEvent *)event;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(NSTouch *)touch;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;

@end

@implementation HSUITKUtilGesturePan
- (instancetype)init {
    self = [super initWithTarget:self action:NSSelectorFromString(@"handleGesture:")] ;
    if (self) {
        _selfRefCount = 0 ;
        _callbackRef  = LUA_NOREF ;

        self.delegate = self ;
    }
    return self ;
}

- (void)handleGesture:(NSGestureRecognizer *)gestureRecognizer {
    NSString *state = RECOGNIZER_STATE[@(self.state)] ;
    if (!state) state = [NSString stringWithFormat:@"unrecognized: %@", @(self.state)] ;
    [self callbackHamster:@[ self, state ]] ;
}

- (void)callbackHamster:(NSArray *)messageParts { // does the "heavy lifting"
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        for (id part in messageParts) [skin pushNSObject:part] ;
        if (![skin protectedCallAndTraceback:(int)messageParts.count nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:callback error:%@", UD_PAN_TAG, errorMessage]] ;
        }
    } else {
        // allow next responder a chance since we don't have a callback set
        NSObject *nextInChain = self.view ;
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

// Delegate methods
//
// - (BOOL)gestureRecognizerShouldBegin:(NSGestureRecognizer *)gestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldAttemptToRecognizeWithEvent:(NSEvent *)event;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(NSTouch *)touch;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;

@end

@implementation HSUITKUtilGesturePress
- (instancetype)init {
    self = [super initWithTarget:self action:NSSelectorFromString(@"handleGesture:")] ;
    if (self) {
        _selfRefCount = 0 ;
        _callbackRef  = LUA_NOREF ;

        self.delegate = self ;
    }
    return self ;
}

- (void)handleGesture:(NSGestureRecognizer *)gestureRecognizer {
    NSString *state = RECOGNIZER_STATE[@(self.state)] ;
    if (!state) state = [NSString stringWithFormat:@"unrecognized: %@", @(self.state)] ;
    [self callbackHamster:@[ self, state ]] ;
}

- (void)callbackHamster:(NSArray *)messageParts { // does the "heavy lifting"
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        for (id part in messageParts) [skin pushNSObject:part] ;
        if (![skin protectedCallAndTraceback:(int)messageParts.count nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:callback error:%@", UD_PRESS_TAG, errorMessage]] ;
        }
    } else {
        // allow next responder a chance since we don't have a callback set
        NSObject *nextInChain = self.view ;
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

// Delegate methods
//
// - (BOOL)gestureRecognizerShouldBegin:(NSGestureRecognizer *)gestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldAttemptToRecognizeWithEvent:(NSEvent *)event;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(NSTouch *)touch;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;

@end

@implementation HSUITKUtilGestureRotation
- (instancetype)init {
    self = [super initWithTarget:self action:NSSelectorFromString(@"handleGesture:")] ;
    if (self) {
        _selfRefCount = 0 ;
        _callbackRef  = LUA_NOREF ;

        self.delegate = self ;
    }
    return self ;
}

- (void)handleGesture:(NSGestureRecognizer *)gestureRecognizer {
    NSString *state = RECOGNIZER_STATE[@(self.state)] ;
    if (!state) state = [NSString stringWithFormat:@"unrecognized: %@", @(self.state)] ;
    [self callbackHamster:@[ self, state ]] ;
}

- (void)callbackHamster:(NSArray *)messageParts { // does the "heavy lifting"
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        [skin pushLuaRef:refTable ref:_callbackRef] ;
        for (id part in messageParts) [skin pushNSObject:part] ;
        if (![skin protectedCallAndTraceback:(int)messageParts.count nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:callback error:%@", UD_ROTATION_TAG, errorMessage]] ;
        }
    } else {
        // allow next responder a chance since we don't have a callback set
        NSObject *nextInChain = self.view ;
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

// Delegate methods
//
// - (BOOL)gestureRecognizerShouldBegin:(NSGestureRecognizer *)gestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldAttemptToRecognizeWithEvent:(NSEvent *)event;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(NSTouch *)touch;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;

@end

static BOOL oneOfOurs(NSGestureRecognizer *gesture) {
    return [gesture isKindOfClass:[HSUITKUtilGestureClick class]] ||
           [gesture isKindOfClass:[HSUITKUtilGestureMagnification class]] ||
           [gesture isKindOfClass:[HSUITKUtilGesturePan class]] ||
           [gesture isKindOfClass:[HSUITKUtilGesturePress class]] ||
           [gesture isKindOfClass:[HSUITKUtilGestureRotation class]] ;
}

#pragma mark - Module Functions -

static int gesture_newClick(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    HSUITKUtilGestureClick *gesture = [[HSUITKUtilGestureClick alloc] init] ;
    if (gesture) {
        [skin pushNSObject:gesture] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int gesture_newMagnification(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    HSUITKUtilGestureMagnification *gesture = [[HSUITKUtilGestureMagnification alloc] init] ;
    if (gesture) {
        [skin pushNSObject:gesture] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int gesture_newPan(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    HSUITKUtilGesturePan *gesture = [[HSUITKUtilGesturePan alloc] init] ;
    if (gesture) {
        [skin pushNSObject:gesture] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int gesture_newPress(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    HSUITKUtilGesturePress *gesture = [[HSUITKUtilGesturePress alloc] init] ;
    if (gesture) {
        [skin pushNSObject:gesture] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int gesture_newRotation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    HSUITKUtilGestureRotation *gesture = [[HSUITKUtilGestureRotation alloc] init] ;
    if (gesture) {
        [skin pushNSObject:gesture] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Common Methods -

static int gesture_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGestureClick *gesture = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!gesture || !oneOfOurs(gesture)) {
        return luaL_argerror(L, 1, "expected userdata representing a gesture element") ;
    }

    if (lua_gettop(L) == 2) {
        gesture.callbackRef = [skin luaUnref:refTable ref:gesture.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            gesture.callbackRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (gesture.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:gesture.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int gesture_enabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSGestureRecognizer *gesture = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!gesture || !oneOfOurs(gesture)) {
        return luaL_argerror(L, 1, "expected userdata representing a gesture element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, gesture.enabled) ;
    } else {
        gesture.enabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gesture_state(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    NSGestureRecognizer *gesture = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!gesture || !oneOfOurs(gesture)) {
        return luaL_argerror(L, 1, "expected userdata representing a gesture element") ;
    }

    NSString *state = RECOGNIZER_STATE[@(gesture.state)] ;
    if (!state) state = [NSString stringWithFormat:@"unrecognized: %@", @(gesture.state)] ;
    [skin pushNSObject:state] ;
    return 1 ;
}

static int gesture_reset(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    NSGestureRecognizer *gesture = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!gesture || !oneOfOurs(gesture)) {
        return luaL_argerror(L, 1, "expected userdata representing a gesture element") ;
    }

    [gesture reset] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int gesture_view(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    NSGestureRecognizer *gesture = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!gesture || !oneOfOurs(gesture)) {
        return luaL_argerror(L, 1, "expected userdata representing a gesture element") ;
    }

    NSView *view = gesture.view ;
    [skin pushNSObject:view] ;
    return 1 ;
}

static int gesture_locationInView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    NSGestureRecognizer *gesture = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!gesture || !oneOfOurs(gesture)) {
        return luaL_argerror(L, 1, "expected userdata representing a gesture element") ;
    }

    [skin pushNSPoint:[gesture locationInView:gesture.view]] ;
    return 1 ;
}

#pragma mark - Click Methods -

static int gesture_click_buttonMask(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CLICK_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGestureClick *gesture = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_newtable(L) ;
        for (uint8_t i = 0; i < 32 ; i++) {
            if ((gesture.buttonMask & (1<<i)) > 0) {
                lua_pushboolean(L, true) ; lua_rawseti(L, -2, i + 1) ;
                if (i == 0) { lua_pushboolean(L, true) ; lua_setfield(L, -2, "left") ; }
                if (i == 1) { lua_pushboolean(L, true) ; lua_setfield(L, -2, "right") ; }
                if (i == 2) { lua_pushboolean(L, true) ; lua_setfield(L, -2, "middle") ; }
            }
        }
    } else {
        NSUInteger mask = 0 ;
        for (uint8_t i = 0; i < 32 ; i++) {
            lua_geti(L, 2, i + 1) ;
            if (lua_toboolean(L, -1)) mask |= (1<<i) ;
            lua_pop(L, 1) ;
        }
        lua_getfield(L, 2, "left") ;
        if (lua_toboolean(L, -1)) mask |= (1<<0) ;
        lua_pop(L, 1) ;
        lua_getfield(L, 2, "right") ;
        if (lua_toboolean(L, -1)) mask |= (1<<1) ;
        lua_pop(L, 1) ;
        lua_getfield(L, 2, "middle") ;
        if (lua_toboolean(L, -1)) mask |= (1<<2) ;
        lua_pop(L, 1) ;

        gesture.buttonMask = mask ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gesture_click_numberOfClicksRequired(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CLICK_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGestureClick *gesture = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, gesture.numberOfClicksRequired) ;
    } else {
        NSInteger value = lua_tointeger(L, 2) ;
        if (value < 1) return luaL_argerror(L, 2, "must be a positive integer") ;
        gesture.numberOfClicksRequired = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gesture_click_numberOfTouchesRequired(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CLICK_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGestureClick *gesture = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, gesture.numberOfTouchesRequired) ;
    } else {
        NSInteger value = lua_tointeger(L, 2) ;
        if (value < 1) return luaL_argerror(L, 2, "must be a positive integer") ;
        gesture.numberOfTouchesRequired = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Magnification Methods -

static int gesture_magnification_magnification(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_MAGNIFICATION_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGestureMagnification *gesture = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, gesture.magnification) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
//         if (value < 1) return luaL_argerror(L, 2, "must be a positive integer") ;
        gesture.magnification = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Pan Methods -

static int gesture_pan_translationInView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PAN_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGesturePan *gesture = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSPoint:[gesture translationInView:gesture.view]] ;
    } else {
        NSPoint point = [skin tableToPointAtIndex:2] ;
        [gesture setTranslation:point inView:gesture.view] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gesture_pan_velocityInView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PAN_TAG, LS_TBREAK] ;
    HSUITKUtilGesturePan *gesture = [skin toNSObjectAtIndex:1] ;

    [skin pushNSPoint:[gesture velocityInView:gesture.view]] ;
    return 1 ;
}

static int gesture_pan_numberOfTouchesRequired(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PAN_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGesturePan *gesture = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, gesture.numberOfTouchesRequired) ;
    } else {
        NSInteger value = lua_tointeger(L, 2) ;
        if (value < 1) return luaL_argerror(L, 2, "must be a positive integer") ;
        gesture.numberOfTouchesRequired = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gesture_pan_buttonMask(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PAN_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGesturePan *gesture = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_newtable(L) ;
        for (uint8_t i = 0; i < 32 ; i++) {
            if ((gesture.buttonMask & (1<<i)) > 0) {
                lua_pushboolean(L, true) ; lua_rawseti(L, -2, i + 1) ;
                if (i == 0) { lua_pushboolean(L, true) ; lua_setfield(L, -2, "left") ; }
                if (i == 1) { lua_pushboolean(L, true) ; lua_setfield(L, -2, "right") ; }
                if (i == 2) { lua_pushboolean(L, true) ; lua_setfield(L, -2, "middle") ; }
            }
        }
    } else {
        NSUInteger mask = 0 ;
        for (uint8_t i = 0; i < 32 ; i++) {
            lua_geti(L, 2, i + 1) ;
            if (lua_toboolean(L, -1)) mask |= (1<<i) ;
            lua_pop(L, 1) ;
        }
        lua_getfield(L, 2, "left") ;
        if (lua_toboolean(L, -1)) mask |= (1<<0) ;
        lua_pop(L, 1) ;
        lua_getfield(L, 2, "right") ;
        if (lua_toboolean(L, -1)) mask |= (1<<1) ;
        lua_pop(L, 1) ;
        lua_getfield(L, 2, "middle") ;
        if (lua_toboolean(L, -1)) mask |= (1<<2) ;
        lua_pop(L, 1) ;

        gesture.buttonMask = mask ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Press Methods -

static int gesture_press_allowableMovement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PRESS_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGesturePress *gesture = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, gesture.allowableMovement) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
//         if (value < 1) return luaL_argerror(L, 2, "must be a positive integer") ;
        gesture.allowableMovement = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gesture_press_numberOfTouchesRequired(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PRESS_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGesturePress *gesture = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, gesture.numberOfTouchesRequired) ;
    } else {
        NSInteger value = lua_tointeger(L, 2) ;
        if (value < 1) return luaL_argerror(L, 2, "must be a positive integer") ;
        gesture.numberOfTouchesRequired = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gesture_press_minimumPressDuration(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PRESS_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGesturePress *gesture = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, gesture.minimumPressDuration) ;
    } else {
        NSTimeInterval value = lua_tonumber(L, 2) ;
//         if (value < 1) return luaL_argerror(L, 2, "must be a positive integer") ;
        gesture.minimumPressDuration = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gesture_press_buttonMask(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PRESS_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGesturePress *gesture = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_newtable(L) ;
        for (uint8_t i = 0; i < 32 ; i++) {
            if ((gesture.buttonMask & (1<<i)) > 0) {
                lua_pushboolean(L, true) ; lua_rawseti(L, -2, i + 1) ;
                if (i == 0) { lua_pushboolean(L, true) ; lua_setfield(L, -2, "left") ; }
                if (i == 1) { lua_pushboolean(L, true) ; lua_setfield(L, -2, "right") ; }
                if (i == 2) { lua_pushboolean(L, true) ; lua_setfield(L, -2, "middle") ; }
            }
        }
    } else {
        NSUInteger mask = 0 ;
        for (uint8_t i = 0; i < 32 ; i++) {
            lua_geti(L, 2, i + 1) ;
            if (lua_toboolean(L, -1)) mask |= (1<<i) ;
            lua_pop(L, 1) ;
        }
        lua_getfield(L, 2, "left") ;
        if (lua_toboolean(L, -1)) mask |= (1<<0) ;
        lua_pop(L, 1) ;
        lua_getfield(L, 2, "right") ;
        if (lua_toboolean(L, -1)) mask |= (1<<1) ;
        lua_pop(L, 1) ;
        lua_getfield(L, 2, "middle") ;
        if (lua_toboolean(L, -1)) mask |= (1<<2) ;
        lua_pop(L, 1) ;

        gesture.buttonMask = mask ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Rotation Methods -

static int gesture_rotation_rotation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROTATION_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGestureRotation *gesture = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, gesture.rotation) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
//         if (value < 1) return luaL_argerror(L, 2, "must be a positive integer") ;
        gesture.rotation = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gesture_rotation_rotationInDegrees(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROTATION_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGestureRotation *gesture = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, gesture.rotationInDegrees) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
//         if (value < 1) return luaL_argerror(L, 2, "must be a positive integer") ;
        gesture.rotationInDegrees = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKUtilGestureClick(lua_State *L, id obj) {
    HSUITKUtilGestureClick *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKUtilGestureClick *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_CLICK_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKUtilGestureClick(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKUtilGestureClick *value ;
    if (luaL_testudata(L, idx, UD_CLICK_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKUtilGestureClick, L, idx, UD_CLICK_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_CLICK_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushHSUITKUtilGestureMagnification(lua_State *L, id obj) {
    HSUITKUtilGestureMagnification *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKUtilGestureMagnification *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_MAGNIFICATION_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKUtilGestureMagnification(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKUtilGestureMagnification *value ;
    if (luaL_testudata(L, idx, UD_MAGNIFICATION_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKUtilGestureMagnification, L, idx, UD_MAGNIFICATION_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_MAGNIFICATION_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushHSUITKUtilGesturePan(lua_State *L, id obj) {
    HSUITKUtilGesturePan *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKUtilGesturePan *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_PAN_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKUtilGesturePan(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKUtilGesturePan *value ;
    if (luaL_testudata(L, idx, UD_PAN_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKUtilGesturePan, L, idx, UD_PAN_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_PAN_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushHSUITKUtilGesturePress(lua_State *L, id obj) {
    HSUITKUtilGesturePress *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKUtilGesturePress *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_PRESS_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKUtilGesturePress(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKUtilGesturePress *value ;
    if (luaL_testudata(L, idx, UD_PRESS_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKUtilGesturePress, L, idx, UD_PRESS_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_PRESS_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushHSUITKUtilGestureRotation(lua_State *L, id obj) {
    HSUITKUtilGestureRotation *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKUtilGestureRotation *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_ROTATION_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKUtilGestureRotation(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKUtilGestureRotation *value ;
    if (luaL_testudata(L, idx, UD_ROTATION_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKUtilGestureRotation, L, idx, UD_ROTATION_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_ROTATION_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKUtilGestureClick *obj = [skin toNSObjectAtIndex:1] ;
    NSString *tag   = @(USERDATA_TAG) ;
    if ([obj isKindOfClass:[HSUITKUtilGestureClick class]]) {
        tag = @(UD_CLICK_TAG) ;
    } else if ([obj isKindOfClass:[HSUITKUtilGestureMagnification class]]) {
        tag = @(UD_MAGNIFICATION_TAG) ;
    } else if ([obj isKindOfClass:[HSUITKUtilGesturePan class]]) {
        tag = @(UD_PAN_TAG) ;
    } else if ([obj isKindOfClass:[HSUITKUtilGesturePress class]]) {
        tag = @(UD_PRESS_TAG) ;
    } else if ([obj isKindOfClass:[HSUITKUtilGestureRotation class]]) {
        tag = @(UD_ROTATION_TAG) ;
    }
    [skin pushNSObject:[NSString stringWithFormat:@"%@: (%p)", tag, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if ((lua_type(L, 1) == LUA_TUSERDATA) && (lua_type(L, 2) == LUA_TUSERDATA)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        NSObject *obj1 = [skin toNSObjectAtIndex:1] ;
        NSObject *obj2 = [skin toNSObjectAtIndex:2];
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSUITKUtilGestureClick *obj = get_anyObjectFromUserdata(__bridge_transfer HSUITKUtilGestureClick, L, 1) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj = nil ;
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
static const luaL_Reg ud_click_metaLib[] = {
    {"buttons",         gesture_click_buttonMask},
    {"clicksRequired",  gesture_click_numberOfClicksRequired},
    {"touchesRequired", gesture_click_numberOfTouchesRequired},

    {"callback",        gesture_callback},
    {"enabled",         gesture_enabled},
    {"state",           gesture_state},
    {"view",            gesture_view},
    {"location",        gesture_locationInView},
    {"reset",           gesture_reset},

    {"__tostring",      userdata_tostring},
    {"__eq",            userdata_eq},
    {"__gc",            userdata_gc},
    {NULL, NULL}
};

static const luaL_Reg ud_magnification_metaLib[] = {
    {"magnification", gesture_magnification_magnification},

    {"callback",      gesture_callback},
    {"enabled",       gesture_enabled},
    {"state",         gesture_state},
    {"view",          gesture_view},
    {"location",      gesture_locationInView},
    {"reset",           gesture_reset},

    {"__tostring",    userdata_tostring},
    {"__eq",          userdata_eq},
    {"__gc",          userdata_gc},
    {NULL, NULL}
};

static const luaL_Reg ud_pan_metaLib[] = {
    {"translation",     gesture_pan_translationInView},
    {"velocity",        gesture_pan_velocityInView},
    {"touchesRequired", gesture_pan_numberOfTouchesRequired},
    {"buttonMask",      gesture_pan_buttonMask},

    {"callback",        gesture_callback},
    {"enabled",         gesture_enabled},
    {"state",           gesture_state},
    {"view",            gesture_view},
    {"location",        gesture_locationInView},
    {"reset",           gesture_reset},

    {"__tostring",      userdata_tostring},
    {"__eq",            userdata_eq},
    {"__gc",            userdata_gc},
    {NULL, NULL}
};

static const luaL_Reg ud_press_metaLib[] = {
    {"allowableMovement", gesture_press_allowableMovement},
    {"touchesRequired",   gesture_press_numberOfTouchesRequired},
    {"minimumDuration",   gesture_press_minimumPressDuration},
    {"buttons",           gesture_press_buttonMask},

    {"callback",          gesture_callback},
    {"enabled",           gesture_enabled},
    {"state",             gesture_state},
    {"view",              gesture_view},
    {"location",          gesture_locationInView},
    {"reset",             gesture_reset},

    {"__tostring",        userdata_tostring},
    {"__eq",              userdata_eq},
    {"__gc",              userdata_gc},
    {NULL, NULL}
};

static const luaL_Reg ud_rotation_metaLib[] = {
    {"rotation",          gesture_rotation_rotation},
    {"rotationInDegrees", gesture_rotation_rotationInDegrees},

    {"callback",          gesture_callback},
    {"enabled",           gesture_enabled},
    {"state",             gesture_state},
    {"view",              gesture_view},
    {"location",          gesture_locationInView},
    {"reset",             gesture_reset},

    {"__tostring",        userdata_tostring},
    {"__eq",              userdata_eq},
    {"__gc",              userdata_gc},
    {NULL, NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"click",         gesture_newClick},
    {"magnification", gesture_newMagnification},
    {"pan",           gesture_newPan},
    {"press",         gesture_newPress},
    {"rotation",      gesture_newRotation},
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_libutil_gesture(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibrary:USERDATA_TAG
                           functions:moduleLib
                       metaFunctions:nil];

    [skin registerObject:UD_CLICK_TAG          objectFunctions:ud_click_metaLib] ;
    [skin registerObject:UD_MAGNIFICATION_TAG  objectFunctions:ud_magnification_metaLib] ;
    [skin registerObject:UD_PAN_TAG            objectFunctions:ud_pan_metaLib] ;
    [skin registerObject:UD_PRESS_TAG          objectFunctions:ud_press_metaLib] ;
    [skin registerObject:UD_ROTATION_TAG       objectFunctions:ud_rotation_metaLib] ;

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKUtilGestureClick  forClass:"HSUITKUtilGestureClick"];
    [skin registerLuaObjectHelper:toHSUITKUtilGestureClick forClass:"HSUITKUtilGestureClick"
                                                withUserdataMapping:UD_CLICK_TAG];

    [skin registerPushNSHelper:pushHSUITKUtilGestureMagnification  forClass:"HSUITKUtilGestureMagnification"];
    [skin registerLuaObjectHelper:toHSUITKUtilGestureMagnification forClass:"HSUITKUtilGestureMagnification"
                                                        withUserdataMapping:UD_MAGNIFICATION_TAG];

    [skin registerPushNSHelper:pushHSUITKUtilGesturePan  forClass:"HSUITKUtilGesturePan"];
    [skin registerLuaObjectHelper:toHSUITKUtilGesturePan forClass:"HSUITKUtilGesturePan"
                                              withUserdataMapping:UD_PAN_TAG];

    [skin registerPushNSHelper:pushHSUITKUtilGesturePress  forClass:"HSUITKUtilGesturePress"];
    [skin registerLuaObjectHelper:toHSUITKUtilGesturePress forClass:"HSUITKUtilGesturePress"
                                                withUserdataMapping:UD_PRESS_TAG];

    [skin registerPushNSHelper:pushHSUITKUtilGestureRotation  forClass:"HSUITKUtilGestureRotation"];
    [skin registerLuaObjectHelper:toHSUITKUtilGestureRotation forClass:"HSUITKUtilGestureRotation"
                                                   withUserdataMapping:UD_ROTATION_TAG];

    return 1;
}
