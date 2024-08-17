
--- === hs._asm.uitk.element.canvas ===
---
--- A different approach to drawing in Hammerspoon
---
--- `hs.drawing` approaches graphical images as independent primitives, each "shape" being a separate drawing object based on the core primitives: ellipse, rectangle, point, line, text, etc.  This model works well with graphical elements that are expected to be managed individually and don't have complex clipping interactions, but does not scale well when more complex combinations or groups of drawing elements need to be moved or manipulated as a group, and only allows for simple inclusionary clipping regions.
---
--- This module works by designating a canvas and then assigning a series of graphical primitives to the canvas.  Included in this assignment list are rules about how the individual elements interact with each other within the canvas (compositing and clipping rules), and direct modification of the canvas itself (move, resize, etc.) causes all of the assigned elements to be adjusted as a group.
---
--- The canvas elements are defined in an array, and each entry of the array is a table of key-value pairs describing the element at that position.  Elements are rendered in the order in which they are assigned to the array (i.e. element 1 is drawn before element 2, etc.).
---
--- Attributes for canvas elements are defined in [hs._asm.uitk.element.canvas.attributes](#attributes). All canvas elements require the `type` field; all other attributes have default values.  Fields required to properly define the element (for example, `frame` for the `rectangle` element type) will be copied into the element definition with their default values if they are not specified at the time of creation. Optional attributes will only be assigned in the element definition if they are specified.  When the module requires the value for an element's attribute it first checks the element definition itself, then the defaults are looked for in the canvas defaults, and then finally in the module's built in defaults (specified in the descriptions below).
---
--- Some examples of how to use this module can be found at https://github.com/asmagill/hammerspoon/wiki/hs._asm.uitk.element.canvas.examples

--- hs._asm.uitk.element.canvas.attributes
--- Field
--- Canvas Element Attributes
---
--- Notes:
--- * `type` - specifies the type of canvas element the table represents. This attribute has no default and must be specified for each element in the canvas array. Valid type strings are:
---   * `arc`           - an arc inscribed on a circle, defined by `radius`, `center`, `startAngle`, and `endAngle`.
---   * `circle`        - a circle, defined by `radius` and `center`.
---   * `ellipticalArc` - an arc inscribed on an oval, defined by `frame`, `startAngle`, and `endAngle`.
---   * `image`         - an image as defined by one of the `hs.image` constructors.
---   * `oval`          - an oval, defined by `frame`
---   * `points`        - a list of points defined in `coordinates`.
---   * `rectangle`     - a rectangle, optionally with rounded corners, defined by `frame`.
---   * `resetClip`     - a special type -- indicates that the current clipping shape should be reset to the canvas default (the full canvas area).  See `Clipping Example`.  All other attributes, except `action` are ignored.
---   * `segments`      - a list of line segments or bezier curves with control points, defined in `coordinates`.
---   * `text`          - a string or `hs.styledtext` object, defined by `text` and `frame`.
---
--- * The following is a list of all valid attributes.  Not all attributes apply to every type, but you can set them for any type.
---   * `action`              - Default `strokeAndFill`. A string specifying the action to take for the element in the array.  The following actions are recognized:
---     * `clip`          - append the shape to the current clipping region for the canvas. Ignored for `image`, and `text` types.
---     * `build`         - do not render the element -- its shape is preserved and the next element in the canvas array is appended to it.  This can be used to create complex shapes or clipping regions. The stroke and fill settings for a complex object created in this manner will be those of the final object of the group. Ignored for `image`, and `text` types.
---     * `fill`          - fill the canvas element, if it is a shape, or display it normally if it is a `image` or `text`.  Ignored for `resetClip`.
---     * `skip`          - ignore this element or its effects.  Can be used to temporarily "remove" an object from the canvas.
---     * `stroke`        - stroke (outline) the canvas element, if it is a shape, or display it normally if it is a `image` or `text`.  Ignored for `resetClip`.
---     * `strokeAndFill` - stroke and fill the canvas element, if it is a shape, or display it normally if it is a `image` or `text`.  Ignored for `resetClip`.
---   * `absolutePosition`    - Default `true`. If false, numeric location and size attributes (`frame`, `center`, `radius`, and `coordinates`) will be automatically adjusted when the canvas is resized with [hs._asm.uitk.element.canvas:size](#size) or [hs._asm.uitk.element.canvas:frame](#frame) so that the element remains in the same relative position in the canvas.
---   * `absoluteSize`        - Default `true`. If false, numeric location and size attributes (`frame`, `center`, `radius`, and `coordinates`) will be automatically adjusted when the canvas is resized with [hs._asm.uitk.element.canvas:size](#size) or [hs._asm.uitk.element.canvas:frame](#frame) so that the element maintains the same relative size in the canvas.
---   * `antialias`           - Default `true`.  Indicates whether or not antialiasing should be enabled for the element.
---   * `arcRadii`            - Default `true`. Used by the `arc` and `ellipticalArc` types to specify whether or not line segments from the element's center to the start and end angles should be included in the element's visible portion.  This affects whether the object's stroke is a pie-shape or an arc with a chord from the start angle to the end angle.
---   * `arcClockwise`        - Default `true`.  Used by the `arc` and `ellipticalArc` types to specify whether the arc should be drawn from the start angle to the end angle in a clockwise (true) direction or in a counter-clockwise (false) direction.
---   * `compositeRule`       - A string, default "sourceOver", specifying how this element should be combined with earlier elements of the canvas.  See [hs._asm.uitk.element.canvas.compositeTypes](#compositeTypes) for a list of valid strings and their descriptions.
---   * `center`              - Default `{ x = "50%", y = "50%" }`.  Used by the `circle` and `arc` types to specify the center of the canvas element.  The `x` and `y` fields can be specified as numbers or as a string. When specified as a string, the value is treated as a percentage of the canvas size.  See the section on [percentages](#percentages) for more information.
---   * `clipToPath`          - Default `false`.   Specifies whether the clipping regions should be temporarily limited to the element's shape while rendering this element or not.  This can be used to produce crisper edges, as seen with `hs.drawing` but reduces stroke width granularity for widths less than 1.0 and causes occasional "missing" lines with the `segments` element type. Ignored for the `image`, `point`, and `text` types.
---   * `closed`              - Default `false`.  Used by the `segments` type to specify whether or not the shape defined by the lines and curves defined should be closed (true) or open (false).  When an object is closed, an implicit line is stroked from the final point back to the initial point of the coordinates listed.
---   * `coordinates`         - An array containing coordinates used by the `segments` and `points` types to define the lines and curves or points that make up the canvas element.  The following keys are recognized and may be specified as numbers or strings (see the section on [percentages](#percentages)).
---     * `x`   - required for `segments` and `points`, specifying the x coordinate of a point.
---     * `y`   - required for `segments` and `points`, specifying the y coordinate of a point.
---     * `c1x` - optional for `segments, specifying the x coordinate of the first control point used to draw a bezier curve between this point and the previous point.  Ignored for `points` and if present in the first coordinate in the `coordinates` array.
---     * `c1y` - optional for `segments, specifying the y coordinate of the first control point used to draw a bezier curve between this point and the previous point.  Ignored for `points` and if present in the first coordinate in the `coordinates` array.
---     * `c2x` - optional for `segments, specifying the x coordinate of the second control point used to draw a bezier curve between this point and the previous point.  Ignored for `points` and if present in the first coordinate in the `coordinates` array.
---     * `c2y` - optional for `segments, specifying the y coordinate of the second control point used to draw a bezier curve between this point and the previous point.  Ignored for `points` and if present in the first coordinate in the `coordinates` array.
---   * `endAngle`            - Default `360.0`. Used by the `arc` and `ellipticalArc` to specify the ending angle position for the inscribed arc.
---   * `fillColor`           - Default `{ red = 1.0 }`.  Specifies the color used to fill the canvas element when the `action` is set to `fill` or `strokeAndFill` and `fillGradient` is equal to `none`.  Ignored for the `image`, `points`, and `text` types.
---   * `fillGradient`        - Default "none".  A string specifying whether a fill gradient should be used instead of the fill color when the action is `fill` or `strokeAndFill`.  May be "none", "linear", or "radial".
---   * `fillGradientAngle`   - Default 0.0.  Specifies the direction of a linear gradient when `fillGradient` is linear.
---   * `fillGradientCenter`  - Default `{ x = 0.0, y = 0.0 }`. Specifies the relative center point within the elements bounds of a radial gradient when `fillGradient` is `radial`.  The `x` and `y` fields must both be between -1.0 and 1.0 inclusive.
---   * `fillGradientColors`  - Default `{ { white = 0.0 }, { white = 1.0 } }`.  Specifies the colors to use for the gradient when `fillGradient` is not `none`.  You must specify at least two colors, each of which must be convertible into the RGB color space (i.e. they cannot be an image being used as a color pattern).  The gradient will blend from the first to the next, and so on until the last color.  If more than two colors are specified, the "color stops" will be placed at evenly spaced intervals within the element.
---   * `flatness`            - Default `0.6`.  A number which specifies the accuracy (or smoothness) with which curves are rendered. It is also the maximum error tolerance (measured in pixels) for rendering curves, where smaller numbers give smoother curves at the expense of more computation.
---   * `flattenPath`         - Default `false`. Specifies whether curved line segments should be converted into straight line approximations. The granularity of the approximations is controlled by the path's current flatness value.
---   * `frame`               - Default `{ x = "0%", y = "0%", h = "100%", w = "100%" }`.  Used by the `rectangle`, `oval`, `ellipticalArc`, `text`, `image` types to specify the element's position and size.  When the key value for `x`, `y`, `h`, or `w` are specified as a string, the value is treated as a percentage of the canvas size.  See the section on [percentages](#percentages) for more information.
---   * `id`                  - An optional string or number which is included in mouse callbacks to identify the element which was the target of the mouse event.  If this is not specified for an element, it's index position is used instead.
---   * `image`               - Defaults to a blank image.  Used by the `image` type to specify an `hs.image` object to display as an image.
---   * `imageAlpha`          - Defaults to `1.0`.  A number between 0.0 and 1.0 specifying the alpha value to be applied to the image specified by `image`.  Note that if an image is a template image, then this attribute will internally default to `0.5` unless explicitly set for the element.
---   * `imageAlignment`      - Default "center". A string specifying the alignment of the image within the canvas element's frame.  Valid values for this attribute are "center", "bottom", "topLeft", "bottomLeft", "bottomRight", "left", "right", "top", and "topRight".
---   * `imageAnimationFrame` - Default `0`. An integer specifying the image frame to display when the image is from an animated GIF.  This attribute is ignored for other image types.  May be specified as a negative integer indicating that the image frame should be calculated from the last frame and calculated backwards (i.e. specifying `-1` selects the last frame for the GIF.)
---   * `imageAnimates`       - Default `false`. A boolean specifying whether or not an animated GIF should be animated or if only a single frame should be shown.  Ignored for other image types.
---   * `imageScaling`        - Default "scaleProportionally".  A string specifying how the image should be scaled within the canvas element's frame.  Valid values for this attribute are:
---     * `scaleToFit`          - shrink the image, preserving the aspect ratio, to fit the drawing frame only if the image is larger than the drawing frame.
---     * `shrinkToFit`         - shrink or expand the image to fully fill the drawing frame.  This does not preserve the aspect ratio.
---     * `none`                - perform no scaling or resizing of the image.
---     * `scaleProportionally` - shrink or expand the image to fully fill the drawing frame, preserving the aspect ration.
---   * `miterLimit`          - Default `10.0`. The limit at which miter joins are converted to bevel join when `strokeJoinStyle` is `miter`.  The miter limit helps you avoid spikes at the junction of two line segments.  When the ratio of the miter length—the diagonal length of the miter join—to the line thickness exceeds the miter limit, the joint is converted to a bevel join. Ignored for the `text`, and `image` types.
---   * `padding`             - Default `0.0`. When an element specifies position information by percentage (i.e. as a string), the actual frame used for calculating position values is inset from the canvas frame on all sides by this amount. If you are using shadows with your elements, the shadow position is not included in the element's size and position specification; this attribute can be used to provide extra space for the shadow to be fully rendered within the canvas.
---   * `radius`              - Default "50%". Used by the `arc` and `circle` types to specify the radius of the circle for the element. May be specified as a string or a number.  When specified as a string, the value is treated as a percentage of the canvas size.  See the section on [percentages](#percentages) for more information.
---   * `reversePath`         - Default `false`.  Specifies drawing direction for the canvas element.  By default, canvas elements are drawn from the point nearest the origin (top left corner) in a clockwise direction.  Setting this to true causes the element to be drawn in a counter-clockwise direction. This will mostly affect fill and stroke dash patterns, but can also be used with clipping regions to create cut-outs.  Ignored for `image`, and `text` types.
---   * `roundedRectRadii`    - Default `{ xRadius = 0.0, yRadius = 0.0 }`.
---   * `shadow`              - Default `{ blurRadius = 5.0, color = { alpha = 1/3 }, offset = { h = -5.0, w = 5.0 } }`.  Specifies the shadow blurring, color, and offset to be added to an element which has `withShadow` set to true.
---   * `startAngle`          - Default `0.0`. Used by the `arc` and `ellipticalArc` to specify the starting angle position for the inscribed arc.
---   * `strokeCapStyle`      - Default "butt". A string which specifies the shape of the endpoints of an open path when stroked.  Primarily noticeable for lines rendered with the `segments` type.  Valid values for this attribute are "butt", "round", and "square".
---   * `strokeColor`         - Default `{ white = 0 }`.  Specifies the stroke (outline) color for a canvas element when the action is set to `stroke` or `strokeAndFill`.  Ignored for the `text`, and `image` types.
---   * `strokeDashPattern`   - Default `{}`.  Specifies an array of numbers specifying a dash pattern for stroked lines when an element's `action` attribute is set to `stroke` or `strokeAndFill`.  The numbers in the array alternate with the first element specifying a dash length in points, the second specifying a gap length in points, the third a dash length, etc.  The array repeats to fully stroke the element.  Ignored for the `image`, and `text` types.
---   * `strokeDashPhase`     - Default `0.0`.  Specifies an offset, in points, where the dash pattern specified by `strokeDashPattern` should start. Ignored for the `image`, and `text` types.
---   * `strokeJoinStyle`     - Default "miter".  A string which specifies the shape of the joints between connected segments of a stroked path.  Valid values for this attribute are "miter", "round", and "bevel".  Ignored for element types of `image`, and `text`.
---   * `strokeWidth`         - Default `1.0`.  Specifies the width of stroked lines when an element's action is set to `stroke` or `strokeAndFill`.  Ignored for the `image`, and `text` element types.
---   * `text`                - Default `""`.  Specifies the text to display for a `text` element.  This may be specified as a string, or as an `hs.styledtext` object.
---   * `textAlignment`       - Default `natural`. A string specifying the alignment of the text within a canvas element of type `text`.  This field is ignored if the text is specified as an `hs.styledtext` object.  Valid values for this attributes are:
---     * `left`      - the text is visually left aligned.
---     * `right`     - the text is visually right aligned.
---     * `center`    - the text is visually center aligned.
---     * `justified` - the text is justified
---     * `natural`   - the natural alignment of the text’s script
---   * `textColor`           - Default `{ white = 1.0 }`.  Specifies the color to use when displaying the `text` element type, if the text is specified as a string.  This field is ignored if the text is specified as an `hs.styledtext` object.
---   * `textFont`            - Defaults to the default system font.  A string specifying the name of the font to use when displaying the `text` element type, if the text is specified as a string.  This field is ignored if the text is specified as an `hs.styledtext` object.
---   * `textLineBreak`       - Default `wordWrap`. A string specifying how to wrap text which exceeds the canvas element's frame for an element of type `text`.  This field is ignored if the text is specified as an `hs.styledtext` object.  Valid values for this attribute are:
---     * `wordWrap`       - wrap at word boundaries, unless the word itself doesn’t fit on a single line
---     * `charWrap`       - wrap before the first character that doesn’t fit
---     * `clip`           - do not draw past the edge of the drawing object frame
---     * `truncateHead`   - the line is displayed so that the end fits in the frame and the missing text at the beginning of the line is indicated by an ellipsis
---     * `truncateTail`   - the line is displayed so that the beginning fits in the frame and the missing text at the end of the line is indicated by an ellipsis
---     * `truncateMiddle` - the line is displayed so that the beginning and end fit in the frame and the missing text in the middle is indicated by an ellipsis
---   * `textSize`            - Default `27.0`.  Specifies the font size to use when displaying the `text` element type, if the text is specified as a string.  This field is ignored if the text is specified as an `hs.styledtext` object.
---   * `trackMouseByBounds`  - Default `false`. If true, mouse events are based on the element's bounds (smallest rectangle which completely contains the element); otherwise, mouse events are based on the visible portion of the canvas element.
---   * `trackMouseEnterExit` - Default `false`.  Generates a callback when the mouse enters or exits the canvas element.  For `text` types, the `frame` of the element defines the boundaries of the tracking area.
---   * `trackMouseDown`      - Default `false`.  Generates a callback when mouse button is clicked down while the cursor is within the canvas element.  For `text` types, the `frame` of the element defines the boundaries of the tracking area.
---   * `trackMouseUp`        - Default `false`.  Generates a callback when mouse button is released while the cursor is within the canvas element.  For `text` types, the `frame` of the element defines the boundaries of the tracking area.
---   * `trackMouseMove`      - Default `false`.  Generates a callback when the mouse cursor moves within the canvas element.  For `text` types, the `frame` of the element defines the boundaries of the tracking area.
---   * `transformation`      - Default `{ m11 = 1.0, m12 = 0.0, m21 = 0.0, m22 = 1.0, tX = 0.0, tY = 0.0 }`. Specifies a matrix transformation to apply to the element before displaying it.  Transformations may include rotation, translation, scaling, skewing, etc.
---   * `windingRule`         - Default "nonZero".  A string specifying the winding rule in effect for the canvas element. May be "nonZero" or "evenOdd".  The winding rule determines which portions of an element to fill. This setting will only have a visible effect on compound elements (built with the `build` action) or elements of type `segments` when the object is made from lines which cross.
---   * `withShadow`          - Default `false`. Specifies whether a shadow effect should be applied to the canvas element.  Ignored for the `text` type.

local USERDATA_TAG = require("hs.settings").get("uitk_wrapCanvas") and "hs._asm.uitk.element.canvas._legacy" or "hs.canvas"
local uitk         = require("hs._asm.uitk")

local fnutils      = require("hs.fnutils")

local module   = {}
local moduleMT = { __e = setmetatable({}, { __mode = "k" }) }

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

local accessibilityWarningIssued = false

local elementMT = {
    __e = setmetatable({}, { __mode="k" }),
}

elementMT.__index = function(_, k)
    local obj = elementMT.__e[_]
    if obj.field then
        return obj.value[obj.field][k]
    elseif obj.key then
        if type(obj.value[k]) == "table" then
            local newTable = {}
            elementMT.__e[newTable] = { self = obj.self, index = obj.index, key = obj.key, value = obj.value, field = k }
            return setmetatable(newTable, elementMT)
        else
            return obj.value[k]
        end
    else
        local value
        if obj.index == "_default" then
            value = obj.self:canvasDefaultFor(k)
        else
            value = obj.self:elementAttribute(obj.index, k)
        end
        if type(value) == "table" then
            local newTable = {}
            elementMT.__e[newTable] = { self = obj.self, index = obj.index, key = k, value = value }
            return setmetatable(newTable, elementMT)
        else
            return value
        end
    end
end

elementMT.__newindex = function(_, k, v)
    local obj = elementMT.__e[_]
    local key, value
    if obj.field then
        key = obj.key
        obj.value[obj.field][k] = v
        value = obj.value
    elseif obj.key then
        key = obj.key
        obj.value[k] = v
        value = obj.value
    else
        key = k
        value = v
    end
    if obj.index == "_default" then
        return obj.self:canvasDefaultFor(key, value)
    else
        return obj.self:elementAttribute(obj.index, key, value)
    end
end

elementMT.__pairs = function(s)
    local obj = elementMT.__e[s]
    local keys = {}
    if obj.field then
        keys = obj.value[obj.field]
    elseif obj.key then
        keys = obj.value
    else
        if obj.index == "_default" then
            for _, k in ipairs(obj.self:canvasDefaultKeys()) do keys[k] = s[k] end
        else
            for _, k in ipairs(obj.self:elementKeys(obj.index)) do keys[k] = s[k] end
        end
    end
    return function(_, k)
            local v
            k, v = next(keys, k)
            return k, v
        end, _, nil
end

elementMT.__len = function(_)
    local obj = elementMT.__e[_]
    local value
    if obj.field then
        value = obj.value[obj.field]
    elseif obj.key then
        value = obj.value
    else
        value = {}
    end
    return #value
end

local dump_table
dump_table = function(depth, value)
    local result = "{\n"
    for k,v in require("hs.fnutils").sortByKeys(value) do
        local displayValue = v
        if type(v) == "table" then
            displayValue = dump_table(depth + 2, v)
        elseif type(v) == "string" then
            displayValue = "\"" .. v .. "\""
        end
        local displayKey = k
        if type(k) == "number" then
            displayKey = "[" .. tostring(k) .. "]"
        end
        result = result .. string.rep(" ", depth + 2) .. string.format("%s = %s,\n", tostring(displayKey), tostring(displayValue))
    end
    result = result .. string.rep(" ", depth) .. "}"
    return result
end

elementMT.__tostring = function(_)
    local obj = elementMT.__e[_]
    local value
    if obj.field then
        value = obj.value[obj.field]
    elseif obj.key then
        value = obj.value
    else
        value = _
    end
    if type(value) == "table" then
        return dump_table(0, value)
    else
        return tostring(value)
    end
end

local legacyWrappedCallback = function(self, fn)
    local obj = moduleMT.__e[self]
    local win, view = obj.window, obj.view

    return function(...)
        local args = table.pack(...)
        for i, v in ipairs(args) do
            if v == view or v == win then
                args[i] = self
            end
        end
        return fn(table.unpack(args))
    end
end

-- Public interface ------------------------------------------------------

module.matrix           = uitk.util.matrix

--- hs._asm.uitk.element.canvas.compositeTypes[]
--- Constant
--- A table containing the possible compositing rules for elements within the canvas.
---
--- Compositing rules specify how an element assigned to the canvas is combined with the earlier elements of the canvas. The default compositing rule for the canvas is `sourceOver`, but each element of the canvas can be assigned a composite type which overrides this default for the specific element.
---
--- The available types are as follows:
---  * `clear`           - Transparent. (R = 0)
---  * `copy`            - Source image. (R = S)
---  * `sourceOver`      - Source image wherever source image is opaque, and destination image elsewhere. (R = S + D*(1 - Sa))
---  * `sourceIn`        - Source image wherever both images are opaque, and transparent elsewhere. (R = S*Da)
---  * `sourceOut`       - Source image wherever source image is opaque but destination image is transparent, and transparent elsewhere. (R = S*(1 - Da))
---  * `sourceAtop`      - Source image wherever both images are opaque, destination image wherever destination image is opaque but source image is transparent, and transparent elsewhere. (R = S*Da + D*(1 - Sa))
---  * `destinationOver` - Destination image wherever destination image is opaque, and source image elsewhere. (R = S*(1 - Da) + D)
---  * `destinationIn`   - Destination image wherever both images are opaque, and transparent elsewhere. (R = D*Sa)
---  * `destinationOut`  - Destination image wherever destination image is opaque but source image is transparent, and transparent elsewhere. (R = D*(1 - Sa))
---  * `destinationAtop` - Destination image wherever both images are opaque, source image wherever source image is opaque but destination image is transparent, and transparent elsewhere. (R = S*(1 - Da) + D*Sa)
---  * `XOR`             - Exclusive OR of source and destination images. (R = S*(1 - Da) + D*(1 - Sa)). Works best with black and white images and is not recommended for color contexts.
---  * `plusDarker`      - Sum of source and destination images, with color values approaching 0 as a limit. (R = MAX(0, (1 - D) + (1 - S)))
---  * `plusLighter`     - Sum of source and destination images, with color values approaching 1 as a limit. (R = MIN(1, S + D))
---
--- In each equation, R is the resulting (premultiplied) color, S is the source color, D is the destination color, Sa is the alpha value of the source color, and Da is the alpha value of the destination color.
---
--- The `source` object is the individual element as it is rendered in order within the canvas, and the `destination` object is the combined state of the previous elements as they have been composited within the canvas.

--- hs._asm.uitk.element.canvas.help([attribute]) -> string
--- Function
--- Provides specification information for the recognized attributes, or the specific attribute specified.
---
--- Parameters:
---  * `attribute` - an optional string specifying an element attribute. If this argument is not provided, all attributes are listed.
---
--- Returns:
---  * a string containing some of the information provided by the [hs._asm.uitk.element.canvas.elementSpec](#elementSpec) in a manner that is easy to reference from the Hammerspoon console.

--- hs._asm.uitk.element.canvas.new(rect) -> canvasWindowObject
--- Constructor
--- Create a new window with a canvas as it's content at the specified coordinates
---
--- Parameters:
---  * `rect` - A rect-table containing the co-ordinates and size for the canvas object
---
--- Returns:
---  * a new, empty, canvas with window object, or nil if the canvas cannot be created with the specified coordinates
---
--- Notes:
---  * The size of the canvas defines the visible area of the canvas -- any portion of a canvas element which extends past the canvas's edges will be clipped.
---  * a rect-table is a table with key-value pairs specifying the top-left coordinate on the screen for the canvas (keys `x`  and `y`) and the size (keys `h` and `w`) of the canvas. The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
module.new = function(...)
    local styleMask = uitk.window.masks.borderless
    local canvasWin = uitk.window.new(..., styleMask)

    if canvasWin then
        canvasWin:backgroundColor{ alpha = 0, white = 0 }
                 :allowTextEntry(false)
                 :opaque(false)
                 :hasShadow(false)
                 :ignoresMouseEvents(true)
                 :animationBehavior("none")
                 :level("screenSaver")
--                  :accessibilitySubrole(:"+.Hammerspoon")
        local bounds = canvasWin:frame()
        bounds.x, bounds.y = 0, 0
        local canvasView = uitk.element.canvas(bounds)
        if canvasView then
            canvasWin:content(canvasView)
            local object = {}
            moduleMT.__e[object] = {
                window = canvasWin,
                view   = canvasView,
            }
            return setmetatable(object, moduleMT)
        end
    end
    return nil
end

module.useCustomAccessibilitySubrole = function(...)
    if not accessibilityWarningIssued then
        accessibilityWarningIssued = true
        print("*** useCustomAccessibilitySubrole is now a no-op -- all accessibility subroles are now left untouched as per Apple guidelines.")
    end
end

moduleMT.__name = USERDATA_TAG
moduleMT.__type = USERDATA_TAG

--- hs.canvas.object[index]
--- Field
--- An array-like method for accessing the attributes for the canvas element at the specified index
---
--- Notes:
--- Metamethods are assigned to the canvas object so that you can refer to individual elements of the canvas as if the canvas object was an array.  Each element is represented by a table of key-value pairs, where each key represents an attribute for that element.  Valid index numbers range from 1 to [hs.canvas:elementCount()](#elementCount) when getting an element or getting or setting one of its attributes, and from 1 to [hs.canvas:elementCount()](#elementCount) + 1 when assign an element table to an index in the canvas.  For example:
---
--- ~~~lua
--- c = require("hs.canvas")
--- a = c.new{ x = 100, y = 100, h = 100, w = 100 }:show()
--- a:insertElement({ type = "rectangle", id = "part1", fillColor = { blue = 1 } })
--- a:insertElement({ type = "circle", id = "part2", fillColor = { green = 1 } })
--- ~~~
--- can also be expressed as:
--- ~~~lua
--- c = require("hs.canvas")
--- a = c.new{ x = 100, y = 100, h = 100, w = 100 }:show()
--- a[1] = { type = "rectangle", id = "part1", fillColor = { blue = 1 } }
--- a[2] = { type = "circle", id = "part2", fillColor = { green = 1 } }
--- ~~~
---
--- You can change a canvas element's attributes using this same style: `a[2].fillColor.alpha = .5` will adjust the alpha value for element 2 of the canvas without adjusting any of the other color fields.  To replace the color entirely, assign it like this: `a[2].fillColor = { white = .5, alpha = .25 }`
---
--- The canvas defaults can also be accessed with the `_default` field like this: `a._default.strokeWidth = 5`.
---
--- Attributes which have a string specified as their `id` attribute can also be accessed as if the `id` where a `key` in the table-like canvas: e.g. `a.part2.action = "skip"`
---
--- It is important to note that these methods are a convenience and that the canvas object is not a true table.  The tables are generated dynamically as needed; as such `hs.inspect` cannot properly display them; however, you can just type in the element or element attribute you wish to see expanded in the Hammerspoon console (or in a `print` command) to see the assigned attributes, e.g. `a[1]` or `a[2].fillColor`, and an inspect-like output will be provided.
---
--- Attributes which allow using a string to specify a percentage (see [percentages](#percentages)) can also be retrieved as their actual number for the canvas's current size by appending `_raw` to the attribute name, e.g. `a[2].frame_raw`.
---
--- Because the canvas object is actually a Lua userdata, and not a real table, you cannot use the `table.insert` and `table.remove` functions on it.  For inserting or removing an element in any position except at the end of the canvas, you must still use [hs.canvas:insertElement](#insertElement) and [hs.canvas:removeElement](#removeElement).
---
--- You can, however, remove the last element with `a[#a] = nil`.
---
--- To print out all of the elements in the canvas with: `for i, v in ipairs(a) do print(v) end`.  The `pairs` iterator will also work, and will work on element sub-tables (transformations, fillColor and strokeColor, etc.), but this iterator does not guarantee order.
moduleMT.__index = function(self, key)
    if type(key) == "string" then
        if key == "_default" then
            local newTable = {}
            elementMT.__e[newTable] = { self = self, index = "_default" }
            return setmetatable(newTable, elementMT)
        elseif key == "_view" then
            return moduleMT.__e[self].view
        elseif key == "_window" then
            return moduleMT.__e[self].window
        else
            if moduleMT[key] then
                return moduleMT[key]
            else
                local answer
                for _,v in ipairs(self) do
                    if v.id == key then
                        answer = v
                        break
                    end
                end
                return answer
            end
        end
    elseif math.type(key) == "integer" and key > 0 and key <= self:elementCount() then
        local newTable = {}
        elementMT.__e[newTable] = { self = self, index = math.tointeger(key) }
        return setmetatable(newTable, elementMT)
    else
        return nil
    end
end

moduleMT.__newindex = function(self, key, value)
    if math.type(key) == "integer" and key > 0 and key <= (self:elementCount() + 1) then
        if type(value) == "table" or type(value) == "nil" then
            return self:assignElement(value, math.tointeger(key))
        else
            error("element definition must be a table", 2)
        end
    else
        error("index invalid or out of bounds", 2)
    end
end

moduleMT.__pairs = function(self)
    local keys = {}
    for i = 1, self:elementCount(), 1 do keys[i] = self[i] end
    return function(_, k)
            local v
            k, v = next(keys, k)
            return k, v
        end, self, nil
end

moduleMT.__eq = function(self, other)
    local objSelf = moduleMT.__e[self] or {}
    local objOther = moduleMT.__e[other] or {}
    return objSelf.window == objOther.window and objSelf.view == objOther.view
end

moduleMT.__gc = function(self)
    local obj = moduleMT.__e[self]
    obj.window:hide()
    obj.window = nil
    obj.view = nil
    setmetatable(self, nil)
end

moduleMT.__len = function(self)
    local obj = moduleMT.__e[self]
    return obj.view:elementCount()
end

moduleMT.__tostring = function(self)
    local obj = moduleMT.__e[self]
    return USERDATA_TAG .. tostring(obj.window):match("(:.+)$")
end

--- hs._asm.uitk.element.canvas:alpha([alpha]) -> canvasObject | number
--- Method
--- Get or set the alpha level of the canvasObject.
---
--- Parameters:
---  * `alpha` - an optional number specifying the new alpha level (0.0 - 1.0, inclusive) for the canvasObject
---
--- Returns:
---  * If an argument is provided, the canvas object; otherwise the current value.
moduleMT.alpha = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.window:alpha(...)
    return (result == obj.window) and self or result
end

--- hs._asm.uitk.element.canvas:hide([fadeOutTime]) -> canvasObject
--- Method
--- Hides the canvas object
---
--- Parameters:
---  * `fadeOutTime` - An optional number of seconds over which to fade out the canvas object. Defaults to zero.
---
--- Returns:
---  * The canvas object
moduleMT.hide = function(self, ...)
    local obj = moduleMT.__e[self]
    obj.window:hide(...)
    return self
end

--- hs._asm.uitk.element.canvas:mouseCallback([mouseCallbackFn]) -> canvasObject | function | nil
--- Method
--- Sets a callback for mouse events with respect to the canvas
---
--- Parameters:
---  * `mouseCallbackFn`   - An optional function or explicit nil, that will be called when a mouse event occurs within the canvas, and an element beneath the mouse's current position has one of the `trackMouse...` attributes set to true.
---
--- Returns:
---  * if an argument is provided, returns the canvasObject, otherwise returns the current value
---
--- Notes:
---  * The callback function should expect 5 arguments: the canvas object itself, a message specifying the type of mouse event, the canvas element `id` (or index position in the canvas if the `id` attribute is not set for the element), the x position of the mouse when the event was triggered within the rendered portion of the canvas element, and the y position of the mouse when the event was triggered within the rendered portion of the canvas element.
---  * See also [hs._asm.uitk.element.canvas:canvasMouseEvents](#canvasMouseEvents) for tracking mouse events in regions of the canvas not covered by an element with mouse tracking enabled.
---
---  * The following mouse attributes may be set to true for a canvas element and will invoke the callback with the specified message:
---    * `trackMouseDown`      - indicates that a callback should be invoked when a mouse button is clicked down on the canvas element.  The message will be "mouseDown".
---    * `trackMouseUp`        - indicates that a callback should be invoked when a mouse button has been released over the canvas element.  The message will be "mouseUp".
---    * `trackMouseEnterExit` - indicates that a callback should be invoked when the mouse pointer enters or exits the  canvas element.  The message will be "mouseEnter" or "mouseExit".
---    * `trackMouseMove`      - indicates that a callback should be invoked when the mouse pointer moves within the canvas element.  The message will be "mouseMove".
---
---  * The callback mechanism uses reverse z-indexing to determine which element will receive the callback -- the topmost element of the canvas which has enabled callbacks for the specified message will be invoked.
---
---  * No distinction is made between the left, right, or other mouse buttons. If you need to determine which specific button was pressed, use `hs.eventtap.checkMouseButtons()` within your callback to check.
---
---  * The hit point detection occurs by comparing the mouse pointer location to the rendered content of each individual canvas object... if an object which obscures a lower object does not have mouse tracking enabled, the lower object will still receive the event if it does have tracking enabled.
---
---  * Clipping regions which remove content from the visible area of a rendered object are ignored for the purposes of element hit-detection.
moduleMT.mouseCallback = function(self, ...)
    local args = table.pack(...)
    local obj = moduleMT.__e[self]
    local win, view = obj.window, obj.view

    if args.n == 0 then
        return view:mouseCallback()
    elseif args.n == 1 then
        local fn = args[1]
        if type(fn) == "nil" then
            view:mouseCallback(fn)
            win:ignoresMouseEvents(true)
        elseif type(fn) == "function" then
            view:mouseCallback(legacyWrappedCallback(self, fn))
            win:ignoresMouseEvents(false)
        else
            error(string.format("incorrect type '%s' for argument 1 (expected function or nil)", type(fn)), 3)
        end
        return self
    else
        error(string.format("incorrect number of arguments. Expected 0 or 1, got %d", args.n), 3)
    end
end

--- hs._asm.uitk.element.canvas:show([fadeInTime]) -> canvasObject
--- Method
--- Displays the canvas object
---
--- Parameters:
---  * `fadeInTime` - An optional number of seconds over which to fade in the canvas object. Defaults to zero.
---
--- Returns:
---  * The canvas object
moduleMT.show = function(self, ...)
    local obj = moduleMT.__e[self]
    obj.window:show(...)
    return self
end

--- hs._asm.uitk.element.canvas:delete([fadeOutTime]) -> none
--- Method
--- Destroys the canvas object, optionally fading it out first (if currently visible).
---
--- Parameters:
---  * `fadeOutTime` - An optional number of seconds over which to fade out the canvas object. Defaults to zero.
---
--- Returns:
---  * None
---
--- Notes:
---  * This method is no longer required, but is still included for backwards compatibility. When invoked, it will hide the canvas and then remove the stored references to the object; this will also happen if you allow the last reference to the canvas object to be garbage collected (i.e. not stored in a variable).
moduleMT.delete = moduleMT.__gc

--- hs._asm.uitk.element.canvas:isShowing() -> boolean
--- Method
--- Returns whether or not the canvas is currently being shown.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a boolean indicating whether or not the canvas is currently being shown (true) or is currently hidden (false).
---
--- Notes:
---  * This method only determines whether or not the canvas is being shown or is hidden -- it does not indicate whether or not the canvas is currently off screen or is occluded by other objects.
---  * See also [hs._asm.uitk.element.canvas:isOccluded](#isOccluded).
moduleMT.isShowing = function(self, ...)
    local obj = moduleMT.__e[self]
    return obj.window:isShowing(...)
end

--- hs._asm.uitk.element.canvas:isOccluded() -> boolean
--- Method
--- Returns whether or not the canvas is currently occluded (hidden by other windows, off screen, etc).
---
--- Parameters:
---  * None
---
--- Returns:
---  * a boolean indicating whether or not the canvas is currently being occluded.
---
--- Notes:
---  * If any part of the canvas is visible (even if that portion of the canvas does not contain any canvas elements), then the canvas is not considered occluded.
---  * a canvas which is completely covered by one or more opaque windows is considered occluded; however, if the windows covering the canvas are not opaque, then the canvas is not occluded.
---  * a canvas that is currently hidden or with a height of 0 or a width of 0 is considered occluded.
---  * See also [hs._asm.uitk.element.canvas:isShowing](#isShowing).
moduleMT.isOccluded = function(self, ...)
    local obj = moduleMT.__e[self]
    return obj.window:isOccluded(...)
end

--- hs._asm.uitk.element.canvas:isVisible() -> boolean
--- Method
--- Returns whether or not the canvas is currently showing and is (at least partially) visible on screen.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a boolean indicating whether or not the canvas is currently visible.
---
--- Notes:
---  * This is syntactic sugar for `not hs._asm.uitk.element.canvas:isOccluded()`.
---  * See [hs._asm.uitk.element.canvas:isOccluded](#isOccluded) for more details.
moduleMT.isVisible = function(self, ...) return not self:isOccluded(...) end

--- hs._asm.uitk.element.canvas:copy() -> canvasObject
--- Method
--- Creates a copy of the canvas.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a copy of the canvas
---
--- Notes:
---  * The copy of the canvas will be identical in all respects except:
---    * The new canvas will not have a callback function assigned, even if the original canvas does.
---    * The new canvas will not initially be visible, even if the original is.
---  * The new canvas is an independent entity -- any subsequent changes to either canvas will not be reflected in the other canvas.
---
---  * This method allows you to display a canvas in multiple places or use it as a canvas element multiple times.
moduleMT.copy = function(self, ...)
    local args = table.pack(...)
    if args.n > 0 then
        error(string.format("incorrect number of arguments. Expected 0, got %d", args.n), 3)
    end

    local newCanvas = module.new(self:frame()):alpha(self:alpha())
                                              :behavior(self:behavior())
                                              :canvasMouseEvents(self:canvasMouseEvents())
                                              :clickActivating(self:clickActivating())
                                              :level(self:level())
                                              :transformation(self:transformation())
                                              :wantsLayer(self:wantsLayer())

    for _, v in ipairs(self:canvasDefaultKeys()) do
        newCanvas:canvasDefaultFor(v, self:canvasDefaultFor(v))
    end

    for i = 1, #self, 1 do
        for _, v2 in ipairs(self:elementKeys(i)) do
            local value = self:elementAttribute(i, v2)
            newCanvas:elementAttribute(i, v2, value)
        end
    end

    return newCanvas
end


--- hs._asm.uitk.element.canvas.percentages
--- Field
--- Canvas attributes which specify the location and size of canvas elements can be specified with an absolute position or as a percentage of the canvas size.
---
--- Notes:
--- Percentages may be assigned to the following attributes:
---  * `frame`       - the frame used by the `rectangle`, `oval`, `ellipticalArc`, `text`, and `image` types.  The `x` and `w` fields will be a percentage of the canvas's width, and the `y` and `h` fields will be a percentage of the canvas's height.
---  * `center`      - the center point for the `circle` and `arc` types.  The `x` field will be a percentage of the canvas's width and the `y` field will be a percentage of the canvas's height.
---  * `radius`      - the radius for the `circle` and `arc` types.  The radius will be a percentage of the canvas's width.
---  * `coordinates` - the point coordinates used by the `segments` and `points` types.  X coordinates (fields `x`, `c1x`, and `c2x`) will be a percentage of the canvas's width, and Y coordinates (fields `y`, `c1y`, and `c2y`) will be a percentage of the canvas's height.
---
--- Percentages are assigned to these fields as a string.  If the number in the string ends with a percent sign (%), then the percentage is the whole number which precedes the percent sign.  If no percent sign is present, the percentage is expected in decimal format (e.g. "1.0" is the same as "100%").
---
--- Because a shadow applied to a canvas element is not considered as part of the element's bounds, you can also set the `padding` attribute to a positive number of points to inset the calculated values by from each edge of the canvas's frame so that the shadow will be fully visible within the canvas, even when an element is set to a width and height of "100%".

moduleMT._accessibilitySubrole = function(...)
    if not accessibilityWarningIssued then
        accessibilityWarningIssued = true
        print("*** _accessibilitySubrole is now a no-op -- all accessibility subroles are now left untouched as per Apple guidelines.")
    end
end

--- hs._asm.uitk.element.canvas:frame([rect]) -> canvasWindowObject | table
--- Method
--- Get or set the frame of the canvasWindowObject.
---
--- Parameters:
---  * rect - An optional rect-table containing the co-ordinates and size the canvas object should be moved and set to
---
--- Returns:
---  * If an argument is provided, the canvas object; otherwise the current value.
---
--- Notes:
---  * a rect-table is a table with key-value pairs specifying the new top-left coordinate on the screen of the canvas (keys `x`  and `y`) and the new size (keys `h` and `w`).  The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
---
---  * elements in the canvas that have the `absolutePosition` attribute set to false will be moved so that their relative position within the canvas remains the same with respect to the new size.
---  * elements in the canvas that have the `absoluteSize` attribute set to false will be resized so that their relative size with respect to the canvas remains the same with respect to the new size.
moduleMT.frame = function(self, ...)
    local pos  = self:topLeft(...)
    local size = self:size(...)
    if size == pos then
        return self
    else
        return { x = pos.x, y = pos.y, h = size.h, w = size.w }
    end
end

--- hs._asm.uitk.element.canvas:topLeft([point]) -> canvasWindowObject | table
--- Method
--- Get or set the top-left coordinate of the canvas object
---
--- Parameters:
---  * `point` - An optional point-table specifying the new coordinate the top-left of the canvas object should be moved to
---
--- Returns:
---  * If an argument is provided, the canvas object; otherwise the current value.
---
--- Notes:
---  * a point-table is a table with key-value pairs specifying the new top-left coordinate on the screen of the canvas (keys `x`  and `y`). The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
moduleMT.topLeft = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.window:topLeft(...)
    return (result == obj.window) and self or result
end

--- hs._asm.uitk.element.canvas:size([size]) -> canvasObject | table
--- Method
--- Get or set the size of a canvas object
---
--- Parameters:
---  * `size` - An optional size-table specifying the width and height the canvas object should be resized to
---
--- Returns:
---  * If an argument is provided, the canvas object; otherwise the current value.
---
--- Notes:
---  * a size-table is a table with key-value pairs specifying the size (keys `h` and `w`) the canvas should be resized to. The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
moduleMT.size = function(self, ...)
    local obj = moduleMT.__e[self]
    -- this allows the canvas to reposition items per absoluteSize and absolutePosition attributes
    if table.pack(...).n > 0 then obj.view:size(...) end
    local result = obj.window:size(...)
    return (result == obj.window) and self or result
end

--- hs._asm.uitk.element.canvas:orderAbove([window2) -> canvasWindowObject
--- Method
--- Moves canvas object above window2, or all `hs._asm.uitk.window` objects in the same presentation level, if window2 is not given.
---
--- Parameters:
---  * `window2` - An optional `hs._asm.uitk.window` object to place the canvas object above.
---
--- Returns:
---  * The canvas object
---
--- Notes:
---  * If the canvas object and window2 are not at the same presentation level, this method will move the canvas object as close to the desired relationship as possible without changing the canvas object's presentation level. See [hs._asm.uitk.element.canvas.level](#level).
moduleMT.orderAbove = function(self, otherWin, ...)
    local obj = moduleMT.__e[self]
    local args = table.pack(...)

    if args.n > 0 then
        error(string.format("incorrect number of arguments. Expected 0 or 1, got %d", args.n + 1), 3)
    end
    if otherWin then
        if getmetatable(otherWin) == moduleMT then
            otherWin = moduleMT.__e[otherWin].window
            obj.window:orderAbove(otherWin)
        else
            error(string.format("expected %s for argument 1", USERDATA_TAG), 3)
        end
    else
        obj.window:orderAbove()
    end
    return self
end

--- hs._asm.uitk.element.canvas:orderBelow([window2]) -> canvasWindowObject
--- Method
--- Moves canvas object below window2, or all `hs._asm.uitk.window` objects in the same presentation level, if window2 is not given.
---
--- Parameters:
---  * `window2` - An optional `hs._asm.uitk.window` object to place the canvas object below.
---
--- Returns:
---  * The canvas object
---
--- Notes:
---  * If the canvas object and window2 are not at the same presentation level, this method will move the canvas object as close to the desired relationship as possible without changing the canvas object's presentation level. See [hs._asm.uitk.element.canvas.level](#level).
moduleMT.orderBelow = function(self, otherWin, ...)
    local obj = moduleMT.__e[self]
    local args = table.pack(...)

    if args.n > 0 then
        error(string.format("incorrect number of arguments. Expected 0 or 1, got %d", args.n + 1), 3)
    end
    if otherWin then
        if getmetatable(otherWin) == moduleMT then
            otherWin = moduleMT.__e[otherWin].window
            obj.window:orderBelow(otherWin)
        else
            error(string.format("expected %s for argument 1", USERDATA_TAG), 3)
        end
    else
        obj.window:orderBelow()
    end
    return self
end

--- hs._asm.uitk.element.canvas:bringToFront([aboveEverything]) -> canvasWindowObject
--- Method
--- Places the canvas window on top of normal windows
---
--- Parameters:
---  * aboveEverything - An optional boolean, default false, that controls how far to the front the canvas window should be placed.
---    * if true, place the canvas on top of all windows (including the dock and menubar and fullscreen windows).
---    * if false, place the canvas above normal windows, but below the dock, menubar and fullscreen windows.
---
--- Returns:
---  * The canvas object
---
--- Notes:
---  * As of macOS Sierra and later, if you want a `hs._asm.uitk.element.canvas` window object to appear above full-screen windows you must hide the Hammerspoon Dock icon first using: `hs.dockicon.hide()`
moduleMT.bringToFront = function(self, ...)
    local obj = moduleMT.__e[self]
    local args = table.pack(...)

    if args.n == 0 then
        obj.window:level("floating")
    elseif args.n == 1 and type(args[1]) == "boolean" then
        obj.window:level(args[1] and "screenSaver" or "floating")
    elseif args.n == 1 then
        error(string.format("incorrect type '%s' for argument 1 (expected boolean)", type(args[1])), 3)
    else
        error(string.format("incorrect number of arguments. Expected 1, got %d", args.n), 3)
    end
    return self
end

--- hs._asm.uitk.element.canvas:sendToBack() -> canvasWindowObject
--- Method
--- Places the canvas window behind normal windows, between the desktop wallpaper and desktop icons
---
--- Parameters:
---  * None
---
--- Returns:
---  * The canvas object
moduleMT.sendToBack = function(self, ...)
    local obj = moduleMT.__e[self]
    local args = table.pack(...)

    if args.n == 0 then
        obj.window:level(module.windowLevels.desktopIcon - 1)
    else
        error(string.format("incorrect number of arguments. Expected 0, got %d", args.n), 3)
    end
    return self
end

--- hs._asm.uitk.element.canvas:clickActivating([flag]) -> canvasWindowObject | boolean
--- Method
--- Get or set whether or not clicking on a canvas window with a click callback defined should bring all of Hammerspoon's open windows to the front.
---
--- Parameters:
---  * `flag` - an optional boolean indicating whether or not clicking on a canvas with a click callback function defined should activate Hammerspoon and bring its windows forward. Defaults to true.
---
--- Returns:
---  * If an argument is provided, returns the canvas object; otherwise returns the current setting.
---
--- Notes:
---  * Setting this to false changes a canvas object's AXsubrole value and may affect the results of filters used with `hs.window.filter`, depending upon how they are defined.
moduleMT.clickActivating = function(self, ...)
    local obj = moduleMT.__e[self]
    local args = table.pack(...)
    local win = obj.window

    local masks = win:styleMask()
    if args.n == 0 then
        return (masks & uitk.window.masks.nonactivating) == uitk.window.masks.nonactivating
    elseif args.n == 1 and type(args[1]) == "boolean" then
        if args[1] then
            qin:styleMask(masks & ~uitk.window.masks.nonactivating)
        else
            win:styleMask(masks | uitk.window.masks.nonactivating)
        end
    elseif args.n == 1 then
        error(string.format("incorrect type '%s' for argument 1 (expected boolean)", type(args[1])), 3)
    else
        error(string.format("incorrect number of arguments. Expected 1, got %d", args.n), 3)
    end
    return self
end

--- hs._asm.uitk.element.canvas:level([level]) -> canvasWindowObject | integer
--- Method
--- Sets the window level more precisely than sendToBack and bringToFront.
---
--- Parameters:
---  * `level` - an optional level, specified as a number or as a string, specifying the new window level for the canvasObject. If it is a string, it must match one of the keys in [hs._asm.uitk.element.canvas.windowLevels](#windowLevels).
---
--- Returns:
---  * If an argument is provided, the canvas object; otherwise the current value.
moduleMT.level = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.window:level(...)
    return (result == obj.window) and self or result
end

--- hs._asm.uitk.element.canvas:behavior([behavior]) -> canvasWindowObject | integer
--- Method
--- Get or set the window behavior settings for the canvas object using labels defined in [hs._asm.uitk.element.canvas.windowBehaviors](#windowBehaviors).
---
--- Parameters:
---  * `behavior` - if present, the behavior should be a combination of values found in [hs._asm.uitk.element.canvas.windowBehaviors](#windowBehaviors) describing the window behavior.  The behavior should be specified as one of the following:
---    * integer - a number representing the behavior which can be created by combining values found in [hs._asm.uitk.element.canvas.windowBehaviors](#windowBehaviors) with the logical or operator.
---    * string  - a single key from [hs._asm.uitk.element.canvas.windowBehaviors](#windowBehaviors) which will be toggled in the current window behavior.
---    * table   - a list of keys from [hs._asm.uitk.element.canvas.windowBehaviors](#windowBehaviors) which will be combined to make the final behavior by combining their values with the logical or operator.
---
--- Returns:
---  * if an argument is provided, then the canvasObject is returned; otherwise the current behavior value is returned.
moduleMT.behavior = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.window:collectionBehavior(...)
    return (result == obj.window) and self or result
end

--- hs._asm.uitk.element.canvas:behaviorAsLabels(behaviorTable) -> canvasWindowObject | table
--- Method
--- Get or set the window behavior settings for the canvas object using labels defined in [hs._asm.uitk.element.canvas.windowBehaviors](#windowBehaviors).
---
--- Parameters:
---  * behaviorTable - an optional table of strings and/or integers specifying the desired window behavior for the canvas object.
---
--- Returns:
---  * If an argument is provided, the canvas object; otherwise the current value as a table of strings.
moduleMT.behaviorAsLabels = function(self, ...)
    local results = self:behavior(...)

    if type(results) == "number" then
        results = uitk.util.intToMasks(results, module.windowBehaviors)
        return setmetatable(results, { __tostring = function(_)
            table.sort(_)
            return "{ "..table.concat(_, ", ").." }"
        end})
    else
        return results
    end
end

--- hs._asm.uitk.element.canvas:assignElement(elementTable, [index]) -> canvasObject
--- Method
--- Assigns a new element to the canvas at the specified index.
---
--- Parameters:
---  * `elementTable` - a table containing key-value pairs that define the element to be added to the canvas.
---  * `index`        - an optional integer between 1 and the canvas element count + 1 specifying the index position to put the new element.  Any element currently at that index will be replaced.  Defaults to the canvas element count + 1 (i.e. after the end of the currently defined elements).
---
--- Returns:
---  * the canvasObject
---
--- Notes:
---  * When the index specified is the canvas element count + 1, the behavior of this method is the same as [hs._asm.uitk.element.canvas:insertElement](#insertElement); i.e. it adds the new element to the end of the currently defined element list.
moduleMT.assignElement = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:assignElement(...)
    return (result == obj.view) and self or result
end

--- hs._asm.uitk.element.canvas:canvasDefaultFor(keyName, [newValue]) -> canvasObject | key value
--- Method
--- Get or set the element default specified by keyName.
---
--- Parameters:
---  * `keyName` - the element default to examine or modify
---  * `value`   - an optional new value to set as the default fot his canvas when not specified explicitly in an element declaration.
---
--- Returns:
---  * If an argument is provided, the canvas object; otherwise the current value.
---
--- Notes:
---  * Not all keys will apply to all element types.
---  * Currently set and built-in defaults may be retrieved in a table with [hs._asm.uitk.element.canvas:canvasDefaults](#canvasDefaults).
moduleMT.canvasDefaultFor = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:canvasDefaultFor(...)
    return (result == obj.view) and self or result
end

--- hs._asm.uitk.element.canvas:canvasDefaultKeys([module]) -> table
--- Method
--- Returns a list of the key names for the attributes set for the canvas defaults.
---
--- Parameters:
---  * `module` - an optional boolean flag, default false, indicating whether the key names for the module defaults (true) should be included in the list.  If false, only those defaults which have been explicitly set for the canvas are included.
---
--- Returns:
---  * a table containing the key names for the defaults which are set for this canvas. May also optionally include key names for all attributes which have a default value defined by the module.
moduleMT.canvasDefaultKeys = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:canvasDefaultKeys(...)
    return result
end

--- hs._asm.uitk.element.canvas:canvasDefaults([module]) -> table
--- Method
--- Get a table of the default key-value pairs which apply to the canvas.
---
--- Parameters:
---  * `module` - an optional boolean flag, default false, indicating whether module defaults (true) should be included in the table.  If false, only those defaults which have been explicitly set for the canvas are returned.
---
--- Returns:
---  * a table containing key-value pairs for the defaults which apply to the canvas.
---
--- Notes:
---  * Not all keys will apply to all element types.
---  * To change the defaults for the canvas, use [hs._asm.uitk.element.canvas:canvasDefaultFor](#canvasDefaultFor).
moduleMT.canvasDefaults = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:canvasDefaults(...)
    return result
end

--- hs._asm.uitk.element.canvas:canvasElements() -> table
--- Method
--- Returns an array containing the elements defined for this canvas.  Each array entry will be a table containing the key-value pairs which have been set for that canvas element.
---
--- Parameters:
---  * None
---
--- Returns:
---  * an array of element tables which are defined for the canvas.
moduleMT.canvasElements = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:canvasElements(...)
    return result
end

moduleMT.canvasMouseEvents = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:canvasMouseEvents(...)
    if result == obj.view then
        return self
    else
        return table.unpack(result)
    end
end

moduleMT.draggingCallback = function(self, ...)
    local args = table.pack(...)
    local obj = moduleMT.__e[self]
    local win, view = obj.window, obj.view

    if args.n == 0 then
        return view:draggingCallback()
    elseif args.n == 1 then
        local fn = args[1]
        if type(fn) == "nil" then
            view:draggingCallback(fn)
        elseif type(fn) == "function" then
            view:draggingCallback(legacyWrappedCallback(self, fn))
        else
            error(string.format("incorrect type '%s' for argument 1 (expected function or nil)", type(fn)), 3)
        end
        return self
    else
        error(string.format("incorrect number of arguments. Expected 0 or 1, got %d", args.n), 3)
    end
end

--- hs._asm.uitk.element.canvas:elementAttribute(index, key, [value]) -> canvasObject | key value
--- Method
--- Get or set the attribute `key` for the canvas element at the specified index.
---
--- Parameters:
---  * `index` - the index of the canvas element whose attribute is to be retrieved or set.
---  * `key`   - the key name of the attribute to get or set.
---  * `value` - an optional value to assign to the canvas element's attribute.
---
--- Returns:
---  * if a value for the attribute is specified, returns the canvas object; otherwise returns the current value for the specified attribute.
moduleMT.elementAttribute = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:elementAttribute(...)
    return (result == obj.view) and self or result
end

--- hs._asm.uitk.element.canvas:elementBounds(index) -> rectTable
--- Method
--- Returns the smallest rectangle which can fully contain the canvas element at the specified index.
---
--- Parameters:
---  * `index` - the index of the canvas element to get the bounds for
---
--- Returns:
---  * a rect table containing the smallest rectangle which can fully contain the canvas element.
---
--- Notes:
---  * For many elements, this will be the same as the element frame.  For items without a frame (e.g. `segments`, `circle`, etc.) this will be the smallest rectangle which can fully contain the canvas element as specified by it's attributes.
moduleMT.elementBounds = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:elementBounds(...)
    return result
end

--- hs._asm.uitk.element.canvas:elementCount() -> integer
--- Method
--- Returns the number of elements currently defined for the canvas object.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the number of elements currently defined for the canvas object.
moduleMT.elementCount = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:elementCount(...)
    return result
end

--- hs._asm.uitk.element.canvas:elementKeys(index, [optional]) -> table
--- Method
--- Returns a list of the key names for the attributes set for the canvas element at the specified index.
---
--- Parameters:
---  * `index`    - the index of the element to get the assigned key list from.
---  * `optional` - an optional boolean, default false, indicating whether optional, but unset, keys relevant to this canvas object should also be included in the list returned.
---
--- Returns:
---  * a table containing the keys that are set for this canvas element.  May also optionally include keys which are not specifically set for this element but use inherited values from the canvas or module defaults.
---
--- Notes:
---  * Any attribute which has been explicitly set for the element will be included in the key list (even if it is ignored for the element type).  If the `optional` flag is set to true, the *additional* attribute names added to the list will only include those which are relevant to the element type.
moduleMT.elementKeys = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:elementKeys(...)
    return result
end

--- hs._asm.uitk.element.canvas:imageFromCanvas() -> hs.image object
--- Method
--- Returns an image of the canvas contents as an `hs.image` object.
---
--- Parameters:
---  * None
---
--- Returns:
---  * an `hs.image` object
---
--- Notes:
---  * The canvas does not have to be visible in order for an image to be generated from it.
moduleMT.imageFromCanvas = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:imageFromCanvas(...)
    return result
end

--- hs._asm.uitk.element.canvas:insertElement(elementTable, [index]) -> canvasObject
--- Method
--- Insert a new element into the canvas at the specified index.
---
--- Parameters:
---  * `elementTable` - a table containing key-value pairs that define the element to be added to the canvas.
---  * `index`        - an optional integer between 1 and the canvas element count + 1 specifying the index position to put the new element.  Any element currently at that index, and those that follow, will be moved one position up in the element array.  Defaults to the canvas element count + 1 (i.e. after the end of the currently defined elements).
---
--- Returns:
---  * the canvasObject
---
--- Notes:
---  * see also [hs._asm.uitk.element.canvas:assignElement](#assignElement).
moduleMT.insertElement = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:insertElement(...)
    return (result == obj.view) and self or result
end

--- hs._asm.uitk.element.canvas:minimumTextSize([index], text) -> table
--- Method
--- Returns a table specifying the size of the rectangle which can fully render the text with the specified style so that is will be completely visible.
---
--- Parameters:
---  * `index` - an optional index specifying the element in the canvas which contains the text attributes which should be used when determining the size of the text. If not provided, the canvas defaults will be used instead. Ignored if `text` is an hs.styledtext object.
---  * `text`  - a string or hs.styledtext object specifying the text.
---
--- Returns:
---  * a size table specifying the height and width of a rectangle which could fully contain the text when displayed in the canvas
---
--- Notes:
---  * Multi-line text (separated by a newline or return) is supported.  The height will be for the multiple lines and the width returned will be for the longest line.
moduleMT.minimumTextSize = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:minimumTextSize(...)
    return result
end

--- hs._asm.uitk.element.canvas:removeElement([index]) -> canvasObject
--- Method
--- Insert a new element into the canvas at the specified index.
---
--- Parameters:
---  * `index`        - an optional integer between 1 and the canvas element count specifying the index of the canvas element to remove. Any elements that follow, will be moved one position down in the element array.  Defaults to the canvas element count (i.e. the last element of the currently defined elements).
---
--- Returns:
---  * the canvasObject
moduleMT.removeElement = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:removeElement(...)
    return (result == obj.view) and self or result
end

--- hs._asm.uitk.element.canvas:transformation([matrix]) -> canvasObject | table
--- Method
--- Get or set the matrix transformation which is applied to every element in the canvas before being individually processed and added to the canvas.
---
--- Parameters:
---  * `matrix` - an optional table specifying the matrix table, as defined by the `hs._asm.uitk.util.matrix` module, to be applied to every element of the canvas, or an explicit `nil` to reset the transformation to the identity matrix.
---
--- Returns:
---  * if an argument is provided, returns the canvasObject, otherwise returns the current value
---
--- Notes:
---  * An example use for this method would be to change the canvas's origin point { x = 0, y = 0 } from the lower left corner of the canvas to somewhere else, like the middle of the canvas.
moduleMT.transformation = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:transformation(...)
    return (result == obj.view) and self or result
end

--- hs._asm.uitk.element.canvas:wantsLayer([flag]) -> canvasObject | true
--- Method
--- Get or set whether or not the canvas object should be rendered by the view or by Core Animation.
---
--- Parameters:
---  * `flag` - optional boolean (default false) which indicates whether the canvas object should be rendered by the containing view (false) or by Core Animation (true).
---
--- Returns:
---  * If an argument is provided, the canvas object; otherwise the current value.
---
--- Notes:
---  * This method can help smooth the display of small text objects on non-Retina monitors.
moduleMT.wantsLayer = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:wantsLayer(...)
    return (result == obj.view) and self or result
end

--- hs._asm.uitk.element.canvas:appendElements(element...) -> canvasObject
--- Method
--- Appends the elements specified to the canvas.
---
--- Parameters:
---  * `element` - a table containing key-value pairs that define the element to be appended to the canvas.  You can specify one or more elements and they will be appended in the order they are listed.
---
--- Returns:
---  * the canvas object
---
--- Notes:
---  * You can also specify multiple elements in a table as an array, where each index in the table contains an element table, and use the array as a single argument to this method if this style works better in your code.
moduleMT.appendElements = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:appendElements(...)
    return (result == obj.view) and self or result
end

--- hs._asm.uitk.element.canvas:replaceElements(element...) -> canvasObject
--- Method
--- Replaces all of the elements in the canvas with the elements specified.  Shortens or lengthens the canvas element count if necessary to accomodate the new canvas elements.
---
--- Parameters:
---  * `element` - a table containing key-value pairs that define the element to be assigned to the canvas.  You can specify one or more elements and they will be appended in the order they are listed.
---
--- Returns:
---  * the canvas object
---
--- Notes:
---  * You can also specify multiple elements in a table as an array, where each index in the table contains an element table, and use the array as a single argument to this method if this style works better in your code.
moduleMT.replaceElements = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:replaceElements(...)
    return (result == obj.view) and self or result
end

--- hs._asm.uitk.element.canvas:rotateElement(index, angle, [point], [append]) -> canvasObject
--- Method
--- Rotates an element about the point specified, or the elements center if no point is specified.
---
--- Parameters:
---  * `index`  - the index of the element to rotate
---  * `angle`  - the angle to rotate the object in a clockwise direction
---  * `point`  - an optional point table, defaulting to the element's center, specifying the point around which the object should be rotated
---  * `append` - an optional boolean, default false, specifying whether or not the rotation transformation matrix should be appended to the existing transformation assigned to the element (true) or replace it (false).
---
--- Returns:
---  * the canvas object
---
--- Notes:
---  * a point-table is a table with key-value pairs specifying a coordinate in the canvas (keys `x`  and `y`). The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
---  * The center of the object is determined by getting the element's bounds with [hs._asm.uitk.element.canvas:elementBounds](#elementBounds).
---  * If the third argument is a boolean value, the `point` argument is assumed to be the element's center and the boolean value is used as the `append` argument.
---
---  * This method uses `hs._asm.uitk.util.matrix` to generate the rotation transformation and provides a wrapper for `hs._asm.uitk.matrix.translate(x, y):rotate(angle):translate(-x, -y)` which is then assigned or appended to the element's existing `transformation` attribute.
moduleMT.rotateElement = function(self, ...)
    local obj = moduleMT.__e[self]
    local result = obj.view:rotateElement(...)
    return (result == obj.view) and self or result
end

-- store this in the registry so we can easily set it both from Lua and from C functions
debug.getregistry()[USERDATA_TAG] = moduleMT

-- Return Module Object --------------------------------------------------

return module

