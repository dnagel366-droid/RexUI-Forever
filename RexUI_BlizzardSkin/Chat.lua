-------------------------------------------------------------------------------
--  RexUI_BlizzardSkin - Chat Reskin
--
--  Dark panel (chat + input), tab restyling, thin scrollbar,
--  sidebar icons, copy popup, portal flyout, URL detection,
--  idle fade, edit box history, timestamps.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local RexUI = ns.RexUI
if not RexUI then return end

local Skin = RexUI.BlizzardSkin
if not Skin then return end

local function T(text)
    return RexUI:LocalizeText(text)
end

local min, max, floor, ceil, abs = math.min, math.max, math.floor, math.ceil, math.abs
local strfind, strgsub, strmatch = string.find, string.gsub, string.match

-- Colors (neutral, no purple/magenta)
local BG_R, BG_G, BG_B, BG_A = 0.03, 0.045, 0.05, 0.70
local BORDER_A = 0.06
local ACCENT_R, ACCENT_G, ACCENT_B = 0.20, 0.60, 0.90

local C_MEDIA = "Interface\\AddOns\\RexUI\\media\\chat\\"
local SIDEBAR_ICONS = {
    friends  = C_MEDIA .. "chat_friends.png",
    copy     = C_MEDIA .. "chat_copy.png",
    portal   = C_MEDIA .. "chat_portal.png",
    voice    = C_MEDIA .. "chat_voice.png",
    settings = C_MEDIA .. "chat_settings.png",
    scroll   = C_MEDIA .. "chat_scroll2.png",
    keys     = "Interface\\Icons\\INV_Misc_Key_14",
}

-- Per-frame data
local _cfd = setmetatable({}, { __mode = "k" })
local function CFD(cf)
    local d = _cfd[cf]
    if not d then d = {}; _cfd[cf] = d end
    return d
end

local _hiddenParent = CreateFrame("Frame")
_hiddenParent:Hide()

-- ----- CONFIG -----

local function GetChatCfg()
    local p = RexUI:GetProfile()
    p.blizzardSkin = p.blizzardSkin or {}
    p.blizzardSkin.chat = p.blizzardSkin.chat or {}
    return p.blizzardSkin.chat
end

local function IsEnabled()
    local p = RexUI:GetProfile()
    p.blizzardSkin = p.blizzardSkin or {}
    p.blizzardSkin.chat = p.blizzardSkin.chat or {}
    if p.blizzardSkin.enabled == false then return false end
    if p.blizzardSkin.chat.enabled == false then return false end
    return true
end

-- ----- HELPERS -----

local function StripBlizzard(f)
    if not f then return end
    for i = 1, select("#", f:GetRegions()) do
        local r = select(i, f:GetRegions())
        if r and r:IsObjectType("Texture") then r:SetAlpha(0) end
    end
end

local function GetFont()
    return STANDARD_TEXT_FONT
end

local function GetChatFontSize()
    return max(10, min(18, tonumber(GetChatCfg().fontSize) or 12))
end

local function GetChatLineSpacing()
    return max(0, min(8, tonumber(GetChatCfg().lineSpacing) or 1))
end

-- ----- TIMESTAMPS -----

local function ApplyTimestamps()
    local cfg = GetChatCfg()
    local fmt = cfg.timestampFormat or "%I:%M "
    if fmt ~= "blizzard" then SetCVar("showTimestamps", fmt) end
end

-- ----- VISIBILITY -----

local _visAlpha = 1
local _idleActive = false
local _idleFadeAlpha = 1
local _fadeFrame = CreateFrame("Frame")
_fadeFrame:Hide()
local _fadeTarget = 1
local _fadeCurrent = 1

local function GetIdleFadeAlpha()
    return 1 - (min(GetChatCfg().idleFadeStrength or 40, 99) / 100)
end

local function SetChatAlpha(alpha)
    _visAlpha = alpha
    _fadeTarget = alpha
    _fadeFrame:Show()
end

local function SetIdleFadeAlpha(alpha)
    _fadeTarget = min(alpha, _visAlpha)
    _fadeFrame:Show()
end

_fadeFrame:SetScript("OnUpdate", function(self, dt)
    if _fadeCurrent == _fadeTarget then self:Hide(); return end
    local speed = dt / (_fadeTarget > _fadeCurrent and 0.35 or 0.5)
    _fadeCurrent = _fadeTarget > _fadeCurrent and min(_fadeTarget, _fadeCurrent + speed) or max(_fadeTarget, _fadeCurrent - speed)

    for i = 1, 20 do
        local cf = _G["ChatFrame" .. i]
        if cf and CFD(cf).bg then
            cf:SetAlpha(_fadeCurrent)
            local eb = _G["ChatFrame" .. i .. "EditBox"]
            if eb and not eb:HasFocus() then eb:SetAlpha(_fadeCurrent) end
        end
    end
    if _G.GeneralDockManager then _G.GeneralDockManager:SetAlpha(_fadeCurrent) end
    local sb = CFD(_G.ChatFrame1).sidebar
    if sb then sb:SetAlpha(_fadeCurrent) end
end)

-- ----- TAB STYLING -----

local TAB_TEX_SUFFIXES = {
    "Left","Middle","Right",
    "SelectedLeft","SelectedMiddle","SelectedRight",
    "ActiveLeft","ActiveMiddle","ActiveRight",
    "HighlightLeft","HighlightMiddle","HighlightRight",
}

local function UpdateTabStyle(tab)
    if not tab or not CFD(tab).skinned then return end
    local cf = _G["ChatFrame" .. tab:GetID()]
    if not cf then return end
    local sel = GENERAL_CHAT_DOCK and FCFDock_GetSelectedWindow and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
    local active = (cf == sel)
    if CFD(tab).tabText then
        CFD(tab).tabText:SetFont(GetFont(), max(10, GetChatFontSize() - 1), "")
        CFD(tab).tabText:SetPoint("CENTER", tab, "CENTER")
        CFD(tab).tabText:SetTextColor(1, 1, 1, active and 1 or 0.5)
    end
    local tabAlpha = GetChatCfg().tabAlpha or BG_A
    if CFD(tab).bg then CFD(tab).bg:SetColorTexture(BG_R, BG_G, BG_B, tabAlpha * 0.5) end
    if CFD(tab).activeBg then CFD(tab).activeBg:SetColorTexture(BG_R, BG_G, BG_B, tabAlpha) end
    if CFD(tab).bg then CFD(tab).bg:SetShown(not active) end
    if CFD(tab).activeBg then CFD(tab).activeBg:SetShown(active) end
    if CFD(tab).underline then CFD(tab).underline:SetShown(active) end
