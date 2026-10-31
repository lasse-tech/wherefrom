local _, T = ...
local L = T.L
local DB = T.DB

local Journal = {}
T.Journal = Journal

-- How many encounters one frame is allowed to read. The scan walks every boss of
-- every instance, so it has to be spread out or the client stutters through it.
local PER_TICK = 4

local running, queue, index, progress

-- The loot list the journal hands back is filtered by class, spec and slot the
-- way the player last left it. For an index we want all of it, so the filters go
-- wide for the scan and back afterwards.
local saved

local function openFilters()
    if saved then return end
    saved = { EJ_GetLootFilter() }

    EJ_SetLootFilter(0, 0)
    if C_EncounterJournal and C_EncounterJournal.SetSlotFilter then
        C_EncounterJournal.SetSlotFilter(Enum.ItemSlotFilterType.NoFilter)
    end
end

local function restoreFilters()
    if not saved then return end
    EJ_SetLootFilter(saved[1] or 0, saved[2] or 0)
    saved = nil
end

-- Building ----------------------------------------------------------------------

local function addItem(itemID, encounterID)
    local current = index.items[itemID]

    if current == nil then
        index.items[itemID] = encounterID
    elseif type(current) == "number" then
        if current ~= encounterID then index.items[itemID] = { current, encounterID } end
    else
        for _, id in ipairs(current) do
            if id == encounterID then return end
        end
        current[#current + 1] = encounterID
    end
end

local function readEncounter(job)
    EJ_SelectInstance(job.instanceID)
    EJ_SelectEncounter(job.encounterID)

    local n = EJ_GetNumLoot() or 0
    if n == 0 then return end

    index.encounters[job.encounterID] = { name = job.name, instance = job.instanceID }

    for i = 1, n do
        local loot = C_EncounterJournal.GetLootInfoByIndex(i)
        if loot and loot.itemID then addItem(loot.itemID, job.encounterID) end
    end
end

local function collectInstances(tier, isRaid)
    EJ_SelectTier(tier)

    local i = 1
    while true do
        local instanceID, name = EJ_GetInstanceByIndex(i, isRaid)
        if not instanceID then break end

        index.instances[instanceID] = { name = name, raid = isRaid or nil }

        EJ_SelectInstance(instanceID)
        local j = 1
        while true do
            local encounterName, _, encounterID = EJ_GetEncounterInfoByIndex(j, instanceID)
            if not encounterID then break end
            queue[#queue + 1] = { instanceID = instanceID, encounterID = encounterID, name = encounterName }
            j = j + 1
        end

        i = i + 1
    end
end

local function finish()
    restoreFilters()

    DB:SetJournal(index)

    running = nil
    queue = nil

    local n = 0
    for _ in pairs(index.items) do n = n + 1 end
    T.Print(L["Indexed %d items from %d encounters."], n, progress or 0)
end

local function step()
    for _ = 1, PER_TICK do
        local job = table.remove(queue)
        if not job then
            running:Cancel()
            finish()
            return
        end

        local ok, err = pcall(readEncounter, job)
        if not ok then geterrorhandler()(err) end
        progress = (progress or 0) + 1
    end
end

-- Scanning moves the journal's own selection around, so it stays out of the way
-- while the player has the journal open.
function Journal:Build(force)
    if running then return end
    if not force and DB:JournalIsCurrent() then return end

    if EncounterJournal and EncounterJournal:IsShown() then
        T.Print(L["Close the Adventure Guide first - the scan uses it."])
        return
    end

    if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_EncounterJournal") end
    if not (EJ_GetNumTiers and C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex) then
        T.Print(L["The Adventure Guide is not available in this client."])
        return
    end

    index = { items = {}, encounters = {}, instances = {} }
    queue, progress = {}, 0
    openFilters()

    local tiers = EJ_GetNumTiers() or 0
    local currentTier = (EJ_GetCurrentTier and EJ_GetCurrentTier()) or tiers
    local first, last = currentTier, currentTier
    if DB:Profile().indexAllTiers then first, last = 1, tiers end

    for tier = first, last do
        collectInstances(tier, false)
        collectInstances(tier, true)
    end

    EJ_SelectTier(currentTier)

    T.Print(L["Indexing %d encounters..."], #queue)
    running = C_Timer.NewTicker(0, step)
end

-- Lookup -------------------------------------------------------------------------

-- Returns a list of { encounter, instance, raid } for an item, newest tier first
-- as the journal listed them, or nil when the index does not know it.
function Journal:Lookup(itemID)
    local journal = DB:Journal()
    local entry = journal.items and journal.items[itemID]
    if not entry then return nil end

    local ids = type(entry) == "number" and { entry } or entry
    local out = {}

    for _, encounterID in ipairs(ids) do
        local encounter = journal.encounters[encounterID]
        local instance = encounter and journal.instances[encounter.instance]
        if encounter then
            out[#out + 1] = {
                encounter = encounter.name,
                instance = instance and instance.name,
                raid = instance and instance.raid,
            }
        end
    end

    return #out > 0 and out or nil
end

function Journal:IsRunning() return running ~= nil end
