@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.image" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *IMAGE_FRAME_STYLES ;
static NSDictionary *IMAGE_ALIGNMENTS ;
static NSDictionary *IMAGE_SCALING_TYPES ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    IMAGE_FRAME_STYLES = @{
        @"none"   : @(NSImageFrameNone),
        @"photo"  : @(NSImageFramePhoto),
        @"bezel"  : @(NSImageFrameGrayBezel),
        @"groove" : @(NSImageFrameGroove),
        @"button" : @(NSImageFrameButton),
    } ;

    IMAGE_ALIGNMENTS = @{
        @"center"      : @(NSImageAlignCenter),
        @"top"         : @(NSImageAlignTop),
        @"topLeft"     : @(NSImageAlignTopLeft),
        @"topRight"    : @(NSImageAlignTopRight),
        @"left"        : @(NSImageAlignLeft),
        @"bottom"      : @(NSImageAlignBottom),
        @"bottomLeft"  : @(NSImageAlignBottomLeft),
        @"bottomRight" : @(NSImageAlignBottomRight),
        @"right"       : @(NSImageAlignRight),
    } ;

    IMAGE_SCALING_TYPES = @{
        @"proportionallyDown"     : @(NSImageScaleProportionallyDown),
        @"axesIndependently"      : @(NSImageScaleAxesIndependently),
        @"none"                   : @(NSImageScaleNone),
        @"proportionallyUpOrDown" : @(NSImageScaleProportionallyUpOrDown),
    } ;
}

@interface HSUITKElementImageView : NSImageView
@end

@interface HSUITKElementImageViewControl : NSControl
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;
@property            CGFloat    rotationAngle ;
@property            CGFloat    zoom ;
@property            BOOL       xFlipped ;
@property            BOOL       yFlipped ;
@end

static void updateTranslationMatrix(HSUITKElementImageView *view) {
    HSUITKElementImageViewControl *sv    = (HSUITKElementImageViewControl *)view.superview ;
    CGFloat                        height = view.frame.size.height ;
    CGFloat                        width  = view.frame.size.width ;

    CATransform3D transform = CATransform3DIdentity ;

    // x/y Flipped
    transform = CATransform3DScale(transform, sv.xFlipped ? -1 : 1, sv.yFlipped ? -1 : 1, 1.0) ;
    transform = CATransform3DTranslate(transform, sv.xFlipped ? -width : 0, sv.yFlipped ? -height : 0, 0) ;

    // rotation
    CGFloat xCenterOffset  = width * (0.5 - view.layer.anchorPoint.x) ;
    CGFloat yCenterOffset  = height * (0.5 - view.layer.anchorPoint.y) ;
    CGFloat angle = sv.rotationAngle * ((sv.xFlipped == sv.yFlipped) ? -1 : 1) ;
    transform = CATransform3DTranslate(transform, xCenterOffset, yCenterOffset, 0) ;
    transform = CATransform3DRotate(transform, angle * M_PI / 180.0, 0, 0, 1.0) ;
    transform = CATransform3DTranslate(transform, -xCenterOffset, -yCenterOffset, 0) ;

    // zoom
    transform = CATransform3DTranslate(transform, xCenterOffset, yCenterOffset, 0) ;
    transform = CATransform3DScale(transform, sv.zoom, sv.zoom, 1.0) ;
    transform = CATransform3DTranslate(transform, -xCenterOffset, -yCenterOffset, 0) ;

    view.layer.transform = transform ;
}

@implementation HSUITKElementImageViewControl
- (instancetype)initWithFrame:(NSRect)frameRect {
    @try {
        self = [super initWithFrame:frameRect] ;
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:new - %@", USERDATA_TAG, exception.reason]] ;
        self = nil ;
    }

    if (self) {
        HSUITKElementImageView *subview = [[HSUITKElementImageView alloc] initWithFrame:frameRect] ;
        if (subview) {
            _callbackRef    = LUA_NOREF ;
            _refTable       = refTable ;
            _selfRefCount   = 0 ;

            _rotationAngle  = 0.0 ;
            _zoom           = 1.0 ;
            _xFlipped       = NO ;
            _yFlipped       = NO ;

            self.autoresizesSubviews = YES ;

            subview.target  = self ;
            subview.action  = @selector(performCallback:) ;
            [self addSubview:subview] ;

            self.wantsLayer = YES ;
        } else {
            self = nil ;
        }
    }
    return self ;
}

