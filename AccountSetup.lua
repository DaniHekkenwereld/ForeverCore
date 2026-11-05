-- ForeverCore: account-wide onboarding for new characters.
-- Includes four non-conflicting Warrior-specific bindings; no existing main is required.
-- An optional captured profile still overrides the built-in starter, when the user wants that.
-- Binding writes and secure CVars are only attempted out of combat.
local FC = _G.ForeverCore
if not FC then return end
-- Emergency safety lock: 0.3.33 keybind import can destroy basic movement
-- bindings on live. No automatic or manual binding writes are permitted until
-- a complete profile exporter and a non-destructive installer are verified.
local KEYBIND_WRITE_LOCKED = true

local f = CreateFrame("Frame")
local prefix = "|cff80c9ffForeverCore|r "
local running = false
local pending = false
local warned = {}
-- Only characters first seen during THIS login may receive a delayed retry.
-- Existing characters' custom bindings must never be automatically replaced.
local newThisLogin = {}
local postLoginChecks = {}
local desiredCVars = {
    {"autoLootDefault", "1"},
    {"raidFramesDisplayClassColor", "1"}, -- raid + raid-style party class colors
    {"alwaysShowActionBars", "1"}, -- keep empty Blizzard action buttons visible
    {"nameplateShowEnemies", "1"},
    {"nameplateShowAll", "1"},
    {"nameplateMaxDistance", "60"},
    {"nameplatePlayerMaxDistance", "60"},
    -- Forever self-highlight / character outline (options + renderer).
    {"Outline", "2"},
    {"graphicsOutlineMode", "2"},
    {"findYourselfModeOutline", "1"},
    {"findYourselfAnywhere", "1"},
    {"countdownForCooldowns", "1"}, -- numeric cooldown timers on action buttons
    {"cooldownViewerEnabled", "1"}, -- Blizzard native Cooldown Manager
}
local friendlyCVars = {"nameplateShowFriends", "nameplateShowFriendlyPlayers"}

