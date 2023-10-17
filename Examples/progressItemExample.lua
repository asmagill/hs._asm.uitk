local uitk  = require("hs._asm.uitk")
local timer = require("hs.timer")

local module = {}

local gui = uitk.window{ x = 100, y = 100, h = 100, w = 204 }:show()
local grp = gui:content()

grp[#grp + 1] = {
    id        = "backgroundSpinner",
    _userdata = uitk.element.progress.new():circular(true):start(),
}
grp[#grp + 1] = {
    id        = "foregroundSpinner",
    _userdata = uitk.element.progress.new():circular(true):threaded(false):start(),
}

grp[#grp + 1] = {
    id        = "backgroundBar",
    _userdata = uitk.element.progress.new():start(),
    frame     = { x = 10, y = 10, w = 184 },
}
grp[#grp + 1] = {
    id        = "foregroundBar",
    _userdata = uitk.element.progress.new():threaded(false):start(),
    frame     = { w = 184 },
}

grp[#grp + 1] = {
    id            = "hoursBar",
    _userdata     = uitk.element.progress.new(),
    min           = 0,
    max           = 23,
    indeterminate = false,
    indicatorSize = "small",
    color         = { red   = 1 },
    tooltip       = "hours",
    frame         = { w = 120 },
}
grp[#grp + 1] = {
    id            = "minutesBar",
    _userdata      = uitk.element.progress.new(),
    min           = 0,
    max           = 60,
    indeterminate = false,
    indicatorSize = "small",
    color         = { green = 1 },
    tooltip       = "minutes",
    frame         = { w = 120 },
}
grp[#grp + 1] = {
    id            = "secondsBar",
    _userdata     = uitk.element.progress.new(),
    min           = 0,
    max           = 60,
    indeterminate = false,
    indicatorSize = "small",
    color         = { blue  = 1 },
    tooltip       = "seconds",
    frame         = { w = 120 },
}

grp[#grp + 1] = {
    id            = "hoursSpinner",
    _userdata     = uitk.element.progress.new(),
    circular      = true,
    min           = 0,
    max           = 23,
    indeterminate = false,
    indicatorSize = "small",
    color         = { red   = 1, green = 1 },
    tooltip       = "hours",
}
grp[#grp + 1] = {
    id            = "minutesSpinner",
    _userdata     = uitk.element.progress.new(),
    circular      = true,
    min           = 0,
    max           = 60,
    indeterminate = false,
    indicatorSize = "small",
    color         = { green = 1, blue = 1 },
    tooltip       = "minutes",
}
grp[#grp + 1] = {
    id            = "secondsSpinner",
    _userdata     = uitk.element.progress.new(),
    circular      = true,
    min           = 0,
    max           = 60,
    indeterminate = false,
    indicatorSize = "small",
    color         = { blue  = 1, red = 1 },
    tooltip       = "seconds",
}

grp("backgroundBar"):frame{ x = 10, y = 10, w = 184 }

grp("backgroundSpinner"):position("below", grp("backgroundBar"), "start")
grp("foregroundSpinner"):position("below", grp("backgroundBar"), "end")

grp("hoursBar"):position("below", grp("backgroundBar"), -2)
grp("minutesBar"):position("below", grp("hoursBar"), "start")
grp("secondsBar"):position("below", grp("minutesBar"), "start")

grp("foregroundBar"):position("below", grp("backgroundSpinner"), "start")

grp("hoursSpinner"):position("below", grp("foregroundBar"), "start")
grp("minutesSpinner"):position("below", grp("foregroundBar"))
grp("secondsSpinner"):position("below", grp("foregroundBar"), "end")

local updateTimeBars = function()
    local t = os.date("*t")
    grp("hoursBar"):value(t.hour)
    grp("minutesBar"):value(t.min)
    grp("secondsBar"):value(t.sec)
    grp("hoursSpinner"):value(t.hour)
    grp("minutesSpinner"):value(t.min)
    grp("secondsSpinner"):value(t.sec)
end

module.gui   = gui -- prevent collections
module.timer = timer.doEvery(1, updateTimeBars):start()
updateTimeBars()

return module

