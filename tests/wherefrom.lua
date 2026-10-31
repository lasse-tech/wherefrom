-- Runs inside wow-ui-sim (`make test`). The addon's private table is out of
-- reach here, so the tests drive it through what a player or another addon can
-- see: slash commands, WherefromDB and the tooltip itself.

local HEARTHSTONE = 6948

local function tooltipLines()
    local lines = {}
    for i = 1, GameTooltip:NumLines() do
        local left = _G["GameTooltipTextLeft" .. i]
        local right = _G["GameTooltipTextRight" .. i]
        lines[#lines + 1] = (left and left:GetText() or "") .. "\t" .. (right and right:GetText() or "")
    end
    return table.concat(lines, "\n")
end

-- ClearLines fires OnTooltipCleared, which is where the addon drops its note of
-- what this tooltip was last written for - so the same item can be shown twice.
local function showItem(itemID)
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:ClearLines()
    GameTooltip:SetItemByID(itemID)
    return tooltipLines()
end

test("registers both slash commands", function()
    assertEquals("/wherefrom", SLASH_WHEREFROM1)
    assertEquals("/wf", SLASH_WHEREFROM2)
    assertType("function", SlashCmdList.WHEREFROM)
end)

test("creates SavedVariables with defaults on first login", function()
    assertType("table", WherefromDB)
    assertType("table", WherefromDB.history)
    assertType("table", WherefromDB.journal)
    assertTrue(WherefromDB.profile.showHistory)
    assertFalse(WherefromDB.profile.onlyOnModifier)
end)

-- The whole point of the addon in one test: something recorded in the history
-- has to turn up in that item's tooltip.
test("puts a recorded source into the item tooltip", function()
    WherefromDB.history[HEARTHSTONE] = {
        first = {
            kind = "npc",
            name = "Hogger",
            t = time(),
            char = "Tester-Testrealm",
            zone = "Elwynn Forest",
        },
        last = time(),
        count = 1,
    }

    local text = showItem(HEARTHSTONE)
    assertNotNil(text:find("Obtained", 1, true))
    assertNotNil(text:find("Hogger", 1, true))
    assertNotNil(text:find("Elwynn Forest", 1, true))
end)

test("leaves tooltips of unrecorded items alone", function()
    WherefromDB.history[HEARTHSTONE] = nil

    local text = showItem(HEARTHSTONE)
    assertNil(text:find("Obtained", 1, true))
end)
