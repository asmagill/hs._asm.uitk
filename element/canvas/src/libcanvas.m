@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.canvas" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

typedef NS_ENUM(NSInteger, attributeValidity) {
    attributeValid,
    attributeNulling,
    attributeInvalid,
};

static NSArray      *ALL_TYPES ;
static NSArray      *VISIBLE ;
static NSArray      *PRIMITIVES ;
static NSArray      *CLOSED ;

static NSDictionary *STROKE_JOIN_STYLES ;
static NSDictionary *STROKE_CAP_STYLES ;
static NSDictionary *COMPOSITING_TYPES ;
static NSDictionary *WINDING_RULES ;
static NSDictionary *TEXTALIGNMENT_TYPES ;
static NSDictionary *TEXTWRAP_TYPES ;
static NSDictionary *IMAGEALIGNMENT_TYPES ;
static NSDictionary *IMAGESCALING_TYPES ;

static NSDictionary *languageDictionary ;

#pragma mark - Class Interfaces -

@interface HSUITKElementCanvas : NSView <NSDraggingDestination>
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;

@property int                   mouseCallbackRef ;
@property int                   draggingCallbackRef ;
@property BOOL                  mouseTracking ;
@property BOOL                  canvasMouseDown ;
@property BOOL                  canvasMouseUp ;
@property BOOL                  canvasMouseEnterExit ;
@property BOOL                  canvasMouseMove ;
@property NSUInteger            previousTrackedIndex ;
@property NSMutableDictionary   *canvasDefaults ;
@property NSMutableArray        *elementList ;
@property NSMutableArray        *elementBounds ;
@property NSAffineTransform     *canvasTransform ;
@property NSMapTable            *imageAnimations ;

// - (NSObject *)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index ;
// - (NSObject *)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index onlyIfSet:(BOOL)onlyIfSet ;
// - (NSObject *)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index resolvePercentages:(BOOL)resolvePercentages ;
// - (NSObject *)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index resolvePercentages:(BOOL)resolvePercentages onlyIfSet:(BOOL)onlyIfSet ;
//
// // (imageAdditions)
// - (void)drawImage:(NSImage *)theImage atIndex:(NSUInteger)idx inRect:(NSRect)cellFrame operation:(NSUInteger)compositeType ;
//
// // (viewNotifications)
// - (void)willRemoveFromCanvas ;
// - (void)didRemoveFromCanvas ;
// - (void)willAddToCanvas ;
// - (void)didAddToCanvas ;
//
// - (void)canvasWillHide ;
// - (void)canvasDidHide ;
// - (void)canvasWillShow ;
// - (void)canvasDidShow ;
@end

@interface HSUITKElementCanvasGifAnimator : NSObject
@property (weak) NSBitmapImageRep    *animatingRepresentation ;
@property (weak) HSUITKElementCanvas *inCanvas ;
@property BOOL             isRunning ;

-(instancetype)initWithImage:(NSImage *)image forCanvas:(HSUITKElementCanvas *)canvas ;
-(void)startAnimating ;
-(void)stopAnimating ;
@end

#pragma mark - Support Functions -

static void defineInternalDictionaries(void) {
    ALL_TYPES  = @[
        @"arc",
        @"circle",
        @"ellipticalArc",
        @"image",
        @"oval",
        @"points",
        @"rectangle",
        @"resetClip",
        @"segments",
        @"text",

    ] ;

    VISIBLE = @[
        @"arc",
        @"circle",
        @"ellipticalArc",
        @"image",
        @"oval",
        @"points",
        @"rectangle",
        @"segments",
        @"text",
    ] ;

    PRIMITIVES = @[
        @"arc",
        @"circle",
        @"ellipticalArc",
        @"oval",
        @"points",
        @"rectangle",
        @"segments"
    ] ;

    CLOSED = @[
        @"arc",
        @"circle",
        @"ellipticalArc",
        @"oval",
        @"rectangle",
        @"segments"
    ] ;

    STROKE_JOIN_STYLES = @{
        @"miter" : @(NSLineJoinStyleMiter),
        @"round" : @(NSLineJoinStyleBevel),
        @"bevel" : @(NSLineJoinStyleBevel),
    } ;

    STROKE_CAP_STYLES = @{
        @"butt"   : @(NSLineCapStyleButt),
        @"round"  : @(NSLineCapStyleRound),
        @"square" : @(NSLineCapStyleSquare),
    } ;

    COMPOSITING_TYPES = @{
        @"clear"           : @(NSCompositingOperationClear),
        @"copy"            : @(NSCompositingOperationCopy),
        @"sourceOver"      : @(NSCompositingOperationSourceOver),
        @"sourceIn"        : @(NSCompositingOperationSourceIn),
        @"sourceOut"       : @(NSCompositingOperationSourceOut),
        @"sourceAtop"      : @(NSCompositingOperationSourceAtop),
        @"destinationOver" : @(NSCompositingOperationDestinationOver),
        @"destinationIn"   : @(NSCompositingOperationDestinationIn),
        @"destinationOut"  : @(NSCompositingOperationDestinationOut),
        @"destinationAtop" : @(NSCompositingOperationDestinationAtop),
        @"XOR"             : @(NSCompositingOperationXOR),
        @"plusDarker"      : @(NSCompositingOperationPlusDarker),
        @"plusLighter"     : @(NSCompositingOperationPlusLighter),
    } ;

    WINDING_RULES = @{
        @"evenOdd" : @(NSWindingRuleEvenOdd),
        @"nonZero" : @(NSWindingRuleNonZero),
    } ;

    TEXTALIGNMENT_TYPES = @{
        @"left"      : @(NSTextAlignmentLeft),
        @"right"     : @(NSTextAlignmentRight),
        @"center"    : @(NSTextAlignmentCenter),
        @"justified" : @(NSTextAlignmentJustified),
        @"natural"   : @(NSTextAlignmentNatural),
    } ;

    TEXTWRAP_TYPES = @{
        @"wordWrap"       : @(NSLineBreakByWordWrapping),
        @"charWrap"       : @(NSLineBreakByCharWrapping),
        @"clip"           : @(NSLineBreakByClipping),
        @"truncateHead"   : @(NSLineBreakByTruncatingHead),
        @"truncateMiddle" : @(NSLineBreakByTruncatingMiddle),
        @"truncateTail"   : @(NSLineBreakByTruncatingTail),
    } ;

    IMAGEALIGNMENT_TYPES = @{
        @"center"      : @(NSImageAlignCenter),
        @"bottom"      : @(NSImageAlignBottom),
        @"bottomLeft"  : @(NSImageAlignBottomLeft),
        @"bottomRight" : @(NSImageAlignBottomRight),
        @"left"        : @(NSImageAlignLeft),
        @"right"       : @(NSImageAlignRight),
        @"top"         : @(NSImageAlignTop),
        @"topLeft"     : @(NSImageAlignTopLeft),
        @"topRight"    : @(NSImageAlignTopRight),
    } ;

    IMAGESCALING_TYPES = @{
        @"none"                : @(NSImageScaleNone),
        @"scaleToFit"          : @(NSImageScaleAxesIndependently),
        @"scaleProportionally" : @(NSImageScaleProportionallyUpOrDown),
        @"shrinkToFit"         : @(NSImageScaleProportionallyDown),
    } ;

    // some defaults aren't reset when graphics context closed, so make sure to only get them once
    if (!languageDictionary) {
        // the default shadow has no offset or blur radius, so lets setup one that is at least visible
        NSShadow *defaultShadow = [[NSShadow alloc] init] ;
        [defaultShadow setShadowOffset:NSMakeSize(5.0, -5.0)];
        [defaultShadow setShadowBlurRadius:5.0];
//         [defaultShadow setShadowColor:[[NSColor blackColor] colorWithAlphaComponent:0.3]];

        // @encode may change depending upon architecture, so use the  same value we check against
        // in isValueValidForDictionary
        const char *archBooleanType = [@(YES) objCType] ;
        NSString   *abtNSString     = [NSString stringWithCString:archBooleanType encoding:NSUTF8StringEncoding] ;

        const char *archIntegerType = [@((lua_Integer)1) objCType] ;
        NSString   *aitNSString     = [NSString stringWithCString:archIntegerType encoding:NSUTF8StringEncoding] ;

        languageDictionary = @{
            @"action" : @{
                @"class"       : @[ [NSString class] ],
                @"luaClass"    : @"string",
                @"default"     : @"strokeAndFill",
                @"values"      : @[ @"stroke", @"fill", @"strokeAndFill", @"clip", @"build", @"skip" ],
                @"nullable" : @(YES),
                @"optionalFor" : ALL_TYPES,
            },
            @"absolutePosition" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"boolean",
                @"objCType"    : abtNSString,
                @"nullable"    : @(YES),
                @"default"     : @(YES),
                @"optionalFor" : VISIBLE,
            },
            @"absoluteSize" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"boolean",
                @"objCType"    : abtNSString,
                @"nullable"    : @(YES),
                @"default"     : @(YES),
                @"optionalFor" : VISIBLE,
            },
            @"antialias" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"boolean",
                @"objCType"    : abtNSString,
                @"nullable"    : @(YES),
                @"default"     : @(YES),
                @"optionalFor" : VISIBLE,
            },
            @"arcRadii" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"boolean",
                @"objCType"    : abtNSString,
                @"nullable"    : @(YES),
                @"default"     : @(YES),
                @"optionalFor" : @[ @"arc", @"ellipticalArc" ],
            },
            @"arcClockwise" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"boolean",
                @"objCType"    : abtNSString,
                @"nullable"    : @(YES),
                @"default"     : @(YES),
                @"optionalFor" : @[ @"arc", @"ellipticalArc" ],
            },
            @"clipToPath" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"boolean",
                @"objCType"    : abtNSString,
                @"nullable"    : @(YES),
                @"default"     : @(NO),
                @"optionalFor" : CLOSED,
            },
            @"compositeRule" : @{
                @"class"       : @[ [NSString class] ],
                @"luaClass"    : @"string",
                @"values"      : COMPOSITING_TYPES.allKeys,
                @"nullable"    : @(YES),
                @"default"     : @"sourceOver",
                @"optionalFor" : VISIBLE,
            },
            @"center" : @{
                @"class"         : @[ [NSDictionary class] ],
                @"luaClass"      : @"table",
                @"keys"          : @{
                    @"x" : @{
                        @"class"    : @[ [NSString class], [NSNumber class] ],
                        @"luaClass" : @"number or string",
                    },
                    @"y" : @{
                        @"class"    : @[ [NSString class], [NSNumber class] ],
                        @"luaClass" : @"number or string",
                    },
                },
                @"default"       : @{
                                       @"x" : @"50%",
                                       @"y" : @"50%",
                                   },
                @"nullable"      : @(NO),
                @"requiredFor"   : @[ @"circle", @"arc" ],
            },
            @"closed" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"boolean",
                @"objCType"    : abtNSString,
                @"nullable"    : @(NO),
                @"default"     : @(NO),
                @"requiredFor" : @[ @"segments" ],
            },
            @"coordinates" : @{
                @"class"           : @[ [NSArray class] ],
                @"luaClass"        : @"table",
                @"default"         : @[ ],
                @"nullable"        : @(NO),
                @"requiredFor"     : @[ @"segments", @"points" ],
                @"memberClass"     : [NSDictionary class],
                @"memberLuaClass"  : @"point table",
                @"memberClassKeys" : @{
                    @"x"   : @{
                        @"class"       : @[ [NSNumber class], [NSString class] ],
                        @"luaClass"    : @"number or string",
                        @"default"     : @"0.0",
                        @"requiredFor" : @[ @"segments", @"points" ],
                        @"nullable"    : @(NO),
                    },
                    @"y"   : @{
                        @"class"       : @[ [NSNumber class], [NSString class] ],
                        @"luaClass"    : @"number or string",
                        @"default"     : @"0.0",
                        @"requiredFor" : @[ @"segments", @"points" ],
                        @"nullable"    : @(NO),
                    },
                    @"c1x" : @{
                        @"class"       : @[ [NSNumber class], [NSString class] ],
                        @"luaClass"    : @"number or string",
                        @"default"     : @"0.0",
                        @"optionalFor" : @[ @"segments" ],
                        @"nullable"    : @(YES),
                    },
                    @"c1y" : @{
                        @"class"       : @[ [NSNumber class], [NSString class] ],
                        @"luaClass"    : @"number or string",
                        @"default"     : @"0.0",
                        @"optionalFor" : @[ @"segments" ],
                        @"nullable"    : @(YES),
                    },
                    @"c2x" : @{
                        @"class"       : @[ [NSNumber class], [NSString class] ],
                        @"luaClass"    : @"number or string",
                        @"default"     : @"0.0",
                        @"optionalFor" : @[ @"segments" ],
                        @"nullable"    : @(YES),
                    },
                    @"c2y" : @{
                        @"class"       : @[ [NSNumber class], [NSString class] ],
                        @"luaClass"    : @"number or string",
                        @"default"     : @"0.0",
                        @"optionalFor" : @[ @"segments" ],
                        @"nullable"    : @(YES),
                    },
                },
            },
            @"endAngle" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"number",
                @"default"     : @(360.0),
                @"nullable"    : @(NO),
                @"requiredFor" : @[ @"arc", @"ellipticalArc" ],
            },
            @"fillColor" : @{
                @"class"       : @[ [NSColor class] ],
                @"luaClass"    : @"hs.drawing.color table",
                @"nullable"    : @(YES),
                @"default"     : [NSColor redColor],
                @"optionalFor" : CLOSED,
            },
            @"fillGradient" : @{
                @"class"       : @[ [NSString class] ],
                @"luaClass"    : @"string",
                @"values"      : @[
                                       @"none",
                                       @"linear",
                                       @"radial",
                                 ],
                @"nullable"    : @(YES),
                @"default"     : @"none",
                @"optionalFor" : CLOSED,
            },
            @"fillGradientAngle"  : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"number",
                @"nullable"    : @(YES),
                @"default"     : @(0.0),
                @"optionalFor" : CLOSED,
            },
            @"fillGradientCenter" : @{
                @"class"         : @[ [NSDictionary class] ],
                @"luaClass"      : @"table",
                @"keys"          : @{
                    @"x" : @{
                        @"class"     : @[ [NSNumber class] ],
                        @"luaClass"  : @"number",
                        @"maxNumber" : @(1.0),
                        @"minNumber" : @(-1.0),
                    },
                    @"y" : @{
                        @"class"    : @[ [NSNumber class] ],
                        @"luaClass" : @"number",
                        @"maxNumber" : @(1.0),
                        @"minNumber" : @(-1.0),
                    },
                },
                @"default"       : @{
                                       @"x" : @(0.0),
                                       @"y" : @(0.0),
                                   },
                @"nullable"      : @(YES),
                @"optionalFor"   : CLOSED,
            },
            @"fillGradientColors" : @{
                @"class"          : @[ [NSArray class] ],
                @"luaClass"       : @"table",
                @"default"        : @[ [NSColor blackColor], [NSColor whiteColor] ],
                @"memberClass"    : [NSColor class],
                @"memberLuaClass" : @"hs.drawing.color table",
                @"nullable"       : @(YES),
                @"optionalFor"    : CLOSED,
            },
            @"flatness" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"number",
                @"nullable"    : @(YES),
                @"default"     : @([NSBezierPath defaultFlatness]),
                @"optionalFor" : PRIMITIVES,
            },
            @"flattenPath" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"boolean",
                @"objCType"    : abtNSString,
                @"nullable"    : @(YES),
                @"default"     : @(NO),
                @"optionalFor" : PRIMITIVES,
            },
            @"frame" : @{
                @"class"         : @[ [NSDictionary class] ],
                @"luaClass"      : @"table",
                @"keys"          : @{
                    @"x" : @{
                        @"class"    : @[ [NSString class], [NSNumber class] ],
                        @"luaClass" : @"number or string",
                    },
                    @"y" : @{
                        @"class"    : @[ [NSString class], [NSNumber class] ],
                        @"luaClass" : @"number or string",
                    },
                    @"h" : @{
                        @"class"    : @[ [NSString class], [NSNumber class] ],
                        @"luaClass" : @"number or string",
                    },
                    @"w" : @{
                        @"class"    : @[ [NSString class], [NSNumber class] ],
                        @"luaClass" : @"number or string",
                    },
                },
                @"default"       : @{
                                       @"x" : @"0%",
                                       @"y" : @"0%",
                                       @"h" : @"100%",
                                       @"w" : @"100%",
                                   },
                @"nullable"      : @(NO),
                @"requiredFor"   : @[ @"rectangle", @"oval", @"ellipticalArc", @"text", @"image", ],
            },
            @"id" : @{
                @"class"       : @[ [NSString class], [NSNumber class] ],
                @"luaClass"    : @"string or number",
                @"nullable"    : @(YES),
                @"optionalFor" : VISIBLE,
            },
            @"image" : @{
                @"class"       : @[ [NSImage class] ],
                @"luaClass"    : @"hs.image object",
                @"nullable"    : @(YES),
                @"default"     : [NSNull null],
                @"optionalFor" : @[ @"image" ],
            },
            @"imageAlpha" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"number",
                @"nullable"    : @(YES),
                @"default"     : @(1.0),
                @"minNumber"   : @(0.0),
                @"maxNumber"   : @(1.0),
                @"optionalFor" : @[ @"image" ],
            },
            @"imageAlignment" : @{
                @"class"       : @[ [NSString class] ],
                @"luaClass"    : @"string",
                @"values"      : IMAGEALIGNMENT_TYPES.allKeys,
                @"nullable"    : @(YES),
                @"default"     : @"center",
                @"optionalFor" : @[ @"image" ],
            },
            @"imageAnimationFrame" : @ {
                @"class"       : @[ [NSNumber class] ],
                @"objCType"    : aitNSString,
                @"luaClass"    : @"integer",
                @"nullable"    : @(YES),
                @"default"     : @(0),
                @"optionalFor" : @[ @"image" ],
            },
            @"imageAnimates" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"boolean",
                @"objCType"    : abtNSString,
                @"nullable"    : @(NO),
                @"default"     : @(NO),
                @"requiredFor" : @[ @"image" ],
            },
            @"imageScaling" : @{
                @"class"       : @[ [NSString class] ],
                @"luaClass"    : @"string",
                @"values"      : IMAGESCALING_TYPES.allKeys,
                @"nullable"    : @(YES),
                @"default"     : @"scaleProportionally",
                @"optionalFor" : @[ @"image" ],
            },
            @"miterLimit" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"number",
                @"default"     : @([NSBezierPath defaultMiterLimit]),
                @"nullable"    : @(YES),
                @"optionalFor" : PRIMITIVES,
            },
            @"padding" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"number",
                @"default"     : @(0.0),
                @"nullable"    : @(YES),
                @"optionalFor" : VISIBLE,
            },
            @"radius" : @{
                @"class"       : @[ [NSNumber class], [NSString class] ],
                @"luaClass"    : @"number or string",
                @"nullable"    : @(NO),
                @"default"     : @"50%",
                @"requiredFor" : @[ @"arc", @"circle" ],
            },
            @"reversePath" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"boolean",
                @"objCType"    : abtNSString,
                @"nullable"    : @(YES),
                @"default"     : @(NO),
                @"optionalFor" : PRIMITIVES,
            },
            @"roundedRectRadii" : @{
                @"class"         : @[ [NSDictionary class] ],
                @"luaClass"      : @"table",
                @"keys"          : @{
                    @"xRadius" : @{
                        @"class"    : @[ [NSNumber class] ],
                        @"luaClass" : @"number",
                    },
                    @"yRadius" : @{
                        @"class"    : @[ [NSNumber class] ],
                        @"luaClass" : @"number",
                    },
                },
                @"default"       : @{
                                       @"xRadius" : @(0.0),
                                       @"yRadius" : @(0.0),
                                   },
                @"nullable"      : @(YES),
                @"optionalFor"   : @[ @"rectangle" ],
            },
            @"shadow" : @{
                @"class"       : @[ [NSShadow class] ],
                @"luaClass"    : @"shadow table",
                @"nullable"    : @(YES),
                @"default"     : defaultShadow,
                @"optionalFor" : PRIMITIVES,
            },
            @"startAngle" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"number",
                @"default"     : @(0.0),
                @"nullable"    : @(NO),
                @"requiredFor" : @[ @"arc", @"ellipticalArc" ],
            },
            @"strokeCapStyle" : @{
                @"class"       : @[ [NSString class] ],
                @"luaClass"    : @"string",
                @"values"      : STROKE_CAP_STYLES.allKeys,
                @"nullable"    : @(YES),
                @"default"     : @"butt",
                @"optionalFor" : PRIMITIVES,
            },
            @"strokeColor" : @{
                @"class"       : @[ [NSColor class] ],
                @"luaClass"    : @"hs.drawing.color table",
                @"nullable"    : @(YES),
                @"default"     : [NSColor blackColor],
                @"optionalFor" : PRIMITIVES,
            },
            @"strokeDashPattern" : @{
                @"class"          : @[ [NSArray class] ],
                @"luaClass"       : @"table",
                @"nullable"       : @(YES),
                @"default"        : @[ ],
                @"memberClass"    : [NSNumber class],
                @"memberLuaClass" : @"number",
                @"optionalFor"    : PRIMITIVES,
            },
            @"strokeDashPhase" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"number",
                @"default"     : @(0.0),
                @"nullable"    : @(YES),
                @"optionalFor" : PRIMITIVES,
            },
            @"strokeJoinStyle" : @{
                @"class"       : @[ [NSString class] ],
                @"luaClass"    : @"string",
                @"values"      : STROKE_JOIN_STYLES.allKeys,
                @"nullable"    : @(YES),
                @"default"     : @"miter",
                @"optionalFor" : PRIMITIVES,
            },
            @"strokeWidth" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"number",
                @"default"     : @([NSBezierPath defaultLineWidth]),
                @"nullable"    : @(YES),
                @"optionalFor" : PRIMITIVES,
            },
            @"text" : @{
                @"class"       : @[ [NSString class], [NSNumber class], [NSAttributedString class] ],
                @"luaClass"    : @"string or hs.styledText object",
                @"default"     : @"",
                @"nullable"    : @(YES),
                @"requiredFor" : @[ @"text" ],
            },
            @"textAlignment" : @{
                @"class"       : @[ [NSString class] ],
                @"luaClass"    : @"string",
                @"values"      : TEXTALIGNMENT_TYPES.allKeys,
                @"nullable"    : @(YES),
                @"default"     : @"natural",
                @"optionalFor" : @[ @"text" ],
            },
            @"textColor" : @{
                @"class"       : @[ [NSColor class] ],
                @"luaClass"    : @"hs.drawing.color table",
                @"nullable"    : @(YES),
                @"default"     : [NSColor colorWithCalibratedWhite:1.0 alpha:1.0],
                @"optionalFor" : @[ @"text" ],
            },
            @"textFont" : @{
                @"class"       : @[ [NSString class] ],
                @"luaClass"    : @"string",
                @"nullable"    : @(YES),
                @"default"     : [[NSFont systemFontOfSize:0] fontName],
                @"optionalFor" : @[ @"text" ],
            },
            @"textLineBreak" : @{
                @"class"       : @[ [NSString class] ],
                @"luaClass"    : @"string",
                @"values"      : TEXTWRAP_TYPES.allKeys,
                @"nullable"    : @(YES),
                @"default"     : @"wordWrap",
                @"optionalFor" : @[ @"text" ],
            },
            @"textSize" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"number",
                @"nullable"    : @(YES),
                @"default"     : @(27.0),
                @"optionalFor" : @[ @"text" ],
            },
            @"trackMouseByBounds" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"boolean",
                @"objCType"    : abtNSString,
                @"nullable"    : @(YES),
                @"default"     : @(NO),
                @"optionalFor" : VISIBLE,
            },
            @"trackMouseEnterExit" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"boolean",
                @"objCType"    : abtNSString,
                @"nullable"    : @(YES),
                @"default"     : @(NO),
                @"optionalFor" : VISIBLE,
            },
            @"trackMouseDown" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"boolean",
                @"objCType"    : abtNSString,
                @"nullable"    : @(YES),
                @"default"     : @(NO),
                @"optionalFor" : VISIBLE,
            },
            @"trackMouseUp" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"boolean",
                @"objCType"    : abtNSString,
                @"nullable"    : @(YES),
                @"default"     : @(NO),
                @"optionalFor" : VISIBLE,
            },
            @"trackMouseMove" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"boolean",
                @"objCType"    : abtNSString,
                @"nullable"    : @(YES),
                @"default"     : @(NO),
                @"optionalFor" : VISIBLE,
            },
            @"transformation" : @{
                @"class"       : @[ [NSAffineTransform class] ],
                @"luaClass"    : @"transform table",
                @"nullable"    : @(YES),
                @"default"     : [NSAffineTransform transform],
                @"optionalFor" : VISIBLE,
            },
            @"type" : @{
                @"class"       : @[ [NSString class] ],
                @"luaClass"    : @"string",
                @"values"      : ALL_TYPES,
                @"nullable"    : @(NO),
                @"requiredFor" : ALL_TYPES,
            },
            @"windingRule" : @{
                @"class"       : @[ [NSString class] ],
                @"luaClass"    : @"string",
                @"values"      : WINDING_RULES.allKeys,
                @"nullable"    : @(YES),
                @"default"     : @"nonZero",
                @"optionalFor" : PRIMITIVES,
            },
            @"withShadow" : @{
                @"class"       : @[ [NSNumber class] ],
                @"luaClass"    : @"boolean",
                @"objCType"    : abtNSString,
                @"nullable"    : @(YES),
                @"default"     : @(NO),
                @"optionalFor" : PRIMITIVES,
            },
        } ;
    }
}

