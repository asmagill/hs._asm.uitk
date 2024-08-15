local console     = require("hs.console")
local canvas      = require("hs.canvas")
local image       = require("hs.image")
local screen      = require("hs.screen")
local application = require("hs.application")
local inspect     = require("hs.inspect")

local uitk = require("hs._asm.uitk")

if not _cbinspect then
    _cbinspect = function(label)
        return function(...)
            print(os.date("%F %T") .. "::" .. label .. ":: " ..
                          inspect({...}, { newline = " ", indent = "" }))
        end
    end
end

w1 = uitk.window{x = 100, y = 100, h = 500, w = 500 }:show():styleMask(1 | 2 | 4 | 8 )
tbd = uitk.toolbar.dictionary("hsConsoleDuplicate")
tb1 = uitk.toolbar("hsConsoleDuplicate"):canCustomize(true)
                         :notifyOnChange(true)
                         :callback(_cbinspect("toolbar"))


local _c = canvas.new{ x = 0, y = 0, h = 200, w = 200 }
_c[1] = {
    type           = "image",
    image          = image.imageFromName("NSShareTemplate"):template(false),
    transformation = canvas.matrix.translate(100, 100):rotate(180):translate(-100, -100),
}
local _i_reseatConsole = _c:imageFromCanvas()
_c:delete()

local _i_darkModeToggle = image.imageFromASCII("2.........3\n" ..
                                               "...........\n" ..
                                               ".....g.....\n" ..
                                               "...........\n" ..
                                               "1...f.h...4\n" ..
                                               "6...b.c...9\n" ..
                                               "...........\n" ..
                                               "...a...d...\n" ..
                                               "...........\n" ..
                                               "7.........8", {
    { strokeColor = { white = .5 }, fillColor = { alpha = 0.0 }, shouldClose = false },
    { strokeColor = { white = .75 }, fillColor = { alpha = 0.5 }, shouldClose = false },
    { strokeColor = { white = .75 }, fillColor = { alpha = 0.0 }, shouldClose = false },
    { strokeColor = { white = .5 }, fillColor = { alpha = 0.0 }, shouldClose = true },
    {}
})

local colorizeConsolePerDarkMode = function()
    if console.darkMode() then
        console.outputBackgroundColor{ white = 0 }
        console.consoleCommandColor{ white = 1 }
        console.windowBackgroundColor{ list="System", name="windowBackgroundColor" }
        console.alpha(.9)
    else
        -- FYI these are the defaults
        console.outputBackgroundColor{ list="System", name="textBackgroundColor" }
        console.consoleCommandColor{ white = 0 }
        console.windowBackgroundColor{ list="System", name="windowBackgroundColor" }

    --     console.windowBackgroundColor({red=.6,blue=.7,green=.7})
    --     console.outputBackgroundColor({red=.8,blue=.8,green=.8})
        console.alpha(.9)
    end
end

local tbItems = {
  {
    id="prefs",
    label="Preferences",
    image=hs.image.imageFromName("NSPreferencesGeneral"),
    tooltip="Open Preferences",
    callback =function() hs.openPreferences() end
  }, {
    id="reload",
    label="Reload config",
    image=hs.image.imageFromName("NSSynchronize"),
    tooltip="Reload configuration",
    callback =function() hs.reload() end
  }, {
    id="help",
    label="Help",
    image=hs.image.imageFromName("NSInfo"),
    tooltip="Open API docs browser",
    callback =function() hs.doc.hsdocs.help() end
  }, {
    id = "clear",
    image   = image.imageFromName("NSTrashFull"),
    callback = function(...) console.clearConsole() end,
    label   = "Clear",
    tooltip = "Clear Console",
  }, {
    id      = "reseat",
    image   = _i_reseatConsole,
-- centers and reseats window tb is attached to; need to think of more consistent
-- way to identify console given we may have other windows out and about soon...
    callback = function(...)
      local hammerspoon = application.applicationsForBundleID(hs.processInfo.bundleID)[1]
      local consoleWindow = hammerspoon:mainWindow()
      if consoleWindow then
        local consoleFrame = consoleWindow:frame()
        local screenFrame = screen.mainScreen():frame()
        local newConsoleFrame = {
          x = screenFrame.x + (screenFrame.w - consoleFrame.w) / 2,
          y = screenFrame.y + (screenFrame.h - consoleFrame.h),
          w = consoleFrame.w,
          h = consoleFrame.h,
        }
        consoleWindow:setFrame(newConsoleFrame)
      end
    end,
    label   = "Reseat",
    tooltip = "Reseat Console",
  }, {
    id      = "darkMode",
    image   = _i_darkModeToggle,
    callback = function()
      console.darkMode(not console.darkMode())
      colorizeConsolePerDarkMode()
    end,
    label   = "Dark Mode",
    tooltip = "Toggle Dark Mode",
  }
}

for i, v in ipairs(tbItems) do tbd:addItem(v) end
tbd:allowedItems(tbd:definedItems())
tbd:defaultItems{ "prefs", "reload", "help" }

w1:toolbar(tb1)

