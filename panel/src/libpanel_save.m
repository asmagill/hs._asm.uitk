@import Cocoa ;
@import LuaSkin ;

#if (TARGET_OS_OSX && __MAC_OS_X_VERSION_MAX_ALLOWED >= 110000)
    @import UniformTypeIdentifiers ;
#endif

static const char * const USERDATA_TAG = "hs._asm.uitk.panel.save" ;
static const char * const UD_OPEN_TAG  = "hs._asm.uitk.panel.open" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes -

BOOL oneOfOurElementObjects(NSView *obj) {
    return [obj isKindOfClass:[NSView class]]  &&
           [obj respondsToSelector:NSSelectorFromString(@"selfRefCount")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setSelfRefCount:")] &&
           [obj respondsToSelector:NSSelectorFromString(@"refTable")] &&
           [obj respondsToSelector:NSSelectorFromString(@"callbackRef")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setCallbackRef:")] ;
}

@interface HSUITKPanelSave : NSObject <NSOpenSavePanelDelegate>
@property            int         selfRefCount ;
@property (readonly) LSRefTable  refTable ;
@property            int         callbackRef ;
@property            NSSavePanel *panel ;
@property            NSView      *accessory ;
@end

@interface HSUITKPanelOpen : NSObject <NSOpenSavePanelDelegate>
@property            int         selfRefCount ;
@property (readonly) LSRefTable  refTable ;
@property            int         callbackRef ;
@property            NSOpenPanel *panel ;
@property            NSView      *accessory ;
@end

@implementation HSUITKPanelSave
- (instancetype)initSavePanel {
    self = [super init] ;
    if (self) {
        _selfRefCount = 0 ;
        _refTable     = refTable ;
        _callbackRef  = LUA_NOREF ;
        _panel        = [NSSavePanel savePanel] ;
        _accessory    = nil ;

        _panel.delegate = self ;

        // since we have to actually make sure to include tags when writing out the file, default
        // to their absence
        _panel.showsTagField = NO ;
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
        NSResponder *nextInChain = [self.panel nextResponder] ;
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

#pragma mark NSOpenSavePanelDelegate methods
// - (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url;
// - (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError * _Nullable *)outError;
// - (NSString *)panel:(id)sender userEnteredFilename:(NSString *)filename confirmed:(BOOL)okFlag;
// - (void)panel:(id)sender didChangeToDirectoryURL:(NSURL *)url;
// - (void)panel:(id)sender willExpand:(BOOL)expanding;
// - (void)panelSelectionDidChange:(id)sender;

@end

@implementation HSUITKPanelOpen
- (instancetype)initOpenPanel {
    self = [super init] ;
    if (self) {
        _selfRefCount = 0 ;
        _refTable     = refTable ;
        _callbackRef  = LUA_NOREF ;
        _panel        = [NSOpenPanel openPanel] ;
        _accessory    = nil ;

        _panel.delegate = self ;
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
            [skin logError:[NSString stringWithFormat:@"%s:callback error:%@", UD_OPEN_TAG, errorMessage]] ;
        }
    } else {
        // allow next responder a chance since we don't have a callback set
        NSResponder *nextInChain = [self.panel nextResponder] ;
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

#pragma mark NSOpenSavePanelDelegate methods
// - (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url;
// - (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError * _Nullable *)outError;
// - (NSString *)panel:(id)sender userEnteredFilename:(NSString *)filename confirmed:(BOOL)okFlag;
// - (void)panel:(id)sender didChangeToDirectoryURL:(NSURL *)url;
// - (void)panel:(id)sender willExpand:(BOOL)expanding;
// - (void)panelSelectionDidChange:(id)sender;

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.panel.save.new() -> panelObject
/// Constructor
/// Create a new save panel.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a new save panel object
static int save_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    HSUITKPanelSave *panel = [[HSUITKPanelSave alloc] initSavePanel] ;
    if (panel) {
        [skin pushNSObject:panel] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.open.new() -> panelObject
/// Constructor
/// Create a new open panel.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a new open panel object
static int open_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    HSUITKPanelOpen *panel = [[HSUITKPanelOpen alloc] initOpenPanel] ;
    if (panel) {
        [skin pushNSObject:panel] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Shared Methods -

/// hs._asm.uitk.panel.save:isVisible() -> boolean
/// Method
/// Return whether or not the save panel is currently being presented.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean value indicating whether the save panel is visible (true) or not (false).

/// hs._asm.uitk.panel.open:isVisible() -> boolean
/// Method
/// Return whether or not the open panel is currently being presented.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean value indicating whether the open panel is visible (true) or not (false).
static int saveOpen_isVisible(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;
    HSUITKPanelSave *panel = nil ;
    if (luaL_testudata(L, 1, USERDATA_TAG) || luaL_testudata(L, 1, UD_OPEN_TAG)) {
        panel = [skin toNSObjectAtIndex:1] ;
    } else {
        return luaL_argerror(L, 1, "expected open or save panel userdata") ;
    }

    lua_pushboolean(L, panel.panel.visible) ;
    return 1 ;
}

/// hs._asm.uitk.panel.save:canCreateDirectories([state]) -> panelObject | boolean
/// Method
/// Get or set whether the user is allowed to create new directories from within the save panel when it is presented.
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether or not the user can create new directories from within the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.

/// hs._asm.uitk.panel.open:canCreateDirectories([state]) -> panelObject | boolean
/// Method
/// Get or set whether the user is allowed to create new directories from within the open panel when it is presented.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not the user can create new directories from within the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
static int saveOpen_canCreateDirectories(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelSave *panel = nil ;
    if (luaL_testudata(L, 1, USERDATA_TAG) || luaL_testudata(L, 1, UD_OPEN_TAG)) {
        panel = [skin toNSObjectAtIndex:1] ;
    } else {
        return luaL_argerror(L, 1, "expected open or save panel userdata") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, panel.panel.canCreateDirectories) ;
    } else {
        panel.panel.canCreateDirectories = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.save:showHiddenFiles([state]) -> panelObject | boolean
/// Method
/// Get or set whether hidden files are displayed within the save panel when it is presented.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether hidden files are displayed in the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * Hidden files include files with the hidden attribute set and files that begin with a period.

/// hs._asm.uitk.panel.open:showHiddenFiles([state]) -> panelObject | boolean
/// Method
/// Get or set whether hidden files are displayed within the open panel when it is presented.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether hidden files are displayed in the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * Hidden files include files with the hidden attribute set and files that begin with a period.
static int saveOpen_showsHiddenFiles(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelSave *panel = nil ;
    if (luaL_testudata(L, 1, USERDATA_TAG) || luaL_testudata(L, 1, UD_OPEN_TAG)) {
        panel = [skin toNSObjectAtIndex:1] ;
    } else {
        return luaL_argerror(L, 1, "expected open or save panel userdata") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, panel.panel.showsHiddenFiles) ;
    } else {
        panel.panel.showsHiddenFiles = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.save:packagesAsDirectories([state]) -> panelObject | boolean
/// Method
/// Get or set whether file packages are treated as a single file or as a directory of files.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether packages are treated as a directory of files (true) or as a single file (false) in the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * File packages are folders that are treated by the system as a single file object. MacOS Applications are file packages, as are Hammerspoon Spoons, just to name a couple of examples.

/// hs._asm.uitk.panel.open:packagesAsDirectories([state]) -> panelObject | boolean
/// Method
/// Get or set whether file packages are treated as a single file or as a directory of files.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether packages are treated as a directory of files (true) or as a single file (false) in the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * File packages are folders that are treated by the system as a single file object. MacOS Applications are file packages, as are Hammerspoon Spoons, just to name a couple of examples.
static int saveOpen_treatsFilePackagesAsDirectories(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelSave *panel = nil ;
    if (luaL_testudata(L, 1, USERDATA_TAG) || luaL_testudata(L, 1, UD_OPEN_TAG)) {
        panel = [skin toNSObjectAtIndex:1] ;
    } else {
        return luaL_argerror(L, 1, "expected open or save panel userdata") ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, panel.panel.treatsFilePackagesAsDirectories) ;
    } else {
        panel.panel.treatsFilePackagesAsDirectories = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.save:message([message]) -> panelObject | string
/// Method
/// Get or set the message displayed at the top of the save panel.
///
/// Parameters:
///  * `message` - an optional string, default the empty string, specifying a message to show at the top of the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.

/// hs._asm.uitk.panel.open:message([message]) -> panelObject | string
/// Method
/// Get or set the message displayed at the top of the open panel.
///
/// Parameters:
///  * `message` - an optional string, default the empty string, specifying a message to show at the top of the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
static int saveOpen_message(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelSave *panel = nil ;
    if (luaL_testudata(L, 1, USERDATA_TAG) || luaL_testudata(L, 1, UD_OPEN_TAG)) {
        panel = [skin toNSObjectAtIndex:1] ;
    } else {
        return luaL_argerror(L, 1, "expected open or save panel userdata") ;
    }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:panel.panel.message] ;
    } else {
        panel.panel.message = [skin toNSObjectAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.save:title([title]) -> panelObject | string
/// Method
/// Get or set the title of the save panel.
///
/// Parameters:
///  * `title` - an optional string, default "Save", specifying the title of the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.

/// hs._asm.uitk.panel.open:title([title]) -> panelObject | string
/// Method
/// Get or set the title of the open panel.
///
/// Parameters:
///  * `title` - an optional string, default "Open", specifying the title of the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * in macOS 14, the titlebar for Open panels is not visible and this method has no visible effect.
static int saveOpen_title(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelSave *panel = nil ;
    if (luaL_testudata(L, 1, USERDATA_TAG) || luaL_testudata(L, 1, UD_OPEN_TAG)) {
        panel = [skin toNSObjectAtIndex:1] ;
    } else {
        return luaL_argerror(L, 1, "expected open or save panel userdata") ;
    }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:panel.panel.title] ;
    } else {
        panel.panel.title = [skin toNSObjectAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.save:prompt([prompt]) -> panelObject | string
/// Method
/// Get or set the label for the prompt button of the save panel.
///
/// Parameters:
///  * `prompt` - an optional string, default "Save", specifying the label for the prompt (default) button of the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * Keep this relatively short as the button doesn't resize.

/// hs._asm.uitk.panel.open:prompt([prompt]) -> panelObject | string
/// Method
/// Get or set the label for the prompt button of the open panel.
///
/// Parameters:
///  * `prompt` - an optional string, default "Open", specifying the label for the prompt (default) button of the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * Keep this relatively short as the button doesn't resize.
static int saveOpen_prompt(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelSave *panel = nil ;
    if (luaL_testudata(L, 1, USERDATA_TAG) || luaL_testudata(L, 1, UD_OPEN_TAG)) {
        panel = [skin toNSObjectAtIndex:1] ;
    } else {
        return luaL_argerror(L, 1, "expected open or save panel userdata") ;
    }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:panel.panel.prompt] ;
    } else {
        panel.panel.prompt = [skin toNSObjectAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.save:accessory([element]) -> panelObject | elementObject | nil
/// Method
/// Get or set the accessory view for the save panel
///
/// Parameters:
///  * `element` - an optional uitk element, or explicit nil to remove, specifying an additional set of user controls in the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * the accessory element appears above the Cancel and Save buttons at the bottom of the panel and will resize the panel if necessary.

/// hs._asm.uitk.panel.open:accessory([element]) -> panelObject | elementObject | nil
/// Method
/// Get or set the accessory view for the open panel
///
/// Parameters:
///  * `element` - an optional uitk element, or explicit nil to remove, specifying an additional set of user controls in the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * The accessory element is not visible by default -- see [hs._asm.uitk.panel.open:accessoryVisible](#accessoryVisible)
///
///  * If an accessory element has been set with this method, a "Show Options" button will be shown in the open panel so that the user can choose to display the accessory element if they wish.
static int saveOpen_accessoryView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;

    HSUITKPanelSave *panel = nil ;
    if (luaL_testudata(L, 1, USERDATA_TAG) || luaL_testudata(L, 1, UD_OPEN_TAG)) {
        panel = [skin toNSObjectAtIndex:1] ;
    } else {
        return luaL_argerror(L, 1, "expected open or save panel userdata") ;
    }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:panel.panel.accessoryView] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            if (panel.panel.accessoryView) {
                [skin luaRelease:refTable forNSObject:panel.panel.accessoryView] ;
            }
            panel.panel.accessoryView = nil ;
        } else {
            NSView *container = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
            if (!container || !oneOfOurElementObjects(container)) {
                return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
            }
            if (panel.panel.accessoryView) {
                [skin luaRelease:refTable forNSObject:panel.panel.accessoryView] ;
            }
            [skin luaRetain:refTable forNSObject:container] ;
            panel.panel.accessoryView = container ;
        }
        lua_pushvalue(L, 1) ;
    }

    return 1 ;
}

/// hs._asm.uitk.panel.save:validateColumns() -> panelObject
/// Method
/// Validate the contents of the save panel based on any changes that have been made to it since it was presented.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the panelObject
///
/// Notes:
///  * This method may be necessary if, for example, an accessory view offers controls to change panel settings.

/// hs._asm.uitk.panel.open:validateColumns() -> panelObject
/// Method
/// Validate the contents of the open panel based on any changes that have been made to it since it was presented.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the panelObject
///
/// Notes:
///  * This method may be necessary if, for example, an accessory view offers controls to change panel settings.
static int saveOpen_validateVisibleColumns(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;

    HSUITKPanelSave *panel = nil ;
    if (luaL_testudata(L, 1, USERDATA_TAG) || luaL_testudata(L, 1, UD_OPEN_TAG)) {
        panel = [skin toNSObjectAtIndex:1] ;
    } else {
        return luaL_argerror(L, 1, "expected open or save panel userdata") ;
    }

    [panel.panel validateVisibleColumns] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

// documented in panel_save.lua and panel_open.lua
static int saveOpen_allowedContentTypes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;

    HSUITKPanelSave *panel = nil ;
    if (luaL_testudata(L, 1, USERDATA_TAG) || luaL_testudata(L, 1, UD_OPEN_TAG)) {
        panel = [skin toNSObjectAtIndex:1] ;
    } else {
        return luaL_argerror(L, 1, "expected open or save panel userdata") ;
    }

    NSArray *newTypes = (lua_gettop(L) > 1 && lua_type(L, 2) == LUA_TTABLE) ? [skin toNSObjectAtIndex:2] : nil ;
    if (newTypes) {
        BOOL       isGood = [newTypes isKindOfClass:[NSArray class]] ;
        NSUInteger i      = 0 ;
        while (isGood && i < newTypes.count) {
            isGood = [(NSObject *)newTypes[i] isKindOfClass:[NSString class]] ;
            i++ ;
        }

        if (!isGood) {
            return luaL_argerror(L, 2, "expected array of strings") ;
        }
    }
    if (@available(macOS 11, *)) {
        if (lua_gettop(L) == 1) {
            NSMutableArray *tags = [NSMutableArray array] ;
            for (UTType *uti in panel.panel.allowedContentTypes) {
                NSString *identifier = uti.preferredFilenameExtension ;
                if (!identifier) identifier = uti.preferredMIMEType ;
                if (!identifier) identifier = uti.identifier ;
                [tags addObject:identifier] ;
            }
            [skin pushNSObject:tags] ;
        } else {
            if (lua_type(L, 2) == LUA_TNIL) newTypes = [NSArray array] ;
            NSMutableArray *UTITypes = [NSMutableArray array] ;
            for (NSString *tag in newTypes) {
                UTType *uti = nil ;
                if ([tag containsString:@"/"]) {
                    uti = [UTType typeWithMIMEType:tag] ;
                } else if ([tag containsString:@"."]) {
                    uti = [UTType typeWithIdentifier:tag] ;
                }
                if (!uti) {
                    uti = [UTType typeWithFilenameExtension:tag] ;
                }
                if (uti) {
                    [UTITypes addObject:uti] ;
                } else {
                    [skin logInfo:[NSString stringWithFormat:@"%s:contentTypes - unable to parse %@ into a recognized type", USERDATA_TAG, tag]] ;
                }
            }
            panel.panel.allowedContentTypes = UTITypes ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (lua_gettop(L) == 1) {
            [skin pushNSObject:panel.panel.allowedFileTypes] ;
        } else {
            if (lua_type(L, 2) == LUA_TNIL || newTypes.count == 0) {
                panel.panel.allowedFileTypes = nil ;
            } else {
                panel.panel.allowedFileTypes = newTypes ;
            }
            lua_pushvalue(L, 1) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.panel.save:path() -> string
/// Method
/// Get the full path for the filename specified in the save panel.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string containing the full path to the name specified in the save panel, or nil if the filename field is empty.

/// hs._asm.uitk.panel.open:paths() -> table
/// Method
/// Get the full path for the items selected in the open panel.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing one or more strings containing the full path to all of the files selected in the open panel. If no file is currently selected, returns an empty table.
///
/// Notes:
///  * To be able to select more than one file in the panel, see [hs._asm.uitk.panel.open:multipleSelection](#multipleSelection).
static int saveOpen_url(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;

    HSUITKPanelSave *panel = nil ;
    if (luaL_testudata(L, 1, USERDATA_TAG) || luaL_testudata(L, 1, UD_OPEN_TAG)) {
        panel = [skin toNSObjectAtIndex:1] ;
    } else {
        return luaL_argerror(L, 1, "expected open or save panel userdata") ;
    }

    if ([panel isKindOfClass:[HSUITKPanelSave class]]) {
        NSURL *url = panel.panel.URL ;
        if (url) {
            [skin pushNSObject:url.path] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        // docs say that panel.panel.URL will be nil if multiple files selected, but testing
        // shows otherwise, so just stick with the array one
        NSArray *urls = ((HSUITKPanelOpen *)panel).panel.URLs ;
        if (urls) {
            lua_newtable(L) ;
            for (NSURL *item in urls) {
                [skin pushNSObject:item.path] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.panel.save:directory([path]) -> panelObject | string
/// Method
/// Set the initial directory for the save panel or get the current directory once it has been presented.
///
/// Parameters:
///  * `path` - an optional string specifying the initial path the save panel starts in.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * When called without an argument, this method returns the directory currently displayed in the panel.
///
///  * Once the panel has been presented, setting a new value has no effect.

/// hs._asm.uitk.panel.open:directory([path]) -> panelObject | string
/// Method
/// Set the initial directory for the open panel or get the current directory once it has been presented.
///
/// Parameters:
///  * `path` - an optional string specifying the initial path the open panel starts in.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * When called without an argument, this method returns the directory currently displayed in the panel.
///
///  * Once the panel has been presented, setting a new value has no effect.
static int saveOpen_directoryURL(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;

    HSUITKPanelSave *panel = nil ;
    if (luaL_testudata(L, 1, USERDATA_TAG) || luaL_testudata(L, 1, UD_OPEN_TAG)) {
        panel = [skin toNSObjectAtIndex:1] ;
    } else {
        return luaL_argerror(L, 1, "expected open or save panel userdata") ;
    }

    if (lua_gettop(L) == 1) {
        NSURL *url = panel.panel.directoryURL ;
        if (url) {
            [skin pushNSObject:url.path] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        NSString *path = [skin toNSObjectAtIndex:2] ;
        path = path.stringByStandardizingPath ;

        NSURL *fileURL = [NSURL fileURLWithPath:path] ;
        NSNumber *isDirectory ;

        if (![fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil] || !isDirectory.boolValue) {
            fileURL = fileURL.URLByDeletingLastPathComponent ;
        }

        panel.panel.directoryURL = fileURL ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.save:present([window]) -> panelObject
/// Method
/// Displays the panel.
///
/// Parameters:
///  * `window` - an optional `hs._asm.uitk.window` object to display the panel in as a modal sheet.
///
/// Returns:
///  * the panel object
///
/// Notes:
///  * if a `window` object is provided, the window will not allow further editing or modification by the user until the panel is closed by using its Save or Cancel buttons.

/// hs._asm.uitk.panel.open:present([window]) -> panelObject
/// Method
/// Displays the panel.
///
/// Parameters:
///  * `window` - an optional `hs._asm.uitk.window` object to display the panel in as a modal sheet.
///
/// Returns:
///  * the panel object
///
/// Notes:
///  * if a `window` object is provided, the window will not allow further editing or modification by the user until the panel is closed by using its Open or Cancel buttons.
static int saveOpen_presentDialog(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;

    HSUITKPanelSave *panel = nil ;
    if (luaL_testudata(L, 1, USERDATA_TAG) || luaL_testudata(L, 1, UD_OPEN_TAG)) {
        panel = [skin toNSObjectAtIndex:1] ;
    } else {
        return luaL_argerror(L, 1, "expected open or save panel userdata") ;
    }

    if (lua_gettop(L) == 1) {
        [skin luaRetain:refTable forNSObject:panel] ;
        [panel.panel beginWithCompletionHandler:^(NSModalResponse result) {
            NSString *how = (result == NSModalResponseOK) ? @"OK" : @"Cancel" ;
            [panel callbackHamster:@[ panel, how ]] ;
            [skin luaRelease:refTable forNSObject:panel] ;
        }] ;
    } else {
        [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.window", LS_TBREAK] ;
        NSWindow *window = [skin toNSObjectAtIndex:2] ;

        [skin luaRetain:refTable forNSObject:panel] ;
        [panel.panel beginSheetModalForWindow:window completionHandler:^(NSModalResponse result) {
            NSString *how = (result == NSModalResponseOK) ? @"OK" : @"Cancel" ;
            [panel callbackHamster:@[ panel, how ]] ;
            [skin luaRelease:refTable forNSObject:panel] ;
        }] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.panel.save:present() -> panelObject
/// Method
/// Close the panel if it is currently being displayed.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the panel object
///
/// Notes:
///  * if the panel is currently visible and a callback has been set with [hs._asm.uitk.panel.save:callback](#callback), the callback will be triggered as if the user had clicked on the Cancel button.

/// hs._asm.uitk.panel.open:present() -> panelObject
/// Method
/// Close the panel if it is currently being displayed.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the panel object
///
/// Notes:
///  * if the panel is currently visible and a callback has been set with [hs._asm.uitk.panel.open:callback](#callback), the callback will be triggered as if the user had clicked on the Cancel button.
static int saveOpen_cancel(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;

    HSUITKPanelSave *panel = nil ;
    if (luaL_testudata(L, 1, USERDATA_TAG) || luaL_testudata(L, 1, UD_OPEN_TAG)) {
        panel = [skin toNSObjectAtIndex:1] ;
    } else {
        return luaL_argerror(L, 1, "expected open or save panel userdata") ;
    }

    [panel.panel cancel:panel] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.panel.save:callback([fn | nil]) -> panelObject | function | nil
/// Method
/// Get or set the save panel callback function.
///
/// Parameters:
///  * `fn` - an optional function, or explicit nil to remove, that will be called when the user clicks on the Save or Cancel button of the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * The function should expect 2 arguments and return none. The arguments will be one of the following:
///    * `panelObject`, "OK"     - the user clicked on the Save button
///    * `panelObject`, "Cancel" - the user clicked on the Cancel button

/// hs._asm.uitk.panel.open:callback([fn | nil]) -> panelObject | function | nil
/// Method
/// Get or set the open panel callback function.
///
/// Parameters:
///  * `fn` - an optional function, or explicit nil to remove, that will be called when the user clicks on the Open or Cancel button of the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * The function should expect 2 arguments and return none. The arguments will be one of the following:
///    * `panelObject`, "OK"     - the user clicked on the Save button
///    * `panelObject`, "Cancel" - the user clicked on the Cancel button
static int saveOpen_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;

    HSUITKPanelSave *panel = nil ;
    if (luaL_testudata(L, 1, USERDATA_TAG) || luaL_testudata(L, 1, UD_OPEN_TAG)) {
        panel = [skin toNSObjectAtIndex:1] ;
    } else {
        return luaL_argerror(L, 1, "expected open or save panel userdata") ;
    }

    if (lua_gettop(L) == 2) {
        panel.callbackRef = [skin luaUnref:panel.refTable ref:panel.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            panel.callbackRef = [skin luaRef:panel.refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (panel.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:panel.refTable ref:panel.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

#pragma mark - Save Only Methods -

/// hs._asm.uitk.panel.save:canToggleHiddenExtensions([state]) -> panelObject | boolean
/// Method
/// Get or set whether the save panel allows toggling the display of file extensions in the panel.
///
/// Parameters:
///  * `state` - an optional boolean, default false, indicating whether the user is allowed to toggle the display of filename extensions in the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * if the Finder setting "Show all filename extensions" has been enabled, this method has no effect -- filename extensions will always be visible.
static int save_canSelectHiddenExtension(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelSave *panel = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, panel.panel.canSelectHiddenExtension) ;
    } else {
        panel.panel.canSelectHiddenExtension = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.save:extensionHidden([state]) -> panelObject | boolean
/// Method
/// Get or set whether the save panel shows file extensions in the panel.
///
/// Parameters:
///  * `state` - an optional boolean, default false, indicating whether the user shows filename extensions in the panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * if the Finder setting "Show all filename extensions" has been enabled, this method has no effect -- filename extensions will always be visible.
static int save_extensionHidden(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelSave *panel = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, panel.panel.extensionHidden) ;
    } else {
        panel.panel.extensionHidden = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.save:isExpanded() -> boolean
/// Method
/// Get whether or not the save panel is in its expanded form.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean indicating whether the save panel is in its expanded form (true) or its compressed form (false)
static int save_isExpanded(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelSave *panel = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, panel.panel.expanded) ;
    return 1 ;
}

/// hs._asm.uitk.panel.save:allowsOtherFileTypes([state]) -> panelObject | boolean
/// Method
/// Get or set whether the save panel allows the user to specify a file with an extension other than those set in [hs._asm.uitk.panel.save:contentTypes](#contentTypes)
///
/// Parameters:
///  * `state` - an optional boolean, default false, indicating whether the user is allowed to specify a file extension not explicitely allowed by the types specified in [hs._asm.uitk.panel.save:contentTypes](#contentTypes)
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * If this is set to `false`, the user will be prompted to use an allowed extension, or to append an allowed extension to the one in the proposed file name.
///  * If this is set to `true`, the user will be prompted to use an allowed extension, or confirm the use of the unspecified extension.
static int save_allowsOtherFileTypes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelSave *panel = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, panel.panel.allowsOtherFileTypes) ;
    } else {
        panel.panel.allowsOtherFileTypes = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.save:filenameLabel([label]) -> panelObject | string
/// Method
/// Get or set the label displayed before the field where the user can type in a filename
///
/// Parameters:
///  * `label` - an optional string, default "Save As:", specifying the label that precedes the textfield where the user can type in a file name.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
static int save_nameFieldLabel(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelSave *panel = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:panel.panel.nameFieldLabel] ;
    } else {
        panel.panel.nameFieldLabel = [skin toNSObjectAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.save:filename([name]) -> panelObject | string
/// Method
/// Get or set the filename currently displayed in the panel's filename field
///
/// Parameters:
///  * `name` - an optional string, default "Untitled", specifying the name of the file to be saved.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * This value may or may not include a file extension; check [hs._asm.uitk.panel.save:path](#path) if you want a fully proper name and path.
static int save_nameFieldStringValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelSave *panel = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:panel.panel.nameFieldStringValue] ;
    } else {
        panel.panel.nameFieldStringValue = [skin toNSObjectAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.save:showsTagField([state]) -> panelObject | boolean
/// Method
/// Get or set whether the save panel displays the Tags field
///
/// Parameters:
///  * `state` - an optional boolean, default false, indicating whether the save panel displays the Tags field
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
static int save_showsTagField(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelSave *panel = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, panel.panel.showsTagField) ;
    } else {
        panel.panel.showsTagField = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.save:tagNames([tags | nil]) -> panelObject | table | nil
/// Method
/// Get or set the tags displayed in the Tags field of the save panel
///
/// Parameters:
///  * `tags` - an optional table, or explicit nil to clear, the Tags field of the save panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * if [hs._asm.uitk.panel.save:showsTagField](#showsTagField) is false, this method will return nil and does not allow the setting of any tags (i.e. it will be silently ignored).
///  * if [hs._asm.uitk.panel.save:showsTagField](#showsTagField) is true, then this method can be used to get or set the tags the user has selected for this file. Specifying an explicit `nil` is equivalent to specifying an empty table.
static int save_tagNames(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelSave *panel = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:panel.panel.tagNames] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            panel.panel.tagNames = nil ;
        } else {
            NSArray *tags = [skin toNSObjectAtIndex:2] ;
            BOOL       isGood = [tags isKindOfClass:[NSArray class]] ;
            NSUInteger i      = 0 ;
            while (isGood && i < tags.count) {
                isGood = [(NSObject *)tags[i] isKindOfClass:[NSString class]] ;
                i++ ;
            }

            if (isGood) {
                panel.panel.tagNames = tags ;
            } else {
                return luaL_argerror(L, 2, "expected array of strings") ;
            }
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Open Only Methods -

/// hs._asm.uitk.panel.open:multipleSelection([state]) -> panelObject | boolean
/// Method
/// Get or set whether the open panel allows the user to select more than one file.
///
/// Parameters:
///  * `state` - an optional boolean, default false, indicating whether the user is allowed to select more than one file with the open panel.
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * if this method is set to true, the user can select more than one file to open by using the Shift or Command keys to make multiple selections.
static int open_allowsMultipleSelection(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelOpen *panel = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, panel.panel.allowsMultipleSelection) ;
    } else {
        panel.panel.allowsMultipleSelection = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.open:selectDirectories([state]) -> panelObject | boolean
/// Method
/// Get or set whether the open panel allows the user to select a directory as the item to be opened.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether the user is allowed to select a directory as an item to be opened (true) or not (false).
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * if both this method and [hs._asm.uitk.panel.open:selectFiles](#selectFiles) are set to false, the user will not be able to select anything with the open panel and only the Cancel button will be choosable by the user.
static int open_canChooseDirectories(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelOpen *panel = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, panel.panel.canChooseDirectories) ;
    } else {
        panel.panel.canChooseDirectories = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.open:selectFiles([state]) -> panelObject | boolean
/// Method
/// Get or set whether the open panel allows the user to select a file as the item to be opened.
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether the user is allowed to select a file as an item to be opened (true) or not (false).
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * if both this method and [hs._asm.uitk.panel.open:selectDirectories](#selectDirectories) are set to false, the user will not be able to select anything with the open panel and only the Cancel button will be choosable by the user.
static int open_canChooseFiles(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelOpen *panel = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, panel.panel.canChooseFiles) ;
    } else {
        panel.panel.canChooseFiles = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// static int open_canDownloadUbiquitousContents(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
//     HSUITKPanelOpen *panel = [skin toNSObjectAtIndex:1] ;
//
//     if (lua_gettop(L) == 1) {
//         lua_pushboolean(L, panel.panel.canDownloadUbiquitousContents) ;
//     } else {
//         panel.panel.canDownloadUbiquitousContents = (BOOL)(lua_toboolean(L, 2)) ;
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }

// static int open_canResolveUbiquitousConflicts(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
//     HSUITKPanelOpen *panel = [skin toNSObjectAtIndex:1] ;
//
//     if (lua_gettop(L) == 1) {
//         lua_pushboolean(L, panel.panel.canResolveUbiquitousConflicts) ;
//     } else {
//         panel.panel.canResolveUbiquitousConflicts = (BOOL)(lua_toboolean(L, 2)) ;
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }

/// hs._asm.uitk.panel.open:resolveAliases([state]) -> panelObject | boolean
/// Method
/// Get or set whether the open panel allows the selection of the item an alias refers to or the alias itself.
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether selecting an alias selects the file the alias refers to (true) or the alias itself (false)
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
static int open_resolvesAliases(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelOpen *panel = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, panel.panel.resolvesAliases) ;
    } else {
        panel.panel.resolvesAliases = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.panel.open:accessoryVisible([state]) -> panelObject | boolean
/// Method
/// Get or set whether the accessory element in the open panel is currently visible or not.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether an accessory element, if one is provided, is visible (true) or not (false).
///
/// Returns:
///  * if an argument is provided, returns the panel object; otherwise returns the current value.
///
/// Notes:
///  * if no accessory has been set with [hs._asm.uitk.panel.open:accessory](#accessory) then this method has no effect.
static int open_accessoryViewDisclosed(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelOpen *panel = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, panel.panel.accessoryViewDisclosed) ;
    } else {
        panel.panel.accessoryViewDisclosed = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKPanelSave(lua_State *L, id obj) {
    HSUITKPanelSave *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKPanelSave *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKPanelSave(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKPanelSave *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKPanelSave, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushHSUITKPanelOpen(lua_State *L, id obj) {
    HSUITKPanelOpen *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKPanelOpen *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_OPEN_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKPanelOpen(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKPanelOpen *value ;
    if (luaL_testudata(L, idx, UD_OPEN_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKPanelOpen, L, idx, UD_OPEN_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_OPEN_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSString *tag      = @"<not userdata>" ;

    if (lua_getmetatable(L, -1)) {
        lua_getfield(L, -1, "__name") ;
        tag = [NSString stringWithUTF8String:lua_tostring(L, -1)] ;
        lua_pop(L, 2) ;
    }

    [skin pushNSObject:[NSString stringWithFormat:@"%@: (%p)", tag, lua_topointer(L, 1)]] ;
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
    HSUITKPanelSave *obj = (__bridge_transfer HSUITKPanelSave *)*((void**)lua_touserdata(L, 1)) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            if (obj.accessory) {
                [skin luaRelease:refTable forNSObject:obj.accessory] ;
                obj.accessory = nil ;
            }
            obj.panel = nil ;
            obj = nil ;
        }
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"canCreateDirectories",      saveOpen_canCreateDirectories},
    {"showHiddenFiles",           saveOpen_showsHiddenFiles},
    {"packagesAsDirectories",     saveOpen_treatsFilePackagesAsDirectories},
    {"message",                   saveOpen_message},
    {"title",                     saveOpen_title},
    {"prompt",                    saveOpen_prompt},
    {"accessory",                 saveOpen_accessoryView},
    {"contentTypes",              saveOpen_allowedContentTypes},
    {"directory",                 saveOpen_directoryURL},
    {"callback",                  saveOpen_callback},

    {"allowsOtherFileTypes",      save_allowsOtherFileTypes},
    {"canToggleHiddenExtensions", save_canSelectHiddenExtension},
    {"extensionHidden",           save_extensionHidden},
    {"filenameLabel",             save_nameFieldLabel},
    {"filename",                  save_nameFieldStringValue},
    {"showsTagField",             save_showsTagField},
    {"tagNames",                  save_tagNames},

    {"isExpanded",                save_isExpanded},

    {"cancel",                    saveOpen_cancel},
    {"isVisible",                 saveOpen_isVisible},
    {"validateColumns",           saveOpen_validateVisibleColumns},
    {"path",                      saveOpen_url},
    {"present",                   saveOpen_presentDialog},

    {"__tostring",                userdata_tostring},
    {"__eq",                      userdata_eq},
    {"__gc",                      userdata_gc},
    {NULL, NULL}
};

static const luaL_Reg ud_open_metaLib[] = {
    {"canCreateDirectories",          saveOpen_canCreateDirectories},
    {"showHiddenFiles",               saveOpen_showsHiddenFiles},
    {"packagesAsDirectories",         saveOpen_treatsFilePackagesAsDirectories},
    {"message",                       saveOpen_message},
    {"title",                         saveOpen_title},
    {"prompt",                        saveOpen_prompt},
    {"accessory",                     saveOpen_accessoryView},
    {"contentTypes",                  saveOpen_allowedContentTypes},
    {"directory",                     saveOpen_directoryURL},
    {"callback",                      saveOpen_callback},

    {"multipleSelection",             open_allowsMultipleSelection},
    {"selectDirectories",             open_canChooseDirectories},
    {"selectFiles",                   open_canChooseFiles},
    {"resolveAliases",                open_resolvesAliases},
    {"accessoryVisible",              open_accessoryViewDisclosed},
//     {"canDownloadUbiquitousContents", open_canDownloadUbiquitousContents},
//     {"canResolveUbiquitousConflicts", open_canResolveUbiquitousConflicts},

    {"cancel",                        saveOpen_cancel},
    {"isVisible",                     saveOpen_isVisible},
    {"validateColumns",               saveOpen_validateVisibleColumns},
    {"paths",                         saveOpen_url},
    {"present",                       saveOpen_presentDialog},

    {"__tostring",                    userdata_tostring},
    {"__eq",                          userdata_eq},
    {"__gc",                          userdata_gc},
    {NULL, NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", save_new},
    {NULL,  NULL}
};

static luaL_Reg openModuleLib[] = {
    {"new", open_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs__asm_uitk_libpanel_save(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    // since the Save and Open panels are related and share so much, we define them together
    // (i.e. this file) but expose them separately -- this creates the open panel "module"
    // which we can separate lua-side
    luaL_newlib(L, openModuleLib) ; lua_setfield(L, -2, "_open") ;
    [skin registerObject:UD_OPEN_TAG  objectFunctions:ud_open_metaLib] ;

    [skin registerPushNSHelper:pushHSUITKPanelSave  forClass:"HSUITKPanelSave"];
    [skin registerLuaObjectHelper:toHSUITKPanelSave forClass:"HSUITKPanelSave"
                                         withUserdataMapping:USERDATA_TAG];

    [skin registerPushNSHelper:pushHSUITKPanelOpen  forClass:"HSUITKPanelOpen"];
    [skin registerLuaObjectHelper:toHSUITKPanelOpen forClass:"HSUITKPanelOpen"
                                         withUserdataMapping:UD_OPEN_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"canCreateDirectories",
        @"showHiddenFiles",
        @"packagesAsDirectories",
        @"message",
        @"title",
        @"prompt",
        @"accessory",
        @"contentTypes",
        @"directory",
        @"callback",

        @"allowsOtherFileTypes",
        @"canToggleHiddenExtensions",
        @"extensionHidden",
        @"filenameLabel",
        @"filenameValue",
        @"showsTagField",
        @"tagNames",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    luaL_getmetatable(L, UD_OPEN_TAG) ;
    [skin pushNSObject:@[
        @"canCreateDirectories",
        @"showHiddenFiles",
        @"packagesAsDirectories",
        @"message",
        @"title",
        @"prompt",
        @"accessory",
        @"contentTypes",
        @"directory",
        @"callback",

        @"multipleSelection",
        @"selectDirectories",
        @"selectFiles",
        @"resolveAliases",
        @"accessoryVisible",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
