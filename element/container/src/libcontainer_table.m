@import Cocoa ;
@import LuaSkin ;
@import ObjectiveC.runtime ;

static const char * const USERDATA_TAG  = "hs._asm.uitk.element.container.table" ;
static const char * const UD_ROW_TAG    = "hs._asm.uitk.element.container.table.row" ;
static const char * const UD_COLUMN_TAG = "hs._asm.uitk.element.container.table.column" ;

static LSRefTable         refTable      = LUA_NOREF ;

static void *CALLBACKREF_KEY  = @"HS_callbackRefKey" ;
static void *SELFREFCOUNT_KEY = @"HS_selfRefCountKey" ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *COLUMN_RESIZING ;
static NSDictionary *AUTORESIZING_STYLE ;
static NSDictionary *TABLE_GRIDLINES ;
static NSDictionary *TABLE_ROWSIZE ;
static NSDictionary *TABLE_VIEWSTYLE ;
static NSDictionary *INTERFACE_LAYOUTDIRECTION ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    COLUMN_RESIZING = @{
        @"none" : @(NSTableColumnNoResizing),
        @"auto" : @(NSTableColumnAutoresizingMask),
        @"user" : @(NSTableColumnUserResizingMask),
        @"both" : @(NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask),
    } ;

    AUTORESIZING_STYLE = @{
        @"none"              : @(NSTableViewNoColumnAutoresizing),
        @"uniform"           : @(NSTableViewUniformColumnAutoresizingStyle),
        @"sequential"        : @(NSTableViewSequentialColumnAutoresizingStyle),
        @"reverseSequential" : @(NSTableViewReverseSequentialColumnAutoresizingStyle),
        @"lastColumnOnly"    : @(NSTableViewLastColumnOnlyAutoresizingStyle),
        @"firstColumnOnly"   : @(NSTableViewFirstColumnOnlyAutoresizingStyle),
    } ;

    TABLE_GRIDLINES = @{
        @"none"                          : @(NSTableViewGridNone),
        @"verticalSolid"                 : @(NSTableViewSolidVerticalGridLineMask),
        @"horizontalSolid"               : @(NSTableViewSolidHorizontalGridLineMask),
        @"horizontalDashed"              : @(NSTableViewDashedHorizontalGridLineMask),
        @"verticalSolidAndHorizontal"    : @(NSTableViewSolidVerticalGridLineMask | NSTableViewSolidHorizontalGridLineMask),
        @"verticalSolidHorizontalDashed" : @(NSTableViewSolidVerticalGridLineMask | NSTableViewDashedHorizontalGridLineMask),
    } ;

    TABLE_ROWSIZE = @{
        @"default" : @(NSTableViewRowSizeStyleDefault),
        @"custom"  : @(NSTableViewRowSizeStyleCustom),
        @"small"   : @(NSTableViewRowSizeStyleSmall),
        @"medium"  : @(NSTableViewRowSizeStyleMedium),
        @"large"   : @(NSTableViewRowSizeStyleLarge),
    } ;

    if (@available(macOS 11, *)) {
        TABLE_VIEWSTYLE = @{
            @"automatic"  : @(NSTableViewStyleAutomatic),
            @"fullWidth"  : @(NSTableViewStyleFullWidth),
            @"inset"      : @(NSTableViewStyleInset),
            @"sourceList" : @(NSTableViewStyleSourceList),
            @"plain"      : @(NSTableViewStylePlain),
        } ;
    }

    INTERFACE_LAYOUTDIRECTION = @{
        @"leftToRight" : @(NSUserInterfaceLayoutDirectionLeftToRight),
        @"rightToLeft" : @(NSUserInterfaceLayoutDirectionRightToLeft),
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

// probably won't ever use them, but lets do it right just in case...
@interface NSTableRowView (HammerspoonAdditions)
@property (nonatomic)           int  callbackRef ;
@property (nonatomic)           int  selfRefCount ;
@property (nonatomic, readonly) int  refTable ;

- (int)callbackRef ;
- (void)setCallbackRef:(int)value ;
- (int)selfRefCount ;
- (void)setSelfRefCount:(int)value ;
- (int)refTable ;
@end

@implementation NSTableRowView (HammerspoonAdditions)
- (void)setCallbackRef:(int)value {
    NSNumber *valueWrapper = [NSNumber numberWithInt:value];
    objc_setAssociatedObject(self, CALLBACKREF_KEY, valueWrapper, OBJC_ASSOCIATION_RETAIN);
}

- (int)callbackRef {
    NSNumber *valueWrapper = objc_getAssociatedObject(self, CALLBACKREF_KEY) ;
    if (!valueWrapper) {
        [self setCallbackRef:LUA_NOREF] ;
        valueWrapper = @(LUA_NOREF) ;
    }
    return valueWrapper.intValue ;
}

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

- (int)refTable {
    return refTable ;
}
@end

@interface HSUITKElementContainerTableView : NSTableView <NSTableViewDelegate, NSTableViewDataSource>
@property            int               selfRefCount ;
@property (readonly) LSRefTable        refTable ;
@property            int               callbackRef ;
@property            int               passThroughRef ;
@property            int               dataSourceRef ;
@property            NSTableHeaderView *storedHeader ;
@property            NSView            *storedCorner ;
@end

@implementation HSUITKElementContainerTableView
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
        _dataSourceRef  = LUA_NOREF ;
        _storedHeader   = nil ;
        _storedCorner   = nil ;

        self.target     = self ;
        self.action     = @selector(performCallback:) ;
        self.continuous = NO ;

        self.delegate           = self ;
        self.dataSource         = self ;
        self.usesStaticContents = NO ;
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
    [self callbackHamster:@[ self, @(self.clickedRow + 1), @(self.clickedColumn + 1)]] ;
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

#pragma mark - NSTableViewDataSource -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    NSInteger rowCount = 0 ;

    if (_dataSourceRef != LUA_NOREF) {
        LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
        lua_State *L    = skin.L ;

        [skin pushLuaRef:refTable ref:_dataSourceRef] ;
        [skin pushNSObject:tableView] ;
        lua_pushstring(L, "count") ;
        if (![skin protectedCallAndTraceback:2 nresults:1]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            [skin logError:[NSString stringWithFormat:@"%s:dataSource callback error:%@", USERDATA_TAG, errorMessage]] ;
        } else if (lua_isinteger(L, -1)) {
            rowCount = lua_tointeger(L, -1) ;
        } else {
            [skin logError:[NSString stringWithFormat:@"%s:dataSource callback error:expected integer return for count", USERDATA_TAG]] ;
        }
        lua_pop(L, 1) ;
    }

    return rowCount ;
}

