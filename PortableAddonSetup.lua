-- Portable extra addon defaults for new WoW accounts.
-- Uses a one-time import and a single UI reload; avoids per-login resets.
local FC = _G.ForeverCore
if not FC then return end
local events = CreateFrame("Frame")
local pending, busy, queued = false, false, false

local function say(s)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80c9ffForeverCore|r " .. tostring(s))
    end
end

local function clone(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do
        result[clone(key, seen)] = clone(item, seen)
    end
    return result
end

local function bundle()
    local t = _G.ForeverCoreBundledAddonSettings
    return type(t) == "table" and type(t.addons) == "table" and t or nil
end

local function account()
    local root = FC.GetDatabase and FC:GetDatabase()
    if not root then return nil end
    if type(root.portableAddonSettings) ~= "table" then
        root.portableAddonSettings = {installed = {}}
    end
    local state = root.portableAddonSettings
    if type(state.installed) ~= "table" then state.installed = {} end
    return root, state
end

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function loaded(name)
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
        local ok, result = pcall(C_AddOns.IsAddOnLoaded, name)
        if ok then return result == true end
    end
    if type(IsAddOnLoaded) == "function" then
        local ok, result = pcall(IsAddOnLoaded, name)
        if ok then return result == true end
    end
    return false
end

local function apply(onlyAddon, force)
    if busy or inCombat() then pending = true; return end
    local data = bundle()
    local root, state = account()
    if not data or not root then return end
    -- The original private-server source keeps its live UI, not a re-import.
    if not root.layoutTemplate or root.layoutTemplate.source ~= "bundled-source" then return end
    busy = true
    local changed, unloaded = 0, 0
    for addon, vars in pairs(data.addons) do
        if (not onlyAddon or addon == onlyAddon) and type(vars) == "table" then
            if loaded(addon) then
                for name, value in pairs(vars) do
                    local key = addon .. "/" .. name
                    if type(name) == "string" and (force or state.installed[key] ~= data.version)
                       and (type(value) == "table" or type(value) == "string"
                         or type(value) == "boolean" or type(value) == "number") then
                        local val = clone(value)
                        -- Original beta settings have EnhanceQoL's swing bars
                        -- explicitly disabled. The portable UI requires both
                        -- melee swing timers on new characters (incl. Rogue).
                        if addon == "EnhanceQoL" and name == "EnhanceQoLDB"
                            and type(val) == "table" and type(val.profiles) == "table" then
                            for _, p in pairs(val.profiles) do
                                if type(p) == "table" then
                                    p.swingBarMainHandEnabled = true
                                    p.swingBarOffHandEnabled = true
                                end
                            end
                        end
                        local old = _G[name]
                        if type(old) == "table" and type(val) == "table" then
                            -- Keep root table identity for addons holding a reference.
                            for k in pairs(old) do old[k] = nil end
                            for k, v in pairs(val) do old[k] = v end
                        else
                            _G[name] = val
                        end
                        state.installed[key] = data.version
                        changed = changed + 1
                    end
                end
            else
                unloaded = unloaded + 1
            end
        end
    end
    busy = false
    if changed > 0 then
        say(changed .. " extra addoninstellingen geïmporteerd; één keer /reload.")
        -- Addons initialized before this module must reload with their
        -- native SavedVariables to actually use the new preferences.
        if type(ReloadUI) == "function" and not inCombat() then
            local ok = pcall(ReloadUI)
            if not ok then say("Automatisch herladen geweigerd; typ /reload.") end
        else
            say("Typ /reload om de geïmporteerde instellingen te activeren.")
        end
    elseif unloaded > 0 and not state.warnedUnloaded then
        state.warnedUnloaded = true
        say("Niet-geladen addons worden ingesteld wanneer ze later laden.")
    end
end

function FC:PortableAddonsStatus()
    local data = bundle()
    if not data then
        say("Aanvullende addons niet geladen: controleer PortableAddonSettings.lua in ForeverCore en Lua-syntaxfouten.")
        return
    end
    local _, state = account()
    local addons, on, applied, variables = 0, 0, 0, 0
    for addon, vars in pairs(data.addons) do
        addons = addons + 1
        if loaded(addon) then on = on + 1 end
        for name in pairs(vars) do
            variables = variables + 1
            if state and state.installed[addon .. "/" .. name] == data.version then
                applied = applied + 1
            end
        end
    end
    say("Extra profielen: " .. addons .. " addons (" .. on .. " geladen), "
        .. applied .. "/" .. variables .. " variabelen geïmporteerd.")
    local bb = data.addons.BetterBlizzFrames
    local target = type(bb) == "table" and bb.BetterBlizzFramesDB
    local actual = _G.BetterBlizzFramesDB
    if type(target) ~= "table" then
        say("BetterBlizzFrames: geen configuratie in snapshot.")
    elseif not loaded("BetterBlizzFrames") then
        say("BetterBlizzFrames: NIET geladen; schakel de addon in bij characterselectie.")
    elseif type(actual) ~= "table" then
        say("BetterBlizzFrames: wel geladen, maar BetterBlizzFramesDB niet beschikbaar.")
    else
        local compared, mismatches = 0, 0
        for key, expected in pairs(target) do
            if type(expected) ~= "table" then
                compared = compared + 1
                if actual[key] ~= expected then mismatches = mismatches + 1 end
            end
        end
        local imported = state and state.installed["BetterBlizzFrames/BetterBlizzFramesDB"] == data.version
        say("BetterBlizzFrames: " .. (imported and "import gemarkeerd" or "nog niet geïmporteerd")
            .. ", eenvoudige opties afwijkend: " .. mismatches .. "/" .. compared .. ".")
    end
    say("Zie PortableAddonSettings-report.txt voor niet-ondersteunde addons.")
end

local function compareBetterBlizzFrames()
    local data = bundle()
    local expected = data and data.addons.BetterBlizzFrames
        and data.addons.BetterBlizzFrames.BetterBlizzFramesDB
    local actual = _G.BetterBlizzFramesDB
    if type(expected) ~= "table" or type(actual) ~= "table" then
        say("BetterBlizzFrames: geen geladen bron- en doelinstellingen om te vergelijken.")
        return
    end
    local keys, checked = {}, 0
    for key, wanted in pairs(expected) do
        if type(wanted) ~= "table" then
            checked = checked + 1
            if actual[key] ~= wanted then keys[#keys + 1] = key end
        end
    end
    table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
    say("BetterBlizzFrames-verschillen: " .. #keys .. " van " .. checked .. " eenvoudige instellingen.")
    for i = 1, math.min(#keys, 12) do
        local key = keys[i]
        say(tostring(key) .. ": bron=" .. tostring(expected[key])
            .. "; huidig=" .. tostring(actual[key]))
    end
    if #keys > 12 then say("Nog " .. (#keys - 12) .. " verschillen niet getoond.") end
end

function FC:PortableAddonCommand(raw)
    local cmd = tostring(raw or "status"):lower()
    if cmd == "diff" then
        compareBetterBlizzFrames()
    elseif cmd == "repair" then
        local data = bundle()
        local root = FC.GetDatabase and FC:GetDatabase()
        if not data or not data.addons.BetterBlizzFrames then
            say("BetterBlizzFrames ontbreekt in de portable export.")
        elseif not root or not root.layoutTemplate or root.layoutTemplate.source ~= "bundled-source" then
            say("Repair alleen op nieuwe portable accounts, niet op het bronaccount.")
        elseif not loaded("BetterBlizzFrames") then
            say("BetterBlizzFrames is niet geladen. Schakel deze addon eerst in.")
        else
            apply("BetterBlizzFrames", true)
        end
    else
        self:PortableAddonsStatus()
    end
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, addon)
    if event == "PLAYER_REGEN_ENABLED" then
        if not pending then return end
        pending = false
        apply()
    elseif event == "ADDON_LOADED" then
        local data = bundle()
        if data and data.addons[addon] then
            if C_Timer and type(C_Timer.After) == "function" then
                C_Timer.After(0.3, apply)
            else apply() end
        end
    elseif event == "PLAYER_ENTERING_WORLD" and not queued then
        queued = true
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(2, function() queued = false; apply() end)
        else queued = false; apply() end
    end
end)
