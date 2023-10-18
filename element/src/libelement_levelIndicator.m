@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.levelIndicator" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *LEVELINDICATOR_STYLES ;
static NSDictionary *LEVELINDICATOR_PLACEHOLDER_VISIBILITY ;
static NSDictionary *LEVELINDICATOR_TICKMARK_POSITION ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    LEVELINDICATOR_STYLES = @{
        @"relevancy"  : @(NSLevelIndicatorStyleRelevancy),
        @"continuous" : @(NSLevelIndicatorStyleContinuousCapacity),
        @"discrete"   : @(NSLevelIndicatorStyleDiscreteCapacity),
        @"rating"     : @(NSLevelIndicatorStyleRating),
    } ;

    LEVELINDICATOR_PLACEHOLDER_VISIBILITY = @{
        @"automatic" : @(NSLevelIndicatorPlaceholderVisibilityAutomatic),
        @"always"    : @(NSLevelIndicatorPlaceholderVisibilityAlways),
        @"editing"   : @(NSLevelIndicatorPlaceholderVisibilityWhileEditing),
    } ;

    LEVELINDICATOR_TICKMARK_POSITION = @{
        @"below"    : @(NSTickMarkPositionBelow),
        @"above"    : @(NSTickMarkPositionAbove),
        @"leading"  : @(NSTickMarkPositionLeading),
        @"trailing" : @(NSTickMarkPositionTrailing),
    } ;
}

@interface HSUITKElementLevelIndicator : NSLevelIndicator
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;
@end

@implementation HSUITKElementLevelIndicator
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

        self.target     = self ;
        self.action     = @selector(performCallback:) ;
        self.continuous = NO ;
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

- (void)performCallback:(__unused id)sender {
    [self callbackHamster:@[ self, @(self.doubleValue) ]] ;
}

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.levelIndicator.new([frame]) -> levelIndicatorObject
/// Constructor
/// Creates a new levelIndicator element for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the frame for the element.
///
/// Returns:
///  * the levelIndicatorObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a content element or to a `hs._asm.uitk.window`.
static int levelIndicator_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementLevelIndicator *element = [[HSUITKElementLevelIndicator alloc] initWithFrame:frameRect];
    if (element) {
        if (lua_gettop(L) != 1) [element setFrameSize:[element fittingSize]] ;
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

static int levelIndicator_drawsTieredCapacityLevels(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.drawsTieredCapacityLevels) ;
    } else {
        element.drawsTieredCapacityLevels = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int levelIndicator_editable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.editable) ;
    } else {
        element.editable = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int levelIndicator_criticalValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.criticalValue) ;
    } else {
        element.criticalValue = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int levelIndicator_maxValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.maxValue) ;
    } else {
        element.maxValue = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int levelIndicator_minValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.minValue) ;
    } else {
        element.minValue = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int levelIndicator_warningValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.warningValue) ;
    } else {
        element.warningValue = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int levelIndicator_ratingImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:element.ratingImage] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            element.ratingImage = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            element.ratingImage = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int levelIndicator_ratingPlaceholderImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:element.ratingPlaceholderImage] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            element.ratingPlaceholderImage = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            element.ratingPlaceholderImage = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int levelIndicator_criticalFillColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:element.criticalFillColor] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            element.criticalFillColor = nil ;
        } else {
            element.criticalFillColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int levelIndicator_fillColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:element.fillColor] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            element.fillColor = nil ;
        } else {
            element.fillColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int levelIndicator_warningFillColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:element.warningFillColor] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            element.warningFillColor = nil ;
        } else {
            element.warningFillColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int levelIndicator_numberOfTickMarks(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, element.numberOfTickMarks) ;
    } else {
        NSInteger marks = lua_tointeger(L, 2) ;
        element.numberOfTickMarks = (marks < 0) ? 0 : marks ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int levelIndicator_numberOfMajorTickMarks(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, element.numberOfMajorTickMarks) ;
    } else {
        NSInteger marks = lua_tointeger(L, 2) ;
        if (marks < 0) marks = 0 ;
        if (marks > element.numberOfTickMarks) marks = element.numberOfTickMarks ;
        element.numberOfMajorTickMarks = marks ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int levelIndicator_currentValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.doubleValue) ;
    } else {
        element.doubleValue = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return  1 ;
}

static int levelIndicator_rectOfTickMarkAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;
    lua_Integer index = lua_tointeger(L, 2) ;

    NSInteger numberOfTickMarks = element.numberOfTickMarks ;
    if (index < 1 || index > numberOfTickMarks) {
        if (numberOfTickMarks > 0) {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index must be between 1 and %ld", numberOfTickMarks] UTF8String]) ;
        } else {
            return luaL_argerror(L, 2, "element does not have any tick marks") ;
        }
    }
    [skin pushNSRect:[element rectOfTickMarkAtIndex:index - 1]] ;
    return 1 ;
}

