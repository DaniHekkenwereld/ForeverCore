-- ForeverCore: safe party frame status checker.
-- Raid-style party layout comes from Blizzard's saved Edit Mode layout.
-- Setting class colors is handled by AccountSetup.lua through the CVar.
-- Never call EditModeManagerFrame:OnSystemSettingChange or SaveLayouts
-- programmatically: those calls tainted CompactUnitFrame_UpdateHealthColor
-- on the Forever client when secret health/color data was used.
local FC = _G.ForeverCore
if not FC then return end

local f = CreateFrame("Frame")
local warned = false
local function say(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80c9ffForeverCore|r " .. tostring(msg))
    end
end

local function getCVar(name)
    local read = (C_CVar and C_CVar.GetCVar) or GetCVar
    if type(read) ~= "function" then return nil end
    local ok, value = pcall(read, name)
    if ok and value ~= nil then return tostring(value) end
    return nil
end

local function getRaidStyle()
    local e = Enum
    if type(e) ~= "table" or type(e.EditModeSystem) ~= "table"
        or type(e.EditModeUnitFrameSystemIndices) ~= "table"
        or type(e.EditModeUnitFrameSetting) ~= "table" then return nil end
    local system = e.EditModeSystem.UnitFrame
    local index = e.EditModeUnitFrameSystemIndices.Party
    local setting = e.EditModeUnitFrameSetting.UseRaidStylePartyFrames
    local manager = _G.EditModeManagerFrame
    if system == nil or index == nil or setting == nil or not manager
        or type(manager.GetSettingValueBool) ~= "function" then return nil end
    local ok, enabled = pcall(manager.GetSettingValueBool, manager, system, index, setting)
    if ok and type(enabled) == "boolean" then return enabled end
    return nil
end

function FC:PartyFramesCommand(command)
    if command == "status" or command == "apply" then
        local style = getRaidStyle()
        say("Party raid-style: " ..
            (style == nil and "onbekend" or (style and "aan" or "uit"))
            .. " | class colors: " .. tostring(getCVar("raidFramesDisplayClassColor")) .. ".")
        if command == "apply" then
            say("Partyinstellingen komen uit je Blizzard Edit Mode-layout."
                .. " /fc layout apply kiest het opgeslagen layout; dit commando wijzigt geen beveiligde frames.")
        elseif style == false then
            say("Zet Use Raid-Style Party Frames eenmalig aan in Blizzard Edit Mode,"
                .. " sla het layout op en maak op Dien Warr opnieuw /fc layout capture.")
        end
    else
        say("/fc party status (read-only) | /fc layout apply")
    end
end

-- The LayoutTemplate module selects the saved Edit Mode account layout on
-- new characters. Do not programmatically mutate a loaded party system.
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
    if warned then return end
    if not (C_Timer and type(C_Timer.After) == "function") then return end
    C_Timer.After(5, function()
        if warned then return end
        local style = getRaidStyle()
        if style == false then
            warned = true
            say("Party raid-style staat UIT in het actieve Edit Mode-layout."
                .. " Zet dit aan op Dien Warr, sla op en doe opnieuw /fc layout capture.")
        end
    end)
end)
