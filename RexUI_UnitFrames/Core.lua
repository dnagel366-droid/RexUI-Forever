-- ============================================================
-- RexUI_UnitFrames - Core.lua
-- oUF based player, target, focus and boss unit frames
-- ============================================================

local ADDON_NAME, ns = ...

local RexUI = ns.RexUI or _G.RexUI
if not RexUI then return end

local oUF = ns.oUF or RexUI.oUF or _G.RexUI_oUF

RexUI.UnitFrames = RexUI.UnitFrames or {}
local UF = RexUI.UnitFrames
RexUI:RegisterModule("UnitFrames", UF)

local function T(text)
    return RexUI:LocalizeText(text)
end

local STYLE_NAME = "RexUI_UnitFrames"
local TEXTURE = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"
local CLEAN_TEXTURE = "Interface\\AddOns\\RexUI\\media\\groupframes\\statusbar.tga"
local CLEAN_FONT = "Interface\\AddOns\\RexUI\\media\\fonts\\Expressway.TTF"
local FRAME_BG = { 0, 0, 0, 0.82 }
local BAR_BG = { 0.028, 0.028, 0.035, 0.94 }
local BORDER_COLOR = { 0, 0, 0, 1 }
local BAR_TOPLINE = { 1, 1, 1, 0.045 }
local CASTBAR_FAIL_COLOR = { 0.58, 0.18, 0.16, 1 }
local DEFAULT_ENEMY_CAST_COLORS = {
    interruptible = { r = 0.70, g = 0.40, b = 0.90, a = 1 },
    protected = { r = 0.45, g = 0.45, b = 0.45, a = 1 },
    interrupted = { r = 0.80, g = 0.00, b = 0.00, a = 1 },
}

local DEFAULTS = {
    enabled = true,
    hideBlizzard = true,
    enemyCastColors = DEFAULT_ENEMY_CAST_COLORS,
    player = { enabled = true, width = 220, healthHeight = 42, powerHeight = 7, scale = 1, point = "CENTER", relPoint = "CENTER", x = -280, y = -185, healthFormat = "PERCENT", healthBackgroundColor = { r = 17/255, g = 17/255, b = 17/255, a = 0.5 }, showCastbar = false, castbarPlacement = "INSIDE", showPortrait = false, showLevel = false, showRaidMarker = false, showDebuffs = false, debuffSize = 20, debuffRows = 1, debuffX = 0, debuffY = -4, showCombatIndicator = true, showClassPower = true, classPowerHeight = 12, castbarColor = { r = 0.20, g = 0.55, b = 0.95, a = 1 } },
    pet = { enabled = true, width = 180, healthHeight = 28, powerHeight = 5, scale = 1, point = "CENTER", relPoint = "CENTER", x = -280, y = -235, healthBackgroundColor = { r = 17/255, g = 17/255, b = 17/255, a = 0.5 }, showCastbar = false, castbarPlacement = "INSIDE", showPortrait = false, showLevel = false, showRaidMarker = false, showDebuffs = false, debuffSize = 18, debuffRows = 1, debuffX = 0, debuffY = -4 },
    target = { enabled = true, width = 220, healthHeight = 42, powerHeight = 7, scale = 1, point = "CENTER", relPoint = "CENTER", x = 280, y = -185, healthFormat = "PERCENT", healthBackgroundColor = { r = 17/255, g = 17/255, b = 17/255, a = 0.5 }, showCastbar = true, castbarPlacement = "INSIDE", showPortrait = true, showLevel = true, showRaidMarker = true, showDebuffs = true, debuffSize = 22, debuffRows = 2, debuffX = 0, debuffY = -4, showBuffs = true, buffSize = 20, buffRows = 1, buffX = 0, buffY = -4, showThreat = true, rangeFade = true },
    focus = { enabled = true, width = 180, healthHeight = 34, powerHeight = 6, scale = 1, point = "CENTER", relPoint = "CENTER", x = 330, y = -80, healthFormat = "PERCENT", healthBackgroundColor = { r = 17/255, g = 17/255, b = 17/255, a = 0.5 }, showCastbar = true, castbarPlacement = "INSIDE", showPortrait = true, showLevel = true, showRaidMarker = true, showDebuffs = true, debuffSize = 20, debuffRows = 2, debuffX = 0, debuffY = -4, showBuffs = true, buffSize = 18, buffRows = 1, buffX = 0, buffY = -4, showThreat = true, rangeFade = true },
    boss = { enabled = true, width = 190, healthHeight = 34, powerHeight = 6, scale = 1, point = "RIGHT", relPoint = "RIGHT", x = -220, y = 155, spacing = 12, count = 5, healthFormat = "PERCENT", healthBackgroundColor = { r = 17/255, g = 17/255, b = 17/255, a = 0.5 }, showCastbar = true, castbarPlacement = "INSIDE", showPortrait = false, showLevel = true, showRaidMarker = true, showDebuffs = false, debuffSize = 20, debuffRows = 1, debuffX = 0, debuffY = -4, showThreat = true, rangeFade = true },
}

local frames = {}
local movers = {}
local debuffMovers = {}
local eventFrame

local HEALTH_TAG_PERCENT = "[perhp<$%]"
local HEALTH_TAG_COMPACT = "[rexui:healthcompact]"

local function ActualSmartLevel(unit)
    if not unit or not UnitExists(unit) then return "" end
    if UnitClassification(unit) == "worldboss" then return T("Boss") end

    local level
    if UnitIsWildBattlePet(unit) or UnitIsBattlePetCompanion(unit) then
        level = UnitBattlePetLevel(unit)
    else
        -- UnitEffectiveLevel liefert in skalierten Inhalten beispielsweise 60,
        -- obwohl der Charakter tatsaechlich bereits Level 72 ist.
        level = UnitLevel(unit)
    end

    if not level or level <= 0 then return "??" end
    local classification = UnitClassification(unit)
    local suffix = (classification == "elite" or classification == "rareelite") and "+" or ""
    return tostring(level) .. suffix
end

local function CompactHealth(unit)
    local value = UnitHealth(unit)
    if AbbreviateNumbers then
        return AbbreviateNumbers(value)
    end

    if issecretvalue and issecretvalue(value) then
        return value
    end

    if value >= 1000000000 then return (string.format("%.1fB", value / 1000000000):gsub("%.0B", "B")) end
    if value >= 1000000 then return (string.format("%.1fM", value / 1000000):gsub("%.0M", "M")) end
    if value >= 1000 then return (string.format("%.1fk", value / 1000):gsub("%.0k", "k")) end
    return tostring(math.floor(value + 0.5))
end

if oUF and oUF.Tags then
    oUF.Tags.Methods["rexui:healthcompact"] = CompactHealth
    oUF.Tags.Events["rexui:healthcompact"] = "UNIT_HEALTH UNIT_MAXHEALTH"
    oUF.Tags.Methods["rexui:smartlevel"] = ActualSmartLevel
    oUF.Tags.Events["rexui:smartlevel"] = "UNIT_LEVEL PLAYER_LEVEL_UP UNIT_CLASSIFICATION_CHANGED PLAYER_ENTERING_WORLD PLAYER_TARGET_CHANGED PLAYER_FOCUS_CHANGED INSTANCE_ENCOUNTER_ENGAGE_UNIT UPDATE_MOUSEOVER_UNIT"
    oUF.Tags.SharedEvents.PLAYER_LEVEL_UP = true
    oUF.Tags.SharedEvents.PLAYER_ENTERING_WORLD = true
    oUF.Tags.SharedEvents.PLAYER_TARGET_CHANGED = true
    oUF.Tags.SharedEvents.PLAYER_FOCUS_CHANGED = true
    oUF.Tags.SharedEvents.INSTANCE_ENCOUNTER_ENGAGE_UNIT = true
    oUF.Tags.SharedEvents.UPDATE_MOUSEOVER_UNIT = true
end

local function CopyConfig(src, saved)
    local cfg = {}

    for k, v in pairs(src) do
        if type(v) == "table" then
            cfg[k] = CopyConfig(v, saved and type(saved[k]) == "table" and saved[k] or nil)
        elseif saved and saved[k] ~= nil then
            cfg[k] = saved[k]
        else
            cfg[k] = v
        end
    end

    if type(saved) == "table" then
        for k, v in pairs(saved) do
            if cfg[k] == nil then cfg[k] = v end
        end
    end

    return cfg
end

function UF:GetConfig()
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    if profile and type(profile.unitframes) == "table" then
        profile.unitframes.target = type(profile.unitframes.target) == "table" and profile.unitframes.target or {}
        profile.unitframes.focus = type(profile.unitframes.focus) == "table" and profile.unitframes.focus or {}

        if not profile.unitframes._targetPortraitRestored then
            profile.unitframes.target.showPortrait = true
            profile.unitframes._targetPortraitRestored = true
        end

        if not profile.unitframes._focusPortraitRestored then
            profile.unitframes.focus.showPortrait = true
            profile.unitframes._focusPortraitRestored = true
        end

        if not profile.unitframes._castbarInsideDefault then
            for _, unitKey in ipairs({ "player", "pet", "target", "focus", "boss" }) do
                profile.unitframes[unitKey] = type(profile.unitframes[unitKey]) == "table" and profile.unitframes[unitKey] or {}
                profile.unitframes[unitKey].castbarPlacement = "INSIDE"
            end
            profile.unitframes._castbarInsideDefault = true
        end
    end

    return CopyConfig(DEFAULTS, profile and profile.unitframes)
end

function UF:Save(unitKey, key, value)
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    if not profile then return end

    profile.unitframes = profile.unitframes or {}
    if unitKey then
        profile.unitframes[unitKey] = profile.unitframes[unitKey] or {}
        profile.unitframes[unitKey][key] = value
    else
        profile.unitframes[key] = value
    end
