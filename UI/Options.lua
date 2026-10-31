local ADDON, T = ...
local L = T.L
local DB = T.DB

local Options = {}
T.Options = Options

local category, layout

local ABOUT_TEMPLATE = "WherefromAboutTemplate"
local ABOUT_FONT = "GameFontHighlight"
local CHIP_PAD_X, CHIP_PAD_Y = 10, 5
local ABOUT_BOTTOM_PAD = 12

-- Kept in the TOC rather than here, so the TOC stays the single source for
-- author, version and copyright.
local function metadata(field)
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local value = get and get(ADDON, field)
    if value == "" then return nil end
    return value
end

local function aboutText()
    local lines = {}

    local author = metadata("Author")
    if author then lines[#lines + 1] = L["Author: %s"]:format(author) end

    local website = metadata("X-Website")
    if website then lines[#lines + 1] = L["More: %s"]:format((website:gsub("^%a+://", ""))) end

    local mail = metadata("X-Email")
    if mail then lines[#lines + 1] = L["Contact: %s"]:format(mail) end

    local version = metadata("Version")
    if version then lines[#lines + 1] = L["Version: %s"]:format(version) end

    local copyright = metadata("X-Copyright")
    local license = metadata("X-License")
    if copyright then
        lines[#lines + 1] = license and ("%s - %s"):format(copyright, license) or copyright
    end

    return table.concat(lines, "\n")
end

-- The chip -----------------------------------------------------------------------

WherefromAboutMixin = {}

function WherefromAboutMixin:OnLoad()
    local chip = self.Chip
    chip:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    chip:SetBackdropColor(0.10, 0.12, 0.18, 0.9)
    chip:SetBackdropBorderColor(0.30, 0.35, 0.50, 1)
    -- A red heart between two plain words, so the chip reads the same whatever
    -- the interface language is.
    chip.Text:SetText(L["Made with"] .. " |cffff5a5a\226\153\165|r " .. L["in Europe"])
    chip:SetSize(chip.Text:GetStringWidth() + CHIP_PAD_X * 2,
        chip.Text:GetStringHeight() + CHIP_PAD_Y * 2)
end

function WherefromAboutMixin:Init(initializer)
    self.Text:SetText(initializer:GetData().text)
end

-- Blizzard's SettingsListMixin lays the list out with a ScrollBox: an element's
-- height is initializer:GetExtent(), or the template's own height when that is
-- nil. We measure the text and add what the chip below it needs.
-- The ruler hangs on a frame of this addon's own, never on UIParent: a region
-- created on UIParent taints it, and the next protected code to touch UIParent
-- is blocked - which the client reports as this addon at login.
local measure

local function textHeight(text)
    if not measure then
        local ruler = CreateFrame("Frame")
        ruler:Hide()
        measure = ruler:CreateFontString(nil, "ARTWORK", ABOUT_FONT)
        measure:SetJustifyH("LEFT")
    end
    measure:SetText(text)
    return measure:GetStringHeight()
end

local function addAbout(text)
    if not Settings.CreateElementInitializer then return end
    if not text or text == "" then return end

    local initializer = Settings.CreateElementInitializer(ABOUT_TEMPLATE, { text = text })
    local chipHeight = select(2, GameFontNormalSmall:GetFont()) + CHIP_PAD_Y * 2
    local extent = math.ceil(textHeight(text)) + 8 + math.ceil(chipHeight) + ABOUT_BOTTOM_PAD
    initializer.GetExtent = function() return extent end
    layout:AddInitializer(initializer)
end

-- Settings --------------------------------------------------------------------------

local function profileSetting(key, variableType, name)
    return Settings.RegisterAddOnSetting(category, ADDON .. "_" .. key, key,
        DB:Profile(), variableType, name, DB:Defaults()[key])
end

local function checkbox(key, name, tooltip, onChange)
    local setting = profileSetting(key, Settings.VarType.Boolean, name)
    if onChange then setting:SetValueChangedCallback(onChange) end
    Settings.CreateCheckbox(category, setting, tooltip)
end

function Options:Initialize()
    if category then return end
    if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end

    category, layout = Settings.RegisterVerticalLayoutCategory(L["Wherefrom"])

    addAbout(aboutText())

    checkbox("showHistory", L["Show where you got it"],
        L["The source this addon recorded when the item entered your bags."])
    checkbox("showSource", L["Show which boss drops it"],
        L["Read from the Adventure Guide. Needs the index; rebuild it with /wf index."])
    checkbox("showAppearance", L["Show the game's own source text"],
        L["What the client knows for mounts, pets, heirlooms and appearances."])

    checkbox("showDate", L["Show the date"])
    checkbox("showCharacter", L["Show which character got it"])
    checkbox("onlyOnModifier", L["Only while holding Shift"])

    checkbox("trackQuestRewards", L["Record quest rewards"])
    checkbox("announce", L["Announce every recorded item in chat"],
        L["Useful for checking what the addon makes of a source. Noisy otherwise."])

    -- Rebuilding on a change would stall the client mid-click, so the new scope
    -- takes effect the next time the index is built.
    checkbox("indexAllTiers", L["Index every expansion, not just the current one"],
        L["Much slower and much larger. Takes effect on the next /wf index."])

    Settings.RegisterAddOnCategory(category)
end

function Options:Toggle()
    if not category then self:Initialize() end
    if category and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    end
end
