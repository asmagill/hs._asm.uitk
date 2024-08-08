@import Cocoa ;
@import LuaSkin ;
@import AVKit ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.avplayer" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static const int32_t PREFERRED_TIMESCALE = 60000 ; // see https://warrenmoore.net/understanding-cmtime
static void *myKVOContext = &myKVOContext ; // See http://nshipster.com/key-value-observing/

static NSDictionary *CONTROLS_STYLES ;
static NSDictionary *VIDEO_GRAVITY ;
static NSDictionary *ANALYSIS_TYPES ;
static NSDictionary *BACKGROUND_POLICY ;
static NSDictionary *WAITING_REASON ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    CONTROLS_STYLES = @{
        @"none"     : @(AVPlayerViewControlsStyleNone),
        @"inline"   : @(AVPlayerViewControlsStyleInline),
        @"floating" : @(AVPlayerViewControlsStyleFloating),
        @"minimal"  : @(AVPlayerViewControlsStyleMinimal),
        @"default"  : @(AVPlayerViewControlsStyleDefault),
    } ;

    VIDEO_GRAVITY = @{
        @"fill"                  : AVLayerVideoGravityResize,
        @"preserveAspect"        : AVLayerVideoGravityResizeAspect,
        @"fillAndPreserveAspect" : AVLayerVideoGravityResizeAspectFill,
    } ;

    if (@available(macOS 14, *)) {
        ANALYSIS_TYPES = @{
            @"none"         : @(AVVideoFrameAnalysisTypeNone),
            @"default"      : @(AVVideoFrameAnalysisTypeDefault),
            @"text"         : @(AVVideoFrameAnalysisTypeText),
            @"subject"      : @(AVVideoFrameAnalysisTypeSubject),
            @"visualSearch" : @(AVVideoFrameAnalysisTypeVisualSearch),
        } ;
    }

    if (@available(macOS 12, *)) {
        BACKGROUND_POLICY = @{
            @"automatic" : @(AVPlayerAudiovisualBackgroundPlaybackPolicyAutomatic),
            @"continue"  : @(AVPlayerAudiovisualBackgroundPlaybackPolicyContinuesIfPossible),
            @"pause"     : @(AVPlayerAudiovisualBackgroundPlaybackPolicyPauses),
        } ;

        WAITING_REASON = @{
            AVPlayerWaitingWhileEvaluatingBufferingRateReason : @"evaluatingBufferingRate",
            AVPlayerWaitingWithNoItemToPlayReason             : @"noItemToPlay",
            AVPlayerWaitingToMinimizeStallsReason             : @"minimizingStalls",
            AVPlayerWaitingDuringInterstitialEventReason      : @"interstitialEvent",
            AVPlayerWaitingForCoordinatedPlaybackReason       : @"coordinatingPlayback",
        } ;
    }

}

@interface NSMenu (assignmentSharing)
@property (weak) NSView *assignedTo ;
@end

@interface HSUITKElementAVPlayer : AVPlayerView <AVPlayerViewDelegate, AVPlayerViewPictureInPictureDelegate>
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;
@property            BOOL       pauseWhenHidden ;
@property            BOOL       trackCompleted ;
@property            BOOL       trackRate ;
@property            BOOL       trackStatus ;
@property            BOOL       trackPlayback ;
@property            id         periodicObserver ;
@property            lua_Number periodicPeriod ;
@end

@implementation HSUITKElementAVPlayer {
    float _rateWhenHidden ;
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

        _pauseWhenHidden                 = YES ;
        _trackCompleted                  = NO ;
        _trackRate                       = NO ;
        _trackStatus                     = NO ;
        _trackPlayback                   = NO ;
        _periodicObserver                = nil ;
        _periodicPeriod                  = 0.0 ;

        _rateWhenHidden                  = 0.0f ;

        self.controlsStyle               = AVPlayerViewControlsStyleDefault ;
        self.showsFrameSteppingButtons   = NO ;
        self.showsSharingServiceButton   = NO ;
        self.showsFullScreenToggleButton = NO ;
        self.actionPopUpButtonMenu       = nil ;
        self.pictureInPictureDelegate    = self ;
        if (@available(macOS 12, *)) {
            self.delegate                = self ;
        }

        self.player                      = [[AVPlayer alloc] init] ;
        self.player.actionAtItemEnd      = AVPlayerActionAtItemEndPause ;
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

- (void)didFinishPlaying:(__unused NSNotification *)notification {
    if (_trackCompleted) [self callbackHamster:@[ self, @"finished" ]] ;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == myKVOContext) {
        if ([keyPath isEqualToString:@"rate"]) {
            if (_trackRate) {
                NSString *message = (self.player.rate == 0.0f) ? @"pause" : @"play" ;
                [self callbackHamster:@[ self, message, @(self.player.rate) ]] ;
            }
            return ;
        } else if ([keyPath isEqualToString:@"status"]) {
            if (_trackStatus) {
                NSMutableArray *args = [NSMutableArray arrayWithArray:@[ self, @"status" ]] ;
                switch(self.player.currentItem.status) {
                    case AVPlayerStatusUnknown:
                        [args addObject:@"unknown"] ;
                        break ;
                    case AVPlayerStatusReadyToPlay:
                        [args addObject:@"readyToPlay"] ;
                        break ;
                    case AVPlayerStatusFailed: {
                        NSString *message = self.player.currentItem.error.localizedDescription ;
                        if (!message) message = @"no reason given" ;
                        [args addObjectsFromArray:@[ @"failed", message ]] ;
                        } break ;
                    default:
                        [args addObjectsFromArray:@[ @"unrecognized", @(self.player.currentItem.status) ]] ;
                        break ;
                }
                [self callbackHamster:args] ;
            }
            return ;
        } else if ([keyPath isEqualToString:@"timeControlStatus"]) {
            if (@available(macOS 12, *)) {
                if (_trackPlayback) {
                    NSMutableArray *args = [NSMutableArray arrayWithArray:@[ self, @"playback" ]] ;
                    switch(self.player.timeControlStatus) {
                        case AVPlayerTimeControlStatusPaused:
                            [args addObject:@"paused"] ;
                            break ;
                        case AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate:
                            [args addObject:@"waiting"] ;
                            break ;
                        case AVPlayerTimeControlStatusPlaying:
                            [args addObject:@"playing"] ;
                            break ;
                        default:
                            [args addObjectsFromArray:@[ @"unrecognized", @(self.player.timeControlStatus) ]] ;
                            break ;
                    }
                    NSString *reason = self.player.reasonForWaitingToPlay ;
                    if (reason) {
                        NSString *message = WAITING_REASON[reason] ;
                        if (!message) message = [NSString stringWithFormat:@"unrecognized reason '%@'", reason] ;
                        [args addObject:message] ;
                    }
                    [self callbackHamster:args] ;
                }
            }
            return ;
        } else {
            [LuaSkin logWarn:[NSString stringWithFormat:@"%s:observeValueForKeyPath - unhandled path '%@' with our context", USERDATA_TAG, keyPath]] ;
        }
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context] ;
}

