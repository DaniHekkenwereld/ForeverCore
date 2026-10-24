-- ForeverCore: Bartender4 initial defaults, one time per character.
-- Touch only Blizzard Art (off) and ActionBars.padding (zero).
-- Never modify scale, bar count, position, fade, visibility, or keybindings.
local FC = _G.ForeverCore
if not FC then return end

local driver = CreateFrame("Frame")
local tried = false
local queued = false
local version = "bartender-padding-art-v1"

local function say(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80c9ffForeverCore|r " .. msg)
    end
end

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function getGuid()
    if type(UnitGUID) ~= "function" then return nil end
    local ok, value = pcall(UnitGUID, "player")
    if ok and type(value) == "string" and value ~= "" then return value end
    return nil
end

local function getSaved()
    local db = FC.GetDatabase and FC:GetDatabase()
    if not db then return nil end
    if type(db.bartenderDefaults) ~= "table" then db.bartenderDefaults = {} end
    return db.bartenderDefaults
end

local function getBartender()
    -- AceAddon's registry is the standard way to obtain another addon's
    -- live module, instead of altering its SavedVariables behind its back.
    if type(LibStub) ~= "function" then return nil end
    local ok, lib = pcall(LibStub, "AceAddon-3.0", true)
    if not ok or not lib or type(lib.GetAddon) ~= "function" then return nil end
    local found, addon = pcall(lib.GetAddon, lib, "Bartender4", true)
    if found and type(addon) == "table" then return addon end
    return nil
end

local function getModule(addon, name)
    if type(addon.GetModule) ~= "function" then return nil end
    local ok, module = pcall(addon.GetModule, addon, name, true)
    if ok and type(module) == "table" then return module end
    return nil
end

local function applyOnce(force)
    if inCombat() then queued = true; return end
    local guid = getGuid()
    local saved = getSaved()
    if not guid or not saved then return end
    if saved[guid] == version and not force then return end

    local bartender = getBartender()
    if not bartender then return end -- Bartender4 is optional: not installed yet.
    local barsMod = getModule(bartender, "ActionBars")
    local artMod = getModule(bartender, "BlizzardArt")
    if not barsMod or not artMod or not barsMod.db or not artMod.db
        or type(barsMod.db.profile) ~= "table"
        or type(barsMod.db.profile.actionbars) ~= "table"
        or type(artMod.db.profile) ~= "table" then
        if not tried then say("Bartender4-modules nog niet gereed; setup uitgesteld.") end
        tried = true
        return
    end

    local config = barsMod.db.profile.actionbars
    local updated = 0
    local liveOK = true
    -- Bartender4 supports extra bars depending on version/client; only
    -- touch padding where a real config table exists.
    for id = 1, 15 do
        local barConfig = config[id]
        if type(barConfig) == "table" and barConfig.padding ~= 0 then
            barConfig.padding = 0
            updated = updated + 1
            local liveBar = type(barsMod.actionbars) == "table" and barsMod.actionbars[id]
            if liveBar and type(liveBar.ApplyConfig) == "function" then
                local ok = pcall(liveBar.ApplyConfig, liveBar, barConfig)
                if not ok then liveOK = false end
            end
        end
    end

    local artConfig = artMod.db.profile
    artConfig.enabled = false
    if type(artMod.IsEnabled) == "function" and artMod:IsEnabled() then
        if type(artMod.Disable) ~= "function" then
            liveOK = false
        else
            local ok = pcall(artMod.Disable, artMod)
            if not ok then liveOK = false end
        end
    end

    if not liveOK then
        say("Bartender-instellingen opgeslagen, maar live refresh deels mislukt. Probeer /reload buiten combat.")
        -- They are saved in Bartender's own AceDB, so do not repeatedly
        -- fight the user's UI every login if one live update fails.
    end
    saved[guid] = version
    say("Bartender4: Blizzard Art uit, padding 0 op " .. updated
        .. " bars; schaal en posities ongewijzigd.")
end

function FC:BartenderCommand(cmd)
    local saved, guid = getSaved(), getGuid()
    if cmd == "status" then
        local hasBT = getBartender() ~= nil
        say("Bartender4: " .. (hasBT and "geladen" or "niet geladen")
            .. "; setup: " .. ((saved and guid and saved[guid] == version)
            and "uitgevoerd" or "nog niet uitgevoerd") .. ".")
    elseif cmd == "apply" then
        applyOnce(true)
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
