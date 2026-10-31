local _, T = ...

local Origin = {}
T.Origin = Origin

-- What the client itself already knows about where an item comes from, without
-- any data of ours. Three collections carry a ready-made, localised source line,
-- and transmog knows at least the category for anything wearable.

-- Mounts, battle pets and heirlooms ship a source string Blizzard wrote - the
-- same one their own tooltips show. Nothing beats that, so it is checked first.
local function collectionSource(itemID)
    if C_MountJournal and C_MountJournal.GetMountFromItem then
        local mountID = C_MountJournal.GetMountFromItem(itemID)
        if mountID then
            local source = select(3, C_MountJournal.GetMountInfoExtraByID(mountID))
            if source and source ~= "" then return source end
        end
    end

    if C_PetJournal and C_PetJournal.GetPetInfoByItemID then
        local source = select(5, C_PetJournal.GetPetInfoByItemID(itemID))
        if source and source ~= "" then return source end
    end

    if C_Heirloom and C_Heirloom.GetHeirloomInfo then
        local source = select(6, C_Heirloom.GetHeirloomInfo(itemID))
        if source and source ~= "" then return source end
    end

    return nil
end

-- Transmog files every appearance under a source type - boss drop, quest, vendor
-- and so on. It is coarse, but it covers all of gear and it is right by
-- definition. TRANSMOG_SOURCE_<n> is the client's own wording for each type.
local function appearanceSource(itemID)
    if not (C_TransmogCollection and C_TransmogCollection.GetItemInfo) then return nil end

    local _, sourceID = C_TransmogCollection.GetItemInfo(itemID)
    if not sourceID then return nil end

    local info = C_TransmogCollection.GetSourceInfo(sourceID)
    local sourceType = info and info.sourceType
    if not sourceType then return nil end

    return _G["TRANSMOG_SOURCE_" .. sourceType]
end

-- A single line, or nil. Cached per item because tooltips ask over and over
-- while the cursor rests on one and none of these answers change in a session.
local cache = {}

function Origin:Describe(itemID)
    if not itemID then return nil end

    local cached = cache[itemID]
    if cached ~= nil then
        return cached or nil
    end

    local text = collectionSource(itemID) or appearanceSource(itemID)
    cache[itemID] = text or false
    return text
end