- (void)viewDidHide {
//     [LuaSkin logInfo:@"entered viewDidHide"] ;
    if (_pauseWhenHidden && _rateWhenHidden == 0.0f) {
        _rateWhenHidden = self.player.rate ;
        [self.player pause] ;
    }
}

- (void)viewDidUnhide {
//     [LuaSkin logInfo:@"entered viewDidUnhide"] ;
    if (_rateWhenHidden != 0.0f) {
        [self.player play] ; // see api docs for AVPlayer defaultRate
        self.player.rate = _rateWhenHidden ;
        _rateWhenHidden = 0.0f ;
    }
}

- (void)viewDidMoveToSuperview {
    if (self.superview) {
        [self viewDidUnhide] ;
    } else {
        [self viewDidHide] ;
    }
}

- (void)viewDidMoveToWindow {
    if (self.window) {
        [self viewDidUnhide] ;
    } else {
        [self viewDidHide] ;
    }
}

#pragma mark AVPlayerViewDelegate Methods

// - (void)playerViewWillEnterFullScreen:(AVPlayerView *)playerView;
// - (void)playerViewDidEnterFullScreen:(AVPlayerView *)playerView;
// - (void)playerViewWillExitFullScreen:(AVPlayerView *)playerView;
// - (void)playerViewDidExitFullScreen:(AVPlayerView *)playerView;
// - (void)playerView:(AVPlayerView *)playerView restoreUserInterfaceForFullScreenExitWithCompletionHandler:(void (^)(BOOL restored))completionHandler;

#pragma mark AVPlayerViewPictureInPictureDelegate Methods

