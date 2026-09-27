@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.container.stack" ;

static LSRefTable         refTable      = LUA_NOREF ;

static NSDictionary       *STACK_VIEW_DISTRIBUTION ;
static NSDictionary       *HORIZONTAL_ALIGNMENTS ;
static NSDictionary       *VERTICAL_ALIGNMENTS ;
static NSDictionary       *UI_LAYOUT_ORIENTATION ;
static NSDictionary       *STACK_VIEW_GRAVITY ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    STACK_VIEW_DISTRIBUTION = @{
        @"equalCentering"     : @(NSStackViewDistributionEqualCentering),
        @"equalSpacing"       : @(NSStackViewDistributionEqualSpacing),
        @"fill"               : @(NSStackViewDistributionFill),
        @"fillEqually"        : @(NSStackViewDistributionFillEqually),
        @"fillProportionally" : @(NSStackViewDistributionFillProportionally),
        @"gravityAreas"       : @(NSStackViewDistributionGravityAreas),
    } ;

    HORIZONTAL_ALIGNMENTS = @{
        @"bottom"         : @(NSLayoutAttributeBottom),
        @"center"         : @(NSLayoutAttributeCenterY),
        @"lastBaseline"   : @(NSLayoutAttributeLastBaseline),
        @"firstBaseline"  : @(NSLayoutAttributeFirstBaseline),
        @"top"            : @(NSLayoutAttributeTop),
    } ;

    VERTICAL_ALIGNMENTS = @{
        @"leading"        : @(NSLayoutAttributeLeading),
        @"center"         : @(NSLayoutAttributeCenterX),
        @"trailing"       : @(NSLayoutAttributeTrailing),
    } ;

