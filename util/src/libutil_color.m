@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;

static const char * const USERDATA_TAG = "hs._asm.uitk.util.color" ;
static const char * const UD_LIST_TAG  = "hs._asm.uitk.util.color.list" ;
static LSRefTable         refTable     = LUA_NOREF ;

static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

@interface NSColorList (HammerspoonAdditions)
@property (nonatomic) int  selfRefCount ;

- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
@end

@implementation NSColorList (HammerspoonAdditions)
- (void)setSelfRefCount:(int)value {
    NSNumber *valueWrapper = [NSNumber numberWithInt:value];
    objc_setAssociatedObject(self, SELFREFCOUNT_KEY, valueWrapper, OBJC_ASSOCIATION_RETAIN);
}

- (int)selfRefCount {
    NSNumber *valueWrapper = objc_getAssociatedObject(self, SELFREFCOUNT_KEY) ;
    if (!valueWrapper) {
        [self setSelfRefCount:0] ;
        valueWrapper = @(0) ;
    }
    return valueWrapper.intValue ;
}
@end

#pragma mark - NSColor Functions -

/// hs._asm.uitk.util.color.asRGB(color) -> table | string
/// Function
/// Returns a table containing the RGB representation of the specified color.
///
/// Parameters:
///  * color - a table specifying a color as described in the module definition (see `hs._asm.uitk.util.color` in the online help or Dash documentation)
///
/// Returns:
///  * a table containing the red, blue, green, and alpha keys representing the specified color as RGB or a string describing the color's colorspace if conversion is not possible.
///
/// Notes:
///  * See also `hs._asm.uitk.util.color.asHSB`
static int color_asRGB(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    NSColor *theColor = [skin luaObjectAtIndex:1 toClass:"NSColor"] ;

    NSColor *safeColor = [theColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]; ;

    if (safeColor) {
        lua_newtable(L) ;
          lua_pushnumber(L, [safeColor redComponent])   ; lua_setfield(L, -2, "red") ;
          lua_pushnumber(L, [safeColor greenComponent]) ; lua_setfield(L, -2, "green") ;
          lua_pushnumber(L, [safeColor blueComponent])  ; lua_setfield(L, -2, "blue") ;
          lua_pushnumber(L, [safeColor alphaComponent]) ; lua_setfield(L, -2, "alpha") ;
    } else {
        lua_pushstring(L, [[NSString stringWithFormat:@"unable to convert colorspace %@ to NSCalibratedRGBColorSpace", theColor.colorSpace.description] UTF8String]) ;
    }

    return 1 ;
}

/// hs._asm.uitk.util.color.asHSB(color) -> table | string
/// Function
/// Returns a table containing the HSB representation of the specified color.
///
/// Parameters:
///  * color - a table specifying a color as described in the module definition (see `hs._asm.uitk.util.color` in the online help or Dash documentation)
///
/// Returns:
///  * a table containing the hue, saturation, brightness, and alpha keys representing the specified color as HSB or a string describing the color's colorspace if conversion is not possible.
///
/// Notes:
///  * See also `hs._asm.uitk.util.color.asRGB`
static int color_asHSB(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    NSColor *theColor = [skin luaObjectAtIndex:1 toClass:"NSColor"] ;

    NSColor *safeColor = [theColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]] ;

    if (safeColor) {
        lua_newtable(L) ;
          lua_pushnumber(L, [safeColor hueComponent])        ; lua_setfield(L, -2, "hue") ;
          lua_pushnumber(L, [safeColor saturationComponent]) ; lua_setfield(L, -2, "saturation") ;
          lua_pushnumber(L, [safeColor brightnessComponent]) ; lua_setfield(L, -2, "brightness") ;
          lua_pushnumber(L, [safeColor alphaComponent])      ; lua_setfield(L, -2, "alpha") ;
    } else {
        lua_pushstring(L, [[NSString stringWithFormat:@"unable to convert colorspace from %@ to NSCalibratedRGBColorSpace", theColor.colorSpace.description] UTF8String]) ;
    }

    return 1 ;
}

#pragma mark - NSColorList Functions -

