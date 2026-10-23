-- ForeverCore 0.3.10-beta (WoW: Forever Beta / Camelot)
-- Display and convenience only. Does not automate spells or bypass protected APIs.

local FC = CreateFrame("Frame")
_G.ForeverCore = FC
local prefix = "|cff80c9ffForeverCore|r "
local defaults = {
    plateMode = "auto",       -- auto: friendly plates only inside raid instances
    profile = "tank",         -- manual: tank, fury or arms; beta talents API differs
    checkFlask = true,
    checkFood = true,
    checkShout = true,
    raidDebuffs = true,
    tauntAlerts = true,
    showOutsideRaid = false,
    x = 0,
    y = -195,
}
local db
function FC:GetDatabase() return db end
local inRaid = false
local pendingPlateSync = false
local lastPlates = nil
local plateWriteBlocked = false -- beta may reject this CVar; avoid spamming writes
local lastResult = {}
local combat = false

local function say(msg)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(prefix .. tostring(msg)) end
end
local function readable(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    if type(canaccessvalue) == "function" then
        local ok, accessible = pcall(canaccessvalue, value)
        if ok and not accessible then return false end
    end
    return true
end
local function raidInstance()
    local ok, inside, kind = pcall(IsInInstance)
    return ok and inside and kind == "raid"
end
local function getCVarValue(key)
    local getter = (C_CVar and C_CVar.GetCVar) or GetCVar
    if not getter then return nil end
    local ok, result = pcall(getter, key)
    if ok and readable(result) then return result end
    return nil
end
local function setCVarValue(key, value)
    local setter = (C_CVar and C_CVar.SetCVar) or SetCVar
    if not setter then return false end
    local ok = pcall(setter, key, value)
    return ok and getCVarValue(key) == value
end
local function syncPlates()
    if not db or plateWriteBlocked then return end
    if InCombatLockdown and InCombatLockdown() then
        pendingPlateSync = true
        return
    end
    local desired = db.plateMode == "on" or (db.plateMode == "auto" and inRaid)
    local value = desired and "1" or "0"
    if lastPlates ~= value or getCVarValue("nameplateShowFriends") ~= value then
        if not setCVarValue("nameplateShowFriends", value) then
            plateWriteBlocked = true
            say("Forever beta weigert nameplate-CVar. Geen verdere automatische pogingen; pas dit aan via de gameopties.")
            pendingPlateSync = false
            return
        end
        lastPlates = value
    end
    pendingPlateSync = false
end

-- Compact icon-only Battle Shout reminder; no dialog, labels or stance alerts.
local frame = CreateFrame("Frame", "ForeverCorePrepull", UIParent)
frame:SetSize(54, 54)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, -195)
frame:SetFrameStrata("HIGH")
frame:EnableMouse(false)
frame:Hide()

local function iconTexture(spellID, fallback)
    if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and readable(texture) and (type(texture) == "string" or type(texture) == "number") then
            return texture
        end
    end
    if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and readable(info) and type(info) == "table" then
            local texture = info.iconID
            if readable(texture) and (type(texture) == "string" or type(texture) == "number") then
                return texture
            end
        end
    end
    if type(GetSpellTexture) == "function" then
        local ok, texture = pcall(GetSpellTexture, spellID)
        if ok and readable(texture) and (type(texture) == "string" or type(texture) == "number") then
            return texture
        end
    end
    return fallback
end
local function createReminder(spellID, fallback)
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetSize(44, 44)
    holder:SetPoint("CENTER", frame, "CENTER", 0, 0)

    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(holder)
    icon:SetTexture(iconTexture(spellID, fallback))
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = holder:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetSize(64, 64)
    border:SetPoint("CENTER", holder, "CENTER", 0, 0)
    border:SetVertexColor(1, 0.68, 0.15)
    border:SetAlpha(0.7)

    local glow = holder:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetPoint("CENTER", holder, "CENTER", 0, 0)
    glow:SetSize(70, 70)
    glow:SetVertexColor(1, 0.72, 0.25)
    glow:SetAlpha(0.28)

    holder.glow = glow
    holder.border = border
    holder:Hide()
    return holder
