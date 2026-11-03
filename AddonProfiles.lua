-- ForeverCore: optional Details! + Questie interface profile snapshot.
-- Only addon UI profiles are copied. Quest progression and combat history are
-- deliberately not copied; the addons own those per-character records.
local FC = _G.ForeverCore
if not FC then return end

local eventFrame = CreateFrame("Frame")
local busy = false
local warned = {}
local detailsName = "FC Dien Warr Details"
local questieName = "FC Dien Warr Questie"

local function say(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80c9ffForeverCore|r " .. tostring(message))
    end
end

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function playerGUID()
    if type(UnitGUID) ~= "function" then return nil end
    local ok, value = pcall(UnitGUID, "player")
    if ok and type(value) == "string" and value ~= "" then return value end
    return nil
end

local function layout()
    local root = FC.GetDatabase and FC:GetDatabase()
    if root and type(root.layoutTemplate) == "table" then return root.layoutTemplate end
    return nil
end

local function questie()
    local q = _G.Questie
    local database = q and q.db
    if type(database) ~= "table" or type(database.GetCurrentProfile) ~= "function"
        or type(database.GetProfiles) ~= "function"
        or type(database.SetProfile) ~= "function"
        or type(database.CopyProfile) ~= "function"
        or type(database.profile) ~= "table" then return nil end
    return database
end

local function details()
    local d = _G.Details
    if type(d) ~= "table" or type(d.SaveProfile) ~= "function"
        or type(d.ApplyProfile) ~= "function"
        or type(d.GetProfile) ~= "function"
        or type(d.GetCurrentProfileName) ~= "function"
        or type(d.tabela_instancias) ~= "table"
        or type(d.default_profile) ~= "table"
        or type(_G._detalhes_global) ~= "table"
        or type(_G._detalhes_database) ~= "table" then return nil end
    return d
end

local function hasAceProfile(database, name)
    local ok, names = pcall(database.GetProfiles, database)
    if not ok or type(names) ~= "table" then return false end
    for _, item in ipairs(names) do
        if item == name then return true end
    end
    return false
end

local function saveQuestieProfile()
    local qdb = questie()
    if not qdb then return false, "Questie is niet geladen" end
    local ok, source = pcall(qdb.GetCurrentProfile, qdb)
    if not ok or type(source) ~= "string" or source == "" then
        return false, "Questie-profiel onbekend"
    end
    if source == questieName then
        return false, "Dien Warr gebruikt al de snapshot; selecteer eerst zijn eigen Questie-profiel"
    end
    -- AceDB CopyProfile copies only the profile table, not db.char quest
    -- tracking state. The source profile remains the active one afterwards.
    local copied, why = pcall(function()
        qdb:SetProfile(questieName)
        qdb:CopyProfile(source)
    end)
    local restored, restoreError = pcall(qdb.SetProfile, qdb, source)
    if not restored then return false, "Questie-bronprofiel herstellen mislukt: " .. tostring(restoreError) end
    if not copied or not hasAceProfile(qdb, questieName) then
        return false, "Questie-profiel kopieren mislukt: " .. tostring(why)
    end
    return true
end

local function saveDetailsProfile()
    local d = details()
    if not d then return false, "Details! is niet volledig geladen" end
    local ok, source = pcall(d.GetCurrentProfileName, d)
    if not ok or type(source) ~= "string" or source == "" then
        return false, "Details!-bronprofiel onbekend"
    end
    if source == detailsName then
        return false, "Dien Warr gebruikt al de snapshot; selecteer eerst zijn eigen Details!-profiel"
    end
    -- The native SaveProfile(saveas) exports the CURRENT LIVE window
    -- instances, including GetPosition(), width, height, skin and active
    -- visibility to a global profile without changing the current profile.
    local saved, result = pcall(d.SaveProfile, d, detailsName)
    if not saved or type(result) ~= "table" then
        return false, "Details!-vensters opslaan mislukt: " .. tostring(result)
    end
    -- Details! defaults to per-character positions in some profiles.
    -- Force *this snapshot only* to use its saved window positions, without
    -- modifying the source profile or copying character combat segments.
    result.profile_save_pos = true
    local verified, profile = pcall(d.GetProfile, d, detailsName, false)
    if not verified or type(profile) ~= "table" then
        return false, "Details!-snapshot niet gevonden na opslaan"
    end
    return true
end

function FC:CaptureExtraUIProfiles(template)
    if inCombat() then
        say("Details!/Questie kunnen alleen buiten combat worden vastgelegd.")
        return
    end
    template = template or layout()
    if not template then return end
    if type(template.addons) ~= "table" then template.addons = {} end

    local qok, qerr = saveQuestieProfile()
    if qok then
        template.addons.questie = {profile = questieName}
        say("Questie: trackerpositie en profielinstellingen vastgelegd.")
    else
        template.addons.questie = nil
        say("Questie niet vastgelegd: " .. tostring(qerr) .. ".")
    end

    local dok, derr = saveDetailsProfile()
    if dok then
        template.addons.details = {profile = detailsName}
        say("Details!: live vensterposities, afmetingen en profielinstellingen vastgelegd.")
    else
        template.addons.details = nil
        say("Details! niet vastgelegd: " .. tostring(derr) .. ".")
    end
    -- Any older per-character apply results are invalidated on recapture.
    template.addonsApplied = {}
end

local function canApply(template, id, force)
    if not template or not template.addons or not template.source or not id then return false end
    if id == template.source then return false end
    if not force and template.existing and template.existing[id] then return false end
    return true
end

local function applyQuestie(profile)
    if FC.EnsurePortableAddonProfile then FC:EnsurePortableAddonProfile("questie") end
    local qdb = questie()
    if not qdb or not hasAceProfile(qdb, profile) then return false, "Questie-profiel ontbreekt" end
    local ok, current = pcall(qdb.GetCurrentProfile, qdb)
    if not ok then return false, "Questie-profielnaam niet leesbaar" end
    if current == profile then return true end
    local switched, reason = pcall(qdb.SetProfile, qdb, profile)
    if not switched then return false, tostring(reason) end
    return true
end

local function applyDetails(profile)
    if FC.EnsurePortableAddonProfile then FC:EnsurePortableAddonProfile("details") end
    local d = details()
    if not d then return false, "Details! nog niet gereed" end
    local ok, snapshot = pcall(d.GetProfile, d, profile, false)
    if not ok or type(snapshot) ~= "table" then return false, "Details!-snapshot ontbreekt" end
    local activeOK, active = pcall(d.GetCurrentProfileName, d)
    if not activeOK then return false, "Details!-profielnaam niet leesbaar" end
    if active == profile then return true end
    -- Standard Details! API saves the old active profile and reconstructs
    -- windows from the snapshot. It does not replace combat log data.
    local applied, result = pcall(d.ApplyProfile, d, profile)
    if not applied or result == false then return false, tostring(result) end
    local verifyOK, current = pcall(d.GetCurrentProfileName, d)
    if not verifyOK or current ~= profile then return false, "Details!-profielwissel niet bevestigd" end
    return true
end

function FC:ApplyExtraUIProfiles(force)
    if busy or inCombat() then return end
    local t, id = layout(), playerGUID()
    if not canApply(t, id, force) then return end
    t.addonsApplied = t.addonsApplied or {}
    local applied = t.addonsApplied[id] or {}
    t.addonsApplied[id] = applied

    busy = true
    for _, addon in ipairs({"questie", "details"}) do
        local info = t.addons[addon]
        if info and info.profile and (force or applied[addon] ~= t.revision) then
            local success, reason
            if addon == "questie" then
                success, reason = applyQuestie(info.profile)
            else
                success, reason = applyDetails(info.profile)
            end
            if success then
                applied[addon] = t.revision
                say((addon == "questie" and "Questie" or "Details!") .. "-layout toegepast van " .. (t.sourceName or "Dien Warr") .. ".")
            elseif force or not warned[id .. addon] then
                warned[id .. addon] = true
                say((addon == "questie" and "Questie" or "Details!") .. ": " .. tostring(reason)
                    .. "; probeer /fc layout apply na /reload.")
            end
        end
    end
    busy = false
end

function FC:ExtraUIProfilesStatus()
    local t, id = layout(), playerGUID()
    if not t or type(t.addons) ~= "table" then
        say("Extra addon-layouts: nog niet vastgelegd.")
        return
    end
    local applied = t.addonsApplied and id and t.addonsApplied[id] or {}
    for _, addon in ipairs({"questie", "details"}) do
        local info = t.addons[addon]
        say((addon == "questie" and "Questie" or "Details!") .. ": "
            .. (info and info.profile or "niet vastgelegd")
            .. ", op dit character: " .. ((info and applied and applied[addon] == t.revision) and "toegepast" or "niet toegepast") .. ".")
    end
end

-- Questie may finish initializing after PLAYER_LOGIN. Retry a limited number
-- of times on the next login, without touching already-applied profiles.
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name ~= "Questie" and name ~= "Details" then return end
    FC:ApplyExtraUIProfiles(false)
    if event == "PLAYER_ENTERING_WORLD" and C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(2, function() FC:ApplyExtraUIProfiles(false) end)
        C_Timer.After(6, function() FC:ApplyExtraUIProfiles(false) end)
    end
end)
