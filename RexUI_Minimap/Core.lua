local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI
if not RexUI then return end

RexUI.Minimap = RexUI.Minimap or {}
local M = RexUI.Minimap
RexUI:RegisterModule("Minimap", M)

local function T(text)
    return RexUI:LocalizeText(text)
end

M.DefaultConfig = {
    enabled = true,
    size = 160,
    borderSize = 1,
    showClock = true,
    showLocation = true,
    showDataBar = true,
    dataTextLayoutVersion = 4,
    dataTextLeft = "GUILD",
    dataTextCenter = "SYSTEM",
    dataTextRight = "BNET",
    dataBarBackdrop = true,
    dataBarBorder = true,
    dataBarPanelTransparency = false,
    bnetToastPoint = "TOPRIGHT",
    bnetToastX = -4,
    bnetToastY = -274,
    scrollZoom = true,
    hideTracking = false,
    hideCalendar = false,
    hideMail = false,
    queuePoint = "BOTTOMRIGHT",
    queueRelPoint = "BOTTOMRIGHT",
    queueX = -5,
    queueY = 25,
    queueScale = 1,
    queueManualPosition = false,
    point = "TOPRIGHT",
    relPoint = "TOPRIGHT",
    x = -10,
    y = -10,
}

local function copyConfig(defaults, saved)
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

local indicators = {}
local clockFrame, clockTicker, clockBg
local locationFrame
local dataBar, dataTicker
local dataButtons = {}
local dataEventFrame
local pendingApply = false
local queueContainer
local queueLayouting = false
local queueHookedButtons = setmetatable({}, { __mode = "k" })
local omniumLayouting = false
local omniumHookedButtons = setmetatable({}, { __mode = "k" })
local omniumContainer
local mailTicker
local LayoutIndicators
local FindOmniumButton
local IsOmniumUnlocked

function M:GetConfig()
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    return copyConfig(self.DefaultConfig, profile and profile.minimap)
end

function M:Save(key, value)
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    if not profile then return end
    profile.minimap = profile.minimap or {}
    profile.minimap[key] = value
end

local function PermaHide(frame)
    if not frame then return end
    frame:Hide()
    frame:SetAlpha(0)
    if frame._rexPermaHideHooked then return end
    frame._rexPermaHideHooked = true
    hooksecurefunc(frame, "Show", function(self)
        self:Hide()
        self:SetAlpha(0)
    end)
end

local function KillBlizzardDecorations()
    local cluster = _G.MinimapCluster
    if cluster then
        cluster:SetAlpha(0)
        cluster:EnableMouse(false)
        PermaHide(cluster)
        PermaHide(cluster.BorderTop)
        PermaHide(cluster.ZoneTextButton)
        PermaHide(cluster.InstanceDifficulty)
    end

    if _G.MinimapBackdrop then PermaHide(_G.MinimapBackdrop) end

    if _G.MinimapCompassTexture then PermaHide(_G.MinimapCompassTexture) end

    local minimap = _G.Minimap
    if minimap then
        PermaHide(minimap.ZoomIn)
        PermaHide(minimap.ZoomOut)
        if minimap.ZoomHitArea then PermaHide(minimap.ZoomHitArea) end
    end

    local mm = _G.Minimap
    if mm then
        mm:SetMaskTexture("Interface\\BUTTONS\\WHITE8X8")
        _G.GetMinimapShape = function() return "SQUARE" end
    end

    if _G.HybridMinimap then
        _G.HybridMinimap.MapCanvas:SetUseMaskTexture(false)
        _G.HybridMinimap.CircleMask:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        _G.HybridMinimap.MapCanvas:SetUseMaskTexture(true)
    end
end

local function HideBlizzardIndicators()
    local cluster = _G.MinimapCluster
    if not cluster then return end
    local indicator = cluster.IndicatorFrame
    if indicator then
        if indicator.MailFrame then
            indicator.MailFrame:SetAlpha(0)
            indicator.MailFrame:EnableMouse(false)
        end
        if indicator.CraftingOrderFrame then
            indicator.CraftingOrderFrame:SetAlpha(0)
            indicator.CraftingOrderFrame:EnableMouse(false)
        end
    end
end

local function ShowBlizzardIndicators()
    local cluster = _G.MinimapCluster
    if not cluster then return end
    local indicator = cluster.IndicatorFrame
    if indicator then
        if indicator.MailFrame then
            indicator.MailFrame:SetAlpha(1)
            indicator.MailFrame:EnableMouse(true)
        end
        if indicator.CraftingOrderFrame then
            indicator.CraftingOrderFrame:SetAlpha(1)
            indicator.CraftingOrderFrame:EnableMouse(true)
        end
    end
end

local function CreateIndicatorBtn(name, upAtlas, overAtlas, downAtlas, onClick)
    local btn = CreateFrame("Button", nil, _G.Minimap)
    btn:SetSize(22, 22)
    btn:SetFrameLevel(_G.Minimap:GetFrameLevel() + 20)
    btn:EnableMouse(true)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetColorTexture(0, 0, 0, 0.8)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)
    icon:SetAtlas(upAtlas)
    btn._icon = icon
    btn._upAtlas = upAtlas
    btn._overAtlas = overAtlas
    btn._downAtlas = downAtlas

    btn:SetScript("OnEnter", function(self)
        if self._overAtlas and self._icon then
            self._icon:SetAtlas(self._overAtlas)
        end
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            _G.GameTooltip:AddLine(T(self._tooltip or name))
            if self._tooltipLines then
                for _, line in ipairs(self._tooltipLines) do
                    _G.GameTooltip:AddLine(T(line), 0.8, 0.8, 0.8)
                end
            end
            _G.GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if self._upAtlas and self._icon then
            self._icon:SetAtlas(self._upAtlas)
        end
        if _G.GameTooltip then
            _G.GameTooltip:Hide()
        end
    end)
    btn:SetScript("OnMouseDown", function(self)
        if self._downAtlas and self._icon then
            self._icon:SetAtlas(self._downAtlas)
        end
    end)
    btn:SetScript("OnMouseUp", function(self)
        local over = self:IsMouseOver()
        local atlas = over and self._overAtlas or self._upAtlas
        if atlas and self._icon then
            self._icon:SetAtlas(atlas)
        end
    end)

    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    return btn
end

local function BuildIndicators()
    if indicators.calendar then return end

    local calDay = tonumber(date("%d")) or 1
    local calPrefix = "UI-HUD-Calendar-" .. calDay
    indicators.calendar = CreateIndicatorBtn("_gameTime",
        calPrefix .. "-Up",
        calPrefix .. "-Mouseover",
        calPrefix .. "-Down",
        function()
            if _G.ToggleCalendar then _G.ToggleCalendar() end
        end)
    indicators.calendar._tooltip = "Calendar"
    indicators.calendar._calDay = calDay

    indicators.mail = CreateIndicatorBtn("_mail",
        "UI-HUD-Minimap-Mail-Up",
        "UI-HUD-Minimap-Mail-Mouseover",
        nil, nil)
    indicators.mail._tooltip = _G.HAVE_MAIL or "New Mail"

end