end
local shoutIcon = createReminder(6673, "Interface\\Icons\\Ability_Warrior_BattleShout")

local pulseTime = 0
frame:SetScript("OnUpdate", function(_, elapsed)
    pulseTime = pulseTime + elapsed
    local pulse = 0.46 + 0.3 * math.sin(pulseTime * 4.5)
    if shoutIcon:IsShown() then
        shoutIcon.border:SetAlpha(pulse)
        shoutIcon.glow:SetAlpha(pulse * 0.64)
    end
end)

local function hasAuras()
    -- Aura values can become 'secret' in combat on Forever. Deliberately scan only OOC.
    local found = {flask = false, food = false, shout = false}
    if InCombatLockdown and InCombatLockdown() then return nil end
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
    local shoutName = "battle shout"
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, spell = pcall(C_Spell.GetSpellInfo, 6673)
        if ok and type(spell) == "table" and readable(spell.name) and type(spell.name) == "string" then
            shoutName = string.lower(spell.name)
        end
    end
    for i = 1, 60 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok then return nil end
        if not aura then break end
        if type(aura) == "table" and readable(aura.name) and type(aura.name) == "string" then
            local name = string.lower(aura.name)
            if name:find("flask", 1, true) or name:find("flacon", 1, true) then found.flask = true end
            if name:find("well fed", 1, true) or name:find("goed gevoed", 1, true) then found.food = true end
            if name == shoutName then found.shout = true end
        end
    end
    return found
end
local function shieldEquipped()
    if not (GetInventoryItemID and C_Item and C_Item.GetItemInfoInstant) then return nil end
    local itemID = GetInventoryItemID("player", 17)
    if not itemID then return false end
    local ok, _, _, _, equipLoc = pcall(C_Item.GetItemInfoInstant, itemID)
    if not ok or not readable(equipLoc) then return nil end
    return equipLoc == "INVTYPE_SHIELD"
end
local function showFrame()
    return inRaid or db.showOutsideRaid
end
local function refresh()
    if not db then return end
    inRaid = raidInstance()
    if not showFrame() then frame:Hide(); return end
    -- Combat aura data can be protected; never claim a missing buff when unreadable.
    if InCombatLockdown and InCombatLockdown() then
        frame:Hide()
        return
    end
    local aura = hasAuras()
    if not aura then frame:Hide(); return end
    if not UnitClass or select(2, UnitClass("player")) ~= "WARRIOR" then
        frame:Hide()
        return
    end

    -- Only Battle Shout: show the icon if the buff is missing, hide if present.
    local missingShout = db.checkShout and not aura.shout
    if missingShout then
        shoutIcon:Show()
        frame:Show()
    else
        shoutIcon:Hide()
        frame:Hide()
    end
end
local function position()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
end
local function moveFrame()
    if InCombatLockdown and InCombatLockdown() then say("Verplaatsen kan alleen buiten combat."); return end
    frame:Show()
    shoutIcon:Show()
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if x and y and ux and uy then db.x, db.y = math.floor(x - ux), math.floor(y - uy) end
        position()
        self:EnableMouse(false)
        self:SetScript("OnDragStart", nil)
        self:SetScript("OnDragStop", nil)
        refresh()
        say("Positie opgeslagen. Let op: SavedVariables zijn in sommige beta-builds defect.")
    end)
    say("Sleep het Battle Shout-icoon met de linkermuisknop. Loslaten bewaart de positie.")
end

