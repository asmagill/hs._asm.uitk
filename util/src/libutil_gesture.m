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
        NSResponder *nextInChain = self.view ;
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

// Delegate methods
//
// - (BOOL)gestureRecognizerShouldBegin:(NSGestureRecognizer *)gestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldAttemptToRecognizeWithEvent:(NSEvent *)event;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(NSTouch *)touch;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;

- (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer {
    BOOL answer = NO ;

    if ([self isEqualTo:gestureRecognizer] && [otherGestureRecognizer isKindOfClass:[NSClickGestureRecognizer class]]) {
        NSClickGestureRecognizer *other = (NSClickGestureRecognizer *)otherGestureRecognizer ;

        answer = [self.view isEqualTo:other.view] &&
                 (self.buttonMask == other.buttonMask) &&
                 (self.numberOfClicksRequired < other.numberOfClicksRequired) ;
    }

    return answer ;
}

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
        NSResponder *nextInChain = self.view ;
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
        NSResponder *nextInChain = self.view ;
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
        NSResponder *nextInChain = self.view ;
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

// Delegate methods
//
// - (BOOL)gestureRecognizerShouldBegin:(NSGestureRecognizer *)gestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldAttemptToRecognizeWithEvent:(NSEvent *)event;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(NSTouch *)touch;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;

- (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer {
    BOOL answer = NO ;

    if ([self isEqualTo:gestureRecognizer] && [otherGestureRecognizer isKindOfClass:[NSPressGestureRecognizer class]]) {
        NSPressGestureRecognizer *other = (NSPressGestureRecognizer *)otherGestureRecognizer ;

        answer = [self.view isEqualTo:other.view] &&
                 (self.buttonMask == other.buttonMask) &&
                 (self.minimumPressDuration < other.minimumPressDuration) ;
    }

    return answer ;
}

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
        NSResponder *nextInChain = self.view ;
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

// Delegate methods
//
// - (BOOL)gestureRecognizerShouldBegin:(NSGestureRecognizer *)gestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldAttemptToRecognizeWithEvent:(NSEvent *)event;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(NSTouch *)touch;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;
// - (BOOL)gestureRecognizer:(NSGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(NSGestureRecognizer *)otherGestureRecognizer;

@end

static BOOL oneOfOurGestureObjects(NSGestureRecognizer *gesture) {
    return [gesture isKindOfClass:[HSUITKUtilGestureClick class]] ||
           [gesture isKindOfClass:[HSUITKUtilGestureMagnification class]] ||
           [gesture isKindOfClass:[HSUITKUtilGesturePan class]] ||
           [gesture isKindOfClass:[HSUITKUtilGesturePress class]] ||
           [gesture isKindOfClass:[HSUITKUtilGestureRotation class]] ;
}

#pragma mark - Module Functions -

/// hs._asm.uitk.util.gesture.click() -> gestureObject
/// Constructor
/// Creates a new click gesture object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a new click gesture object
///
/// Notes:
///  * a click gesture is triggered when the specified mouse button is clicked a specific number of times in a short period without dragging.
///
///  * if more than one click gesture recognizer with identical settings for [hs._asm.uitk.util.gesture:buttons](#buttons) but differing [hs._asm.uitk.util.gesture:clicks](#clicks) are assigned to the same `hs._asm.uitk.element` object, the one with fewer clicks will delay being triggered (i.e. sending "begin" to its callback, if defined) long enough to make sure that the other gesture has failed -- this is to ensure that only the correct gesture recognizer is triggered and reduce false positives.
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

/// hs._asm.uitk.util.gesture.magnification() -> gestureObject
/// Constructor
/// Creates a new magnification gesture object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a new magnification gesture object
///
/// Notes:
///  * a magnification gesture is continuous gesture recognizer that tracks a pinch gesture on the trackpad representing a magnification or shrinking motion.
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

/// hs._asm.uitk.util.gesture.pan() -> gestureObject
/// Constructor
/// Creates a new pan gesture object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a new pan gesture object
///
/// Notes:
///  * a pan gesture is continuous gesture recognizer that tracks dragging while the specified button or buttons are pressed. Releasing any of the specified buttons will end the gesture.
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

/// hs._asm.uitk.util.gesture.press() -> gestureObject
/// Constructor
/// Creates a new press gesture object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a new press gesture object
///
/// Notes:
///  * a press gesture is triggered when the specified mouse button or buttons are pressed and held for the specified amount of time without dragging.
///
///  * if more than one press gesture recognizer with identical settings for [hs._asm.uitk.util.gesture:buttons](#buttons) but differing [hs._asm.uitk.util.gesture:duration](#duration) valuesare assigned to the same `hs._asm.uitk.element` object, the one with the shorter duration will delay being triggered (i.e. sending "begin" to its callback, if defined) long enough to make sure that the other gesture has failed -- this is to ensure that only the correct gesture recognizer is triggered and reduce false positives.
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

/// hs._asm.uitk.util.gesture.rotation() -> gestureObject
/// Constructor
/// Creates a new rotation gesture object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a new rotation gesture object
///
/// Notes:
///  * a rotation gesture is continuous gesture recognizer that tracks two trackpad touches moving in opposite directions in a circular motion.
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

/// hs._asm.uitk.util.gesture:callback([fn | nil]) -> gestureObject | function | nil
/// Method
/// Get or set the callback function invoked when the gesture is triggered or in progress.
///
/// Parameters:
///  * `fn` - an optional function, or explicit `nil` to remove, that will be called when the gesture is recognized or triggered within the assigned view.
///
/// Returns:
///  * If an argument is provided, the gesture object; otherwise the current value.
///
/// Notes:
///  * The callback should expect two arguments and return none. The arguments received will be the gesture object and a string specifying the state of the gesture.
///
/// * for a Click gesture, the following callback will occur:
///    * `onj, "ended"` -- indicates that the user has clicked the appropriate button the specified number of times.
///
/// * for a Magnification gesture, the following callbacks will occur:
///    * `obj, "begin"`  -- indicates that the magnification gesture has been recognized.
///    * `obj, "changed" -- indicates that the magnification gesture has moved in our out and the magnification value has changed
///    * `onj, "ended"`  -- indicates that the user has ended the magnification gesture.
///
/// * for a Pan gesture, the following callbacks will occur:
///    * `obj, "begin"`  -- indicates that the user has pressed the specified button(s) and started dragging.
///    * `obj, "changed" -- indicates that the pan gesture has moved and the translation and/or velocity values have changed
///    * `onj, "ended"`  -- indicates that the user has ended the pan gesture.
///
///  * for a Press gesture, the following callbacks will occur:
///    * `obj, "begin"`  -- indicates that the user has pressed the specified mouse buttons for the specified period of time.
///    * `obj, "changed" -- indicates that the press gesture has moved; this will only occur after the time specified has passed.
///    * `onj, "ended"`  -- indicates that the user has released the mouse button.
///
/// * for a Rotation gesture, the following callbacks will occur:
///    * `obj, "begin"`  -- indicates that the rotation gesture has been recognized.
///    * `obj, "changed" -- indicates that the rotation gesture has moved CW or CCW and the rotation value has changed
///    * `onj, "ended"`  -- indicates that the user has ended the rotation gesture.
///
/// * the "cancelled" state may also be received by any gesture, if the gesture has been cancelled, most commonly because you have invoked the [hs._asm.uitk.util.gesture:cancel](@cancel) method on the gesture object, or changed its enabled state with [hs._asm.uitk.util.gesture:enabled](#enabled).
static int gesture_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGestureClick *gesture = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!gesture || !oneOfOurGestureObjects(gesture)) {
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

/// hs._asm.uitk.util.gesture:enabled([state]) -> gestureObject | boolean
/// Method
/// Get or set the enabled status of the gesture recognizer.
///
/// Parameters:
///  * `state` - an optional boolean indicating whether the gesture should be enabled (true) or disabled (false).
///
/// Returns:
///  * If an argument is provided, the gesture object; otherwise the current value.
///
/// Notes:
///  * a disabled gesture will not recognize its gesture; this can be used to suspend a specific gesture without actually removing it from the view it is attached to.
///
///  * if a gesture recognizer is currently in progress, setting this to false will cause the recognition to be cancelled and a "cancelled" message will be sent to the gesture's callback, if defined.
static int gesture_enabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSGestureRecognizer *gesture = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!gesture || !oneOfOurGestureObjects(gesture)) {
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

/// hs._asm.uitk.util.gesture:state() -> string
/// Method
/// Returns a string specifying the current state of the gesture recognizer.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string specifying the current state of the recognizer.
///
/// Notes:
///  * the string returned will be one of the following:
///    * "possible"  - the gesture hasn't yet been recognized by recent macOS events; this is the default state
///    * "begin"     - the gesture has been recognized and the callback, if defined, has been called
///    * "cancelled" - the gesture has been cancelled, most likely because [hs._asm.uitk.util.gesture:cancel](#cancel) has been called or the gesture has been disabled with [hs._asm.uitk.util.gesture:enabled](#enabled) while the gesture was active.
///    * "changed"   - the tracked value (rotation, magnification, location, etc.) of a recognized gesture has changed and you should reflect this as appropriate in your user interface. For most gestures, this will be invoked multiple times while the gesture is still active.
///    * "ended"     - the gesture has ended, likely because the user has released the mouse button(s) or stopped making the gesture motion on the trackpad.
///    * "failed"    - indicates that the gesture has failed, likely because one or more of its requirements has not been met. You shouldn't see this message often, if at all in your callbacks.
static int gesture_state(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    NSGestureRecognizer *gesture = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!gesture || !oneOfOurGestureObjects(gesture)) {
        return luaL_argerror(L, 1, "expected userdata representing a gesture element") ;
    }

    NSString *state = RECOGNIZER_STATE[@(gesture.state)] ;
    if (!state) state = [NSString stringWithFormat:@"unrecognized: %@", @(gesture.state)] ;
    [skin pushNSObject:state] ;
    return 1 ;
}

/// hs._asm.uitk.util.gesture:element() -> elementObject | nil
/// Method
/// Returns the view the gesture is currently attached to, or nil if the gesture is currently unattached.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the uitkObject for the element the gesture is attached to, or nil if it is currently unattached.
///
/// Notes:
///  * gestures are added and removed from elements using the element's `:addGesture`, `:removeGesture`, and `:gestures` methods.
static int gesture_view(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    NSGestureRecognizer *gesture = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!gesture || !oneOfOurGestureObjects(gesture)) {
        return luaL_argerror(L, 1, "expected userdata representing a gesture element") ;
    }

    NSView *view = gesture.view ;
    [skin pushNSObject:view] ;
    return 1 ;
}