local function HasPendingMail(cfg)
    if cfg and cfg.hideMail then return false end

    if M._forceMailVisible then return true end

    if _G.HasNewMail then
        local hasMail = _G.HasNewMail()
        if hasMail then return true end
    end

    if C_Mail and C_Mail.HasInboxMoney then
        local ok, hasMoney = pcall(C_Mail.HasInboxMoney)
        if ok and hasMoney then return true end
    end

    if _G.GetInboxNumItems then
        local ok, numItems = pcall(_G.GetInboxNumItems)
        if ok and numItems and numItems > 0 then return true end
    end

    if _G.GetLatestThreeSenders then
        local ok, sender1, sender2, sender3 = pcall(_G.GetLatestThreeSenders)
        if ok and (sender1 or sender2 or sender3) then return true end
    end

    local cluster = _G.MinimapCluster
    local mailFrame = cluster and cluster.IndicatorFrame and cluster.IndicatorFrame.MailFrame
    if mailFrame and mailFrame:IsShown() then return true end
    if _G.MiniMapMailFrame and _G.MiniMapMailFrame:IsShown() then return true end

    return false
end

local function PositionMailIndicator()
    local btn = indicators.mail
    local minimap = _G.Minimap
    if not btn or not minimap then return end

    local cfg = M:GetConfig()
    if cfg.hideMail then return end

    local sz = 22
    local y = -sz
    if not cfg.hideCalendar and indicators.calendar then
        y = y - sz
    end
    if FindOmniumButton() and IsOmniumUnlocked() then
        y = y - sz
    end

    btn:SetSize(sz, sz)
    btn:ClearAllPoints()
    btn:SetPoint("TOPRIGHT", minimap, "TOPLEFT", 0, y)
    btn:SetFrameLevel(minimap:GetFrameLevel() + 20)
end

