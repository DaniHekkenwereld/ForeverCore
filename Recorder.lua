-- ForeverCore: passive levelling/Warrior gameplay recorder for WoW Forever.
-- Local-only SavedVariables + optional native /combatlog. No protected combat-log parsing.
local FC = _G.ForeverCore
if not FC then return end
local f = CreateFrame("Frame")
local VERSION, MAX_SESSIONS, MAX_RECORDS, TRIM_BATCH = 1, 8, 15000, 2500
local SAMPLE_SECONDS = 1.5
local session, settings, nextNativeAttempt
local nativeAttempts, combat, lastRage, lastRageAt = 0, false, nil, 0
local equipmentPending, refreshClock, mapClock = false, 0, 0

local function say(s)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff80c9ffForeverCore Recorder|r " .. s) end
end
local function safe(x)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, x)
        if not ok or secret then return false end
    end
    if type(canaccessvalue) == "function" then
        local ok, yes = pcall(canaccessvalue, x)
        if not ok or not yes then return false end
    end
    return true
end
local function num(x)
    if safe(x) and type(x) == "number" then return x end
    return nil
end
local function txt(x)
    if safe(x) and type(x) == "string" then return x:sub(1, 80) end
    return nil
end
local function clock() return (type(GetTime) == "function" and GetTime()) or 0 end
local function epoch()
    for _, fn in ipairs({GetServerTime, time}) do
        if type(fn) == "function" then
            local ok, value = pcall(fn)
            if ok and num(value) then return value end
        end
    end
    return 0
end
local function stance()
    if type(GetShapeshiftForm) ~= "function" then return nil end
    local ok, value = pcall(GetShapeshiftForm)
    return ok and num(value) or nil
end
local function rage()
    if type(UnitPower) ~= "function" then return nil end
    local ok, value = pcall(UnitPower, "player", 1)
    return ok and num(value) or nil
end
local function inCombat()
    if type(InCombatLockdown) == "function" then
        local ok, value = pcall(InCombatLockdown)
        if ok and safe(value) and type(value) == "boolean" then return value end
    end
    return combat