end

local function GetRexColor(name, fallbackR, fallbackG, fallbackB, fallbackA)
    if RexUI.GetColor then
        local r, g, b, a = RexUI:GetColor(name)
        if r and g and b then
            return r, g, b, a or fallbackA or 1
        end
    end

    return fallbackR or 1, fallbackG or 1, fallbackB or 1, fallbackA or 1
end

local function UnitKey(unit)
    if unit and unit:match("^boss%d+$") then
        return "boss"
    end

    return unit
end

local function CreateBorder(parent)
    local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({ edgeFile = TEXTURE, edgeSize = 1 })
    border:SetBackdropBorderColor(unpack(BORDER_COLOR))
    border:SetFrameLevel(parent:GetFrameLevel() + 3)
    return border
end

local function CreateFont(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size or 11, "OUTLINE")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetTextColor(0.92, 0.92, 0.96, 1)
    fs:SetShadowColor(0, 0, 0, 0.95)
    fs:SetShadowOffset(1, -1)
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    return fs
end

local function CreateStatusBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(TEXTURE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.bg:SetColorTexture(unpack(BAR_BG))

    bar.topLine = bar:CreateTexture(nil, "OVERLAY", nil, 1)
    bar.topLine:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    bar.topLine:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -1, -1)
    bar.topLine:SetHeight(1)
    bar.topLine:SetColorTexture(unpack(BAR_TOPLINE))

    bar.border = CreateBorder(bar)
    return bar
end

local function CreateResourceSegment(parent)
    local segment = CreateFrame("StatusBar", nil, parent)
    segment:SetStatusBarTexture(CLEAN_TEXTURE)
    segment:SetMinMaxValues(0, 1)
    segment:SetValue(0)

    segment.bg = segment:CreateTexture(nil, "BACKGROUND")
    segment.bg:SetAllPoints(segment)
    segment.bg:SetColorTexture(0.035, 0.035, 0.045, 0.94)
    segment.border = CreateBorder(segment)
    segment:Hide()
    return segment
end

local function LayoutResourceSegments(element, holder, count)
    if not element or not holder then return end

    count = math.min(#element, math.max(0, tonumber(count) or 0))
    if count == 0 then
        holder:Hide()
        return
    end

    local padding = 2
    local spacing = 3
    local width = math.max(1, holder:GetWidth() - padding * 2)
    local segmentWidth = math.max(1, (width - spacing * (count - 1)) / count)

    for index = 1, #element do
        local segment = element[index]
        segment:ClearAllPoints()
        if index <= count then
            local offset = padding + (index - 1) * (segmentWidth + spacing)
            segment:SetPoint("TOPLEFT", holder, "TOPLEFT", offset, -padding)
            segment:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", offset, padding)
            segment:SetWidth(segmentWidth)
        end
    end
end

local function CreatePlayerClassResources(frame)
    local holder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    holder:SetPoint("TOPLEFT", frame.Power, "BOTTOMLEFT", 0, -4)
    holder:SetPoint("TOPRIGHT", frame.Power, "BOTTOMRIGHT", 0, -4)
    holder:SetHeight(12)
    holder:SetBackdrop({
        bgFile = TEXTURE,
        edgeFile = TEXTURE,
        edgeSize = 1,
    })
    holder:SetBackdropColor(0.015, 0.015, 0.02, 0.96)
    holder:SetBackdropBorderColor(unpack(BORDER_COLOR))
    holder:Hide()
    frame.ClassPowerHolder = holder

    local _, playerClass = UnitClass("player")
    if playerClass == "DEATHKNIGHT" then
        local runes = {}
        for index = 1, 6 do
            runes[index] = CreateResourceSegment(holder)
        end
        runes.colorSpec = true
        runes.sortOrder = "asc"
        runes.PostUpdate = function(element)
            LayoutResourceSegments(element, holder, 6)
            holder:Show()
        end
        frame.Runes = runes
        LayoutResourceSegments(runes, holder, 6)
    else
        local classPower = {}
        for index = 1, 10 do
            classPower[index] = CreateResourceSegment(holder)
        end
        classPower.PostUpdate = function(element, _, maximum)
            LayoutResourceSegments(element, holder, maximum or element.__max)
        end
        classPower.PostVisibility = function(element, visible)
            if visible then
                LayoutResourceSegments(element, holder, element.__max)
                holder:Show()
            else
                holder:Hide()
            end
        end
        frame.ClassPower = classPower
    end
end

local function StyleAuraButton(element, button)
    if not button then return end

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    button.bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    button.bg:SetColorTexture(0, 0, 0, 0.85)

    button.border = CreateBorder(button)

    if button.Icon then
        button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.Icon:SetDrawLayer("BORDER")
    end

    if button.Count then
        button.Count:SetFont(FONT, 10, "OUTLINE")
        button.Count:ClearAllPoints()
        button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 0)
        button.Count:SetTextColor(1, 1, 1, 1)
        button.Count:SetShadowColor(0, 0, 0, 1)
        button.Count:SetShadowOffset(1, -1)
    end
end

local function InitializeNativeAuraButton(button)
    if not button then return end

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(false)

    local count = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    count:SetFont(CLEAN_FONT, 10, "OUTLINE")

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    button.bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    button.bg:SetColorTexture(0, 0, 0, 0.85)
    button.border = CreateBorder(button)
    button.Icon = icon
    button.Cooldown = cooldown
    button.Count = count

    if button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end
    if button.SetIcon then button:SetIcon(icon) end
    if button.SetDurationCooldown then button:SetDurationCooldown(cooldown) end
    if button.SetApplicationCount then button:SetApplicationCount(count, {}) end
end

local function CreateNativeAuraContainer(parent, groupKey, filter)
    if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.LoadAddOn) then return nil end
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo
        and not C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate") then
        return nil
    end

    local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    if not ok or not container or not container.AddAuraGroup then return nil end

    container._rexGroupKey = groupKey
    container._rexButtons = {}
    local added = pcall(container.AddAuraGroup, container, groupKey, filter, {
        maxFrameCount = 40,
        sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.ImportantOnly,
        sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal,
        initializeFrame = function(button)
            InitializeNativeAuraButton(button)
            container._rexButtons[button] = true
        end,
        layout = {
            elementWidth = 20,
            elementHeight = 20,
            elementSpacing = 3,
            lineSpacing = 3,
            maximumLineSize = 220,
        },
    })
    if not added then
        container:Hide()
        return nil
    end

    container:SetFrameLevel(parent:GetFrameLevel() + 25)
    container:SetClipsChildren(false)

    if container.SetFlowLayoutAnchorPoint then
        pcall(container.SetFlowLayoutAnchorPoint, container, "TOPLEFT")
    end
    if container.SetFlowLayoutGrowthDirection and AnchorUtil and AnchorUtil.FlowDirection then
        pcall(container.SetFlowLayoutGrowthDirection, container,
            AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
    end
    if container.SetEnabled then pcall(container.SetEnabled, container, false) end
    pcall(container.SetUnit, container, "none")
    container:Hide()
    return container
end

local function ConfigureNativeAuraContainer(container, count, size, spacing, columns)
    if not container then return end
    local key = container._rexGroupKey
    local layout = {
        elementWidth = size,
        elementHeight = size,
        elementSpacing = spacing,
        lineSpacing = spacing,
        maximumLineSize = columns * (size + spacing) + 1,
    }
    if container.SetAuraGroupMaxFrameCount then
        pcall(container.SetAuraGroupMaxFrameCount, container, key, count)
    end
    if container.SetAuraGroupLayout then
        pcall(container.SetAuraGroupLayout, container, key, layout)
    end
    if container.SetFlowLayoutMaximumLineSize then
        pcall(container.SetFlowLayoutMaximumLineSize, container, layout.maximumLineSize)
    end
    for button in pairs(container._rexButtons or {}) do
        pcall(button.SetSize, button, size, size)
    end
end

local function SetElementEnabled(frame, elementName, enabled)
    if not frame or not frame.IsElementEnabled then return end

    local active = frame:IsElementEnabled(elementName)
    if enabled and not active then
        frame:EnableElement(elementName, frame.unit)
    elseif not enabled and active then
        frame:DisableElement(elementName)
    end
end

local function IsPlayerInCombat()
    local ok, inCombat = pcall(function()
        return UnitAffectingCombat("player") and true or false
    end)

    return ok and inCombat == true
end

local function IsPlayerResting()
    local ok, resting = pcall(function()
        return IsResting and IsResting() and true or false
    end)

    return ok and resting == true
end

local function GetThreatState(unit)
    local ok, state = pcall(function()
        if not unit or not UnitExists(unit) then return nil end

        local status = UnitThreatSituation("player", unit)
        if status and status >= 3 then return "high" end
        if status and status >= 2 then return "medium" end
        return nil
    end)

    return ok and state or nil
end

local function IsUnitOutOfRange(unit)
    local ok, outOfRange = pcall(function()
        if not unit or not UnitExists(unit) or UnitIsUnit(unit, "player") then
            return false
        end

        if UnitInRange then
            local inRange, checked = UnitInRange(unit)
            local inRangeIsSecret = issecretvalue and issecretvalue(inRange)
            local checkedIsSecret = issecretvalue and issecretvalue(checked)
            if not checkedIsSecret and not inRangeIsSecret and checked then
                return inRange == false
            end
        end

        return false
    end)

    return ok and outOfRange == true
end

local function GetFrameConfig(frame)
    if not frame then return nil end

    local cfg = UF.Config or UF:GetConfig()
    if frame.unitKey == "boss" then return cfg.boss or DEFAULTS.boss end
    return cfg[frame.unitKey] or DEFAULTS[frame.unitKey]
end

local function GetCastbarPlacement(cfg)
    return cfg and cfg.castbarPlacement == "INSIDE" and "INSIDE" or "BELOW"
end

local function SetShownIfChanged(region, shown)
    if not region then return end

    shown = shown == true
    if region:IsShown() ~= shown then
        region:SetShown(shown)
    end
end

local function SetAlphaIfChanged(frame, alpha)
    if not frame then return end

    alpha = alpha or 1
    if frame.rexLastAlpha ~= alpha then
        frame:SetAlpha(alpha)
        frame.rexLastAlpha = alpha
    end
end

local function AnchorDebuffs(frame, cfg, x, y)
    if not frame or not cfg then return end

    local debuffs = frame.RexDebuffs or frame.Debuffs
    if not debuffs then return end
    local anchor = cfg.showCastbar ~= false and GetCastbarPlacement(cfg) == "BELOW" and frame.Castbar or frame
    debuffs:ClearAllPoints()
    debuffs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or cfg.debuffX or 0, y or cfg.debuffY or -4)
