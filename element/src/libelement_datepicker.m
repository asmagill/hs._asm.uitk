@import Cocoa ;
@import LuaSkin ;

static const char * const USERDATA_TAG = "hs._asm.uitk.element.datepicker" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static NSDictionary *DATEPICKER_STYLES ;

#pragma mark - Support Functions and Classes -

static void defineInternalDictionaries(void) {
    DATEPICKER_STYLES = @{
        @"textFieldAndStepper" : @(NSTextFieldAndStepperDatePickerStyle),
        @"clockAndCalendar"    : @(NSClockAndCalendarDatePickerStyle),
        @"textField"           : @(NSTextFieldDatePickerStyle),
    } ;
}

@interface HSUITKElementDatePicker : NSDatePicker <NSDatePickerCellDelegate>
@property            int        selfRefCount ;
@property (readonly) LSRefTable refTable ;
@property            int        callbackRef ;
@end

@implementation HSUITKElementDatePicker
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

        self.target     = self ;
        self.action     = @selector(performCallback:) ;
        self.continuous = NO ;
        self.delegate   = self ;
        self.dateValue  = [NSDate date] ;
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
    if (self.continuous) [self callbackHamster:@[ self, @"dateDidChange", @(self.dateValue.timeIntervalSince1970) ]] ;
}

- (BOOL)becomeFirstResponder {
    [self callbackHamster:@[ self, @"didBeginEditing" ]] ;
    return [super becomeFirstResponder] ;
}

- (BOOL)resignFirstResponder {
    [self callbackHamster:@[ self, @"didEndEditing", @(self.dateValue.timeIntervalSince1970) ]] ;
    return [super resignFirstResponder] ;
}

// - (void)datePickerCell:(NSDatePickerCell *)datePickerCell validateProposedDateValue:(NSDate * _Nonnull *)proposedDateValue timeInterval:(NSTimeInterval *)proposedTimeInterval {
// }

@end

#pragma mark - Module Functions -