static attributeValidity isValueValidForDictionary(NSString *keyName, NSObject *keyValue, NSDictionary *attributeDefinition) {
    __block attributeValidity validity = attributeValid ;
    __block NSString          *errorMessage ;

    BOOL checked = NO ;
    while (!checked) {  // doing this as a loop so we can break out as soon as we know enough
        checked = YES ; // but we really don't want to loop

        if (!keyValue || [keyValue isKindOfClass:[NSNull class]]) {
            if (attributeDefinition[@"nullable"] && [(NSNumber *)attributeDefinition[@"nullable"] boolValue]) {
                validity = attributeNulling ;
            } else {
                errorMessage = [NSString stringWithFormat:@"%@ is not nullable", keyName] ;
            }
            break ;
        }

        if ([(NSObject *)attributeDefinition[@"class"] isKindOfClass:[NSArray class]]) {
            BOOL found = NO ;
            for (NSUInteger i = 0 ; i < [(NSArray *)attributeDefinition[@"class"] count] ; i++) {
                found = [keyValue isKindOfClass:attributeDefinition[@"class"][i]] ;
                if (found) break ;
            }
            if (!found) {
                errorMessage = [NSString stringWithFormat:@"%@ must be a %@", keyName, attributeDefinition[@"luaClass"]] ;
                break ;
            }
        } else {
            if (![keyValue isKindOfClass:attributeDefinition[@"class"]]) {
                errorMessage = [NSString stringWithFormat:@"%@ must be a %@", keyName, attributeDefinition[@"luaClass"]] ;
                break ;
            }
        }

        if (attributeDefinition[@"objCType"]) {
            if (strcmp([(NSString *)attributeDefinition[@"objCType"] UTF8String], [(NSNumber *)keyValue objCType])) {
                errorMessage = [NSString stringWithFormat:@"%@ must be a %@", keyName, attributeDefinition[@"luaClass"]] ;
                break ;
            }
        }

        if ([keyValue isKindOfClass:[NSNumber class]] && !attributeDefinition[@"objCType"]) {
          if (!isfinite([(NSNumber *)keyValue doubleValue])) {
              errorMessage = [NSString stringWithFormat:@"%@ must be a finite number", keyName] ;
              break ;
          }
        }


        if (attributeDefinition[@"values"]) {
            BOOL found = NO ;
            for (NSUInteger i = 0 ; i < [(NSArray *)attributeDefinition[@"values"] count] ; i++) {
                found = [(NSString *)attributeDefinition[@"values"][i] isEqualToString:(NSString *)keyValue] ;
                if (found) break ;
            }
            if (!found) {
                errorMessage = [NSString stringWithFormat:@"%@ must be one of %@", keyName, [(NSArray *)attributeDefinition[@"values"] componentsJoinedByString:@", "]] ;
                break ;
            }
        }

        if (attributeDefinition[@"maxNumber"]) {
            if ([(NSNumber *)keyValue doubleValue] > [(NSNumber *)attributeDefinition[@"maxNumber"] doubleValue]) {
                errorMessage = [NSString stringWithFormat:@"%@ must be <= %f", keyName, [(NSNumber *)attributeDefinition[@"maxNumber"] doubleValue]] ;
                break ;
            }
        }

        if (attributeDefinition[@"minNumber"]) {
            if ([(NSNumber *)keyValue doubleValue] < [(NSNumber *)attributeDefinition[@"minNumber"] doubleValue]) {
                errorMessage = [NSString stringWithFormat:@"%@ must be >= %f", keyName, [(NSNumber *)attributeDefinition[@"minNumber"] doubleValue]] ;
                break ;
            }
        }

        if ([keyValue isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *keyValueAsMDictionary = (NSMutableDictionary *)keyValue ;
            NSDictionary *subKeys = attributeDefinition[@"keys"] ;
            for (NSString *subKeyName in subKeys) {
                NSDictionary *subKeyMiniDefinition = subKeys[subKeyName] ;
                if ([(NSObject *)subKeyMiniDefinition[@"class"] isKindOfClass:[NSArray class]]) {
                    BOOL found = NO ;
                    for (NSUInteger i = 0 ; i < [(NSArray *)subKeyMiniDefinition[@"class"] count] ; i++) {
                        found = [(NSObject *)keyValueAsMDictionary[subKeyName] isKindOfClass:((NSArray *)subKeyMiniDefinition[@"class"])[i]] ;
                        if (found) break ;
                    }
                    if (!found) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be a %@", subKeyName, keyName, subKeyMiniDefinition[@"luaClass"]] ;
                        break ;
                    }
                } else {
                    if (![(NSObject *)keyValueAsMDictionary[subKeyName] isKindOfClass:subKeyMiniDefinition[@"class"]]) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be a %@", subKeyName, keyName, subKeyMiniDefinition[@"luaClass"]] ;
                        break ;
                    }
                }

                if (subKeyMiniDefinition[@"objCType"]) {
                    if (strcmp([(NSString *)subKeyMiniDefinition[@"objCType"] UTF8String], [(NSNumber *)keyValueAsMDictionary[subKeyName] objCType])) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be a %@", subKeyName, keyName, subKeyMiniDefinition[@"luaClass"]] ;
                        break ;
                    }
                }

                if ([(NSObject *)keyValueAsMDictionary[subKeyName] isKindOfClass:[NSNumber class]] && !subKeyMiniDefinition[@"objCType"]) {
                  if (!isfinite([(NSNumber *)keyValueAsMDictionary[subKeyName] doubleValue])) {
                      errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be a finite number", subKeyName, keyName] ;
                      break ;
                  }
                }

                if (subKeyMiniDefinition[@"values"]) {
                    BOOL found = NO ;
                    NSString *subKeyValue = keyValueAsMDictionary[subKeyName] ;
                    for (NSUInteger i = 0 ; i < [(NSArray *)subKeyMiniDefinition[@"values"] count] ; i++) {
                        found = [(NSString *)subKeyMiniDefinition[@"values"][i] isEqualToString:subKeyValue] ;
                        if (found) break ;
                    }
                    if (!found) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be one of %@", subKeyName, keyName, [(NSArray *)subKeyMiniDefinition[@"values"] componentsJoinedByString:@", "]] ;
                        break ;
                    }
                }

                if (subKeyMiniDefinition[@"maxNumber"]) {
                    if ([(NSNumber *)keyValueAsMDictionary[subKeyName] doubleValue] > [(NSNumber *)subKeyMiniDefinition[@"maxNumber"] doubleValue]) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be <= %f", subKeyName, keyName, [(NSNumber *)subKeyMiniDefinition[@"maxNumber"] doubleValue]] ;
                        break ;
                    }
                }

                if (subKeyMiniDefinition[@"minNumber"]) {
                    if ([(NSNumber *)keyValueAsMDictionary[subKeyName] doubleValue] < [(NSNumber *)subKeyMiniDefinition[@"minNumber"] doubleValue]) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be >= %f", subKeyName, keyName, [(NSNumber *)subKeyMiniDefinition[@"minNumber"] doubleValue]] ;
                        break ;
                    }
                }

            }
            if (errorMessage) break ;
        }

        if ([keyValue isKindOfClass:[NSArray class]]) {
            BOOL isGood = YES ;
            if ([(NSArray *)keyValue count] > 0) {
                for (NSUInteger i = 0 ; i < [(NSArray *)keyValue count] ; i++) {
                    if (![(NSObject *)((NSArray *)keyValue)[i] isKindOfClass:attributeDefinition[@"memberClass"]]) {
                        isGood = NO ;
                        break ;
                    } else if ([(NSObject *)((NSArray *)keyValue)[i] isKindOfClass:[NSDictionary class]]) {
                        [(NSDictionary *)((NSArray *)keyValue)[i] enumerateKeysAndObjectsUsingBlock:^(NSString *subKey, id obj, BOOL *stop) {
                            NSDictionary *subKeyDefinition = attributeDefinition[@"memberClassKeys"][subKey] ;
                            if (subKeyDefinition) {
                                validity = isValueValidForDictionary(subKey, obj, subKeyDefinition) ;
                            } else {
                                validity = attributeInvalid ;
                                errorMessage = [NSString stringWithFormat:@"%@ is not a valid subkey for a %@ value", subKey, attributeDefinition[@"memberLuaClass"]] ;
                            }
                            if (validity != attributeValid) *stop = YES ;
                        }] ;
                    }
                }
                if (!isGood) {
                    errorMessage = [NSString stringWithFormat:@"%@ must be an array of %@ values", keyName, attributeDefinition[@"memberLuaClass"]] ;
                    break ;
                }
            }
        }

        if ([keyName isEqualToString:@"textFont"]) {
            NSFont *testFont = [NSFont fontWithName:(NSString *)keyValue size:0.0] ;
            if (!testFont) {
                errorMessage = [NSString stringWithFormat:@"%@ is not a recognized font name", keyValue] ;
                break ;
            }
        }
    }
    if (errorMessage) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:%@", USERDATA_TAG, errorMessage]] ;
        validity = attributeInvalid ;
    }
    return validity ;
}

static attributeValidity isValueValidForAttribute(NSString *keyName, id keyValue) {
    NSDictionary      *attributeDefinition = languageDictionary[keyName] ;
    if (attributeDefinition) {
        return isValueValidForDictionary(keyName, keyValue, attributeDefinition) ;
    } else {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:%@ is not a valid canvas attribute", USERDATA_TAG, keyName]] ;
        return attributeInvalid ;
    }
}

static NSNumber *convertPercentageStringToNumber(NSString *stringValue) {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.locale = [NSLocale currentLocale] ;

    formatter.numberStyle = NSNumberFormatterDecimalStyle ;
    NSNumber *tmpValue = [formatter numberFromString:stringValue] ;
    if (!tmpValue) {
        formatter.numberStyle = NSNumberFormatterPercentStyle ;
        tmpValue = [formatter numberFromString:stringValue] ;
    }
    // just to be sure, let's also check with the en_US locale
    if (!tmpValue) {
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"] ;
        formatter.numberStyle = NSNumberFormatterDecimalStyle ;
        tmpValue = [formatter numberFromString:stringValue] ;
        if (!tmpValue) {
            formatter.numberStyle = NSNumberFormatterPercentStyle ;
            tmpValue = [formatter numberFromString:stringValue] ;
        }
    }
    return tmpValue ;
}

static inline CGFloat xLeftInRect(__unused NSSize innerSize, NSRect outerRect) {
    return NSMinX(outerRect);
}

static inline CGFloat xCenterInRect(NSSize innerSize, NSRect outerRect) {
    return NSMidX(outerRect) - (innerSize.width/2.0);
}

static inline CGFloat xRightInRect(NSSize innerSize, NSRect outerRect) {
    return NSMaxX(outerRect) - innerSize.width;
}

static inline CGFloat yTopInRect(NSSize innerSize, NSRect outerRect, BOOL flipped) {
    if (flipped)
        return NSMinY(outerRect);
    else
        return NSMaxY(outerRect) - innerSize.height;
}

static inline CGFloat yCenterInRect(NSSize innerSize, NSRect outerRect, __unused BOOL flipped) {
    return NSMidY(outerRect) - innerSize.height/2.0;
}

static inline CGFloat yBottomInRect(NSSize innerSize, NSRect outerRect, BOOL flipped) {
    if (flipped)
        return NSMaxY(outerRect) - innerSize.height;
    else
        return NSMinY(outerRect);
}

static inline NSSize scaleProportionally(NSSize imageSize, NSSize canvasSize, BOOL scaleUpOrDown) {
    CGFloat ratio;
    if (imageSize.width <= 0 || imageSize.height <= 0) {
        return NSMakeSize(0, 0);
    }
    /* Get the smaller ratio and scale the image size by it.  */
    ratio = fmin(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height);
    /* Only scale down, unless scaleUpOrDown is YES */
    if (ratio < 1.0 || scaleUpOrDown) {
        imageSize.width *= ratio;
        imageSize.height *= ratio;
    }
    return imageSize;
}

// static inline NSRect RectWithFlippedYCoordinate(NSRect theRect) {
//     return NSMakeRect(theRect.origin.x,
//                       [[NSScreen screens][0] frame].size.height - theRect.origin.y - theRect.size.height,
//                       theRect.size.width,
//                       theRect.size.height) ;
// }

#pragma mark - Class Implementations -

@implementation HSUITKElementCanvas {
    NSTrackingArea *_trackingArea ;
    NSSize         _assignedSize ;
}

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
        _refTable       = refTable ;
        _selfRefCount   = 0 ;

        _assignedSize          = frameRect.size ;
        _mouseCallbackRef      = LUA_NOREF ;
        _draggingCallbackRef   = LUA_NOREF ;
        _canvasDefaults        = [[NSMutableDictionary alloc] init] ;
        _elementList           = [[NSMutableArray alloc] init] ;
        _elementBounds         = [[NSMutableArray alloc] init] ;
        _canvasTransform       = [NSAffineTransform transform] ;
        _imageAnimations       = [NSMapTable weakToStrongObjectsMapTable] ;

        _canvasMouseDown       = NO ;
        _canvasMouseUp         = NO ;
        _canvasMouseEnterExit  = NO ;
        _canvasMouseMove       = NO ;

        _mouseTracking         = NO ;
        _previousTrackedIndex  = NSNotFound ;

        self.postsFrameChangedNotifications = YES ;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(frameChangedNotification:)
                                                     name:NSViewFrameDidChangeNotification
                                                   object:nil] ;

        _trackingArea = [[NSTrackingArea alloc] initWithRect:frameRect
                                                     options:(NSTrackingMouseMoved |
                                                             NSTrackingMouseEnteredAndExited |
                                                             NSTrackingActiveAlways |
                                                             NSTrackingInVisibleRect)
                                                       owner:self
                                                    userInfo:nil] ;
        [self addTrackingArea:_trackingArea] ;

    }
    return self ;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSViewFrameDidChangeNotification
                                                  object:nil] ;
    [self removeTrackingArea:_trackingArea] ;
    _trackingArea = nil ;
}

