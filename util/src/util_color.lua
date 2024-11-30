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

--- === hs._asm.uitk.util.color ===
---
--- Provides access to the system color lists and a wider variety of ways to represent color within Hammerspoon.
---
--- Color is represented within Hammerspoon as a table containing keys which tell Hammerspoon how the color is specified.  You can specify a color in one of the following ways, depending upon the keys you supply within the table:
---
--- * As a combination of Red, Green, and Blue elements (RGB Color):
---   * red   - the red component of the color specified as a number from 0.0 to 1.0.
---   * green - the green component of the color specified as a number from 0.0 to 1.0.
---   * blue  - the blue component of the color specified as a number from 0.0 to 1.0.
---   * alpha - the color transparency from 0.0 (completely transparent) to 1.0 (completely opaque)
---
--- * As a combination of Hue, Saturation, and Brightness (HSB or HSV Color):
---   * hue        - the hue component of the color specified as a number from 0.0 to 1.0.
---   * saturation - the saturation component of the color specified as a number from 0.0 to 1.0.
---   * brightness - the brightness component of the color specified as a number from 0.0 to 1.0.
---   * alpha      - the color transparency from 0.0 (completely transparent) to 1.0 (completely opaque)
---
--- * As grayscale (Grayscale Color):
---   * white - the ratio of white to black from 0.0 (completely black) to 1.0 (completely white)
---   * alpha - the color transparency from 0.0 (completely transparent) to 1.0 (completely opaque)
---
--- * From the system or Hammerspoon color lists:
---   * list - the name of a system color list or a collection list defined in `hs._asm.uitk.util.color`
---   * name - the color name within the specified color list
---
--- * As an HTML style hex color specification:
---   * hex   - a string of the format "#rrggbb" or "#rgb" where `r`, `g`, and `b` are hexadecimal digits (i.e. 0-9, A-F)
---   * alpha - the color transparency from 0.0 (completely transparent) to 1.0 (completely opaque)
---
--- * From an image to be used as a tiled pattern:
---   * image - an `hs.image` object representing the image to be used as a tiled pattern
---
--- Any combination of the above keys may be specified within the color table and they will be evaluated in the following order:
---   1. if the `image` key is specified, it will be used to create a tiling pattern.
---   2. If the `list` and `name` keys are specified, and if they can be matched to an existing color within the system color lists, that color is used.
---   3. If the `hue` key is provided, then the color is generated as an HSB color
---   4. If the `white` key is provided, then the color is generated as a Grayscale color
---   5. Otherwise, an RGB color is generated.
---
--- Except where specified above to indicate the color model being used, any key which is not provided defaults to a value of 0.0, except for `alpha`, which defaults to 1.0.  This means that specifying an empty table as the color will result in an opaque black color.