// - (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
// - (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
// - (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row;
// - (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation;
// - (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation;
// - (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes;
// - (void)tableView:(NSTableView *)tableView updateDraggingItemsForDrag:(id<NSDraggingInfo>)draggingInfo;
// - (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation;
// - (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors;

#pragma mark - NSTableViewDelegate -

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSView *viewAtCell = nil ;

    if (_dataSourceRef != LUA_NOREF) {
        LuaSkin   *skin = [LuaSkin sharedWithState:NULL] ;
        lua_State *L    = skin.L ;

        [skin pushLuaRef:refTable ref:_dataSourceRef] ;
        [skin pushNSObject:tableView] ;
        lua_pushstring(L, "view") ;
        lua_pushinteger(L, row + 1) ;
        [skin pushNSObject:tableColumn.identifier] ;
        if (![skin protectedCallAndTraceback:4 nresults:1]) {
            NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
            [skin logError:[NSString stringWithFormat:@"%s:dataSource callback error:%@", USERDATA_TAG, errorMessage]] ;
        } else if (lua_type(L, -1) == LUA_TUSERDATA) {
            viewAtCell = [skin toNSObjectAtIndex:-1] ;
            if (!oneOfOurs(viewAtCell)) {
                viewAtCell = nil ;
                [skin logError:[NSString stringWithFormat:@"%s:dataSource callback error:expected uitk element", USERDATA_TAG]] ;
            }
        } else if (lua_toboolean(L, -1)) { // i.e. not (nil or (boolean and false))
            [skin logError:[NSString stringWithFormat:@"%s:dataSource callback error:expected uitk element, nil, or false", USERDATA_TAG]] ;
        }
        lua_pop(L, 1) ;
    }

    return viewAtCell ;
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
// TODO: need a callback because row settings are lost when non-visible rows are released
//     [skin logInfo:[NSString stringWithFormat:@"%s:didAddRow - retaining row %ld", USERDATA_TAG, row]] ;
    for (NSInteger i = 0 ; i < rowView.numberOfColumns ; i++) {
        NSView *view = [rowView viewAtColumn:i] ;
        if (view) [skin luaRetain:refTable forNSObject:view] ;
    }
}

- (void)tableView:(NSTableView *)tableView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
// TODO: callback for one last chance to capture settings before it's cleared?
//     [skin logInfo:[NSString stringWithFormat:@"%s:didRemoveRow - releasing row %ld", USERDATA_TAG, row]] ;
    for (NSInteger i = 0 ; i < rowView.numberOfColumns ; i++) {
        NSView *view = [rowView viewAtColumn:i] ;
        if (view) [skin luaRelease:refTable forNSObject:view] ;
    }
}

