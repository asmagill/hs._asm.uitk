-- REMOVE IF ADDED TO CORE APPLICATION
    repeat
        -- add proper user dylib path if it doesn't already exist
        if not package.cpath:match(hs.configdir .. "/%?.dylib") then
            package.cpath = hs.configdir .. "/?.dylib;" .. package.cpath
        end

        -- load docs file if provided
        local basePath, moduleName = debug.getinfo(1, "S").source:match("^@(.*)/([%w_]+).lua$")
        if basePath and moduleName then
            if moduleName == "init" then
                moduleName = moduleName:match("/([%w_]+)$")
            end

            local docsFileName = basePath .. "/" .. moduleName .. ".docs.json"
            if require"hs.fs".attributes(docsFileName) then
                require"hs.doc".registerJSONFile(docsFileName)
            end
        end

        -- setup loaders for submodules (if any)
        --     copy into Hammerspoon/setup.lua before removing

    until true -- executes once and hides any local variables we create
-- END REMOVE IF ADDED TO CORE APPLICATION

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

local USERDATA_TAG = "hs._asm.uitk.element.canvas"
local uitk         = require("hs._asm.uitk")
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libelement_"))

module.matrix      = uitk.util.matrix

-- include these so that their support functions are available to us
require("hs.image")
require("hs.styledtext")

local accessibilityWarningIssued = false

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- support function for hs._asm.uitk.canvas.help
local help_table
help_table = function(depth, value)
    local result = "{\n"
    for k,v in require("hs.fnutils").sortByKeys(value) do
        if not ({class = 1, objCType = 1, memberClass = 1})[k] then
            local displayValue = v
            if type(v) == "table" then
                displayValue = help_table(depth + 2, v)
            elseif type(v) == "string" then
                displayValue = "\"" .. v .. "\""
            end
            local displayKey = k
            if type(k) == "number" then
                displayKey = "[" .. tostring(k) .. "]"
            end
            result = result .. string.rep(" ", depth + 2) .. string.format("%s = %s,\n", tostring(displayKey), tostring(displayValue))
        end
    end
    result = result .. string.rep(" ", depth) .. "}"
    return result
end

-- Public interface ------------------------------------------------------

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
    elseif type(key) == "number" and key > 0 and key <= self:elementCount() and math.tointeger(key) then
        local newTable = {}
        elementMT.__e[newTable] = { self = self, index = math.tointeger(key) }
        return setmetatable(newTable, elementMT)
    else
        return nil
    end
end

moduleMT.__newindex = function(self, key, value)
    if type(key) == "number" and key > 0 and key <= (self:elementCount() + 1) and math.tointeger(key) then
        if type(value) == "table" or type(value) == "nil" then
            return self:assignElement(value, math.tointeger(key))
        else
            error("element definition must be a table", 2)
        end
    else
        error("index invalid or out of bounds", 2)
    end
end

moduleMT.__len = function(self)
    return self:elementCount()
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

module.compositeTypes  = ls.makeConstantsTable(module.compositeTypes)
module.windowBehaviors = uitk.window.behaviors
module.windowLevels    = uitk.window.levels

--- hs._asm.uitk.element.canvas:alpha([alpha]) -> canvasObject | currentValue
--- Method
--- Get or set the alpha level of the canvasObject.
---
--- Parameters:
---  * `alpha` - an optional number specifying the new alpha level (0.0 - 1.0, inclusive) for the canvasObject
---
--- Returns:
---  * If an argument is provided, the canvas object; otherwise the current value.
moduleMT.alpha = function(self, ...)
    local canvasWin = self:_wrappedWindow()
    if canvasWin then
        local result = canvasWin:alpha(...)
        return type(result) == "userdata" and self or result
    else
        return self:_alpha(...)
    end
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
    local canvasWin = self:_wrappedWindow()
    if canvasWin then
        canvasWin:hide(...)
    else
        self:_hide(...)
    end
    return self
end