//     LAYOUT_ATTRIBUTE = @{
//         @"left"           : @(NSLayoutAttributeLeft),
//         @"right"          : @(NSLayoutAttributeRight),
//         @"top"            : @(NSLayoutAttributeTop),
//         @"bottom"         : @(NSLayoutAttributeBottom),
//         @"leading"        : @(NSLayoutAttributeLeading),
//         @"trailing"       : @(NSLayoutAttributeTrailing),
//         @"width"          : @(NSLayoutAttributeWidth),
//         @"height"         : @(NSLayoutAttributeHeight),
//         @"centerX"        : @(NSLayoutAttributeCenterX),
//         @"centerY"        : @(NSLayoutAttributeCenterY),
//         @"lastBaseline"   : @(NSLayoutAttributeLastBaseline),
//         @"firstBaseline"  : @(NSLayoutAttributeFirstBaseline),
//         @"notAnAttribute" : @(NSLayoutAttributeNotAnAttribute),
//     } ;

    UI_LAYOUT_ORIENTATION = @{
        @"horizontal" : @(NSUserInterfaceLayoutOrientationHorizontal),
        @"vertical"   : @(NSUserInterfaceLayoutOrientationVertical),
    } ;

    STACK_VIEW_GRAVITY = @{
        @"top"      : @(NSStackViewGravityTop),
        @"leading"  : @(NSStackViewGravityLeading),
        @"center"   : @(NSStackViewGravityCenter),
        @"bottom"   : @(NSStackViewGravityBottom),
        @"trailing" : @(NSStackViewGravityTrailing),
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

@interface HSUITKElementContainerStackView : NSStackView <NSStackViewDelegate>
@property            int               selfRefCount ;
@property (readonly) LSRefTable        refTable ;
@property            int               callbackRef ;
@property            int               passThroughRef ;
@end

@implementation HSUITKElementContainerStackView

- (void)commonInit {
    _callbackRef    = LUA_NOREF ;
    _passThroughRef = LUA_NOREF ;
    _refTable       = refTable ;
    _selfRefCount   = 0 ;

    self.delegate   = self ;
}

+ (instancetype)newStackView {
    HSUITKElementContainerStackView *stack = [HSUITKElementContainerStackView stackViewWithViews:[NSArray array]] ;

    if (stack) [stack commonInit] ;

    return stack ;
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

#pragma mark - NSStackViewDelegate -

- (void) stackView:stackView didReattachViews:views {
    [self callbackHamster:@[ self, @"reattach", views ]] ;
}

- (void) stackView:stackView willDetachViews:views {
    [self callbackHamster:@[ self, @"detach", views ]] ;
}

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.container.stack.new() -> stackObject
/// Constructor
/// Creates a new stack container for `hs._asm.uitk.window`.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the stackObject
static int stack_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    HSUITKElementContainerStackView *element = [HSUITKElementContainerStackView newStackView] ;
    if (element) {
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

static int stack_attachmentCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        stack.callbackRef = [skin luaUnref:refTable ref:stack.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            stack.callbackRef = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (stack.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:stack.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int stack_passthroughCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        stack.passThroughRef = [skin luaUnref:refTable ref:stack.passThroughRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            stack.passThroughRef = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (stack.passThroughRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:stack.passThroughRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int stack_removeView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    NSView *view = nil ;

    if (lua_gettop(L) == 1) {
        view = stack.views.lastObject ;
    } else if (lua_type(L, 2) == LUA_TUSERDATA) {
        view = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
        if (!view || !oneOfOurElementObjects(view)) {
            return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
        }
        if (![stack.views containsObject:view]) return luaL_argerror(L, 2, "element not a member of the stack") ;
    } else if (lua_type(L, 2) == LUA_TNUMBER && lua_isinteger(L, 2)) {
        NSInteger idx = lua_tointeger(L, 2) - 1 ;
        if (idx < 0 || idx >= (NSInteger)stack.views.count) return luaL_argerror(L, 2, "index out of bounds") ;
        view = stack.views[(NSUInteger)idx] ;
    } else {
        return luaL_argerror(L, 2, "expected integer index or uitk element userdata") ;
    }

    [skin luaRelease:refTable forNSObject:view] ;
    [stack removeView:view] ;
    lua_pushvalue(L, 1) ;

    return 1 ;
}

static int stack_insertArrangedSubview(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK | LS_TVARARG] ; //LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    NSView *view = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
    if (!view || !oneOfOurElementObjects(view)) {
        return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
    }
    if ([view isDescendantOf:stack]) {
        return luaL_argerror(L, 2, "element already managed by this stack or one of its elements") ;
    }

    NSString *where = nil ;
    switch(lua_gettop(L)) {
        case 2:
            break ;
        case 3:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                            LS_TANY,
                            LS_TNUMBER | LS_TINTEGER | LS_TSTRING,
                            LS_TBREAK] ;
            if (lua_type(L, -1) == LUA_TSTRING) where = [skin toNSObjectAtIndex:3] ;
            break ;
        default:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                            LS_TANY,
                            LS_TSTRING,
                            LS_TNUMBER | LS_TINTEGER,
                            LS_TBREAK] ;
            where = [skin toNSObjectAtIndex:3] ;
    }

    if (where) {
        NSNumber *value = STACK_VIEW_GRAVITY[where] ;
        if (!value) {
            return luaL_argerror(L, 3, [[NSString stringWithFormat:@"must be one of %@", [STACK_VIEW_GRAVITY.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
        NSStackViewGravity gravity = value.integerValue ;

        NSInteger maxIdx = (NSInteger)[stack viewsInGravity:gravity].count ;
        NSInteger idx    = (lua_type(L, -1) == LUA_TNUMBER) ? (lua_tointeger(L, -1) - 1) : maxIdx ;
        if (idx < 0 || idx > maxIdx) return luaL_argerror(L, lua_gettop(L), "index out of bounds") ;

        [stack insertView:view atIndex:(NSUInteger)idx inGravity:gravity] ;
    } else {
        NSInteger maxIdx = (NSInteger)stack.arrangedSubviews.count ;
        NSInteger idx    = (lua_type(L, -1) == LUA_TNUMBER) ? (lua_tointeger(L, -1) - 1) : maxIdx ;
        if (idx < 0 || idx > maxIdx) return luaL_argerror(L, lua_gettop(L), "index out of bounds") ;

        [stack insertArrangedSubview:view atIndex:idx] ;
    }

    [skin luaRetain:refTable forNSObject:view] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}
// - (void) addArrangedSubview:(NSView *) view;
// - (void) addView:(NSView *) view inGravity:(NSStackViewGravity) gravity;

static int stack_customSpacingAfterView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    NSView *view = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
    if (!view || !oneOfOurElementObjects(view)) {
        return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
    }
    if (![stack.views containsObject:view]) return luaL_argerror(L, 2, "element not a member of the stack") ;

    if (lua_gettop(L) == 2) {
        CGFloat spacing = [stack customSpacingAfterView:view] ;
        lua_pushnumber(L, spacing) ;
    } else {
        CGFloat spacing = lua_tonumber(L, 3) ;
        [stack setCustomSpacing:spacing afterView:view] ;
        lua_pushvalue(L, 1) ;
    }

    return 1 ;
}

static int stack_visibilityPriorityForView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    NSView *view = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
    if (!view || !oneOfOurElementObjects(view)) {
        return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
    }
    if (![stack.views containsObject:view]) return luaL_argerror(L, 2, "element not a member of the stack") ;

    if (lua_gettop(L) == 2) {
        lua_pushnumber(L, (lua_Number)[stack visibilityPriorityForView:view]) ;
    } else {
        float priority = (float)lua_tonumber(L, 3) ;
        if (priority > NSStackViewVisibilityPriorityMustHold) priority = NSStackViewVisibilityPriorityMustHold ;
        if (priority < NSStackViewVisibilityPriorityNotVisible) priority = NSStackViewVisibilityPriorityNotVisible ;

        [stack setVisibilityPriority:priority forView:view] ;
        lua_pushvalue(L, 1) ;
    }

    return 1 ;
}

static int stack_edgeInsets(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    CGFloat t = stack.edgeInsets.top ;
    CGFloat b = stack.edgeInsets.bottom ;
    CGFloat l = stack.edgeInsets.left ;
    CGFloat r = stack.edgeInsets.right ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:@{
            @"t" : @(t),
            @"b" : @(b),
            @"l" : @(l),
            @"r" : @(r),
        }] ;
    } else {
        lua_getfield(L, -1, "t") ;
        if (lua_type(L, -1) == LUA_TNUMBER) {
            t = lua_tonumber(L, -1) ;
        } else if (lua_type(L, -1) != LUA_TNIL) {
            return luaL_argerror(L, 2, "inset for top must be specified as a number") ;
        }
        lua_pop(L, 1) ;

        lua_getfield(L, -1, "b") ;
        if (lua_type(L, -1) == LUA_TNUMBER) {
            b = lua_tonumber(L, -1) ;
        } else if (lua_type(L, -1) != LUA_TNIL) {
            return luaL_argerror(L, 2, "inset for bottom must be specified as a number") ;
        }
        lua_pop(L, 1) ;

        lua_getfield(L, -1, "l") ;
        if (lua_type(L, -1) == LUA_TNUMBER) {
            l = lua_tonumber(L, -1) ;
        } else if (lua_type(L, -1) != LUA_TNIL) {
            return luaL_argerror(L, 2, "inset for left must be specified as a number") ;
        }
        lua_pop(L, 1) ;

        lua_getfield(L, -1, "r") ;
        if (lua_type(L, -1) == LUA_TNUMBER) {
            r = lua_tonumber(L, -1) ;
        } else if (lua_type(L, -1) != LUA_TNIL) {
            return luaL_argerror(L, 2, "inset for right must be specified as a number") ;
        }
        lua_pop(L, 1) ;

        stack.edgeInsets = NSEdgeInsetsMake(t, l, b, r) ;
        lua_pushvalue(L, 1) ;
    }

    return 1 ;

}

static int stack_detachedViews(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:stack.detachedViews] ;
    return 1 ;
}

static int stack_views(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:stack.views] ;
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = STACK_VIEW_GRAVITY[key] ;
        if (!value) {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [STACK_VIEW_GRAVITY.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }

        [skin pushNSObject:[stack viewsInGravity:value.integerValue]] ;
    }
    return 1 ;
}
// - (void) setViews:(NSArray<NSView *> *) views inGravity:(NSStackViewGravity) gravity;

static int stack_detachesHiddenViews(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, stack.detachesHiddenViews) ;
    } else {
        stack.detachesHiddenViews = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }

    return 1 ;
}