// - (BOOL)selectionShouldChangeInTableView:(NSTableView *)tableView;
// - (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row;
// - (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
// - (BOOL)tableView:(NSTableView *)tableView shouldReorderColumn:(NSInteger)columnIndex toColumn:(NSInteger)newColumnIndex;
// - (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row;
// - (BOOL)tableView:(NSTableView *)tableView shouldSelectTableColumn:(NSTableColumn *)tableColumn;
// - (BOOL)tableView:(NSTableView *)tableView shouldShowCellExpansionForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
// - (BOOL)tableView:(NSTableView *)tableView shouldTrackCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
// - (BOOL)tableView:(NSTableView *)tableView shouldTypeSelectForEvent:(NSEvent *)event withCurrentSearchString:(NSString *)searchString;
// - (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row;
// - (CGFloat)tableView:(NSTableView *)tableView sizeToFitWidthOfColumn:(NSInteger)column;
// - (NSArray<NSTableViewRowAction *> *)tableView:(NSTableView *)tableView rowActionsForRow:(NSInteger)row edge:(NSTableRowActionEdge)edge;
// - (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
// - (NSIndexSet *)tableView:(NSTableView *)tableView selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes;
// - (NSInteger)tableView:(NSTableView *)tableView nextTypeSelectMatchFromRow:(NSInteger)startRow toRow:(NSInteger)endRow forString:(NSString *)searchString;
// - (NSString *)tableView:(NSTableView *)tableView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation;
// - (NSString *)tableView:(NSTableView *)tableView typeSelectStringForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
// - (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row;
// - (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn;
// - (void)tableView:(NSTableView *)tableView didDragTableColumn:(NSTableColumn *)tableColumn;
// - (void)tableView:(NSTableView *)tableView mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn;
// - (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
// - (void)tableViewColumnDidMove:(NSNotification *)notification;
// - (void)tableViewColumnDidResize:(NSNotification *)notification;
// - (void)tableViewSelectionDidChange:(NSNotification *)notification;
// - (void)tableViewSelectionIsChanging:(NSNotification *)notification;

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.container.table.new([frame]) -> tableObject
/// Constructor
/// Creates a new table element for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the frame for the element.
///
/// Returns:
///  * the tableObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a container element or to a `hs._asm.uitk.window`.
static int table_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementContainerTableView *element = [[HSUITKElementContainerTableView alloc] initWithFrame:frameRect];
    if (element) {
        if (lua_gettop(L) != 1) [element setFrameSize:[element fittingSize]] ;
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

static int table_newColumn(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    NSString *identifier = [skin toNSObjectAtIndex:1] ;

    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:identifier] ;

    if (column) {
        [skin pushNSObject:column] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

/// hs._asm.uitk.element.container.table:passthroughCallback([fn | nil]) -> tableObject | fn | nil
/// Method
/// Get or set the pass through callback for the table
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
static int table_passthroughCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        table.passThroughRef = [skin luaUnref:refTable ref:table.passThroughRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            table.passThroughRef = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (table.passThroughRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:table.passThroughRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int table_dataSourceCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        table.dataSourceRef = [skin luaUnref:refTable ref:table.dataSourceRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            table.dataSourceRef = [skin luaRef:refTable] ;
        }
        [table reloadData] ;
        lua_pushvalue(L, 1) ;
    } else {
        if (table.dataSourceRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:table.dataSourceRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int table_allowsColumnReordering(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, table.allowsColumnReordering) ;
    } else {
        table.allowsColumnReordering = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_allowsColumnResizing(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, table.allowsColumnResizing) ;
    } else {
        table.allowsColumnResizing = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_allowsColumnSelection(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, table.allowsColumnSelection) ;
    } else {
        table.allowsColumnSelection = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_allowsEmptySelection(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, table.allowsEmptySelection) ;
    } else {
        table.allowsEmptySelection = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_allowsMultipleSelection(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, table.allowsMultipleSelection) ;
    } else {
        table.allowsMultipleSelection = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_allowsTypeSelect(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, table.allowsTypeSelect) ;
    } else {
        table.allowsTypeSelect = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_autosaveTableColumns(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, table.autosaveTableColumns) ;
    } else {
        table.autosaveTableColumns = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_usesAlternatingRowBackgroundColors(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, table.usesAlternatingRowBackgroundColors) ;
    } else {
        table.usesAlternatingRowBackgroundColors = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_usesAutomaticRowHeights(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, table.usesAutomaticRowHeights) ;
    } else {
        table.usesAutomaticRowHeights = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_verticalMotionCanBeginDrag(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, table.verticalMotionCanBeginDrag) ;
    } else {
        table.verticalMotionCanBeginDrag = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_rowHeight(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, table.rowHeight) ;
    } else {
        CGFloat rowHeight = lua_tonumber(L, 2) ;
        if (rowHeight < 0.0) return luaL_argerror(L, 2, "rowHeight must be non-negative") ;
        table.rowHeight = rowHeight ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_rows(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, table.numberOfRows) ;
    return 1 ;
}

static int table_columns(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, table.numberOfColumns) ;
    return 1 ;
}

static int table_autosaveName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:table.autosaveName] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            table.autosaveName = nil ;
        } else {
            table.autosaveName = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_backgroundColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:table.backgroundColor] ;
    } else {
        table.backgroundColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_gridColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:table.gridColor] ;
    } else {
        table.gridColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_intercellSpacing(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:table.intercellSpacing] ;
    } else {
        NSSize newSize = [skin tableToSizeAtIndex:2] ;
        table.intercellSpacing = newSize ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_columnAutoresizingStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table  = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(table.columnAutoresizingStyle) ;
        NSArray  *temp   = [AUTORESIZING_STYLE allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized resizing type %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = AUTORESIZING_STYLE[key] ;
        if (value) {
            table.columnAutoresizingStyle = value.unsignedIntegerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[AUTORESIZING_STYLE allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int table_gridStyleMask(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table  = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(table.gridStyleMask) ;
        NSArray  *temp   = [TABLE_GRIDLINES allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized grid style type %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = TABLE_GRIDLINES[key] ;
        if (value) {
            table.gridStyleMask = value.unsignedIntegerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[TABLE_GRIDLINES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int table_rowSizeStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table  = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(table.rowSizeStyle) ;
        NSArray  *temp   = [TABLE_ROWSIZE allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized row size style type %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }

        value  = @(table.effectiveRowSizeStyle) ;
        temp   = [TABLE_ROWSIZE allKeysForObject:value] ;
        answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized effective row size style type %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
        return 2 ;
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = TABLE_ROWSIZE[key] ;
        if (value) {
            table.rowSizeStyle = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[TABLE_ROWSIZE allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int table_selectionHighlightStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table  = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, (table.selectionHighlightStyle == NSTableViewSelectionHighlightStyleRegular)) ;
    } else {
        table.selectionHighlightStyle = lua_toboolean(L, 2) ? NSTableViewSelectionHighlightStyleRegular
                                                            : NSTableViewSelectionHighlightStyleNone ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_style(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table  = [skin toNSObjectAtIndex:1] ;

    if (@available(macOS 11, *)) {
        if (lua_gettop(L) == 1) {
            NSNumber *value  = @(table.style) ;
            NSArray  *temp   = [TABLE_VIEWSTYLE allKeysForObject:value] ;
            NSString *answer = [temp firstObject] ;
            if (answer) {
                [skin pushNSObject:answer] ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized table view style type %@ -- notify developers", USERDATA_TAG, value]] ;
                lua_pushnil(L) ;
            }

            value  = @(table.effectiveStyle) ;
            temp   = [TABLE_VIEWSTYLE allKeysForObject:value] ;
            answer = [temp firstObject] ;
            if (answer) {
                [skin pushNSObject:answer] ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized effective table view style type %@ -- notify developers", USERDATA_TAG, value]] ;
                lua_pushnil(L) ;
            }
            return 2 ;
        } else {
            NSString *key   = [skin toNSObjectAtIndex:2] ;
            NSNumber *value = TABLE_VIEWSTYLE[key] ;
            if (value) {
                table.style = value.integerValue ;
                lua_pushvalue(L, 1) ;
            } else {
                return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[TABLE_VIEWSTYLE allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
            }
        }
    } else {
        [skin logInfo:[NSString stringWithFormat:@"%s:style - Requires macOS 11.0 or newer", USERDATA_TAG]] ;
        if (lua_gettop(L) == 1) {
            lua_pushnil(L) ;
        } else {
            lua_pushvalue(L, 1) ;
        }
    }

    return 1 ;
}

static int table_userInterfaceLayoutDirection(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table  = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(table.userInterfaceLayoutDirection) ;
        NSArray  *temp   = [INTERFACE_LAYOUTDIRECTION allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized layout direction type %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = INTERFACE_LAYOUTDIRECTION[key] ;
        if (value) {
            table.userInterfaceLayoutDirection = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[INTERFACE_LAYOUTDIRECTION allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int table_addTableColumn(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, UD_COLUMN_TAG, LS_TBREAK] ;
    HSUITKElementContainerTableView *table  = [skin toNSObjectAtIndex:1] ;
    NSTableColumn          *column = [skin toNSObjectAtIndex:2] ;

    [table addTableColumn:column] ;
    [table reloadData] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int table_removeTableColumn(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK] ;
    HSUITKElementContainerTableView *table  = [skin toNSObjectAtIndex:1] ;

    NSTableColumn *column     = nil ;
    if (lua_type(L, 2) == LUA_TUSERDATA) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, UD_COLUMN_TAG, LS_TBREAK] ;
        column = [skin toNSObjectAtIndex:2] ;
    } else if (lua_type(L, 2) == LUA_TSTRING) {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
        NSString *identifier = [skin toNSObjectAtIndex:2] ;
        column = [table tableColumnWithIdentifier:identifier] ;
        if (!column) {
            return luaL_argerror(L, 2, "identifier not recognized") ;
        }
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
        NSInteger idx   = lua_tointeger(L, 2) ;
        NSInteger count = table.numberOfColumns ;

        if (idx < 0) idx = count + 1 + idx ;
        if (idx < 1 || idx > count) {
            return luaL_argerror(L, 2, "index out of bounds") ;
        }
        column = [table.tableColumns objectAtIndex:(NSUInteger)(idx - 1)] ;
    }

    [table removeTableColumn:column] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int table_columnWithIdentifier(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table      = [skin toNSObjectAtIndex:1] ;

    if (lua_type(L, 2) == LUA_TSTRING) {
        NSString      *identifier = [skin toNSObjectAtIndex:2] ;
        NSTableColumn *column     = [table tableColumnWithIdentifier:identifier] ;
        [skin pushNSObject:column] ;
    } else {
        NSInteger idx   = lua_tointeger(L, 2) ;
        NSInteger count = table.numberOfColumns ;

        if (idx < 0) idx = count + 1 + idx ;
        idx-- ;
        if (idx < 0 || idx >= count) {
            lua_pushnil(L) ;
        } else {
            NSTableColumn *col = [table.tableColumns objectAtIndex:(NSUInteger)idx] ;
            [skin pushNSObject:col] ;
        }
    }
    return 1 ;
}

static int table_tableColumns(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementContainerTableView *table      = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:table.tableColumns] ;
    return 1 ;
}

static int table_viewAtRowColumn(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TSTRING | LS_TNUMBER | LS_TINTEGER,
                    LS_TBREAK] ;
    HSUITKElementContainerTableView *table      = [skin toNSObjectAtIndex:1] ;
    NSInteger              row         = lua_tointeger(L, 2) ;
    NSInteger              col         = (lua_type(L, 3) == LUA_TNUMBER) ? lua_tointeger(L, 3) : NSNotFound ;

    if (lua_type(L, 3) == LUA_TSTRING) {
        NSString      *identifier = [skin toNSObjectAtIndex:3] ;
        NSTableColumn *column     = [table tableColumnWithIdentifier:identifier] ;
        if (column) {
            col = [table columnWithIdentifier:column.identifier] ;
        } else {
            lua_pushnil(L) ;
            return 1 ;
        }
    }

    NSInteger rCount = table.numberOfRows ;
    if (row < 0) row = rCount + 1 + row ;
    if (row < 1 || row > rCount) {
        lua_pushnil(L) ;
        return 1;
    }
    NSInteger cCount = table.numberOfColumns ;
    if (col < 0) col = cCount + 1 + col ;
    if (col < 1 || col > cCount) {
        lua_pushnil(L) ;
        return 1;
    }

    NSView *view = [table viewAtColumn:(col - 1) row:(row - 1) makeIfNecessary:YES] ;

    if (view) {
        [skin pushNSObject:view] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

static int table_reloadData(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    [table reloadData] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int table_hiddenRows(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    NSIndexSet     *rows  = [table hiddenRowIndexes] ;
    NSMutableArray *array = [NSMutableArray array] ;

    [rows enumerateIndexesUsingBlock:^(NSUInteger idx, __unused BOOL *stop) {
        [array addObject:@(idx)] ;
    }];

    [skin pushNSObject:array] ;
    return 1 ;
}

static int table_hideRow(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    NSInteger idx   = lua_tointeger(L, 2) ;
    NSInteger count = table.numberOfRows ;
    if (idx < 0) idx = count + 1 + idx ;
    if (idx < 1 || idx > count) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }

    if (lua_gettop(L) == 2) {
        NSIndexSet *rows  = [table hiddenRowIndexes] ;
        lua_pushboolean(L, [rows containsIndex:(NSUInteger)(idx - 1)]) ;
    } else {
        if (lua_toboolean(L, 3)) {
            [table hideRowsAtIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)(idx - 1)]
                       withAnimation:NSTableViewAnimationEffectNone] ;
        } else {
            [table unhideRowsAtIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)(idx - 1)]
                         withAnimation:NSTableViewAnimationEffectNone] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_showHeader(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, table.headerView ? YES : NO) ;
    } else {
        if (lua_toboolean(L, 2)) {
            if (!table.headerView) {
                table.headerView = table.storedHeader ;
                table.cornerView = table.storedCorner ;
                table.storedHeader = nil ;
                table.storedCorner = nil ;
            }
        } else {
            if (table.headerView) {
                table.storedHeader = table.headerView ;
                table.storedCorner = table.cornerView ;
                table.headerView = nil ;
                table.cornerView = nil ;
            }
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_scrollToRow(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    NSInteger idx   = lua_tointeger(L, 2) ;
    NSInteger count = table.numberOfRows ;
    if (idx < 0) idx = count + 1 + idx ;
    if (idx < 1 || idx > count) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }

    [table scrollRowToVisible:(idx - 1)];
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int table_scrollToColumn(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    NSInteger idx = (lua_type(L, 2) == LUA_TNUMBER) ? lua_tointeger(L, 2) : NSNotFound ;
    if (lua_type(L, 2) == LUA_TSTRING) {
        NSString      *identifier = [skin toNSObjectAtIndex:2] ;
        NSTableColumn *column     = [table tableColumnWithIdentifier:identifier] ;
        if (column) {
            idx = [table columnWithIdentifier:column.identifier] ;
        } else {
            return luaL_argerror(L, 2, "identifier not recognized") ;
        }
    }

    NSInteger count = table.numberOfColumns ;
    if (idx < 0) idx = count + 1 + idx ;
    if (idx < 1 || idx > count) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }

    [table scrollColumnToVisible:(idx - 1)];
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int table_selectAll(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_toboolean(L, 2)) {
        [table selectAll:table] ;
    } else {
        [table deselectAll:table] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int table_rowForElement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_type(L, 2) == LUA_TUSERDATA) {
        NSView *view = [skin toNSObjectAtIndex:2] ;
        if (oneOfOurs(view)) {
            lua_pushinteger(L, [table rowForView:view] + 1) ;
            return 1 ;
        }
    }

    return luaL_argerror(L, 2, "expected a uitk element object") ;
}

static int table_columnForElement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_type(L, 2) == LUA_TUSERDATA) {
        NSView *view = [skin toNSObjectAtIndex:2] ;
        if (oneOfOurs(view)) {
            lua_pushinteger(L, [table columnForView:view] + 1) ;
            return 1 ;
        }
    }

    return luaL_argerror(L, 2, "expected a uitk element object") ;
}

static int table_sizeToFit(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    BOOL lastColumnOnly = (lua_gettop(L) == 2) ? (BOOL)(lua_toboolean(L, 2)) : NO ;

    if (lastColumnOnly) {
        [table sizeLastColumnToFit] ;
    } else {
        [table sizeToFit] ;
    }

    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int table_selectedColumns(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSIndexSet     *set   = [table selectedColumnIndexes] ;
        NSMutableArray *array = [NSMutableArray array] ;
        [set enumerateIndexesUsingBlock:^(NSUInteger idx, __unused BOOL *stop) {
            [array addObject:@(idx + 1)] ;
        }];
        [skin pushNSObject:array] ;
    } else {
        BOOL extend = (lua_gettop(L) == 3) ? (BOOL)(lua_toboolean(L, 3)) : NO ;
        NSArray *selection = [skin toNSObjectAtIndex:2] ;
        if ([selection isKindOfClass:[NSNumber class]]) {
            selection = @[
                (NSNumber *)selection
            ] ;
        }

        NSMutableIndexSet *indexes  = [NSMutableIndexSet indexSet] ;
        __block BOOL      goodTable = [selection isKindOfClass:[NSArray class]] ;
        NSInteger         colCount  = table.numberOfColumns ;

        if (goodTable) {
            [selection enumerateObjectsUsingBlock:^(NSNumber *obj, __unused NSUInteger i, BOOL *stop) {
                if ([obj isKindOfClass:[NSNumber class]]) {
                    NSInteger idx = obj.integerValue ;
                    if (idx < 0) idx = colCount + 1 + idx ;
                    if (idx < 1 || idx > colCount) {
                        goodTable = NO ;
                        *stop = YES ;
                    } else {
                        [indexes addIndex:(NSUInteger)(idx - 1)] ;
                    }
                } else {
                    goodTable = NO ;
                    *stop = YES ;
                }
            }] ;
        }

        if (!goodTable) {
            return luaL_argerror(L, 2, "expected table of indicies or an index was out of bounds") ;
        }

        [table selectColumnIndexes:indexes byExtendingSelection:extend] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_selectedRows(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSIndexSet     *set   = [table selectedRowIndexes] ;
        NSMutableArray *array = [NSMutableArray array] ;
        [set enumerateIndexesUsingBlock:^(NSUInteger idx, __unused BOOL *stop) {
            [array addObject:@(idx + 1)] ;
        }];
        [skin pushNSObject:array] ;
    } else {
        BOOL extend = (lua_gettop(L) == 3) ? (BOOL)(lua_toboolean(L, 3)) : NO ;
        NSArray *selection = [skin toNSObjectAtIndex:2] ;
        if ([selection isKindOfClass:[NSNumber class]]) {
            selection = @[
                (NSNumber *)selection
            ] ;
        }

        NSMutableIndexSet *indexes  = [NSMutableIndexSet indexSet] ;
        __block BOOL      goodTable = [selection isKindOfClass:[NSArray class]] ;
        NSInteger         rowCount  = table.numberOfRows ;

        if (goodTable) {
            [selection enumerateObjectsUsingBlock:^(NSNumber *obj, __unused NSUInteger i, BOOL *stop) {
                if ([obj isKindOfClass:[NSNumber class]]) {
                    NSInteger idx = obj.integerValue ;
                    if (idx < 0) idx = rowCount + 1 + idx ;
                    if (idx < 1 || idx > rowCount) {
                        goodTable = NO ;
                        *stop = YES ;
                    } else {
                        [indexes addIndex:(NSUInteger)(idx - 1)] ;
                    }
                } else {
                    goodTable = NO ;
                    *stop = YES ;
                }
            }] ;
        }

        if (!goodTable) {
            return luaL_argerror(L, 2, "expected table of indicies or an index was out of bounds") ;
        }

        [table selectRowIndexes:indexes byExtendingSelection:extend] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int table_isColumnSelected(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    NSInteger idx = (lua_type(L, 2) == LUA_TNUMBER) ? lua_tointeger(L, 2) : NSNotFound ;
    if (lua_type(L, 2) == LUA_TSTRING) {
        NSString      *identifier = [skin toNSObjectAtIndex:2] ;
        NSTableColumn *column     = [table tableColumnWithIdentifier:identifier] ;
        if (column) {
            idx = [table columnWithIdentifier:column.identifier] ;
        } else {
            return luaL_argerror(L, 2, "identifier not recognized") ;
        }
    }

    NSInteger count = table.numberOfColumns ;
    if (idx < 0) idx = count + 1 + idx ;
    if (idx < 1 || idx > count) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }

    lua_pushboolean(L, [table isColumnSelected:idx]) ;
    return 1 ;
}

static int table_isRowSelected(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    NSInteger idx   = lua_tointeger(L, 2) ;
    NSInteger count = table.numberOfRows ;
    if (idx < 0) idx = count + 1 + idx ;
    if (idx < 1 || idx > count) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }

    lua_pushboolean(L, [table isRowSelected:idx]) ;
    return 1 ;
}

static int table_rowViewAtRow(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKElementContainerTableView *table = [skin toNSObjectAtIndex:1] ;

    NSInteger idx   = lua_tointeger(L, 2) ;
    NSInteger count = table.numberOfRows ;

    if (idx < 0) idx = count + 1 + idx ;
    idx-- ;
    if (idx < 0 || idx >= count) {
        lua_pushnil(L) ;
    } else {
        NSTableRowView *row = [table rowViewAtRow:idx makeIfNecessary:YES] ;
        [skin pushNSObject:row] ;
    }
    return 1 ;
}

// @property(readonly) NSInteger numberOfSelectedColumns;
// @property(readonly) NSInteger selectedColumn;
// - (void)deselectColumn:(NSInteger)column;

// @property(readonly) NSInteger numberOfSelectedRows;
// @property(readonly) NSInteger selectedRow;
// - (void)deselectRow:(NSInteger)row;

// @property(weak) NSTableColumn *highlightedTableColumn;

// - (NSIndexSet *)columnIndexesInRect:(NSRect)rect;
// - (NSInteger)columnAtPoint:(NSPoint)point;
// - (NSInteger)rowAtPoint:(NSPoint)point;
// - (NSRange)rowsInRect:(NSRect)rect;
// - (NSRect)frameOfCellAtColumn:(NSInteger)column row:(NSInteger)row;
// - (NSRect)rectOfColumn:(NSInteger)column;
// - (NSRect)rectOfRow:(NSInteger)row;
// - (void)highlightSelectionInClipRect:(NSRect)clipRect;

// - (void)reloadDataForRowIndexes:(NSIndexSet *)rowIndexes columnIndexes:(NSIndexSet *)columnIndexes;
// @property BOOL rowActionsVisible;
// @property(copy) NSArray<NSSortDescriptor *> *sortDescriptors;

#pragma mark - NSTableRowView Methods -

static int tableRow_viewAtColumn(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TSTRING | LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    NSTableRowView *row = [skin toNSObjectAtIndex:1] ;

    NSInteger idx = (lua_type(L, 2) == LUA_TNUMBER) ? lua_tointeger(L, 2) : NSNotFound ;
    if (lua_type(L, 2) == LUA_TSTRING) {
        NSString      *identifier = [skin toNSObjectAtIndex:2] ;
        NSTableView *table = (NSTableView *)[row nextResponder] ;
        if (table && [table isKindOfClass:[NSTableView class]]) {
            NSTableColumn *column = [table tableColumnWithIdentifier:identifier] ;
            if (column) {
                idx = [table columnWithIdentifier:column.identifier] ;
            } else {
                lua_pushnil(L) ;
                return 1 ;
            }
        } else {
            lua_pushnil(L) ;
            return 1 ;
        }
    }

    NSInteger count = row.numberOfColumns ;

    if (idx < 0) idx = count + 1 + idx ;
    idx-- ;
    if (idx < 0 || idx >= count) {
        lua_pushnil(L) ;
    } else {
        NSView *view = [row viewAtColumn:idx] ;
        [skin pushNSObject:view] ;
    }
    return 1 ;
}

static int tableRow_selectionHighlightStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableRowView *row = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, (row.selectionHighlightStyle == NSTableViewSelectionHighlightStyleRegular)) ;
    } else {
        row.selectionHighlightStyle = lua_toboolean(L, 2) ? NSTableViewSelectionHighlightStyleRegular
                                                          : NSTableViewSelectionHighlightStyleNone ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tableRow_backgroundColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableRowView *row = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:row.backgroundColor] ;
    } else {
        row.backgroundColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tableRow_emphasized(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableRowView *row = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, row.emphasized) ;
    } else {
        row.emphasized = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tableRow_floating(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableRowView *row = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, row.floating) ;
    } else {
        row.floating = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tableRow_groupRowStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableRowView *row = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, row.groupRowStyle) ;
    } else {
        row.groupRowStyle = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tableRow_nextRowSelected(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableRowView *row = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, row.nextRowSelected) ;
    } else {
        row.nextRowSelected = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tableRow_previousRowSelected(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableRowView *row = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, row.previousRowSelected) ;
    } else {
        row.previousRowSelected = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tableRow_selected(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableRowView *row = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, row.selected) ;
    } else {
        row.selected = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - NSTableColumn Methods -

static int tableColumn_sizeToFit(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COLUMN_TAG, LS_TBREAK] ;
    NSTableColumn *column = [skin toNSObjectAtIndex:1] ;

    [column sizeToFit] ;
    lua_pushvalue(L, 1) ;
    return 1;
}

static int tableColumn_maxWidth(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COLUMN_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableColumn *column = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, column.maxWidth) ;
    } else {
        CGFloat maxWidth = lua_tonumber(L, 2) ;
        if (maxWidth < 0.0) return luaL_argerror(L, 2, "maxWidth must be non-negative") ;
        column.maxWidth = maxWidth ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tableColumn_minWidth(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COLUMN_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableColumn *column = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, column.minWidth) ;
    } else {
        CGFloat minWidth = lua_tonumber(L, 2) ;
        if (minWidth < 0.0) return luaL_argerror(L, 2, "minWidth must be non-negative") ;
        column.minWidth = minWidth ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tableColumn_width(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COLUMN_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableColumn *column = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, column.width) ;
    } else {
        CGFloat width = lua_tonumber(L, 2) ;
        if (width < 0.0) return luaL_argerror(L, 2, "width must be non-negative") ;
        column.width = width ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tableColumn_hidden(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COLUMN_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableColumn *column = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, column.hidden) ;
    } else {
        column.hidden = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tableColumn_editable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COLUMN_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableColumn *column = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, column.editable) ;
    } else {
        column.editable = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tableColumn_headerToolTip(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COLUMN_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableColumn *column = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:column.headerToolTip] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            column.headerToolTip = nil ;
        } else {
            column.headerToolTip = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tableColumn_title(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COLUMN_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableColumn *column = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:column.title] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            column.title = @"" ;
        } else {
            column.title = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tableColumn_identifier(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COLUMN_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableColumn *column = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:column.identifier] ;
    } else {
        column.identifier = [skin toNSObjectAtIndex:2] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tableColumn_resizingMask(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COLUMN_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableColumn *column = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(column.resizingMask) ;
        NSArray  *temp   = [COLUMN_RESIZING allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized resizing type %@ -- notify developers", UD_COLUMN_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = COLUMN_RESIZING[key] ;
        if (value) {
            column.resizingMask = value.unsignedIntegerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[COLUMN_RESIZING allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int tableColumn_tableView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COLUMN_TAG, LS_TBREAK] ;
    NSTableColumn *column = [skin toNSObjectAtIndex:1] ;

    NSTableView *table = column.tableView ;

    if (table) {
        [skin pushNSObject:table] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int tableColumn_indicatorImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COLUMN_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    NSTableColumn          *column = [skin toNSObjectAtIndex:1] ;
    HSUITKElementContainerTableView *table  = (HSUITKElementContainerTableView *)column.tableView ;

    if (lua_gettop(L) == 1) {
        if (table) {
            [skin pushNSObject:[table indicatorImageInTableColumn:column]] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        [skin checkArgs:LS_TUSERDATA, UD_COLUMN_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
        NSImage *image = [skin toNSObjectAtIndex:2] ;
        if (table) {
            [table setIndicatorImage:image inTableColumn:column] ;
        } else {
            luaL_argerror(L, 1, "column not attached to a table") ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int tableColumn_moveColumn(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COLUMN_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    NSTableColumn *column = [skin toNSObjectAtIndex:1] ;
    NSInteger     destCol = lua_tointeger(L, 2) ;

    HSUITKElementContainerTableView *table  = (HSUITKElementContainerTableView *)column.tableView ;

    if (table) {
        NSInteger count = table.numberOfColumns ;
        if (destCol < 0) destCol = count + 1 + destCol ;
        if (destCol < 1 || destCol > count) {
            return luaL_argerror(L, 2, "index out of bounds") ;
        }
        NSInteger fromCol = [table columnWithIdentifier:column.identifier] ;
        [table moveColumn:fromCol toColumn:(destCol - 1)] ;
        lua_pushvalue(L, 1) ;
    } else {
        luaL_argerror(L, 1, "column not attached to a table") ;
    }
    return 1 ;
}

static int tableColumn_index(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COLUMN_TAG, LS_TBREAK] ;
    NSTableColumn *column = [skin toNSObjectAtIndex:1] ;

    HSUITKElementContainerTableView *table  = (HSUITKElementContainerTableView *)column.tableView ;

    if (table) {
        lua_pushinteger(L, [table columnWithIdentifier:column.identifier] + 1) ;
    } else {
        luaL_argerror(L, 1, "column not attached to a table") ;
    }
    return 1 ;
}

// @property(copy) NSSortDescriptor *sortDescriptorPrototype;
// @property(strong) __kindof NSTableHeaderCell *headerCell;

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementContainerTableView(lua_State *L, id obj) {
    HSUITKElementContainerTableView *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementContainerTableView *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementContainerTableView(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementContainerTableView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementContainerTableView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushNSTableColumn(lua_State *L, id obj) {
    NSTableColumn *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(NSTableColumn *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_COLUMN_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toNSTableColumn(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSTableColumn *value ;
    if (luaL_testudata(L, idx, UD_COLUMN_TAG)) {
        value = get_objectFromUserdata(__bridge NSTableColumn, L, idx, UD_COLUMN_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_COLUMN_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushNSTableRowView(lua_State *L, id obj) {
    NSTableRowView *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(NSTableRowView *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_ROW_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toNSTableRowView(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSTableRowView *value ;
    if (luaL_testudata(L, idx, UD_ROW_TAG)) {
        value = get_objectFromUserdata(__bridge NSTableRowView, L, idx, UD_ROW_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_ROW_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int table_object_tostring(lua_State *L) {
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

static int table_object_eq(lua_State *L) {
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

static int table_object_gc(lua_State *L) {
    NSObject *obj = (__bridge_transfer NSObject *)*((void**)lua_touserdata(L, 1)) ;

    if ([obj isKindOfClass:[NSTableRowView class]]) {
        NSTableRowView *view = (NSTableRowView *)obj ;
        view.selfRefCount-- ;
//         if (view.selfRefCount == 0) {
//             // probably never going to need this, but placeholder here in case that changes
//         }
    }
    if (obj) obj = nil ;

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int userdata_gc(lua_State* L) {
    HSUITKElementContainerTableView *obj = get_objectFromUserdata(__bridge_transfer HSUITKElementContainerTableView, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef    = [skin luaUnref:refTable ref:obj.callbackRef] ;
            obj.passThroughRef = [skin luaUnref:refTable ref:obj.passThroughRef] ;
            obj.dataSourceRef  = [skin luaUnref:refTable ref:obj.dataSourceRef] ;
            obj.storedHeader   = nil ;
            obj.storedCorner   = nil ;
            [obj enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, __unused NSInteger row) {
                for (NSInteger i = 0 ; i < rowView.numberOfColumns ; i++) {
                    NSView *view = [rowView viewAtColumn:i] ;
                    if (view) [skin luaRelease:refTable forNSObject:view] ;
                }
            }] ;
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
    {"passthroughCallback",        table_passthroughCallback},
    {"dataSourceCallback",         table_dataSourceCallback},
    {"columnReordering",           table_allowsColumnReordering},
    {"columnResizing",             table_allowsColumnResizing},
    {"columnSelection",            table_allowsColumnSelection},
    {"allowEmptySelection",        table_allowsEmptySelection},
    {"allowMultipleSelection",     table_allowsMultipleSelection},
    {"allowTypeSelect",            table_allowsTypeSelect},
    {"autosaveTableColumns",       table_autosaveTableColumns},
    {"alternatingRowBgColors",     table_usesAlternatingRowBackgroundColors},
    {"usesAutomaticRowHeights",    table_usesAutomaticRowHeights},
    {"verticalMotionCanBeginDrag", table_verticalMotionCanBeginDrag},
    {"rowHeight",                  table_rowHeight},
    {"autosaveName",               table_autosaveName},
    {"backgroundColor",            table_backgroundColor},
    {"gridColor",                  table_gridColor},
    {"intercellSpacing",           table_intercellSpacing},
    {"columnAutosizing",           table_columnAutoresizingStyle},
    {"gridStyle",                  table_gridStyleMask},
    {"rowSize",                    table_rowSizeStyle},
    {"highlightSelection",         table_selectionHighlightStyle},
    {"style",                      table_style},
    {"layoutDirection",            table_userInterfaceLayoutDirection},
    {"showHeader",                 table_showHeader},
    {"selectedColumns",            table_selectedColumns},
    {"selectedRows",               table_selectedRows},

    {"rows",                       table_rows},
    {"columns",                    table_columns},
    {"addColumn",                  table_addTableColumn},
    {"removeColumn",               table_removeTableColumn},
    {"column",                     table_columnWithIdentifier},
    {"tableColumns",               table_tableColumns},
    {"cell",                       table_viewAtRowColumn},
    {"reloadData",                 table_reloadData},
    {"hiddenRows",                 table_hiddenRows},
    {"hideRow",                    table_hideRow},
    {"scrollToRow",                table_scrollToRow},
    {"scrollToColumn",             table_scrollToColumn},
    {"selectAll",                  table_selectAll},
    {"elementRow",                 table_rowForElement},
    {"elementColumn",              table_columnForElement},
    {"sizeToFit",                  table_sizeToFit},
    {"isColumnSelected",           table_isColumnSelected},
    {"isRowSelected",              table_isRowSelected},
    {"row",                        table_rowViewAtRow},

// other metamethods inherited from _control and _view
    {"__gc",                       userdata_gc},
    {NULL,                         NULL}
};

static const luaL_Reg ud_row_metaLib[] = {
    {"selectionHighlightStyle", tableRow_selectionHighlightStyle},
    {"backgroundColor",         tableRow_backgroundColor},
    {"emphasized",              tableRow_emphasized},
    {"floating",                tableRow_floating},
    {"groupRowStyle",           tableRow_groupRowStyle},
    {"nextRowSelected",         tableRow_nextRowSelected},
    {"previousRowSelected",     tableRow_previousRowSelected},
    {"selected",                tableRow_selected},

    {"cell",                    tableRow_viewAtColumn},

    {"__tostring",              table_object_tostring},
    {"__eq",                    table_object_eq},
    {"__gc",                    table_object_gc},
    {NULL,                      NULL}
} ;

static const luaL_Reg ud_column_metaLib[] = {
    {"maxWidth",       tableColumn_maxWidth},
    {"minWidth",       tableColumn_minWidth},
    {"width",          tableColumn_width},
    {"hide",           tableColumn_hidden},
    {"editable",       tableColumn_editable},
    {"headerToolTip",  tableColumn_headerToolTip},
    {"title",          tableColumn_title},
    {"identifier",     tableColumn_identifier},
    {"resizingStyle",  tableColumn_resizingMask},

    {"sizeToFit",      tableColumn_sizeToFit},
    {"table",          tableColumn_tableView},
    {"indicatorImage", tableColumn_indicatorImage},
    {"moveTo",         tableColumn_moveColumn},
    {"index",          tableColumn_index},

    {"__tostring",     table_object_tostring},
    {"__eq",           table_object_eq},
    {"__gc",           table_object_gc},
    {NULL,             NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",       table_new},
    {"newColumn", table_newColumn},

    {NULL,        NULL}
};

int luaopen_hs__asm_uitk_element_libcontainer_table(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    [skin registerObject:UD_ROW_TAG    objectFunctions:ud_row_metaLib] ;
    [skin registerObject:UD_COLUMN_TAG objectFunctions:ud_column_metaLib] ;

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKElementContainerTableView  forClass:"HSUITKElementContainerTableView"];
    [skin registerLuaObjectHelper:toHSUITKElementContainerTableView forClass:"HSUITKElementContainerTableView"
                                                         withUserdataMapping:USERDATA_TAG];

    [skin registerPushNSHelper:pushNSTableRowView  forClass:"NSTableRowView"];
    [skin registerLuaObjectHelper:toNSTableRowView forClass:"NSTableRowView"
                                        withUserdataMapping:UD_ROW_TAG];

    [skin registerPushNSHelper:pushNSTableColumn  forClass:"NSTableColumn"];
    [skin registerLuaObjectHelper:toNSTableColumn forClass:"NSTableColumn"
                                       withUserdataMapping:UD_COLUMN_TAG];

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"passthroughCallback",
        @"dataSourceCallback",
        @"columnReordering",
        @"columnResizing",
        @"columnSelection",
        @"allowEmptySelection",
        @"allowMultipleSelection",
        @"allowTypeSelect",
        @"autosaveTableColumns",
        @"alternatingRowBgColors",
        @"usesAutomaticRowHeights",
        @"verticalMotionCanBeginDrag",
        @"rowHeight",
        @"autosaveName",
        @"backgroundColor",
        @"gridColor",
        @"intercellSpacing",
        @"columnAutosizing",
        @"gridStyle",
        @"rowSize",
        @"highlightSelection",
        @"style",
        @"layoutDirection",
        @"showHeader",
        @"selectedRows",
        @"selectedColumns",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    luaL_getmetatable(L, UD_ROW_TAG) ;
    [skin pushNSObject:@[
        @"selectionHighlightStyle",
        @"backgroundColor",
        @"emphasized",
        @"floating",
        @"groupRowStyle",
        @"nextRowSelected",
        @"previousRowSelected",
        @"selected",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    luaL_getmetatable(L, UD_COLUMN_TAG) ;
    [skin pushNSObject:@[
        @"maxWidth",
        @"minWidth",
        @"width",
        @"hide",
        @"editable",
        @"headerToolTip",
        @"title",
        @"identifier",
        @"resizingStyle",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
