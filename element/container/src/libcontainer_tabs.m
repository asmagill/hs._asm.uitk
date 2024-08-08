@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.container.tabs" ;
static const char * const UD_ITEM_TAG   = "hs._asm.uitk.element.container.tabs.item" ;

static LSRefTable         refTable      = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *CONTROL_SIZE ;
static NSDictionary *TAB_POSITION ;
static NSDictionary *TAB_BORDER ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    if (@available(macOS 11, *)) {
        CONTROL_SIZE = @{
            @"regular" : @(NSControlSizeRegular),
            @"small"   : @(NSControlSizeSmall),
            @"mini"    : @(NSControlSizeMini),
            @"large"   : @(NSControlSizeLarge),
        } ;
    } else {
        CONTROL_SIZE = @{
            @"regular" : @(NSControlSizeRegular),
            @"small"   : @(NSControlSizeSmall),
            @"mini"    : @(NSControlSizeMini),
        } ;
    }

    TAB_POSITION = @{
        @"bottom" : @(NSTabPositionBottom),
        @"left"   : @(NSTabPositionLeft),
        @"none"   : @(NSTabPositionNone),
        @"right"  : @(NSTabPositionRight),
        @"top"    : @(NSTabPositionTop),
    } ;

    TAB_BORDER = @{
        @"bezel" : @(NSTabViewBorderTypeBezel),
        @"line"  : @(NSTabViewBorderTypeLine),
        @"none"  : @(NSTabViewBorderTypeNone),
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

@interface HSUITKElementContainerTabView : NSTabView <NSTabViewDelegate>
@property            int               selfRefCount ;
@property (readonly) LSRefTable        refTable ;
@property            int               callbackRef ;
@property            int               passThroughRef ;
@end

@interface HSUITKElementContainerTabViewItem : NSTabViewItem
@property            int               selfRefCount ;
@end

@implementation HSUITKElementContainerTabView

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

        self.delegate   = self ;
    }
    return self ;
}

- (NSSize)fittingSize {
    return self.minimumSize ;
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
        NSObject *nextInChain = [self nextResponder] ;

        SEL passthroughCallback = NSSelectorFromString(@"performPassthroughCallback:") ;
        while(nextInChain) {
            if ([nextInChain respondsToSelector:passthroughCallback]) {
                [nextInChain performSelectorOnMainThread:passthroughCallback
                                              withObject:@[ self, arguments ]
                                           waitUntilDone:YES] ;
                break ;
            } else {
                nextInChain = [(NSResponder *)nextInChain nextResponder] ;
            }
        }
    }
}

#pragma mark - NSTabViewDelegate -

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    [self callbackHamster:@[ self, tabViewItem]] ;
}

// - (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem;
// - (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem;
// - (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView;

@end

@implementation HSUITKElementContainerTabViewItem

- (instancetype)initWithoutIdentifier {
    self = [self initWithIdentifier:nil] ;
    if (self) {
        _selfRefCount = 0 ;

        // since property is nullable, just clear it -- we only want to allow our own types
        self.view = nil ;
    }

    return self ;
}

