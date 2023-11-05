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

--- === hs._asm.uitk.element.segmentBar ===
---
--- Stuff about the module

local USERDATA_TAG = "hs._asm.uitk.element.segmentBar"
local uitk         = require("hs._asm.uitk")
local module       = require(table.concat({ USERDATA_TAG:match("^([%w%._]+%.)[%w_]+%.([%w_]+)$") }, "libelement_"))

local moduleMT     = hs.getObjectMetatable(USERDATA_TAG)

-- settings with periods in them can't be watched via KVO with hs.settings.watchKey, so
-- in general it's a good idea not to include periods
-- local SETTINGS_TAG = USERDATA_TAG:gsub("%.", "_")
-- local settings     = require("hs.settings")
-- local log          = require("hs.logger").new(USERDATA_TAG, settings.get(SETTINGS_TAG .. "_logLevel") or "warning")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

moduleMT.labels = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        local results = {}
        for i = 1, self:segmentCount(), 1 do
            results[i] = self:labelForSegment(i)
        end
        return results
    elseif args.n == 1 and type(args[1]) ~= "table" then
        for i = 1, self:segmentCount(), 1 do
            self:labelForSegment(i, args[1])
        end
        return self
    else
        if args.n == 1 then
            args = table.pack(table.unpack(args[1]))
        end
        if args.n > self:segmentCount() then
            error("too many values", 3)
        end

        for i = 1, self:segmentCount(), 1 do
            local t = type(args[i])
            if t ~= "string" and t ~= "nil" then
                error("expected string or nil in labels array", 3)
            end
        end

        for i = 1, self:segmentCount(), 1 do
            self:labelForSegment(i, args[i])
        end
        return self
    end
end
table.insert(moduleMT._propertyList, "labels") ;

moduleMT.images = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        local results = {}
        for i = 1, self:segmentCount(), 1 do
            results[i] = self:imageForSegment(i)
        end
        return results
    elseif args.n == 1 and type(args[1]) ~= "table" then
        for i = 1, self:segmentCount(), 1 do
            self:imageForSegment(i, args[1])
        end
        return self
    else
        if args.n == 1 then
            args = table.pack(table.unpack(args[1]))
        end
        if args.n > self:segmentCount() then
            error("too many values", 3)
        end

        for i = 1, self:segmentCount(), 1 do
            local t = type(args[i])
            if t ~= "userdata" and t ~= "nil" and (getmetatable(args[i]) or {}).__name ~= "hs.image" then
                error("expected hs.image object or nil in images array", 3)
            end
        end

        for i = 1, self:segmentCount(), 1 do
            self:imageForSegment(i, args[i])
        end
        return self
    end
end
table.insert(moduleMT._propertyList, "images") ;

moduleMT.menus = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        local results = {}
        for i = 1, self:segmentCount(), 1 do
            results[i] = self:menuForSegment(i)
        end
        return results
    elseif args.n == 1 and type(args[1]) ~= "table" then
        for i = 1, self:segmentCount(), 1 do
            self:menuForSegment(i, args[1])
        end
        return self
    else
        if args.n == 1 then
            args = table.pack(table.unpack(args[1]))
        end
        if args.n > self:segmentCount() then
            error("too many values", 3)
        end

        for i = 1, self:segmentCount(), 1 do
            local t = type(args[i])
            if t ~= "userdata" and t ~= "nil" and (getmetatable(args[i]) or {}).__name ~= "hs._asm.uitk.menu" then
                error("expected hs._asm.uitk.menu object or nil in menus array", 3)
            end
        end

        for i = 1, self:segmentCount(), 1 do
            self:menuForSegment(i, args[i])
        end
        return self
    end
end
table.insert(moduleMT._propertyList, "menus") ;

moduleMT.toolTips = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        local results = {}
        for i = 1, self:segmentCount(), 1 do
            results[i] = self:toolTipForSegment(i)
        end
        return results
    elseif args.n == 1 and type(args[1]) ~= "table" then
        for i = 1, self:segmentCount(), 1 do
            self:toolTipForSegment(i, args[1])
        end
        return self
    else
        if args.n == 1 then
            args = table.pack(table.unpack(args[1]))
        end
        if args.n > self:segmentCount() then
            error("too many values", 3)
        end

        for i = 1, self:segmentCount(), 1 do
            local t = type(args[i])
            if t ~= "string" and t ~= "nil" then
                error("expected string or nil in toolTips array", 3)
            end
        end

        for i = 1, self:segmentCount(), 1 do
            self:toolTipForSegment(i, args[i])
        end
        return self
    end
end
table.insert(moduleMT._propertyList, "toolTips") ;

moduleMT.alignments = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        local results = {}
        for i = 1, self:segmentCount(), 1 do
            results[i] = self:alignmentForSegment(i)
        end
        return results
    elseif args.n == 1 and type(args[1]) ~= "table" then
        for i = 1, self:segmentCount(), 1 do
            self:alignmentForSegment(i, args[1])
        end
        return self
    else
        if args.n == 1 then
            args = table.pack(table.unpack(args[1]))
        end
        if args.n > self:segmentCount() then
            error("too many values", 3)
        end

        for i = 1, self:segmentCount(), 1 do
            local t = type(args[i])
            if t ~= "string" then
                error("expected string in alignments array", 3)
            end
        end

        for i = 1, self:segmentCount(), 1 do
            self:alignmentForSegment(i, args[i])
        end
        return self
    end
end
table.insert(moduleMT._propertyList, "alignments") ;

