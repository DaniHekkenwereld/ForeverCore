-- ForeverCore 0.3.23-beta (WoW: Forever Beta / Camelot)
-- Display and convenience only. Does not automate spells or bypass protected APIs.

local FC = CreateFrame("Frame")
_G.ForeverCore = FC
local prefix = "|cff80c9ffForeverCore|r "
local defaults = {
    plateMode = "auto",       -- auto: friendly plates only inside raid instances
    profile = "tank",         -- manual: tank, fury or arms; beta talents API differs
    raidDebuffs = true,
    tauntAlerts = true,
}
local db
function FC:GetDatabase() return db end
local inRaid = false
local pendingPlateSync = false
local lastPlates = nil
local plateWriteBlocked = false -- beta may reject this CVar; avoid spamming writes

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
        say("/fc macros | /fc openers [prot/fury/arms] | /fc mode tank/fury/arms")
        say("/fc setup [capture|status|apply|restore|bindings|settings]")
        say("/fc plates auto/on/off | /fc mode tank/fury/arms | /fc alerts on/off | /fc taunt on/off")
        say("/fc chat status | /fc chat setup   (Party + Whispers tabs)")
        say("/fc bartender status | /fc bartender apply | /fc layout capture/status/apply")
        say("/fc party status (raid-style + class colors; via opgeslagen Edit Mode layout)")
        say("/fc record [status|summary|on|off|native on|native off] | /fc mark <notitie>")
    elseif arg == "record" or arg == "combatlog" or arg == "mark" then
        if FC.RecorderCommand then FC:RecorderCommand(line) else say("Recorder-module ontbreekt.") end
    elseif arg == "setup" then
        if FC.SetupCommand then
            FC:SetupCommand(line:match("^%s*%S+%s*(.-)%s*$") or "")
        else
            say("AccountSetup.lua is niet geladen.")
        end
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
        say("Warrior-profiel: " .. val .. " (handmatig; geen automatische talentscan).")
    elseif arg == "layout" then
        if FC.LayoutTemplateCommand then
            FC:LayoutTemplateCommand(val)
        else
            say("LayoutTemplate.lua is niet geladen.")
        end
    elseif arg == "party" then
        if FC.PartyFramesCommand then
            FC:PartyFramesCommand(val)
        else
            say("PartyFrames.lua is niet geladen.")
        end
    elseif arg == "bartender" then
        if FC.BartenderCommand then
            FC:BartenderCommand(val)
        else
            say("BartenderSetup.lua is niet geladen.")
        end
    elseif arg == "chat" then
        if FC.ChatCommand then
            FC:ChatCommand(val)
        else
            say("ChatSetup.lua is niet geladen.")
        end
    elseif (arg == "alerts" or arg == "taunt") and switch(val) ~= nil then
        local key = ({alerts = "raidDebuffs", taunt = "tauntAlerts"})[arg]
        db[key] = switch(val)
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
FC:RegisterEvent("PLAYER_REGEN_ENABLED")
FC:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if (...) ~= "ForeverCore" then return end
        if type(ForeverCoreDB) ~= "table" then ForeverCoreDB = {} end
        db = ForeverCoreDB
        for k, v in pairs(defaults) do
            if db[k] == nil then db[k] = v end
        end
        say("ForeverCore geladen. Gameplay recorder standaard aan; /fc record status en /fc help.")
    elseif not db then
        return
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "GROUP_ROSTER_UPDATE" then
        inRaid = raidInstance()
        syncPlates()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingPlateSync then syncPlates() end
    end
end)