local function SyncMailVisibility()
    if not indicators.mail then return end
    if HasPendingMail(M:GetConfig()) then
        PositionMailIndicator()
        indicators.mail._tooltip = _G.HAVE_MAIL or "Post"
        indicators.mail._tooltipLines = nil
        if _G.GetLatestThreeSenders then
            local ok, sender1, sender2, sender3 = pcall(_G.GetLatestThreeSenders)
            if ok then
                local lines = {}
                if _G.GetInboxNumItems then
                    local inboxOk, numItems = pcall(_G.GetInboxNumItems)
                    if inboxOk and numItems and numItems > 0 then
                        lines[#lines + 1] = string.format("%d im Briefkasten", numItems)
                    end
                end
                for _, sender in ipairs({ sender1, sender2, sender3 }) do
                    if sender and sender ~= "" then
                        lines[#lines + 1] = sender
                    end
                end
                if #lines > 0 then
                    indicators.mail._tooltipLines = lines
                end
            end
        end
        indicators.mail:Show()
    else
        indicators.mail._tooltipLines = nil
        indicators.mail:Hide()
    end
end

local function UpdateClock()
    if not clockFrame then return end
    local use24h = GetCVar("timeMgrUseMilitaryTime") == "1"
    local h, m = _G.GetGameTime()
    if use24h then
        clockFrame:SetText(format("%02d:%02d", h, m))
    else
        local ampm = h >= 12 and "PM" or "AM"
        h = h % 12
        if h == 0 then h = 12 end
        clockFrame:SetText(format("%d:%02d %s", h, m, ampm))
    end
end

local function UpdateLocation()
    if not locationFrame then return end
    if _G.InCombatLockdown() then return end
    local sub = _G.GetSubZoneText()
    local text = (sub and sub ~= "") and sub or (_G.GetZoneText() or "")
    locationFrame:SetText(text)
end

local function FindQueueButton()
    local qb = _G.QueueStatusButton or _G.QueueStatusMinimapButton or _G.MiniMapLFGFrame or _G.LFGMinimapFrame
    if qb then return qb end

    for _, parent in ipairs({ _G.UIParent, _G.Minimap, _G.MinimapCluster }) do
        if parent then
            for _, child in ipairs({ parent:GetChildren() }) do
                local cn = child:GetName() or ""
                if cn:match("QueueStatus") or cn:match("MatchmakingQueue") then
                    return child
                end
            end
        end
    end
end

local function EnsureQueueContainer(minimap, sz)
    if queueContainer then return queueContainer end

    queueContainer = CreateFrame("Frame", nil, _G.UIParent)
    queueContainer:SetSize(32, 32)
    queueContainer:SetFrameLevel(minimap:GetFrameLevel() + 20)
    queueContainer:SetMovable(true)
    queueContainer:EnableMouse(false)

    local bg = queueContainer:CreateTexture(nil, "BACKGROUND")
    bg:SetColorTexture(0, 0, 0, 0.8)
    bg:SetAllPoints(queueContainer)
    bg:Hide()
    queueContainer._rexBg = bg

    local mover = CreateFrame("Button", nil, queueContainer)
    mover:SetAllPoints(queueContainer)
    mover:SetFrameLevel(queueContainer:GetFrameLevel() + 50)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")

    mover.Bg = mover:CreateTexture(nil, "BACKGROUND")
    mover.Bg:SetColorTexture(0.2, 0.6, 1, 0.28)
    mover.Bg:SetAllPoints(mover)

    mover.Label = mover:CreateFontString(nil, "OVERLAY")
    mover.Label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    mover.Label:SetPoint("CENTER")
    mover.Label:SetText("Queue")

    mover:SetScript("OnDragStart", function(self)
        self.dragged = true
        queueContainer:StartMoving()
    end)

    mover:SetScript("OnDragStop", function(self)
        queueContainer:StopMovingOrSizing()
        local point, _, relPoint, x, y = queueContainer:GetPoint()
        if point then
            M:Save("queueManualPosition", true)
            M:Save("queuePoint", point)
            M:Save("queueRelPoint", relPoint or point)
            M:Save("queueX", math.floor((x or 0) + 0.5))
            M:Save("queueY", math.floor((y or 0) + 0.5))
        end
        M:UpdateQueue()
    end)

    mover:SetScript("OnMouseUp", function(self, button)
        if self.dragged then
            self.dragged = false
            return
        end
        if button == "RightButton" then
            M:Save("queueManualPosition", false)
            M:Save("queuePoint", "BOTTOMRIGHT")
            M:Save("queueRelPoint", "BOTTOMRIGHT")
            M:Save("queueX", -5)
            M:Save("queueY", 25)
            M:UpdateQueue()
            return
        end
        if RexUI.ConfigUI and RexUI.ConfigUI.Open then
            RexUI.ConfigUI:Open()
            if RexUI.ConfigUI.SetCategory then
                RexUI.ConfigUI:SetCategory("Minimap")
            end
        end
    end)

    mover:Hide()
    queueContainer._rexMover = mover

    return queueContainer
end

local function SyncQueueContainerVisibility(qb)
    if not queueContainer then return end

    local unlocked = RexUI.Unlocked == true
    local buttonShown = qb and qb.IsShown and qb:IsShown()
    queueContainer:SetShown(buttonShown or unlocked)

    if queueContainer._rexBg then
        queueContainer._rexBg:Hide()
    end

    if queueContainer._rexMover then
        queueContainer._rexMover:SetShown(unlocked)
    end
end

local function GetQueueScale(cfg)
    local scale = tonumber(cfg and cfg.queueScale) or 1
    if scale <= 0 then scale = 1 end
    return scale
end

local function PositionQueueContainer(cfg)
    local minimap = _G.Minimap
    if not minimap or not queueContainer then return end

    local scale = GetQueueScale(cfg)
    queueContainer:ClearAllPoints()
    if cfg and cfg.queueManualPosition then
        queueContainer:SetPoint(cfg.queuePoint or "BOTTOMRIGHT", _G.UIParent, cfg.queueRelPoint or "BOTTOMRIGHT", cfg.queueX or -5, cfg.queueY or 25)
    else
        local queueX = tonumber(cfg and cfg.queueX) or -5
        local queueY = tonumber(cfg and cfg.queueY) or 25
        if queueX < -40 or queueX > 40 then queueX = -5 end
        if queueY < -40 or queueY > 40 then queueY = 25 end
        queueContainer:SetPoint("BOTTOMRIGHT", minimap, "BOTTOMRIGHT", queueX, queueY)
    end
    queueContainer:SetSize(32 * scale, 32 * scale)
    if queueContainer._rexMover then
        queueContainer._rexMover:SetAllPoints(queueContainer)
        queueContainer._rexMover:SetFrameLevel(queueContainer:GetFrameLevel() + 50)
    end
end

local function ApplyQueueButtonLayout(qb, cfg)
    if not qb or not queueContainer then return end

    local scale = GetQueueScale(cfg)

    if qb:GetParent() ~= queueContainer then
        qb:SetParent(queueContainer)
    end
    if qb.SetIgnoreParentScale then
        qb:SetIgnoreParentScale(true)
    end
    qb:ClearAllPoints()
    qb:SetPoint("CENTER", queueContainer, "CENTER", 0, 0)
    if math.abs((qb:GetScale() or 1) - scale) > 0.001 then
        qb:SetScale(scale)
    end
    qb:SetFrameLevel(queueContainer:GetFrameLevel() + 1)
    qb:SetAlpha(1)
    qb:EnableMouse(true)
end

local function ShouldControlQueue()
    local cfg = M:GetConfig()
    return queueContainer and cfg.enabled ~= false
end

local function HookQueueButton(qb)
    if not qb or queueHookedButtons[qb] then return end
    queueHookedButtons[qb] = true

    qb:HookScript("OnShow", function(self)
        if not ShouldControlQueue() or queueLayouting then return end

        local minimap = _G.Minimap
        if not minimap then return end

        local cfg = M:GetConfig()
        queueLayouting = true
        EnsureQueueContainer(minimap, 22)
        PositionQueueContainer(cfg)
        ApplyQueueButtonLayout(self, cfg)
        SyncQueueContainerVisibility(self)
        queueLayouting = false
    end)

    qb:HookScript("OnHide", function(self)
        SyncQueueContainerVisibility(self)
    end)

    hooksecurefunc(qb, "SetParent", function(self, parent)
        if ShouldControlQueue() and parent ~= queueContainer then
            self:SetParent(queueContainer)
        end
    end)
    hooksecurefunc(qb, "SetPoint", function(self, _, anchor)
        if ShouldControlQueue() and anchor ~= queueContainer then
            self:ClearAllPoints()
            self:SetPoint("CENTER", queueContainer, "CENTER", 0, 0)
        end
    end)
    hooksecurefunc(qb, "SetScale", function(self, value)
        local scale = GetQueueScale(M:GetConfig())
        if ShouldControlQueue() and math.abs((value or 1) - scale) > 0.001 then
            self:SetScale(scale)
        end
    end)
end

FindOmniumButton = function()
    return _G.ExpansionLandingPageMinimapButton or _G.GarrisonLandingPageMinimapButton
end

IsOmniumUnlocked = function()
    local level = UnitLevel and UnitLevel("player")
    local effectiveLevel = UnitEffectiveLevel and UnitEffectiveLevel("player")

    level = math.max(tonumber(level) or 0, tonumber(effectiveLevel) or 0)
    return level >= 90
end

local function HideOmniumButton(btn)
    btn = btn or FindOmniumButton()

    if omniumContainer then
        omniumContainer:Hide()
    end

    if not btn then return end

    if btn:GetParent() == omniumContainer then
        pcall(btn.SetParent, btn, _G.MinimapCluster or _G.UIParent)
        pcall(btn.ClearAllPoints, btn)
    end

    pcall(btn.Hide, btn)
end

local function ReleaseOmniumButton(btn)
    btn = btn or FindOmniumButton()

    if omniumContainer then
        omniumContainer:Hide()
    end

    if not btn then return end

    if btn:GetParent() == omniumContainer then
        pcall(btn.SetParent, btn, _G.MinimapCluster or _G.UIParent)
        pcall(btn.ClearAllPoints, btn)
    end
end

local function ShouldControlOmnium()
    local cfg = M:GetConfig()
    return cfg.enabled ~= false and IsOmniumUnlocked()
end

local function IsOmniumReadyForRexUI(btn)
    if not btn or not ShouldControlOmnium() then
        return false
    end

    if GameRulesUtil and GameRulesUtil.ShouldShowExpansionLandingPageButton
    and not GameRulesUtil.ShouldShowExpansionLandingPageButton() then
        return false
    end

    if btn.IsShown and not btn:IsShown() then
        return false
    end

    return btn.title ~= nil and btn.description ~= nil
end

local function LayoutOmniumButton(btn, y, sz)
    local minimap = _G.Minimap
    if not btn or not minimap then return y end

    if not IsOmniumReadyForRexUI(btn) then
        if ShouldControlOmnium() then
            ReleaseOmniumButton(btn)
        else
            HideOmniumButton(btn)
        end
        return y
    end

    if _G.InCombatLockdown() then
        pendingApply = true
        return y - sz
    end

    omniumLayouting = true

    if not omniumContainer then
        omniumContainer = CreateFrame("Button", "RexUI_OmniumMinimapContainer", minimap, "BackdropTemplate")
        omniumContainer:SetSize(sz, sz)
        omniumContainer:SetFrameLevel(minimap:GetFrameLevel() + 20)
    end

    omniumContainer:SetParent(minimap)
    omniumContainer:ClearAllPoints()
    omniumContainer:SetPoint("TOPRIGHT", minimap, "TOPLEFT", 0, y)
    omniumContainer:SetSize(sz, sz)
    omniumContainer:SetFrameLevel(minimap:GetFrameLevel() + 20)
    omniumContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    omniumContainer:SetBackdropColor(0, 0, 0, 0.82)
    omniumContainer:SetBackdropBorderColor(0, 0, 0, 1)
    omniumContainer:SetAlpha(1)
    omniumContainer:Show()

    if btn:GetParent() ~= omniumContainer then
        btn:SetParent(omniumContainer)
    end
    if btn.SetIgnoreParentScale then
        btn:SetIgnoreParentScale(true)
    end

    btn:ClearAllPoints()
    btn:SetPoint("CENTER", omniumContainer, "CENTER", 0, 0)
    btn:SetSize(sz - 6, sz - 6)
    btn:SetScale(1)
    btn:SetAlpha(1)
    btn:SetFrameLevel(omniumContainer:GetFrameLevel() + 1)
    btn:EnableMouse(true)

    if btn.SetHitRectInsets then
        btn:SetHitRectInsets(0, 0, 0, 0)
    end

    if btn._rexBg then btn._rexBg:Hide() end

    for i = 1, btn:GetNumRegions() do
        local region = select(i, btn:GetRegions())
        if region and region ~= btn._rexBg and region.SetPoint then
            region:ClearAllPoints()
            region:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
            region:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        end
    end

    for i = 1, btn:GetNumChildren() do
        local child = select(i, btn:GetChildren())
        if child and child.SetPoint then
            child:ClearAllPoints()
            child:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
            child:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
            if child.SetScale then child:SetScale(1) end
        end
    end

    omniumLayouting = false
    return y - sz
end

local function HookOmniumButton(btn)
    if not btn or omniumHookedButtons[btn] then return end
    omniumHookedButtons[btn] = true

    btn:HookScript("OnShow", function(self)
        if omniumLayouting then return end
        if not IsOmniumReadyForRexUI(self) then
            if ShouldControlOmnium() then
                ReleaseOmniumButton(self)
            else
                HideOmniumButton(self)
            end
            return
        end
        LayoutIndicators(M:GetConfig())
    end)

    hooksecurefunc(btn, "SetParent", function(self)
        if omniumLayouting then return end
        if not IsOmniumReadyForRexUI(self) then
            if ShouldControlOmnium() then
                ReleaseOmniumButton(self)
            else
                HideOmniumButton(self)
            end
            return
        end
        LayoutIndicators(M:GetConfig())
    end)

    hooksecurefunc(btn, "SetPoint", function(self)
        if omniumLayouting then return end
        if not IsOmniumReadyForRexUI(self) then
            if ShouldControlOmnium() then
                ReleaseOmniumButton(self)
            else
                HideOmniumButton(self)
            end
            return
        end
        LayoutIndicators(M:GetConfig())
    end)
end

LayoutIndicators = function(cfg)
    local minimap = _G.Minimap
    local sz = 22

    if not cfg.hideTracking then
        local track = _G.MiniMapTracking or (_G.MinimapCluster and _G.MinimapCluster.Tracking)
        if track then
            track:SetParent(minimap)
            track:SetSize(sz, sz)
            track:ClearAllPoints()
            track:SetPoint("TOPRIGHT", minimap, "TOPLEFT", 0, 0)
            track:SetAlpha(1)
            track:EnableMouse(true)
            track:Show()

            if not track._rexBg then
                local bg = track:CreateTexture(nil, "BACKGROUND")
                bg:SetColorTexture(0, 0, 0, 0.8)
                track._rexBg = bg
            end
            track._rexBg:SetAllPoints(track)
            track._rexBg:Show()
        end
    else
        local track = _G.MiniMapTracking or (_G.MinimapCluster and _G.MinimapCluster.Tracking)
        if track then
            track:Hide()
            track:SetParent(_G.MinimapCluster or _G.UIParent)
        end
    end

    local y = -sz
    for _, key in ipairs({ "calendar", "omnium", "mail", "queue" }) do
        if key == "omnium" then
            local btn = FindOmniumButton()
            if btn and IsOmniumReadyForRexUI(btn) then
                HookOmniumButton(btn)
                y = LayoutOmniumButton(btn, y, sz)
            elseif ShouldControlOmnium() then
                ReleaseOmniumButton(btn)
            else
                HideOmniumButton(btn)
            end
        elseif key == "queue" then
            local qb = FindQueueButton()
            if qb and not queueLayouting then
                queueLayouting = true
                EnsureQueueContainer(minimap, sz)
                queueContainer:SetFrameLevel(minimap:GetFrameLevel() + 20)
                PositionQueueContainer(cfg)
                HookQueueButton(qb)
                ApplyQueueButtonLayout(qb, cfg)

                local statusFrame = _G.QueueStatusFrame
                if statusFrame and statusFrame.SetClampedToScreen then
                    statusFrame:SetClampedToScreen(true)
                end

                SyncQueueContainerVisibility(qb)
                y = y - sz
                queueLayouting = false
            elseif queueContainer then
                if RexUI.Unlocked then
                    PositionQueueContainer(cfg)
                    queueContainer:Show()
                    if queueContainer._rexBg then queueContainer._rexBg:Hide() end
                    if queueContainer._rexMover then queueContainer._rexMover:Show() end
                else
                    queueContainer:Hide()
                    if queueContainer._rexMover then
                        queueContainer._rexMover:Hide()
                    end
                end
            end
        else
            local btn = indicators[key]
            if not btn then
                y = y - sz
            elseif cfg["hide" .. key:gsub("^%l", string.upper)] or (key == "mail" and not HasPendingMail(cfg)) then
                btn:Hide()
                y = y - sz
            else
                btn:SetSize(sz, sz)
                btn:ClearAllPoints()
                btn:SetPoint("TOPRIGHT", minimap, "TOPLEFT", 0, y)
                y = y - sz
                btn:SetFrameLevel(minimap:GetFrameLevel() + 20)
                btn:Show()
            end
        end
    end
end

local function ApplyBorder(cfg)
    local minimap = _G.Minimap
    local borderSize = tonumber(cfg.borderSize) or 1
    if borderSize < 0 then borderSize = 0 end

    if not minimap.RexUIBorder then
        local border = CreateFrame("Frame", nil, minimap, "BackdropTemplate")
        minimap.RexUIBorder = border
        local bg = CreateFrame("Frame", nil, minimap, "BackdropTemplate")
        minimap.RexUIBg = bg
    end

    local sz = minimap:GetSize()

    local border = minimap.RexUIBorder
    border:ClearAllPoints()
    border:SetPoint("CENTER", minimap, "CENTER")
    border:SetSize(sz + borderSize * 2, sz + borderSize * 2)
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = math.max(1, borderSize),
    })
    border:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.95)
    border:SetFrameLevel(minimap:GetFrameLevel() + 5)
    border:SetShown(borderSize > 0)

    local bg = minimap.RexUIBg
    bg:ClearAllPoints()
    bg:SetPoint("CENTER", minimap, "CENTER")
    bg:SetSize(sz, sz)
    bg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    bg:SetBackdropColor(0, 0, 0, 1)
    bg:SetFrameLevel(minimap:GetFrameLevel() - 1)
    bg:EnableMouse(false)
    bg:Show()
