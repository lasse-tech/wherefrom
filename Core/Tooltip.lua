local _, T = ...
local L = T.L
local DB = T.DB
local Format = T.Format

local Tooltip = {}
T.Tooltip = Tooltip

local LABEL = Format.LABEL_COLOR
local VALUE = Format.VALUE_COLOR
local DETAIL = Format.DETAIL_COLOR

-- Past this, a value on the right would stretch the tooltip wider than the item
-- text it belongs to. It counts bytes rather than characters, which only makes
-- the threshold a little stricter for accented text - fine for a layout guess.
local WRAP_AT = 44

-- Short values sit on the right of the label; long ones - a boss list, a source
-- sentence Blizzard wrote - get their own wrapped line underneath.
local function label(tooltip, text, value)
    if #value > WRAP_AT then
        tooltip:AddLine(text, LABEL[1], LABEL[2], LABEL[3])
        tooltip:AddLine("   " .. value, VALUE[1], VALUE[2], VALUE[3], true)
        return
    end
    tooltip:AddDoubleLine(text, value, LABEL[1], LABEL[2], LABEL[3], VALUE[1], VALUE[2], VALUE[3])
end

local function detail(tooltip, text)
    tooltip:AddLine("   " .. text, DETAIL[1], DETAIL[2], DETAIL[3], true)
end

-- Building the block ----------------------------------------------------------

-- Returns true when anything was written, so the blank separator line is only
-- spent on tooltips that actually gained something.
local function addHistory(tooltip, itemID, profile)
    if not profile.showHistory then return false end

    local entry = DB:Entry(itemID)
    if not entry then return false end

    label(tooltip, L["Obtained"], Format:SourceLine(entry.first))

    local line = Format:DetailLine(entry.first, profile)
    if line then detail(tooltip, line) end

    for _, other in ipairs(entry.also or {}) do
        label(tooltip, L["Also from"], Format:SourceLine(other))
        local otherLine = Format:DetailLine(other, profile)
        if otherLine then detail(tooltip, otherLine) end
    end

    return true
end

local function addJournal(tooltip, itemID, profile)
    if not profile.showSource then return false end

    local hits = T.Journal:Lookup(itemID)
    if not hits then return false end

    label(tooltip, L["Drops from"], Format:JournalLine(hits))
    return true
end

-- Blizzard's own source text is the coarse fallback: "Boss Drop" adds nothing
-- once the journal has named the boss.
local function addOrigin(tooltip, itemID, profile)
    if not profile.showAppearance then return false end

    local text = T.Origin:Describe(itemID)
    if not text then return false end

    label(tooltip, L["Source"], text)
    return true
end

-- Wiring ------------------------------------------------------------------------

-- The post call fires again every time a tooltip refreshes itself, so the item
-- it was last written for is remembered and a repeat is skipped. The note is
-- kept here, keyed by the tooltip, rather than as a field on the frame itself:
-- a field of our own on a Blizzard frame carries this addon's taint into
-- whatever touches it. Weak keys, so a tooltip that goes away is not held.
local written = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })

local function alreadyDone(tooltip, itemID)
    if written[tooltip] == itemID then return true end
    written[tooltip] = itemID

    if not hooked[tooltip] then
        hooked[tooltip] = true
        tooltip:HookScript("OnTooltipCleared", function(self) written[self] = nil end)
    end

    return false
end

local function onItemTooltip(tooltip, data)
    local itemID = data and data.id
    if not itemID then return end

    local profile = DB:Profile()
    if profile.onlyOnModifier and not IsShiftKeyDown() then return end
    if alreadyDone(tooltip, itemID) then return end

    local wrote = addHistory(tooltip, itemID, profile)
    local journal = addJournal(tooltip, itemID, profile)
    local origin = not journal and addOrigin(tooltip, itemID, profile)

    if wrote or journal or origin then tooltip:Show() end
end

function Tooltip:Initialize()
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall) then
        T.Print(L["This client is too old for the tooltip API this addon needs."])
        return
    end

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItemTooltip)

    -- With the modifier option on, holding shift has to redraw what is already
    -- under the cursor instead of waiting for the next hover.
    T.Addon:Listen("MODIFIER_STATE_CHANGED", function(key)
        if not DB:Profile().onlyOnModifier then return end
        if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
        if not (GameTooltip:IsShown() and GameTooltip.RefreshData) then return end
        written[GameTooltip] = nil
        GameTooltip:RefreshData()
    end)
end