/// hs._asm.uitk.util.gesture:element() -> table
/// Method
/// Returns a point table specifying the location of the mouse pointer within the element the gesture is attached to when gesture recognition is in progress.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a point table, with `x` and `y` keys specifying the mouse position within the element.
///
/// Notes:
///  * the value returned by this method is only valid when called from within a callback, and can be used to determine the mouse pointer's location during the progression of the gesture.
///  * if this method is called while the gesture is inactive, the table returned will contain an unspecified point.
static int gesture_locationInView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    NSGestureRecognizer *gesture = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!gesture || !oneOfOurGestureObjects(gesture)) {
        return luaL_argerror(L, 1, "expected userdata representing a gesture element") ;
    }

    [skin pushNSPoint:[gesture locationInView:gesture.view]] ;
    return 1 ;
}

#pragma mark - Shared Methods -

/// hs._asm.uitk.util.gesture:buttons([buttons]) -> gestureObject | table
/// Method
/// Get or set the buttons required to trigger a Pan, Click, or Press gesture.
///
/// Parameters:
///  * `buttons` - an optional table specifying the buttons required for the gesture. Defaults to the primary mouse button.
///
/// Returns:
///  * If an argument is provided, the gesture object; otherwise the current value.
///
/// Notes:
///  * this method is only valid for the Pan, Click or Press gesture types.
///
///  * the `buttons` table should be a table of up to 32 boolean values specifying the button or buttons required for the gesture.
///    * for convenience, the first three buttons (left (primary), right, and middle) can be specified as key-value pairs with the keys "left", "right", and "middle".
///    * the table can be sparse - you only need to define as true the button(s) required, e.g. `buttons = {} ; butons[3] = true`, `{ false, false, true }`, and `{ middle = true }` are all equivalent.
///
///  * the table returned will be a sparse table in which only the required button position(s) in the table will be set to true.
///    * for convenience, the first three buttons (left (primary), right, and middle) will also set the keys "left", "right", and "middle" if they are required.
static int gesture_shared_buttonMask(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    // Click arbitrarily chosen to reduces compiler warnings; really it could be any that recognize buttonMask
    NSClickGestureRecognizer *gesture = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!(gesture && ([gesture isKindOfClass:[NSClickGestureRecognizer class]] ||
                      [gesture isKindOfClass:[NSPanGestureRecognizer class]]   ||
                      [gesture isKindOfClass:[NSPressGestureRecognizer class]]))) {
        return luaL_argerror(L, 2, "expected userdata representing press, pan, or click gesture") ;
    }

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