end

local function GetDataTextValue(kind)
    if kind == "TIME" then
        local hour, minute = GameTime_GetGameTime()
        return format("%02d:%02d", hour or 0, minute or 0)
    elseif kind == "GOLD" then
        return format("%dg", floor((GetMoney() or 0) / 10000))
    elseif kind == "DURABILITY" then
        local lowest
        for slot = 1, 18 do
            local current, maximum = GetInventoryItemDurability(slot)
            if current and maximum and maximum > 0 then
                local percent = current / maximum * 100
                lowest = not lowest and percent or math.min(lowest, percent)
            end
        end
        if not lowest then return T("Rüstung") .. " --" end
        local color = lowest <= 25 and "|cffff4040" or (lowest <= 50 and "|cffffb020" or "|cff40ff70")
        return format(T("%sRüstung %d%%|r"), color, floor(lowest + 0.5))
    elseif kind == "SYSTEM" then
        local _, _, _, worldLatency = GetNetStats()
        return format("%d FPS  %d ms", floor(GetFramerate() + 0.5), worldLatency or 0)
    elseif kind == "BAGS" then
        local free = C_Container and C_Container.CalculateTotalNumberOfFreeBagSlots
            and C_Container.CalculateTotalNumberOfFreeBagSlots() or 0
        return format("Taschen %d", free or 0)
    elseif kind == "GUILD" then
        if not IsInGuild or not IsInGuild() then return T("Keine Gilde") end
        local total, online = 0, 0
        if GetNumGuildMembers then
            total, online = GetNumGuildMembers()
        end
        return format("Gilde %d/%d", tonumber(online) or 0, tonumber(total) or 0)
    elseif kind == "BNET" then
        local _, onlineBNet = 0, 0
        if BNGetNumFriends then _, onlineBNet = BNGetNumFriends() end
        local onlineWoW = C_FriendList and C_FriendList.GetNumOnlineFriends and C_FriendList.GetNumOnlineFriends() or 0
        return format("Freunde %d", (tonumber(onlineWoW) or 0) + (tonumber(onlineBNet) or 0))
    elseif kind == "COORDINATES" then
        local ok, coordinates = pcall(function()
            local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
            local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
            if not position then return nil end
            local x, y = position:GetXY()
            if canaccessvalue and (not canaccessvalue(x) or not canaccessvalue(y)) then return nil end
            return format("%.1f  %.1f", x * 100, y * 100)
        end)
        return ok and coordinates or "--  --"
    elseif kind == "LOCATION" then
        return GetMinimapZoneText() or ""
    end
    return ""