- (void)drawRect:(NSRect)dirtyRect {
    self.subviews[0].needsDisplay = YES ;
    [super drawRect:dirtyRect] ;
}

// NOTE: _control passthrough methods

- (NSControlSize)controlSize {
    return ((HSUITKElementImageView *)self.subviews[0]).controlSize ;
}

- (void)setControlSize:(NSControlSize)value {
    ((HSUITKElementImageView *)self.subviews[0]).controlSize = value ;
}

- (NSTextAlignment)alignment {
    return ((HSUITKElementImageView *)self.subviews[0]).alignment ;
}

- (void)setAlignment:(NSTextAlignment)value {
    ((HSUITKElementImageView *)self.subviews[0]).alignment = value ;
}

- (NSFont *)font {
    return ((HSUITKElementImageView *)self.subviews[0]).font ;
}

- (void)setFont:(NSFont *)value {
    ((HSUITKElementImageView *)self.subviews[0]).font = value ;
}

- (BOOL)isHighlighted {
    return ((HSUITKElementImageView *)self.subviews[0]).highlighted ;
}

- (void)setHighlighted:(BOOL)value {
    ((HSUITKElementImageView *)self.subviews[0]).highlighted = value ;
}

- (BOOL)isEnabled {
    return ((HSUITKElementImageView *)self.subviews[0]).enabled ;
}

- (void)setEnabled:(BOOL)value {
    ((HSUITKElementImageView *)self.subviews[0]).enabled = value ;
}

- (BOOL)isContinuous {
    return ((HSUITKElementImageView *)self.subviews[0]).continuous ;
}

- (void)setContinuous:(BOOL)value {
    ((HSUITKElementImageView *)self.subviews[0]).continuous = value ;
}

- (NSLineBreakMode)lineBreakMode {
    return ((HSUITKElementImageView *)self.subviews[0]).lineBreakMode ;
}

- (void)setLineBreakMode:(NSLineBreakMode)value {
    ((HSUITKElementImageView *)self.subviews[0]).lineBreakMode = value ;
}

- (BOOL)usesSingleLineMode {
    return ((HSUITKElementImageView *)self.subviews[0]).usesSingleLineMode ;
}

- (void)setUsesSingleLineMode:(BOOL)value {
    ((HSUITKElementImageView *)self.subviews[0]).usesSingleLineMode = value ;
}

- (NSInteger)tag {
    return ((HSUITKElementImageView *)self.subviews[0]).tag ;
}

- (void)setTag:(NSInteger)value {
    ((HSUITKElementImageView *)self.subviews[0]).tag = value ;
}

// NOTE: _view passthrough methods

- (NSString *)toolTip {
    return ((HSUITKElementImageView *)self.subviews[0]).toolTip ;
}

- (void)setToolTip:(NSString *)value {
    ((HSUITKElementImageView *)self.subviews[0]).toolTip = value ;
}

- (NSFocusRingType)focusRingType {
    return ((HSUITKElementImageView *)self.subviews[0]).focusRingType ;
}

- (void)setFocusRingType:(NSFocusRingType)value {
    ((HSUITKElementImageView *)self.subviews[0]).focusRingType = value ;
}

// NOTE: callback support

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

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
//     [LuaSkin logInfo:[NSString stringWithFormat:@"%s.resizeSubviewsWithOldSize - frame set to %@", USERDATA_TAG, NSStringFromRect(self.bounds)]] ;
    [self.subviews[0] resizeWithOldSuperviewSize:oldSize] ;
}

- (void)performCallback:(__unused id)sender {
    [self callbackHamster:@[ self ]] ;
}

@end

@implementation HSUITKElementImageView
- (instancetype)initWithFrame:(NSRect)frameRect {
    @try {
        self = [super initWithFrame:frameRect] ;
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:new - %@", USERDATA_TAG, exception.reason]] ;
        self = nil ;
    }

    if (self) {
        self.continuous = NO ;
        self.wantsLayer = YES ;
    }
    return self ;
}

