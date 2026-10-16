-- ForeverCore 0.2: raid debuffs and Taunt feedback (Forever beta).
-- No combat log / Taunt resist attribution is available to addons.
local FC = _G.ForeverCore
if not FC then return end
local f = CreateFrame("Frame")
local function db() return FC:GetDatabase() end
local function safe(x)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, x)
        if not ok or secret then return false end
    end
    if type(issecrettable) == "function" then
        local ok, secret = pcall(issecrettable, x)
        if not ok or secret then return false end
    end
    if type(canaccessvalue) == "function" then
        local ok, yes = pcall(canaccessvalue, x)
        if ok and not yes then return false end
    end
    return true
end
local function inRaid()
    if not IsInInstance then return false end
    local ok, yes, kind = pcall(IsInInstance)
    return ok and yes and kind == "raid"
end
local specs = {sunder = {7386,"Sunder Armor"}, demo = {1160,"Demoralizing Shout"}, thunder = {6343,"Thunder Clap"}}
local names = {}
local function resolve()
    for k, v in pairs(specs) do
        local name = v[2]
        if C_Spell and C_Spell.GetSpellInfo then
            local ok, spell = pcall(C_Spell.GetSpellInfo, v[1])
            if ok and safe(spell) and type(spell) == "table" then
                local n = spell.name
                if safe(n) and type(n) == "string" then name = n end
            end
        end
        names[k] = name
    end
end
local panel = CreateFrame("Frame","ForeverCoreDebuffs",UIParent,"BackdropTemplate")
panel:SetSize(465,62)
panel:SetPoint("CENTER",UIParent,"CENTER",0,155)
panel:SetFrameStrata("MEDIUM")
if panel.SetBackdrop then
    panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    panel:SetBackdropColor(0.035,0.045,0.07,0.9)
    panel:SetBackdropBorderColor(0.28,0.4,0.55,0.85)
end
local title = panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
title:SetPoint("TOPLEFT",panel,"TOPLEFT",12,-8)
title:SetText("FOREVERCORE  /  RAID DEBUFFS")
local state = panel:CreateFontString(nil,"OVERLAY","GameFontHighlight")
state:SetPoint("TOPLEFT",title,"BOTTOMLEFT",0,-9)
state:SetWidth(445)
state:SetJustifyH("LEFT")
panel:Hide()

local alert = CreateFrame("Frame","ForeverCoreTauntAlert",UIParent,"BackdropTemplate")
alert:SetSize(470,42)
alert:SetPoint("CENTER",UIParent,"CENTER",0,-80)
alert:SetFrameStrata("HIGH")
if alert.SetBackdrop then
    alert:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    alert:SetBackdropColor(0.05,0.03,0.03,0.94)
    alert:SetBackdropBorderColor(0.8,0.4,0.2,1)
end
local warning = alert:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
warning:SetPoint("CENTER")
alert:Hide()
local hideAt = 0
local function tauntNotice(msg,bad)
    local data = db()
    if not data or not data.tauntAlerts or not inRaid() then return end
    warning:SetText((bad and "|cffff5555" or "|cffffc15c") .. msg .. "|r")
    hideAt = GetTime() + 2.5
    alert:Show()
end
local function targetAvailable()
    if not UnitExists or not UnitCanAttack then return false end
    local ok1,exists = pcall(UnitExists,"target")
    local ok2,hostile = pcall(UnitCanAttack,"player","target")
    return ok1 and ok2 and safe(exists) and safe(hostile) and exists and hostile
end
local function scan()
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return nil end
    local seen, unknown = {}, false
    for i = 1,60 do
        local ok,aura = pcall(C_UnitAuras.GetAuraDataByIndex,"target",i,"HARMFUL")
        if not ok or not safe(aura) then return nil end
        if aura == nil then break end
        if type(aura) ~= "table" then return nil end
        local read,id,name,count = pcall(function() return aura.spellId,aura.name,aura.applications end)
        if not read or not safe(id) or not safe(name) then
            unknown = true
        else
            for k,v in pairs(specs) do
                if id == v[1] or (type(name) == "string" and name == names[k]) then
                    seen[k] = {stacks = (safe(count) and type(count) == "number") and count or nil}
                end
            end
        end
    end
    return seen,unknown
end
local function update()
    local data = db()
    if not data or not data.raidDebuffs or not inRaid() or not targetAvailable() then panel:Hide(); return end
    panel:Show()
    local found,unknown = scan()
    if not found then state:SetText("|cffacbac9Debuffs: unavailable / protected by Forever|r"); return end
    local function status(k,label)
        if found[k] then
            if k == "sunder" then
                local n = found[k].stacks
                if type(n) == "number" and n > 0 then
                    return label .. (n >= 5 and " |cff58f79a" or " |cffffc15b") .. n .. "/5|r"
                end
                return label .. " |cffffc15bACTIVE (?/5)|r"
            end
            return label .. " |cff58f79aOK|r"
        end
        return label .. (unknown and " |cffadb9c9?|r" or " |cffff6464MISSING|r")
    end
    state:SetText(status("sunder","Sunder").."  |  "..status("demo","Demo").."  |  "..status("thunder","T.Clap"))
end
function FC:UpdateRaidWarnings() update() end
for _,ev in ipairs({"PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","PLAYER_TARGET_CHANGED","UNIT_AURA","UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_FAILED"}) do f:RegisterEvent(ev) end
f:SetScript("OnEvent",function(_,ev,...)
    if not db() then return end
    if ev == "UNIT_SPELLCAST_SUCCEEDED" or ev == "UNIT_SPELLCAST_FAILED" then
        local unit,_,spellID = ...
        if unit == "player" and safe(spellID) and spellID == 355 then
            if ev == "UNIT_SPELLCAST_FAILED" then
                tauntNotice("TAUNT CAST FAILED - CHECK TARGET",true)
            else
                tauntNotice("TAUNT USED - VERIFY TARGET",false)
            end
        end
    elseif ev == "PLAYER_ENTERING_WORLD" then resolve();update()
    elseif ev == "UNIT_AURA" then
        local unit = ...
        if unit == "target" then update() end
    else update() end
end)
local tick = 0
f:SetScript("OnUpdate",function(_,elapsed)
    if alert:IsShown() and GetTime() > hideAt then alert:Hide() end
    tick = tick + elapsed
    if tick >= 0.8 then tick = 0; update() end
end)