/// hs._asm.uitk.util.color.loadList(name, path) -> colorListObject | nil
/// Constructor
/// Loads the colorlist from the specified path and creates a colorlist object with the specified name.
///
/// Parameters:
///  * `name` - the name to assign to the loaded list.
///  * `path` - the path where the colorlist data is saved. By convention, colorlist files are given a file extension of "clr".
///
/// Returns:
///  * a colorlist object, or nil if no colorlist was found at the specified path.
///
/// Notes:
///  * by convention, the list name and the filename portion (minus a file extension of "clr", should match, but this is not enforced.
///
///  * if a colorlist is saved into the users colorlist directory (see the [hs._asm.uitk.util.color.list:saveList](#saveList) method), you do not need to load it -- it will be available automatically.
static int colorList_loadList(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TBREAK] ;

    NSString *name = [skin toNSObjectAtIndex:1] ;
    NSString *path = [skin toNSObjectAtIndex:2] ;

    NSColorList *list = [[NSColorList alloc] initWithName:name fromFile:path.stringByStandardizingPath] ;
    if (list) {
        [skin pushNSObject:list] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.util.color.list.listNamed(name, [create]) -> colorListObject | nil
/// Constructor
/// Return a colorlist object for an existing list, or create a new empty list.
///
/// Parameters:
///  * `name`   - the name of the list.
///  * `create` - an optional boolean, default false, indicating whether or not a new empty list should be created
///
/// Returns:
///  * a colorlist object, or nil if no colorlist with that name exists.
///
/// Notes:
///  * You can use this to get a colorlist object for existing colorlists, or to create a new empty list.
static int colorList_listNamed(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    NSString    *name  = [skin toNSObjectAtIndex:1] ;
    BOOL        create = (lua_gettop(L) == 2) ? (BOOL)(lua_toboolean(L, 2)) : NO ;

    NSColorList *list = nil ;
    if (create) {
        list = [[NSColorList alloc] initWithName:name] ;
    } else {
        list = [NSColorList colorListNamed:name] ;
    }

    if (list) {
        [skin pushNSObject:list] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.util.color.list.availableLists() -> table
/// Constructor
/// Get a table containing all of the defined colorlists located in the standard colorlist directories.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table objects representing the colorlists.
///
/// Notes:
///  * you can use this method to get all of the colorlists defined by the macOS system, as well as user specific lists that have been saved in the users personal colorlist directory. See [hs._asm.uitk.util.color.list:saveList](#saveList) for more information.
///
///  * this will not include named colorlists created with the other constructors of this submodule unless they have been saved in the users personal colorlist directory.
static int colorList_availableColorLists(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    [skin pushNSObject:NSColorList.availableColorLists] ;
    return 1 ;
}

#pragma mark - NSColorList Methods -

/// hs._asm.uitk.util.color.list:name() -> string
/// Method
/// Returns the name of the colorlist.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string specifying the name of the colorlist.
static int colorList_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_LIST_TAG, LS_TBREAK] ;
    NSColorList *list = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:list.name] ;
    return 1 ;
}

/// hs._asm.uitk.util.color.list:editable() -> boolean
/// Method
/// Returns a boolean value indicating whether or not the colorlist is editable.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean indicating whether the colorlist is editable (true) or not (false).
///
/// Notes:
///  * only new lists created by the user with [hs._asm.uitk.util.color.list.listNamed](#listNamed) or found in the users colorlist directory and owned by the user can be edited.
static int colorList_editable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_LIST_TAG, LS_TBREAK] ;
    NSColorList *list = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, list.editable) ;
    return 1 ;
}

/// hs._asm.uitk.util.color.list:colorNames() -> table
/// Method
/// Returns a table containing the names of all of the colors defined within the colorlist
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the names of all of the colors defined within the color list
static int colorList_allKeys(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_LIST_TAG, LS_TBREAK] ;
    NSColorList *list = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:list.allKeys] ;
    return 1 ;
}

