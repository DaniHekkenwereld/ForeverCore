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
        -- Optional Details!/Questie profiles are not part of the Bartender
        -- package; never claim they were installed on a different account.
        t.addons = nil
        root.layoutTemplate = t
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

-- Install the portable Edit Mode account layout once. Blizzard owns these
-- layouts; this is a guarded, single-account creation via its native API.
-- It is never called during combat and never changes secure frames directly.
function FC:EnsurePortableEditLayout(name)
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
        for _, item in ipairs(info.layouts) do
            if item.layoutName == name and item.layoutType == account then return true, info end
        end
        return false, info
    end

    local exists, info = found()
    if exists == nil then return false end
    if exists then return true end
    if t.portableEditModeAttempted then return false end
    -- Avoid repeated protected API writes on a client that rejects creation.
    t.portableEditModeAttempted = true

    local account = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
    local layout = clone(t.layoutData)
    layout.layoutType = account
    layout.layoutName = name

    -- Do not delete or overwrite existing account HUD layouts.
    table.insert(info.layouts, layout)
    local ok, reason = pcall(C_EditMode.SaveLayouts, info)
    if not ok then
        say("Portable Edit Mode kon niet worden opgeslagen: " .. tostring(reason)
            .. ". Bartender blijft wel automatisch werken.")
        return false
    end
    local verified = found()
    if verified then
        say("Portable Edit Mode-layout '" .. name .. "' beschikbaar op dit WoW-account.")
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
