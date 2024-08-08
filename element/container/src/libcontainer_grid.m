@import Cocoa ;
@import LuaSkin ;

// for our purposes this is 1/1000 of a screen point; small enough that it can't be seen so effectively 0
#define FLOAT_EQUIVALENT_TO_ZERO 0.001

static const char * const USERDATA_TAG = "hs._asm.uitk.element.container.grid" ;
static const char * const UD_ROW_TAG   = "hs._asm.uitk.element.container.grid.row" ;
static const char * const UD_COL_TAG   = "hs._asm.uitk.element.container.grid.column" ;
static const char * const UD_CELL_TAG  = "hs._asm.uitk.element.container.grid.cell" ;

static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *GRID_ROW_ALIGNMENT ;
static NSDictionary *GRID_CELL_PLACEMENT ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    GRID_ROW_ALIGNMENT = @{
        @"firstBaseline" : @(NSGridRowAlignmentFirstBaseline),
        @"inherited"     : @(NSGridRowAlignmentInherited),
        @"lastBaseline"  : @(NSGridRowAlignmentLastBaseline),
        @"none"          : @(NSGridRowAlignmentNone),
    } ;

    GRID_CELL_PLACEMENT = @{
        @"center"    : @(NSGridCellPlacementCenter),
        @"fill"      : @(NSGridCellPlacementFill),
        @"inherited" : @(NSGridCellPlacementInherited),
        @"leading"   : @(NSGridCellPlacementLeading),
        @"none"      : @(NSGridCellPlacementNone),
        @"trailing"  : @(NSGridCellPlacementTrailing),
    } ;
}

@interface HSUITKElementContainerGridView : NSGridView
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ; // in this case, it's the passthrough callback for subviews
                                              // with no callbacks, but we keep the name since this is
                                              // checked in _view for the common methods
@end