end

local function UpdateDataBar()
    if not dataBar or not dataBar:IsShown() then return end
    local cfg = M:GetConfig()
    local kinds = { cfg.dataTextLeft, cfg.dataTextRight }
    for index, button in ipairs(dataButtons) do
        button.kind = kinds[index] or "NONE"
        button.text:SetText(GetDataTextValue(button.kind))
        button.text:SetTextColor(0.92, 0.92, 0.92, 1)
    end
end

local function ApplyDataBar(cfg)
    local minimap = _G.Minimap
    if not minimap then return end

    -- DataTexts.lua ist die einzige Engine fuer die Leiste. Kein zweiter
    -- Fallback-Frame und kein konkurrierender Login-Ticker mehr.
    if M.DataTexts then
        M.DataTexts:Apply(minimap, cfg)
    end
end

local function ApplyClock(cfg)
    local minimap = _G.Minimap
    if cfg.showClock then
        if not clockBg then
            clockBg = CreateFrame("Button", nil, minimap, "BackdropTemplate")
            clockBg:SetSize(80, 16)
            clockBg:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
            clockBg:SetBackdropColor(0, 0, 0, 0.8)
            clockBg:SetFrameLevel(minimap:GetFrameLevel() + 25)
            clockBg:RegisterForClicks("AnyUp")
            clockBg:SetScript("OnClick", function()
                if _G.ToggleTimeManager then _G.ToggleTimeManager() end
            end)

            local fs = clockBg:CreateFontString(nil, "OVERLAY")
            fs:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            fs:SetPoint("CENTER", clockBg, "CENTER", 0, 0)
            fs:SetTextColor(1, 1, 1, 0.9)
            clockFrame = fs

            clockTicker = C_Timer.NewTicker(10, UpdateClock)

            local cvFrame = CreateFrame("Frame")
            cvFrame:RegisterEvent("CVAR_UPDATE")
            cvFrame:SetScript("OnEvent", function(_, _, cvar)
                if cvar == "timeMgrUseMilitaryTime" then UpdateClock() end
            end)
        end
        clockBg:ClearAllPoints()
        clockBg:SetPoint("TOP", minimap, "TOP", 0, -2)
        clockBg:Show()
        clockFrame:Show()
        UpdateClock()
    else
        if clockBg then clockBg:Hide() end
        if clockFrame then clockFrame:Hide() end
    end
end

local function ApplyLocation(cfg)
    local minimap = _G.Minimap
    if cfg.showLocation then
        if not locationFrame then
            locationFrame = minimap:CreateFontString(nil, "OVERLAY")
            locationFrame:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            locationFrame:SetTextColor(1, 1, 1, 0.9)
            locationFrame:SetJustifyH("CENTER")

            local zf = CreateFrame("Frame")
            zf:RegisterEvent("ZONE_CHANGED")
            zf:RegisterEvent("ZONE_CHANGED_INDOORS")
            zf:RegisterEvent("ZONE_CHANGED_NEW_AREA")
            zf:SetScript("OnEvent", UpdateLocation)
        end
        locationFrame:ClearAllPoints()
        locationFrame:SetPoint("BOTTOM", minimap, "BOTTOM", 0, 4)
        locationFrame:SetWidth(cfg.size - 20)
        locationFrame:Show()
        UpdateLocation()
    else
        if locationFrame then locationFrame:Hide() end
    end
end

local function SetupScrollZoom(cfg)
    local minimap = _G.Minimap
    if cfg.scrollZoom then
        minimap:EnableMouseWheel(true)
        if not M._zoomHooked then
            M._zoomHooked = true
            minimap:HookScript("OnMouseWheel", function(self, delta)
                local zoom = self:GetZoom()
                if delta > 0 then
                    zoom = math.min(zoom + 1, 5)
                else
                    zoom = math.max(zoom - 1, 0)
                end
                self:SetZoom(zoom)
            end)
        end
    else
        minimap:EnableMouseWheel(false)
    end
end