-- Each entry is a regular WoW macro. A user keypress is always required.
local macros = {
    {"FC-Sunder", "#showtooltip Sunder Armor\n/startattack [harm]\n/cast [harm] Sunder Armor"},
    {"FC-Revenge", "#showtooltip Revenge\n/startattack [harm]\n/cast [harm] Revenge"},
    {"FC-Taunt", "#showtooltip Taunt\n/cast [@mouseover,harm,nodead][harm] Taunt"},
    {"FC-ShBlock", "#showtooltip Shield Block\n/cast [stance:2] Shield Block; Defensive Stance"},
    {"FC-ShWall", "#showtooltip Shield Wall\n/cast [stance:2] Shield Wall; Defensive Stance"},
    {"FC-Reck", "#showtooltip Recklessness\n/cast [stance:3] Recklessness; Berserker Stance"},
    {"FC-Retal", "#showtooltip Retaliation\n/cast [stance:1] Retaliation; Battle Stance"},
    {"FC-3CDs", "#showtooltip [stance:1] Retaliation; [stance:2] Shield Wall; [stance:3] Recklessness\n/cast [stance:1] Retaliation; [stance:2] Shield Wall; [stance:3] Recklessness"},
    {"FC-BT", "#showtooltip Bloodthirst\n/startattack [harm]\n/cast [harm] Bloodthirst"},
    {"FC-WW", "#showtooltip Whirlwind\n/cast [stance:3] Whirlwind; Berserker Stance"},
    {"FC-Execute", "#showtooltip Execute\n/startattack [harm]\n/cast [harm] Execute"},
    {"FC-Pummel", "#showtooltip\n/cast [stance:3] Pummel; [stance:1/2] Shield Bash"},
    -- Combo macros: normal press = Reck, Shift = Retal, Ctrl = Shield Wall.
    -- Manual modifier progression, intentionally not automatic combat decisions.
    {"FC-ReckRet", "#showtooltip\n/cast [mod:shift,stance:1] Retaliation; [mod:shift] Battle Stance; [stance:3] Recklessness; Berserker Stance"},
    {"FC-ReckWall", "#showtooltip\n/cast [mod:shift,stance:2] Shield Wall; [mod:shift] Defensive Stance; [stance:3] Recklessness; Berserker Stance"},
    {"FC-All3", "#showtooltip\n/cast [mod:ctrl,stance:2] Shield Wall; [mod:ctrl] Defensive Stance; [mod:shift,stance:1] Retaliation; [mod:shift] Battle Stance; [stance:3] Recklessness; Berserker Stance"},
}
local function macroExists(name)
    if GetMacroIndexByName then
        local ok, index = pcall(GetMacroIndexByName, name)
        return ok and type(index) == "number" and index > 0
    end
    return false
end
local function installMacros()
    if InCombatLockdown and InCombatLockdown() then
        say("Macro's aanmaken kan alleen buiten combat.")
        return
    end
    if UnitClass and select(2, UnitClass("player")) ~= "WARRIOR" then
        say("Deze macroset is alleen bedoeld voor Warriors.")
        return
    end
    if not CreateMacro then say("CreateMacro-API ontbreekt in deze build."); return end
    local created, skipped, failed = 0, 0, 0
    for _, entry in ipairs(macros) do
        local name, body = entry[1], entry[2]
        if macroExists(name) then
            skipped = skipped + 1
        elseif #body > 255 then
            failed = failed + 1
            say(name .. " over 255 karakters; overgeslagen.")
        else
            local ok, index = pcall(CreateMacro, name, "INV_MISC_QUESTIONMARK", body, true)
            if ok and type(index) == "number" and index > 0 then
                created = created + 1
            else
                failed = failed + 1
                say("Kon " .. name .. " niet toevoegen (mogelijk macro-limiet).")
            end
        end
    end
    say(string.format("Macro's: %d nieuw, %d bestonden al, %d mislukt. Open /macro en sleep ze naar je bars.", created, skipped, failed))
    say("Combo's: FC-ReckRet = normaal Reck, Shift Retal; FC-ReckWall = normaal Reck, Shift Wall; FC-All3 = normaal Reck, Shift Retal, Ctrl Wall. Wisselen van stance kan een extra druk vereisen.")
end
local function switch(v)
    if v == "on" then return true elseif v == "off" then return false end
    return nil