static BOOL oneOfOurs(NSView *obj) {
    return [obj isKindOfClass:[NSView class]]  &&
           [obj respondsToSelector:NSSelectorFromString(@"selfRefCount")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setSelfRefCount:")] &&
           [obj respondsToSelector:NSSelectorFromString(@"refTable")] &&
           [obj respondsToSelector:NSSelectorFromString(@"callbackRef")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setCallbackRef:")] ;
}

static NSGridView *getParentGridFromCell(NSGridCell *cell) {
    NSGridRow    *row = cell.row ;
    NSGridColumn *col = cell.column ;
    NSGridView   *rGrid = (row) ? row.gridView : nil ;
    NSGridView   *cGrid = (col) ? col.gridView : nil ;

    return (row && col && rGrid == cGrid) ? rGrid : nil ;
}

static NSArray *makeGridElementArray(NSArray *array) {
    NSMutableArray *newArray = [array isKindOfClass:[NSArray class]] ? [NSMutableArray arrayWithCapacity:array.count] : nil ;

    if (newArray) {
        BOOL isGood = YES ;
        for (NSView *view in array) {
            if (([view isKindOfClass:[NSNumber class]] && !((NSNumber *)view).boolValue) || [view isKindOfClass:[NSNull class]]) {
                [newArray addObject:NSGridCell.emptyContentView] ;
            } else {
                isGood = oneOfOurs(view) ;
                if (isGood) {
                    [newArray addObject:view] ;
                } else {
                    [LuaSkin logInfo:[NSString stringWithFormat:@"%s - validating gridElementArray, found, expected uitk element, nil, or false; found: %@", USERDATA_TAG, view]] ;
                    break ;
                }
            }
        }
        if (!isGood) newArray = nil ;
    } else {
        [LuaSkin logInfo:[NSString stringWithFormat:@"%s - validating gridElementArray - expected array, found: %@", USERDATA_TAG, array]] ;
    }

    return newArray ;
}

static void retainGridElementArray(lua_State *L, NSArray *array) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    for (NSView *obj in array) {
        if ([obj isKindOfClass:[NSArray class]]) {
            retainGridElementArray(L, (NSArray *)obj) ;
        } else if (![obj isEqualTo:NSGridCell.emptyContentView]) {
            [skin luaRetain:refTable forNSObject:obj] ;
        }
    }
}

@implementation HSUITKElementContainerGridView
- (void)commonInit {
    _callbackRef    = LUA_NOREF ;
    _refTable       = refTable ;
    _selfRefCount   = 0 ;
}

+ (instancetype)gridWithRows:(NSArray<NSArray<NSView *> *> *)rows {
    HSUITKElementContainerGridView *grid = [HSUITKElementContainerGridView gridViewWithViews:rows] ;

    if (grid) [grid commonInit] ;

    return grid ;
}

+ (instancetype)gridWithColumns:(NSInteger)columnCount andRows:(NSInteger)rowCount {
    HSUITKElementContainerGridView *grid = [HSUITKElementContainerGridView gridViewWithNumberOfColumns:columnCount
                                                                                  rows:rowCount] ;

    if (grid) [grid commonInit] ;

    return grid ;
}

// - (void)dealloc {
// }

// Follow the Hammerspoon convention
- (BOOL)isFlipped { return YES; }

// NOTE: Passthrough Callback Support

// allow next responder a chance since we don't have a callback set
- (void)passCallbackUpWith:(NSArray *)arguments {
    NSResponder *nextInChain = [self nextResponder] ;

    SEL passthroughCallback = NSSelectorFromString(@"performPassthroughCallback:") ;
    while(nextInChain) {
        if ([nextInChain respondsToSelector:passthroughCallback]) {
            [nextInChain performSelectorOnMainThread:passthroughCallback
                                          withObject:arguments
                                       waitUntilDone:YES] ;
            break ;
        } else {
            nextInChain = nextInChain.nextResponder ;
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

/// hs._asm.uitk.element.container.grid.new(rows, columns) -> gridObject
/// Constructor
/// Creates a new grid container element for `hs._asm.uitk.window` with the specified number of columns and rows.
///
/// Parameters:
///  * `rows`    - an integer greater than 0 specifying the number of rows in the grid
///  * `columns` - an integer greater than 0 specifying the number of columns in the grid
///
/// Returns:
///  * the gridObject
static int grid_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementContainerGridView *grid = nil ;

    if (lua_type(L, 1) == LUA_TTABLE) {
        [skin checkArgs:LS_TTABLE, LS_TBREAK] ;

        NSArray *rows = [skin toNSObjectAtIndex:1] ;
        if ([rows isKindOfClass:[NSArray class]]) {
            NSMutableArray *newRows = [NSMutableArray arrayWithCapacity:rows.count] ;
            for (NSArray *oneRow in rows) {
                NSArray *adjustedRow = makeGridElementArray(oneRow) ;
                if (adjustedRow) {
                    [newRows addObject:adjustedRow] ;
                } else {
                    rows = nil ;
                    break ;
                }
            }

            if (rows) {
                grid = [HSUITKElementContainerGridView gridWithRows:newRows] ;
                retainGridElementArray(L, newRows) ;
            } else {
                return luaL_argerror(L, 1, "all rows must contain only uitk elements, nil, or false") ;
            }
        } else {
            return luaL_argerror(L, 1, "expected an array of rows") ;
        }
    } else {
        [skin checkArgs:LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;

        NSInteger rows    = lua_tointeger(L, 1) ;
        NSInteger columns = lua_tointeger(L, 2) ;

        if (columns < 1) return luaL_argerror(L, 1, "number of columns must be greater than 0") ;
        if (rows < 1) return luaL_argerror(L, 2, "number of rows must be greater than 0") ;

        grid = [HSUITKElementContainerGridView gridWithColumns:columns andRows:rows] ;
    }

    if (grid) {
        [grid setFrameSize:[grid fittingSize]] ;
        [skin pushNSObject:grid] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

/// hs._asm.uitk.element.container.grid:passthroughCallback([fn | nil]) -> containerObject | fn | nil
/// Method
/// Get or set the pass through callback for the container.
///
/// Parameters:
///  * `fn` - a function, or an explicit nil to remove, specifying the callback to invoke for elements which do not have their own callbacks assigned.
///
/// Returns:
///  * If an argument is provided, the container object; otherwise the current value.
///
/// Notes:
///  * The pass through callback should expect one or two arguments and return none.
///
///  * The pass through callback is designed so that elements which trigger a callback based on user interaction which do not have a specifically assigned callback can still report user interaction through a common fallback.
///  * The arguments received by the pass through callback will be organized as follows:
///    * the container userdata object
///    * a table containing the arguments provided by the elements callback itself, usually the element userdata followed by any additional arguments as defined for the element's callback function.
///
///  * Note that elements which have a callback that returns a response cannot use this common pass through callback method; in such cases a specific callback must be assigned to the element directly as described in the element's documentation.
static int grid_passthroughCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerGridView *grid = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        grid.callbackRef = [skin luaUnref:refTable ref:grid.callbackRef] ;
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2) ;
            grid.callbackRef = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (grid.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:grid.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int grid_cellForView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY, LS_TBREAK] ;
    HSUITKElementContainerGridView *grid = [skin toNSObjectAtIndex:1] ;

    NSView *view = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
    if (view && oneOfOurs(view)) {
        NSGridCell *cell = [grid cellForView:view] ;
        if (cell) {
            [skin pushNSObject:cell] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
    }
    return 1 ;
}

static int grid_columnAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKElementContainerGridView *grid = [skin toNSObjectAtIndex:1] ;

    NSInteger idx   = lua_tointeger(L, 2) ;
    NSInteger count = grid.numberOfColumns ;

    if (idx < 0) idx = count + 1 + idx ;
    idx-- ;
    if (idx < 0 || idx >= count) {
        lua_pushnil(L) ;
    } else {
        [skin pushNSObject:[grid columnAtIndex:idx]] ;
    }
    return 1 ;
}

static int grid_rowAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKElementContainerGridView *grid = [skin toNSObjectAtIndex:1] ;

    NSInteger idx   = lua_tointeger(L, 2) ;
    NSInteger count = grid.numberOfRows ;

    if (idx < 0) idx = count + 1 + idx ;
    idx-- ;
    if (idx < 0 || idx >= count) {
        lua_pushnil(L) ;
    } else {
        [skin pushNSObject:[grid rowAtIndex:idx]] ;
    }
    return 1 ;
}

static int grid_cellAtRowColIndicies(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKElementContainerGridView *grid = [skin toNSObjectAtIndex:1] ;

    NSInteger row    = lua_tointeger(L, 2) ;
    NSInteger rCount = grid.numberOfRows ;

    if (row < 0) row = rCount + 1 + row ;
    row-- ;

    NSInteger col    = lua_tointeger(L, 3) ;
    NSInteger cCount = grid.numberOfColumns ;

    if (col < 0) col = cCount + 1 + col ;
    col-- ;

    if (row < 0 || row >= rCount || col < 0 || col >= cCount) {
        lua_pushnil(L) ;
    } else {
        [skin pushNSObject:[grid cellAtColumnIndex:col rowIndex:row]] ;
    }
    return 1 ;
}

static int grid_columnCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementContainerGridView *grid = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, grid.numberOfColumns) ;
    return 1 ;
}

static int grid_rowCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerGridView *grid = [skin toNSObjectAtIndex:1] ;

    lua_pushinteger(L, grid.numberOfRows) ;
    return 1 ;
}

