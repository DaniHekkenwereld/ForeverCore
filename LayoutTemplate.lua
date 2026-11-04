-- ForeverCore: capture the exact Bartender4 profile and Blizzard Edit Mode
-- layout on the source character, then apply them once to future characters.
-- Action slot contents, spells, bags, macros and character keybindings are NOT copied.
local FC = _G.ForeverCore
if not FC then return end

local driver = CreateFrame("Frame")
local busy = false
local queued = false
local warned = {}
local retryScheduled = false
local retryTimers = {1, 3, 7}
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

local function namedEditLayout(name)
    local info = editLayouts()
    if not info or type(name) ~= "string" or name == "" then return nil end
    local accountType = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
    local first
    for _, item in ipairs(info.layouts) do
        if type(item.layoutName) == "string"
            and item.layoutName:lower() == name:lower() then
            if item.layoutType == accountType then return item end
            first = first or item
        end
    end
    return first
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

local function copyLayoutToAccount(layout, requestedName)
    local account = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
    if layout.layoutType == account then return layout.layoutName end
    local destination = requestedName or accountLayoutName
    if findAccountLayout(destination) then return destination end

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
    local ok = pcall(frame.MakeNewLayout, frame, copy, account, destination, true)
    if not ok or not findAccountLayout(destination) then
        return nil, "Blizzard weigerde de accountkopie van Edit Mode."
    end
    return destination
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

local function capture(requestedName)
    if combat() then say("Sla het profiel buiten combat op."); return end
    local id = guid()
    local t, root = db()
    local bt = bartender()
    -- Explicit name wins: the beta's GetActiveLayoutInfo can return a
    -- different layout from the user's saved custom layout.
    local layout = requestedName and namedEditLayout(requestedName) or activeLayout()
    if not id or not t then say("Charactergegevens nog niet beschikbaar."); return end
    if not bt then say("Bartender4 is nog niet volledig geladen. Probeer na /reload."); return end
    if not layout then
        say(requestedName and ("Edit Mode-layout '" .. requestedName
            .. "' bestaat niet op dit character. Sla die eerst op via Edit Mode.")
            or "Geen opgeslagen actief Edit Mode-layout; gebruik /fc layout capture OWN.")
        return
    end

    -- Freeze a character-only layout as an account layout so it can be
    -- selected on every future character, regardless of HUD ownership.
    local layoutName, why = copyLayoutToAccount(layout, requestedName and layout.layoutName or nil)
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
    -- Preserve the native Blizzard layout data for new accounts using this AddOn
    -- package. The portable export script embeds this in PortableSnapshot.lua.
    t.layoutData = CopyTable(layout)
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
    -- A missing Blizzard Edit Mode layout must not block Bartender4.
    -- Edit Mode account layouts often do not travel with a copied WTF folder
    -- because they are associated with another game account.
    if force and FC.ApplyExtraUIProfiles then FC:ApplyExtraUIProfiles(true) end
    -- The packaged snapshot is the default even when this WoW account has
    -- never seen the source private-server character.
    if FC.EnsurePortableDefaults then FC:EnsurePortableDefaults() end
    local id = guid()
    local t = db()
    if not id or not t or not t.profileName or not t.editModeName then return end
    if not force and (id == t.source or (t.existing and t.existing[id])) then return end
    if not force and t.applied and t.applied[id] == t.revision then return end

    t.appliedParts = t.appliedParts or {}
    t.appliedParts[id] = t.appliedParts[id] or {}
    local state = t.appliedParts[id]
    local bt = bartender()

    if not state.bartender or force then
        if not bt then return end -- Retry after Bartender's preset loads.
        if not isSavedProfile(bt, t.profileName) then
            if not warned[id .. ":bartender"] then
                warned[id .. ":bartender"] = true
                say("Bartender-profiel '" .. t.profileName
                    .. "' ontbreekt. Genereer PortableSnapshot.lua vanuit de bronconfiguratie.")
            end
            return
        end
        busy = true
        local ok, result = pcall(bt.db.SetProfile, bt.db, t.profileName)
        busy = false
        if ok then
            -- A profile is only considered applied after checking AceDB.
            local checked, current = pcall(bt.db.GetCurrentProfile, bt.db)
            if not checked or current ~= t.profileName then
                ok = false
                result = "huidig profiel is " .. tostring(current)
            end
        end
        if not ok then
            if not warned[id .. ":bartender"] then
                warned[id .. ":bartender"] = true
                say("Bartender-profiel laden mislukt: " .. tostring(result))
            end
            return
        end
        state.bartender = true
        say("Bartender-profiel '" .. t.profileName .. "' toegepast.")
    end

    if not state.editMode or force then
        if not findAccountLayout(t.editModeName) and FC.EnsurePortableEditLayout then
            if force then t.portableEditModeAttempted = nil end
            FC:EnsurePortableEditLayout(t.editModeName)
        end
        if findAccountLayout(t.editModeName) then
            if selectEditLayout(t.editModeName) then
                state.editMode = true
                say("Edit Mode-layout '" .. t.editModeName .. "' geselecteerd.")
            end
        else
            if not warned[id .. ":editMode"] then
                warned[id .. ":editMode"] = true
                say("Edit Mode-layout '" .. t.editModeName
                    .. "' ontbreekt op dit account. Controleer de ingepakte layout en /fc layout apply.")
            end
        end
    end

    if state.bartender and state.editMode then
        t.applied = t.applied or {}
        t.applied[id] = t.revision
        say("Bartender + Blizzard Edit Mode-layout volledig toegepast.")
    end
end

function FC:LayoutTemplateCommand(raw)
    local action, arg = tostring(raw or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local command = (action or ""):lower()
    if command == "capture" then
        capture(arg ~= "" and arg or nil)
    elseif command == "apply" then
        apply(true)
    elseif command == "status" then
        if FC.EnsurePortableDefaults then FC:EnsurePortableDefaults() end
        local t = db()
        local bt = bartender()
        local id = guid()
        if not t or not t.profileName then
            say("Nog geen layout vastgelegd. Log op Dien Warr in en gebruik /fc layout capture.")
            return
        end
        local this = (t.applied and id and t.applied[id] == t.revision) and "toegepast" or "niet volledig toegepast"
        local state = id and t.appliedParts and t.appliedParts[id]
        local currentProfile = "onbekend"
        if bt and type(bt.db.GetCurrentProfile) == "function" then
            local success, name = pcall(bt.db.GetCurrentProfile, bt.db)
            if success then currentProfile = tostring(name) end
        end
        say("Bartender huidig profiel: " .. currentProfile
            .. ", snapshot toegepast: " .. ((state and state.bartender) and "ja" or "nee")
            .. " | Edit Mode toegepast: " .. ((state and state.editMode) and "ja" or "nee") .. ".")
        say("Portable instellingen in addon: "
            .. ((FC.HasPortableDefaults and FC:HasPortableDefaults()) and "aan" or "NIET AANWEZIG") .. ".")
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
        say("/fc layout capture OWN | status | apply")
    end
end

local function retryAfterLogin()
    if retryScheduled then return end
    if not (C_Timer and type(C_Timer.After) == "function") then return end
    retryScheduled = true
    for i, delay in ipairs(retryTimers) do
        C_Timer.After(delay, function()
            -- Do not reconfigure the source or existing characters. apply()
            -- has the existing-character and completion guards.
            apply(false)
            if i == #retryTimers then retryScheduled = false end
        end)
    end
end

driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon ~= "Bartender4" then return end
    if event == "PLAYER_REGEN_ENABLED" then
        if not queued then return end
        queued = false
    end
    apply(false)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
        retryAfterLogin()
    end
end)
