@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;

//    removing element attribute for now for simplifying... we'll see if it's missed

// TODO: Master List of Major Crap
//
//    add console support
//    legacy support (wait for webview?)
//
//    if a group item is visible and has more than 1 subitem, and window:toolbarStyle("preference") is invoked, HS crashes
//        if group item defined and allowed and has more than 1 subitem, customizing toolbar crashes, even though not visible
//           need to prevent change in window:toolbarStyle, updateItem, addItem, others?
//           should toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar: suppress them? would only fix 2nd case, not first
//
//    update without replace needs to be specific when groupMembers changes
//        i.e. applyDefinition shouldn't remove existing and remaining items, just tweak and reassign array
//
//    centered methods for toolbar
//
//    implement HSUITKSearchToolbarItem, will need pre-11 implementation as well
//              HSUITKSharingServicePickerToolbarItem ?
//              HSUITKTrackingSeparatorToolbarItem    ?
//
// +  toolbar and dictionary constructors
// +  add/modify/delete need to check and update if identifier for a present subitem
// +  menuForm, menu, element properties need to accept false to clear and reset to "normal"
// +      item metamethods should take nil, but also need to compare to initial and conditionally release existing
//
// +  toolbar group item members when toolbar set to display label only, target to callback is group item, not group member
// +      convert target/action to self (i.e. the toolbar item itself)
// +      will have to change dictionary item method as well
//
// +  I think menu, menuForm, and element will need to be copied from dict in [toolbar applyDefinition:toItem:]
//        must test...
//
// +  should a removed (and visible) subitem revert to placeholder as the "owner" still lists them in groupMembers?
// +      already creates placeholder item when identifier not found
//
// +  item dealloc removes menu, menuForm, etc. instead of userdata
// +  when dictionary adds, modifies, or removes item definition, trigger update on all assigned toolbars
//
// +  add/modify should invoke validate, not lua functions to keep retain/release cleaner
// +      modify add/modify to use error style of validate
// +      remove as well? Not sure it really can fail if identifier exists...
//
// +  dictionary needs array of weak references to all toolbars it is the delegate for
// +  make type unchangeable? we can't change an instantiated item, so it can only affect new items
// +       or remove and replace at same location in toolbar?
// +  prevent adding group into group (throws exception)
//
// *  make pass through's for toolbar to dictionary methods? (lua side?)
// *      is there a reason dictionary *needs* to be visible to user?
// *      yeah, probably cleaner when using same toolbar identifier in multiple windows
//
// *  subclass other item types
// *  move item to userdata and add methods -- note methods will only affect specific instance, not dictionary

static const char * const USERDATA_TAG = "hs._asm.uitk.toolbar" ;
static const char * const UD_DICT_TAG  = "hs._asm.uitk.toolbar.dictionary" ;
static const char * const UD_ITEM_TAG  = "hs._asm.uitk.toolbar.item" ;

static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSMapTable   *knownDictionaries ;

static NSDictionary *DISPLAY_MODES ;
static NSDictionary *SIZE_MODES ;
static NSArray      *ITEM_TYPES ;
static NSDictionary *GROUP_SELECTION_MODES ;
static NSDictionary *GROUP_REPRESENTATION ;

#pragma mark - Support Functions and Classes -

// static BOOL oneOfOurElementObjects(NSView *obj) {
//     return [obj isKindOfClass:[NSView class]]  &&
//            [obj respondsToSelector:NSSelectorFromString(@"selfRefCount")] &&
//            [obj respondsToSelector:NSSelectorFromString(@"setSelfRefCount:")] &&
//            [obj respondsToSelector:NSSelectorFromString(@"refTable")] &&
//            [obj respondsToSelector:NSSelectorFromString(@"callbackRef")] &&
//            [obj respondsToSelector:NSSelectorFromString(@"setCallbackRef:")] ;
// }

static void defineInternalDictionaries(void) {
    DISPLAY_MODES = @{
        @"default" : @(NSToolbarDisplayModeDefault),
        @"both"    : @(NSToolbarDisplayModeIconAndLabel),
        @"icon"    : @(NSToolbarDisplayModeIconOnly),
        @"label"   : @(NSToolbarDisplayModeLabelOnly),
    } ;

    SIZE_MODES = @{
        @"default" : @(NSToolbarSizeModeDefault),
        @"regular" : @(NSToolbarSizeModeRegular),
        @"small"   : @(NSToolbarSizeModeSmall),
    } ;

    ITEM_TYPES = @[ @"item", @"group", @"menu" ] ;

    GROUP_SELECTION_MODES = @{
        @"momentary" : @(NSToolbarItemGroupSelectionModeMomentary),
        @"multiple"  : @(NSToolbarItemGroupSelectionModeSelectAny),
        @"single"    : @(NSToolbarItemGroupSelectionModeSelectOne),
    } ;

    GROUP_REPRESENTATION = @{
        @"automatic" : @(NSToolbarItemGroupControlRepresentationAutomatic),
        @"expanded"  : @(NSToolbarItemGroupControlRepresentationExpanded),
        @"collapsed" : @(NSToolbarItemGroupControlRepresentationCollapsed),
    } ;
}

static BOOL isNSNumberActuallyABoolean(NSNumber *num) {
   CFTypeID boolID = CFBooleanGetTypeID() ;                   // the type ID of CFBoolean
   CFTypeID numID  = CFGetTypeID((__bridge CFTypeRef)(num)) ; // the type ID of num
   return numID == boolID;
}

@interface NSMenu (HammerspoonAdditions)
@property (weak) NSResponder *assignedTo ;

- (instancetype)copyWithState:(lua_State *)L ;
@end

@interface NSMenuItem (HammerspoonAdditions)
- (instancetype)copyWithState:(lua_State *)L ;
@end

@interface HSUITKToolbar : NSToolbar
@property            int      callbackRef ;
@property            int      selfRefCount ;
@property            BOOL     notifyToolbarChanges ;
@property (weak)     NSWindow *window ;
@end

@interface HSUITKToolbarDictionary : NSObject <NSToolbarDelegate>
@property (readonly)         NSString *identifier ;
@property                    int      selfRefCount ;

// The following properties have custom getters/setters
@property (atomic, readonly) NSDictionary<NSToolbarIdentifier, NSDictionary *> *itemDefinitions ;
@property (atomic)           NSArray<NSToolbarItemIdentifier>                  *allowedIdentifiers ;
@property (atomic)           NSArray<NSToolbarItemIdentifier>                  *defaultIdentifiers ;
@property (atomic, readonly) NSArray<NSToolbarIdentifier>                      *selectableIdentifiers ;
@property (atomic, readonly) NSSet<NSToolbarIdentifier>                        *immovableIdentifiers ;
@property (atomic, readonly) NSArray<NSToolbarIdentifier>                      *definedIdentifiers ;

- (NSToolbarItem *)newEmptyItem:(NSString *)itemIdentifier ofType:(NSString *)type ;
@end

@interface HSUITKToolbarItem : NSToolbarItem
@property            int        selfRefCount ;
@property            BOOL       enableOverrideDictionary ;
@property            NSMenuItem *ourMenuFormRepresentation ;
@property (readonly) NSMenuItem *initialMenuFormRepresentation ;
@end

@interface HSUITKToolbarItemGroup : NSToolbarItemGroup
@property          int          selfRefCount ;
@property          BOOL         enableOverrideDictionary ;
@property            NSMenuItem *ourMenuFormRepresentation ;
@property (readonly) NSMenuItem *initialMenuFormRepresentation ;
@end

@interface HSUITKMenuToolbarItem: NSMenuToolbarItem
@property          int          selfRefCount ;
@property          BOOL         enableOverrideDictionary ;
@property            NSMenuItem *ourMenuFormRepresentation ;
@property (readonly) NSMenuItem *initialMenuFormRepresentation ;
@property (readonly) NSMenu     *initialMenu ;
@end

// @interface HSUITKSearchToolbarItem : NSSearchToolbarItem
// @interface HSUITKSharingServicePickerToolbarItem : NSSharingServicePickerToolbarItem
// @interface HSUITKTrackingSeparatorToolbarItem : NSTrackingSeparatorToolbarItem

@implementation HSUITKToolbar

- (instancetype)initWithDictionary:(HSUITKToolbarDictionary *)dictionary withState:(lua_State *)L {
    self = [super initWithIdentifier:dictionary.identifier] ;
    if (self) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;

        _selfRefCount         = 0 ;
        _callbackRef          = LUA_NOREF ;
        _notifyToolbarChanges = NO ;
        _window               = nil ;

        [skin luaRetain:refTable forNSObject:dictionary] ;
        self.delegate         = dictionary ;
    }
    return self ;
}

- (void)dealloc {
    if (self.delegate) {
        LuaSkin                 *skin       = [LuaSkin sharedWithState:NULL] ;
        HSUITKToolbarDictionary *dictionary = self.delegate ;

        // we retain in initWithDictionary:withState: so, deallocate here instead of _gc
        [skin luaRelease:refTable forNSObject:dictionary] ;
        self.delegate = nil ;
    }
}

- (void)callbackHamster:(NSArray *)messageParts {
    [self callbackHamster:messageParts withCallback:LUA_NOREF] ;
}

