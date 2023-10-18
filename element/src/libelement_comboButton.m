@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.comboButton" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *IMAGE_SCALING_TYPES ;
static NSDictionary *COMBO_BUTTON_STYLE ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    IMAGE_SCALING_TYPES = @{
        @"proportionallyDown"     : @(NSImageScaleProportionallyDown),
        @"axesIndependently"      : @(NSImageScaleAxesIndependently),
        @"none"                   : @(NSImageScaleNone),
        @"proportionallyUpOrDown" : @(NSImageScaleProportionallyUpOrDown),
    } ;
    if (@available(macOS 13, *)) {
        COMBO_BUTTON_STYLE = @{
            @"split" : @(NSComboButtonStyleSplit),
            @"unified" : @(NSComboButtonStyleUnified),
        } ;
    } else {
        COMBO_BUTTON_STYLE = @{
        } ;
    }
}

@interface NSMenu (assignmentSharing)
@property (weak) NSView *assignedTo ;
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
@interface HSUITKElementComboButton : NSComboButton
#pragma clang diagnostic pop
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;
@property            NSMenu     *initialMenu ;
@end

@implementation HSUITKElementComboButton

- (void)commonInit {
    _callbackRef    = LUA_NOREF ;
    _refTable       = refTable ;
    _selfRefCount   = 0 ;
    _initialMenu    = self.menu ; // since we created it with nil, the placeholder will
                                  // be what we reset it to when the user assigns it nil

    self.target     = self ;
    self.action     = @selector(performCallback:) ;
    self.continuous = NO ;
}

+ (instancetype)comboButtonWithTitle:(NSString *)title andImage:(NSImage *)image {
    HSUITKElementComboButton *button = nil ;
    if (@available(macOS 13, *)) {
        button = [HSUITKElementComboButton comboButtonWithTitle:title
                                                           image:image
                                                            menu:nil
                                                          target:nil
                                                          action:nil] ;
    }
    if (button) {
        [button commonInit] ;
    }

    return button ;
}

+ (instancetype)comboButtonWithTitle:(NSString *)title {
    HSUITKElementComboButton *button = nil ;
    if (@available(macOS 13, *)) {
        button = [HSUITKElementComboButton comboButtonWithTitle:title
                                                            menu:nil
                                                          target:nil
                                                          action:nil] ;
    }
    if (button) {
        [button commonInit] ;
    }

    return button ;
}

