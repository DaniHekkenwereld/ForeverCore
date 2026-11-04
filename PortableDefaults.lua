-- Portable ForeverCore UI defaults: installed AddOn files apply to every WoW account.
-- Unlike WTF/Account/*/SavedVariables, these defaults are account-independent.
-- Never change action slots, spells, talents, macros, or an existing named Bartender profile.
local FC = _G.ForeverCore
if not FC then return end

local function bundle()
    local value = _G.ForeverCoreBundledDefaults
    return type(value) == "table" and value or nil
end

local function clone(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do copy[clone(key, seen)] = clone(item, seen) end
    return copy
end

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function say(text)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80c9ffForeverCore|r " .. text)
    end
end

function FC:HasPortableDefaults()
    local data = bundle()
    return data and type(data.bartender) == "table"
        and type(data.bartender.profile) == "table"
        and type(data.layout) == "table"
end

function FC:EnsurePortableDefaults()
    local data = bundle()
    if not data or not self:HasPortableDefaults() then return false end
    local root = self.GetDatabase and self:GetDatabase()
    if not root then return false end

    -- New accounts have their own ForeverCoreDB. Bootstrap it from the AddOn
    -- package without importing source-account character completion markers.
    if type(root.layoutTemplate) ~= "table" or not root.layoutTemplate.profileName then
        local t = clone(data.layout)
        t.source = "bundled-source"
        t.sourceName = t.sourceName or "Dien Warr"
        t.profileName = data.bartender.profileName or "FC Dien Warr Snapshot"
        t.editModeName = t.editModeName or "FC Dien Layout"
        t.revision = tonumber(t.revision) or 1
        t.existing, t.applied, t.appliedParts, t.addonsApplied = {}, {}, {}, {}
        -- Existing characters previously configured by ForeverCore should
        -- retain their chosen UI rather than be treated as fresh characters.
        if type(root.accountSetup) == "table"
            and type(root.accountSetup.applied) == "table" then
            for id in pairs(root.accountSetup.applied) do t.existing[id] = true end
        end
        if type(root.bartenderDefaults) == "table" then
            for id in pairs(root.bartenderDefaults) do t.existing[id] = true end
        end
        t.portableEditModeAttempted = nil
        -- Include only optional profiles really bundled in the AddOn.
        local addons = {}
        if type(data.questie) == "table" then
            addons.questie = {profile = data.questie.profileName}
        end
        if type(data.details) == "table" then
            addons.details = {profile = data.details.profileName}
        end
        t.addons = next(addons) and addons or nil
        root.layoutTemplate = t
    elseif root.layoutTemplate.source == "bundled-source"
        and type(data.layout) == "table" then
        -- Re-exported snapshots must update old test accounts too. Previously
        -- the first imported "Dien" layout was cached forever, even after
        -- the source was recaptured as a different layout (e.g. "OWN").
        local t = root.layoutTemplate
        local newName = data.layout.editModeName or "FC Dien Layout"
        local newRevision = tonumber(data.layout.revision) or 1
        if t.editModeName ~= newName or tonumber(t.revision) ~= newRevision then
            t.editModeName = newName
            t.layoutData = clone(data.layout.layoutData)
            t.screenWidth = data.layout.screenWidth
            t.screenHeight = data.layout.screenHeight
            t.sourceName = data.layout.sourceName or t.sourceName
            t.revision = newRevision
            t.applied, t.appliedParts = {}, {}
            t.portableEditModeAttempted = nil
            say("Nieuwe portable Edit Mode-layout geladen: " .. tostring(newName)
                .. " (rev " .. tostring(newRevision) .. ").")
        end
    end

    if type(data.bindingProfile) == "table" then
        root.accountSetup = root.accountSetup or {}
        if type(root.accountSetup.profile) ~= "table" then
            root.accountSetup.profile = clone(data.bindingProfile)
        end
    end

    local bt = _G.Bartender4
    if type(bt) ~= "table" or bt.finishedLoading ~= true
        or type(bt.db) ~= "table" then return true end
    local sv = bt.db.sv or _G.Bartender4DB
    if type(sv) ~= "table" then return true end
    sv.profiles = sv.profiles or {}
    local name = data.bartender.profileName or "FC Dien Warr Snapshot"
    if type(sv.profiles[name]) ~= "table" then
        sv.profiles[name] = clone(data.bartender.profile)
        sv.namespaces = sv.namespaces or {}
        for ns, profile in pairs(data.bartender.namespaces or {}) do
            if type(profile) == "table" then
                sv.namespaces[ns] = sv.namespaces[ns] or {}
                local section = sv.namespaces[ns]
                section.profiles = section.profiles or {}
                section.profiles[name] = clone(profile)
            end
        end
    end
    return true
end

-- Questie and Details! use different profile stores; seed only their captured
-- named UI profiles. Quest progress, character data and combat history stay local.
function FC:EnsurePortableAddonProfile(which, refresh)
    local data = bundle()
    if not data then return false end
    if refresh then
        local root = self.GetDatabase and self:GetDatabase()
        if not root or not root.layoutTemplate
            or root.layoutTemplate.source ~= "bundled-source" then
            return false -- never overwrite profiles on the original/source account
        end
    end
    if which == "questie" and type(data.questie) == "table" then
        local q = _G.Questie
        local sv = q and q.db and q.db.sv
        local name = data.questie.profileName
        if type(sv) ~= "table" or type(name) ~= "string" then return false end
        sv.profiles = sv.profiles or {}
        if refresh or not sv.profiles[name] then
            sv.profiles[name] = clone(data.questie.profile)
        end
        return type(sv.profiles[name]) == "table"
    elseif which == "details" and type(data.details) == "table" then
        local d = _G.Details
        local sv = _G._detalhes_global
        local name = data.details.profileName
        if type(d) ~= "table" or type(sv) ~= "table"
            or type(name) ~= "string" then return false end
        sv.__profiles = sv.__profiles or {}
        if refresh or not sv.__profiles[name] then
            sv.__profiles[name] = clone(data.details.profile)
        end
        return type(sv.__profiles[name]) == "table"
    end
    return false
end

-- Install the portable Edit Mode account layout once. Blizzard owns these
-- layouts; this is a guarded, single-account creation via its native API.
-- It is never called during combat and never changes secure frames directly.
function FC:EnsurePortableEditLayout(name, refresh)
    local root = self.GetDatabase and self:GetDatabase()
    local t = root and root.layoutTemplate
    if not t or type(t.layoutData) ~= "table" then return false end
    if inCombat() or type(C_EditMode) ~= "table"
        or type(C_EditMode.GetLayouts) ~= "function"
        or type(C_EditMode.SaveLayouts) ~= "function" then return false end

    local function found()
        local ok, info = pcall(C_EditMode.GetLayouts)
        if not ok or type(info) ~= "table" or type(info.layouts) ~= "table" then return nil, nil end
        local account = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
        for index, item in ipairs(info.layouts) do
            if item.layoutName == name and item.layoutType == account then
                return true, info, index
            end
        end
        return false, info, nil
    end

    local exists, info, index = found()
    if exists == nil then return false end
    if exists and not refresh then return true end
    if refresh and t.source ~= "bundled-source" then
        say("Edit Mode vernieuwen kan alleen op een portable testaccount.")
        return false
    end
    if t.portableEditModeAttempted and not refresh then return false end
    -- Avoid repeated protected API writes when creation was rejected.
    t.portableEditModeAttempted = true

    local account = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
    local layout = clone(t.layoutData)
    layout.layoutType = account
    layout.layoutName = name

    if exists then
        -- Explicit /fc layout apply: replace ONLY this matching account
        -- layout (OWN) with the complete bundled systems and anchors.
        -- Other named user layouts stay untouched.
        info.layouts[index] = layout
    else
        table.insert(info.layouts, layout)
    end
    local ok, reason = pcall(C_EditMode.SaveLayouts, info)
    if not ok or reason == false then
        say("Portable Edit Mode kon niet worden opgeslagen: " .. tostring(reason)
            .. ". Bartender blijft wel automatisch werken.")
        return false
    end
    local verified = found()
    if verified then
        say("Portable Edit Mode-layout '" .. name .. "' "
            .. (exists and refresh and "vernieuwd" or "beschikbaar")
            .. " op dit WoW-account.")
        return true
    end
    say("Portable Edit Mode kon niet worden bevestigd. Bartender blijft wel werken.")
    return false
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName ~= "ForeverCore"
        and addonName ~= "Bartender4" then return end
    FC:EnsurePortableDefaults()
end)
