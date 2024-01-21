-- based on example at https://www.tothenew.com/blog/nsgridview-a-new-layout-container-for-macos/

local uitk  = require("hs._asm.uitk")

local finspect = function(...) return (require("hs.inspect")({...}):gsub("%s+", " ")) end

local module = {}

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
    { showAlertCheckbox                                   }
})

-- the sides need a little padding
gridView[0][1]._properties.leadingPadding = 5
gridView[0][2]._properties.trailingPadding = 5
-- as does the bottom
gridView[-1]._properties.bottomPadding = 5

--  the first column needs to be right-justified:
gridView[0][1]._properties.placement = "trailing"

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

local gridFittingSize = gridView:fittingSize()
local window = uitk.window.new{
    x = 100,
    y = 100,
    w = gridFittingSize.w,
    h = gridFittingSize.h,
}:styleMask{ "titled", "closable" }:title("Options"):content(gridView):show()

-- each element and menu item could have its own callback, but we can also leverage the passthroughs:
gridView:passthroughCallback(function(...)
    print("container.grid passthrough:", finspect(...))
end)
brailleMenu:passthroughCallback(function(...)
    print("menu passthrough:", finspect(...))
end)

-- all we need to capture to prevent garbage collection is window, but
module.window = window

return module
