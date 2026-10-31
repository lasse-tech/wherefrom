local _, T = ...
local L = T.L
local KIND = T.Sources.KIND

local Format = {}
T.Format = Format

Format.LABEL_COLOR = { 1.0, 0.82, 0.0 }
Format.VALUE_COLOR = { 1.0, 1.0, 1.0 }
Format.DETAIL_COLOR = { 0.6, 0.6, 0.6 }

-- One phrase per source kind. The name is whatever the capture managed to catch;
-- when it caught nothing, the kind alone still says something useful.
local PHRASE = {
    [KIND.NPC]       = { named = "%s",                  bare = L["An enemy"] },
    [KIND.OBJECT]    = { named = "%s",                  bare = L["A world object"] },
    [KIND.CONTAINER] = { named = L["Out of %s"],        bare = L["Out of a container"] },
    [KIND.QUEST]     = { named = L["Quest: %s"],        bare = L["A quest reward"] },
    [KIND.VENDOR]    = { named = L["Bought from %s"],   bare = L["Bought from a vendor"] },
    [KIND.MAIL]      = { named = L["Mail from %s"],     bare = L["Mail"] },
    [KIND.AUCTION]   = { named = L["Auction house"],    bare = L["Auction house"] },
    [KIND.CRAFT]     = { named = L["Crafted: %s"],      bare = L["Crafted"] },
    [KIND.TRADE]     = { named = L["Traded by %s"],     bare = L["Traded by another player"] },
    [KIND.GUILDBANK] = { named = L["Guild bank of %s"], bare = L["Guild bank"] },
}

-- "Nexus-King Salhadaar", "Bought from Provisioner Aelsa", "Picked up"
function Format:SourceLine(record)
    local phrase = PHRASE[record.kind]
    if not phrase then return L["Picked up"] end
    if not record.name then return phrase.bare end
    -- The auction house phrase ignores its sender, so it has no %s to fill.
    if not phrase.named:find("%%s") then return phrase.named end
    return phrase.named:format(record.name)
end

-- "Manaforge Omega (Mythic)" or "Tanaris - Steamwheedle Port". Nil when the
-- record predates knowing where the player stood.
function Format:PlaceLine(record)
    if not record.zone then return nil end
    if record.difficulty then
        return ("%s (%s)"):format(record.zone, record.difficulty)
    end
    if record.sub then
        return ("%s - %s"):format(record.zone, record.sub)
    end
    return record.zone
end

-- Blizzard's own short date, so the order of day and month follows the client.
function Format:Date(timestamp)
    if not timestamp then return nil end
    local d = date("*t", timestamp)
    if FormatShortDate then return FormatShortDate(d.day, d.month, d.year) end
    return ("%02d.%02d.%04d"):format(d.day, d.month, d.year)
end

-- Own realm characters read better without the realm hanging off them.
function Format:Character(key)
    if not key then return nil end
    local own = T.CharacterKey()
    if key == own then return (key:match("^(.-)%-")) or key end
    return (key:gsub("%-", " - "))
end

-- The grey second line under a source: where, when, and who. Each part is
-- switchable, and with all of them off there is no line at all.
function Format:DetailLine(record, profile)
    local parts = {}

    local place = self:PlaceLine(record)
    if place then parts[#parts + 1] = place end

    if profile.showDate then
        local when = self:Date(record.t)
        if when then parts[#parts + 1] = when end
    end

    if profile.showCharacter then
        local who = self:Character(record.char)
        if who then parts[#parts + 1] = who end
    end

    if #parts == 0 then return nil end
    return table.concat(parts, " - ")
end

-- "Nexus-King Salhadaar (Manaforge Omega)", joined for several encounters.
function Format:JournalLine(hits)
    local parts = {}

    for _, hit in ipairs(hits) do
        if hit.instance then
            parts[#parts + 1] = ("%s (%s)"):format(hit.encounter, hit.instance)
        else
            parts[#parts + 1] = hit.encounter
        end
    end

    return table.concat(parts, ", ")
end