/// hs._asm.uitk.element.datepicker.new([frame]) -> datepickerObject
/// Constructor
/// Creates a new date picker element for `hs._asm.uitk.window`.
///
/// Parameters:
///  * `frame` - an optional frame table specifying the position and size of the frame for the element.
///
/// Returns:
///  * the datepickerObject
///
/// Notes:
///  * In most cases, setting the frame is not necessary and will be overridden when the element is assigned to a container element or to a `hs._asm.uitk.window`.
///
///  * The initial date and time represented by the element will be the date and time when this function is invoked.  See [hs._asm.uitk.element.datepicker:date](#date).
static int datepicker_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;

    NSRect frameRect = (lua_gettop(L) == 1) ? [skin tableToRectAtIndex:1] : NSZeroRect ;
    HSUITKElementDatePicker *element = [[HSUITKElementDatePicker alloc] initWithFrame:frameRect];
    if (element) {
        if (lua_gettop(L) != 1) [element setFrameSize:[element fittingSize]] ;
        [skin pushNSObject:element] ;
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

#pragma mark - Module Methods -

/// hs._asm.uitk.element.datepicker:bordered([enabled]) -> datepickerObject | boolean
/// Method
/// Get or set whether the datepicker element has a rectangular border around it.
///
/// Parameters:
///  * `enabled` - an optional boolean, default false, specifying whether or not a border should be drawn around the element.
///
/// Returns:
///  * if a value is provided, returns the datepickerObject ; otherwise returns the current value.
///
/// Notes:
///  * Setting this to true will set [hs._asm.uitk.element.datepicker:bezeled](#bezeled) to false.
static int datepicker_bordered(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementDatePicker *picker = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, picker.bordered) ;
    } else {
        picker.bordered = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.datepicker:bezeled([flag]) -> datepickerObject | boolean
/// Method
/// Get or set whether or not the datepicker element has a bezeled border around it.
///
/// Parameters:
///  * `flag` - an optional boolean, default true, indicating whether or not the element's frame is bezeled.
///
/// Returns:
///  * if a value is provided, returns the datepickerObject ; otherwise returns the current value.
///
/// Notes:
///  * Setting this to true will set [hs._asm.uitk.element.datepicker:bordered](#bordered) to false.
static int datepicker_bezeled(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementDatePicker *picker = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, picker.bezeled) ;
    } else {
        picker.bezeled = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.datepicker:drawsBackground([flag]) -> datepickerObject | boolean
/// Method
/// Get or set whether or not the datepicker element draws its background.
///
/// Parameters:
///  * `flag` - an optional boolean, default false, indicating whether or not the element's background is drawn.
///
/// Returns:
///  * if a value is provided, returns the datepickerObject ; otherwise returns the current value.
///
/// Notes:
///  * Setting this to true will draw the background of the element with the color specified with [hs._asm.uitk.element.datepicker:backgroundColor](#backgroundColor).
static int datepicker_drawsBackground(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementDatePicker *picker = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, picker.drawsBackground) ;
    } else {
        picker.drawsBackground = (BOOL)(lua_toboolean(L, 2)) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.datepicker:backgroundColor([color]) -> datepickerObject | color table
/// Method
/// Get or set the color for the background of datepicker element.
///
/// Parameters:
/// * `color` - an optional table containing color keys as described in `hs.drawing.color`
///
/// Returns:
///  * If an argument is provided, the datepickerObject; otherwise the current value.
///
/// Notes:
///  * The background color will only be drawn when [hs._asm.uitk.element.datepicker:drawsBackground](#drawsBackground) is true.
///  * If [hs._asm.uitk.element.datepicker:pickerStyle](#pickerStyle) is "textField" or "textFieldAndStepper", this will set the background of the text field. If it is "clockAndColor", only the calendar's background color will be set.
static int datepicker_backgroundColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementDatePicker *picker = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:picker.backgroundColor] ;
    } else {
        picker.backgroundColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.datepicker:textColor([color]) -> datepickerObject | color table
/// Method
/// Get or set the color for the text of the datepicker element.
///
/// Parameters:
/// * `color` - an optional table containing color keys as described in `hs.drawing.color`
///
/// Returns:
///  * If an argument is provided, the datepickerObject; otherwise the current value.
///
/// Notes:
///  * This method only affects the text color when [hs._asm.uitk.element.datepicker:pickerStyle](#pickerStyle) is "textField" or "textFieldAndStepper".
static int datepicker_textColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementDatePicker *picker = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:picker.textColor] ;
    } else {
        picker.textColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.datepicker:dateRangeMode([flag]) -> datepickerObject | boolean
/// Method
/// Get or set whether a date range can be selected by the datepicker object
///
/// Parameters:
///  * `flag` - an optional boolean, default false, indicating whether or not the datepicker allows a single date (false) or a date range (true) to be selected.
///
/// Returns:
///  * If an argument is provided, the datepickerObject; otherwise the current value.
///
/// Notes:
///  * A date range can only be selected by the user when [hs._asm.uitk.element.datepicker:pickerStyle](#pickerStyle) is "clockAndCalendar".
///
///  * When the user has selected a date range, the first date in the range will be available in [hs._asm.uitk.element.datepicker:date](#date) and the interval between the start and end date will be the number of seconds returned by [hs._asm.uitk.element.datepicker:timeInterval](#timeInterval)
static int datepicker_datePickerMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementDatePicker *picker = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, (picker.datePickerMode == NSRangeDateMode)) ;
    } else {
        picker.datePickerMode = (lua_toboolean(L, 2) ? NSRangeDateMode : NSSingleDateMode) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.datepicker:pickerStyle([style]) -> datepickerObject | string
/// Method
/// Get or set the style of datepicker element displayed.
///
/// Parameters:
///  * `style` - an optional string, default "textFieldAndStepper", specifying the images alignment within the element frame. Valid strings are as follows:
///    * "textFieldAndStepper" - displays the date in an editable textField with stepper arrows
///    * "clockAndCalendar"    - displays a calendar and/or clock, depending upon the value of [hs._asm.uitk.element.datepicker:pickerElements](#pickerElements).
///    * "textField"           - displays the date in an editable textField
///
/// Returns:
///  * if a value is provided, returns the datepickerObject ; otherwise returns the current value.
static int datepicker_datePickerStyle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementDatePicker *picker = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSNumber *datePickerStyle = @(picker.datePickerStyle) ;
        NSArray *temp = [DATEPICKER_STYLES allKeysForObject:datePickerStyle];
        NSString *answer = [temp firstObject] ;
        if (answer) {
            [skin pushNSObject:answer] ;
        } else {
            [skin logWarn:[NSString stringWithFormat:@"%s:unrecognized image position %@ -- notify developers", USERDATA_TAG, datePickerStyle]] ;
            lua_pushnil(L) ;
        }
    } else {
        NSString *key = [skin toNSObjectAtIndex:2] ;
        NSNumber *datePickerStyle = DATEPICKER_STYLES[key] ;
        if (datePickerStyle) {
            picker.datePickerStyle = [datePickerStyle unsignedIntegerValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"must be one of %@", [[DATEPICKER_STYLES allKeys] componentsJoinedByString:@", "]] UTF8String]) ;
        }
    }
    return 1 ;
}