end

local function AnchorBuffs(frame, cfg, x, y)
    if not frame or not cfg then return end

    local buffs = frame.RexBuffs or frame.Buffs
    local debuffs = frame.RexDebuffs or frame.Debuffs
    if not buffs then return end
    -- Keep both aura types in separate rows. Buffs follow the debuff block;
    -- if debuffs are disabled, they start directly below the unit frame.
    local anchor
    if cfg.showDebuffs == true and debuffs then
        anchor = debuffs
    elseif cfg.showCastbar ~= false and GetCastbarPlacement(cfg) == "BELOW" then
        anchor = frame.Castbar
    else
        anchor = frame
    end
    buffs:ClearAllPoints()
    buffs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or cfg.buffX or 0, y or cfg.buffY or -4)
end

local function UpdateFrameHints(frame)
    local cfg = GetFrameConfig(frame)
    if not frame or not cfg then return end
    if frame.rexEnabled == false then return end

    if frame.CombatIndicator then
        SetShownIfChanged(frame.CombatIndicator, frame.unitKey == "player" and cfg.showCombatIndicator ~= false and IsPlayerInCombat())
    end

    if frame.RestingIndicator then
        SetShownIfChanged(frame.RestingIndicator, frame.unitKey == "player" and IsPlayerResting())
    end

    if frame.ReadyCheckIndicator then
        local status = frame.unitKey == "player" and GetReadyCheckStatus and GetReadyCheckStatus("player")
        if status == "ready" then
            frame.ReadyCheckIndicator:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
            SetShownIfChanged(frame.ReadyCheckIndicator, true)
        elseif status == "notready" then
            frame.ReadyCheckIndicator:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
            SetShownIfChanged(frame.ReadyCheckIndicator, true)
        elseif status == "waiting" then
            frame.ReadyCheckIndicator:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
            SetShownIfChanged(frame.ReadyCheckIndicator, true)
        else
            SetShownIfChanged(frame.ReadyCheckIndicator, false)
        end
    end

    if frame.ThreatBorder then
        local threat = frame.unitKey ~= "player" and cfg.showThreat ~= false and GetThreatState(frame.unit)
        if threat ~= frame.rexThreatState then
            frame.rexThreatState = threat
            if threat == "high" then
                frame.ThreatBorder:SetBackdropBorderColor(1, 0.18, 0.12, 0.66)
            elseif threat == "medium" then
                frame.ThreatBorder:SetBackdropBorderColor(1, 0.72, 0.18, 0.52)
            end
        end

        if threat == "high" or threat == "medium" then
            SetShownIfChanged(frame.ThreatBorder, true)
        else
            SetShownIfChanged(frame.ThreatBorder, false)
        end
    end

    local outOfRange = frame.unitKey ~= "player" and cfg.rangeFade ~= false and IsUnitOutOfRange(frame.unit)
    if outOfRange then
        frame.rexRangeMisses = math.min((frame.rexRangeMisses or 0) + 1, 2)
    else
        frame.rexRangeMisses = 0
    end

    if frame.rexRangeMisses >= 2 then
        SetAlphaIfChanged(frame, 0.72)
    else
        SetAlphaIfChanged(frame, 1)
    end
end

-- Keep Blizzard/oUF's filled health color, but use the independently
-- configurable RexHeal-style color for the missing-health area.
local ELVUI_UF_MULTIPLIER = 0.35

local function UpdateElvHealthBackdrop(element, unit, r, g, b)
    if not element then return end
    if not r or not g or not b then r, g, b = element:GetStatusBarColor() end
    if not r or not g or not b then return end
    element:SetStatusBarColor(r, g, b, 1)
    if element.bg then
        local owner = element.__owner
        local unitKey = owner and owner.unitKey
        local unitCfg = unitKey and UF.Config and UF.Config[unitKey]
        local color = unitCfg and unitCfg.healthBackgroundColor
        if type(color) == "table" then
            element.bg:SetColorTexture(
                tonumber(color.r) or 17/255,
                tonumber(color.g) or 17/255,
                tonumber(color.b) or 17/255,
                tonumber(color.a) or 0.5
            )
        else
            element.bg:SetColorTexture(17/255, 17/255, 17/255, 0.5)
        end
    end
end

local function UpdateElvPowerColor(element, unit, r, g, b)
    if not element then return end
    if not r or not g or not b then r, g, b = element:GetStatusBarColor() end
    if not r or not g or not b then return end
    element:SetStatusBarColor(r, g, b, 1)
    if element.bg then element.bg:SetColorTexture(r, g, b, ELVUI_UF_MULTIPLIER) end
end

local function UpdateCastbarColor(self)
    local r, g, b, a
    local owner = self.__owner
    local unitKey = owner and owner.unitKey
    local enemyCastColors = UF.Config and UF.Config.enemyCastColors or DEFAULT_ENEMY_CAST_COLORS

    if self.rexFailed then
        if unitKey == "target" or unitKey == "focus" or unitKey == "boss" then
            local c = enemyCastColors.interrupted
            r, g, b, a = c.r, c.g, c.b, c.a
        else
            r, g, b, a = 0.20, 0.20, 0.20, 0.90
        end
    else
        local notInterruptible = self.notInterruptible
        if issecretvalue and issecretvalue(notInterruptible) then notInterruptible = nil end

        local unitCfg = unitKey and UF.Config and UF.Config[unitKey]
        local customColor = unitCfg and unitCfg.castbarColor

        if unitKey == "player" and type(customColor) == "table" then
            r = tonumber(customColor.r) or 0.20
            g = tonumber(customColor.g) or 0.55
            b = tonumber(customColor.b) or 0.95
            a = tonumber(customColor.a) or 1
        elseif unitKey == "target" or unitKey == "focus" or unitKey == "boss" then
            local c = notInterruptible and enemyCastColors.protected or enemyCastColors.interruptible
            r, g, b, a = c.r, c.g, c.b, c.a
        elseif notInterruptible then
            r, g, b, a = 0.78, 0.25, 0.25, 0.90
        else
            r, g, b, a = 0.40, 0.40, 0.40, 0.90
        end
    end

    self:SetStatusBarColor(r, g, b, a)
end

local function UpdateCastbarActive(self)
    self.rexFailed = nil
    UpdateCastbarColor(self)

    if self.Spark then
        self.Spark:SetAlpha(0.52)
    end
end

local function UpdateCastbarFailed(self)
    self.rexFailed = true
    UpdateCastbarColor(self)

    if self.Spark then
        self.Spark:Hide()
    end
end

local function UpdateCastbarStopped(self)
    self.rexFailed = nil
    UpdateCastbarColor(self)

    if self.Spark then
        self.Spark:Hide()
    end
end

local function PortraitGuidChanged(element, guid)
    if element._rexPortraitGuid == guid then
        return false
    end
    element._rexPortraitGuid = guid
    return true
end

-- Forever: oUF's default 3D Portrait Update treats every event as a state
-- change (ClearModel + SetUnit). UNIT_PORTRAIT_UPDATE fires as a mob dies
-- and hitchs the whole screen. Only rebuild when GUID/visibility changes;
-- NPCs stay on the 2D texture, players keep the 3D model.
--
-- Cold-start: SetUnit on an already-visible PlayerModel leaves a black mesh.
-- The config AUS/EIN path works because it hides the unit frame, SetUnit, then
-- shows it. ApplyPortraitModel hides the model/holder around SetUnit; the
-- first PLAYER_ENTERING_WORLD also replays that hide/SetUnit/show on player.
local function ApplyPortraitModel(element, unit)
    if not element or not unit then
        return
    end

    local holder = element.GetParent and element:GetParent()
    if holder and holder.Hide then
        holder:Hide()
    end
    element:Hide()
    if element.ClearModel then
        element:ClearModel()
    end
    element:SetUnit(unit)
    if element.SetCamDistanceScale then
        element:SetCamDistanceScale(1)
    end
    if element.SetPortraitZoom then
        element:SetPortraitZoom(1)
    end
    if element.SetPosition then
        element:SetPosition(0, 0, 0)
    end
    element:Show()
    if holder and holder.Show then
        holder:Show()
    end
end

