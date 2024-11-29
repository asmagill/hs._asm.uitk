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

--- === hs._asm.uitk.element.image ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.element.turtle"
local uitk         = require("hs._asm.uitk")
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libelement_"))
local color        = uitk.util.color
local inspect      = require("hs.inspect")

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)


-- don't need these directly, just their helpers
require("hs.image")

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
local settings     = require("hs.settings")
local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- borrowed and slightly modified from https://www.calormen.com/jslogo/#; specifically
-- https://github.com/inexorabletash/jslogo/blob/02482525925e399020f23339a0991d98c4f088ff/turtle.js#L129-L152
local betterTurtle = uitk.element.canvas{ h = 45, w = 45 }:appendElements{
    {
        type           = "segments",
        action         = "strokeAndFill",
        strokeColor    = { green = 1 },
        fillColor      = { green = .75, alpha = .25 },
        frame          = { x = 0, y = 0, h = 40, w = 40 },
        strokeWidth    = 2,
        transformation = uitk.util.matrix.translate(22.5, 24.5),
        coordinates    = {
            { x =    0, y =  -20 },
            { x =  2.5, y =  -17 },
            { x =    3, y =  -12 },
            { x =    6, y =  -10 },
            { x =    9, y =  -13 },
            { x =   13, y =  -12 },
            { x =   18, y =   -4 },
            { x =   18, y =    0 },
            { x =   14, y =   -1 },
            { x =   10, y =   -7 },
            { x =    8, y =   -6 },
            { x =   10, y =   -2 },
            { x =    9, y =    3 },
            { x =    6, y =   10 },
            { x =    9, y =   13 },
            { x =    6, y =   15 },
            { x =    3, y =   12 },
            { x =    0, y =   13 },
            { x =   -3, y =   12 },
            { x =   -6, y =   15 },
            { x =   -9, y =   13 },
            { x =   -6, y =   10 },
            { x =   -9, y =    3 },
            { x =  -10, y =   -2 },
            { x =   -8, y =   -6 },
            { x =  -10, y =   -7 },
            { x =  -14, y =   -1 },
            { x =  -18, y =    0 },
            { x =  -18, y =   -4 },
            { x =  -13, y =  -12 },
            { x =   -9, y =  -13 },
            { x =   -6, y =  -10 },
            { x =   -3, y =  -12 },
            { x = -2.5, y =  -17 },
            { x =    0, y =  -20 },
        },
    },
}:imageFromCanvas()

-- Hide the internals from accidental usage
local _wrappedCommands  = module._wrappedCommands
-- module._wrappedCommands = nil

local _unwrappedSynonyms = {
    clearscreen = { "cs" },
    showturtle  = { "st" },
    hideturtle  = { "ht" },
    background  = { "bg" },
    textscreen  = { "ts" },
    fullscreen  = { "fs" },
    splitscreen = { "ss" },
    pencolor    = { "pc" },
--    shownp      = { "shown?" }, -- not a legal lua method name, so will need to catch when converter written
--    pendownp    = { "pendown?" },
}

-- in case I ever write something to import turtle code directly, don't want these to cause it to break immediately
local _nops = {
    wrap          = false, -- boolean indicates whether or not warning has been issued; don't want to spam console
    window        = false,
    fence         = false,
    textscreen    = false,
    fullscreen    = false,
    splitscreen   = false,
    refresh       = false,
    norefresh     = false,
    setpenpattern = true,  -- used in setpen, in case I ever actually implement it, so skip warning
}

