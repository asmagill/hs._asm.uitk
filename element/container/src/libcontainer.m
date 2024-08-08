@import Cocoa ;
@import LuaSkin ;

// for our purposes this is 1/1000 of a screen point; small enough that it can't be seen so effectively 0
#define FLOAT_EQUIVALENT_TO_ZERO 0.001

static const char * const USERDATA_TAG = "hs._asm.uitk.element.container" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

@interface HSUITKElementContainerView : NSView <NSDraggingDestination>
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ; // in this case, it's the passthrough callback for subviews
                                              // with no callbacks, but we keep the name since this is
                                              // checked in _view for the common methods
@property BOOL           trackMouseEvents ;
@property BOOL           trackMouseMove ;
@property int            mouseCallback ;
@property int            frameChangeCallback ;
@property int            draggingCallbackRef ;
@property NSMapTable     *subviewDetails ;
@property NSColor        *frameDebugColor ;
@end


BOOL oneOfOurs(NSView *obj) {
    return [obj isKindOfClass:[NSView class]]  &&
           [obj respondsToSelector:NSSelectorFromString(@"selfRefCount")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setSelfRefCount:")] &&
           [obj respondsToSelector:NSSelectorFromString(@"refTable")] &&
           [obj respondsToSelector:NSSelectorFromString(@"callbackRef")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setCallbackRef:")] ;
}

static NSNumber *convertPercentageStringToNumber(NSString *stringValue) {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.locale = [NSLocale currentLocale] ;

    formatter.numberStyle = NSNumberFormatterDecimalStyle ;
    NSNumber *tmpValue = [formatter numberFromString:stringValue] ;
    if (!tmpValue) {
        formatter.numberStyle = NSNumberFormatterPercentStyle ;
        tmpValue = [formatter numberFromString:stringValue] ;
    }
    // just to be sure, let's also check with the en_US locale
    if (!tmpValue) {
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"] ;
        formatter.numberStyle = NSNumberFormatterDecimalStyle ;
        tmpValue = [formatter numberFromString:stringValue] ;
        if (!tmpValue) {
            formatter.numberStyle = NSNumberFormatterPercentStyle ;
            tmpValue = [formatter numberFromString:stringValue] ;
        }
    }
    return tmpValue ;
}

@implementation HSUITKElementContainerView {
    NSTrackingArea *_trackingArea ;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    @try {
        self = [super initWithFrame:frameRect] ;
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:new - %@", USERDATA_TAG, exception.reason]] ;
        self = nil ;
    }

    if (self) {
        _selfRefCount        = 0 ;
        _trackMouseEvents    = NO ;
        _trackMouseMove      = NO ;
        _refTable            = refTable ;
        _callbackRef         = LUA_NOREF ;
        _mouseCallback       = LUA_NOREF ;
        _frameChangeCallback = LUA_NOREF ;
        _draggingCallbackRef = LUA_NOREF ;
        _subviewDetails      = [NSMapTable strongToStrongObjectsMapTable] ;
        _frameDebugColor     = nil ;

        self.postsFrameChangedNotifications = YES ;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(frameChangedNotification:)
                                                     name:NSViewFrameDidChangeNotification
                                                   object:nil] ;

        _trackingArea = [[NSTrackingArea alloc] initWithRect:frameRect
                                                     options:NSTrackingMouseMoved |
                                                             NSTrackingMouseEnteredAndExited |
                                                             NSTrackingActiveAlways |
                                                             NSTrackingInVisibleRect
                                                       owner:self
                                                    userInfo:nil] ;
        [self addTrackingArea:_trackingArea] ;

//         self.wantsLayer = YES ;
    }
    return self ;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSViewFrameDidChangeNotification
                                                  object:nil] ;
    [self removeTrackingArea:_trackingArea] ;
    _trackingArea = nil ;
}

// Follow the Hammerspoon convention
- (BOOL)isFlipped { return YES; }

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect] ;

    if (_frameDebugColor) {
        NSGraphicsContext* gc = [NSGraphicsContext currentContext];
        [gc saveGraphicsState];

        [NSBezierPath setDefaultLineWidth:2.0] ;
        [_frameDebugColor setStroke] ;
        [self.subviews enumerateObjectsUsingBlock:^(NSView *view, __unused NSUInteger idx, __unused BOOL *stop) {
            NSRect frame = view.frame ;
            // Since this is for debugging frames, check if a size component approaches/is effectively invisible... .5 point should do
            if ((frame.size.height < 0.5) || (frame.size.width < 0.5)) {
                NSPoint topLeft = NSMakePoint(frame.origin.x, frame.origin.y) ;
                NSPoint btRight = NSMakePoint(frame.origin.x + frame.size.width, frame.origin.y + frame.size.height) ;
            // comparing floats is problematic, but for our purposes, if the difference is less than this, it has no visible width
                if (btRight.x - topLeft.x < FLOAT_EQUIVALENT_TO_ZERO) {
                    topLeft.x -= 5 ;
                    btRight.x += 5 ;
                }
            // comparing floats is problematic, but for our purposes, if the difference is less than this, it has no visible height
                if (btRight.y - topLeft.y < FLOAT_EQUIVALENT_TO_ZERO) {
                    topLeft.y -= 5 ;
                    btRight.y += 5 ;
                }
                [NSBezierPath strokeLineFromPoint:topLeft toPoint:btRight] ;
                [NSBezierPath strokeLineFromPoint:NSMakePoint(topLeft.x, btRight.y) toPoint:NSMakePoint(btRight.x, topLeft.y)] ;
            } else {
                [NSBezierPath strokeRect:view.frame] ;
            }
        }] ;
        [gc restoreGraphicsState];
    }
}

// NOTE: Passthrough Callback Support

// allow next responder a chance since we don't have a callback set
- (void)passCallbackUpWith:(NSArray *)arguments {
    NSResponder *nextInChain = [self nextResponder] ;

    SEL passthroughCallback = NSSelectorFromString(@"performPassthroughCallback:") ;
    while(nextInChain) {
        if ([nextInChain respondsToSelector:passthroughCallback]) {
            [nextInChain performSelectorOnMainThread:passthroughCallback
                                          withObject:arguments
                                       waitUntilDone:YES] ;
            break ;
        } else {
            nextInChain = nextInChain.nextResponder ;
        }
    }
}

// perform callback for subviews which don't have a callback defined
- (void)performPassthroughCallback:(NSArray *)arguments {
    if (_callbackRef != LUA_NOREF) {
        LuaSkin *skin    = [LuaSkin sharedWithState:NULL] ;
        int     argCount = 1 ;

        [skin pushLuaRef:refTable ref:_callbackRef] ;
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
    } else {
        [self passCallbackUpWith:@[ self, arguments ]] ;
    }
}

// NOTE: Frame Change Notification and Propagation

- (void)doFrameChangeCallbackWith:(NSView *)targetView {
    if (_frameChangeCallback != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        [skin pushLuaRef:refTable ref:_frameChangeCallback] ;
        [skin pushNSObject:self] ;
        [skin pushNSObject:targetView] ;
        if (![skin protectedCallAndTraceback:2 nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:[NSString stringWithFormat:@"%s:frameChangeCallback error:%@", USERDATA_TAG, errorMessage]] ;
        }
// We're not passing this up for now
//     } else {
//         [self passCallbackUpWith:@[ self, targetView ]] ;
    }
}