end
local function handle(line)
    if not db then return end
    local arg, val = line:lower():match("^%s*(%S*)%s*(%S*)")
    if arg == "" or arg == "help" then
        say("/fc check | /fc move | /fc macros | /fc openers [prot/fury/arms]")
        say("/fc setup [capture|status|apply|restore|bindings|settings]")
        say("/fc plates auto/on/off | /fc mode tank/fury/arms | /fc alerts on/off | /fc taunt on/off")
        say("/fc flask on/off | /fc food on/off | /fc shout on/off | /fc show on/off")
        say("/fc record [status|summary|on|off|native on|native off] | /fc mark <notitie>")
    elseif arg == "record" or arg == "combatlog" or arg == "mark" then
        if FC.RecorderCommand then FC:RecorderCommand(line) else say("Recorder-module ontbreekt.") end
    elseif arg == "setup" then
        if FC.SetupCommand then
            FC:SetupCommand(line:match("^%s*%S+%s*(.-)%s*$") or "")
        else
            say("AccountSetup.lua is niet geladen.")
        end
    elseif arg == "check" then
        refresh()
        say("Pre-pull controle uitgevoerd (alleen buiten combat, vereist beschikbare aura-API).")
    elseif arg == "move" then
        moveFrame()
    elseif arg == "macros" then
        installMacros()
    elseif arg == "openers" then
        if FC.ShowOpeners then FC:ShowOpeners(val) else say("Opener-module niet geladen.") end
    elseif arg == "plates" and (val == "auto" or val == "on" or val == "off") then
        db.plateMode = val
        lastPlates = nil
        plateWriteBlocked = false -- manual user request may try again
        syncPlates()
        say("Friendly nameplates: " .. val)
    elseif arg == "mode" and (val == "tank" or val == "fury" or val == "arms") then
        db.profile = val
        refresh()
        say("Warrior-profiel: " .. val .. " (handmatig; geen automatische talentscan).")
    elseif (arg == "flask" or arg == "food" or arg == "shout" or arg == "show" or arg == "alerts" or arg == "taunt") and switch(val) ~= nil then
        local key = ({flask = "checkFlask", food = "checkFood", shout = "checkShout", show = "showOutsideRaid", alerts = "raidDebuffs", taunt = "tauntAlerts"})[arg]
        db[key] = switch(val)
        refresh()
        if FC.UpdateRaidWarnings then FC:UpdateRaidWarnings() end
        say(arg .. " = " .. val)
    else
        say("Onbekende opdracht. Typ /fc help.")
    end
end
SLASH_FOREVERCORE1 = "/fc"
SLASH_FOREVERCORE2 = "/forevercore"
SlashCmdList.FOREVERCORE = handle

FC:RegisterEvent("ADDON_LOADED")
FC:RegisterEvent("PLAYER_ENTERING_WORLD")
FC:RegisterEvent("ZONE_CHANGED_NEW_AREA")
FC:RegisterEvent("GROUP_ROSTER_UPDATE")
FC:RegisterEvent("PLAYER_REGEN_DISABLED")
FC:RegisterEvent("PLAYER_REGEN_ENABLED")
FC:RegisterEvent("UNIT_AURA")
FC:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
FC:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if (...) ~= "ForeverCore" then return end
        if type(ForeverCoreDB) ~= "table" then ForeverCoreDB = {} end
        db = ForeverCoreDB
        for k, v in pairs(defaults) do
            if db[k] == nil then db[k] = v end
        end
        position()
        say("ForeverCore geladen. Gameplay recorder standaard aan; /fc record status en /fc help.")
    elseif not db then
        return
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "GROUP_ROSTER_UPDATE" then
        inRaid = raidInstance()
        syncPlates()
        refresh()
    elseif event == "PLAYER_REGEN_DISABLED" then
        refresh()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingPlateSync then syncPlates() end
        refresh()
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" and not (InCombatLockdown and InCombatLockdown()) then refresh() end
    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        if not (InCombatLockdown and InCombatLockdown()) then refresh() end
    end
end)
