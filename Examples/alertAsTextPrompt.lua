local uitk     = require("hs._asm.uitk")
local inspect  = require("hs.inspect")

local callback = function(obj, btnTitle)
    local message = string.format("%s :: %s", os.date("%F %T"), btnTitle)
    if btnTitle == "OK" then
        message = message .. " -> " .. obj:accessory():value()
    end
    print(message)
end

local prompt = uitk.element.textField.newTextField()
prompt:placeholder("your input")

alert = uitk.panel.alert.new()

prompt:editingCallback(function(object, action, ...)
    local args = table.pack(...)
    if action == "keyPress" then
        local keyName = args[1]
        if keyName == "return" then
            alert:buttons()[1]:press()
            return true
        elseif keyName == "escape" then
            alert:buttons()[2]:press()
            return true
        end
    end

    return args[#args]
end)

alert:messageText("Main message")
alert:informativeText("Please enter something:")
alert:addButtonWithTitle("OK")
alert:addButtonWithTitle("Cancel")
alert:callback(callback)
alert:accessory(prompt)
alert:run()