- (void)frameChangedNotification:(NSNotification *)notification {
    NSView *targetView = notification.object ;
    if (targetView) {
        if ([targetView isEqualTo:self]) {
            [self doFrameChangeCallbackWith:targetView] ;
            for (NSView *view in self.subviews) [self updateFrameFor:view] ;
        } else {
            if ([self.subviews containsObject:targetView]) {
                [self doFrameChangeCallbackWith:targetView] ;
                [self updateFrameFor:targetView] ;
            }
        }
    }
}

// allows _view frameSize to update details recorded for item
- (void)resetFrameSizeDetailsFor:(NSView *)view {
    NSMutableDictionary *details = [_subviewDetails objectForKey:view] ;
    if (details) {
        NSSize updatedSize = view.frame.size ;
        details[@"h"] = @(updatedSize.height) ;
        details[@"w"] = @(updatedSize.width) ;
    }
}

- (void) updateFrameFor:(NSView *)view {
    NSMutableDictionary *details = [_subviewDetails objectForKey:view] ;
    NSRect frame = view.frame ;
//     [LuaSkin logInfo:[NSString stringWithFormat:@"oldFrame: %@", NSStringFromRect(frame)]] ;
    if (details[@"h"]) {
        NSNumber *value = details[@"h"] ;
        if ([value isKindOfClass:[NSString class]]) {
            value = convertPercentageStringToNumber((NSString *)value) ;
            value = @(self.frame.size.height * value.doubleValue) ;
        }
        frame.size.height = value.doubleValue ;
    } else {
        frame.size.height = view.fittingSize.height ;
    }
    if (details[@"w"]) {
        NSNumber *value = details[@"w"] ;
        if ([value isKindOfClass:[NSString class]]) {
            value = convertPercentageStringToNumber((NSString *)value) ;
            value = @(self.frame.size.width * value.doubleValue) ;
        }
        frame.size.width = value.doubleValue ;
    } else {
        frame.size.width = view.fittingSize.width ;
    }
    if (details[@"x"]) {
        NSNumber *value = details[@"x"] ;
        if ([value isKindOfClass:[NSString class]]) {
            value = convertPercentageStringToNumber((NSString *)value) ;
            value = @(self.frame.size.width * value.doubleValue) ;
        }
        frame.origin.x = value.doubleValue ;
    }
    if (details[@"y"]) {
        NSNumber *value = details[@"y"] ;
        if ([value isKindOfClass:[NSString class]]) {
            value = convertPercentageStringToNumber((NSString *)value) ;
            value = @(self.frame.size.height * value.doubleValue) ;
        }
        frame.origin.y = value.doubleValue ;
    }

    if (details[@"cX"]) {
        NSNumber *value = details[@"cX"] ;
        if ([value isKindOfClass:[NSString class]]) {
            value = convertPercentageStringToNumber((NSString *)value) ;
            value = @(self.frame.size.width * value.doubleValue) ;
        }
        frame.origin.x = value.doubleValue - (frame.size.width / 2) ;
    }
    if (details[@"cY"]) {
        NSNumber *value = details[@"cY"] ;
        if ([value isKindOfClass:[NSString class]]) {
            value = convertPercentageStringToNumber((NSString *)value) ;
            value = @(self.frame.size.height * value.doubleValue) ;
        }
        frame.origin.y = value.doubleValue - (frame.size.height / 2) ;
    }

    if (details[@"rX"]) {
        NSNumber *value = details[@"rX"] ;
        if ([value isKindOfClass:[NSString class]]) {
            value = convertPercentageStringToNumber((NSString *)value) ;
            value = @(self.frame.size.width * value.doubleValue) ;
        }
        frame.origin.x = value.doubleValue - frame.size.width ;
    }
    if (details[@"bY"]) {
        NSNumber *value = details[@"bY"] ;
        if ([value isKindOfClass:[NSString class]]) {
            value = convertPercentageStringToNumber((NSString *)value) ;
            value = @(self.frame.size.height * value.doubleValue) ;
        }
        frame.origin.y = value.doubleValue - frame.size.height ;
    }
//     [LuaSkin logInfo:[NSString stringWithFormat:@"newFrame: %@", NSStringFromRect(frame)]] ;
    view.frame = frame ;
}

- (NSSize)fittingSize {
    NSSize fittedContentSize = NSZeroSize ;

    if ([self.subviews count] > 0) {
        __block NSPoint bottomRight = NSZeroPoint ;
        [self.subviews enumerateObjectsUsingBlock:^(NSView *view, __unused NSUInteger idx, __unused BOOL *stop) {
            NSRect frame             = view.frame ;
            NSPoint frameBottomRight = NSMakePoint(frame.origin.x + frame.size.width, frame.origin.y + frame.size.height) ;
// unless we add a "shrinkToFit" (as opposed to sizeToFit) we only care about the subview sizes as currently expressed
//             NSSize viewFittingSize   = view.fittingSize ;
//             if (!CGSizeEqualToSize(viewFittingSize, NSZeroSize)) {
//                 frameBottomRight = NSMakePoint(frame.origin.x + viewFittingSize.width, frame.origin.y + viewFittingSize.height) ;
//             }
            if (frameBottomRight.x > bottomRight.x) bottomRight.x = frameBottomRight.x ;
            if (frameBottomRight.y > bottomRight.y) bottomRight.y = frameBottomRight.y ;
        }] ;

        fittedContentSize = NSMakeSize(bottomRight.x, bottomRight.y) ;
    }

    return fittedContentSize ;
}

// NOTE: Subviews

- (void)didAddSubview:(NSView *)subview {
    LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
//     [skin logInfo:[NSString stringWithFormat:@"%s:didAddSubview - added %@", USERDATA_TAG, subview]] ;
    // increase lua reference count of subview so it won't be collected
    if (![skin luaRetain:refTable forNSObject:subview]) {
        [skin logDebug:[NSString stringWithFormat:@"%s:didAddSubview - unrecognized subview added:%@", USERDATA_TAG, subview]] ;

//         [self updateFrameFor:subview] ;
    }
}

- (void)willRemoveSubview:(NSView *)subview {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
//     [skin logInfo:[NSString stringWithFormat:@"%s:willRemoveSubview - removed %@", USERDATA_TAG, subview]] ;
    [skin luaRelease:refTable forNSObject:subview] ;
}

// NOTE: Mouse tracking

- (void) invokeMouseTrackingCallback:(NSString *)message forEvent:(NSEvent *)theEvent {
    if (_trackMouseEvents) {
        NSPoint point     = [self convertPoint:theEvent.locationInWindow fromView:nil];
        NSValue *location = [NSValue valueWithPoint:point] ;

        if (_mouseCallback != LUA_NOREF) {
            LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
            [skin pushLuaRef:refTable ref:_mouseCallback] ;
            [skin pushNSObject:self] ;
            [skin pushNSObject:message] ;
            [skin pushNSObject:location] ;
            if (![skin protectedCallAndTraceback:3 nresults:0]) {
                NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
                lua_pop(skin.L, 1) ;
                [skin logError:[NSString stringWithFormat:@"%s:mouseCallback error:%@", USERDATA_TAG, errorMessage]] ;
            }
// We're not passing this up for now
//         } else {
//             [self passCallbackUpWith:@[ self, message, location ]] ;
        }
    }
}

