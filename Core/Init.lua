local _, T = ...
local L = T.L
local DB = T.DB

-- Everything is wired up here, after every module has been loaded.

-- The index scan walks the whole Adventure Guide, so it waits until the client
-- has finished the rest of its login work.
local INDEX_DELAY = 15

local function bootstrap()
    DB:Initialize()

    T.Capture:InstallHooks()
    T.Tooltip:Initialize()
    T.Options:Initialize()

    -- Nothing may touch the database before this point; the bag diff checks it.
    T.Addon.loaded = true

    if not DB:JournalIsCurrent() then
        C_Timer.After(INDEX_DELAY, function() T.Journal:Build() end)
    end
end

T.Addon:Listen("PLAYER_LOGIN", bootstrap)

-- Slash commands ----------------------------------------------------------------

local function status()
    T.Print(L["%d items recorded."], DB:CountHistory())

    local journal = DB:Journal()
    if not DB:JournalIsCurrent() then
        T.Print(L["No drop index for this build yet - /wf index builds it."])
        return
    end

    local n = 0
    for _ in pairs(journal.items or {}) do n = n + 1 end
    T.Print(L["Drop index: %d items (build %s)."], n, tostring(journal.build))
end

local function forget(input)
    local itemID = T.ItemIDFromLink(input) or tonumber(input)
    if not itemID then
        T.Print(L["Shift-click an item into the command: /wf forget [item]"])
        return
    end

    if DB:Forget(itemID) then
        T.Print(L["Forgot %s."], C_Item.GetItemNameByID(itemID) or itemID)
    else
        T.Print(L["Nothing recorded for %s."], C_Item.GetItemNameByID(itemID) or itemID)
    end
end

local function help()
    T.Print(L["Commands:"])
    for _, line in ipairs({
        "/wf - open the options",
        "/wf status - what is recorded and indexed",
        "/wf index - rebuild the drop index from the Adventure Guide",
        "/wf forget [item] - drop what is recorded for one item",
        "/wf reset confirm - forget every recorded item",
    }) do
        DEFAULT_CHAT_FRAME:AddMessage("  |cff9ecfff" .. L[line] .. "|r")
    end
end

SLASH_WHEREFROM1 = "/wherefrom"
SLASH_WHEREFROM2 = "/wf"
SlashCmdList["WHEREFROM"] = function(input)
    input = strtrim(input or "")
    local command, rest = input:match("^(%S*)%s*(.*)$")
    command = strlower(command or "")

    if command == "" or command == "options" or command == "config" or command == "about" then
        T.Options:Toggle()
    elseif command == "status" then
        status()
    elseif command == "index" then
        T.Journal:Build(true)
    elseif command == "forget" then
        forget(rest)
    elseif command == "reset" then
        if strlower(rest) ~= "confirm" then
            T.Print(L["This forgets every recorded item. Type /wf reset confirm to go ahead."])
            return
        end
        DB:ResetHistory()
        T.Print(L["Forgot every recorded item."])
    else
        help()
    end
end