local function SetupMiddleClickMenu()
    local menuFrame, menuOpen

    local menuItems = {
        { text = _G.CHARACTER_BUTTON, microButton = "CharacterMicroButton" },
        { text = _G.SPELLBOOK_ABILITIES_BUTTON, microButton = "PlayerSpellsMicroButton" },
        { text = _G.TALENTS_BUTTON, microButton = "TalentMicroButton" },
        { text = "Taschen", fn = function()
            if _G.ToggleAllBags then
                _G.ToggleAllBags()
            elseif _G.OpenAllBags then
                _G.OpenAllBags()
            end
        end },
        { divider = true },
        { text = _G.SOCIAL_BUTTON, microButton = "QuickJoinToastButton" },
        { text = _G.GUILD, microButton = "GuildMicroButton" },
        { text = _G.LFG_TITLE, microButton = "LFDMicroButton" },
        { divider = true },
        { text = _G.ACHIEVEMENT_BUTTON, microButton = "AchievementMicroButton" },
        { text = _G.COLLECTIONS, microButton = "CollectionsMicroButton" },
        { text = _G.QUESTLOG_BUTTON, microButton = "QuestLogMicroButton" },
        { text = T("Abenteuerführer"), microButton = "EJMicroButton" },
        { divider = true },
        { text = _G.MAINMENU_BUTTON, fn = function() _G.ToggleFrame(_G.GameMenuFrame) end },
        { text = _G.HELP_BUTTON, microButton = "HelpMicroButton" },
    }

    local function SetMenuVisible(visible)
        if not menuFrame then return end
        menuOpen = visible
        menuFrame:ClearAllPoints()
        if visible then
            menuFrame:SetClampedToScreen(true)
            menuFrame:SetPoint("TOPRIGHT", _G.Minimap, "TOPLEFT", -4, 0)
        else
            menuFrame:SetClampedToScreen(false)
            menuFrame:SetPoint("TOPLEFT", _G.UIParent, "TOPRIGHT", 10000, 0)
        end
    end

    local function BuildMenu()
        if menuFrame then return end

        menuFrame = CreateFrame("Frame", nil, _G.UIParent, "BackdropTemplate")
        menuFrame:SetFrameStrata("TOOLTIP")
        menuFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        menuFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
        menuFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        menuFrame:EnableMouse(true)

        menuFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
        menuFrame:SetScript("OnEvent", function(self, event)
            if event == "GLOBAL_MOUSE_DOWN" and menuOpen then
                if not self:IsMouseOver() then SetMenuVisible(false) end
            end
        end)

        local y = -6
        local MENU_WIDTH = 160
        local BUTTON_H = 20
        local DIVIDER_H = 9

        for _, item in ipairs(menuItems) do
            if item.divider then
                local div = menuFrame:CreateTexture(nil, "ARTWORK")
                div:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 8, y - 4)
                div:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -8, y - 4)
                div:SetHeight(1)
                div:SetColorTexture(0.3, 0.3, 0.3, 0.6)
                y = y - DIVIDER_H
            elseif item.fn then
                local btn = CreateFrame("Button", nil, menuFrame)
                btn:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 1, y)
                btn:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -1, y)
                btn:SetHeight(BUTTON_H)

                local hl = btn:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetColorTexture(1, 1, 1, 0.08)

                local label = btn:CreateFontString(nil, "OVERLAY")
                label:SetFont("Fonts\\FRIZQT__.TTF", 11)
                label:SetShadowOffset(1, -1)
                label:SetShadowColor(0, 0, 0, 1)
                label:SetPoint("LEFT", btn, "LEFT", 10, 0)
                label:SetTextColor(0.9, 0.9, 0.9)
                label:SetText(T(item.text))

                local fn = item.fn
                btn:SetScript("OnClick", function()
                    SetMenuVisible(false)
                    fn()
                end)

                y = y - BUTTON_H
            else
                local microRef = item.microButton and _G[item.microButton]
                if not microRef then
                    y = y - BUTTON_H
                else
                    local btn = CreateFrame("Button", nil, menuFrame, "SecureActionButtonTemplate,SecureHandlerStateTemplate")
                    btn:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 1, y)
                    btn:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -1, y)
                    btn:SetHeight(BUTTON_H)

                    btn:SetAttribute("*clickbutton1", microRef)
                    btn:SetAttribute("useOnKeyDown", false)
                    btn:SetAttribute("*type1", "click")
                    btn:EnableMouse(true)
                    btn:RegisterForClicks("AnyUp")

                    local toc = select(4, GetBuildInfo()) or 0
                    if toc >= 16000 and toc < 20000 and RegisterAttributeDriver then
                        -- Forever cannot compile _onstate bodies; drive the click type directly.
                        RegisterAttributeDriver(btn, "*type1", "[nocombat] click")
                    else
                        RegisterStateDriver(btn, "comlock", "[combat] combat; safe")
                        btn:SetAttribute("_onstate-comlock", [[
                            if newstate == 'combat' then
                                self:SetAttribute('*type1', nil)
                                self:EnableMouse(false)
                            else
                                self:SetAttribute('*type1', 'click')
                                self:EnableMouse(true)
                            end
                        ]])
                    end

                    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
                    hl:SetAllPoints()
                    hl:SetColorTexture(1, 1, 1, 0.08)

                    local label = btn:CreateFontString(nil, "OVERLAY")
                    label:SetFont("Fonts\\FRIZQT__.TTF", 11)
                    label:SetShadowOffset(1, -1)
                    label:SetShadowColor(0, 0, 0, 1)
                    label:SetPoint("LEFT", btn, "LEFT", 10, 0)
                    label:SetTextColor(0.9, 0.9, 0.9)
                    label:SetText(T(item.text))

                    btn:HookScript("OnClick", function()
                        C_Timer.After(0, function() SetMenuVisible(false) end)
                    end)

                    y = y - BUTTON_H
                end
            end
        end

        menuFrame:SetSize(MENU_WIDTH, -y + 6)
        SetMenuVisible(false)
    end

    BuildMenu()

    if not M._middleClickHooked then
        M._middleClickHooked = true
        _G.Minimap:HookScript("OnMouseUp", function(_, btn)
            if btn == "MiddleButton" then
                if not _G.InCombatLockdown() then
                    SetMenuVisible(not menuOpen)
                end
            end
        end)
    end
end

local function SetupSyncHooks()
    if M._syncHooked then return end
    M._syncHooked = true

    local cluster = _G.MinimapCluster
    local indicator = cluster and cluster.IndicatorFrame
    local mailFrame = indicator and indicator.MailFrame

    if mailFrame then
        hooksecurefunc(mailFrame, "Show", function()
            M._forceMailVisible = true
            SyncMailVisibility()
        end)
        hooksecurefunc(mailFrame, "Hide", function()
            M._forceMailVisible = nil
            SyncMailVisibility()
        end)
    end

    if _G.MiniMapMailFrame then
        hooksecurefunc(_G.MiniMapMailFrame, "Show", function()
            M._forceMailVisible = true
            SyncMailVisibility()
        end)
        hooksecurefunc(_G.MiniMapMailFrame, "Hide", function()
            M._forceMailVisible = nil
            SyncMailVisibility()
        end)
    end

    local mailPoll = CreateFrame("Frame")
    mailPoll:RegisterEvent("PLAYER_ENTERING_WORLD")
    mailPoll:RegisterEvent("UPDATE_PENDING_MAIL")
    mailPoll:RegisterEvent("MAIL_INBOX_UPDATE")
    mailPoll:RegisterEvent("MAIL_SHOW")
    mailPoll:RegisterEvent("MAIL_CLOSED")
    mailPoll:RegisterEvent("PLAYER_MONEY")
    mailPoll:SetScript("OnEvent", function()
        SyncMailVisibility()
        if C_Timer and C_Timer.After then
            C_Timer.After(1, SyncMailVisibility)
            C_Timer.After(5, SyncMailVisibility)
        end
    end)

    if C_Timer and C_Timer.NewTicker and not mailTicker then
        mailTicker = C_Timer.NewTicker(10, SyncMailVisibility)
    end
end

-- ============================================================