end
local function append(kind, a, b, c)
    if not settings or not settings.enabled or not session then return end
    local rows = session.records
    if #rows >= MAX_RECORDS then
        local kept = #rows - TRIM_BATCH
        for i = 1, kept do rows[i] = rows[i + TRIM_BATCH] end
        for i = kept + 1, #rows do rows[i] = nil end
        session.dropped = (session.dropped or 0) + TRIM_BATCH
    end
    rows[#rows+1] = {math.floor((clock() - session.startedAt)*1000 + 0.5), kind, a, b, c}
    session.total = (session.total or 0) + 1
end
local function sampleRage(force)
    local r = rage()
    if r == nil then return end
    local t = clock()
    if force or (r ~= lastRage and t - lastRageAt >= SAMPLE_SECONDS) then
        append("rage", r, stance())
        lastRage, lastRageAt = r, t
    end
end
local function nativeState()
    if type(LoggingCombat) ~= "function" then return nil end
    local ok, v = pcall(LoggingCombat)
    if not ok or not safe(v) then return nil end
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    return nil
end
local function startNative()
    if not settings or not settings.native or not session then return end
    if nativeState() == true then nextNativeAttempt = nil; return end
    nativeAttempts = nativeAttempts + 1
    if type(LoggingCombat) == "function" then pcall(LoggingCombat, true) end
    if nativeState() == true then
        nextNativeAttempt = nil; append("native", 1); return
    end
    if nativeAttempts >= 4 then
        nextNativeAttempt = nil
        if not session.nativeWarned then
            session.nativeWarned = true
            say("Game-combatlog niet bevestigd. Check /combatlog en /fc record status.")
        end
    else
        nextNativeAttempt = clock() + nativeAttempts*4
    end
end
local function scheduleNative()
    if not settings or not settings.native then return end
    nativeAttempts, nextNativeAttempt = 0, clock()+2
end
local function snapshotEquipment()
    if type(GetInventoryItemID) ~= "function" or inCombat() then
        equipmentPending = true; return
    end
    equipmentPending = false
    local items = {}
    for slot=1,19 do
        local ok, id = pcall(GetInventoryItemID, "player", slot)
        items[slot] = (ok and num(id)) or 0
    end
    if session then
        local signature = table.concat(items, ",")
        if signature ~= session.lastEquipment then
            session.lastEquipment = signature
            append("equipment", signature)
        end
    end
end
local function snapshotXP()
    if type(UnitXP) ~= "function" or type(UnitXPMax) ~= "function" then return end
    local ok1, v = pcall(UnitXP,"player")
    local ok2, maximum = pcall(UnitXPMax,"player")
    v, maximum = ok1 and num(v) or nil, ok2 and num(maximum) or nil
    if v and maximum and session and (v ~= session.lastXP or maximum ~= session.lastXPMax) then
        session.lastXP, session.lastXPMax = v, maximum
        append("xp", v, maximum)
    end
end
local function snapshotZone()
    if not session then return end
    local z, sub
    if type(GetZoneText) == "function" then
        local ok, v=pcall(GetZoneText)
        if ok then z=txt(v) end
    end
    if type(GetSubZoneText) == "function" then
        local ok, v=pcall(GetSubZoneText)
        if ok then sub=txt(v) end
    end
    if z ~= session.lastZone or sub ~= session.lastSubzone then
        session.lastZone, session.lastSubzone = z, sub
        append("zone",z or "?",sub or "")
    end
end
local function snapshotPosition()
    -- Open-world route checkpoints only. Never sample restricted combat positions.
    if inCombat() or not session or not C_Map or
       type(C_Map.GetBestMapForUnit) ~= "function" or
       type(C_Map.GetPlayerMapPosition) ~= "function" then return end
    local ok, mapID=pcall(C_Map.GetBestMapForUnit,"player")
    mapID = ok and num(mapID) or nil
    if not mapID then return end
    local posOK, pos=pcall(C_Map.GetPlayerMapPosition,mapID,"player")
    if not posOK or not safe(pos) or not pos then return end
    local xyOK, x, y=pcall(function() return pos:GetXY() end)
    x, y=xyOK and num(x) or nil,xyOK and num(y) or nil
    if not x or not y or x<0 or x>1 or y<0 or y>1 then return end
    append("position",mapID,math.floor(x*1000+0.5),math.floor(y*1000+0.5))
end
local function snapshotLevel()
    if type(UnitLevel) ~= "function" then return end
    local ok,v=pcall(UnitLevel,"player")
    if ok and num(v) and session and session.lastLevel ~= v then
        session.lastLevel=v; append("level",v)
    end
end
local function createSession()
    local db=FC:GetDatabase()
    if not db then return end
    if type(db.recorder) ~= "table" then db.recorder={} end
    settings=db.recorder
    if settings.enabled == nil then settings.enabled=true end
    if settings.native == nil then settings.native=true end
    if type(settings.sessions) ~= "table" then settings.sessions={} end
    if session then return end
    session = {
        schema=VERSION, startedEpoch=epoch(), startedAt=clock(),
        client=(type(GetBuildInfo)=="function" and select(1,GetBuildInfo())) or "unknown",
        records={}, total=0, dropped=0
    }
    table.insert(settings.sessions,session)
    while #settings.sessions>MAX_SESSIONS do table.remove(settings.sessions,1) end
    append("session","start")
    snapshotLevel(); snapshotZone(); snapshotXP(); snapshotEquipment()
    snapshotPosition(); sampleRage(true); scheduleNative()
end
local function status()
    if not settings then say("Recorder nog niet geladen."); return end
    local v=nativeState()
    local state=v==nil and "ONBEKEND" or (v and "AAN" or "UIT")
    say(string.format("Gameplay %s | sessies %d | huidige events %d | geroteerd %d",
        settings.enabled and "AAN" or "UIT",#settings.sessions,
        session and #session.records or 0,session and (session.dropped or 0) or 0))
    say("Game-combatlog: "..state.." | automatisch starten: "..(settings.native and "AAN" or "UIT"))
    say("Gameplay: WTF/Account/.../SavedVariables/ForeverCore.lua (na logout of /reload)")
    say("Combat: World of Warcraft/Logs/WoWCombatLog*.txt (kan groot worden)")
end
local function summary()
    if not session then say("Nog geen sessie."); return end
    local casts,failed,stances,deaths,quests=0,0,0,0,0
    local combatStart,combatSeconds=nil,0
    for _,e in ipairs(session.records) do
        local ms,kind=e[1],e[2]
        if kind=="cast" then casts=casts+1
        elseif kind=="castFailed" then failed=failed+1
        elseif kind=="stance" then stances=stances+1
        elseif kind=="death" then deaths=deaths+1
        elseif kind=="questDone" then quests=quests+1
        elseif kind=="combat" and e[3]==1 then combatStart=ms
        elseif kind=="combat" and e[3]==0 and combatStart then
            combatSeconds=combatSeconds+(ms-combatStart)/1000;combatStart=nil
        end
    end
    if combatStart then combatSeconds=combatSeconds+(clock()*1000-session.startedAt*1000-combatStart)/1000 end
    say(string.format("Bewaarde events: %d casts, %d cast-fails, %d stancewissels, %d deaths, %d quests, %.0f sec in combat.",
        casts,failed,stances,deaths,quests,math.max(0,combatSeconds)))
    if (session.dropped or 0)>0 then say("Oudere events geroteerd; samenvatting is partieel.") end
end
function FC:RecorderCommand(line)
    local cmd,sub,value=(line or ""):lower():match("^%s*(%S*)%s*(%S*)%s*(%S*)")
    if cmd=="mark" then
        local label=txt((line or ""):match("^%s*%S+%s*(.-)%s*$"))
        if label and label~="" then append("mark",label);say("Markering: "..label)
        else say("Gebruik /fc mark <notitie>") end
        return
    end
    if cmd=="combatlog" then value,cmd,sub=sub,"record","native" end
    if cmd=="record" and sub=="summary" then summary();return end
    if cmd=="record" and (sub=="" or sub=="status") then status();return end
    if cmd=="record" and (sub=="on" or sub=="off") then
        settings.enabled=sub=="on"
        if settings.enabled then
            append("recording","on");snapshotXP();snapshotEquipment();sampleRage(true)
        end
        say("Gameplay recorder "..(settings.enabled and "aan" or "uit"));return
    end
    if cmd=="record" and sub=="native" and (value=="on" or value=="off") then
        settings.native=value=="on"
        if settings.native then scheduleNative();startNative()
        else nextNativeAttempt=nil end
        say("Automatisch game-combatloggen "..(settings.native and "aan" or "uit")..
            ". Al lopende /combatlog wordt niet geforceerd gestopt.")
        return
    end
    say("Gebruik /fc record [status|summary|on|off|native on|native off] of /fc mark <notitie>")
end
local function spell(kind,unit,_,spellID)
    if unit~="player" or not num(spellID) then return end
    append(kind,spellID,stance(),rage())
end
local function snapshotTarget()
    if inCombat() or not session or not UnitExists or not UnitGUID or not UnitIsPlayer then return end
    local ok1,exists=pcall(UnitExists,"target")
    local ok2,player=pcall(UnitIsPlayer,"target")
    if not ok1 or not ok2 or not safe(exists) or not safe(player) or not exists or player then return end
    local ok,guid=pcall(UnitGUID,"target")
    if not ok or not safe(guid) or type(guid)~="string" then return end
    local id=guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    id=id and tonumber(id) or nil
    if not id then return end
    local level
    if type(UnitLevel)=="function" then
        local lvok,lv=pcall(UnitLevel,"target")
        if lvok then level=num(lv) end
    end
    append("target",id,level)
end

local events={
    "PLAYER_ENTERING_WORLD","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED",
    "UNIT_SPELLCAST_START","UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED","UNIT_POWER_UPDATE","UPDATE_SHAPESHIFT_FORM",
    "PLAYER_LEVEL_UP","PLAYER_XP_UPDATE","PLAYER_DEAD","PLAYER_ALIVE",
    "PLAYER_UNGHOST","QUEST_ACCEPTED","QUEST_TURNED_IN",
    "PLAYER_EQUIPMENT_CHANGED","ZONE_CHANGED_NEW_AREA","PLAYER_TARGET_CHANGED","PLAYER_LOGOUT"
}
for _,ev in ipairs(events) do f:RegisterEvent(ev) end
f:SetScript("OnEvent",function(_,ev,...)
    if ev=="PLAYER_ENTERING_WORLD" then
        createSession()
        if settings then append("world","enter");snapshotZone();scheduleNative() end
        return
    end
    if not session then return end
    if ev=="PLAYER_REGEN_DISABLED" then
        combat=true;append("combat",1,stance(),rage());sampleRage(true)
    elseif ev=="PLAYER_REGEN_ENABLED" then
        combat=false;append("combat",0,stance(),rage());sampleRage(true)
        snapshotXP();if equipmentPending then snapshotEquipment() end
    elseif ev=="UNIT_SPELLCAST_START" then spell("castStart",...)
    elseif ev=="UNIT_SPELLCAST_SUCCEEDED" then spell("cast",...)
    elseif ev=="UNIT_SPELLCAST_FAILED" then spell("castFailed",...)
    elseif ev=="UNIT_SPELLCAST_INTERRUPTED" then spell("castInterrupted",...)
    elseif ev=="UNIT_POWER_UPDATE" then
        local unit,powerName=...
        if unit=="player" and safe(powerName) and powerName=="RAGE" then sampleRage(false) end
    elseif ev=="UPDATE_SHAPESHIFT_FORM" then append("stance",stance(),rage())
    elseif ev=="PLAYER_LEVEL_UP" then local lvl=...;append("levelUp",num(lvl));snapshotXP()
    elseif ev=="PLAYER_XP_UPDATE" then snapshotXP()
    elseif ev=="PLAYER_DEAD" then append("death",stance())
    elseif ev=="PLAYER_ALIVE" or ev=="PLAYER_UNGHOST" then append("alive")
    elseif ev=="QUEST_ACCEPTED" then
        local idx,id=...
        append("questStart",num(id) or num(idx));snapshotPosition()
    elseif ev=="QUEST_TURNED_IN" then
        local id,xp=...
        append("questDone",num(id),num(xp));snapshotXP();snapshotPosition()
    elseif ev=="PLAYER_EQUIPMENT_CHANGED" then snapshotEquipment()
    elseif ev=="ZONE_CHANGED_NEW_AREA" then snapshotZone();snapshotPosition();scheduleNative()
    elseif ev=="PLAYER_TARGET_CHANGED" then snapshotTarget()
    elseif ev=="PLAYER_LOGOUT" then append("session","end");session.endedEpoch=epoch()
    end
end)
f:SetScript("OnUpdate",function(_,elapsed)
    if not session then return end
    if nextNativeAttempt and clock()>=nextNativeAttempt then
        nextNativeAttempt=nil;startNative()
    end
    if not settings or not settings.enabled then return end
    mapClock=mapClock+elapsed
    if mapClock>=30 then mapClock=0;snapshotPosition() end
    refreshClock=refreshClock+elapsed
    if refreshClock>=SAMPLE_SECONDS then
        refreshClock=0
        if combat then sampleRage(false) end
    end
end)
