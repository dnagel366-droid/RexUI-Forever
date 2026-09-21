-- ============================================================
-- RexUI_StatusBars - Experience and watched reputation bar
-- ============================================================

local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI
if not RexUI then return end

RexUI.StatusBars = RexUI.StatusBars or {}
local SB = RexUI.StatusBars
RexUI:RegisterModule("StatusBars", SB)

local function T(text)
    return RexUI:LocalizeText(text)
end

local FONT = "Fonts\\FRIZQT__.TTF"
local TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local WHITE = "Interface\\Buttons\\WHITE8X8"

SB.DefaultConfig = {
    enabled = true,
    xpEnabled = false,
    showReputationAtMax = true,
    width = 420,
    height = 10,
    point = "CENTER",
    relPoint = "CENTER",
    x = 0,
    y = -305,
    scale = 1,
    alpha = 1,
    showTextOnMouseover = true,
}

local function GetCharacterConfig()
    if type(RexUICharDB) ~= "table" then
        RexUICharDB = {}
    end

    RexUICharDB.statusbars = RexUICharDB.statusbars or {}
    return RexUICharDB.statusbars
end

function SB:IsXPEnabled()
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    if profile and profile.statusbars and profile.statusbars.xpEnabled ~= nil then
        return profile.statusbars.xpEnabled == true
    end
    return GetCharacterConfig().xpEnabled == true
end

function SB:SetXPEnabled(enabled)
    enabled = enabled == true
    GetCharacterConfig().xpEnabled = enabled
    local function write(profile)
        if type(profile) ~= "table" then
            return
        end
        profile.statusbars = profile.statusbars or {}
        profile.statusbars.xpEnabled = enabled
    end
    write(RexUI.GetProfile and RexUI:GetProfile())
    if RexUIDB and type(RexUIDB.profiles) == "table" then
        local name = RexUI.GetCurrentProfile and RexUI:GetCurrentProfile()
        if name then
            write(RexUIDB.profiles[name])
        end
    end
end

function SB:SyncToProfile(profile)
    profile = profile or (RexUI.GetProfile and RexUI:GetProfile())
    if type(profile) ~= "table" then
        return
    end
    profile.statusbars = profile.statusbars or {}
    local current = RexUI.GetProfile and RexUI:GetProfile()
    if current == profile or (RexUI.GetCurrentProfile and RexUIDB and RexUIDB.profiles and RexUIDB.profiles[RexUI:GetCurrentProfile()] == profile) then
        -- Live toggle wins. Covers older CharDB-only sessions and the config checkbox.
        profile.statusbars.xpEnabled = profile.statusbars.xpEnabled == true
            or GetCharacterConfig().xpEnabled == true
    elseif profile.statusbars.xpEnabled == nil then
        profile.statusbars.xpEnabled = false
    end
end

function SB:ApplyProfile()
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    local enabled = profile and profile.statusbars and profile.statusbars.xpEnabled == true
    self:SetXPEnabled(enabled)
    if self.Update then
        self:Update()
    end
end

local REP_COLORS = {
    [1] = { 0.80, 0.12, 0.12 },
    [2] = { 0.80, 0.27, 0.12 },
    [3] = { 0.75, 0.27, 0.00 },
    [4] = { 0.90, 0.75, 0.18 },
    [5] = { 0.10, 0.65, 0.20 },
    [6] = { 0.00, 0.55, 0.85 },
    [7] = { 0.55, 0.25, 0.85 },
    [8] = { 0.85, 0.45, 0.95 },
}

local function copyConfig(defaults, saved)
    local cfg = {}
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            cfg[key] = copyConfig(value, saved and type(saved[key]) == "table" and saved[key] or nil)
        elseif saved and saved[key] ~= nil then
            cfg[key] = saved[key]
        else
            cfg[key] = value
        end
    end
    if type(saved) == "table" then
        for key, value in pairs(saved) do
            if cfg[key] == nil then cfg[key] = value end
        end
    end
    return cfg
end

local function clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    return math.max(minValue, math.min(maxValue, value))
end

local function formatNumber(value)
    value = tonumber(value) or 0
    if value >= 1000000 then
        return string.format("%.1fm", value / 1000000)
    elseif value >= 10000 then
        return string.format("%.1fk", value / 1000)
    end
    return tostring(math.floor(value + 0.5))
end

local function percent(value, maxValue)
    if not maxValue or maxValue <= 0 then return 0 end
    return math.floor((value / maxValue) * 1000 + 0.5) / 10
end

function SB:GetConfig()
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    local cfg = copyConfig(self.DefaultConfig, profile and profile.statusbars)

    cfg.enabled = true
    cfg.xpEnabled = self:IsXPEnabled()
    return cfg
end

function SB:Save(key, value)
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    if not profile then return end

    profile.statusbars = profile.statusbars or {}
    profile.statusbars[key] = value
end