static int levelIndicator_tickMarkValueAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;
    lua_Integer index = lua_tointeger(L, 2) ;

    NSInteger numberOfTickMarks = element.numberOfTickMarks ;
    if (index < 1 || index > numberOfTickMarks) {
        if (numberOfTickMarks > 0) {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index must be between 1 and %ld", numberOfTickMarks] UTF8String]) ;
        } else {
            return luaL_argerror(L, 2, "element does not have any tick marks") ;
        }
    }
    lua_pushnumber(L, [element tickMarkValueAtIndex:index - 1]) ;
    return 1 ;
}

static int levelIndicator_placeholderVisibility(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *number = @(element.placeholderVisibility) ;
        NSArray *temp = [LEVELINDICATOR_PLACEHOLDER_VISIBILITY allKeysForObject:number];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized placeholder visiblity %@ -- notify developers", USERDATA_TAG, number]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *number = LEVELINDICATOR_PLACEHOLDER_VISIBILITY[key] ;
        if (number) {
            element.placeholderVisibility = [number integerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[LEVELINDICATOR_PLACEHOLDER_VISIBILITY allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int levelIndicator_levelIndicatorStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *number = @(element.levelIndicatorStyle) ;
        NSArray *temp = [LEVELINDICATOR_STYLES allKeysForObject:number];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized style %@ -- notify developers", USERDATA_TAG, number]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *number = LEVELINDICATOR_STYLES[key] ;
        if (number) {
            element.levelIndicatorStyle = [number unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[LEVELINDICATOR_STYLES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int levelIndicator_tickMarkPosition(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementLevelIndicator *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *number = @(element.tickMarkPosition) ;
        NSArray *temp = [LEVELINDICATOR_TICKMARK_POSITION allKeysForObject:number];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized style %@ -- notify developers", USERDATA_TAG, number]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *number = LEVELINDICATOR_TICKMARK_POSITION[key] ;
        if (number) {
            element.tickMarkPosition = [number unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[LEVELINDICATOR_TICKMARK_POSITION allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementLevelIndicator(lua_State *L, id obj) {
    HSUITKElementLevelIndicator *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementLevelIndicator *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementLevelIndicatorFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementLevelIndicator *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementLevelIndicator, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"criticalFillColor",      levelIndicator_criticalFillColor},
    {"criticalValue",          levelIndicator_criticalValue},
    {"tieredCapacityLevels",   levelIndicator_drawsTieredCapacityLevels},
    {"editable",               levelIndicator_editable},
    {"fillColor",              levelIndicator_fillColor},
    {"maxValue",               levelIndicator_maxValue},
    {"minValue",               levelIndicator_minValue},
    {"majorTickMarks",         levelIndicator_numberOfMajorTickMarks},
    {"tickMarks",              levelIndicator_numberOfTickMarks},
    {"ratingImage",            levelIndicator_ratingImage},
    {"ratingPlaceholderImage", levelIndicator_ratingPlaceholderImage},
    {"warningFillColor",       levelIndicator_warningFillColor},
    {"warningValue",           levelIndicator_warningValue},
    {"value",                  levelIndicator_currentValue},
    {"tickMarkValue",          levelIndicator_tickMarkValueAtIndex},
    {"rectOfTickMark",         levelIndicator_rectOfTickMarkAtIndex},
    {"placeholderVisibility",  levelIndicator_placeholderVisibility},
    {"style",                  levelIndicator_levelIndicatorStyle},
    {"tickMarkPosition",       levelIndicator_tickMarkPosition},

// other metamethods inherited from _control and _view
    {NULL,    NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", levelIndicator_new},
    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_libelement_levelIndicator(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKElementLevelIndicator         forClass:"HSUITKElementLevelIndicator"];
    [skin registerLuaObjectHelper:toHSUITKElementLevelIndicatorFromLua forClass:"HSUITKElementLevelIndicator"
                                                             withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through content metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"criticalFillColor",
        @"criticalValue",
        @"tieredCapacityLevels",
        @"editable",
        @"fillColor",
        @"maxValue",
        @"minValue",
        @"majorTickMarks",
        @"tickMarks",
        @"ratingImage",
        @"ratingPlaceholderImage",
        @"warningFillColor",
        @"warningValue",
        @"value",
        @"placeholderVisibility",
        @"style",
        @"tickMarkPosition",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}