- (void)resizeWithOldSuperviewSize:(__unused NSSize)oldSize {
    if (self.superview) {
//     [LuaSkin logInfo:[NSString stringWithFormat:@"%s.resizeWithOldSuperviewSize - frame set to %@", USERDATA_TAG, NSStringFromRect(self.superview.bounds)]] ;
        self.frame = self.superview.bounds ;
    }
}

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.image.new([frame]) -> imageObject
/// Constructor
/// Creates a new image element for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the frame for the element.
///
/// Returns:
///  * the imageObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a container element or to a `hs._asm.uitk.window`.
static int image_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementImageViewControl *element = [[HSUITKElementImageViewControl alloc] initWithFrame:frameRect];
    if (element) {
        if (lua_gettop(L) != 1) [element setFrameSize:[element fittingSize]] ;
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

// -- // if I add translate to the matrix, I think these can be in lua as well. consider...
// -- // before or after rotation?
// -- // need rotation point? for last one yes... for others as well?
// --
// -- // - (void)scrollToPoint:(NSPoint)point;
// -- // - (void)scrollToRect:(NSRect)rect;
// -- // - (void)zoomImageToRect:(NSRect)rect;
// -- // - (void)setImageZoomFactor:(CGFloat)zoomFactor centerPoint:(NSPoint)centerPoint;
// -- // - (void)setRotationAngle:(CGFloat)rotationAngle centerPoint:(NSPoint)centerPoint;


static int image_zoomToFit(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementImageViewControl *element = [skin toNSObjectAtIndex:1] ;
    HSUITKElementImageView        *image   = element.subviews[0] ;

    NSSize imageSize = image.image.size ;
    NSSize frameSize = element.frame.size ;

    CGFloat angle = element.rotationAngle * ((element.xFlipped == element.yFlipped) ? -1 : 1) ;
    CGAffineTransform xfrm = CGAffineTransformMakeRotation(angle * M_PI / 180.0) ;
    NSRect rotatedSize = CGRectApplyAffineTransform(NSMakeRect(0, 0, imageSize.width, imageSize.height), xfrm) ;

    CGFloat xZoomFactor = frameSize.width / rotatedSize.size.width  ;
    CGFloat yZoomFactor = frameSize.height / rotatedSize.size.height ;

    element.zoom = fmin(xZoomFactor, yZoomFactor) ;
    updateTranslationMatrix(image) ;
    element.needsDisplay = YES ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

static int image_rotationAngle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImageViewControl *element = [skin toNSObjectAtIndex:1] ;
    HSUITKElementImageView        *image   = element.subviews[0] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.rotationAngle) ;
    } else {
        element.rotationAngle = lua_tonumber(L, 2) ;
        updateTranslationMatrix(image) ;
        element.needsDisplay  = YES ;

        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int image_zoom(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImageViewControl *element = [skin toNSObjectAtIndex:1] ;
    HSUITKElementImageView        *image   = element.subviews[0] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, element.zoom) ;
    } else {
        CGFloat zoom = lua_tonumber(L, 2) ;
        if (zoom > 0.0) {
            element.zoom = zoom ;
        } else {
            return luaL_argerror(L, 2, "zoom factor must be positive") ;
        }
        updateTranslationMatrix(image) ;
        element.needsDisplay  = YES ;

        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int image_flipHorizontally(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImageViewControl *element = [skin toNSObjectAtIndex:1] ;
    HSUITKElementImageView        *image   = element.subviews[0] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.xFlipped) ;
    } else {
        element.xFlipped = (BOOL)(lua_toboolean(L, 2)) ;
        updateTranslationMatrix(image) ;
        element.needsDisplay  = YES ;

        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int image_flipVertically(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImageViewControl *element = [skin toNSObjectAtIndex:1] ;
    HSUITKElementImageView        *image   = element.subviews[0] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, element.yFlipped) ;
    } else {
        element.yFlipped = (BOOL)(lua_toboolean(L, 2)) ;
        updateTranslationMatrix(image) ;
        element.needsDisplay  = YES ;

        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int image_imageSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementImageViewControl *element = [skin toNSObjectAtIndex:1] ;
    HSUITKElementImageView        *image   = element.subviews[0] ;

    [skin pushNSSize:image.image.size] ;
    return 1 ;
}

