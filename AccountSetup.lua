-- ForeverCore: account-wide onboarding for new characters.
-- The player captures their bindings once; no guessing or overwriting before capture.
-- Binding writes and secure CVars are only attempted out of combat.
local FC = _G.ForeverCore
if not FC then return end

local f = CreateFrame("Frame")
local prefix = "|cff80c9ffForeverCore|r "
local running = false
local pending = false
local warned = {}
local desiredCVars = {
    {"autoLootDefault", "1"},
    {"nameplateShowEnemies", "1"},
    {"nameplateShowAll", "1"},
    {"nameplateMaxDistance", "60"},
    {"nameplatePlayerMaxDistance", "60"},
}
local friendlyCVars = {"nameplateShowFriends", "nameplateShowFriendlyPlayers"}

local function say(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(prefix .. message) end
end
local function locked()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end
local function settings()
    if not FC.GetDatabase then return nil end
    local db = FC:GetDatabase()
    if not db then return nil end
    if type(db.accountSetup) ~= "table" then db.accountSetup = {} end
    local s = db.accountSetup
    if s.autoCVars == nil then s.autoCVars = true end
    if s.autoBindings == nil then s.autoBindings = true end
    if type(s.applied) ~= "table" then s.applied = {} end
    if type(s.backups) ~= "table" then s.backups = {} end
    -- Migrate pre-0.3 default: keep friendly plates enabled everywhere.
    -- A later explicit /fc plates auto/off selection still takes precedence.
    if not s.nameplatesMigrated then
        if db.plateMode == "auto" then db.plateMode = "on" end
        s.nameplatesMigrated = true
    end
    return s, db
end
local function playerID()
    if type(UnitGUID) ~= "function" then return nil end
    local ok, guid = pcall(UnitGUID, "player")
    if ok and type(guid) == "string" and guid ~= "" then return guid end
    return nil
end
local function classToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, class = pcall(UnitClass, "player")
    if ok then return class end
    return nil
end
local function getCVar(name)
    local getter = (C_CVar and C_CVar.GetCVar) or GetCVar
    if type(getter) ~= "function" then return nil end
    local ok, value = pcall(getter, name)
    if ok and type(value) == "string" then return value end
    return nil
end
local function setCVar(name, value)
    local before = getCVar(name)
    if before == nil then return nil end -- Unknown CVar on this beta build.
    if tonumber(before) == tonumber(value) then return true end
    local setter = (C_CVar and C_CVar.SetCVar) or SetCVar
    if type(setter) ~= "function" then return false end
    local ok = pcall(setter, name, value)
    if not ok then return false end
    local after = getCVar(name)
    return after ~= nil and tonumber(after) == tonumber(value)
end
local function applyCVars()
    local s, db = settings()
    if not s or not s.autoCVars then return end
    if locked() then pending = true; return end
    for _, pair in ipairs(desiredCVars) do
        local result = setCVar(pair[1], pair[2])
        if result == false and not warned[pair[1]] then
            warned[pair[1]] = true
            say(pair[1] .. " niet toepasbaar; client/server kan deze instelling beperken.")
        end
    end
    if db.plateMode == "on" then
        for _, name in ipairs(friendlyCVars) do
            local result = setCVar(name, "1")
            if result == false and not warned[name] then
                warned[name] = true
                say(name .. " kon niet ingeschakeld worden door addon.")
            end
        end
    end
end

-- Capture every current key, not only the first two bindings shown in the UI.
-- This records binding commands, NOT action bar spell assignments.
local function collect()
    if type(GetNumBindings) ~= "function" or type(GetBinding) ~= "function" then return nil end
    local ok, count = pcall(GetNumBindings)
    if not ok or type(count) ~= "number" or count < 1 or count > 4096 then return nil end
    local keys, seen = {}, {}
    for i = 1, count do
        local good, values = pcall(function() return {GetBinding(i)} end)
        if not good or type(values) ~= "table" then return nil end
        local command = values[1]
        if type(command) == "string" and command ~= "" then
            for j = 3, #values do
                local key = values[j]
                if type(key) == "string" and key ~= "" and not seen[key] then
                    seen[key] = true
                    keys[#keys + 1] = {key, command}
                end
            end
        end
    end
    if #keys < 5 then return nil end -- Refuse a broken/incomplete beta API result.
    return keys
end
local function classSpecific(command)
    return command:match("^SPELL ") or command:match("^MACRO ")
        or command:match("^ITEM ") or command:match("^CLICK ")
end
local function setKey(key, command)
    if type(SetBinding) ~= "function" then return false end
    local ok, result = pcall(SetBinding, key, command)
    return ok and result ~= nil and result ~= false
end
local function writeBindings(desired, clearExisting, saveMode)
    if locked() then return false, "in combat" end
    if type(SaveBindings) ~= "function" then return false, "SaveBindings unavailable" end
    local active = collect()
    if not active then return false, "GetBinding unavailable" end
    if clearExisting then
        for _, pair in ipairs(active) do
            if not setKey(pair[1], nil) then return false, "clear " .. pair[1] end
        end
    end
    for _, pair in ipairs(desired) do
        if not setKey(pair[1], pair[2]) then return false, "bind " .. pair[1] end
    end
    local ok, saved = pcall(SaveBindings, saveMode or 2)
    if not ok or saved == false then return false, "SaveBindings failed" end
    return true
end
local function applyBindings(force)
    local s = settings()
    if not s or not s.autoBindings and not force then return end
    local profile = s.profile
    if type(profile) ~= "table" or type(profile.keys) ~= "table" or #profile.keys < 5 then return end
    if locked() then pending = true; return end
    local guid = playerID()
    if not guid then pending = true; return end
    local revision = profile.revision
    if not force and s.applied[guid] == revision then return end
    if s.excluded and s.excluded[guid] and not force then return end
    if running then return end
    running = true
    local isSameClass = profile.class == classToken()
    local target = {}
    for _, pair in ipairs(profile.keys) do
        local key, command = pair[1], pair[2]
        if type(key) == "string" and type(command) == "string"
            and (isSameClass or not classSpecific(command)) then
            target[#target + 1] = {key, command}
        end
    end
    local current = collect()
    if not current then running = false; say("Keybind API nog niet beschikbaar."); return end
    -- Keep a per-character restore point before first change in this revision.
    if not s.backups[guid] then
        local mode = type(GetCurrentBindingSet) == "function" and GetCurrentBindingSet() or 2
        s.backups[guid] = {keys = current, mode = (mode == 1 and 1 or 2)}
    end
    -- For the same class clone exactly. On another class keep its class-specific keys.
    local ok, reason = writeBindings(target, isSameClass, 2)
    running = false
    if ok then
        s.applied[guid] = revision
        if s.excluded then s.excluded[guid] = nil end
        say("Keybind-profiel toegepast: " .. #target .. " toetsen (" .. (isSameClass and "volledig" or "class-onafhankelijk") .. ").")
    else
        say("Keybind-sync mislukt (" .. tostring(reason) .. "). Backup: /fc setup restore. ")
    end
end
local function capture()
    local s = settings()
    if not s then return end
    if locked() then say("Sla keybinds buiten combat op."); return end
    local keys = collect()
    if not keys then say("Geen volledige keybindset leesbaar: niets opgeslagen."); return end
    s.profile = {keys = keys, class = classToken(), revision = (s.profile and s.profile.revision or 0) + 1}
    local guid = playerID()
    if guid then s.applied[guid] = s.profile.revision end
    say("Profiel opgeslagen (" .. #keys .. " toetsen). Nieuwe characters importeren dit automatisch.")
end
local function restore()
    local s = settings()
    if not s then return end
    if locked() then say("Herstellen kan alleen buiten combat."); return end
    local guid = playerID()
    if not guid or not s.backups[guid] then say("Geen originele keybind-backup voor dit character."); return end
    local backup = s.backups[guid]
    local ok, reason = writeBindings(backup.keys, true, backup.mode)
    if ok then
        s.excluded = s.excluded or {}
        s.excluded[guid] = true -- no automatic re-apply after restore
        say("Originele keybinds hersteld. /fc setup apply om opnieuw te importeren.")
    else
        say("Herstellen mislukt (" .. tostring(reason) .. ").")
    end
end
local function status()
    local s, db = settings()
    if not s then return end
    local p = s.profile
    say("Setup: CVars " .. (s.autoCVars and "aan" or "uit") .. ", keybind-sync " .. (s.autoBindings and "aan" or "uit")
        .. ", friendly " .. db.plateMode .. ", profiel " .. (p and (#p.keys .. " toetsen, rev " .. p.revision) or "niet opgenomen") .. ".")
    say("Auto loot=" .. tostring(getCVar("autoLootDefault"))
        .. ", enemy plates=" .. tostring(getCVar("nameplateShowEnemies"))
        .. ", friend plates=" .. tostring(getCVar("nameplateShowFriends") or getCVar("nameplateShowFriendlyPlayers"))
        .. ", afstand=" .. tostring(getCVar("nameplateMaxDistance")) .. " (effectieve servercap kan lager zijn).")
end
function FC:SetupCommand(raw)
    local command, option = tostring(raw or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if command == "capture" then capture()
    elseif command == "apply" then applyBindings(true)
    elseif command == "restore" then restore()
    elseif command == "status" then status()
    elseif command == "bindings" and (option == "on" or option == "off") then
        local s = settings(); if s then s.autoBindings = option == "on" end
        say("Automatische keybind-sync: " .. option)
    elseif command == "settings" and (option == "on" or option == "off") then
        local s = settings(); if s then s.autoCVars = option == "on" end
        if option == "on" then applyCVars() end
        say("Automatische clientinstellingen: " .. option)
    else
        say("/fc setup capture | apply | restore | status | bindings on/off | settings on/off")
    end
end
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event)
    if not settings() then return end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        applyCVars()
        applyBindings(false)
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        applyCVars()
    elseif event == "PLAYER_REGEN_ENABLED" and pending then
        pending = false
        applyCVars()
        applyBindings(false)
    end
end)