// - (void)drawLabel:(BOOL)shouldTruncateLabel inRect:(NSRect)labelRect;

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.container.tabs.new([frame]) -> tableObject
/// Constructor
/// Creates a new tabs container for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the frame for the element.
///
/// Returns:
///  * the tableObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a container element or to a `hs._asm.uitk.window`.
static int tabs_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementContainerTabView *element = [[HSUITKElementContainerTabView alloc] initWithFrame:frameRect];
    if (element) {
        if (lua_gettop(L) != 1) [element setFrameSize:[element fittingSize]] ;
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

static int tabs_item_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    HSUITKElementContainerTabViewItem *element = [[HSUITKElementContainerTabViewItem alloc] initWithoutIdentifier];
    if (element) {
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

/// hs._asm.uitk.element.container.tabs:passthroughCallback([fn | nil]) -> tableObject | fn | nil
/// Method
/// Get or set the pass through callback for the tabs
///
/// Parameters:
///  * `fn` - a function, or an explicit nil to remove, specifying the callback to invoke for elements which do not have their own callbacks assigned.
///
/// Returns:
///  * If an argument is provided, the table object; otherwise the current value.
///
/// Notes:
///  * The pass through callback should expect one or two arguments and return none.
///
///  * The pass through callback is designed so that elements which trigger a callback based on user interaction which do not have a specifically assigned callback can still report user interaction through a common fallback.
///  * The arguments received by the pass through callback will be organized as follows:
///    * the table userdata object
///    * a table containing the arguments provided by the elements callback itself, usually the element userdata followed by any additional arguments as defined for the element's callback function.
///
///  * Note that elements which have a callback that returns a response cannot use this common pass through callback method; in such cases a specific callback must be assigned to the element directly as described in the element's documentation.
static int tabs_passthroughCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTabView *tabView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        tabView.passThroughRef = [skin luaUnref:refTable ref:tabView.passThroughRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            tabView.passThroughRef = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (tabView.passThroughRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:tabView.passThroughRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int tabs_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTabView *tabView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        tabView.callbackRef = [skin luaUnref:refTable ref:tabView.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            tabView.callbackRef = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (tabView.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:tabView.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int tabs_tabViewItems(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementContainerTabView *tabView = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:tabView.tabViewItems] ;
    return 1 ;
}

static int tabs_insertTabViewItem(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, UD_ITEM_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTabView     *tabView = [skin toNSObjectAtIndex:1] ;
    HSUITKElementContainerTabViewItem *item    = [skin toNSObjectAtIndex:2] ;

    NSInteger idx = (lua_gettop(L) == 3) ? (lua_tointeger(L, 3) - 1) : tabView.numberOfTabViewItems ;
    if (idx < 0 || idx > tabView.numberOfTabViewItems) return luaL_argerror(L, 3, "index out of bounds") ;

    [tabView insertTabViewItem:item atIndex:idx] ;
    [skin luaRetain:refTable forNSObject:item] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int tabs_removeTabViewItem(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTabView *tabView = [skin toNSObjectAtIndex:1] ;

    HSUITKElementContainerTabViewItem *item = nil ;

    if (lua_gettop(L) == 1) {
        item = tabView.tabViewItems.lastObject ;
    } else if (lua_type(L, 2) == LUA_TUSERDATA) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, UD_ITEM_TAG, LS_TBREAK] ;
        item = [skin toNSObjectAtIndex:2] ;
    } else if (lua_type(L, 2) == LUA_TNUMBER) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
        NSInteger idx = lua_tointeger(L, 2) - 1 ;
        if (idx < 0 || idx >= tabView.numberOfTabViewItems) return luaL_argerror(L, lua_gettop(L), "index out of bounds") ;
        item = (HSUITKElementContainerTabViewItem *)[tabView tabViewItemAtIndex:idx] ;
    } else {
        return luaL_argerror(L, 2, "expected integer index or tab item userdata") ;
    }

    if ([tabView.tabViewItems containsObject:item]) {
        [skin luaRelease:refTable forNSObject:item] ;
        [tabView removeTabViewItem:item] ;
    } else {
        return luaL_argerror(L, 2, "item specified is not a member of this tabs container") ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int tabs_indexOfTabViewItem(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, UD_ITEM_TAG, LS_TBREAK] ;
    HSUITKElementContainerTabView     *tabView = [skin toNSObjectAtIndex:1] ;
    HSUITKElementContainerTabViewItem *item    = [skin toNSObjectAtIndex:2] ;

    lua_pushinteger(L, [tabView indexOfTabViewItem:item] + 1) ;
    return 1 ;
}

static int tabs_tabViewItemAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKElementContainerTabView *tabView = [skin toNSObjectAtIndex:1] ;

    NSInteger idx   = lua_tointeger(L, 2) ;
    NSInteger count = tabView.numberOfTabViewItems ;
    if (idx < 0) idx = count + 1 + idx ;
    if (idx < 1 || idx > count) {
        lua_pushnil(L) ;
    } else {
        [skin pushNSObject:[tabView tabViewItemAtIndex:(idx - 1)]] ;
    }
    return 1 ;
}

static int tabs_tabViewItemAtPoint(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    HSUITKElementContainerTabView *tabView = [skin toNSObjectAtIndex:1] ;

    NSPoint point = [skin tableToPointAtIndex:2] ;
    [skin pushNSObject:[tabView tabViewItemAtPoint:point]] ;
    return 1 ;
}

static int tabs_font(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTabView *tabView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:tabView.font] ;
    } else {
        tabView.font = [skin luaObjectAtIndex:2 toClass:"NSFont"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tabs_controlSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTabView *tabView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = CONTROL_SIZE[key] ;
        if (value) {
            tabView.controlSize = [value unsignedIntegerValue] ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [CONTROL_SIZE.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        NSNumber *value = @(tabView.controlSize) ;
        NSArray *temp = [CONTROL_SIZE allKeysForObject:value];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized tabs size %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    }
    return 1;
}

static int tabs_tabPosition(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTabView *tabView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = TAB_POSITION[key] ;
        if (value) {
            tabView.tabPosition = [value unsignedIntegerValue] ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [TAB_POSITION.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        NSNumber *value ;
        value = @(tabView.tabPosition) ;
        NSArray *temp = [TAB_POSITION allKeysForObject:value];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized tabs position %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    }
    return 1;
}

static int tabs_tabViewBorderType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTabView *tabView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = TAB_BORDER[key] ;
        if (value) {
            tabView.tabViewBorderType = [value unsignedIntegerValue] ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [TAB_BORDER.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        NSNumber *value ;
        value = @(tabView.tabViewBorderType) ;
        NSArray *temp = [TAB_BORDER allKeysForObject:value];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized tabs border type %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    }
    return 1;
}

static int tabs_allowsTruncatedLabels(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTabView *tabView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, tabView.allowsTruncatedLabels) ;
    } else {
        tabView.allowsTruncatedLabels = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tabs_drawsBackground(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTabView *tabView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, tabView.drawsBackground) ;
    } else {
        tabView.drawsBackground = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tabs_selectTab(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTabView *tabView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
      [skin pushNSObject:tabView.selectedTabViewItem] ;
    } else {
        if (lua_type(L, 2) == LUA_TSTRING) {
            NSString *string = [skin toNSObjectAtIndex:2] ;
            if ([string isEqualToString:@"first"]) {
                [tabView selectFirstTabViewItem:tabView] ;
            } else if ([string isEqualToString:@"last"]) {
                [tabView selectLastTabViewItem:tabView] ;
            } else if ([string isEqualToString:@"next"]) {
                [tabView selectNextTabViewItem:tabView] ;
            } else if ([string isEqualToString:@"previous"]) {
                [tabView selectPreviousTabViewItem:tabView] ;
            } else {
                return luaL_argerror(L, 2, "expected first, last, next, or previous") ;
            }
        } else if (lua_type(L, 2) == LUA_TUSERDATA) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, UD_ITEM_TAG, LS_TBREAK] ;
            HSUITKElementContainerTabViewItem *item = [skin toNSObjectAtIndex:2] ;
            [tabView selectTabViewItem:item] ;
        } else if (lua_type(L, 2) == LUA_TNUMBER && lua_isinteger(L, 2)) {
            NSInteger idx   = lua_tointeger(L, 2) ;
            NSInteger count = tabView.numberOfTabViewItems ;
            if (idx < 0) idx = count + 1 + idx ;
            if (idx < 1 || idx > count) {
                return luaL_argerror(L, 2, "index out of bounds") ;
            }
            [tabView selectTabViewItemAtIndex:(idx - 1)] ;
        } else {
            return luaL_argerror(L, 2, "expected integer index, string, or tab item userdata") ;
        }

        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tabs_numberOfTabViewItems(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementContainerTabView *tabView = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, tabView.numberOfTabViewItems) ;
    return 1 ;
}

static int tabs_contentRect(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementContainerTabView *tabView = [skin toNSObjectAtIndex:1] ;

    [skin pushNSRect:tabView.contentRect] ;
    return 1 ;
}

static int tabs_minimumSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementContainerTabView *tabView = [skin toNSObjectAtIndex:1] ;

    [skin pushNSSize:tabView.minimumSize] ;
    return 1 ;
}

// - (void)addTabViewItem:(NSTabViewItem *)tabViewItem;
// - (NSInteger)indexOfTabViewItemWithIdentifier:(id)identifier;
// - (void)selectTabViewItemWithIdentifier:(id)identifier;
// - (void)takeSelectedTabViewItemFromSender:(id)sender;

#pragma mark - TabViewItem Methods -

static int tabs_item_index(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TBREAK] ;
    HSUITKElementContainerTabViewItem *item = [skin toNSObjectAtIndex:1] ;

    HSUITKElementContainerTabView *tabView = (HSUITKElementContainerTabView *)item.tabView ;

    if (tabView) {
        lua_pushinteger(L, [tabView indexOfTabViewItem:item] + 1) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int tabs_item_sizeOfLabel(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTabViewItem *item = [skin toNSObjectAtIndex:1] ;
    BOOL computeMin = (lua_gettop(L) == 2) ? (BOOL)(lua_toboolean(L, 2)) : NO ;

    [skin pushNSSize:[item sizeOfLabel:computeMin]] ;
    return 1 ;
}

// // Used by NSTabViewController when promoting tabs into toolbar -- otherwise we have to
// // override drawLabel:inRect: to take advantage of this
//
// static int tabs_item_image(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
//     HSUITKElementContainerTabViewItem *item = [skin toNSObjectAtIndex:1] ;
//
//     if (lua_gettop(L) == 1) {
//         [skin pushNSObject:item.image] ;
//     } else {
//         if (lua_type(L, 2) == LUA_TNIL) {
//             item.image = nil ;
//         } else {
//             [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
//             item.image = [skin toNSObjectAtIndex:2] ;
//         }
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }

static int tabs_item_color(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTabViewItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.color] ;
    } else {
        item.color = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tabs_item_view(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTabViewItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.view withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            [skin luaRelease:refTable forNSObject:item.view] ;
            item.view = nil ;
        } else {
            NSView *view = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
            if (!view || !oneOfOurs(view)) {
                return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
            }

            [skin luaRelease:refTable forNSObject:item.view] ;
            item.view = view ;
            [skin luaRetain:refTable forNSObject:item.view] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tabs_item_label(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTabViewItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if ([item.label isEqualToString:@""]) {
            lua_pushnil(L) ;
        } else {
            [skin pushNSObject:item.label] ;
        }
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            item.label = @"" ;
        } else {
            item.label = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tabs_item_toolTip(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTabViewItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.toolTip] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            item.toolTip = nil ;
        } else {
            item.toolTip = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tabs_item_tabState(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TBREAK] ;
    HSUITKElementContainerTabViewItem *item = [skin toNSObjectAtIndex:1] ;

    switch(item.tabState) {
        case NSBackgroundTab: lua_pushstring(L, "background") ; break ;
        case NSPressedTab:    lua_pushstring(L, "pressed") ; break ;
        case NSSelectedTab:   lua_pushstring(L, "selected") ; break ;
        default:
            lua_pushfstring(L, "unrecognized %d", item.tabState) ;
    }

    return 1 ;
}

static int tabs_item_tabView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TBREAK] ;
    HSUITKElementContainerTabViewItem *item = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:item.tabView withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

// @property(strong) id identifier;
// @property(weak) NSView *initialFirstResponder;

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementContainerTabView(lua_State *L, id obj) {
    HSUITKElementContainerTabView *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementContainerTabView *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementContainerTabView(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementContainerTabView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementContainerTabView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushHSUITKElementContainerTabViewItem(lua_State *L, id obj) {
    HSUITKElementContainerTabViewItem *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementContainerTabViewItem *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_ITEM_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementContainerTabViewItem(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementContainerTabViewItem *value ;
    if (luaL_testudata(L, idx, UD_ITEM_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementContainerTabViewItem, L, idx, UD_ITEM_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_ITEM_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     HSUITKElementContainerTabView *obj = [skin luaObjectAtIndex:1 toClass:"HSUITKElementContainerTabView"] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int ud_item_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementContainerTabViewItem *obj = [skin luaObjectAtIndex:1 toClass:"HSUITKElementContainerTabViewItem"] ;
    NSString *title = obj.label ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_ITEM_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if ((luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) ||
        (luaL_testudata(L, 1, UD_ITEM_TAG) && luaL_testudata(L, 2, UD_ITEM_TAG))
    ) {
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
    HSUITKElementContainerTabView *obj = get_objectFromUserdata(__bridge_transfer HSUITKElementContainerTabView, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef    = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj.passThroughRef = [skin luaUnref:refTable ref:obj.passThroughRef] ;
            for (HSUITKElementContainerTabViewItem *item in obj.tabViewItems) [skin luaRelease:refTable forNSObject:item] ;

            obj = nil ;
        }
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int ud_item_gc(lua_State* L) {
    HSUITKElementContainerTabViewItem *obj = get_objectFromUserdata(__bridge_transfer HSUITKElementContainerTabViewItem, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
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
    {"passthroughCallback", tabs_passthroughCallback},
    {"callback",            tabs_callback},
    {"font",                tabs_font},
    {"controlSize",         tabs_controlSize},
    {"tabPosition",         tabs_tabPosition},
    {"borderType",          tabs_tabViewBorderType},
    {"truncatedLabels",     tabs_allowsTruncatedLabels},
    {"drawsBackground",     tabs_drawsBackground},
    {"selectedTab",         tabs_selectTab},

    {"tabs",                tabs_tabViewItems},
    {"insert",              tabs_insertTabViewItem},
    {"remove",              tabs_removeTabViewItem},
    {"indexOf",             tabs_indexOfTabViewItem},
    {"tabAtIndex",          tabs_tabViewItemAtIndex},
    {"tabAtPoint",          tabs_tabViewItemAtPoint},
    {"itemCount",           tabs_numberOfTabViewItems},
    {"contentRect",         tabs_contentRect},
    {"minimumSize",         tabs_minimumSize},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

static const luaL_Reg ud_item_metaLib[] = {
//     {"image",     tabs_item_image},
    {"color",     tabs_item_color},
    {"element",   tabs_item_view},
    {"label",     tabs_item_label},
    {"toolTip",   tabs_item_toolTip},

    {"index",     tabs_item_index},
    {"labelSize", tabs_item_sizeOfLabel},
    {"state",     tabs_item_tabState},
    {"container", tabs_item_tabView},

    {"__tostring", ud_item_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       ud_item_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",     tabs_new},
    {"newItem", tabs_item_new},
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_element_libcontainer_tabs(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerObject:UD_ITEM_TAG objectFunctions:ud_item_metaLib] ;

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKElementContainerTabView  forClass:"HSUITKElementContainerTabView"];
    [skin registerLuaObjectHelper:toHSUITKElementContainerTabView forClass:"HSUITKElementContainerTabView"
                                                       withUserdataMapping:USERDATA_TAG];

    [skin registerPushNSHelper:pushHSUITKElementContainerTabViewItem  forClass:"HSUITKElementContainerTabViewItem"];
    [skin registerLuaObjectHelper:toHSUITKElementContainerTabViewItem forClass:"HSUITKElementContainerTabViewItem"
                                                           withUserdataMapping:UD_ITEM_TAG];

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"passthroughCallback",
        @"callback",
        @"font",
        @"controlSize",
        @"tabPosition",
        @"borderType",
        @"truncatedLabels",
        @"drawsBackground",
        @"selectedTab",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    // lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    luaL_getmetatable(L, UD_ITEM_TAG) ;
    [skin pushNSObject:@[
//         @"image",
        @"color",
        @"element",
        @"label",
        @"toolTip",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}

