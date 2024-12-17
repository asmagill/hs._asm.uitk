@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.container.split" ;

static LSRefTable         refTable      = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *DIVIDER_STYLE ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    DIVIDER_STYLE = @{
        @"thick" : @(NSSplitViewDividerStyleThick),
        @"thin"  : @(NSSplitViewDividerStyleThin),
        @"pane"  : @(NSSplitViewDividerStylePaneSplitter),
    } ;
}

static BOOL oneOfOurElementObjects(NSView *obj) {
    return [obj isKindOfClass:[NSView class]]  &&
           [obj respondsToSelector:NSSelectorFromString(@"selfRefCount")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setSelfRefCount:")] &&
           [obj respondsToSelector:NSSelectorFromString(@"refTable")] &&
           [obj respondsToSelector:NSSelectorFromString(@"callbackRef")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setCallbackRef:")] ;
}

@interface HSUITKElementContainerSplitView : NSSplitView <NSSplitViewDelegate>
@property            int               selfRefCount ;
@property (readonly) LSRefTable        refTable ;
@property            int               callbackRef ;
@property            int               passThroughRef ;

- (NSColor *)dividerColor ;
- (void)setDividerColor:(NSColor *)color ;

- (CGFloat)dividerThickness ;
- (void)setDividerThickness:(CGFloat)thickness  ;

@end

@implementation HSUITKElementContainerSplitView {
    NSColor *_colorOfDivider ;
    CGFloat _thickness ;
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
        _callbackRef    = LUA_NOREF ;
        _passThroughRef = LUA_NOREF ;
        _refTable       = refTable ;
        _selfRefCount   = 0 ;

        _colorOfDivider = nil ;
        _thickness      = -1 ;

        self.delegate            = self ;
        self.arrangesAllSubviews = YES ;
    }
    return self ;
}

// - (NSSize)fittingSize {
//     return self.minimumSize ;
// }

- (NSColor *)dividerColor {
    if (_colorOfDivider) {
        return _colorOfDivider ;
    } else {
        return [super dividerColor] ;
    }
}

- (void)setDividerColor:(NSColor *)color {
    _colorOfDivider = color ;
}

- (CGFloat)dividerThickness {
    if (_thickness < 0) {
        return [super dividerThickness] ;
    } else {
        return _thickness ;
    }
}

- (void)setDividerThickness:(CGFloat)thickness {
    _thickness = thickness ;
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

- (void)performCallback:(__unused id)sender {
    [self callbackHamster:@[ self ]] ;
}

// NOTE: Passthrough Callback Support

// perform callback for subviews which don't have a callback defined
- (void)performPassthroughCallback:(NSArray *)arguments {
    if (_passThroughRef != LUA_NOREF) {
        LuaSkin *skin    = [LuaSkin sharedWithState:NULL] ;
        int     argCount = 1 ;

        [skin pushLuaRef:refTable ref:_passThroughRef] ;
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
        NSResponder *nextInChain = [self nextResponder] ;

        SEL passthroughCallback = NSSelectorFromString(@"performPassthroughCallback:") ;
        while(nextInChain) {
            if ([nextInChain respondsToSelector:passthroughCallback]) {
                [nextInChain performSelectorOnMainThread:passthroughCallback
                                              withObject:@[ self, arguments ]
                                           waitUntilDone:YES] ;
                break ;
            } else {
                nextInChain = nextInChain.nextResponder ;
            }
        }
    }
}

#pragma mark - NSSplitViewDelegate -

// - (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview;
// - (BOOL)splitView:(NSSplitView *)splitView shouldHideDividerAtIndex:(NSInteger)dividerIndex;
// - (BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)view;

// - (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex;
// - (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex;

// // - (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex;

// // - (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize;
// // - (void)splitViewDidResizeSubviews:(NSNotification *)notification;
// // - (void)splitViewWillResizeSubviews:(NSNotification *)notification;

// // - (NSRect)splitView:(NSSplitView *)splitView additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex;
// // - (NSRect)splitView:(NSSplitView *)splitView effectiveRect:(NSRect)proposedEffectiveRect forDrawnRect:(NSRect)drawnRect ofDividerAtIndex:(NSInteger)dividerIndex;

@end

#pragma mark - Module Functions -

static int split_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementContainerSplitView *element = [[HSUITKElementContainerSplitView alloc] initWithFrame:frameRect];
    if (element) {
        if (lua_gettop(L) != 1) [element setFrameSize:[element fittingSize]] ;
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

static int split_passthroughCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerSplitView *splitView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        splitView.passThroughRef = [skin luaUnref:refTable ref:splitView.passThroughRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            splitView.passThroughRef = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (splitView.passThroughRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:splitView.passThroughRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int split_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerSplitView *splitView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        splitView.callbackRef = [skin luaUnref:refTable ref:splitView.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            splitView.callbackRef = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (splitView.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:splitView.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

// // simplify and just make this YES, otherwise use a different container
// static int split_arrangesAllSubviews(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
//     HSUITKElementContainerSplitView *splitView = [skin toNSObjectAtIndex:1] ;
//
//     if (lua_gettop(L) == 1) {
//         lua_pushboolean(L, splitView.arrangesAllSubviews) ;
//     } else {
//         BOOL value = (BOOL)(lua_toboolean(L, 2)) ;
//         splitView.arrangesAllSubviews = value ;
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }

static int split_vertical(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerSplitView *splitView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, splitView.vertical) ;
    } else {
        BOOL value = (BOOL)(lua_toboolean(L, 2)) ;
        splitView.vertical = value ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int split_autosaveName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerSplitView *splitView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:splitView.autosaveName] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            splitView.autosaveName = nil ;
        } else {
            NSString *value = [skin toNSObjectAtIndex:2] ;
            splitView.autosaveName = value ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int split_dividerColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerSplitView *splitView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:splitView.dividerColor] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            splitView.dividerColor = nil ;
        } else {
            NSColor *value = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
            splitView.dividerColor = value ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int split_dividerThickness(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerSplitView *splitView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, splitView.dividerThickness) ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            splitView.dividerThickness = -1 ;
        } else {
            CGFloat value = lua_tonumber(L, 2) ;
            splitView.dividerThickness = value ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int split_dividerStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerSplitView *splitView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [DIVIDER_STYLE allKeysForObject:@(splitView.dividerStyle)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", splitView.dividerStyle] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = DIVIDER_STYLE[key] ;
        if (value) {
            splitView.dividerStyle = value.longLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [DIVIDER_STYLE.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int split_arrangedSubviews(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementContainerSplitView *splitView = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:splitView.arrangedSubviews withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

static int split_adjustSubviews(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementContainerSplitView *splitView = [skin toNSObjectAtIndex:1] ;

    [splitView adjustSubviews] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int split_isSubviewCollapsed(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK] ;
    HSUITKElementContainerSplitView *splitView = [skin toNSObjectAtIndex:1] ;
    NSView *view = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
    if (!view || !oneOfOurElementObjects(view)) {
        return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
    }

    if (![splitView.subviews containsObject:view]) {
        return luaL_argerror(L, 2, "element is not one of our subviews") ;
    }

    lua_pushboolean(L, [splitView isSubviewCollapsed:view]) ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int split_maxPossiblePositionOfDividerAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK] ;
    HSUITKElementContainerSplitView *splitView = [skin toNSObjectAtIndex:1] ;

    NSInteger idx = NSNotFound ;

    if (lua_type(L, 2) == LUA_TNUMBER && lua_isinteger(L, 2)) {
        idx = lua_tointeger(L, 2) - 1 ;
    } else {
        NSView *view = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
        if (!view || !oneOfOurElementObjects(view)) {
            return luaL_argerror(L, 2, "expected userdata representing a uitk element or integer index position") ;
        }

        idx = (NSInteger)[splitView.arrangedSubviews indexOfObject:view] ;
    }

    if (idx < 0 && idx >= (NSInteger)splitView.arrangedSubviews.count) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }

    lua_pushnumber(L, [splitView maxPossiblePositionOfDividerAtIndex:idx]) ;
    return 1 ;
}

static int split_minPossiblePositionOfDividerAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK] ;
    HSUITKElementContainerSplitView *splitView = [skin toNSObjectAtIndex:1] ;

    NSInteger idx = NSNotFound ;

    if (lua_type(L, 2) == LUA_TNUMBER && lua_isinteger(L, 2)) {
        idx = lua_tointeger(L, 2) - 1 ;
    } else {
        NSView *view = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
        if (!view || !oneOfOurElementObjects(view)) {
            return luaL_argerror(L, 2, "expected userdata representing a uitk element or integer index position") ;
        }

        idx = (NSInteger)[splitView.arrangedSubviews indexOfObject:view] ;
    }

    if (idx < 0 && idx >= (NSInteger)splitView.arrangedSubviews.count) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }

    lua_pushnumber(L, [splitView minPossiblePositionOfDividerAtIndex:idx]) ;
    return 1 ;
}

static int split_setPosition_ofDividerAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKElementContainerSplitView *splitView = [skin toNSObjectAtIndex:1] ;

    NSInteger idx = NSNotFound ;

    if (lua_type(L, 2) == LUA_TNUMBER && lua_isinteger(L, 2)) {
        idx = lua_tointeger(L, 2) - 1 ;
    } else {
        NSView *view = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
        if (!view || !oneOfOurElementObjects(view)) {
            return luaL_argerror(L, 2, "expected userdata representing a uitk element or integer index position") ;
        }

        idx = (NSInteger)[splitView.arrangedSubviews indexOfObject:view] ;
    }

    if (idx < 0 && idx >= (NSInteger)splitView.arrangedSubviews.count) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }

    CGFloat position = lua_tointeger(L, 3) ;

    [splitView setPosition:position ofDividerAtIndex:idx] ;
    lua_pushboolean(L, 1) ;
    return 1 ;
}

static int split_insertElement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerSplitView *splitView = [skin toNSObjectAtIndex:1] ;
    NSView *item = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;

    if (!item || !oneOfOurElementObjects(item)) {
        return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
    }
    if ([item isDescendantOf:splitView]) {
        return luaL_argerror(L, 2, "element already managed by this split or one of its elements") ;
    }

    NSInteger idx = (lua_type(L, 3) == LUA_TNUMBER) ? (lua_tointeger(L, 3) - 1) : (NSInteger)splitView.arrangedSubviews.count ;
    if ((idx < 0) || (idx > (NSInteger)splitView.arrangedSubviews.count)) return luaL_argerror(L, 3, "index out of bounds") ;

    [splitView insertArrangedSubview:item atIndex:idx] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int split_removeElement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerSplitView *splitView = [skin toNSObjectAtIndex:1] ;
    NSView *item = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;

    if (!item && lua_isinteger(L, 2)) {
        NSInteger idx = ((lua_type(L, 2) == LUA_TNUMBER) ? lua_tointeger(L, 2) : (NSInteger)splitView.arrangedSubviews.count) - 1 ;
        if ((idx < 0) || (idx >= (NSInteger)splitView.arrangedSubviews.count)) return luaL_argerror(L, 2, "index out of bounds") ;
        item = splitView.arrangedSubviews[(NSUInteger)idx] ;
    } else {
        return luaL_argerror(L, 2, "userdata representing a uitk element or integer index" ) ;
    }

    [splitView removeArrangedSubview:item] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int split_holdingPriority(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerSplitView *splitView = [skin toNSObjectAtIndex:1] ;
    NSInteger idx = NSNotFound ;

    if (lua_type(L, 2) == LUA_TNUMBER && lua_isinteger(L, 2)) {
        idx = lua_tointeger(L, 2) - 1 ;
    } else {
        NSView *view = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
        if (!view || !oneOfOurElementObjects(view)) {
            return luaL_argerror(L, 2, "expected userdata representing a uitk element or integer index position") ;
        }

        idx = (NSInteger)[splitView.arrangedSubviews indexOfObject:view] ;
    }

    if (idx < 0 && idx >= (NSInteger)splitView.arrangedSubviews.count) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }

    if (lua_gettop(L) == 2) {
        lua_pushnumber(L, (lua_Number)[splitView holdingPriorityForSubviewAtIndex:idx]) ;
    } else {
        NSLayoutPriority priority = (NSLayoutPriority)(lua_tonumber(L, 3)) ;

        if (priority > NSLayoutPriorityRequired) priority = NSLayoutPriorityRequired ;
        if (priority < 0)                        priority = 0 ;

        [splitView setHoldingPriority:priority forSubviewAtIndex:idx] ;
        lua_pushboolean(L, 1) ;
    }
    return 1 ;
}