static int grid_columnSpacing(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerGridView *grid = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if (fabs(NSGridViewSizeForContent - grid.columnSpacing) < FLOAT_EQUIVALENT_TO_ZERO) {
            lua_pushnil(L) ;
        } else {
            lua_pushnumber(L, grid.columnSpacing) ;
        }
    } else {
        CGFloat spacing = (lua_type(L, 2) == LUA_TNUMBER) ? lua_tonumber(L, 2)
                                                          : NSGridViewSizeForContent ;
        grid.columnSpacing = spacing ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int grid_rowSpacing(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerGridView *grid = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if (fabs(NSGridViewSizeForContent - grid.rowSpacing) < FLOAT_EQUIVALENT_TO_ZERO) {
            lua_pushnil(L) ;
        } else {
            lua_pushnumber(L, grid.rowSpacing) ;
        }
    } else {
        CGFloat spacing = (lua_type(L, 2) == LUA_TNUMBER) ? lua_tonumber(L, 2)
                                                          : NSGridViewSizeForContent ;
        grid.rowSpacing = spacing ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int grid_rowAlignment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerGridView *grid = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(grid.rowAlignment) ;
        NSArray  *temp   = [GRID_ROW_ALIGNMENT allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized alignment type %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = GRID_ROW_ALIGNMENT[key] ;
        if (value) {
            grid.rowAlignment = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [GRID_ROW_ALIGNMENT.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int grid_xPlacement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerGridView *grid = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(grid.xPlacement) ;
        NSArray  *temp   = [GRID_CELL_PLACEMENT allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized placement type %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = GRID_CELL_PLACEMENT[key] ;
        if (value) {
            grid.xPlacement = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [GRID_CELL_PLACEMENT.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int grid_yPlacement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementContainerGridView *grid = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(grid.yPlacement) ;
        NSArray  *temp   = [GRID_CELL_PLACEMENT allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized placement type %@ -- notify developers", USERDATA_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = GRID_CELL_PLACEMENT[key] ;
        if (value) {
            grid.yPlacement = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [GRID_CELL_PLACEMENT.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int grid_insertRow(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementContainerGridView *grid = [skin toNSObjectAtIndex:1] ;

    NSInteger idx     = -1 ;
    NSArray   *newRow = [NSArray array] ;

    switch(lua_gettop(L)) {
        case 2:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                            LS_TNUMBER | LS_TINTEGER | LS_TTABLE,
                            LS_TBREAK] ;
            if (lua_type(L, 2) == LUA_TNUMBER) {
                idx = lua_tointeger(L, 2) ;
            } else {
                newRow = [skin toNSObjectAtIndex:2] ;
            }
            break ;
        case 3:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                            LS_TNUMBER | LS_TINTEGER,
                            LS_TTABLE,
                            LS_TBREAK] ;
            idx    = lua_tointeger(L, 3) ;
            newRow = [skin toNSObjectAtIndex:3] ;
            break ;
    }

    NSInteger count = grid.numberOfRows ;
    if (idx < 0) idx = count + 1 + idx ;
    idx-- ;
    if (idx < 0 || idx > count) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }

    newRow = makeGridElementArray(newRow) ;
    if (newRow) {
        if (idx == count) {
            [grid addColumnWithViews:newRow] ;
        } else {
            [grid insertColumnAtIndex:idx withViews:newRow] ;
        }
        retainGridElementArray(L, newRow) ;
    } else {
        return luaL_argerror(L, lua_gettop(L), "array must contain only uitk elements, nil, or false") ;
    }

    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int grid_removeRow(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKElementContainerGridView *grid = [skin toNSObjectAtIndex:1] ;

    NSInteger idx   = lua_tointeger(L, 2) ;
    NSInteger count = grid.numberOfRows ;
    if (idx < 0) idx = count + 1 + idx ;
    idx-- ;
    if (idx < 0 || idx >= count) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }

    [grid removeRowAtIndex:idx] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int grid_insertColumn(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementContainerGridView *grid = [skin toNSObjectAtIndex:1] ;

    NSInteger idx     = -1 ;
    NSArray   *newCol = [NSArray array] ;

    switch(lua_gettop(L)) {
        case 2:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                            LS_TNUMBER | LS_TINTEGER | LS_TTABLE,
                            LS_TBREAK] ;
            if (lua_type(L, 2) == LUA_TNUMBER) {
                idx = lua_tointeger(L, 2) ;
            } else {
                newCol = [skin toNSObjectAtIndex:2] ;
            }
            break ;
        case 3:
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                            LS_TNUMBER | LS_TINTEGER,
                            LS_TTABLE,
                            LS_TBREAK] ;
            idx = lua_tointeger(L, 3) ;
            newCol = [skin toNSObjectAtIndex:3] ;
            break ;
    }

    NSInteger count = grid.numberOfColumns ;
    if (idx < 0) idx = count + 1 + idx ;
    idx-- ;
    if (idx < 0 || idx > count) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }

    newCol = makeGridElementArray(newCol) ;
    if (newCol) {
        if (idx == count) {
            [grid addColumnWithViews:newCol] ;
        } else {
            [grid insertColumnAtIndex:idx withViews:newCol] ;
        }
        retainGridElementArray(L, newCol) ;
    } else {
        return luaL_argerror(L, lua_gettop(L), "array must contain only uitk elements, nil, or false") ;
    }

    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int grid_removeColumn(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;
    HSUITKElementContainerGridView *grid = [skin toNSObjectAtIndex:1] ;

    NSInteger idx   = lua_tointeger(L, 2) ;
    NSInteger count = grid.numberOfColumns ;
    if (idx < 0) idx = count + 1 + idx ;
    idx-- ;
    if (idx < 0 || idx >= count) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }

    [grid removeColumnAtIndex:idx] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

// TODO - (void)mergeCellsInHorizontalRange:(NSRange)hRange verticalRange:(NSRange)vRange;

#pragma mark - NSGridRow Methods -

static int gridRow_index(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridRow *row = [skin toNSObjectAtIndex:1] ;
    NSGridView *grid = row.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_ROW_TAG]] ;
    }

    if (lua_gettop(L) == 1) {
        if (grid) {
            lua_pushinteger(L, [grid indexOfRow:row] + 1) ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (grid) {
            NSInteger idx   = lua_tointeger(L, 2) ;
            NSInteger count = grid.numberOfRows ;

            if (idx < 0) idx = count + 1 + idx ;
            idx-- ;

            if (idx < 0 || idx >= count) {
                return luaL_error(L, "index out of bounds") ;
            } else {
                [grid moveRowAtIndex:[grid indexOfRow:row] toIndex:idx] ;
                lua_pushvalue(L, 1) ;
            }
        } else {
            return luaL_argerror(L, 2, "row is not a member of a grid") ;
        }
    }

    return 1 ;
}

static int gridRow_hidden(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridRow *row = [skin toNSObjectAtIndex:1] ;
    NSGridView *grid = row.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_ROW_TAG]] ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, row.hidden) ;
    } else {
        row.hidden = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gridRow_count(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridRow *row = [skin toNSObjectAtIndex:1] ;
    NSGridView *grid = row.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_ROW_TAG]] ;
    }

    lua_pushinteger(L, row.numberOfCells) ;
    return 1 ;
}

