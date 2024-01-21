local uitk = require("hs._asm.uitk")

local finspect = function(...) return (require("hs.inspect")({...}):gsub("%s+", " ")) end

local module = {}

local tableRows = {}

for i = 1, 20, 1 do
    local modsMenu = uitk.menu("Mod " .. tostring(i)):callback(function(...)
                                                                   print("mods", i, finspect(...))
                                                               end)
    modsMenu[1] = { title = ""        }
    modsMenu[2] = { title = "Cmd"     }
    modsMenu[3] = { title = "Shift"   }
    modsMenu[4] = { title = "Control" }
    modsMenu[5] = { title = "Option"  }

    local keysMenu = uitk.menu("Key " .. tostring(i)):callback(function(...)
                                                                   print("keys", i, finspect(...))
                                                               end)
    keysMenu[1] = { title = "" }
    for j = 65, 90, 1 do keysMenu[#keysMenu + 1] = { title = string.char(j) } end

    local label    = uitk.element.textField.newLabel("Action " .. tostring(i))
    local action   = uitk.element.container()
    action[1] = {
        _self          = uitk.element.textField.newTextField(),
        containerFrame = { w = 300 },
    }
    action[2] = uitk.element.button.buttonWithTitle("Select"):bezelStyle("roundRect")
    action[2]:position("after", action[1], 5, "center")
    action[3] = uitk.element.button.buttonWithTitle("Clear"):bezelStyle("roundRect")
    action[3]:position("after", action[2], 5, "center")
    local modifier = uitk.element.popUpButton(modsMenu):selectedIndex(1)
    local key      = uitk.element.popUpButton(keysMenu):selectedIndex(1)

    tableRows[i] = { label = label, action = action, modifier = modifier, key = key }
end

local actionFittingSize = tableRows[1].action:fittingSize()

local dataSourceCallback = function(tbl, action, ...)
    if action == "count" then
        return #tableRows
    elseif action == "view" then
        local r, cIdentifier = ...
-- uncomment to see when rows are repopulated...
--         print(r,cIdentifier)
        return tableRows[r][cIdentifier]
    else
        return "unknown: " .. tostring(action)
    end
end

local labelColumn    = uitk.element.container.table.newColumn("label"):title("Label")
local actionColumn   = uitk.element.container.table.newColumn("action"):title("Action"):width(actionFittingSize.w)
local modifierColumn = uitk.element.container.table.newColumn("modifier"):title("Modifier")
local keyColumn      = uitk.element.container.table.newColumn("key"):title("Key")

local tableView = uitk.element.container.table():dataSourceCallback(dataSourceCallback)
                                                :addColumn(labelColumn)
                                                :addColumn(actionColumn)
                                                :addColumn(modifierColumn)
                                                :addColumn(keyColumn)
                                                :passthroughCallback(function(...)
                                                    print("tablePassthrough", finspect(...))
                                                end)

local scroller = uitk.element.container.scroller{}:document(tableView)

tableView._properties = {
    columnAutosizing = "firstColumnOnly",
    callback         = function(...)
                           print("tableCallback", finspect(...))
                       end,
}

local window = uitk.window{x = 100, y = 100, h = 200, w = 900 }:show():passthroughCallback(function(...)
    print("windowPassthrough", finspect(...))
end)
local content  = window:content()
content[1] = {
    _self            = scroller,
    containerFrame   = { h = "100%", w = "100%" },
    verticalScroller = true,
}

module.window = window
-- module.tableRows = tableRows

return module