/// hs._asm.uitk.element.datepicker.pickerElements([elements]) -> datepickerObject | table
/// Method
/// Get or set what date and time components the datepicker element presents to the user for modification
///
/// Parameters:
///  * `elements` - an optional table containing the following key-value pairs:
///    * `timeElement` - a string, default "HMS", specifying what time components to display. Valid strings are:
///      * "HMS" - allows setting the hour, minute, and seconds of the time. This is the default.
///      * "HM"  - allows setting the hour and minute of the time
///      * "off" - do not present the time for modification; can also be nil (i.e. if the `timeElement` key is not provided)
///    * `dateElement` - a string, default "YMD", specifying what date components to display. Valid strings are:
///      * "YMD" - allows setting the year, month, and day of the date. This is the default.
///      * "YM"  - allows setting the year and month; not valid when [hs._asm.uitk.element.datepicker:pickerStyle](#pickerStyle) is "clockAndCalendar" and will be reset to "YMD".
///      * "off" - do not present the date for modification; can also be nil (i.e. if the `dateElement` key is not provided)
///
/// Returns:
///  * if a value is provided, returns the datepickerObject ; otherwise returns the current value.
static int datepicker_datePickerElements(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementDatePicker *picker = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSDatePickerElementFlags flags = picker.datePickerElements ;
        lua_newtable(L) ;
        if ((flags & NSHourMinuteSecondDatePickerElementFlag) == NSHourMinuteSecondDatePickerElementFlag) {
            lua_pushstring(L, "HMS") ;
        } else if ((flags & NSHourMinuteDatePickerElementFlag) == NSHourMinuteDatePickerElementFlag) {
            lua_pushstring(L, "HM") ;
        } else {
            lua_pushstring(L, "off") ;
        }
        lua_setfield(L, -2, "timeElement") ;
// Per docs, currently does nothing
//         lua_pushboolean(L, ((flags & NSTimeZoneDatePickerElementFlag) == NSTimeZoneDatePickerElementFlag)) ;
//         lua_setfield(L, -2, "includeTimeZone") ;
        if ((flags & NSYearMonthDayDatePickerElementFlag) == NSYearMonthDayDatePickerElementFlag) {
            lua_pushstring(L, "YMD") ;
        } else if ((flags & NSYearMonthDatePickerElementFlag) == NSYearMonthDatePickerElementFlag) {
            lua_pushstring(L, "YM") ;
        } else {
            lua_pushstring(L, "off") ;
        }
        lua_setfield(L, -2, "dateElement") ;
// Per docs, currently does nothing
//         lua_pushboolean(L, ((flags & NSEraDatePickerElementFlag) == NSEraDatePickerElementFlag)) ;
//         lua_setfield(L, -2, "includeEra") ;
    } else {
        NSDatePickerElementFlags flags = (NSDatePickerElementFlags)0 ;
        if (lua_getfield(L, 2, "timeElement") == LUA_TSTRING) {
            NSString *value = [skin toNSObjectAtIndex:-1] ;
            if ([value isEqualToString:@"HMS"]) {
                flags |= NSHourMinuteSecondDatePickerElementFlag ;
            } else if ([value isEqualToString:@"HM"]) {
                flags |= NSHourMinuteDatePickerElementFlag ;
            } else if (![value isEqualToString:@"off"]) {
                return luaL_argerror(L, 2, "expected HMS, HM, or off for timeElement key") ;
            }
        } else if (lua_type(L, -1) != LUA_TNIL) {
            return luaL_argerror(L, 2, "expected string value for timeElement key") ;
        }
        lua_pop(L, 1) ;
        if (lua_getfield(L, 2, "dateElement") == LUA_TSTRING) {
            NSString *value = [skin toNSObjectAtIndex:-1] ;
            if ([value isEqualToString:@"YMD"]) {
                flags |= NSYearMonthDayDatePickerElementFlag ;
            } else if ([value isEqualToString:@"YM"]) {
                flags |= NSYearMonthDatePickerElementFlag ;
            } else if (![value isEqualToString:@"off"]) {
                return luaL_argerror(L, 2, "expected YMD, YM, or off for dateElement key") ;
            }
        } else if (lua_type(L, -1) != LUA_TNIL) {
            return luaL_argerror(L, 2, "expected string value for dateElement key") ;
        }
        lua_pop(L, 1) ;
// Per docs, currently does nothing
//         if (lua_getfield(L, 2, "includeTimeZone") == LUA_TBOOLEAN) {
//             if (lua_toboolean(L, -1)) flags |= NSTimeZoneDatePickerElementFlag ;
//         } else if (lua_type(L, -1) != LUA_TNIL) {
//             return luaL_argerror(L, 2, "expected boolean value for inclueTimeZone key") ;
//         }
//         lua_pop(L, 1) ;
//         if (lua_getfield(L, 2, "includeEra") == LUA_TBOOLEAN) {
//             if (lua_toboolean(L, -1)) flags |= NSEraDatePickerElementFlag ;
//         } else if (lua_type(L, -1) != LUA_TNIL) {
//             return luaL_argerror(L, 2, "expected boolean value for includeEra key") ;
//         }
//         lua_pop(L, 1) ;
        picker.datePickerElements = flags ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.datepicker:locale([locale]) -> datepickerObject | string | nil
/// Method
/// Get or set the current locale used for displaying the datepicker element.
///
/// Parameters:
///  * `locale` - an optional string specifying the locale that determines how the datepicker should be displayed. Specify nil, the default value, to use the current system locale.
///
/// Returns:
///  * if a value is provided, returns the datepickerObject ; otherwise returns the current value.
///
/// Notes:
///  * See `hs.host.locale.availableLocales` for a list of locales available.
static int datepicker_locale(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementDatePicker *picker = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:[picker.locale localeIdentifier]] ;
    } else if (lua_type(L, 2) == LUA_TNIL) {
        picker.locale = nil ;
    } else {
        NSLocale *locale = [NSLocale localeWithLocaleIdentifier:[skin toNSObjectAtIndex:2]] ;
        if (locale) {
            picker.locale = locale ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"invalid locale '%@' specified", [skin toNSObjectAtIndex:2]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.datepicker:timezone([timezone]) -> datepickerObject | string | integer | nil
/// Method
/// Get or set the current timezone used for displaying the time in the datepicker element.
///
/// Parameters:
///  * `timezone` - an optional string or integer specifying the timezone used when displaying the time in the element. Specify nil, the default value, to use the current system timezone. If specified as an integer, the integer represents the number of seconds offset from GMT.
///
/// Returns:
///  * if a value is provided, returns the datepickerObject ; otherwise returns the current value.
///
/// Notes:
///  * See [hs._asm.uitk.element.datepicker.timezoneNames](#timezoneNames) and [hs._asm.uitk.element.datepicker.timezoneAbbreviations](#timezoneAbbreviations) for valid strings that can be used with this method.
static int datepicker_timezone(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER | LS_TINTEGER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementDatePicker *picker = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:[picker.timeZone name]] ;
    } else {
        NSTimeZone *newTimeZone ;
        switch(lua_type(L, 2)) {
            case LUA_TNUMBER: {
                newTimeZone = [NSTimeZone timeZoneForSecondsFromGMT:lua_tointeger(L, 2)] ;
            } break ;
            case LUA_TNIL: {
                newTimeZone = nil ;
            } break ;
            case LUA_TSTRING: {
                NSString *label = [skin toNSObjectAtIndex:2] ;
                newTimeZone = [NSTimeZone timeZoneWithName:label] ;
                if (!newTimeZone) newTimeZone = [NSTimeZone timeZoneWithAbbreviation:label] ;
                if (!newTimeZone) return luaL_argerror(L, 2, [[NSString stringWithFormat:@"unrecognized timezone label '%@'", label] UTF8String]) ;
            } break ;
        }
        picker.timeZone = newTimeZone ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.datepicker:calendar([calendar]) -> datepickerObject | string | nil
/// Method
/// Get or set the current calendar used for displaying the date in the datepicker element.
///
/// Parameters:
///  * `calendar` - an optional string specifying the calendar used when displaying the date in the element. Specify nil, the default value, to use the current system calendar.
///
/// Returns:
///  * if a value is provided, returns the datepickerObject ; otherwise returns the current value.
///
/// Notes:
///  * See [hs._asm.uitk.element.datepicker.calendarIdentifiers](#calendarIdentifiers) for valid strings that can be used with this method.
static int datepicker_calendar(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING  | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementDatePicker *picker = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:[picker.calendar calendarIdentifier]] ;
    } else if (lua_type(L, 2) == LUA_TNIL) {
        picker.calendar = nil ;
    } else {
        NSCalendar *calendar = [NSCalendar calendarWithIdentifier:[skin toNSObjectAtIndex:2]] ;
        if (calendar) {
            picker.calendar = calendar ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"invalid calendar '%@' specified", [skin toNSObjectAtIndex:2]] UTF8String]) ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.datepicker:timeInterval([interval]) -> datepickerObject | integer