static int gridRow_topPadding(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridRow *row = [skin toNSObjectAtIndex:1] ;
    NSGridView *grid = row.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_ROW_TAG]] ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, row.topPadding) ;
    } else {
        row.topPadding = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gridRow_bottomPadding(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridRow *row = [skin toNSObjectAtIndex:1] ;
    NSGridView *grid = row.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_ROW_TAG]] ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, row.bottomPadding) ;
    } else {
        row.bottomPadding = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gridRow_height(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridRow *row = [skin toNSObjectAtIndex:1] ;
    NSGridView *grid = row.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_ROW_TAG]] ;
    }

    if (lua_gettop(L) == 1) {
        if (fabs(NSGridViewSizeForContent - row.height) < FLOAT_EQUIVALENT_TO_ZERO) {
            lua_pushnil(L) ;
        } else {
            lua_pushnumber(L, row.height) ;
        }
    } else {
        CGFloat height = (lua_type(L, 2) == LUA_TNUMBER) ? lua_tonumber(L, 2)
                                                         : NSGridViewSizeForContent ;
        row.height = height ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gridRow_yPlacement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridRow  *row  = [skin toNSObjectAtIndex:1] ;
    NSGridView *grid = row.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_ROW_TAG]] ;
    }

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(row.yPlacement) ;
        NSArray  *temp   = [GRID_CELL_PLACEMENT allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized placement type %@ -- notify developers", UD_ROW_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = GRID_CELL_PLACEMENT[key] ;
        if (value) {
            row.yPlacement = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [GRID_CELL_PLACEMENT.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int gridRow_alignment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridRow  *row  = [skin toNSObjectAtIndex:1] ;
    NSGridView *grid = row.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_ROW_TAG]] ;
    }

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(row.rowAlignment) ;
        NSArray  *temp   = [GRID_ROW_ALIGNMENT allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized alignment type %@ -- notify developers", UD_ROW_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = GRID_ROW_ALIGNMENT[key] ;
        if (value) {
            row.rowAlignment = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [GRID_ROW_ALIGNMENT.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int gridRow_cellAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;

    NSGridRow  *row  = [skin toNSObjectAtIndex:1] ;
    NSGridView *grid = row.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_ROW_TAG]] ;
    }

    NSInteger idx   = lua_tointeger(L, 2) ;
    NSInteger count = row.numberOfCells ;

    if (idx < 0) idx = count + 1 + idx ;
    idx-- ;
    if (idx < 0 || idx >= count) {
        lua_pushnil(L) ;
    } else {
        [skin pushNSObject:[row cellAtIndex:idx]] ;
    }

    return 1 ;
}

