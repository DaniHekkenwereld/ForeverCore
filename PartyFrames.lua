-- ForeverCore: Blizzard raid-style party frames + class-colored healthbars.
-- Uses the native Edit Mode setting instead of replacing secure unit frames.
-- Does not alter unit frame coordinates, scale, other settings or addons.
local FC = _G.ForeverCore
if not FC then return end

local frame = CreateFrame("Frame")
local pending = false
local warned = false
local scheduled = false

local function say(text)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80c9ffForeverCore|r " .. text)
    end
end

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function getCVar(name)
    local f = (C_CVar and C_CVar.GetCVar) or GetCVar
    if type(f) ~= "function" then return nil end
    local ok, value = pcall(f, name)
    if ok and value ~= nil then return tostring(value) end
    return nil
end

local function setCVarOn(name)
    local previous = getCVar(name)
    if previous == nil then return false end
    if previous == "1" then return true end
    if inCombat() then pending = true; return false end
    local setter = (C_CVar and C_CVar.SetCVar) or SetCVar
    if type(setter) ~= "function" then return false end
    local ok = pcall(setter, name, "1")
    return ok and getCVar(name) == "1"
end

local function getPartyEditSystem()
    if type(Enum) ~= "table"
        or type(Enum.EditModeSystem) ~= "table"
        or type(Enum.EditModeUnitFrameSystemIndices) ~= "table"
        or type(Enum.EditModeUnitFrameSetting) ~= "table"
        or Enum.EditModeSystem.UnitFrame == nil
        or Enum.EditModeUnitFrameSystemIndices.Party == nil
        or Enum.EditModeUnitFrameSetting.UseRaidStylePartyFrames == nil then
        return nil, nil, nil, "Edit Mode party setting niet beschikbaar"
    end

    local manager = _G.EditModeManagerFrame
    if type(manager) ~= "table" or type(manager.GetRegisteredSystemFrame) ~= "function"
        or type(manager.GetActiveLayoutInfo) ~= "function" then
        return nil, nil, nil, "Edit Mode nog niet geladen"
    end
    local system = Enum.EditModeSystem.UnitFrame
    local partyIndex = Enum.EditModeUnitFrameSystemIndices.Party
    local setting = Enum.EditModeUnitFrameSetting.UseRaidStylePartyFrames
    local ok, partyFrame = pcall(manager.GetRegisteredSystemFrame, manager, system, partyIndex)
    if not ok or type(partyFrame) ~= "table" or type(partyFrame.HasSetting) ~= "function"
        or type(partyFrame.GetSettingValueBool) ~= "function" then
        return nil, nil, nil, "Party Edit Mode frame niet gereed"
    end
    local supports, has = pcall(partyFrame.HasSetting, partyFrame, setting)
    if not supports or not has then
        return nil, nil, nil, "Raid-style party setting ontbreekt"
    end
    return manager, partyFrame, setting
end

local function isRaidStyleEnabled()
    local manager, partyFrame, setting = getPartyEditSystem()
    if not manager then return nil end
    local ok, enabled = pcall(partyFrame.GetSettingValueBool, partyFrame, setting)
    if ok then return enabled == true end
    return nil
end

local function useRaidStyle()
    if inCombat() then pending = true; return false, "in combat" end

    local manager, partyFrame, setting, reason = getPartyEditSystem()
    if not manager then
        -- Some older clients still use this CVar for compact party frames.
        -- It is not a substitute for the modern Edit Mode setting.
        if setCVarOn("useCompactPartyFrames") then
            return true, "legacy CVar"
        end
        return false, reason
    end

    local ok, enabled = pcall(partyFrame.GetSettingValueBool, partyFrame, setting)
    if not ok then return false, "Edit Mode setting niet leesbaar" end
    if enabled then return true, "Edit Mode" end

    if type(manager.IsShown) == "function" and manager:IsShown() then
        -- Do not race against a player editing and saving the HUD.
        return false, "Edit Mode is open; sluit het na opslaan"
    end
    local layoutOK, activeLayout = pcall(manager.GetActiveLayoutInfo, manager)
    if not layoutOK or type(activeLayout) ~= "table" then
        return false, "Geen actief Edit Mode layout"
    end

    -- A Blizzard preset cannot be saved in place. Do not mutate it or
    -- replace the player's chosen layout with a new one.
    local preset = Enum.EditModeLayoutType and Enum.EditModeLayoutType.Preset
    if preset ~= nil and activeLayout.layoutType == preset then
        return false, "Actief Blizzard standaardlayout is niet bewerkbaar; maak een eigen Edit Mode layout"
    end
    if type(manager.HasActiveChanges) == "function" then
        local checked, hasChanges = pcall(manager.HasActiveChanges, manager)
        if checked and hasChanges then
            return false, "Er zijn niet-opgeslagen Edit Mode wijzigingen"
        end
    end

    if type(manager.OnSystemSettingChange) ~= "function"
        or type(manager.SaveLayouts) ~= "function" then
        return false, "Edit Mode instelfuncties ontbreken"
    end

    -- Native Blizzard API; updates only Party > UseRaidStylePartyFrames.
    -- Never call protected CompactRaidFrameManager updates directly.
    local changed, err = pcall(manager.OnSystemSettingChange,
        manager, partyFrame, setting, 1)
    if not changed then return false, "Instellen mislukt: " .. tostring(err) end

    local verified, value = pcall(partyFrame.GetSettingValueBool, partyFrame, setting)
    if not verified or not value then return false, "Instelling niet geactiveerd" end

    local saved, saveError = pcall(manager.SaveLayouts, manager)
    if not saved then
        return false, "Edit Mode opslaan mislukt: " .. tostring(saveError)
    end
    return true, "Edit Mode opgeslagen"
end

local function apply(announce)
    if inCombat() then pending = true; return end
    local classOK = setCVarOn("raidFramesDisplayClassColor")
    local raidOK, how = useRaidStyle()
    if announce then
        say("Party = raid-style: " .. (raidOK and "aan" or "niet ingesteld")
            .. " (" .. tostring(how) .. "); class colors: "
            .. (classOK and "aan" or "niet beschikbaar") .. ".")
    elseif not raidOK and not warned and how ~= "Edit Mode nog niet geladen"
        and how ~= "Party Edit Mode frame niet gereed" then
        warned = true
        say("Party raid-style nog niet ingesteld: " .. tostring(how)
            .. ". Controleer met /fc party status.")
    end
end

local function schedule()
    if scheduled then return end
    scheduled = true
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(1, function() apply(false) end)
        C_Timer.After(4, function() apply(false) end)
        C_Timer.After(8, function()
            scheduled = false
            apply(false)
        end)
    else
        scheduled = false
        apply(false)
    end
end

function FC:PartyFramesCommand(command)
    if command == "apply" then
        warned = false
        apply(true)
    elseif command == "status" then
        local party = isRaidStyleEnabled()
        say("Party raid-style (Edit Mode): " ..
            (party == nil and "onbekend" or (party and "aan" or "uit"))
            .. " | legacy compact: " .. tostring(getCVar("useCompactPartyFrames"))
            .. " | class colors: " .. tostring(getCVar("raidFramesDisplayClassColor")))
    else
        say("/fc party status | /fc party apply")
    end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then
            pending = false
            schedule()
        end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD"
        or event == "EDIT_MODE_LAYOUTS_UPDATED" then
        schedule()
    end
end)