/// hs._asm.uitk.util.color.list:colorNamed(name, [color]) -> colorlistObject | table | nil
/// Method
/// Get or set the color associated with the specified name in the colorlist
///
/// Parameters:
///  * `name`  - a string specifying the name of the color in the colorlist
///  * `color` - an optional color table as described in the documentation for `hs._asm.uitk.util.color`
///
/// Returns:
///  * if `color` is specified, returns the colorlist object, or an error if the colorlist is not editable. If only `name` is specified, returns a table representing the color stored for `name`, or nil if no color is defined for the name.
static int colorList_colorWithKey(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_LIST_TAG, LS_TSTRING, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSColorList *list = [skin toNSObjectAtIndex:1] ;

    NSString *key = [skin toNSObjectAtIndex:2] ;
    if (lua_gettop(L) == 2) {
        NSColor *color = [list colorWithKey:key] ;
        if (color) {
            [skin pushNSObject:color] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (list.editable) {
            if (lua_type(L, 3) == LUA_TTABLE) {
                NSColor *color = [skin luaObjectAtIndex:3 toClass:"NSColor"] ;
                [list setColor:color forKey:key] ;
            } else {
                [list removeColorWithKey:key] ;
            }
        } else {
            return luaL_argerror(L, 3, "colorlist is not editable") ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.util.color.list:saveList([path | true]) -> colorlistObject
/// Method
/// Saves the color list.
///
/// Parameters:
///  * `path` - the full path where the colorlist is to be saved, or an explicit true to specify that it should be saved in the users personal colorlist directory.
///
/// Returns:
///  * the colorlistObject, or an error if there is a problem saving the file.
///
/// Notes:
///  * The user's personal colorlist directory is located at `~/Library/Colors` and the file will be saved as `name.clr`, where `name` is the colorlist name, in this directory if true is specified as the path.
///  * a color saved to the users personal colorlist directory becomes available for selection by the color panel when in list mode across all macOS applications, not just Hammerspoon.
///
///  * By convention, colorlist filenames are `name.clr` where `name` is the colorlist name, but this is not enforced and the list will be saved in the filename specified in the `path` argument to this method.
static int colorList_writeToFile(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    // second argument is optional so that if the method is called without an argument, we generate our own error msg
    [skin checkArgs:LS_TUSERDATA, UD_LIST_TAG, LS_TSTRING | LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSColorList *list = [skin toNSObjectAtIndex:1] ;

    NSString *path = (lua_type(L, 2) == LUA_TSTRING) ? [skin toNSObjectAtIndex:2] : nil ;
    NSURL    *url  = path ? [NSURL fileURLWithPath:path.stringByStandardizingPath isDirectory:NO] : nil ;

    if (!path && !(lua_type(L, 2) == LUA_TBOOLEAN && lua_toboolean(L, 2))) {
        return luaL_argerror(L, 2, "expected path or explicit `true` to save in user library") ;
    }
    NSError *error = nil ;

    if (![list writeToURL:url error:&error]) {
        return luaL_error(L, error.localizedDescription.UTF8String) ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.util.color.list:removeFile() -> colorlistObject
/// Method
/// Removes the colorlist file if it has been previously saved in the users personal colorlist directory.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the colorlistObject
///
/// Notes:
///  * This will only delete colorlist files found in the users personal colorlist directory that are also owned by the user.
///  * No error will be generated if this method fails; if you need to check if the file has actually been deleted, use the `hs.fs` module.
///
///  * You can also use the `hs.fs` module to remove colorlist files that have been saved in other locations.
static int colorList_removeFile(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_LIST_TAG, LS_TBREAK] ;
    NSColorList *list = [skin toNSObjectAtIndex:1] ;

    [list removeFile] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

// only official method with index; with no direct way to determine number or current order, seems useless
// - (void)insertColor:(NSColor *)color key:(NSColorName)key atIndex:(NSUInteger)loc;

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushNSColorList(lua_State *L, id obj) {
    NSColorList *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(NSColorList *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_LIST_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toNSColorList(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSColorList *value ;
    if (luaL_testudata(L, idx, UD_LIST_TAG)) {
        value = get_objectFromUserdata(__bridge NSColorList, L, idx, UD_LIST_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_LIST_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

// [skin pushNSObject:NSColor]
// C-API
// Pushes the provided NSColor onto the Lua Stack as an array meeting the color table description provided in `hs._asm.uitk.util.color`
static int pushNSColor(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSColor *theColor = obj ;
    NSColor *safeColor = [theColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]] ;

    if (safeColor) {
        lua_newtable(L) ;
          lua_pushnumber(L, [safeColor redComponent])   ; lua_setfield(L, -2, "red") ;
          lua_pushnumber(L, [safeColor greenComponent]) ; lua_setfield(L, -2, "green") ;
          lua_pushnumber(L, [safeColor blueComponent])  ; lua_setfield(L, -2, "blue") ;
          lua_pushnumber(L, [safeColor alphaComponent]) ; lua_setfield(L, -2, "alpha") ;
          lua_pushstring(L, "NSColor") ; lua_setfield(L, -2, "__luaSkinType") ;
    } else if (theColor.type == NSColorTypeCatalog) {
        lua_newtable(L) ;
          [skin pushNSObject:[theColor catalogNameComponent]] ;
          lua_setfield(L, -2, "list") ;
          [skin pushNSObject:[theColor colorNameComponent]] ;
          lua_setfield(L, -2, "name") ;
          lua_pushstring(L, "NSColor") ; lua_setfield(L, -2, "__luaSkinType") ;
    } else if (theColor.type == NSColorTypePattern) {
        lua_newtable(L) ;
          [skin pushNSObject:[theColor patternImage]] ;
          lua_setfield(L, -2, "image") ;
          lua_pushstring(L, "NSColor") ; lua_setfield(L, -2, "__luaSkinType") ;
    } else {
        lua_pushstring(L, [[NSString stringWithFormat:@"unable to convert colorspace from %@ to NSCalibratedRGBColorSpace", theColor.colorSpace.description] UTF8String]) ;
    }

    return 1 ;
}

// [skin luaObjectAtIndex:idx toClass:"NSColor"]
// C-API
// Converts the table at the specified index on the Lua Stack into an NSColor and returns the NSColor.  A description of how the table should be defined can be found in `hs._asm.uitk.util.color`
static id table_toNSColor(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 1.0 ;
    CGFloat hue = 0.0, saturation = 0.0, brightness = 0.0 ;
    CGFloat white = 0.0 ;

    BOOL     RGBColor = YES ;
    NSImage  *image ;
    NSString *colorList, *colorName ;

    if (lua_type(L, idx) == LUA_TTABLE) {
        if (lua_getfield(L, idx, "list") == LUA_TSTRING)
            colorList = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;
        if (lua_getfield(L, idx, "name") == LUA_TSTRING)
            colorName = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;

        if (lua_getfield(L, idx, "hex") == LUA_TSTRING) {
            NSString *hexString = [skin toNSObjectAtIndex:-1] ;
            if ([hexString hasPrefix:@"#"])  hexString = [hexString substringFromIndex:1] ;
            if ([hexString hasPrefix:@"0x"]) hexString = [hexString substringFromIndex:2] ;
            BOOL isBadHex = YES ;
            unsigned int rHex = 0, gHex = 0, bHex = 0 ;
            if ([[NSScanner scannerWithString:hexString] scanHexInt:NULL]) {
                if ([hexString length] == 3) {
                    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(0, 1)]] scanHexInt:&rHex] ;
                    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(1, 1)]] scanHexInt:&gHex] ;
                    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(2, 1)]] scanHexInt:&bHex] ;
                    rHex = rHex * 0x11 ;
                    gHex = gHex * 0x11 ;
                    bHex = bHex * 0x11 ;
                    isBadHex = NO ;
                } else if ([hexString length] == 6) {
                    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(0, 2)]] scanHexInt:&rHex] ;
                    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(2, 2)]] scanHexInt:&gHex] ;
                    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(4, 2)]] scanHexInt:&bHex] ;
                    isBadHex = NO ;
                }
            }
            if (isBadHex) {
                [skin logWarn:[NSString stringWithFormat:@"invalid hexadecimal string #%@ specified for color, ignoring", hexString]] ;
            } else {
                red   = rHex / 255.0 ;
                green = gHex / 255.0 ;
                blue  = bHex / 255.0 ;
            }
        }
        lua_pop(L, 1) ;

        if (lua_getfield(L, idx, "red") == LUA_TNUMBER)
            red = lua_tonumber(L, -1);
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "green") == LUA_TNUMBER)
            green = lua_tonumber(L, -1);
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "blue") == LUA_TNUMBER)
            blue = lua_tonumber(L, -1);
        lua_pop(L, 1);

        if (lua_getfield(L, idx, "hue") == LUA_TNUMBER) {
            hue = lua_tonumber(L, -1);
            RGBColor = NO ;
        }
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "saturation") == LUA_TNUMBER)
            saturation = lua_tonumber(L, -1);
        lua_pop(L, 1);
        if (lua_getfield(L, idx, "brightness") == LUA_TNUMBER)
            brightness = lua_tonumber(L, -1);
        lua_pop(L, 1);

        if (lua_getfield(L, idx, "white") == LUA_TNUMBER)
            white = lua_tonumber(L, -1);
        lua_pop(L, 1);

        if (lua_getfield(L, idx, "alpha") == LUA_TNUMBER)
            alpha = lua_tonumber(L, -1);
        lua_pop(L, 1);

        if (lua_getfield(L, idx, "image") == LUA_TUSERDATA && luaL_testudata(L, -1, "hs.image")) {
            image = [skin toNSObjectAtIndex:-1] ;
        }
        lua_pop(L, 1) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"returning BLACK, unexpected type passed as a color: %s", lua_typename(L, lua_type(L, idx))]] ;
    }

    if (colorList && colorName && !image) {
        NSColor *holding = [[NSColorList colorListNamed:colorList] colorWithKey:colorName] ;
        if (holding) return holding ;
    }

    if (image) {
            return [NSColor colorWithPatternImage:image] ;
    } else if (RGBColor) {
        if (white != 0.0)
            return [NSColor colorWithCalibratedWhite:white alpha:alpha] ;
        else
            return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
    } else {
        return [NSColor colorWithCalibratedHue:hue saturation:saturation brightness:brightness alpha:alpha] ;
    }
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSColorList *obj = [skin luaObjectAtIndex:1 toClass:"NSColorList"] ;
    NSString *title = obj.name ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_LIST_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, UD_LIST_TAG) && luaL_testudata(L, 2, UD_LIST_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        NSColorList *obj1 = [skin luaObjectAtIndex:1 toClass:"NSColorList"] ;
        NSColorList *obj2 = [skin luaObjectAtIndex:2 toClass:"NSColorList"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    NSColorList *obj = get_objectFromUserdata(__bridge_transfer NSColorList, L, 1, UD_LIST_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            obj = nil ;
        }
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"asRGB",          color_asRGB},
    {"asHSB",          color_asHSB},
    {NULL, NULL}
};