end

local function UpdateAllTabs()
    for i = 1, 20 do
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab and CFD(tab).skinned then UpdateTabStyle(tab) end
    end
end

local function SkinTab(cf)
    local name = cf:GetName()
    if not name then return end
    local tab = _G[name .. "Tab"]
    if not tab or CFD(tab).skinned then return end
    CFD(tab).skinned = true

    for _, s in ipairs(TAB_TEX_SUFFIXES) do
        local tex = _G[name .. "Tab" .. s] or tab[s]
        if tex and tex.SetTexture then tex:SetTexture(nil) end
    end
    local hl = tab:GetHighlightTexture()
    if hl then hl:SetTexture(nil) end
    if tab.conversationIcon then tab.conversationIcon:SetParent(_hiddenParent) end

    CFD(tab).bg = tab:CreateTexture(nil, "BACKGROUND")
    CFD(tab).bg:SetAllPoints()
    CFD(tab).bg:SetColorTexture(BG_R, BG_G, BG_B, BG_A * 0.5)

    CFD(tab).activeBg = tab:CreateTexture(nil, "BACKGROUND")
    CFD(tab).activeBg:SetAllPoints()
    CFD(tab).activeBg:SetColorTexture(BG_R, BG_G, BG_B, BG_A)
    CFD(tab).activeBg:Hide()

    CFD(tab).tabText = tab:GetFontString()
    tab:SetPushedTextOffset(0, 0)

    local ul = tab:CreateTexture(nil, "OVERLAY")
    ul:SetHeight(2)
    ul:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 2, 0)
    ul:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 0)
    ul:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 1)
    ul:Hide()
    CFD(tab).underline = ul

    hooksecurefunc(tab, "SetAlpha", function(self, a, skip)
        if skip or self.alerting then return end
        local _cf = _G["ChatFrame" .. self:GetID()]
        local sel = GENERAL_CHAT_DOCK and FCFDock_GetSelectedWindow and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
        self:SetAlpha((_cf and _cf == sel) and 1 or 0.5, true)
    end)

    UpdateTabStyle(tab)
end

-- ----- EDIT BOX -----

