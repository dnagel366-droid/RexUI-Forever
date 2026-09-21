-- ============================================================
-- RexUI_RaidUtility - Core.lua
-- RexUI raid utility menu for ready checks, pull timers and markers
-- ============================================================

local ADDON_NAME, ns = ...

local RexUI = ns.RexUI or _G.RexUI
if not RexUI then return end

RexUI.RaidUtility = RexUI.RaidUtility or {}
local RU = RexUI.RaidUtility
RexUI:RegisterModule("RaidUtility", RU)

local function T(text)
    return RexUI:LocalizeText(text)
end

local TEXTURE = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"
local MARKER_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local TARGET_MARKER = _G.SLASH_TARGET_MARKER4 or "/tm"
local WORLD_MARKER = _G.SLASH_WORLD_MARKER1 or "/wm"
local CLEAR_WORLD_MARKER = _G.SLASH_CLEAR_WORLD_MARKER1 or "/cwm"

local defaults = {
    enabled = true,
    point = "TOP",
    relPoint = "TOP",
    x = -400,
    y = 1,
    showMarkers = true,
    pullTimer = 10,
}

local eventFrame
local showButton
local panel
local mover
local buttons = {}
local markerButtons = {}
local clearMarkerButton
local WORLD_RAID_MARKER_ORDER = { 5, 6, 3, 2, 7, 1, 4, 8 }

local function InLockdown()
    return InCombatLockdown and InCombatLockdown()
end

local function CopyConfig(saved)
    local cfg = {}
    for k, v in pairs(defaults) do
        cfg[k] = v
    end
    if type(saved) == "table" then
        for k, v in pairs(saved) do
            cfg[k] = v
        end
    end
    return cfg
end

function RU:GetConfig()
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    return CopyConfig(profile and profile.raidUtility)
end

function RU:Save(key, value)
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    if not profile then return end
    profile.raidUtility = profile.raidUtility or {}
    profile.raidUtility[key] = value
end

local function GetColor(name, r, g, b, a)
    if RexUI.GetColor then
        local cr, cg, cb, ca = RexUI:GetColor(name)
        if cr and cg and cb then return cr, cg, cb, ca or a or 1 end
    end
    return r or 1, g or 1, b or 1, a or 1
end

local function StyleFrame(frame, alpha)
    frame:SetBackdrop({
        bgFile = TEXTURE,
        edgeFile = TEXTURE,
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.02, 0.015, 0.025, alpha or 0.88)
    frame:SetBackdropBorderColor(GetColor("border", 0.22, 0.08, 0.32, 0.95))
end

local function StyleButton(button)
    StyleFrame(button, 0.72)

    button:SetHighlightTexture(TEXTURE)
    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetColorTexture(GetColor("highlight", 0.85, 0.25, 1, 0.18))
    end

    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(GetColor("highlight", 0.85, 0.25, 1, 1))
        if self.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(T(self.tooltip))
            GameTooltip:Show()
        end
    end)

    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(GetColor("border", 0.22, 0.08, 0.32, 0.95))
        GameTooltip:Hide()
    end)
end

local function HideBlizzardFrame(frame)
    if not frame then return end

    if InLockdown() then
        RU.pendingBlizzardHide = true
        return
    end

    frame:SetAlpha(0)
    frame:EnableMouse(false)
    frame:Hide()

    if frame._rexRaidUtilityHidden then return end
    frame._rexRaidUtilityHidden = true

    hooksecurefunc(frame, "Show", function(self)
        if InLockdown() then
            RU.pendingBlizzardHide = true
            return
        end

        self:SetAlpha(0)
        self:EnableMouse(false)
        self:Hide()
    end)
end

function RU:HideBlizzard()
    HideBlizzardFrame(_G.CompactRaidFrameManager)
    HideBlizzardFrame(_G.CompactRaidFrameManagerDisplayFrame)
    HideBlizzardFrame(_G.CompactRaidFrameManagerContainer)
    HideBlizzardFrame(_G.CompactRaidFrameManagerResizeFrame)
    HideBlizzardFrame(_G.CompactRaidFrameManagerToggleButton)