static int gridRow_mergeCells(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;

    NSGridRow  *row  = [skin toNSObjectAtIndex:1] ;
    NSGridView *grid = row.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_ROW_TAG]] ;
    }

    NSInteger i     = lua_tointeger(L, 2) ;
    NSInteger j     = lua_tointeger(L, 3) ;
    NSInteger count = row.numberOfCells ;

    if (i < 0) i = count + 1 + i ;
    i-- ;

    if (j < 0) j = count + 1 + j ;
    j-- ;

    if (i < 0 || i >= count) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }
    if (j < 0 || j >= count) {
        return luaL_argerror(L, 3, "index out of bounds") ;
    }
    if (i >= j) {
        return luaL_argerror(L, 3, "starting index must be less than ending index") ;
    }

    [row mergeCellsInRange:NSMakeRange((NSUInteger)i, (NSUInteger)(j - i + 1))] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int gridRow_gridView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_ROW_TAG, LS_TBREAK] ;
    NSGridRow  *row  = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:row.gridView] ;
    return 1 ;
}

#pragma mark - NSGridColumn Methods -

static int gridCol_index(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COL_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridColumn *col  = [skin toNSObjectAtIndex:1] ;
    NSGridView   *grid = col.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_COL_TAG]] ;
    }

    if (lua_gettop(L) == 1) {
        if (grid) {
            lua_pushinteger(L, [grid indexOfColumn:col] + 1) ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (grid) {
            NSInteger idx   = lua_tointeger(L, 2) ;
            NSInteger count = grid.numberOfColumns ;

            if (idx < 0) idx = count + 1 + idx ;
            idx-- ;

            if (idx < 0 || idx >= count) {
                return luaL_error(L, "index out of bounds") ;
            } else {
                [grid moveRowAtIndex:[grid indexOfColumn:col] toIndex:idx] ;
                lua_pushvalue(L, 1) ;
            }
        } else {
            return luaL_argerror(L, 2, "row is not a member of a grid") ;
        }
    }

    return 1 ;
}

static int gridCol_hidden(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COL_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridColumn *col = [skin toNSObjectAtIndex:1] ;
    NSGridView *grid = col.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_COL_TAG]] ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, col.hidden) ;
    } else {
        col.hidden = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gridCol_count(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COL_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridColumn *col  = [skin toNSObjectAtIndex:1] ;
    NSGridView   *grid = col.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_COL_TAG]] ;
    }

    lua_pushinteger(L, col.numberOfCells) ;
    return 1 ;
}