- (NSSize)fittingSize { return _assignedSize ; }

- (BOOL)isFlipped { return YES; }

- (void)frameChangedNotification:(NSNotification *)notification {
    NSView *targetView = notification.object ;
    if (targetView && [targetView isEqualTo:self]) {
        _assignedSize = self.frame.size ;
    }
}

- (BOOL)acceptsFirstMouse:(__unused NSEvent *)theEvent {
    if (self.window == nil) return NO;
    return !self.window.ignoresMouseEvents;
}

- (BOOL)canBecomeKeyView {
    __block BOOL allowKey = NO ;
//     [_elementList enumerateObjectsUsingBlock:^(NSDictionary *element, __unused NSUInteger idx, BOOL *stop) {
//         if (element[@"canvas"] && [element[@"canvas"] respondsToSelector:@selector(canBecomeKeyView)]) {
//             allowKey = [element[@"canvas"] canBecomeKeyView] ;
//             *stop = YES ;
//         }
//     }] ;
    return allowKey ;
}

- (void)mouseMoved:(NSEvent *)theEvent {
    BOOL canvasMouseEvents = _canvasMouseEnterExit || _canvasMouseMove ;

    if ((_mouseCallbackRef != LUA_NOREF) && (_mouseTracking || canvasMouseEvents)) {
        NSPoint event_location = theEvent.locationInWindow;
        NSPoint local_point = [self convertPoint:event_location fromView:nil];

        __block NSUInteger targetIndex = NSNotFound ;
        __block NSPoint actualPoint = local_point ;

        [_elementBounds enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSDictionary *box, NSUInteger idx, BOOL *stop) {
            NSUInteger elementIdx  = [(NSNumber *)box[@"index"] unsignedIntegerValue] ;
            if ([(NSNumber *)[self getElementValueFor:@"trackMouseEnterExit" atIndex:elementIdx] boolValue] || [(NSNumber *)[self getElementValueFor:@"trackMouseMove" atIndex:elementIdx] boolValue]) {
                NSAffineTransform *pointTransform = [self->_canvasTransform copy] ;
                [pointTransform appendTransform:(NSAffineTransform *)[self getElementValueFor:@"transformation" atIndex:elementIdx]] ;
                [pointTransform invert] ;
                if (box[@"imageByBounds"] && ![(NSNumber *)box[@"imageByBounds"] boolValue]) {
                    NSImage *theImage = self->_elementList[elementIdx][@"image"] ;
                    if (theImage) {
                        NSRect hitRect = NSMakeRect(actualPoint.x, actualPoint.y, 1.0, 1.0) ;
                        NSRect imageRect = [(NSValue *)box[@"frame"] rectValue] ;
                        if ([theImage hitTestRect:hitRect withImageDestinationRect:imageRect
                                                                           context:nil
                                                                             hints:nil
                                                                           flipped:YES]) {
                            targetIndex = idx ;
                            *stop = YES ;
                        }
                    }
                } else if ((box[@"frame"] && NSPointInRect(actualPoint, [(NSValue *)box[@"frame"] rectValue])) || (box[@"path"] && [(NSBezierPath *)box[@"path"] containsPoint:actualPoint])) {
                    targetIndex = idx ;
                    *stop = YES ;
                }
            }
        }] ;

        NSUInteger realTargetIndex = (targetIndex != NSNotFound) ?
                    [(NSNumber *)_elementBounds[targetIndex][@"index"] unsignedIntegerValue]  : NSNotFound ;
        NSUInteger realPrevIndex = (_previousTrackedIndex != NSNotFound) ?
                    [(NSNumber *)_elementBounds[_previousTrackedIndex][@"index"] unsignedIntegerValue]  : NSNotFound ;

        if (_previousTrackedIndex == targetIndex) {
            if ((targetIndex != NSNotFound) && [(NSNumber *)[self getElementValueFor:@"trackMouseMove" atIndex:realPrevIndex] boolValue]) {
                NSObject *targetID = [self getElementValueFor:@"id" atIndex:realPrevIndex onlyIfSet:YES] ;
                if (!targetID) targetID = @(realPrevIndex + 1) ;
                [self doMouseCallback:@"mouseMove" for:targetID at:local_point] ;
            }
        } else {
            if ((_previousTrackedIndex != NSNotFound) && [(NSNumber *)[self getElementValueFor:@"trackMouseEnterExit" atIndex:realPrevIndex] boolValue]) {
                NSObject *targetID = [self getElementValueFor:@"id" atIndex:realPrevIndex onlyIfSet:YES] ;
                if (!targetID) targetID = @(realPrevIndex + 1) ;
                [self doMouseCallback:@"mouseExit" for:targetID at:local_point] ;
            }
            if (targetIndex != NSNotFound) {
                NSObject *targetID = [self getElementValueFor:@"id" atIndex:realTargetIndex onlyIfSet:YES] ;
                if (!targetID) targetID = @(realTargetIndex + 1) ;
                if ([(NSNumber *)[self getElementValueFor:@"trackMouseEnterExit" atIndex:realTargetIndex] boolValue]) {
                    [self doMouseCallback:@"mouseEnter" for:targetID at:local_point] ;
                } else if ([(NSNumber *)[self getElementValueFor:@"trackMouseMove" atIndex:realTargetIndex] boolValue]) {
                    [self doMouseCallback:@"mouseMove" for:targetID at:local_point] ;
                }
                if (_canvasMouseEnterExit && (_previousTrackedIndex == NSNotFound)) {
                    [self doMouseCallback:@"mouseExit" for:@"_canvas_" at:local_point] ;
                }
            }
        }

        if ((_canvasMouseEnterExit || _canvasMouseMove) && (targetIndex == NSNotFound)) {
            if (_previousTrackedIndex == NSNotFound && _canvasMouseMove) {
                [self doMouseCallback:@"mouseMove" for:@"_canvas_" at:local_point] ;
            } else if (_previousTrackedIndex != NSNotFound && _canvasMouseEnterExit) {
                [self doMouseCallback:@"mouseEnter" for:@"_canvas_" at:local_point] ;
            }
        }
        _previousTrackedIndex = targetIndex ;
    }
}

- (void)mouseEntered:(NSEvent *)theEvent {
    if ((_mouseCallbackRef != LUA_NOREF) && _canvasMouseEnterExit) {
        NSPoint event_location = theEvent.locationInWindow;
        NSPoint local_point = [self convertPoint:event_location fromView:nil];

        [self doMouseCallback:@"mouseEnter" for:@"_canvas_" at:local_point] ;
    }
}

- (void)mouseExited:(NSEvent *)theEvent {
    BOOL canvasMouseEvents = _canvasMouseEnterExit || _canvasMouseMove ;

    if ((_mouseCallbackRef != LUA_NOREF) && (_mouseTracking || canvasMouseEvents)) {
        NSPoint event_location = theEvent.locationInWindow;
        NSPoint local_point = [self convertPoint:event_location fromView:nil];
        if (_previousTrackedIndex != NSNotFound) {
            NSUInteger realPrevIndex = (_previousTrackedIndex != NSNotFound) ?
                    [(NSNumber *)_elementBounds[_previousTrackedIndex][@"index"] unsignedIntegerValue]  : NSNotFound ;
            if ([(NSNumber *)[self getElementValueFor:@"trackMouseEnterExit" atIndex:realPrevIndex] boolValue]) {
                NSObject *targetID = [self getElementValueFor:@"id" atIndex:realPrevIndex onlyIfSet:YES] ;
                if (!targetID) targetID = @(realPrevIndex + 1) ;
                [self doMouseCallback:@"mouseExit" for:targetID at:local_point] ;
            }
        }
        if (_canvasMouseEnterExit) {
            [self doMouseCallback:@"mouseExit" for:@"_canvas_" at:local_point] ;
        }
    }
    _previousTrackedIndex = NSNotFound ;
}

