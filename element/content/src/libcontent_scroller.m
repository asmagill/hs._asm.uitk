@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.content.scroller" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *BORDER_TYPE ;
static NSDictionary *SCROLL_ELASTICITY ;
static NSDictionary *SCROLLER_KNOB_STYLE ;
static NSDictionary *SCROLLER_STYLE ;
static NSDictionary *FIND_BAR_POSITION ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    BORDER_TYPE = @{
        @"bezel"  : @(NSBezelBorder),
        @"groove" : @(NSGrooveBorder),
        @"line"   : @(NSLineBorder),
        @"none"   : @(NSNoBorder),
    } ;

    SCROLL_ELASTICITY = @{
        @"automatic" : @(NSScrollElasticityAutomatic),
        @"none"      : @(NSScrollElasticityNone),
        @"allowed"   : @(NSScrollElasticityAllowed),
    };

    SCROLLER_KNOB_STYLE = @{
        @"default" : @(NSScrollerKnobStyleDefault),
        @"dark"    : @(NSScrollerKnobStyleDark),
        @"light"   : @(NSScrollerKnobStyleLight),
    } ;

    SCROLLER_STYLE = @{
        @"legacy"  : @(NSScrollerStyleLegacy),
        @"overlay" : @(NSScrollerStyleOverlay),
    } ;

    FIND_BAR_POSITION = @{
        @"aboveRuler"   : @(NSScrollViewFindBarPositionAboveHorizontalRuler),
        @"aboveContent" : @(NSScrollViewFindBarPositionAboveContent),
        @"belowContent" : @(NSScrollViewFindBarPositionBelowContent),
    };
}

@interface HSUITKElementScrollView : NSScrollView
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ; // in this case, it's the passthrough callback for subviews
                                              // with no callbacks, but we keep the name since this is
                                              // checked in _view for the common methods
@property            BOOL       documentTracksWidth ;
@end

BOOL oneOfOurs(NSView *obj) {
    return [obj isKindOfClass:[NSView class]]  &&
           [obj respondsToSelector:NSSelectorFromString(@"selfRefCount")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setSelfRefCount:")] &&
           [obj respondsToSelector:NSSelectorFromString(@"refTable")] &&
           [obj respondsToSelector:NSSelectorFromString(@"callbackRef")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setCallbackRef:")] ;
}

@implementation HSUITKElementScrollView
- (instancetype)initWithFrame:(NSRect)frameRect {
    @try {
        self = [super initWithFrame:frameRect] ;
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:new - %@", USERDATA_TAG, exception.reason]] ;
        self = nil ;
    }

    if (self) {
        _callbackRef         = LUA_NOREF ;
        _refTable            = refTable ;
        _selfRefCount        = 0 ;
        _documentTracksWidth = YES ;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(frameChangedNotification:)
                                                     name:NSViewFrameDidChangeNotification
                                                   object:nil] ;
    }
    return self ;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSViewFrameDidChangeNotification
                                                  object:nil] ;
}

// Follow the Hammerspoon convention
- (BOOL)isFlipped { return YES; }

// Override if we want to provide our own ruler objects
// @property(class) Class rulerViewClass;

// NOTE: support for _documentTracksWidth

- (void)updateDocumentFrameMinimums {
    if (self.documentView && oneOfOurs(self.documentView)) {
        NSSize documentSize = self.documentView.frame.size ;
        NSSize contentSize  = self.contentSize ;
        // width is more obvious because it impacts line wrapping... document height will always be larger if
        // content is longer than fits in one "page" and requires the vertical scroller.
        //
        // TODO: need to consider/test how to best handle horizontal scroller when it's enabled, or is it
        // sufficient to tell user just to disable documentTracksWidth and manage it by themselves?
        // What about "screen wrap" (what this implements) vs no wrap when it's text? Same?
        documentSize.width  = contentSize.width ;
        if (documentSize.height < contentSize.height) documentSize.height = contentSize.height ;
        [self.documentView setFrameSize:documentSize] ;
    }
}
- (void)viewDidMoveToSuperview {
    if (_documentTracksWidth && self.superview) [self updateDocumentFrameMinimums] ;
}

- (void)viewDidMoveToWindow {
    if (_documentTracksWidth && self.window) [self updateDocumentFrameMinimums] ;
}

