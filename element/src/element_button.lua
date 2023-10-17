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

--- === hs._asm.uitk.element.button ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.element.button"
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libelement_"))

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

--- hs._asm.uitk.element.button.radioButtonSet(...) -> contentObject
--- Constructor
--- Creates an `hs._asm.uitk.element.content` object which can be used as an element containing a set of radio buttons with labels defined by the specified title strings.
---
--- Parameters:
---  `...` - a single table of strings, or list of strings separated by commas, specifying the labels to assign to the radion buttons in the set.
---
--- Returns:
---  * a new contentObject which can be used as an element to another `hs._asm.uitk.element.content` or assigned to an `hs._asm.uitk.window` directly.
---
--- Notes:
---  * Radio buttons in the same view (content) are treated as related and only one can be selected at a time. By grouping radio button sets in separate contents, these independant contents can be assigned to a parent content and each set will be seen as independent -- each set can have a selected item independent of the other radio sets which may also be displayed in the parent.
---
---  * For example:
--- ~~~ lua
---     g = require("hs._asm.uitk.window")
---     m = g.new{ x = 100, y = 100, h = 100, w = 130 }:content(g.content.new())():show()
---     m[1] = g.element.button.radioButtonSet(1, 2, 3, 4)
---     m[2] = g.element.button.radioButtonSet{"abc", "d", "efghijklmn"}
---     m(2):position("after", m(1), 10, "center")
--- ~~~
---
--- See [hs._asm.uitk.element.button.radioButton](#radioButton) for more details.
module.radioButtonSet = function(...)
    local args = table.pack(...)
    if args.n == 1 and type(args[1]) == "table" then
        args = args[1]
        args.n = #args
    end

    if args.n > 0 then
        local content = require(USERDATA_TAG:gsub("%.button", ".content"))
        local result = content.new()
        for i,v in ipairs(args) do
            result[i] = module.button.radioButton(tostring(v))
        end
        result:sizeToFit()
        return result
    else
        error("expected a table of strings")
    end
end

-- Return Module Object --------------------------------------------------

return module