/// Method
/// Get or set the interval between the start date and the end date when a range of dates is specified by the datepicker element.
///
/// Parameters:
///  * `interval` - an optional integer specifying the interval between a the range of dates represented by the datepicker element.
///
/// Returns:
///  * if a value is provided, returns the datepickerObject ; otherwise returns the current value.
///
/// Notes:
///  * This value is only relevant when [hs._asm.uitk.element.datepicker:dateRangeMode](#dateRangeMode) is true and [hs._asm.uitk.element.datepicker:pickerStyle](#pickerStyle) is "clockAndCalendar".
///
///  * If the user selects a range of dates in the calendar portion of the datepicker element, this number will be a multiple of 86400, the number of seconds in a day.
///  * If you set a value with this method, it should be a multiple of 86400 - fractions of a day will not be visible or adjustable within the datepicker element.
static int datepicker_timeInterval(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementDatePicker *picker = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        lua_pushnumber(L, picker.timeInterval) ;
    } else {
        picker.timeInterval = lua_tonumber(L, 2) ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.datepicker:date([date]) -> datepickerObject | number
/// Method
/// Get or set the date, or initial date when dateRangeMode is true, and time displayed by the datepicker element.
///
/// Parameters:
///  * `date` - an optional number representing a date and time as the number of seconds from 00:00:00 GMT on 1 January 1970. The default value will be the number representing the date and time when the element was constructed with [hs._asm.uitk.element.datepicker.new](#new).
///
/// Returns:
///  * if a value is provided, returns the datepickerObject ; otherwise returns the current value.
///
/// Notes:
///  * Lua's `os.date` function can only handle integer values; this method returns fractions of a second in the decimal portion of the number, so you will need to convert the number to an integer first, e.g. `os.date("%c", math.floor(hs._asm.uitk.element.datepicker:date()))`
///
///  * When [hs._asm.uitk.element.datepicker:dateRangeMode](#dateRangeMode) is true, the end date of the range can be calculated as `hs._asm.uitk.element.datepicker:date() + hs._asm.uitk.element.datepicker:timeInterval()`.
static int datepicker_dateValue(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementDatePicker *picker = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSDate *date = picker.dateValue ;
        if (date) {
            lua_pushnumber(L, date.timeIntervalSince1970) ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        picker.dateValue = [NSDate dateWithTimeIntervalSince1970:lua_tonumber(L, 2)] ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.datepicker:maxDate([date]) -> datepickerObject | number
/// Method
/// Get or set the maximum date and time the user is allowed to select with the datepicker element.
///
/// Parameters:
///  * `date` - an optional number representing the maximum date and time that the user is allowed to select with the datepicker element. Set to nil, the default value, to specify that there is no maximum valid date and time.
///
/// Returns:
///  * if a value is provided, returns the datepickerObject ; otherwise returns the current value.
///
/// Notes:
///  * The behavior is undefined If a value is set with this method and it is less than the value of [hs._asm.uitk.element.datepicker:minDate](#minDate).
static int datepicker_maxDate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementDatePicker *picker = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSDate *date = picker.maxDate ;
        if (date) {
            lua_pushnumber(L, date.timeIntervalSince1970) ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            picker.maxDate = nil ;
        } else {
            picker.maxDate = [NSDate dateWithTimeIntervalSince1970:lua_tonumber(L, 2)] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs._asm.uitk.element.datepicker:minDate([date]) -> datepickerObject | number
/// Method
/// Get or set the minimum date and time the user is allowed to select with the datepicker element.
///
/// Parameters:
///  * `date` - an optional number representing the minimum date and time that the user is allowed to select with the datepicker element. Set to nil, the default value, to specify that there is no minimum valid date and time.
///
/// Returns:
///  * if a value is provided, returns the datepickerObject ; otherwise returns the current value.
///
/// Notes:
///  * The behavior is undefined If a value is set with this method and it is greater than the value of [hs._asm.uitk.element.datepicker:maxDate](#maxDate).
static int datepicker_minDate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSUITKElementDatePicker *picker = [skin toNSObjectAtIndex:1] ;

    if (lua_gettop(L) == 1) {
        NSDate *date = picker.minDate ;
        if (date) {
            lua_pushnumber(L, date.timeIntervalSince1970) ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            picker.minDate = nil ;
        } else {
            picker.minDate = [NSDate dateWithTimeIntervalSince1970:lua_tonumber(L, 2)] ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

#pragma mark - Module Constants -

/// hs._asm.uitk.element.datepicker.calendarIdentifiers
/// Constant
/// A table which contains an array of strings listing the calendar types supported by the system.
///
/// These values can be used with [hs._asm.uitk.element.datepicker:calendar](#calendar) to adjust the date and calendar displayed by the datepicker element.
static int datepicker_calendarIdentifiers(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    lua_newtable(L) ;
    [skin pushNSObject:NSCalendarIdentifierGregorian] ;           lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSCalendarIdentifierBuddhist] ;            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSCalendarIdentifierChinese] ;             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSCalendarIdentifierCoptic] ;              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSCalendarIdentifierEthiopicAmeteMihret] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSCalendarIdentifierEthiopicAmeteAlem] ;   lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSCalendarIdentifierHebrew] ;              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSCalendarIdentifierISO8601] ;             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSCalendarIdentifierIndian] ;              lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSCalendarIdentifierIslamic] ;             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSCalendarIdentifierIslamicCivil] ;        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSCalendarIdentifierJapanese] ;            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSCalendarIdentifierPersian] ;             lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSCalendarIdentifierRepublicOfChina] ;     lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSCalendarIdentifierIslamicTabular] ;      lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    [skin pushNSObject:NSCalendarIdentifierIslamicUmmAlQura] ;    lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    return 1 ;
}

