// NOTE: Methods which can be applied to all NSView based elements (i.e. all of them I think)
//       These will be made available to any element in this submodule
//       If an element specifies _inheritControl in its luaopen_* function, the methods
//           in lib_control.m are added first.
//       If an element file already defines a method that is named here, the existing
//           method will be used for that element -- it will not be replaced by the
//           common method.

/// === hs._asm.uitk.element._view ===
///
/// Common methods inherited by elements defined in this submodule.

@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element._view" ;

#define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)lua_touserdata(L, idx))

static NSDictionary *VIEW_FOCUSRINGTYPE ;

#pragma mark - Support Functions and Classes -

@interface NSView (Hammerspoon)
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;

- (int)        selfRefCount ;
- (void)       setSelfRefCount:(int)value ;
- (LSRefTable) refTable ;
- (int)        callbackRef ;
- (void)       setCallbackRef:(int)value ;
@end

BOOL oneOfOurs(NSView *obj) {
    return [obj isKindOfClass:[NSView class]]  &&
           [obj respondsToSelector:NSSelectorFromString(@"selfRefCount")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setSelfRefCount:")] &&
           [obj respondsToSelector:NSSelectorFromString(@"refTable")] &&
           [obj respondsToSelector:NSSelectorFromString(@"callbackRef")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setCallbackRef:")] ;
}

static void defineInternalDictionaries(void) {
    VIEW_FOCUSRINGTYPE = @{
        @"default"  : @(NSFocusRingTypeDefault),
        @"none"     : @(NSFocusRingTypeNone),
        @"exterior" : @(NSFocusRingTypeExterior),
    } ;
}

#pragma mark - Common NSView Methods -

/// hs._asm.uitk.element._view:fittingSize() -> table
/// Method
/// Returns a table with `h` and `w` keys specifying the element's fitting size as defined by macOS and the element's current properties.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table with `h` and `w` keys specifying the elements fitting size
///
/// Notes:
///  * The dimensions provided can be used to determine a minimum size for the element to display fully based on its current properties and may change as these change.
///  * Not all elements provide one or both of these fields; in such a case, the value for the missing or unspecified field will be 0.
///
///  * If you do not specify an elements height or width with the elements constructor, with [hs._asm.uitk.element._view:frameSize](#frameSize), or within the container that it is assigned to, the value returned by this method will be used instead; in cases where a specific dimension is not defined by this method, you should make sure to specify it or the element may not be visible.
static int view_fittingSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    NSView *view = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!view || !oneOfOurs(view)) {
        return luaL_argerror(L, 1, "expected userdata representing a uitk element") ;
    }

    [skin pushNSSize:view.fittingSize] ;
    return 1 ;
}

