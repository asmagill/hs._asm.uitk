@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element" ;
static LSRefTable         refTable     = LUA_NOREF ;

#pragma mark - Support Functions and Classes -

BOOL oneOfOurElementObjects(NSView *obj) {
    return [obj isKindOfClass:[NSView class]]  &&
           [obj respondsToSelector:NSSelectorFromString(@"selfRefCount")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setSelfRefCount:")] &&
           [obj respondsToSelector:NSSelectorFromString(@"refTable")] &&
           [obj respondsToSelector:NSSelectorFromString(@"callbackRef")] &&
           [obj respondsToSelector:NSSelectorFromString(@"setCallbackRef:")] ;
}

#pragma mark - Module Functions -

static int element_isElementType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TANY, LS_TBREAK] ;

    if (lua_type(L, 1) == LUA_TUSERDATA) {
        NSView *view = [skin toNSObjectAtIndex:1] ;
        lua_pushboolean(L, oneOfOurElementObjects(view)) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"isElementType", element_isElementType},
    {NULL,            NULL}
};

int luaopen_hs__asm_uitk_libelement(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    refTable = [skin registerLibrary:USERDATA_TAG
                           functions:moduleLib
                       metaFunctions:nil] ; // or module_metaLib

    return 1;
}
