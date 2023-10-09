@import Cocoa ;
@import LuaSkin ;
@import Quartz.ImageKit ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.image" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *IMAGE_TOOLMODES ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaryies(void) {
    IMAGE_TOOLMODES = @{
        @"none"          : IKToolModeNone,
        @"move"          : IKToolModeMove,
        @"select"        : IKToolModeSelect,
        @"selectRect"    : IKToolModeSelectRect,
        @"selectEllipse" : IKToolModeSelectEllipse,
        @"selectLasso"   : IKToolModeSelectLasso,
        @"crop"          : IKToolModeCrop,
        @"rotate"        : IKToolModeRotate,
        @"annotate"      : IKToolModeAnnotate,
    } ;
}

@interface HSUITKElementImage : IKImageView
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;
@end

@implementation HSUITKElementImage
- (instancetype)initWithFrame:(NSRect)frameRect {
    @try {
        self = [super initWithFrame:frameRect] ;
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:new - %@", USERDATA_TAG, exception.reason]] ;
        self = nil ;
    }

    if (self) {
        _selfRefCount   = 0 ;

        self.delegate   = self ;

        // unused, but the fields are how other code identifies us as a member view or control
        _callbackRef    = LUA_NOREF ;
        _refTable       = refTable ;
    }
    return self ;
}

// - (BOOL)performDragOperation:(id<NSDraggingInfo>)sender;
// - (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender;
// - (BOOL)wantsPeriodicDraggingUpdates;
// - (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender;
// - (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender;
// - (void)concludeDragOperation:(id<NSDraggingInfo>)sender;
// - (void)draggingEnded:(id<NSDraggingInfo>)sender;
// - (void)draggingExited:(id<NSDraggingInfo>)sender;
// - (void)updateDraggingItemsForDrag:(id<NSDraggingInfo>)sender;

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.image.new([frame]) -> imageObject
/// Constructor
/// Creates a new image element for `hs._asm.uitk.panel`.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the frame for the element.
///
/// Returns:
///  * the imageObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a manager or to a `hs._asm.uitk.panel` window.
static int image_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementImage *element = [[HSUITKElementImage alloc] initWithFrame:frameRect];
    if (element) {
        if (lua_gettop(L) != 1) [element setFrameSize:[element fittingSize]] ;
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

static int image_autohidesScrollers(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        element.autohidesScrollers = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, element.autohidesScrollers) ;
    }
    return 1;
}

static int image_autoresizes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        element.autoresizes = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, element.autoresizes) ;
    }
    return 1;
}

static int image_editable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        element.editable = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, element.editable) ;
    }
    return 1;
}

static int image_hasHorizontalScroller(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        element.hasHorizontalScroller = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, element.hasHorizontalScroller) ;
    }
    return 1;
}

static int image_hasVerticalScroller(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        element.hasVerticalScroller = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, element.hasVerticalScroller) ;
    }
    return 1;
}

static int image_supportsDragAndDrop(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        element.supportsDragAndDrop = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, element.supportsDragAndDrop) ;
    }
    return 1;
}

static int image_rotationAngle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        element.rotationAngle = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnumber(L, element.rotationAngle) ;
    }
    return 1;
}

static int image_zoomFactor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 2) {
        element.zoomFactor = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnumber(L, element.zoomFactor) ;
    }
    return 1;
}