/// hs._asm.uitk.element._view:frameSize([size]) -> elementObject | table
/// Method
/// Get or set the frame size of the element.
///
/// Parameters:
///  * `size` - a size-table specifying the height and width of the element's frame
///
/// Returns:
///  * if an argument is provided, returns the elementObject userdata; otherwise returns the current value
///
/// Notes:
///  * a size-table is a table with key-value pairs specifying the size (keys `h` and `w`) the element should be resized to.
///
///  * this method is primarily used to adjust an elements size before it has been assigned to a pane or window, but was not assigned during the element's creation with its constructor, perhaps because the size wasn't known or calculable at the time.
///  * if the element is already assigned to a container or window, this method will likely have no effect.
static int view_frameSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    NSView *view = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!view || !oneOfOurs(view)) {
        return luaL_argerror(L, 1, "expected userdata representing a uitk element") ;
    }

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:view.frame.size] ;
    } else {
        if (!(view.window && [view isEqualTo:view.window.contentView])) {
            NSSize newSize = [skin tableToSizeAtIndex:2] ;
            [view setFrameSize:newSize] ;
            // prevent existing frame details from resetting the change
            NSView *viewParent       = view.superview ;
            SEL    resetFrameDetails = NSSelectorFromString(@"resetFrameSizeDetailsFor:") ;
            if (viewParent && [viewParent respondsToSelector:resetFrameDetails]) {
                [viewParent performSelectorOnMainThread:resetFrameDetails withObject:view waitUntilDone:YES] ;
            }
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element._view:tooltip([tooltip]) -> elementObject | string
/// Method
/// Get or set the tooltip for the element
///
/// Parameters:
///  * `tooltip` - a string, or nil to remove, specifying the tooltip to display when the mouse pointer hovers over the element
///
/// Returns:
///  * if an argument is provided, returns the elementObject userdata; otherwise returns the current value
///
/// Notes:
///  * Tooltips are displayed when the window is active and the mouse pointer hovers over an element.
static int view_toolTip(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSView *view = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!view || !oneOfOurs(view)) {
        return luaL_argerror(L, 1, "expected userdata representing a uitk element") ;
    }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:view.toolTip] ;
    } else {
        if (lua_type(L, 2) != LUA_TSTRING) {
            view.toolTip = nil ;
        } else {
            view.toolTip = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element._view:centerRotation([angle]) -> elementObject | number
/// Method
/// Get or set the rotation of the element about its center.
///
/// Parameters:
///  * `angle` - an optional number representing the number of degrees the element should be rotated clockwise around its center
///
/// Returns:
///  * if an argument is provided, returns the elementObject userdata; otherwise returns the current value
///
/// Notes:
///  * Not all elements rotate cleanly, e.g. button elements with an image in them may skew the image or alter its size depending upon the specific angle of rotation. At this time it is not known if this can be easily addressed or not.

// If you're digging this deep to learn why the note above, a quick intial search suggests that this method is old and manipulating the layer directly is the more "modern" way to do it, but this would require some significant changes and will be delayed until absolutely necessary

static int view_frameCenterRotation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    NSView *view = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!view || !oneOfOurs(view)) {
        return luaL_argerror(L, 1, "expected userdata representing a uitk element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, view.frameCenterRotation) ;
    } else {
// // Rotates visually but not controls (what mouse/keyboard interacts with)
//         NSSize viewSize = view.frame.size ;
//         CGFloat xOffset = viewSize.width * (0.5 - view.layer.anchorPoint.x) ;
//         CGFloat yOffset = viewSize.height * (0.5 - view.layer.anchorPoint.y) ;
//
//         CATransform3D transform = CATransform3DMakeTranslation(xOffset, yOffset, 0) ;
//         transform = CATransform3DRotate(transform, lua_tonumber(L, 2) * M_PI / 180.0, 0, 0, 1.0) ;
//         transform = CATransform3DTranslate(transform, -xOffset, -yOffset, 0) ;
//         view.layer.transform = transform ;
        view.frameCenterRotation = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// static int view_frameRotation(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
//     NSView *view = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
//     if (!view || !oneOfOurs(view)) {
//         return luaL_argerror(L, 1, "expected userdata representing a uitk element") ;
//     }
//
//     if (lua_gettop(L) == 1) {
//         lua_pushnumber(L, view.frameRotation) ;
//     } else {
//         view.frameRotation = lua_tonumber(L, 2) ;
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }

// static int view_boundsRotation(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
//     NSView *view = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
//     if (!view || !oneOfOurs(view)) {
//         return luaL_argerror(L, 1, "expected userdata representing a uitk element") ;
//     }
//
//     if (lua_gettop(L) == 1) {
//         lua_pushnumber(L, view.boundsRotation) ;
//     } else {
//         view.boundsRotation = lua_tonumber(L, 2) ;
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }

/// hs._asm.uitk.element._view:hidden([state | nil]) -> elementObject | boolean
/// Method
/// Get or set whether or not the element is currently hidden
///
/// Parameters:
///  * `state` - an optional boolean specifying whether the element should be hidden. If you specify an explicit nil, this method will return whether or not this element *or any of its parents* are currently hidden.
///
/// Returns:
///  * if a boolean argument is provided, returns the elementObject userdata; otherwise returns the current value
///
/// Notes:
///  * If no argument is provided, this method will return whether or not the element itself has been explicitly hidden; when an explicit nil is provided as the argument, this method will return whether or not this element or any of its parent objects are hidden, since hiding the parent will also hide all of the elements of the parent.
static int view_hidden(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSView *view = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!view || !oneOfOurs(view)) {
        return luaL_argerror(L, 1, "expected userdata representing a uitk element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, view.hidden) ;
    } else if (lua_type(L, 2) == LUA_TNIL) {
        lua_pushboolean(L, view.hiddenOrHasHiddenAncestor) ;
    } else {
        view.hidden = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element._view:alphaValue([alpha]) -> elementObject | number
/// Method
/// Get or set the alpha level of the element.
///
/// Parameters:
///  * `alpha` - an optional number, default 1.0, specifying the alpha level (0.0 - 1.0, inclusive) for the element.
///
/// Returns:
///  * if an argument is provided, returns the elementObject userdata; otherwise returns the current value
static int view_alphaValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    NSView *view = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!view || !oneOfOurs(view)) {
        return luaL_argerror(L, 1, "expected userdata representing a uitk element") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, view.alphaValue) ;
    } else {
        CGFloat newAlpha = luaL_checknumber(L, 2);
        view.alphaValue = ((newAlpha < 0.0) ? 0.0 : ((newAlpha > 1.0) ? 1.0 : newAlpha)) ;
        lua_pushvalue(L, 1);
    }
    return 1 ;
}