/// hs._asm.uitk.util.gesture:touches([num]) -> gestureObject | int
/// Method
/// Get or set the number of touches required in the touchbar to trigger a Pan, Click, or Press gesture.
///
/// Parameters:
///  * `num` - an optional integer, default 1, specifying the number of touches in the touchbar required for the gesture.
///
/// Returns:
///  * If an argument is provided, the gesture object; otherwise the current value.
///
/// Notes:
///  * this method is only valid for the Pan, Click or Press gesture types.
///
///  * at the moment, the `hs._asm.uitk` modules do not directly support the touchbar; this may or may not change in the future.
///  * the `hs._asm.uitk.element` object *may* work with `hs._asm.touchbar`, but this is untested and is purely theoretical at the moment.
static int gesture_shared_numberOfTouchesRequired(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;

    // Click arbitrarily chosen to reduces compiler warnings; really it could be any that recognize numberOfTouchesRequired
    NSClickGestureRecognizer *gesture = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!(gesture && ([gesture isKindOfClass:[NSClickGestureRecognizer class]] ||
                      [gesture isKindOfClass:[NSPanGestureRecognizer class]]   ||
                      [gesture isKindOfClass:[NSPressGestureRecognizer class]]))) {
        return luaL_argerror(L, 2, "expected userdata representing press, pan, or click gesture") ;
    }

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