local function UpdatePortrait(self, event, unit)
    if not unit or unit ~= self.unit then return end
    local element = self.Portrait
    if not element then return end
    local texture = self.PortraitTexture

    if not UnitExists(unit) then
        element._rexPortraitGuid = nil
        element._rexPortraitAvailable = nil
        if texture then texture:Hide() end
        element:Hide()
        return
    end

    local guid = UnitGUID(unit)
    local isAvailable = UnitIsConnected(unit) and UnitIsVisible(unit)
    local guidChanged = PortraitGuidChanged(element, guid)
    local availabilityChanged = element._rexPortraitAvailable ~= isAvailable
    element._rexPortraitAvailable = isAvailable
    local forceRebuild = event == "ForceUpdate"
        or event == "UNIT_MODEL_CHANGED"
        or event == "PLAYER_ENTERING_WORLD"
        or event == "OnShow"
    if not guidChanged and not availabilityChanged and not forceRebuild then
        return
    end

    local isPlayer = UnitIsPlayer(unit)
    if not isAvailable then
        if texture then texture:Hide() end
        element:Hide()
        return
    end

    if isPlayer then
        if texture then texture:Hide() end
        if forceRebuild or guidChanged or not element:IsShown() then
            ApplyPortraitModel(element, unit)
        end
        element:Show()
        return
    end

    element:Hide()
    if texture then
        SetPortraitTexture(texture, unit)
        texture:Show()
    end
end

local function UpdatePortraitFallback(element, unit)
    -- Kept for ForceUpdate paths that still call PostUpdate.
    UpdatePortrait(element.__owner, "ForceUpdate", unit)
end

local function StyleUnitFrame(frame, unit)
    frame.unitKey = UnitKey(unit)
    frame:SetFrameStrata("LOW")
    frame:SetFrameLevel(20)
    frame:RegisterForClicks("AnyUp")
    frame:SetSize(220, 50)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetPoint("TOPLEFT", -1, 1)
    frame.bg:SetPoint("BOTTOMRIGHT", 1, -1)
    frame.bg:SetColorTexture(unpack(FRAME_BG))

    local threatBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    threatBorder:SetPoint("TOPLEFT", -2, 2)
    threatBorder:SetPoint("BOTTOMRIGHT", 2, -2)
    threatBorder:SetBackdrop({ edgeFile = TEXTURE, edgeSize = 1 })
    threatBorder:SetBackdropBorderColor(1, 0.08, 0.04, 0.72)
    threatBorder:SetFrameLevel(frame:GetFrameLevel() + 45)
    threatBorder:Hide()
    frame.ThreatBorder = threatBorder

    -- Player-state icons need their own raised child frame. A texture created
    -- directly on the oUF frame is rendered below child StatusBars, so the
    -- health/power bars can completely cover it even on the OVERLAY layer.
    -- ElvUI solves the same problem with a raised element parent.
    local stateOverlay = CreateFrame("Frame", nil, frame)
    stateOverlay:SetAllPoints(frame)
    stateOverlay:SetFrameStrata(frame:GetFrameStrata())
    stateOverlay:SetFrameLevel(frame:GetFrameLevel() + 100)
    stateOverlay:EnableMouse(false)
    frame.StateOverlay = stateOverlay

    local combatIndicator = stateOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    combatIndicator:SetSize(20, 20)
    combatIndicator:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
    combatIndicator:SetTexture([[Interface\CharacterFrame\UI-StateIcon]])
    combatIndicator:SetTexCoord(0.5, 1, 0, 0.49)
    combatIndicator:Hide()
    frame.CombatIndicator = combatIndicator

    local restingIndicator = stateOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    restingIndicator:SetSize(20, 20)
    restingIndicator:SetPoint("TOPLEFT", frame, "TOPLEFT", -8, 8)
    restingIndicator:SetTexture([[Interface\CharacterFrame\UI-StateIcon]])
    restingIndicator:SetTexCoord(0, 0.5, 0, 0.421875)
    restingIndicator:Hide()
    frame.RestingIndicator = restingIndicator

    -- Ready check status. Keep this on the same raised overlay as the player
    -- state icons so health bars / portrait children can never cover it.
    -- Position and size follow ElvUI's default ready-check treatment.
    local readyCheckIndicator = stateOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    readyCheckIndicator:SetSize(16, 16)
    readyCheckIndicator:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)
    readyCheckIndicator:Hide()
    frame.ReadyCheckIndicator = readyCheckIndicator

    frame.PortraitHolder = CreateFrame("Frame", nil, frame)
    frame.PortraitHolder:Hide()
    frame.PortraitHolder.bg = frame.PortraitHolder:CreateTexture(nil, "BACKGROUND")
    frame.PortraitHolder.bg:SetAllPoints(frame.PortraitHolder)
    frame.PortraitHolder.bg:SetColorTexture(unpack(BAR_BG))
    frame.PortraitHolder.border = CreateBorder(frame.PortraitHolder)

    local portraitTexture = frame.PortraitHolder:CreateTexture(nil, "ARTWORK")
    portraitTexture:SetAllPoints(frame.PortraitHolder)
    portraitTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    portraitTexture:Hide()
    frame.PortraitTexture = portraitTexture

    local portrait = CreateFrame("PlayerModel", nil, frame.PortraitHolder)
    portrait:SetAllPoints(frame.PortraitHolder)
    portrait:SetFrameLevel(frame.PortraitHolder:GetFrameLevel() + 1)
    portrait.Override = UpdatePortrait
    portrait:Hide()
    frame.Portrait = portrait

    local health = CreateStatusBar(frame)
    health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    health:SetHeight(42)
    health.colorClass = true
    health.colorReaction = true
    health.colorDisconnected = true
    health.colorTapping = true
    health.colorHealth = nil
    health.PostUpdateColor = UpdateElvHealthBackdrop
    frame.Health = health

    local levelText = CreateFont(health, 11, "LEFT")
    levelText:SetPoint("LEFT", health, "LEFT", 6, 0)
    levelText:SetWidth(58)
    levelText:SetJustifyH("RIGHT")
    levelText:Hide()
    frame:Tag(levelText, "[rexui:smartlevel]")
    frame.levelText = levelText

    local nameText = CreateFont(health, 12, "LEFT")
    nameText:SetPoint("LEFT", levelText, "RIGHT", 4, 0)
    nameText:SetPoint("RIGHT", health, "RIGHT", -82, 0)
    frame:Tag(nameText, "[name]")
    frame.nameText = nameText

    local healthText = CreateFont(health, 12, "RIGHT")
    healthText:SetPoint("RIGHT", health, "RIGHT", -6, 0)
    frame:Tag(healthText, HEALTH_TAG_PERCENT)
    frame.healthTag = HEALTH_TAG_PERCENT
    frame.healthText = healthText

    local power = CreateStatusBar(frame)
    power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -2)
    power:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", 0, -2)
    power:SetHeight(7)
    power.colorPower = true
    power.frequentUpdates = true
    power.PostUpdateColor = UpdateElvPowerColor
    frame.Power = power

    local powerText = CreateFont(power, 9, "CENTER")
    powerText:SetPoint("CENTER", power, "CENTER", 0, 0)
    frame:Tag(powerText, "[perpp<$%]")
    frame.powerText = powerText

    if frame.unitKey == "player" then
        CreatePlayerClassResources(frame)
    end

    local debuffs = CreateFrame("Frame", nil, frame)
    debuffs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -4)
    debuffs:SetSize(220, 44)
    debuffs.size = 22
    debuffs.spacing = 3
    debuffs.num = 16
    debuffs.maxCols = 8
    debuffs.initialAnchor = "TOPLEFT"
    debuffs.growthX = "RIGHT"
    debuffs.growthY = "DOWN"
    debuffs.filter = "HARMFUL"
    debuffs.showDebuffType = true
    debuffs.tooltipAnchor = "ANCHOR_RIGHT"
    debuffs.PostCreateButton = StyleAuraButton
    debuffs:Hide()
    frame.Debuffs = debuffs

    local buffs = CreateFrame("Frame", nil, frame)
    buffs:SetPoint("TOPLEFT", debuffs, "BOTTOMLEFT", 0, -4)
    buffs:SetSize(220, 20)
    buffs.size = 20
    buffs.spacing = 3
    buffs.num = 9
    buffs.maxCols = 9
    buffs.initialAnchor = "TOPLEFT"
    buffs.growthX = "RIGHT"
    buffs.growthY = "DOWN"
    buffs.filter = "HELPFUL"
    buffs.showBuffType = true
    buffs.showStealableBuffs = true
    buffs.tooltipAnchor = "ANCHOR_RIGHT"
    buffs.PostCreateButton = StyleAuraButton
    buffs:Hide()
    frame.Buffs = buffs

    -- Midnight's native aura container is the same reliable primary path
    -- used by RexUI nameplates. The oUF widgets above remain as fallback.
    frame.RexDebuffs = CreateNativeAuraContainer(frame, "debuffs", "HARMFUL")
    frame.RexBuffs = CreateNativeAuraContainer(frame, "buffs", "HELPFUL")
    frame.usesNativeAuras = frame.RexDebuffs ~= nil and frame.RexBuffs ~= nil
    if not frame.usesNativeAuras then
        if frame.RexDebuffs then frame.RexDebuffs:Hide() end
        if frame.RexBuffs then frame.RexBuffs:Hide() end
        frame.RexDebuffs = nil
        frame.RexBuffs = nil
    end

    local castbar = CreateStatusBar(frame)
    castbar:SetPoint("TOPLEFT", power, "BOTTOMLEFT", 0, -6)
    castbar:SetPoint("TOPRIGHT", power, "BOTTOMRIGHT", 0, -6)
    castbar:SetHeight(14)
    castbar:SetStatusBarColor(0.31, 0.31, 0.31, 1)
    castbar.timeToHold = 0.32
    castbar.PostCastStart = UpdateCastbarActive
    castbar.PostCastUpdate = UpdateCastbarActive
    castbar.PostCastInterruptible = UpdateCastbarColor
    castbar.PostCastInterrupted = UpdateCastbarFailed
    castbar.PostCastFail = UpdateCastbarFailed
    castbar.PostCastStop = UpdateCastbarStopped

    local castText = CreateFont(castbar, 10, "LEFT")
    castText:SetPoint("LEFT", castbar, "LEFT", 5, 0)
    castText:SetJustifyH("LEFT")
    castbar.Text = castText

    local castTime = CreateFont(castbar, 10, "RIGHT")
    castTime:SetPoint("RIGHT", castbar, "RIGHT", -5, 0)
    castTime:SetJustifyH("RIGHT")
    castbar.Time = castTime
    castText:SetPoint("RIGHT", castTime, "LEFT", -6, 0)

    local castIconHolder = CreateFrame("Frame", nil, castbar)
    castIconHolder:SetPoint("LEFT", castbar, "LEFT", 0, 0)
    castIconHolder:SetSize(16, 16)
    castIconHolder:SetFrameLevel(castbar:GetFrameLevel() + 4)
    castIconHolder.bg = castIconHolder:CreateTexture(nil, "BACKGROUND")
    castIconHolder.bg:SetAllPoints(castIconHolder)
    castIconHolder.bg:SetColorTexture(unpack(BAR_BG))
    castIconHolder.border = CreateBorder(castIconHolder)
    castbar.IconHolder = castIconHolder

    local castIcon = castIconHolder:CreateTexture(nil, "ARTWORK")
    castIcon:SetPoint("TOPLEFT", castIconHolder, "TOPLEFT", 1, -1)
    castIcon:SetPoint("BOTTOMRIGHT", castIconHolder, "BOTTOMRIGHT", -1, 1)
    castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    castbar.Icon = castIcon

    local spark = castbar:CreateTexture(nil, "OVERLAY")
    spark:SetBlendMode("ADD")
    spark:SetAlpha(0.52)
    castbar.Spark = spark

    castbar:Hide()
    frame.Castbar = castbar

    local raidIcon = frame:CreateTexture(nil, "OVERLAY")
    raidIcon:SetSize(20, 20)
    raidIcon:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    raidIcon:SetDrawLayer("OVERLAY", 7)
    frame.RaidTargetIndicator = raidIcon

    frame:SetScript("OnEnter", function(self)
        if RexUI.ShowUnitTooltip then RexUI:ShowUnitTooltip(self, self.unit, "ANCHOR_RIGHT") end
    end)

    frame:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function SetFontFace(fontString, face)
    if not fontString or not fontString.GetFont then return end
    local _, size, flags = fontString:GetFont()
    fontString:SetFont(face, size or 11, flags or "OUTLINE")