/// hs._asm.uitk.element._view:focusRingType([type]) -> elementObject | string
/// Method
/// Get or set the focus ring type for the element
///
/// Parameters:
///  * `type` - an optional string specifying the focus ring type for the element.  Valid strings are as follows:
///    * "default"  - The default focus ring behavior for the element will be used when the element is the input focus; usually this is identical to "exterior".
///    * "none"     - No focus ring will be drawn around the element when it is the input focus
///    * "Exterior" - The standard Aqua focus ring will be drawn around the element when it is the input focus
///
/// Returns:
///  * if an argument is provided, returns the elementObject userdata; otherwise returns the current value
///
/// Notes:
///  * Setting this for an element that cannot be an active element has no effect.
///  * When an element is rotated with [hs._asm.uitk.element._view:rotation](#rotation), the focus ring may not appear properly; if you are using angles other then the four cardinal directions (0, 90, 180, or 270), it may be visually more appropriate to set this to "none".
static int view_focusRingType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSView *view = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!view || !oneOfOurs(view)) {
        return luaL_argerror(L, 1, "expected userdata representing a uitk element") ;
    }

    if (lua_gettop(L) == 2) {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *focusRingType = VIEW_FOCUSRINGTYPE[key] ;
        if (focusRingType) {
            view.focusRingType = [focusRingType unsignedIntegerValue] ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[VIEW_FOCUSRINGTYPE allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        NSNumber *focusRingType = @(view.focusRingType) ;
        NSArray *temp = [VIEW_FOCUSRINGTYPE allKeysForObject:focusRingType];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized focus ring type %@ -- notify developers", USERDATA_TAG, focusRingType]] ;
            lua_pushnil(L) ;
        }
    }
    return 1;
}

static int view_needsDisplay(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    NSView *view = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!view || !oneOfOurs(view)) {
        return luaL_argerror(L, 1, "expected userdata representing a uitk element") ;
    }

    view.needsDisplay = YES ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int view__nextResponder(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    NSView *view = (lua_type(L, 1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:1] : nil ;
    if (!view || !oneOfOurs(view)) {
        return luaL_argerror(L, 1, "expected userdata representing a uitk element") ;
    }

    [skin pushNSObject:view.nextResponder] ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSString *title = @"<not userdata>" ;
    if (lua_getmetatable(L, -1)) {
        lua_getfield(L, -1, "__name") ;
        title = [NSString stringWithUTF8String:lua_tostring(L, -1)] ;
        lua_pop(L, 2) ;
    }
    NSView   *obj   = [skin toNSObjectAtIndex:1] ;
    NSString *frame = NSStringFromRect(obj.frame) ;
    [skin pushNSObject:[NSString stringWithFormat:@"%@: %@ (%p)", title, frame, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if ((lua_type(L, 1) == LUA_TUSERDATA) && (lua_type(L, 2) == LUA_TUSERDATA)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        NSObject *obj1 = [skin toNSObjectAtIndex:1] ;
        NSObject *obj2 = [skin toNSObjectAtIndex:2];
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    NSView  *obj  = get_objectFromUserdata(__bridge_transfer NSView, L, 1) ;

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
    {"tooltip",       view_toolTip},

    {"centerRotation", view_frameCenterRotation},
    {"hidden",         view_hidden},
    {"alphaValue",     view_alphaValue},
    {"focusRingType",  view_focusRingType},
    {"fittingSize",    view_fittingSize},
    {"frameSize",      view_frameSize},
    {"needsDisplay",   view_needsDisplay},

    {"_nextResponder", view__nextResponder},

//     {"frameRotation",  view_frameRotation},
//     {"boundsRotation", view_boundsRotation},

    {"__tostring",     userdata_tostring},
    {"__eq",           userdata_eq},
    {"__gc",           userdata_gc},
    {NULL,             NULL}
};

int luaopen_hs__asm_uitk_libelement__view(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin registerLibrary:USERDATA_TAG functions:userdata_metaLib metaFunctions:nil] ;

    defineInternalDictionaries() ;

    [skin pushNSObject:@[
        @"tooltip",
        @"centerRotation",
        @"hidden",
        @"alphaValue",
        @"focusRingType",

//         @"frameRotation",
//         @"boundsRotation",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;

    return 1;
}
