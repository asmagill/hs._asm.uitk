@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.segmentBar" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *SEGMENTS_STYLE ;
static NSDictionary *SEGMENTS_TRACKING ;
static NSDictionary *SEGMENTS_DISTRIBUTION ;
static NSDictionary *SEGMENTS_ALIGNMENT ;
static NSDictionary *IMAGE_SCALING_TYPES ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    SEGMENTS_STYLE = @{
        @"automatic"       : @(NSSegmentStyleAutomatic),
        @"rounded"         : @(NSSegmentStyleRounded),
        @"texturedRounded" : @(NSSegmentStyleTexturedRounded),
        @"roundRect"       : @(NSSegmentStyleRoundRect),
        @"texturedSquare"  : @(NSSegmentStyleTexturedSquare),
        @"capsule"         : @(NSSegmentStyleCapsule),
        @"square"          : @(NSSegmentStyleSmallSquare),
        @"separated"       : @(NSSegmentStyleSeparated),
    } ;

    SEGMENTS_TRACKING = @{
        @"selectOne"            : @(NSSegmentSwitchTrackingSelectOne),
        @"selectAny"            : @(NSSegmentSwitchTrackingSelectAny),
        @"momentary"            : @(NSSegmentSwitchTrackingMomentary),
        @"momentaryAccelerator" : @(NSSegmentSwitchTrackingMomentaryAccelerator),
    } ;

    SEGMENTS_DISTRIBUTION = @{
        @"fit"                : @(NSSegmentDistributionFit),
        @"fill"               : @(NSSegmentDistributionFill),
        @"fillEqually"        : @(NSSegmentDistributionFillEqually),
        @"fillProportionally" : @(NSSegmentDistributionFillProportionally),
    } ;

    SEGMENTS_ALIGNMENT = @{
        @"left"      : @(NSTextAlignmentLeft),
        @"right"     : @(NSTextAlignmentRight),
        @"center"    : @(NSTextAlignmentCenter),
        @"justified" : @(NSTextAlignmentJustified),
        @"natural"   : @(NSTextAlignmentNatural),
    } ;

    IMAGE_SCALING_TYPES = @{
        @"proportionallyDown"     : @(NSImageScaleProportionallyDown),
        @"axesIndependently"      : @(NSImageScaleAxesIndependently),
        @"none"                   : @(NSImageScaleNone),
        @"proportionallyUpOrDown" : @(NSImageScaleProportionallyUpOrDown),
    };
}

@interface NSMenu (assignmentSharing)
@property (weak) NSResponder *assignedTo ;
@end

@interface HSUITKElementSegmentedControl : NSSegmentedControl
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;
@end