--- === hs._asm.uitk.util.color.list ===
---
--- Provides support for color lists. Color lists are a collection of colors that can be saved and loaded as needed. In addition, you can create lists which you wish to make available to the color panel and outside of Hammerspoon by saving your created lists in the users custom color directory. See [hs._asm.uitk.util.color.list:saveList](#saveList) for more information.
---
--- The users personal colorlist directory is located at `~/Library/Colors`; colorlists saved here can be used by all macOS applications, not just Hammerspoon. See [hs._asm.uitk.util.color.lists:saveList](#saveList) for more information.

local USERDATA_TAG = "hs._asm.uitk.util.color"
local uitk         = require("hs._asm.uitk")
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libutil_"))

local colorlistMT  = hs.getObjectMetatable(USERDATA_TAG .. ".list")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

local _colorList_index = colorlistMT.__index
colorlistMT.__index = function(self, key)
    local result = _colorList_index[key]
    if not result and type(key) == "string" then
        result = self:colorNamed(key)
    end
    return result
end

colorlistMT.__newindex = function(self, key, value)
    if not _colorList_index[key] then
        if type(key) == "string" and (type(value) == "table" or type(value) == "nil") then
            self:colorNamed(key, value)
        end
    end
end

colorlistMT.__len = function(self) return 0 end

colorlistMT.__pairs = function(self)
    local keys = self:colorNames()

    return function(_, k)
        local v = nil
        k = table.remove(keys)
        if k then v = self[k] end
        return k, v
    end, self, nil
end

--- hs._asm.uitk.util.color.ansiTerminalColors
--- Variable
--- A collection of colors representing the ANSI Terminal color sequences.  The color definitions are based upon code found at https://github.com/balthamos/geektool-3 in the /NerdTool/classes/ANSIEscapeHelper.m file.
---
--- Notes:
---  * This is not a constant, so you can adjust the colors at run time for your installation if desired.
---  * This is actually an `hs._asm.uitk.util.color.list` object, but you can access it as if it were a table of key-value pairs.
local ansiTerminalColors = module.list.listNamed("ansiTerminalColors")
if not ansiTerminalColors then
    ansiTerminalColors = module.list.listNamed("ansiTerminalColors", true)
    for k, v in pairs({
        fgBlack         = { list = "Apple", name = "Black" },
        fgRed           = { list = "Apple", name = "Red" },
        fgGreen         = { list = "Apple", name = "Green" },
        fgYellow        = { list = "Apple", name = "Yellow" },
        fgBlue          = { list = "Apple", name = "Blue" },
        fgMagenta       = { list = "Apple", name = "Magenta" },
        fgCyan          = { list = "Apple", name = "Cyan" },
        fgWhite         = { list = "Apple", name = "White" },
        fgBrightBlack   = { white = 0.337, alpha = 1 },
        fgBrightRed     = { hue = 1,     saturation = 0.4, brightness = 1, alpha = 1},
        fgBrightGreen   = { hue = 1/3,   saturation = 0.4, brightness = 1, alpha = 1},
        fgBrightYellow  = { hue = 1/6,   saturation = 0.4, brightness = 1, alpha = 1},
        fgBrightBlue    = { hue = 2/3,   saturation = 0.4, brightness = 1, alpha = 1},
        fgBrightMagenta = { hue = 5/6,   saturation = 0.4, brightness = 1, alpha = 1},
        fgBrightCyan    = { hue = 0.5,   saturation = 0.4, brightness = 1, alpha = 1},
        fgBrightWhite   = { list = "Apple", name = "White" },
        bgBlack         = { list = "Apple", name = "Black" },
        bgRed           = { list = "Apple", name = "Red" },
        bgGreen         = { list = "Apple", name = "Green" },
        bgYellow        = { list = "Apple", name = "Yellow" },
        bgBlue          = { list = "Apple", name = "Blue" },
        bgMagenta       = { list = "Apple", name = "Magenta" },
        bgCyan          = { list = "Apple", name = "Cyan" },
        bgWhite         = { list = "Apple", name = "White" },
        bgBrightBlack   = { white = 0.337, alpha = 1 },
        bgBrightRed     = { hue = 1,     saturation = 0.4, brightness = 1, alpha = 1},
        bgBrightGreen   = { hue = 1/3,   saturation = 0.4, brightness = 1, alpha = 1},
        bgBrightYellow  = { hue = 1/6,   saturation = 0.4, brightness = 1, alpha = 1},
        bgBrightBlue    = { hue = 2/3,   saturation = 0.4, brightness = 1, alpha = 1},
        bgBrightMagenta = { hue = 5/6,   saturation = 0.4, brightness = 1, alpha = 1},
        bgBrightCyan    = { hue = 0.5,   saturation = 0.4, brightness = 1, alpha = 1},
        bgBrightWhite   = { list = "Apple", name = "White" },
    }) do ansiTerminalColors[k] = v end
end
module.ansiTerminalColors = ansiTerminalColors

--- hs._asm.uitk.util.color.x11
--- Variable
--- A collection of colors representing the X11 color names as defined at  https://en.wikipedia.org/wiki/Web_colors#X11_color_names (names in lowercase)
---
--- Notes:
---  * This is not a constant, so you can adjust the colors at run time for your installation if desired.
---  * This is actually an `hs._asm.uitk.util.color.list` object, but you can access it as if it were a table of key-value pairs.
local x11 = module.list.listNamed("x11")
if not x11 then
    x11 = module.list.listNamed("x11", true)
    for k, v in pairs({
    -- Pink colors
        ["pink"]              = { ["red"]=1.000,["green"]=0.753,["blue"]=0.796,["alpha"]=1 },
        ["lightpink"]         = { ["red"]=1.000,["green"]=0.714,["blue"]=0.757,["alpha"]=1 },
        ["hotpink"]           = { ["red"]=1.000,["green"]=0.412,["blue"]=0.706,["alpha"]=1 },
        ["deeppink"]          = { ["red"]=1.000,["green"]=0.078,["blue"]=0.576,["alpha"]=1 },
        ["palevioletred"]     = { ["red"]=0.859,["green"]=0.439,["blue"]=0.576,["alpha"]=1 },
        ["mediumvioletred"]   = { ["red"]=0.780,["green"]=0.082,["blue"]=0.522,["alpha"]=1 },
    -- Red colors
        ["lightsalmon"]       = { ["red"]=1.000,["green"]=0.627,["blue"]=0.478,["alpha"]=1 },
        ["salmon"]            = { ["red"]=0.980,["green"]=0.502,["blue"]=0.447,["alpha"]=1 },
        ["darksalmon"]        = { ["red"]=0.914,["green"]=0.588,["blue"]=0.478,["alpha"]=1 },
        ["lightcoral"]        = { ["red"]=0.941,["green"]=0.502,["blue"]=0.502,["alpha"]=1 },
        ["indianred"]         = { ["red"]=0.804,["green"]=0.361,["blue"]=0.361,["alpha"]=1 },
        ["crimson"]           = { ["red"]=0.863,["green"]=0.078,["blue"]=0.235,["alpha"]=1 },
        ["firebrick"]         = { ["red"]=0.698,["green"]=0.133,["blue"]=0.133,["alpha"]=1 },
        ["darkred"]           = { ["red"]=0.545,["green"]=0.000,["blue"]=0.000,["alpha"]=1 },
        ["red"]               = { ["red"]=1.000,["green"]=0.000,["blue"]=0.000,["alpha"]=1 },
    -- Orange colors
        ["orangered"]         = { ["red"]=1.000,["green"]=0.271,["blue"]=0.000,["alpha"]=1 },
        ["tomato"]            = { ["red"]=1.000,["green"]=0.388,["blue"]=0.278,["alpha"]=1 },
        ["coral"]             = { ["red"]=1.000,["green"]=0.498,["blue"]=0.314,["alpha"]=1 },
        ["darkorange"]        = { ["red"]=1.000,["green"]=0.549,["blue"]=0.000,["alpha"]=1 },
        ["orange"]            = { ["red"]=1.000,["green"]=0.647,["blue"]=0.000,["alpha"]=1 },
    -- Yellow colors
        ["yellow"]            = { ["red"]=1.000,["green"]=1.000,["blue"]=0.000,["alpha"]=1 },
        ["lightyellow"]       = { ["red"]=1.000,["green"]=1.000,["blue"]=0.878,["alpha"]=1 },
        ["lemonchiffon"]      = { ["red"]=1.000,["green"]=0.980,["blue"]=0.804,["alpha"]=1 },
        ["papayawhip"]        = { ["red"]=1.000,["green"]=0.937,["blue"]=0.835,["alpha"]=1 },
        ["moccasin"]          = { ["red"]=1.000,["green"]=0.894,["blue"]=0.710,["alpha"]=1 },
        ["peachpuff"]         = { ["red"]=1.000,["green"]=0.855,["blue"]=0.725,["alpha"]=1 },
        ["palegoldenrod"]     = { ["red"]=0.933,["green"]=0.910,["blue"]=0.667,["alpha"]=1 },
        ["khaki"]             = { ["red"]=0.941,["green"]=0.902,["blue"]=0.549,["alpha"]=1 },
        ["darkkhaki"]         = { ["red"]=0.741,["green"]=0.718,["blue"]=0.420,["alpha"]=1 },
        ["gold"]              = { ["red"]=1.000,["green"]=0.843,["blue"]=0.000,["alpha"]=1 },
    -- Brown colors
        ["cornsilk"]          = { ["red"]=1.000,["green"]=0.973,["blue"]=0.863,["alpha"]=1 },
        ["blanchedalmond"]    = { ["red"]=1.000,["green"]=0.922,["blue"]=0.804,["alpha"]=1 },
        ["bisque"]            = { ["red"]=1.000,["green"]=0.894,["blue"]=0.769,["alpha"]=1 },
        ["navajowhite"]       = { ["red"]=1.000,["green"]=0.871,["blue"]=0.678,["alpha"]=1 },
        ["wheat"]             = { ["red"]=0.961,["green"]=0.871,["blue"]=0.702,["alpha"]=1 },
        ["burlywood"]         = { ["red"]=0.871,["green"]=0.722,["blue"]=0.529,["alpha"]=1 },
        ["tan"]               = { ["red"]=0.824,["green"]=0.706,["blue"]=0.549,["alpha"]=1 },
        ["rosybrown"]         = { ["red"]=0.737,["green"]=0.561,["blue"]=0.561,["alpha"]=1 },
        ["sandybrown"]        = { ["red"]=0.957,["green"]=0.643,["blue"]=0.376,["alpha"]=1 },
        ["goldenrod"]         = { ["red"]=0.855,["green"]=0.647,["blue"]=0.125,["alpha"]=1 },
        ["darkgoldenrod"]     = { ["red"]=0.722,["green"]=0.525,["blue"]=0.043,["alpha"]=1 },
        ["peru"]              = { ["red"]=0.804,["green"]=0.522,["blue"]=0.247,["alpha"]=1 },
        ["chocolate"]         = { ["red"]=0.824,["green"]=0.412,["blue"]=0.118,["alpha"]=1 },
        ["saddlebrown"]       = { ["red"]=0.545,["green"]=0.271,["blue"]=0.075,["alpha"]=1 },
        ["sienna"]            = { ["red"]=0.627,["green"]=0.322,["blue"]=0.176,["alpha"]=1 },
        ["brown"]             = { ["red"]=0.647,["green"]=0.165,["blue"]=0.165,["alpha"]=1 },
        ["maroon"]            = { ["red"]=0.502,["green"]=0.000,["blue"]=0.000,["alpha"]=1 },
    -- Green colors
        ["darkolivegreen"]    = { ["red"]=0.333,["green"]=0.420,["blue"]=0.184,["alpha"]=1 },
        ["olive"]             = { ["red"]=0.502,["green"]=0.502,["blue"]=0.000,["alpha"]=1 },
        ["olivedrab"]         = { ["red"]=0.420,["green"]=0.557,["blue"]=0.137,["alpha"]=1 },
        ["yellowgreen"]       = { ["red"]=0.604,["green"]=0.804,["blue"]=0.196,["alpha"]=1 },
        ["limegreen"]         = { ["red"]=0.196,["green"]=0.804,["blue"]=0.196,["alpha"]=1 },
        ["lime"]              = { ["red"]=0.000,["green"]=1.000,["blue"]=0.000,["alpha"]=1 },
        ["lawngreen"]         = { ["red"]=0.486,["green"]=0.988,["blue"]=0.000,["alpha"]=1 },
        ["chartreuse"]        = { ["red"]=0.498,["green"]=1.000,["blue"]=0.000,["alpha"]=1 },
        ["greenyellow"]       = { ["red"]=0.678,["green"]=1.000,["blue"]=0.184,["alpha"]=1 },
        ["springgreen"]       = { ["red"]=0.000,["green"]=1.000,["blue"]=0.498,["alpha"]=1 },
        ["mediumspringgreen"] = { ["red"]=0.000,["green"]=0.980,["blue"]=0.604,["alpha"]=1 },
        ["lightgreen"]        = { ["red"]=0.565,["green"]=0.933,["blue"]=0.565,["alpha"]=1 },
        ["palegreen"]         = { ["red"]=0.596,["green"]=0.984,["blue"]=0.596,["alpha"]=1 },
        ["darkseagreen"]      = { ["red"]=0.561,["green"]=0.737,["blue"]=0.561,["alpha"]=1 },
        ["mediumseagreen"]    = { ["red"]=0.235,["green"]=0.702,["blue"]=0.443,["alpha"]=1 },
        ["seagreen"]          = { ["red"]=0.180,["green"]=0.545,["blue"]=0.341,["alpha"]=1 },
        ["forestgreen"]       = { ["red"]=0.133,["green"]=0.545,["blue"]=0.133,["alpha"]=1 },
        ["green"]             = { ["red"]=0.000,["green"]=0.502,["blue"]=0.000,["alpha"]=1 },
        ["darkgreen"]         = { ["red"]=0.000,["green"]=0.392,["blue"]=0.000,["alpha"]=1 },
    -- Cyan colors
        ["mediumaquamarine"]  = { ["red"]=0.400,["green"]=0.804,["blue"]=0.667,["alpha"]=1 },
        ["aqua"]              = { ["red"]=0.000,["green"]=1.000,["blue"]=1.000,["alpha"]=1 },
        ["cyan"]              = { ["red"]=0.000,["green"]=1.000,["blue"]=1.000,["alpha"]=1 },
        ["lightcyan"]         = { ["red"]=0.878,["green"]=1.000,["blue"]=1.000,["alpha"]=1 },
        ["paleturquoise"]     = { ["red"]=0.686,["green"]=0.933,["blue"]=0.933,["alpha"]=1 },
        ["aquamarine"]        = { ["red"]=0.498,["green"]=1.000,["blue"]=0.831,["alpha"]=1 },
        ["turquoise"]         = { ["red"]=0.251,["green"]=0.878,["blue"]=0.816,["alpha"]=1 },
        ["mediumturquoise"]   = { ["red"]=0.282,["green"]=0.820,["blue"]=0.800,["alpha"]=1 },
        ["darkturquoise"]     = { ["red"]=0.000,["green"]=0.808,["blue"]=0.820,["alpha"]=1 },
        ["lightseagreen"]     = { ["red"]=0.125,["green"]=0.698,["blue"]=0.667,["alpha"]=1 },
        ["cadetblue"]         = { ["red"]=0.373,["green"]=0.620,["blue"]=0.627,["alpha"]=1 },
        ["darkcyan"]          = { ["red"]=0.000,["green"]=0.545,["blue"]=0.545,["alpha"]=1 },
        ["teal"]              = { ["red"]=0.000,["green"]=0.502,["blue"]=0.502,["alpha"]=1 },
    -- Blue colors
        ["lightsteelblue"]    = { ["red"]=0.690,["green"]=0.769,["blue"]=0.871,["alpha"]=1 },
        ["powderblue"]        = { ["red"]=0.690,["green"]=0.878,["blue"]=0.902,["alpha"]=1 },
        ["lightblue"]         = { ["red"]=0.678,["green"]=0.847,["blue"]=0.902,["alpha"]=1 },
        ["skyblue"]           = { ["red"]=0.529,["green"]=0.808,["blue"]=0.922,["alpha"]=1 },
        ["lightskyblue"]      = { ["red"]=0.529,["green"]=0.808,["blue"]=0.980,["alpha"]=1 },
        ["deepskyblue"]       = { ["red"]=0.000,["green"]=0.749,["blue"]=1.000,["alpha"]=1 },
        ["dodgerblue"]        = { ["red"]=0.118,["green"]=0.565,["blue"]=1.000,["alpha"]=1 },
        ["cornflowerblue"]    = { ["red"]=0.392,["green"]=0.584,["blue"]=0.929,["alpha"]=1 },
        ["steelblue"]         = { ["red"]=0.275,["green"]=0.510,["blue"]=0.706,["alpha"]=1 },
        ["royalblue"]         = { ["red"]=0.255,["green"]=0.412,["blue"]=0.882,["alpha"]=1 },
        ["blue"]              = { ["red"]=0.000,["green"]=0.000,["blue"]=1.000,["alpha"]=1 },
        ["mediumblue"]        = { ["red"]=0.000,["green"]=0.000,["blue"]=0.804,["alpha"]=1 },
        ["darkblue"]          = { ["red"]=0.000,["green"]=0.000,["blue"]=0.545,["alpha"]=1 },
        ["navy"]              = { ["red"]=0.000,["green"]=0.000,["blue"]=0.502,["alpha"]=1 },
        ["midnightblue"]      = { ["red"]=0.098,["green"]=0.098,["blue"]=0.439,["alpha"]=1 },
    -- Purple/Violet/Magenta colors
        ["lavender"]          = { ["red"]=0.902,["green"]=0.902,["blue"]=0.980,["alpha"]=1 },
        ["thistle"]           = { ["red"]=0.847,["green"]=0.749,["blue"]=0.847,["alpha"]=1 },
        ["plum"]              = { ["red"]=0.867,["green"]=0.627,["blue"]=0.867,["alpha"]=1 },
        ["violet"]            = { ["red"]=0.933,["green"]=0.510,["blue"]=0.933,["alpha"]=1 },
        ["orchid"]            = { ["red"]=0.855,["green"]=0.439,["blue"]=0.839,["alpha"]=1 },
        ["fuchsia"]           = { ["red"]=1.000,["green"]=0.000,["blue"]=1.000,["alpha"]=1 },
        ["magenta"]           = { ["red"]=1.000,["green"]=0.000,["blue"]=1.000,["alpha"]=1 },
        ["mediumorchid"]      = { ["red"]=0.729,["green"]=0.333,["blue"]=0.827,["alpha"]=1 },
        ["mediumpurple"]      = { ["red"]=0.576,["green"]=0.439,["blue"]=0.859,["alpha"]=1 },
        ["blueviolet"]        = { ["red"]=0.541,["green"]=0.169,["blue"]=0.886,["alpha"]=1 },
        ["darkviolet"]        = { ["red"]=0.580,["green"]=0.000,["blue"]=0.827,["alpha"]=1 },
        ["darkorchid"]        = { ["red"]=0.600,["green"]=0.196,["blue"]=0.800,["alpha"]=1 },
        ["darkmagenta"]       = { ["red"]=0.545,["green"]=0.000,["blue"]=0.545,["alpha"]=1 },
        ["purple"]            = { ["red"]=0.502,["green"]=0.000,["blue"]=0.502,["alpha"]=1 },
        ["indigo"]            = { ["red"]=0.294,["green"]=0.000,["blue"]=0.510,["alpha"]=1 },
        ["darkslateblue"]     = { ["red"]=0.282,["green"]=0.239,["blue"]=0.545,["alpha"]=1 },
        ["rebeccapurple"]     = { ["red"]=0.400,["green"]=0.200,["blue"]=0.600,["alpha"]=1 },
        ["slateblue"]         = { ["red"]=0.416,["green"]=0.353,["blue"]=0.804,["alpha"]=1 },
        ["mediumslateblue"]   = { ["red"]=0.482,["green"]=0.408,["blue"]=0.933,["alpha"]=1 },
    -- White colors
        ["white"]             = { ["red"]=1.000,["green"]=1.000,["blue"]=1.000,["alpha"]=1 },
        ["snow"]              = { ["red"]=1.000,["green"]=0.980,["blue"]=0.980,["alpha"]=1 },
        ["honeydew"]          = { ["red"]=0.941,["green"]=1.000,["blue"]=0.941,["alpha"]=1 },
        ["mintcream"]         = { ["red"]=0.961,["green"]=1.000,["blue"]=0.980,["alpha"]=1 },
        ["azure"]             = { ["red"]=0.941,["green"]=1.000,["blue"]=1.000,["alpha"]=1 },
        ["aliceblue"]         = { ["red"]=0.941,["green"]=0.973,["blue"]=1.000,["alpha"]=1 },
        ["ghostwhite"]        = { ["red"]=0.973,["green"]=0.973,["blue"]=1.000,["alpha"]=1 },
        ["whitesmoke"]        = { ["red"]=0.961,["green"]=0.961,["blue"]=0.961,["alpha"]=1 },
        ["seashell"]          = { ["red"]=1.000,["green"]=0.961,["blue"]=0.933,["alpha"]=1 },
        ["beige"]             = { ["red"]=0.961,["green"]=0.961,["blue"]=0.863,["alpha"]=1 },
        ["oldlace"]           = { ["red"]=0.992,["green"]=0.961,["blue"]=0.902,["alpha"]=1 },
        ["floralwhite"]       = { ["red"]=1.000,["green"]=0.980,["blue"]=0.941,["alpha"]=1 },
        ["ivory"]             = { ["red"]=1.000,["green"]=1.000,["blue"]=0.941,["alpha"]=1 },
        ["antiquewhite"]      = { ["red"]=0.980,["green"]=0.922,["blue"]=0.843,["alpha"]=1 },
        ["linen"]             = { ["red"]=0.980,["green"]=0.941,["blue"]=0.902,["alpha"]=1 },
        ["lavenderblush"]     = { ["red"]=1.000,["green"]=0.941,["blue"]=0.961,["alpha"]=1 },
        ["mistyrose"]         = { ["red"]=1.000,["green"]=0.894,["blue"]=0.882,["alpha"]=1 },
    -- Gray/Black colors
        ["gainsboro"]         = { ["red"]=0.863,["green"]=0.863,["blue"]=0.863,["alpha"]=1 },
        ["lightgrey"]         = { ["red"]=0.827,["green"]=0.827,["blue"]=0.827,["alpha"]=1 },
        ["silver"]            = { ["red"]=0.753,["green"]=0.753,["blue"]=0.753,["alpha"]=1 },
        ["darkgray"]          = { ["red"]=0.663,["green"]=0.663,["blue"]=0.663,["alpha"]=1 },
        ["gray"]              = { ["red"]=0.502,["green"]=0.502,["blue"]=0.502,["alpha"]=1 },
        ["dimgray"]           = { ["red"]=0.412,["green"]=0.412,["blue"]=0.412,["alpha"]=1 },
        ["lightslategray"]    = { ["red"]=0.467,["green"]=0.533,["blue"]=0.600,["alpha"]=1 },
        ["slategray"]         = { ["red"]=0.439,["green"]=0.502,["blue"]=0.565,["alpha"]=1 },
        ["darkslategray"]     = { ["red"]=0.184,["green"]=0.310,["blue"]=0.310,["alpha"]=1 },
        ["black"]             = { ["red"]=0.000,["green"]=0.000,["blue"]=0.000,["alpha"]=1 },
    }) do x11[k] = v end
end
module.x11 = x11

--- hs._asm.uitk.util.color.hammerspoon
--- Variable
--- This table contains a collection of various useful pre-defined colors:
---  * osx_red - The same red used for OS X window close buttons
---  * osx_green - The same green used for OS X window zoom buttons
---  * osx_yellow - The same yellow used for OS X window minimize buttons
---
--- Notes:
---  * This is not a constant, so you can adjust the colors at run time for your installation if desired.
---  * This is actually an `hs._asm.uitk.util.color.list` object, but you can access it as if it were a table of key-value pairs.
local hammerspoon = module.list.listNamed("hammerspoon")
if not hammerspoon then
    hammerspoon = module.list.listNamed("hammerspoon", true)
    for k, v in pairs({
        ["osx_green"]   = { ["red"]=0.153,["green"]=0.788,["blue"]=0.251,["alpha"]=1 },
        ["osx_red"]     = { ["red"]=0.996,["green"]=0.329,["blue"]=0.302,["alpha"]=1 },
        ["osx_yellow"]  = { ["red"]=1.000,["green"]=0.741,["blue"]=0.180,["alpha"]=1 },
        ["red"]         = { ["red"]=1.000,["green"]=0.000,["blue"]=0.000,["alpha"]=1 },
        ["green"]       = { ["red"]=0.000,["green"]=1.000,["blue"]=0.000,["alpha"]=1 },
        ["blue"]        = { ["red"]=0.000,["green"]=0.000,["blue"]=1.000,["alpha"]=1 },
        ["white"]       = { ["red"]=1.000,["green"]=1.000,["blue"]=1.000,["alpha"]=1 },
        ["black"]       = { ["red"]=0.000,["green"]=0.000,["blue"]=0.000,["alpha"]=1 },
    }) do hammerspoon[k] = v end
end
module.hammerspoon = hammerspoon

--- hs._asm.uitk.util.color.definedCollections
--- Constant
--- This table contains this list of defined color collections provided by the `hs._asm.uitk.util.color` module.  Collections differ from the system color lists in that you can modify the color values their members contain by modifying the table at `hs._asm.uitk.util.color.<collection>.<color>` and future references to that color will reflect the new changes, thus allowing you to customize the palettes for your installation.
module.definedCollections = {

-- NOTE: to allow hs._asm.uitk.util.color.lists, hs._asm.uitk.util.color.colorsFor, and the
-- LuaSkin convertor for NSColor to support collections, keep this up to date
-- with any collection additions

    hammerspoon        = module.hammerspoon,
    ansiTerminalColors = module.ansiTerminalColors,
    x11                = module.x11,
}

--- hs._asm.uitk.util.color.lists() -> table
--- Function
--- Returns a table of key-value pairs for the colorlists known or defined for Hammerspoon.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a key-value table where the keys are strings specifying the names of known lists, and the objects are `hs._asm.uitk.util.color.list` objects.
---
--- Notes:
---  * this table will contain the standard system color lists, any colorlists in the users colorlist directory (see `hs._asm.uitk.util.color.list` documentation), and the legacy `hammerspoon`, `ansiTerminalColors`, and `x11` lists originally found in the `hs._asm.uitk.util.color` module.
module.lists = function(...)
    local availableLists = module.list.availableLists(...)
    local results = {}
    for _, v in ipairs(availableLists) do results[v:name()] = v end

    for k,v in pairs(module.definedCollections) do
        if not results[k] then results[k] = v end
    end
    return setmetatable(results, {
        __tostring = function(_)
            local fnutils, result = require("hs.fnutils"), ""
            for k, v in fnutils.sortByKeys(_) do result = result..k.."\n" end
            return result
        end
    })
end


--- hs._asm.uitk.util.color.colorsFor(list) -> table
--- Function
--- Returns a table containing the colors for the specified system color list or hs._asm.uitk.util.color collection.
---
--- Parameters:
---  * list - the name of the list to provide colors for
---
--- Returns:
---  * a table whose keys are made from the colors provided by the color list or nil if the list does not exist.
---
--- Notes:
---  * Where possible, each color node is provided as its RGB color representation.  Where this is not possible, the color node contains the keys `list` and `name` which identify the indicated color.  This means that you can use the following wherever a color parameter is expected: `hs._asm.uitk.util.color.colorsFor(list)["color-name"]`
---  * This function provides a tostring metatable method which allows listing the defined colors in the list in the Hammerspoon console with: `hs._asm.uitk.util.colorsFor(list)`
---  * See also `hs._asm.uitk.util.color.lists`
module.colorsFor = function(...)
    local args = table.pack(...)
    if args.n == 1 and type(args[1]) == "string" then
        local cl = module.list.listNamed(args[1])
        if cl then
            local result = {}
            for k,v in pairs(cl) do result[k] = v end
            return setmetatable(result, {
                __tostring = function(_)
                    local fnutils, result = require("hs.fnutils"), ""
                    for k, v in fnutils.sortByKeys(_) do result = result..k.."\n" end
                    return result
                end
            })
        else
            return nil
        end
    end
end

-- Return Module Object --------------------------------------------------

return setmetatable(module, {
    __index = function(self, key)
        local result = module.hammerspoon[key]
        return result
    end,
})