- (void)frameChangedNotification:(NSNotification *)notification {
    if (_documentTracksWidth && (self.window || self.superview)) {
        NSView *targetView = notification.object ;
        if (targetView) {
            if ([targetView isEqualTo:self]) [self updateDocumentFrameMinimums] ;
        }
    }
}

// NOTE: Passthrough Callback Support

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

#pragma mark - Module Functions -

/// hs._asm.uitk.element.content.scroller.new([frame]) -> scrollerObject
/// Constructor
/// Creates a new scroller content element for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the frame for the element.
///
/// Returns:
///  * the scrollerObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a content element or to a `hs._asm.uitk.window`.
static int scroller_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementScrollView *element = [[HSUITKElementScrollView alloc] initWithFrame:frameRect];
    if (element) {
        if (lua_gettop(L) != 1) [element setFrameSize:[element fittingSize]] ;
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

/// hs._asm.uitk.element.content.scroller:passthroughCallback([fn | nil]) -> contentObject | fn | nil
/// Method
/// Get or set the pass through callback for the content.
///
/// Parameters:
///  * `fn` - a function, or an explicit nil to remove, specifying the callback to invoke for elements which do not have their own callbacks assigned.
///
/// Returns:
///  * If an argument is provided, the content object; otherwise the current value.
///
/// Notes:
///  * The pass through callback should expect one or two arguments and return none.
///
///  * The pass through callback is designed so that elements which trigger a callback based on user interaction which do not have a specifically assigned callback can still report user interaction through a common fallback.
///  * The arguments received by the pass through callback will be organized as follows:
///    * the content userdata object
///    * a table containing the arguments provided by the elements callback itself, usually the element userdata followed by any additional arguments as defined for the element's callback function.
///
///  * Note that elements which have a callback that returns a response cannot use this common pass through callback method; in such cases a specific callback must be assigned to the element directly as described in the element's documentation.
static int scroller_passthroughCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        element.callbackRef = [skin luaUnref:refTable ref:element.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            element.callbackRef = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (element.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:element.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int scroller_documentTracksWidthSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.documentTracksWidth) ;
    } else {
        element.documentTracksWidth = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_allowsMagnification(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.allowsMagnification) ;
    } else {
        element.allowsMagnification = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_autohidesScrollers(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.autohidesScrollers) ;
    } else {
        element.autohidesScrollers = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_automaticallyAdjustsContentInsets(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.automaticallyAdjustsContentInsets) ;
    } else {
        element.automaticallyAdjustsContentInsets = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_drawsBackground(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.drawsBackground) ;
    } else {
        element.drawsBackground = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_hasHorizontalRuler(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.hasHorizontalRuler) ;
    } else {
        element.hasHorizontalRuler = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_hasHorizontalScroller(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.hasHorizontalScroller) ;
    } else {
        element.hasHorizontalScroller = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_hasVerticalRuler(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.hasVerticalRuler) ;
    } else {
        element.hasVerticalRuler = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_hasVerticalScroller(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.hasVerticalScroller) ;
    } else {
        element.hasVerticalScroller = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_rulersVisible(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.rulersVisible) ;
    } else {
        element.rulersVisible = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_scrollsDynamically(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.scrollsDynamically) ;
    } else {
        element.scrollsDynamically = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_usesPredominantAxisScrolling(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.usesPredominantAxisScrolling) ;
    } else {
        element.usesPredominantAxisScrolling = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_horizontalLineScroll(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.horizontalLineScroll) ;
    } else {
        element.horizontalLineScroll = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_horizontalPageScroll(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.horizontalPageScroll) ;
    } else {
        element.horizontalPageScroll = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_lineScroll(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.lineScroll) ;
    } else {
        element.lineScroll = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_magnification(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.magnification) ;
    } else {
        element.magnification = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_maxMagnification(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.maxMagnification) ;
    } else {
        element.maxMagnification = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_minMagnification(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.minMagnification) ;
    } else {
        element.minMagnification = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_pageScroll(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.pageScroll) ;
    } else {
        element.pageScroll = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_verticalLineScroll(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.verticalLineScroll) ;
    } else {
        element.verticalLineScroll = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_verticalPageScroll(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.verticalPageScroll) ;
    } else {
        element.verticalPageScroll = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_backgroundColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:element.backgroundColor] ;
    } else {
        element.backgroundColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_borderType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(element.borderType) ;
        NSArray  *temp   = [BORDER_TYPE allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized border type %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = BORDER_TYPE[key] ;
        if (value) {
            element.borderType = value.unsignedIntegerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[BORDER_TYPE allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int scroller_horizontalScrollElasticity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(element.horizontalScrollElasticity) ;
        NSArray  *temp   = [SCROLL_ELASTICITY allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized scroll elasticity type %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = SCROLL_ELASTICITY[key] ;
        if (value) {
            element.horizontalScrollElasticity = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[SCROLL_ELASTICITY allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int scroller_verticalScrollElasticity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(element.verticalScrollElasticity) ;
        NSArray  *temp   = [SCROLL_ELASTICITY allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized scroll elasticity type %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = SCROLL_ELASTICITY[key] ;
        if (value) {
            element.verticalScrollElasticity = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[SCROLL_ELASTICITY allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int scroller_scrollerKnobStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(element.scrollerKnobStyle) ;
        NSArray  *temp   = [SCROLLER_KNOB_STYLE allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized scroll knob style %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = SCROLLER_KNOB_STYLE[key] ;
        if (value) {
            element.scrollerKnobStyle = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[SCROLLER_KNOB_STYLE allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int scroller_scrollerStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(element.scrollerStyle) ;
        NSArray  *temp   = [SCROLLER_STYLE allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized scroller style %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = SCROLLER_STYLE[key] ;
        if (value) {
            element.scrollerStyle = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[SCROLLER_STYLE allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int scroller_findBarPosition(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(element.findBarPosition) ;
        NSArray  *temp   = [FIND_BAR_POSITION allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized find bar position %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = FIND_BAR_POSITION[key] ;
        if (value) {
            element.findBarPosition = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[FIND_BAR_POSITION allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int scroller_contentInsets(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TTABLE | LS_TNIL | LS_TOPTIONAL,
                    LS_TNUMBER | LS_TNIL | LS_TOPTIONAL,
                    LS_TNUMBER | LS_TNIL | LS_TOPTIONAL,
                    LS_TNUMBER | LS_TNIL | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_newtable(L) ;
        lua_pushnumber(L, element.contentInsets.top) ;    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushnumber(L, element.contentInsets.left) ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushnumber(L, element.contentInsets.right) ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushnumber(L, element.contentInsets.bottom) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    } else {
        NSEdgeInsets newInset = NSEdgeInsetsZero ;
        if (lua_type(L, 2) == LUA_TTABLE) {

            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
            if (lua_geti(L, -1, 1) == LUA_TNUMBER) {
                newInset.top = lua_tonumber(L, -1) ;
            } else if (lua_type(L, -1) != LUA_TNIL) {
                return luaL_argerror(L, 2, "expected table of numbers") ;
            }
            lua_pop(L, 1) ;
            if (lua_geti(L, -1, 2) == LUA_TNUMBER) {
                newInset.left = lua_tonumber(L, -1) ;
            } else if (lua_type(L, -1) != LUA_TNIL) {
                return luaL_argerror(L, 2, "expected table of numbers") ;
            }
            lua_pop(L, 1) ;
            if (lua_geti(L, -1, 3) == LUA_TNUMBER) {
                newInset.right = lua_tonumber(L, -1) ;
            } else if (lua_type(L, -1) != LUA_TNIL) {
                return luaL_argerror(L, 2, "expected table of numbers") ;
            }
            lua_pop(L, 1) ;
            if (lua_geti(L, -1, 4) == LUA_TNUMBER) {
                newInset.bottom = lua_tonumber(L, -1) ;
            } else if (lua_type(L, -1) != LUA_TNIL) {
                return luaL_argerror(L, 2, "expected table of numbers") ;
            }
            lua_pop(L, 1) ;
        } else {
            switch(lua_gettop(L)) {
                case 5: if (lua_type(L, 5) == LUA_TNUMBER) newInset.bottom = lua_tonumber(L, 5) ;
                case 4: if (lua_type(L, 4) == LUA_TNUMBER) newInset.right  = lua_tonumber(L, 4) ;
                case 3: if (lua_type(L, 3) == LUA_TNUMBER) newInset.left   = lua_tonumber(L, 3) ;
                case 2: if (lua_type(L, 2) == LUA_TNUMBER) newInset.top    = lua_tonumber(L, 2) ;
            }
        }

        element.contentInsets = newInset ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_scrollerInsets(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TTABLE | LS_TNIL | LS_TOPTIONAL,
                    LS_TNUMBER | LS_TNIL | LS_TOPTIONAL,
                    LS_TNUMBER | LS_TNIL | LS_TOPTIONAL,
                    LS_TNUMBER | LS_TNIL | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_newtable(L) ;
        lua_pushnumber(L, element.scrollerInsets.top) ;    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushnumber(L, element.scrollerInsets.left) ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushnumber(L, element.scrollerInsets.right) ;  lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushnumber(L, element.scrollerInsets.bottom) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    } else {
        NSEdgeInsets newInset = NSEdgeInsetsZero ;
        if (lua_type(L, 2) == LUA_TTABLE) {

            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
            if (lua_geti(L, -1, 1) == LUA_TNUMBER) {
                newInset.top = lua_tonumber(L, -1) ;
            } else if (lua_type(L, -1) != LUA_TNIL) {
                return luaL_argerror(L, 2, "expected table of numbers") ;
            }
            lua_pop(L, 1) ;
            if (lua_geti(L, -1, 2) == LUA_TNUMBER) {
                newInset.left = lua_tonumber(L, -1) ;
            } else if (lua_type(L, -1) != LUA_TNIL) {
                return luaL_argerror(L, 2, "expected table of numbers") ;
            }
            lua_pop(L, 1) ;
            if (lua_geti(L, -1, 3) == LUA_TNUMBER) {
                newInset.right = lua_tonumber(L, -1) ;
            } else if (lua_type(L, -1) != LUA_TNIL) {
                return luaL_argerror(L, 2, "expected table of numbers") ;
            }
            lua_pop(L, 1) ;
            if (lua_geti(L, -1, 4) == LUA_TNUMBER) {
                newInset.bottom = lua_tonumber(L, -1) ;
            } else if (lua_type(L, -1) != LUA_TNIL) {
                return luaL_argerror(L, 2, "expected table of numbers") ;
            }
            lua_pop(L, 1) ;
        } else {
            switch(lua_gettop(L)) {
                case 5: if (lua_type(L, 5) == LUA_TNUMBER) newInset.bottom = lua_tonumber(L, 5) ;
                case 4: if (lua_type(L, 4) == LUA_TNUMBER) newInset.right  = lua_tonumber(L, 4) ;
                case 3: if (lua_type(L, 3) == LUA_TNUMBER) newInset.left   = lua_tonumber(L, 3) ;
                case 2: if (lua_type(L, 2) == LUA_TNUMBER) newInset.top    = lua_tonumber(L, 2) ;
            }
        }

        element.scrollerInsets = newInset ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_documentView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:element.documentView withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            [skin luaRelease:refTable forNSObject:element.documentView] ;
            element.documentView = nil ;
        } else {
            NSView *document = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
            if (!document || !oneOfOurs(document)) {
                return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
            }
            [skin luaRelease:refTable forNSObject:element.documentView] ;
            [skin luaRetain:refTable forNSObject:document] ;
            element.documentView = document ;

            if (element.documentTracksWidth) {
                NSSize documentSize = document.frame.size ;
                NSSize contentSize  = element.contentSize ;
                documentSize.width  = contentSize.width ;
                if (documentSize.height < contentSize.height) documentSize.height = contentSize.height ;
                [document setFrameSize:documentSize] ;
            }
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int scroller_contentSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    [skin pushNSSize:element.contentSize] ;
    return 1 ;
}

static int scroller_documentVisibleRect(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    [skin pushNSRect:element.documentVisibleRect] ;
    return 1 ;
}

static int scroller_flashScrollers(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;

    [element flashScrollers] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int scroller_magnifyToFitRect(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;
    NSRect                   rect     = [skin tableToRectAtIndex:2] ;

    [element magnifyToFitRect:rect] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int scroller_setMagnificationCenteredAtPoint(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TTABLE, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;
    CGFloat                  zoom     = lua_tonumber(L, 2) ;
    NSPoint                  point    = [skin tableToPointAtIndex:3] ;

    [element setMagnification:zoom centeredAtPoint:point] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int scroller_scrollPoint(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;
    NSPoint                  point    = [skin tableToPointAtIndex:2] ;

    if (element.documentView) {
        [element.documentView scrollPoint:point] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int scroller_scrollRectToVisible(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
    HSUITKElementScrollView *element = [skin toNSObjectAtIndex:1] ;
    NSRect                   rect     = [skin tableToRectAtIndex:2] ;

    if (element.documentView) {
        [element.documentView scrollRectToVisible:rect] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

// @property(strong) NSCursor *documentCursor;

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementScrollView(lua_State *L, id obj) {
    HSUITKElementScrollView *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementScrollView *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementScrollViewFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementScrollView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementScrollView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_gc(lua_State* L) {
    HSUITKElementScrollView *obj = get_objectFromUserdata(__bridge_transfer HSUITKElementScrollView, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef         = [skin luaUnref:refTable ref:obj.callbackRef] ;
            [skin luaRelease:refTable forNSObject:obj.documentView] ;
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
    {"passthroughCallback",        scroller_passthroughCallback},
    {"allowsMagnification",        scroller_allowsMagnification},
    {"autohidesScrollers",         scroller_autohidesScrollers},
    {"autoAdjustsContentInsets",   scroller_automaticallyAdjustsContentInsets},
    {"drawsBackground",            scroller_drawsBackground},
    {"horizontalRuler",            scroller_hasHorizontalRuler},
    {"horizontalScroller",         scroller_hasHorizontalScroller},
    {"verticalRuler",              scroller_hasVerticalRuler},
    {"verticalScroller",           scroller_hasVerticalScroller},
    {"rulersVisible",              scroller_rulersVisible},
    {"scrollsDynamically",         scroller_scrollsDynamically},
    {"predominantAxisScrolling",   scroller_usesPredominantAxisScrolling},
    {"horizontalLineScroll",       scroller_horizontalLineScroll},
    {"horizontalPageScroll",       scroller_horizontalPageScroll},
    {"lineScroll",                 scroller_lineScroll},
    {"magnification",              scroller_magnification},
    {"maxMagnification",           scroller_maxMagnification},
    {"minMagnification",           scroller_minMagnification},
    {"pageScroll",                 scroller_pageScroll},
    {"verticalLineScroll",         scroller_verticalLineScroll},
    {"verticalPageScroll",         scroller_verticalPageScroll},
    {"backgroundColor",            scroller_backgroundColor},
    {"borderType",                 scroller_borderType},
    {"horizontalScrollElasticity", scroller_horizontalScrollElasticity},
    {"verticalScrollElasticity",   scroller_verticalScrollElasticity},
    {"scrollerKnobStyle",          scroller_scrollerKnobStyle},
    {"scrollerStyle",              scroller_scrollerStyle},
    {"findBarPosition",            scroller_findBarPosition},
    {"contentInsets",              scroller_contentInsets},
    {"scrollerInsets",             scroller_scrollerInsets},
    {"document",                   scroller_documentView},
    {"contentSize",                scroller_contentSize},
    {"documentVisibleRect",        scroller_documentVisibleRect},
    {"documentTracksWidth",         scroller_documentTracksWidthSize},
    {"flashScrollers",             scroller_flashScrollers},
    {"magnifyToFit",               scroller_magnifyToFitRect},
    {"magnifyCenteredAt",          scroller_setMagnificationCenteredAtPoint},
    {"scrollPoint",                scroller_scrollPoint},
    {"scrollToRect",               scroller_scrollRectToVisible},

// other metamethods inherited from _control and _view
    {"__gc",                userdata_gc},
    {NULL,    NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", scroller_new},
    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_element_libcontent_scroller(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKElementScrollView         forClass:"HSUITKElementScrollView"];
    [skin registerLuaObjectHelper:toHSUITKElementScrollViewFromLua forClass:"HSUITKElementScrollView"
                                                        withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through content metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"passthroughCallback",
        @"allowsMagnification",
        @"autohidesScrollers",
        @"autoAdjustsContentInsets",
        @"drawsBackground",
        @"horizontalRuler",
        @"horizontalScroller",
        @"verticalRuler",
        @"verticalScroller",
        @"rulersVisible",
        @"scrollsDynamically",
        @"predominantAxisScrolling",
        @"horizontalLineScroll",
        @"horizontalPageScroll",
        @"lineScroll",
        @"magnification",
        @"maxMagnification",
        @"minMagnification",
        @"pageScroll",
        @"verticalLineScroll",
        @"verticalPageScroll",
        @"backgroundColor",
        @"borderType",
        @"horizontalScrollElasticity",
        @"verticalScrollElasticity",
        @"scrollerKnobStyle",
        @"scrollerStyle",
        @"findBarPosition",
        @"contentInsets",
        @"scrollerInsets",
        @"document",
        @"documentTracksWidth",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pop(L, 1) ;

    return 1;
}