static int gridCol_leadingPadding(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COL_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridColumn *col  = [skin toNSObjectAtIndex:1] ;
    NSGridView   *grid = col.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_COL_TAG]] ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, col.leadingPadding) ;
    } else {
        col.leadingPadding = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gridCol_trailingPadding(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COL_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridColumn *col  = [skin toNSObjectAtIndex:1] ;
    NSGridView   *grid = col.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_COL_TAG]] ;
    }

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, col.trailingPadding) ;
    } else {
        col.trailingPadding = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gridCol_width(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COL_TAG, LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridColumn *col  = [skin toNSObjectAtIndex:1] ;
    NSGridView   *grid = col.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_COL_TAG]] ;
    }

    if (lua_gettop(L) == 1) {
        if (fabs(NSGridViewSizeForContent - col.width) < FLOAT_EQUIVALENT_TO_ZERO) {
            lua_pushnil(L) ;
        } else {
            lua_pushnumber(L, col.width) ;
        }
    } else {
        CGFloat width = (lua_type(L, 2) == LUA_TNUMBER) ? lua_tonumber(L, 2)
                                                        : NSGridViewSizeForContent ;
        col.width = width ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gridCol_xPlacement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COL_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridColumn *col  = [skin toNSObjectAtIndex:1] ;
    NSGridView   *grid = col.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_COL_TAG]] ;
    }

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(col.xPlacement) ;
        NSArray  *temp   = [GRID_CELL_PLACEMENT allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized placement type %@ -- notify developers", UD_COL_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = GRID_CELL_PLACEMENT[key] ;
        if (value) {
            col.xPlacement = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [GRID_CELL_PLACEMENT.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int gridCol_cellAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COL_TAG, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;

    NSGridColumn *col  = [skin toNSObjectAtIndex:1] ;
    NSGridView   *grid = col.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_COL_TAG]] ;
    }

    NSInteger idx   = lua_tointeger(L, 2) ;
    NSInteger count = col.numberOfCells ;

    if (idx < 0) idx = count + 1 + idx ;
    idx-- ;
    if (idx < 0 || idx >= count) {
        lua_pushnil(L) ;
    } else {
        [skin pushNSObject:[col cellAtIndex:idx]] ;
    }

    return 1 ;
}

static int gridCol_mergeCells(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COL_TAG, LS_TNUMBER | LS_TINTEGER, LS_TNUMBER | LS_TINTEGER, LS_TBREAK] ;

    NSGridColumn *col  = [skin toNSObjectAtIndex:1] ;
    NSGridView   *grid = col.gridView ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_ROW_TAG]] ;
    }

    NSInteger i     = lua_tointeger(L, 2) ;
    NSInteger j     = lua_tointeger(L, 3) ;
    NSInteger count = col.numberOfCells ;

    if (i < 0) i = count + 1 + i ;
    i-- ;

    if (j < 0) j = count + 1 + j ;
    j-- ;

    if (i < 0 || i >= count) {
        return luaL_argerror(L, 2, "index out of bounds") ;
    }
    if (j < 0 || j >= count) {
        return luaL_argerror(L, 3, "index out of bounds") ;
    }
    if (i >= j) {
        return luaL_argerror(L, 3, "starting index must be less than ending index") ;
    }

    [col mergeCellsInRange:NSMakeRange((NSUInteger)i, (NSUInteger)(j - i + 1))] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int gridCol_gridView(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_COL_TAG, LS_TBREAK] ;
    NSGridColumn *col  = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:col.gridView] ;
    return 1 ;
}

#pragma mark - NSGridCell Methods -

static int gridCell_rowElement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CELL_TAG, LS_TBREAK] ;

    NSGridCell *cell = [skin toNSObjectAtIndex:1] ;
    NSGridView *grid = getParentGridFromCell(cell) ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_CELL_TAG]] ;
        lua_pushnil(L) ;
    } else {
        NSGridRow *row = cell.row ;
        [skin pushNSObject:row] ;
    }
    return 1 ;
}

static int gridCell_colElement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CELL_TAG, LS_TBREAK] ;

    NSGridCell *cell = [skin toNSObjectAtIndex:1] ;
    NSGridView *grid = getParentGridFromCell(cell) ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_CELL_TAG]] ;
        lua_pushnil(L) ;
    } else {
        NSGridColumn *col = cell.column ;
        [skin pushNSObject:col] ;
    }
    return 1 ;
}

