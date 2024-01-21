local uitk  = require("hs._asm.uitk")
local image = require("hs.image")
local stext = require("hs.styledtext")

local finspect = function(...) return (require("hs.inspect")({...}):gsub("%s+", " ")) end

local module = {}

local win = uitk.window{ x = 100, y = 100, h = 550, w = 500 }
                :styleMask{ "titled", "closable", "miniaturizable" }
                :show()

local tabs = uitk.element.container.tabs():passthroughCallback(function(...)
    print("tabs passthrough", finspect(...))
end):callback(function(...) print("tabs", finspect(...)) end)
win:content(tabs)

local contentRect = tabs:contentRect()

-- tab 1
local buttonGroup = uitk.element.container(contentRect)
local types = {
    "momentaryLight",
    "toggle",
    "switch",
    "radio",
    "momentaryChange",
    "multiLevelAccelerator",
    "onOff",
    "pushOnPushOff",
    "accelerator",
    "momentaryPushIn"
}

for i, v in ipairs(types) do
    buttonGroup[#buttonGroup + 1] = uitk.element.button.buttonType(v):title(v):alternateTitle("not " .. v):tooltip("button type " .. v)
end

local lastFrame = buttonGroup[#buttonGroup]._properties.containerFrame._effective

buttonGroup[#buttonGroup + 1] = {
    _self          = uitk.element.button.buttonWithImage(image.imageFromName(image.systemImageNames.ApplicationIcon)),
    containerFrame = { y = lastFrame.y + 2 * lastFrame.h }
}
buttonGroup[#buttonGroup + 1] = uitk.element.button.buttonWithTitle("buttonWithTitle")
buttonGroup[#buttonGroup + 1] = uitk.element.button.buttonWithTitleAndImage("buttonWithTitleAndImage", image.imageFromName(image.systemImageNames.ApplicationIcon))
buttonGroup[#buttonGroup + 1] = uitk.element.button.checkbox("checkbox")
buttonGroup[#buttonGroup + 1] = uitk.element.button.radioButton("radioButton")

-- radio buttons within the same view (container element) only allow one at a time to be selected (they automatically
-- unselect the others) to have multiple sets of radio buttons they need to be in different views
local radio = uitk.element.container():tooltip("grouped radiobuttons")
radio:insert(uitk.element.button.radioButton("A"):tooltip("A"))
radio:insert(uitk.element.button.radioButton("B"):tooltip("not A"))
radio:insert(uitk.element.button.radioButton("C"):tooltip("also not A"))
-- then add the new view to the main one just like any other element
buttonGroup:insert(radio, { x = 200, y = 200 })
buttonGroup:sizeToFit(20, 10)

-- tab2
-- A simple menu for example purposes
local brailleMenu = uitk.menu("popUpMenu")
for i = 1, 10, 1 do
    brailleMenu[#brailleMenu + 1] = { title = "Choice " .. tostring(i), }
end

local brailleTranslationLabel    = uitk.element.textField.newLabel("Braille Translation:")
local brailleTranslationPopup    = uitk.element.popUpButton(brailleMenu)
local showContractedCheckbox     = uitk.element.button.checkbox("Show contracted braille")
local showEightDotCheckbox       = uitk.element.button.checkbox("Show eight-dot braille")
local statusCellsLabel           = uitk.element.textField.newLabel("Status Cells:")
local showGeneralDisplayCheckbox = uitk.element.button.checkbox("Show general display status")
local textStyleCheckbox          = uitk.element.button.checkbox("Show text style")
local showAlertCheckbox          = uitk.element.button.checkbox("Show alert messages for duration")

-- create grid view
local gridView = uitk.element.container.grid({
    { brailleTranslationLabel, brailleTranslationPopup    },
    { false,                   showContractedCheckbox     },
    { false,                   showEightDotCheckbox       },
    { statusCellsLabel,        showGeneralDisplayCheckbox },
    { false,                   textStyleCheckbox          },
    { showAlertCheckbox                                   },
    { false,                   false                      }
})

-- the sides need a little padding
gridView[0][1]._properties.leadingPadding = 5
gridView[0][2]._properties.trailingPadding = 5
-- as does the bottom
gridView[-2]._properties.bottomPadding = 5

--  the first column needs to be right-justified:
gridView[0][1]._properties = {
    placement = "trailing",
    width     = contentRect.w / 2,
}

--  all cells use firstBaseline alignment
gridView:alignment("firstBaseline")

-- We need a little extra vertical space around the popup:
local adjRow = gridView:cellForElement(brailleTranslationPopup):row()._properties
adjRow.topPadding = 5
adjRow.bottomPadding = 5

-- and statusCells row...
adjRow = gridView:cellForElement(statusCellsLabel):row()._properties
adjRow.topPadding = 6

-- Special treatment for centered checkbox:
adjRow = gridView:cellForElement(showAlertCheckbox):row()._properties
adjRow.topPadding = 4
adjRow._self:mergeCells(1,2)
adjRow[1].columnPlacement = "center"

-- bottom "filler" row ensures the grid displays at the top of the view without
-- automatically introducing extra spacing
local fittingSize = gridView:fittingSize() -- get this before setting anything for filler row
gridView[-1]._properties.height = contentRect.h - fittingSize.h

local textfields = uitk.element.container(contentRect):passthroughCallback(function(...) print("textfields:", finspect(...)) end)
textfields[1] = {
    _self          = uitk.element.textField.newLabel("textField"),
    containerFrame = { x = 75, y = 20, w = 100 },
}
textfields[2] = {
    _self          = uitk.element.textField.newTextField(),
    containerFrame = { w = 200 },
}
textfields[2]:position("after", textfields[1])

textfields[3] = {
    _self          = uitk.element.textField.newLabel("secure"),
    containerFrame = { w = 100 },
}
textfields[4] = {
    _self          = uitk.element.textField.secure(),
    containerFrame = { w = 200 },
}
textfields[3]:position("below", textfields[1], 15)
textfields[4]:position("after", textfields[3])

textfields[5] = {
    _self          = uitk.element.textField.newLabel("comboBox"),
    containerFrame = { w = 100 },
}
textfields[6] = {
    _self          = uitk.element.textField.comboBox(),
    containerFrame = { w = 200 },
}
textfields[5]:position("below", textfields[3], 15)
textfields[6]:position("after", textfields[5])

local searchMenu = uitk.menu("searchMenu")
searchMenu[#searchMenu + 1] = {
    title    = stext.new("Recent Search Items", { font = { name = ".AppleSystemUIFontItalic", size = 13.0 } }),
    -- only appear when there *are* items in the history
    tag      = uitk.element.textField.searchField.recentMenuConstants.recentsTitle,
    enabled  = false, -- we don't want them to actually select it...
    -- or we could do this and it would be the same color as other items, but selectable
    -- callback = function() end,
}

searchMenu[#searchMenu + 1] = {
    title = "Items",
    -- the items themselves
    tag   = uitk.element.textField.searchField.recentMenuConstants.recentItems,
    indentationLevel = 2,
}

searchMenu[#searchMenu + 1] = {
    title   = stext.new("No Recent Searches", { font = { name = ".AppleSystemUIFontItalic", size = 13.0 } }),
    -- displayed when there are *no* items in the history
    tag     = uitk.element.textField.searchField.recentMenuConstants.noRecentItems,
    enabled = false, -- we don't want them to actually select it...
}

searchMenu[#searchMenu + 1] = {
    title = "-",
    tag   = uitk.element.textField.searchField.recentMenuConstants.recentsTitle, -- also applies to this separator
}

searchMenu[#searchMenu + 1] = {
    title = stext.new("Clear History", { font = { name = ".AppleSystemUIFontItalic", size = 13.0 } }),
    -- clear the history -- only appears when there are items in the history
    tag   = uitk.element.textField.searchField.recentMenuConstants.clearRecents,
}

searchMenu[#searchMenu + 1] = { title = "-" }

searchMenu[#searchMenu + 1] = {
    title = "Other thing",
}

searchMenu[#searchMenu + 1] = {
    title = "Yet Another thing",
}

textfields[7] = {
    _self          = uitk.element.textField.newLabel("searchField"),
    containerFrame = { w = 100 },
}
textfields[8] = {
    _self             = uitk.element.textField.searchField(),
    containerFrame    = { w = 300 },
    menu              = searchMenu,
    sendsWhenComplete = true,
}
textfields[7]:position("below", textfields[5], 15)
textfields[8]:position("after", textfields[7])


-- insert tabs into container

tabs[1] = {
    _self   = uitk.element.container.tabs.newItem():label("Buttons"),
    element = buttonGroup,
}

tabs[2] = {
    _self   = uitk.element.container.tabs.newItem():label("Grid"),
    element = gridView,
}

tabs[3] = {
    _self   = uitk.element.container.tabs.newItem():label("Progress"),
    element = uitk.element.progress():circular(true):frameSize(contentRect):start(),
}

tabs[4] = {
    _self   = uitk.element.container.tabs.newItem():label("Player"),
    element = uitk.element.avplayer(contentRect):controlsStyle("inline")
                                                :load("http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8")
                                                :pauseWhenHidden(true)
}

tabs[5] = {
    _self   = uitk.element.container.tabs.newItem():label("textField"),
    element = textfields,
}

module.win = win
return module
