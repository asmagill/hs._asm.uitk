// NOTE: Methods which can be applied to all NSControll based elements
//       These will be made available to any element which sets _inheritControl in its
//           luaopen_* function,
//       If an element file already defines a method that is named here, the existing
//           method will be used for that element -- it will not be replaced by the
//           common method.

/// === hs._asm.uitk.element._control ===
///
/// Common methods inherited by elements which act as controls. Generally these are elements which are manipulated directly by the user to supply information or trigger a desired action.
///

@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element._control" ;

#define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)lua_touserdata(L, idx))

static NSDictionary *CONTROL_SIZE ;
static NSDictionary *TEXT_ALIGNMENT ;
static NSDictionary *TEXT_LINEBREAK ;

#pragma mark - Support Functions and Classes -

@interface NSControl (Hammerspoon)
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;

- (int)        selfRefCount ;
- (void)       setSelfRefCount:(int)value ;
- (LSRefTable) refTable ;
- (int)        callbackRef ;
- (void)       setCallbackRef:(int)value ;
@end

BOOL oneOfOurs(NSControl *obj) {
    return [obj isKindOfClass:[NSControl class]]  &&
           [obj respondsToSelector:NSSelectorFromString(@"selfRefCount")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setSelfRefCount:")] &&
           [obj respondsToSelector:NSSelectorFromString(@"refTable")] &&
           [obj respondsToSelector:NSSelectorFromString(@"callbackRef")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setCallbackRef:")] ;
}

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

    TEXT_ALIGNMENT = @{
        @"left"      : @(NSTextAlignmentLeft),
        @"center"    : @(NSTextAlignmentCenter),
        @"right"     : @(NSTextAlignmentRight),
        @"justified" : @(NSTextAlignmentJustified),
        @"natural"   : @(NSTextAlignmentNatural),
    } ;

    TEXT_LINEBREAK = @{
        @"wordWrap"       : @(NSLineBreakByWordWrapping),
        @"charWrap"       : @(NSLineBreakByCharWrapping),
        @"clip"           : @(NSLineBreakByClipping),
        @"truncateHead"   : @(NSLineBreakByTruncatingHead),
        @"truncateTail"   : @(NSLineBreakByTruncatingTail),
        @"truncateMiddle" : @(NSLineBreakByTruncatingMiddle),
    } ;
}

#pragma mark - Common NSControl Methods -

/// hs._asm.uitk.element._control:textAlignment([alignment]) -> controlObject | string
/// Method
/// Get or set the alignment of text which is displayed by the control, often as a label or description.
///
/// Parameters:
///  * `alignment` - an optional string specifying the alignment of the text being displayed by the control. Valid strings are as follows:
///    * "left"      - Align text along the left edge
///    * "center"    - Align text equally along both sides of the center line
///    * "right"     - Align text along the right edge
///    * "justified" - Fully justify the text so that the last line in a paragraph is natural aligned
///    * "natural"   - Use the default alignment associated with the current locale. The default alignment for left-to-right scripts is "left", and the default alignment for right-to-left scripts is "right".
///
/// Returns:
///  * if an argument is provided, returns the controlObject userdata; otherwise returns the current value
static int control_textAlignment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSControl *control = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!control || !oneOfOurs(control)) {
        return luaL_argerror(L, 1, "expected userdata representing a control element") ;
    }

    if (lua_gettop(L) == 2) {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *alignment = TEXT_ALIGNMENT[key] ;
        if (alignment) {
            control.alignment = (NSTextAlignment)[alignment unsignedIntegerValue] ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[TEXT_ALIGNMENT allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        NSNumber *alignment = @(control.alignment) ;
        NSArray *temp = [TEXT_ALIGNMENT allKeysForObject:alignment];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized text alignment %@ -- notify developers", USERDATA_TAG, alignment]] ;
            lua_pushnil(L) ;
        }
    }
    return 1;
}

/// hs._asm.uitk.element._control:controlSize([size]) -> controlObject | string
/// Method
/// Get or set the general size of the control.
///
/// Parameters:
///  * `size` - an optional string specifying the size, in a general way, necessary to properly display the control.  Valid strings are as follows:
///    * "regular" - present the control in its normal default size
///    * "small"   - present the control in a more compact form; for example when a windows toolbar offers the "Use small size" option.
///    * "mini"    - present the control in an even smaller form
///    * "large"   - present the control larger than the default size (only available for macOS 11 or newer)
///
/// Returns:
///  * if an argument is provided, returns the controlObject userdata; otherwise returns the current value
///
/// Notes:
///  * The exact effect this has on each control is type specific and may change the look of the control in other ways as well, such as reducing or removing borders for buttons -- the intent is provide a differing level of detail appropriate to the chosen control size; it is still incumbent upon you to select an appropriate sized font or frame size to take advantage of the level of detail provided.
static int control_controlSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSControl *control = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!control || !oneOfOurs(control)) {
        return luaL_argerror(L, 1, "expected userdata representing a control element") ;
    }

    if (lua_gettop(L) == 2) {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *controlSize = CONTROL_SIZE[key] ;
        if (controlSize) {
            control.controlSize = [controlSize unsignedIntegerValue] ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[CONTROL_SIZE allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        NSNumber *controlSize = @(control.controlSize) ;
        NSArray *temp = [CONTROL_SIZE allKeysForObject:controlSize];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized control size %@ -- notify developers", USERDATA_TAG, controlSize]] ;
            lua_pushnil(L) ;
        }
    }
    return 1;
}