end

local function SetButtonEnabled(button, enabled)
    button.enabled = enabled == true
    button:SetAlpha(button.enabled and 1 or 0.45)
    if button.Text then
        button.Text:SetTextColor(button.enabled and 1 or 0.55, button.enabled and 1 or 0.55, button.enabled and 1 or 0.55, 1)
    end
end

local function CreateTextButton(parent, name, text, width, height, onClick, template)
    local button = CreateFrame("Button", name, parent, template or "BackdropTemplate")
    button:SetSize(width or 100, height or 22)
    button:RegisterForClicks("AnyUp")
    StyleButton(button)

    button.Text = button:CreateFontString(nil, "OVERLAY")
    button.Text:SetFont(FONT, 10, "OUTLINE")
    button.Text:SetPoint("CENTER", 0, 0)
    button.Text:SetText(T(text or ""))

    if onClick then
        button:SetScript("OnClick", onClick)
    end

    buttons[#buttons + 1] = button
    return button
end

local function IsPvpInstance()
    local _, instanceType = IsInInstance()
    return instanceType == "pvp" or instanceType == "arena"
end

function RU:InGroup()
    return IsInGroup and IsInGroup() and not IsPvpInstance()
end

function RU:HasPermission()
    if not self:InGroup() then return false end
    if not UnitIsGroupLeader or not UnitIsGroupAssistant then return true end
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

function RU:IsLeader()
    return self:InGroup() and UnitIsGroupLeader and UnitIsGroupLeader("player")
end

local function UpdateMarkerTexCoord(texture, index)
    local left = ((index - 1) % 4) * 0.25
    local right = left + 0.25
    local top = math.floor((index - 1) / 4) * 0.25
    local bottom = top + 0.25
    texture:SetTexCoord(left, right, top, bottom)
end

local function TargetMarkerMacro(index)
    return TARGET_MARKER .. " " .. index
end

local function WorldMarkerMacro(index)
    local marker = WORLD_RAID_MARKER_ORDER[index] or index
    return CLEAR_WORLD_MARKER .. " " .. marker .. "\n" .. WORLD_MARKER .. " " .. marker
end

local function RegisterSecureMarkerClicks(button)
    button:RegisterForClicks("AnyDown", "AnyUp")

    if C_CVar and C_CVar.GetCVarBool then
        button:SetAttribute("useOnKeyDown", C_CVar.GetCVarBool("ActionButtonUseKeyDown"))
    end
end

local function ConfigureMarkerButton(button, index)
    local targetMacro = TargetMarkerMacro(index)
    local worldMacro = WorldMarkerMacro(index)

    button:SetAttribute("shift-type*", "macro")
    button:SetAttribute("type1", "macro")
    button:SetAttribute("type2", "macro")
    button:SetAttribute("type3", "macro")
    button:SetAttribute("macrotext", worldMacro)
    button:SetAttribute("macrotext1", targetMacro)
    button:SetAttribute("macrotext2", targetMacro)
    button:SetAttribute("macrotext3", targetMacro)
end

local function ConfigureClearMarkerButton(button)
    button:SetAttribute("isclearbutton", true)
    button:SetAttribute("shift-type*", "worldmarker")
    button:SetAttribute("shift-action*", "clear")
    button:SetAttribute("type1", "raidtarget")
    button:SetAttribute("type2", "raidtarget")
    button:SetAttribute("type3", "raidtarget")
    button:SetAttribute("action", "clear-all")
    button:SetAttribute("action1", "clear-all")
    button:SetAttribute("action2", "clear-all")
    button:SetAttribute("action3", "clear-all")
end

local function CreateMarkerButton(parent, index, previous)
    local button = CreateFrame("Button", "RexUI_RaidUtilityMarker" .. index, parent, "SecureActionButtonTemplate, BackdropTemplate")
    button:SetSize(22, 22)
    RegisterSecureMarkerClicks(button)
    StyleButton(button)
    button.tooltip = T("Klick: Zielmarker ") .. index .. "\n" .. T("Shift-Klick: Weltmarker ") .. index
    button.markerIndex = index
    ConfigureMarkerButton(button, index)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(MARKER_TEXTURE)
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    UpdateMarkerTexCoord(icon, index)
    button.icon = icon

    if previous then
        button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
    else
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
    end

    markerButtons[#markerButtons + 1] = button
    return button
end

local function CreateClearMarkerButton(parent, previous)
    local button = CreateFrame("Button", "RexUI_RaidUtilityMarkerClear", parent, "SecureActionButtonTemplate, BackdropTemplate")
    button:SetSize(22, 22)
    RegisterSecureMarkerClicks(button)
    StyleButton(button)
    button.tooltip = "Klick: alle Zielmarker entfernen\nShift-Klick: Weltmarker entfernen"
    ConfigureClearMarkerButton(button)
    button:SetPoint("LEFT", previous, "RIGHT", 4, 0)

    button.Text = button:CreateFontString(nil, "OVERLAY")
    button.Text:SetFont(FONT, 12, "OUTLINE")
    button.Text:SetPoint("CENTER")
    button.Text:SetText("x")

    clearMarkerButton = button
    return button
end

function RU:UpdateMarkerButtons()
    if InLockdown() then
        self.pendingMarkerUpdate = true
        return
    end

    for _, button in ipairs(markerButtons) do
        button:SetAlpha(1)
        button:Enable()
        if button.icon then
            button.icon:SetDesaturated(false)
            button.icon:SetAlpha(1)
        end
    end

    if clearMarkerButton then
        clearMarkerButton:SetAlpha(1)
        clearMarkerButton:Enable()
    end
end

function RU:UpdateMarkerClickMode()
    if InLockdown() then
        self.pendingMarkerClickModeUpdate = true
        return
    end

    for _, button in ipairs(markerButtons) do
        RegisterSecureMarkerClicks(button)
    end

    if clearMarkerButton then
        RegisterSecureMarkerClicks(clearMarkerButton)
    end
end

function RU:TogglePanel(open)
    if InLockdown() then
        self.pendingAvailability = true
        return
    end

    if not panel or not showButton then return end

    local shouldOpen = open
    if shouldOpen == nil then
        shouldOpen = not panel:IsShown()
    end

    panel:SetShown(shouldOpen)
    showButton:SetShown(not shouldOpen and self:InGroup())

    if shouldOpen then
        self:UpdateMarkerButtons()
    end
end

function RU:UpdateAvailability()
    if InLockdown() then
        self.pendingAvailability = true
        return
    end

    local cfg = self:GetConfig()
    local show = cfg.enabled ~= false and self:InGroup()
    local moverActive = self.moverActive == true and cfg.enabled ~= false

    if showButton then
        showButton:SetShown((moverActive or show) and not (panel and panel:IsShown()))
    end

    if panel and not show and not moverActive then
        panel:Hide()
    end

    local canLead = self:HasPermission()
    local isLeader = self:IsLeader()

    if self.ReadyButton then SetButtonEnabled(self.ReadyButton, canLead) end
    if self.RoleButton then SetButtonEnabled(self.RoleButton, canLead and InitiateRolePoll ~= nil) end
    if self.PullButton then SetButtonEnabled(self.PullButton, canLead and C_PartyInfo and C_PartyInfo.DoCountdown ~= nil) end
    if self.ConvertRaidButton then SetButtonEnabled(self.ConvertRaidButton, isLeader and C_PartyInfo and C_PartyInfo.ConvertToRaid ~= nil and not IsInRaid()) end
    if self.ConvertPartyButton then SetButtonEnabled(self.ConvertPartyButton, isLeader and C_PartyInfo and C_PartyInfo.ConvertToParty ~= nil and IsInRaid()) end
    if self.AssistCheck then
        self.AssistCheck:SetChecked(IsEveryoneAssistant and IsEveryoneAssistant() or false)
        self.AssistCheck:SetAlpha(isLeader and 1 or 0.45)
    end

    self:UpdateMarkerButtons()
end

function RU:Position()
    if InLockdown() then
        self.pendingPosition = true
        return
    end

    local cfg = self:GetConfig()
    if not showButton then return end

    showButton:ClearAllPoints()
    showButton:SetPoint(cfg.point or "TOP", UIParent, cfg.relPoint or cfg.point or "TOP", cfg.x or -400, cfg.y or 1)
end

function RU:SavePosition()
    if not showButton then return end
    local point, _, relPoint, x, y = showButton:GetPoint()
    if not point then return end
    self:Save("point", point)
    self:Save("relPoint", relPoint or point)
    self:Save("x", math.floor((x or 0) + 0.5))
    self:Save("y", math.floor((y or 0) + 0.5))
end

function RU:UpdateMover()
    if InLockdown() then
        self.pendingMoverUpdate = true
        return
    end

    if not mover or not showButton then return end

    mover:ClearAllPoints()
    -- Exakt deckungsgleich mit der sichtbaren Schlachtzugsteuerung.
    -- Keine eigene Groesse/Offsets: der Mover folgt dem ShowButton 1:1.
    mover:SetPoint("TOPLEFT", showButton, "TOPLEFT", 0, 0)
    mover:SetPoint("BOTTOMRIGHT", showButton, "BOTTOMRIGHT", 0, 0)
end

function RU:CreateMover()
    if mover or not showButton then return end

    mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    -- Der ShowButton liegt auf HIGH. Der Mover muss auf derselben Strata
    -- darueber liegen, sonst ist er beim globalen Entsperren nicht sichtbar.
    mover:SetFrameStrata(showButton:GetFrameStrata() or "HIGH")
    mover:SetFrameLevel((showButton:GetFrameLevel() or 0) + 50)
    mover:SetClampedToScreen(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:Hide()
    StyleFrame(mover, 0.2)
    mover:SetBackdropBorderColor(0.2, 0.6, 1, 0.95)

    mover.Label = mover:CreateFontString(nil, "OVERLAY")
    mover.Label:SetFont(FONT, 9, "OUTLINE")
    mover.Label:SetPoint("CENTER")
    mover.Label:SetText(T("Raid Utility"))

    mover:SetScript("OnDragStart", function()
        if InCombatLockdown and InCombatLockdown() then return end
        mover.dragged = true
        showButton:SetMovable(true)
        showButton:StartMoving()
        mover:SetScript("OnUpdate", function()
            RU:UpdateMover()
        end)
    end)

    mover:SetScript("OnDragStop", function()
        mover:SetScript("OnUpdate", nil)
        showButton:StopMovingOrSizing()
        RU:SavePosition()
        RU:UpdateMover()
    end)

    mover:SetScript("OnMouseUp", function()
        if mover.dragged then
            mover.dragged = false
            return
        end

        if RexUI.ConfigUI and RexUI.ConfigUI.Open then
            RexUI.ConfigUI:Open()
        end
    end)

    self.Mover = mover
    self:UpdateMover()
end

function RU:ShowMover()
    if not showButton then return end
    self.moverActive = true

    if InLockdown() then
        self.pendingMoverUpdate = true
        self.pendingAvailability = true
        return
    end

    self:CreateMover()
    self:Position()
    showButton:Show()
    if panel then panel:Hide() end
    self:UpdateMover()
    if mover then mover:Show() end
end

function RU:HideMover()
    self.moverActive = false

    if InLockdown() then
        self.pendingMoverUpdate = true
        self.pendingAvailability = true
        return
    end

    if mover then mover:Hide() end
    self:UpdateAvailability()
end

function RU:Create()
    if panel then return end

    showButton = CreateTextButton(UIParent, "RexUI_RaidUtilityShowButton", RAID_CONTROL or "Raid Control", 136, 22, function()
        RU:TogglePanel(true)
    end)
    showButton:SetFrameStrata("HIGH")
    showButton:SetMovable(true)
    showButton:SetClampedToScreen(true)
    showButton:RegisterForDrag("RightButton")
    showButton:SetScript("OnDragStart", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        self:StartMoving()
    end)
    showButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        RU:SavePosition()
    end)
    showButton.tooltip = "Linksklick: Raid Utility öffnen\nRechts ziehen: verschieben"

    panel = CreateFrame("Frame", "RexUI_RaidUtilityPanel", UIParent, "BackdropTemplate")
    panel:SetSize(250, 166)
    panel:SetFrameStrata("HIGH")
    panel:SetPoint("TOP", showButton, "BOTTOM", 0, -1)
    StyleFrame(panel, 0.9)
    panel:Hide()

    local markerHolder = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    markerHolder:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -6)
    markerHolder:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
    markerHolder:SetHeight(38)
    StyleFrame(markerHolder, 0.45)
    self.MarkerHolder = markerHolder

    local previous
    for i = 1, 8 do
        previous = CreateMarkerButton(markerHolder, i, previous)
    end
    CreateClearMarkerButton(markerHolder, previous)

    local close = CreateTextButton(panel, "RexUI_RaidUtilityCloseButton", CLOSE or "Close", 92, 22, function()
        RU:TogglePanel(false)
    end)
    close:SetPoint("BOTTOM", panel, "TOP", 0, 0)

    local rowY = -50
    local half = 116

    local raidMenu = CreateTextButton(panel, "RexUI_RaidUtilityRaidMenuButton", "Raid Menu", half, 22, function()
        if ToggleFriendsFrame then ToggleFriendsFrame(3) end
    end)
    raidMenu:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, rowY)

    self.ReadyButton = CreateTextButton(panel, "RexUI_RaidUtilityReadyButton", READY_CHECK or "Ready Check", half, 22, function(self)
        if not self.enabled then return end
        local readyCheck = C_PartyInfo and C_PartyInfo.DoReadyCheck or DoReadyCheck
        if readyCheck then readyCheck() end
    end)
    self.ReadyButton:SetPoint("LEFT", raidMenu, "RIGHT", 6, 0)

    self.RoleButton = CreateTextButton(panel, "RexUI_RaidUtilityRoleButton", ROLE_POLL or "Role Check", half, 22, function(self)
        if self.enabled and InitiateRolePoll then InitiateRolePoll() end
    end)
    self.RoleButton:SetPoint("TOPLEFT", raidMenu, "BOTTOMLEFT", 0, -6)

    self.PullButton = CreateTextButton(panel, "RexUI_RaidUtilityPullButton", "Pull 10", half, 22, function(self)
        if not self.enabled or not C_PartyInfo or not C_PartyInfo.DoCountdown then return end
        local cfg = RU:GetConfig()
        C_PartyInfo.DoCountdown(cfg.pullTimer or 10)
    end)
    self.PullButton:SetPoint("LEFT", self.RoleButton, "RIGHT", 6, 0)

    local tank = CreateTextButton(panel, "RexUI_RaidUtilityMainTankButton", MAINTANK or "Tank", half, 22, nil, "SecureActionButtonTemplate, BackdropTemplate")
    tank:SetAttribute("type", "maintank")
    tank:SetAttribute("unit", "target")
    tank:SetAttribute("action", "toggle")
    tank:SetPoint("TOPLEFT", self.RoleButton, "BOTTOMLEFT", 0, -6)
    tank.tooltip = "Setzt das aktuelle Ziel als Main Tank"

    local assist = CreateTextButton(panel, "RexUI_RaidUtilityMainAssistButton", MAINASSIST or "Assist", half, 22, nil, "SecureActionButtonTemplate, BackdropTemplate")
    assist:SetAttribute("type", "mainassist")
    assist:SetAttribute("unit", "target")
    assist:SetAttribute("action", "toggle")
    assist:SetPoint("LEFT", tank, "RIGHT", 6, 0)
    assist.tooltip = "Setzt das aktuelle Ziel als Main Assist"

    self.ConvertRaidButton = CreateTextButton(panel, "RexUI_RaidUtilityConvertRaidButton", RAID or "Raid", half, 22, function(self)
        if self.enabled and C_PartyInfo and C_PartyInfo.ConvertToRaid then C_PartyInfo.ConvertToRaid() end
    end)
    self.ConvertRaidButton:SetPoint("TOPLEFT", tank, "BOTTOMLEFT", 0, -6)

    self.ConvertPartyButton = CreateTextButton(panel, "RexUI_RaidUtilityConvertPartyButton", PARTY or "Party", half, 22, function(self)
        if self.enabled and C_PartyInfo and C_PartyInfo.ConvertToParty then C_PartyInfo.ConvertToParty() end
    end)
    self.ConvertPartyButton:SetPoint("LEFT", self.ConvertRaidButton, "RIGHT", 6, 0)

    local check = CreateFrame("CheckButton", "RexUI_RaidUtilityEveryoneAssist", panel, "UICheckButtonTemplate")
    check:SetSize(22, 22)
    check:SetPoint("TOPLEFT", self.ConvertRaidButton, "BOTTOMLEFT", -4, -7)
    local checkText = check.Text or check:CreateFontString(nil, "OVERLAY")
    checkText:SetPoint("LEFT", check, "RIGHT", 2, 0)
    checkText:SetText(ALL_ASSIST_LABEL_LONG or "Everyone Assist")
    checkText:SetFont(FONT, 10, "OUTLINE")
    check.Text = checkText
    check:SetScript("OnClick", function(self)
        if not RU:IsLeader() then
            self:SetChecked(IsEveryoneAssistant and IsEveryoneAssistant() or false)
            return
        end
        local setter = C_PartyInfo and C_PartyInfo.SetEveryoneIsAssistant or SetEveryoneIsAssistant
        if setter then setter(self:GetChecked()) end
    end)
    self.AssistCheck = check

    self:Position()
    self:CreateMover()
    self:UpdateAvailability()
