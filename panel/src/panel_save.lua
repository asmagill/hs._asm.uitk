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

--- === hs._asm.uitk.panel.save ===
---
--- This module provides a save dialog with which the user can navigate and specify a file name for saving something.

local USERDATA_TAG = "hs._asm.uitk.panel.save"
local uitk         = require("hs._asm.uitk")
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libpanel_"))
local fnutils      = require("hs.fnutils")

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)
local openMT       = hs.getObjectMetatable(USERDATA_TAG:match("^(.+)%.%w+$") .. ".open")

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
local settings     = require("hs.settings")
local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

local _open = module._open
module._open = nil

-- Public interface ------------------------------------------------------

--- hs._asm.uitk.panel.save.refreshFileTypeBindings() -> None
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
---    * [hs._asm.uitk.panel.save.mimeTypes](#mimeTypes)
---    * [hs._asm.uitk.panel.save.utiTypes](#utiTypes)
---    * [hs._asm.uitk.panel.save.fileExtensions](#fileExtensions)
---
---  * This function is identical to the one provided in `hs._asm.uitk.panel.open` and running either will update the same lookup tables.
module.refreshFileTypeBindings = function()
    local UTIBinding, MIMEBinding, ExtensionBinding = {}, {}, {}

    local o,s,t,r = hs.execute([[ (/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -dump UTIBinding | grep -v '^\-' | awk '{ print $1 }' | sed 's/:$//' | sort | uniq) 2>&1 ]])

    if s == true and t == "exit" and r == 0 then
        for identifier in o:gmatch("([^\r\n]+)[\r\n]") do
            if identifier ~= "" then table.insert(UTIBinding, identifier) end
        end
    else
        log.ef("error retrieving UTIBindings: %s, %s code %d", o, t, r)
    end

    o,s,t,r = hs.execute([[ (/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -dump MIMEBinding | grep -v '^\-' | awk '{ print $1 }' | sed 's/:$//' | sort | uniq) 2>&1 ]])

    if s == true and t == "exit" and r == 0 then
        for identifier in o:gmatch("([^\r\n]+)[\r\n]") do
            if identifier ~= "" then table.insert(MIMEBinding, identifier) end
        end
    else
        log.ef("error retrieving MIMEBindings: %s, %s code %d", o, t, r)
    end

    o,s,t,r = hs.execute([[ (/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -dump ExtensionBinding | grep -v '^\-' | awk '{ print $1 }' | sed 's/:$//' | sort | uniq) 2>&1 ]])

    if s == true and t == "exit" and r == 0 then
        for identifier in o:gmatch("([^\r\n]+)[\r\n]") do
            if identifier ~= "" then table.insert(ExtensionBinding, identifier) end
        end
    else
        log.ef("error retrieving ExtensionBinding: %s, %s code %d", o, t, r)
    end

    module.mimeTypes      = ls.makeConstantsTable(MIMEBinding)
    module.utiTypes       = ls.makeConstantsTable(UTIBinding)
    module.fileExtensions = ls.makeConstantsTable(ExtensionBinding)

    _open.mimeTypes      = module.mimeTypes
    _open.utiTypes       = module.utiTypes
    _open.fileExtensions = module.fileExtensions
end

--- hs._asm.uitk.panel.save.mimeTypes[]
--- Constant
--- A table of mime types recognized by this system
---
--- This table contains mime types recognized by this system and can be used with the [hs._asm.uitk.panel.save:contentTypes](#contentTypes) method to indicate the types of file that you wish to save. If the user attempts to save a file with an extension that does not map to a specified mime type, they will be prompted.
---
--- Mime types are specified as a string and follow the format "type/tree.subtype+suffix;parameter", where only "type" and "subtype" are required.
---
--- The term "mime types" is considered deprecated by some in favor of "media type", but the term is still commonly used and the format remains the same.

--- hs._asm.uitk.panel.save.utiTypes[]
--- Constant
--- A table of Uniform Type Identifiers (UTIs) recognized by this system
---
--- This table contains UTI types recognized by this system and can be used with the [hs._asm.uitk.panel.save:contentTypes](#contentTypes) method to indicate the types of file that you wish to save. If the user attempts to save a file with an extension that does not map to a specified UTI type, they will be prompted.
---
--- Per Wikipedia: UTIs (are strings that) use a reverse-DNS naming structure. Names may include the ASCII characters A–Z, a–z, 0–9, hyphen ("-"), and period ("."), and all Unicode characters above U+007F.[1] Colons and slashes are prohibited for compatibility with Macintosh and POSIX file path conventions. UTIs support multiple inheritance, allowing files to be identified with any number of relevant types, as appropriate to the contained data. UTIs are case-insensitive.

--- hs._asm.uitk.panel.save.fileExtensions[]
--- Constant
--- A table of filename extensions recognized by this system
---
--- This table contains file extensions recognized by this system and can be used with the [hs._asm.uitk.panel.save:contentTypes](#contentTypes) method to indicate the types of file that you wish to save. If the user attempts to save a file with an extension that has not been specified, they will be prompted.
---
--- Filename extensions are strings that are used by many systems to identify file types. They are the characters which usually follow the final period in a file name, though there are a few recognized compound file extensions which contain a period within the extension string.
---
--- Under the macOS Finder, file extensions may be hidden, though they still exist for most files which are expected to be shared or usable across multiple platforms. They may also be hidden in a presented save panel if the [hs._asm.uitk.panel.save:extensionHidden](#extensionHidden) property is set to true.

--- hs._asm.uitk.panel.save:contentTypes([types], [force]) -> panelObject | table
--- Method
--- Get or set the content types the save panel will allow without prompting.
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
---    * [hs._asm.uitk.panel.save.mimeTypes](#mimeTypes)
---    * [hs._asm.uitk.panel.save.utiTypes](#utiTypes)
---    * [hs._asm.uitk.panel.save.fileExtensions](#fileExtensions)
---
---  * You can mix types, e.g. `{ "txt", "text/plain", "public.text" }`
local _contentTypes = moduleMT.contentTypes
moduleMT.contentTypes = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        return _contentTypes(self)
    else
        local passUntested = nil
        if args.n > 1 and type(args[args.n]) == "boolean" then
            passUntested = table.remove(args)
            args.n = args.n - 1
        end
        if args.n == 1 and type(args[1]) == "table" then
            args = args[1]
        end
        args.n = nil

        if not passUntested then
            local good = true
            for i, v in ipairs(args) do
                good = fnutils.contains(module.mimeTypes, v) or
                       fnutils.contains(module.utiTypes, v) or
                       fnutils.contains(module.fileExtensions, v)
                if not good then
                    error(string.format("%s at index %d is not a recognized MIME Type, UTI, or file extension", v, i), 3)
                end
            end
        end

        return _contentTypes(self, args)
    end
end

openMT.contentTypes = moduleMT.contentTypes

-- Return Module Object --------------------------------------------------

-- do initial assignment of type tables
module.refreshFileTypeBindings()

uitk.util._properties.addPropertiesWrapper(moduleMT)

return setmetatable(module, {
    __call = function(self, ...) return self.new(...) end,
    __index = function(self, key)
        if key == "_open" then
            return _open
        else
            return nil
        end
    end,
})