--- hs._asm.uitk.element.canvas:mouseCallback([mouseCallbackFn]) -> canvasObject | current value
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
---  * For proper mouse tracking, the containing `hs._asm.uitk.window` object must also have the `ignoresMouseEvents` property set to false. If you use the legacy canvas constructor, [hs._asm.uitk.element.canvas.new](#new), this is taken care of automatically for you; if you create the canvas with [hs._asm.uitk.element.canvas.newCanvas](#newCanvas) or with the `hs._asm.uitk.element.canvas(...)` shorthand, you will need to manage this yourself.
---
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
    local canvasWin = self:_wrappedWindow()
    local result    = self:_mouseCallback(...)
    if canvasWin and result == self then
        canvasWin:ignoresMouseEvents(not self:_mouseCallback() and true or false)
    end
    return result
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
    local canvasWin = self:_wrappedWindow()
    if canvasWin then
        canvasWin:show(...)
    else
        self:_show(...)
    end
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
---  * This method is automatically called during garbage collection, notably during a Hammerspoon termination or reload, with a fade time of 0.
moduleMT.delete = function(self, ...)
    self:hide(...)
    return nil
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
    local elementsArray = table.pack(...)
    if elementsArray.n == 1 and #elementsArray[1] ~= 0 then elementsArray = elementsArray[1] end
    for _,v in ipairs(elementsArray) do self:insertElement(v) end
    return self
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
moduleMT.replaceElements = function(self,  ...)
    local elementsArray = table.pack(...)
    if elementsArray.n == 1 and #elementsArray[1] ~= 0 then elementsArray = elementsArray[1] end
    for i,v in ipairs(elementsArray) do self:assignElement(v, i) end
    while (#self > #elementsArray) do self:removeElement() end
    return self
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
moduleMT.rotateElement = function(self, index, angle, point, append)
    if type(point) == "boolean" then
        append, point = point, nil
    end

    if not point then
        local bounds = self:elementBounds(index)
        point = {
            x = bounds.x + bounds.w / 2,
            y = bounds.y + bounds.h / 2,
        }
    end

    local initialTransform = append and self[index].transformation or module.matrix.identity()
    self[index].transformation = initialTransform:translate(point.x, point.y)
                                                 :rotate(angle)
                                                 :translate(-point.x, -point.y)
    return self
end

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
    local args = table.pack(...)
    local canvasWin = self:_window()

    if canvasWin then
        return canvasWin:isShowing(...) and not self:_hidden(...)
    else
        return false
    end
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
    local args = table.pack(...)
    local canvasWin = self:_window()

    if canvasWin then
        return canvas:isOccluded(...) or self:_hidden(...)
    else
        return true
    end
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
---
---  * If the original canvas object was a legacy canvas window, the copy will also be a legacy canvas window.
moduleMT.copy = function(self, ...)
    local args = table.pack(...)
    local canvasWin = self:_wrappedWindow()

    if args.n == 0 then
        local newCanvas = canvasWin and module.new(self:frame()) or module.newCanvas(self:frameSize())
        newCanvas:alpha(obj:alpha())
                           :behavior(obj:behavior())
                           :canvasMouseEvents(obj:canvasMouseEvents())
                           :clickActivating(obj:clickActivating())
                           :level(obj:level())
                           :transformation(obj:transformation())
                           :wantsLayer(obj:wantsLayer())

        for _, v in ipairs(self:canvasDefaultKeys()) do
          newCanvas:canvasDefaultFor(v, self:canvasDefaultFor(v))
        end

        for i = 1, #self, 1 do
          for _, v2 in ipairs(self:elementKeys(i)) do
              local value = self:elementAttribute(i, v2)
              newCanvas:elementAttribute(i, v2, value)
          end
        end
    else
        error(string.format("incorrect number of arguments. Expected 0, got %d", args.n), 3)
    end

    return newCanvas
end

--- hs._asm.uitk.element.canvas.help([attribute]) -> string
--- Function
--- Provides specification information for the recognized attributes, or the specific attribute specified.
---
--- Parameters:
---  * `attribute` - an optional string specifying an element attribute. If this argument is not provided, all attributes are listed.
---
--- Returns:
---  * a string containing some of the information provided by the [hs._asm.uitk.element.canvas.elementSpec](#elementSpec) in a manner that is easy to reference from the Hammerspoon console.
module.help = function(what)
    local help = module.elementSpec()
    if what and help[what] then what, help = nil, help[what] end
    if type(what) ~= "nil" then
        error("unrecognized argument `" .. tostring(what) .. "`", 2)
    end
    print(help_table(0, help))
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

-- Legacy Methods and Functions ------------------------------------------

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
---  * This is the legacy canvas constructor, provided for backwards compatibility. When including a canvas with other `hs._asm.uitk.element` objects, use [hs._asm.uitk.element.canvas.newCanvas](#newCanvas) and include it in a container element along with the others.
---
---  * The size of the canvas defines the visible area of the canvas -- any portion of a canvas element which extends past the canvas's edges will be clipped.
---  * a rect-table is a table with key-value pairs specifying the top-left coordinate on the screen for the canvas (keys `x`  and `y`) and the size (keys `h` and `w`) of the canvas. The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
module.new = function(...)
    local styleMask = uitk.window.masks.borderless
    local canvasWin = uitk.window.new(..., styleMask)

    if canvasWin then
        canvasWin:backgroundColor{ alpha = 0, white = 0 }
                 :opaque(false)
                 :hasShadow(false)
                 :ignoresMouseEvents(true)
                 :animationBehavior("none")
                 :level("screenSaver")
--                  :accessibilitySubrole(:"+.Hammerspoon")
        local bounds = canvasWin:frame()
        bounds.x, bounds.y = 0, 0
        local canvasView = module.newCanvas(bounds)
        if canvasView then
            canvasWin:content(canvasView)
            -- keep window as uservalue so it's not collected until canvas is
            return canvasView:_wrappedWindow(canvasWin)
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

moduleMT._accessibilitySubrole = function(...)
    if not accessibilityWarningIssued then
        accessibilityWarningIssued = true
        print("*** _accessibilitySubrole is now a no-op -- all accessibility subroles are now left untouched as per Apple guidelines.")
    end
end

--- hs._asm.uitk.element.canvas:frame([rect]) -> canvasWindowObject | currentValue | nil
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
---  * This method is provided for use with the legacy canvas constructor and is provided for backwards compatibility. When used with a canvas object embedded in an `hs._asm.uitk` element container, this method only sets or returns the canvas's size -- you should use the container's methods for determining or setting the canvas's location.
---
---  * a rect-table is a table with key-value pairs specifying the new top-left coordinate on the screen of the canvas (keys `x`  and `y`) and the new size (keys `h` and `w`).  The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
---
---  * elements in the canvas that have the `absolutePosition` attribute set to false will be moved so that their relative position within the canvas remains the same with respect to the new size.
---  * elements in the canvas that have the `absoluteSize` attribute set to false will be resized so that their relative size with respect to the canvas remains the same with respect to the new size.
moduleMT.frame = function(self, ...)
    local args = table.pack(...)
    local canvasWin = self:_wrappedWindow()

    if canvasWin then
        local result = canvasWin:frame(...)
        return type(result) == "userdata" and self or result
    else
        local result = self:size(...)
        return type(result) == "userdata" and self or { x = 0, y = 0, h = result.h, w = result.w }
    end
end

--- hs._asm.uitk.element.canvas:topLeft([point]) -> canvasWindowObject | currentValue | nil
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
---  * This method is provided for use with the legacy canvas constructor and is provided for backwards compatibility. When used with a canvas object embedded in an `hs._asm.uitk` element container, this method is a no-op -- you should use the container's methods for determining or setting the canvas's location.
---
---  * a point-table is a table with key-value pairs specifying the new top-left coordinate on the screen of the canvas (keys `x`  and `y`). The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
moduleMT.topLeft = function(self, ...)
    local args = table.pack(...)
    local canvasWin = self:_wrappedWindow()

    if canvasWin then
        local result = canvasWin:topLeft(...)
        return type(result) == "userdata" and self or result
    else
        return args.n > 0 and self or { x = 0, y = 0 }
    end
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
---  * This method is provided for use with the legacy canvas constructor and is provided for backwards compatibility. When used with a canvas object embedded in an `hs._asm.uitk` element container, this method is a no-op -- you should use `hs._asm.uitk.window` methods to adjust window levels.
---
---  * If the canvas object and window2 are not at the same presentation level, this method will move the canvas object as close to the desired relationship as possible without changing the canvas object's presentation level. See [hs._asm.uitk.element.canvas.level](#level).
moduleMT.orderAbove = function(self, ...)
    local canvasWin = self:_wrappedWindow()

    if canvasWin then canvasWin:orderAbove(...) end
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
---  * This method is provided for use with the legacy canvas constructor and is provided for backwards compatibility. When used with a canvas object embedded in an `hs._asm.uitk` element container, this method is a no-op -- you should use `hs._asm.uitk.window` methods to adjust window levels.
---
---  * If the canvas object and window2 are not at the same presentation level, this method will move the canvas object as close to the desired relationship as possible without changing the canvas object's presentation level. See [hs._asm.uitk.element.canvas.level](#level).
moduleMT.orderBelow = function(self, ...)
    local canvasWin = self:_wrappedWindow()

    if canvasWin then canvasWin:orderBelow(...) end
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
---  * This method is provided for use with the legacy canvas constructor and is provided for backwards compatibility. When used with a canvas object embedded in an `hs._asm.uitk` element container, this method is a no-op -- you should use `hs._asm.uitk.window` methods to adjust window levels.
---
---  * As of macOS Sierra and later, if you want a `hs._asm.uitk.element.canvas` window object to appear above full-screen windows you must hide the Hammerspoon Dock icon first using: `hs.dockicon.hide()`
moduleMT.bringToFront = function(self, ...)
    local args = table.pack(...)
    local canvasWin = self:_wrappedWindow()

    if canvasWin then
        if args.n == 0 then
            canvasWin:level("floating")
        elseif args.n == 1 and type(args[1]) == "boolean" then
            canvasWin:level(args[1] and "screenSaver" or "floating")
        elseif args.n == 1 then
            error(string.format("incorrect type '%s' for argument 1 (expected boolean)", type(args[1])), 3)
        else
            error(string.format("incorrect number of arguments. Expected 1, got %d", args.n), 3)
        end
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
---
--- Notes:
---  * This method is provided for use with the legacy canvas constructor and is provided for backwards compatibility. When used with a canvas object embedded in an `hs._asm.uitk` element container, this method is a no-op -- you should use `hs._asm.uitk.window` methods to adjust window levels.
moduleMT.sendToBack = function(self, ...)
    local args = table.pack(...)
    local canvasWin = self:_wrappedWindow()

    if canvasWin then
        if args.n == 0 then
            canvasWin:level(module.windowLevels.desktopIcon - 1)
        else
            error(string.format("incorrect number of arguments. Expected 0, got %d", args.n), 3)
        end
    end
    return self
end

--- hs._asm.uitk.element.canvas:clickActivating([flag]) -> canvasWindowObject | currentValue
--- Method
--- Get or set whether or not clicking on a legacy canvas window with a click callback defined should bring all of Hammerspoon's open windows to the front.
---
--- Parameters:
---  * `flag` - an optional boolean indicating whether or not clicking on a canvas with a click callback function defined should activate Hammerspoon and bring its windows forward. Defaults to true.
---
--- Returns:
---  * If an argument is provided, returns the canvas object; otherwise returns the current setting.
---
--- Notes:
---  * This method is provided for use with the legacy canvas constructor and is provided for backwards compatibility. When used with a canvas object embedded in an `hs._asm.uitk` element container, this method is a no-op -- you should use `hs._asm.uitk.window` methods.
---
---  * Setting this to false changes a canvas object's AXsubrole value and may affect the results of filters used with `hs.window.filter`, depending upon how they are defined.
moduleMT.clickActivating = function(self, ...)
    local args = table.pack(...)
    local canvasWin = self:_wrappedWindow()

    if canvasWin then
        local masks = canvasWin:styleMask()
        if args.n == 0 then
            return (masks & uitk.window.masks.nonactivating) == uitk.window.masks.nonactivating
        elseif args.n == 1 and type(args[1]) == "boolean" then
            if args[1] then
                canvasWin:styleMask(masks & ~uitk.window.masks.nonactivating)
            else
                canvasWin:styleMask(masks | uitk.window.masks.nonactivating)
            end
        elseif args.n == 1 then
            error(string.format("incorrect type '%s' for argument 1 (expected boolean)", type(args[1])), 3)
        else
            error(string.format("incorrect number of arguments. Expected 1, got %d", args.n), 3)
        end
        return self
    else
        return args.n > 0 and self or nil
    end
end

--- hs._asm.uitk.element.canvas:level([level]) -> canvasWindowObject | currentValue
--- Method
--- Sets the window level more precisely than sendToBack and bringToFront.
---
--- Parameters:
---  * `level` - an optional level, specified as a number or as a string, specifying the new window level for the canvasObject. If it is a string, it must match one of the keys in [hs._asm.uitk.element.canvas.windowLevels](#windowLevels).
---
--- Returns:
---  * If an argument is provided, the canvas object; otherwise the current value.
---
--- Notes:
---  * This method is provided for use with the legacy canvas constructor and is provided for backwards compatibility. When used with a canvas object embedded in an `hs._asm.uitk` element container, this method is a no-op -- you should use `hs._asm.uitk.window` methods.
moduleMT.level = function(self, ...)
    local args = table.pack(...)
    local canvasWin = self:_wrappedWindow()

    if canvasWin then
        local result = canvasWin:level(...)
        return type(result) == "userdata" and self or result
    else
        return args.n > 0 and self or nil
    end
end

--- hs._asm.uitk.element.canvas:behavior([behavior]) -> canvasWindowObject | currentValue
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
---
--- Notes:
---  * This method is provided for use with the legacy canvas constructor and is provided for backwards compatibility. When used with a canvas object embedded in an `hs._asm.uitk` element container, this method is a no-op -- you should use `hs._asm.uitk.window` methods.
moduleMT.behavior = function(self, ...)
    local args = table.pack(...)
    local canvasWin = self:_wrappedWindow()

    if canvasWin then
        local result = canvasWin:collectionBehavior(...)
        return type(result) == "userdata" and self or result
    else
        return args.n > 0 and self or nil
    end
end

--- hs._asm.uitk.element.canvas:behaviorAsLabels(behaviorTable) -> canvasWindowObject | currentValue
--- Method
--- Get or set the window behavior settings for the canvas object using labels defined in [hs._asm.uitk.element.canvas.windowBehaviors](#windowBehaviors).
---
--- Parameters:
---  * behaviorTable - an optional table of strings and/or integers specifying the desired window behavior for the canvas object.
---
--- Returns:
---  * If an argument is provided, the canvas object; otherwise the current value as a table of strings.
---
--- Notes:
---  * This method is provided for use with the legacy canvas constructor and is provided for backwards compatibility. When used with a canvas object embedded in an `hs._asm.uitk` element container, this method is a no-op -- you should use `hs._asm.uitk.window` methods.
moduleMT.behaviorAsLabels = function(self, ...)
    local args = table.pack(...)
    local canvasWin = self:_wrappedWindow()

    if canvasWin then
        local results = self:behavior(...)

        if args.n == 0 then
            local behaviorNumber = results
            results = {}

            if behaviorNumber ~= 0 then
                for i, v in pairs(module.windowBehaviors) do
                    if type(i) == "string" then
                        if (behaviorNumber & v) > 0 then table.insert(results, i) end
                    end
                end
            else
                table.insert(results, module.windowBehaviors[0])
            end

            return setmetatable(results, { __tostring = function(_)
                table.sort(_)
                return "{ "..table.concat(_, ", ").." }"
            end})
        else
            return self
        end
    else
        return args.n > 0 and self or nil
    end
end

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
    __call = function(self, ...) return self.newCanvas(...) end,
})

