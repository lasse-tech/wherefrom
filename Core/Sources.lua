local _, T = ...

local Sources = {}
T.Sources = Sources

-- Every way an item can enter the bags that the client lets us tell apart. The
-- strings are stored in SavedVariables, so they are part of the file format and
-- must not be renamed without a migration.
Sources.KIND = {
    NPC       = "npc",        -- looted from a creature
    OBJECT    = "object",     -- looted from a chest, node or other world object
    CONTAINER = "container",  -- opened a bag, box or lockbox
    QUEST     = "quest",      -- quest reward
    VENDOR    = "vendor",     -- bought from a merchant
    MAIL      = "mail",       -- taken out of the mailbox
    AUCTION   = "auction",    -- mail from the auction house
    CRAFT     = "craft",      -- made by a profession
    TRADE     = "trade",      -- traded by another player
    GUILDBANK = "guildbank",  -- withdrawn from the guild bank
    PLACE     = "place",      -- nothing more specific than where it happened
}

-- A record always carries the place and the moment; the kind decides which of
-- name/id mean anything on top of that. Callers pass only what they know.
function Sources:Make(kind, fields)
    local place = T.CurrentPlace()
    local record = {
        kind = kind,
        t = time(),
        char = T.CharacterKey(),
        zone = place.zone,
        sub = place.subzone,
        difficulty = place.difficulty,
        instance = place.instance or nil,
    }

    if fields then
        for k, v in pairs(fields) do record[k] = v end
    end

    return record
end