function M:Apply(cfg)
    if _G.InCombatLockdown() then
        pendingApply = true
        return
    end

    cfg = cfg or self:GetConfig()
    local minimap = _G.Minimap
    if not minimap then return end

    minimap:SetParent(_G.UIParent)
    minimap:SetFrameStrata("LOW")
    minimap:SetFrameLevel(10)

    if minimap.SetFixedFrameStrata then minimap:SetFixedFrameStrata(true) end
    if minimap.SetFixedFrameLevel then minimap:SetFixedFrameLevel(true) end

    local sz = cfg.size or 160
    local scale = sz / 160
    minimap:SetSize(160, 160)
    minimap:SetScale(scale)

    minimap:ClearAllPoints()
    minimap:SetPoint(cfg.point or "TOPRIGHT", _G.UIParent, cfg.relPoint or "TOPRIGHT", cfg.x or -10, cfg.y or -10)

    KillBlizzardDecorations()

    if _G.HybridMinimap and _G.HybridMinimap.CircleMask then
        _G.HybridMinimap.CircleMask:SetAllPoints(_G.HybridMinimap)
    end

    ApplyBorder(cfg)
    BuildIndicators()

    local addonComp = _G.AddonCompartmentFrame
    if addonComp then
        addonComp:SetParent(minimap)
        addonComp:ClearAllPoints()
        addonComp:SetPoint("TOPRIGHT", minimap, "TOPRIGHT", -2, -2)
        addonComp:SetFrameLevel(minimap:GetFrameLevel() + 15)
        addonComp:Show()
    end

    if not M._queueHooked then
        M._queueHooked = true
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("ADDON_LOADED")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("LFG_UPDATE")
        eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
        eventFrame:RegisterEvent("LFG_PROPOSAL_SHOW")
        eventFrame:RegisterEvent("LFG_PROPOSAL_FAILED")
        eventFrame:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE")
        eventFrame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
        eventFrame:SetScript("OnEvent", function(_, event, arg1)
            if (event == "ADDON_LOADED" and (arg1 == "Blizzard_QueueStatusFrame" or arg1 == "Blizzard_MatchmakingQueueDisplay")) or event ~= "ADDON_LOADED" then
                local qb = FindQueueButton()
                if qb then
                    LayoutIndicators(M:GetConfig())
                end
            end
        end)
    end

    if not M._omniumHooked then
        M._omniumHooked = true
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("ADDON_LOADED")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
        eventFrame:SetScript("OnEvent", function()
            local function refresh()
                local btn = FindOmniumButton()
                if btn and IsOmniumReadyForRexUI(btn) then
                    LayoutIndicators(M:GetConfig())
                elseif ShouldControlOmnium() then
                    ReleaseOmniumButton(btn)
                else
                    HideOmniumButton(btn)
                end
            end

            refresh()
            C_Timer.After(0.2, refresh)
            C_Timer.After(1, refresh)
            C_Timer.After(3, refresh)
        end)

        if _G.GarrisonLandingPageMinimapButton_UpdateIcon then
            hooksecurefunc("GarrisonLandingPageMinimapButton_UpdateIcon", function()
                local btn = FindOmniumButton()
                if btn and IsOmniumReadyForRexUI(btn) then
                    LayoutIndicators(M:GetConfig())
                elseif ShouldControlOmnium() then
                    ReleaseOmniumButton(btn)
                else
                    HideOmniumButton(btn)
                end
            end)
        elseif _G.ExpansionLandingPageMinimapButton and _G.ExpansionLandingPageMinimapButton.UpdateIcon then
            hooksecurefunc(_G.ExpansionLandingPageMinimapButton, "UpdateIcon", function()
                local btn = FindOmniumButton()
                if btn and IsOmniumReadyForRexUI(btn) then
                    LayoutIndicators(M:GetConfig())
                elseif ShouldControlOmnium() then
                    ReleaseOmniumButton(btn)
                else
                    HideOmniumButton(btn)
                end
            end)
        end
    end

    -- Hook QueueStatusFrame_Update to catch every queue status change
    if not M._queueUpdateHooked and _G.QueueStatusFrame_Update then
        M._queueUpdateHooked = true
        hooksecurefunc("QueueStatusFrame_Update", function()
            if not ShouldControlQueue() then return end
            local qb = FindQueueButton()
            if qb then
                LayoutIndicators(M:GetConfig())
            end
        end)
    end

    -- Catch when LFG browser opens (manual search)
    for _, name in ipairs({"LFGListFrame", "LFGParentFrame", "PVEFrame"}) do
        local f = _G[name]
        if f and not f._rexShowHooked then
            f._rexShowHooked = true
            f:HookScript("OnShow", function()
                local qb = FindQueueButton()
                if qb then
                    LayoutIndicators(M:GetConfig())
                end
            end)
        end
    end
    
    HideBlizzardIndicators()
    LayoutIndicators(cfg)
    ApplyClock(cfg)
    ApplyLocation(cfg)
    ApplyDataBar(cfg)
    SetupScrollZoom(cfg)
    SetupMiddleClickMenu()
    SetupSyncHooks()
    SyncMailVisibility()
end

function M:RestoreBlizzard()
    local minimap = _G.Minimap
    if not minimap then return end

    minimap:SetParent(_G.MinimapCluster or _G.UIParent)
    minimap:SetFrameStrata("MEDIUM")
    minimap:SetFrameLevel(0)

    if minimap.SetFixedFrameStrata then minimap:SetFixedFrameStrata(false) end
    if minimap.SetFixedFrameLevel then minimap:SetFixedFrameLevel(false) end

    if _G.MinimapCluster then
        _G.MinimapCluster:SetAlpha(1)
        _G.MinimapCluster:EnableMouse(true)
        if _G.MinimapCluster.BorderTop then _G.MinimapCluster.BorderTop:Show() end
        if _G.MinimapCluster.ZoneTextButton then _G.MinimapCluster.ZoneTextButton:Show() end
    end

    local addonComp = _G.AddonCompartmentFrame
    if addonComp then
        addonComp:SetParent(_G.MinimapCluster or _G.UIParent)
    end

    local track = _G.MiniMapTracking or (_G.MinimapCluster and _G.MinimapCluster.Tracking)
    if track then
        if track._rexBg then track._rexBg:Hide() end
        track:SetParent(_G.MinimapCluster or _G.UIParent)
        track:SetAlpha(1)
        track:EnableMouse(true)
    end

    local qb = FindQueueButton()
    if qb then
        if queueContainer and queueContainer._rexBg then queueContainer._rexBg:Hide() end
        qb:SetParent(_G.MinimapCluster or _G.UIParent)
        qb._rexQueueAnchored = nil
        qb:SetScale(1)
        qb:SetAlpha(1)
        qb:EnableMouse(true)
    end

    local omnium = FindOmniumButton()
    if omnium then
        if IsOmniumUnlocked() then
            ReleaseOmniumButton(omnium)
            omnium:SetScale(1)
            omnium:SetAlpha(1)
            omnium:EnableMouse(true)
        else
            HideOmniumButton(omnium)
        end
    end
    if omniumContainer then
        omniumContainer:Hide()
    end
    if queueContainer then
        if queueContainer._rexMover then queueContainer._rexMover:Hide() end
        queueContainer:Hide()
    end

    if _G.MinimapBackdrop then _G.MinimapBackdrop:Show(); _G.MinimapBackdrop:SetAlpha(1) end
    if _G.MinimapCompassTexture then _G.MinimapCompassTexture:Show(); _G.MinimapCompassTexture:SetAlpha(1) end

    if minimap.ZoomIn then minimap.ZoomIn:Show(); minimap.ZoomIn:SetAlpha(1) end
    if minimap.ZoomOut then minimap.ZoomOut:Show(); minimap.ZoomOut:SetAlpha(1) end
    if minimap.ZoomHitArea then minimap.ZoomHitArea:Show(); minimap.ZoomHitArea:SetAlpha(1) end

    ShowBlizzardIndicators()

    for _, btn in pairs(indicators) do
        if btn then btn:Hide() end
    end

    if clockBg then clockBg:Hide() end
    if locationFrame then locationFrame:Hide() end
    if dataBar then dataBar:Hide() end
    if M.DataTexts then M.DataTexts:Hide() end
    if clockTicker then clockTicker:Cancel(); clockTicker = nil end
    if dataTicker then dataTicker:Cancel(); dataTicker = nil end

    minimap:SetMaskTexture("Interface\\MINIMAP\\UI-Minimap-Background")
    _G.GetMinimapShape = nil

    if _G.HybridMinimap then
        _G.HybridMinimap.MapCanvas:SetUseMaskTexture(false)
        _G.HybridMinimap.CircleMask:SetTexture("Interface\\MINIMAP\\UI-Minimap-Background")
        _G.HybridMinimap.MapCanvas:SetUseMaskTexture(true)
    end

    minimap:EnableMouseWheel(false)
end

function M:PositionBNetToast()
    local toast = _G.BNToastFrame
    local mover = self.BNetMover
    if not toast or not mover then return end

    local point = mover.anchorPoint or "TOPRIGHT"
    toast._rexPositioning = true
    toast:ClearAllPoints()
    toast:SetPoint(point, mover, point, 0, 0)
    toast._rexPositioning = nil