@implementation HSUITKElementSegmentedControl
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
        _refTable       = refTable ;
        _selfRefCount   = 0 ;

        self.target       = self ;
        self.action       = @selector(performCallback:) ;
        self.continuous   = NO ;
        self.segmentCount = 1 ; // give it an initial fitting size to remove warnings during setup
    }
    return self ;
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
    if (self.trackingMode == NSSegmentSwitchTrackingMomentaryAccelerator) {
        [self callbackHamster:@[ self, @(self.indexOfSelectedItem + 1), @(self.doubleValueForSelectedSegment) ]] ;
    } else {
        [self callbackHamster:@[ self, @(self.indexOfSelectedItem + 1) ]] ;
    }
}

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.segmentBar.new([frame]) -> segmentBarObject
/// Constructor
/// Creates a new segmentBar element for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the frame for the element.
///
/// Returns:
///  * the segmentBarObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a container element or to a `hs._asm.uitk.window`.
static int segmentBar_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementSegmentedControl *element = [[HSUITKElementSegmentedControl alloc] initWithFrame:frameRect];
    if (element) {
        if (lua_gettop(L) != 1) [element setFrameSize:[element fittingSize]] ;
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

static int segmentBar_segmentCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, element.segmentCount) ;
    } else {
        NSInteger segments = lua_tointeger(L, 2) ;
        if (segments < 0) {
            return luaL_argerror(L, 2, "count must be 0 or greater") ;
        }
        element.segmentCount = lua_tointeger(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int segmentBar_labelForSegment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TSTRING | LS_TNIL | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;
    NSInteger                      segment  = lua_tointeger(L, 2) ;

    if ((segment < 1) || (segment > element.segmentCount)) {
        return luaL_argerror(L, 2, "index out of range") ;
    } else {
        segment = segment - 1 ;
    }

    if (lua_gettop(L) == 2) {
        [skin pushNSObject:[element labelForSegment:segment]] ;
    } else {
        if (lua_type(L, 3) == LUA_TNIL) {
// NOTE: this is actually allowed and is how to force proper alignment of images in 10.4
//       granted we're newer than that, but before label assignment, a segments
//       label is nill, so must be an oversight when they started accepting the
//       NONNULL attribute in clang
// https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SegmentedControl/Articles/SegmentedControlCode.html
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
            [element setLabel:nil forSegment:segment] ;
#pragma clang diagnostic pop
        } else {
            [element setLabel:[skin toNSObjectAtIndex:3] forSegment:segment] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int segmentBar_imageForSegment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;
    NSInteger                      segment  = lua_tointeger(L, 2) ;

    if ((segment < 1) || (segment > element.segmentCount)) {
        return luaL_argerror(L, 2, "index out of range") ;
    } else {
        segment = segment - 1 ;
    }

    if (lua_gettop(L) == 2) {
        [skin pushNSObject:[element imageForSegment:segment]] ;
    } else {
        if (lua_type(L, 3) == LUA_TNIL) {
            [element setImage:nil forSegment:segment] ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                            LS_TNUMBER | LS_TINTEGER,
                            LS_TUSERDATA, "hs.image",
                            LS_TBREAK] ;
            [element setImage:[skin toNSObjectAtIndex:3] forSegment:segment] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int segmentBar_menuForSegment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;
    NSInteger                      segment  = lua_tointeger(L, 2) ;

    if ((segment < 1) || (segment > element.segmentCount)) {
        return luaL_argerror(L, 2, "index out of range") ;
    } else {
        segment = segment - 1 ;
    }

    if (lua_gettop(L) == 2) {
        [skin pushNSObject:[element menuForSegment:segment]] ;
    } else {
        NSMenu *currentMenu = [element menuForSegment:segment] ;

        if (lua_type(L, 3) == LUA_TNIL) {
            [element setMenu:nil forSegment:segment] ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                            LS_TNUMBER | LS_TINTEGER,
                            LS_TUSERDATA, "hs._asm.uitk.menu",
                            LS_TBREAK] ;
            NSMenu *newMenu = [skin toNSObjectAtIndex:3] ;
            newMenu.assignedTo = element ;
            [element setMenu:newMenu forSegment:segment] ;
            [skin luaRetain:refTable forNSObject:newMenu] ;
        }

        if (currentMenu) {
            currentMenu.assignedTo = nil ;
            [skin luaRelease:refTable forNSObject:currentMenu] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int segmentBar_menuOnly(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.action == nil) ;
    } else {
        if (lua_toboolean(L, 2)) {
            element.action = @selector(performCallback:) ;
        } else {
            element.action = nil ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int segmentBar_isEnabledForSegment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;
    NSInteger                      segment  = lua_tointeger(L, 2) ;

    if ((segment < 1) || (segment > element.segmentCount)) {
        return luaL_argerror(L, 2, "index out of range") ;
    } else {
        segment = segment - 1 ;
    }

    if (lua_gettop(L) == 2) {
        lua_pushboolean(L, [element isEnabledForSegment:segment]) ;
    } else {
        [element setEnabled:(BOOL)(lua_toboolean(L, 3)) forSegment:segment] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int segmentBar_showsMenuIndicatorForSegment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;
    NSInteger                      segment  = lua_tointeger(L, 2) ;

    if ((segment < 1) || (segment > element.segmentCount)) {
        return luaL_argerror(L, 2, "index out of range") ;
    } else {
        segment = segment - 1 ;
    }

    if (lua_gettop(L) == 2) {
        lua_pushboolean(L, [element showsMenuIndicatorForSegment:segment]) ;
    } else {
        [element setShowsMenuIndicator:(BOOL)(lua_toboolean(L, 3)) forSegment:segment] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int segmentBar_isSelectedForSegment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;
    NSInteger                      segment  = lua_tointeger(L, 2) ;

    if ((segment < 1) || (segment > element.segmentCount)) {
        return luaL_argerror(L, 2, "index out of range") ;
    } else {
        segment = segment - 1 ;
    }

    if (lua_gettop(L) == 2) {
        lua_pushboolean(L, [element isSelectedForSegment:segment]) ;
    } else {
        [element setSelected:(BOOL)(lua_toboolean(L, 3)) forSegment:segment] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int segmentBar_widthForSegment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;
    NSInteger                      segment  = lua_tointeger(L, 2) ;

    if ((segment < 1) || (segment > element.segmentCount)) {
        return luaL_argerror(L, 2, "index out of range") ;
    } else {
        segment = segment - 1 ;
    }

    if (lua_gettop(L) == 2) {
        lua_pushnumber(L, [element widthForSegment:segment]) ;
    } else {
        CGFloat width = lua_tonumber(L, 3) ;
        if (width < 0) {
            return luaL_argerror(L, 3, "width must be 0 or greater") ;
        }
        [element setWidth:width forSegment:segment] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int segmentBar_tagForSegment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;
    NSInteger                      segment  = lua_tointeger(L, 2) ;

    if ((segment < 1) || (segment > element.segmentCount)) {
        return luaL_argerror(L, 2, "index out of range") ;
    } else {
        segment = segment - 1 ;
    }

    if (lua_gettop(L) == 2) {
        lua_pushinteger(L, [element tagForSegment:segment]) ;
    } else {
        [element setTag:lua_tointeger(L, 3) forSegment:segment] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int segmentBar_toolTipForSegment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TSTRING | LS_TNIL | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;
    NSInteger                      segment  = lua_tointeger(L, 2) ;

    if ((segment < 1) || (segment > element.segmentCount)) {
        return luaL_argerror(L, 2, "index out of range") ;
    } else {
        segment = segment - 1 ;
    }

    if (lua_gettop(L) == 2) {
        [skin pushNSObject:[element toolTipForSegment:segment]] ;
    } else {
        if (lua_type(L, 3) == LUA_TNIL) {
            [element setToolTip:nil forSegment:segment] ;
        } else {
            [element setToolTip:[skin toNSObjectAtIndex:3] forSegment:segment] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int segmentBar_alignmentForSegment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TSTRING | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;
    NSInteger                      segment  = lua_tointeger(L, 2) ;

    if ((segment < 1) || (segment > element.segmentCount)) {
        return luaL_argerror(L, 2, "index out of range") ;
    } else {
        segment = segment - 1 ;
    }

    if (lua_gettop(L) == 2) {
        NSNumber *value  = @([element alignmentForSegment:segment]) ;
        NSArray  *temp   = [SEGMENTS_ALIGNMENT allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized label alignment %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:3] ;
        NSNumber *value = SEGMENTS_ALIGNMENT[key] ;
        if (value) {
            [element setAlignment:value.integerValue forSegment:segment] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 3, [[NSString stringWithFormat:@"must be one of %@", [SEGMENTS_ALIGNMENT.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int segmentBar_imageScalingForSegment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TSTRING | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;
    NSInteger                      segment  = lua_tointeger(L, 2) ;

    if ((segment < 1) || (segment > element.segmentCount)) {
        return luaL_argerror(L, 2, "index out of range") ;
    } else {
        segment = segment - 1 ;
    }

    if (lua_gettop(L) == 2) {
        NSNumber *value  = @([element imageScalingForSegment:segment]) ;
        NSArray  *temp   = [IMAGE_SCALING_TYPES allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized image scaling %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:3] ;
        NSNumber *value = IMAGE_SCALING_TYPES[key] ;
        if (value) {
            [element setImageScaling:value.unsignedIntegerValue forSegment:segment] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 3, [[NSString stringWithFormat:@"must be one of %@", [IMAGE_SCALING_TYPES.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int segmentBar_trackingMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(element.trackingMode) ;
        NSArray  *temp   = [SEGMENTS_TRACKING allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized tracking mode %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = SEGMENTS_TRACKING[key] ;
        if (value) {
            element.trackingMode = value.unsignedIntegerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [SEGMENTS_TRACKING.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int segmentBar_segmentDistribution(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(element.segmentDistribution) ;
        NSArray  *temp   = [SEGMENTS_DISTRIBUTION allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized segment distribution %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = SEGMENTS_DISTRIBUTION[key] ;
        if (value) {
            element.segmentDistribution = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [SEGMENTS_DISTRIBUTION.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int segmentBar_segmentStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(element.segmentStyle) ;
        NSArray  *temp   = [SEGMENTS_STYLE allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized segment style %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = SEGMENTS_STYLE[key] ;
        if (value) {
            element.segmentStyle = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [SEGMENTS_STYLE.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int segmentBar_springLoaded(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.springLoaded) ;
    } else {
        element.springLoaded = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int segmentBar_selectedSegment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if (element.selectedSegment == -1) {
            lua_pushnil(L) ;
        } else {
            lua_pushinteger(L, element.selectedSegment + 1) ;
        }
    } else {
        NSInteger idx = -1 ;
        if (lua_type(L, 2) != LUA_TNIL) {
            idx = lua_tointeger(L, 2) ;
            if ((idx < 1) || (idx > element.segmentCount)) {
                return luaL_argerror(L, 2, "index out of range") ;
            } else {
                idx = idx - 1 ;
            }
        }
        element.selectedSegment = idx ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int segmentBar_selectSegmentWithTag(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, [element selectSegmentWithTag:lua_tointeger(L, 2)]) ;
    return 1 ;
}

static int segmentBar_selectedSegmentBezelColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementSegmentedControl *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:element.selectedSegmentBezelColor] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            element.selectedSegmentBezelColor = nil ;
        } else {
            element.selectedSegmentBezelColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// @property(readonly, copy) NSUserInterfaceCompressionOptions *activeCompressionOptions;
// - (void)compressWithPrioritizedCompressionOptions:(NSArray<NSUserInterfaceCompressionOptions *> *)prioritizedOptions;
// - (NSSize)minimumSizeWithPrioritizedCompressionOptions:(NSArray<NSUserInterfaceCompressionOptions *> *)prioritizedOptions;

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementSegmentedControl(lua_State *L, id obj) {
    HSUITKElementSegmentedControl *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementSegmentedControl *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementSegmentedControl(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementSegmentedControl *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementSegmentedControl, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_gc(lua_State* L) {
    HSUITKElementSegmentedControl *obj  = get_objectFromUserdata(__bridge_transfer HSUITKElementSegmentedControl, L, 1, USERDATA_TAG) ;

    obj.selfRefCount-- ;
    if (obj.selfRefCount == 0) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        obj.callbackRef = [skin luaUnref:obj.refTable ref:obj.callbackRef] ;
        for(NSInteger i = 0 ; i < obj.segmentCount ; i++) {
            NSMenu *menu = [obj menuForSegment:i] ;
            if (menu) {
                menu.assignedTo = nil ;
                [skin luaRelease:refTable forNSObject:menu] ;
            }
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
    {"segmentCount",            segmentBar_segmentCount},
    {"labelForSegment",         segmentBar_labelForSegment},
    {"imageForSegment",         segmentBar_imageForSegment},
    {"menuForSegment",          segmentBar_menuForSegment},
    {"enabledForSegment",       segmentBar_isEnabledForSegment},
    {"menuIndicatorForSegment", segmentBar_showsMenuIndicatorForSegment},
    {"selectedForSegment",      segmentBar_isSelectedForSegment},
    {"widthForSegment",         segmentBar_widthForSegment},
    {"tagForSegment",           segmentBar_tagForSegment},
    {"toolTipForSegment",       segmentBar_toolTipForSegment},
    {"alignmentForSegment",     segmentBar_alignmentForSegment},
    {"imageScalingForSegment",  segmentBar_imageScalingForSegment},
    {"trackingMode",            segmentBar_trackingMode},
    {"segmentDistribution",     segmentBar_segmentDistribution},
    {"segmentStyle",            segmentBar_segmentStyle},
    {"springLoaded",            segmentBar_springLoaded},
    {"selectedSegment",         segmentBar_selectedSegment},
    {"selectSegmentWithTag",    segmentBar_selectSegmentWithTag},
    {"selectedBezelColor",      segmentBar_selectedSegmentBezelColor},
    {"menuOnly",                segmentBar_menuOnly},

// other metamethods inherited from _control and _view
    {"__gc",                   userdata_gc},
    {NULL,                     NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", segmentBar_new},
    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_libelement_segmentBar(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKElementSegmentedControl  forClass:"HSUITKElementSegmentedControl"];
    [skin registerLuaObjectHelper:toHSUITKElementSegmentedControl forClass:"HSUITKElementSegmentedControl"
                                                       withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"segmentCount",
        @"trackingMode",
        @"segmentDistribution",
        @"segmentStyle",
        @"springLoaded",
        @"selectedSegment",
        @"selectedBezelColor",
        @"menuOnly",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}
