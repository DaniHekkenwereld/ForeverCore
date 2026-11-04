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

local function apply()
    if busy or inCombat() then pending = true; return end
    local data = bundle()
    local root, state = account()
    if not data or not root then return end
    -- The original private-server source keeps its live UI, not a re-import.
    if not root.layoutTemplate or root.layoutTemplate.source ~= "bundled-source" then return end
    busy = true
    local changed, unloaded = 0, 0
    for addon, vars in pairs(data.addons) do
        if type(vars) == "table" then
            if loaded(addon) then
                for name, value in pairs(vars) do
                    local key = addon .. "/" .. name
                    if type(name) == "string" and state.installed[key] ~= data.version
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
        say("Aanvullende addons: geen PortableAddonSettings.lua gegenereerd.")
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
    say("Zie PortableAddonSettings-report.txt voor niet-ondersteunde addons.")
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