static luaL_Reg list_moduleLib[] = {
    {"loadList",       colorList_loadList},
    {"listNamed",      colorList_listNamed},
    {"availableLists", colorList_availableColorLists},
    {NULL, NULL}
};

// Metatable for module, if needed
static const luaL_Reg ud_list_metaLib[] = {
    {"name",         colorList_name},
    {"editable",     colorList_editable},
    {"colorNames",   colorList_allKeys},
    {"colorNamed",   colorList_colorWithKey},
    {"saveList",     colorList_writeToFile},
    {"removeFile",   colorList_removeFile},

    {"__tostring",   userdata_tostring},
    {"__eq",         userdata_eq},
    {"__gc",         userdata_gc},
    {NULL,           NULL}
};

int luaopen_hs__asm_uitk_libutil_color(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibrary:USERDATA_TAG
                           functions:moduleLib
                       metaFunctions:NULL] ; // or module_metaLib

    [skin registerLibraryWithObject:UD_LIST_TAG
                          functions:list_moduleLib
                      metaFunctions:nil
                    objectFunctions:ud_list_metaLib];
    lua_setfield(L, -2, "list") ;

    // since they're identical, don't add conversions if drawing.color not being wrapped and already loaded
    // Reduces one point for spurious unnecessary warnings at least...
    if (![skin canPushNSObject:[NSColor blackColor]]) {
        [skin registerPushNSHelper:pushNSColor        forClass:"NSColor"] ;
        [skin registerLuaObjectHelper:table_toNSColor forClass:"NSColor"
                                              withTableMapping:"NSColor"] ;

        [skin registerPushNSHelper:pushNSColorList  forClass:"NSColorList"];
        [skin registerLuaObjectHelper:toNSColorList forClass:"NSColorList"
                                         withUserdataMapping:UD_LIST_TAG];
    }

    return 1;
}