// // - (void)drawDividerInRect:(NSRect)rect;

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementContainerSplitView(lua_State *L, id obj) {
    HSUITKElementContainerSplitView *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementContainerSplitView *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementContainerSplitView(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementContainerSplitView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementContainerSplitView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     HSUITKElementContainerSplitView *obj = [skin luaObjectAtIndex:1 toClass:"HSUITKElementContainerSplitView"] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        NSObject *obj1 = [skin toNSObjectAtIndex:1] ;
        NSObject *obj2 = [skin toNSObjectAtIndex:2] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSUITKElementContainerSplitView *obj = get_objectFromUserdata(__bridge_transfer HSUITKElementContainerSplitView, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef    = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj.passThroughRef = [skin luaUnref:refTable ref:obj.passThroughRef] ;

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
  static const luaL_Reg userdata_metaLib[] = {
    {"passthroughCallback", split_passthroughCallback},
    {"callback",            split_callback},
    {"vertical",            split_vertical},
    {"autosaveName",        split_autosaveName},
    {"dividerColor",        split_dividerColor},
    {"dividerThickness",    split_dividerThickness},
    {"dividerStyle",        split_dividerStyle},

    {"arrangedSubviews",    split_arrangedSubviews},
    {"adjustSubviews",      split_adjustSubviews},
    {"isSubviewCollapsed",  split_isSubviewCollapsed},
    {"maxDividerPosition",  split_maxPossiblePositionOfDividerAtIndex},
    {"minDividerPosition",  split_minPossiblePositionOfDividerAtIndex},
    {"setDividerPosition",  split_setPosition_ofDividerAtIndex},
    {"insertElement",       split_insertElement},
    {"removeElement",       split_removeElement},
    {"holdingPriority",     split_holdingPriority},

    {"__tostring",          userdata_tostring},
    {"__eq",                userdata_eq},
    {"__gc",                userdata_gc},
    {NULL,                  NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",     split_new},
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libcontainer_split(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKElementContainerSplitView  forClass:"HSUITKElementContainerSplitView"];
    [skin registerLuaObjectHelper:toHSUITKElementContainerSplitView forClass:"HSUITKElementContainerSplitView"
                                                         withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"passthroughCallback",
        @"callback",
        @"vertical",
        @"autosaveName",
        @"dividerColor",
        @"dividerThickness",
        @"dividerStyle",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    // lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}

