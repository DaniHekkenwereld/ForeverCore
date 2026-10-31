-- ForeverCore: enable only "Use Raid-Style Party Frames" in the saved
-- Blizzard Edit Mode layout. No live unit-frame/manager method writes.
local FC = _G.ForeverCore
if not FC then return end

local events = CreateFrame("Frame")
local scheduled, writing, pending = false, false, false
local lastStatus = "Nog niet gecontroleerd"

local function say(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80c9ffForeverCore|r " .. tostring(message))
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

local function getSavedOption()
    local root = FC.GetDatabase and FC:GetDatabase()
    local template = root and root.layoutTemplate
    local name = template and template.editModeName
    local e = Enum
    if type(name) ~= "string" or name == "" then
        return nil, "geen opgeslagen UI-template"
    end
    if type(e) ~= "table" or type(e.EditModeSystem) ~= "table"
        or type(e.EditModeUnitFrameSystemIndices) ~= "table"
        or type(e.EditModeUnitFrameSetting) ~= "table" then
        return nil, "Edit Mode-enums ontbreken"
    end
    local sysID = e.EditModeSystem.UnitFrame
    local idx = e.EditModeUnitFrameSystemIndices.Party
    local settingID = e.EditModeUnitFrameSetting.UseRaidStylePartyFrames
    if type(sysID) ~= "number" or type(idx) ~= "number"
        or type(settingID) ~= "number" then
        return nil, "Party-frame instelling ontbreekt"
    end
    if type(C_EditMode) ~= "table" or type(C_EditMode.GetLayouts) ~= "function"
        or type(C_EditMode.SaveLayouts) ~= "function" then
        return nil, "Blizzard Edit Mode API ontbreekt"
    end
    local ok, data = pcall(C_EditMode.GetLayouts)
    if not ok or type(data) ~= "table" or type(data.layouts) ~= "table" then
        return nil, "Opgeslagen Edit Mode-layouts niet beschikbaar"
    end

    for _, layout in ipairs(data.layouts) do
        if type(layout) == "table" and layout.layoutName == name then
            if e.EditModeLayoutType and layout.layoutType == e.EditModeLayoutType.Preset then
                return nil, "Blizzard preset mag niet worden aangepast"
            end
            for _, system in ipairs(layout.systems or {}) do
                if system.system == sysID and system.systemIndex == idx
                    and type(system.settings) == "table" then
                    for _, setting in ipairs(system.settings) do
                        if setting.setting == settingID then
                            return data, nil, setting, system.settings, settingID, name
                        end
                    end
                    return data, nil, nil, system.settings, settingID, name
                end
            end
            return nil, "Party Frames ontbreken in opgeslagen layout"
        end
    end
    return nil, "UI-layout '" .. name .. "' ontbreekt"
end

local function apply(report)
    if writing then return end
    if inCombat() then pending = true; return end
    local manager = _G.EditModeManagerFrame
    if manager and manager.IsShown and manager:IsShown() then
        lastStatus = "Edit Mode staat open"
        return
    end
    local layouts, reason, entry, settings, settingID, name = getSavedOption()
    if not layouts then
        lastStatus = reason
        if report then say(lastStatus) end
        return
    end
    if entry and entry.value == 1 then
        lastStatus = "aan"
        if report then say("Use Raid-Style Party Frames staat al aan.") end
        return
    end
    if entry then
        entry.value = 1
    else
        table.insert(settings, {setting = settingID, value = 1})
    end

    -- Native saved-layout API; only one boolean changes. Do NOT invoke
    -- EditModeManagerFrame:OnSystemSettingChange, SaveLayouts, or any
    -- protected CompactUnitFrame functions (v0.3.22 taint regression).
    writing = true
    local ok, err = pcall(C_EditMode.SaveLayouts, layouts)
    writing = false
    if not ok then
        lastStatus = "opslaan mislukt: " .. tostring(err)
        say(lastStatus)
        return
    end
    lastStatus = "aan in '" .. name .. "'"
    say("Use Raid-Style Party Frames automatisch aangezet in layout '" .. name .. "'.")
end

function FC:PartyFramesCommand(command)
    if command == "apply" then
        apply(true)
    elseif command == "status" then
        local layouts, reason, entry = getSavedOption()
        local value = not layouts and ("onbekend (" .. tostring(reason) .. ")")
            or (entry and entry.value == 1 and "aan" or "uit")
        say("Party raid-style: " .. value
            .. " | class colors: " .. tostring(getCVar("raidFramesDisplayClassColor"))
            .. " | " .. lastStatus .. ".")
    else
        say("/fc party status | /fc party apply")
    end
end

local function schedule()
    if scheduled or writing then return end
    scheduled = true
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.5, function() apply(false) end)
        C_Timer.After(3, function()
            scheduled = false
            apply(false)
        end)
    else
        scheduled = false
        apply(false)
    end
end

events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if not pending then return end
        pending = false
    end
    schedule()
end)