#pragma mark - Click Methods -

/// hs._asm.uitk.util.gesture:clicks([num]) -> gestureObject | int
/// Method
/// Get or set the number of clicks required to trigger a Click gesture.
///
/// Parameters:
///  * `num` - an optional integer, default 1, specifying the number of clicks required for the gesture.
///
/// Returns:
///  * If an argument is provided, the gesture object; otherwise the current value.
///
/// Notes:
///  * this method is only valid for the Click gesture type.
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

#pragma mark - Magnification Methods -

/// hs._asm.uitk.util.gesture:magnification() -> number
/// Method
/// Get the current magnification value as generated by a Magnification gesture.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a number specifying the amount of magnification or shrinking specified by the magnification gesture
///
/// Notes:
///  * this method is only valid for the Magnification gesture type.
///
///  * When the gesture is not active, this method will return 0.0
///  * the magnification is the cumulative amount of magnification or shrinking that has occurred since the gesture was recognized (i.e. since "begin" was received by the callback function, if defined)
///  * While the gesture recognizer is active and callbacks are being performed, a number less than 1.0 indicates a shrinking motion while a number greater than 1.0 indicates a magnification or spreading motion.
static int gesture_magnification_magnification(lua_State *L) {
//NOTE:  technically a read-write property, but since we're limiting ourselves to only the built-in gesture types
// and not custom or combinations atm, there is no obvious benefit to being able to set it; wait until requested.
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_MAGNIFICATION_TAG, LS_TBREAK] ;
    HSUITKUtilGestureMagnification *gesture = [skin toNSObjectAtIndex:1] ;

    lua_pushnumber(L, 1.0 + gesture.magnification) ;
    return 1 ;
}

#pragma mark - Pan Methods -