local function SkinEditBox(cf)
    local name = cf:GetName()
    if not name then return end
    local eb = _G[name .. "EditBox"]
    if not eb or CFD(eb).skinned then return end
    CFD(eb).skinned = true

    for _, tn in ipairs({
        name.."EditBoxLeft", name.."EditBoxMid", name.."EditBoxRight",
        name.."EditBoxFocusLeft", name.."EditBoxFocusMid", name.."EditBoxFocusRight",
    }) do
        local tex = _G[tn]
        if tex then tex:SetAlpha(0) end
    end
    if eb.focusLeft then eb.focusLeft:SetAlpha(0) end
    if eb.focusMid then eb.focusMid:SetAlpha(0) end
    if eb.focusRight then eb.focusRight:SetAlpha(0) end

    eb:SetFont(GetFont(), 12, "")
    eb:SetTextInsets(6, 6, 0, 0)
    eb:SetAltArrowKeyMode(false)

    local function ApplyEditBoxLayout()
        eb:ClearAllPoints()
        eb:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", 0, -2)
        eb:SetPoint("TOPRIGHT", cf, "BOTTOMRIGHT", 0, -2)
        eb:SetHeight(20)
    end
    CFD(eb).ApplyLayout = ApplyEditBoxLayout
    ApplyEditBoxLayout()

    -- Background behind edit box (same dimensions as chat bg)
    if not CFD(eb).ebBg then
        local ebg = CreateFrame("Frame", nil, eb)
        ebg:SetPoint("TOPLEFT", eb, "TOPLEFT", -8, 2)
        ebg:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 4, -6)
        ebg:SetFrameLevel(max(0, eb:GetFrameLevel() - 1))
        local ebt = ebg:CreateTexture(nil, "BACKGROUND")
        ebt:SetAllPoints()
        local ea = GetChatCfg().ebAlpha
        ebt:SetColorTexture(BG_R, BG_G, BG_B, ea or 0.50)
        local ebb = Skin:CreateBorder(ebg)
        ebb:SetAllPoints()
        Skin:SetBorderColor(ebb, {1, 1, 1, BORDER_A})
        CFD(eb).ebBg = ebg
        CFD(eb).ebBgTex = ebt
    end

    -- History
    if not CFD(eb).history then
        CFD(eb).history = {}
        CFD(eb).histIdx = 0
        hooksecurefunc(eb, "AddHistoryLine", function(self, text)
            if not text or text == "" then return end
            local h = CFD(self).history
            if h[#h] ~= text then
                h[#h + 1] = text
                if #h > 50 then tremove(h, 1) end
            end
        end)
        eb:HookScript("OnKeyDown", function(self, key)
            if key ~= "UP" and key ~= "DOWN" then return end
            local h = CFD(self).history
            if #h == 0 then return end
            if key == "UP" then
                CFD(self).histIdx = min(CFD(self).histIdx + 1, #h)
            else
                CFD(self).histIdx = max(CFD(self).histIdx - 1, 0)
            end
            if CFD(self).histIdx == 0 then
                self:SetText("")
            else
                self:SetText(h[#h - CFD(self).histIdx + 1])
            end
        end)
        eb:HookScript("OnEditFocusLost", function() CFD(eb).histIdx = 0 end)
    end
end

-- ----- SCROLLBAR -----

local function SkinScrollBar(cf)
    if CFD(cf).scrollTrack then return end
    local blizSB = cf.ScrollBar
    if not blizSB then return end

    -- Keep Blizzard's scrollbar logic and events active because the RexUI
    -- track reads and writes its scroll percentage. Only hide the artwork.
    blizSB:SetParent(_hiddenParent)
    blizSB:Hide()

    local track = CreateFrame("Button", nil, cf)
    track:SetWidth(6)
    track:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -2, -2)
    track:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -2, 2)
    track:SetFrameLevel(cf:GetFrameLevel() + 10)

    local thumb = track:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(1, 1, 1, 0.25)
    thumb:SetWidth(3)

    local hovered, dragging, dragOffY = false, false, 0
    track:SetAlpha(0)

    local function Upd()
        local pct = blizSB.GetScrollPercentage and blizSB:GetScrollPercentage()
        local ext = blizSB.GetVisibleExtentPercentage and blizSB:GetVisibleExtentPercentage()
        if not pct or not ext or ext >= 1 then thumb:Hide(); return end
        local th = track:GetHeight()
        local umh = max(20, th * ext)
        thumb:SetHeight(umh)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -(th - umh) * pct)
        thumb:Show()
    end

    local function TrackOnUpdate()
        if dragging then
            if not IsMouseButtonDown("LeftButton") then
                dragging = false
                if not track:IsMouseOver() then
                    hovered = false
                    track:SetAlpha(0)
                    track:SetScript("OnUpdate", nil)
                end
                return
            end
            local _, cy = GetCursorPosition()
            local es = track:GetEffectiveScale()
            local tTop = track:GetTop() or 0
            local ext = blizSB.GetVisibleExtentPercentage and blizSB:GetVisibleExtentPercentage() or 1
            local th = track:GetHeight()
            local umh = max(20, th * ext)
            local localY = (cy / es) - (tTop - th) - dragOffY
            local pctNew = max(0, min(1, 1 - localY / (th - umh)))
            if blizSB.SetScrollPercentage then blizSB:SetScrollPercentage(pctNew) end
            Upd()
            return
        end
        if hovered then Upd() end
    end

    track:SetScript("OnEnter", function()
        hovered = true
        track:SetAlpha(0.8)
        track:SetScript("OnUpdate", TrackOnUpdate)
        Upd()
    end)
    track:SetScript("OnLeave", function()
        if not dragging then
            hovered = false
            track:SetAlpha(0)
            track:SetScript("OnUpdate", nil)
        end
    end)

    track:SetScript("OnMouseDown", function(self, b)
        if b ~= "LeftButton" then return end
        dragging = true
        track:SetScript("OnUpdate", TrackOnUpdate)
        local _, cy = GetCursorPosition()
        local s = self:GetEffectiveScale()
        local tTop = self:GetTop()
        if not tTop then return end
        local ext = blizSB.GetVisibleExtentPercentage and blizSB:GetVisibleExtentPercentage() or 1
        local th = self:GetHeight()
        local umh = max(20, th * ext)
        local localY = cy / s - (tTop - th)
        dragOffY = 0
        local pct = blizSB.GetScrollPercentage and blizSB:GetScrollPercentage() or 0
        local thumbTop = th - (th - umh) * pct
        dragOffY = localY - (thumbTop - umh/2)
    end)
    track:SetScript("OnMouseUp", function()
        dragging = false
        if not hovered then
            track:SetScript("OnUpdate", nil)
        end
    end)

    CFD(cf).scrollTrack = track
end

-- ----- COPY POPUP -----

local copyDimmer, copyPopup

local function CleanChatLine(text)
    if text == nil then return nil end
    if type(text) ~= "string" then return nil end

    local ok, cleaned = pcall(function(value)
        value = strgsub(value, "|H.-|h(.-)|h", "%1")
        value = strgsub(value, "|T.-|t", "")
        value = strgsub(value, "|A.-|a", "")
        value = strgsub(value, "|K.-|k", "")
        return value
    end, text)

    if ok and type(cleaned) == "string" then
        return cleaned
    end

    return nil
end

local function ReadChatText()
    local sel = GENERAL_CHAT_DOCK and FCFDock_GetSelectedWindow and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
    local cf = sel or ChatFrame1
    if not cf or not cf.GetNumMessages then return "" end
    local n = cf:GetNumMessages()
    if n == 0 then return "" end
    local lines = {}
    for i = 1, n do
        local ok, text = pcall(cf.GetMessageInfo, cf, i)
        if ok then
            local cleaned = CleanChatLine(text)
            if cleaned and cleaned ~= "" then
                lines[#lines + 1] = cleaned
            end
        end
    end
    return table.concat(lines, "\n")
end

local function ShowCopyPopup()
    if not copyDimmer then
        local POP_W, POP_H = 700, 460
        copyDimmer = CreateFrame("Frame", nil, UIParent)
        copyDimmer:SetFrameStrata("FULLSCREEN_DIALOG")
        copyDimmer:SetAllPoints(UIParent)
        copyDimmer:EnableMouse(true)

        local dim = copyDimmer:CreateTexture(nil, "BACKGROUND")
        dim:SetAllPoints()
        dim:SetColorTexture(0, 0, 0, 0.25)

        copyPopup = CreateFrame("Frame", nil, copyDimmer)
        copyPopup:SetSize(POP_W, POP_H)
        copyPopup:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        copyPopup:SetFrameStrata("FULLSCREEN_DIALOG")

        local bg = copyPopup:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.06, 0.08, 0.10, 0.95)

        local bdr = Skin:CreateBorder(copyPopup)
        bdr:SetAllPoints()
        Skin:SetBorderColor(bdr, {1, 1, 1, 0.10})

        local textBox = CreateFrame("Frame", nil, copyPopup, "ScrollingEditBoxTemplate")
        textBox:SetPoint("TOPLEFT", copyPopup, "TOPLEFT", 18, -18)
        textBox:SetPoint("BOTTOMRIGHT", copyPopup, "BOTTOMRIGHT", -18, 46)
        textBox:SetClipsChildren(true)

        local editBox = textBox:GetEditBox()
        editBox:SetFont(GetFont(), 12, "")
        editBox:SetTextColor(1, 1, 1, 0.75)
        editBox:SetWidth(POP_W - 48)
        editBox:SetTextInsets(4, 10, 4, 4)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetMaxLetters(0)
        if editBox.SetIndentedWordWrap then
            editBox:SetIndentedWordWrap(false)
        end
        editBox:SetScript("OnEscapePressed", function() editBox:ClearFocus(); copyDimmer:Hide() end)
        editBox:SetScript("OnChar", function(self)
            if self._ro then self:SetText(self._ro); self:HighlightText() end
        end)

        local closeBtn = CreateFrame("Button", nil, copyPopup)
        closeBtn:SetSize(80, 24)
        closeBtn:SetPoint("BOTTOM", copyPopup, "BOTTOM", 0, 10)
        local ct = closeBtn:CreateFontString(nil, "OVERLAY")
        ct:SetFont(GetFont(), 10, "")
        ct:SetTextColor(1, 1, 1, 0.6)
        ct:SetPoint("CENTER")
        ct:SetText("Close")
        local cbg = closeBtn:CreateTexture(nil, "BACKGROUND")
        cbg:SetAllPoints()
        cbg:SetColorTexture(0.10, 0.12, 0.16, 1)
        closeBtn:SetScript("OnClick", function() copyDimmer:Hide() end)
        closeBtn:HookScript("OnEnter", function() ct:SetTextColor(1, 1, 1, 0.9) end)
        closeBtn:HookScript("OnLeave", function() ct:SetTextColor(1, 1, 1, 0.6) end)

        copyDimmer:SetScript("OnMouseDown", function()
            if not copyPopup:IsMouseOver() then copyDimmer:Hide() end
        end)

        copyPopup._textBox = textBox
        copyPopup._editBox = editBox
    end

    local text = ReadChatText()
    if text == "" then text = "(No chat history)" end
    copyPopup._textBox:SetText(text)
    copyPopup._editBox._ro = text
    copyDimmer:Show()
    C_Timer.After(0.05, function()
        copyPopup._editBox:SetFocus()
        copyPopup._editBox:HighlightText()
    end)
end

-- ----- PORTAL FLYOUT -----

local HEARTHSTONE_ITEM_ID = 6948

local portalFlyout, portalBtns, hearthBtns

local function IsPortalKnown(spellID)
    if C_SpellBook and C_SpellBook.IsSpellInSpellBook
        and Enum and Enum.SpellBookSpellBank then
        return C_SpellBook.IsSpellInSpellBook(
            spellID,
            Enum.SpellBookSpellBank.Player,
            true
        ) == true
    end
    if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
        return C_SpellBook.IsSpellKnownOrInSpellBook(spellID) == true
    end
    return IsPlayerSpell and IsPlayerSpell(spellID) == true
end

local function GetRexUIItemCooldown(itemID)
    if C_Item and C_Item.GetItemCooldown then
        local ok, startTime, duration = pcall(C_Item.GetItemCooldown, itemID)
        if ok then return startTime, duration end
    end
    if C_Container and C_Container.GetItemCooldown then
        local ok, startTime, duration = pcall(C_Container.GetItemCooldown, itemID)
        if ok then return startTime, duration end
    end
    if GetItemCooldown then
        local ok, startTime, duration = pcall(GetItemCooldown, itemID)
        if ok then return startTime, duration end
    end
end

local function RefreshPortals()
    if not portalBtns then return end
    for _, btn in ipairs(portalBtns) do
        local known = IsPortalKnown(btn.spellID)
        btn.icon:SetDesaturated(not known)
        btn.icon:SetAlpha(known and 1 or 0.4)
        if known then
            local cd = C_Spell.GetSpellCooldown(btn.spellID)
            if cd and cd.duration and cd.duration > 0 and type(cd.startTime) == "number" then
                btn.cd:SetCooldown(cd.startTime, cd.duration)
            else btn.cd:Clear() end
        else btn.cd:Clear() end
    end
    if hearthBtns then
        for _, btn in ipairs(hearthBtns) do
            if btn._type == "spell" then
                local cd = C_Spell.GetSpellCooldown(btn._id)
                if cd and cd.duration and cd.duration > 0 and type(cd.startTime) == "number" then btn.cd:SetCooldown(cd.startTime, cd.duration)
                else btn.cd:Clear() end
            elseif btn._type == "item" then
                local st, dur = GetRexUIItemCooldown(btn._id)
                if st and dur and dur > 0 then btn.cd:SetCooldown(st, dur)
                else btn.cd:Clear() end
            end
        end
    end
end

local function ResolveHearth()
    if not hearthBtns then return end

    -- Button 1: use the language-independent item ID. The previous
    -- "/cast Hearthstone" macro failed on localized clients and treated the
    -- Hearthstone as a player spell instead of an inventory item.
    local b1 = hearthBtns[1]
    if b1 then
        local icon = C_Item and C_Item.GetItemIconByID
            and C_Item.GetItemIconByID(HEARTHSTONE_ITEM_ID)
        b1._type, b1._id = "item", HEARTHSTONE_ITEM_ID
        b1.icon:SetTexture(icon or 134414)
        b1.icon:SetTexCoord(6/64, 58/64, 6/64, 58/64)
        b1:SetAttribute("type", "item")
        b1:SetAttribute("item", "item:" .. HEARTHSTONE_ITEM_ID)
        b1:SetAttribute("macrotext", nil)
        b1:Show()
    end

    -- Button 2 + 3: ohne zuverlaessigen Resolver ausgeblendet
    for i = 2, #hearthBtns do
        local btn = hearthBtns[i]
        if btn then btn:Hide() end
    end
end

local function CreatePortalFlyout()
    if portalFlyout then return portalFlyout end

    local BS, SP, PD = 32, 1, 2
    portalFlyout = CreateFrame("Frame", nil, UIParent)
    portalFlyout:SetSize(BS + PD * 2, BS + PD * 2)
    portalFlyout:SetFrameStrata("DIALOG")
    portalFlyout:SetFrameLevel(100)

    local bg = portalFlyout:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(BG_R, BG_G, BG_B, 0.95)
    local bdr = Skin:CreateBorder(portalFlyout)
    bdr:SetAllPoints()
    Skin:SetBorderColor(bdr, {1, 1, 1, BORDER_A})

    local guard = CreateFrame("Frame"); guard:RegisterEvent("PLAYER_REGEN_DISABLED")
    guard:SetScript("OnEvent", function() portalFlyout:Hide() end)

    portalBtns = {}
    -- Hearth buttons
    local HS_N = 1
    hearthBtns = {}
    local hsX = PD
    for i = 1, HS_N do
        local btn = CreateFrame("Button", nil, portalFlyout, "SecureActionButtonTemplate")
        btn:SetSize(BS, BS)
        btn:SetPoint("TOPLEFT", portalFlyout, "TOPLEFT", hsX, -(PD + (i-1)*(BS+SP)))
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(); icon:SetTexCoord(6/64, 58/64, 6/64, 58/64)
        btn.icon = icon
        local b2 = Skin:CreateBorder(btn)
        b2:SetAllPoints()
        Skin:SetBorderColor(b2, {0, 0, 0, 1})
        local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        cd:SetAllPoints(); cd:SetHideCountdownNumbers(true); cd:SetDrawSwipe(true); cd:SetDrawBling(false); cd:SetDrawEdge(false)
        btn.cd = cd
        local hov = btn:CreateTexture(nil, "HIGHLIGHT")
        hov:SetAllPoints(); hov:SetColorTexture(1, 1, 1, 0.20)
        btn:RegisterForClicks("AnyUp", "AnyDown")
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self._type == "spell" then GameTooltip:SetSpellByID(self._id)
            elseif self._type == "item" then GameTooltip:SetItemByID(self._id)
            elseif self._type == "housing" then GameTooltip:AddLine("Housing Dashboard")
            end; GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        btn:HookScript("PostClick", function(self)
            if self._type == "housing" and HousingFramesUtil and HousingFramesUtil.ToggleHousingDashboard then
                HousingFramesUtil.ToggleHousingDashboard()
                portalFlyout:Hide()
            end
        end)
        hearthBtns[i] = btn
    end

    portalFlyout:SetScript("OnShow", function(self)
        self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        self:RegisterEvent("BAG_UPDATE_COOLDOWN")
        ResolveHearth()
        RefreshPortals()
    end)
    portalFlyout:SetScript("OnHide", function(self) self:UnregisterAllEvents() end)
    portalFlyout:SetScript("OnEvent", function(self, ev)
        if ev == "SPELL_UPDATE_COOLDOWN"
        or ev == "BAG_UPDATE_COOLDOWN" then
            RefreshPortals()
        end
    end)

    return portalFlyout
end

local function TogglePortalFlyout(anchor)
    if InCombatLockdown() then return end
    local f = CreatePortalFlyout()
    if f:IsShown() then f:Hide(); return end
    local bs = anchor:GetEffectiveScale()
    local fs = f:GetEffectiveScale()
    local bRight = anchor:GetRight() * bs
    local bTop = anchor:GetTop() * bs
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (bRight+4)/fs, (bTop+4)/fs)
    f:Show()
end

-- ----- URL DETECTION -----

local function ContainsURL(text)
    if not text then return false end
    local ok, found = pcall(function(value)
        return strfind(value, "://", 1, true) or strfind(value, "www.", 1, true)
    end, text)

    return ok and found or false
end

local function WrapURLs(text)
    if not text then return text end
    local patterns = {
        "%f[%S](%a[%w+.-]+://%S+)", "^(%a[%w+.-]+://%S+)",
        "%f[%S](www%.[-%w_%%]+%.%a%a+/%S+)", "^(www%.[-%w_%%]+%.%a%a+/%S+)",
        "%f[%S](www%.[-%w_%%]+%.%a%a+)", "^(www%.[-%w_%%]+%.%a%a+)",
    }
    local hex = "|cff3399ff"
    local ok, wrapped = pcall(function(value)
        for _, p in ipairs(patterns) do
            value = strgsub(value, p, hex .. "|H" .. ADDON_NAME .. "url:%1|h[%1]|h|r")
        end

        return value
    end, text)

    return ok and wrapped or text
end

-- Register filters outside RexUI's tainted execution context. On Retail, a raw
-- registration can contaminate Blizzard's shared chat dispatch/history state.
local function AddMessageEventFilter(event, filter)
    if securecallfunction then
        securecallfunction(ChatFrame_AddMessageEventFilter, event, filter)
    elseif securecall then
        securecall("ChatFrame_AddMessageEventFilter", event, filter)
    else
        ChatFrame_AddMessageEventFilter(event, filter)
    end
end

hooksecurefunc("SetItemRef", function(link)
    if canaccessvalue and not canaccessvalue(link) then return end
    local ok, url = pcall(function(value)
        return value and strmatch(value, "^" .. ADDON_NAME .. "url:(.+)$")
    end, link)
    if not ok then return end

    if url then
        local popup = CreateFrame("Frame", nil, UIParent)
        popup:SetFrameStrata("DIALOG"); popup:SetFrameLevel(500)
        popup:SetSize(340, 44); popup:EnableMouse(true)
        local bg = popup:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetColorTexture(0.06, 0.08, 0.10, 0.97)
        local bdr = Skin:CreateBorder(popup)
        bdr:SetAllPoints()
        Skin:SetBorderColor(bdr, {1, 1, 1, 0.10})
        popup:SetScript("OnMouseUp", function(self) self:Hide() end)

        local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
        close:SetSize(20, 20)
        close:SetPoint("TOPRIGHT", popup, "TOPRIGHT", 2, 2)
        close:SetScript("OnClick", function() popup:Hide() end)

        local hint = popup:CreateFontString(nil, "OVERLAY")
        hint:SetFont(GetFont(), 8, ""); hint:SetTextColor(1, 1, 1, 0.5)
        hint:SetPoint("TOP", popup, "TOP", 0, -4)
        hint:SetText(T("Strg+C zum Kopieren - Esc oder X zum Schließen"))
        local eb = CreateFrame("EditBox", nil, popup)
        eb:SetSize(300, 16); eb:SetPoint("TOP", hint, "BOTTOM", 0, -3)
        eb:SetFont(GetFont(), 11, ""); eb:SetAutoFocus(false); eb:SetJustifyH("CENTER")
        eb:SetText(url); eb:HighlightText()
        local ebg = eb:CreateTexture(nil, "BACKGROUND")
        ebg:SetColorTexture(0.10, 0.12, 0.16, 1)
        ebg:SetPoint("TOPLEFT", -6, 4); ebg:SetPoint("BOTTOMRIGHT", 6, -4)
        eb:SetScript("OnEscapePressed", function() eb:ClearFocus(); popup:Hide() end)
        eb:SetScript("OnKeyDown", function(_, k) if k == "C" and IsControlKeyDown() then C_Timer.After(0.1, function() popup:Hide() end) end end)
        popup:SetScript("OnHide", function() eb:ClearFocus() end)
        local cx, cy = GetCursorPosition()
        local s = UIParent:GetEffectiveScale()
        popup:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", cx/s, cy/s + 10)
        popup:Show(); eb:SetFocus(); eb:HighlightText()
    end
end)

-- ----- SIDEBAR -----

local function ToggleRexUIFriendsFrame()
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.3, 0.3, 1)
        return
    end

    if type(_G.ToggleFriendsFrame) ~= "function" then
        if C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, "Blizzard_FriendsFrame")
        elseif UIParentLoadAddOn then
            pcall(UIParentLoadAddOn, "Blizzard_FriendsFrame")
        end
    end

    if type(_G.ToggleFriendsFrame) == "function" then
        _G.ToggleFriendsFrame(_G.FRIEND_TAB_FRIENDS or 1)
    else
        UIErrorsFrame:AddMessage(T("Freundesliste konnte nicht geladen werden."), 1, 0.3, 0.3, 1)
    end