static int image_backgroundColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:element.backgroundColor] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            element.backgroundColor = nil ;
        } else {
            element.backgroundColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int image_zoomIn(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;

    [element zoomIn:element] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int image_zoomOut(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;

    [element zoomOut:element] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int image_zoomImageToActualSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;

    [element zoomImageToActualSize:element] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int image_zoomImageToFit(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;

    [element zoomImageToFit:element] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int image_flipImageHorizontal(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;

    [element flipImageHorizontal:element] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int image_flipImageVertical(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;

    [element flipImageVertical:element] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int image_rotateImageLeft(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;

    [element rotateImageLeft:element] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int image_rotateImageRight(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;

    [element rotateImageRight:element] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int image_size(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;

    [skin pushNSSize:[element imageSize]] ;
    return 1 ;
}

static int image_metadata(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;

    [skin pushNSObject:[element imageProperties] withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

static int image_imageFromURL(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;
    NSString            *path    = [skin toNSObjectAtIndex:2] ;
    BOOL                fileURL  = !([path hasPrefix:@"http:"] || [path hasPrefix:@"https:"]) ;
    NSURL               *url     = nil ;

    if (lua_gettop(L) == 3) fileURL = !((BOOL)(lua_toboolean(L, 3))) ;
    if (fileURL) {
        path = [[path componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]
                                  componentsJoinedByString:@""] ;
        path = [path stringByStandardizingPath] ;
        url = [NSURL fileURLWithPath:path isDirectory:NO] ;
    } else {
        url = [NSURL URLWithString:path] ;
    }

    [element setImageWithURL:url] ;
    [element zoomImageToFit:element] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int image_imageFromNSImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSImage *image = [[NSImage alloc] initWithCGImage:element.image size:NSZeroSize] ;
        [skin pushNSObject:image] ;
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
        NSImage *image = [skin toNSObjectAtIndex:2] ;
        CGImageRef CGImage = [image CGImageForProposedRect:NULL context:nil hints:nil] ;
        [element setImage:CGImage imageProperties:nil] ;
        [element zoomImageToFit:element] ;
        CFRelease(CGImage) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// - (void)scrollToPoint:(NSPoint)point;
// - (void)scrollToRect:(NSRect)rect;
// - (void)zoomImageToRect:(NSRect)rect;
// - (void)setImageZoomFactor:(CGFloat)zoomFactor centerPoint:(NSPoint)centerPoint;
// - (void)setRotationAngle:(CGFloat)rotationAngle centerPoint:(NSPoint)centerPoint;

// - (NSPoint)convertImagePointToViewPoint:(NSPoint)imagePoint;
// - (NSPoint)convertViewPointToImagePoint:(NSPoint)viewPoint;
// - (NSRect)convertImageRectToViewRect:(NSRect)imageRect;
// - (NSRect)convertViewRectToImageRect:(NSRect)viewRect;



// static int image_doubleClickOpensImageEditPanel(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L]  ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
//     HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;
//     if (lua_gettop(L) == 2) {
//         element.doubleClickOpensImageEditPanel = (BOOL)(lua_toboolean(L, 2)) ;
//         lua_pushvalue(L, 1) ;
//     } else {
//         lua_pushboolean(L, element.doubleClickOpensImageEditPanel) ;
//     }
//     return 1;
// }

// static int image_currentToolMode(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
//     HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;
//
//     if (lua_gettop(L) == 1) {
//         NSString *mode   = element.currentToolMode ;
//         NSArray  *temp   = [IMAGE_TOOLMODES allKeysForObject:mode];
//         NSString *answer = [temp firstObject] ;
//         if (answer) {
//             [skin pushNSObject:answer] ;
//         } else {
//             [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized tool mode %@ -- notify developers", USERDATA_TAG, mode]] ;
//             lua_pushnil(L) ;
//         }
//     } else {
//         NSString *key  = [skin toNSObjectAtIndex:2] ;
//         NSString *mode = IMAGE_TOOLMODES[key] ;
//         if (mode) {
//             element.currentToolMode = mode ;
//             lua_pushvalue(L, 1) ;
//         } else {
//             return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[IMAGE_TOOLMODES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
//         }
//     }
//     return 1 ;
// }

// static int image_crop(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
//     HSUITKElementImage *element = [skin toNSObjectAtIndex:1] ;
//
//     [element crop:element] ;
//     lua_pushvalue(L, 1) ;
//     return 1 ;
// }

// - (CALayer *)overlayForType:(NSString *)layerType;
// - (void)setOverlay:(CALayer *)layer forType:(NSString *)layerType;
// @property(assign) CIFilter *imageCorrection;

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementImage(lua_State *L, id obj) {
    HSUITKElementImage *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementImage *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementImageFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementImage *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementImage, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"autoHideScrollers",       image_autohidesScrollers},
    {"autoResize",              image_autoresizes},
    {"backgroundColor",         image_backgroundColor},
    {"editable",                image_editable},
    {"horizontalScroller",      image_hasHorizontalScroller},
    {"verticalScroller",        image_hasVerticalScroller},
    {"rotationAngle",           image_rotationAngle},
    {"supportsDragAndDrop",     image_supportsDragAndDrop},
    {"zoom",                    image_zoomFactor},
    {"zoomIn",                  image_zoomIn},
    {"zoomOut",                 image_zoomOut},
    {"zoomToActualSize",        image_zoomImageToActualSize},
    {"zoomToFit",               image_zoomImageToFit},
    {"flipHorizontally",        image_flipImageHorizontal},
    {"flipVertically",          image_flipImageVertical},
    {"rotateLeft",              image_rotateImageLeft},
    {"rotateRight",             image_rotateImageRight},
    {"size",                    image_size},
    {"metadata",                image_metadata},
    {"image",                   image_imageFromNSImage},
    {"imageFrom",               image_imageFromURL},

//     {"toolMode",                image_currentToolMode},
//     {"doubleClickForEditPanel", image_doubleClickOpensImageEditPanel},
//     {"crop",                    image_crop},

// other metamethods inherited from _control and _view
    {NULL,                        NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", image_new},
    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_libelement_image(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaryies() ;

    [skin registerPushNSHelper:pushHSUITKElementImage         forClass:"HSUITKElementImage"];
    [skin registerLuaObjectHelper:toHSUITKElementImageFromLua forClass:"HSUITKElementImage"
                                                    withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through content metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"autoHideScrollers",
        @"autoResize",
        @"backgroundColor",
        @"editable",
        @"horizontalScroller",
        @"verticalScroller",
        @"rotationAngle",
        @"supportsDragAndDrop",
        @"zoom",
        @"image",

//         @"toolMode",
//         @"doubleClickForEditPanel",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pop(L, 1) ;

    return 1;
}