end

function M:CreateBNetMover()
    local toast = _G.BNToastFrame
    if not toast then return end

    if self.BNetMover then
        local width, height = toast:GetSize()
        self.BNetMover:SetSize(width > 0 and width or 250, height > 0 and height or 70)
        self:PositionBNetToast()
        return
    end

    local cfg = self:GetConfig()
    local mover = CreateFrame("Frame", "RexUI_BNETMover", UIParent, "BackdropTemplate")
    local width, height = toast:GetSize()
    mover:SetSize(width > 0 and width or 250, height > 0 and height or 70)
    mover:SetPoint(cfg.bnetToastPoint or "TOPRIGHT", UIParent, cfg.bnetToastPoint or "TOPRIGHT", cfg.bnetToastX or -4, cfg.bnetToastY or -274)
    mover:SetFrameStrata("DIALOG")
    mover:SetFrameLevel(100)
    mover:SetClampedToScreen(true)
    mover:SetMovable(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    mover:SetBackdropColor(0.2, 0.6, 1, 0.20)
    mover:SetBackdropBorderColor(0.2, 0.6, 1, 0.90)

    mover.Label = mover:CreateFontString(nil, "OVERLAY")
    mover.Label:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    mover.Label:SetPoint("CENTER")
    mover.Label:SetText(T("Battle.net-Popups"))

    mover:SetScript("OnDragStart", function(self)
        self.dragged = true
        self:StartMoving()
    end)
    mover:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        local centerX, centerY = self:GetCenter()
        local screenRight, screenTop = UIParent:GetRight(), UIParent:GetTop()
        local point
        if centerY > screenTop * 0.5 then
            point = centerX > screenRight * 0.5 and "TOPRIGHT" or "TOPLEFT"
        else
            point = centerX > screenRight * 0.5 and "BOTTOMRIGHT" or "BOTTOMLEFT"
        end

        local x, y
        if point == "TOPRIGHT" then
            x, y = self:GetRight() - screenRight, self:GetTop() - screenTop
        elseif point == "TOPLEFT" then
            x, y = self:GetLeft(), self:GetTop() - screenTop
        elseif point == "BOTTOMRIGHT" then
            x, y = self:GetRight() - screenRight, self:GetBottom()
        else
            x, y = self:GetLeft(), self:GetBottom()
        end

        self.anchorPoint = point
        self:ClearAllPoints()
        self:SetPoint(point, UIParent, point, x, y)
        M:Save("bnetToastPoint", point)
        M:Save("bnetToastX", math.floor(x + 0.5))
        M:Save("bnetToastY", math.floor(y + 0.5))
        M:PositionBNetToast()
    end)
    mover:SetScript("OnMouseUp", function(self)
        if self.dragged then self.dragged = false return end
    end)

    mover.anchorPoint = cfg.bnetToastPoint or "TOPRIGHT"
    mover:Hide()
    self.BNetMover = mover
    self:PositionBNetToast()

    if not toast._rexMoverHooked then
        toast._rexMoverHooked = true
        hooksecurefunc(toast, "SetPoint", function(frame, _, relativeTo)
            if not frame._rexPositioning and relativeTo ~= mover then
                M:PositionBNetToast()
            end
        end)
    end
end

function M:CreateMover()
    self:CreateBNetMover()
    if self.Mover then
        local sz = _G.Minimap:GetSize()
        self.Mover:SetSize(sz, sz)
        return
    end

    local minimap = _G.Minimap
    if not minimap then return end

    local mover = CreateFrame("Frame", nil, minimap)
    mover:SetAllPoints(minimap)
    mover:SetFrameLevel(minimap:GetFrameLevel() + 50)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")

    mover.Bg = mover:CreateTexture(nil, "BACKGROUND")
    mover.Bg:SetColorTexture(0.2, 0.6, 1, 0.2)
    mover.Bg:SetAllPoints(mover)

    mover.Label = mover:CreateFontString(nil, "OVERLAY")
    mover.Label:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    mover.Label:SetPoint("CENTER")
    mover.Label:SetText("Minimap")

    mover:SetScript("OnDragStart", function()
        mover.dragged = true
        minimap:SetMovable(true)
        minimap:StartMoving()
    end)

    mover:SetScript("OnDragStop", function()
        minimap:StopMovingOrSizing()
        local point, _, relPoint, x, y = minimap:GetPoint()
        if point then
            M:Save("point", point)
            M:Save("relPoint", relPoint or point)
            M:Save("x", math.floor((x or 0) + 0.5))
            M:Save("y", math.floor((y or 0) + 0.5))
        end
    end)

    mover:SetScript("OnMouseUp", function()
        if mover.dragged then
            mover.dragged = false
            return
        end
        if RexUI.ConfigUI and RexUI.ConfigUI.Open then
            RexUI.ConfigUI:Open()
            if RexUI.ConfigUI.SetCategory then
                RexUI.ConfigUI:SetCategory("Minimap")
            end
        end
    end)

    mover:Hide()
    self.Mover = mover
end

function M:ShowMover()
    self:CreateBNetMover()
    if self.Mover then self.Mover:Show() end
    if self.BNetMover then self.BNetMover:Show() end
    if self.DataTexts and self.DataTexts.ShowMover then
        self.DataTexts:ShowMover()
    end
    local cfg = self:GetConfig()
    local minimap = _G.Minimap
    if minimap then
        EnsureQueueContainer(minimap, 22)
        PositionQueueContainer(cfg)
        queueContainer:Show()
        if queueContainer._rexBg then queueContainer._rexBg:Hide() end
        if queueContainer._rexMover then queueContainer._rexMover:Show() end
    end
end

function M:HideMover()
    if self.Mover then self.Mover:Hide() end
    if self.BNetMover then self.BNetMover:Hide() end
    if self.DataTexts and self.DataTexts.HideMover then
        self.DataTexts:HideMover()
    end
    if queueContainer and queueContainer._rexMover then
        queueContainer._rexMover:Hide()
    end
    SyncQueueContainerVisibility(FindQueueButton())
end

function M:UpdateQueue()
    if _G.InCombatLockdown() then
        pendingApply = true
        return
    end

    local cfg = self:GetConfig()
    if cfg.enabled == false or not _G.Minimap then return end
    LayoutIndicators(cfg)
    SyncMailVisibility()
end

function M:Update()
    local cfg = self:GetConfig()
    local minimap = _G.Minimap
    if not minimap then return end

    if cfg.enabled == false then
        self:RestoreBlizzard()
        self:HideMover()
        return
    end

    self:Apply(cfg)
    self:CreateMover()

    if RexUI.Unlocked then
        self:ShowMover()
    end
end

function M:Initialize()
    local minimap = _G.Minimap
    if not minimap then return end

    local cfg = self:GetConfig()

    if cfg.enabled ~= false then
        self:Apply(cfg)
        self:CreateMover()
    end

    local combatFrame = CreateFrame("Frame")
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    combatFrame:SetScript("OnEvent", function()
        if pendingApply then
            pendingApply = false
            self:Update()
        end
    end)
end

-- RexUI:Initialize() initialisiert registrierte Module bereits bei
-- PLAYER_LOGIN. Ein zweiter Minimap-Initialisierer führte zu konkurrierenden
-- Datentext-Aufbauten und wurde deshalb entfernt.
