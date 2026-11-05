-- ForeverCore: SAFE setup placeholder (0.3.38-beta).
-- The previous keybinding installer was permanently removed after it erased
-- movement and other keys on fresh characters on WoW Forever live.
-- This file MUST NOT call SetBinding, SaveBindings, LoadBindings, or the
-- equivalent API. The original implementation remains in Git history.
local FC = _G.ForeverCore
if not FC then return end

local function say(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80c9ffForeverCore|r " .. tostring(message))
    end
end

local function inspect()
    if type(GetBindingAction) ~= "function" then
        say("Keybind-API niet beschikbaar.")
        return
    end
    local mode = type(GetCurrentBindingSet) == "function"
        and tostring(GetCurrentBindingSet()) or "onbekend"
    local result = {}
    for _, key in ipairs({"W", "A", "S", "D", "SPACE", "-", "MOUSEWHEELDOWN", "G"}) do
        local binding = GetBindingAction(key)
        result[#result + 1] = key .. "="
            .. ((type(binding) == "string" and binding ~= "") and binding or "NOT BOUND")
    end
    say("Binding set=" .. mode .. "; " .. table.concat(result, "; "))
end

function FC:SetupCommand(raw)
    local cmd = tostring(raw or ""):lower():match("^%s*(%S*)") or ""
    if cmd == "inspect" or cmd == "status" then
        say("Keybind-sync permanent UIT. ForeverCore wijzigt geen toetsen.")
        inspect()
    elseif cmd == "apply" or cmd == "repair" or cmd == "restore"
        or cmd == "capture" or cmd == "bindings" or cmd == "diff" then
        say("Keybind-import UITGESCHAKELD ter bescherming van je toetsen. Geen wijzigingen uitgevoerd.")
    else
        say("Setup is uitgeschakeld. /fc setup inspect toont huidige toetsen (alleen lezen).")
    end
end

-- Deliberately NO event handlers and NO automatic settings on new characters.