- (void) mouseMoved:(NSEvent *)theEvent {
    if (_trackMouseMove) [self invokeMouseTrackingCallback:@"move" forEvent:theEvent] ;
}

- (void) mouseEntered:(NSEvent *)theEvent {
    [self invokeMouseTrackingCallback:@"enter" forEvent:theEvent] ;
}

- (void) mouseExited:(NSEvent *)theEvent {
    [self invokeMouseTrackingCallback:@"exit" forEvent:theEvent] ;
}

// NOTE: NSDraggingDestination protocol methods

- (BOOL)draggingCallback:(NSString *)message with:(id<NSDraggingInfo>)sender {
    BOOL isAllGood = NO ;
    if (_draggingCallbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        lua_State *L = skin.L ;
        int argCount = 2 ;
        [skin pushLuaRef:refTable ref:_draggingCallbackRef] ;
        [skin pushNSObject:self] ;
        [skin pushNSObject:message] ;
        if (sender) {
            lua_newtable(L) ;
            NSPasteboard *pasteboard = [sender draggingPasteboard] ;
            if (pasteboard) {
                [skin pushNSObject:pasteboard.name] ; lua_setfield(L, -2, "pasteboard") ;
            }
            lua_pushinteger(L, [sender draggingSequenceNumber]) ; lua_setfield(L, -2, "sequence") ;
            [skin pushNSPoint:[sender draggingLocation]] ; lua_setfield(L, -2, "mouse") ;
            NSDragOperation operation = [sender draggingSourceOperationMask] ;
            lua_newtable(L) ;
            if (operation == NSDragOperationNone) {
                lua_pushstring(L, "none") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
            } else {
                if ((operation & NSDragOperationCopy) == NSDragOperationCopy) {
                    lua_pushstring(L, "copy") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationLink) == NSDragOperationLink) {
                    lua_pushstring(L, "link") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationGeneric) == NSDragOperationGeneric) {
                    lua_pushstring(L, "generic") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationPrivate) == NSDragOperationPrivate) {
                    lua_pushstring(L, "private") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationMove) == NSDragOperationMove) {
                    lua_pushstring(L, "move") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationDelete) == NSDragOperationDelete) {
                    lua_pushstring(L, "delete") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
            }
            lua_setfield(L, -2, "operation") ;
            argCount += 1 ;
        }
        if ([skin protectedCallAndTraceback:argCount nresults:1]) {
            isAllGood = lua_isnoneornil(L, -1) ? YES : (BOOL)(lua_toboolean(skin.L, -1)) ;
        } else {
            [skin logError:[NSString stringWithFormat:@"%s:draggingCallback error: %@", USERDATA_TAG, [skin toNSObjectAtIndex:-1]]] ;
        }
        lua_pop(L, 1) ;
    }
    return isAllGood ;
}

- (BOOL)wantsPeriodicDraggingUpdates {
    return NO ;
}

- (BOOL)prepareForDragOperation:(__unused id<NSDraggingInfo>)sender {
    return YES ;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    return [self draggingCallback:@"enter" with:sender] ? NSDragOperationGeneric : NSDragOperationNone ;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
    [self draggingCallback:@"exit" with:sender] ;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    return [self draggingCallback:@"receive" with:sender] ;
}

// - (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender ;
// - (void)concludeDragOperation:(id<NSDraggingInfo>)sender ;
// - (void)draggingEnded:(id<NSDraggingInfo>)sender ;
// - (void)updateDraggingItemsForDrag:(id<NSDraggingInfo>)sender

@end

static void validateElementDetailsTable(lua_State *L, int idx, NSMutableDictionary *details) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    idx = lua_absindex(L, idx) ;
    if (lua_type(L, idx) == LUA_TTABLE) {
        if (lua_getfield(L, idx, "id") == LUA_TSTRING) {
            details[@"id"] = [skin toNSObjectAtIndex:-1] ;
        } else if ((lua_type(L, -1) == LUA_TBOOLEAN) && !lua_toboolean(L, -1)) {
            details[@"id"] = nil ;
        } else if (lua_type(L, -1) != LUA_TNIL) {
            [skin logWarn:[NSString stringWithFormat:@"%s expected string or false for id key in element details, found %s", USERDATA_TAG, lua_typename(L, lua_type(L, -1))]] ;
        }
        lua_pop(L, 1) ;

        NSArray *xFields = @[ @"rX", @"cX", @"x" ] ;
        for (NSString *key in xFields) {
            if (lua_getfield(L, idx, key.UTF8String) != LUA_TNIL) {
                id newVal = [skin toNSObjectAtIndex:-1] ;
                if (lua_type(L, -1) == LUA_TSTRING) {
                    if (!convertPercentageStringToNumber(newVal)) {
                        [skin logWarn:[NSString stringWithFormat:@"%s:percentage string %@ invalid for %@ key in element details", USERDATA_TAG, newVal, key]] ;
                        newVal = nil ;
                    }
                } else if (lua_type(L, -1) != LUA_TNUMBER) {
                    [skin logWarn:[NSString stringWithFormat:@"%s:expected number or string for %@ key in element details, found %s", USERDATA_TAG, key, lua_typename(L, lua_type(L, -1))]] ;
                    newVal = nil ;
                }
                if (newVal) {
                    for (NSString *clearKey in xFields) details[clearKey] = nil ;
                    details[key] = newVal ;
                }
            }
            lua_pop(L, 1) ;
        }

        NSArray *yFields = @[ @"bY", @"cY", @"y" ] ;
        for (NSString *key in yFields) {
            if (lua_getfield(L, idx, key.UTF8String) != LUA_TNIL) {
                id newVal = [skin toNSObjectAtIndex:-1] ;
                if (lua_type(L, -1) == LUA_TSTRING) {
                    if (!convertPercentageStringToNumber(newVal)) {
                        [skin logWarn:[NSString stringWithFormat:@"%s:percentage string %@ invalid for %@ key in element details", USERDATA_TAG, newVal, key]] ;
                        newVal = nil ;
                    }
                } else if (lua_type(L, -1) != LUA_TNUMBER) {
                    [skin logWarn:[NSString stringWithFormat:@"%s:expected number or string for %@ key in element details, found %s", USERDATA_TAG, key, lua_typename(L, lua_type(L, -1))]] ;
                    newVal = nil ;
                }
                if (newVal) {
                    for (NSString *clearKey in yFields) details[clearKey] = nil ;
                    details[key] = newVal ;
                }
            }
            lua_pop(L, 1) ;
        }

        if (lua_getfield(L, idx, "h") == LUA_TSTRING) {
            NSString *value = [skin toNSObjectAtIndex:-1] ;
            if (convertPercentageStringToNumber(value)) {
                details[@"h"] = [skin toNSObjectAtIndex:-1] ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s percentage string %@ invalid for h key in element details", USERDATA_TAG, value]] ;
            }
        } else if (lua_type(L, -1) == LUA_TNUMBER) {
            details[@"h"] = [skin toNSObjectAtIndex:-1] ;
        } else if ((lua_type(L, -1) == LUA_TBOOLEAN) && !lua_toboolean(L, -1)) {
            details[@"h"] = nil ;
        } else if (lua_type(L, -1) != LUA_TNIL) {
            [skin logWarn:[NSString stringWithFormat:@"%s expected number, string, or false for h key in element details, found %s", USERDATA_TAG, lua_typename(L, lua_type(L, -1))]] ;
        }
        lua_pop(L, 1) ;

        if (lua_getfield(L, idx, "w") == LUA_TSTRING) {
            NSString *value = [skin toNSObjectAtIndex:-1] ;
            if (convertPercentageStringToNumber(value)) {
                details[@"w"] = [skin toNSObjectAtIndex:-1] ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s percentage string %@ invalid for w key in element details", USERDATA_TAG, value]] ;
            }
        } else if (lua_type(L, -1) == LUA_TNUMBER) {
            details[@"w"] = [skin toNSObjectAtIndex:-1] ;
        } else if ((lua_type(L, -1) == LUA_TBOOLEAN) && !lua_toboolean(L, -1)) {
            details[@"w"] = nil ;
        } else if (lua_type(L, -1) != LUA_TNIL) {
            [skin logWarn:[NSString stringWithFormat:@"%s expected number, string, or false for w key in element details, found %s", USERDATA_TAG, lua_typename(L, lua_type(L, -1))]] ;
        }
        lua_pop(L, 1) ;

//         if (lua_getfield(L, idx, "honorCanvasMove") == LUA_TBOOLEAN) {
//             details[@"honorCanvasMove"] = lua_toboolean(L, -1) ? @(YES) : nil ;
//         } else if (lua_type(L, -1) != LUA_TNIL) {
//             [skin logWarn:[NSString stringWithFormat:@"%s expected boolean or nil for honorCanvasMove key in element details, found %s", USERDATA_TAG, lua_typename(L, lua_type(L, -1))]] ;
//         }
//         lua_pop(L, 1) ;

    } else {
        [skin logWarn:[NSString stringWithFormat:@"%s expected table for element details, found %s", USERDATA_TAG, lua_typename(L, lua_type(L, idx))]] ;
    }
}