// may move to hs.host.locale

/// hs._asm.uitk.element.datepicker.timezoneAbbreviations
/// Constant
/// A table which contains a mapping of timezone abbreviations known to the system to the corresponding timezone name.
///
/// These values can be used with [hs._asm.uitk.element.datepicker:timezone](#timezone) to adjust the time displayed by the datepicker element.
///
/// This table contains key-value pairs in which each key is a timezone abbreviation and its value is the timezone name it represents. This table is generated when this module is loaded so that it will reflect the timezones recognized by the currently running version of macOS.
static int datepicker_timezoneAbbreviations(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:[NSTimeZone abbreviationDictionary]] ;
    return 1 ;
}

/// hs._asm.uitk.element.datepicker.timezoneNames
/// Constant
/// A table which contains an array of strings listing the names of all the time zones known to the system.
///
/// These values can be used with [hs._asm.uitk.element.datepicker:timezone](#timezone) to adjust the time displayed by the datepicker element.
///
/// This table is generated when this module is loaded so that it will reflect the timezones recognized by the currently running version of macOS.
static int datepicker_timeZoneNames(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:[NSTimeZone knownTimeZoneNames]] ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSUITKElementDatePicker(lua_State *L, id obj) {
    HSUITKElementDatePicker *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSUITKElementDatePicker *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSUITKElementDatePickerFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUITKElementDatePicker *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSUITKElementDatePicker, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure -

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"drawsBackground", datepicker_drawsBackground},
    {"bordered",        datepicker_bordered},
    {"bezeled",         datepicker_bezeled},
    {"backgroundColor", datepicker_backgroundColor},
    {"textColor",       datepicker_textColor},
    {"dateRangeMode",   datepicker_datePickerMode},
    {"pickerStyle",     datepicker_datePickerStyle},
    {"pickerElements",  datepicker_datePickerElements},
    {"locale",          datepicker_locale},
    {"timezone",        datepicker_timezone},
    {"calendar",        datepicker_calendar},
    {"timeInterval",    datepicker_timeInterval},
    {"date",            datepicker_dateValue},
    {"maxDate",         datepicker_maxDate},
    {"minDate",         datepicker_minDate},

