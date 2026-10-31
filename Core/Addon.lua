local ADDON, T = ...
local L = T.L

T.ADDON = ADDON
T.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") or "0"

local Addon = CreateFrame("Frame")
T.Addon = Addon

Addon.handlers = {}

-- Modules register interest per event; the frame only listens to what somebody
-- actually asked for.
function Addon:Listen(event, fn)
    local list = self.handlers[event]
    if not list then
        list = {}
        self.handlers[event] = list
        self:RegisterEvent(event)
    end
    list[#list + 1] = fn
end

Addon:SetScript("OnEvent", function(self, event, ...)
    local list = self.handlers[event]
    if not list then return end
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, ...)
        if not ok then geterrorhandler()(err) end
    end
end)

function T.Print(msg, ...)
    if select("#", ...) > 0 then msg = format(msg, ...) end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. L["Wherefrom"] .. "|r: " .. tostring(msg))
end

-- One key per character, so an entry can name who picked the item up. The realm
-- is part of it because connected realms put same-named characters side by side.
function T.CharacterKey()
    return (UnitName("player") or "?") .. "-" .. (GetNormalizedRealmName and GetNormalizedRealmName()
        or GetRealmName() or "?")
end

-- Item links, bag slots and loot slots all hand out something different; the
-- numeric id is the only key the whole addon agrees on.
function T.ItemIDFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("|Hitem:(%d+)"))
end

-- "Creature-0-1234-2444-1234-215781-00003C51A2" -> "Creature", 215781
function T.ParseGUID(guid)
    if type(guid) ~= "string" then return nil end
    local kind = guid:match("^(%a+)%-")
    if not kind then return nil end
    local id = tonumber((select(6, strsplit("-", guid))))
    return kind, id
end

-- Where the player stands right now, as the fallback every source falls back to.
-- Inside an instance the difficulty matters, outside it the subzone is the more
-- telling half of the name.
function T.CurrentPlace()
    local inInstance, instanceType = IsInInstance()
    if inInstance then
        local name, _, difficultyID, difficultyName = GetInstanceInfo()
        return {
            zone = name,
            instance = true,
            instanceType = instanceType,
            difficultyID = difficultyID,
            difficulty = difficultyName ~= "" and difficultyName or nil,
        }
    end

    local zone = GetZoneText()
    local subzone = GetSubZoneText()
    return {
        zone = (zone ~= "" and zone) or nil,
        subzone = (subzone ~= "" and subzone ~= zone and subzone) or nil,
    }
end