// - (BOOL)playerViewShouldAutomaticallyDismissAtPictureInPictureStart:(AVPlayerView *)playerView;
// - (void)playerView:(AVPlayerView *)playerView failedToStartPictureInPictureWithError:(NSError *)error;
// - (void)playerView:(AVPlayerView *)playerView restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler;
// - (void)playerViewDidStartPictureInPicture:(AVPlayerView *)playerView;
// - (void)playerViewDidStopPictureInPicture:(AVPlayerView *)playerView;
// - (void)playerViewWillStartPictureInPicture:(AVPlayerView *)playerView;
// - (void)playerViewWillStopPictureInPicture:(AVPlayerView *)playerView;

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.avplayer.new([frame]) -> avplayerObject
/// Constructor
/// Creates a new avplayer element for `hs._asm.uitk.window` which can display audiovisual media.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the frame for the element.
///
/// Returns:
///  * the avplayerObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a container element or to a `hs._asm.uitk.window`.
static int avplayerview_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementAVPlayer *element = [[HSUITKElementAVPlayer alloc] initWithFrame:frameRect];
    if (element) {
        if (lua_gettop(L) != 1) [element setFrameSize:[element fittingSize]] ;
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods : AVPlayerView -

/// hs._asm.uitk.element.avplayer:controlsStyle([style]) -> avplayerObject | string
/// Method
/// Get or set the style of controls displayed in the avplayerObject for controlling media playback.
///
/// Parameters:
///  * `style` - an optional string, default "default", specifying the stye of the controls displayed for controlling media playback.  The string may be one of the following:
///    * `none`     - no controls are provided -- playback must be managed programmatically through Hammerspoon Lua code.
///    * `inline`   - media controls are displayed in an autohiding status bar at the bottom of the media display.
///    * `floating` - media controls are displayed in an autohiding panel which floats over the media display.
///    * `minimal`  - media controls are displayed as a round circle in the center of the media display.
///    * `none`     - no media controls are displayed in the media display.
///    * `default`  - use the OS X default control style; under OS X 10.11, this is the "inline".
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
static int avplayerview_controlsStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *controlsStyle = @(playerView.controlsStyle) ;
        NSArray *temp = [CONTROLS_STYLES allKeysForObject:controlsStyle];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized controls style %@ -- notify developers", USERDATA_TAG, controlsStyle]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *controlsStyle = CONTROLS_STYLES[key] ;
        if (controlsStyle) {
            playerView.controlsStyle = [controlsStyle integerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [CONTROLS_STYLES.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:frameSteppingButtons([state]) -> avplayerObject | boolean
/// Method
/// Get or set whether frame stepping or fast-forward/rewind controls are included in the media controls.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether frame stepping (true) or fast-forward/rewind (false) controls are included in the media controls.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
///
/// Notes:
///  * This property is currently supported only when [hs._asm.uitk.element.avplayer:controlsStyle](#controlsStyle) is set to "floating".
static int avplayerview_showsFrameSteppingButtons(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.showsFrameSteppingButtons) ;
    } else {
        playerView.showsFrameSteppingButtons = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:flashChapterAndTitle(number, [string]) -> avplayerObject
/// Method
/// Flashes the number and optional string over the media playback display momentarily.
///
/// Parameters:
///  * `number` - an integer specifying the chapter number to display.
///  * `string` - an optional string specifying the chapter name to display.
///
/// Returns:
///  * the avplayerObject
///
/// Notes:
///  * If only a number is provided, the text "Chapter #" is displayed.  If a string is also provided, "#. string" is displayed.
static int avplayerview_flashChapterAndTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TSTRING | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    NSUInteger          chapterNumber = (lua_Unsigned)lua_tointeger(L, 2) ;
    NSString            *chapterTitle = (lua_gettop(L) == 3) ? [skin toNSObjectAtIndex:3] : nil ;

    [playerView flashChapterNumber:chapterNumber chapterTitle:chapterTitle] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:pauseWhenHidden([state]) -> avplayerObject | boolean
/// Method
/// Get or set whether or not playback of media should be paused when the avplayer object is hidden.
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether or not media playback should be paused when the avplayer object is hidden.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
static int avplayerview_pauseWhenHidden(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.pauseWhenHidden) ;
    } else {
        playerView.pauseWhenHidden = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:sharingServiceButton([state]) -> avplayerObject | boolean
/// Method
/// Get or set whether or not the sharing services button is included in the media controls.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not the sharing services button is included in the media controls.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
static int avplayerview_showsSharingServiceButton(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.showsSharingServiceButton) ;
    } else {
        playerView.showsSharingServiceButton = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:fullScreenButton([state]) -> avplayerObject | boolean
/// Method
/// Get or set whether or not the full screen toggle button should be included in the media controls.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not the full screen toggle button should be included in the media controls.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
static int avplayerview_showsFullScreenToggleButton(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.showsFullScreenToggleButton) ;
    } else {
        playerView.showsFullScreenToggleButton = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int avplayerview_showsTimecodes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.showsTimecodes) ;
    } else {
        playerView.showsTimecodes = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int avplayerview_updatesNowPlayingInfoCenter(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.updatesNowPlayingInfoCenter) ;
    } else {
        playerView.updatesNowPlayingInfoCenter = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int avplayerview_allowsMagnification(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if (@available(macOS 13, *)) {
            lua_pushboolean(L, playerView.allowsMagnification) ;
        } else {
            lua_pushboolean(L, false) ;
        }
    } else {
        if (@available(macOS 13, *)) {
            playerView.allowsMagnification = (BOOL)(lua_toboolean(L, 2)) ;
        } else {
            [skin logInfo:[NSString stringWithFormat:@"%s:allowMagnification - only supported in macOS 13 and newer", USERDATA_TAG]] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int avplayerview_allowsPictureInPicturePlayback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.allowsPictureInPicturePlayback) ;
    } else {
        playerView.allowsPictureInPicturePlayback = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int avplayerview_allowsVideoFrameAnalysis(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if (@available(macOS 13, *)) {
            lua_pushboolean(L, playerView.allowsVideoFrameAnalysis) ;
        } else {
            lua_pushboolean(L, false) ;
        }
    } else {
        if (@available(macOS 13, *)) {
            playerView.allowsVideoFrameAnalysis = (BOOL)(lua_toboolean(L, 2)) ;
        } else {
            [skin logInfo:[NSString stringWithFormat:@"%s:allowFrameAnalysis - only supported in macOS 13 and newer", USERDATA_TAG]] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int avplayerview_actionMenu(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:playerView.actionPopUpButtonMenu withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        NSMenu *oldMenu = nil ;

        if (lua_type(L, 2) == LUA_TNIL) {
            oldMenu     = playerView.actionPopUpButtonMenu ;
            playerView.actionPopUpButtonMenu = nil ;
        } else {
            [skin checkArgs:LS_TANY, LS_TUSERDATA, "hs._asm.uitk.menu", LS_TBREAK] ;
            oldMenu      = playerView.actionPopUpButtonMenu ;
            NSMenu *menu = [skin toNSObjectAtIndex:2] ;
            menu.assignedTo = playerView ;
            playerView.actionPopUpButtonMenu = menu ;
            [skin luaRetain:refTable forNSObject:menu] ;
        }

        if (oldMenu) {
            oldMenu.assignedTo = nil ;
            [skin luaRelease:refTable forNSObject:oldMenu] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int avplayerview_magnification(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK | LS_TVARARG] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if (@available(macOS 13, *)) {
            lua_pushnumber(L, playerView.magnification) ;
        } else {
            lua_pushboolean(L, false) ;
        }
    } else {
        [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
        if (@available(macOS 13, *)) {
            CGFloat magnification = lua_tonumber(L, 2) ;
            if (lua_gettop(L) == 2) {
                playerView.magnification = magnification ;
            } else {
                NSPoint centerOn = [skin tableToPointAtIndex:3] ;
                [playerView setMagnification:magnification centeredAtPoint:centerOn] ;
            }
        } else {
            [skin logInfo:[NSString stringWithFormat:@"%s:magnification - only supported in macOS 13 and newer", USERDATA_TAG]] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int avplayerview_videoGravity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSString *string = playerView.videoGravity ;
        NSArray *temp = [VIDEO_GRAVITY allKeysForObject:string];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized video gravity %@ -- notify developers", USERDATA_TAG, string]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSString *string = VIDEO_GRAVITY[key] ;
        if (string) {
            playerView.videoGravity = string ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [VIDEO_GRAVITY.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

static int avplayerview_videoFrameAnalysisTypes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        if (@available(macOS 14, *)) {
            NSNumber *number = @(playerView.videoFrameAnalysisTypes) ;
            NSArray *temp = [ANALYSIS_TYPES allKeysForObject:number];
            NSString *answer = [temp firstObject] ;
            if (answer) {
                [skin pushNSObject:answer] ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized frame analysis type %@ -- notify developers", USERDATA_TAG, number]] ;
                lua_pushnil(L) ;
            }
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (@available(macOS 14, *)) {
            NSString *key = [skin toNSObjectAtIndex:2] ;
            NSNumber *number = ANALYSIS_TYPES[key] ;
            if (number) {
                playerView.videoFrameAnalysisTypes = [number unsignedIntegerValue] ;
                lua_pushvalue(L, 1) ;
            } else {
                return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [ANALYSIS_TYPES.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
            }
        } else {
            [skin logInfo:[NSString stringWithFormat:@"%s:frameAnalysisType - only supported in macOS 13 and newer", USERDATA_TAG]] ;
        }
    }
    return 1 ;
}

// TODO: add one of our containers as a subview and then set constraint so it tracks superview size
//     @property(readonly) NSRect videoBounds;
//     @property(readonly) NSView *contentOverlayView;

// FIXME: things to consider
// is AVPlayer rate sufficient?
//     - (void)selectSpeed:(AVPlaybackSpeed *)speed;
//     @property(copy) NSArray<AVPlaybackSpeed *> *speeds;
//     @property(readonly) AVPlaybackSpeed *selectedSpeed;

// How useful?
//     @property(readonly, getter=isReadyForDisplay) BOOL readyForDisplay;
//
//     - (void)beginTrimmingWithCompletionHandler:(void (^)(AVPlayerViewTrimResult result))handler;
//     @property(readonly) BOOL canBeginTrimming;

#pragma mark - Module Methods : AVPlayer -

/// hs._asm.uitk.element.avplayer:load(path) -> avplayerObject
/// Method
/// Load the specified resource for playback.
///
/// Parameters:
///  * `path` - a string specifying the file path or URL to the audiovisual resource.
///
/// Returns:
///  * the avplayerObject
///
/// Notes:
///  * Content will not start autoplaying when loaded - you must use the controls provided in the audiovisual player or one of [hs._asm.uitk.element.avplayer:play](#play) or [hs._asm.uitk.element.avplayer:rate](#rate) to begin playback.
///
///  * If the path or URL are malformed, unreachable, or otherwise unavailable, [hs._asm.uitk.element.avplayer:status](#status) will return "failed".
///  * Because a remote URL may not respond immediately, you can also setup a callback with [hs._asm.uitk.element.avplayer:trackStatus](#trackStatus) to be notified when the item has loaded or if it has failed.
static int avplayer_load(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer              *player     = playerView.player ;

    if (player.currentItem) {
        if (playerView.trackCompleted) {
            [[NSNotificationCenter defaultCenter] removeObserver:playerView
                                                            name:AVPlayerItemDidPlayToEndTimeNotification
                                                          object:player.currentItem] ;
        }
        if (playerView.trackStatus) {
            [player.currentItem removeObserver:playerView forKeyPath:@"status" context:myKVOContext] ;
        }
    }

    player.rate = 0.0f ; // any load should start in a paused state
    [player replaceCurrentItemWithPlayerItem:nil] ;

    if (lua_type(L, 2) != LUA_TNIL) {
        NSString *path   = [skin toNSObjectAtIndex:2] ;
        NSURL    *theURL = [NSURL URLWithString:path] ;

        if (!theURL) {
            theURL = [NSURL fileURLWithPath:path.stringByExpandingTildeInPath] ;
        }

        [player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:theURL]] ;
    }

    if (player.currentItem) {
        if (playerView.trackCompleted) {
            [[NSNotificationCenter defaultCenter] addObserver:playerView
                                                     selector:@selector(didFinishPlaying:)
                                                         name:AVPlayerItemDidPlayToEndTimeNotification
                                                       object:player.currentItem] ;
        }
        if (playerView.trackStatus) {
            [player.currentItem addObserver:playerView
                                 forKeyPath:@"status"
                                    options:NSKeyValueObservingOptionNew
                                    context:myKVOContext] ;
        }
    }

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:play([fromBeginning]) -> avplayerObject
/// Method
/// Play the audiovisual media currently loaded in the avplayer object.
///
/// Parameters:
///  * `fromBeginning` - an optional boolean, default false, specifying whether or not the media playback should start from the beginning or from the current location.
///
/// Returns:
///  * the avplayerObject
///
/// Notes:
///  * this is equivalent to setting the rate to 1.0 (see [hs._asm.uitk.element.avplayer:rate](#rate)`)
static int avplayer_play(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer              *player     = playerView.player ;

    if (lua_gettop(L) == 2 && lua_toboolean(L, 2)) {
        [player seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero] ;
    }
    [player play] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:pause() -> avplayerObject
/// Method
/// Pause the audiovisual media currently loaded in the avplayer object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the avplayerObject
///
/// Notes:
///  * this is equivalent to setting the rate to 0.0 (see [hs._asm.uitk.element.avplayer:rate](#rate)`)
static int avplayer_pause(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer              *player     = playerView.player ;

    [player pause] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:rate([rate]) -> avplayerObject | number
/// Method
/// Get or set the rate of playback for the audiovisual content of the avplayer object.
///
/// Parameters:
///  * `rate` - an optional number specifying the rate you wish for the audiovisual content to be played.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
///
/// Notes:
///  * This method affects the playback rate of both video and audio -- if you wish to mute audio during a "fast forward" or "rewind", see [hs._asm.uitk.element.avplayer:mute](#mute).
///  * A value of 0.0 is equivalent to [hs._asm.uitk.element.avplayer:pause](#pause).
///  * A value of 1.0 is equivalent to [hs._asm.uitk.element.avplayer:play](#play).
///
///  * Other rates may not be available for all media and will be ignored if specified and the media does not support playback at the specified rate:
///    * Rates between 0.0 and 1.0 are allowed if [hs._asm.uitk.element.avplayer:playbackInformation](#playbackInformation) returns true for the `canPlaySlowForward` field
///    * Rates greater than 1.0 are allowed if [hs._asm.uitk.element.avplayer:playbackInformation](#playbackInformation) returns true for the `canPlayFastForward` field
///    * The item can be played in reverse (a rate of -1.0) if [hs._asm.uitk.element.avplayer:playbackInformation](#playbackInformation) returns true for the `canPlayReverse` field
///    * Rates between 0.0 and -1.0 are allowed if [hs._asm.uitk.element.avplayer:playbackInformation](#playbackInformation) returns true for the `canPlaySlowReverse` field
///    * Rates less than -1.0 are allowed if [hs._asm.uitk.element.avplayer:playbackInformation](#playbackInformation) returns true for the `canPlayFastReverse` field
static int avplayer_rate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer              *player     = playerView.player ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, (lua_Number)player.rate) ;
    } else {
        player.rate = (float)lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:mute([state]) -> avplayerObject | boolean
/// Method
/// Get or set whether or not audio output is muted for the audovisual media item.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not audio output has been muted for the avplayer object.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
static int avplayer_mute(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer              *player     = playerView.player ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, player.muted) ;
    } else {
        player.muted = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:volume([volume]) -> avplayerObject | number
/// Method
/// Get or set the avplayer object's volume on a linear scale from 0.0 (silent) to 1.0 (full volume, relative to the current OS volume).
///
/// Parameters:
///  * `volume` - an optional number, default as specified by the media or 1.0 if no designation is specified by the media, specifying the player's volume relative to the system volume level.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
static int avplayer_volume(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer              *player     = playerView.player ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, (lua_Number)player.volume) ;
    } else {
        float newLevel = (float)lua_tonumber(L, 2) ;
        player.volume = ((newLevel < 0.0f) ? 0.0f : ((newLevel > 1.0f) ? 1.0f : newLevel)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:trackProgress([number | nil]) -> avplayerObject | number | nil
/// Method
/// Enable or disable a periodic callback at the interval specified.
///
/// Parameters:
///  * `number` - an optional number specifying how often, in seconds, the callback function should be invoked to report progress.  If an explicit nil is specified, then the progress callback is disabled. Defaults to nil.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.  A return value of `nil` indicates that no progress callback is in effect.
///
/// Notes:
///  * the callback function (see [hs._asm.uitk.element.avplayer:setCallback](#setCallback)) will be invoked with the following 3 arguments:
///    * the avplayerObject
///    * "progress"
///    * the time in seconds specifying the current location in the media playback.
///
///  * From Apple Documentation: The block is invoked periodically at the interval specified, interpreted according to the timeline of the current item. The block is also invoked whenever time jumps and whenever playback starts or stops. If the interval corresponds to a very short interval in real time, the player may invoke the block less frequently than requested. Even so, the player will invoke the block sufficiently often for the client to update indications of the current time appropriately in its end-user interface.
static int avplayer_trackProgress(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer              *player     = playerView.player ;

    if (lua_gettop(L) == 1) {
        if (playerView.periodicObserver) {
            lua_pushnumber(L, playerView.periodicPeriod) ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (playerView.periodicObserver) {
            [player removeTimeObserver:playerView.periodicObserver] ;
            playerView.periodicObserver = nil ;
            playerView.periodicPeriod = 0.0 ;
        }
        if (lua_type(L, 2) == LUA_TNUMBER) {
            playerView.periodicPeriod = lua_tonumber(L, 2) ;
            CMTime period = CMTimeMakeWithSeconds(playerView.periodicPeriod, PREFERRED_TIMESCALE) ;
            playerView.periodicObserver = [player addPeriodicTimeObserverForInterval:period
                                                                               queue:NULL
                                                                          usingBlock:^(CMTime time) {
                [playerView callbackHamster:@[ playerView, @"progress", @(CMTimeGetSeconds(time)) ]] ;
            }] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:trackRate([state]) -> avplayerObject | boolean
/// Method
/// Enable or disable a callback whenever the rate of playback changes.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not playback rate changes should invoke a callback.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
///
/// Notes:
///  * the callback function (see [hs._asm.uitk.element.avplayer:setCallback](#setCallback)) will be invoked with the following 3 arguments:
///    * the avplayerObject
///    * "pause", if the rate changes to 0.0, or "play" if the rate changes to any other value
///    * the rate that the playback was changed to.
///
///  * Not all media content can have its playback rate changed; attempts to do so will invoke the callback twice -- once signifying that the change was made, and a second time indicating that the rate of play was reset back to the limits of the media content.  See [hs._asm:rate](#rate) for more information.
static int avplayer_trackRate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer              *player     = playerView.player ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.trackRate) ;
    } else {
        if (playerView.trackRate) {
            [player removeObserver:playerView forKeyPath:@"rate" context:myKVOContext] ;
        }

        playerView.trackRate = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;

        if (playerView.trackRate) {
            [player addObserver:playerView
                     forKeyPath:@"rate"
                        options:NSKeyValueObservingOptionNew
                        context:myKVOContext] ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:allowExternalPlayback([state]) -> avplayerObject | boolean
/// Method
/// Get or set whether or not external playback via AirPlay is allowed for this item.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether external playback via AirPlay is allowed for this item.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
static int avplayer_allowsExternalPlayback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer              *player     = playerView.player ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, player.allowsExternalPlayback) ;
    } else {
        player.allowsExternalPlayback = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:externalPlayback() -> Boolean
/// Method
/// Returns whether or not external playback via AirPlay is currently active for the avplayer object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * true, if AirPlay is currently being used to play the audiovisual content, or false if it is not.
static int avplayer_externalPlaybackActive(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer              *player     = playerView.player ;

    lua_pushboolean(L, player.externalPlaybackActive) ;
    return 1 ;
}

static int avplayerview_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 2) {
        playerView.callbackRef = [skin luaUnref:refTable ref:playerView.callbackRef];
        if (lua_type(L, 2) != LUA_TNIL) {
            lua_pushvalue(L, 2);
            playerView.callbackRef = [skin luaRef:refTable] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        if (playerView.callbackRef != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:playerView.callbackRef] ;
        } else {
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

static int avplayer_trackPlayback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer              *player     = playerView.player ;

    if (lua_gettop(L) == 1) {
        if (@available(macOS 12, *)) {
            lua_pushboolean(L, playerView.trackPlayback) ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (@available(macOS 12, *)) {
            if (playerView.trackPlayback) {
                [player removeObserver:playerView forKeyPath:@"timeControlStatus" context:myKVOContext] ;
            }

            playerView.trackPlayback = (BOOL)(lua_toboolean(L, 2)) ;

            if (playerView.trackPlayback) {
                [player addObserver:playerView
                         forKeyPath:@"timeControlStatus"
                            options:NSKeyValueObservingOptionNew
                            context:myKVOContext] ;
            }
        } else {
            [skin logInfo:[NSString stringWithFormat:@"%s:trackPlayback - only supported in macOS 12 and newer", USERDATA_TAG]] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int avplayer_playbackStatus(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer              *player     = playerView.player ;
    int                   returnCount = 1 ;

    switch(player.timeControlStatus) {
        case AVPlayerTimeControlStatusPaused:
            lua_pushstring(L, "paused") ;
            break ;
        case AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate:
            lua_pushstring(L, "waiting") ;
            break ;
        case AVPlayerTimeControlStatusPlaying:
            lua_pushstring(L, "playing") ;
            break ;
        default:
            lua_pushstring(L, [[NSString stringWithFormat:@"unrecognized status:%ld", player.timeControlStatus] UTF8String]) ;
            break ;
    }
    NSString *reason = player.reasonForWaitingToPlay ;
    if (reason) {
        NSString *message = WAITING_REASON[reason] ;
        if (!message) message = [NSString stringWithFormat:@"unrecognized reason '%@'", reason] ;
        lua_pushstring(L, message.UTF8String) ;
        returnCount++ ;
    }
    return returnCount ;
}

static int avplayer_automaticallyWaitsToMinimizeStalling(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer              *player     = playerView.player ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, player.automaticallyWaitsToMinimizeStalling) ;
    } else {
        player.automaticallyWaitsToMinimizeStalling = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int avplayer_preventsDisplaySleepDuringVideoPlayback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer              *player     = playerView.player ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, player.preventsDisplaySleepDuringVideoPlayback) ;
    } else {
        player.preventsDisplaySleepDuringVideoPlayback = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int avplayer_defaultRate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer              *player     = playerView.player ;

    if (lua_gettop(L) == 1) {
        if (@available(macOS 13, *)) {
            lua_pushnumber(L, (lua_Number)player.defaultRate) ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (@available(macOS 13, *)) {
            player.defaultRate = (float)lua_tonumber(L, 2) ;
        } else {
            [skin logInfo:[NSString stringWithFormat:@"%s:defaultRate - only supported in macOS 13 and newer", USERDATA_TAG]] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int avplayer_audiovisualBackgroundPlaybackPolicy(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer              *player     = playerView.player ;

    if (lua_gettop(L) == 1) {
        if (@available(macOS 12, *)) {
            NSNumber *value = @(player.audiovisualBackgroundPlaybackPolicy) ;
            NSArray *temp = [BACKGROUND_POLICY allKeysForObject:value];
            NSString *answer = [temp firstObject] ;
            if (answer) {
                [skin pushNSObject:answer] ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized background policy %@ -- notify developers", USERDATA_TAG, value]] ;
                lua_pushnil(L) ;
            }
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (@available(macOS 12, *)) {
            NSString *key = [skin toNSObjectAtIndex:2] ;
            NSNumber *value = BACKGROUND_POLICY[key] ;
            if (value) {
                player.audiovisualBackgroundPlaybackPolicy = [value integerValue] ;
            } else {
                return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of %@", [BACKGROUND_POLICY.allKeys componentsJoinedByString:@", "]] UTF8String]) ;
            }
        } else {
            [skin logInfo:[NSString stringWithFormat:@"%s:backgroundPolicy - only supported in macOS 12 and newer", USERDATA_TAG]] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

static int avplayer_outputObscuredDueToInsufficientExternalProtection(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayer              *player     = playerView.player ;

    lua_pushboolean(L, player.outputObscuredDueToInsufficientExternalProtection) ;
    return 1 ;
}

// FIXME: things to consider
// How useful?
//     - (void)playImmediatelyAtRate:(float)rate;
//     @property BOOL appliesMediaSelectionCriteriaAutomatically;
//     - (AVPlayerMediaSelectionCriteria *)mediaSelectionCriteriaForMediaCharacteristic:(AVMediaCharacteristic)mediaCharacteristic;
//     - (void)setMediaSelectionCriteria:(AVPlayerMediaSelectionCriteria *)criteria forMediaCharacteristic:(AVMediaCharacteristic)mediaCharacteristic;
//     @property(nonatomic, assign) AVAudioSpatializationFormats allowedAudioSpatializationFormats;
//     @property(nonatomic, assign, getter=isAudioSpatializationAllowed) BOOL audioSpatializationAllowed;
//     @property(class, readonly) AVPlayerHDRMode availableHDRModes;
//     @property(class, readonly) BOOL eligibleForHDRPlayback;
//     @property(copy) NSString *audioOutputDeviceUniqueID;
//     @property(nonatomic) uint64_t preferredVideoDecoderGPURegistryID;
//     - (id)addBoundaryTimeObserverForTimes:(NSArray<NSValue *> *)times queue:(dispatch_queue_t)queue usingBlock:(void (^)(void))block;

// Synchronization of multiple players -- beyond our scope
//     - (void)setRate:(float)rate time:(CMTime)itemTime atHostTime:(CMTime)hostClockTime;
//     - (void)cancelPendingPrerolls;
//     - (void)prerollAtRate:(float)rate completionHandler:(void (^)(BOOL finished))completionHandler;
//     @property(nonatomic, retain, nullable) CMClockRef sourceClock;
//     @property(readonly, strong) AVPlayerPlaybackCoordinator *playbackCoordinator;

#pragma mark - Module Methods : AVPlayerItem -

/// hs._asm.uitk.element.avplayer:playbackInformation() -> table | nil
/// Method
/// Returns a table containing information about the media playback characteristics of the audiovisual media currently loaded in the avplayerObject.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the following media characteristics, or `nil` if no media content is currently loaded:
///    * "playbackLikelyToKeepUp" - Indicates whether the item will likely play through without stalling.  Note that this is only a prediction.
///    * "playbackBufferEmpty"    - Indicates whether playback has consumed all buffered media and that playback may stall or end.
///    * "playbackBufferFull"     - Indicates whether the internal media buffer is full and that further I/O is suspended.
///    * "canPlayReverse"         - A Boolean value indicating whether the item can be played with a rate of -1.0.
///    * "canPlayFastForward"     - A Boolean value indicating whether the item can be played at rates greater than 1.0.
///    * "canPlayFastReverse"     - A Boolean value indicating whether the item can be played at rates less than –1.0.
///    * "canPlaySlowForward"     - A Boolean value indicating whether the item can be played at a rate between 0.0 and 1.0.
///    * "canPlaySlowReverse"     - A Boolean value indicating whether the item can be played at a rate between -1.0 and 0.0.
static int avplayeritem_playbackInformation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayerItem          *playerItem = playerView.player.currentItem ;

    if (playerItem) {
        lua_newtable(L) ;
        lua_pushboolean(L, playerItem.playbackLikelyToKeepUp) ; lua_setfield(L, -2, "playbackLikelyToKeepUp") ;
        lua_pushboolean(L, playerItem.playbackBufferEmpty) ;    lua_setfield(L, -2, "playbackBufferEmpty") ;
        lua_pushboolean(L, playerItem.playbackBufferFull) ;     lua_setfield(L, -2, "playbackBufferFull") ;
        lua_pushboolean(L, playerItem.canPlayReverse) ;         lua_setfield(L, -2, "canPlayReverse") ;
        lua_pushboolean(L, playerItem.canPlayFastForward) ;     lua_setfield(L, -2, "canPlayFastForward") ;
        lua_pushboolean(L, playerItem.canPlayFastReverse) ;     lua_setfield(L, -2, "canPlayFastReverse") ;
        lua_pushboolean(L, playerItem.canPlaySlowForward) ;     lua_setfield(L, -2, "canPlaySlowForward") ;
        lua_pushboolean(L, playerItem.canPlaySlowReverse) ;     lua_setfield(L, -2, "canPlaySlowReverse") ;

// Not currently supported by the module since it involves tracks
//         lua_pushboolean(L, playerItem.canStepBackward) ;        lua_setfield(L, -2, "canStepBackward") ;
//         lua_pushboolean(L, playerItem.canStepForward) ;         lua_setfield(L, -2, "canStepForward") ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:status() -> status[, error] | nil
/// Method
/// Returns the current status of the media content loaded for playback.
///
/// Parameters:
///  * None
///
/// Returns:
///  * One of the following status strings, or `nil` if no media content is currently loaded:
///    * "unknown"     - The content's status is unknown; often this is returned when remote content is still loading or being evaluated for playback.
///    * "readyToPlay" - The content has been loaded or sufficiently buffered so that playback may begin
///    * "failed"      - There was an error loading the content; a second return value will contain a string which may contain more information about the error.
static int avplayeritem_status(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayerItem          *playerItem = playerView.player.currentItem ;
    int                   returnCount = 1 ;

    if (playerItem) {
        switch(playerItem.status) {
            case AVPlayerStatusUnknown:
                lua_pushstring(L, "unknown") ;
                break ;
            case AVPlayerStatusReadyToPlay:
                lua_pushstring(L, "readyToPlay") ;
                break ;
            case AVPlayerStatusFailed:
                lua_pushstring(L, "failed") ;
                [skin pushNSObject:[playerItem.error localizedDescription]] ;
                returnCount++ ;
                break ;
            default:
                lua_pushstring(L, [[NSString stringWithFormat:@"unrecognized status:%ld", playerItem.status] UTF8String]) ;
                break ;
        }
    } else {
        lua_pushnil(L) ;
    }
    return returnCount ;
}

/// hs._asm.uitk.element.avplayer:trackCompleted([state]) -> avplayerObject | boolean
/// Method
/// Enable or disable a callback whenever playback of the current media content is completed (reaches the end).
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not completing the playback of media should invoke a callback.
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
///
/// Notes:
///  * the callback function (see [hs._asm.uitk.element.avplayer:setCallback](#setCallback)) will be invoked with the following 2 arguments:
///    * the avplayerObject
///    * "finished"
static int avplayeritem_trackCompleted(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayerItem          *playerItem = playerView.player.currentItem ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.trackCompleted) ;
    } else {
        if (playerItem && playerView.trackCompleted) {
            [[NSNotificationCenter defaultCenter] removeObserver:playerView
                                                            name:AVPlayerItemDidPlayToEndTimeNotification
                                                          object:playerItem] ;
        }

        playerView.trackCompleted = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;

        if (playerItem && playerView.trackCompleted) {
            [[NSNotificationCenter defaultCenter] addObserver:playerView
                                                     selector:@selector(didFinishPlaying:)
                                                         name:AVPlayerItemDidPlayToEndTimeNotification
                                                       object:playerItem] ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:trackStatus([state]) -> avplayerObject | boolean
/// Method
/// Enable or disable a callback whenever the status of loading a media item changes.
///
/// Parameters:
///  * `state` - an optional boolean, default false, specifying whether or not changes to the status of audiovisual media's loading status should generate a callback..
///
/// Returns:
///  * if an argument is provided, the avplayerObject; otherwise the current value.
///
/// Notes:
///  * the callback function (see [hs._asm.uitk.element.avplayer:setCallback](#setCallback)) will be invoked with the following 3 or 4 arguments:
///    * the avplayerObject
///    * "status"
///    * a string matching one of the states described in [hs._asm.uitk.element.avplayer:status](#status)
///    * if the state reported is failed, an error message describing the error that occurred.
static int avplayeritem_trackStatus(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayerItem          *playerItem = playerView.player.currentItem ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, playerView.trackStatus) ;
    } else {
        if (playerItem && playerView.trackStatus) {
            [playerItem removeObserver:playerView forKeyPath:@"status" context:myKVOContext] ;
        }

        playerView.trackStatus = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;

        if (playerItem && playerView.trackStatus) {
            [playerItem addObserver:playerView
                         forKeyPath:@"status"
                            options:NSKeyValueObservingOptionNew
                            context:myKVOContext] ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:currentTime() -> number | nil
/// Method
/// Returns the current position in seconds within the audiovisual media content.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the current position, in seconds, within the audiovisual media content, or `nil` if no media content is currently loaded.
static int avplayeritem_currentTime(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayerItem          *playerItem = playerView.player.currentItem ;

    if (playerItem) {
        lua_pushnumber(L, CMTimeGetSeconds(playerItem.currentTime)) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:duration() -> number | nil
/// Method
/// Returns the duration, in seconds, of the audiovisual media content currently loaded.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the duration, in seconds, of the audiovisual media content currently loaded, if it can be determined, or `nan` (not-a-number) if it cannot.  If no item has been loaded, this method will return nil.
///
/// Notes:
///  * the duration of an item which is still loading cannot be determined; you may want to use [hs._asm.uitk.element.avplayer:trackStatus](#trackStatus) and wait until it receives a "readyToPlay" state before querying this method.
///
///  * a live stream may not provide duration information and also return `nan` for this method.
///
///  * Lua defines `nan` as a number which is not equal to itself.  To test if the value of this method is `nan` requires code like the following:
///  ~~~lua
///  duration = avplayer:duration()
///  if type(duration) == "number" and duration ~= duration then
///      -- the duration is equal to `nan`
///  end
/// ~~~
static int avplayeritem_duration(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayerItem          *playerItem = playerView.player.currentItem ;

    if (playerItem) {
        lua_pushnumber(L, CMTimeGetSeconds(playerItem.duration)) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.avplayer:seek(time, [callback]) -> avplayerObject | nil
/// Method
/// Jumps to the specified location in the audiovisual content currently loaded into the player.
///
/// Parameters:
///  * `time`     - the location, in seconds, within the audiovisual content to seek to.
///  * `callback` - an optional boolean, default false, specifying whether or not a callback should be invoked when the seek operation has completed.
///
/// Returns:
///  * the avplayerObject, or nil if no media content is currently loaded
///
/// Notes:
///  * If you specify `callback` as true, the callback function (see [hs._asm.uitk.element.avplayer:setCallback](#setCallback)) will be invoked with the following 3 or 4 arguments:
///    * the avplayerObject
///    * "seek"
///    * the current time, in seconds, specifying the current playback position in the media content
///    * `true` if the seek operation was allowed to complete, or `false` if it was interrupted (for example by another seek request).
static int avplayeritem_seekToTime(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementAVPlayer *playerView = [skin toNSObjectAtIndex:1] ;
    AVPlayerItem          *playerItem = playerView.player.currentItem ;
    lua_Number            desiredPosition = lua_tonumber(L, 2) ;

    if (playerItem) {
        CMTime positionAsCMTime = CMTimeMakeWithSeconds(desiredPosition, PREFERRED_TIMESCALE) ;
        if (lua_gettop(L) == 3 && lua_toboolean(L, 3)) {
            [playerItem seekToTime:positionAsCMTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
                if (playerView.callbackRef != LUA_NOREF) {
                    [skin pushLuaRef:refTable ref:playerView.callbackRef] ;
                    [skin pushNSObject:playerView] ;
                    lua_pushstring(L, "seek") ;
                    lua_pushnumber(L, CMTimeGetSeconds(playerItem.currentTime)) ;
                    lua_pushboolean(L, finished) ;
                    if (![skin protectedCallAndTraceback:4 nresults:0]) {
                        NSString *errorMessage = [skin toNSObjectAtIndex:-1] ;
                        lua_pop(L, 1) ;
                        [skin logError:[NSString stringWithFormat:@"%s:seek callback error:%@", USERDATA_TAG, errorMessage]] ;
                    }
                }
            }] ;
        } else {
            [playerItem seekToTime:positionAsCMTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:nil] ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

// FIXME: things to consider
//     - (void)cancelPendingSeeks;
//
//     - (AVPlayerItemAccessLog *)accessLog;
//     - (AVPlayerItemErrorLog *)errorLog;
//     const NSNotificationName AVPlayerItemNewAccessLogEntryNotification;
//     const NSNotificationName AVPlayerItemNewErrorLogEntryNotification;
//
//     @property CMTime forwardPlaybackEndTime;
//     @property CMTime reversePlaybackEndTime;
//
//     @property(copy) NSArray<AVTextStyleRule *> *textStyleRules;
//     @property(nonatomic, copy) NSArray<AVMetadataItem *> *externalMetadata;
//     @property(nonatomic, copy, nullable) NSDictionary<NSString *,id> *nowPlayingInfo;
//
//     - (void)stepByCount:(NSInteger)stepCount;
//     @property(readonly) BOOL canStepBackward;
//     @property(readonly) BOOL canStepForward;
//     @property(readonly) NSArray<AVPlayerItemTrack *> *tracks;
//
//     @property(readonly) NSArray<NSValue *> *loadedTimeRanges;
//     @property(readonly) NSArray<NSValue *> *seekableTimeRanges;
//
// is trackPlayback sufficient?
//     const NSNotificationName AVPlayerItemPlaybackStalledNotification;
//
//     const NSNotificationName AVPlayerItemFailedToPlayToEndTimeNotification;
//     const NSNotificationName AVPlayerItemTimeJumpedNotification;
//     const NSNotificationName AVPlayerItemMediaSelectionDidChangeNotification;
//     const NSNotificationName AVPlayerItemRecommendedTimeOffsetFromLiveDidChangeNotification;

#pragma mark - Module Constants -

#pragma mark - Lua<->NSObject Conversion Functions -
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementAVPlayer(lua_State *L, id obj) {
    HSUITKElementAVPlayer *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementAVPlayer *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementAVPlayer(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementAVPlayer *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementAVPlayer, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

static int userdata_gc(lua_State* L) {
    HSUITKElementAVPlayer *obj = get_objectFromUserdata(__bridge_transfer HSUITKElementAVPlayer, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
            if (obj.periodicObserver) {
                [obj.player removeTimeObserver:obj.periodicObserver] ;
                obj.periodicObserver = nil ;
                obj.periodicPeriod = 0.0 ;
            }

            if (obj.player.currentItem) {
                if (obj.trackCompleted) {
                    [[NSNotificationCenter defaultCenter] removeObserver:obj
                                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                                  object:obj.player.currentItem] ;
                }
                if (obj.trackStatus) {
                    [obj.player.currentItem removeObserver:obj forKeyPath:@"status" context:myKVOContext] ;
                }
            }
            if (obj.trackRate) {
                [obj.player removeObserver:obj forKeyPath:@"rate" context:myKVOContext] ;
            }
            if (obj.trackPlayback) {
                [obj.player removeObserver:obj forKeyPath:@"timeControlStatus" context:myKVOContext] ;
            }

            obj.player.rate = 0.0f ;
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
    {"controlsStyle",           avplayerview_controlsStyle},
    {"frameSteppingButtons",    avplayerview_showsFrameSteppingButtons},
    {"flashChapterAndTitle",    avplayerview_flashChapterAndTitle},
    {"pauseWhenHidden",         avplayerview_pauseWhenHidden},
    {"sharingServiceButton",    avplayerview_showsSharingServiceButton},
    {"fullScreenToggleButton",  avplayerview_showsFullScreenToggleButton},
    {"showsTimecodes",          avplayerview_showsTimecodes},
    {"updatesInfoCenter",       avplayerview_updatesNowPlayingInfoCenter},
    {"allowMagnification",      avplayerview_allowsMagnification},
    {"allowPIPPlayback",        avplayerview_allowsPictureInPicturePlayback},
    {"allowFrameAnalysis",      avplayerview_allowsVideoFrameAnalysis},
    {"actionMenu",              avplayerview_actionMenu},
    {"magnification",           avplayerview_magnification},
    {"videoGravity",            avplayerview_videoGravity},
    {"frameAnalysisType",       avplayerview_videoFrameAnalysisTypes},
    {"callback",                avplayerview_callback},

    {"load",                    avplayer_load},
    {"play",                    avplayer_play},
    {"pause",                   avplayer_pause},
    {"rate",                    avplayer_rate},
    {"mute",                    avplayer_mute},
    {"volume",                  avplayer_volume},
    {"trackProgress",           avplayer_trackProgress},
    {"trackRate",               avplayer_trackRate},
    {"allowExternalPlayback",   avplayer_allowsExternalPlayback},
    {"externalPlaybackActive",  avplayer_externalPlaybackActive},
    {"waitToMinimizeStalling",  avplayer_automaticallyWaitsToMinimizeStalling},
    {"preventDisplaySleep",     avplayer_preventsDisplaySleepDuringVideoPlayback},
    {"defaultRate",             avplayer_defaultRate},
    {"backgroundPolicy",        avplayer_audiovisualBackgroundPlaybackPolicy},
    {"trackPlayback",           avplayer_trackPlayback},
    {"copyProtectInsufficient", avplayer_outputObscuredDueToInsufficientExternalProtection},
    {"playbackStatus",          avplayer_playbackStatus},

    {"playbackInformation",     avplayeritem_playbackInformation},
    {"status",                  avplayeritem_status},
    {"trackCompleted",          avplayeritem_trackCompleted},
    {"trackStatus",             avplayeritem_trackStatus},
    {"currentTime",             avplayeritem_currentTime},
    {"duration",                avplayeritem_duration},
    {"seekToTime",              avplayeritem_seekToTime},

// other metamethods inherited from _control and _view
    {"__gc",  userdata_gc},
    {NULL,    NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", avplayerview_new},
    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_libelement_avplayer(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKElementAVPlayer  forClass:"HSUITKElementAVPlayer"];
    [skin registerLuaObjectHelper:toHSUITKElementAVPlayer forClass:"HSUITKElementAVPlayer"
                                               withUserdataMapping:USERDATA_TAG];

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"controlsStyle",
        @"frameSteppingButtons",
        @"pauseWhenHidden",
        @"sharingServiceButton",
        @"fullScreenToggleButton",
        @"showsTimecodes",
        @"updatesInfoCenter",
        @"allowMagnification",
        @"allowPIPPlayback",
        @"allowFrameAnalysis",
        @"actionMenu",
        @"magnification",
        @"videoGravity",
        @"frameAnalysisType",
        @"callback",

        @"rate",
        @"mute",
        @"volume",
        @"trackProgress",
        @"trackRate",
        @"allowExternalPlayback",
        @"waitToMinimizeStalling",
        @"preventDisplaySleep",
        @"defaultRate",
        @"backgroundPolicy",
        @"trackPlayback",

        @"trackStatus",
        @"trackCompleted",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pop(L, 1) ;

    return 1;
}