// other metamethods inherited from _control and _view
    {NULL,    NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", datepicker_new},
    {NULL,  NULL}
};

int luaopen_hs__asm_uitk_libelement_datepicker(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:userdata_metaLib];

    defineInternalDictionaries() ;

    [skin registerPushNSHelper:pushHSUITKElementDatePicker         forClass:"HSUITKElementDatePicker"];
    [skin registerLuaObjectHelper:toHSUITKElementDatePickerFromLua forClass:"HSUITKElementDatePicker"
                                                         withUserdataMapping:USERDATA_TAG];

    datepicker_calendarIdentifiers(L) ;   lua_setfield(L, -2, "calendarIdentifiers") ;
    datepicker_timezoneAbbreviations(L) ; lua_setfield(L, -2, "timezoneAbbreviations") ;
    datepicker_timeZoneNames(L) ;         lua_setfield(L, -2, "timezoneNames") ;

    // properties for this item that can be modified through container metamethods
    luaL_getmetatable(L, USERDATA_TAG) ;
    [skin pushNSObject:@[
        @"drawsBackground",
        @"bordered",
        @"bezeled",
        @"backgroundColor",
        @"textColor",
        @"dateRangeMode",
        @"pickerStyle",
        @"pickerElements",
        @"locale",
        @"timezone",
        @"calendar",
        @"timeInterval",
        @"date",
        @"minDate",
        @"maxDate",
    ]] ;
    lua_setfield(L, -2, "_propertyList") ;
    // (all elements inherit from _view)
    lua_pushboolean(L, YES) ; lua_setfield(L, -2, "_inheritControl") ; // inherit from _control
    lua_pop(L, 1) ;

    return 1;
}