/// hs._asm.uitk.element._control:tag([value]) -> controlObject | integer
/// Method
/// Get or set the user defined tag value for the control.
///
/// Parameters:
///  * `value` - an optional integer specifying the tag value for the control.
///
/// Returns:
///  * if an argument is provided, returns the controlObject userdata; otherwise returns the current value
///
/// Notes:
///  * The tag value is not used internally and is provided solely for your use.
static int control_tag(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    NSControl *control = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!control || !oneOfOurs(control)) {
        return luaL_argerror(L, 1, "expected userdata representing a control element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, control.tag) ;
    } else {
        control.tag = lua_tointeger(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element._control:highlighted([state]) -> controlObject | boolean
/// Method
/// Get or set whether or not the control has a highlighted appearance.
///
/// Parameters:
///  * `state` - an optional boolean indicating whether or not the control has a highlighted appearance.
///
/// Returns:
///  * if an argument is provided, returns the controlObject userdata; otherwise returns the current value
///
/// Notes:
///  * Not all elements have a highlighted appearance and this method will have no effect in such cases.
static int control_highlighted(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSControl *control = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!control || !oneOfOurs(control)) {
        return luaL_argerror(L, 1, "expected userdata representing a control element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, control.highlighted) ;
    } else {
        control.highlighted = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element._control:enabled([state]) -> controlObject | boolean
/// Method
/// Get or set whether or not the control is currently enabled.
///
/// Parameters:
///  * `state` - an optional boolean indicating whether or not the control is enabled.
///
/// Returns:
///  * if an argument is provided, returns the controlObject userdata; otherwise returns the current value
static int control_enabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSControl *control = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!control || !oneOfOurs(control)) {
        return luaL_argerror(L, 1, "expected userdata representing a control element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, control.enabled) ;
    } else {
        control.enabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element._control:font([font]) -> controlObject | table
/// Method
/// Get or set the font used for displaying text for the control.
///
/// Paramaters:
///  * `font` - an optional table specifying a font as defined in `hs.styledtext`.
///
/// Returns:
///  * if an argument is provided, returns the controlObject userdata; otherwise returns the current value
///
/// Notes:
///  * a font table is defined as having two key-value pairs: `name` specifying the name of the font as a string and `size` specifying the font size as a number.
static int control_font(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TANY, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    NSControl *control = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!control || !oneOfOurs(control)) {
        return luaL_argerror(L, 1, "expected userdata representing a control element") ;
    }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:control.font] ;
    } else {
        control.font = [skin luaObjectAtIndex:2 toClass:"NSFont"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element._control:lineBreakMode([mode]) -> controlObject | string
/// Method
/// Get or set the linebreak mode used for displaying text for the control.
///
/// Parameters:
///  * `mode` - an optional string specifying the line break mode for the control. Must be one of:
///    * "wordWrap"       - Wrapping occurs at word boundaries, unless the word itself doesn’t fit on a single line.
///    * "charWrap"       - Wrapping occurs before the first character that doesn’t fit.
///    * "clip"           - Lines are simply not drawn past the edge of the text container.
///    * "truncateHead"   - The line is displayed so that the end fits in the container and the missing text at the beginning of the line is indicated by an ellipsis glyph.
///    * "truncateTail"   - The line is displayed so that the beginning fits in the container and the missing text at the end of the line is indicated by an ellipsis glyph.
///    * "truncateMiddle" - The line is displayed so that the beginning and end fit in the container and the missing text in the middle is indicated by an ellipsis glyph.
///
/// Returns:
///  * if a value is provided, returns the controlObject ; otherwise returns the current value.
static int control_lineBreakMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSControl *control = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!control || !oneOfOurs(control)) {
        return luaL_argerror(L, 1, "expected userdata representing a control element") ;
    }

    if (lua_gettop(L) == 2) {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *lineBreakMode = TEXT_LINEBREAK[key] ;
        if (lineBreakMode) {
            control.lineBreakMode = [lineBreakMode unsignedIntegerValue] ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[TEXT_LINEBREAK allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        NSNumber *lineBreakMode = @(control.lineBreakMode) ;
        NSArray *temp = [TEXT_LINEBREAK allKeysForObject:lineBreakMode];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized linebreak mode %@ -- notify developers", USERDATA_TAG, lineBreakMode]] ;
            lua_pushnil(L) ;
        }
    }
    return 1;
}

/// hs._asm.uitk.element._control:continuous([state]) -> controlObject | boolean
/// Method
/// Get or set whether or not the control triggers continuous callbacks when the user interacts with it.
///
/// Paramaters:
///  * `state` - an optional boolean indicating whether or not continuous callbacks are generated for the control when the user interacts with it.
///
/// Returns:
///  * if an argument is provided, returns the controlObject userdata; otherwise returns the current value
///
/// Notes:
///  * The exact effect of this method depends upon the type of element; for example with the color well setting this to true will cause a callback as the user drags the mouse around in the color wheel; for a textField this determines whether a callback occurs after each character is entered or deleted or just when the user enters or exits the textField.
static int control_continuous(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSControl *control = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!control || !oneOfOurs(control)) {
        return luaL_argerror(L, 1, "expected userdata representing a control element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, control.continuous) ;
    } else {
        control.continuous = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element._control:singleLineMode([state]) -> controlObject | boolean
/// Method
/// Get or set whether the control restricts layout and rendering of text to a single line.
///
/// Parameters:
///  * `state` - an optional boolean specifying whether the control restricts text to a single line.
///
/// Returns:
///  * if a value is provided, returns the control ; otherwise returns the current value.
///
/// Notes:
///  * When this is set to true, text layout and rendering is restricted to a single line. The element will interpret [hs._asm.uitk.element._control:lineBreakMode](#lineBreakMode) modes of "charWrap" and "wordWrap" as if they were "clip" and an editable textField will ignore key binding commands that insert paragraph and line separators.
static int control_usesSingleLineMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSControl *control = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!control || !oneOfOurs(control)) {
        return luaL_argerror(L, 1, "expected userdata representing a control element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, control.usesSingleLineMode) ;
    } else {
        control.usesSingleLineMode = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element._control:callback([fn | nil]) -> controlObject | fn | nil
/// Method
/// Get or set the callback function which will be invoked whenever the user interacts with the control.
///
/// Parameters:
///  * `fn` - a lua function, or explicit nil to remove, which will be invoked when the user interacts with the control.
///
/// Returns:
///  * if a value is provided, returns the controlObject ; otherwise returns the current value (function or nil).
///
/// Notes:
///  * The callback will generally receive two arguments and should return none. See the documentation for the specific control for more details about what each callback should expect.
static int control_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSControl *control = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!control || !oneOfOurs(control)) {
        return luaL_argerror(L, 1, "expected userdata representing a control element") ;
    }

    if (lua_gettop(L) == 2) {
        control.callbackRef = [skin luaUnref:control.refTable ref:control.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            control.callbackRef = [skin luaRef:control.refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (control.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:control.refTable ref:control.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int control_sizeToFit(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    NSControl *control = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!control || !oneOfOurs(control)) {
        return luaL_argerror(L, 1, "expected userdata representing a control element") ;
    }

    [control sizeToFit] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_gc(lua_State* L) {
    NSControl *obj  = get_objectFromUserdata(__bridge_transfer NSControl, L, 1) ;

    if (obj && oneOfOurs(obj)) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:obj.refTable ref:obj.callbackRef] ;
            obj = nil ;
        }
        // Remove the Metatable so future use of the variable in Lua won't think its valid
        lua_pushnil(L) ;
        lua_setmetatable(L, 1) ;
    } else {
        [LuaSkin logError:[NSString stringWithFormat:@"%s.__gc: unrecognized object during collection (%@)", USERDATA_TAG, obj]] ;
    }
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"controlSize",    control_controlSize},
    {"textAlignment",  control_textAlignment},
    {"font",           control_font},
    {"highlighted",    control_highlighted},
    {"enabled",        control_enabled},
    {"continuous",     control_continuous},
    {"lineBreakMode",  control_lineBreakMode},
    {"singleLineMode", control_usesSingleLineMode},
    {"tag",            control_tag},
    {"callback",       control_callback},

    {"sizeToFit",      control_sizeToFit},

    {"__gc",           userdata_gc},
    {NULL,             NULL}
};

int luaopen_hs__asm_uitk_libelement__control(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin registerLibrary:USERDATA_TAG functions:userdata_metaLib metaFunctions:nil] ;

    defineInternalDictionaries() ;

    [skin pushNSObject:@[
        @"font",
        @"highlighted",
        @"enabled",
        @"controlSize",
        @"textAlignment",
        @"continuous",
        @"lineBreakMode",
        @"singleLineMode",
        @"tag",
        @"callback",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;

    return 1;
}