end

local function ApplyVisualStyle(frame, cfg)
    local texture = CLEAN_TEXTURE
    local font = CLEAN_FONT

    frame.Health:SetStatusBarTexture(texture)
    frame.Power:SetStatusBarTexture(texture)
    frame.Castbar:SetStatusBarTexture(texture)

    SetFontFace(frame.levelText, font)
    SetFontFace(frame.nameText, font)
    SetFontFace(frame.healthText, font)
    SetFontFace(frame.powerText, font)
    SetFontFace(frame.Castbar.Text, font)
    SetFontFace(frame.Castbar.Time, font)

    frame.bg:SetColorTexture(0.055, 0.055, 0.055, 1)
    UpdateElvHealthBackdrop(frame.Health)
    frame.Power.bg:SetColorTexture(0.055, 0.055, 0.055, 1)
    frame.PortraitHolder.bg:SetColorTexture(0.055, 0.055, 0.055, 1)
    frame.Health.topLine:Hide()
    frame.Power.topLine:Hide()
end

local function RemoveLegacyUnitAccent(frame)
    local accent = frame and frame.UnitAccent
    if not accent then return end

    accent:Hide()
    accent:SetAlpha(0)
    accent:SetTexture(nil)
    accent:ClearAllPoints()
    frame.UnitAccent = nil
end