local function GetXPData()
    if not UnitXP or not UnitXPMax then return nil end

    local maxValue = UnitXPMax("player") or 0
    if maxValue <= 0 then return nil end

    local value = UnitXP("player") or 0
    local rested = GetXPExhaustion and GetXPExhaustion() or 0
    local level = UnitLevel and UnitLevel("player") or nil

    return {
        kind = "xp",
        label = level and ("Level " .. level) or T("Erfahrung"),
        value = value,
        minValue = 0,
        maxValue = maxValue,
        rested = rested or 0,
        color = { 0.55, 0.20, 0.95 },
        restedColor = { 0.20, 0.48, 1.00, 0.55 },
        text = string.format("XP: %s / %s (%s%%)", formatNumber(value), formatNumber(maxValue), percent(value, maxValue)),
        tooltip = string.format(T("Erfahrung: %s / %s (%s%%)"), formatNumber(value), formatNumber(maxValue), percent(value, maxValue)),
    }
end

local function GetWatchedFactionData()
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local data = C_Reputation.GetWatchedFactionData()
        if data and data.name then
            local minValue = data.currentReactionThreshold or data.reactionThreshold or 0
            local maxValue = data.nextReactionThreshold or 0
            local value = data.currentStanding or 0

            if maxValue > minValue then
                local barValue = value - minValue
                local barMax = maxValue - minValue
                local color = REP_COLORS[data.reaction or data.standingID or 4] or REP_COLORS[4]

                return {
                    kind = "reputation",
                    label = data.name,
                    value = barValue,
                    minValue = 0,
                    maxValue = barMax,
                    color = color,
                    text = string.format("%s: %s / %s (%s%%)", data.name, formatNumber(barValue), formatNumber(barMax), percent(barValue, barMax)),
                    tooltip = string.format("%s: %s / %s (%s%%)", data.name, formatNumber(barValue), formatNumber(barMax), percent(barValue, barMax)),
                }
            end
        end
    end

    if GetWatchedFactionInfo then
        local name, standing, minValue, maxValue, value = GetWatchedFactionInfo()
        if name and maxValue and minValue and maxValue > minValue then
            local barValue = (value or 0) - minValue
            local barMax = maxValue - minValue
            local color = REP_COLORS[standing or 4] or REP_COLORS[4]

            return {
                kind = "reputation",
                label = name,
                value = barValue,
                minValue = 0,
                maxValue = barMax,
                color = color,
                text = string.format("%s: %s / %s (%s%%)", name, formatNumber(barValue), formatNumber(barMax), percent(barValue, barMax)),
                tooltip = string.format("%s: %s / %s (%s%%)", name, formatNumber(barValue), formatNumber(barMax), percent(barValue, barMax)),
            }
        end
    end

    return nil
end

function SB:GetDisplayData()
    local cfg = self:GetConfig()
    if cfg.enabled == false then return nil end

    local xpData = cfg.xpEnabled ~= false and GetXPData() or nil
    if xpData then return xpData end

    if cfg.showReputationAtMax ~= false then
        return GetWatchedFactionData()
    end

    return nil
end

