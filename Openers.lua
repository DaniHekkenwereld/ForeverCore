-- ForeverCore 0.2: Warrior opener library (12 user-editable, draggable macros).
-- A macro casts only what the player explicitly chooses; no automatic combat rotation.
local FC = _G.ForeverCore
if not FC then return end
local defs = {
  prot = {
    {"STT","ST threat","Defensive Charge (Vanguard) > Shield Slam > Revenge proc > Sunder. Shift Revenge, Ctrl Sunder, Alt Shield Block.",
      "#showtooltip\n/startattack [harm]\n/cast [mod:shift] Revenge; [mod:ctrl] Sunder Armor; [mod:alt] Shield Block; Shield Slam"},
    {"AOT","AoE threat","Defensive Stance > Bloodrage > Thunder Clap > tab Revenge or Shield Slam. Shift Demo Shout; Ctrl Cleave with excess rage.",
      "#showtooltip\n/startattack [harm]\n/cast [mod:shift] Demoralizing Shout; [mod:ctrl] Cleave; Thunder Clap"},
    {"STD","ST DPS","Shield Slam, Revenge on procs, Execute when usable. Shift Revenge; Ctrl Execute.",
      "#showtooltip\n/startattack [harm]\n/cast [mod:shift] Revenge; [mod:ctrl] Execute; Shield Slam"},
    {"AOD","AoE DPS","Thunder Clap on cooldown; Cleave as rage dump, Revenge on procs. Shift Cleave; Ctrl Revenge.",
      "#showtooltip\n/startattack [harm]\n/cast [mod:shift] Cleave; [mod:ctrl] Revenge; Thunder Clap"}
  },
  fury = {
    {"STT","ST threat","Emergency tank: Defensive Stance > Bloodthirst > Revenge proc > Sunder. Shift Revenge; Ctrl Sunder.",
      "#showtooltip\n/startattack [harm]\n/cast [mod:shift] Revenge; [mod:ctrl] Sunder Armor; Bloodthirst"},
    {"AOT","AoE threat","Emergency tank: Defensive Stance > Thunder Clap > tab-target; Demo for mitigation. Shift Demo; Ctrl Cleave.",
      "#showtooltip\n/startattack [harm]\n/cast [mod:shift] Demoralizing Shout; [mod:ctrl] Cleave; Thunder Clap"},
    {"STD","ST DPS","Charge > Bloodrage > Death Wish at planned burst > Bloodthirst > Whirlwind. Shift WW, Ctrl Execute.",
      "#showtooltip\n/startattack [harm]\n/cast [mod:shift] Whirlwind; [mod:ctrl] Execute; Bloodthirst"},
    {"AOD","AoE DPS","Whirlwind in Berserker Stance > Cleave as rage dump > Bloodthirst on priority target. Shift Cleave, Ctrl BT.",
      "#showtooltip\n/startattack [harm]\n/cast [mod:shift] Cleave; [mod:ctrl] Bloodthirst; Whirlwind"}
  },
  arms = {
    {"STT","ST threat","Emergency tank: Defensive Stance > Mortal Strike > Revenge proc > Sunder. Shift Revenge; Ctrl Sunder.",
      "#showtooltip\n/startattack [harm]\n/cast [mod:shift] Revenge; [mod:ctrl] Sunder Armor; Mortal Strike"},
    {"AOT","AoE threat","Emergency tank: Defensive Stance > Thunder Clap > tab-target Sunder/Revenge. Shift Demo, Ctrl Cleave.",
      "#showtooltip\n/startattack [harm]\n/cast [mod:shift] Demoralizing Shout; [mod:ctrl] Cleave; Thunder Clap"},
    {"STD","ST DPS","Charge > Mortal Strike; Rend when fight is long; Overpower on proc. Shift Rend; Ctrl Overpower.",
      "#showtooltip\n/startattack [harm]\n/cast [mod:shift] Rend; [mod:ctrl] Overpower; Mortal Strike"},
    {"AOD","AoE DPS","Charge > Sweeping Strikes (talent/Battle Stance), then Cleave or Mortal Strike. Shift Cleave; Ctrl MS.",
      "#showtooltip\n/startattack [harm]\n/cast [mod:shift] Cleave; [mod:ctrl] Mortal Strike; Sweeping Strikes"}
  }
}
local tabs={"prot","fury","arms"}
local specLabel={prot="PROTECTION",fury="FURY",arms="ARMS"}
local chosen="prot"
local win, title, editor, editingBox, editingName, chars, editingEntry
local rows={}
local function db() return FC:GetDatabase() end
local function combat() return type(InCombatLockdown)=="function" and InCombatLockdown() end
local function say(s) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff80c9ffForeverCore|r "..s) end end
local function id(spec,e) return "FC-"..spec:sub(1,1):upper().."-"..e[1] end
local function indexOf(name)
    if not GetMacroIndexByName then return nil end
    local i=GetMacroIndexByName(name)
    return type(i)=="number" and i>0 and i or nil