local function ApplyFrameLayout(frame, cfg)
    if not frame or not cfg then return end

    RemoveLegacyUnitAccent(frame)

    local healthHeight = cfg.healthHeight or 40
    local powerHeight = cfg.powerHeight or 7
    local hasPower = powerHeight > 0
    local frameHeight = healthHeight + (hasPower and (powerHeight + 1) or 0)
    local showPortrait = cfg.showPortrait == true
    local showLevel = cfg.showLevel == true
    local showRaidMarker = cfg.showRaidMarker == true
    local showCastbar = cfg.showCastbar ~= false
    local castbarPlacement = GetCastbarPlacement(cfg)
    local showDebuffs = cfg.showDebuffs == true and (frame.unitKey == "target" or frame.unitKey == "focus")
    local showBuffs = cfg.showBuffs == true and (frame.unitKey == "target" or frame.unitKey == "focus")
    local debuffSize = cfg.debuffSize or 20
    local debuffRows = math.max(1, cfg.debuffRows or 1)
    local debuffSpacing = 3
    local debuffCols = math.max(1, math.floor(((cfg.width or 220) + debuffSpacing) / (debuffSize + debuffSpacing)))
    local buffSize = cfg.buffSize or 18
    local buffRows = math.max(1, cfg.buffRows or 1)
    local buffSpacing = 3
    local buffCols = math.max(1, math.floor(((cfg.width or 220) + buffSpacing) / (buffSize + buffSpacing)))
    local portraitSize = frameHeight
    local barLeft = showPortrait and (portraitSize + 3) or 0

    frame:SetScale(cfg.scale or 1)
    frame:SetSize(cfg.width or 220, frameHeight)

    frame.bg:ClearAllPoints()
    frame.bg:SetPoint("TOPLEFT", -1, 1)
    frame.bg:SetPoint("BOTTOMRIGHT", 1, -1)

    frame.PortraitHolder:ClearAllPoints()
    frame.PortraitHolder:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.PortraitHolder:SetSize(portraitSize, portraitSize)
    frame.PortraitHolder:SetShown(showPortrait)
    SetElementEnabled(frame, "Portrait", showPortrait)
    if showPortrait and frame.Portrait.ForceUpdate then
        frame.Portrait:ForceUpdate()
    elseif not showPortrait then
        frame.Portrait:Hide()
        frame.PortraitTexture:Hide()
    end

    frame.RaidTargetIndicator:ClearAllPoints()
    frame.RaidTargetIndicator:SetSize(18, 18)
    frame.RaidTargetIndicator:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    frame.RaidTargetIndicator:SetDrawLayer("OVERLAY", 7)
    SetElementEnabled(frame, "RaidTargetIndicator", showRaidMarker)

    frame.Health:ClearAllPoints()
    frame.Health:SetPoint("TOPLEFT", frame, "TOPLEFT", barLeft, 0)
    frame.Health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.Health:SetHeight(healthHeight)

    frame.Power:ClearAllPoints()
    frame.Power:SetPoint("TOPLEFT", frame.Health, "BOTTOMLEFT", 0, -1)
    frame.Power:SetPoint("TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, -1)
    frame.Power:SetHeight(math.max(1, powerHeight))
    frame.Power:SetShown(hasPower)
    SetElementEnabled(frame, "Power", hasPower)

    if frame.ClassPowerHolder then
        local showClassPower = cfg.showClassPower ~= false
        frame.ClassPowerHolder:SetHeight(math.max(8, math.min(24, tonumber(cfg.classPowerHeight) or 12)))

        if frame.Runes then
            SetElementEnabled(frame, "Runes", showClassPower)
            if showClassPower then
                LayoutResourceSegments(frame.Runes, frame.ClassPowerHolder, 6)
                frame.ClassPowerHolder:Show()
                if frame.Runes.ForceUpdate then frame.Runes:ForceUpdate() end
            else
                frame.ClassPowerHolder:Hide()
            end
        elseif frame.ClassPower then
            SetElementEnabled(frame, "ClassPower", showClassPower)
            if showClassPower then
                if frame.ClassPower.ForceUpdate then frame.ClassPower:ForceUpdate() end
                LayoutResourceSegments(frame.ClassPower, frame.ClassPowerHolder, frame.ClassPower.__max)
            else
                frame.ClassPowerHolder:Hide()
            end
        end
    end

    frame.healthText:ClearAllPoints()
    frame.healthText:SetPoint("RIGHT", frame.Health, "RIGHT", -6, 0)

    local healthTag = cfg.healthFormat == "COMPACT" and HEALTH_TAG_COMPACT or HEALTH_TAG_PERCENT
    if frame.healthTag ~= healthTag then
        frame:Untag(frame.healthText)
        frame:Tag(frame.healthText, healthTag)
        frame.healthTag = healthTag
    end

    frame.levelText:ClearAllPoints()
    frame.levelText:SetPoint("RIGHT", frame.healthText, "LEFT", -8, 0)
    frame.levelText:SetWidth(showLevel and 68 or 1)
    frame.levelText:SetShown(showLevel)

    frame.nameText:ClearAllPoints()
    frame.nameText:SetPoint("LEFT", frame.Health, "LEFT", 6, 0)
    if showLevel then
        frame.nameText:SetPoint("RIGHT", frame.levelText, "LEFT", -6, 0)
    else
        frame.nameText:SetPoint("RIGHT", frame.healthText, "LEFT", -8, 0)
    end

    if frame.nameTag ~= "[name]" then
        frame:Tag(frame.nameText, "[name]")
        frame.nameTag = "[name]"
    end

    frame.powerText:ClearAllPoints()
    frame.powerText:SetPoint("CENTER", frame.Power, "CENTER", 0, 0)

    AnchorDebuffs(frame, cfg)
    AnchorBuffs(frame, cfg)
    if frame.usesNativeAuras then
        -- Do not let oUF and Blizzard compete for UNIT_AURA. The native
        -- containers are the primary Midnight path, matching nameplates.
        SetElementEnabled(frame, "Auras", false)
        frame.Debuffs:Hide()
        frame.Buffs:Hide()

        local debuffCount = debuffCols * debuffRows
        local buffCount = buffCols * buffRows
        frame.RexDebuffs:SetSize(cfg.width or 220,
            (debuffSize * debuffRows) + (debuffSpacing * (debuffRows - 1)))
        frame.RexBuffs:SetSize(cfg.width or 220,
            (buffSize * buffRows) + (buffSpacing * (buffRows - 1)))
        ConfigureNativeAuraContainer(frame.RexDebuffs, debuffCount, debuffSize, debuffSpacing, debuffCols)
        ConfigureNativeAuraContainer(frame.RexBuffs, buffCount, buffSize, buffSpacing, buffCols)

        for _, data in ipairs({
            { container = frame.RexDebuffs, shown = showDebuffs },
            { container = frame.RexBuffs, shown = showBuffs },
        }) do
            local container = data.container
            if data.shown then
                pcall(container.SetUnit, container, frame.unit)
                if container.SetEnabled then pcall(container.SetEnabled, container, true) end
                container:Show()
                if container.UpdateAllAuras then pcall(container.UpdateAllAuras, container) end
            else
                if container.SetEnabled then pcall(container.SetEnabled, container, false) end
                pcall(container.SetUnit, container, "none")
                container:Hide()
            end
        end
    else
        frame.Debuffs:SetSize(cfg.width or 220, (debuffSize * debuffRows) + (debuffSpacing * (debuffRows - 1)))
        frame.Debuffs.size = debuffSize
        frame.Debuffs.spacing = debuffSpacing
        frame.Debuffs.maxCols = debuffCols
        frame.Debuffs.num = debuffCols * debuffRows
        frame.Buffs:SetSize(cfg.width or 220, (buffSize * buffRows) + (buffSpacing * (buffRows - 1)))
        frame.Buffs.size = buffSize
        frame.Buffs.spacing = buffSpacing
        frame.Buffs.maxCols = buffCols
        frame.Buffs.num = buffCols * buffRows

        SetElementEnabled(frame, "Auras", showDebuffs or showBuffs)
        frame.Debuffs:SetShown(showDebuffs)
        frame.Buffs:SetShown(showBuffs)
        if showDebuffs or showBuffs then
            frame.Debuffs.needFullUpdate = true
            frame.Buffs.needFullUpdate = true
            if frame.Debuffs.ForceUpdate then
                frame.Debuffs:ForceUpdate()
            elseif frame.Buffs.ForceUpdate then
                frame.Buffs:ForceUpdate()
            end
            frame.Debuffs:SetShown(showDebuffs)
            frame.Buffs:SetShown(showBuffs)
        end
    end

    frame.Castbar:ClearAllPoints()
    frame.Castbar:SetFrameLevel(frame:GetFrameLevel() + (castbarPlacement == "INSIDE" and 18 or 8))

    local castbarHeight
    if castbarPlacement == "INSIDE" then
        castbarHeight = math.max(10, math.min(13, math.floor(healthHeight * 0.30)))
        frame.Castbar:SetPoint("BOTTOMLEFT", frame.Health, "BOTTOMLEFT", 1, 1)
        frame.Castbar:SetPoint("BOTTOMRIGHT", frame.Health, "BOTTOMRIGHT", -1, 1)
        frame.Castbar.bg:SetColorTexture(0, 0, 0, 0.42)
    elseif hasPower then
        castbarHeight = math.max(14, powerHeight + 8)
        frame.Castbar:SetPoint("TOPLEFT", frame.Power, "BOTTOMLEFT", 0, -6)
        frame.Castbar:SetPoint("TOPRIGHT", frame.Power, "BOTTOMRIGHT", 0, -6)
        frame.Castbar.bg:SetColorTexture(unpack(BAR_BG))
    else
        castbarHeight = math.max(14, powerHeight + 8)
        frame.Castbar:SetPoint("TOPLEFT", frame.Health, "BOTTOMLEFT", 0, -6)
        frame.Castbar:SetPoint("TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, -6)
        frame.Castbar.bg:SetColorTexture(unpack(BAR_BG))
    end
    frame.Castbar:SetHeight(castbarHeight)
    SetShownIfChanged(frame.Castbar.border, castbarPlacement ~= "INSIDE")
    SetShownIfChanged(frame.Castbar.topLine, castbarPlacement ~= "INSIDE")

    frame.Castbar.IconHolder:ClearAllPoints()
    frame.Castbar.IconHolder:SetPoint("LEFT", frame.Castbar, "LEFT", castbarPlacement == "INSIDE" and 1 or 0, 0)
    frame.Castbar.IconHolder:SetSize(castbarHeight, castbarHeight)
    SetShownIfChanged(frame.Castbar.IconHolder.border, castbarPlacement ~= "INSIDE")

    frame.Castbar.Spark:ClearAllPoints()
    frame.Castbar.Spark:SetSize(5, castbarHeight + (castbarPlacement == "INSIDE" and 1 or 5))
    frame.Castbar.Spark:SetPoint("CENTER", frame.Castbar:GetStatusBarTexture(), "RIGHT", 0, 0)

    frame.Castbar.Time:ClearAllPoints()
    frame.Castbar.Time:SetPoint("RIGHT", frame.Castbar, "RIGHT", castbarPlacement == "INSIDE" and -3 or -5, 0)
    frame.Castbar.Time:SetFont(FONT, castbarPlacement == "INSIDE" and 8 or 10, "OUTLINE")
    frame.Castbar.Time:SetWidth(castbarPlacement == "INSIDE" and 32 or 38)

    frame.Castbar.Text:ClearAllPoints()
    frame.Castbar.Text:SetPoint("LEFT", frame.Castbar.IconHolder, "RIGHT", castbarPlacement == "INSIDE" and 4 or 6, 0)
    frame.Castbar.Text:SetPoint("RIGHT", frame.Castbar.Time, "LEFT", castbarPlacement == "INSIDE" and -4 or -7, 0)
    frame.Castbar.Text:SetFont(FONT, castbarPlacement == "INSIDE" and 8 or 10, "OUTLINE")

    SetElementEnabled(frame, "Castbar", showCastbar)
    if not showCastbar then
        frame.Castbar:Hide()
    end

    ApplyVisualStyle(frame, cfg)

    if frame.UpdateAllElements then
        frame:UpdateAllElements("RexUI_ApplyLayout")
    end

    UpdateFrameHints(frame)
end

local function PositionFrame(frame, cfg)
    if not frame or not cfg then return end
    frame:ClearAllPoints()
    frame:SetPoint(cfg.point or "CENTER", UIParent, cfg.relPoint or cfg.point or "CENTER", cfg.x or 0, cfg.y or 0)
end

local function SetFrameCenterPosition(frame, saveKey, x, y, shouldSave)
    if not frame then return end

    local fx = math.floor((x or 0) + 0.5)
    local fy = math.floor((y or 0) + 0.5)

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", fx, fy)

    local cfg = GetFrameConfig(frame)
    if cfg then
        cfg.point = "CENTER"
        cfg.relPoint = "CENTER"
        cfg.x = fx
        cfg.y = fy
    end

    if shouldSave then
        UF:Save(saveKey, "point", "CENTER")
        UF:Save(saveKey, "relPoint", "CENTER")
        UF:Save(saveKey, "x", fx)
        UF:Save(saveKey, "y", fy)
    end
end

local function GetMoverCenterPosition(mover)
    if not mover then return 0, 0 end

    local x, y = mover:GetCenter()
    local cx, cy = UIParent:GetCenter()
    if not x or not cx then return 0, 0 end

    return x - cx, y - cy
end

local function IsAccessibleNumber(value)
    if type(value) ~= "number" then return false end
    return not canaccessvalue or canaccessvalue(value)
end

local function PositionMoverFromConfig(mover, cfg)
    if not mover or not cfg then return false end

    local scale = tonumber(cfg.scale) or 1
    local width = tonumber(cfg.width) or 220
    local healthHeight = tonumber(cfg.healthHeight) or tonumber(cfg.height) or 40
    local powerHeight = tonumber(cfg.powerHeight) or 0
    local height = healthHeight + (powerHeight > 0 and powerHeight + 1 or 0)

    mover:ClearAllPoints()
    mover:SetScale(scale)
    mover:SetSize(width, height)
    mover:SetPoint(cfg.point or "CENTER", UIParent,
        cfg.relPoint or cfg.point or "CENTER", tonumber(cfg.x) or 0, tonumber(cfg.y) or 0)
    return true
end

local function PositionDebuffMoverFromConfig(mover, cfg, saveKey)
    local unitMover = movers[saveKey]
    if not mover or not cfg or not unitMover then return false end

    PositionMoverFromConfig(unitMover, cfg)
    local size = tonumber(cfg.debuffSize) or 20
    local rows = math.max(1, tonumber(cfg.debuffRows) or 1)
    local height = (size * rows) + (3 * (rows - 1))

    mover:ClearAllPoints()
    mover:SetScale(tonumber(cfg.scale) or 1)
    mover:SetSize(tonumber(cfg.width) or 220, height)
    mover:SetPoint("TOPLEFT", unitMover, "BOTTOMLEFT",
        tonumber(cfg.debuffX) or 0, tonumber(cfg.debuffY) or -4)
    return true
end

-- Mover duerfen in WoW 12 nicht von geschuetzten oUF-Frames abhaengen.
-- Darum spiegeln wir die Bildschirmposition absolut auf UIParent, anstatt
-- den Mover direkt an das Unitframe oder dessen Aura-Container zu haengen.
local function PositionMoverOverRegion(mover, region)
    if not mover or not region then return false end

    local left, bottom = region:GetLeft(), region:GetBottom()
    local width, height = region:GetWidth(), region:GetHeight()
    if not IsAccessibleNumber(left) or not IsAccessibleNumber(bottom)
        or not IsAccessibleNumber(width) or not IsAccessibleNumber(height) then
        return false
    end

    local regionScale = region:GetEffectiveScale()
    local parentScale = UIParent:GetEffectiveScale()
    if not IsAccessibleNumber(regionScale) or not IsAccessibleNumber(parentScale)
        or parentScale == 0 then
        return false
    end
    local scaleRatio = regionScale / parentScale

    mover:ClearAllPoints()
    mover:SetScale(1)
    mover:SetSize(math.max(1, width * scaleRatio), math.max(1, height * scaleRatio))
    mover:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * scaleRatio, bottom * scaleRatio)
    return true
end

local function CreateMover(frame, label, saveKey)
    if not frame or movers[saveKey] then return end

    local mover = CreateFrame("Frame", nil, UIParent)
    mover:SetFrameLevel(500)
    local cfg = GetFrameConfig(frame)
    mover:SetSize(tonumber(cfg and cfg.width) or 150,
        cfg and ((tonumber(cfg.healthHeight) or tonumber(cfg.height) or 40)
            + ((tonumber(cfg.powerHeight) or 0) > 0 and (tonumber(cfg.powerHeight) + 1) or 0)) or 40)
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
    mover.Label:SetText(T(label))

    mover:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        PositionMoverOverRegion(self, frame)

        local cursorX, cursorY = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale() or 1
        cursorX = cursorX / scale
        cursorY = cursorY / scale

        local startX, startY = GetMoverCenterPosition(self)

        self.dragged = true
        self.startCursorX = cursorX
        self.startCursorY = cursorY
        self.startMoverX = startX
        self.startMoverY = startY

        self:SetScript("OnUpdate", function(button)
            local currentX, currentY = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale() or 1
            currentX = currentX / scale
            currentY = currentY / scale

            local nextX = button.startMoverX + (currentX - button.startCursorX)
            local nextY = button.startMoverY + (currentY - button.startCursorY)

            SetFrameCenterPosition(frame, saveKey, nextX, nextY, false)
            PositionMoverOverRegion(button, frame)
        end)
    end)

    mover:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if InCombatLockdown() then return end

        if self.startCursorX and self.startCursorY then
            local currentX, currentY = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale() or 1
            currentX = currentX / scale
            currentY = currentY / scale

            local nextX = self.startMoverX + (currentX - self.startCursorX)
            local nextY = self.startMoverY + (currentY - self.startCursorY)

            SetFrameCenterPosition(frame, saveKey, nextX, nextY, true)
            PositionMoverOverRegion(self, frame)
        end

        self.startCursorX = nil
        self.startCursorY = nil
        self.startMoverX = nil
        self.startMoverY = nil
    end)

    mover:SetScript("OnMouseUp", function(self)
        if self.dragged then
            self.dragged = false
            return
        end

        if RexUI.ConfigUI then
            if RexUI.ConfigUI.OpenUnitFrameSettings then
                RexUI.ConfigUI:OpenUnitFrameSettings(saveKey)
            elseif RexUI.ConfigUI.Open then
                RexUI.ConfigUI:Open()
                if RexUI.ConfigUI.SetCategory then RexUI.ConfigUI:SetCategory("UnitFrames") end
            end
        end
    end)

    movers[saveKey] = mover