- (void)doMouseCallback:(NSString *)message for:(NSObject *)elementIdentifier at:(NSPoint)location {
    if (elementIdentifier && _mouseCallbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:_mouseCallbackRef];
        [skin pushNSObject:self] ;
        [skin pushNSObject:message] ;
        [skin pushNSObject:elementIdentifier] ;
        lua_pushnumber(skin.L, location.x) ;
        lua_pushnumber(skin.L, location.y) ;
        [skin protectedCallAndError:[NSString stringWithFormat:@"%s:clickCallback for %@", USERDATA_TAG, message] nargs:5 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

- (void)mouseDown:(NSEvent *)theEvent {
    [NSApp preventWindowOrdering];
    if (_mouseCallbackRef != LUA_NOREF) {
        BOOL isDown = (theEvent.type == NSEventTypeLeftMouseDown)  ||
                      (theEvent.type == NSEventTypeRightMouseDown) ||
                      (theEvent.type == NSEventTypeOtherMouseDown) ;

        NSPoint event_location = theEvent.locationInWindow;
        NSPoint local_point = [self convertPoint:event_location fromView:nil];
//         [LuaSkin logWarn:[NSString stringWithFormat:@"mouse click at (%f, %f)", local_point.x, local_point.y]] ;

        __block id targetID = nil ;
        __block NSPoint actualPoint = local_point ;

        [_elementBounds enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSDictionary *box, __unused NSUInteger idx, BOOL *stop) {
            NSUInteger elementIdx  = [(NSNumber *)box[@"index"] unsignedIntegerValue] ;
            if ([(NSNumber *)[self getElementValueFor:(isDown ? @"trackMouseDown" : @"trackMouseUp") atIndex:elementIdx] boolValue]) {
                NSAffineTransform *pointTransform = [self->_canvasTransform copy] ;
                [pointTransform appendTransform:(NSAffineTransform *)[self getElementValueFor:@"transformation" atIndex:elementIdx]] ;
                [pointTransform invert] ;
                actualPoint = [pointTransform transformPoint:local_point] ;
                if (box[@"imageByBounds"] && ![(NSNumber *)box[@"imageByBounds"] boolValue]) {
                    NSImage *theImage = self->_elementList[elementIdx][@"image"] ;
                    if (theImage) {
                        NSRect hitRect = NSMakeRect(actualPoint.x, actualPoint.y, 1.0, 1.0) ;
                        NSRect imageRect = [(NSValue *)box[@"frame"] rectValue] ;
                        if ([theImage hitTestRect:hitRect withImageDestinationRect:imageRect
                                                                           context:nil
                                                                             hints:nil
                                                                           flipped:YES]) {
                        targetID = [self getElementValueFor:@"id" atIndex:elementIdx onlyIfSet:YES] ;
                        if (!targetID) targetID = @(elementIdx + 1) ;
                            *stop = YES ;
                        }
                    }
                } else if ((box[@"frame"] && NSPointInRect(actualPoint, [(NSValue *)box[@"frame"] rectValue])) || (box[@"path"] && [(NSBezierPath *)box[@"path"] containsPoint:actualPoint])) {
                    targetID = [self getElementValueFor:@"id" atIndex:elementIdx onlyIfSet:YES] ;
                    if (!targetID) targetID = @(elementIdx + 1) ;
                    *stop = YES ;
                }
                if (*stop) {
                    if (isDown && [(NSNumber *)[self getElementValueFor:@"trackMouseDown" atIndex:elementIdx] boolValue]) {
                        [self doMouseCallback:@"mouseDown" for:targetID at:local_point] ;
                    }
                    if (!isDown && [(NSNumber *)[self getElementValueFor:@"trackMouseUp" atIndex:elementIdx] boolValue]) {
                        [self doMouseCallback:@"mouseUp" for:targetID at:local_point] ;
                    }
                }
            }
        }] ;

        if (!targetID) {
            if (isDown && _canvasMouseDown) {
                [self doMouseCallback:@"mouseDown" for:@"_canvas_" at:local_point] ;
            } else if (!isDown && _canvasMouseUp) {
                [self doMouseCallback:@"mouseUp" for:@"_canvas_" at:local_point] ;
            }
        }
    }
}

- (void)rightMouseDown:(NSEvent *)theEvent { [self mouseDown:theEvent] ; }
- (void)otherMouseDown:(NSEvent *)theEvent { [self mouseDown:theEvent] ; }
- (void)mouseUp:(NSEvent *)theEvent        { [self mouseDown:theEvent] ; }
- (void)rightMouseUp:(NSEvent *)theEvent   { [self mouseDown:theEvent] ; }
- (void)otherMouseUp:(NSEvent *)theEvent   { [self mouseDown:theEvent] ; }

- (NSBezierPath *)pathForElementAtIndex:(NSUInteger)idx {
    NSDictionary *frame = (NSDictionary *)[self getElementValueFor:@"frame" atIndex:idx resolvePercentages:YES] ;
    NSRect frameRect = NSMakeRect([(NSNumber *)frame[@"x"] doubleValue], [(NSNumber *)frame[@"y"] doubleValue],
                                  [(NSNumber *)frame[@"w"] doubleValue], [(NSNumber *)frame[@"h"] doubleValue]) ;
    return [self pathForElementAtIndex:idx withFrame:frameRect] ;
}

- (NSBezierPath *)pathForElementAtIndex:(NSUInteger)idx withFrame:(NSRect)frameRect {
    NSBezierPath *elementPath = nil ;
    NSString     *elementType = (NSString *)[self getElementValueFor:@"type" atIndex:idx] ;

#pragma mark ARC
    if ([elementType isEqualToString:@"arc"]) {
        NSDictionary *center = (NSDictionary *)[self getElementValueFor:@"center" atIndex:idx resolvePercentages:YES] ;
        CGFloat cx = [(NSNumber *)center[@"x"] doubleValue] ;
        CGFloat cy = [(NSNumber *)center[@"y"] doubleValue] ;
        CGFloat r  = [(NSNumber *)[self getElementValueFor:@"radius" atIndex:idx resolvePercentages:YES] doubleValue] ;
        NSPoint myCenterPoint = NSMakePoint(cx, cy) ;
        elementPath = [NSBezierPath bezierPath];
        CGFloat startAngle = [(NSNumber *)[self getElementValueFor:@"startAngle" atIndex:idx] doubleValue] - 90 ;
        CGFloat endAngle   = [(NSNumber *)[self getElementValueFor:@"endAngle" atIndex:idx] doubleValue] - 90 ;
        BOOL    arcDir     = [(NSNumber *)[self getElementValueFor:@"arcClockwise" atIndex:idx] boolValue] ;
        BOOL    arcLegs    = [(NSNumber *)[self getElementValueFor:@"arcRadii" atIndex:idx] boolValue] ;
        if (arcLegs) [elementPath moveToPoint:myCenterPoint] ;
        [elementPath appendBezierPathWithArcWithCenter:myCenterPoint
                                                radius:r
                                            startAngle:startAngle
                                              endAngle:endAngle
                                             clockwise:!arcDir // because our canvas is flipped, we have to reverse this
        ] ;
        if (arcLegs) [elementPath lineToPoint:myCenterPoint] ;
    } else
#pragma mark CIRCLE
    if ([elementType isEqualToString:@"circle"]) {
        NSDictionary *center = (NSDictionary *)[self getElementValueFor:@"center" atIndex:idx resolvePercentages:YES] ;
        CGFloat cx = [(NSNumber *)center[@"x"] doubleValue] ;
        CGFloat cy = [(NSNumber *)center[@"y"] doubleValue] ;
        CGFloat r  = [(NSNumber *)[self getElementValueFor:@"radius" atIndex:idx resolvePercentages:YES] doubleValue] ;
        elementPath = [NSBezierPath bezierPath];
        [elementPath appendBezierPathWithOvalInRect:NSMakeRect(cx - r, cy - r, r * 2, r * 2)] ;
    } else
#pragma mark ELLIPTICALARC
    if ([elementType isEqualToString:@"ellipticalArc"]) {
        CGFloat cx     = frameRect.origin.x + frameRect.size.width / 2 ;
        CGFloat cy     = frameRect.origin.y + frameRect.size.height / 2 ;
        CGFloat r      = frameRect.size.width / 2 ;

        NSAffineTransform *moveTransform = [NSAffineTransform transform] ;
        [moveTransform translateXBy:cx yBy:cy] ;
        NSAffineTransform *scaleTransform = [NSAffineTransform transform] ;
        [scaleTransform scaleXBy:1.0 yBy:(frameRect.size.height / frameRect.size.width)] ;
        NSAffineTransform *finalTransform = [[NSAffineTransform alloc] initWithTransform:scaleTransform] ;
        [finalTransform appendTransform:moveTransform] ;
        elementPath = [NSBezierPath bezierPath];
        CGFloat startAngle = [(NSNumber *)[self getElementValueFor:@"startAngle" atIndex:idx] doubleValue] - 90 ;
        CGFloat endAngle   = [(NSNumber *)[self getElementValueFor:@"endAngle" atIndex:idx] doubleValue] - 90 ;
        BOOL    arcDir     = [(NSNumber *)[self getElementValueFor:@"arcClockwise" atIndex:idx] boolValue] ;
        BOOL    arcLegs    = [(NSNumber *)[self getElementValueFor:@"arcRadii" atIndex:idx] boolValue] ;
        if (arcLegs) [elementPath moveToPoint:NSZeroPoint] ;
        [elementPath appendBezierPathWithArcWithCenter:NSZeroPoint
                                                radius:r
                                            startAngle:startAngle
                                              endAngle:endAngle
                                             clockwise:!arcDir // because our canvas is flipped, we have to reverse this
        ] ;
        if (arcLegs) [elementPath lineToPoint:NSZeroPoint] ;
        elementPath = [finalTransform transformBezierPath:elementPath] ;
    } else
#pragma mark OVAL
    if ([elementType isEqualToString:@"oval"]) {
        elementPath = [NSBezierPath bezierPath];
        [elementPath appendBezierPathWithOvalInRect:frameRect] ;
    } else
#pragma mark RECTANGLE
    if ([elementType isEqualToString:@"rectangle"]) {
        elementPath = [NSBezierPath bezierPath];
        NSDictionary *roundedRect = (NSDictionary *)[self getElementValueFor:@"roundedRectRadii" atIndex:idx] ;
        [elementPath appendBezierPathWithRoundedRect:frameRect
                                          xRadius:[(NSNumber *)roundedRect[@"xRadius"] doubleValue]
                                          yRadius:[(NSNumber *)roundedRect[@"yRadius"] doubleValue]] ;
    } else
#pragma mark POINTS
    if ([elementType isEqualToString:@"points"]) {
        elementPath = [NSBezierPath bezierPath];
        NSArray *coordinates = (NSArray *)[self getElementValueFor:@"coordinates" atIndex:idx resolvePercentages:YES] ;

        [coordinates enumerateObjectsUsingBlock:^(NSDictionary *aPoint, __unused NSUInteger idx2, __unused BOOL *stop2) {
            NSNumber *xNumber   = aPoint[@"x"] ;
            NSNumber *yNumber   = aPoint[@"y"] ;
            [elementPath appendBezierPathWithRect:NSMakeRect([xNumber doubleValue], [yNumber doubleValue], 1.0, 1.0)] ;
        }] ;
    } else
#pragma mark SEGMENTS
    if ([elementType isEqualToString:@"segments"]) {
        elementPath = [NSBezierPath bezierPath];
        NSArray *coordinates = (NSArray *)[self getElementValueFor:@"coordinates" atIndex:idx resolvePercentages:YES] ;

        [coordinates enumerateObjectsUsingBlock:^(NSDictionary *aPoint, NSUInteger idx2, __unused BOOL *stop2) {
            NSNumber *xNumber   = aPoint[@"x"] ;
            NSNumber *yNumber   = aPoint[@"y"] ;
            NSNumber *c1xNumber = aPoint[@"c1x"] ;
            NSNumber *c1yNumber = aPoint[@"c1y"] ;
            NSNumber *c2xNumber = aPoint[@"c2x"] ;
            NSNumber *c2yNumber = aPoint[@"c2y"] ;
            BOOL goodForCurve = (c1xNumber) && (c1yNumber) && (c2xNumber) && (c2yNumber) ;
            if (idx2 == 0) {
                [elementPath moveToPoint:NSMakePoint([xNumber doubleValue], [yNumber doubleValue])] ;
            } else if (!goodForCurve) {
                [elementPath lineToPoint:NSMakePoint([xNumber doubleValue], [yNumber doubleValue])] ;
            } else {
                [elementPath curveToPoint:NSMakePoint([xNumber doubleValue], [yNumber doubleValue])
                            controlPoint1:NSMakePoint([c1xNumber doubleValue], [c1yNumber doubleValue])
                            controlPoint2:NSMakePoint([c2xNumber doubleValue], [c2yNumber doubleValue])] ;
            }
        }] ;
        if ([(NSNumber *)[self getElementValueFor:@"closed" atIndex:idx] boolValue]) {
            [elementPath closePath] ;
        }
    }

    return elementPath ;
}

- (void)drawRect:(__unused NSRect)rect {
    NSGraphicsContext* gc = [NSGraphicsContext currentContext];
    [gc saveGraphicsState];

    [_canvasTransform concat] ;

    [NSBezierPath setDefaultLineWidth:[(NSNumber *)[self getDefaultValueFor:@"strokeWidth" onlyIfSet:NO] doubleValue]] ;
    [NSBezierPath setDefaultMiterLimit:[(NSNumber *)[self getDefaultValueFor:@"miterLimit" onlyIfSet:NO] doubleValue]] ;
    [NSBezierPath setDefaultFlatness:[(NSNumber *)[self getDefaultValueFor:@"flatness" onlyIfSet:NO] doubleValue]] ;

    NSString *LJS = (NSString *)[self getDefaultValueFor:@"strokeJoinStyle" onlyIfSet:NO] ;
    [NSBezierPath setDefaultLineJoinStyle:[(NSNumber *)STROKE_JOIN_STYLES[LJS] unsignedIntValue]] ;

    NSString *LCS = (NSString *)[self getDefaultValueFor:@"strokeCapStyle" onlyIfSet:NO] ;
    [NSBezierPath setDefaultLineJoinStyle:[(NSNumber *)STROKE_CAP_STYLES[LCS] unsignedIntValue]] ;

    NSString *WR = (NSString *)[self getDefaultValueFor:@"windingRule" onlyIfSet:NO] ;
    [NSBezierPath setDefaultWindingRule:[(NSNumber *)WINDING_RULES[WR] unsignedIntValue]] ;

    NSString *CS = (NSString *)[self getDefaultValueFor:@"compositeRule" onlyIfSet:NO] ;
    gc.compositingOperation = [(NSNumber *)COMPOSITING_TYPES[CS] unsignedIntValue] ;

//     [(NSNumber *)[self getDefaultValueFor:@"antialias" onlyIfSet:NO] boolValue] ;
    [(NSColor *)[self getDefaultValueFor:@"fillColor" onlyIfSet:NO] setFill] ;
    [(NSColor *)[self getDefaultValueFor:@"strokeColor" onlyIfSet:NO] setStroke] ;

    // because of changes to the elements, skip actions, etc, previous tracking info may change...
    NSUInteger previousTrackedRealIndex = NSNotFound ;
    if (_previousTrackedIndex != NSNotFound) {
        previousTrackedRealIndex = [(NSNumber *)_elementBounds[_previousTrackedIndex][@"index"] unsignedIntegerValue] ;
        _previousTrackedIndex = NSNotFound ;
    }

    _elementBounds = [[NSMutableArray alloc] init] ;

    // renderPath needs to persist through iterations, so define it here
    __block NSBezierPath *renderPath ;
    __block BOOL         clippingModified = NO ;
    __block BOOL         needMouseTracking = NO ;

    [_elementList enumerateObjectsUsingBlock:^(NSDictionary *element, NSUInteger idx, __unused BOOL *stop) {
        NSBezierPath *elementPath ;
        NSString     *elementType = element[@"type"] ;
        NSString     *action      = (NSString *)[self getElementValueFor:@"action" atIndex:idx] ;

        if (![action isEqualTo:@"skip"]) {
            if (!needMouseTracking) {
                needMouseTracking = [(NSNumber *)[self getElementValueFor:@"trackMouseEnterExit" atIndex:idx] boolValue] || [(NSNumber *)[self getElementValueFor:@"trackMouseMove" atIndex:idx] boolValue] ;
            }

            BOOL wasClippingChanged = NO ; // necessary to keep graphicsState stack properly ordered

            [gc saveGraphicsState] ;

            BOOL hasShadow = [(NSNumber *)[self getElementValueFor:@"withShadow" atIndex:idx] boolValue] ;
            if (hasShadow) [(NSShadow *)[self getElementValueFor:@"shadow" atIndex:idx] set] ;

            NSNumber *shouldAntialias = (NSNumber *)[self getElementValueFor:@"antialias" atIndex:idx onlyIfSet:YES] ;
            if (shouldAntialias) gc.shouldAntialias = [shouldAntialias boolValue] ;

            NSString *compositingString = (NSString *)[self getElementValueFor:@"compositeRule" atIndex:idx onlyIfSet:YES] ;
            if (compositingString) gc.compositingOperation = [(NSNumber *)COMPOSITING_TYPES[compositingString] unsignedIntValue] ;

            NSColor *fillColor = (NSColor *)[self getElementValueFor:@"fillColor" atIndex:idx onlyIfSet:YES] ;
            if (fillColor) [fillColor setFill] ;

            NSColor *strokeColor = (NSColor *)[self getElementValueFor:@"strokeColor" atIndex:idx onlyIfSet:YES] ;
            if (strokeColor) [strokeColor setStroke] ;

            NSAffineTransform *elementTransform = (NSAffineTransform *)[self getElementValueFor:@"transformation" atIndex:idx] ;
            if (elementTransform) [elementTransform concat] ;

            NSDictionary *frame = (NSDictionary *)[self getElementValueFor:@"frame" atIndex:idx resolvePercentages:YES] ;
            NSRect frameRect = NSMakeRect([(NSNumber *)frame[@"x"] doubleValue], [(NSNumber *)frame[@"y"] doubleValue],
                                          [(NSNumber *)frame[@"w"] doubleValue], [(NSNumber *)frame[@"h"] doubleValue]) ;

//             // Converts the corners of a specified rectangle to lie on the center of device pixels, which is useful in compensating for rendering overscanning when the coordinate system has been scaled.
//             frameRect = [self centerScanRect:frameRect] ;

            elementPath = [self pathForElementAtIndex:idx withFrame:frameRect] ;

            // First, if it's not a path, make sure it's not an element which doesn't have a path...

            if (!elementPath) {
#pragma mark IMAGE
                if ([elementType isEqualToString:@"image"]) {
                    NSImage *theImage = self->_elementList[idx][@"image"] ;
                    if (theImage && [theImage isKindOfClass:[NSImage class]]) {
                        [self drawImage:theImage
                                atIndex:idx
                                 inRect:frameRect
                              operation:[(NSNumber *)COMPOSITING_TYPES[CS] unsignedIntValue]] ;
                        [self->_elementBounds addObject:@{
                            @"index"         : @(idx),
                            @"frame"         : [NSValue valueWithRect:frameRect],
                            @"imageByBounds" : [self getElementValueFor:@"trackMouseByBounds" atIndex:idx]
                        }] ;
                    }
                    elementPath = nil ; // shouldn't be necessary, but lets be explicit
                } else
#pragma mark TEXT
                if ([elementType isEqualToString:@"text"]) {
                    NSObject *textEntry = [self getElementValueFor:@"text" atIndex:idx onlyIfSet:YES] ;
                    if (!textEntry) {
                        textEntry = @"" ;
                    } else if([textEntry isKindOfClass:[NSNumber class]]) {
                        textEntry = [(NSNumber *)textEntry stringValue] ;
                    }

                    if ([textEntry isKindOfClass:[NSString class]]) {
                        NSString *myFont = (NSString *)[self getElementValueFor:@"textFont" atIndex:idx onlyIfSet:NO] ;
                        NSNumber *mySize = (NSNumber *)[self getElementValueFor:@"textSize" atIndex:idx onlyIfSet:NO] ;
                        NSMutableParagraphStyle *theParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
                        NSString *alignment = (NSString *)[self getElementValueFor:@"textAlignment" atIndex:idx onlyIfSet:NO] ;
                        theParagraphStyle.alignment = [(NSNumber *)TEXTALIGNMENT_TYPES[alignment] unsignedIntValue] ;
                        NSString *wrap = (NSString *)[self getElementValueFor:@"textLineBreak" atIndex:idx onlyIfSet:NO] ;
                        theParagraphStyle.lineBreakMode = [(NSNumber *)TEXTWRAP_TYPES[wrap] unsignedIntValue] ;
                        NSFont *theFont = [NSFont fontWithName:myFont size:[mySize doubleValue]] ;
                        NSDictionary *attributes = @{
                            NSForegroundColorAttributeName : [self getElementValueFor:@"textColor" atIndex:idx onlyIfSet:NO],
                            NSFontAttributeName            : theFont,
                            NSParagraphStyleAttributeName  : theParagraphStyle,
                        } ;

                        [(NSString *)textEntry drawInRect:frameRect withAttributes:attributes] ;
                    } else {
                        [(NSAttributedString *)textEntry drawInRect:frameRect] ;
                    }
                    [self->_elementBounds addObject:@{
                        @"index" : @(idx),
                        @"frame" : [NSValue valueWithRect:frameRect]
                    }] ;
                    elementPath = nil ; // shouldn't be necessary, but lets be explicit
                } else
#pragma mark RESETCLIP
                if ([elementType isEqualToString:@"resetClip"]) {
                    [gc restoreGraphicsState] ; // from beginning of enumeration
                    wasClippingChanged = YES ;
                    if (clippingModified) {
                        [gc restoreGraphicsState] ; // from clip action
                        clippingModified = NO ;
                    } else {
                        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - un-nested resetClip at index %lu", USERDATA_TAG, idx + 1]] ;
                    }
                    elementPath = nil ; // shouldn't be necessary, but lets be explicit
                } else {
                    [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - unrecognized type %@ at index %lu", USERDATA_TAG, elementType, idx + 1]] ;
                    elementPath = nil ; // shouldn't be necessary, but lets be explicit
                }
            }
            // Now, if it's still not a path, we don't render it.  But if it is...

#pragma mark Render Logic
            if (elementPath) {
                NSNumber *miterLimit = (NSNumber *)[self getElementValueFor:@"miterLimit" atIndex:idx onlyIfSet:YES] ;
                if (miterLimit) elementPath.miterLimit = [miterLimit doubleValue] ;

                NSNumber *flatness = (NSNumber *)[self getElementValueFor:@"flatness" atIndex:idx onlyIfSet:YES] ;
                if (flatness) elementPath.flatness = [flatness doubleValue] ;

                if ([(NSNumber *)[self getElementValueFor:@"flattenPath" atIndex:idx] boolValue]) {
                    elementPath = elementPath.bezierPathByFlatteningPath ;
                }
                if ([(NSNumber *)[self getElementValueFor:@"reversePath" atIndex:idx] boolValue]) {
                    elementPath = elementPath.bezierPathByReversingPath ;
                }

                NSString *windingRule = (NSString *)[self getElementValueFor:@"windingRule" atIndex:idx onlyIfSet:YES] ;
                if (windingRule) elementPath.windingRule = [(NSNumber *)WINDING_RULES[windingRule] unsignedIntValue] ;

                if (renderPath) {
                    [renderPath appendBezierPath:elementPath] ;
                } else {
                    renderPath = elementPath ;
                }

                if ([action isEqualToString:@"clip"]) {
                    [gc restoreGraphicsState] ; // from beginning of enumeration
                    wasClippingChanged = YES ;
                    if (!clippingModified) {
                        [gc saveGraphicsState] ;
                        clippingModified = YES ;
                    }
                    [renderPath addClip] ;
                    renderPath = nil ;

                } else if ([action isEqualToString:@"fill"] || [action isEqualToString:@"stroke"] || [action isEqualToString:@"strokeAndFill"]) {

                    BOOL clipToPath = [(NSNumber *)[self getElementValueFor:@"clipToPath" atIndex:idx] boolValue] ;
                    if ([CLOSED containsObject:elementType] && clipToPath) {
                        [gc saveGraphicsState] ;
                        [renderPath addClip] ;
                    }

                    if (![elementType isEqualToString:@"points"] && ([action isEqualToString:@"fill"] || [action isEqualToString:@"strokeAndFill"])) {
                        NSString     *fillGradient   = (NSString *)[self getElementValueFor:@"fillGradient" atIndex:idx] ;
                        if (![fillGradient isEqualToString:@"none"] && ![renderPath isEmpty]) {
                            NSArray *gradientColors = (NSArray *)[self getElementValueFor:@"fillGradientColors" atIndex:idx] ;
                            NSGradient* gradient = [[NSGradient alloc] initWithColors:gradientColors];
                            if ([fillGradient isEqualToString:@"linear"]) {
                                [gradient drawInBezierPath:renderPath angle:[(NSNumber *)[self getElementValueFor:@"fillGradientAngle" atIndex:idx] doubleValue]] ;
                            } else if ([fillGradient isEqualToString:@"radial"]) {
                                NSDictionary *centerPoint = (NSDictionary *)[self getElementValueFor:@"fillGradientCenter" atIndex:idx] ;
                                [gradient drawInBezierPath:renderPath
                                    relativeCenterPosition:NSMakePoint([(NSNumber *)centerPoint[@"x"] doubleValue], [(NSNumber *)centerPoint[@"y"] doubleValue])] ;
                            }
                        } else {
                            [renderPath fill] ;
                        }
                    }

                    if ([action isEqualToString:@"stroke"] || [action isEqualToString:@"strokeAndFill"]) {
                        NSNumber *strokeWidth = (NSNumber *)[self getElementValueFor:@"strokeWidth" atIndex:idx onlyIfSet:YES] ;
                        if (strokeWidth) renderPath.lineWidth  = [strokeWidth doubleValue] ;

                        NSString *lineJoinStyle = (NSString *)[self getElementValueFor:@"strokeJoinStyle" atIndex:idx onlyIfSet:YES] ;
                        if (lineJoinStyle) renderPath.lineJoinStyle = [(NSNumber *)STROKE_JOIN_STYLES[lineJoinStyle] unsignedIntValue] ;

                        NSString *lineCapStyle = (NSString *)[self getElementValueFor:@"strokeCapStyle" atIndex:idx onlyIfSet:YES] ;
                        if (lineCapStyle) renderPath.lineCapStyle = [(NSNumber *)STROKE_CAP_STYLES[lineCapStyle] unsignedIntValue] ;

                        NSArray *strokeDashes = (NSArray *)[self getElementValueFor:@"strokeDashPattern" atIndex:idx] ;
                        if ([strokeDashes count] > 0) {
                            NSUInteger count = [strokeDashes count] ;
                            CGFloat    phase = [(NSNumber *)[self getElementValueFor:@"strokeDashPhase" atIndex:idx] doubleValue] ;
                            CGFloat *pattern ;
                            pattern = (CGFloat *)malloc(sizeof(CGFloat) * count) ;
                            if (pattern) {
                                for (NSUInteger i = 0 ; i < count ; i++) {
                                    pattern[i] = [(NSNumber *)strokeDashes[i] doubleValue] ;
                                }
                                [renderPath setLineDash:pattern count:(NSInteger)count phase:phase];
                                free(pattern) ;
                            }
                        }

                        [renderPath stroke] ;
                    }

                    if ([CLOSED containsObject:elementType] && clipToPath) {
                        [gc restoreGraphicsState] ;
                    }

                    if ([(NSNumber *)[self getElementValueFor:@"trackMouseByBounds" atIndex:idx] boolValue]) {
                        NSRect objectBounds = NSZeroRect ;
                        if (![renderPath isEmpty]) objectBounds = [renderPath bounds] ;
                        [self->_elementBounds addObject:@{
                            @"index" : @(idx),
                            @"frame"  : [NSValue valueWithRect:objectBounds],
                        }] ;
                    } else {
                        [self->_elementBounds addObject:@{
                            @"index" : @(idx),
                            @"path"  : renderPath,
                        }] ;
                    }
                    renderPath = nil ;
                } else if (![action isEqualToString:@"build"]) {
                    [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - unrecognized action %@ at index %lu", USERDATA_TAG, action, idx + 1]] ;
                }
            }
            // to keep nesting correct, this was already done if we adjusted clipping this round
            if (!wasClippingChanged) [gc restoreGraphicsState] ;

            if (idx == previousTrackedRealIndex) self->_previousTrackedIndex = [self->_elementBounds count] - 1 ;
        }
    }] ;

    if (clippingModified) [gc restoreGraphicsState] ; // balance our saves

    _mouseTracking = needMouseTracking ;
    [gc restoreGraphicsState];
}

// To facilitate the way frames and points are specified, we get our tables from lua with the LS_NSRawTables option... this forces rect-tables and point-tables to be just that - tables, but also prevents color tables, styledtext tables, and transform tables from being converted... so we add fixes for them here...
// Plus we allow some "laziness" on the part of the programmer to leave out __luaSkinType when crafting the tables by hand, either to make things cleaner/easier or for historical reasons...

- (NSObject *)massageKeyValue:(NSObject *)oldValue forKey:(NSString *)keyName withState:(lua_State *)L {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     lua_State *L = [skin L] ;

    NSObject *newValue = oldValue ; // assume we're not changing anything
//     [LuaSkin logWarn:[NSString stringWithFormat:@"keyname %@ (%@) oldValue is %@", keyName, NSStringFromClass([oldValue class]), [oldValue debugDescription]]] ;

    // fix "...Color" tables
    if ([keyName hasSuffix:@"Color"] && ([oldValue isKindOfClass:[NSDictionary class]] || [oldValue isKindOfClass:[NSArray class]])) {
        [skin pushNSObject:oldValue] ;
        lua_pushstring(L, "NSColor") ;
        lua_setfield(L, -2, "__luaSkinType") ;
        newValue = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;

    // fillGradientColors is an array of colors
    } else if ([keyName isEqualToString:@"fillGradientColors"]) {
        newValue = [[NSMutableArray alloc] init] ;
        [(NSMutableArray *)oldValue enumerateObjectsUsingBlock:^(NSDictionary *anItem, NSUInteger idx, __unused BOOL *stop) {
            if ([anItem isKindOfClass:[NSDictionary class]]) {
                [skin pushNSObject:anItem] ;
                lua_pushstring(L, "NSColor") ;
                lua_setfield(L, -2, "__luaSkinType") ;
                anItem = [skin toNSObjectAtIndex:-1] ;
                lua_pop(L, 1) ;
            }
            if (anItem && [anItem isKindOfClass:[NSColor class]] && [(NSColor *)anItem colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]) {
                [(NSMutableArray *)newValue addObject:anItem] ;
            } else {
                [LuaSkin logWarn:[NSString stringWithFormat:@"%s:not a proper color at index %lu of fillGradientColor; using Black", USERDATA_TAG, idx + 1]] ;
                [(NSMutableArray *)newValue addObject:[NSColor blackColor]] ;
            }
        }] ;
        if ([(NSMutableArray *)newValue count] < 2) {
            [LuaSkin logWarn:[NSString stringWithFormat:@"%s:fillGradientColor requires at least 2 colors; using default", USERDATA_TAG]] ;
            newValue = [self getDefaultValueFor:keyName onlyIfSet:NO] ;
        }
    // fix NSAffineTransform table
    } else if ([keyName isEqualToString:@"transformation"] && ([oldValue isKindOfClass:[NSDictionary class]] || [oldValue isKindOfClass:[NSArray class]])) {
        [skin pushNSObject:oldValue] ;
        lua_pushstring(L, "NSAffineTransform") ;
        lua_setfield(L, -2, "__luaSkinType") ;
        newValue = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;

    // fix NSShadow table
    } else if ([keyName isEqualToString:@"shadow"] && ([oldValue isKindOfClass:[NSDictionary class]] || [oldValue isKindOfClass:[NSArray class]])) {
        [skin pushNSObject:oldValue] ;
        lua_pushstring(L, "NSShadow") ;
        lua_setfield(L, -2, "__luaSkinType") ;
        newValue = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;

    // fix hs.styledText as Table
    } else if ([keyName isEqualToString:@"text"] && ([oldValue isKindOfClass:[NSDictionary class]] || [oldValue isKindOfClass:[NSArray class]])) {
        [skin pushNSObject:oldValue] ;
        lua_pushstring(L, "NSAttributedString") ;
        lua_setfield(L, -2, "__luaSkinType") ;
        newValue = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;

    // recurse into fields which have subfields to check those as well -- this should be done last in case the dictionary can be coerced into an object, like the color tables handled above
    } else if ([oldValue isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *blockValue = [[NSMutableDictionary alloc] init] ;
        [(NSDictionary *)oldValue enumerateKeysAndObjectsUsingBlock:^(id blockKeyName, id valueForKey, __unused BOOL *stop) {
            [blockValue setObject:[self massageKeyValue:valueForKey forKey:blockKeyName withState:L] forKey:blockKeyName] ;
        }] ;
        newValue = blockValue ;
    }
//     [LuaSkin logWarn:[NSString stringWithFormat:@"newValue is %@", [newValue debugDescription]]] ;

    return newValue ;
}

- (NSObject *)getDefaultValueFor:(NSString *)keyName onlyIfSet:(BOOL)onlyIfSet {
    NSDictionary *attributeDefinition = languageDictionary[keyName] ;
    NSObject *result ;
    if (!attributeDefinition[@"default"]) {
        return nil ;
    } else if (_canvasDefaults[keyName]) {
        result = _canvasDefaults[keyName] ;
    } else if (!onlyIfSet) {
        result = attributeDefinition[@"default"] ;
    } else {
        result = nil ;
    }

    if ([[result class] conformsToProtocol:@protocol(NSMutableCopying)]) {
        result = [result mutableCopy] ;
    } else if ([[result class] conformsToProtocol:@protocol(NSCopying)]) {
        result = [result copy] ;
    }
    return result ;
}

- (attributeValidity)setDefaultFor:(NSString *)keyName to:(NSObject *)keyValue withState:(lua_State *)L {
    attributeValidity validityStatus       = attributeInvalid ;
    if ([(NSNumber *)languageDictionary[keyName][@"nullable"] boolValue]) {
        keyValue = [self massageKeyValue:keyValue forKey:keyName withState:L] ;
        validityStatus = isValueValidForAttribute(keyName, keyValue) ;
        switch (validityStatus) {
            case attributeValid:
                _canvasDefaults[keyName] = keyValue ;
                break ;
            case attributeNulling:
                [_canvasDefaults removeObjectForKey:keyName] ;
                break ;
            case attributeInvalid:
                break ;
            default:
                [LuaSkin logWarn:@"unexpected validity status returned; notify developers"] ;
                break ;
        }
    }
    self.needsDisplay = YES ;
    return validityStatus ;
}

- (NSObject *)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index {
    return [self getElementValueFor:keyName atIndex:index resolvePercentages:NO onlyIfSet:NO] ;
}

- (NSObject *)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index onlyIfSet:(BOOL)onlyIfSet {
    return [self getElementValueFor:keyName atIndex:index resolvePercentages:NO onlyIfSet:onlyIfSet] ;
}

- (NSObject *)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index resolvePercentages:(BOOL)resolvePercentages {
    return [self getElementValueFor:keyName atIndex:index resolvePercentages:resolvePercentages onlyIfSet:NO] ;
}

- (NSObject *)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index resolvePercentages:(BOOL)resolvePercentages onlyIfSet:(BOOL)onlyIfSet {
    if (index >= [_elementList count]) return nil ;
    NSDictionary *elementAttributes = _elementList[index] ;
    NSObject *foundObject = elementAttributes[keyName] ? elementAttributes[keyName] : (onlyIfSet ? nil : [self getDefaultValueFor:keyName onlyIfSet:NO]) ;
    if ([[foundObject class] conformsToProtocol:@protocol(NSMutableCopying)]) {
        foundObject = [foundObject mutableCopy] ;
    } else if ([[foundObject class] conformsToProtocol:@protocol(NSCopying)]) {
        foundObject = [foundObject copy] ;
    }

    if ([keyName isEqualToString:@"imageAnimationFrame"]) {
        NSImage *theImage = _elementList[index][@"image"] ;
        if (theImage && [theImage isKindOfClass:[NSImage class]]) {
            for (NSBitmapImageRep *representation in [theImage representations]) {
                if ([representation isKindOfClass:[NSBitmapImageRep class]]) {
                    NSNumber *currentFrame = [representation valueForProperty:NSImageCurrentFrame] ;
                    if (currentFrame) {
                        foundObject = currentFrame ;
                        break ;
                    }
                }
            }
        }
    }

    if (foundObject && resolvePercentages) {
        CGFloat padding = [(NSNumber *)[self getElementValueFor:@"padding" atIndex:index] doubleValue] ;
        CGFloat paddedWidth = self.frame.size.width - padding * 2 ;
        CGFloat paddedHeight = self.frame.size.height - padding * 2 ;

        NSMutableDictionary *foundObjectAsMDictionary = (NSMutableDictionary *)foundObject ;
        if ([keyName isEqualToString:@"radius"]) {
            if ([foundObject isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber((NSString *)foundObject) ;
                foundObject = [NSNumber numberWithDouble:([percentage doubleValue] * paddedWidth)] ;
            }
        } else if ([keyName isEqualToString:@"center"]) {
            if ([(NSObject *)foundObjectAsMDictionary[@"x"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber((NSString *)foundObjectAsMDictionary[@"x"]) ;
                foundObjectAsMDictionary[@"x"] = [NSNumber numberWithDouble:(padding + [percentage doubleValue] * paddedWidth)] ;
            }
            if ([(NSObject *)foundObjectAsMDictionary[@"y"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber((NSString *)foundObjectAsMDictionary[@"y"]) ;
                foundObjectAsMDictionary[@"y"] = [NSNumber numberWithDouble:(padding + [percentage doubleValue] * paddedHeight)] ;
            }
        } else if ([keyName isEqualToString:@"frame"]) {
            if ([(NSObject *)foundObjectAsMDictionary[@"x"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber((NSString *)foundObjectAsMDictionary[@"x"]) ;
                foundObjectAsMDictionary[@"x"] = [NSNumber numberWithDouble:(padding + [percentage doubleValue] * paddedWidth)] ;
            }
            if ([(NSObject *)foundObjectAsMDictionary[@"y"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber((NSString *)foundObjectAsMDictionary[@"y"]) ;
                foundObjectAsMDictionary[@"y"] = [NSNumber numberWithDouble:(padding + [percentage doubleValue] * paddedHeight)] ;
            }
            if ([(NSObject *)foundObjectAsMDictionary[@"w"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber((NSString *)foundObjectAsMDictionary[@"w"]) ;
                foundObjectAsMDictionary[@"w"] = [NSNumber numberWithDouble:([percentage doubleValue] * paddedWidth)] ;
            }
            if ([(NSObject *)foundObjectAsMDictionary[@"h"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber((NSString *)foundObjectAsMDictionary[@"h"]) ;
                foundObjectAsMDictionary[@"h"] = [NSNumber numberWithDouble:([percentage doubleValue] * paddedHeight)] ;
            }
        } else if ([keyName isEqualToString:@"coordinates"]) {
        // make sure we adjust a copy and not the actual items as defined; this is necessary because the copy above just does the top level element; this attribute is an array of objects unlike above attributes
            NSMutableArray *ourCopy = [[NSMutableArray alloc] init] ;
            [(NSMutableArray *)foundObject enumerateObjectsUsingBlock:^(NSMutableDictionary *subItem, NSUInteger idx, __unused BOOL *stop) {
                NSMutableDictionary *targetItem = [[NSMutableDictionary alloc] init] ;
                for (NSString *field in @[ @"x", @"y", @"c1x", @"c1y", @"c2x", @"c2y" ]) {
                    if (subItem[field] && [(NSString *)subItem[field] isKindOfClass:[NSString class]]) {
                        NSNumber *percentage = convertPercentageStringToNumber(subItem[field]) ;
                        CGFloat ourPadding = [field hasSuffix:@"x"] ? paddedWidth : paddedHeight ;
                        targetItem[field] = [NSNumber numberWithDouble:(padding + [percentage doubleValue] * ourPadding)] ;
                    } else {
                        targetItem[field] = subItem[field] ;
                    }
                }
                ourCopy[idx] = targetItem ;
            }] ;
            foundObject = ourCopy ;
        }
    }

    return foundObject ;
}

- (attributeValidity)setElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index to:(NSObject *)keyValue withState:(lua_State *)L {
    if (index >= [_elementList count]) return attributeInvalid ;
    keyValue = [self massageKeyValue:keyValue forKey:keyName withState:L] ;
    __block attributeValidity validityStatus = isValueValidForAttribute(keyName, keyValue) ;

    NSMutableDictionary *keyValueAsMDictionary = (NSMutableDictionary *)keyValue ;
    switch (validityStatus) {
        case attributeValid: {
            if ([keyName isEqualToString:@"radius"]) {
                if ([keyValue isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber((NSString *)keyValue) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
            } else if ([keyName isEqualToString:@"center"]) {
                if ([(NSObject *)keyValueAsMDictionary[@"x"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber((NSString *)keyValueAsMDictionary[@"x"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field x of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([(NSObject *)keyValueAsMDictionary[@"y"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber((NSString *)keyValueAsMDictionary[@"y"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field y of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
            } else if ([keyName isEqualToString:@"frame"]) {
                if ([(NSObject *)keyValueAsMDictionary[@"x"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber((NSString *)keyValueAsMDictionary[@"x"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field x of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([(NSObject *)keyValueAsMDictionary[@"y"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber((NSString *)keyValueAsMDictionary[@"y"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field y of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([(NSObject *)keyValueAsMDictionary[@"w"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber((NSString *)keyValueAsMDictionary[@"w"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field w of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([(NSObject *)keyValueAsMDictionary[@"h"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber((NSString *)keyValueAsMDictionary[@"h"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field h of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
            } else if ([keyName isEqualToString:@"coordinates"]) {
                [(NSMutableArray *)keyValue enumerateObjectsUsingBlock:^(NSMutableDictionary *subItem, NSUInteger idx, BOOL *stop) {
                    NSMutableSet *seenFields = [[NSMutableSet alloc] init] ;
                    for (NSString *field in @[ @"x", @"y", @"c1x", @"c1y", @"c2x", @"c2y" ]) {
                        if (subItem[field]) {
                            [seenFields addObject:field] ;
                            if ([(NSObject *)subItem[field] isKindOfClass:[NSString class]]) {
                                NSNumber *percentage = convertPercentageStringToNumber(subItem[field]) ;
                                if (!percentage) {
                                    [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field %@ at index %lu of %@ for element %lu", USERDATA_TAG, field, idx + 1, keyName, index + 1]];
                                    validityStatus = attributeInvalid ;
                                    *stop = YES ;
                                    break ;
                                }
                            }
                        }
                    }
                    BOOL goodForPoint = [seenFields containsObject:@"x"] && [seenFields containsObject:@"y"] ;
                    BOOL goodForCurve = goodForPoint && [seenFields containsObject:@"c1x"] && [seenFields containsObject:@"c1y"] &&
                                                        [seenFields containsObject:@"c2x"] && [seenFields containsObject:@"c2y"] ;
                    BOOL partialCurve = ([seenFields containsObject:@"c1x"] || [seenFields containsObject:@"c1y"] ||
                                        [seenFields containsObject:@"c2x"] || [seenFields containsObject:@"c2y"]) && !goodForCurve ;

                    if (!goodForPoint) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:index %lu of %@ for element %lu does not specify a valid point or curve with control points", USERDATA_TAG, idx + 1, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                    } else if (goodForPoint && partialCurve) {
                        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:index %lu of %@ for element %lu does not contain complete curve control points; treating as a singular point", USERDATA_TAG, idx + 1, keyName, index + 1]];
                    }
                }] ;
                if (validityStatus == attributeInvalid) break ;
            } else if ([keyName isEqualToString:@"imageAnimationFrame"]) {
                if ([(NSNumber *)[self getElementValueFor:@"imageAnimates" atIndex:index] boolValue]) {
                    [LuaSkin logWarn:[NSString stringWithFormat:@"%s:%@ cannot be changed when element %lu is animating", USERDATA_TAG, keyName, index + 1]] ;
                    validityStatus = attributeInvalid ;
                    break ;
                } else {
                    NSImage *theImage = _elementList[index][@"image"] ;
                    if (theImage && [theImage isKindOfClass:[NSImage class]]) {
                        for (NSBitmapImageRep *representation in [theImage representations]) {
                            if ([representation isKindOfClass:[NSBitmapImageRep class]]) {
                                NSNumber *maxFrames = [representation valueForProperty:NSImageFrameCount] ;
                                if (maxFrames) {
                                    lua_Integer newFrame = [(NSNumber *)keyValue integerValue] % [maxFrames integerValue] ;
                                    while (newFrame < 0) newFrame = [maxFrames integerValue] + newFrame ;
                                    [representation setProperty:NSImageCurrentFrame withValue:[NSNumber numberWithInteger:newFrame]] ;
                                    break ;
                                }
                            }
                        }
                    }
                }
            } else if ([keyName isEqualToString:@"imageAnimates"]) {
                NSImage *currentImage = _elementList[index][@"image"] ;
                if (currentImage && [currentImage isKindOfClass:[NSImage class]]) {
                    BOOL shouldAnimate = [(NSNumber *)keyValue boolValue] ;
                    HSUITKElementCanvasGifAnimator *animator = [_imageAnimations objectForKey:currentImage] ;
                    if (shouldAnimate) {
                        if (!animator) {
                            animator = [[HSUITKElementCanvasGifAnimator alloc] initWithImage:currentImage forCanvas:self] ;
                            if (animator) [_imageAnimations setObject:animator forKey:currentImage] ;
                        }
                        if (animator) [animator startAnimating] ;
                    } else {
                        if (animator) [animator stopAnimating] ;
                    }
                }
            } else if ([keyName isEqualToString:@"image"]) {
                NSImage *currentImage = _elementList[index][@"image"] ;
                if (currentImage && [currentImage isKindOfClass:[NSImage class]]) {
                    HSUITKElementCanvasGifAnimator *animator = [_imageAnimations objectForKey:currentImage] ;
                    if (animator) {
                        [animator stopAnimating] ;
                        [_imageAnimations removeObjectForKey:currentImage] ;
                    }
                }
                BOOL shouldAnimate = [(NSNumber *)[self getElementValueFor:@"imageAnimates" atIndex:index] boolValue] ;
                if (shouldAnimate) {
                    HSUITKElementCanvasGifAnimator *animator = [[HSUITKElementCanvasGifAnimator alloc] initWithImage:(NSImage *)keyValue forCanvas:self] ;
                    if (animator) {
                        [_imageAnimations setObject:animator forKey:currentImage] ;
                        [animator startAnimating] ;
                    }
                }
            }

            if (![keyName isEqualToString:@"imageAnimationFrame"]) _elementList[index][keyName] = keyValue ;

            // add defaults, if not already present, for type (recurse into this method as needed)
            if ([keyName isEqualToString:@"type"]) {
                NSSet *defaultsForType = [languageDictionary keysOfEntriesPassingTest:^BOOL(NSString *typeName, NSDictionary *typeDefinition, __unused BOOL *stop){
                    return ![typeName isEqualToString:@"type"] && typeDefinition[@"requiredFor"] && [(NSArray *)typeDefinition[@"requiredFor"] containsObject:keyValue] ;
                }] ;
                for (NSString *additionalKey in defaultsForType) {
                    if (!_elementList[index][additionalKey]) {
                        [self setElementValueFor:additionalKey atIndex:index to:[self getDefaultValueFor:additionalKey onlyIfSet:NO] withState:L] ;
                    }
                }
            }
        }   break ;
        case attributeNulling:
            if ([keyName isEqualToString:@"imageAnimationFrame"]) {
                if ([(NSNumber *)[self getElementValueFor:@"imageAnimates" atIndex:index] boolValue]) {
                    [LuaSkin logWarn:[NSString stringWithFormat:@"%s:%@ cannot be changed when element %lu is animating", USERDATA_TAG, keyName, index + 1]] ;
                    validityStatus = attributeInvalid ;
                    break ;
                } else {
                    NSImage *theImage = _elementList[index][@"image"] ;
                    if (theImage && [theImage isKindOfClass:[NSImage class]]) {
                        NSNumber *imageFrame = (NSNumber *)[self getDefaultValueFor:@"imageAnimationFrame" onlyIfSet:NO] ;
                        for (NSBitmapImageRep *representation in [theImage representations]) {
                            if ([representation isKindOfClass:[NSBitmapImageRep class]]) {
                                NSNumber *maxFrames = [representation valueForProperty:NSImageFrameCount] ;
                                if (maxFrames) {
                                    lua_Integer newFrame = [imageFrame integerValue] % [maxFrames integerValue] ;
                                    [representation setProperty:NSImageCurrentFrame withValue:[NSNumber numberWithInteger:newFrame]] ;
                                    break ;
                                }
                            }
                        }
                    }
                }
            } else if ([keyName isEqualToString:@"imageAnimates"]) {
                NSImage *currentImage = _elementList[index][@"image"] ;
                if (currentImage && [currentImage isKindOfClass:[NSImage class]]) {
                    BOOL shouldAnimate = [(NSNumber *)[self getDefaultValueFor:@"imageAnimates" onlyIfSet:NO] boolValue] ;
                    HSUITKElementCanvasGifAnimator *animator = [_imageAnimations objectForKey:currentImage] ;
                    if (shouldAnimate) {
                        if (!animator) {
                            animator = [[HSUITKElementCanvasGifAnimator alloc] initWithImage:currentImage forCanvas:self] ;
                            if (animator) [_imageAnimations setObject:animator forKey:currentImage] ;
                        }
                        if (animator) [animator startAnimating] ;
                    } else {
                        if (animator) [animator stopAnimating] ;
                    }
                }
            } else if ([keyName isEqualToString:@"image"]) {
                NSImage *currentImage = _elementList[index][@"image"] ;
                if (currentImage && [currentImage isKindOfClass:[NSImage class]]) {
                    HSUITKElementCanvasGifAnimator *animator = [_imageAnimations objectForKey:currentImage] ;
                    if (animator) {
                        [animator stopAnimating] ;
                        [_imageAnimations removeObjectForKey:currentImage] ;
                    }
                }
            }

            [(NSMutableDictionary *)_elementList[index] removeObjectForKey:keyName] ;
            break ;
        case attributeInvalid:
            break ;
        default:
            [LuaSkin logWarn:@"unexpected validity status returned; notify developers"] ;
            break ;
    }
    self.needsDisplay = YES ;
    return validityStatus ;
}

// see https://www.stairways.com/blog/2009-04-21-nsimage-from-nsview
- (NSImage *)imageWithSubviews {
    // Source: https://stackoverflow.com/questions/1733509/huge-memory-leak-in-nsbitmapimagerep/2189699
    @autoreleasepool {
        NSBitmapImageRep *bir = [self bitmapImageRepForCachingDisplayInRect:self.bounds];
        [bir setSize:self.bounds.size];
        [self cacheDisplayInRect:self.bounds toBitmapImageRep:bir];

        NSImage* image = [[NSImage alloc]initWithSize:self.bounds.size] ;
        [image addRepresentation:bir];

        return image;
    }
}

#pragma mark View Animation Methods

- (void)fadeIn:(NSTimeInterval)fadeTime {
    CGFloat alphaSetting = self.alphaValue ;
    [self setAlphaValue:0.0];
    [self setHidden:NO];
    [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:fadeTime];
        [[self animator] setAlphaValue:alphaSetting];
    [NSAnimationContext endGrouping];
}

- (void)fadeOut:(NSTimeInterval)fadeTime {
    CGFloat alphaSetting = self.alphaValue ;
    [NSAnimationContext beginGrouping];
        __weak HSUITKElementCanvas *bself = self; // in ARC, __block would increase retain count
        [[NSAnimationContext currentContext] setDuration:fadeTime];
        [[NSAnimationContext currentContext] setCompletionHandler:^{
            // unlikely that bself will go to nil after this starts, but this keeps the warnings down from [-Warc-repeated-use-of-weak]
            HSUITKElementCanvas *mySelf = bself ;
            if (mySelf) {
                [mySelf setHidden:YES];
                [mySelf setAlphaValue:alphaSetting];
            }
        }];
        [[self animator] setAlphaValue:0.0];
    [NSAnimationContext endGrouping];
}

#pragma mark NSDraggingDestination protocol methods

- (BOOL)draggingCallback:(NSString *)message with:(id<NSDraggingInfo>)sender {
    BOOL isAllGood = NO ;
    if (_draggingCallbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        lua_State *L = skin.L ;
        _lua_stackguard_entry(L);
        int argCount = 2 ;
        [skin pushLuaRef:refTable ref:_draggingCallbackRef] ;
        [skin pushNSObject:self] ;
        [skin pushNSObject:message] ;
        if (sender) {
            lua_newtable(L) ;
            NSPasteboard *pasteboard = [sender draggingPasteboard] ;
            if (pasteboard) {
                [skin pushNSObject:pasteboard.name] ; lua_setfield(L, -2, "pasteboard") ;
            }
            lua_pushinteger(L, [sender draggingSequenceNumber]) ; lua_setfield(L, -2, "sequence") ;
            [skin pushNSPoint:[sender draggingLocation]] ; lua_setfield(L, -2, "mouse") ;
            NSDragOperation operation = [sender draggingSourceOperationMask] ;
            lua_newtable(L) ;
            if (operation == NSDragOperationNone) {
                lua_pushstring(L, "none") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
            } else {
                if ((operation & NSDragOperationCopy) == NSDragOperationCopy) {
                    lua_pushstring(L, "copy") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationLink) == NSDragOperationLink) {
                    lua_pushstring(L, "link") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationGeneric) == NSDragOperationGeneric) {
                    lua_pushstring(L, "generic") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationPrivate) == NSDragOperationPrivate) {
                    lua_pushstring(L, "private") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationMove) == NSDragOperationMove) {
                    lua_pushstring(L, "move") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationDelete) == NSDragOperationDelete) {
                    lua_pushstring(L, "delete") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
            }
            lua_setfield(L, -2, "operation") ;
            argCount += 1 ;
        }
        if ([skin protectedCallAndTraceback:argCount nresults:1]) {
            isAllGood = lua_isnoneornil(L, -1) ? YES : (BOOL)(lua_toboolean(skin.L, -1)) ;
        } else {
            [skin logError:[NSString stringWithFormat:@"%s:draggingCallback error: %@", USERDATA_TAG, [skin toNSObjectAtIndex:-1]]] ;
            // No need to lua_pop() the error because nresults is 1, so the call below gets it whether it's a successful result or an error message
        }
        lua_pop(L, 1) ;
        _lua_stackguard_exit(L);
    }
    return isAllGood ;
}

- (BOOL)wantsPeriodicDraggingUpdates {
    return NO ;
}

- (BOOL)prepareForDragOperation:(__unused id<NSDraggingInfo>)sender {
    return YES ;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    return [self draggingCallback:@"enter" with:sender] ? NSDragOperationGeneric : NSDragOperationNone ;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
    [self draggingCallback:@"exit" with:sender] ;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    return [self draggingCallback:@"receive" with:sender] ;
}

// - (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender ;
// - (void)concludeDragOperation:(id<NSDraggingInfo>)sender ;
// - (void)draggingEnded:(id<NSDraggingInfo>)sender ;
// - (void)updateDraggingItemsForDrag:(id<NSDraggingInfo>)sender

#pragma mark imageAdditions

- (NSSize) _scaleImageWithSize: (NSSize)imageSize
                   toFitInSize: (NSSize)canvasSize
                   scalingType: (NSImageScaling)scalingType {
    NSSize result;
    switch (scalingType) {
        case NSImageScaleProportionallyDown: // == NSScaleProportionally:
              result = scaleProportionally (imageSize, canvasSize, NO);
              break;
        case NSImageScaleAxesIndependently: // == NSScaleToFit
              result = canvasSize;
              break;
        default:
        case NSImageScaleNone: // == NSScaleNone
              result = imageSize;
              break;
        case NSImageScaleProportionallyUpOrDown:
              result = scaleProportionally (imageSize, canvasSize, YES);
              break;
    }
    return result;
}

- (NSRect) realRectFor:(NSImage *)theImage inFrame:(NSRect)cellFrame
                                       withScaling:(NSImageScaling)scaleStyle
                                     withAlignment:(NSImageAlignment)alignmentStyle {

    NSPoint position;
    BOOL    is_flipped = [self isFlipped];
    NSSize  imageSize ;

    imageSize = [self _scaleImageWithSize:[theImage size] toFitInSize:cellFrame.size scalingType:scaleStyle];

    switch (alignmentStyle) {
        default:
        case NSImageAlignLeft:
            position.x = xLeftInRect(imageSize, cellFrame);
            position.y = yCenterInRect(imageSize, cellFrame, is_flipped);
            break;
        case NSImageAlignRight:
            position.x = xRightInRect(imageSize, cellFrame);
            position.y = yCenterInRect(imageSize, cellFrame, is_flipped);
            break;
        case NSImageAlignCenter:
            position.x = xCenterInRect(imageSize, cellFrame);
            position.y = yCenterInRect(imageSize, cellFrame, is_flipped);
            break;
        case NSImageAlignTop:
            position.x = xCenterInRect(imageSize, cellFrame);
            position.y = yTopInRect(imageSize, cellFrame, is_flipped);
            break;
        case NSImageAlignBottom:
            position.x = xCenterInRect(imageSize, cellFrame);
            position.y = yBottomInRect(imageSize, cellFrame, is_flipped);
            break;
        case NSImageAlignTopLeft:
            position.x = xLeftInRect(imageSize, cellFrame);
            position.y = yTopInRect(imageSize, cellFrame, is_flipped);
            break;
        case NSImageAlignTopRight:
            position.x = xRightInRect(imageSize, cellFrame);
            position.y = yTopInRect(imageSize, cellFrame, is_flipped);
            break;
        case NSImageAlignBottomLeft:
            position.x = xLeftInRect(imageSize, cellFrame);
            position.y = yBottomInRect(imageSize, cellFrame, is_flipped);
            break;
        case NSImageAlignBottomRight:
            position.x = xRightInRect(imageSize, cellFrame);
            position.y = yBottomInRect(imageSize, cellFrame, is_flipped);
            break;
    }

    return [self centerScanRect:NSMakeRect(position.x, position.y, imageSize.width, imageSize.height)];
}

- (void)drawImage:(NSImage *)theImage atIndex:(NSUInteger)idx inRect:(NSRect)cellFrame operation:(NSUInteger)compositeType {

  // do nothing if cell's frame rect is zero
  if (NSIsEmptyRect(cellFrame)) return;

  NSString *alignmentString = (NSString *)[self getElementValueFor:@"imageAlignment" atIndex:idx onlyIfSet:NO] ;
  NSImageAlignment alignment = [(NSNumber *)IMAGEALIGNMENT_TYPES[alignmentString] unsignedIntValue] ;

  NSString *scalingString = (NSString *)[self getElementValueFor:@"imageScaling" atIndex:idx onlyIfSet:NO] ;
  NSImageScaling scaling = [(NSNumber *)IMAGESCALING_TYPES[scalingString] unsignedIntValue] ;

  NSNumber *alpha  ;
  if ([theImage isTemplate]) {
  // approximates NSCell's drawing of a template image since drawInRect bypasses Apple's template handling
      alpha = (NSNumber *)[self getElementValueFor:@"imageAlpha" atIndex:idx onlyIfSet:YES] ;
      if (!alpha) alpha = @(0.5) ;
  } else {
      alpha = (NSNumber *)[self getElementValueFor:@"imageAlpha" atIndex:idx] ;
  }

  // draw actual image
  NSRect rect = [self realRectFor:theImage inFrame:cellFrame withScaling:scaling withAlignment:alignment] ;

  NSGraphicsContext* gc = [NSGraphicsContext currentContext];
  [gc saveGraphicsState];
  [NSBezierPath clipRect:cellFrame] ;

  NSSize realImageSize = [theImage size] ;
  [theImage drawInRect:rect
              fromRect:NSMakeRect(0, 0, realImageSize.width, realImageSize.height)
             operation:compositeType
              fraction:[alpha doubleValue]
        respectFlipped:YES
                 hints:nil];

  [gc restoreGraphicsState];
}

@end

@implementation HSUITKElementCanvasGifAnimator
-(instancetype)initWithImage:(NSImage *)image forCanvas:(HSUITKElementCanvas *)canvas {
    self = [super init] ;
    if (self) {
      _inCanvas                = canvas ;
      _isRunning               = NO ;

      NSBitmapImageRep *animatingRepresentation = nil ;
      for (NSBitmapImageRep *representation in [image representations]) {
          if ([representation isKindOfClass:[NSBitmapImageRep class]]) {
              NSNumber *maxFrames = [representation valueForProperty:NSImageFrameCount] ;
              if (maxFrames) {
                  animatingRepresentation = representation ;
                  break ;
              }
          }
      }
      // if _animatingRepresentation is nil, start and stop don't do anything, so this becomes a no-op
      _animatingRepresentation = animatingRepresentation ;
    }
    return self ;
}

-(void)startAnimating {
    NSBitmapImageRep *animatingRepresentation = _animatingRepresentation ;
    if (animatingRepresentation) {
        if (!_isRunning) {
            NSNumber *frameDuration  = [animatingRepresentation valueForProperty:NSImageCurrentFrameDuration] ;
            if (!frameDuration) frameDuration = @(0.1) ;
            [NSTimer scheduledTimerWithTimeInterval:[frameDuration doubleValue]
                                             target:self
                                           selector:@selector(animateFrame:)
                                           userInfo:nil
                                            repeats:NO] ;

            _isRunning = YES ;
        }
    } else {
        _isRunning = NO ;
    }
}

-(void)stopAnimating {
    if (_isRunning) {
        _isRunning = NO ;
    }
}

-(void)animateFrame:(__unused NSTimer *)timer {
    NSBitmapImageRep    *animatingRepresentation = _animatingRepresentation ;
    HSUITKElementCanvas *inCanvas                = _inCanvas ;

    if (animatingRepresentation && inCanvas) {
        NSNumber *maxFrames = [animatingRepresentation valueForProperty:NSImageFrameCount] ;
        NSNumber *curFrame  = [animatingRepresentation valueForProperty:NSImageCurrentFrame] ;
        NSInteger newFrame  = ([curFrame integerValue] + 1) % [maxFrames integerValue] ;
        [animatingRepresentation setProperty:NSImageCurrentFrame withValue:[NSNumber numberWithInteger:newFrame]] ;
        inCanvas.needsDisplay = YES ;

        if (_isRunning) {
            _isRunning = NO ;
            [self startAnimating] ;
        }
    } else {
        _isRunning = NO ;
    }
}

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.canvas.newCanvas(rect) -> canvasObject
/// Constructor
/// Create a new canvas object at the specified coordinates
///
/// Parameters:
///  * `rect` - A rect-table containing the co-ordinates and size for the canvas object
///
/// Returns:
///  * a new, empty, canvas object, or nil if the canvas cannot be created with the specified coordinates
///
/// Notes:
///  * The size of the canvas defines the visible area of the canvas -- any portion of a canvas element which extends past the canvas's edges will be clipped.
///  * a rect-table is a table with key-value pairs specifying the top-left coordinate on the screen for the canvas (keys `x`  and `y`) and the size (keys `h` and `w`) of the canvas. The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
static int canvas_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementCanvas *canvasView = [[HSUITKElementCanvas alloc] initWithFrame:frameRect] ;
    if (canvasView) {
        [skin pushNSObject:canvasView] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.canvas.elementSpec() -> table
/// Function
/// Returns the list of attributes and their specifications that are recognized for canvas elements by this module.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the attributes and specifications defined for this module.
///
/// Notes:
///  * This is primarily for debugging purposes and may be removed in the future.
static int canvas_dumpLanguageDictionary(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    [skin pushNSObject:languageDictionary withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

/// hs._asm.uitk.element.canvas.defaultTextStyle() -> `hs.styledtext` attributes table
/// Function
/// Returns a table containing the default font, size, color, and paragraphStyle used by `hs._asm.uitk.element.canvas` for text drawing objects.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the default style attributes `hs._asm.uitk.element.canvas` uses for text drawing objects in the `hs.styledtext` attributes table format.
///
/// Notes:
///  * This method is intended to be used in conjunction with `hs.styledtext` to create styledtext objects that are based on, or a slight variation of, the defaults used by `hs._asm.uitk.element.canvas`.
static int canvas_defaultTextAttributes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_newtable(L) ;
    NSString *fontName = languageDictionary[@"textFont"][@"default"] ;
    if (fontName) {
        [skin pushNSObject:[NSFont fontWithName:fontName
                                           size:[(NSNumber *)((NSDictionary *)languageDictionary[@"textSize"])[@"default"] doubleValue]]] ;
        lua_setfield(L, -2, "font") ;
        [skin pushNSObject:languageDictionary[@"textColor"][@"default"]] ;
        lua_setfield(L, -2, "color") ;
        [skin pushNSObject:[NSParagraphStyle defaultParagraphStyle]] ;
        lua_setfield(L, -2, "paragraphStyle") ;
    } else {
        return luaL_error(L, "%s:unable to get default font name from element language dictionary", USERDATA_TAG) ;
    }
    return 1 ;
}

#pragma mark - Module Methods -

// /// hs._asm.uitk.element.canvas:passthroughCallback([fn | nil]) -> canvasObject | fn | nil
// /// Method
// /// Get or set the pass through callback for the canvas
// ///
// /// Parameters:
// ///  * `fn` - a function, or an explicit nil to remove, specifying the callback to invoke for elements which do not have their own callbacks assigned.
// ///
// /// Returns:
// ///  * If an argument is provided, the canvas object; otherwise the current value.
// ///
// /// Notes:
// ///  * The pass through callback should expect one or two arguments and return none.
// ///
// ///  * The pass through callback is designed so that elements which trigger a callback based on user interaction which do not have a specifically assigned callback can still report user interaction through a common fallback.
// ///  * The arguments received by the pass through callback will be organized as follows:
// ///    * the canvas userdata object
// ///    * a canvas containing the arguments provided by the elements callback itself, usually the element userdata followed by any additional arguments as defined for the element's callback function.
// ///
// ///  * Note that elements which have a callback that returns a response cannot use this common pass through callback method; in such cases a specific callback must be assigned to the element directly as described in the element's documentation.
// static int canvas_passthroughCallback(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
//     HSUITKElementCanvas *canvas = [skin toNSObjectAtIndex:1] ;
//
//     if (lua_gettop(L) == 2) {
//         canvas.passThroughRef = [skin luaUnref:refTable ref:canvas.passThroughRef] ;
//         if (lua_type(L, 2) != LUA_TNIL) {
//             lua_pushvalue(L, 2) ;
//             canvas.passThroughRef = [skin luaRef:refTable] ;
//         }
//         lua_pushvalue(L, 1) ;
//     } else {
//         if (canvas.passThroughRef != LUA_NOREF) {
//             [skin pushLuaRef:refTable ref:canvas.passThroughRef] ;
//         } else {
//             lua_pushnil(L) ;
//         }
//     }
//     return 1 ;
// }

/// hs._asm.uitk.element.canvas:draggingCallback([fn]) -> canvasObject | current value
/// Method
/// Sets or remove a callback for accepting dragging and dropping items onto the canvas.
///
/// Parameters:
///  * `fn`   - An optional function or explicit nil, that will be called when an item is dragged onto the canvas.  An explicit nil, the default, disables drag-and-drop for this canvas.
///
/// Returns:
///  * if an argument is provided, returns the canvasObject, otherwise returns the current value
///
/// Notes:
///  * The callback function should expect 3 arguments and optionally return 1: the canvas object itself, a message specifying the type of dragging event, and a table containing details about the item(s) being dragged.  The key-value pairs of the details table will be the following:
///    * `pasteboard` - the name of the pasteboard that contains the items being dragged
///    * `sequence`   - an integer that uniquely identifies the dragging session.
///    * `mouse`      - a point table containing the location of the mouse pointer within the canvas corresponding to when the callback occurred.
///    * `operation`  - a table containing string descriptions of the type of dragging the source application supports. Potentially useful for determining if your callback function should accept the dragged item or not.
///
/// * The possible messages the callback function may receive are as follows:
///    * "enter"   - the user has dragged an item into the canvas.  When your callback receives this message, you can optionally return false to indicate that you do not wish to accept the item being dragged.
///    * "exit"    - the user has moved the item out of the canvas; if the previous "enter" callback returned false, this message will also occur when the user finally releases the items being dragged.
///    * "receive" - indicates that the user has released the dragged object while it is still within the canvas frame.  When your callback receives this message, you can optionally return false to indicate to the sending application that you do not want to accept the dragged item -- this may affect the animations provided by the sending application.
///
///  * You can use the sequence number in the details table to match up an "enter" with an "exit" or "receive" message.
///
///  * You should capture the details you require from the drag-and-drop operation during the callback for "receive" by using the pasteboard field of the details table and the `hs.pasteboard` module.  Because of the nature of "promised items", it is not guaranteed that the items will still be on the pasteboard after your callback completes handling this message.
///
///  * A canvas object can only accept drag-and-drop items when its window level is at `hs._asm.uitk.window.levels.dragging` or lower.
///  * a canvas object can only accept drag-and-drop items when it accepts mouse events.  You must define a [hs._asm.uitk.element.canvas:mouseCallback](#mouseCallback) function, even if it is only a placeholder, e.g. `hs._asm.uitk.element.canvas:mouseCallback(function() end)`
static int canvas_draggingCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;

    if (lua_gettop(L) == 1) {
        if (canvasView.draggingCallbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:canvasView.draggingCallbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        // We're either removing callback(s), or setting new one(s). Either way, remove existing.
        canvasView.draggingCallbackRef = [skin luaUnref:refTable ref:canvasView.draggingCallbackRef];
        [canvasView unregisterDraggedTypes] ;
        if ([skin luaTypeAtIndex:2] != LUA_TNIL) {
            lua_pushvalue(L, 2);
            canvasView.draggingCallbackRef = [skin luaRef:refTable] ;
            [canvasView registerForDraggedTypes:@[ (__bridge NSString *)kUTTypeItem ]] ;
        }

        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs._asm.uitk.element.canvas:minimumTextSize([index], text) -> table
/// Method
/// Returns a table specifying the size of the rectangle which can fully render the text with the specified style so that is will be completely visible.
///
/// Parameters:
///  * `index` - an optional index specifying the element in the canvas which contains the text attributes which should be used when determining the size of the text. If not provided, the canvas defaults will be used instead. Ignored if `text` is an hs.styledtext object.
///  * `text`  - a string or hs.styledtext object specifying the text.
///
/// Returns:
///  * a size table specifying the height and width of a rectangle which could fully contain the text when displayed in the canvas
///
/// Notes:
///  * Multi-line text (separated by a newline or return) is supported.  The height will be for the multiple lines and the width returned will be for the longest line.
static int canvas_getTextElementSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;
    int        textIndex    = 2 ;
    NSUInteger elementIndex = NSNotFound ;
    if (lua_gettop(L) == 3) {
        if (lua_type(L, 3) == LUA_TSTRING) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TSTRING, LS_TBREAK] ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                            LS_TNUMBER | LS_TINTEGER,
                            LS_TUSERDATA, "hs.styledtext",
                            LS_TBREAK] ;
        }
        elementIndex = (NSUInteger)lua_tointeger(L, 2) - 1 ;
        if ((NSInteger)elementIndex < 0 || elementIndex >= [canvasView.elementList count]) {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index %ld out of bounds", elementIndex + 1] UTF8String]) ;
        }
        textIndex = 3 ;
    } else {
        if (lua_type(L, 2) == LUA_TSTRING) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                            LS_TUSERDATA, "hs.styledtext",
                            LS_TBREAK] ;
        }
    }
    NSSize theSize = NSZeroSize ;
    NSString *theText = [skin toNSObjectAtIndex:textIndex] ;

    if (lua_type(L, textIndex) == LUA_TSTRING) {
        NSString *myFont = (elementIndex == NSNotFound) ?
            (NSString *)[canvasView getDefaultValueFor:@"textFont" onlyIfSet:NO] :
            (NSString *)[canvasView getElementValueFor:@"textFont" atIndex:elementIndex onlyIfSet:NO] ;
        NSNumber *mySize = (elementIndex == NSNotFound) ?
            (NSNumber *)[canvasView getDefaultValueFor:@"textSize" onlyIfSet:NO] :
            (NSNumber *)[canvasView getElementValueFor:@"textSize" atIndex:elementIndex onlyIfSet:NO] ;
        NSMutableParagraphStyle *theParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        NSString *alignment = (elementIndex == NSNotFound) ?
            (NSString *)[canvasView getDefaultValueFor:@"textAlignment" onlyIfSet:NO] :
            (NSString *)[canvasView getElementValueFor:@"textAlignment" atIndex:elementIndex onlyIfSet:NO] ;
        theParagraphStyle.alignment = [(NSNumber *)TEXTALIGNMENT_TYPES[alignment] unsignedIntValue] ;
        NSString *wrap = (elementIndex == NSNotFound) ?
            (NSString *)[canvasView getDefaultValueFor:@"textLineBreak" onlyIfSet:NO] :
            (NSString *)[canvasView getElementValueFor:@"textLineBreak" atIndex:elementIndex onlyIfSet:NO] ;
        theParagraphStyle.lineBreakMode = [(NSNumber *)TEXTWRAP_TYPES[wrap] unsignedIntValue] ;
        NSColor *color = (elementIndex == NSNotFound) ?
            (NSColor *)[canvasView getDefaultValueFor:@"textColor" onlyIfSet:NO] :
            (NSColor *)[canvasView getElementValueFor:@"textColor" atIndex:elementIndex onlyIfSet:NO] ;
        NSFont *theFont = [NSFont fontWithName:myFont size:[mySize doubleValue]] ;
        NSDictionary *attributes = @{
            NSForegroundColorAttributeName : color,
            NSFontAttributeName            : theFont,
            NSParagraphStyleAttributeName  : theParagraphStyle,
        } ;
        theSize = [theText sizeWithAttributes:attributes] ;
    } else {
//       NSAttributedString *theText = [skin luaObjectAtIndex:textIndex toClass:"NSAttributedString"] ;
      theSize = [(NSAttributedString *)theText size] ;
    }
    [skin pushNSSize:theSize] ;
    return 1 ;
}

/// hs._asm.uitk.element.canvas:transformation([matrix]) -> canvasObject | current value
/// Method
/// Get or set the matrix transformation which is applied to every element in the canvas before being individually processed and added to the canvas.
///
/// Parameters:
///  * `matrix` - an optional table specifying the matrix table, as defined by the `hs._asm.uitk.util.matrix` module, to be applied to every element of the canvas, or an explicit `nil` to reset the transformation to the identity matrix.
///
/// Returns:
///  * if an argument is provided, returns the canvasObject, otherwise returns the current value
///
/// Notes:
///  * An example use for this method would be to change the canvas's origin point { x = 0, y = 0 } from the lower left corner of the canvas to somewhere else, like the middle of the canvas.
static int canvas_canvasTransformation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:canvasView.canvasTransform] ;
    } else {
        NSAffineTransform *transform = [NSAffineTransform transform] ;
        if (lua_type(L, 2) == LUA_TTABLE) transform = [skin luaObjectAtIndex:2 toClass:"NSAffineTransform"] ;
        canvasView.canvasTransform = transform ;
        canvasView.needsDisplay = YES ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.canvas:mouseCallback([mouseCallbackFn]) -> canvasObject | current value
/// Method
/// Sets a callback for mouse events with respect to the canvas
///
/// Parameters:
///  * `mouseCallbackFn`   - An optional function or explicit nil, that will be called when a mouse event occurs within the canvas, and an element beneath the mouse's current position has one of the `trackMouse...` attributes set to true.
///
/// Returns:
///  * if an argument is provided, returns the canvasObject, otherwise returns the current value
///
/// Notes:
///  * The callback function should expect 5 arguments: the canvas object itself, a message specifying the type of mouse event, the canvas element `id` (or index position in the canvas if the `id` attribute is not set for the element), the x position of the mouse when the event was triggered within the rendered portion of the canvas element, and the y position of the mouse when the event was triggered within the rendered portion of the canvas element.
///  * See also [hs._asm.uitk.element.canvas:canvasMouseEvents](#canvasMouseEvents) for tracking mouse events in regions of the canvas not covered by an element with mouse tracking enabled.
///
///  * The following mouse attributes may be set to true for a canvas element and will invoke the callback with the specified message:
///    * `trackMouseDown`      - indicates that a callback should be invoked when a mouse button is clicked down on the canvas element.  The message will be "mouseDown".
///    * `trackMouseUp`        - indicates that a callback should be invoked when a mouse button has been released over the canvas element.  The message will be "mouseUp".
///    * `trackMouseEnterExit` - indicates that a callback should be invoked when the mouse pointer enters or exits the  canvas element.  The message will be "mouseEnter" or "mouseExit".
///    * `trackMouseMove`      - indicates that a callback should be invoked when the mouse pointer moves within the canvas element.  The message will be "mouseMove".
///
///  * The callback mechanism uses reverse z-indexing to determine which element will receive the callback -- the topmost element of the canvas which has enabled callbacks for the specified message will be invoked.
///
///  * No distinction is made between the left, right, or other mouse buttons. If you need to determine which specific button was pressed, use `hs.eventtap.checkMouseButtons()` within your callback to check.
///
///  * The hit point detection occurs by comparing the mouse pointer location to the rendered content of each individual canvas object... if an object which obscures a lower object does not have mouse tracking enabled, the lower object will still receive the event if it does have tracking enabled.
///
///  * Clipping regions which remove content from the visible area of a rendered object are ignored for the purposes of element hit-detection.
static int canvas_mouseCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;

    if (lua_gettop(L) == 1) {
        if (canvasView.mouseCallbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:canvasView.mouseCallbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        // We're either removing callback(s), or setting new one(s). Either way, remove existing.
        canvasView.mouseCallbackRef = [skin luaUnref:refTable ref:canvasView.mouseCallbackRef];
        canvasView.previousTrackedIndex = NSNotFound ;

        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2);
            canvasView.mouseCallbackRef = [skin luaRef:refTable] ;
        }

        lua_pushvalue(L, 1);
    }
    return 1;
}

/// hs._asm.uitk.element.canvas:canvasMouseEvents([down], [up], [enterExit], [move]) -> canvasObject | current values
/// Method
/// Get or set whether or not regions of the canvas which are not otherwise covered by an element with mouse tracking enabled should generate a callback for mouse events.
///
/// Parameters:
///  * `down`      - an optional boolean, or nil placeholder, specifying whether or not the mouse button being pushed down should generate a callback for the canvas areas not otherwise covered by an element with mouse tracking enabled.
///  * `up`        - an optional boolean, or nil placeholder, specifying whether or not the mouse button being released should generate a callback for the canvas areas not otherwise covered by an element with mouse tracking enabled.
///  * `enterExit` - an optional boolean, or nil placeholder, specifying whether or not the mouse pointer entering or exiting the canvas bounds should generate a callback for the canvas areas not otherwise covered by an element with mouse tracking enabled.
///  * `move`      - an optional boolean, or nil placeholder, specifying whether or not the mouse pointer moving within the canvas bounds should generate a callback for the canvas areas not otherwise covered by an element with mouse tracking enabled.
///
/// Returns:
///  * If any arguments are provided, returns the canvas Object, otherwise returns the current values in a table.
///
/// Notes:
///  * Each value that you wish to set must be provided in the order given above, but you may specify a position as `nil` to indicate that whatever it's current state, no change should be applied.  For example, to activate a callback for entering and exiting the canvas without changing the current callback status for up or down button clicks, you could use: `hs._asm.uitk.element.canvas:canvasMouseTracking(nil, nil, true)`.
///
///  * Use [hs._asm.uitk.element.canvas:mouseCallback](#mouseCallback) to set the callback function.  The identifier field in the callback's argument list will be "_canvas_", but otherwise identical to those specified in [hs._asm.uitk.element.canvas:mouseCallback](#mouseCallback).
static int canvas_canvasMouseEvents(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;

    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;

    if (lua_gettop(L) == 1) {
        lua_newtable(L) ;
        lua_pushboolean(L, canvasView.canvasMouseDown) ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushboolean(L, canvasView.canvasMouseUp) ;        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushboolean(L, canvasView.canvasMouseEnterExit) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        lua_pushboolean(L, canvasView.canvasMouseMove) ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    } else {
        if (lua_type(L, 2) == LUA_TTABLE) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK] ;
            lua_rawgeti(L, 2, 1) ;
            lua_rawgeti(L, 2, 2) ;
            lua_rawgeti(L, 2, 3) ;
            lua_rawgeti(L, 2, 4) ;
            lua_remove(L, 2) ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                            LS_TBOOLEAN | LS_TNIL,
                            LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                            LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                            LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                            LS_TBREAK] ;
        }
        if (lua_type(L, 2) == LUA_TBOOLEAN) {
            canvasView.canvasMouseDown = (BOOL)(lua_toboolean(L, 2)) ;
        }
        if (lua_type(L, 3) == LUA_TBOOLEAN) {
            canvasView.canvasMouseUp = (BOOL)(lua_toboolean(L, 3)) ;
        }
        if (lua_type(L, 4) == LUA_TBOOLEAN) {
            canvasView.canvasMouseEnterExit = (BOOL)(lua_toboolean(L, 4)) ;
        }
        if (lua_type(L, 5) == LUA_TBOOLEAN) {
            canvasView.canvasMouseMove = (BOOL)(lua_toboolean(L, 5)) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1;
}

/// hs._asm.uitk.element.canvas:imageFromCanvas() -> hs.image object
/// Method
/// Returns an image of the canvas contents as an `hs.image` object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an `hs.image` object
///
/// Notes:
///  * The canvas does not have to be visible in order for an image to be generated from it.
static int canvas_canvasAsImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBREAK] ;

    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;
    NSImage *image = [canvasView imageWithSubviews] ;
    [skin pushNSObject:image] ;
    return 1;
}

// documented in element_canvas.lua
static int canvas_alpha(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, canvasView.alphaValue) ;
    } else {
        CGFloat newLevel = luaL_checknumber(L, 2);
        canvasView.alphaValue = ((newLevel < 0.0) ? 0.0 : ((newLevel > 1.0) ? 1.0 : newLevel)) ;
        lua_pushvalue(L, 1);
    }

    return 1 ;
}

/// hs._asm.uitk.element.canvas:wantsLayer([flag]) -> canvasObject | currentValue
/// Method
/// Get or set whether or not the canvas object should be rendered by the view or by Core Animation.
///
/// Parameters:
///  * `flag` - optional boolean (default false) which indicates whether the canvas object should be rendered by the containing view (false) or by Core Animation (true).
///
/// Returns:
///  * If an argument is provided, the canvas object; otherwise the current value.
///
/// Notes:
///  * This method can help smooth the display of small text objects on non-Retina monitors.
static int canvas_wantsLayer(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;

    if (lua_type(L, 2) != LUA_TNONE) {
        [canvasView setWantsLayer:(BOOL)(lua_toboolean(L, 2))];
        canvasView.needsDisplay = YES ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, (BOOL)[canvasView wantsLayer]) ;
    }

    return 1;
}

/// hs._asm.uitk.element.canvas:canvasDefaultFor(keyName, [newValue]) -> canvasObject | currentValue
/// Method
/// Get or set the element default specified by keyName.
///
/// Parameters:
///  * `keyName` - the element default to examine or modify
///  * `value`   - an optional new value to set as the default fot his canvas when not specified explicitly in an element declaration.
///
/// Returns:
///  * If an argument is provided, the canvas object; otherwise the current value.
///
/// Notes:
///  * Not all keys will apply to all element types.
///  * Currently set and built-in defaults may be retrieved in a table with [hs._asm.uitk.element.canvas:canvasDefaults](#canvasDefaults).
static int canvas_canvasDefaultFor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;
    NSString *keyName = [skin toNSObjectAtIndex:2] ;

    if (!languageDictionary[keyName]) {
        return luaL_argerror(L, 2, [[NSString stringWithFormat:@"attribute name %@ unrecognized", keyName] UTF8String]) ;
    }

    NSObject *attributeDefault = [canvasView getDefaultValueFor:keyName onlyIfSet:NO] ;
    if (!attributeDefault) {
        return luaL_argerror(L, 2, [[NSString stringWithFormat:@"attribute %@ has no default value", keyName] UTF8String]) ;
    }

    if (lua_gettop(L) == 2) {
        [skin pushNSObject:attributeDefault] ;
    } else {
        NSObject *keyValue = [skin toNSObjectAtIndex:3 withOptions:LS_NSRawTables] ;

        switch([canvasView setDefaultFor:keyName to:keyValue withState:L]) {
            case attributeValid:
            case attributeNulling:
                break ;
            case attributeInvalid:
            default:
                if ([(NSNumber *)((NSDictionary *)languageDictionary)[keyName][@"nullable"] boolValue]) {
                    return luaL_argerror(L, 3, [[NSString stringWithFormat:@"invalid argument type for %@ specified", keyName] UTF8String]) ;
                } else {
                    return luaL_argerror(L, 2, [[NSString stringWithFormat:@"attribute default for %@ cannot be changed", keyName] UTF8String]) ;
                }
//                 break ;
        }

        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.canvas:insertElement(elementTable, [index]) -> canvasObject
/// Method
/// Insert a new element into the canvas at the specified index.
///
/// Parameters:
///  * `elementTable` - a table containing key-value pairs that define the element to be added to the canvas.
///  * `index`        - an optional integer between 1 and the canvas element count + 1 specifying the index position to put the new element.  Any element currently at that index, and those that follow, will be moved one position up in the element array.  Defaults to the canvas element count + 1 (i.e. after the end of the currently defined elements).
///
/// Returns:
///  * the canvasObject
///
/// Notes:
///  * see also [hs._asm.uitk.element.canvas:assignElement](#assignElement).
static int canvas_insertElementAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;
    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = (lua_gettop(L) == 3) ? (lua_tointeger(L, 3) - 1) : (NSInteger)elementCount ;

    if (tablePosition < 0 || tablePosition > (NSInteger)elementCount) {
        return luaL_argerror(L, 3, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
    }

    NSDictionary *element = [skin toNSObjectAtIndex:2 withOptions:LS_NSRawTables] ;
    if ([element isKindOfClass:[NSDictionary class]]) {
        NSString *elementType = element[@"type"] ;
        if (elementType && [ALL_TYPES containsObject:elementType]) {
            [canvasView.elementList insertObject:[[NSMutableDictionary alloc] init] atIndex:(NSUInteger)tablePosition] ;
            [element enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, id keyValue, __unused BOOL *stop) {
                // skip type in here to minimize the need to copy in defaults just to be overwritten
                if (![keyName isEqualTo:@"type"]) [canvasView setElementValueFor:keyName atIndex:(NSUInteger)tablePosition to:keyValue withState:L] ;
            }] ;
            [canvasView setElementValueFor:@"type" atIndex:(NSUInteger)tablePosition to:elementType withState:L] ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"invalid type %@; must be one of %@", elementType, [ALL_TYPES componentsJoinedByString:@", "]] UTF8String]) ;
        }
    } else {
        return luaL_argerror(L, 2, "invalid element definition; must contain key-value pairs");
    }

    canvasView.needsDisplay = YES ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.element.canvas:removeElement([index]) -> canvasObject
/// Method
/// Insert a new element into the canvas at the specified index.
///
/// Parameters:
///  * `index`        - an optional integer between 1 and the canvas element count specifying the index of the canvas element to remove. Any elements that follow, will be moved one position down in the element array.  Defaults to the canvas element count (i.e. the last element of the currently defined elements).
///
/// Returns:
///  * the canvasObject
static int canvas_removeElementAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;
    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = (lua_gettop(L) == 2) ? (lua_tointeger(L, 2) - 1) : (NSInteger)elementCount - 1 ;

    if (tablePosition < 0 || tablePosition >= (NSInteger)elementCount) {
        return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
    }

    NSUInteger realIndex = (NSUInteger)tablePosition ;
    [canvasView.elementList removeObjectAtIndex:realIndex] ;

    canvasView.needsDisplay = YES ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.element.canvas:elementAttribute(index, key, [value]) -> canvasObject | current value
/// Method
/// Get or set the attribute `key` for the canvas element at the specified index.
///
/// Parameters:
///  * `index` - the index of the canvas element whose attribute is to be retrieved or set.
///  * `key`   - the key name of the attribute to get or set.
///  * `value` - an optional value to assign to the canvas element's attribute.
///
/// Returns:
///  * if a value for the attribute is specified, returns the canvas object; otherwise returns the current value for the specified attribute.
static int canvas_elementAttributeAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TSTRING,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;
    NSString        *keyName      = [skin toNSObjectAtIndex:3] ;

    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = lua_tointeger(L, 2) - 1 ;

    BOOL            resolvePercentages = NO ;

    if (tablePosition < 0 || tablePosition >= (NSInteger)elementCount) {
        return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
    }

    if (!languageDictionary[keyName]) {
        if (lua_gettop(L) == 3) {
            // check if keyname ends with _raw, if so we get with converted numeric values
            if ([keyName hasSuffix:@"_raw"]) {
                keyName = [keyName substringWithRange:NSMakeRange(0, [keyName length] - 4)] ;
                if (languageDictionary[keyName]) resolvePercentages = YES ;
            }
            if (!resolvePercentages) {
                lua_pushnil(L) ;
                return 1 ;
            }
        } else {
            return luaL_argerror(L, 3, [[NSString stringWithFormat:@"attribute name %@ unrecognized", keyName] UTF8String]) ;
        }
    }

    if (lua_gettop(L) == 3) {
        [skin pushNSObject:[canvasView getElementValueFor:keyName atIndex:(NSUInteger)tablePosition resolvePercentages:resolvePercentages onlyIfSet:NO]] ;
    } else {
        NSObject *keyValue = [skin toNSObjectAtIndex:4 withOptions:LS_NSRawTables] ;
        switch([canvasView setElementValueFor:keyName atIndex:(NSUInteger)tablePosition to:keyValue withState:L]) {
            case attributeValid:
            case attributeNulling:
                lua_pushvalue(L, 1) ;
                break ;
            case attributeInvalid:
            default:
                return luaL_argerror(L, 4, [[NSString stringWithFormat:@"invalid argument type for %@ specified", keyName] UTF8String]) ;
//                 break ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.canvas:elementKeys(index, [optional]) -> table
/// Method
/// Returns a list of the key names for the attributes set for the canvas element at the specified index.
///
/// Parameters:
///  * `index`    - the index of the element to get the assigned key list from.
///  * `optional` - an optional boolean, default false, indicating whether optional, but unset, keys relevant to this canvas object should also be included in the list returned.
///
/// Returns:
///  * a table containing the keys that are set for this canvas element.  May also optionally include keys which are not specifically set for this element but use inherited values from the canvas or module defaults.
///
/// Notes:
///  * Any attribute which has been explicitly set for the element will be included in the key list (even if it is ignored for the element type).  If the `optional` flag is set to true, the *additional* attribute names added to the list will only include those which are relevant to the element type.
static int canvas_elementKeysAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;
    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = lua_tointeger(L, 2) - 1 ;

    if (tablePosition < 0 || tablePosition >= (NSInteger)elementCount) {
        return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
    }
    NSUInteger indexPosition = (NSUInteger)tablePosition ;

    NSMutableSet *list = [[NSMutableSet alloc] initWithArray:[(NSDictionary *)canvasView.elementList[indexPosition] allKeys]] ;
    if ((lua_gettop(L) == 3) && lua_toboolean(L, 3)) {
        NSString *ourType = canvasView.elementList[indexPosition][@"type"] ;
        [languageDictionary enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, NSDictionary *keyValue, __unused BOOL *stop) {
            if (keyValue[@"optionalFor"] && [(NSArray *)keyValue[@"optionalFor"] containsObject:ourType]) {
                [list addObject:keyName] ;
            }
        }] ;
    }
    [skin pushNSObject:list] ;
    return 1 ;
}

/// hs._asm.uitk.element.canvas:elementCount() -> integer
/// Method
/// Returns the number of elements currently defined for the canvas object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the number of elements currently defined for the canvas object.
static int canvas_elementCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;
    lua_pushinteger(L, (lua_Integer)[canvasView.elementList count]) ;
    return 1 ;
}

/// hs._asm.uitk.element.canvas:canvasDefaults([module]) -> table
/// Method
/// Get a table of the default key-value pairs which apply to the canvas.
///
/// Parameters:
///  * `module` - an optional boolean flag, default false, indicating whether module defaults (true) should be included in the table.  If false, only those defaults which have been explicitly set for the canvas are returned.
///
/// Returns:
///  * a table containing key-value pairs for the defaults which apply to the canvas.
///
/// Notes:
///  * Not all keys will apply to all element types.
///  * To change the defaults for the canvas, use [hs._asm.uitk.element.canvas:canvasDefaultFor](#canvasDefaultFor).
static int canvas_canvasDefaults(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;
    if ((lua_gettop(L) == 2) && lua_toboolean(L, 2)) {
        lua_newtable(L) ;
        for (NSString *keyName in languageDictionary) {
            NSObject *keyValue = [canvasView getDefaultValueFor:keyName onlyIfSet:NO] ;
            if (keyValue) {
                [skin pushNSObject:keyValue] ; lua_setfield(L, -2, [keyName UTF8String]) ;
            }
        }
    } else {
        [skin pushNSObject:canvasView.canvasDefaults withOptions:LS_NSDescribeUnknownTypes] ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.canvas:canvasDefaultKeys([module]) -> table
/// Method
/// Returns a list of the key names for the attributes set for the canvas defaults.
///
/// Parameters:
///  * `module` - an optional boolean flag, default false, indicating whether the key names for the module defaults (true) should be included in the list.  If false, only those defaults which have been explicitly set for the canvas are included.
///
/// Returns:
///  * a table containing the key names for the defaults which are set for this canvas. May also optionally include key names for all attributes which have a default value defined by the module.
static int canvas_canvasDefaultKeys(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;

    NSMutableSet *list = [[NSMutableSet alloc] initWithArray:[(NSDictionary *)canvasView.canvasDefaults allKeys]] ;
    if ((lua_gettop(L) == 2) && lua_toboolean(L, 2)) {
        [languageDictionary enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, NSDictionary *keyValue, __unused BOOL *stop) {
            if (keyValue[@"default"]) {
                [list addObject:keyName] ;
            }
        }] ;
    }
    [skin pushNSObject:list] ;
    return 1 ;
}

/// hs._asm.uitk.element.canvas:canvasElements() -> table
/// Method
/// Returns an array containing the elements defined for this canvas.  Each array entry will be a table containing the key-value pairs which have been set for that canvas element.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an array of element tables which are defined for the canvas.
static int canvas_canvasElements(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBREAK] ;
    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;
    [skin pushNSObject:canvasView.elementList withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

/// hs._asm.uitk.element.canvas:elementBounds(index) -> rectTable
/// Method
/// Returns the smallest rectangle which can fully contain the canvas element at the specified index.
///
/// Parameters:
///  * `index` - the index of the canvas element to get the bounds for
///
/// Returns:
///  * a rect table containing the smallest rectangle which can fully contain the canvas element.
///
/// Notes:
///  * For many elements, this will be the same as the element frame.  For items without a frame (e.g. `segments`, `circle`, etc.) this will be the smallest rectangle which can fully contain the canvas element as specified by it's attributes.
static int canvas_elementBoundsAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TBREAK] ;
    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;

    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = (lua_tointeger(L, 2) - 1) ;

    if (tablePosition < 0 || tablePosition >= (NSInteger)elementCount) {
        return luaL_argerror(L, 3, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
    }

    NSUInteger   idx         = (NSUInteger)tablePosition ;
    NSRect       boundingBox = NSZeroRect ;
    NSBezierPath *itemPath   = [canvasView pathForElementAtIndex:idx] ;
    if (itemPath) {
        if ([itemPath isEmpty]) {
            boundingBox = NSZeroRect ;
        } else {
            boundingBox = [itemPath bounds] ;
        }
    } else {
        NSString *itemType = canvasView.elementList[idx][@"type"] ;
        if ([itemType isEqualToString:@"image"] || [itemType isEqualToString:@"text"]) {
            NSDictionary *frame = (NSDictionary *)[canvasView getElementValueFor:@"frame"
                                                                         atIndex:idx
                                                              resolvePercentages:YES] ;
            boundingBox = NSMakeRect([(NSNumber *)frame[@"x"] doubleValue], [(NSNumber *)frame[@"y"] doubleValue],
                                     [(NSNumber *)frame[@"w"] doubleValue], [(NSNumber *)frame[@"h"] doubleValue]) ;
        } else {
            lua_pushnil(L) ;
            return 1 ;
        }
    }
    [skin pushNSRect:boundingBox] ;
    return 1 ;
}

/// hs._asm.uitk.element.canvas:assignElement(elementTable, [index]) -> canvasObject
/// Method
/// Assigns a new element to the canvas at the specified index.
///
/// Parameters:
///  * `elementTable` - a table containing key-value pairs that define the element to be added to the canvas.
///  * `index`        - an optional integer between 1 and the canvas element count + 1 specifying the index position to put the new element.  Any element currently at that index will be replaced.  Defaults to the canvas element count + 1 (i.e. after the end of the currently defined elements).
///
/// Returns:
///  * the canvasObject
///
/// Notes:
///  * When the index specified is the canvas element count + 1, the behavior of this method is the same as [hs._asm.uitk.element.canvas:insertElement](#insertElement); i.e. it adds the new element to the end of the currently defined element list.
static int canvas_assignElementAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TNIL,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementCanvas   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;

    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = (lua_gettop(L) == 3) ? (lua_tointeger(L, 3) - 1) : (NSInteger)elementCount ;

    if (tablePosition < 0 || tablePosition > (NSInteger)elementCount) {
        return luaL_argerror(L, 3, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
    }

    if (lua_isnil(L, 2)) {
        if (tablePosition == (NSInteger)elementCount - 1) {
            [canvasView.elementList removeLastObject] ;
        } else {
            return luaL_argerror(L, 3, "nil only valid for final element") ;
        }
    } else {
        NSDictionary *element = [skin toNSObjectAtIndex:2 withOptions:LS_NSRawTables] ;
        if ([element isKindOfClass:[NSDictionary class]]) {
            NSString *elementType = element[@"type"] ;
            if (elementType && [ALL_TYPES containsObject:elementType]) {
                NSUInteger realIndex = (NSUInteger)tablePosition ;
                canvasView.elementList[realIndex] = [[NSMutableDictionary alloc] init] ;
                [element enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, id keyValue, __unused BOOL *stop) {
                    // skip type in here to minimize the need to copy in defaults just to be overwritten
                    if (![keyName isEqualTo:@"type"]) [canvasView setElementValueFor:keyName atIndex:realIndex to:keyValue withState:L] ;
                }] ;
                [canvasView setElementValueFor:@"type" atIndex:realIndex to:elementType withState:L] ;
            } else {
                return luaL_argerror(L, 2, [[NSString stringWithFormat:@"invalid type %@; must be one of %@", elementType, [ALL_TYPES componentsJoinedByString:@", "]] UTF8String]) ;
            }
        } else {
            return luaL_argerror(L, 2, "invalid element definition; must contain key-value pairs");
        }
    }

    canvasView.needsDisplay = YES ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.element.canvas:size([size]) -> canvasObject | currentValue
/// Method
/// Get or set the size of a canvas object
///
/// Parameters:
///  * `size` - An optional size-table specifying the width and height the canvas object should be resized to
///
/// Returns:
///  * If an argument is provided, the canvas object; otherwise the current value.
///
/// Notes:
///  * a size-table is a table with key-value pairs specifying the size (keys `h` and `w`) the canvas should be resized to. The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
static int canvas_size(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSUITKElementCanvas *canvasView = [skin luaObjectAtIndex:1 toClass:"HSUITKElementCanvas"] ;
    NSSize              oldSize     = canvasView.frame.size ;

    if (lua_gettop(L) == 1) {
        [skin pushNSSize:oldSize] ;
    } else {
        NSSize newSize = [skin tableToSizeAtIndex:2] ;

        CGFloat xFactor = newSize.width  / oldSize.width ;
        CGFloat yFactor = newSize.height / oldSize.height ;

        for (NSUInteger i = 0 ; i < [canvasView.elementList count] ; i++) {
            NSNumber *absPos = (NSNumber *)[canvasView getElementValueFor:@"absolutePosition" atIndex:i] ;
            NSNumber *absSiz = (NSNumber *)[canvasView getElementValueFor:@"absoluteSize" atIndex:i] ;
            if (absPos && absSiz) {
                BOOL absolutePosition = absPos ? [absPos boolValue] : YES ;
                BOOL absoluteSize     = absSiz ? [absSiz boolValue] : YES ;
                NSMutableDictionary *attributeDefinition = canvasView.elementList[i] ;
                if (!absolutePosition) {
                    [attributeDefinition enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, NSObject *keyValue, __unused BOOL *stop) {
                        NSMutableDictionary *keyValueAsMDictionary = (NSMutableDictionary *)keyValue ;

                        if ([keyName isEqualToString:@"center"] || [keyName isEqualToString:@"frame"]) {
                            if ([(NSObject *)keyValueAsMDictionary[@"x"] isKindOfClass:[NSNumber class]]) {
                                keyValueAsMDictionary[@"x"] = [NSNumber numberWithDouble:([(NSNumber *)keyValueAsMDictionary[@"x"] doubleValue] * xFactor)] ;
                            }
                            if ([(NSObject *)keyValueAsMDictionary[@"y"] isKindOfClass:[NSNumber class]]) {
                                keyValueAsMDictionary[@"y"] = [NSNumber numberWithDouble:([(NSNumber *)keyValueAsMDictionary[@"y"] doubleValue] * yFactor)] ;
                            }
                        } else if ([keyName isEqualTo:@"coordinates"]) {
                            [(NSMutableArray *)keyValue enumerateObjectsUsingBlock:^(NSMutableDictionary *subItem, __unused NSUInteger idx, __unused BOOL *stop2) {
                                for (NSString *field in @[ @"x", @"y", @"c1x", @"c1y", @"c2x", @"c2y" ]) {
                                    if (subItem[field] && [(NSNumber *)subItem[field] isKindOfClass:[NSNumber class]]) {
                                        CGFloat ourFactor = [field hasSuffix:@"x"] ? xFactor : yFactor ;
                                        subItem[field] = [NSNumber numberWithDouble:([(NSNumber *)subItem[field] doubleValue] * ourFactor)] ;
                                    }
                                }
                            }] ;

                        }
                    }] ;
                }
                if (!absoluteSize) {
                    [attributeDefinition enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, NSObject *keyValue, __unused BOOL *stop) {
                        NSMutableDictionary *keyValueAsMDictionary = (NSMutableDictionary *)keyValue ;

                        if ([keyName isEqualToString:@"frame"]) {
                            if ([(NSObject *)keyValueAsMDictionary[@"h"] isKindOfClass:[NSNumber class]]) {
                                keyValueAsMDictionary[@"h"] = [NSNumber numberWithDouble:([(NSNumber *)keyValueAsMDictionary[@"h"] doubleValue] * yFactor)] ;
                            }
                            if ([(NSObject *)keyValueAsMDictionary[@"w"] isKindOfClass:[NSNumber class]]) {
                                keyValueAsMDictionary[@"w"] = [NSNumber numberWithDouble:([(NSNumber *)keyValueAsMDictionary[@"w"] doubleValue] * xFactor)] ;
                            }
                        } else if ([keyName isEqualToString:@"radius"]) {
                            if ([keyValue isKindOfClass:[NSNumber class]]) {
                                attributeDefinition[keyName] = [NSNumber numberWithDouble:([(NSNumber *)keyValue doubleValue] * xFactor)] ;
                            }
                        }
                    }] ;
                }
            } else {
                [skin logError:[NSString stringWithFormat:@"%s:unable to get absolute positioning info for index position %lu", USERDATA_TAG, i + 1]] ;
            }
        }

        [canvasView setFrameSize:newSize] ;

        lua_pushvalue(L, 1) ;
    }

    return 1 ;
}

#pragma mark - Module Constants -

/// hs._asm.uitk.element.canvas.compositeTypes[]
/// Constant
/// A table containing the possible compositing rules for elements within the canvas.
///
/// Compositing rules specify how an element assigned to the canvas is combined with the earlier elements of the canvas. The default compositing rule for the canvas is `sourceOver`, but each element of the canvas can be assigned a composite type which overrides this default for the specific element.
///
/// The available types are as follows:
///  * `clear`           - Transparent. (R = 0)
///  * `copy`            - Source image. (R = S)
///  * `sourceOver`      - Source image wherever source image is opaque, and destination image elsewhere. (R = S + D*(1 - Sa))
///  * `sourceIn`        - Source image wherever both images are opaque, and transparent elsewhere. (R = S*Da)
///  * `sourceOut`       - Source image wherever source image is opaque but destination image is transparent, and transparent elsewhere. (R = S*(1 - Da))
///  * `sourceAtop`      - Source image wherever both images are opaque, destination image wherever destination image is opaque but source image is transparent, and transparent elsewhere. (R = S*Da + D*(1 - Sa))
///  * `destinationOver` - Destination image wherever destination image is opaque, and source image elsewhere. (R = S*(1 - Da) + D)
///  * `destinationIn`   - Destination image wherever both images are opaque, and transparent elsewhere. (R = D*Sa)
///  * `destinationOut`  - Destination image wherever destination image is opaque but source image is transparent, and transparent elsewhere. (R = D*(1 - Sa))
///  * `destinationAtop` - Destination image wherever both images are opaque, source image wherever source image is opaque but destination image is transparent, and transparent elsewhere. (R = S*(1 - Da) + D*Sa)
///  * `XOR`             - Exclusive OR of source and destination images. (R = S*(1 - Da) + D*(1 - Sa)). Works best with black and white images and is not recommended for color contexts.
///  * `plusDarker`      - Sum of source and destination images, with color values approaching 0 as a limit. (R = MAX(0, (1 - D) + (1 - S)))
///  * `plusLighter`     - Sum of source and destination images, with color values approaching 1 as a limit. (R = MIN(1, S + D))
///
/// In each equation, R is the resulting (premultiplied) color, S is the source color, D is the destination color, Sa is the alpha value of the source color, and Da is the alpha value of the destination color.
///
/// The `source` object is the individual element as it is rendered in order within the canvas, and the `destination` object is the combined state of the previous elements as they have been composited within the canvas.
static int canvas_compositeTypes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:COMPOSITING_TYPES] ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementCanvas(lua_State *L, id obj) {
    HSUITKElementCanvas *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementCanvas *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementCanvas(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementCanvas *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementCanvas, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementCanvas *theView = get_objectFromUserdata(__bridge_transfer HSUITKElementCanvas, L, 1, USERDATA_TAG) ;
    if (theView) {
        theView.selfRefCount-- ;
        if (theView.selfRefCount == 0) {
            theView.callbackRef         = [skin luaUnref:refTable ref:theView.callbackRef] ;
            theView.mouseCallbackRef    = [skin luaUnref:refTable ref:theView.mouseCallbackRef] ;
            theView.draggingCallbackRef = [skin luaUnref:refTable ref:theView.draggingCallbackRef] ;

            NSDockTile *tile     = [[NSApplication sharedApplication] dockTile];
            NSView     *tileView = tile.contentView ;
            if (tileView && [theView isEqualTo:tileView]) tile.contentView = nil ;
        }
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
//     {"passthroughCallback", canvas_passthroughCallback},
    {"assignElement",       canvas_assignElementAtIndex},
    {"imageFromCanvas",     canvas_canvasAsImage},
    {"canvasDefaultFor",    canvas_canvasDefaultFor},
    {"canvasDefaultKeys",   canvas_canvasDefaultKeys},
    {"canvasDefaults",      canvas_canvasDefaults},
    {"canvasElements",      canvas_canvasElements},
    {"canvasMouseEvents",   canvas_canvasMouseEvents},
    {"transformation",      canvas_canvasTransformation},
    {"draggingCallback",    canvas_draggingCallback},
    {"elementAttribute",    canvas_elementAttributeAtIndex},
    {"elementBounds",       canvas_elementBoundsAtIndex},
    {"elementCount",        canvas_elementCount},
    {"elementKeys",         canvas_elementKeysAtIndex},
    {"minimumTextSize",     canvas_getTextElementSize},
    {"insertElement",       canvas_insertElementAtIndex},
    {"removeElement",       canvas_removeElementAtIndex},
    {"wantsLayer",          canvas_wantsLayer},
    {"alpha",               canvas_alpha},
    {"mouseCallback",       canvas_mouseCallback},

    {"size",                canvas_size},
    {"frameSize",           canvas_size}, // override default frameSize from __view

// other metamethods inherited from _control and _view
    {"__gc",                userdata_gc},
    {NULL,    NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"defaultTextStyle", canvas_defaultTextAttributes},
    {"elementSpec",      canvas_dumpLanguageDictionary},
    {"new",              canvas_new},
    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_element_libcanvas(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKElementCanvas  forClass:"HSUITKElementCanvas"];
    [skin registerLuaObjectHelper:toHSUITKElementCanvas forClass:"HSUITKElementCanvas"
                                             withUserdataMapping:USERDATA_TAG];

    canvas_compositeTypes(L) ;      lua_setfield(L, -2, "compositeTypes") ;

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
//         "passthroughCallback",
        @"draggingCallback",
        @"transformation",
        @"mouseCallback",
        @"alpha",
        @"wantsLayer",
        @"frameSize",
        @"canvasMouseEvents",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    // lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}