moduleMT.imageScalings = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        local results = {}
        for i = 1, self:segmentCount(), 1 do
            results[i] = self:imageScalingForSegment(i)
        end
        return results
    elseif args.n == 1 and type(args[1]) ~= "table" then
        for i = 1, self:segmentCount(), 1 do
            self:imageScalingForSegment(i, args[1])
        end
        return self
    else
        if args.n == 1 then
            args = table.pack(table.unpack(args[1]))
        end
        if args.n > self:segmentCount() then
            error("too many values", 3)
        end

        for i = 1, self:segmentCount(), 1 do
            local t = type(args[i])
            if t ~= "string" then
                error("expected string in imageScalings array", 3)
            end
        end

        for i = 1, self:segmentCount(), 1 do
            self:imageScalingForSegment(i, args[i])
        end
        return self
    end
end
table.insert(moduleMT._propertyList, "imageScalings") ;

moduleMT.enabledSegments = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        local results = {}
        for i = 1, self:segmentCount(), 1 do
            results[i] = self:enabledForSegment(i)
        end
        return results
    elseif args.n == 1 and type(args[1]) ~= "table" then
        for i = 1, self:segmentCount(), 1 do
            self:enabledForSegment(i, args[1])
        end
        return self
    else
        if args.n == 1 then
            args = table.pack(table.unpack(args[1]))
        end
        if args.n > self:segmentCount() then
            error("too many values", 3)
        end

        for i = 1, self:segmentCount(), 1 do
            local t = type(args[i])
            if t ~= "boolean" then
                error("expected boolean in enabledSegments array", 3)
            end
        end

        for i = 1, self:segmentCount(), 1 do
            self:enabledForSegment(i, args[i])
        end
        return self
    end
end
table.insert(moduleMT._propertyList, "enabledSegments") ;

moduleMT.menuIndicators = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        local results = {}
        for i = 1, self:segmentCount(), 1 do
            results[i] = self:menuIndicatorForSegment(i)
        end
        return results
    elseif args.n == 1 and type(args[1]) ~= "table" then
        for i = 1, self:segmentCount(), 1 do
            self:menuIndicatorForSegment(i, args[1])
        end
        return self
    else
        if args.n == 1 then
            args = table.pack(table.unpack(args[1]))
        end
        if args.n > self:segmentCount() then
            error("too many values", 3)
        end

        for i = 1, self:segmentCount(), 1 do
            local t = type(args[i])
            if t ~= "boolean" then
                error("expected boolean in menuIndicators array", 3)
            end
        end

        for i = 1, self:segmentCount(), 1 do
            self:menuIndicatorForSegment(i, args[i])
        end
        return self
    end
end
table.insert(moduleMT._propertyList, "menuIndicators") ;

moduleMT.selectedSegments = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        local results = {}
        for i = 1, self:segmentCount(), 1 do
            results[i] = self:selectedForSegment(i)
        end
        return results
    elseif args.n == 1 and type(args[1]) ~= "table" then
        for i = 1, self:segmentCount(), 1 do
            self:selectedForSegment(i, args[1])
        end
        return self
    else
        if args.n == 1 then
            args = table.pack(table.unpack(args[1]))
        end
        if args.n > self:segmentCount() then
            error("too many values", 3)
        end

        for i = 1, self:segmentCount(), 1 do
            local t = type(args[i])
            if t ~= "boolean" then
                error("expected boolean in selectedSegments array", 3)
            end
        end

        for i = 1, self:segmentCount(), 1 do
            self:selectedForSegment(i, args[i])
        end
        return self
    end
end
table.insert(moduleMT._propertyList, "selectedSegments") ;

moduleMT.widths = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        local results = {}
        for i = 1, self:segmentCount(), 1 do
            results[i] = self:widthForSegment(i)
        end
        return results
    elseif args.n == 1 and type(args[1]) ~= "table" then
        for i = 1, self:segmentCount(), 1 do
            self:widthForSegment(i, args[1])
        end
        return self
    else
        if args.n == 1 then
            args = table.pack(table.unpack(args[1]))
        end
        if args.n > self:segmentCount() then
            error("too many values", 3)
        end

        for i = 1, self:segmentCount(), 1 do
            local t = type(args[i])
            if t ~= "number" then
                error("expected number in widths array", 3)
            end
        end

        for i = 1, self:segmentCount(), 1 do
            self:widthForSegment(i, args[i])
        end
        return self
    end
end
table.insert(moduleMT._propertyList, "widths") ;

moduleMT.tags = function(self, ...)
    local args = table.pack(...)
    if args.n == 0 then
        local results = {}
        for i = 1, self:segmentCount(), 1 do
            results[i] = self:tagForSegment(i)
        end
        return results
    elseif args.n == 1 and type(args[1]) ~= "table" then
        for i = 1, self:segmentCount(), 1 do
            self:tagForSegment(i, args[1])
        end
        return self
    else
        if args.n == 1 then
            args = table.pack(table.unpack(args[1]))
        end
        if args.n > self:segmentCount() then
            error("too many values", 3)
        end

        for i = 1, self:segmentCount(), 1 do
            local t = math.type(args[i])
            if t ~= "integer" then
                error("expected integer in tags array", 3)
            end
        end

        for i = 1, self:segmentCount(), 1 do
            self:tagForSegment(i, args[i])
        end
        return self
    end
end
table.insert(moduleMT._propertyList, "tags") ;

-- Return Module Object --------------------------------------------------

return module