end

local function GetDebuffAuraFrame(frame)
    return frame and (frame.RexDebuffs or frame.Debuffs)
end

local function CreateDebuffMover(frame, label, saveKey, categoryLabel)
    if not GetDebuffAuraFrame(frame) or debuffMovers[saveKey] then return end

    local mover = CreateFrame("Frame", nil, UIParent)
    mover:SetFrameLevel(500)
    mover:SetSize(120, 20)
    mover:SetClampedToScreen(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:Hide()

    mover.Bg = mover:CreateTexture(nil, "BACKGROUND")
    mover.Bg:SetAllPoints(mover)
    mover.Bg:SetColorTexture(0.85, 0.25, 1, 0.22)

    mover.Label = mover:CreateFontString(nil, "OVERLAY")
    mover.Label:SetFont(FONT, 9, "OUTLINE")
    mover.Label:SetPoint("CENTER")
    mover.Label:SetText(T(label))

    local function UpdateMoverPosition(self, dx, dy)
        local debuffs = GetDebuffAuraFrame(frame)
        if not debuffs then return end
        if not PositionMoverOverRegion(self, debuffs) then
            PositionDebuffMoverFromConfig(self, GetFrameConfig(frame), saveKey)
        end
    end

    mover:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end

        local cfg = GetFrameConfig(frame)
        if not cfg then return end

        local cursorX, cursorY = GetCursorPosition()
        self.dragged = true
        self.startCursorX = cursorX
        self.startCursorY = cursorY
        self.startX = cfg.debuffX or 0
        self.startY = cfg.debuffY or -4

        self:SetScript("OnUpdate", function(button)
            local currentCfg = GetFrameConfig(frame)
            if not currentCfg then return end

            local x, y = GetCursorPosition()
            local scale = frame:GetEffectiveScale() or 1
            local nextX = button.startX + ((x - button.startCursorX) / scale)
            local nextY = button.startY + ((y - button.startCursorY) / scale)

            AnchorDebuffs(frame, currentCfg, nextX, nextY)
            UpdateMoverPosition(button, nextX, nextY)
        end)
    end)

    mover:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if InCombatLockdown() then return end

        local cfg = GetFrameConfig(frame)
        if not cfg or not self.startCursorX or not self.startCursorY then return end

        local x, y = GetCursorPosition()
        local scale = frame:GetEffectiveScale() or 1
        local nextX = math.floor((self.startX + ((x - self.startCursorX) / scale)) + 0.5)
        local nextY = math.floor((self.startY + ((y - self.startCursorY) / scale)) + 0.5)

        UF:Save(saveKey, "debuffX", nextX)
        UF:Save(saveKey, "debuffY", nextY)
        cfg.debuffX = nextX
        cfg.debuffY = nextY
        AnchorDebuffs(frame, cfg)
        UpdateMoverPosition(self, nextX, nextY)
    end)

    mover:SetScript("OnMouseUp", function(self)
        if self.dragged then
            self.dragged = false
            return
        end

        if RexUI.ConfigUI then
            if RexUI.ConfigUI.OpenUnitFrameSettings then
                RexUI.ConfigUI:OpenUnitFrameSettings(saveKey)
            elseif RexUI.ConfigUI.Open then
                RexUI.ConfigUI:Open()
                if RexUI.ConfigUI.SetCategory then RexUI.ConfigUI:SetCategory("UnitFrames") end
            end
        end
    end)

    debuffMovers[saveKey] = mover
end

local function HideBlizzardFrame(frame)
    if not frame then return end

    frame:SetAlpha(0)
    if not InCombatLockdown() then frame:Hide() end
    if frame._rexUFHidden then return end

    frame._rexUFHidden = true
    hooksecurefunc(frame, "Show", function(self)
        self:SetAlpha(0)
        if not InCombatLockdown() then self:Hide() end
    end)
end

function UF:HideBlizzard()
    local cfg = self.Config or self:GetConfig()
    if cfg.hideBlizzard == false then return end

    HideBlizzardFrame(_G.PlayerFrame)
    HideBlizzardFrame(_G.PetFrame)
    HideBlizzardFrame(_G.TargetFrame)
    HideBlizzardFrame(_G.FocusFrame)
    HideBlizzardFrame(_G.BossTargetFrameContainer)

    for i = 1, 5 do
        HideBlizzardFrame(_G["Boss" .. i .. "TargetFrame"])
    end
end

function UF:RegisterStyle()
    if self.styleRegistered or not oUF then return end

    oUF:RegisterStyle(STYLE_NAME, StyleUnitFrame)
    self.styleRegistered = true
end

function UF:CreateFrames(config)
    if not oUF then return end

    self:RegisterStyle()
    oUF:SetActiveStyle(STYLE_NAME)

    local cfg = config or self.Config or DEFAULTS
    for _, key in ipairs({ "player", "pet", "target", "focus" }) do
        local unitCfg = cfg[key] or DEFAULTS[key]
        if unitCfg.enabled ~= false and not frames[key] then
            frames[key] = oUF:Spawn(key, "RexUI_" .. key:sub(1, 1):upper() .. key:sub(2) .. "Frame")
        end
    end

    self.bossFrames = self.bossFrames or {}
    local bossCfg = cfg.boss or DEFAULTS.boss
    local bossCount = bossCfg.enabled == false and 0 or math.max(1, math.min(5, tonumber(bossCfg.count) or 5))
    for i = 1, bossCount do
        if not self.bossFrames[i] then
            local unit = "boss" .. i
            local frame = oUF:Spawn(unit, "RexUI_BossFrame" .. i)
            frames[unit] = frame
            self.bossFrames[i] = frame
        end
    end

    self.created = true
end

local function SetFrameEnabled(frame, enabled)
    if not frame then return end

    frame.rexEnabled = enabled == true

    if enabled then
        if frame.Enable then frame:Enable() end
        SetAlphaIfChanged(frame, 1)
    else
        if frame.Disable then
            frame:Disable()
        else
            frame:Hide()
        end
    end
end

