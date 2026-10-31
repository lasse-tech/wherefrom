-- Warnings are errors here: luacheck exits non-zero on any of them, and `make
-- lint` blocks on that. Nothing is suppressed inline; a finding gets fixed.

std = "lua51"
max_line_length = 120
-- Methods are written with `:`, so every one of them carries an implicit self
-- it rarely reads. Unused arguments are still reported; only self is exempt.
self = false

-- Set by this addon at load time, on purpose.
globals = {
    "WherefromDB",        -- SavedVariables
    "WherefromAboutMixin",-- referenced from UI/Options.xml
    "SLASH_WHEREFROM1",
    "SLASH_WHEREFROM2",
    "SlashCmdList",
}

-- The client's API. Anything the addon touches has to be listed, so a typo in a
-- Blizzard function name is a lint failure rather than a runtime nil call.
read_globals = {
    -- Lua extras WoW adds to the global table
    "format", "strtrim", "strlower", "strsplit", "wipe", "time", "date",

    -- Frames and infrastructure
    "CreateFrame", "UIParent", "GameTooltip", "DEFAULT_CHAT_FRAME",
    "geterrorhandler", "hooksecurefunc", "GameFontNormalSmall",
    "Enum", "Settings", "TooltipDataProcessor", "EncounterJournal",

    -- Namespaced API
    "C_AddOns", "C_Container", "C_EncounterJournal", "C_Heirloom", "C_Item",
    "C_MountJournal", "C_PetJournal", "C_QuestLog", "C_Timer", "C_TradeSkillUI",
    "C_TransmogCollection",

    -- Player, world and units
    "GetAddOnMetadata", "GetBuildInfo", "GetGuildInfo", "GetInstanceInfo", "GetLocale",
    "GetNormalizedRealmName", "GetRealmName", "GetSubZoneText", "GetZoneText",
    "IsInInstance", "IsShiftKeyDown", "UnitGUID", "UnitName", "GetTime",
    "FormatShortDate",

    -- Loot, mail and the combat log
    "GetLootSlotLink", "GetLootSourceInfo",
    "GetNumLootItems", "AutoLootMailItem", "GetInboxHeaderInfo",
    "GetInboxInvoiceInfo", "TakeInboxItem",

    -- Adventure Guide
    "EJ_GetCurrentTier", "EJ_GetEncounterInfoByIndex", "EJ_GetInstanceByIndex",
    "EJ_GetLootFilter", "EJ_GetNumLoot", "EJ_GetNumTiers", "EJ_SelectEncounter",
    "EJ_SelectInstance", "EJ_SelectTier", "EJ_SetLootFilter",

    -- Bags and worn gear
    "BACKPACK_CONTAINER", "NUM_BAG_SLOTS", "NUM_TOTAL_EQUIPPED_BAG_SLOTS",
    "GetInventoryItemID", "INVSLOT_FIRST_EQUIPPED", "INVSLOT_LAST_EQUIPPED",
}

-- The test files run inside wow-ui-sim against TestFramework's globals.
files["tests/*.lua"] = {
    read_globals = { "test", "assertEquals", "assertTrue", "assertFalse",
        "assertNil", "assertNotNil", "assertType" },
}
