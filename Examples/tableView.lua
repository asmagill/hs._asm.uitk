local uitk = require("hs._asm.uitk")

local finspect = function(...)
    local args = table.pack(...)
    if args.n == 1 then
        args = args[1]
    else
        args.n = nil -- supress the count from table.pack
    end
    return inspect(args, { newline = " ", indent = "" })
end

local menuChangeCallback = function(name, row, ...)
    print(name, row, finspect(...))
end

local module = {}

local tableRows = {}

for i = 1, 10, 1 do
    local modsMenu = uitk.menu("Mod " .. tostring(i)):callback(function(...)
                                                                   menuChangeCallback("mods", i, ...)
                                                               end)
    modsMenu[1] = { title = ""        }
    modsMenu[2] = { title = "Cmd"     }
    modsMenu[3] = { title = "Shift"   }
    modsMenu[4] = { title = "Control" }
    modsMenu[5] = { title = "Option"  }

    local keysMenu = uitk.menu("Key " .. tostring(i)):callback(function(...)
                                                                   menuChangeCallback("keys", i, ...)
                                                               end)
    keysMenu[1] = { title = "" }
    for j = 65, 90, 1 do keysMenu[#keysMenu + 1] = { title = string.char(j) } end

    local label    = uitk.element.textField.newLabel("Action " .. tostring(i))
    local action   = uitk.element.content()
    action[1] = {
        _userdata = uitk.element.textField.newTextField(),
        frame     = { w = 300 },
    }
    action[2] = uitk.element.button.buttonWithTitle("Select"):bezelStyle("roundRect")
    action[2]._userdata:position("after", action[1]._userdata, 5, "center")
    action[3] = uitk.element.button.buttonWithTitle("Clear"):bezelStyle("roundRect")
    action[3]._userdata:position("after", action[2]._userdata, 5, "center")
    local modifier = uitk.element.popUpButton(modsMenu):selectedIndex(1)
    local key      = uitk.element.popUpButton(keysMenu):selectedIndex(1)

    tableRows[i] = { label = label, action = action, modifier = modifier, key = key }
end

local actionFittingSize = tableRows[1].action:fittingSize()

local dataSourceCallback = function(tbl, action, ...)
    if action == "count" then
        return #tableRows
    elseif action == "view" then
        local r, c = ...
        print(r,c)
        return tableRows[r][c:identifier()]
    else
        return "unknown: " .. tostring(action)
    end
end

local labelColumn    = uitk.element.table.newColumn("label"):title("Label")
local actionColumn   = uitk.element.table.newColumn("action"):title("Action"):width(actionFittingSize.w)
local modifierColumn = uitk.element.table.newColumn("modifier"):title("Modifier")
local keyColumn      = uitk.element.table.newColumn("key"):title("Key")

local tableView = uitk.element.table():dataSourceCallback(dataSourceCallback)
                                      :addColumn(labelColumn)
                                      :addColumn(actionColumn)
                                      :addColumn(modifierColumn)
                                      :addColumn(keyColumn)
                                      :passthroughCallback(function(...)
                                          print("tablePassthrough", finspect(...))
                                      end)

local scroller = uitk.element.content.scroller{}

scroller.element = {
    _userdata        = tableView,
    columnAutosizing = "firstColumnOnly",
    callback         = function(...)
                           print("scrollerCallback", finspect(...))
                       end,
}

local panel    = uitk.panel{x = 100, y = 100, h = 200, w = 900 }:show():passthroughCallback(function(...)
    print("panelPassthrough", finspect(...))
end)
local content  = panel:content()
content[1] = {
    _userdata = scroller,
    frame            = { h = "100%", w = "100%" },
    verticalScroller = true,
}

module.panel = panel
module.tableRows = tableRows

return module