/// hs._asm.uitk.util.gesture:translation() -> table
/// Method
/// Get the current translation for a Pan gesture.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a point table where `x` and `y` keys specify the horizontal and vertical distance the pan gesture has moved from it's origin point.
///
/// Notes:
///  * this method is only valid for the Pan gesture type.
///
///  * you can get the gesture's origin point by storing the [hs._asm.uitk.util.gesture:location](#location) value when the Pan gesture's callback is called with the "begin" state.
static int gesture_pan_translationInView(lua_State *L) {
//NOTE:  technically a read-write property, but since we're limiting ourselves to only the built-in gesture types
// and not custom or combinations atm, there is no obvious benefit to being able to set it; wait until requested.
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PAN_TAG, LS_TBREAK] ;
    HSUITKUtilGesturePan *gesture = [skin toNSObjectAtIndex:1] ;

    [skin pushNSPoint:[gesture translationInView:gesture.view]] ;
    return 1 ;
}

/// hs._asm.uitk.util.gesture:velocity() -> table
/// Method
/// Get the current rate of change for a Pan gesture.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a point table where `x` and `y` keys specify the current horizontal and vertical rate of change in points per second for the pan gesture.
///
/// Notes:
///  * this method is only valid for the Pan gesture type.
static int gesture_pan_velocityInView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PAN_TAG, LS_TBREAK] ;
    HSUITKUtilGesturePan *gesture = [skin toNSObjectAtIndex:1] ;

    [skin pushNSPoint:[gesture velocityInView:gesture.view]] ;
    return 1 ;
}

#pragma mark - Press Methods -

/// hs._asm.uitk.util.gesture:movement([distance]) -> gestureObject | number
/// Method
/// Get or set the maximum distance the mouse pointer can move before failing while waiting for a Press gesture to activate.
///
/// Parameters:
///  * `distance` - an optional number specifying in points the maximum absolute distance the mouse pointer can move before failing while waiting for the Press gesture to activate. Defaults to the current double-click distance.
///
/// Returns:
///  * If an argument is provided, the gesture object; otherwise the current value.
///
/// Notes:
///  * this method is only valid for the Press gesture type.
///
///  * `distance`, if provided, must be a positive number greater than 0.0.
///  * once the gesture has been recognized, the mouse pointer may move, and as long as the required buttons remain pressed, will report to the callback as "change" events.
static int gesture_press_allowableMovement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PRESS_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGesturePress *gesture = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, gesture.allowableMovement) ;
    } else {
        CGFloat value = lua_tonumber(L, 2) ;
        if (value <= 0.0) return luaL_argerror(L, 2, "must be a positive number") ;
        gesture.allowableMovement = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.util.gesture:duration([seconds]) -> gestureObject | number
/// Method
/// Get or set the current duration required for a Press gesture.
///
/// Parameters:
///  * `seconds` - an optional number specifying in seconds the minimum time the press gesture must be held before recognizing the gesture. Defaults to the current double-click interval - see `hs.eventtap.doubleClickInterval`.
///
/// Returns:
///  * If an argument is provided, the gesture object; otherwise the current value.
///
/// Notes:
///  * this method is only valid for the Press gesture type.
///
///  * `seconds`, if provided, must be a positive number greater than 0.0.
static int gesture_press_minimumPressDuration(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_PRESS_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGesturePress *gesture = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, gesture.minimumPressDuration) ;
    } else {
        NSTimeInterval value = lua_tonumber(L, 2) ;
        if (value <= 0.0) return luaL_argerror(L, 2, "must be a positive number") ;
        gesture.minimumPressDuration = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Rotation Methods -

/// hs._asm.uitk.util.gesture:rotation([degrees]) -> number
/// Method
/// Get the current rotation value as generated by a Rotation gesture.
///
/// Parameters:
///  * `degrees` - an optional boolean, default true, specifying whether the rotation angle should be reported in degrees (true) or in radians (false).
///
/// Returns:
///  * a number specifying the amount of rotation specified by the rotation gesture.
///
/// Notes:
///  * this method is only valid for the Rotation gesture type.
///
///  * When the gesture is not active, this method will return 0.0
///  * the rotation is the cumulative amount of rotation that has occurred since the gesture was recognized (i.e. since "begin" was received by the callback function, if defined)
///  * While the gesture recognizer is active and callbacks are being performed, a number greater than 0.0 indicates a clockwise rotation while a number less than 0.0 indicates a counter-clockwise rotation.
static int gesture_rotation_rotation(lua_State *L) {
//NOTE:  technically a read-write property, but since we're limiting ourselves to only the built-in gesture types
// and not custom or combinations atm, there is no obvious benefit to being able to set it; wait until requested.
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROTATION_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKUtilGestureRotation *gesture = [skin toNSObjectAtIndex:1] ;

    BOOL inDegrees = (lua_gettop(L) == 2) ? (BOOL)(lua_toboolean(L, 2)) : YES ;

    lua_pushnumber(L, -(inDegrees ? gesture.rotationInDegrees : gesture.rotation)) ;
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
    {"touches",    gesture_shared_numberOfTouchesRequired},
    {"buttons",    gesture_shared_buttonMask},
    {"clicks",     gesture_click_numberOfClicksRequired},

    {"callback",   gesture_callback},
    {"enabled",    gesture_enabled},

    {"state",      gesture_state},
    {"element",    gesture_view},
    {"location",   gesture_locationInView},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL, NULL}
};