+ (instancetype)comboButtonWithImage:(NSImage *)image {
    HSUITKElementComboButton *button = nil ;
    if (@available(macOS 13, *)) {
        button = [HSUITKElementComboButton comboButtonWithImage:image
                                                            menu:nil
                                                          target:nil
                                                          action:nil] ;
    }
    if (button) {
        [button commonInit] ;
    }

    return button ;
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

@end

#pragma mark - Module Functions -

static int comboButton_newButtonWithTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *title = [skin toNSObjectAtIndex:1] ;

    HSUITKElementComboButton *button = [HSUITKElementComboButton comboButtonWithTitle:title] ;

    if (button) {
        [skin pushNSObject:button] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int comboButton_newButtonWithTitleAndImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
    NSString *title = [skin toNSObjectAtIndex:1] ;
    NSImage  *image = [skin toNSObjectAtIndex:2] ;

    HSUITKElementComboButton *button = [HSUITKElementComboButton comboButtonWithTitle:title
                                                                               andImage:image] ;

    if (button) {
        [skin pushNSObject:button] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int comboButton_newButtonWithImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, "hs.image", LS_TBREAK] ;
    NSImage  *image = [skin toNSObjectAtIndex:1] ;

    HSUITKElementComboButton *button = [HSUITKElementComboButton comboButtonWithImage:image] ;

    if (button) {
        [skin pushNSObject:button] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

static int comboButton_title(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementComboButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:button.title] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
                button.title = @"" ;
        } else {
            button.title = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int comboButton_imageScaling(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementComboButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *imageScaling = @(((NSButtonCell *)button.cell).imageScaling) ;
        NSArray *temp = [IMAGE_SCALING_TYPES allKeysForObject:imageScaling];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized image scaling %@ -- notify developers", USERDATA_TAG, imageScaling]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *imageScaling = IMAGE_SCALING_TYPES[key] ;
        if (imageScaling) {
            ((NSButtonCell *)button.cell).imageScaling = [imageScaling unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[IMAGE_SCALING_TYPES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int comboButton_style(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementComboButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *style = @(button.style) ;
        NSArray *temp = [COMBO_BUTTON_STYLE allKeysForObject:style];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized style %@ -- notify developers", USERDATA_TAG, style]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *style = COMBO_BUTTON_STYLE[key] ;
        if (style) {
            button.style = [style integerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[COMBO_BUTTON_STYLE allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int comboButton_menu(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementComboButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if ([button.menu isEqualTo:button.initialMenu]) {
            lua_pushnil(L) ;
        } else {
            [skin pushNSObject:button.menu withOptions:LS_NSDescribeUnknownTypes] ;
        }
    } else {
        NSMenu *oldMenu = nil ;

        if (lua_type(L, 2) == LUA_TNIL) {
            oldMenu     = button.menu ;
            button.menu = button.initialMenu ;
        } else {
            [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.menu", LS_TBREAK] ;
            oldMenu      = button.menu ;
            NSMenu *menu = [skin toNSObjectAtIndex:2] ;
            menu.assignedTo = button ;
            button.menu  = menu ;
            [skin luaRetain:refTable forNSObject:menu] ;
        }

        if (oldMenu && ![oldMenu isEqualTo:button.initialMenu]) {
            oldMenu.assignedTo = nil ;
            [skin luaRelease:refTable forNSObject:oldMenu] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int comboButton_image(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementComboButton *button = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:button.image] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            button.image = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            button.image = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementComboButton(lua_State *L, id obj) {
    HSUITKElementComboButton *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementComboButton *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementComboButtonFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementComboButton *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementComboButton, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_gc(lua_State* L) {
    HSUITKElementComboButton *obj  = get_objectFromUserdata(__bridge_transfer HSUITKElementComboButton, L, 1, USERDATA_TAG) ;

    obj.selfRefCount-- ;
    if (obj.selfRefCount == 0) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        obj.callbackRef = [skin luaUnref:obj.refTable ref:obj.callbackRef] ;
        if (obj.menu) {
            obj.menu.assignedTo = nil ;
            [skin luaRelease:refTable forNSObject:obj.menu] ;
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
    {"title",        comboButton_title},
    {"image",        comboButton_image},
    {"imageScaling", comboButton_imageScaling},
    {"menu",         comboButton_menu},
    {"style",        comboButton_style},

// other metamethods inherited from _control and _view
    {"__gc",         userdata_gc},
    {NULL,           NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"buttonWithTitle",         comboButton_newButtonWithTitle},
    {"buttonWithTitleAndImage", comboButton_newButtonWithTitleAndImage},
    {"buttonWithImage",         comboButton_newButtonWithImage},
    {NULL,                      NULL}
};

int luaopen_hs__asm_uitk_libelement_comboButton(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    if (@available(macOS 13, *)) {
        refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                         functions:moduleLib
                                     metaFunctions:nil
                                   objectFunctions:userdata_metaLib];

        defineInternalDictionaries() ;

        [skin registerPushNSHelper:pushHSUITKElementComboButton         forClass:"HSUITKElementComboButton"];
        [skin registerLuaObjectHelper:toHSUITKElementComboButtonFromLua forClass:"HSUITKElementComboButton"
                                                              withUserdataMapping:USERDATA_TAG];

        // properties for this item that can be modified through content metamethods
        luaL_getmetatable(L, USERDATA_TAG) ;
        [skin pushNSObject:@[
            @"title",
            @"image",
            @"imageScaling",
            @"style",
            @"menu",
        ]] ;
        lua_setfield(L, -2, "_propertyList") ;
        // (all elements inherit from _view)
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
        lua_pop(L, 1) ;
    } else {
        [skin logWarn:[NSString stringWithFormat:@"%s only available in macOS 13 or newer", USERDATA_TAG]] ;
        lua_pushnil(L) ;
    }
    return 1;
}
