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

BOOL oneOfOurs(NSView *obj) {
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
        NSObject *nextInChain = [self.panel nextResponder] ;
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
        NSObject *nextInChain = [self.panel nextResponder] ;
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

#pragma mark NSOpenSavePanelDelegate methods
// - (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url;
// - (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError * _Nullable *)outError;
// - (NSString *)panel:(id)sender userEnteredFilename:(NSString *)filename confirmed:(BOOL)okFlag;
// - (void)panel:(id)sender didChangeToDirectoryURL:(NSURL *)url;
// - (void)panel:(id)sender willExpand:(BOOL)expanding;
// - (void)panelSelectionDidChange:(id)sender;

@end

#pragma mark - Module Functions -

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
            if (!container || !oneOfOurs(container)) {
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

static int save_isExpanded(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKPanelSave *panel = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, panel.panel.expanded) ;
    return 1 ;
}

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
    {"canCreateDirectories",     saveOpen_canCreateDirectories},
    {"showHiddenFiles",          saveOpen_showsHiddenFiles},
    {"packagesAsDirectories",    saveOpen_treatsFilePackagesAsDirectories},
    {"message",                  saveOpen_message},
    {"title",                    saveOpen_title},
    {"prompt",                   saveOpen_prompt},
    {"accessory",                saveOpen_accessoryView},
    {"contentTypes",             saveOpen_allowedContentTypes},
    {"directory",                saveOpen_directoryURL},
    {"callback",                 saveOpen_callback},

    {"allowsOtherFileTypes",     save_allowsOtherFileTypes},
    {"canSelectHiddenExtension", save_canSelectHiddenExtension},
    {"extensionHidden",          save_extensionHidden},
    {"filenameLabel",            save_nameFieldLabel},
    {"filenameValue",            save_nameFieldStringValue},
    {"showsTagField",            save_showsTagField},
    {"tagNames",                 save_tagNames},

    {"isExpanded",               save_isExpanded},
    {"isVisible",                saveOpen_isVisible},
    {"validateColumns",          saveOpen_validateVisibleColumns},
    {"path",                     saveOpen_url},
    {"present",                  saveOpen_presentDialog},

    {"__tostring",               userdata_tostring},
    {"__eq",                     userdata_eq},
    {"__gc",                     userdata_gc},
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
        @"allowsOtherFileTypes",
        @"canCreateDirectories",
        @"canSelectHiddenExtension",
        @"showHiddenFiles",
        @"packagesAsDirectories",
        @"extensionHidden",
        @"message",
        @"filenameLabel",
        @"filenameValue",
        @"title",
        @"prompt",
        @"accessory",
        @"contentTypes",
        @"directory",
        @"callback",
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