static const luaL_Reg ud_magnification_metaLib[] = {
    {"magnification", gesture_magnification_magnification},

    {"callback",      gesture_callback},
    {"enabled",       gesture_enabled},

    {"state",         gesture_state},
    {"element",       gesture_view},
    {"location",      gesture_locationInView},

    {"__tostring",    userdata_tostring},
    {"__eq",          userdata_eq},
    {"__gc",          userdata_gc},
    {NULL, NULL}
};

static const luaL_Reg ud_pan_metaLib[] = {
    {"touches",     gesture_shared_numberOfTouchesRequired},
    {"buttons",     gesture_shared_buttonMask},

    {"translation", gesture_pan_translationInView},
    {"velocity",    gesture_pan_velocityInView},

    {"callback",    gesture_callback},
    {"enabled",     gesture_enabled},

    {"state",       gesture_state},
    {"element",     gesture_view},
    {"location",    gesture_locationInView},

    {"__tostring",  userdata_tostring},
    {"__eq",        userdata_eq},
    {"__gc",        userdata_gc},
    {NULL, NULL}
};

static const luaL_Reg ud_press_metaLib[] = {
    {"touches",    gesture_shared_numberOfTouchesRequired},
    {"buttons",    gesture_shared_buttonMask},

    {"movement",   gesture_press_allowableMovement},
    {"duration",   gesture_press_minimumPressDuration},

    {"callback",   gesture_callback},
    {"enabled",    gesture_enabled},

    {"state",      gesture_state},
    {"element",    gesture_view},
    {"location",   gesture_locationInView},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL, NULL}
};

static const luaL_Reg ud_rotation_metaLib[] = {
    {"rotation",        gesture_rotation_rotation},

    {"callback",        gesture_callback},
    {"enabled",         gesture_enabled},

    {"state",           gesture_state},
    {"element",         gesture_view},
    {"location",        gesture_locationInView},

    {"__tostring",      userdata_tostring},
    {"__eq",            userdata_eq},
    {"__gc",            userdata_gc},
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

    luaL_getmetatable(L, UD_CLICK_TAG) ;
    [skin pushNSObject:@[
        @"touches",
        @"buttons",

        @"clicks",

        @"callback",
        @"enabled",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    luaL_getmetatable(L, UD_MAGNIFICATION_TAG) ;
    [skin pushNSObject:@[
        @"callback",
        @"enabled",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    luaL_getmetatable(L, UD_PAN_TAG) ;
    [skin pushNSObject:@[
        @"touches",
        @"buttons",

        @"callback",
        @"enabled",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    luaL_getmetatable(L, UD_PRESS_TAG) ;
    [skin pushNSObject:@[
        @"touches",
        @"buttons",

        @"movement",
        @"duration",

        @"callback",
        @"enabled",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    luaL_getmetatable(L, UD_ROTATION_TAG) ;
    [skin pushNSObject:@[
        @"callback",
        @"enabled",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
