-- ForeverCore: Bartender4 compatibility on WoW Forever.
-- Only configure UI settings after Bartender4's own first-run preset has loaded.
-- Never touch action/spell assignments, paging, button offsets or bindings.
local FC = _G.ForeverCore
if not FC then return end

local driver = CreateFrame("Frame")
local queued = false
local warned = false
local revision = "bt4-forever-bars-grid-fullrange-art-v3"

local requiredBars = {1, 3, 4, 5, 6}
-- Bartender IDs 3/4 are the two vertical right bars; 5/6 are the lower extra bars.
-- Bar 2 is the bonus bar and is deliberately not changed.

local function say(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80c9ffForeverCore|r " .. message)
    end
end

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function getGuid()
    if type(UnitGUID) ~= "function" then return nil end
    local ok, guid = pcall(UnitGUID, "player")
    if ok and type(guid) == "string" and guid ~= "" then return guid end
    return nil
end

local function getSaved()
    local db = FC.GetDatabase and FC:GetDatabase()
    if not db then return nil end
    if type(db.bartenderDefaults) ~= "table" then db.bartenderDefaults = {} end
    return db.bartenderDefaults
end

local function getBartender()
    -- LibStub is a TABLE with an __call metamethod, not a Lua function.
    -- The old `type(LibStub) ~= "function"` check rejected real Bartender4
    -- on every character, silently preventing all Bartender setup.
    if type(_G.Bartender4) == "table" then return _G.Bartender4 end
    local stub = _G.LibStub
    if type(stub) ~= "table" or type(stub.GetLibrary) ~= "function" then return nil end
    local ok, ace = pcall(stub.GetLibrary, stub, "AceAddon-3.0", true)
    if not ok or type(ace) ~= "table" or type(ace.GetAddon) ~= "function" then return nil end
    local found, addon = pcall(ace.GetAddon, ace, "Bartender4", true)
    if found and type(addon) == "table" then return addon end
    return nil
end

local function module(addon, name)
    if not addon or type(addon.GetModule) ~= "function" then return nil end
    local ok, m = pcall(addon.GetModule, addon, name, true)
    if ok and type(m) == "table" then return m end
    return nil
end

local function ready()
    local bartender = getBartender()
    if not bartender or bartender.finishedLoading ~= true then return nil end
    local bars = module(bartender, "ActionBars")
    local art = module(bartender, "BlizzardArt")
    if not bars or not art or type(bartender.db) ~= "table"
        or type(bartender.db.profile) ~= "table"
        or type(bars.db) ~= "table"
        or type(bars.db.profile) ~= "table"
        or type(bars.db.profile.actionbars) ~= "table"
        or type(bars.actionbars) ~= "table"
        or type(bars.EnableBar) ~= "function"
        or type(art.db) ~= "table"
        or type(art.db.profile) ~= "table" then return nil end
    return bartender, bars, art
end

local function configureBar(bars, id)
    local config = bars.db.profile.actionbars[id]
    if type(config) ~= "table" then return false, "config ontbreekt voor bar " .. id end

    -- Enable missing live bars using Bartender4's own method, never by
    -- enabling Blizzard's protected bar toggles.
    local liveBar = bars.actionbars[id]
    if config.enabled == false or not liveBar or liveBar.disabled then
        local ok = pcall(bars.EnableBar, bars, id)
        if not ok then return false, "inschakelen bar " .. id end
    end

    liveBar = bars.actionbars[id]
    if not liveBar or type(liveBar.ApplyConfig) ~= "function" then
        return false, "live bar " .. id .. " niet beschikbaar"
    end

    -- Bartender's Button Grid shows empty slots. Disable hiding and fading
    -- of these five bars so they stay visible with or without placed spells.
    config.enabled = true
    config.padding = 0
    config.showgrid = true
    config.alpha = 1
    config.fadeout = false
    if type(config.visibility) == "table" then
        config.visibility.always = false  -- In BT4, "always" means always HIDE.
        config.visibility.custom = false
        config.visibility.combat = false
        config.visibility.nocombat = false
    end

    local ok = pcall(liveBar.ApplyConfig, liveBar, config)
    if not ok then return false, "ApplyConfig bar " .. id end
    return true
end

local function applyOnce(force)
    if inCombat() then queued = true; return end
    local guid, saved = getGuid(), getSaved()
    if not guid or not saved or (saved[guid] == revision and not force) then return end
    local bartender, bars, art = ready()
    if not bartender then return end -- Wait until first-run Presets has finished.

    local failures = {}
    for _, id in ipairs(requiredBars) do
        local ok, reason = configureBar(bars, id)
        if not ok then failures[#failures + 1] = reason end
    end

    -- Official Bartender setting: Options > Out of Range Indicator >
    -- Full Button Mode. Requires live button configuration refresh.
    bartender.db.profile.outofrange = "button"
    if bartender.Bar and type(bartender.Bar.ForAll) == "function" then
        if not pcall(bartender.Bar.ForAll, bartender.Bar, "UpdateButtonConfig") then
            failures[#failures + 1] = "range update"
        end
    else
        failures[#failures + 1] = "range update ontbreekt"
    end

    -- Use the official Bartender module toggle (not a fake Blizzard UI
    -- visibility CVar). This hides the art/gryphons without affecting spells.
    if type(art.ToggleModule) == "function" then
        if not pcall(art.ToggleModule, art, nil, false) then
            failures[#failures + 1] = "Blizzard Art toggle"
        end
    else
        failures[#failures + 1] = "Blizzard Art toggle ontbreekt"
    end
    if type(art.IsEnabled) == "function" and art:IsEnabled() then
        failures[#failures + 1] = "Blizzard Art nog aan"
    end

    if #failures > 0 then
        if not warned then
            warned = true
            say("Bartender-setup niet volledig: " .. table.concat(failures, ", ")
                .. ". Probeer /fc bartender apply buiten combat.")
        end
        return -- Do not mark the setup complete when any part failed.
    end

    saved[guid] = revision
    say("Bartender: bars 1/3/4/5/6 aan, lege knoppen zichtbaar, Blizzard Art uit en out of range = volledig icoon.")
end

function FC:BartenderCommand(cmd)
    if cmd == "apply" then
        warned = false
        applyOnce(true)
    elseif cmd == "status" then
        local bartender, bars, art = ready()
        if not bartender then
            say("Bartender: " .. (getBartender() and "geladen maar nog niet klaar" or "niet geladen") .. ".")
            return
        end
        local states = {}
        for _, id in ipairs(requiredBars) do
            local cfg = bars.db.profile.actionbars[id]
            local live = bars.actionbars[id]
            states[#states + 1] = id .. "="
                .. ((type(cfg) == "table" and cfg.enabled and live and not live.disabled) and "aan" or "uit")
                .. ((type(cfg) == "table" and cfg.showgrid) and "+grid" or "")
        end
        local saved, guid = getSaved(), getGuid()
        say("Bartender bars: " .. table.concat(states, ", "))
        say("Blizzard Art=" .. (art:IsEnabled() and "aan" or "uit")
            .. ", range=" .. tostring(bartender.db.profile.outofrange)
            .. ", setup=" .. ((saved and guid and saved[guid] == revision) and "uitgevoerd" or "niet voltooid") .. ".")
        if type(HasAction) == "function" then
            local count = 0
            for slot = 1, 12 do
                local ok, has = pcall(HasAction, slot)
                if ok and has then count = count + 1 end
            end
            say("Blizzard action slots 1-12 bevatten " .. count .. " abilities/items (geen aanpassingen door ForeverCore).")
        end
    else
        say("/fc bartender status | /fc bartender apply")
    end
end

driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName ~= "Bartender4" then return end
    if event == "PLAYER_REGEN_ENABLED" then
        if not queued then return end
        queued = false
    end
    applyOnce(false)
end)