function UF:Apply()
    if InCombatLockdown() then
        self.pendingApply = true
        return
    end

    self.Config = self:GetConfig()
    local cfg = self.Config

    if cfg.enabled == false then
        self:HideMovers()
        for _, frame in pairs(frames) do
            SetFrameEnabled(frame, false)
        end
        return
    end

    self:CreateFrames(cfg)
    self:HideBlizzard()

    for _, key in ipairs({ "player", "pet", "target", "focus" }) do
        local frame = frames[key]
        local unitCfg = cfg[key] or DEFAULTS[key]

        if frame and unitCfg then
            if unitCfg.enabled == false then
                SetFrameEnabled(frame, false)
            else
                ApplyFrameLayout(frame, unitCfg)
                PositionFrame(frame, unitCfg)
                SetFrameEnabled(frame, true)
                UpdateFrameHints(frame)
                local label = frame.unitKey == "player" and "Spieler" or frame.unitKey == "pet" and "Begleiter" or frame.unitKey == "target" and "Ziel" or "Fokus"
                CreateMover(frame, label, key)
                if key == "target" or key == "focus" then
                    CreateDebuffMover(frame, label .. " Debuffs", key, label)
                end
            end
        end
    end

    local bossCfg = cfg.boss or DEFAULTS.boss
    for i, frame in ipairs(self.bossFrames or {}) do
        if bossCfg.enabled == false or i > (bossCfg.count or 5) then
            SetFrameEnabled(frame, false)
        else
            ApplyFrameLayout(frame, bossCfg)

            if i == 1 then
                PositionFrame(frame, bossCfg)
                CreateMover(frame, "Boss", "boss")
            else
                frame:ClearAllPoints()
                frame:SetPoint("TOP", self.bossFrames[i - 1], "BOTTOM", 0, -(bossCfg.spacing or 12))
            end

            SetFrameEnabled(frame, true)
            UpdateFrameHints(frame)
        end
    end

    if RexUI.Unlocked then
        self:ShowMovers()
    end
end

function UF:UpdateUnit(unit)
    local frame = unit and frames[unit]
    if frame and frame.UpdateAllElements then
        frame:UpdateAllElements("RexUI_UpdateUnit")
    end
end

function UF:RefreshAuras(unit)
    local frame = unit and frames[unit]
    if not frame or not frame.usesNativeAuras then return end

    for _, container in ipairs({ frame.RexDebuffs, frame.RexBuffs }) do
        if container and container:IsShown() then
            pcall(container.SetUnit, container, frame.unit)
            if container.UpdateAllAuras then pcall(container.UpdateAllAuras, container) end
        end
    end
end

function UF:UpdateAll()
    for _, frame in pairs(frames) do
        if frame.UpdateAllElements then
            frame:UpdateAllElements("RexUI_UpdateAll")
        end
        if frame.UpdateTags then frame:UpdateTags() end
    end

end

function UF:RefreshLevelDisplays()
    for _, frame in pairs(frames) do
        if frame.UpdateTags then frame:UpdateTags() end
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(frame) and frame.unit and UnitExists(frame.unit) then
            RexUI:ShowUnitTooltip(frame, frame.unit, "ANCHOR_RIGHT")
        end
    end
end

function UF:UpdateFrameHints()
    for _, frame in pairs(frames) do
        UpdateFrameHints(frame)
    end
end

local function ConfigHeight(cfg)
    if cfg.healthHeight then
        return cfg.healthHeight + ((cfg.powerHeight or 0) > 0 and ((cfg.powerHeight or 0) + 2) or 0)
    end
    return cfg.height or 40
end

function UF:ShowMovers()
    local cfg = self.Config or self:GetConfig()
    if cfg.enabled == false then return end

    for key, mover in pairs(movers) do
        local f = (key == "player" or key == "pet" or key == "target" or key == "focus") and frames[key] or (key == "boss" and self.bossFrames and self.bossFrames[1])
        if f then
            local unitCfg = cfg[key]
            if PositionMoverOverRegion(mover, f) or PositionMoverFromConfig(mover, unitCfg) then
                mover:Show()
            else
                mover:Hide()
            end
        else
            mover:Hide()
        end
    end

    for key, mover in pairs(debuffMovers) do
        local unitCfg = cfg[key]
        if unitCfg and unitCfg.enabled ~= false and unitCfg.showDebuffs == true then
            local f = (key == "player" or key == "target" or key == "focus") and frames[key]
            local debuffs = GetDebuffAuraFrame(f)
            if debuffs then
                if PositionMoverOverRegion(mover, debuffs)
                    or PositionDebuffMoverFromConfig(mover, unitCfg, key) then
                    mover:Show()
                else
                    mover:Hide()
                end
            end
        else
            mover:Hide()
        end
    end
end

function UF:HideMovers()
    for _, mover in pairs(movers) do
        mover:Hide()
    end

    for _, mover in pairs(debuffMovers) do
        mover:Hide()
    end
end

local rangeTickElapsed = 0

local function NeedsFrameHintPolling()
    if InCombatLockdown and InCombatLockdown() then return true end
    if UnitExists("target") or UnitExists("focus") then return true end

    for i = 1, 5 do
        if UnitExists("boss" .. i) then return true end
    end

    return false
end

local function FrameHintOnUpdate(self, elapsed)
    rangeTickElapsed = rangeTickElapsed + elapsed
    if rangeTickElapsed < 0.75 then return end
    rangeTickElapsed = 0
    UF:UpdateFrameHints()
end

local function UpdateFrameHintPolling()
    if not eventFrame then return end

    if NeedsFrameHintPolling() then
        if not eventFrame.rexFrameHintPolling then
            eventFrame:SetScript("OnUpdate", FrameHintOnUpdate)
            eventFrame.rexFrameHintPolling = true
        end
    elseif eventFrame.rexFrameHintPolling then
        eventFrame:SetScript("OnUpdate", nil)
        eventFrame.rexFrameHintPolling = nil
        rangeTickElapsed = 0
    end
end

local pendingPlayerPortraitRefresh = true
local waitingForReadyApply = false
local readyApplyFallbackUsed = false
local coldStartPlayerRefreshQueued = false

-- Config "Level anzeigen" only calls UF:Apply(). Reload is ready at PEW+1 frame;
-- cold start is not. After the portrait rebuild, run that same Apply once the
-- world is actually shown.
local function ApplyPlayerFrameLayout()
    if InCombatLockdown and InCombatLockdown() then
        UF.pendingApply = true
        return false
    end
    UF:Apply()
    return true
end

local function QueueColdStartPlayerRefresh()
    if coldStartPlayerRefreshQueued then return end
    coldStartPlayerRefreshQueued = true

    local function refresh()
        ApplyPlayerFrameLayout()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(2, refresh)
    else
        refresh()
    end
end

local function RunReadyApply()
    if not waitingForReadyApply then
        return
    end
    waitingForReadyApply = false
    ApplyPlayerFrameLayout()
end

local function ArmReadyApply()
    waitingForReadyApply = true
    if readyApplyFallbackUsed then
        return
    end
    readyApplyFallbackUsed = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, RunReadyApply)
    end
end

local function RefreshPlayerPortrait()
    local frame = frames.player
    local portrait = frame and frame.Portrait
    if not frame then
        return false
    end

    if portrait and (not frame.IsElementEnabled or frame:IsElementEnabled("Portrait")) then
        if InCombatLockdown and InCombatLockdown() then
            pendingPlayerPortraitRefresh = true
            return false
        end

        if frame.Disable then
            frame:Disable()
        else
            frame:Hide()
        end
        ApplyPortraitModel(portrait, frame.unit or "player")
        if frame.PortraitHolder then
            frame.PortraitHolder:Show()
        end
        if frame.Enable then
            frame:Enable()
        else
            frame:Show()
        end
    end

    pendingPlayerPortraitRefresh = false
    ApplyPlayerFrameLayout()
    ArmReadyApply()
    return true
end

local function QueuePlayerPortraitRefresh()
    local function run()
        if RefreshPlayerPortrait() then
            pendingPlayerPortraitRefresh = false
        else
            pendingPlayerPortraitRefresh = true
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, run)
    else
        run()
    end
end

local function OnEvent(_, event, arg1)
    if event == "PLAYER_REGEN_ENABLED" then
        if UF.pendingApply then
            UF.pendingApply = false
            UF:Apply()
        end
        if pendingPlayerPortraitRefresh and RefreshPlayerPortrait() then
            pendingPlayerPortraitRefresh = false
        end
        RunReadyApply()
    elseif event == "PLAYER_ENTERING_WORLD" then
        UF:Apply()
        if pendingPlayerPortraitRefresh then
            QueuePlayerPortraitRefresh()
        end
    elseif event == "LOADING_SCREEN_DISABLED" then
        RunReadyApply()
        QueueColdStartPlayerRefresh()
    elseif event == "UNIT_PET" and arg1 == "player" then
        UF:HideBlizzard()
    elseif event == "UNIT_LEVEL" or event == "PLAYER_LEVEL_UP" or event == "UPDATE_MOUSEOVER_UNIT" then
        UF:RefreshLevelDisplays()
    elseif event == "PLAYER_TARGET_CHANGED" then
        UF:RefreshAuras("target")
        UF:UpdateFrameHints()
    elseif event == "PLAYER_FOCUS_CHANGED" then
        UF:RefreshAuras("focus")
        UF:UpdateFrameHints()
    else
        UF:UpdateFrameHints()
    end

    UpdateFrameHintPolling()
end

function UF:RegisterEvents()
    if eventFrame then return end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("LOADING_SCREEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
    eventFrame:RegisterEvent("READY_CHECK")
    eventFrame:RegisterEvent("READY_CHECK_CONFIRM")
    eventFrame:RegisterEvent("READY_CHECK_FINISHED")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterUnitEvent("UNIT_LEVEL", "player", "pet", "target", "focus", "boss1", "boss2", "boss3", "boss4", "boss5")
    eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    eventFrame:RegisterUnitEvent("UNIT_PET", "player")
    eventFrame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", "target", "focus", "boss1", "boss2", "boss3", "boss4", "boss5")
    eventFrame:RegisterUnitEvent("UNIT_THREAT_LIST_UPDATE", "target", "focus", "boss1", "boss2", "boss3", "boss4", "boss5")
    eventFrame:SetScript("OnEvent", OnEvent)
    UpdateFrameHintPolling()
end

function UF:Initialize()
    if self.initialized then return end
    self.initialized = true

    if not oUF then return end

    self:RegisterEvents()
    self:Apply()
end