-- Ergonomic 4-layer preset: same 12 physical keys in the same 12 slots.
-- Rows 1/2/3/4 use no modifier, Shift, Alt and Shift+Alt.
-- Main row alone uses G and Mouse Wheel Down for buttons 5/6.
-- Modifier rows retain the original base keys without changes.
-- Right Action Bar is still vertical in Blizzard's default layout.
local starterRevision = "ergonomic-4layer-20261026-v6-main-g-wheel"
local previousStarterRevision = "ergonomic-4layer-20261025-v5-restore-movedown"
local baseKeys = {"1", "2", "3", "4", "Q", "E", "R", "F", "Z", "X", "C", "V"}
local mainKeys = {"1", "2", "3", "4", "G", "MOUSEWHEELDOWN", "R", "F", "Z", "X", "C", "V"}
local starterRows = {
    {label = "Rij 1 / Main - normale toetsen", prefix = "ACTIONBUTTON", modifier = ""},
    {label = "Rij 2 / Bottom Left - Shift", prefix = "MULTIACTIONBAR1BUTTON", modifier = "SHIFT-"},
    {label = "Rij 3 / Bottom Right - Alt", prefix = "MULTIACTIONBAR2BUTTON", modifier = "ALT-"},
    {label = "Rij 4 / Right Bar - Shift+Alt", prefix = "MULTIACTIONBAR3BUTTON", modifier = "ALT-SHIFT-"},
}
local screenshotBindings = {}
for _, row in ipairs(starterRows) do
    local rowKeys = row.modifier == "" and mainKeys or baseKeys
    for index, key in ipairs(rowKeys) do
        -- The bare X is Sit/Move Down, not an actionbar key. Keep modifier
        -- combinations such as Shift+X, Alt+X, and Shift+Alt+X.
        if row.modifier ~= "" or key ~= "X" then
            screenshotBindings[#screenshotBindings + 1] = {row.modifier .. key, row.prefix .. index}
        end
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
    {"BUTTON3", "SPELL Taunt"},          -- middle mouse
    {"MOUSEWHEELUP", "SPELL Cleave"},
    -- G and MOUSEWHEELDOWN belong to main actionbar buttons 5 and 6.
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
    -- Override persisted 'on' from older versions. Account keybind import is
    -- disabled globally until the faulty WoW-live behavior is fixed.
    s.autoBindings = false
    -- Keep the old, unsafe repeating actionbar automation disabled.
    -- New characters use a separate one-time, per-GUID setup instead.
    s.autoActionBars = false
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
    if before == tostring(value) then return true end
    if tonumber(before) and tonumber(value) and tonumber(before) == tonumber(value) then return true end
    local setter = (C_CVar and C_CVar.SetCVar) or SetCVar
    if type(setter) ~= "function" then return false end
    local ok = pcall(setter, name, value)
    if not ok then return false end
    local after = getCVar(name)
    if after == tostring(value) then return true end
    return after ~= nil and tonumber(after) ~= nil and tonumber(after) == tonumber(value)
end
-- Do not call SetActionBarToggles on fresh characters.
-- The Forever client previously hid secure bars after these writes.
-- Bartender4 is configured via its own live ActionBars module instead.

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
    -- Apply source client preferences to newly created accounts only;
    -- never change the source account's own CVar configuration.
    local bundled = _G.ForeverCoreBundledDefaults
    local portable = bundled and bundled.clientCVars
    if type(db.layoutTemplate) == "table" and db.layoutTemplate.source == "bundled-source"
        and type(portable) == "table" then
        for name, value in pairs(portable) do
            if type(name) == "string" and type(value) == "string" then
                local result = setCVar(name, value)
                if result == false and not warned[name] then
                    warned[name] = true
                    say(name .. " uit het bronaccount niet toepasbaar in deze client.")
                end
            end
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
        -- GetBinding returns command, category, key1, key2. Do not
        -- pack the returns in a Lua array: a nil category produces a hole,
        -- making #values unreliable and silently losing all hotkeys.
        local good, command, category, key1, key2 = pcall(GetBinding, i)
        if not good then return nil end
        if type(command) == "string" and command ~= "" then
            if type(key1) == "string" and key1 ~= "" and not seen[key1] then
                seen[key1] = true
                keys[#keys + 1] = {key1, command}
            end
            if type(key2) == "string" and key2 ~= "" and not seen[key2] then
                seen[key2] = true
                keys[#keys + 1] = {key2, command}
            end
        end
    end
    if #keys < 5 then return nil end -- Refuse a broken/incomplete beta API result.
    return keys
end
local function classSpecific(command)
    -- CLICK bindings (e.g. Bartender4 button clicks) belong to shared
    -- actionbar keys, not to one class. Keep them for Rogues and Warriors.
    return command:match("^SPELL ") or command:match("^MACRO ")
        or command:match("^ITEM ")
end
-- Beta-only Bug Reporter commands are not portable across accounts or to live.
local function nonPortableCommand(command)
    return type(command) == "string" and command:match("^FOREVERBUGREPORTER_") ~= nil
end
local function setKey(key, command)
    if type(SetBinding) ~= "function" then return false end
    -- WoW's bindings-cache uses NONE for an explicitly unbound key.
    -- SetBinding expects nil (not the literal command "NONE") to unbind.
    if command == "NONE" or command == "" then command = nil end
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

local function writeBindings(desired, clearExisting, saveMode, previousPreset, normalizeSlots, defaultBaseline)
    if KEYBIND_WRITE_LOCKED then return false, "keybind-import tijdelijk uitgeschakeld wegens live bug" end
    if locked() then return false, "in combat" end
    if type(SaveBindings) ~= "function" then return false, "SaveBindings unavailable" end
    local active = collect()
    if not active then return false, "GetBinding unavailable" end
    if defaultBaseline then
        -- The exported bindings-cache only lists explicit overrides. Start new
        -- portable characters from Blizzard's full defaults (WASD, jump, etc.),
        -- rather than reusing a damaged/incomplete character-specific cache.
        if type(LoadBindings) ~= "function" then return false, "LoadBindings unavailable" end
        local ok, loaded = pcall(LoadBindings, DEFAULT_BINDINGS or 0)
        if not ok or loaded == false then return false, "loading Blizzard defaults failed" end
    end
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
    local mode = saveMode or 2
    local ok, saved = pcall(SaveBindings, mode)
    if not ok or saved == false then return false, "SaveBindings failed" end
    if defaultBaseline then
        -- Immediately load the just-saved character set. This catches the bug
        -- where missing default bindings become visible on the first keypress.
        local loadedOK, loaded = pcall(LoadBindings, mode)
        if not loadedOK or loaded == false then
            return false, "saved binding set could not be reloaded"
        end
        local requiredDefaults = {W = "MOVEFORWARD", S = "MOVEBACKWARD", SPACE = "JUMP"}
        for key, action in pairs(requiredDefaults) do
            if type(GetBindingAction) ~= "function" or GetBindingAction(key) ~= action then
                return false, "default " .. key .. " missing after reload"
            end
        end
    end
    return true
end
local function expectedStarterBindings()
    if type(GetBindingAction) ~= "function" then return false end
    local checks = {
        {"1", "ACTIONBUTTON1"},
        {"2", "ACTIONBUTTON2"},
        {"3", "ACTIONBUTTON3"},
        {"4", "ACTIONBUTTON4"},
        {"G", "ACTIONBUTTON5"},
        {"MOUSEWHEELDOWN", "ACTIONBUTTON6"},
        {"SHIFT-1", "MULTIACTIONBAR1BUTTON1"},
        {"ALT-1", "MULTIACTIONBAR2BUTTON1"},
        {"ALT-SHIFT-1", "MULTIACTIONBAR3BUTTON1"},
        {"X", "SITORSTAND"},
    }
    for _, pair in ipairs(checks) do
        local ok, actual = pcall(GetBindingAction, pair[1])
        if not ok or actual ~= pair[2] then return false end
    end
    return true
end

local function applyBindings(force, resetToDefaults)
    -- Even explicit /fc setup apply or /fc setup repair must be harmless.
    if KEYBIND_WRITE_LOCKED then
        if force then say("Veiligheidsblokkade: keybind-import uitgeschakeld. Gebruik WoW Keybindings of een WTF-backup.") end
        return
    end
    local s, db = settings()
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

    -- Never re-import modifier rows or the whole preset on an existing
    -- character. Migrate only the two main row slots on the previous
    -- built-in revision, provided their original keybinds are still intact.
    if not force and starter and s.applied[guid] ~= nil then
        local function currentAction(key)
            if type(GetBindingAction) ~= "function" then return nil end
            local ok, action = pcall(GetBindingAction, key)
            if ok and type(action) == "string" then return action end
            return nil
        end
        local restoreX = currentAction("X") == "ACTIONBUTTON10"
        local migrateMain = s.applied[guid] == previousStarterRevision
            and currentAction("Q") == "ACTIONBUTTON5"
            and currentAction("E") == "ACTIONBUTTON6"
            and (currentAction("G") == "" or currentAction("G") == "SHAPESHIFTBUTTON3")
            and (currentAction("MOUSEWHEELDOWN") == "" or currentAction("MOUSEWHEELDOWN") == "SPELL Heroic Strike")
        if restoreX or migrateMain then
            if restoreX and not setKey("X", "SITORSTAND") then
                say("X kon niet worden hersteld. Probeer /fc setup apply.")
                return
            end
            if migrateMain then
                -- Only unbind the two unchanged former main-row keys.
                -- The Shift, Alt and Shift+Alt bindings are never touched.
                if not setKey("Q", nil) or not setKey("E", nil)
                    or not setKey("G", "ACTIONBUTTON5")
                    or not setKey("MOUSEWHEELDOWN", "ACTIONBUTTON6") then
                    say("Nieuwe hoofdbar-toetsen konden niet worden ingesteld. Probeer /fc setup apply.")
                    return
                end
            end
            local saved, result = pcall(SaveBindings, 2)
            if not saved or result == false then
                say("Hoofdbar-keybinds konden niet worden opgeslagen.")
                return
            end
            if restoreX then say("X hersteld naar Sit/Move Down.") end
            if migrateMain then say("Hoofdbar aangepast: G = 5 en Scroll Down = 6; modifiers ongewijzigd.") end
        end
        s.applied[guid] = revision
        return
    end
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
        -- Restore Blizzard's standard X = Sit/Move Down. On existing
        -- ForeverCore characters this replaces the old X = ACTIONBUTTON10.
        add("X", "SITORSTAND")
        -- The four remaining Warrior-specific bindings do not overlap
        -- the new main-row G and Mouse Wheel Down slots.
        if characterClass == "WARRIOR" then
            for _, pair in ipairs(warriorStarter) do
                add(pair[1], pair[2])
            end
        end
    else
        for _, pair in ipairs(profile.keys) do
            local key, command = pair[1], pair[2]
            if type(key) == "string" and type(command) == "string"
                and (sameClass or not classSpecific(command))
                and not nonPortableCommand(command) then
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
    -- A portable capture contains explicit overrides, not the complete
    -- Blizzard defaults. Fresh bundled characters need a full default
    -- baseline to protect W/A/S/D, space, camera controls and other keys.
    -- Existing manually customized characters are never reset on login.
    local freshPortable = captured and db and type(db.layoutTemplate) == "table"
        and db.layoutTemplate.source == "bundled-source"
        and s.applied[guid] == nil
    local baseline = resetToDefaults or freshPortable
    local ok, reason = writeBindings(target, false, 2,
        starter and s.applied[guid] or nil, starter, baseline)
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
-- Opt-in rescue for characters damaged by previous import versions.
-- Backup data can itself be incomplete; rebuild from native Blizzard defaults.
local function repair()
    if locked() then say("Herstellen kan alleen buiten combat."); return end
    local s, db = settings()
    if not s or not playerID() then say("Characterdata nog niet geladen."); return end
    if not db.layoutTemplate or db.layoutTemplate.source ~= "bundled-source" then
        say("Deze herstelactie is alleen voor portable testaccounts.")
        return
    end
    say("Herstel: Blizzard-standaardbindings + portable toetsen, daarna opslagcontrole.")
    applyBindings(true, true)
end
local function inspectBindings()
    if type(GetBindingAction) ~= "function" then
        say("GetBindingAction niet beschikbaar.")
        return
    end
    local set = type(GetCurrentBindingSet) == "function"
        and tostring(GetCurrentBindingSet()) or "onbekend"
    local keys = {"W", "A", "S", "D", "SPACE", "-", "MOUSEWHEELDOWN", "G"}
    local parts = {}
    for _, key in ipairs(keys) do
        local value = GetBindingAction(key)
        parts[#parts + 1] = key .. "=" .. ((value and value ~= "") and value or "NOT BOUND")
    end
    say("Actieve binding set=" .. set .. "; " .. table.concat(parts, "; "))
end
-- Read-only comparison of a captured profile against active client bindings.
-- Invalid/disabled private-beta Bug Reporter commands are intentionally skipped.
local function portableBindingDifferences(profile, currentClass)
    if type(profile) ~= "table" or type(profile.keys) ~= "table"
        or type(GetBindingAction) ~= "function" then return nil, 0, 0 end
    local mismatches, checked, skipped = {}, 0, 0
    local sameClass = profile.class == currentClass
    for _, binding in ipairs(profile.keys) do
        local key, action = binding[1], binding[2]
        if type(key) == "string" and type(action) == "string" then
            if nonPortableCommand(action) or (not sameClass and classSpecific(action)) then
                skipped = skipped + 1
            else
                checked = checked + 1
                local expected = action == "NONE" and "" or action
                local ok, actual = pcall(GetBindingAction, key)
                if type(actual) ~= "string" then actual = "" end
                if not ok or actual ~= expected then
                    mismatches[#mismatches + 1] = {key, expected, actual}
                end
            end
        end
    end
    return mismatches, checked, skipped
end

local function diagnosticBindings()
    local s = settings()
    local profile = s and s.profile
    local mismatches, checked, skipped = portableBindingDifferences(profile, classToken())
    if not mismatches then
        say("Geen portable keybindprofiel of binding-API beschikbaar.")
        return
    end
    say("Portable keybindcontrole: " .. (#mismatches == 0 and "OK" or "AFWIJKING")
        .. "; " .. checked .. " gecontroleerd, " .. skipped .. " overgeslagen, "
        .. #mismatches .. " verschillend.")
    for index = 1, math.min(#mismatches, 12) do
        local pair = mismatches[index]
        say(pair[1] .. ": verwacht " .. (pair[2] ~= "" and pair[2] or "NOT BOUND")
            .. ", aanwezig " .. (pair[3] ~= "" and pair[3] or "NOT BOUND"))
    end
    if #mismatches > 12 then say("Nog " .. (#mismatches - 12) .. " verschillen niet getoond.") end
end

local function status()
    local s, db = settings()
    if not s then return end
    local p = s.profile
    say("Setup: CVars " .. (s.autoCVars and "aan" or "uit") .. ", keybind-sync " .. (s.autoBindings and "aan" or "uit")
        .. ", friendly " .. db.plateMode .. ", profiel " .. (p and (#p.keys .. " toetsen, rev " .. p.revision) or "ergonomische 4-layer layout (geen hoofdchar nodig)") .. ".")
    local id = playerID()
    local currentRev = p and p.revision or starterRevision
    say("Bindings status: " .. ((id and s.applied[id] == currentRev) and "opgeslagen" or "niet toegepast")
        .. "; current binding set: " .. (type(GetCurrentBindingSet) == "function" and tostring(GetCurrentBindingSet()) or "onbekend")
        .. "; verwachte 1-4, G, ScrollDown, Shift/Alt: " .. (p and "aangepast profiel" or (expectedStarterBindings() and "correct" or "NIET correct")) .. ".")
    say("Blizzard actionbar toggles worden niet door ForeverCore gewijzigd; Bartender4 heeft eigen bar-instellingen.")
    if FC.BartenderCommand then FC:BartenderCommand("status") end
    say("Auto loot=" .. tostring(getCVar("autoLootDefault"))
        .. ", enemy plates=" .. tostring(getCVar("nameplateShowEnemies"))
        .. ", friend plates=" .. tostring(getCVar("nameplateShowFriends") or getCVar("nameplateShowFriendlyPlayers"))
        .. ", afstand=" .. tostring(getCVar("nameplateMaxDistance")) .. " (effectieve servercap kan lager zijn).")
    say("Actionbar countdown=" .. tostring(getCVar("countdownForCooldowns"))
        .. ", Cooldown Manager=" .. tostring(getCVar("cooldownViewerEnabled")) .. ".")
    say("Status text=" .. tostring(getCVar("statusText")) .. " / " .. tostring(getCVar("statusTextDisplay"))
        .. ", camera max=" .. tostring(getCVar("cameraDistanceMaxZoomFactor"))
        .. ", highlight circle=" .. tostring(getCVar("findYourselfModeCircle")) .. ".")
    say("Player Outline=" .. tostring(getCVar("Outline"))
        .. ", Graphics Outline=" .. tostring(getCVar("graphicsOutlineMode"))
        .. ", Self Highlight=" .. tostring(getCVar("findYourselfAnywhere"))
        .. ", Self Outline=" .. tostring(getCVar("findYourselfModeOutline")) .. ".")
end
local function printStarterLayout()
    say("4 keybind-rijen: 47 actionbar-toetsen. X = Sit/Move Down (geen actionbar).")
    for _, row in ipairs(starterRows) do
        local keys = {}
        local rowKeys = row.modifier == "" and mainKeys or baseKeys
        for _, base in ipairs(rowKeys) do
            if row.modifier ~= "" or base ~= "X" then
                keys[#keys + 1] = row.modifier .. base
            end
        end
        say(row.label .. ": " .. table.concat(keys, ", "))
    end
    say("X is Sit/Move Down; Shift+X, Alt+X en Shift+Alt+X blijven op de extra actionbars.")
    say("Warrior: G en wiel down = hoofdbar 5/6; muis 4-5 stances / midden Taunt / wiel up Cleave.")
    say("Rij 4 is de standaard verticale Right Bar; addon verandert geen balkpositie.")
end
function FC:SetupCommand(raw)
    local command, option = tostring(raw or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if command == "layout" then printStarterLayout()
    elseif command == "capture" then capture()
    elseif command == "apply" then applyBindings(true)
    elseif command == "repair" then repair()
    elseif command == "inspect" then inspectBindings()
    elseif command == "diff" then diagnosticBindings()
    elseif command == "restore" then restore()
    elseif command == "status" then status()
    elseif command == "bindings" and (option == "on" or option == "off") then
        local s = settings(); if s then s.autoBindings = false end
        say("Automatische keybind-sync uitgeschakeld wegens fout op live. 'on' is geblokkeerd.")
    elseif command == "bars" and (option == "on" or option == "off") then
        local s = settings()
        if s then s.autoActionBars = false end
        say("Bartender4 configureert de actie-balken; Blizzard SetActionBarToggles blijft uit wegens eerdere combat-fouten.")
        say("Gebruik /fc bartender status. /fc setup bars on/off wijzigt niets.")
    elseif command == "settings" and (option == "on" or option == "off") then
        local s = settings(); if s then s.autoCVars = option == "on" end
        if option == "on" then applyCVars() end
        say("Automatische clientinstellingen: " .. option)
    else
        say("/fc setup layout | capture | apply | repair | inspect | diff | restore | status | bindings on/off | settings on/off | bars on/off")
    end
end
-- A new character's first keybind writes can be overwritten when Blizzard
-- or Bartender finishes loading. Apply after world entry and verify again.
-- Never re-import on old characters or silently override later user edits.
local function capturedBindingsMatch(profile, currentClass)
    local mismatches = portableBindingDifferences(profile, currentClass)
    return mismatches ~= nil and #mismatches == 0
end

local function checkNewCharacterBindings(id, attempt)
    if not newThisLogin[id] then return end
    if postLoginChecks[id] and postLoginChecks[id] >= 2 then return end
    if locked() then pending = true; return end
    local s = settings()
    if not s or not s.autoBindings then return end
    local profile = s.profile
    if type(profile) == "table" and type(profile.keys) == "table" and #profile.keys >= 5 then
        if capturedBindingsMatch(profile, classToken()) then
            newThisLogin[id] = nil
            return
        end
        postLoginChecks[id] = (postLoginChecks[id] or 0) + 1
        -- Blizzard's keybinding loader or another addon can overwrite
        -- bindings after the first successful application.
        if s.applied[id] == profile.revision then s.applied[id] = nil end
        applyBindings(false)
        if capturedBindingsMatch(profile, classToken()) then
            newThisLogin[id] = nil
            say("Portable keybinds na laden geverifieerd, inclusief camera.")
        elseif attempt == 2 then
            newThisLogin[id] = nil
            say("Niet alle portable keybinds zijn toegepast. Typ /fc setup apply.")
        end
        return
    end
    if expectedStarterBindings() then
        newThisLogin[id] = nil
        return
    end
    postLoginChecks[id] = (postLoginChecks[id] or 0) + 1
    -- Ensure an initial attempt which reported success but was subsequently
    -- overwritten can be retried for THIS newly-created character only.
    if s.applied[id] == starterRevision then s.applied[id] = nil end
    applyBindings(false)
    if expectedStarterBindings() then
        newThisLogin[id] = nil
        say("Keybinds geverifieerd na initialisatie: 1-4, G, Scroll Down en modifiers.")
    elseif attempt == 2 then
        newThisLogin[id] = nil
        say("Keybinds wijken nog af. Gebruik /fc setup status en zo nodig /fc setup apply.")
    end
end

local function scheduleNewCharacterCheck(id)
    if not id or not newThisLogin[id] then return end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(2, function() checkNewCharacterBindings(id, 1) end)
        C_Timer.After(6, function() checkNewCharacterBindings(id, 2) end)
    else
        checkNewCharacterBindings(id, 2)
    end
end

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event)
    if not settings() then return end
    if event == "PLAYER_LOGIN" then
        -- Determine newness BEFORE assigning s.applied[guid].
        local s = settings()
        local id = playerID()
        if id and s and not s.applied[id] then newThisLogin[id] = true end
        applyCVars()
        -- First attempt at login; second chance after other addons load.
        applyBindings(false)
    elseif event == "PLAYER_ENTERING_WORLD" then
        applyCVars()
        if newThisLogin[playerID()] then
            scheduleNewCharacterCheck(playerID())
        else
            applyBindings(false)
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        applyCVars()
    elseif event == "PLAYER_REGEN_ENABLED" and pending then
        pending = false
        applyCVars()
        applyBindings(false)
        local id = playerID()
        if id and newThisLogin[id] then scheduleNewCharacterCheck(id) end
    end
end)