- (void)callbackHamster:(NSArray *)messageParts withCallback:(int)callbackRef { // does the "heavy lifting"
    if (callbackRef == LUA_NOREF) callbackRef = _callbackRef ;

    if (callbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        [skin pushLuaRef:refTable ref:callbackRef] ;
        for (id part in messageParts) [skin pushNSObject:part] ;
        if (![skin protectedCallAndTraceback:(int)messageParts.count nresults:0]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            lua_pop(skin.L, 1) ;
            [skin logError:@"%s:callback error:%@", USERDATA_TAG, errorMessage] ;
        }
    } else {
        // allow next responder a chance since we don't have a callback set
        NSResponder *nextInChain = _window ;
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

// we don't actually support this, but HSUITKMenu will check for this, so this needs exist to prevent
// an attempt to call nextResponder on us, which we don't have...
- (void)performPassthroughCallback:(NSArray *)arguments {
    [self callbackHamster:@[ self, arguments ]] ;
}

@end

@implementation HSUITKToolbarDictionary {
    NSMutableDictionary *_itemDefinitions ;
    NSMutableOrderedSet *_allowedIdentifiers ;
    NSMutableArray      *_defaultIdentifiers ;    // can have duplicates
    NSHashTable         *_toolbars ;              // attached toolbars so we can notify of dictionary changes
}

- (instancetype)initWithIdentifier:(NSToolbarIdentifier)identifier {
    self = [super init] ;
    if (self) {
        _identifier            = identifier ;
        _selfRefCount          = 0 ;

        _toolbars              = [NSHashTable weakObjectsHashTable] ;

        _itemDefinitions       = [NSMutableDictionary dictionary] ;
        _allowedIdentifiers    = [NSMutableOrderedSet orderedSet] ;
        _defaultIdentifiers    = [NSMutableArray array] ;
    }
    return self ;
}

- (void)dealloc {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;

    // we retain items with userdata in validatePropertiesAtIndex:forIdentifier:withState:error:,
    // so remove via deleteItem:withState:

    for (NSString *key in _itemDefinitions.allKeys) [self deleteItem:key withState:skin.L error:NULL] ;
}

- (void)addToolbar:(HSUITKToolbar *)toolbar {
    [_toolbars addObject:toolbar] ;
}

- (void)removeToolbar:(HSUITKToolbar *)toolbar {
    [_toolbars removeObject:toolbar] ;
}

- (void)toolbarItemCallback:(NSToolbarItem *)toolbarItem {
    HSUITKToolbar *toolbar    = (HSUITKToolbar *)toolbarItem.toolbar ;
    int           callbackRef = LUA_NOREF ;

    if (toolbar) {
        NSDictionary *itemDefinition = self.itemDefinitions[toolbarItem.itemIdentifier] ;
        NSNumber *tempNumber = itemDefinition[@"callback"] ;
        if (tempNumber) callbackRef = tempNumber.intValue ;
        [toolbar callbackHamster:@[ toolbar, @"action", toolbarItem ] withCallback:callbackRef] ;
    }
}

#pragma mark custom getters and setters

- (NSDictionary<NSToolbarIdentifier, NSDictionary *> *)itemDefinitions {
    NSDictionary *definitions ;
    @synchronized (self) {
        definitions = [[NSDictionary alloc] initWithDictionary:_itemDefinitions copyItems:YES] ;
    }
    return definitions ;
}

- (NSArray<NSToolbarItemIdentifier> *)allowedIdentifiers {
    NSArray *identifiers ;
    @synchronized (self) {
        identifiers = _allowedIdentifiers.array.copy ;
    }
    return identifiers ;
}

- (void)setAllowedIdentifiers:(NSArray<NSToolbarItemIdentifier> *)identifiers {
    [self willChangeValueForKey:@"allowedIdentifiers"];
    @synchronized (self) {
        _allowedIdentifiers = [NSMutableOrderedSet orderedSetWithArray:identifiers] ;
    }
    [self didChangeValueForKey:@"allowedIdentifiers"];
}

- (NSArray<NSToolbarIdentifier> *)defaultIdentifiers {
    NSArray *identifiers ;
    @synchronized (self) {
        identifiers = _defaultIdentifiers.copy ;
    }
    return identifiers ;
}

- (void)setDefaultIdentifiers:(NSArray<NSToolbarItemIdentifier> *)identifiers {
    [self willChangeValueForKey:@"defaultIdentifiers"];
    @synchronized (self) {
        _defaultIdentifiers = identifiers.mutableCopy ;
    }
    [self didChangeValueForKey:@"defaultIdentifiers"];
}

- (NSArray<NSToolbarIdentifier> *)selectableIdentifiers {
    NSMutableArray *identifiers        = [NSMutableArray arrayWithCapacity:_allowedIdentifiers.count] ;
    NSArray        *allowedIdentifiers = self.allowedIdentifiers ;
    NSDictionary   *definitions        = self.itemDefinitions ;

    for (NSString *name in allowedIdentifiers) {
        NSDictionary *item = definitions[name] ;
        if (item) {
            NSNumber *selectable = item[@"selectable"] ;
            if (selectable && selectable.boolValue) [identifiers addObject:name] ;
        }
    }
    return identifiers.copy ;
}

- (NSSet<NSToolbarIdentifier> *)immovableIdentifiers {
    NSMutableSet *identifiers        = [NSMutableSet setWithCapacity:_allowedIdentifiers.count] ;
    NSArray      *allowedIdentifiers = self.allowedIdentifiers ;
    NSDictionary *definitions        = self.itemDefinitions ;

    for (NSString *name in allowedIdentifiers) {
        NSDictionary *item = definitions[name] ;
        if (item) {
            NSNumber *immovable = item[@"immovable"] ;
            if (immovable && immovable.boolValue) [identifiers addObject:name] ;
        }
    }
    return identifiers.copy ;
}

- (NSArray<NSToolbarIdentifier> *)definedIdentifiers {
    NSArray *identifiers = self.itemDefinitions.allKeys ;
    return identifiers ;
}

#pragma mark Updates to _itemDefinitions and supporting objects

- (NSToolbarItem *)newEmptyItem:(NSString *)itemIdentifier ofType:(NSString *)type {
    NSToolbarItem *toolbarItem    = nil ;

    if ([type isEqualToString:@"group"]) {
        toolbarItem = (NSToolbarItem *)[[HSUITKToolbarItemGroup alloc] initWithItemIdentifier:itemIdentifier] ;
    } else if ([type isEqualToString:@"menu"]) {
        toolbarItem = (NSToolbarItem *)[[HSUITKMenuToolbarItem alloc] initWithItemIdentifier:itemIdentifier] ;
    } else { // it's an item
        toolbarItem = (NSToolbarItem *)[[HSUITKToolbarItem alloc] initWithItemIdentifier:itemIdentifier] ;
    }

    if (![type isEqualToString:@"group"]) {
        toolbarItem.target  = toolbarItem ;
        toolbarItem.action  = @selector(toolbarItemCallback:) ;
    }

    return toolbarItem ;
}

- (NSDictionary *)validatePropertiesAtIndex:(int)idx forIdentifier:(NSString *)identifier
                                                         withState:(lua_State *)L
                                                             error:(NSError * __autoreleasing *)error {
    LuaSkin                                     *skin         = [LuaSkin sharedWithState:L] ;
    NSMutableDictionary<NSString *, NSObject *> *details = [NSMutableDictionary dictionary] ;
    NSString                                    *errMsg       = nil ;

    idx = lua_absindex(L, idx) ;

    lua_pushnil(L);  /* first key */
    while (lua_next(L, idx) != 0) { // puts 'key' at index -2 and 'value' at index -1
        NSString *keyName ;
        NSObject *value ;
        if (lua_type(L, -2) == LUA_TSTRING) {
            keyName = [skin toNSObjectAtIndex:-2] ;
            value   = nil ;
            if ([keyName isEqualToString:@"type"]) {
                if (lua_type(L, -1) == LUA_TSTRING) {
                    NSString *type = [skin toNSObjectAtIndex:-1] ;
                    if ([ITEM_TYPES containsObject:type]) {
                        value = type ;
                    } else {
                        errMsg = [NSString stringWithFormat:@"type must be one of %@", [ITEM_TYPES componentsJoinedByString:@", "]] ;
                    }
                } else {
                    errMsg = @"expected a string for type key" ;
                }
            } else if ([keyName isEqualToString:@"label"]) {
                if (lua_type(L, -1) == LUA_TSTRING) {
                    value = [skin toNSObjectAtIndex:-1] ;
                } else {
                    errMsg = @"expected a string for label key" ;
                }
            } else if ([keyName isEqualToString:@"paletteLabel"]) {
                if (lua_type(L, -1) == LUA_TSTRING) {
                    value = [skin toNSObjectAtIndex:-1] ;
                } else {
                    errMsg = @"expected a string for paletteLabel key" ;
                }
            } else if ([keyName isEqualToString:@"tooltip"]) {
                if (lua_type(L, -1) == LUA_TSTRING) {
                    value = [skin toNSObjectAtIndex:-1] ;
                } else if (lua_type(L, -1) == LUA_TBOOLEAN && !lua_toboolean(L, -1)) {
                    value = @((BOOL)(lua_toboolean(L, -1))) ;
                } else {
                    errMsg = @"expected a string for tooltip key or false to remove" ;
                }
            } else if ([keyName isEqualToString:@"image"]) {
                if (lua_type(L, -1) == LUA_TUSERDATA && luaL_testudata(L, -1, "hs.image")) {
                    value = [skin toNSObjectAtIndex:-1] ;
                } else if (lua_type(L, -1) == LUA_TBOOLEAN && !lua_toboolean(L, -1)) {
                    value = @((BOOL)(lua_toboolean(L, -1))) ;
                } else {
                    errMsg = @"expected hs.image object for image key or false to remove" ;
                }
            } else if ([keyName isEqualToString:@"priority"]) {
                if (lua_type(L, -1) == LUA_TNUMBER && lua_isinteger(L, -1)) {
                    value = @(lua_tointeger(L, -1)) ;
                } else {
                    errMsg = @"expected integer for priority key" ;
                }
            } else if ([keyName isEqualToString:@"tag"]) {
                if (lua_type(L, -1) == LUA_TNUMBER && lua_isinteger(L, -1)) {
                    value = @(lua_tointeger(L, -1)) ;
                } else {
                    errMsg = @"expected integer for tag key" ;
                }
            } else if ([keyName isEqualToString:@"enabled"]) {
                if (lua_type(L, -1) == LUA_TBOOLEAN) {
                    value = @((BOOL)(lua_toboolean(L, -1))) ;
                } else {
                    errMsg = @"expected boolean for enabled key" ;
                }
            } else if ([keyName isEqualToString:@"bordered"]) {
                if (lua_type(L, -1) == LUA_TBOOLEAN) {
                    value = @((BOOL)(lua_toboolean(L, -1))) ;
                } else {
                    errMsg = @"expected boolean for bordered key" ;
                }
            } else if ([keyName isEqualToString:@"navigational"]) {
                if (lua_type(L, -1) == LUA_TBOOLEAN) {
                    value = @((BOOL)(lua_toboolean(L, -1))) ;
                } else {
                    errMsg = @"expected boolean for navigational key" ;
                }
            } else if ([keyName isEqualToString:@"menuForm"]) {
                if (lua_type(L, -1) == LUA_TUSERDATA && luaL_testudata(L, -1, "hs._asm.uitk.menu.item")) {
                    value = [skin toNSObjectAtIndex:-1] ;
                    [skin luaRetain:refTable forNSObject:value] ;
                } else if (lua_type(L, -1) == LUA_TBOOLEAN && !lua_toboolean(L, -1)) {
                    value = @((BOOL)(lua_toboolean(L, -1))) ;
                } else {
                    errMsg = @"expected hs._asm.uitk.menu.item object for menuForm key or false to reset to default" ;
                }
//             } else if ([keyName isEqualToString:@"title"]) {
//                 if (lua_type(L, -1) == LUA_TSTRING) {
//                     value = [skin toNSObjectAtIndex:-1] ;
//                 } else {
//                     errMsg = @"expected a string for title key" ;
//                 }
//             } else if ([keyName isEqualToString:@"element"]) {
//                 NSView *view = (lua_type(L, -1) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:-1] : nil ;
//                 if (view && oneOfOurElementObjects(view)) {
//                     value = view ;
//                     [skin luaRetain:refTable forNSObject:value] ;
//                 } else if (lua_type(L, -1) == LUA_TBOOLEAN && !lua_toboolean(L, -1)) {
//                     value = @((BOOL)(lua_toboolean(L, -1))) ;
//                 } else {
//                     errMsg = @"expected userdata representing a uitk element for element key or false to remove" ;
//                 }
            } else if ([keyName isEqualToString:@"selectable"]) {
                if (lua_type(L, -1) == LUA_TBOOLEAN) {
                    value = @((BOOL)(lua_toboolean(L, -1))) ;
                } else {
                    errMsg = @"expected boolean for selectable key" ;
                }
            } else if ([keyName isEqualToString:@"immovable"]) {
                if (lua_type(L, -1) == LUA_TBOOLEAN) {
                    value = @((BOOL)(lua_toboolean(L, -1))) ;
                } else {
                    errMsg = @"expected boolean for immovable key" ;
                }
            } else if ([keyName isEqualToString:@"callback"]) {
                BOOL isFunction = (lua_type(L, -1) == LUA_TFUNCTION) ;
                if (!isFunction && lua_getmetatable(L, -1)) {
                    lua_getfield(L, -1, "__call") ;
                    isFunction = (lua_type(L, -1) != LUA_TNIL) ;
                    lua_pop(L, 2) ;
                }
                if (isFunction) {
                    lua_pushvalue(L, -1) ;
                    int callbackRef = [skin luaRef:refTable] ;
                    value = [NSNumber numberWithInt:callbackRef] ;
                } else if (lua_type(L, -1) == LUA_TBOOLEAN && !lua_toboolean(L, -1)) {
                    value = @((BOOL)(lua_toboolean(L, -1))) ;
                } else {
                    errMsg = @"expected function for callback key or false to remove" ;
                }

// Don't think these will be useful
//             } else if ([keyName isEqualToString:@"autoValidates"]) {  // not sure how useful yet
//             } else if ([keyName isEqualToString:@"possibleLabels"]) { // not sure how useful yet
//             } else if ([keyName isEqualToString:@"minSize"]) {        // deprecated
//             } else if ([keyName isEqualToString:@"maxSize"]) {        // deprecated
// NSToolbarItemGroup
            } else if ([keyName isEqualToString:@"groupMembers"]) {
                BOOL good = lua_type(L, -1) == LUA_TTABLE ;
                if (good) {
                    NSArray *members = [skin toNSObjectAtIndex:-1] ;
                    if (good) good = [members isKindOfClass:[NSArray class]] ;
                    if (good) {
                        NSDictionary *itemDefinitions = self.itemDefinitions ;

                        for (NSString *item in members) {
                            if (![item isKindOfClass:[NSString class]]) {
                                good = NO ;
                                break ;
                            }
                            NSDictionary *subitemDefinition = itemDefinitions[item] ;
                            if (subitemDefinition) {
                                NSString *subitemType = subitemDefinition[@"type"] ;
                                if (subitemType && [subitemType isEqualToString:@"group"]) {
                                    good = NO ;
                                    errMsg = @"groupMembers cannot include another group item" ;
                                    break ;
                                }
                            }
                        }
                    }
                    if (good) value = members ;
                }

                if (!good && !errMsg) errMsg = @"expected a table of string identifiers for groupMembers key" ;
            } else if ([keyName isEqualToString:@"groupRepresentation"]) {
                if (lua_type(L, -1) == LUA_TSTRING) {
                    NSString *type   = [skin toNSObjectAtIndex:-1] ;
                    NSNumber *actual = GROUP_REPRESENTATION[type] ;
                    if (actual) {
                        value = actual ;
                    } else {
                        errMsg = [NSString stringWithFormat:@"groupRepresentation must be one of %@", [GROUP_REPRESENTATION.allKeys componentsJoinedByString:@", "]] ;
                    }
                } else {
                    errMsg = @"expected a string for groupRepresentation key" ;
                }
            } else if ([keyName isEqualToString:@"groupSelectionMode"]) {
                if (lua_type(L, -1) == LUA_TSTRING) {
                    NSString *type = [skin toNSObjectAtIndex:-1] ;
                    NSNumber *actual = GROUP_SELECTION_MODES[type] ;
                    if (actual) {
                        value = actual ;
                    } else {
                        errMsg = [NSString stringWithFormat:@"groupSelectionMode must be one of %@", [GROUP_SELECTION_MODES.allKeys componentsJoinedByString:@", "]] ;
                    }
                } else {
                    errMsg = @"expected a string for groupSelectionMode key" ;
                }
// NSMenuToolbarItem
            } else if ([keyName isEqualToString:@"menu"]) {
                if (lua_type(L, -1) == LUA_TUSERDATA && luaL_testudata(L, -1, "hs._asm.uitk.menu")) {
                    value = [skin toNSObjectAtIndex:-1] ;
                    [skin luaRetain:refTable forNSObject:value] ;
                } else if (lua_type(L, -1) == LUA_TBOOLEAN && !lua_toboolean(L, -1)) {
                    value = @((BOOL)(lua_toboolean(L, -1))) ;
                } else {
                    errMsg = @"expected hs._asm.uitk.menu object for menu key or false to remove" ;
                }
            } else if ([keyName isEqualToString:@"menuIndicator"]) {
                if (lua_type(L, -1) == LUA_TBOOLEAN) {
                    value = @((BOOL)(lua_toboolean(L, -1))) ;
                } else {
                    errMsg = @"expected boolean for menuIndicator key" ;
                }
// NSSearchToolbarItem
//    Need to understand better and see about replicating for pre 11.
//    Use mld hs.webview.toolbar method?
//             } else if ([keyName isEqualToString:@"searchHistory"]) {
//             } else if ([keyName isEqualToString:@"searchHistoryAutosaveName"]) {
//             } else if ([keyName isEqualToString:@"searchHistoryLimit"]) {
//             } else if ([keyName isEqualToString:@"searchPredefinedMenuTitle"]) {
//             } else if ([keyName isEqualToString:@"searchPredefinedSearches"]) {
//             } else if ([keyName isEqualToString:@"searchReleaseFocusOnCallback"]) {
//             } else if ([keyName isEqualToString:@"searchText"]) {
//             } else if ([keyName isEqualToString:@"searchWidth"]) {
// MAYBE: NSSharingServicePickerToolbarItem
//    Need to understand better and see what infrastructure we need to add
//    Looks like hs.sharing isn't enough...
//             } else if ([keyName isEqualToString:@"sharingServiceCallback"]) { // needs more infrastructure first
// MAYBE: NSTrackingSeparatorToolbarItem
//    requires NSSplitView support
//             } else if ([keyName isEqualToString:@"splitViewDividerIndex"]) {
//             } else if ([keyName isEqualToString:@"splitView"]) {
            } else {
                // don't log ID -- we allow it in the table for legacy reasons
                if (![keyName isEqualToString:@"id"]) {
                    [skin logVerbose:[NSString stringWithFormat:@"%s:%@ unrecognized key %@; ignoring",
                        UD_DICT_TAG, NSStringFromSelector(_cmd), keyName]] ;
                }
            }
        } else {
            errMsg = [NSString stringWithFormat:@"expected string key; found %s", luaL_typename(L, -2)] ;
        }

        if (errMsg) {
            lua_pop(L, 2) ; // remove both key and value and break
            break ;
        } else {
            if (value) details[keyName] = value ; // else assume taken care of above
            lua_pop(L, 1); // removes 'value'; keeps 'key' for next iteration
        }
    }

    NSString *type = (NSString *)details[@"type"] ;
    if (!errMsg && type && [type isEqualToString:@"group"]) {
        NSDictionary *itemDefinitions = self.itemDefinitions ;

        for (NSString *item in itemDefinitions.allKeys) {
            NSDictionary *definition = itemDefinitions[item] ;
            NSArray      *members    = definition[@"groupMembers"] ;
            if (members && [members containsObject:identifier]) {
                errMsg = [NSString stringWithFormat:@"%@ cannot be a group because it is already a member of %@", identifier, item] ;
                break ;
            }
        }
    }

    if (errMsg) {
        [self releaseLuaObjectsFromDefinition:details withState:L] ;
        if (error != NULL) {
            NSString *errDomain = [[NSBundle mainBundle] bundleIdentifier] ;
            if (!errDomain) errDomain = @"<no-bundle-identifier>" ;
            *error = [NSError errorWithDomain:errDomain code:NSKeyValueValidationError
                                                    userInfo:@{ NSLocalizedDescriptionKey : errMsg }] ;
        }

        return nil ;
    } else {
        return details.copy ;
    }
}

- (void)releaseLuaObjectsFromDefinition:(NSDictionary *)details withState:(lua_State *)L {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    for (NSString *key in details.allKeys) {
        if ([key isEqualToString:@"callback"]) {
            NSNumber *callback = details[key] ;
            if (!isNSNumberActuallyABoolean(callback)) [skin luaUnref:refTable ref:callback.intValue] ;
        } else if ( [key isEqualToString:@"menuForm"] ||
//                     [key isEqualToString:@"element"] ||
                    [key isEqualToString:@"menu"] )
        {
            [skin luaRelease:refTable forNSObject:details[key]] ;
        }
    }
}

- (BOOL)addItem:(NSString *)identifier propertiesAtIndex:(int)idx
                                               withState:(lua_State *)L
                                                   error:(NSError * __autoreleasing *)error {

    NSDictionary *itemDefinition = nil ;
    BOOL         result          = NO ;
    NSString     *errMsg         = nil ;

    NSDictionary *properties = [self validatePropertiesAtIndex:idx forIdentifier:identifier withState:L error:error] ;
    if (properties) {
        @synchronized (self) {
            itemDefinition = _itemDefinitions[identifier] ;
            if (!itemDefinition) {
                _itemDefinitions[identifier] = properties ;
                result = YES ;
            } else {
                errMsg = [NSString stringWithFormat:@"item with identifier %@ already defined", identifier] ;
            }
        }

        if (!result) [self releaseLuaObjectsFromDefinition:properties withState:L] ;
    } // else error already set in validatePropertiesAtIndex:forIdentifier:withState:error:

    if (result) {
        HSUITKToolbar *sample = _toolbars.anyObject ; // what happens to one toolbar, happens to all
        if (sample) {
            NSArray   *itemIdentifiers = [sample.items valueForKey:@"itemIdentifier"] ;
            NSInteger atIdx            = (NSInteger)[itemIdentifiers indexOfObject:identifier] ;
            if (atIdx != NSNotFound) {
                // item placeholder being shown
                [sample removeItemAtIndex:atIdx] ;
                [self purgeFalsePlaceholdersInDefinitionFor:identifier] ;
                [sample insertItemWithItemIdentifier:identifier atIndex:atIdx] ;
            }
        }
    }

    if (errMsg && error != NULL) {
        NSString *errDomain = [[NSBundle mainBundle] bundleIdentifier] ;
        if (!errDomain) errDomain = @"<no-bundle-identifier>" ;
        *error = [NSError errorWithDomain:errDomain code:NSKeyValueValidationError
                                                userInfo:@{ NSLocalizedDescriptionKey : errMsg }] ;
    }

    return result ;
}

- (BOOL)modifyItem:(NSString *)identifier andReplace:(BOOL)replace
                                   propertiesAtIndex:(int)idx
                                           withState:(lua_State *)L
                                               error:(NSError * __autoreleasing *)error {
    NSDictionary *itemDefinition = nil ;
    BOOL         result          = NO ;
    NSString     *errMsg         = nil ;

    NSDictionary *properties = [self validatePropertiesAtIndex:idx forIdentifier:identifier withState:L error:error] ;

    if (properties) {
        @synchronized (self) {
            itemDefinition = _itemDefinitions[identifier] ;
            if (itemDefinition) {
                if (replace) {
                    _itemDefinitions[identifier] = properties ;
                    [self releaseLuaObjectsFromDefinition:itemDefinition withState:L] ;
                } else {
                    if (properties[@"type"] == nil) {
                        LuaSkin             *skin           = [LuaSkin sharedWithState:L] ;
                        NSMutableDictionary *itemProperties = itemDefinition.mutableCopy ;

                        for (NSString *key in properties.allKeys) {
                            NSObject *value    = properties[key] ;
                            NSObject *oldValue = itemDefinition[key] ;

                            // new value retained in validatePropertiesAtIndex:, but old one needs to be released
                            if (oldValue) {
                                if ([key isEqualToString:@"callback"]) {
                                    NSNumber *callback = (NSNumber *)oldValue ;
                                    [skin luaUnref:refTable ref:callback.intValue] ;
                                } else if ( [key isEqualToString:@"menuForm"] ||
//                                             [key isEqualToString:@"element"] ||
                                            [key isEqualToString:@"menu"] )
                                {
                                    [skin luaRelease:refTable forNSObject:oldValue] ;
                                }
                            }
                            if ([key isEqualToString:@"callback"] && isNSNumberActuallyABoolean((NSNumber *)value)) {
                                itemProperties[key] = nil ;
                            } else {
                                itemProperties[key] = value ;
                            }
                        }
                        _itemDefinitions[identifier] = itemProperties.copy ;
                        result = YES ;
                    } else {
                        errMsg = @"can't change type of item unless replacing it" ;
                    }
                }
            } else {
                errMsg = [NSString stringWithFormat:@"item with identifier %@ undefined", identifier] ;
            }
        }
    } // else error already set in validatePropertiesAtIndex:forIdentifier:withState:error:

    if (result) {
        if (replace) {
            HSUITKToolbar *toolbar = _toolbars.anyObject ; // what happens to one toolbar, happens to all
            if (toolbar) {
                NSArray   *itemIdentifiers = [toolbar.items valueForKey:@"itemIdentifier"] ;
                NSInteger atIdx            = (NSInteger)[itemIdentifiers indexOfObject:identifier] ;
                if (atIdx != NSNotFound) {
                    [toolbar removeItemAtIndex:atIdx] ;
                    [self purgeFalsePlaceholdersInDefinitionFor:identifier] ;
                    [toolbar insertItemWithItemIdentifier:identifier atIndex:atIdx] ;
                }
            }
        } else {
            NSArray *toolbars = _toolbars.allObjects ;
            if (toolbars.count > 0) {
                HSUITKToolbar *sample          = toolbars.firstObject ;
                NSArray       *itemIdentifiers = [sample.items valueForKey:@"itemIdentifier"] ;
                NSUInteger atIdx               = [itemIdentifiers indexOfObject:identifier] ;
                if (atIdx != NSNotFound) {
                    for (HSUITKToolbar *toolbar in toolbars) {
                        NSToolbarItem *item = toolbar.items[atIdx] ;
                        [self applyDefinition:properties withToolbar:toolbar
                                                              toItem:item
                                                           withState:L] ;
                    }
                }
            }
            [self purgeFalsePlaceholdersInDefinitionFor:identifier] ;
        }
    }

    if (errMsg && error != NULL) {
        if (properties) [self releaseLuaObjectsFromDefinition:properties withState:L] ;

        NSString *errDomain = [[NSBundle mainBundle] bundleIdentifier] ;
        if (!errDomain) errDomain = @"<no-bundle-identifier>" ;
        *error = [NSError errorWithDomain:errDomain code:NSKeyValueValidationError
                                                userInfo:@{ NSLocalizedDescriptionKey : errMsg }] ;
    }

    return result ;
}

- (BOOL)deleteItem:(NSString *)identifier withState:(lua_State *)L
                                              error:(NSError * __autoreleasing *)error {
    NSDictionary *itemDefinition = nil ;
    BOOL         result          = NO ;
    NSString     *errMsg         = nil ;

    @synchronized (self) {
        itemDefinition = _itemDefinitions[identifier] ;
        if (itemDefinition) {
            _itemDefinitions[identifier] = nil ;
            result = YES ;
        } else {
            errMsg = [NSString stringWithFormat:@"item with identifier %@ undefined", identifier] ;
        }
    }

    if (itemDefinition) [self releaseLuaObjectsFromDefinition:itemDefinition withState:L] ;

    if (result) {
        HSUITKToolbar *sample = _toolbars.anyObject ; // what happens to one toolbar, happens to all
        if (sample) {
            NSArray   *itemIdentifiers = [sample.items valueForKey:@"itemIdentifier"] ;
            NSInteger atIdx            = (NSInteger)[itemIdentifiers indexOfObject:identifier] ;
            if (atIdx != NSNotFound) [sample removeItemAtIndex:atIdx] ;
        }
    }

    if (errMsg && error != NULL) {
        NSString *errDomain = [[NSBundle mainBundle] bundleIdentifier] ;
        if (!errDomain) errDomain = @"<no-bundle-identifier>" ;
        *error = [NSError errorWithDomain:errDomain code:NSKeyValueValidationError
                                                userInfo:@{ NSLocalizedDescriptionKey : errMsg }] ;
    }

    return result ;
}

- (void)purgeFalsePlaceholdersInDefinitionFor:(NSString *)identifier {
    @synchronized (self) {
        NSMutableDictionary *itemDefinition = _itemDefinitions[identifier] ;
        if (itemDefinition) {
            NSNumber *temp = itemDefinition[@"menuForm"] ;
            if ([temp isKindOfClass:[NSNumber class]] && !temp.boolValue) itemDefinition[@"menuForm"] = nil ;
//             temp = itemDefinition[@"element"] ;
//             if ([temp isKindOfClass:[NSNumber class]] && !temp.boolValue) itemDefinition[@"element"]  = nil ;
            temp = itemDefinition[@"menu"] ;
            if ([temp isKindOfClass:[NSNumber class]] && !temp.boolValue) itemDefinition[@"menu"]     = nil ;

            _itemDefinitions[identifier] = itemDefinition ;
        }
    }
}

- (void)applyDefinition:(NSDictionary *)itemDefinition withToolbar:(HSUITKToolbar *)toolbar
                                                           toItem:(NSToolbarItem *)toolbarItem
                                                        withState:(lua_State *)L {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    HSUITKToolbarItem *asItem = (HSUITKToolbarItem *)toolbarItem ;

    NSString   *label            = itemDefinition[@"label"] ;
    NSString   *paletteLabel     = itemDefinition[@"paletteLabel"] ;
    NSString   *tooltip          = itemDefinition[@"tooltip"] ;
    NSImage    *image            = itemDefinition[@"image"] ;
    NSNumber   *priority         = itemDefinition[@"priority"] ;
    NSNumber   *tag              = itemDefinition[@"tag"] ;
    NSNumber   *enabled          = itemDefinition[@"enabled"] ;
    NSNumber   *bordered         = itemDefinition[@"bordered"] ;
    NSNumber   *navigational     = itemDefinition[@"navigational"] ;
    NSMenuItem *menuForm         = itemDefinition[@"menuForm"] ;
//     NSString   *title            = itemDefinition[@"title"] ;
//     NSView     *element          = itemDefinition[@"element"] ;

    if (label) {
        asItem.label = label ;
    }
    if (paletteLabel) {
        asItem.paletteLabel = paletteLabel ;
    }
    if (tooltip) {
        if ([tooltip isKindOfClass:[NSString class]]) {
            asItem.toolTip = tooltip ;
        } else {
            asItem.toolTip = nil ;
        }
    }
    if (image) {
        if (asItem.image) {
            asItem.image = nil ;
        }
        if ([image isKindOfClass:[NSImage class]]) {
            asItem.image = image ;
        } // else it's false and we've already removed it
    }
    if (priority) {
        asItem.visibilityPriority = priority.longLongValue ;
    }
    if (tag) {
        asItem.tag = tag.longLongValue ;
    }
    if (enabled) {
        asItem.enabled = enabled.boolValue ;
        asItem.enableOverrideDictionary = NO ;
    }
    if (bordered) {
        asItem.bordered = bordered.boolValue ;
    }
    if (@available(macOS 11.0, *)) {
        if (navigational) {
            asItem.navigational = navigational.boolValue ;
        }
    }
    if (menuForm) {
        NSMenuItem *oldValue = asItem.menuFormRepresentation ;
        if (oldValue && ![oldValue isEqualTo:asItem.initialMenuFormRepresentation]) {
            [skin luaRelease:refTable forNSObject:oldValue] ;
            asItem.menuFormRepresentation    = asItem.initialMenuFormRepresentation ;
            asItem.ourMenuFormRepresentation = nil ;
        }
        if ([menuForm isKindOfClass:[NSMenuItem class]]) {
            NSMenuItem *newValue = [menuForm copyWithState:L] ;
            [skin luaRetain:refTable forNSObject:newValue] ;
            asItem.menuFormRepresentation    = newValue ;
            asItem.ourMenuFormRepresentation = newValue ; // see notes in HSUITKToolbarItem dealloc
        } // else it's false and we've already removed it
    }
//     if (element) {
//         NSView *oldValue = asItem.view ;
//         if (oldValue) {
//             [skin luaRelease:refTable forNSObject:oldValue] ;
//             asItem.view = nil ;
//         }
//         if ([element isKindOfClass:[NSView class]]) {
// // ??? I suspect we're going to need to add copyWithState: to all of the possibilities for this as well...
//             [skin luaRetain:refTable forNSObject:element] ;
//             asItem.view = element ;
//         } // else it's false and we've already removed it
//     }
//     if (title) {
//         asItem.title = title ;
//     }

    if ([toolbarItem isKindOfClass:[NSToolbarItemGroup class]]) {
        HSUITKToolbarItemGroup *asGroupItem = (HSUITKToolbarItemGroup *)toolbarItem ;

        NSArray  *groupMembers        = itemDefinition[@"groupMembers"] ;
        NSNumber *groupRepresentation = itemDefinition[@"groupRepresentation"] ;
        NSNumber *groupSelectionMode  = itemDefinition[@"groupSelectionMode"] ;

        if (groupMembers) {
            for (NSToolbarItem *item in asGroupItem.subitems) [skin luaRelease:refTable forNSObject:item] ;

            NSDictionary *itemDefinitions = self.itemDefinitions ;

            NSMutableArray *newSubItems = [NSMutableArray arrayWithCapacity:groupMembers.count] ;
            for (NSString *identifier in groupMembers) {
                NSDictionary *subitemDefinition = itemDefinitions[identifier] ;

                if (subitemDefinition) {
                    NSString *type = subitemDefinition[@"type"] ;
                    if (!type) type = @"item" ;
                    if (![ITEM_TYPES containsObject:type]) {
                        [LuaSkin logDebug:@"%s:%@ - unrecognized type %@; treating as item", USERDATA_TAG, NSStringFromSelector(_cmd), type] ;
                        type = @"item" ;
                    }

                    if ([type isEqualToString:@"group"]) {
                            [skin logVerbose:@"%s:%@ - %@ group member %@ cannot be a group item; ignoring", USERDATA_TAG, NSStringFromSelector(_cmd), asGroupItem.itemIdentifier, identifier] ;
                    } else {
                        NSToolbarItem *subitem = [self newEmptyItem:identifier ofType:type] ;
                        if (subitem) {
                            [self applyDefinition:subitemDefinition withToolbar:toolbar toItem:subitem withState:L] ;
                            [skin luaRetain:refTable forNSObject:subitem] ;
                            [newSubItems addObject:subitem] ;
                        } else {
                            [skin logError:@"%s:%@ - failed to create subitem of type %@; skipping", USERDATA_TAG, NSStringFromSelector(_cmd), type] ;
                        }
                    }
                } else {
                    [LuaSkin logVerbose:@"%s:%@ - %@ group member %@ is undefined; ignoring", USERDATA_TAG, NSStringFromSelector(_cmd), asGroupItem.itemIdentifier, identifier] ;
                }
            }
            asGroupItem.subitems = newSubItems.copy ;
        }
        if (groupRepresentation) {
            asGroupItem.controlRepresentation = groupRepresentation.longLongValue ;
        }
        if (groupSelectionMode) {
            asGroupItem.selectionMode = groupSelectionMode.longLongValue ;
        }
    }

    if ([toolbarItem isKindOfClass:[NSMenuToolbarItem class]]) {
        HSUITKMenuToolbarItem *asMenuItem = (HSUITKMenuToolbarItem *)toolbarItem ;

        NSMenu   *menu          = itemDefinition[@"menu"] ;
        NSNumber *menuIndicator = itemDefinition[@"menuIndicator"] ;

        if (menu) {
            NSMenu *oldValue = asMenuItem.menu ;
            if (oldValue && ![oldValue isEqualTo:asMenuItem.initialMenu]) {
                [skin luaRelease:refTable forNSObject:oldValue] ;
                oldValue.assignedTo = nil ;
                asMenuItem.menu = asMenuItem.initialMenu ;
            }
            if ([menu isKindOfClass:[NSMenu class]]) {
                NSMenu *newValue = [menu copyWithState:L] ;
                newValue.assignedTo = (NSResponder *)toolbar ;
                [skin luaRetain:refTable forNSObject:newValue] ;
                asMenuItem.menu = newValue ;
            } // else it's false and we've already removed it
        }
        if (menuIndicator) {
            asMenuItem.showsIndicator = menuIndicator.boolValue ;
        }
    }

// NSSearchToolbarItem
//    Need to understand better and see about replicating for pre 11.
//    Use mld hs.webview.toolbar method?
//         @"searchHistory"
//         @"searchHistoryAutosaveName"
//         @"searchHistoryLimit"
//         @"searchPredefinedMenuTitle"
//         @"searchPredefinedSearches"
//         @"searchReleaseFocusOnCallback"
//         @"searchText"
//         @"searchWidth"
// MAYBE: NSSharingServicePickerToolbarItem
//    Need to understand better and see what infrastructure we need to add
//    Looks like hs.sharing isn't enough...
//         @"sharingServiceCallback" // needs more infrastructure first
// MAYBE: NSTrackingSeparatorToolbarItem
//    requires NSSplitView support
//         @"splitViewDividerIndex"
//         @"splitView"

}

#pragma mark NSToolbar Delegate methods

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    NSDictionary  *itemDefinition = self.itemDefinitions[itemIdentifier] ;
    NSToolbarItem *toolbarItem    = nil ;

//     [LuaSkin logBreadcrumb:@"%s%@ - %@ %@", USERDATA_TAG, NSStringFromSelector(_cmd), itemIdentifier, (flag ? @"YES" : @"NO ")] ;

    if (itemDefinition) {
        NSString *type = itemDefinition[@"type"] ;

        // if type isn't set, assume item
        if (!type) type = @"item" ;

        // treat unrecognized types as regular items, but log it
        if (![ITEM_TYPES containsObject:type]) {
            [LuaSkin logDebug:@"%s:%@ - unrecognized type %@; treating as item", USERDATA_TAG, NSStringFromSelector(_cmd), type] ;
            type = @"item" ;
        }

        toolbarItem = [self newEmptyItem:itemIdentifier ofType:type] ;

        [self applyDefinition:itemDefinition withToolbar:(HSUITKToolbar *)toolbar toItem:toolbarItem
                                                                               withState:NULL] ;
    } else {
        [LuaSkin logDebug:@"%s:%@ - undefined identifier %@; returning placeholder", UD_DICT_TAG, NSStringFromSelector(_cmd), itemIdentifier] ;

        // placeholder so dictionary can push updates if item defined after toolbar attached
        toolbarItem = [[HSUITKToolbarItem alloc] initWithItemIdentifier:itemIdentifier]  ;
    }

    // if this is for the configuration pane, enabled should be YES, even if the definition says it's not ATM
    if (toolbarItem && !flag) {
        toolbarItem.enabled = YES ;
        ((HSUITKToolbarItem *)toolbarItem).enableOverrideDictionary = YES ;
    }
    return toolbarItem ;
}

- (void)toolbarDidRemoveItem:(NSNotification *)notification {
    [LuaSkin logBreadcrumb:@"%s:%@ - %@", UD_DICT_TAG, NSStringFromSelector(_cmd), notification] ;

    NSToolbarItem *item = nil ;
    if (@available(macos 13.0, *)) {
        item = notification.userInfo[NSToolbarItemKey] ;
    } else {
        item = notification.userInfo[@"item"] ;
    }
    HSUITKToolbar *toolbar = (HSUITKToolbar *)item.toolbar ;
    if (toolbar && toolbar.notifyToolbarChanges) [toolbar callbackHamster:@[ toolbar, @"remove", item ]] ;
}

- (void)toolbarWillAddItem:(NSNotification *)notification {
    [LuaSkin logBreadcrumb:@"%s:%@ - %@", UD_DICT_TAG, NSStringFromSelector(_cmd), notification] ;

    NSToolbarItem *item = nil ;
    if (@available(macos 13.0, *)) {
        item = notification.userInfo[NSToolbarItemKey] ;
    } else {
        item = notification.userInfo[@"item"] ;
    }
    HSUITKToolbar *toolbar = (HSUITKToolbar *)item.toolbar ;
    if (toolbar && toolbar.notifyToolbarChanges) [toolbar callbackHamster:@[ toolbar, @"add", item ]] ;
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return self.allowedIdentifiers ;
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return self.defaultIdentifiers ;
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
    return self.selectableIdentifiers ;
}

- (NSSet<NSToolbarItemIdentifier> *)toolbarImmovableItemIdentifiers:(NSToolbar *)toolbar  {
    return self.immovableIdentifiers ;
}

// - (BOOL)toolbar:(NSToolbar *)toolbar itemIdentifier:(NSToolbarItemIdentifier)itemIdentifier canBeInsertedAtIndex:(NSInteger)index;
@end

static BOOL validateToolbarItem(HSUITKToolbarItem *item) {
    BOOL enabled = item.enabled ;
    if (!item.enableOverrideDictionary) {
        NSToolbar *toolbar = item.toolbar ;
        if (toolbar) {
            HSUITKToolbarDictionary *dictionary = toolbar.delegate ;
            if (dictionary) {
                NSDictionary *definition = dictionary.itemDefinitions[item.itemIdentifier] ;
                NSNumber     *enabledNum = definition ? definition[@"enabled"] : nil ;
                if (enabledNum) enabled = enabledNum.boolValue ;
            }
        }
    }
    return enabled ;
}

@implementation HSUITKToolbarItem

- (instancetype)initWithItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier {
    self = [super initWithItemIdentifier:itemIdentifier] ;
    if (self) {
        _selfRefCount                  = 0 ;
        _enableOverrideDictionary      = NO ;
        _ourMenuFormRepresentation     = nil ;
        _initialMenuFormRepresentation = self.menuFormRepresentation ;
    }
    return self ;
}

- (void)dealloc {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    // dealloc crashes if trying to access self.menuFormRepresentation, so we track
    // if we've changed it another way...
    if (_ourMenuFormRepresentation) [skin luaRelease:refTable forNSObject:_ourMenuFormRepresentation] ;
    _ourMenuFormRepresentation = nil ;
}

// the default implementation ignores items with a view set, plus we're putting the enabled onus on the user, so...
- (void)validate {
    self.enabled = validateToolbarItem(self) ;
}

// if toolbar mode set to labels only, argument will be group object, not item object, so we intervene
- (void)toolbarItemCallback:(NSToolbarItem *)toolbarItem {
    NSToolbar *toolbar = self.toolbar ;
    if (toolbar) {
        HSUITKToolbarDictionary *dictionary = toolbar.delegate ;
        if (dictionary) [dictionary toolbarItemCallback:self] ;
    }
}
@end

@implementation HSUITKToolbarItemGroup

- (instancetype)initWithItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier {
    self = [super initWithItemIdentifier:itemIdentifier] ;
    if (self) {
        _selfRefCount                  = 0 ;
        _enableOverrideDictionary      = NO ;
        _ourMenuFormRepresentation     = nil ;
        _initialMenuFormRepresentation = self.menuFormRepresentation ;
    }
    return self ;
}

- (void)dealloc {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    // dealloc crashes if trying to access self.menuFormRepresentation, so we track
    // if we've changed it another way...
    if (_ourMenuFormRepresentation) [skin luaRelease:refTable forNSObject:_ourMenuFormRepresentation] ;
    _ourMenuFormRepresentation = nil ;
    // TODO: see if subitems has the same issue as menuFormRepresentation
    for (NSToolbarItem *item in self.subitems) [skin luaRelease:refTable forNSObject:item] ;
    self.subitems = [NSArray array] ;
}

// the default implementation ignores items with a view set, plus we're putting the enabled onus on the user, so...
- (void)validate {
    self.enabled = validateToolbarItem((HSUITKToolbarItem *)self) ;
}

// if toolbar mode set to labels only, argument will be group object, not item object, so we intervene
- (void)toolbarItemCallback:(NSToolbarItem *)toolbarItem {
    NSToolbar *toolbar = self.toolbar ;
    if (toolbar) {
        HSUITKToolbarDictionary *dictionary = toolbar.delegate ;
        if (dictionary) [dictionary toolbarItemCallback:self] ;
    }
}
@end

@implementation HSUITKMenuToolbarItem

- (instancetype)initWithItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier {
    self = [super initWithItemIdentifier:itemIdentifier] ;
    if (self) {
        _selfRefCount                  = 0 ;
        _enableOverrideDictionary      = NO ;
        _ourMenuFormRepresentation     = nil ;
        _initialMenuFormRepresentation = self.menuFormRepresentation ;
        _initialMenu                   = self.menu ;
    }
    return self ;
}

- (void)dealloc {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
    // dealloc crashes if trying to access self.menuFormRepresentation, so we track
    // if we've changed it another way...
    if (_ourMenuFormRepresentation) [skin luaRelease:refTable forNSObject:_ourMenuFormRepresentation] ;
    _ourMenuFormRepresentation = nil ;
    // TODO: see if menu has the same issue as menuFormRepresentation
    if (![self.menu isEqualTo:_initialMenu]) {
        [skin luaRelease:refTable forNSObject:self.menu] ;
        self.menu = _initialMenu ;
    }

}

// the default implementation ignores items with a view set, plus we're putting the enabled onus on the user, so...
- (void)validate {
    self.enabled = validateToolbarItem((HSUITKToolbarItem *)self) ;
}

// if toolbar mode set to labels only, argument will be group object, not item object, so we intervene
- (void)toolbarItemCallback:(NSToolbarItem *)toolbarItem {
    NSToolbar *toolbar = self.toolbar ;
    if (toolbar) {
        HSUITKToolbarDictionary *dictionary = toolbar.delegate ;
        if (dictionary) [dictionary toolbarItemCallback:self] ;
    }
}
@end

#pragma mark - Module Functions -

/// hs._asm.uitk.toolbar.new(dictionary) -> toolbarObject
/// Constructor
/// Create a new toolbar object to be attached to an hs._asm.uitk.window object.
///
/// Parameters:
///  * `dictionary` - a string specifying the title of a toolbar item dictionary, or an `hs._asm.uitk.toolbar.dictionary` object. If you specify a string and the string does not match an existing toolbar item dictionary, a new dictionary with the specified title will be created for the new toolbar object.
///
/// Returns:
///  * a new toolbarObject
///
/// Notes:
///  * All toolbars created with the same dictionary identifier or dictionaryObject will share the same item definitions and default presentation when the item is first rendered visible in the toolbar.
static int toolbar_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKToolbarDictionary *dictionary = nil ;

    if (lua_type(L, 1) != LUA_TUSERDATA) {
        [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
        NSString *dictionaryName = [skin toNSObjectAtIndex:1] ;
        dictionary = [knownDictionaries objectForKey:dictionaryName] ;
        if (!dictionary) {
            dictionary = [[HSUITKToolbarDictionary alloc] initWithIdentifier:dictionaryName] ;
            if (dictionary) [knownDictionaries setObject:dictionary forKey:dictionaryName] ;
        }
    } else {
        [skin checkArgs:LS_TUSERDATA, UD_DICT_TAG, LS_TBREAK] ;
        dictionary = [skin toNSObjectAtIndex:1] ;
    }

    if (!dictionary) {
        return luaL_argerror(L, 1, "unable to find or create a dictionary with that identifier") ;
    }

    HSUITKToolbar *toolbar = [[HSUITKToolbar alloc] initWithDictionary:dictionary withState:L] ;
    if (toolbar) {
        [dictionary addToolbar:toolbar] ;
        [skin pushNSObject:toolbar] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

/// hs._asm.uitk.toolbar.dictionary(title) -> itemDictionaryObject
/// Constructor
/// Creates a new toolbar item dictionary with the specified title.
///
/// Parameters:
///  * `title` - a string specifying the title of the new toolbar item dictionary
///
/// Returns:
///  * a new itemDictionaryObject or an error if the title is already in use by another itemDictionaryObject.
///
/// Notes:
///  * this function is provided for code clarity, but is not required -- specifying a string title to [hs._asm.uitk.toolbar.new](#new) will create a new item dictionary with the specified name if one does not already exist. You can then get the itemDictionaryObject to add toolbar item definitions with [hs._asm.uitk.toolbar:dictionary](#dictionary).
static int toolbar_dictionary(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    NSString *dictionaryName = [skin toNSObjectAtIndex:1] ;
    if ([knownDictionaries objectForKey:dictionaryName]) {
    [skin logInfo:@"%@, %d", [knownDictionaries objectForKey:dictionaryName], ((HSUITKToolbarDictionary *)[knownDictionaries objectForKey:dictionaryName]).selfRefCount] ;
        return luaL_argerror(L, 1, "dictionary with that identifier already exists") ;
    }

    HSUITKToolbarDictionary *dictionary = [[HSUITKToolbarDictionary alloc] initWithIdentifier:dictionaryName] ;
    if (dictionary) {
        [knownDictionaries setObject:dictionary forKey:dictionaryName] ;
        [skin pushNSObject:dictionary] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

/// hs._asm.uitk.toolbar:configuration([config]) -> toolbarObject | table
/// Method
/// Get or set the toolbar visual configuration as specified by user changes to the toolbar.
///
/// Parameters:
///  * `config` - an optional table specifying the visual details for the toolbar.
///
/// Returns:
///  * if an argument is provided, returns the toolbarObject; otherwise returns the current value
///
/// Notes:
///  * The table returned will contain key-value entries specifying changes the user has made to the visual aspects of the toolbar (e.g. toolbar size, item order, etc.) if these are allowed (see [hs._asm.uitk.toolbar:canCustomize](#canCustomize). This table is what is automatically saved by the macOS if [hs._asm.uitk.toolbar:autosaves](#autosaves) is set to true.
///  * You can get and then set this if you choose to store the configuration in a different manner, say if you wish to include additional state information for use when recreating the menu after a restart. Unrecognized keys will be ignored by the macOS, so you do not need to sanitize the table before supplying it as an argument.
///
///  * to ensure that the changes are applied correctly, you should set this property before the toolbar is actually attached to a window; otherwise the specific changes may not be reflected and could be overwritten if the user makes additional changes.
static int toolbar_configurationDictionary(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:toolbar.configurationDictionary] ;
    } else {
        NSDictionary *configDict = [skin toNSObjectAtIndex:2] ;

        // Make sure the table is key-value pairs
        BOOL listIsGood = [configDict isKindOfClass:[NSDictionary class]] ;
        // Make sure all of the keys are strings
        if (listIsGood) {
            for (NSString *key in configDict.allKeys) {
                if (![key isKindOfClass:[NSString class]]) {
                    listIsGood = NO ;
                    break ;
                }
            }
        }
        if (!listIsGood) {
            return luaL_argerror(L, 2, "expected table of key-value pairs with string keys") ;
        }

        // beyond that, we don't know what keys or values are valid, so cross fingers
        // -- we know unrecognized keys are ignored per documentation
        [toolbar setConfigurationFromDictionary:configDict] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.toolbar:isCustomizing() -> boolean
/// Method
/// Returns a boolean indicating whether the user is currently customizing the toolbar or not.
///
/// Parameters:
///  * None
///
/// Returns:
///  * true if the user customization panel is open; otherwise false
static int toolbar_customizationPaletteIsRunning(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    lua_pushboolean(L, toolbar.customizationPaletteIsRunning) ;
    return 1 ;
}

/// hs._asm.uitk.toolbar:identifier() -> string
/// Method
/// The identifier for the toolbar
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string specifying the identifier for the toolbar. This is the same identifier for the itemDictionaryObject from which the toolbar gets its item definitions when requesting a toolbar item to display it
static int toolbar_identifier(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:toolbar.identifier] ;
    return 1 ;
}

/// hs._asm.uitk.toolbar:customizePanel() -> toolbarObject
/// Method
/// Opens the toolbar customization panel so the user can add or remove toolbar items.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the toolbarObject
static int toolbar_runCustomizationPalette(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    [toolbar runCustomizationPalette:toolbar] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.toolbar:callback([fn | nil]) -> toolbarObject | fn | nil
/// Method
/// Get or set the toolbar callback function
///
/// Parameters:
///  * `fn` - a function, or explicit nil to remove, that will be called whenever an item is added or removed from the toolbar. It also acts as the fallback function to call when an item does not have one explicitly defined.
///
/// Returns:
///  * if an argument is provided, returns the toolbarObject; otherwise returns the current value
///
/// Notes:
///  * The callback should expect three arguments and return none. The first argument will be the toolbarObject, and the third argument will be the item object which the callback is about. The second argument will be a string specifying what the callback is for:
///    * "add"    - the item is being added to the items currently present in the toolbar
///    * "remove" - the item is being removed from the items currently presented in the toolbar
///    * "action" - the item has been clicked by the user, or otherwise activated, and does not have an item callback function assigned.
///
///  * The callback for "add" and "remove" will only be invoked if [hs._asm.uitk.toolbar:notifyOnChange](#notifyOnChange) is true.
///  * The callback for "action" will only be invoked for items which do not have an item callback function assigned. See `hs._asm.uitk.toolbar.item:callback`.
static int toolbar_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        toolbar.callbackRef = [skin luaUnref:refTable ref:toolbar.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            toolbar.callbackRef = [skin luaRef:refTable] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        if (toolbar.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:toolbar.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.toolbar:notifyOnChange([state) -> toolbarObject | boolean
/// Method
/// Get or set whether the toolbar will invoke the callback function when an item is added or removed from the toolbar.
///
/// Parameters:
///  * `state` - a boolean, default false, specifying whether or not a callback will be invoked when an item is added to or removed from the toolbar.
///
/// Returns:
///  * if an argument is provided, returns the toolbarObject; otherwise returns the current value
///
/// Notes:
///  * see also [hs._asm.uitk.toolbar:callback](#callback)
static int toolbar_notifyWhenToolbarChanges(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, toolbar.notifyToolbarChanges) ;
    } else {
        toolbar.notifyToolbarChanges = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.toolbar:canCustomize([state) -> toolbarObject | boolean
/// Method
/// Get or set whether the user is allowed to customize the toolbar by right clicking on it
///
/// Parameters:
///  * `state` - a boolean, default false, specifying whether or not the user can customize the toolbar by right clicking on it.
///
/// Returns:
///  * if an argument is provided, returns the toolbarObject; otherwise returns the current value
static int toolbar_allowsUserCustomization(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, toolbar.allowsUserCustomization) ;
    } else {
        toolbar.allowsUserCustomization = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.toolbar:autosaves([state) -> toolbarObject | boolean
/// Method
/// Get or set whether the toolbar autosaves user customization information about the toolbar.
///
/// Parameters:
///  * `state` - a boolean, default false, specifying whether or not user customizations to the toolbar are automatically saved.
///
/// Returns:
///  * if an argument is provided, returns the toolbarObject; otherwise returns the current value
///
/// Notes:
///  * see also [hs._asm.uitk.toolbar:configuration](#configuration)
///
///  * if you are going to allow the saving of user customizations to the toolbar, you should ensure that all of the toolbar items have been defined in the relevant `hs._asm.uitk.toolbar.dictionary` before the toolbar is actually attached to a window; otherwise the toolbar may not display items which have not yet been defined properly or even at all.
static int toolbar_autosavesConfiguration(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, toolbar.autosavesConfiguration) ;
    } else {
        toolbar.autosavesConfiguration = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.toolbar:visible([state) -> toolbarObject | boolean
/// Method
/// Get or set whether the toolbar is currently visible in the window it is attached to.
///
/// Parameters:
///  * `state` - a boolean specifying whether or not toolbar should be visible in the window it is attached to.
///
/// Returns:
///  * if an argument is provided, returns the toolbarObject; otherwise returns the current value
///
/// Notes:
///  * if the toolbar is not currently attached to a window, this method will return `false` and setting a value has no effect.
static int toolbar_visible(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, toolbar.visible) ;
    } else {
        toolbar.visible = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.toolbar:separator([state]) -> toolbarObject | boolean
/// Method
/// Get or set whether or not the toolbar shows a separator between the toolbar and the main window contents.
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether or not a separator is present between the toolbar and the main window contents.
///
/// Returns:
///  * if an argument is provided, returns the toolbarObject; otherwise returns the current value
///
/// Notes:
///  * this method may have little or no visible effect with newer version of the macOS, but it has not been formally deprecated yet.
static int toolbar_showsBaselineSeparator(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, toolbar.showsBaselineSeparator) ;
    } else {
        toolbar.showsBaselineSeparator = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.toolbar:items() -> table
/// Method
/// Returns an array of the toolbar items currently assigned to the toolbar.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing toolbarItem objects for the toolbar items currently being presented in the toolbar.
///
/// Notes:
///  * the order of the items in the table matches the current display order of the items.
///  * see also [hs._asm.uitk.toolbar:visibleItems](#visibleItems)
static int toolbar_items(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:toolbar.items] ;
    return 1 ;
}

/// hs._asm.uitk.toolbar:visibleItems() -> table
/// Method
/// Returns an array of the toolbar items currently visible in the toolbar.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing toolbarItem objects for the toolbar items currently visible in the toolbar.
///
/// Notes:
///  * the order of the items in the table matches the current display order of the items.
///  * this method does not include items which are in the toolbar's overflow menu.
///  * see also [hs._asm.uitk.toolbar:items](#items)
static int toolbar_visibleItems(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:toolbar.visibleItems] ;
    return 1 ;
}

/// hs._asm.uitk.toolbar:selectedItem([id]) -> toolbarObject | string | nil
/// Method
/// Get or set the currently selected toolbar item.
///
/// Parameters:
///  * `id` - an optional string, or explicit nil to clear, the currently selected toolbar item. If the string does not match a visible item's identifier, then no toolbar item is selected.
///
/// Returns:
///  * if an argument is provided, returns the toolbarObject; otherwise returns the current value
///
/// Notes:
///  * only items with the "selectable" attribute in their definition set to true can be selected; attempting to select an item that does not have this attribute set will have no effect.
static int toolbar_selectedItemIdentifier(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:toolbar.selectedItemIdentifier] ;
    } else {
        NSString *identifier = (lua_type(L, 2) == LUA_TSTRING) ? [skin toNSObjectAtIndex:2] : nil ;
        if (identifier) {
            NSArray *itemIdentifiers = [toolbar.items valueForKey:@"itemIdentifier"] ;
            if (![itemIdentifiers containsObject:identifier]) {
                identifier = nil ;
            }
        }
        toolbar.selectedItemIdentifier = identifier ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.toolbar:sizeMode([mode]) -> toolbarObject | string
/// Method
/// Get or set the size mode for the toolbar.
///
/// Parameters:
///  * `mode` - an optional string specifying the size of the toolbar items within the toolbar. The string must be one of "default", "regular", or "small".
///
/// Returns:
///  * if an argument is provided, returns the toolbarObject; otherwise returns the current value
///
/// Notes:
///  * This method was deprecated in macOS 11.0 and has no effect on the toolbar in more recent macOS versions. You can achieve a similar effect with the "unified" and "unifiedCompact" modes for `hs._asm.uitk.window:toolbarStyle` as of macOS 11.0.
static int toolbar_sizeMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [SIZE_MODES allKeysForObject:@(toolbar.sizeMode)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", toolbar.sizeMode] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = SIZE_MODES[key] ;
        if (value) {
            toolbar.sizeMode = value.unsignedLongLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [SIZE_MODES.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.toolbar:displaytMode([mode]) -> toolbarObject | string
/// Method
/// Get or set the display mode for the toolbar.
///
/// Parameters:
///  * `mode` - an optional string specifying the display mode for the toolbar.
///
/// Returns:
///  * if an argument is provided, returns the toolbarObject; otherwise returns the current value
///
/// Notes:
///  * Currently recognizes the following modes:
///     * "default" - choose the default display mode based on the current setting of `hs._asm.uitk.window:toolbarStyle`
///     * "both"    - display both the label and the icon for the toolbar items
///     * "icon"    - display only the icon for the toolbar items
///     * "label"   - display only the label for the toolbar items
static int toolbar_displayMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSArray  *keys   = [DISPLAY_MODES allKeysForObject:@(toolbar.displayMode)] ;
        NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", toolbar.displayMode] ;
        [skin pushNSObject:answer] ;
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = DISPLAY_MODES[key] ;
        if (value) {
            toolbar.displayMode = value.unsignedLongLongValue ;
        } else {
            NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [DISPLAY_MODES.allKeys componentsJoinedByString:@", "]] ;
            return luaL_argerror(L, 2, errMsg.UTF8String) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.toolbar:insertItem(id, [idx]) -> toolbarObject
/// Method
/// Insert the specified toolbar item into the toolbar at the specified index.
///
/// Parameters:
///  * `id`  - a string specifying the item identifier for the toolbar item to insert
///  * `idx` - an optional integer, default the current number of visible toolbar items + 1 (i.e. at the rightmost end), specifying the index position where the toolbar item should be inserted.
///
/// Returns:
///  * the toolbarObject
///
/// Notes:
///  * if the specified index is < 1, it will be treated as 1 (the first item in the toolbar)
///  * if the specified index is > the current number of assigned toolbar items, it will be treated as specifying the index after the current last item of toolbar.
static int toolbar_insertItemAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbar *toolbar    = [skin toNSObjectAtIndex:1] ;
    NSString      *identifier = [skin toNSObjectAtIndex:2] ;
    NSInteger     idx         = (lua_gettop(L) > 2) ? lua_tointeger(L, 3) : (NSInteger)(toolbar.items.count + 1) ;

    idx-- ;
    if (idx < 0) idx = 0 ;
    if (idx > (NSInteger)toolbar.items.count) idx = (NSInteger)toolbar.items.count ;

// ??? I want to see what happens without the sanity checks
//     if (!toolbar.itemDefDictionary[identifier]) {
//         return luaL_error(L, "toolbar item %s does not exist", [identifier UTF8String]) ;
//     }
//     if (![toolbar.allowedIdentifiers containsObject:identifier]) {
//         return luaL_error(L, "%s is not allowed outside of its group", [identifier UTF8String]) ;
//     }
//
//     NSUInteger itemIndex = [[toolbar.items valueForKey:@"itemIdentifier"] indexOfObject:identifier] ;
//     if (itemIndex != NSNotFound) {
//         [toolbar removeItemAtIndex:(NSInteger)itemIndex] ;
//         // if we're moving it to the end, but already at the end, well, we just changed the index bounds...
//         if (idx > (NSInteger)toolbar.items.count) idx-- ;
//     }

    [toolbar insertItemWithItemIdentifier:identifier atIndex:idx] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.toolbar:removeItem([id | idx]) -> toolbarObject
/// Method
/// Remove the specified toolbar item from the toolbar.
///
/// Parameters:
///  * `id`  - a string specifying the item identifier for the toolbar item to remove; if you specify this parameter, you cannot also specify `idx`.
///  * `idx` - an integer specifying the index position of the toolbar item to remove; if you specify this parameter, you cannot also specify `id`.
///
/// Returns:
///  * the toolbarObject
///
/// Notes:
///  * if the specified id is not found, or if the index is outside of the range of assigned items, this method will be silently ignored.
static int toolbar_removeItemAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKToolbar *toolbar    = [skin toNSObjectAtIndex:1] ;
    NSInteger     idx         = (lua_type(L, 2) == LUA_TNUMBER) ? lua_tointeger(L, 2) : NSNotFound ;

    if (idx == NSNotFound) {
        NSString *identifier     = [skin toNSObjectAtIndex:2] ;
        NSArray *itemIdentifiers = [toolbar.items valueForKey:@"itemIdentifier"] ;

        // NSNotFound is defined as NSIntegerMax; it will be greater than count so we don't need to check
        idx = (NSInteger)[itemIdentifiers indexOfObject:identifier] ;
    } else {
        idx-- ;
    }

    if (!(idx < 0 || idx >= (NSInteger)toolbar.items.count)) [toolbar removeItemAtIndex:idx] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.toolbar:dictionary() -> itemDictionaryObject
/// Method
/// Get the item dictionary for the toolbar.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the itemDictionaryObject that maintains the definitions for the items of the toolbar.
static int toolbar_delegate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:toolbar.delegate] ;
    return 1 ;
}

/// hs._asm.uitk.toolbar:window() -> windowObject | nil
/// Method
/// Get the window object that the toolbar is currently assigned to.
///
/// Parameters:
///  * None
///
/// Returns:
///  * if the toolbar is currently assigned to a window, returns the `hs._asm.uitk.window` object fot that window; otherwise returns nil.
static int toolbar_window(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKToolbar *toolbar = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:toolbar.window withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

//     @property(copy) NSSet<NSToolbarItemIdentifier> *centeredItemIdentifiers;  macOS 13.0+
//     @property(copy) NSToolbarItemIdentifier centeredItemIdentifier;           macOS 10.14-13.0

#pragma mark - Dictionary Methods -

/// hs._asm.uitk.toolbar.dictionary:identifier() -> string
/// Method
/// Get the identifier for the dictionary.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the identifier for the dictionary.
///
/// Notes:
///  * This identifier can be used when creating a new toolbar with `hs._asm.uitk.toolbar.new`. All toolbars created with the same dictionary identifier will share the same item definitions and default presentation when the item is first rendered visible in the toolbar.
static int dictionary_identifier(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DICT_TAG, LS_TBREAK] ;
    HSUITKToolbarDictionary *dictionary = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:dictionary.identifier] ;
    return 1 ;
}

/// hs._asm.uitk.toolbar.dictionary:allowedItems([items]) -> itemDictionaryObject | table
/// Method
/// Get or set the allowed items for toolbars using this dictionary. Allowed items are those items that can be assigned and made visible in the toolbars.
///
/// Parameters:
///  * `items` - an optional table of string identifiers specifying the items that are allowed to be assigned and made visible in the toolbars.
///
/// Returns:
///  * if an argument is provided, returns the itemDictionaryObject; otherwise returns the current value
///
/// Notes:
///  * the order of the item identifiers in the assigned table determines the order in which items will appear in the customization palette for toolbars using this dictionary, if the toolbar allows user modifications (see `hs._asm.uitk.toolbar:canCustomize`).
static int dictionary_allowedItems(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DICT_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbarDictionary *dictionary = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:dictionary.allowedIdentifiers] ;
    } else {
        NSArray *itemIdentifiers = [skin toNSObjectAtIndex:2] ;
        // Make sure the table is an array and not key-value pairs
        BOOL listIsGood = [itemIdentifiers isKindOfClass:[NSArray class]] ;
        // Make sure all of the members are strings
        if (listIsGood) {
            for (NSString *identifier in itemIdentifiers) {
                if (![identifier isKindOfClass:[NSString class]]) {
                    listIsGood = NO ;
                    break ;
                }
            }
        }

        if (!listIsGood) {
            return luaL_argerror(L, 2, "expected array of string identifiers") ;
        }

        // our setter ensures they are unique
        dictionary.allowedIdentifiers = itemIdentifiers ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.toolbar.dictionary:defaultItems([items]) -> itemDictionaryObject | table
/// Method
/// Get or set the default items for toolbars using this dictionary. This determines the initial order and visibility of items for the toolbar.
///
/// Parameters:
///  * `items` - an optional table of string identifiers specifying the default items for toolbars using this dictionary.
///
/// Returns:
///  * if an argument is provided, returns the itemDictionaryObject; otherwise returns the current value
///
/// Notes:
///  * the order of the item identifiers in the assigned table determines the order and visibility of the initial toolbar items for the toolbar. If the toolbar's state has been modified by the use of toolbar insert and remove methods, or if the user has customized the toolbar, this table will be ignored.
static int dictionary_defaultItems(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DICT_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbarDictionary *dictionary = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:dictionary.defaultIdentifiers] ;
    } else {
        NSArray *itemIdentifiers = [skin toNSObjectAtIndex:2] ;

//         NSArray *allowedIdentifiers = dictionary.allowedIdentifiers ;

        // Make sure the table is an array and not key-value pairs
        BOOL listIsGood = [itemIdentifiers isKindOfClass:[NSArray class]] ;
        // Make sure all of the members are strings and are allowed identifier
        if (listIsGood) {
            for (NSString *identifier in itemIdentifiers) {
                if (!([identifier isKindOfClass:[NSString class]])) { // && [allowedIdentifiers containsObject:identifier])) {
                    listIsGood = NO ;
                    break ;
                }
            }
        }

        if (!listIsGood) {
            return luaL_argerror(L, 2, "expected array of string identifiers from list of allowed items") ;
        }

        dictionary.defaultIdentifiers = itemIdentifiers ;
        lua_pushvalue(L, 1) ;
    }

    return 1 ;
}

// static int dictionary_selectableItems(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, UD_DICT_TAG, LS_TBREAK] ;
//     HSUITKToolbarDictionary *dictionary = [skin toNSObjectAtIndex:1] ;
//     [skin pushNSObject:dictionary.selectableIdentifiers] ;
//     return 1 ;
// }

// static int dictionary_immovableItems(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, UD_DICT_TAG, LS_TBREAK] ;
//     HSUITKToolbarDictionary *dictionary = [skin toNSObjectAtIndex:1] ;
//     [skin pushNSObject:dictionary.immovableIdentifiers] ;
//     return 1 ;
// }

/// hs._asm.uitk.toolbar.dictionary:definedItems() -> table
/// Method
/// Get a list of the items identifiers for the currently defined items in this dictionary.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the item identifiers of the currently defined items in this dictionary.
static int dictionary_definedItems(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DICT_TAG, LS_TBREAK] ;
    HSUITKToolbarDictionary *dictionary = [skin toNSObjectAtIndex:1] ;
    [skin pushNSObject:dictionary.definedIdentifiers] ;
    return 1 ;
}

/// hs._asm.uitk.toolbar.dictionary:itemDefinition(id) -> table | nil
/// Method
/// Get the definition of the item with the specified identifier
///
/// Parameters:
///  * `id` - a string specifying the identifier of the item whose definition you wish returned.
///
/// Returns:
///  * if an item with the specified identifier has been defined in this dictionary, returns a table containing key-value pairs that define the item; if no item with the specified identifier has been defined, returns nil.
static int dictionary_itemDictionary(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DICT_TAG, LS_TSTRING, LS_TBREAK] ;
    HSUITKToolbarDictionary *dictionary = [skin toNSObjectAtIndex:1] ;
    NSString                *itemID     = [skin toNSObjectAtIndex:2] ;

    [skin pushNSObject:dictionary.itemDefinitions[itemID]] ;
    return 1 ;
}

/// hs._asm.uitk.toolbar.dictionary:addItem([id], definition]) -> itemDictionaryObject
/// Method
/// Add an item definition to the item dictionary.
///
/// Parameters:
///  * `id`         - an optional string, specifying the identifier of the item the definition describes. If this argument is not provided, then the definition table *must* include an "id" key specifying the item identifier within its key-value pairs.
///  * `definition` - a table of key-value pairs defining the item.
///
/// Returns:
///  * if no item with the specified identifier exists, returns the itemDictionaryObject after creating it; otherwise throws an error
///
/// Notes:
///  * see [hs._asm.uitk.toolbar.dictionary.definition](#definition) for a description of the recognized key-value pairs you can include in the definition table.
///
///  * If this method is invoked for an item definition after a toolbar using this dictionary has already been assigned to a window, any placeholder items in the toolbar with this identifier will be replaced with the new definition. This will reset any local modifications that have been performed on the specific itemObjects that may have been performed (see `hs._asm.uitk.toolbar.item` methods).
static int dictionary_addItem(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DICT_TAG, LS_TSTRING | LS_TTABLE, LS_TBREAK | LS_TVARARG] ;
    HSUITKToolbarDictionary *dictionary = [skin toNSObjectAtIndex:1] ;
    NSString                *itemID     = (lua_type(L, 2) == LUA_TSTRING) ? [skin toNSObjectAtIndex:2] : nil ;
    int                     detailIndex = itemID ? 3 : 2 ;

    if (detailIndex == 2) {
        [skin checkArgs:LS_TUSERDATA, UD_DICT_TAG, LS_TTABLE, LS_TBREAK] ;
        if (lua_getfield(L, 2, "id") == LUA_TSTRING) {
            itemID = [skin toNSObjectAtIndex:-1] ;
        } else {
            return luaL_argerror(L, 2, "expected id key with string value in definition table") ;
        }
        lua_pop(L, 1) ;
    } else {
        [skin checkArgs:LS_TUSERDATA, UD_DICT_TAG, LS_TSTRING, LS_TTABLE, LS_TBREAK] ;
    }

    NSError *error = nil ;
    BOOL successful = [dictionary addItem:itemID propertiesAtIndex:detailIndex withState:L error:&error] ;

    if (!successful || error) {
        if (error) {
            return luaL_argerror(L, 3, error.localizedDescription.UTF8String) ;
        } else {
            return luaL_argerror(L, 3, "unable to add item definition to dictionary") ;
        }
    }

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.toolbar.dictionary:modifiyItem([id], definition, [replace]) -> itemDictionaryObject
/// Method
/// Modify the existing definition for an item in the toolbar item dictionary.
///
/// Parameters:
///  * `id`         - an optional string, specifying the identifier of the item the definition changes apply to. If this argument is not provided, then the definition table *must* include an "id" key specifying the item identifier within its key-value pairs.
///  * `definition` - a table of key-value pairs defining the item.
///  * `replace`    - an optional boolean, default false, specifying whether the definition table should fully replace the existing item definition (true) or just modify the attributes provided in the `defintion` table (false).
///
/// Returns:
///  * if an item with the specified id exists to be modified or replaced, returns the itemDictionaryObject after modifying it; otherwise throws an error
///
/// Notes:
///  * see [hs._asm.uitk.toolbar.dictionary.definition](#definition) for a description of the recognized key-value pairs you can include in the definition table.
///  * if you are changing the `type` attribute of an item, you must replace the entire definition (i.e. the `replace` argument must be true).
///
///  * If the item definition being modified applies to an item currently being displayed in a toolbar, the existing toolbar items will be modified (or replaced, if `replace` is true) resetting any local modifications that have been performed on the specific itemObjects that may have been performed (see `hs._asm.uitk.toolbar.item` methods).
static int dictionary_modifyItem(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DICT_TAG, LS_TSTRING | LS_TTABLE, LS_TBREAK | LS_TVARARG] ;
    HSUITKToolbarDictionary *dictionary = [skin toNSObjectAtIndex:1] ;
    NSString                *itemID     = (lua_type(L, 2) == LUA_TSTRING) ? [skin toNSObjectAtIndex:2] : nil ;
    int                     detailIndex = itemID ? 3 : 2 ;

    if (detailIndex == 2) {
        [skin checkArgs:LS_TUSERDATA, UD_DICT_TAG, LS_TTABLE, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
        if (lua_getfield(L, 2, "id") == LUA_TSTRING) {
            itemID = [skin toNSObjectAtIndex:-1] ;
        } else {
            return luaL_argerror(L, 2, "expected id key with string value in definition table") ;
        }
        lua_pop(L, 1) ;
    } else {
        [skin checkArgs:LS_TUSERDATA, UD_DICT_TAG, LS_TSTRING, LS_TTABLE, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    }

    BOOL replace = (lua_type(L, -1) == LUA_TBOOLEAN) ? (BOOL)(lua_toboolean(L, -1)) : NO ;

    NSError *error = nil ;
    BOOL successful = [dictionary modifyItem:itemID andReplace:replace
                                             propertiesAtIndex:detailIndex
                                                     withState:L
                                                         error:&error] ;

    if (!successful || error) {
        if (error) {
            return luaL_argerror(L, 3, error.localizedDescription.UTF8String) ;
        } else {
            return luaL_argerror(L, 3, "unable to modify item definition in dictionary") ;
        }
    }

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.toolbar.dictionary:deleteItem(id) -> itemDictionaryObject
/// Method
/// Removes the definition for the item with the specified id from the dictionary.
///
/// Parameters:
///  * `id`         - a string specifying the identifier of the item definition to remove.
///
/// Returns:
///  * if an item with the specified identifier exists, returns the itemDictionaryObject after removing it; otherwise throws an error
///
/// Notes:
///  * if the identifier specifies an item that is currently assigned to toolbars using this dictionary, the item is removed from the assigned toolbar items before the definition is removed.
static int dictionary_deleteItem(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_DICT_TAG, LS_TSTRING, LS_TBREAK] ;
    HSUITKToolbarDictionary *dictionary = [skin toNSObjectAtIndex:1] ;
    NSString                *itemID     = [skin toNSObjectAtIndex:2] ;

    NSError *error = nil ;
    BOOL successful = [dictionary deleteItem:itemID withState:L error:&error] ;

    if (!successful || error) {
        if (error) {
            return luaL_argerror(L, 3, error.localizedDescription.UTF8String) ;
        } else {
            return luaL_argerror(L, 3, "unable to remove item definition from dictionary") ;
        }
    }

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.toolbar.dictionary.definition
/// Field
/// Key-Value pairs allowed in toolbar item definition tables
///
/// The following key-value pairs apply to all toolbar item types:
///   * `id`                  - a string specifying the item identifier for the definition. This key is only used by the [hs._asm.uitk.toolbar.dictionary:addItem](#addItem) and [hs._asm.uitk.toolbar.dictionary:modifyItem](#modifyItem) methods and is ignored in all other contexts.
///   * `type`                - a string, default "item" if not provided, specifying the toolbar item type. Currently recognized types are "item", "group", and "menu".
///   * `label`               - a string specifying the label that appears for this item in the toolbar when text is displayed.
///   * `paletteLabel`        - a string specifying the label that appears in the customization palette for this item. If this is not set, or is set to the empty string, then the value for `label` will be used.
///   * `tooltip`             - a string specifying the tooltip to display when someone hovers over the item in the toolbar
///   * `image`               - an `hs.image` object specifying the image to display for this item in the toolbar when the icon is displayed.
///   * `priority`            - an integer specifying the visibility priority for this toolbar item when the windows width isn't sufficient to display all of the items and must put some into an overflow menu. See `hs._asm.uitk.toolbar.itempriorities` for suggestions.
///   * `tag`                 - an integer value that you can set and use for your own purposes -- the macOS system ignores this value.
///   * `enabled`             - a boolean, default true, indicating whether or not the toolbar item is enabled and can receive button clicks from the user.
///   * `bordered`            - a boolean, default false, indicating whether or not the toolbar item has a bordered style.
///   * `navigational`        - a boolean indicating whether or not the item is used to navigate within the attached window's content. Navigational items may be treated separately from the other toolbar items for positioning and overflow purposes by the macOS.
///   * `menuForm`            - an `hs._asm.uitk.menu.item` object that should be used for the item when the item is moved into the toolbar overflow menu. You do not have to set this attribute unless you wish to modify the default behavior of showing a menu item with a title matching the item's `label`.
///   * `selectable`          - a boolean, default false, indicating whether or not this item is selectable; selectable items will show a highlight around the last selectable item that was clicked on, clearing any previously selected item, if one exists.
///   * `immovable`           - a boolean, default false, indicating that the item cannot be moved or removed from the toolbar by the user using the customization palette. Items with this attribute set to false should also be listed as part of the default items -- see [hs._asm.uitk.toolbar:defaultItems](#defaultItems) to ensure that they are presented in the toolbar.
///   * `callback`            - a callback function unique to this toolbar item that will be called when the user interacts with this item. The callback function should expect three arguments (`toolbarObject, "action", toolbarItemObject`) and return none. If this attribute is not set, the `hs._asm.uitk.toolbar:callback` function will act as a fallback, if defined.
///
/// The following key-value pairs apply only when `type` is "group":
///   * `groupMembers`        - a table, default empty, specifying the string identifiers of the members of this toolbar item group. Item groups are collections of ordered toolbar items that are added or removed from the toolbar as a unit, rather than as individual items.
///   * `groupRepresentation` - "automatic", "expanded", "collapsed"
///   * `groupSelectionMode`  - "momentary", "multiple", "single"
///
/// The following key-value pairs apply only when `type` is "menu":
///   * `menu`                -
///   * `menuIndicator`       -

// disabled for now... requires copyWithState: -- lets see if it's missed
// ///   * `title`               - a string specifying the title for this toolbar item when the toolbar item has a custom element assigned.
// ///   * `element`             - an `hs._asm.uitk.element` object that will be displayed for the toolbar item instead of the default label or icon.

#pragma mark - Item Methods -

// NOTE: In these methods, most of the time we're accessing the object as a generic NSToolbarItem.
//       Because we have multiple types that are all NSToolbarItem subclasses, it's easier (i.e.
//       requires less coercion or compiler warnings) to stick with the base class when working
//       with properties they all have and coerce only when necessary

/// hs._asm.uitk.toolbar.item:type() -> string
/// Method
/// Get the type of toolbar item.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string specifying the type of toolbar item
///
/// Notes:
///  * the current possible return values for this method are "item", "group", and "menu"
static int item_type(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TBREAK] ;
    NSToolbarItem *item = [skin toNSObjectAtIndex:1] ;

    if ([item isKindOfClass:[HSUITKToolbarItem class]]) {
        lua_pushstring(L, "item") ;
    } else if ([item isKindOfClass:[HSUITKToolbarItemGroup class]]) {
        lua_pushstring(L, "group") ;
    } else if ([item isKindOfClass:[HSUITKMenuToolbarItem class]]) {
        lua_pushstring(L, "menu") ;
    } else {
        [skin pushNSObject:[NSString stringWithFormat:@"*** %@", item.className]] ;
    }
    return 1 ;
}

/// hs._asm.uitk.toolbar.item:identifier() -> string
/// Method
/// Return the toolbar item's identifier.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string specifying the toolbar item's identifier
static int item_identifier(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TBREAK] ;
    NSToolbarItem *item = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:item.itemIdentifier] ;
    return 1 ;
}

/// hs._asm.uitk.toolbar.item:visible() -> boolean
/// Method
/// Return a boolean value indicating whether the toolbar item is currently visible.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean specifying whether or not the toolbar item is currently visible.
///
/// Notes:
///  * a toolbar item is visible if it is currently assigned to a toolbar and not in the overflow menu
static int item_isVisible(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TBREAK] ;
    NSToolbarItem *item = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 12, *)) {
        lua_pushboolean(L, item.visible) ;
    } else {
        NSToolbar *toolbar = item.toolbar ;
        if (toolbar) {
            lua_pushboolean(L, [toolbar.visibleItems containsObject:item]) ;
        } else {
            lua_pushboolean(L, NO) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.toolbar.item:toolbar() -> toolbarObject | nil
/// Method
/// Get the toolbar that the item is a member of
///
/// Parameters:
///  * None
///
/// Returns:
///  * if the item is attached to a toolbar, returns the toolbarObject, otherwise returns nil
static int item_toolbar(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TBREAK] ;
    NSToolbarItem *item = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:item.toolbar] ;
    return 1 ;
}

/// hs._asm.uitk.toolbar.item:dictionary() -> itemDictionaryObject
/// Method
/// Returns the dictionary that contains the item's definition
///
/// Parameters:
///  * None
///
/// Returns:
///  * the dictionary object that contains the toolbar item's definition
static int item_target(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TBREAK] ;
    NSToolbarItem *item = [skin toNSObjectAtIndex:1] ;

    NSToolbar *toolbar = item.toolbar ;
    if (toolbar) {
        [skin pushNSObject:toolbar.delegate] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.toolbar.item:tag([tag]) -> toolbarItemObject | integer
/// Method
/// Get or set the toolbar item's tag value
///
/// Parameters:
///  * `tag` - an optional integer, specifying the tag to assign to the toolbar item
///
/// Returns:
///  * if an argument is provided, returns the toolbarItemObject; otherwise returns the current value
///
/// Notes:
///  * this is a purely informational value and can be used for your own purposes in differentiating or storing information about the toolbar items
static int item_tag(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    NSToolbarItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, item.tag) ;
    } else {
        item.tag = lua_tointeger(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.toolbar.item:priority([priority]) -> toolbarItemObject | integer
/// Method
/// Get or set the toolbar item's visibility priority when the overflow menu is reqjuired.
///
/// Parameters:
///  * `priority` - an optional integer, default 0, specifying visibility priority for the item.
///
/// Returns:
///  * if an argument is provided, returns the toolbarItemObject; otherwise returns the current value
///
/// Notes:
///  * Lower priority items may get shifted to the overflow menu when toolbar space is limited.
///  * suggested values are provided in `hs._asm.uitk.toolbar.itempriorities`.
static int item_visibilityPriority(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    NSToolbarItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushinteger(L, item.visibilityPriority) ;
    } else {
        item.visibilityPriority = lua_tointeger(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.toolbar.item:label([label]) -> toolbarItemObject | string
/// Method
/// Get or set the toolbar item's label.
///
/// Parameters:
///  * `label` - an optional string, default the empty string, specifying the label to display for the menu item when displayed as text or as icon & text.
///
/// Returns:
///  * if an argument is provided, returns the toolbarItemObject; otherwise returns the current value
///
/// Notes:
///  * See also `hs._asm.toolbar:displayMode`.
///  * This will also be used as the [hs._asm.uitk.toolbar.item:paletteLabel](#paletteLabel) if it hasn't been set.
static int item_label(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSToolbarItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.label] ;
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

/// hs._asm.uitk.toolbar.item:paletteLabel([label]) -> toolbarItemObject | string
/// Method
/// Get or set the toolbar item's palette label.
///
/// Parameters:
///  * `label` - an optional string, default the empty string, specifying the label to display for the menu item when the customization panel is active.
///
/// Returns:
///  * if an argument is provided, returns the toolbarItemObject; otherwise returns the current value
///
/// Notes:
///  * If this is not set, or is set to the empty string, the value for [hs._asm.uitk.toolbar.item:label](#label) will be used.
static int item_paletteLabel(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSToolbarItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.paletteLabel] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            item.paletteLabel = @"" ;
        } else {
            item.paletteLabel = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.toolbar.item:toolTip([text]) -> toolbarItemObject | string | nil
/// Method
/// Get or set the toolbar item's tooltip, displayed when the user hovers the mouse pointer over the item.
///
/// Parameters:
///  * `text` - an optional string, or explicit nil to clear, specifying the tooltip to display for the item.
///
/// Returns:
///  * if an argument is provided, returns the toolbarItemObject; otherwise returns the current value
static int item_toolTip(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSToolbarItem *item = [skin toNSObjectAtIndex:1] ;

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

static int item_isBordered(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSToolbarItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, item.bordered) ;
    } else {
        item.bordered = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int item_isNavigational(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSToolbarItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if (@available(macOS 11, *)) {
            lua_pushboolean(L, item.navigational) ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (@available(macOS 11, *)) {
            item.navigational = (BOOL)(lua_toboolean(L, 2)) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int item_image(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    NSToolbarItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.image] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            item.image = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            item.image = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int item_menuFormRepresentation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKMenuToolbarItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:item.menuFormRepresentation] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            if (item.ourMenuFormRepresentation) [skin luaRelease:refTable forNSObject:item.menuFormRepresentation] ;
            item.ourMenuFormRepresentation = nil ;
            item.menuFormRepresentation = item.initialMenuFormRepresentation ;
        } else {
            [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TUSERDATA, "hs._asm.uitk.menu.item", LS_TBREAK] ;
            if (item.ourMenuFormRepresentation) [skin luaRelease:refTable forNSObject:item.menuFormRepresentation] ;
            item.menuFormRepresentation = [skin toNSObjectAtIndex:2] ;
            item.ourMenuFormRepresentation = item.menuFormRepresentation ;
            [skin luaRetain:refTable forNSObject:item.menuFormRepresentation] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// static int item_view(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
//     NSToolbarItem *item = [skin toNSObjectAtIndex:1] ;
//
//     if (lua_gettop(L) == 1) {
//         if (item.view && [skin canPushNSObject:item.view]) {
//             [skin pushNSObject:item.view] ;
//         } else {
//             lua_pushnil(L) ;
//         }
//     } else {
//         if (lua_type(L, 2) == LUA_TNIL) {
//             if (item.view && [skin canPushNSObject:item.view]) [skin luaRelease:refTable forNSObject:item.view] ;
//             item.view = nil ;
//         } else {
//             NSView *view = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
//             if (!(view && oneOfOurElementObjects(view))) {
//                 return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
//             }
//             if (item.view && [skin canPushNSObject:item.view]) [skin luaRelease:refTable forNSObject:item.view] ;
//             [skin luaRetain:refTable forNSObject:view] ;
//             item.view = view ;
//         }
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }

// static int item_title(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
//     NSToolbarItem *item = [skin toNSObjectAtIndex:1] ;
//
//     if (lua_gettop(L) == 1) {
//         [skin pushNSObject:item.title] ;
//     } else {
//         if (lua_type(L, 2) == LUA_TNIL) {
//             item.title = @"" ;
//         } else {
//             item.title = [skin toNSObjectAtIndex:2] ;
//         }
//         lua_pushvalue(L, 1) ;
//     }
//     return 1 ;
// }
//

static int item_enabled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbarItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, item.enabled) ;
    } else {
        item.enableOverrideDictionary = YES ;
        item.enabled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

//     @property(getter=isEnabled) BOOL enabled; // can we prevent validate from overriding, based on dictionary?

// Don't think these will be useful
//     - (void)validate;
//     @property BOOL autovalidates;
//     @property(copy) NSSet<NSString *> *possibleLabels; // not sure how useful yet

# pragma mark Group item specific methods

// NOTE: This property is actually read-write, but since we're hiding the actual creation of items
//       in a dictionary that handles on-demand creation and the delegate and target stuff for us,
//       supporting changing this gets... complicated, especially when you consider that toolbars
//       with the same identifier share the same properties -- what updates the dictionary?, what
//       doesn't?, do we force the other toolbars to change items as well?, etc.
//
//       Until I see or am told a specific need for this, I don't wanna.
static int groupitem_subitems(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TBREAK] ;
    HSUITKToolbarItemGroup *item = [skin toNSObjectAtIndex:1] ;

    if (![item isKindOfClass:[HSUITKToolbarItemGroup class]]) {
        return luaL_error(L, "method only valid for group type items") ;
    }

    [skin pushNSObject:item.subitems] ;
    return 1 ;
}

static int groupitem_selectedAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbarItemGroup *item = [skin toNSObjectAtIndex:1] ;
    NSInteger              idx   = lua_tointeger(L, 2) ;
    idx-- ;

    if (![item isKindOfClass:[HSUITKToolbarItemGroup class]]) {
        return luaL_error(L, "method only valid for group type items") ;
    }

    if (lua_gettop(L) == 2) {
        if (idx < 0 || idx >= (NSInteger)item.subitems.count) {
            lua_pushboolean(L, NO) ;
        } else {
            lua_pushboolean(L, [item isSelectedAtIndex:idx]) ;
        }
    } else {
        if (!(idx < 0 || idx >= (NSInteger)item.subitems.count)) {
            [item setSelected:(BOOL)(lua_toboolean(L, 3)) atIndex:idx] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int groupitem_selectedIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbarItemGroup *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if ([item isKindOfClass:[HSUITKToolbarItemGroup class]]) {
            lua_pushinteger(L, item.selectedIndex + 1) ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if ([item isKindOfClass:[HSUITKToolbarItemGroup class]]) {
            NSInteger idx = lua_tointeger(L, 2) ;
            // an index of -1 indicates nothing currently selected, so coerce out of bounds to do the same
            if (idx < 0) idx = 0 ;
            if (idx > (NSInteger)item.subitems.count) idx = 0 ;
            item.selectedIndex = idx - 1 ;
        } else {
            return luaL_error(L, "method only valid for group type items") ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int groupitem_controlRepresentation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbarItemGroup *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if ([item isKindOfClass:[HSUITKToolbarItemGroup class]]) {
            NSArray  *keys   = [GROUP_REPRESENTATION allKeysForObject:@(item.controlRepresentation)] ;
            NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", item.controlRepresentation] ;
            [skin pushNSObject:answer] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if ([item isKindOfClass:[HSUITKToolbarItemGroup class]]) {
            NSString *key = [skin toNSObjectAtIndex:2] ;
            NSNumber *value = GROUP_REPRESENTATION[key] ;
            if (value) {
                item.controlRepresentation = value.longLongValue ;
            } else {
                NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [GROUP_REPRESENTATION.allKeys componentsJoinedByString:@", "]] ;
                return luaL_argerror(L, 2, errMsg.UTF8String) ;
            }
        } else {
            return luaL_error(L, "method only valid for group type items") ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int groupitem_selectionMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKToolbarItemGroup *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if ([item isKindOfClass:[HSUITKToolbarItemGroup class]]) {
            NSArray  *keys   = [GROUP_SELECTION_MODES allKeysForObject:@(item.selectionMode)] ;
            NSString *answer = (keys.count > 0) ? keys[0] : [NSString stringWithFormat:@"*** %ld", item.selectionMode] ;
            [skin pushNSObject:answer] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if ([item isKindOfClass:[HSUITKToolbarItemGroup class]]) {
            NSString *key = [skin toNSObjectAtIndex:2] ;
            NSNumber *value = GROUP_SELECTION_MODES[key] ;
            if (value) {
                item.selectionMode = value.longLongValue ;
            } else {
                NSString *errMsg = [NSString stringWithFormat:@"expected one of %@", [GROUP_SELECTION_MODES.allKeys componentsJoinedByString:@", "]] ;
                return luaL_argerror(L, 2, errMsg.UTF8String) ;
            }
        } else {
            return luaL_error(L, "method only valid for group type items") ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

# pragma mark Menu item specific methods

static int menuitem_menu(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKMenuToolbarItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if ([item isKindOfClass:[HSUITKMenuToolbarItem class]]) {
            [skin pushNSObject:item.menu] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if ([item isKindOfClass:[HSUITKMenuToolbarItem class]]) {
            if (lua_type(L, 2) == LUA_TNIL) {
                if (![item.menu isEqualTo:item.initialMenu]) [skin luaRelease:refTable forNSObject:item.menu] ;
                item.menu = item.initialMenu ;
            } else {
                [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TUSERDATA, "hs._asm.uitk.menu", LS_TBREAK] ;
                if (![item.menu isEqualTo:item.initialMenu]) [skin luaRelease:refTable forNSObject:item.menu] ;
                item.menu = [skin toNSObjectAtIndex:2] ;
                [skin luaRetain:refTable forNSObject:item.menu] ;
            }
        } else {
            return luaL_error(L, "method only valid for menu type items") ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int menuitem_showsIndicator(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ITEM_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKMenuToolbarItem *item = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if ([item isKindOfClass:[HSUITKMenuToolbarItem class]]) {
            lua_pushboolean(L, item.showsIndicator) ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if ([item isKindOfClass:[HSUITKMenuToolbarItem class]]) {
            item.showsIndicator = (BOOL)(lua_toboolean(L, 2)) ;
        } else {
            return luaL_error(L, "method only valid for menu type items") ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// NSSearchToolbarItem methods
// MAYBE: NSSharingServicePickerToolbarItem methods
// MAYBE: NSTrackingSeparatorToolbarItem methods

#pragma mark - Module Constants -

/// hs._asm.uitk.toolbar.systemToolbarItems[]
/// Constant
/// This table contains the macOS names for specific system provided toolbar items. You must still specify these as allowed in a toolbar item dictionary, but you not have to provide a defintion for them -- the system will provide it for you.
///
/// * The table currently contains the following system toolbar items:
///   * space                      - an empty space with a fixed size for spreading out the toolbar items
///   * flexibleSpace              - a flexible space that will expand to fill the space between two items or an item and the toolbar boundary, if it is placed at one of the ends. If there are multiple flexible spaces, they will all expand the same amount to balance the distance between items.
///
/// * The following are being considered once it has been determined what additional infrastructure is required to support them
///   * showColors                 - likely in conjunction with `hs._asm.uitk.panel.color`, but requires more investigation
///   * showFonts                  - likely in conjunction with `hs._asm.uitk.panel.font` (once implemented), but requires more investigation
///   * cloudSharing               - uncertain
// ///   * print                      - uncertain; requires a responder to support printDocument:
// ///   * toggleSidebar              - requires NSSplitView to be implemented; requires responder to support toggleSidebar:
// ///   * sidebarTrackingSeparator   - (macOS 11+) requires NSSplitView to be implemented
// ///   * inspectorTrackingSeparator - (macOS 14+) uncertain
// ///   * toggleInspector            - (macOS 14+) uncertain
static int toolbar_systemToolbarItems(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
    [skin pushNSObject:NSToolbarSpaceItemIdentifier] ;                      lua_setfield(L, -2, "space") ;
    [skin pushNSObject:NSToolbarFlexibleSpaceItemIdentifier] ;              lua_setfield(L, -2, "flexibleSpace") ;
    [skin pushNSObject:NSToolbarShowColorsItemIdentifier] ;                 lua_setfield(L, -2, "showColors") ;
    [skin pushNSObject:NSToolbarShowFontsItemIdentifier] ;                  lua_setfield(L, -2, "showFonts") ;
//     [skin pushNSObject:NSToolbarToggleSidebarItemIdentifier] ;              lua_setfield(L, -2, "toggleSidebar") ;
//     [skin pushNSObject:NSToolbarPrintItemIdentifier] ;                      lua_setfield(L, -2, "print") ;
    [skin pushNSObject:NSToolbarCloudSharingItemIdentifier] ;               lua_setfield(L, -2, "cloudSharing") ;
//     if (@available(macOS 11, *)) {
//         [skin pushNSObject:NSToolbarSidebarTrackingSeparatorItemIdentifier] ;   lua_setfield(L, -2, "sidebarTrackingSeparator") ;
//     }
//     if (@available(macOS 14, *)) {
//         [skin pushNSObject:NSToolbarInspectorTrackingSeparatorItemIdentifier] ; lua_setfield(L, -2, "inspectorTrackingSeparator") ;
//         [skin pushNSObject:NSToolbarToggleInspectorItemIdentifier] ;            lua_setfield(L, -2, "toggleInspector") ;
//     }
    return 1 ;
}

/// hs._asm.uitk.toolbar.itemPriorities[]
/// Constant
/// Recommended values for use with `hs._asm.uitk.toolbar.item:priority` to determine which toolbar items should be pushed into the overflow menu first if the window is not wide enough to display all of them.
///
/// The following priorities are specified, though you can of course use your own numbers with `hs._asm.uitk.toolbar.item:priority`.
///  * standard - The default visibility priority.
///  * low      - The lowest-priority for a toolbar item.
///  * high     - A high priority that makes it less likely for the toolbar item to move to the overflow item.
///  * user     - The highest priority for items in the toolbar.
static int toolbar_itemPriorities(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSToolbarItemVisibilityPriorityStandard) ; lua_setfield(L, -2, "standard") ;
    lua_pushinteger(L, NSToolbarItemVisibilityPriorityLow) ;      lua_setfield(L, -2, "low") ;
    lua_pushinteger(L, NSToolbarItemVisibilityPriorityHigh) ;     lua_setfield(L, -2, "high") ;
    lua_pushinteger(L, NSToolbarItemVisibilityPriorityUser) ;     lua_setfield(L, -2, "user") ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKToolbar(lua_State *L, id obj) {
    HSUITKToolbar *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKToolbar *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKToolbar(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKToolbar *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKToolbar, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushHSUITKToolbarDictionary(lua_State *L, id obj) {
    HSUITKToolbarDictionary *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKToolbarDictionary *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_DICT_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKToolbarDictionary(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKToolbarDictionary *value ;
    if (luaL_testudata(L, idx, UD_DICT_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKToolbarDictionary, L, idx, UD_DICT_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_DICT_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

// this works for all item types because an object is a ptr to a ptr (i.e. size is the same at this level)
// and because all of our item types have the selfRefCount property
static int pushHSUITKToolbarItem(lua_State *L, id obj) {
    HSUITKToolbarItem *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKToolbarItem *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_ITEM_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

// this works because we've given all of the item types the same userdata tag and we expect the
// receiver to know (or test for) what it really is, as we only promise to return an id (i.e. object)
static id toHSUITKToolbarItem(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKToolbarItem *value ;
    if (luaL_testudata(L, idx, UD_ITEM_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKToolbarItem, L, idx, UD_ITEM_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_ITEM_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKToolbar *obj = [skin luaObjectAtIndex:1 toClass:"HSUITKToolbar"] ;
    NSString *title = obj.identifier ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSUITKToolbar *obj1 = [skin luaObjectAtIndex:1 toClass:"HSUITKToolbar"] ;
        HSUITKToolbar *obj2 = [skin luaObjectAtIndex:2 toClass:"HSUITKToolbar"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSUITKToolbar *obj = get_objectFromUserdata(__bridge_transfer HSUITKToolbar, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin                 *skin       = [LuaSkin sharedWithState:L] ;
            HSUITKToolbarDictionary *dictionary = obj.delegate ;

            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            if (dictionary) [dictionary removeToolbar:obj] ;

// don't clear delegate -- this will be done by dealloc since a retain was done in init
//             obj.delegate = nil ;
            obj = nil ;
        }
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int ud_dictionary_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKToolbarDictionary *obj = [skin luaObjectAtIndex:1 toClass:"HSUITKToolbarDictionary"] ;
    NSString *title = obj.identifier ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_DICT_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int ud_dictionary_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, UD_DICT_TAG) && luaL_testudata(L, 2, UD_DICT_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSUITKToolbarDictionary *obj1 = [skin luaObjectAtIndex:1 toClass:"HSUITKToolbarDictionary"] ;
        HSUITKToolbarDictionary *obj2 = [skin luaObjectAtIndex:2 toClass:"HSUITKToolbarDictionary"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int ud_dictionary_gc(lua_State* L) {
    HSUITKToolbarDictionary *obj = get_objectFromUserdata(__bridge_transfer HSUITKToolbarDictionary, L, 1, UD_DICT_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
//             [knownDictionaries removeObjectForKey:obj.identifier] ;
            obj = nil ;
        }
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int ud_item_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKToolbarItem *obj = [skin toNSObjectAtIndex:1] ;
    NSString *title = obj.itemIdentifier ;
    if ([obj isKindOfClass:[HSUITKToolbarItemGroup class]]) title = [@"group " stringByAppendingString:title] ;
    if ([obj isKindOfClass:[HSUITKMenuToolbarItem class]])  title = [@"group " stringByAppendingString:title] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", UD_ITEM_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int ud_item_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, UD_ITEM_TAG) && luaL_testudata(L, 2, UD_ITEM_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSUITKToolbarItem *obj1 = [skin toNSObjectAtIndex:1] ;
        HSUITKToolbarItem *obj2 = [skin toNSObjectAtIndex:2] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int ud_item_gc(lua_State* L) {
    HSUITKToolbarItem *obj = get_objectFromUserdata(__bridge_transfer HSUITKToolbarItem, L, 1, UD_ITEM_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
//         if (obj.selfRefCount == 0) {
//             obj = nil ;
//         }
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
    knownDictionaries = nil ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"configuration",  toolbar_configurationDictionary},
    {"isCustomizing",  toolbar_customizationPaletteIsRunning},
    {"identifier",     toolbar_identifier},
    {"customizePanel", toolbar_runCustomizationPalette},
    {"items",          toolbar_items},
    {"visibleItems",   toolbar_visibleItems},
    {"insertItem",     toolbar_insertItemAtIndex},
    {"removeItem",     toolbar_removeItemAtIndex},
    {"dictionary",     toolbar_delegate},
    {"window",         toolbar_window},

    {"callback",       toolbar_callback},
    {"notifyOnChange", toolbar_notifyWhenToolbarChanges},
    {"canCustomize",   toolbar_allowsUserCustomization},
    {"autosaves",      toolbar_autosavesConfiguration},
    {"visible",        toolbar_visible},
    {"separator",      toolbar_showsBaselineSeparator},
    {"selectedItem",   toolbar_selectedItemIdentifier},
    {"sizeMode",       toolbar_sizeMode},
    {"displayMode",    toolbar_displayMode},

    {"__tostring",     userdata_tostring},
    {"__eq",           userdata_eq},
    {"__gc",           userdata_gc},
    {NULL, NULL}
};

static const luaL_Reg ud_dictionary_metaLib[] = {
    {"identifier",      dictionary_identifier},
    {"addItem",         dictionary_addItem},
    {"deleteItem",      dictionary_deleteItem},
    {"modifyItem",      dictionary_modifyItem},
    {"itemDictionary",  dictionary_itemDictionary},
    {"definedItems",    dictionary_definedItems},
    {"allowedItems",    dictionary_allowedItems},
    {"defaultItems",    dictionary_defaultItems},
//     {"selectableItems", dictionary_selectableItems},
//     {"immovableItems",  dictionary_immovableItems},

    {"__tostring",      ud_dictionary_tostring},
    {"__eq",            ud_dictionary_eq},
    {"__gc",            ud_dictionary_gc},
    {NULL, NULL}
};

static const luaL_Reg ud_item_metaLib[] = {
    {"type",                item_type},
    {"identifier",          item_identifier},
    {"visible",             item_isVisible},
    {"toolbar",             item_toolbar},
    {"dictionary",          item_target},
    {"groupMembers",        groupitem_subitems},
    {"selectedAtIndex",     groupitem_selectedAtIndex},

    {"tag",                 item_tag},
    {"priority",            item_visibilityPriority},
    {"label",               item_label},
    {"paletteLabel",        item_paletteLabel},
    {"toolTip",             item_toolTip},
    {"bordered",            item_isBordered},
    {"navigational",        item_isNavigational},
    {"image",               item_image},
    {"menuForm",            item_menuFormRepresentation},
    {"enabled",             item_enabled},
//     {"title",               item_title},
//     {"element",             item_view},

    {"selectedIndex",       groupitem_selectedIndex},
    {"groupRepresentation", groupitem_controlRepresentation},
    {"selectionMode",       groupitem_selectionMode},

    {"menu",                menuitem_menu},
    {"menuIndicator",       menuitem_showsIndicator},

    {"__tostring",          ud_item_tostring},
    {"__eq",                ud_item_eq},
    {"__gc",                ud_item_gc},
    {NULL, NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",        toolbar_new},
    {"dictionary", toolbar_dictionary},

    {NULL,         NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs__asm_uitk_libtoolbar(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    knownDictionaries = [NSMapTable strongToWeakObjectsMapTable] ;
    defineInternalDictionaries() ;

    toolbar_systemToolbarItems(L) ; lua_setfield(L, -2, "systemToolbarItems") ;
    toolbar_itemPriorities(L) ;     lua_setfield(L, -2, "itemPriorities") ;

    [skin registerPushNSHelper:pushHSUITKToolbar  forClass:"HSUITKToolbar"];
    [skin registerLuaObjectHelper:toHSUITKToolbar forClass:"HSUITKToolbar"
                                       withUserdataMapping:USERDATA_TAG];

    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"callback",
        @"notifyOnChange",
        @"visible",
        @"separator",
        @"canCustomize",
        @"autosaves",
        @"displayMode",
        @"selectedItem",
        @"sizeMode",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    [skin registerObject:UD_DICT_TAG objectFunctions:ud_dictionary_metaLib] ;

    [skin registerPushNSHelper:pushHSUITKToolbarDictionary  forClass:"HSUITKToolbarDictionary"];
    [skin registerLuaObjectHelper:toHSUITKToolbarDictionary forClass:"HSUITKToolbarDictionary"
                                                 withUserdataMapping:UD_DICT_TAG];

//     luaL_getmetatable(L, UD_DICT_TAG) ;
//     [skin pushNSObject:@[
//     ]] ;
//     lua_setfield(L, -2, "_propertyList") ;
//     lua_pop(L, 1) ;

    [skin registerObject:UD_ITEM_TAG objectFunctions:ud_item_metaLib] ;

// simpler, but interferes with existing hs.webview.toolbar... maybe someday?
//     [skin registerPushNSHelper:pushHSUITKToolbarItem  forClass:"NSToolbarItem"];

    [skin registerPushNSHelper:pushHSUITKToolbarItem  forClass:"HSUITKToolbarItem"];
    [skin registerPushNSHelper:pushHSUITKToolbarItem  forClass:"HSUITKToolbarItemGroup"];
    [skin registerPushNSHelper:pushHSUITKToolbarItem  forClass:"HSUITKMenuToolbarItem"];

// hs.webview.toolbar doesn't define this, so we can
    [skin registerLuaObjectHelper:toHSUITKToolbarItem forClass:"NSToolbarItem"
                                           withUserdataMapping:UD_ITEM_TAG];

    luaL_getmetatable(L, UD_ITEM_TAG) ;
    [skin pushNSObject:@[
        @"tag",
        @"priority",
        @"label",
        @"paletteLabel",
        @"toolTip",
        @"bordered",
        @"navigational",
        @"image",
        @"menuForm",
        @"enabled",
//         @"title",
//         @"element",

        @"selectedIndex",
        @"groupRepresentation",
        @"selectionMode",

        @"menu",
        @"menuIndicator",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
