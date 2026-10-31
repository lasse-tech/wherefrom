local _, T = ...
local DB = T.DB
local Context = T.Context
local KIND = T.Sources.KIND

local Capture = {}
T.Capture = Capture

local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetContainerItemInfo = C_Container.GetContainerItemInfo

-- Only the bags the player carries. The bank is storage, not an acquisition, so
-- what sits in it is none of this addon's business.
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4

local FIRST_SLOT = INVSLOT_FIRST_EQUIPPED or 1
local LAST_SLOT = INVSLOT_LAST_EQUIPPED or 19

local counts = {}
local primed = false

-- Worn gear is counted alongside the bags. Taking a weapon off puts it in a bag
-- and would otherwise look exactly like acquiring it; counted together, the two
-- halves cancel out and only a real gain shows up.
local function snapshot(into)
    wipe(into)

    for bag = BACKPACK_CONTAINER or 0, LAST_BAG do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            local info = GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                into[info.itemID] = (into[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end

    for slot = FIRST_SLOT, LAST_SLOT do
        local itemID = GetInventoryItemID("player", slot)
        if itemID then into[itemID] = (into[itemID] or 0) + 1 end
    end
end

-- Recording ---------------------------------------------------------------------

function Capture:Note(itemID, quantity)
    if not itemID then return end

    local record = Context:Resolve(itemID)
    if not record then return end

    local isNew = DB:Record(itemID, record, quantity)

    if DB:Profile().announce then
        local name = C_Item.GetItemNameByID(itemID) or itemID
        T.Print("%s x%d - %s", tostring(name), quantity or 1, T.Format:SourceLine(record))
    end

    return isNew
end

-- Bag diff -----------------------------------------------------------------------

local previous = {}

local function diff()
    -- BAG_UPDATE_DELAYED fires before PLAYER_LOGIN, when there is no database to
    -- write to yet. The bank is skipped for a different reason: pulling
    -- something out of storage is not getting it from anywhere.
    if not T.Addon.loaded then return end
    if Context:Get("bank") then return end

    snapshot(counts)

    if not primed then
        primed = true
        previous, counts = counts, previous
        return
    end

    for itemID, now in pairs(counts) do
        local before = previous[itemID] or 0
        if now > before then
            Capture:Note(itemID, now - before)
        end
    end

    previous, counts = counts, previous
end

-- The bags settle a frame or two after the event that filled them, which is what
-- BAG_UPDATE_DELAYED is for: one diff per batch instead of one per slot.
T.Addon:Listen("BAG_UPDATE_DELAYED", diff)

-- Zoning reloads the bag contents from scratch, so the next diff would see every
-- item as new. Drop the baseline and re-prime instead.
T.Addon:Listen("PLAYER_ENTERING_WORLD", function()
    primed = false
    Context:Reset()
end)

-- Hints ---------------------------------------------------------------------------

local function rememberUnit(unit)
    Context:RememberName(UnitGUID(unit), UnitName(unit))
end

-- A corpse about to be looted is almost always the player's target, and the
-- name is needed before the loot is read.
T.Addon:Listen("LOOT_READY", function()
    rememberUnit("target")
    Context:ScanLootSlots()
end)
T.Addon:Listen("LOOT_OPENED", function()
    rememberUnit("target")
    Context:ScanLootSlots()
end)

-- The name of a chest, ore vein or herb is not in the loot data, but it is the
-- target of the "Opening"/gathering cast the player just finished.
T.Addon:Listen("UNIT_SPELLCAST_SENT", function(unit, target, _, spellID)
    if unit ~= "player" then return end
    if not target or target == "" then return end
    Context:Set("cast", { target = target, spellID = spellID })
end)

-- Creature names are collected while the client still knows the unit: by the
-- time its loot is read, it is gone. UNIT_DIED from the combat log would be the
-- precise source, but 12.0 made COMBAT_LOG_EVENT_UNFILTERED restricted - an
-- addon that registers it has the call blocked outright - so what the player
-- targeted or hovered has to carry it.
T.Addon:Listen("PLAYER_TARGET_CHANGED", function() rememberUnit("target") end)
T.Addon:Listen("UPDATE_MOUSEOVER_UNIT", function() rememberUnit("mouseover") end)

T.Addon:Listen("QUEST_TURNED_IN", function(questID)
    if not DB:Profile().trackQuestRewards then return end
    Context:Set("quest", {
        questID = questID,
        title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or nil,
    })
end)

-- Fires per rewarded item and names it outright, so it does not have to wait for
-- the bag diff to guess.
T.Addon:Listen("QUEST_LOOT_RECEIVED", function(questID, itemLink, quantity)
    if not T.Addon.loaded then return end
    if not DB:Profile().trackQuestRewards then return end
    local itemID = T.ItemIDFromLink(itemLink)
    if not itemID then return end
    DB:Record(itemID, T.Sources:Make(KIND.QUEST, {
        id = questID,
        name = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or nil,
    }), quantity)
end)

T.Addon:Listen("MERCHANT_SHOW", function()
    Context:Set("vendor", { name = UnitName("npc"), open = true })
end)

T.Addon:Listen("MERCHANT_CLOSED", function()
    local vendor = Context:Get("vendor")
    if vendor then vendor.open = nil; vendor.t = GetTime() end
end)

T.Addon:Listen("TRADE_SHOW", function()
    Context:Set("trade", { name = UnitName("NPC"), open = true })
end)

T.Addon:Listen("TRADE_CLOSED", function()
    local trade = Context:Get("trade")
    if trade then trade.open = nil; trade.t = GetTime() end
end)

T.Addon:Listen("BANKFRAME_OPENED", function()
    Context:Set("bank", { open = true })
end)

T.Addon:Listen("BANKFRAME_CLOSED", function()
    Context:Clear("bank")
    -- The bags settle after the window closes; re-prime so the moves made in
    -- there are not read as a gain.
    primed = false
end)

T.Addon:Listen("GUILDBANKFRAME_OPENED", function()
    Context:Set("guildbank", { name = GetGuildInfo("player"), open = true })
end)

T.Addon:Listen("GUILDBANKFRAME_CLOSED", function()
    local bank = Context:Get("guildbank")
    if bank then bank.open = nil; bank.t = GetTime() end
end)

-- A finished cast is a craft when the client can name a recipe for it. That test
-- also keeps ordinary spells from claiming whatever lands in the bags next.
T.Addon:Listen("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" or not spellID then return end

    local recipe = C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo
        and C_TradeSkillUI.GetRecipeInfo(spellID)
    if not (recipe and recipe.name) then return end

    Context:Set("craft", { name = recipe.name, spellID = spellID })
end)

-- Hooks ------------------------------------------------------------------------------

-- Mail and containers have no event that names what was taken, so these run off
-- the calls the UI makes. hooksecurefunc leaves the originals untouched.
function Capture:InstallHooks()
    local function noteMail(index)
        local _, _, sender = GetInboxHeaderInfo(index)
        -- An invoice means the auction house sent it, whatever the sender reads
        -- as in this client's language.
        local invoice = GetInboxInvoiceInfo and GetInboxInvoiceInfo(index)
        Context:Set("mail", { sender = sender, auction = invoice ~= nil or nil })
    end

    hooksecurefunc("TakeInboxItem", noteMail)
    if AutoLootMailItem then hooksecurefunc("AutoLootMailItem", noteMail) end

    hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot)
        local info = GetContainerItemInfo(bag, slot)
        if not (info and info.itemID) then return end
        Context:Set("container", {
            id = info.itemID,
            name = C_Item.GetItemNameByID(info.itemID),
        })
    end)
end