end
local function body(spec,e)
    local name=id(spec,e)
    local i=indexOf(name)
    if i and GetMacroBody then
        local ok,b=pcall(GetMacroBody,i)
        if ok and type(b)=="string" then return b end
    end
    local d=db()
    return (d and d.openerBodies and d.openerBodies[name]) or e[4]
end
local function createIfMissing(spec,e)
    if combat() then say("Macro's slepen kan niet in combat."); return nil end
    local name=id(spec,e)
    local i=indexOf(name)
    if i then return i end
    if not CreateMacro then say("CreateMacro niet beschikbaar."); return nil end
    local txt=body(spec,e)
    if #txt>255 then say("Macro is langer dan 255 tekens."); return nil end
    for _,perCharacter in ipairs({true,false}) do
        local ok,result=pcall(CreateMacro,name,"INV_MISC_QUESTIONMARK",txt,perCharacter)
        if ok and type(result)=="number" and result>0 then return result end
    end
    say("Macro-slots vol. Maak ruimte in /macro.")
    return nil
end
local function pickup(spec,e)
    if combat() then say("Buiten combat slepen."); return end
    if not PickupMacro then say("PickupMacro ontbreekt."); return end
    local i=createIfMissing(spec,e)
    if i then
        local ok=pcall(PickupMacro,i)
        if not ok then say("Kon macro niet oppakken. Kijk in /macro.") end
    end
end
local function label(parent,font,x,y,width,txt)
    local s=parent:CreateFontString(nil,"OVERLAY",font)
    s:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    if width then s:SetWidth(width);s:SetJustifyH("LEFT") end
    if txt then s:SetText(txt) end
    return s
