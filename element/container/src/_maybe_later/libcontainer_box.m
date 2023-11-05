@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.container.box" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *BORDER_TYPES ;
static NSDictionary *BOX_TYPES ;
static NSDictionary *TITLE_POSITIONS ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    BORDER_TYPES = @{
        @"bezel"  : @(NSBezelBorder),
        @"groove" : @(NSGrooveBorder),
        @"line"   : @(NSLineBorder),
        @"none"   : @(NSNoBorder),
    } ;

    BOX_TYPES = @{
        @"primary"   : @(NSBoxPrimary),
        @"separator" : @(NSBoxSeparator),
        @"custom"    : @(NSBoxCustom),
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        @"secondary" : @(NSBoxSecondary),
        @"oldStyle"  : @(NSBoxOldStyle),
#pragma clang diagnostic pop
    } ;

    TITLE_POSITIONS = @{
        @"none"        : @(NSNoTitle),
        @"aboveTop"    : @(NSAboveTop),
        @"atTop"       : @(NSAtTop),
        @"belowTop"    : @(NSBelowTop),
        @"aboveBottom" : @(NSAboveBottom),
        @"atBottom"    : @(NSAtBottom),
        @"belowBottom" : @(NSBelowBottom),
    } ;

}

static BOOL oneOfOurs(NSView *obj) {
    return [obj isKindOfClass:[NSView class]]  &&
           [obj respondsToSelector:NSSelectorFromString(@"selfRefCount")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setSelfRefCount:")] &&
           [obj respondsToSelector:NSSelectorFromString(@"refTable")] &&
           [obj respondsToSelector:NSSelectorFromString(@"callbackRef")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setCallbackRef:")] ;
}

@interface HSUITKElementContainerBox : NSBox
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ; // in this case, it's the passthrough callback for subviews
                                              // with no callbacks, but we keep the name since this is
                                              // checked in _view for the common methods
@end

@implementation HSUITKElementContainerBox
- (instancetype)initWithFrame:(NSRect)frameRect {
    @try {
        self = [super initWithFrame:frameRect] ;
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:new - %@", USERDATA_TAG, exception.reason]] ;
        self = nil ;
    }

    if (self) {
        _selfRefCount = 0 ;
        _refTable     = refTable ;
        _callbackRef  = LUA_NOREF ;
    }

    return self ;
}

// allow next responder a chance since we don't have a callback set
- (void)passCallbackUpWith:(NSArray *)arguments {
    NSObject *nextInChain = [self nextResponder] ;

    SEL passthroughCallback = NSSelectorFromString(@"performPassthroughCallback:") ;
    while(nextInChain) {
        if ([nextInChain respondsToSelector:passthroughCallback]) {
            [nextInChain performSelectorOnMainThread:passthroughCallback
                                          withObject:arguments
                                       waitUntilDone:YES] ;
            break ;
        } else {
            nextInChain = [(NSResponder *)nextInChain nextResponder] ;
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

@end

#pragma mark - Module Functions

/// hs._asm.uitk.element.container.box.new([frame]) -> containerObject
/// Constructor
/// Creates a new container box for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the frame for the element.
///
/// Returns:
///  * the containerObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a window or to another container.
static int box_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementContainerBox *container = [[HSUITKElementContainerBox alloc] initWithFrame:frameRect];
    if (container) {
        if (lua_gettop(L) != 1) [container setFrameSize:[container fittingSize]] ;
        [skin pushNSObject:container] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods

/// hs._asm.uitk.element.container.box:passthroughCallback([fn | nil]) -> containerObject | fn | nil
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
static int box_passthroughCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        box.callbackRef = [skin luaUnref:refTable ref:box.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            box.callbackRef = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (box.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:box.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int box_borderWidth(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, box.borderWidth) ;
    } else {
        box.borderWidth = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int box_cornerRadius(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, box.cornerRadius) ;
    } else {
        box.cornerRadius = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int box_transparent(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, box.transparent) ;
    } else {
        box.transparent = lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int box_borderType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSNumber *value  = @(box.borderType) ;
#pragma clang diagnostic pop
        NSArray  *temp   = [BORDER_TYPES allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized border type %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = BORDER_TYPES[key] ;
        if (value) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            box.borderType = value.unsignedIntegerValue ;
#pragma clang diagnostic pop
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[BORDER_TYPES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int box_boxType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(box.boxType) ;
        NSArray  *temp   = [BOX_TYPES allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized box type %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = BOX_TYPES[key] ;
        if (value) {
            box.boxType = value.unsignedIntegerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[BOX_TYPES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int box_titlePosition(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(box.titlePosition) ;
        NSArray  *temp   = [TITLE_POSITIONS allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized title position %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = TITLE_POSITIONS[key] ;
        if (value) {
            box.titlePosition = value.unsignedIntegerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[TITLE_POSITIONS allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int box_contentViewMargins(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:box.contentViewMargins] ;
    } else {
        box.contentViewMargins = [skin tableToSizeAtIndex:2] ;
        [box sizeToFit] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int box_borderColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:box.borderColor] ;
    } else {
        box.borderColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int box_fillColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:box.fillColor] ;
    } else {
        box.fillColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int box_title(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:box.title] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            box.title = @"" ;
        } else {
            box.title = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int box_contentView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:box.contentView withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            [skin luaRelease:refTable forNSObject:box.contentView] ;
            box.contentView = nil ;
        } else {
            NSView *content = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
            if (!content || !oneOfOurs(content)) {
                return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
            }
            [skin luaRelease:refTable forNSObject:box.contentView] ;
            [skin luaRetain:refTable forNSObject:content] ;
            box.contentView = content ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}


static int box_titleFont(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerBox *box = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:box.titleFont] ;
    } else {
        box.titleFont = [skin luaObjectAtIndex:2 toClass:"NSFont"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int box_sizeToFit(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementContainerBox *box = [skin toNSObjectAtIndex:1] ;

    [box sizeToFit] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

// // alters box.frame as well in ways I don't understand yet... let's wait to see
// // if this is necessary...
// //
// static int box_setContentFrame(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
//     HSUITKElementContainerBox *box = [skin toNSObjectAtIndex:1] ;
//
//     NSRect newRect = [skin tableToRectAtIndex:2] ;
//     NSRect superRect = box.superview.frame ;
//     newRect.origin.y = (superRect.size.height - newRect.size.height) - newRect.origin.y ;
//
//     [box setFrameFromContentFrame:newRect] ;
//     lua_pushvalue(L, 1) ;
//     return 1 ;
// }

// @property(readonly, strong) id titleCell;
// @property(readonly) NSRect borderRect;
// @property(readonly) NSRect titleRect;

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementContainerBox(lua_State *L, id obj) {
    HSUITKElementContainerBox *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementContainerBox *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementContainerBoxFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementContainerBox *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementContainerBox, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

// static int userdata_gc(lua_State* L) {
//     HSUITKElementContainerBox *obj = get_objectFromUserdata(__bridge_transfer HSUITKElementContainerBox, L, 1, USERDATA_TAG) ;
//     if (obj) {
//         obj. selfRefCount-- ;
//         if (obj.selfRefCount == 0) {
//             LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//             obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
//             obj = nil ;
//         }
//     }
//     // Remove the Metatable so future use of the variable in Lua won't think its valid
//     lua_pushnil(L) ;
//     lua_setmetatable(L, 1) ;
//     return 0 ;
// }

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"passthroughCallback", box_passthroughCallback},
    {"borderWidth",         box_borderWidth},
    {"cornerRadius",        box_cornerRadius},
    {"transparent",         box_transparent},
    {"borderType",          box_borderType},
    {"boxType",             box_boxType},
    {"titlePosition",       box_titlePosition},
    {"contentMargins",      box_contentViewMargins},
    {"borderColor",         box_borderColor},
    {"fillColor",           box_fillColor},
    {"title",               box_title},
    {"content",             box_contentView},
    {"titleFont",           box_titleFont},

//     {"setContentFrame",     box_setContentFrame},
    {"sizeToFit",           box_sizeToFit},

// other metamethods inherited from _control and _view
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", box_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libcontainer_box(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSUITKElementContainerBox         forClass:"HSUITKElementContainerBox"];
    [skin registerLuaObjectHelper:toHSUITKElementContainerBoxFromLua forClass:"HSUITKElementContainerBox"
                                             withUserdataMapping:USERDATA_TAG];

    defineInternalDictionaries() ;

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"passthroughCallback",
        @"borderWidth",
        @"cornerRadius",
        @"transparent",
        @"borderType",
        @"boxType",
        @"titlePosition",
        @"contentMargins",
        @"borderColor",
        @"fillColor",
        @"title",
        @"content",
        @"titleFont",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pop(L, 1) ;

    return 1;
}