/// hs._asm.uitk.element:allowsCutCopyPaste([state]) -> imageObject | boolean
/// Method
/// Get or set whether or not the image holder element allows the user to cut, copy, and paste an image to or from the element.
///
/// Parameters:
///  * `state` - an optional boolean, default true, indicating whether or not the user can cut, copy, and paste images to or from the element.
///
/// Returns:
///  * if a value is provided, returns the imageObject ; otherwise returns the current value.
static int image_allowsCutCopyPaste(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImageViewControl *element = [skin toNSObjectAtIndex:1] ;
    HSUITKElementImageView        *image   = element.subviews[0] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, image.allowsCutCopyPaste) ;
    } else {
        image.allowsCutCopyPaste = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element:animates([state]) -> imageObject | boolean
/// Method
/// Get or set whether or not an animated GIF that is assigned to the imageObject should be animated or static.
///
/// Parameters:
///  * `state` - an optional boolean indicating whether or not animated GIF images can be animated.
///
/// Returns:
///  * if a value is provided, returns the imageObject ; otherwise returns the current value.
static int image_animates(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImageViewControl *element = [skin toNSObjectAtIndex:1] ;
    HSUITKElementImageView        *image   = element.subviews[0] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, image.animates) ;
    } else {
        image.animates = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element:editable([state]) -> imageObject | boolean
/// Method
/// Get or set whether or not the image holder element allows the user to drag an image or image file onto the element.
///
/// Parameters:
///  * `state` - an optional boolean, default false, indicating whether or not the user can drag an image or image file onto the element.
///
/// Returns:
///  * if a value is provided, returns the imageObject ; otherwise returns the current value.
static int image_editable(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImageViewControl *element = [skin toNSObjectAtIndex:1] ;
    HSUITKElementImageView        *image   = element.subviews[0] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, image.editable) ;
    } else {
        image.editable = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.image:imageAlignment([alignment]) -> imageObject | string
/// Method
/// Get or set the alignment of the image within the image element.
///
/// Parameters:
///  * `alignment` - an optional string, default "center", specifying the images alignment within the element frame. Valid strings are as follows:
///    * "topLeft"     - the image's top left corner will match the element frame's top left corner
///    * "top"         - the image's top match the element frame's top and will be centered horizontally
///    * "topRight"    - the image's top right corner will match the element frame's top right corner
///    * "left"        - the image's left side will match the element frame's left side and will be centered vertically
///    * "center"      - the image will be centered vertically and horizontally within the element frame
///    * "right"       - the image's right side will match the element frame's right side and will be centered vertically
///    * "bottomLeft"  - the image's bottom left corner will match the element frame's bottom left corner
///    * "bottom"      - the image's bottom match the element frame's bottom and will be centered horizontally
///    * "bottomRight" - the image's bottom right corner will match the element frame's bottom right corner
///
/// Returns:
///  * if a value is provided, returns the imageObject ; otherwise returns the current value.
static int image_imageAlignment(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImageViewControl *element = [skin toNSObjectAtIndex:1] ;
    HSUITKElementImageView        *image   = element.subviews[0] ;

    if (lua_gettop(L) == 1) {
        NSNumber *type = @(image.imageAlignment) ;
        NSArray *temp = [IMAGE_ALIGNMENTS allKeysForObject:type] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized alignment %@ -- notify developers", USERDATA_TAG, type]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *type = IMAGE_ALIGNMENTS[key] ;
        if (type) {
            image.imageAlignment = [type unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[IMAGE_ALIGNMENTS allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.image:imageFrameStyle([style]) -> imageObject | string
/// Method
/// Get or set the visual frame drawn around the image element area.
///
/// Parameters:
///  * `style` - an optional string, default "none", specifying the frame to draw around the image element area. Valid strings are as follows:
///    * "none"   - no frame is drawing around the image element frame
///    * "photo"  - a thin black outline with a white background and a dropped shadow.
///    * "bezel"  - a gray, concave bezel with no background that makes the image look sunken
///    * "groove" - a thin groove with a gray background that looks etched around the image
///    * "button" - a convex bezel with a gray background that makes the image stand out in relief, like a butto
///
/// Returns:
///  * if a value is provided, returns the imageObject ; otherwise returns the current value.
///
/// Notes:
///  * Apple considers the photo, groove, and button style frames "stylistically obsolete" and if a frame is required, recommend that you use the bezel style or draw your own to more closely match the OS look and feel.
static int image_imageFrameStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImageViewControl *element = [skin toNSObjectAtIndex:1] ;
    HSUITKElementImageView        *image   = element.subviews[0] ;

    if (lua_gettop(L) == 1) {
        NSNumber *type = @(image.imageFrameStyle) ;
        NSArray *temp = [IMAGE_FRAME_STYLES allKeysForObject:type] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized frame style %@ -- notify developers", USERDATA_TAG, type]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *type = IMAGE_FRAME_STYLES[key] ;
        if (type) {
            image.imageFrameStyle = [type unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[IMAGE_FRAME_STYLES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.image:imageScaling([scale]) -> imageObject | string
/// Method
/// Get or set the scaling applied to the image if it doesn't fit the image element area exactly
///
/// Parameters:
///  * `scale` - an optional string, default "proportionallyDown", specifying how to scale the image when it doesn't fit the element area exactly. Valid strings are as follows:
///    * "proportionallyDown"     - shrink the image, preserving the aspect ratio, to fit the element frame if the image is larger than the element frame
///    * "axesIndependently"      - shrink or expand the image to fully fill the element frame. This does not preserve the aspect ratio
///    * "none"                   - perform no scaling or resizing of the image
///    * "proportionallyUpOrDown" - shrink or expand the image to fully fill the element frame, preserving the aspect ration
///
/// Returns:
///  * if a value is provided, returns the imageObject ; otherwise returns the current value.
static int image_imageScaling(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImageViewControl *element = [skin toNSObjectAtIndex:1] ;
    HSUITKElementImageView        *image   = element.subviews[0] ;

    if (lua_gettop(L) == 1) {
        NSNumber *type = @(image.imageScaling) ;
        NSArray *temp = [IMAGE_SCALING_TYPES allKeysForObject:type] ;
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized image scaling %@ -- notify developers", USERDATA_TAG, type]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *type = IMAGE_SCALING_TYPES[key] ;
        if (type) {
            image.imageScaling = [type unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [[IMAGE_SCALING_TYPES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.image:image([image]) -> imageObject | hs.image | nil
/// Method
/// Get or set the image currently being displayed in the image element.
///
/// Parameters:
///  * `image` - an optional `hs.image` object, or explicit nil to remove, representing the image currently being displayed by the image element.
///
/// Returns:
///  * if a value is provided, returns the imageObject ; otherwise returns the current value.
///
/// Notes:
///  * If the element is editable or supports cut-and-paste, any change made by the user to the image will be available to Hammerspoon through this method.
static int image_image(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementImageViewControl *element = [skin toNSObjectAtIndex:1] ;
    HSUITKElementImageView        *image   = element.subviews[0] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:image.image] ;
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            image.image = nil ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, "hs.image", LS_TBREAK] ;
            image.image = [skin toNSObjectAtIndex:2] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementImageViewControl(lua_State *L, id obj) {
    HSUITKElementImageViewControl *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementImageViewControl *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementImageViewControl(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementImageViewControl *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementImageViewControl, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_gc(lua_State* L) {
    HSUITKElementImageViewControl *obj  = get_objectFromUserdata(__bridge_transfer HSUITKElementImageViewControl, L, 1, USERDATA_TAG) ;

    obj.selfRefCount-- ;
    if (obj.selfRefCount == 0) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        obj.callbackRef = [skin luaUnref:obj.refTable ref:obj.callbackRef] ;
        [obj.subviews[0] removeFromSuperview] ;
        obj = nil ;
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"allowsCutCopyPaste", image_allowsCutCopyPaste},
    {"animates",           image_animates},
    {"editable",           image_editable},
    {"imageAlignment",     image_imageAlignment},
    {"imageFrameStyle",    image_imageFrameStyle},
    {"imageScaling",       image_imageScaling},
    {"image",              image_image},
    {"rotationAngle",      image_rotationAngle},
    {"imageSize",          image_imageSize},
    {"zoom",               image_zoom},
    {"flipHorizontally",   image_flipHorizontally},
    {"flipVertically",     image_flipVertically},
    {"zoomToFit",          image_zoomToFit},

// other metamethods inherited from _control and _view
    {"__gc",               userdata_gc},
    {NULL,                 NULL}
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

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKElementImageViewControl  forClass:"HSUITKElementImageViewControl"];
    [skin registerLuaObjectHelper:toHSUITKElementImageViewControl forClass:"HSUITKElementImageViewControl"
                                                       withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"allowsCutCopyPaste",
        @"animates",
        @"editable",
        @"imageAlignment",
        @"imageFrameStyle",
        @"imageScaling",
        @"image",
        @"rotationAngle",
        @"zoom",
        @"flipHorizontally",
        @"flipVertically",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}