local defaultPalette = {
    { "black",   { __luaSkinType = "NSColor", list = "Apple",   name = "Black" }},
    { "blue",    { __luaSkinType = "NSColor", list = "Apple",   name = "Blue" }},
    { "green",   { __luaSkinType = "NSColor", list = "Apple",   name = "Green" }},
    { "cyan",    { __luaSkinType = "NSColor", list = "Apple",   name = "Cyan" }},
    { "red",     { __luaSkinType = "NSColor", list = "Apple",   name = "Red" }},
    { "magenta", { __luaSkinType = "NSColor", list = "Apple",   name = "Magenta" }},
    { "yellow",  { __luaSkinType = "NSColor", list = "Apple",   name = "Yellow" }},
    { "white",   { __luaSkinType = "NSColor", list = "Apple",   name = "White" }},
    { "brown",   { __luaSkinType = "NSColor", list = "Apple",   name = "Brown" }},
    { "tan",     { __luaSkinType = "NSColor", list = "x11",     name = "tan" }},
    { "forest",  { __luaSkinType = "NSColor", list = "x11",     name = "forestgreen" }},
    { "aqua",    { __luaSkinType = "NSColor", list = "Crayons", name = "Aqua" }},
    { "salmon",  { __luaSkinType = "NSColor", list = "Crayons", name = "Salmon" }},
    { "purple",  { __luaSkinType = "NSColor", list = "Apple",   name = "Purple" }},
    { "orange",  { __luaSkinType = "NSColor", list = "Apple",   name = "Orange" }},
    { "gray",    { __luaSkinType = "NSColor", list = "x11",     name = "gray" }},
}

-- pulled from webkit/Source/WebKit/Shared/WebPreferencesDefaultValues.h 2020-05-17
module._fontMap = {
    serif          = "Times",
    ["sans-serif"] = "Helvetica",
    cursive        = "Apple Chancery",
    fantasy        = "Papyrus",
    monospace      = "Courier",
--     pictograph     = "Apple Color Emoji",
}

module._registerDefaultPalette(defaultPalette)
module._registerDefaultPalette = nil
module._registerFontMap(module._fontMap)
module._registerFontMap = nil

local finspect = function(obj)
    return inspect(obj, { newline = " ", indent = "" })
end

-- Public interface ------------------------------------------------------

local _new = module.new
module.new = function(...) return _new(...):_turtleImage(betterTurtle) end

--- hs._asm.uitk.element.turtle:pos() -> table
--- Method
--- Returns the turtle’s current position, as a table containing two numbers, the X and Y coordinates.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table containing the X and Y coordinates of the turtle.
local _pos = moduleMT.pos
moduleMT.pos = function(...)
    local result = _pos(...)
    return setmetatable(result, {
        __tostring = function(_) return string.format("{ %.2f, %.2f }", _[1], _[2]) end
    })
end

--- hs._asm.uitk.element.turtle:pensize() -> turtleViewObject
--- Method
--- Returns a table of two positive integers, specifying the horizontal and vertical thickness of the turtle pen.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table specifying the horizontal and vertical thickness of the turtle pen.
---
--- Notes:
---  * in this implementation the two numbers will always be equal as the macOS uses a single width for determining stroke size.
local _pensize = moduleMT.pensize
moduleMT.pensize = function(...)
    local result = _pensize(...)
    return setmetatable(result, {
        __tostring = function(_) return string.format("{ %.2f, %.2f }", _[1], _[2]) end
    })
end

--- hs._asm.uitk.element.turtle:scrunch() -> table
--- Method
--- Returns a table containing the current X and Y scrunch factors.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table containing the X and Y scrunch factors for the turtle view
local _scrunch = moduleMT.scrunch
moduleMT.scrunch = function(...)
    local result = _scrunch(...)
    return setmetatable(result, {
        __tostring = function(_) return string.format("{ %.2f, %.2f }", _[1], _[2]) end
    })
end

