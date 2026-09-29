local uitk = require("hs._asm.uitk")
local image = require("hs.image")

w1 = uitk.window{x = 100, y = 100, h = 500, w = 500 }:show():styleMask(1 | 2 | 4 | 8 )
tbd = uitk.toolbar.dictionary("sample")

tbd:addItem("one", {
    type = "group",
})
tbd:addItem("two", {
    label = "two",
    image = image.imageFromName(image.systemImageNames.StatusAvailable),
})
tbd:addItem("three", {
    label = "three",
    image = image.imageFromName(image.systemImageNames.StatusUnavailable),
})
tbd:addItem("four", {
    label = "four",
    image = image.imageFromName(image.systemImageNames.StatusPartiallyAvailable),
})

local groupMembers = {}
for i = 1, 10, 1 do
    tbd:addItem("g" .. tostring(i), {
        label = "g" .. tostring(i),
        image = image.imageFromName(image.systemImageNames.StatusNone),
    })
    table.insert(groupMembers, "g" .. tostring(i))
end

tbd:modifyItem("one", {
    groupMembers = groupMembers
})

tbd:allowedItems({ "one", "two", "three", "four" })
tbd:defaultItems({ "one", "two" })

tb1 = uitk.toolbar("sample"):canCustomize(true)
                            :callback(_cbinspect("sample"))
                            :displayMode("both")

w1:toolbar(tb1)
