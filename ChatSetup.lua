-- ForeverCore: one-time chat tabs on a character's first login.
-- These are CHAT WINDOWS/TABS, not joinable custom chat channels.
local FC = _G.ForeverCore
if not FC then return end

local listener = CreateFrame("Frame")
local triedThisSession = false
local function notify(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80c9ffForeverCore|r " .. message)
    end
end
local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end
local definitions = {
    {name = "Party", groups = {"PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "GUILD"}},
    {name = "Whispers", groups = {"WHISPER", "BN_WHISPER"}},
}

local function state()
    local db = FC.GetDatabase and FC:GetDatabase()
    if not db then return nil end
    if type(db.chatTabsDone) ~= "table" then db.chatTabsDone = {} end
    return db.chatTabsDone
end
local function playerGUID()
    if type(UnitGUID) ~= "function" then return nil end
    local ok, guid = pcall(UnitGUID, "player")
    if ok and type(guid) == "string" and guid ~= "" then return guid end
    return nil
end
local function findWindow(name)
    if type(GetChatWindowInfo) ~= "function" then return nil end
    local count = type(NUM_CHAT_WINDOWS) == "number" and NUM_CHAT_WINDOWS or 10
    for id = 1, count do
        local ok, existingName = pcall(GetChatWindowInfo, id)
        if ok and type(existingName) == "string"
            and existingName:lower() == name:lower() then
            local chatFrame = _G["ChatFrame" .. id]
            if chatFrame then return chatFrame, id end
        end
    end
    return nil
end
local function callFrame(frame, method, fallback, ...)
    if type(frame[method]) == "function" then
        return pcall(frame[method], frame, ...)
    end
    if type(_G[fallback]) == "function" then
        return pcall(_G[fallback], frame, ...)
    end
    return false
end
local function configureNewWindow(frame, groups)
    -- FCF_OpenNewWindow adds SAY/YELL/CHANNEL by default; remove all of them.
    -- A Whispers tab must never show guild, raid, party or public channels.
    if not callFrame(frame, "RemoveAllMessageGroups", "ChatFrame_RemoveAllMessageGroups") then
        return false, "message groups cannot be cleared"
    end
    if not callFrame(frame, "RemoveAllChannels", "ChatFrame_RemoveAllChannels") then
        return false, "public channels cannot be cleared"
    end
    for _, group in ipairs(groups) do
        if not callFrame(frame, "AddMessageGroup", "ChatFrame_AddMessageGroup", group) then
            return false, "cannot add " .. group
        end
    end
    return true
end
local function ensureWindow(def)
    -- Respect windows that already exist; never overwrite another addon/user setup.
    local existing = findWindow(def.name)
    if existing then return true end
    if type(FCF_OpenNewWindow) ~= "function" then
        return false, "FCF_OpenNewWindow unavailable"
    end
    local ok, created = pcall(FCF_OpenNewWindow, def.name)
    if not ok then return false, "Blizzard rejected new chat tab" end
    local frame = created or findWindow(def.name)
    if not frame then return false, "chat frame not found after creation" end
    return configureNewWindow(frame, def.groups)
end
local function setup(force)
    if inCombat() then
        notify("Chatvensters aanmaken kan alleen buiten combat.")
        return
    end
    local done = state()
    local guid = playerGUID()
    if not done or not guid then return end
    if done[guid] then
        if force then notify("Party en Whispers waren al eenmalig ingesteld; niets gewijzigd.") end
        return
    end
    local allGood = true
    for _, def in ipairs(definitions) do
        local ok, reason = ensureWindow(def)
        if not ok then
            allGood = false
            notify("Chatvenster " .. def.name .. " mislukt: " .. tostring(reason))
        end
    end
    if allGood then
        done[guid] = true
        notify("Chatvensters Party (guild/raid/party) en Whispers (alleen whispers) ingesteld.")
    end
end
function FC:ChatCommand(command)
    local done = state()
    local guid = playerGUID()
    if command == "status" then
        notify("Chat setup voor dit character: "
            .. ((done and guid and done[guid]) and "al uitgevoerd" or "nog niet voltooid") .. ".")
    elseif command == "setup" then
        setup(true)
    else
        notify("/fc chat setup | /fc chat status")
    end
end
listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:SetScript("OnEvent", function()
    if triedThisSession then return end
    triedThisSession = true
    setup(false)
end)