--- hs._asm.uitk.element.turtle:labelsize() -> table
--- Method
--- Returns a table containing the height and width of characters rendered by [hs._asm.uitk.element.turtle:label](#label).
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table containing the width and height of characters.
---
--- Notes:
---  * On most modern machines, font widths are variable for most fonts; as this is not easily calculated unless the specific text to be rendered is known, the height, as specified with [hs._asm.uitk.element.turtle:setlabelheight](#setlabelheight) is returned for both values by this method.
local _labelsize = moduleMT.labelsize
moduleMT.labelsize = function(...)
    local result = _labelsize(...)
    return setmetatable(result, {
        __tostring = function(_) return string.format("{ %.2f, %.2f }", _[1], _[2]) end
    })
end

local __visibleAxes = moduleMT._visibleAxes
moduleMT._visibleAxes = function(...)
    local result = __visibleAxes(...)
    return setmetatable(result, {
        __tostring = function(_)
            return string.format("{ { %.2f, %.2f }, { %.2f, %.2f } }", _[1][1], _[1][2], _[2][1], _[2][2])
        end
    })
end

--- hs._asm.uitk.element.turtle:pencolor() -> int | table
--- Method
--- Get the current pen color, either as a palette index number or as an RGB(A) list, whichever way it was most recently set.
---
--- Parameters:
---  * None
---
--- Returns:
---  * if the background color was most recently set by palette index, returns the integer specifying the index; if it was set as a 3 or 4 value table representing RGB(A) values, the table is returned; otherwise returns a color table as defined in `hs.drawing.color`.
---
--- Notes:
---  * Synonym: `hs._asm.uitk.element.turtle:pc()`
local _pencolor = moduleMT.pencolor
moduleMT.pencolor = function(...)
    local result = _pencolor(...)
    if type(result) == "number" then return result end

    local defaultToString = finspect(result)
    return setmetatable(result, {
        __tostring = function(_)
            if #_ == 3 then
                return string.format("{ %.2f, %.2f, %.2f }", _[1], _[2], _[3])
            elseif #_ == 4 then
                return string.format("{ %.2f, %.2f, %.2f, %.2f }", _[1], _[2], _[3], _[4])
            else
                return defaultToString
            end
        end
    })
end

--- hs._asm.uitk.element.turtle:background() -> int | table
--- Method
--- Get the background color, either as a palette index number or as an RGB(A) list, whichever way it was most recently set.
---
--- Parameters:
---  * None
---
--- Returns:
---  * if the background color was most recently set by palette index, returns the integer specifying the index; if it was set as a 3 or 4 value table representing RGB(A) values, the table is returned; otherwise returns a color table as defined in `hs.drawing.color`.
---
--- Notes:
---  * Synonym: `hs._asm.uitk.element.turtle:bg()`
local _background = moduleMT.background
moduleMT.background = function(...)
    local result = _background(...)
    if type(result) == "number" then return result end

    local defaultToString = finspect(result)
    return setmetatable(result, {
        __tostring = function(_)
            if #_ == 3 then
                return string.format("{ %.2f, %.2f, %.2f }", _[1], _[2], _[3])
            elseif #_ == 4 then
                return string.format("{ %.2f, %.2f, %.2f, %.2f }", _[1], _[2], _[3], _[4])
            else
                return defaultToString
            end
        end
    })
end

--- hs._asm.uitk.element.turtle:palette(index) -> table
--- Method
--- Returns the color defined at the specified palette index.
---
--- Parameters:
---  * `index` - an integer between 0 and 255 specifying the index in the palette of the desired coloe
---
--- Returns:
---  * a table specifying the color as a list of 3 or 4 numbers representing the intensity of the red, green, blue, and optionally alpha channels as a number between 0.0 and 100.0. If the color cannot be represented in RGB(A) format, then a table as described in `hs.drawing.color` is returned.
local _palette = moduleMT.palette
moduleMT.palette = function(...)
    local result = _palette(...)
    local defaultToString = finspect(result)
    return setmetatable(result, {
        __tostring = function(_)
            if #_ == 3 then
                return string.format("{ %.2f, %.2f, %.2f }", _[1], _[2], _[3])
            elseif #_ == 4 then
                return string.format("{ %.2f, %.2f, %.2f, %.2f }", _[1], _[2], _[3], _[4])
            else
                return defaultToString
            end
        end
    })
end

--- hs._asm.uitk.element.turtle:towards(pos) -> number
--- Method
--- Returns the heading at which the turtle should be facing so that it would point from its current position to the position specified.
---
--- Parameters:
---  * `pos` - a position table containing the x and y coordinates as described in [hs._asm.uitk.element.turtle:pos](#pos) of the point the turtle should face.
---
--- Returns:
---  * a number representing the heading the turtle should face to point to the position specified in degrees clockwise from the positive Y axis.
moduleMT.towards = function(self, pos)
    local x, y = pos[1], pos[2]
    assert(type(x) == "number", "expected a number for the x coordinate")
    assert(type(y) == "number", "expected a number for the y coordinate")

    local cpos = self:pos()
    return (90 - math.atan(y - cpos[2],x - cpos[1]) * 180 / math.pi) % 360
end

--- hs._asm.uitk.element.turtle:screenmode() -> string
--- Method
--- Returns a string describing the current screen mode for the turtle view.
---
--- Parameters:
---  * None
---
--- Returns:
---  * "FULLSCREEN"
---
--- Notes:
---  * This method always returns "FULLSCREEN" for compatibility with translated Logo code; since this module only implements `textscreen`, `fullscreen`, and `splitscreen` as no-op methods to simplify conversion, no other return value is possible.
moduleMT.screenmode = function(self, ...) return "FULLSCREEN" end

--- hs._asm.uitk.element.turtle:turtlemode() -> string
--- Method
--- Returns a string describing the current turtle mode for the turtle view.
---
--- Parameters:
---  * None
---
--- Returns:
---  * "WINDOW"
---
--- Notes:
---  * This method always returns "WINDOW" for compatibility with translated Logo code; since this module only implements `window`, `wrap`, and `fence` as no-op methods to simplify conversion, no other return value is possible.
moduleMT.turtlemode = function(self, ...) return "WINDOW" end

--- hs._asm.uitk.element.turtle:pen() -> table
--- Method
--- Returns a table containing the pen’s position, mode, thickness, and hardware-specific characteristics.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table containing the contents of the following as entries:
---    * [hs._asm.uitk.element.turtle:pendownp()](#pendownp)
---    * [hs._asm.uitk.element.turtle:penmode()](#penmode)
---    * [hs._asm.uitk.element.turtle:pensize()](#pensize)
---    * [hs._asm.uitk.element.turtle:pencolor()](#pencolor)
---    * [hs._asm.uitk.element.turtle:penpattern()](#penpattern)
---
--- Notes:
---  * the resulting table is suitable to be used as input to [hs._asm.uitk.element.turtle:setpen](#setpen).
moduleMT.pen = function(self, ...)
    local pendown    = self:pendownp() and "PENDOWN" or "PENUP"
    local penmode    = self:penmode()
    local pensize    = self:pensize()
    local pencolor   = self:pencolor()
    local penpattern = self:penpattern()

    return setmetatable({ pendown, penmode, pensize, pencolor, penpattern }, {
        __tostring = function(_)
            return string.format("{ %s, %s, %s, %s, %s }",
                pendown,
                penmode,
                tostring(pensize),
                tostring(pencolor),
                tostring(penpattern)
            )
        end
    })
end

moduleMT.penpattern = function(self, ...)
    return nil
end

--- hs._asm.uitk.element.turtle:setpen(state) -> turtleViewObject
--- Method
--- Sets the pen’s position, mode, thickness, and hardware-dependent characteristics.
---
--- Parameters:
---  * `state` - a table containing the results of a previous invocation of [hs._asm.uitk.element.turtle:pen](#pen).
---
--- Returns:
---  * the turtleViewObject
moduleMT.setpen = function(self, ...)
    local args = table.pack(...)
    assert(args.n == 1, "setpen: expected only one argument")
    assert(type(args[1]) == "table", "setpen: expected table of pen state values")
    local details = args[1]

    assert(({ penup = true, pendown = true })[details[1]:lower()],               "setpen: invalid penup/down state at index 1")
    assert(({ paint = true, erase = true, reverse = true })[details[2]:lower()], "setpen: invalid penmode state at index 2")
    assert((type(details[3]) == "table") and (#details[3] == 2)
                                         and (type(details[3][1]) == "number")
                                         and (type(details[3][2]) == "number"),  "setpen: invalid pensize table at index 3")
    assert(({ string = true, number = true, table = true })[type(details[4])],   "setpen: invalid pencolor at index 4")
    assert(true,                                                                 "setpen: invalid penpattern at index 5") -- in case I add it

    moduleMT["pen" .. details[2]:lower()](self) -- penpaint, penerase, or penreverse
    moduleMT[details[1]:lower()](self)          -- penup or pendown (has to come after mode since mode sets pendown)
    self:setpensize(details[3])
    self:setpencolor(details[4])
    self:setpenpattern(details[5])              -- its a nop currently, but we're supressing it's output message
    return self
end

-- 6.1 Turtle Motion

--- hs._asm.uitk.element.turtle:forward(dist) -> turtleViewObject
--- Method
--- Moves the turtle forward in the direction that it’s facing, by the specified distance. The heading of the turtle does not change.
---
--- Parameters:
---  * `dist` -  the distance the turtle should move forwards.
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs._asm.uitk.element.turtle:fd(dist)`

--- hs._asm.uitk.element.turtle:back(dist) -> turtleViewObject
--- Method
--- Move the turtle backward, (i.e. opposite to the direction that it's facing) by the specified distance. The heading of the turtle does not change.
---
--- Parameters:
---  * `dist` - the distance the turtle should move backwards.
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs._asm.uitk.element.turtle:bk(dist)`

--- hs._asm.uitk.element.turtle:left(angle) -> turtleViewObject
--- Method
--- Turns the turtle counterclockwise by the specified angle, measured in degrees
---
--- Parameters:
---  * `angle` - the number of degrees to adjust the turtle's heading counterclockwise.
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs._asm.uitk.element.turtle:lt(angle)`

--- hs._asm.uitk.element.turtle:right(angle) -> turtleViewObject
--- Method
--- Turns the turtle clockwise by the specified angle, measured in degrees
---
--- Parameters:
---  * `angle` - the number of degrees to adjust the turtle's heading clockwise.
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs._asm.uitk.element.turtle:rt(angle)`

--- hs._asm.uitk.element.turtle:setpos(pos) -> turtleViewObject
--- Method
--- Moves the turtle to an absolute position in the graphics window. Does not change the turtle's heading.
---
--- Parameters:
---  * `pos` - a table containing two numbers specifying the `x` and the `y` position within the turtle view to move the turtle to. (Note that this is *not* a point table with key-value pairs).
---
--- Returns:
---  * the turtleViewObject

--- hs._asm.uitk.element.turtle:setxy(x, y) -> turtleViewObject
--- Method
--- Moves the turtle to an absolute position in the graphics window. Does not change the turtle's heading.
---
--- Parameters:
---  * `x` - the x coordinate of the turtle's new position within the turtle view
---  * `y` - the y coordinate of the turtle's new position within the turtle view
---
--- Returns:
---  * the turtleViewObject

--- hs._asm.uitk.element.turtle:setx(x) -> turtleViewObject
--- Method
--- Moves the turtle horizontally from its old position to a new absolute horizontal coordinate. Does not change the turtle's heading.
---
--- Parameters:
---  * `x` - the x coordinate of the turtle's new position within the turtle view
---
--- Returns:
---  * the turtleViewObject

--- hs._asm.uitk.element.turtle:sety(y) -> turtleViewObject
--- Method
--- Moves the turtle vertically from its old position to a new absolute vertical coordinate. Does not change the turtle's heading.
---
--- Parameters:
---  * `y` - the y coordinate of the turtle's new position within the turtle view
---
--- Returns:
---  * the turtleViewObject

--- hs._asm.uitk.element.turtle:setheading(angle) -> turtleViewObject
--- Method
--- Sets the heading of the turtle to a new absolute heading.
---
--- Parameters:
---  * `angle` - The heading, in degrees clockwise from the positive Y axis, of the new turtle heading.
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs._asm.uitk.element.turtle:seth(angle)`

--- hs._asm.uitk.element.turtle:home() -> turtleViewObject
--- Method
--- Moves the turtle to the center of the turtle view.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * this is equivalent to `hs._asm.uitk.element.turtle:setxy(0, 0):setheading(0)`.
---    * this does not change the pen state, so if the pen is currently down, a line may be drawn from the previous position to the home position.

--- hs._asm.uitk.element.turtle:arc(angle, radius) -> turtleViewObject
--- Method
--- Draws an arc of a circle, with the turtle at the center, with the specified radius, starting at the turtle’s heading and extending clockwise through the specified angle. The turtle does not move.
---
--- Parameters:
---  * `angle` - the number of degrees the arc should extend from the turtle's current heading. Positive numbers indicate that the arc should extend in a clockwise direction, negative numbers extend in a counter-clockwise direction.
---  * `radius` - the distance from the turtle's current position that the arc should be drawn.
---
--- Returns:
---  * the turtleViewObject


-- 6.2 Turtle Motion Queries

-- pos     - documented where defined
-- xcor    - documented where defined
-- ycor    - documented where defined
-- heading - documented where defined
-- towards - documented where defined
-- scrunch - documented where defined


-- 6.3 Turtle and Window Control

--- hs._asm.uitk.element.turtle:label(text) -> turtleViewObject
--- Method
--- Displays a string at the turtle’s position current position in the current pen mode and color.
---
--- Parameters:
---  * `text` -
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * does not move the turtle

--- hs._asm.uitk.element.turtle:setlabelheight(height) -> turtleViewObject
--- Method
--- Sets the font size for text displayed with the [hs._asm.uitk.element.turtle:label](#label) method.
---
--- Parameters:
---  * `height` - a number specifying the font size
---
--- Returns:
---  * the turtleViewObject

--- hs._asm.uitk.element.turtle:setscrunch(xscale, yscale) -> turtleViewObject
--- Method
--- Adjusts the aspect ratio and scaling within the turtle view. Further turtle motion will be adjusted by multiplying the horizontal and vertical extent of the motion by the two numbers given as inputs.
---
--- Parameters:
---  * `xscale` - a number specifying the horizontal scaling applied to the turtle position
---  * `yscale` - a number specifying the vertical scaling applied to the turtle position
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * On old CRT monitors, it was common that pixels were not exactly square and this method could be used to compensate. Now it is more commonly used to create scaling effects.

-- showturtle     - documented where defined
-- hideturtle     - documented where defined
-- clean          - documented where defined
-- clearscreen    - documented where defined
-- wrap           - no-op -- implemented, but does nothing to simplify conversion to/from logo
-- window         - no-op -- implemented, but does nothing to simplify conversion to/from logo
-- fence          - no-op -- implemented, but does nothing to simplify conversion to/from logo
-- fill           - not implemented at present
-- filled         - not implemented at present; a similar effect can be had with `:fillStart()` and `:fillEnd()`
-- textscreen     - no-op -- implemented, but does nothing to simplify conversion to/from logo
-- fullscreen     - no-op -- implemented, but does nothing to simplify conversion to/from logo
-- splitscreen    - no-op -- implemented, but does nothing to simplify conversion to/from logo
-- refresh        - no-op -- implemented, but does nothing to simplify conversion to/from logo
-- norefresh      - no-op -- implemented, but does nothing to simplify conversion to/from logo


-- 6.4 Turtle and Window Queries

-- shownp     - documented where defined
-- screenmode - documented where defined
-- turtlemode - documented where defined
-- labelsize  - documented where defined

-- 6.5 Pen and Background Control

--- hs._asm.uitk.element.turtle:pendown() -> turtleViewObject
--- Method
--- Sets the pen’s position to down so that movement methods will draw lines in the turtle view.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs._asm.uitk.element.turtle:pd()`

--- hs._asm.uitk.element.turtle:penup() -> turtleViewObject
--- Method
--- Sets the pen’s position to up so that movement methods do not draw lines in the turtle view.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs._asm.uitk.element.turtle:pu()`

--- hs._asm.uitk.element.turtle:penpaint() -> turtleViewObject
--- Method
--- Sets the pen’s position to DOWN and mode to PAINT.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs._asm.uitk.element.turtle:ppt()`
---
---  * this mode is equivalent to `hs.uitk.element.canvas.compositeTypes.sourceOver`

--- hs._asm.uitk.element.turtle:penerase() -> turtleViewObject
--- Method
--- Sets the pen’s position to DOWN and mode to ERASE.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs._asm.uitk.element.turtle:pe()`
---
---  * this mode is equivalent to `hs.uitk.element.canvas.compositeTypes.destinationOut`

--- hs._asm.uitk.element.turtle:penreverse() -> turtleViewObject
--- Method
--- Sets the pen’s position to DOWN and mode to REVERSE.
---
--- Parameters:
---  * None
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs._asm.uitk.element.turtle:px()`
---
---  * this mode is equivalent to `hs.uitk.element.canvas.compositeTypes.XOR`

--- hs._asm.uitk.element.turtle:setpencolor(color) -> turtleViewObject
--- Method
--- Sets the pen color (the color the turtle draws when it moves and the pen is down).
---
--- Parameters:
---  * `color` - one of the following types:
---    * an integer greater than or equal to 0 specifying an entry in the color palette (see [hs._asm.uitk.element.turtle:setpalette](#setpalette)). If the index is outside of the defined palette, defaults to black (index entry 0).
---    * a string matching one of the names of the predefined colors as described in [hs._asm.uitk.element.turtle:setpalette](#setpalette).
---    * a string starting with "#" followed by 6 hexadecimal digits specifying a color in the HTML style.
---    * a table of 3 or 4 numbers between 0.0 and 100.0 specifying the percent saturation of red, green, blue, and optionally the alpha channel.
---    * a color as defined in `hs.drawing.color`
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs._asm.uitk.element.turtle:setpc(color)`

--- hs._asm.uitk.element.turtle:setpalette(index, color) -> turtleViewObject
--- Method
--- Assigns the color to the palette at the given index.
---
--- Parameters:
---  * `index` - an integer between 8 and 255 inclusive specifying the slot within the palette to assign the specified color.
---  * `color` - one of the following types:
---    * an integer greater than or equal to 0 specifying an entry in the color palette (see Notes). If the index is outside the range of the defined palette, defaults to black (index entry 0).
---    * a string matching one of the names of the predefined colors as described in the Notes.
---    * a string starting with "#" followed by 6 hexadecimal digits specifying a color in the HTML style.
---    * a table of 3 or 4 numbers between 0.0 and 100.0 specifying the percent saturation of red, green, blue, and optionally the alpha channel.
---    * a color as defined in `hs.drawing.color`
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Attempting to modify color with an index of 0-7 are silently ignored.
---
---  * An assigned color has no label for use when doing a string match with [hs._asm.uitk.element.turtle:setpencolor](#setpencolor) or [hs._asm.uitk.element.turtle:setbackground](#setbackground). Changing the assigned color to indexes 8-15 will clear the default label.
---
---  * The initial palette is defined as follows:
---    *  0 - "black"    1 - "blue"      2 - "green"    3 - "cyan"
---    *  4 - "red"      5 - "magenta"   6 - "yellow"   7 - "white"
---    *  8 - "brown"    9 - "tan"      10 - "forest"  11 - "aqua"
---    * 12 - "salmon"  13 - "purple"   14 - "orange"  15 - "gray"

--- hs._asm.uitk.element.turtle:setpensize(size) -> turtleViewObject
--- Method
--- Sets the thickness of the pen.
---
--- Parameters:
---  * `size` - a number or table of two numbers (for horizontal and vertical thickness) specifying the size of the turtle's pen.
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
--- * this method accepts two numbers for compatibility reasons - macOS uses a square pen for drawing.

--- hs._asm.uitk.element.turtle:setbackground(color) -> turtleViewObject
--- Method
--- Sets the turtle view background color.
---
--- Parameters:
---  * `color` - one of the following types:
---    * an integer greater than or equal to 0 specifying an entry in the color palette (see [hs._asm.uitk.element.turtle:setpalette](#setpalette)). If the index is outside of the defined palette, defaults to black (index entry 0).
---    * a string matching one of the names of the predefined colors as described in [hs._asm.uitk.element.turtle:setpalette](#setpalette).
---    * a string starting with "#" followed by 6 hexadecimal digits specifying a color in the HTML style.
---    * a table of 3 or 4 numbers between 0.0 and 100.0 specifying the percent saturation of red, green, blue, and optionally the alpha channel.
---    * a color as defined in `hs.drawing.color`
---
--- Returns:
---  * the turtleViewObject
---
--- Notes:
---  * Synonym: `hs._asm.uitk.element.turtle:setbg(...)`

-- setpenpattern - no-op -- implemented, but does nothing to simplify conversion to/from logo
-- setpen        - documented where defined


-- 6.6 Pen Queries

-- pendownp   - documented where defined
-- penmode    - documented where defined
-- pencolor   - documented where defined
-- palette    - documented where defined
-- pensize    - documented where defined
-- penpattern - no-op -- implemented to simplify pen and setpen, but returns nil
-- pen        - documented where defined
-- background - documented where defined


-- 6.7 Saving and Loading Pictures

-- savepict - not implemented at present
-- loadpict - not implemented at present
-- epspict  - not implemented at present; a similar function can be found with `:_image()`


-- 6.8 Mouse Queries

-- mousepos - not implemented at present
-- clickpos - not implemented at present
-- buttonp  - not implemented at present
-- button   - not implemented at present


-- Others (unique to this module)

-- _image
-- _translate
-- _visibleAxes

-- _turtleImage
-- _turtleSize

-- fillend
-- fillstart
-- labelfont
-- setlabelfont

-- Internal use only, no need to fully document at present
--   _appendCommand -- internal command to add turtle moves
--   _cmdCount
--   _commandDump
--   _dumpPalette

-- _fontMap = {...},
-- new

for i, v in ipairs(_wrappedCommands) do
    local cmdLabel, cmdNumber = v[1], i - 1
--     local synonyms = v[2] or {}

    if not cmdLabel:match("^_") then
        if not moduleMT[cmdLabel] then
            -- this needs "special" help not worth changing the validation code in internal.m for
            if cmdLabel == "setpensize" then
                moduleMT[cmdLabel] = function(self, ...)
                    local args = table.pack(...)
                    if type(args[1]) ~= "table" then args[1] = { args[1], args[1] } end
                    local status, result = pcall(self._appendCommand, self, cmdNumber, table.unpack(args))
                    if not status or type(result) == "string" then
                        error(result, 3) ;
                    end
                    return result
                end
            else
                moduleMT[cmdLabel] = function(self, ...)
                    local status, result = pcall(self._appendCommand, self, cmdNumber, ...)
                    if not status or type(result) == "string" then
                        error(result, 3) ;
                    end
                    return result
                end
            end
        else
            log.wf("%s - method already defined; can't wrap", cmdLabel)
        end
    end
end

for k, v in pairs(_nops) do
    if not moduleMT[k] then
        moduleMT[k] = function(self, ...)
            if not _nops[k] then
                log.f("%s - method is a nop and has no effect for this implemntation", k)
                _nops[k] = true
            end
            return self
        end
    else
        log.wf("%s - method already defined; can't assign as nop", k)
    end
end

moduleMT.__indexLookup = moduleMT.__index
moduleMT.__index = function(self, key)
    -- handle the methods as they are defined
    if moduleMT.__indexLookup[key] then return moduleMT.__indexLookup[key] end
    -- no "logo like" command will start with an underscore
    if key:match("^_") then return nil end

    -- all logo commands are defined as lowercase, so convert the passed in key to lower case and...
    local lcKey = key:lower()

    -- check against the defined logo methods again
    if moduleMT.__indexLookup[lcKey] then return moduleMT.__indexLookup[lcKey] end

    -- check against the synonyms for the defined logo methods that wrap _appendCommand
    for i,v in ipairs(_wrappedCommands) do
        if lcKey == v[1] then return moduleMT.__indexLookup[v[1]] end
        for i2, v2 in ipairs(v[2]) do
            if lcKey == v2 then return moduleMT.__indexLookup[v[1]] end
        end
    end

    -- check against the synonyms for the defined logo methods that are defined explicitly
    for k,v in pairs(_unwrappedSynonyms) do
        for i2, v2 in ipairs(v) do
            if lcKey == v2 then return moduleMT.__indexLookup[k] end
        end
    end

    return nil -- not really necessary as none is interpreted as nil, but I like to be explicit
end

-- Return Module Object --------------------------------------------------

return module
