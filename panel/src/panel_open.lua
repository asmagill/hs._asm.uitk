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

--- === hs._asm.uitk.panel.open ===
---
--- This module provides an open dialog with which the user can select one or more files or directories.

local USERDATA_TAG = "hs._asm.uitk.panel.open"
local uitk         = require("hs._asm.uitk")
local savePanel    = uitk.panel.save
local module       = savePanel._open
local fnutils      = require("hs.fnutils")

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

module.__refTable = savePanel.__refTable

-- Public interface ------------------------------------------------------

--- hs._asm.uitk.panel.open.refreshFileTypeBindings() -> None
--- Function
--- Refresh the known file extensions, mime types, and uti types provided by the constants in this module.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * This function is run automatically when the module first loads and you should not need to run it again unless there have been applications added or removed from the Mac that might change what file types are recognized by the system.
---
---  * The following tables are populated by this function:
---    * [hs._asm.uitk.panel.open.mimeTypes](#mimeTypes)
---    * [hs._asm.uitk.panel.open.utiTypes](#utiTypes)
---    * [hs._asm.uitk.panel.open.fileExtensions](#fileExtensions)
---
---  * This function is identical to the one provided in `hs._asm.uitk.panel.save` and running either will update the same lookup tables.

--- hs._asm.uitk.panel.open.mimeTypes[]
--- Constant
--- A table of mime types recognized by this system
---
--- This table contains mime types recognized by this system and can be used with the [hs._asm.uitk.panel.open:contentTypes](#contentTypes) method to indicate the types of file that you wish to open.
---
--- Mime types are specified as a string and follow the format "type/tree.subtype+suffix;parameter", where only "type" and "subtype" are required.
---
--- The term "mime types" is considered deprecated by some in favor of "media type", but the term is still commonly used and the format remains the same.

--- hs._asm.uitk.panel.open.utiTypes[]
--- Constant
--- A table of Uniform Type Identifiers (UTIs) recognized by this system
---
--- This table contains UTI types recognized by this system and can be used with the [hs._asm.uitk.panel.open:contentTypes](#contentTypes) method to indicate the types of file that you wish to open.
---
--- Per Wikipedia: UTIs (are strings that) use a reverse-DNS naming structure. Names may include the ASCII characters A–Z, a–z, 0–9, hyphen ("-"), and period ("."), and all Unicode characters above U+007F.[1] Colons and slashes are prohibited for compatibility with Macintosh and POSIX file path conventions. UTIs support multiple inheritance, allowing files to be identified with any number of relevant types, as appropriate to the contained data. UTIs are case-insensitive.

--- hs._asm.uitk.panel.open.fileExtensions[]
--- Constant
--- A table of filename extensions recognized by this system
---
--- This table contains file extensions recognized by this system and can be used with the [hs._asm.uitk.panel.open:contentTypes](#contentTypes) method to indicate the types of file that you wish to open.
---
--- Filename extensions are strings that are used by many systems to identify file types. They are the characters which usually follow the final period in a file name, though there are a few recognized compound file extensions which contain a period within the extension string.
---
--- Under the macOS Finder, file extensions may be hidden, though they still exist for most files which are expected to be shared or usable across multiple platforms. They may also be hidden in a presented save panel if the [hs._asm.uitk.panel.open:extensionHidden](#extensionHidden) property is set to true.

--- hs._asm.uitk.panel.open:contentTypes([types], [force]) -> panelObject | table
--- Method
--- Get or set the content types the open panel will allow the user to select
---
--- Parameters:
---  * `types` - an array of strings (or list of comma separated strings) specifying the file types allowed. Supply an empty table to specify that all types are allowed.
---  * `force` - an optional boolean, default false, specifying whether or not the content types should be compared against the types known to the macOS operating system.
---
--- Returns:
---  * If an argument is provided, the panel object; otherwise the current value.
---
--- Notes:
---  * if you do not specify `force` as true, the strings provided are looked up in the following tables to verify that they are known to the system:
---    * [hs._asm.uitk.panel.open.mimeTypes](#mimeTypes)
---    * [hs._asm.uitk.panel.open.utiTypes](#utiTypes)
---    * [hs._asm.uitk.panel.open.fileExtensions](#fileExtensions)
---
---  * You can mix types, e.g. `{ "txt", "text/plain", "public.text" }`

module.refreshFileTypeBindings = savePanel.refreshFileTypeBindings

-- Return Module Object --------------------------------------------------

uitk.util._properties.addPropertiesWrapper(moduleMT)

return setmetatable(module, {
    __call = function(self, ...) return self.new(...) end,
})