static void adjustElementDetailsTable(lua_State *L, HSUITKElementContainerView *container, NSView *element, NSDictionary *changes) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSMutableDictionary *details = [container.subviewDetails objectForKey:element] ;
    if (!details) details = [[NSMutableDictionary alloc] init] ;
    [skin pushNSObject:changes] ;
    validateElementDetailsTable(L, -1, details) ;
    [container.subviewDetails setObject:details forKey:element] ;
    [container updateFrameFor:element] ;
}

#pragma mark - Module Functions -

/// hs._asm.uitk.element.container.new([frame]) -> containerObject
/// Constructor
/// Creates a new container element for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the frame for the element.
///
/// Returns:
///  * the containerObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a window or to another container.
static int container_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementContainerView *container = [[HSUITKElementContainerView alloc] initWithFrame:frameRect];
    if (container) {
        if (lua_gettop(L) != 1) [container setFrameSize:[container fittingSize]] ;
        [skin pushNSObject:container] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

/// hs._asm.uitk.element.container:_debugFrames([color]) -> containerObject | table | nil
/// Method
/// Enable or disable visual rectangles around element frames in the container which can aid in identifying frame or positioning bugs.
///
/// Parameters:
///  * `color` - a color table (as defined in `hs.drawing.color`, boolean, or nil, specifying whether debugging frames should be displayed and if so in what color.
///
/// Returns:
///  * If an argument is provided, the container object; otherwise the current value.
///
/// Notes:
///  * Specifying `true` will enable the debugging frames with the current system color that represents the keyboard focus ring around controls.
///  * Specifying `false` or `nil` will disable the debugging frames (default).
///  * Specifying a color as defined by `hs.drawing.color` will display the debugging frames in the specified color.
///
///  * Element frames which contain a height or width which is less than .5 points (effectively invisible) will draw an X at the center of the elements position instead of a rectangle.
static int container__debugFrames(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TNIL | LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerView *container = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        if (container.frameDebugColor) {
            [skin pushNSObject:container.frameDebugColor] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (lua_type(L, 2) == LUA_TTABLE) {
            container.frameDebugColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        } else {
            if (lua_toboolean(L, 2) && lua_toboolean(L, 2)) {
                container.frameDebugColor = [NSColor keyboardFocusIndicatorColor] ;
            } else {
                container.frameDebugColor = nil ;
            }
        }
        container.needsDisplay = YES ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// /// hs._asm.uitk.element.container:autoPosition() -> containerObject
// /// Method
// /// Recalculate the position of all elements in the container and update them if necessary.
// ///
// /// Parameters:
// ///  * None
// ///
// /// Returns:
// ///  * the container object
// ///
// /// Notes:
// ///  * This method recalculates the position of elements whose position in `frameDetails` is specified by the element center or whose position or size are specified by percentages. See [hs._asm.uitk.element.container:elementFrame](#elementFrame) for more information.
// ///  * This method is invoked automatically anytime the container's parent (usually a `hs._asm.uitk.window`) is resized and you shouldn't need to invoke it manually very often. If you find that you are needing to invoke it manually on a regular basis, try to determine what the specific circumstances are and submit an issue so that it can be evaluated to determine if the situation can be detected and trigger an update automatically.
// ///
// /// * See also [hs._asm.uitk.element.container:elementAutoPosition](#elementAutoPosition).
// static int container_autoPosition(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
//     HSUITKElementContainerView *container = [skin toNSObjectAtIndex:1] ;
//     [container frameChangedNotification:[NSNotification notificationWithName:NSViewFrameDidChangeNotification object:container]] ;
//     lua_pushvalue(L, 1) ;
//     return 1 ;
// }

/// hs._asm.uitk.element.container:insert(element, [frameDetails], [pos]) -> containerObject
/// Method
/// Inserts a new element for the container to manage.
///
/// Parameters:
///  * `element`      - the element userdata to insert into the container
///  * `frameDetails` - an optional table containing frame details for the element as described for the [hs._asm.uitk.element.container:elementFrame](#elementFrame) method.
///  * `pos`          - the index position in the list of elements specifying where to insert the element.  Defaults to `#hs._asm.uitk.element.container:elements() + 1`, which will insert the element at the end.
///
/// Returns:
///  * the container object
///
/// Notes:
///  * If the frameDetails table is not provided, the elements position will default to the lower left corner of the last element added to the container, and its size will default to the element's fitting size as returned by [hs._asm.uitk.element.container:elementFittingSize](#elementFittingSize).
static int container_insertElement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TTABLE | LS_TOPTIONAL, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerView *container = [skin toNSObjectAtIndex:1] ;
    NSView *item = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;

    if (!item || !oneOfOurs(item)) {
        return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
    }
    if ([item isDescendantOf:container]) {
        return luaL_argerror(L, 2, "element already managed by this container or one of its elements") ;
    }

    NSInteger idx = (lua_type(L, -1) == LUA_TNUMBER) ? (lua_tointeger(L, -1) - 1) : (NSInteger)container.subviews.count ;
    if ((idx < 0) || (idx > (NSInteger)container.subviews.count)) return luaL_argerror(L, lua_gettop(L), "index out of bounds") ;

    NSMutableDictionary *details = [[NSMutableDictionary alloc] init] ;
    if (container.subviews.count > 0) {
        NSRect lastElementFrame = container.subviews.lastObject.frame ;
        details[@"x"] = @(lastElementFrame.origin.x) ;
        details[@"y"] = @(lastElementFrame.origin.y + lastElementFrame.size.height) ;
    } else {
        details[@"x"] = @(0) ;
        details[@"y"] = @(0) ;
    }
    if (lua_type(L, 3) == LUA_TTABLE) validateElementDetailsTable(L, 3, details) ;

    NSMutableArray *subviewHolder = [container.subviews mutableCopy] ;
    [subviewHolder insertObject:item atIndex:(NSUInteger)idx] ;
    container.subviews = subviewHolder ;
    adjustElementDetailsTable(L, container, item, details) ;

    // Comparing floats is problematic; but if the item is effectively invisible, warn if not set on purpose
    id suppressWarnings = [[NSUserDefaults standardUserDefaults] objectForKey:@"uitk_containerSuppressZeroWarnings" ] ;
    BOOL ignoreZeros = suppressWarnings ? ((NSNumber *)suppressWarnings).boolValue : NO ;

    if (!ignoreZeros) {
        if ((item.fittingSize.height < FLOAT_EQUIVALENT_TO_ZERO) && !details[@"h"]) {
            [skin logDebug:[NSString stringWithFormat:@"%s:insert - height not specified and default height for element is 0", USERDATA_TAG]] ;
        }
        if ((item.fittingSize.width < FLOAT_EQUIVALENT_TO_ZERO) && !details[@"w"]) {
            [skin logDebug:[NSString stringWithFormat:@"%s:insert - width not specified and default width for element is 0", USERDATA_TAG]] ;
        }
    }

    container.needsDisplay = YES ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int container_removeElement(lua_State *L) {
// NOTE: this method is wrapped in element_container.lua
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerView *container = [skin toNSObjectAtIndex:1] ;
    NSInteger idx = ((lua_type(L, 2) == LUA_TNUMBER) ? lua_tointeger(L, 2) : (NSInteger)container.subviews.count) - 1 ;
    if ((idx < 0) || (idx >= (NSInteger)container.subviews.count)) return luaL_argerror(L, lua_gettop(L), "index out of bounds") ;

    NSMutableArray *subviewHolder = [container.subviews mutableCopy] ;
    [subviewHolder removeObjectAtIndex:(NSUInteger)idx] ;
    container.subviews = subviewHolder ;

    container.needsDisplay = YES ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.element.container:passthroughCallback([fn | nil]) -> containerObject | fn | nil
/// Method
/// Get or set the pass through callback for the container.
///
/// Parameters:
///  * `fn` - a function, or an explicit nil to remove, specifying the callback to invoke for elements which do not have their own callbacks assigned.
///
/// Returns:
///  * If an argument is provided, the container object; otherwise the current value.
///
/// Notes:
///  * The pass through callback should expect one or two arguments and return none.
///
///  * The pass through callback is designed so that elements which trigger a callback based on user interaction which do not have a specifically assigned callback can still report user interaction through a common fallback.
///  * The arguments received by the pass through callback will be organized as follows:
///    * the container userdata object
///    * a table containing the arguments provided by the elements callback itself, usually the element userdata followed by any additional arguments as defined for the element's callback function.
///
///  * Note that elements which have a callback that returns a response cannot use this common pass through callback method; in such cases a specific callback must be assigned to the element directly as described in the element's documentation.
static int container_passthroughCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerView *container = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        container.callbackRef = [skin luaUnref:refTable ref:container.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            container.callbackRef = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (container.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:container.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.container:frameChangeCallback([fn | nil]) -> containerObject | fn | nil
/// Method
/// Get or set the frame change callback for the container.
///
/// Parameters:
///  * `fn` - a function, or an explicit nil to remove, specifying the callback to invoke when the frame changes for the container or one of its subviews. A frame change can be a change in location or a change in size or both.
///
/// Returns:
///  * If an argument is provided, the container object; otherwise the current value.
///
/// Notes:
///  * The frame change callback should expect 2 arguments and return none.
///  * The arguments are as follows:
///    * the container object userdata
///    * the userdata object of the element whose frame has changed -- this may be equal to the container object itself, if it is the containers frame that changed.
///
///  * Frame change callbacks are not passed to the parent passthrough callback; they must be handled by the container in which the change occurs.
static int container_frameChangeCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerView *container = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        container.frameChangeCallback = [skin luaUnref:refTable ref:container.frameChangeCallback] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            container.frameChangeCallback = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (container.frameChangeCallback != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:container.frameChangeCallback] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.container:draggingCallback(fn | nil) -> containerObject | fn | nil
/// Method
/// Get or set the callback for accepting dragging and dropping items onto the container.
///
/// Parameters:
///  * `fn` - a function, or an explicit nil to remove, specifying the callback to invoke when an item is dragged onto the container.  An explicit nil, the default, disables drag-and-drop for this element.
///
/// Returns:
///  * If an argument is provided, the container object; otherwise the current value.
///
/// Notes:
///  * The callback function should expect 3 arguments and optionally return 1: the container object itself, a message specifying the type of dragging event, and a table containing details about the item(s) being dragged.  The key-value pairs of the details table will be the following:
///    * `pasteboard` - the name of the pasteboard that contains the items being dragged
///    * `sequence`   - an integer that uniquely identifies the dragging session.
///    * `mouse`      - a point table containing the location of the mouse pointer within the container corresponding to when the callback occurred.
///    * `operation`  - a table containing string descriptions of the type of dragging the source application supports. Potentially useful for determining if your callback function should accept the dragged item or not.
///
/// * The possible messages the callback function may receive are as follows:
///    * "enter"   - the user has dragged an item into the container.  When your callback receives this message, you can optionally return false to indicate that you do not wish to accept the item being dragged.
///    * "exit"    - the user has moved the item out of the container; if the previous "enter" callback returned false, this message will also occur when the user finally releases the items being dragged.
///    * "receive" - indicates that the user has released the dragged object while it is still within the element frame.  When your callback receives this message, you can optionally return false to indicate to the sending application that you do not want to accept the dragged item -- this may affect the animations provided by the sending application.
///
///  * You can use the sequence number in the details table to match up an "enter" with an "exit" or "receive" message.
///
///  * You should capture the details you require from the drag-and-drop operation during the callback for "receive" by using the pasteboard field of the details table and the `hs.pasteboard` module.  Because of the nature of "promised items", it is not guaranteed that the items will still be on the pasteboard after your callback completes handling this message.
///
///  * A container object can only accept drag-and-drop items when the `hs._asm.uitk.window` the container ultimately belongs to is at a level of `hs._asm.uitk.window.levels.dragging` or lower. Note that the container receiving the drag-and-drop item does not have to be the container of the `hs._asm.uitk.window` -- it can be an element of another container acting as the window container.
///  * a container object can only accept drag-and-drop items if it's `hs._asm.uitk.window` object accepts mouse events, i.e. `hs._asm.uitk.window:ignoresMouseEvents` is set to false.
///
///  * Dragging callbacks are not passed to the parent passthrough callback; they must be handled by the container which is the dragging target.
static int container_draggingCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerView *container = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        // We're either removing callback(s), or setting new one(s). Either way, remove existing.
        container.draggingCallbackRef = [skin luaUnref:refTable ref:container.draggingCallbackRef];
        [container unregisterDraggedTypes] ;
        if ([skin luaTypeAtIndex:2] != LUA_TNIL) {
            lua_pushvalue(L, 2);
            container.draggingCallbackRef = [skin luaRef:refTable] ;
            [container registerForDraggedTypes:@[ (__bridge NSString *)kUTTypeItem ]] ;
        }
        lua_pushvalue(L, 1);
    } else {
        if (container.draggingCallbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:container.draggingCallbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }

    return 1;
}

/// hs._asm.uitk.element.container:mouseCallback([fn | true | nil]) -> containerObject | fn | boolean
/// Method
/// Get or set the mouse tracking callback for the container.
///
/// Parameters:
///  * `fn` - a function, or an explicit nil to remove, specifying the callback to invoke when the mouse enters, exits, or moves within the container. Specify an explicit true if you wish for mouse tracking information to be passed to the parent object passthrough callback, if defined, instead.
///
/// Returns:
///  * If an argument is provided, the container object; otherwise the current value.
///
/// Notes:
///  * The mouse tracking callback should expect 3 arguments and return none.
///  * The arguments are as follows:
///    * the container object userdata
///    * a string specifying the type of the callback. Possible values are "enter", "exit", or "move"
///    * a point-table containing the coordinates within the container of the mouse event. A point table is a table with `x` and `y` keys specifying the mouse coordinates.
///
///  * By default, only mouse enter and mouse exit events will invoke the callback to reduce overhead; if you need to track mouse movement within the container as well, see [hs._asm.uitk.element.container:trackMouseMove](#trackMouseMove).
///
///  * Mouse tracking callbacks are not passed to the parent passthrough callback; they must be handled by the container for which the tracking is to occur.
static int container_mouseCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerView *container = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        container.mouseCallback    = [skin luaUnref:refTable ref:container.mouseCallback] ;
        container.trackMouseEvents = NO ;
        if (lua_type(L, 2) == LUA_TBOOLEAN) {
            container.trackMouseEvents = (BOOL)(lua_toboolean(L, 2)) ;
        } else if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            container.mouseCallback    = [skin luaRef:refTable] ;
            container.trackMouseEvents = YES ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (container.mouseCallback != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:container.mouseCallback] ;
        } else {
            lua_pushboolean(L, container.trackMouseEvents) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.container:trackMouseMove([state]) -> containerObject | boolean
/// Method
/// Get or set whether mouse tracking callbacks should include movement within the container's visible area.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether mouse movement within the container also triggers a callback.
///
/// Returns:
///  * If an argument is provided, the container object; otherwise the current value.
///
/// Notes:
///  * [hs._asm.uitk.element.container:mouseCallback](#mouseCallback) must bet set to a callback function or true for this attribute to have any effect.
static int container_trackMouseMove(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerView *container = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, container.trackMouseMove) ;
    } else {
        container.trackMouseMove = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.container:element(id) -> elementUserdata | nil
/// Method
/// Returns the element userdata for the element specified.
///
/// Parameters:
///  * `id` - a string or integer specifying which element to return.  If `id` is an integer, returns the element at the specified index position; if `id` is a string, returns the element with the specified identifier string.
///
/// Returns:
///  * the element userdata, or nil if no element exists in the container at the specified index position or with the specified identifier.
///
/// Notes:
///  * See [hs._asm.uitk.element.container:elementFrame](#elementFrame) for more information on setting an element's identifier string.
static int container_element(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKElementContainerView *container = [skin toNSObjectAtIndex:1] ;
    if (lua_type(L, 2) == LUA_TSTRING) {
        NSString *identifier = [skin toNSObjectAtIndex:2] ;
        BOOL found = NO ;
        for (NSView *view in container.subviewDetails) {
            NSMutableDictionary *details = [container.subviewDetails objectForKey:view] ;
            NSString *elementID = details[@"id"] ;
            if ([elementID isEqualToString:identifier]) {
                [skin pushNSObject:view] ;
                found = YES ;
                break ;
            }
        }
        if (!found) lua_pushnil(L) ;
    } else {
        NSInteger idx = lua_tointeger(L, 2) - 1 ;
        if ((idx < 0) || (idx >= (NSInteger)container.subviews.count)) {
            lua_pushnil(L) ;
        } else {
            [skin pushNSObject:container.subviews[(NSUInteger)idx]] ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.container:sizeToFit([hPad], [vPad]) -> containerObject
/// Method
/// Adjusts the size of the container so that it is the minimum size necessary to contain all of its elements.
///
/// Parameters:
///  * `hPad` - an optional number specifying the horizontal padding to include between the elements and the left and right of the container's new borders. Defaults to 0.0.
///  * `vPad` - an optional number specifying the vertical padding to include between the elements and the top and bottom of the container's new borders.  Defaults to the value of `hPad`.
///
/// Returns:
///  * the container object
///
/// Notes:
///  * If the container is the member of another container, this container's size (but not top-left corner) is adjusted within its parent.
///  * If the container is assigned to a `hs._asm.uitk.window`, the window's size (but not top-left corner) will be adjusted to the calculated size.
static int container_sizeToFit(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerView *container = [skin toNSObjectAtIndex:1] ;

    CGFloat hPadding = (lua_gettop(L) > 1) ? lua_tonumber(L, 2) : 0.0 ;
    CGFloat vPadding = (lua_gettop(L) > 2) ? lua_tonumber(L, 3) : ((lua_gettop(L) > 1) ? hPadding : 0.0) ;

    if (container.subviews.count > 0) {
        __block NSPoint topLeft     = container.subviews.firstObject.frame.origin ;
        __block NSPoint bottomRight = NSZeroPoint ;
        [container.subviews enumerateObjectsUsingBlock:^(NSView *view, __unused NSUInteger idx, __unused BOOL *stop) {
            NSRect frame = view.frame ;
            if (frame.origin.x < topLeft.x) topLeft.x = frame.origin.x ;
            if (frame.origin.y < topLeft.y) topLeft.y = frame.origin.y ;
            NSPoint frameBottomRight = NSMakePoint(frame.origin.x + frame.size.width, frame.origin.y + frame.size.height) ;
            if (frameBottomRight.x > bottomRight.x) bottomRight.x = frameBottomRight.x ;
            if (frameBottomRight.y > bottomRight.y) bottomRight.y = frameBottomRight.y ;
        }] ;
        [container.subviews enumerateObjectsUsingBlock:^(NSView *view, __unused NSUInteger idx, __unused BOOL *stop) {
            NSRect frame = view.frame ;
            frame.origin.x = frame.origin.x + hPadding - topLeft.x ;
            frame.origin.y = frame.origin.y + vPadding - topLeft.y ;
            adjustElementDetailsTable(L, container, view, @{ @"x" : @(frame.origin.x), @"y" : @(frame.origin.y) }) ;
        }] ;

        NSSize oldContentSize = container.frame.size ;
        NSSize newContentSize = NSMakeSize(2 * hPadding + bottomRight.x - topLeft.x, 2 * vPadding + bottomRight.y - topLeft.y) ;

        if (container.window && [container isEqualTo:container.window.contentView]) {
            NSRect oldFrame = container.window.frame ;
            NSSize newSize  = NSMakeSize(
                newContentSize.width  + (oldFrame.size.width - oldContentSize.width),
                newContentSize.height + (oldFrame.size.height - oldContentSize.height)
            ) ;
            NSRect newFrame = NSMakeRect
                (oldFrame.origin.x,
                oldFrame.origin.y + oldFrame.size.height - newSize.height,
                newSize.width,
                newSize.height
            ) ;
            [container.window setFrame:newFrame display:YES animate:NO] ;
        } else {
            [container setFrameSize:newContentSize] ;
        }
    }
    container.needsDisplay = YES ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.element.container:elements() -> table
/// Method
/// Returns an array containing the elements in index order currently managed by this container.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the elements in index order currently managed by this container
static int container_elements(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerView *container = [skin toNSObjectAtIndex:1] ;
    LS_NSConversionOptions options = (lua_gettop(L) == 1) ? LS_TNONE : (lua_toboolean(L, 2) ? LS_NSDescribeUnknownTypes : LS_TNONE) ;
    [skin pushNSObject:container.subviews withOptions:options] ;
    return 1 ;
}

// /// hs._asm.uitk.element.container:elementAutoPosition(element) -> containerObject
// /// Method
// /// Recalculate the position of the specified element in the container and update it if necessary.
// ///
// /// Parameters:
// ///  * `element` - the element userdata to recalculate the size and position for.
// ///
// /// Returns:
// ///  * the container object
// ///
// /// Notes:
// ///  * This method recalculates the position of the element if it is defined in `framedDetails` as a percentage or by the elements center and it's size if the element size is specified as a percentage or inherits its size from the element's fitting size (see [hs._asm.uitk.element.container:elementFittingSize](#elementFittingSize).
// ///
// ///  * See also [hs._asm.uitk.element.container:autoPosition](#autoPosition).
// static int container_elementAutoPosition(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK] ;
//     HSUITKElementContainerView *container = [skin toNSObjectAtIndex:1] ;
//     NSView *item = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
//
//     if (!item || !oneOfOurs(item)) {
//         return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
//     }
//     if (![container.subviews containsObject:item]) {
//         return luaL_argerror(L, 2, "element not managed by this container") ;
//     }
//     [container frameChangedNotification:[NSNotification notificationWithName:NSViewFrameDidChangeNotification object:item]] ;
//     lua_pushvalue(L, 1) ;
//     return 1 ;
// }

/// hs._asm.uitk.element.container:elementFittingSize(element) -> size-table
/// Method
/// Returns a table with `h` and `w` keys specifying the element's fitting size as defined by macOS and the element's current properties.
///
/// Parameters:
///  * `element` - the element userdata to get the fitting size for.
///
/// Returns:
///  * a table with `h` and `w` keys specifying the elements fitting size
///
/// Notes:
///  * The dimensions provided can be used to determine a minimum size for the element to display fully based on its current properties and may change as these change.
///  * Not all elements provide one or both of these fields; in such a case, the value for the missing or unspecified field will be 0.
///  * If you do not specify an elements height or width with [hs._asm.uitk.element.container:elementFrame](#elementFrame), the value returned by this method will be used instead; in cases where a specific dimension is not defined by this method, you should make sure to specify it or the element may not be visible.
static int container_elementFittingSize(lua_State *L) {
// This is a method so it can be inherited by elements, but it doesn't really have to be
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK] ;
//     HSUITKElementContainerView *container = [skin toNSObjectAtIndex:1] ;
    NSView *item = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;

    if (!item || !oneOfOurs(item)) {
        return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
    }
    [skin pushNSSize:item.fittingSize] ;
    return 1 ;
}

/// hs._asm.uitk.element.container:elementFrame(element, [details]) -> containerObject | table
/// Method
/// Get or set the frame details in the container for the specified element.
///
/// Parameters:
///  * `element` - the element to get or set the frame details for
///  * `details` - an optional table specifying the details to change or set for this element. The valid key-value pairs for the table are as follows:
///    * `x`  - The horizontal position of the elements left side. Only one of `x`, `rX`, or`cX` can be set; setting one will clear the others.
///    * `rX`  - The horizontal position of the elements right side. Only one of `x`, `rX`, or`cX` can be set; setting one will clear the others.
///    * `cX` - The horizontal position of the elements center point. Only one of `x`, `rX`, or`cX` can be set; setting one will clear the others.
///    * `y`  - The vertical position of the elements top. Only one of `y`, `bY`, or `cY` can be set; setting one will clear the others.
///    * `bY`  - The vertical position of the elements bottom. Only one of `y`, `bY`, or `cY` can be set; setting one will clear the others.
///    * `cY` - The vertical position of the elements center point. Only one of `y`, `bY`, or `cY` can be set; setting one will clear the others.
///    * `h`  - The element's height. If this is set, it will be used instead of the default height as returned by [hs._asm.uitk.element.container:elementFittingSize](#elementFittingSize). If the default height is 0, then this *must* be set or the element will be effectively invisible. Set to false to clear a defined height and return the the default behavior.
///    * `w`  - The element's width. If this is set, it will be used instead of the default width as returned by [hs._asm.uitk.element.container:elementFittingSize](#elementFittingSize). If the default width is 0, then this *must* be set or the element will be effectively invisible. Set to false to clear a defined width and return the the default behavior.
///    * `id` - A string specifying an identifier which can be used to reference this element with [hs._asm.uitk.element.container:element](#element) without requiring knowledge of the element's index position. Specify the value as false to clear the identifier and set it to nil.
///
/// Returns:
///  * If an argument is provided, the container object; otherwise the current value.
///
/// Notes:
///  * When setting the frame details, only those fields provided will be adjusted; other fields will remain unaffected (except as noted above).
///  * The values for keys `x`, `rX`, `cX`, `y`, `bY`, `cY`, `h`, and `w` may be specified as numbers or as strings representing percentages of the element's parent width (for `x`, `rX`, `cX`, and `w`) or height (for `y`, `bY`, `cY`, and `h`). Percentages should specified in the string as defined for your locale or in the `en_US` locale (as a fallback) which is either a number followed by a % sign or a decimal number.
///
///  * When returning the current frame details table, an additional key-value pair is included: `_effective` will be a table specifying the elements actual frame-table (a table specifying the elements position as key-value pairs specifying the top-left position with `x` and `y`, and the element size with `h` and `w`).  This is provided for reference only: if this key-value pair is included when setting the frame details with this method, it will be ignored.

// ///    * `honorCanvasMove` - A boolean, default nil (false), indicating whether or not the frame wrapper functions for `hs.canvas` objects should honor location changes when made with `hs.canvas:topLeft` or `hs.canvas:frame`. This is a (hopefully temporary) fix because canvas objects are not aware of the `hs._asm.uitk.window` frameDetails model for element placement.

static int container_elementFrame(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerView *container = [skin toNSObjectAtIndex:1] ;
    NSView *item = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;

    if (!item || !oneOfOurs(item)) {
        return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
    }
    if (![container.subviews containsObject:item]) {
        return luaL_argerror(L, 2, "element not managed by this container") ;
    }

    if (lua_gettop(L) == 2) {
        [skin pushNSObject:[container.subviewDetails objectForKey:item]] ;
        [skin pushNSRect:item.frame] ;
        lua_setfield(L, -2, "_effective") ;
    } else {
        adjustElementDetailsTable(L, container, item, [skin toNSObjectAtIndex:3]) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.container:positionElement(element1, where, element2, [offset], [align]) -> containerObject
/// Method
/// Moves element1 above element2 in the container.
///
/// Parameters:
///  * `element1` - the element userdata to adjust the `x` and `y` coordinates of
///  * `where`    - a string specifying where the element1 is to be moved to in relation to element2. The string must be one of the following:
///    * "above"  - element1 should be moved above element2
///    * "below"  - element1 should be moved below element2
///    * "before" - element1 should be moved to the left of element2
///    * "after"  - element1 should be moved to the right of element2
///  * `element2` - the element userdata to anchor element1 to
///  * `offset`   - a number, default 0.0, specifying the space between element1 and element2 in their new relationship
///  * `align`    - a string, default "center", specifying how element1 should be aligned along the shared edge with element2. The string must be one of the following:
///    * "start"  - element1 will be aligned at the beginning of the shared edge.
///    * "center" - element1 will be centered along the shared edge.
///    * "end"    - element1 will be aligned at the end of the shared edge.
///
/// Returns:
///  * the container object
///
/// Notes:
///  * This method will set the `x` and `y` fields of `frameDetails` for the element.  See [hs._asm.uitk.element.container:elementFrame](#elementFrame) for the effect of this on other frame details.
///
///  * this method moves element1 in relation to element2's current position -- moving element2 at a later point will not cause element1 to follow
///  * this method will not adjust the postion of any other element which may already be at the new position for element1
static int container_moveElement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TANY,
                    LS_TSTRING,
                    LS_TANY,
                    LS_TNUMBER | LS_TSTRING | LS_TOPTIONAL,
                    LS_TSTRING | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementContainerView *container = [skin toNSObjectAtIndex:1] ;
    NSView             *element1 = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
    NSView             *element2 = (lua_type(L, 4) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:4] : nil ;
    NSString           *where    = [skin toNSObjectAtIndex:3] ;
    CGFloat            padding   = ((lua_gettop(L) > 4) && (lua_type(L, 5) == LUA_TNUMBER)) ? lua_tonumber(L, 5) : 0.0 ;
    NSString           *align    = (lua_type(L, -1) == LUA_TSTRING) ? [skin toNSObjectAtIndex:-1] : @"center" ;

    if (!element1 || !oneOfOurs(element1)) {
        return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
    }
    if (![container.subviews containsObject:element1]) {
        return luaL_argerror(L, 2, "element not managed by this container element") ;
    }

    if (!element2 || !oneOfOurs(element2)) {
        return luaL_argerror(L, 4, "expected userdata representing a uitk element") ;
    }
    if (![container.subviews containsObject:element2]) {
        return luaL_argerror(L, 4, "element not managed by this container element") ;
    }

    NSRect elementFrame = element1.frame ;
    NSRect anchorFrame  = element2.frame ;

    int alignment = 0 ;
    if ([align isEqualToString:@"start"]) {
        alignment = -1 ;
    } else if ([align isEqualToString:@"center"]) {
        alignment = 0 ;
    } else if ([align isEqualToString:@"end"]) {
        alignment = 1 ;
    } else {
        return luaL_argerror(L, lua_gettop(L), "expected start, center, or end") ;
    }

    if ([where isEqualToString:@"above"] || [where isEqualToString:@"below"]) {
        if ([where isEqualToString:@"above"]) {
            elementFrame.origin.y = anchorFrame.origin.y - (elementFrame.size.height + padding) ;
        } else {
            elementFrame.origin.y = anchorFrame.origin.y + (anchorFrame.size.height + padding) ;
        }
        switch(alignment) {
            case -1:
                elementFrame.origin.x = anchorFrame.origin.x ;
                break ;
            case  0:
                elementFrame.origin.x = anchorFrame.origin.x + (anchorFrame.size.width - elementFrame.size.width) / 2 ;
                break ;
            case  1:
                elementFrame.origin.x = anchorFrame.origin.x + anchorFrame.size.width - elementFrame.size.width ;
                break ;
        }
    } else if ([where isEqualToString:@"before"] || [where isEqualToString:@"after"]) {
        if ([where isEqualToString:@"before"]) {
            elementFrame.origin.x = anchorFrame.origin.x - (elementFrame.size.width + padding) ;
        } else {
            elementFrame.origin.x = anchorFrame.origin.x + (anchorFrame.size.width + padding) ;
        }
        switch(alignment) {
            case -1:
                elementFrame.origin.y = anchorFrame.origin.y ;
                break ;
            case  0:
                elementFrame.origin.y = anchorFrame.origin.y + (anchorFrame.size.height - elementFrame.size.height) / 2 ;
                break ;
            case  1:
                elementFrame.origin.y = anchorFrame.origin.y + anchorFrame.size.height - elementFrame.size.height ;
                break ;
        }
    } else {
        return luaL_argerror(L, 3, "expected above, below, before, or after") ;
    }

    adjustElementDetailsTable(L, container, element1, @{
        @"x" : @(elementFrame.origin.x),
        @"y" : @(elementFrame.origin.y)
    }) ;

    container.needsDisplay = YES ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementContainerView(lua_State *L, id obj) {
    HSUITKElementContainerView *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementContainerView *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementContainerView(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementContainerView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementContainerView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_len(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementContainerView *obj = [skin luaObjectAtIndex:1 toClass:"HSUITKElementContainerView"] ;
    if (obj.subviews) {
        lua_pushinteger(L, (lua_Integer)obj.subviews.count) ;
    } else {
        lua_pushinteger(L, 0) ;
    }
    return 1 ;
}

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementContainerView *obj = [skin luaObjectAtIndex:1 toClass:"HSUITKElementContainerView"] ;
    NSString *title = NSStringFromRect(obj.frame) ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSUITKElementContainerView *obj = get_objectFromUserdata(__bridge_transfer HSUITKElementContainerView, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.mouseCallback       = [skin luaUnref:refTable ref:obj.mouseCallback] ;
            obj.callbackRef         = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj.frameChangeCallback = [skin luaUnref:refTable ref:obj.frameChangeCallback] ;
            [obj.subviews enumerateObjectsUsingBlock:^(NSView *subview, __unused NSUInteger idx, __unused BOOL *stop) {
                [skin luaRelease:refTable forNSObject:subview] ;
            }] ;
            [obj.subviewDetails removeAllObjects] ;
            obj.subviewDetails = nil ;
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
    {"insert",              container_insertElement},
    {"remove",              container_removeElement},
    {"elements",            container_elements},
    {"element",             container_element},
    {"passthroughCallback", container_passthroughCallback},
    {"frameChangeCallback", container_frameChangeCallback},
    {"mouseCallback",       container_mouseCallback},
    {"draggingCallback",    container_draggingCallback},
    {"trackMouseMove",      container_trackMouseMove},
    {"sizeToFit",           container_sizeToFit},
    {"elementFittingSize",  container_elementFittingSize},
    {"elementFrame",        container_elementFrame},
    {"positionElement",     container_moveElement},

// FIXME: are these really needed?
//     {"elementAutoPosition", container_elementAutoPosition},
//     {"autoPosition",        container_autoPosition},

    {"_debugFrames",        container__debugFrames},

// other metamethods inherited from _view
    {"__len",               userdata_len},
    {"__tostring",          userdata_tostring},
    {"__gc",                userdata_gc},
    {NULL,    NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",            container_new},
    {NULL,             NULL}
};

int luaopen_hs__asm_uitk_element_libcontainer(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSUITKElementContainerView  forClass:"HSUITKElementContainerView"];
    [skin registerLuaObjectHelper:toHSUITKElementContainerView forClass:"HSUITKElementContainerView"
                                                    withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"elements",
        @"passthroughCallback",
        @"mouseCallback",
        @"draggingCallback",
        @"frameChangeCallback",
        @"trackMouseMove",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
//     lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}