function SB:CreateBar()
    if self.Bar then return end

    local bar = CreateFrame("StatusBar", "RexUIExperienceBar", UIParent, "BackdropTemplate")
    bar:SetStatusBarTexture(TEXTURE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetFrameStrata("MEDIUM")
    bar:EnableMouse(true)

    bar:SetBackdrop({
        bgFile = WHITE,
        edgeFile = WHITE,
        edgeSize = RexUI.PixelBorder and RexUI:PixelBorder(1) or 1,
    })
    bar:SetBackdropColor(0.025, 0.025, 0.03, 0.92)
    bar:SetBackdropBorderColor(RexUI:GetColor("border"))

    bar.Rested = CreateFrame("StatusBar", nil, bar)
    bar.Rested:SetAllPoints(bar)
    bar.Rested:SetStatusBarTexture(TEXTURE)
    bar.Rested:SetMinMaxValues(0, 1)
    bar.Rested:SetValue(0)
    bar.Rested:SetFrameLevel(bar:GetFrameLevel() + 1)

    bar:SetFrameLevel(bar.Rested:GetFrameLevel() + 1)

    bar.Spark = bar:CreateTexture(nil, "OVERLAY")
    bar.Spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    bar.Spark:SetBlendMode("ADD")
    bar.Spark:SetAlpha(0.75)

    bar.Text = bar:CreateFontString(nil, "OVERLAY")
    bar.Text:SetFont(FONT, 10, "OUTLINE")
    bar.Text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar.Text:SetTextColor(RexUI:GetColor("text"))

    bar:SetScript("OnEnter", function(self)
        if SB:GetConfig().showTextOnMouseover ~= false then
            self.Text:Show()
        end

        if GameTooltip and SB.CurrentData then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(SB.CurrentData.tooltip or SB.CurrentData.text or "RexUI")
            if SB.CurrentData.kind == "xp" and SB.CurrentData.rested and SB.CurrentData.rested > 0 then
                GameTooltip:AddLine(T("Ausgeruht: ") .. formatNumber(SB.CurrentData.rested), 0.25, 0.55, 1)
            end
            GameTooltip:Show()
        end
    end)

    bar:SetScript("OnLeave", function(self)
        if SB:GetConfig().showTextOnMouseover ~= false then
            self.Text:Hide()
        end
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    self.Bar = bar
end

function SB:ApplyConfig()
    self:CreateBar()

    local cfg = self:GetConfig()
    local bar = self.Bar
    if not bar then return end

    bar:ClearAllPoints()
    bar:SetPoint(cfg.point or "CENTER", UIParent, cfg.relPoint or cfg.point or "CENTER", cfg.x or 0, cfg.y or -305)
    bar:SetSize(clamp(cfg.width, 120, 1200), clamp(cfg.height, 4, 40))
    bar:SetScale(clamp(cfg.scale, 0.5, 2))
    bar:SetAlpha(clamp(cfg.alpha, 0.05, 1))
    bar.Spark:SetSize(10, (cfg.height or 10) + 18)

    if cfg.showTextOnMouseover ~= false then
        bar.Text:Hide()
    else
        bar.Text:Show()
    end
end

function SB:Update()
    self:ApplyConfig()

    local cfg = self:GetConfig()
    local bar = self.Bar
    if not bar then return end

    local data = self:GetDisplayData()
    self.CurrentData = data

    if cfg.enabled == false or not data or data.maxValue <= 0 then
        bar:Hide()
        if self.Mover then self.Mover:Hide() end
        return
    end

    bar:SetMinMaxValues(0, data.maxValue)
    bar:SetValue(data.value)
    bar:SetStatusBarColor(unpack(data.color))
    bar.Text:SetText(T(data.text or ""))

    local restedValue = 0
    if data.kind == "xp" and data.rested and data.rested > 0 then
        restedValue = math.min(data.maxValue, data.value + data.rested)
        bar.Rested:SetStatusBarColor(unpack(data.restedColor))
    end
    bar.Rested:SetMinMaxValues(0, data.maxValue)
    bar.Rested:SetValue(restedValue)
    bar.Rested:SetShown(restedValue > data.value)

    bar.Spark:ClearAllPoints()
    if data.value > 0 then
        bar.Spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
        bar.Spark:Show()
    else
        bar.Spark:Hide()
    end

    bar:Show()

    if RexUI.Unlocked then
        self:ShowMover()
    else
        self:HideMover()
    end
end

function SB:CreateMover()
    if self.Mover then return end

    local mover = CreateFrame("Frame", nil, UIParent)
    mover:SetFrameLevel(500)
    mover:SetClampedToScreen(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:Hide()

    mover.Bg = mover:CreateTexture(nil, "BACKGROUND")
    mover.Bg:SetAllPoints(mover)
    mover.Bg:SetColorTexture(0.2, 0.6, 1, 0.25)

    mover.Label = mover:CreateFontString(nil, "OVERLAY")
    mover.Label:SetFont(FONT, 9, "OUTLINE")
    mover.Label:SetPoint("CENTER")
    mover.Label:SetText(T("Erfahrungsleiste"))

    mover:SetScript("OnDragStart", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        self:SetMovable(true)
        self:StartMoving()
    end)

    mover:SetScript("OnDragStop", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        self:StopMovingOrSizing()
        self:SetMovable(false)

        local left, bottom, width, height = self:GetRect()
        if left then
            local centerX, centerY = UIParent:GetCenter()
            local x = math.floor((left + width / 2 - centerX) + 0.5)
            local y = math.floor((bottom + height / 2 - centerY) + 0.5)

            SB:Save("point", "CENTER")
            SB:Save("relPoint", "CENTER")
            SB:Save("x", x)
            SB:Save("y", y)
            SB:Update()
        end
    end)

    self.Mover = mover
end

function SB:ShowMover()
    self:CreateMover()
    if not self.Mover or not self.Bar or not self.Bar:IsShown() then return end

    self.Mover:ClearAllPoints()
    self.Mover:SetSize(self.Bar:GetWidth(), math.max(self.Bar:GetHeight(), 26))
    self.Mover:SetPoint("CENTER", self.Bar, "CENTER", 0, 0)
    self.Mover:Show()
end

function SB:HideMover()
    if self.Mover then
        self.Mover:Hide()
    end
end

function SB:Initialize()
    if self.initialized then return end
    self.initialized = true

    self.EventFrame = self.EventFrame or CreateFrame("Frame")
    local function registerEvent(event)
        pcall(self.EventFrame.RegisterEvent, self.EventFrame, event)
    end

    registerEvent("PLAYER_ENTERING_WORLD")
    registerEvent("PLAYER_XP_UPDATE")
    registerEvent("PLAYER_LEVEL_UP")
    registerEvent("UPDATE_EXHAUSTION")
    registerEvent("DISABLE_XP_GAIN")
    registerEvent("ENABLE_XP_GAIN")
    registerEvent("UPDATE_FACTION")
    registerEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
    self.EventFrame:SetScript("OnEvent", function()
        SB:Update()
    end)

    self:Update()
    C_Timer.After(0.5, function() SB:Update() end)
end
