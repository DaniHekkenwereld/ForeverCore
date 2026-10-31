-- ForeverCore: capture the exact Bartender4 profile and Blizzard Edit Mode
-- layout on the source character, then apply them once to future characters.
-- Action slot contents, spells, bags, macros and character keybindings are NOT copied.
local FC = _G.ForeverCore
if not FC then return end

local driver = CreateFrame("Frame")
local busy = false
local queued = false
local warned = {}
local profileName = "FC Dien Warr Snapshot"
local accountLayoutName = "FC Dien Layout"

local function say(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80c9ffForeverCore|r " .. tostring(message))
    end
end

local function combat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function guid()
    if type(UnitGUID) ~= "function" then return nil end
    local ok, value = pcall(UnitGUID, "player")
    return ok and type(value) == "string" and value ~= "" and value or nil
end

local function db()
    local root = FC.GetDatabase and FC:GetDatabase()
    if not root then return nil end
    if type(root.layoutTemplate) ~= "table" then root.layoutTemplate = {} end
    return root.layoutTemplate, root
end

local function bartender()
    -- Bartender4 creates a global addon object; it is an AceAddon, not
    -- a Blizzard actionbar module. Wait for its own Forever preset.
    local bt = _G.Bartender4
    if type(bt) ~= "table" or bt.finishedLoading ~= true then return nil end
    if type(bt.db) ~= "table"
        or type(bt.db.GetCurrentProfile) ~= "function"
        or type(bt.db.SetProfile) ~= "function"
        or type(bt.db.CopyProfile) ~= "function" then return nil end
    return bt
end

local function editLayouts()
    if type(C_EditMode) ~= "table" or type(C_EditMode.GetLayouts) ~= "function" then return nil end
    local ok, info = pcall(C_EditMode.GetLayouts)
    if ok and type(info) == "table" and type(info.layouts) == "table" then return info end
    return nil
end

local function getPresetCount()
    local count = Enum and Enum.EditModePresetLayoutsMeta and Enum.EditModePresetLayoutsMeta.NumValues
    return type(count) == "number" and count or nil
end

local function activeLayout()
    local info = editLayouts()
    if not info then return nil end
    local manager = _G.EditModeManagerFrame
    if manager and type(manager.GetActiveLayoutInfo) == "function" then
        local ok, layout = pcall(manager.GetActiveLayoutInfo, manager)
        if ok and type(layout) == "table" and type(layout.layoutName) == "string"
            and layout.layoutType ~= (Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Preset or 0) then
            return layout
        end
    end
    local offset = getPresetCount()
    if offset and type(info.activeLayout) == "number" then
        local layout = info.layouts[info.activeLayout - offset]
        if type(layout) == "table" then return layout end
    end
    -- Last resort: use the explicitly named saved layout shown in Edit Mode.
    for _, layout in ipairs(info.layouts) do
        if type(layout) == "table" and layout.layoutName == "Dien" then return layout end
    end
    return nil
end

local function findAccountLayout(name)
    local layouts = editLayouts()
    if not layouts then return nil end
    local account = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
    for i, layout in ipairs(layouts.layouts) do
        if layout.layoutName == name and layout.layoutType == account then
            -- The raw C_EditMode list does not contain the built-in presets.
            local presetCount = getPresetCount()
            if not presetCount then return nil end
            return presetCount + i
        end
    end
    return nil
end

local function copyLayoutToAccount(layout)
    local account = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
    if layout.layoutType == account then return layout.layoutName end
    if findAccountLayout(accountLayoutName) then return accountLayoutName end

    -- A character-only HUD layout is not accessible to new characters.
    -- Use Blizzard's own layout creation flow to save an account copy.
    local frame = _G.EditModeManagerFrame
    if not frame or type(frame.MakeNewLayout) ~= "function"
        or type(frame.IsInitialized) ~= "function" or not frame:IsInitialized()
        or type(frame.AreLayoutsOfTypeMaxed) ~= "function"
        or frame:AreLayoutsOfTypeMaxed(account) then
        return nil, "Edit Mode-layout is character-only en een accountkopie kon niet worden gemaakt."
    end
    local copy
    if type(CopyTable) == "function" then
        copy = CopyTable(layout)
    else
        return nil, "Blizzard CopyTable niet beschikbaar."
    end
    local ok = pcall(frame.MakeNewLayout, frame, copy, account, accountLayoutName, true)
    if not ok or not findAccountLayout(accountLayoutName) then
        return nil, "Blizzard weigerde de accountkopie van Edit Mode."
    end
    return accountLayoutName
end

local function isSavedProfile(bt, name)
    if type(bt.db.GetProfiles) ~= "function" then return false end
    local ok, profiles = pcall(bt.db.GetProfiles, bt.db)
    if not ok or type(profiles) ~= "table" then return false end
    for _, item in ipairs(profiles) do
        if item == name then return true end
    end
    return false
end

local function capture()
    if combat() then say("Sla het profiel buiten combat op."); return end
    local id = guid()
    local t, root = db()
    local bt = bartender()
    local layout = activeLayout()
    if not id or not t then say("Charactergegevens nog niet beschikbaar."); return end
    if not bt then say("Bartender4 is nog niet volledig geladen. Probeer na /reload."); return end
    if not layout then say("Geen opgeslagen actief Edit Mode-layout. Sla layout 'Dien' eerst op in Edit Mode."); return end

    -- Freeze a character-only layout as an account layout so it can be
    -- selected on every future character, regardless of HUD ownership.
    local layoutName, why = copyLayoutToAccount(layout)
    if not layoutName then say(why); return end

    local source = bt.db:GetCurrentProfile()
    if type(source) ~= "string" then say("Bartender-profiel onbekend."); return end

    if source ~= profileName then
        -- AceDB: CopyProfile copies the parent profile AND all child
        -- namespaces (all Bartender bars/modules, positions, visibility).
        -- Temporarily switch to a snapshot profile, copy and restore the
        -- current source profile even if the copy fails.
        local ok, reason = pcall(function()
            bt.db:SetProfile(profileName)
            bt.db:CopyProfile(source)
        end)
        local restored, restoreReason = pcall(bt.db.SetProfile, bt.db, source)
        if not restored then
            say("Bartender bronprofiel kon niet worden hersteld: " .. tostring(restoreReason))
            return
        end
        if not ok then
            say("Bartender-profiel kopieren mislukt: " .. tostring(reason))
            return
        end
    end
    if not isSavedProfile(bt, profileName) then
        say("Bartender-snapshot kon niet worden gecontroleerd.")
        return
    end

    -- Do not import over characters that already existed when capturing.
    t.existing = t.existing or {}
    t.applied = t.applied or {}
    if root.accountSetup and type(root.accountSetup.applied) == "table" then
        for characterId in pairs(root.accountSetup.applied) do
            t.existing[characterId] = true
        end
    end
    if type(root.bartenderDefaults) == "table" then
        for characterId in pairs(root.bartenderDefaults) do
            t.existing[characterId] = true
        end
    end
    for characterId in pairs(t.applied) do t.existing[characterId] = true end

    t.revision = (tonumber(t.revision) or 0) + 1
    t.source = id
    t.sourceName = UnitName and UnitName("player") or "broncharacter"
    t.profileName = profileName
    t.editModeName = layoutName
    t.screenWidth = GetPhysicalScreenSize and select(1, GetPhysicalScreenSize()) or nil
    t.screenHeight = GetPhysicalScreenSize and select(2, GetPhysicalScreenSize()) or nil
    t.existing[id] = true
    -- Collect optional addon UI profiles at the same moment as Bartender.
    -- Details! exports its live windows; Questie stores tracker positions
    -- in its AceDB profile. Do not copy their character-specific histories.
    if FC.CaptureExtraUIProfiles then FC:CaptureExtraUIProfiles(t) end
    say("Layout vastgelegd vanuit " .. t.sourceName .. ": Bartender-profiel '" .. profileName
        .. "', Edit Mode '" .. layoutName .. "'. Nieuwe characters nemen dit automatisch over.")
    say("Abilities en spells worden niet gekopieerd of verwijderd; dat blijft per character.")
end

local function selectEditLayout(name)
    if not name then return false end
    local index = findAccountLayout(name)
    if not index then return false end
    local info = editLayouts()
    if info and info.activeLayout == index then return true end
    if combat() or type(C_EditMode.SetActiveLayout) ~= "function" then return false end
    local ok = pcall(C_EditMode.SetActiveLayout, index)
    return ok
end

local function apply(force)
    if busy or combat() then queued = true; return end
    -- Manual apply must include optional addon UI profiles even when
    -- Bartender or Edit Mode have not finished initializing yet.
    if force and FC.ApplyExtraUIProfiles then FC:ApplyExtraUIProfiles(true) end
    local id = guid()
    local t = db()
    if not id or not t or not t.profileName or not t.editModeName then return end
    if not force and (id == t.source or (t.existing and t.existing[id])) then return end
    if not force and t.applied and t.applied[id] == t.revision then return end
    local bt = bartender()
    if not bt or not isSavedProfile(bt, t.profileName) then return end
    if not findAccountLayout(t.editModeName) then return end

    busy = true
    local ok, reason = pcall(bt.db.SetProfile, bt.db, t.profileName)
    if not ok then
        busy = false
        if not warned[id] then
            warned[id] = true
            say("Bartender-profiel laden mislukt: " .. tostring(reason))
        end
        return
    end
    local editOK = selectEditLayout(t.editModeName)
    busy = false
    if not editOK then
        if not warned[id] then
            warned[id] = true
            say("Bartender geladen, maar Edit Mode-layout kon niet geactiveerd worden. /fc layout apply om opnieuw te proberen.")
        end
        return
    end
    t.applied = t.applied or {}
    t.applied[id] = t.revision
    say("Layout van " .. (t.sourceName or "broncharacter") .. " toegepast: Bartender + Blizzard Edit Mode.")
end

function FC:LayoutTemplateCommand(raw)
    local command = tostring(raw or ""):lower():match("^%s*(%S*)") or ""
    if command == "capture" then
        capture()
    elseif command == "apply" then
        apply(true)
    elseif command == "status" then
        local t = db()
        local bt = bartender()
        local id = guid()
        if not t or not t.profileName then
            say("Nog geen layout vastgelegd. Log op Dien Warr in en gebruik /fc layout capture.")
            return
        end
        local this = (t.applied and id and t.applied[id] == t.revision) and "toegepast" or "niet toegepast"
        say("Bron: " .. tostring(t.sourceName) .. ", rev " .. tostring(t.revision)
            .. " | Bartender: " .. tostring(t.profileName)
            .. " | Edit Mode: " .. tostring(t.editModeName) .. ".")
        say("Dit character: " .. this .. " | Bartender geladen: " .. tostring(bt ~= nil)
            .. " | Edit Mode layout aanwezig: " .. tostring(findAccountLayout(t.editModeName) ~= nil) .. ".")
        if FC.ExtraUIProfilesStatus then FC:ExtraUIProfilesStatus() end
        local bbfLoaded = false
        if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
            local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "BetterBlizzFrames")
            bbfLoaded = ok and loaded or false
        elseif type(IsAddOnLoaded) == "function" then
            local ok, loaded = pcall(IsAddOnLoaded, "BetterBlizzFrames")
            bbfLoaded = ok and loaded or false
        end
        say("BetterBlizzFrames: " .. (bbfLoaded and "geladen" or "NIET geladen")
            .. " (instellingen zijn accountbreed; geen aparte capture).")
        if t.screenWidth and t.screenHeight then
            local w, h = nil, nil
            if type(GetPhysicalScreenSize) == "function" then w, h = GetPhysicalScreenSize() end
            say("Bronresolutie " .. t.screenWidth .. "x" .. t.screenHeight
                .. "; huidig " .. tostring(w) .. "x" .. tostring(h) .. ".")
        end
    else
        say("/fc layout capture | status | apply")
    end
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if not queued then return end
        queued = false
    end
    apply(false)
end)
