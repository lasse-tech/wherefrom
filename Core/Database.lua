local _, T = ...

local DB = {}
T.DB = DB

-- How many differing sources one item keeps besides the first one. Somebody who
-- farms the same reagent from five places does not need five lines in a tooltip.
local MAX_ALSO = 2

local defaults = {
    showHistory = true,
    showSource = true,
    showAppearance = true,
    showDate = true,
    showCharacter = true,
    onlyOnModifier = false,
    indexAllTiers = false,
    trackQuestRewards = true,
    announce = false,
}

function DB:Initialize()
    WherefromDB = WherefromDB or {}
    local db = WherefromDB

    db.profile = db.profile or {}
    for k, v in pairs(defaults) do
        if db.profile[k] == nil then db.profile[k] = v end
    end

    -- Account-wide on purpose: the point of the addon is remembering that an
    -- alt looted the thing three months ago.
    db.history = db.history or {}
    db.journal = db.journal or {}
end

function DB:Profile() return WherefromDB.profile end
function DB:Defaults() return defaults end

function DB:Set(key, value)
    WherefromDB.profile[key] = value
end

-- History ---------------------------------------------------------------------

function DB:History() return WherefromDB.history end

function DB:Entry(itemID) return WherefromDB.history[itemID] end

-- Two records describe the same source when they would print the same line, so
-- that is exactly what the comparison looks at - kind plus whatever names it.
local function sameSource(a, b)
    return a.kind == b.kind and a.name == b.name and a.id == b.id and a.zone == b.zone
end

-- The first record is the answer to "where did this come from" and never moves.
-- Later acquisitions only bump the counter, unless they came from somewhere else
-- - those are worth a line of their own.
function DB:Record(itemID, record, quantity)
    local history = WherefromDB.history
    local entry = history[itemID]

    if not entry then
        history[itemID] = { first = record, last = record.t, count = quantity or 1 }
        return true
    end

    entry.last = record.t
    entry.count = (entry.count or 1) + (quantity or 1)

    if sameSource(entry.first, record) then return false end

    entry.also = entry.also or {}
    for _, other in ipairs(entry.also) do
        if sameSource(other, record) then return false end
    end

    if #entry.also >= MAX_ALSO then table.remove(entry.also, 1) end
    entry.also[#entry.also + 1] = record
    return true
end

function DB:Forget(itemID)
    if not WherefromDB.history[itemID] then return false end
    WherefromDB.history[itemID] = nil
    return true
end

function DB:CountHistory()
    local n = 0
    for _ in pairs(WherefromDB.history) do n = n + 1 end
    return n
end

function DB:ResetHistory()
    WherefromDB.history = {}
end

-- Journal index ---------------------------------------------------------------

-- Rebuilt after a patch, because encounter and item ids move between builds.
-- The build string is the cheapest stamp the client offers for that.
function DB:Journal() return WherefromDB.journal end

function DB:JournalIsCurrent()
    local journal = WherefromDB.journal
    return journal.build == select(2, GetBuildInfo()) and journal.items ~= nil
end

function DB:SetJournal(journal)
    journal.build = select(2, GetBuildInfo())
    WherefromDB.journal = journal
end

function DB:ResetJournal()
    WherefromDB.journal = {}
end