static int gridCell_element(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CELL_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridCell *cell = [skin toNSObjectAtIndex:1] ;
    NSGridView *grid = getParentGridFromCell(cell) ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_CELL_TAG]] ;
    }

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:cell.contentView withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        NSView *view    = (lua_type(L, 2) == LUA_TUSERDATA) ? [skin toNSObjectAtIndex:2] : nil ;
        NSView *oldView = cell.contentView ;

        if (!grid || lua_type(L, 2) == LUA_TNIL || (lua_type(L, 2) == LUA_TBOOLEAN && !lua_toboolean(L, 2))) {
            cell.contentView = nil ;
        } else if (view) {
            if (oneOfOurs(view) && ![view isDescendantOf:grid]) {
                [skin luaRetain:refTable forNSObject:view] ;
                cell.contentView = view ;
            } else if ([view isDescendantOf:grid]) {
                return luaL_argerror(L, 2, "element already managed by this grid or one of its elements") ;
            } else {
                return luaL_argerror(L, 2, "expected userdata representing a uitk element") ;
            }
        } else {
            return luaL_argerror(L, 2, "expected userdata representing a uitk element, nil, or false") ;
        }
        if (oldView) [skin luaRelease:refTable forNSObject:oldView] ;

        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int gridCell_rowAlignment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CELL_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridCell *cell = [skin toNSObjectAtIndex:1] ;
    NSGridView *grid = getParentGridFromCell(cell) ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_CELL_TAG]] ;
    }

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(cell.rowAlignment) ;
        NSArray  *temp   = [GRID_ROW_ALIGNMENT allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized alignment type %@ -- notify developers", UD_CELL_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = GRID_ROW_ALIGNMENT[key] ;
        if (value) {
            cell.rowAlignment = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [GRID_ROW_ALIGNMENT.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int gridCell_xPlacement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CELL_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridCell *cell = [skin toNSObjectAtIndex:1] ;
    NSGridView *grid = getParentGridFromCell(cell) ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_CELL_TAG]] ;
    }

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(cell.xPlacement) ;
        NSArray  *temp   = [GRID_CELL_PLACEMENT allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized placement type %@ -- notify developers", UD_CELL_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = GRID_CELL_PLACEMENT[key] ;
        if (value) {
            cell.xPlacement = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [GRID_CELL_PLACEMENT.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int gridCell_yPlacement(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, UD_CELL_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;

    NSGridCell *cell = [skin toNSObjectAtIndex:1] ;
    NSGridView *grid = getParentGridFromCell(cell) ;
    if (!grid) {
        [skin logWarn:[NSString stringWithFormat:@"%s object does not belong to a grid", UD_CELL_TAG]] ;
    }

    if (lua_gettop(L) == 1) {
        NSNumber *value  = @(cell.yPlacement) ;
        NSArray  *temp   = [GRID_CELL_PLACEMENT allKeysForObject:value] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized placement type %@ -- notify developers", UD_CELL_TAG, value]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key   = [skin toNSObjectAtIndex:2] ;
        NSNumber *value = GRID_CELL_PLACEMENT[key] ;
        if (value) {
            cell.yPlacement = value.integerValue ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [GRID_CELL_PLACEMENT.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementContainerGridView(lua_State *L, id obj) {
    HSUITKElementContainerGridView *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementContainerGridView *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementContainerGridView(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementContainerGridView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementContainerGridView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushNSGridRow(lua_State *L, id obj) {
    NSGridRow *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(NSGridRow *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_ROW_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static int pushNSGridColumn(lua_State *L, id obj) {
    NSGridColumn *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(NSGridColumn *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_COL_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static int pushNSGridCell(lua_State *L, id obj) {
    NSGridCell *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(NSGridCell *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, UD_CELL_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toNSGridRow(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSGridRow *value ;
    if (luaL_testudata(L, idx, UD_ROW_TAG)) {
        value = get_objectFromUserdata(__bridge NSGridRow, L, idx, UD_ROW_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_ROW_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static id toNSGridColumn(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSGridColumn *value ;
    if (luaL_testudata(L, idx, UD_COL_TAG)) {
        value = get_objectFromUserdata(__bridge NSGridColumn, L, idx, UD_COL_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_COL_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static id toNSGridCell(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSGridCell *value ;
    if (luaL_testudata(L, idx, UD_CELL_TAG)) {
        value = get_objectFromUserdata(__bridge NSGridCell, L, idx, UD_CELL_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", UD_CELL_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementContainerGridView *obj = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:[NSString stringWithFormat:@"%s: %ldx%ld (%p)", USERDATA_TAG, obj.numberOfRows, obj.numberOfColumns, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSUITKElementContainerGridView *obj = get_objectFromUserdata(__bridge_transfer HSUITKElementContainerGridView, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;

            for (NSInteger r = 0 ; r < obj.numberOfRows ; r++) {
                for (NSInteger c = 0 ; c < obj.numberOfColumns ; c++) {
                    NSGridCell *cell = [obj cellAtColumnIndex:c rowIndex:r] ;
                    if (cell.contentView) {
                        [skin luaRelease:refTable forNSObject:cell.contentView] ;
                        cell.contentView = nil ;
                    }
                }
            }
        }
        obj = nil ;
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int grid_object_tostring(lua_State *L) {
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

static int grid_object_eq(lua_State *L) {
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

static int grid_object_gc(lua_State *L) {
    NSObject *obj = (__bridge_transfer NSObject *)*((void**)lua_touserdata(L, 1)) ;

    if (obj) obj = nil ;

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"passthroughCallback", grid_passthroughCallback},
    {"columnSpacing",       grid_columnSpacing},
    {"rowSpacing",          grid_rowSpacing},
    {"alignment",           grid_rowAlignment},
    {"columnPlacement",     grid_xPlacement},
    {"rowPlacement",        grid_yPlacement},

    {"rows",                grid_rowCount},
    {"columns",             grid_columnCount},
    {"row",                 grid_rowAtIndex},
    {"column",              grid_columnAtIndex},
    {"cell",                grid_cellAtRowColIndicies},
    {"cellForElement",      grid_cellForView},
    {"insertRow",           grid_insertRow},
    {"removeRow",           grid_removeRow},
    {"insertColumn",        grid_insertColumn},
    {"removeColumn",        grid_removeColumn},

// other metamethods inherited from _control and _view
    {"__tostring",          userdata_tostring},
    {"__len",               grid_rowCount},
    {"__gc",                userdata_gc},
    {NULL,    NULL}
};

static const luaL_Reg ud_row_metaLib[] = {
    {"hidden",        gridRow_hidden},
    {"topPadding",    gridRow_topPadding},
    {"bottomPadding", gridRow_bottomPadding},
    {"height",        gridRow_height},
    {"placement",     gridRow_yPlacement},
    {"alignment",     gridRow_alignment},
    {"index",         gridRow_index},

    {"count",         gridRow_count},
    {"cell",          gridRow_cellAtIndex},
    {"mergeCells",    gridRow_mergeCells},
    {"grid",          gridRow_gridView},

    {"__tostring",    grid_object_tostring},
    {"__eq",          grid_object_eq},
    {"__gc",          grid_object_gc},
    {NULL,    NULL}
} ;

static const luaL_Reg ud_col_metaLib[] = {
    {"hidden",          gridCol_hidden},
    {"leadingPadding",  gridCol_leadingPadding},
    {"trailingPadding", gridCol_trailingPadding},
    {"width",           gridCol_width},
    {"placement",       gridCol_xPlacement},
    {"index",           gridCol_index},

    {"count",           gridCol_count},
    {"cell",            gridCol_cellAtIndex},
    {"mergeCells",      gridCol_mergeCells},
    {"grid",            gridCol_gridView},

    {"__tostring",      grid_object_tostring},
    {"__eq",            grid_object_eq},
    {"__gc",            grid_object_gc},
    {NULL,    NULL}
} ;

static const luaL_Reg ud_cell_metaLib[] = {
    {"element",         gridCell_element},
    {"alignment",       gridCell_rowAlignment},
    {"columnPlacement", gridCell_xPlacement},
    {"rowPlacement",    gridCell_yPlacement},

    {"row",             gridCell_rowElement},
    {"column",          gridCell_colElement},

    {"__tostring",      grid_object_tostring},
    {"__eq",            grid_object_eq},
    {"__gc",            grid_object_gc},
    {NULL,    NULL}
} ;

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",          grid_new},

    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_element_libcontainer_grid(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    [skin registerObject:UD_ROW_TAG  objectFunctions:ud_row_metaLib] ;
    [skin registerObject:UD_COL_TAG  objectFunctions:ud_col_metaLib] ;
    [skin registerObject:UD_CELL_TAG objectFunctions:ud_cell_metaLib] ;

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKElementContainerGridView  forClass:"HSUITKElementContainerGridView"];
    [skin registerLuaObjectHelper:toHSUITKElementContainerGridView forClass:"HSUITKElementContainerGridView"
                                                        withUserdataMapping:USERDATA_TAG];

    [skin registerPushNSHelper:pushNSGridRow  forClass:"NSGridRow"];
    [skin registerLuaObjectHelper:toNSGridRow forClass:"NSGridRow"
                                   withUserdataMapping:UD_ROW_TAG];

    [skin registerPushNSHelper:pushNSGridColumn  forClass:"NSGridColumn"];
    [skin registerLuaObjectHelper:toNSGridColumn forClass:"NSGridColumn"
                                      withUserdataMapping:UD_COL_TAG];

    [skin registerPushNSHelper:pushNSGridCell  forClass:"NSGridCell"];
    [skin registerLuaObjectHelper:toNSGridCell forClass:"NSGridCell"
                                    withUserdataMapping:UD_CELL_TAG];

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"passthroughCallback",
        @"columnSpacing",
        @"rowSpacing",
        @"alignment",
        @"columnPlacement",
        @"rowPlacement",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pop(L, 1) ;

    luaL_getmetatable(L, UD_ROW_TAG) ;
    [skin pushNSObject:@[
        @"index",
        @"hidden",
        @"topPadding",
        @"bottomPadding",
        @"height",
        @"placement",
        @"alignment",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    luaL_getmetatable(L, UD_COL_TAG) ;
    [skin pushNSObject:@[
        @"index",
        @"hidden",
        @"leadingPadding",
        @"trailingPadding",
        @"width",
        @"placement",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    luaL_getmetatable(L, UD_CELL_TAG) ;
    [skin pushNSObject:@[
        @"element",
        @"alignment",
        @"columnPlacement",
        @"rowPlacement",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    lua_pop(L, 1) ;

    return 1;
}