end

local function CreateSidebar()
    local cf1 = _G.ChatFrame1
    if not cf1 or CFD(cf1).sidebar then return end

    local side = CreateFrame("Frame", nil, UIParent)
    side:SetWidth(36)
    side:SetFrameStrata(cf1:GetFrameStrata() or "MEDIUM")
    side:SetFrameLevel((cf1:GetFrameLevel() or 1) + 20)
    local sbg = side:CreateTexture(nil, "BACKGROUND")
    sbg:SetAllPoints(); sbg:SetColorTexture(BG_R, BG_G, BG_B, GetChatCfg().sidebarAlpha or BG_A)
    local sdiv = side:CreateTexture(nil, "OVERLAY")
    sdiv:SetWidth(1); sdiv:SetColorTexture(1, 1, 1, BORDER_A)
    CFD(cf1).sidebar = side
    CFD(cf1).sidebarBgTex = sbg
    CFD(cf1).sidebarDiv = sdiv

    local GAP = 4
    local function MkBtn(tex, sz, tooltip)
        sz = sz or 20
        local b = CreateFrame("Button", nil, side)
        b:SetSize(28, 28)
        b:RegisterForClicks("LeftButtonUp")
        local ic = b:CreateTexture(nil, "OVERLAY")
        ic:SetSize(sz, sz)
        ic:SetPoint("CENTER")
        ic:SetTexture(tex)
        ic:SetDesaturated(true); ic:SetVertexColor(1, 1, 1, 0.4)
        b._icon = ic

        local highlight = b:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetPoint("TOPLEFT", 1, -1)
        highlight:SetPoint("BOTTOMRIGHT", -1, 1)
        highlight:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.16)

        b:HookScript("OnEnter", function(self)
            ic:SetVertexColor(1, 1, 1, 0.95)
            if tooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(T(tooltip), 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        b:HookScript("OnLeave", function()
            ic:SetVertexColor(1, 1, 1, 0.4)
            GameTooltip:Hide()
        end)
        b:HookScript("OnMouseDown", function()
            ic:SetPoint("CENTER", 1, -1)
        end)
        b:HookScript("OnMouseUp", function()
            ic:SetPoint("CENTER", 0, 0)
        end)
        return b
    end

    local sidebarBtns = {}
    local lastBtn

    local function AddSideBtn(key, tex, sz, tooltip, onClick)
        local btn = MkBtn(tex, sz or 20, tooltip)
        if lastBtn then
            btn:SetPoint("TOP", lastBtn, "BOTTOM", 0, -GAP)
        else
            btn:SetPoint("TOP", side, "TOP", 0, -GAP)
        end
        btn:SetScript("OnClick", onClick)
        CFD(cf1)[key:lower() .. "Btn"] = btn
        sidebarBtns[#sidebarBtns + 1] = { key = key, button = btn }
        lastBtn = btn
        return btn
    end

    AddSideBtn("friends", SIDEBAR_ICONS.friends, 24, "Freundesliste", ToggleRexUIFriendsFrame)
    AddSideBtn("copy", SIDEBAR_ICONS.copy, 20, "Chat kopieren", ShowCopyPopup)
    AddSideBtn("portals", SIDEBAR_ICONS.portal, 24, "Ruhesteine", function(self) TogglePortalFlyout(self) end)
    AddSideBtn("voice", SIDEBAR_ICONS.voice, 20, "Sprachchat", function()
        if InCombatLockdown() then return end
        ToggleChannelFrame()
    end)
    AddSideBtn("settings", SIDEBAR_ICONS.settings, 20, "RexUI-Einstellungen", function()
        if InCombatLockdown() then return end
        RexUI.ConfigUI:Toggle()
    end)
    AddSideBtn("scroll", SIDEBAR_ICONS.scroll, 20, "Zum neuesten Beitrag", function()
        if ChatFrame1 and ChatFrame1.ScrollBar and ChatFrame1.ScrollBar.SetScrollPercentage then
            ChatFrame1.ScrollBar:SetScrollPercentage(1)
        end
    end)

    local function RefreshSidebarButtons()
        local cfg = GetChatCfg()
        local visibleButtons = {}

        for _, entry in ipairs(sidebarBtns) do
            local btn = entry.button
            local visible = cfg["show" .. entry.key] ~= false
            btn:SetShown(visible)
            btn:ClearAllPoints()
            if visible then visibleButtons[#visibleButtons + 1] = btn end
        end

        -- Keep every enabled icon in one ordered group and center that group
        -- vertically. The scroll button previously had a separate bottom
        -- anchor, which caused overlaps and an uneven layout at some chat
        -- heights or when individual buttons were disabled.
        local count = #visibleButtons
        if count == 0 then return end
        local totalHeight = (count * 28) + ((count - 1) * GAP)
        for index, btn in ipairs(visibleButtons) do
            if index == 1 then
                btn:SetPoint("TOP", side, "CENTER", 0, totalHeight / 2)
            else
                btn:SetPoint("TOP", visibleButtons[index - 1], "BOTTOM", 0, -GAP)
            end
        end
    end
    CFD(cf1).RefreshSidebarButtons = RefreshSidebarButtons
    RefreshSidebarButtons()

    local function Repos()
        local bg = CFD(cf1).bg
        if not bg then return end
        side:ClearAllPoints()
        side:SetPoint("TOPRIGHT", bg, "TOPLEFT", 0, 0)
        side:SetPoint("BOTTOMRIGHT", bg, "BOTTOMLEFT", 0, 0)
        sdiv:ClearAllPoints()
        sdiv:SetPoint("TOPRIGHT", side, "TOPRIGHT", 0, 0)
        sdiv:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", 0, 0)
        RefreshSidebarButtons()
    end
    C_Timer.After(0, Repos)
    cf1:HookScript("OnShow", Repos)
end

-- ----- CHAT NOTIFICATION SOUNDS -----

local _notificationSoundFrame

-- RexUI chat notification sounds. These files ship with RexUI so the
-- selection works without BigWigs, BugSack or other addons installed.
local CHAT_NOTIFICATION_SOUNDS = {
    alarm = "Alarm.ogg",
    alert = "Alert.ogg",
    info = "Info.ogg",
    long = "Long.ogg",
    spell_on_you = "spell_on_you.ogg",
    spell_under_you = "spell_under_you.ogg",
    whisper = "Whisper.ogg",
}

local function PlayChatNotificationSound(selection)
    if not selection or selection == "none" then return end
    local file = CHAT_NOTIFICATION_SOUNDS[selection]
    if file then
        PlaySoundFile("Interface\\AddOns\\RexUI\\media\\Sounds\\" .. file, "SFX")
    end
end

local function SetupNotificationSounds()
    if _notificationSoundFrame then return end

    _notificationSoundFrame = CreateFrame("Frame")
    Skin:RegisterEvents(_notificationSoundFrame, { "CHAT_MSG_GUILD", "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER" })
    _notificationSoundFrame:SetScript("OnEvent", function(_, event, _, sender, _, _, _, _, _, _, _, _, _, guid)
        local cfg = GetChatCfg()
        if event == "CHAT_MSG_GUILD" then
            -- Midnight 12.x can mark CHAT_MSG_* payload fields (including GUID/name)
            -- as secret values. Do not inspect or compare them from addon code.
            local selection = cfg.guildSoundSelection or (cfg.guildSound == false and "none" or "alert")
            PlayChatNotificationSound(selection)
        elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
            local selection = cfg.whisperSoundSelection or (cfg.whisperSound == false and "none" or "whisper")
            PlayChatNotificationSound(selection)
        end
    end)
end

-- ----- IDLE FADE -----

local function SetupIdleFade()
    local idleTimer
    local function StartIdle()
        if _idleActive then return end
        _idleActive = true
        SetIdleFadeAlpha(GetIdleFadeAlpha())
    end
    local function CancelIdle()
        _idleActive = false
        if idleTimer then idleTimer:Cancel(); idleTimer = nil end
        SetIdleFadeAlpha(1)
    end
    local function ResetIdle()
        local cfg = GetChatCfg()
        if cfg.idleFade == false then
            CancelIdle()
            return
        end
        CancelIdle()
        idleTimer = C_Timer.NewTimer(cfg.idleFadeDelay or 15, StartIdle)
    end

    local evtFrame = CreateFrame("Frame")
    local msgEvents = {
        "CHAT_MSG_SAY","CHAT_MSG_YELL","CHAT_MSG_PARTY","CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER","CHAT_MSG_RAID_WARNING",
        "CHAT_MSG_INSTANCE_CHAT","CHAT_MSG_INSTANCE_CHAT_LEADER",
        "CHAT_MSG_GUILD","CHAT_MSG_OFFICER","CHAT_MSG_WHISPER","CHAT_MSG_WHISPER_INFORM",
        "CHAT_MSG_BN_WHISPER","CHAT_MSG_BN_WHISPER_INFORM","CHAT_MSG_CHANNEL",
    }
    Skin:RegisterEvents(evtFrame, msgEvents)
    evtFrame:SetScript("OnEvent", ResetIdle)

    for i = 1, 20 do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then
            eb:HookScript("OnEditFocusGained", ResetIdle)
            eb:HookScript("OnTextChanged", ResetIdle)
        end
    end

    ResetIdle()
end

-- ----- MAIN SKIN -----

local _skinned = {}

local function SkinChatFrame(cf)
    if not cf or _skinned[cf] then return end
    _skinned[cf] = true
    local name = cf:GetName()
    if not name then return end

    -- Background panel
    if not CFD(cf).bg then
        local bg = CreateFrame("Frame", nil, cf)
        bg:SetPoint("TOPLEFT", cf, "TOPLEFT", -8, 2)
        bg:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 4, -6)
        bg:SetFrameLevel(max(0, cf:GetFrameLevel() - 1))

        local tex = bg:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        local ba = GetChatCfg().bgAlpha
        tex:SetColorTexture(BG_R, BG_G, BG_B, ba or BG_A)

        local bdr = Skin:CreateBorder(bg)
        bdr:SetAllPoints(); bdr:SetFrameLevel(bg:GetFrameLevel() + 1)
        Skin:SetBorderColor(bdr, {1, 1, 1, BORDER_A})
        CFD(cf).bg = bg
        CFD(cf).bgTex = tex
    end

    -- Font
    cf:SetFont(GetFont(), GetChatFontSize(), "")
    if cf.SetSpacing then cf:SetSpacing(GetChatLineSpacing()) end
    if cf.SetShadowOffset then cf:SetShadowOffset(1, -1) end
    if cf.SetShadowColor then cf:SetShadowColor(0, 0, 0, 0.8) end
    cf:SetFading(false)

    -- Anklickbare Spielernamen sicherstellen. Einige Retail-Versionen bzw.
    -- Chatfenster verlieren beim Neuaufbau den Hyperlink-Status. Der eigene
    -- Fallback öffnet bei einem normalen Linksklick direkt einen Whisper.
    if cf.SetHyperlinksEnabled then cf:SetHyperlinksEnabled(true) end
    cf:EnableMouse(true)
    cf:HookScript("OnHyperlinkClick", function(frame, link, _, button)
        if button ~= "LeftButton" then return end
        if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then return end
        if canaccessvalue and not canaccessvalue(link) then return end

        local ok, playerName = pcall(function(value)
            return value and strmatch(value, "^player:([^:]+)")
        end, link)
        if not ok or not playerName or playerName == "" then return end

        if type(ChatFrame_SendTell) == "function" then
            pcall(ChatFrame_SendTell, playerName, frame)
        end
    end)

    -- FontStringContainer
    local fsc = cf.FontStringContainer
    if fsc then
        fsc:ClearAllPoints()
        fsc:SetPoint("TOPLEFT", cf, "TOPLEFT", 0, -4)
        fsc:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 0, 0)
    end

    -- Strip chrome
    StripBlizzard(cf)
    if cf.Background then cf.Background:SetAlpha(0) end
    for _, s in ipairs({"BottomButton","DownButton","UpButton","MinimizeButton"}) do
        local btn = _G[name .. s]
        if btn then btn:SetAlpha(0); btn:EnableMouse(false) end
    end
    if cf.ScrollToBottomButton then cf.ScrollToBottomButton:SetParent(_hiddenParent) end
    local btnFrame = _G[name .. "ButtonFrame"]
    if btnFrame then btnFrame:SetParent(_hiddenParent) end

    -- Resize button
    local res = _G[name .. "ResizeButton"]
    if res then
        StripBlizzard(res)
        local rt = res:CreateTexture(nil, "OVERLAY")
        rt:SetColorTexture(1, 1, 1, 0.15)
        rt:SetPoint("BOTTOMRIGHT", res, "BOTTOMRIGHT", -2, 2)
        rt:SetSize(10, 10)
        res:SetSize(14, 14)
        res:ClearAllPoints()
        res:SetPoint("BOTTOMRIGHT", CFD(cf).bg or cf, "BOTTOMRIGHT", -4, 4)
        res:SetFrameStrata("HIGH")
        res:SetAlpha(0.1)
        res:HookScript("OnEnter", function() res:SetAlpha(0.5) end)
        res:HookScript("OnLeave", function() res:SetAlpha(0.1) end)
    end

    -- Edit box
    SkinEditBox(cf)

    -- Tab
    SkinTab(cf)

    -- Scrollbar
    SkinScrollBar(cf)

    -- Combat Log filter bar
    if name == "ChatFrame2" then
        local qbf = _G.CombatLogQuickButtonFrame_Custom
        if qbf and not CFD(qbf).done then
            CFD(qbf).done = true
            StripBlizzard(qbf)
            qbf:ClearAllPoints()
            qbf:SetPoint("BOTTOMLEFT", cf, "TOPLEFT", -8, 2)
            qbf:SetPoint("BOTTOMRIGHT", cf, "TOPRIGHT", 8, 2)
            qbf:SetHeight(22)
            local qbg = qbf:CreateTexture(nil, "BACKGROUND")
            qbg:SetAllPoints(); qbg:SetColorTexture(BG_R, BG_G, BG_B, 1)
            local qdiv = qbf:CreateTexture(nil, "OVERLAY")
            qdiv:SetHeight(1); qdiv:SetColorTexture(1, 1, 1, BORDER_A)
            qdiv:SetPoint("BOTTOMLEFT", qbf, "BOTTOMLEFT", 0, 0)
            qdiv:SetPoint("BOTTOMRIGHT", qbf, "BOTTOMRIGHT", 0, 0)
            for i = 1, select("#", qbf:GetChildren()) do
                local btn = select(i, qbf:GetChildren())
                if btn and (btn:IsObjectType("CheckButton") or btn:IsObjectType("Button")) then
                    StripBlizzard(btn)
                    local fs = btn:GetFontString()
                    if fs then fs:SetFont(GetFont(), 11, "") end
                end
            end
        end
    end
end

-- ----- INIT -----

local function SkinChat()
    if not IsEnabled() then return end

    local count = 0
    for i = 1, 20 do
        local cf = _G["ChatFrame" .. i]
        if cf then SkinChatFrame(cf); count = count + 1 end
    end

    CreateSidebar()

    -- Tab hooks
    if FCFDock_SelectWindow then
        hooksecurefunc("FCFDock_SelectWindow", function() C_Timer.After(0, UpdateAllTabs) end)
    end
    if FCF_Close then
        hooksecurefunc("FCF_Close", function() C_Timer.After(0, UpdateAllTabs) end)
    end
    -- Do not hook FCF_OpenTemporaryWindow on Retail: it runs inside Blizzard's
    -- protected whisper-history path. UPDATE_CHAT_WINDOWS provides a taint-free
    -- notification after temporary whisper/Battle.net windows have changed.
    local chatWindowWatcher = CreateFrame("Frame")
    Skin:RegisterEvents(chatWindowWatcher, { "UPDATE_CHAT_WINDOWS" })
    chatWindowWatcher:SetScript("OnEvent", function()
        C_Timer.After(0, function()
            for i = 1, 20 do
                local cf = _G["ChatFrame" .. i]
                if cf and not _skinned[cf] then SkinChatFrame(cf) end
            end
            UpdateAllTabs()
        end)
    end)

    -- Hide Blizzard buttons
    for _, fn in ipairs({"QuickJoinToastButton","ChatFrameMenuButton","ChatFrameChannelButton",
        "ChatFrameToggleVoiceDeafenButton","ChatFrameToggleVoiceMuteButton"}) do
        local f = _G[fn]
        if f then f:SetAlpha(0); f:EnableMouse(false) end
    end

    -- Hide Blizzard social bar
    local sb = _G.ChatFrameSocialButtons
    if sb then sb:SetAlpha(0); sb:EnableMouse(false) end

    -- URL filter
    local urlEvents = {
        "CHAT_MSG_SAY","CHAT_MSG_YELL","CHAT_MSG_GUILD","CHAT_MSG_OFFICER",
        "CHAT_MSG_PARTY","CHAT_MSG_PARTY_LEADER","CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_INSTANCE_CHAT","CHAT_MSG_INSTANCE_CHAT_LEADER",
        "CHAT_MSG_CHANNEL",
    }
    local function UrlFilter(self, ev, msg, ...)
        -- pcall catches an inaccessible/secret-value error but does not prevent
        -- the execution path from becoming tainted. Reject it before inspection.
        if canaccessvalue and not canaccessvalue(msg) then return false end
        if not msg or not ContainsURL(msg) then return false end
        return false, WrapURLs(msg), ...
    end
    for _, ev in ipairs(urlEvents) do
        AddMessageEventFilter(ev, UrlFilter)
    end

    ApplyTimestamps()
    SetupIdleFade()
    SetupNotificationSounds()

    if _G.GeneralDockManager then _G.GeneralDockManager:SetAlpha(1) end
    UpdateAllTabs()
end

function Skin:RefreshChatConfig()
    if not IsEnabled() then return end
    local cfg = GetChatCfg()
    -- Apply bg alpha to all chat frames
    for i = 1, NUM_CHAT_WINDOWS or 7 do
        local cf = _G["ChatFrame" .. i]
        if cf and CFD(cf).bgTex then
            CFD(cf).bgTex:SetColorTexture(BG_R, BG_G, BG_B, cfg.bgAlpha or BG_A)
            cf:SetFont(GetFont(), GetChatFontSize(), "")
            if cf.SetSpacing then cf:SetSpacing(GetChatLineSpacing()) end
        end
        -- Apply edit box bg alpha
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb and CFD(eb) and CFD(eb).ebBgTex then
            eb:SetFont(GetFont(), 12, "")
            CFD(eb).ebBgTex:SetColorTexture(BG_R, BG_G, BG_B, cfg.ebAlpha or 0.50)
            if CFD(eb).ApplyLayout then CFD(eb).ApplyLayout() end
        end
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab and CFD(tab).skinned then
            UpdateTabStyle(tab)
        end
        -- Apply input position (removed - FCF_SetInputPosition unavailable in this WoW version)
    end
    local cf1 = _G.ChatFrame1
    if cf1 and CFD(cf1).sidebarBgTex then
        CFD(cf1).sidebarBgTex:SetColorTexture(BG_R, BG_G, BG_B, cfg.sidebarAlpha or BG_A)
        if CFD(cf1).RefreshSidebarButtons then
            CFD(cf1).RefreshSidebarButtons()
        end
    end
    if cfg.idleFade == false then
        SetIdleFadeAlpha(1)
    end
    ApplyTimestamps()
end

function Skin:HookChat()
    if self.ChatHooked then return end
    self.ChatHooked = true
    local ok, err = pcall(SkinChat)
    if not ok then RexUI:PrintMessage("Chat error: " .. tostring(err)) end
end