static int stack_spacing(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, stack.spacing) ;
    } else {
        CGFloat spacing = lua_tonumber(L, 2) ;
        stack.spacing = spacing ;
        lua_pushvalue(L, 1) ;
    }

    return 1 ;
}

static int stack_alignment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    NSDictionary *dictionaryToUse = (stack.orientation == NSUserInterfaceLayoutOrientationHorizontal) ?
                                    HORIZONTAL_ALIGNMENTS : VERTICAL_ALIGNMENTS ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(stack.alignment) ;
        NSArray  *temp   = [dictionaryToUse allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized alignment type %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = dictionaryToUse[key] ;
        if (value) {
            stack.alignment = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [dictionaryToUse.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int stack_distribution(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(stack.distribution) ;
        NSArray  *temp   = [STACK_VIEW_DISTRIBUTION allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized distribution type %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = STACK_VIEW_DISTRIBUTION[key] ;
        if (value) {
            stack.distribution = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [STACK_VIEW_DISTRIBUTION.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int stack_orientation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(stack.orientation) ;
        NSArray  *temp   = [UI_LAYOUT_ORIENTATION allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized orientation type %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = UI_LAYOUT_ORIENTATION[key] ;
        if (value) {
            stack.orientation = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [UI_LAYOUT_ORIENTATION.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int stack_horizontalClippingResistancePriority(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, (lua_Number)[stack clippingResistancePriorityForOrientation:NSLayoutConstraintOrientationHorizontal]) ;
    } else {
        float resistance = (float)lua_tonumber(L, 2) ;
        if (resistance > NSLayoutPriorityRequired) resistance = NSLayoutPriorityRequired ;
        [stack setClippingResistancePriority:resistance forOrientation:NSLayoutConstraintOrientationHorizontal] ;
        lua_pushvalue(L, 1) ;
    }

    return 1 ;
}

static int stack_verticalClippingResistancePriority(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, (lua_Number)[stack clippingResistancePriorityForOrientation:NSLayoutConstraintOrientationVertical]) ;
    } else {
        float resistance = (float)lua_tonumber(L, 2) ;
        if (resistance > NSLayoutPriorityRequired) resistance = NSLayoutPriorityRequired ;
        [stack setClippingResistancePriority:resistance forOrientation:NSLayoutConstraintOrientationVertical] ;
        lua_pushvalue(L, 1) ;
    }

    return 1 ;
}


static int stack_horizontalHuggingPriority(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, (lua_Number)[stack huggingPriorityForOrientation:NSLayoutConstraintOrientationHorizontal]) ;
    } else {
        float hugging = (float)lua_tonumber(L, 2) ;
        if (hugging > NSLayoutPriorityRequired) hugging = NSLayoutPriorityRequired ;
//         if (hugging < 0) hugging = 0 ;
        [stack setHuggingPriority:hugging forOrientation:NSLayoutConstraintOrientationHorizontal] ;
        lua_pushvalue(L, 1) ;
    }

    return 1 ;
}

static int stack_verticalHuggingPriority(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, (lua_Number)[stack huggingPriorityForOrientation:NSLayoutConstraintOrientationVertical]) ;
    } else {
        float hugging = (float)lua_tonumber(L, 2) ;
        if (hugging > NSLayoutPriorityRequired) hugging = NSLayoutPriorityRequired ;
//         if (hugging < 0) hugging = 0 ;
        [stack setHuggingPriority:hugging forOrientation:NSLayoutConstraintOrientationVertical] ;
        lua_pushvalue(L, 1) ;
    }

    return 1 ;
}

// Only useful if we allow stack to have subviews that aren't automatically managed as part of the
// horizontal or vertical stack.
//
// static int stack_removeArrangedSubview(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
//     HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;
//
//     NSView *view = nil ;
//
//     if (lua_gettop(L) == 1) {
//         view = stack.arrangedSubviews.lastObject ;
//     } else if (lua_type(L, 2) == LUA_TUSERDATA) {
//         view = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
//         if (!view || !oneOfOurElementObjects(view)) {
//             return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
//         }
//         if (![stack.views containsObject:view]) return luaL_argerror(L, 2, "element not a member of the stack") ;
//     } else if (lua_type(L, 2) == LUA_TNUMBER && lua_isinteger(L, 2)) {
//         NSInteger idx = lua_tointeger(L, 2) - 1 ;
//         if (idx < 0 || idx >= (NSInteger)stack.arrangedSubviews.count) return luaL_argerror(L, 2, "index out of bounds") ;
//         view = stack.arrangedSubviews[(NSUInteger)idx] ;
//     } else {
//         return luaL_argerror(L, 2, "expected integer index or uitk element userdata") ;
//     }
//
// //     [skin luaRelease:refTable forNSObject:view] ; // leaves it in subviews, just no longer managed
//     [stack removeArrangedSubview:view] ;
//     lua_pushvalue(L, 1) ;
//
//     return 1 ;
// }
//
// static int stack_arrangedSubviews(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
//     HSUITKElementContainerStackView *stack = [skin toNSObjectAtIndex:1] ;
//
//     [skin pushNSObject:stack.arrangedSubviews] ;
//     return 1 ;
// }

#pragma mark - Module Constants -

static int stack_layoutPriorities(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    [skin pushNSObject:@{
        @"required"            : @(NSLayoutPriorityRequired),
        @"defaultHigh"         : @(NSLayoutPriorityDefaultHigh),
        @"dragCanResize"       : @(NSLayoutPriorityDragThatCanResizeWindow),
        @"windowSizeStayPut"   : @(NSLayoutPriorityWindowSizeStayPut),
        @"dragCannotResize"    : @(NSLayoutPriorityDragThatCannotResizeWindow),
        @"defaultLow"          : @(NSLayoutPriorityDefaultLow),
        @"fittingSizeCompress" : @(NSLayoutPriorityFittingSizeCompression),
    }] ;

    return 1 ;
}

static int stack_visibilityPriorities(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    [skin pushNSObject:@{
        @"mustHold"          : @(NSStackViewVisibilityPriorityMustHold),
        @"detachIfNecessary" : @(NSStackViewVisibilityPriorityDetachOnlyIfNecessary),
        @"notVisible"        : @(NSStackViewVisibilityPriorityNotVisible),
    }] ;

    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementContainerStackView(lua_State *L, id obj) {
    HSUITKElementContainerStackView *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = (void **)(lua_newuserdata(L, sizeof(HSUITKElementContainerStackView *)));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementContainerStackView(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementContainerStackView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementContainerStackView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     HSUITKElementContainerStackView *obj = [skin luaObjectAtIndex:1 toClass:"HSUITKElementContainerStackView"] ;
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
    HSUITKElementContainerStackView *obj = get_objectFromUserdata(__bridge_transfer HSUITKElementContainerStackView, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef    = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj.passThroughRef = [skin luaUnref:refTable ref:obj.passThroughRef] ;
            for (NSView *item in obj.views) [skin luaRelease:refTable forNSObject:item] ;

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
    {"attachmentCallback",        stack_attachmentCallback},
    {"passthroughCallback",       stack_passthroughCallback},
    {"edgeInsets",                stack_edgeInsets},
    {"detachesHiddenElements",    stack_detachesHiddenViews},
    {"spacing",                   stack_spacing},
    {"alignment",                 stack_alignment},
    {"distribution",              stack_distribution},
    {"orientation",               stack_orientation},
    {"horizontalClipResistance",  stack_horizontalClippingResistancePriority},
    {"verticalClipResistance",    stack_verticalClippingResistancePriority},
    {"horizontalHugging",         stack_horizontalHuggingPriority},
    {"verticalHugging",           stack_verticalHuggingPriority},

    {"detachedElements",          stack_detachedViews},
    {"elements",                  stack_views},
    {"elementVisibilityPriority", stack_visibilityPriorityForView},
    {"insertElement",             stack_insertArrangedSubview},
    {"removeElement",             stack_removeView},
    {"spacingAfterElement",       stack_customSpacingAfterView},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",     stack_new},
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libcontainer_stack(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKElementContainerStackView  forClass:"HSUITKElementContainerStackView"];
    [skin registerLuaObjectHelper:toHSUITKElementContainerStackView forClass:"HSUITKElementContainerStackView"
                                                       withUserdataMapping:USERDATA_TAG];

    stack_layoutPriorities(L) ;     lua_setfield(L, -2, "layoutPriorities") ;
    stack_visibilityPriorities(L) ; lua_setfield(L, -2, "visibilityPriorities") ;

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"attachmentCallback",
        @"passthroughCallback",
        @"edgeInsets",
        @"detachesHiddenElements",
        @"spacing",
        @"alignment",
        @"distribution",
        @"orientation",
        @"horizontalClipResistance",
        @"verticalClipResistance",
        @"horizontalHugging",
        @"verticalHugging",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    // lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}