end

function RU:Initialize()
    if self.initialized then return end
    self.initialized = true

    self:Create()
    self:HideBlizzard()

    SLASH_REXRAID1 = "/rexraid"
    SlashCmdList["REXRAID"] = function()
        if RU:InGroup() then
            RU:TogglePanel()
        elseif RexUI.PrintMessage then
            RexUI:PrintMessage("Raid Utility ist sichtbar, sobald du in einer Gruppe bist.")
        end
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("RAID_TARGET_UPDATE")
    eventFrame:RegisterEvent("CVAR_UPDATE")
    eventFrame:SetScript("OnEvent", function(_, event, addonName)
        if event == "ADDON_LOADED" and addonName == "Blizzard_CompactRaidFrames" then
            RU:HideBlizzard()
        elseif event == "PLAYER_ENTERING_WORLD" then
            RU:HideBlizzard()
        elseif event == "PLAYER_REGEN_ENABLED" then
            if RU.pendingBlizzardHide then
                RU.pendingBlizzardHide = nil
                RU:HideBlizzard()
            end

            if RU.pendingPosition then
                RU.pendingPosition = nil
                RU:Position()
            end

            if RU.pendingMoverUpdate then
                RU.pendingMoverUpdate = nil
                if RU.moverActive then
                    RU:ShowMover()
                else
                    RU:HideMover()
                end
            end

            if RU.pendingMarkerUpdate then
                RU.pendingMarkerUpdate = nil
                RU:UpdateMarkerButtons()
            end

            if RU.pendingMarkerClickModeUpdate then
                RU.pendingMarkerClickModeUpdate = nil
                RU:UpdateMarkerClickMode()
            end

            RU.pendingAvailability = nil
        elseif event == "PLAYER_TARGET_CHANGED" or event == "RAID_TARGET_UPDATE" then
            RU:UpdateMarkerButtons()
        elseif event == "CVAR_UPDATE" and addonName == "ActionButtonUseKeyDown" then
            RU:UpdateMarkerClickMode()
        end

        RU:UpdateAvailability()
    end)
end