end
local function edit(spec,e)
    if combat() then say("Bewerken kan alleen buiten combat."); return end
    editingEntry={spec=spec,e=e}
    editingName:SetText(specLabel[spec].." - "..e[2])
    editingBox:SetText(body(spec,e))
    editingBox:SetCursorPosition(0)
    chars:SetText(#editingBox:GetText().." / 255")
    editor:Show()
end
local function showRows()
    if not win then return end
    title:SetText("FOREVERCORE  /  "..specLabel[chosen].."  /  OPENERS")
    for i,e in ipairs(defs[chosen]) do
        local r=rows[i]
        r.title:SetText(e[2])
        r.detail:SetText(e[3])
        r.drag:SetScript("OnDragStart",function() pickup(chosen,e) end)
        r.drag:SetScript("OnClick",function(_,btn)
            if btn=="RightButton" then edit(chosen,e) else pickup(chosen,e) end
        end)
        r.edit:SetScript("OnClick",function() edit(chosen,e) end)
    end
end
local function build()
    if win then return end
    win=CreateFrame("Frame","ForeverCoreOpeners",UIParent,"BackdropTemplate")
    win:SetSize(610,468)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart",function(self) if not combat() then self:StartMoving() end end)
    win:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    if win.SetBackdrop then
        win:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        win:SetBackdropColor(0.03,0.04,0.06,0.97)
        win:SetBackdropBorderColor(0.3,0.5,0.64,1)
    end
    title=label(win,"GameFontNormalLarge",14,-14,490,"")
    local close=CreateFrame("Button",nil,win,"UIPanelButtonTemplate")
    close:SetSize(70,24);close:SetPoint("TOPRIGHT",win,"TOPRIGHT",-12,-10);close:SetText("Close")
    close:SetScript("OnClick",function() win:Hide() end)
    for i,spec in ipairs(tabs) do
        local btn=CreateFrame("Button",nil,win,"UIPanelButtonTemplate")
        btn:SetSize(183,26);btn:SetPoint("TOPLEFT",win,"TOPLEFT",14+(i-1)*194,-48)
        btn:SetText(specLabel[spec])
        btn:SetScript("OnClick",function() chosen=spec;showRows() end)
    end
    label(win,"GameFontDisableSmall",14,-82,570,"Sleep links een opener naar je actionbar. Rechtsklik/Edit om aan te passen.")
    label(win,"GameFontDisableSmall",14,-99,570,"Normaal=hoofdspell, Shift/Ctrl/Alt=bewuste keuze. Elke cast vereist een keypress.")
    for i=1,4 do
        local y=-123-(i-1)*80
        local r={}
        r.drag=CreateFrame("Button",nil,win,"UIPanelButtonTemplate")
        r.drag:SetSize(151,28);r.drag:SetPoint("TOPLEFT",win,"TOPLEFT",14,y-17)
        r.drag:RegisterForClicks("LeftButtonUp","RightButtonUp")
        r.drag:RegisterForDrag("LeftButton")
        r.drag:SetText("Drag: opener")
        r.title=label(win,"GameFontNormal",176,y-12,350,"")
        r.detail=label(win,"GameFontHighlightSmall",176,y-32,410,"")
        r.detail:SetHeight(52);r.detail:SetWordWrap(true)
        r.edit=CreateFrame("Button",nil,win,"UIPanelButtonTemplate")
        r.edit:SetSize(47,23);r.edit:SetPoint("TOPRIGHT",win,"TOPRIGHT",-14,y-13)
        r.edit:SetText("Edit")
        rows[i]=r
    end
    label(win,"GameFontDisableSmall",14,-450,570,"Geen /castsequence voor Revenge-procs: dat kan bij onbruikbare spells vastlopen.")
    editor=CreateFrame("Frame",nil,win,"BackdropTemplate")
    editor:SetSize(570,241);editor:SetPoint("CENTER",win,"CENTER",0,0)
    editor:SetFrameStrata("FULLSCREEN_DIALOG")
    if editor.SetBackdrop then
        editor:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        editor:SetBackdropColor(0.05,0.07,0.11,1)
        editor:SetBackdropBorderColor(0.65,0.72,0.8,1)
    end
    editingName=label(editor,"GameFontNormal",12,-12,520,"")
    local bg=CreateFrame("Frame",nil,editor,"BackdropTemplate")
    bg:SetSize(546,143);bg:SetPoint("TOPLEFT",editor,"TOPLEFT",12,-40)
    if bg.SetBackdrop then
        bg:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        bg:SetBackdropColor(0.01,0.02,0.04,1)
        bg:SetBackdropBorderColor(0.3,0.3,0.4,1)
    end
    editingBox=CreateFrame("EditBox",nil,bg)
    editingBox:SetMultiLine(true)
    editingBox:SetAutoFocus(false)
    editingBox:SetFontObject("ChatFontNormal")
    editingBox:SetSize(529,132);editingBox:SetPoint("TOPLEFT",bg,"TOPLEFT",8,-6)
    editingBox:SetMaxLetters(255)
    editingBox:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    chars=label(editor,"GameFontDisableSmall",12,-188,150,"0 / 255")
    editingBox:SetScript("OnTextChanged",function(self) chars:SetText(#self:GetText().." / 255") end)
    local save=CreateFrame("Button",nil,editor,"UIPanelButtonTemplate")
    save:SetSize(94,26);save:SetPoint("BOTTOMLEFT",editor,"BOTTOMLEFT",12,9);save:SetText("Save")
    save:SetScript("OnClick",function()
        if combat() or not editingEntry then return end
        local txt=editingBox:GetText()
        if #txt==0 or #txt>255 then say("Macro-body moet 1-255 tekens bevatten."); return end
        local name=id(editingEntry.spec,editingEntry.e)
        local idx=indexOf(name)
        if idx then
            if not EditMacro then say("EditMacro niet beschikbaar."); return end
            local ok=pcall(EditMacro,idx,name,nil,txt)
            if not ok then say("Kon macro niet opslaan."); return end
        end
        local d=db()
        if d then
            d.openerBodies=d.openerBodies or {}
            d.openerBodies[name]=txt
        end
        editor:Hide()
        say(name.." opgeslagen. Sleep hem naar je actionbar.")
    end)
    local reset=CreateFrame("Button",nil,editor,"UIPanelButtonTemplate")
    reset:SetSize(94,26);reset:SetPoint("LEFT",save,"RIGHT",9,0);reset:SetText("Default")
    reset:SetScript("OnClick",function() if editingEntry then editingBox:SetText(editingEntry.e[4]) end end)
    local cancel=CreateFrame("Button",nil,editor,"UIPanelButtonTemplate")
    cancel:SetSize(94,26);cancel:SetPoint("BOTTOMRIGHT",editor,"BOTTOMRIGHT",-12,9);cancel:SetText("Cancel")
    cancel:SetScript("OnClick",function() editor:Hide() end)
    editor:Hide()
    win:Hide()
end
function FC:ShowOpeners(spec)
    if UnitClass and select(2,UnitClass("player"))~="WARRIOR" then
        say("Dit zijn Warrior openers."); return
    end
    if combat() then say("Open het openerpaneel buiten combat."); return end
    build()
    if spec=="tank" then spec="prot" end
    if defs[spec] then chosen=spec end
    showRows()
    editor:Hide()
    win:Show()
end
