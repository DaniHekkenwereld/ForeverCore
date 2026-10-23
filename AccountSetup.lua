-- ForeverCore: account-wide onboarding for new characters.
-- Includes six known Warrior bindings for a fresh Forever character; no existing main is required.
-- An optional captured profile still overrides the built-in starter, when the user wants that.
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

-- Ergonomic 4-layer preset: same 12 physical keys in the same 12 slots.
-- Rows 1/2/3/4 use no modifier, Shift, Alt and Shift+Alt.
-- No WASD, Tab, Space, G, or dedicated Warrior mouse keys are remapped.
-- Right Action Bar is still vertical in Blizzard's default layout.
local starterRevision = "ergonomic-4layer-20261023-v4-singlekey"
local baseKeys = {"1", "2", "3", "4", "Q", "E", "R", "F", "Z", "X", "C", "V"}
local starterRows = {
    {label = "Rij 1 / Main - normale toetsen", prefix = "ACTIONBUTTON", modifier = ""},
    {label = "Rij 2 / Bottom Left - Shift", prefix = "MULTIACTIONBAR1BUTTON", modifier = "SHIFT-"},
    {label = "Rij 3 / Bottom Right - Alt", prefix = "MULTIACTIONBAR2BUTTON", modifier = "ALT-"},
    {label = "Rij 4 / Right Bar - Shift+Alt", prefix = "MULTIACTIONBAR3BUTTON", modifier = "ALT-SHIFT-"},
}
local screenshotBindings = {}
for _, row in ipairs(starterRows) do
    for index, key in ipairs(baseKeys) do
        screenshotBindings[#screenshotBindings + 1] = {row.modifier .. key, row.prefix .. index}
    end
end

-- Legacy bindings are removed only during an addon-presets migration,
-- and only when their current action still matches the earlier preset.
-- Manually changed bindings are preserved.
local legacyStarterBindings = {
    ["modifier-rows-20261023-v2"] = {
        {"1", "ACTIONBUTTON1"},
        {"2", "ACTIONBUTTON2"},
        {"3", "ACTIONBUTTON3"},
        {"6", "ACTIONBUTTON4"},
        {"Q", "ACTIONBUTTON5"},
        {"R", "ACTIONBUTTON6"},
        {"Z", "ACTIONBUTTON7"},
        {"F", "MULTIACTIONBAR1BUTTON1"},
        {"C", "MULTIACTIONBAR1BUTTON2"},
        {"T", "MULTIACTIONBAR1BUTTON3"},
        {"V", "MULTIACTIONBAR1BUTTON4"},
        {"G", "MULTIACTIONBAR1BUTTON5"},
        {"MOUSEWHEELDOWN", "MULTIACTIONBAR1BUTTON6"},
        {"SHIFT-C", "MULTIACTIONBAR2BUTTON1"},
        {"SHIFT-SPACE", "MULTIACTIONBAR2BUTTON2"},
        {"SHIFT-V", "MULTIACTIONBAR2BUTTON3"},
        {"SHIFT-X", "MULTIACTIONBAR2BUTTON4"},
        {"SHIFT-E", "MULTIACTIONBAR2BUTTON5"},
        {"SHIFT-2", "MULTIACTIONBAR2BUTTON6"},
        {"ALT-P", "MULTIACTIONBAR3BUTTON1"},
        {"ALT-E", "MULTIACTIONBAR3BUTTON2"},
        {"ALT-2", "MULTIACTIONBAR3BUTTON3"},
        {"ALT-G", "MULTIACTIONBAR3BUTTON4"},
        {"ALT-T", "MULTIACTIONBAR3BUTTON5"},
        {"ALT-R", "MULTIACTIONBAR3BUTTON6"},
        {"ALT-F", "MULTIACTIONBAR3BUTTON7"},
        {"ALT-V", "MULTIACTIONBAR3BUTTON8"},
        {"ALT-3", "MULTIACTIONBAR3BUTTON9"},
        {"ALT-X", "MULTIACTIONBAR3BUTTON10"},
    },
    ["screenshot-20261023-v1"] = {
        {"1", "ACTIONBUTTON1"},
        {"2", "ACTIONBUTTON2"},
        {"3", "ACTIONBUTTON3"},
        {"R", "ACTIONBUTTON4"},
        {"MOUSEWHEELDOWN", "ACTIONBUTTON5"},
        {"Z", "ACTIONBUTTON6"},
        {"ALT-P", "ACTIONBUTTON8"},
        {"6", "ACTIONBUTTON9"},
        {"F", "MULTIACTIONBAR1BUTTON1"},
        {"C", "MULTIACTIONBAR1BUTTON2"},
        {"G", "MULTIACTIONBAR1BUTTON3"},
        {"Q", "MULTIACTIONBAR1BUTTON4"},
        {"T", "MULTIACTIONBAR1BUTTON5"},
        {"V", "MULTIACTIONBAR1BUTTON6"},
        {"ALT-E", "MULTIACTIONBAR1BUTTON8"},
        {"ALT-2", "MULTIACTIONBAR1BUTTON9"},
        {"ALT-G", "MULTIACTIONBAR1BUTTON10"},
        {"SHIFT-C", "MULTIACTIONBAR2BUTTON2"},
        {"SHIFT-SPACE", "MULTIACTIONBAR2BUTTON4"},
        {"SHIFT-V", "MULTIACTIONBAR2BUTTON5"},
        {"SHIFT-X", "MULTIACTIONBAR2BUTTON6"},
        {"SHIFT-E", "MULTIACTIONBAR2BUTTON7"},
        {"ALT-T", "MULTIACTIONBAR2BUTTON8"},
        {"ALT-R", "MULTIACTIONBAR2BUTTON9"},
        {"ALT-F", "MULTIACTIONBAR2BUTTON10"},
        {"ALT-V", "MULTIACTIONBAR2BUTTON11"},
        {"SHIFT-2", "MULTIACTIONBAR2BUTTON12"},
        {"ALT-3", "MULTIACTIONBAR3BUTTON1"},
        {"ALT-X", "MULTIACTIONBAR3BUTTON2"},
    },
}
local warriorStarter = {
    {"BUTTON4", "SHAPESHIFTBUTTON1"},    -- Battle Stance
    {"BUTTON5", "SHAPESHIFTBUTTON2"},    -- Defensive Stance
    {"G", "SHAPESHIFTBUTTON3"},          -- Berserker Stance
    {"BUTTON3", "SPELL Taunt"},          -- middle mouse
    {"MOUSEWHEELDOWN", "SPELL Heroic Strike"},
    {"MOUSEWHEELUP", "SPELL Cleave"},
}

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
    if s.autoActionBars == nil then s.autoActionBars = true end
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
-- Four EXTRA Blizzard action bars: Bottom Left, Bottom Right, Right 1, Right 2.
-- Prefer native toggles (official Forever API), preserve 5/6/7 if present.
-- In modern clients, the Settings proxies update visibility immediately.
local actionBarProxies = {
    "PROXY_SHOW_ACTIONBAR_2",
    "PROXY_SHOW_ACTIONBAR_3",
    "PROXY_SHOW_ACTIONBAR_4",
    "PROXY_SHOW_ACTIONBAR_5",
}
local actionBarCVars = {
    "bottomLeftActionBar",
    "bottomRightActionBar",
    "rightActionBar",
    "rightTwoActionBar",
}
local function enableFourActionBars()
    local s = settings()
    if not s or not s.autoCVars or not s.autoActionBars then return end
    if locked() then pending = true; return end

    local supported = false
    if type(GetActionBarToggles) == "function" and type(SetActionBarToggles) == "function" then
        local ok, a, b, c, d, e, g, h = pcall(GetActionBarToggles)
        if ok and type(a) == "boolean" and type(b) == "boolean"
            and type(c) == "boolean" and type(d) == "boolean" then
            supported = true
            if not (a and b and c and d) then
                -- Keep optional bars 5-7 at their previous values.
                local applied = pcall(SetActionBarToggles, true, true, true, true, e, g, h)
                if not applied then supported = false end
            end
        end
    end

    -- Modern UI Settings proxies; each maps to an extra action bar.
    if type(Settings) == "table"
        and type(Settings.GetSetting) == "function"
        and type(Settings.SetValue) == "function" then
        for _, key in ipairs(actionBarProxies) do
            local ok, setting = pcall(Settings.GetSetting, key)
            if ok and setting ~= nil then
                local wrote = pcall(Settings.SetValue, key, true)
                if wrote then supported = true end
            end
        end
    end

    -- Fallback for older UI flavors that expose these CVars.
    if not supported then
        for _, key in ipairs(actionBarCVars) do
            local result = setCVar(key, "1")
            if result == true then supported = true end
        end
    end
    if not supported and not warned["actionBars"] then
        warned["actionBars"] = true
        say("Extra action bars konden niet automatisch worden ingesteld op deze client.")
    end
end

local function applyCVars()
    local s, db = settings()
    if not s or not s.autoCVars then return end
    if locked() then pending = true; return end
    enableFourActionBars()
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
local function removeLegacyPresetBindings(previousRevision, desired)
    local old = legacyStarterBindings[previousRevision]
    if not old or type(GetBindingAction) ~= "function" then return true end
    local kept = {}
    for _, entry in ipairs(desired) do kept[entry[1]] = true end
    for _, entry in ipairs(old) do
        local key, expectedAction = entry[1], entry[2]
        if not kept[key] then
            local ok, actualAction = pcall(GetBindingAction, key)
            if ok and actualAction == expectedAction then
                if not setKey(key, nil) then
                    return false, "old preset cleanup: " .. key
                end
            end
        end
    end
    return true
end
-- Blizzard can keep a *second* original binding on a slot (e.g. "5"
-- still displayed for ACTIONBUTTON5, while the new "Q" also works).
-- For the BUILT-IN preset only, detach extra keys from the 48 targeted
-- action bar slots before binding the chosen ergonomic key.
local function clearExtraSlotBindings(desired)
    if type(GetBindingKey) ~= "function" then return true end
    local slots = {}
    for _, binding in ipairs(desired) do
        local key, action = binding[1], binding[2]
        if type(action) == "string" and
            (action:match("^ACTIONBUTTON%d+$") or action:match("^MULTIACTIONBAR%d+BUTTON%d+$")) then
            if not slots[action] then slots[action] = {} end
            slots[action][key] = true
        end
    end
    for action, chosenKeys in pairs(slots) do
        local ok, key1, key2 = pcall(GetBindingKey, action)
        if ok then
            for _, key in ipairs({key1, key2}) do
                if type(key) == "string" and not chosenKeys[key] then
                    if not setKey(key, nil) then
                        return false, "old slot key " .. key
                    end
                end
            end
        end
    end
    return true
end

local function writeBindings(desired, clearExisting, saveMode, previousPreset, normalizeSlots)
    if locked() then return false, "in combat" end
    if type(SaveBindings) ~= "function" then return false, "SaveBindings unavailable" end
    local active = collect()
    if not active then return false, "GetBinding unavailable" end
    if clearExisting then
        for _, pair in ipairs(active) do
            if not setKey(pair[1], nil) then return false, "clear " .. pair[1] end
        end
    end
    if previousPreset then
        local cleaned, reason = removeLegacyPresetBindings(previousPreset, desired)
        if not cleaned then return false, reason end
    end
    if normalizeSlots then
        local cleaned, reason = clearExtraSlotBindings(desired)
        if not cleaned then return false, reason end
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
    if not s or (not s.autoBindings and not force) then return end
    if locked() then pending = true; return end
    local guid = playerID()
    if not guid then pending = true; return end
    local characterClass = classToken()
    local profile = s.profile
    local captured = type(profile) == "table" and type(profile.keys) == "table" and #profile.keys >= 5
    -- The built-in screenshot layout works on every class, without capture.
    local starter = not captured
    local revision = captured and profile.revision or starterRevision
    if not force and s.applied[guid] == revision then return end
    if s.excluded and s.excluded[guid] and not force then return end
    if running then return end
    running = true

    local sameClass = captured and profile.class == characterClass
    local target = {}
    if starter then
        local orderedKeys = {}
        local positions = {}
        local function add(key, command)
            if not positions[key] then
                orderedKeys[#orderedKeys + 1] = key
                positions[key] = #orderedKeys
            end
            target[positions[key]] = {key, command}
        end
        for _, pair in ipairs(screenshotBindings) do
            add(pair[1], pair[2])
        end
        -- Preserve the user's existing Warrior-specific stance / mouse prefs.
        -- These six take priority where a screenshot hotkey conflicts.
        if characterClass == "WARRIOR" then
            for _, pair in ipairs(warriorStarter) do
                add(pair[1], pair[2])
            end
        end
    else
        for _, pair in ipairs(profile.keys) do
            local key, command = pair[1], pair[2]
            if type(key) == "string" and type(command) == "string"
                and (sameClass or not classSpecific(command)) then
                target[#target + 1] = {key, command}
            end
        end
    end

    local current = collect()
    if not current then
        running = false
        say("Keybind API nog niet beschikbaar; probeer opnieuw met /fc setup apply.")
        return
    end
    -- Backup once before any write. Never clear other keys when using the six-key starter.
    if not s.backups[guid] then
        s.backups[guid] = {keys = current, mode = 2}
    end
    local ok, reason = writeBindings(target, captured and sameClass, 2, starter and s.applied[guid] or nil, starter)
    running = false
    if ok then
        s.applied[guid] = revision
        if s.excluded then s.excluded[guid] = nil end
        if starter then
            say("Ergonomische keybind-layout ingesteld: " .. #target .. " toetsen ("
                .. (characterClass == "WARRIOR" and "incl. Warrior stance/mouse binds" or "algemeen")
                .. "); overige toetsen blijven staan.")
        else
            say("Keybind-profiel toegepast: " .. #target .. " toetsen ("
                .. (sameClass and "volledig" or "class-onafhankelijk") .. ").")
        end
    else
        say("Keybind-sync mislukt (" .. tostring(reason) .. "). Backup: /fc setup restore.")
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
    local ok, reason = writeBindings(backup.keys, true, 2) -- never alter account-wide bindings to restore one character
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
        .. ", friendly " .. db.plateMode .. ", profiel " .. (p and (#p.keys .. " toetsen, rev " .. p.revision) or "ergonomische 4-layer layout (geen hoofdchar nodig)") .. ".")
    local bars = "onbekend"
    if type(GetActionBarToggles) == "function" then
        local ok, a, b, c, d = pcall(GetActionBarToggles)
        if ok then
            bars = tostring(a) .. "/" .. tostring(b) .. "/" .. tostring(c) .. "/" .. tostring(d)
        end
    end
    say("Extra bars onder links/rechts + rechts 1/2: " .. bars
        .. " (auto: " .. (s.autoActionBars and "aan" or "uit") .. ").")
    say("Auto loot=" .. tostring(getCVar("autoLootDefault"))
        .. ", enemy plates=" .. tostring(getCVar("nameplateShowEnemies"))
        .. ", friend plates=" .. tostring(getCVar("nameplateShowFriends") or getCVar("nameplateShowFriendlyPlayers"))
        .. ", afstand=" .. tostring(getCVar("nameplateMaxDistance")) .. " (effectieve servercap kan lager zijn).")
end
local function printStarterLayout()
    say("4 symmetrische keybind-rijen: 12 dezelfde basistoetsen per rij (48 slots).")
    for _, row in ipairs(starterRows) do
        local keys = {}
        for _, base in ipairs(baseKeys) do
            keys[#keys + 1] = row.modifier .. base
        end
        say(row.label .. ": " .. table.concat(keys, ", "))
    end
    say("Warrior: G Berserker / muis 4-5 stances / midden Taunt / wiel down Heroic Strike / wiel up Cleave.")
    say("Rij 4 is de standaard verticale Right Bar; addon verandert geen balkpositie.")
end
function FC:SetupCommand(raw)
    local command, option = tostring(raw or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if command == "layout" then printStarterLayout()
    elseif command == "capture" then capture()
    elseif command == "apply" then applyBindings(true)
    elseif command == "restore" then restore()
    elseif command == "status" then status()
    elseif command == "bindings" and (option == "on" or option == "off") then
        local s = settings(); if s then s.autoBindings = option == "on" end
        say("Automatische keybind-sync: " .. option)
    elseif command == "bars" and (option == "on" or option == "off") then
        local s = settings()
        if s then s.autoActionBars = option == "on" end
        if option == "on" then enableFourActionBars() end
        say("Vier extra action bars automatisch aanzetten: " .. option)
    elseif command == "settings" and (option == "on" or option == "off") then
        local s = settings(); if s then s.autoCVars = option == "on" end
        if option == "on" then applyCVars() end
        say("Automatische clientinstellingen: " .. option)
    else
        say("/fc setup layout | capture | apply | restore | status | bindings on/off | settings on/off | bars on/off")
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