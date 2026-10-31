local _, T = ...
local KIND = T.Sources.KIND

local Context = {}
T.Context = Context

-- A hint is "the player just did X". Bag changes arrive a moment after the thing
-- that caused them, so each hint carries the moment it was noted and expires on
-- its own. Loot slots get the longest window because a loot window can sit open.
local WINDOW = {
    loot = 20,
    quest = 8,
    vendor = 8,
    mail = 8,
    craft = 8,
    trade = 8,
    guildbank = 8,
    container = 8,
    cast = 8,
}

local hints = {}

-- Names seen for creature GUIDs. Loot only ever hands out the GUID, so the name
-- has to come from somewhere the player looked at recently: the combat log when
-- it died, or the unit frames while it was alive.
local names = {}
local nameOrder = {}
local MAX_NAMES = 60

function Context:RememberName(guid, name)
    if not guid or not name or name == "" then return end
    if names[guid] then return end

    names[guid] = name
    nameOrder[#nameOrder + 1] = guid
    if #nameOrder > MAX_NAMES then
        names[table.remove(nameOrder, 1)] = nil
    end
end

function Context:NameFor(guid) return names[guid] end

-- Hints ------------------------------------------------------------------------

function Context:Set(kind, data)
    data = data or {}
    data.t = GetTime()
    hints[kind] = data
end

function Context:Clear(kind) hints[kind] = nil end

function Context:Get(kind)
    local hint = hints[kind]
    if not hint then return nil end
    -- A hint that is still open (a merchant window, say) never goes stale.
    if not hint.open and GetTime() - hint.t > (WINDOW[kind] or 8) then
        hints[kind] = nil
        return nil
    end
    return hint
end

function Context:Reset()
    wipe(hints)
end

-- Loot slots --------------------------------------------------------------------

-- Read once per loot window: which item sits in which slot, and which GUID it
-- came off. This is the only path that ties a source to a specific item instead
-- of to a moment in time, so it always wins.
function Context:ScanLootSlots()
    local slots = {}

    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local itemID = T.ItemIDFromLink(link)
        if itemID then
            -- AoE-looting several corpses can list more than one source per
            -- slot; the first one is the one the client credits.
            local guid = GetLootSourceInfo(slot)
            slots[itemID] = { guid = guid }
        end
    end

    self:Set("loot", { slots = slots })
end

-- Resolving ----------------------------------------------------------------------

-- Turns a loot GUID into a record. Creatures keep their npc id, world objects
-- have no useful id but do have the name the player just cast "Opening" at, and
-- containers name the item that was opened.
local function fromLootGUID(guid)
    local kind, id = T.ParseGUID(guid)

    if kind == "Creature" or kind == "Vehicle" or kind == "Pet" then
        return T.Sources:Make(KIND.NPC, { name = Context:NameFor(guid), id = id })
    end

    if kind == "GameObject" then
        local cast = Context:Get("cast")
        return T.Sources:Make(KIND.OBJECT, { name = cast and cast.target, id = id })
    end

    if kind == "Item" then
        local opened = Context:Get("container")
        return T.Sources:Make(KIND.CONTAINER, { name = opened and opened.name, id = opened and opened.id })
    end

    return nil
end

-- Everything that is not loot is a "the player was doing X just now" hint. The
-- most recent one wins: opening the mailbox after buying from a vendor means the
-- new item came out of the mail.
local function fromHints()
    local best, bestAt

    local function consider(hint, make)
        if not hint then return end
        if bestAt and hint.t <= bestAt then return end
        best, bestAt = make, hint.t
    end

    local quest = Context:Get("quest")
    consider(quest, quest and function()
        return T.Sources:Make(KIND.QUEST, { name = quest.title, id = quest.questID })
    end)

    local vendor = Context:Get("vendor")
    consider(vendor, vendor and function()
        return T.Sources:Make(KIND.VENDOR, { name = vendor.name })
    end)

    local mail = Context:Get("mail")
    consider(mail, mail and function()
        return T.Sources:Make(mail.auction and KIND.AUCTION or KIND.MAIL, { name = mail.sender })
    end)

    local craft = Context:Get("craft")
    consider(craft, craft and function()
        return T.Sources:Make(KIND.CRAFT, { name = craft.name, id = craft.spellID })
    end)

    local trade = Context:Get("trade")
    consider(trade, trade and function()
        return T.Sources:Make(KIND.TRADE, { name = trade.name })
    end)

    local guildbank = Context:Get("guildbank")
    consider(guildbank, guildbank and function()
        return T.Sources:Make(KIND.GUILDBANK, { name = guildbank.name })
    end)

    local container = Context:Get("container")
    consider(container, container and function()
        return T.Sources:Make(KIND.CONTAINER, { name = container.name, id = container.id })
    end)

    return best and best() or nil
end

-- The record for an item that just appeared in the bags, or nil when even the
-- zone is unknown - which only happens before the world has loaded.
function Context:Resolve(itemID)
    local loot = self:Get("loot")
    local slot = loot and loot.slots and loot.slots[itemID]
    if slot and slot.guid then
        local record = fromLootGUID(slot.guid)
        if record then return record end
    end

    local record = fromHints()
    if record then return record end

    local place = T.CurrentPlace()
    if not place.zone then return nil end
    return T.Sources:Make(KIND.PLACE)
end
