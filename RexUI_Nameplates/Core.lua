-- ============================================================
-- RexUI - Nameplates / Final
-- Complete profile-driven system with lifecycle, colors, casts, pooled
-- auras, independent indicators and live configuration.
-- ============================================================

local ADDON_NAME, ns = ...

local RexUI = ns.RexUI
if not RexUI then
    return
end

local Nameplates = RexUI.Nameplates
local Perf = RexUI.Perf

local CreateFrame = CreateFrame
local CreateFramePool = CreateFramePool
local InCombatLockdown = InCombatLockdown
local UnitCanAttack = UnitCanAttack
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitHealthPercent = UnitHealthPercent
local UnitClassification = UnitClassification
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local UnitEffectiveLevel = UnitEffectiveLevel
local UnitLevel = UnitLevel
local UnitGUID = UnitGUID
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitHasPowerType = UnitHasPowerType
local UnitIsLieutenant = UnitIsLieutenant
local UnitIsTapDenied = UnitIsTapDenied
local UnitIsUnit = UnitIsUnit
local UnitName = UnitName
local UnitReaction = UnitReaction
local UnitSelectionColor = UnitSelectionColor
local UnitAffectingCombat = UnitAffectingCombat
local UnitThreatSituation = UnitThreatSituation
local GetRaidTargetIndex = GetRaidTargetIndex
local SetRaidTargetIconTexture = SetRaidTargetIconTexture
local AbbreviateNumbers = AbbreviateNumbers

local NP = Nameplates.Internal
local BASE_BORDER = NP.BASE_BORDER
local CAST_COLORS = NP.CAST_COLORS
local ENEMY_HEALTH_HEIGHT = NP.ENEMY_HEALTH_HEIGHT
local FRIENDLY_HEALTH_HEIGHT = NP.FRIENDLY_HEALTH_HEIGHT
local FRIENDLY_WIDTH = NP.FRIENDLY_WIDTH
local HEALTH_COLORS = NP.HEALTH_COLORS
local NON_TARGET_ALPHA = NP.NON_TARGET_ALPHA
local PLATE_HEIGHT = NP.PLATE_HEIGHT
local PLATE_WIDTH = NP.PLATE_WIDTH
local STATUS_TEXTURE = NP.STATUS_TEXTURE
local TARGET_COLOR = NP.TARGET_COLOR
local TARGET_SCALE = NP.TARGET_SCALE
local NAMEPLATE_MEDIA = NP.NAMEPLATE_MEDIA
local FOREVER_CLIENT = (function()
    local toc = select(4, GetBuildInfo()) or 0
    return toc >= 16000 and toc < 20000
end)()

local enemyByUnit = {}
local friendlyByUnit = {}
local visibleUnits = {}
local plateByNative = setmetatable({}, { __mode = "k" })
local nativeFrameState = setmetatable({}, { __mode = "k" })
local hiddenBlizzardHolder = CreateFrame("Frame")
hiddenBlizzardHolder:Hide()
local activeCasts = {}

-- Startzustand: tiefe Kopie der Datenbank-Standardwerte, bis Apply() das Profil setzt.
local function CopyDefaults(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = type(value) == "table" and CopyDefaults(value) or value
    end
    return copy
end
Nameplates.settings = CopyDefaults(RexUI.defaults and RexUI.defaults.profile and RexUI.defaults.profile.nameplates)

local function ApplyIntegrationDefaults(settings)
    if type(settings) ~= "table" then return end
    local function EnsureSection(key)
        if type(settings[key]) ~= "table" then settings[key] = {} end
        return settings[key]
    end
    local function Default(target, key, value)
        if target[key] == nil then target[key] = value end
    end
    local general = EnsureSection("general")
    Default(general, "stacking", true)
    Default(general, "stackSpacing", 1.0)
    Default(general, "hitboxWidth", NP.PLATE_WIDTH)
    Default(general, "hitboxHeight", NP.PLATE_HEIGHT)

    local appearance = EnsureSection("appearance")
    Default(appearance, "borderStyle", "PIXEL")
    Default(appearance, "backgroundColor", { r = 0.03, g = 0.03, b = 0.03, a = 0.90 })
    Default(appearance, "showLevel", true)

    local target = EnsureSection("target")
    Default(target, "arrows", true)
    Default(target, "arrowScale", 1)
    Default(target, "arrowSpacing", 6)
    Default(target, "arrowAlpha", 1)
    Default(target, "arrowStyle", "SINGLE")
    Default(target, "arrowClassColor", false)
    Default(target, "arrowColor", { r = 1, g = 1, b = 1, a = 1 })
    Default(target, "targetOverlayEnabled", false)
    Default(target, "targetOverlayTexture", "striped-v2")
    Default(target, "targetOverlayColor", { r = 1, g = 1, b = 1, a = 1 })
    Default(target, "targetOverlayAlpha", 1)
    Default(target, "focusOverlayEnabled", false)
    Default(target, "focusOverlayTexture", "striped-v2")
    Default(target, "focusOverlayColor", { r = 1, g = 1, b = 1, a = 1 })
    Default(target, "focusOverlayAlpha", 1)
    Default(target, "executeGlowAlpha", 1)

    local castbars = EnsureSection("castbars")
    Default(castbars, "showShield", true)
    Default(castbars, "focusScale", 1)
end

local function Section(name)
    local value = Nameplates.settings and Nameplates.settings[name]
    return type(value) == "table" and value or {}
end

local function Setting(section, key, fallback)
    local value = Section(section)[key]
    if value == nil then return fallback end
    return value
end

local function CopyProfileColor(target, source)
    if type(source) ~= "table" then return end
    target[1] = tonumber(source.r) or target[1]
    target[2] = tonumber(source.g) or target[2]
    target[3] = tonumber(source.b) or target[3]
    target[4] = tonumber(source.a) or target[4] or 1
end

local function SyncConfiguredColors()
    local colors = Section("colors")
    CopyProfileColor(HEALTH_COLORS.enemy, colors.enemy)
    CopyProfileColor(HEALTH_COLORS.neutral, colors.neutral)
    CopyProfileColor(HEALTH_COLORS.friendly, colors.friendly)
    for _, key in ipairs({ "tapped", "important", "boss", "rare", "elite", "caster", "trivial",
        "tankAggro", "tankLosing", "tankNoAggro", "offTank", "tankTakeover", "dpsAggro",
        "threatHigh", "threatLow", "threatNone", "solo", "nonTankTarget", "outOfCombat" }) do
        CopyProfileColor(HEALTH_COLORS[key], colors[key])
    end
    CopyProfileColor(TARGET_COLOR, colors.target)
    CopyProfileColor(CAST_COLORS.normal, colors.castNormal or colors.castInterruptible)
    CopyProfileColor(CAST_COLORS.channel, colors.castChannel)
    CopyProfileColor(CAST_COLORS.empowered, colors.castEmpowered)
    CopyProfileColor(CAST_COLORS.kickReady, colors.castKickReady)
    CopyProfileColor(CAST_COLORS.kickCooldown, colors.castKickCooldown)
    CopyProfileColor(CAST_COLORS.uninterruptible, colors.castProtected)
    CopyProfileColor(CAST_COLORS.important, colors.castImportant)
    CopyProfileColor(CAST_COLORS.interrupted, colors.castInterrupted)
    CopyProfileColor(CAST_COLORS.succeeded, colors.castSucceeded)
    CopyProfileColor(CAST_COLORS.background, colors.castBackground)
end

Nameplates.enemyPlates = enemyByUnit
Nameplates.friendlyPlates = friendlyByUnit

local function CanAccess(value)
    if canaccessvalue then
        return canaccessvalue(value)
    end
    return true
end

local function AccessibleBoolean(value)
    if type(value) ~= "boolean" or not CanAccess(value) then
        return nil
    end
    return value
end

local function IsAttackable(unit)
    local result = UnitCanAttack("player", unit)
    if type(result) == "nil" then
        return false
    end
    if not CanAccess(result) then
        return false
    end
    return result
end

local function IsEnemyPlate(unit)
    if IsAttackable(unit) then return true end
    -- Some neutral NPCs are not attackable until interacted with. Their
    -- reaction still belongs on the neutral/enemy color path.
    if UnitIsPlayer and UnitIsPlayer(unit) then return false end
    local reaction = UnitReaction and UnitReaction(unit, "player")
    return type(reaction) == "number" and CanAccess(reaction) and reaction == 4
end

local function ColorComponents(value, red, green, blue, alpha)
    if type(value) ~= "table" then return red, green, blue, alpha end
    return tonumber(value.r or value[1]) or red,
        tonumber(value.g or value[2]) or green,
        tonumber(value.b or value[3]) or blue,
        tonumber(value.a or value[4]) or alpha
end

local function CreateNineSlice(parent, texturePath, extend, cornerSize, blendMode)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", -extend, extend)
    holder:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", extend, -extend)
    holder:EnableMouse(false)
    if holder.SetMouseMotionEnabled then holder:SetMouseMotionEnabled(false) end

    local textures = {}
    local function NewTexture()
        local texture = holder:CreateTexture(nil, "OVERLAY")
        texture:SetTexture(texturePath)
        if blendMode then texture:SetBlendMode(blendMode) end
        textures[#textures + 1] = texture
        return texture
    end

    local margin = 0.48
    local topLeft = NewTexture(); topLeft:SetSize(cornerSize, cornerSize); topLeft:SetPoint("TOPLEFT"); topLeft:SetTexCoord(0, margin, 0, margin)
    local topRight = NewTexture(); topRight:SetSize(cornerSize, cornerSize); topRight:SetPoint("TOPRIGHT"); topRight:SetTexCoord(1 - margin, 1, 0, margin)
    local bottomLeft = NewTexture(); bottomLeft:SetSize(cornerSize, cornerSize); bottomLeft:SetPoint("BOTTOMLEFT"); bottomLeft:SetTexCoord(0, margin, 1 - margin, 1)
    local bottomRight = NewTexture(); bottomRight:SetSize(cornerSize, cornerSize); bottomRight:SetPoint("BOTTOMRIGHT"); bottomRight:SetTexCoord(1 - margin, 1, 1 - margin, 1)
    local top = NewTexture(); top:SetHeight(cornerSize); top:SetPoint("TOPLEFT", topLeft, "TOPRIGHT"); top:SetPoint("TOPRIGHT", topRight, "TOPLEFT"); top:SetTexCoord(margin, 1 - margin, 0, margin)
    local bottom = NewTexture(); bottom:SetHeight(cornerSize); bottom:SetPoint("BOTTOMLEFT", bottomLeft, "BOTTOMRIGHT"); bottom:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT"); bottom:SetTexCoord(margin, 1 - margin, 1 - margin, 1)
    local left = NewTexture(); left:SetWidth(cornerSize); left:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT"); left:SetPoint("BOTTOMLEFT", bottomLeft, "TOPLEFT"); left:SetTexCoord(0, margin, margin, 1 - margin)
    local right = NewTexture(); right:SetWidth(cornerSize); right:SetPoint("TOPRIGHT", topRight, "BOTTOMRIGHT"); right:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT"); right:SetTexCoord(1 - margin, 1, margin, 1 - margin)
    local center = NewTexture(); center:SetPoint("TOPLEFT", left, "TOPRIGHT"); center:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT"); center:SetTexCoord(margin, 1 - margin, margin, 1 - margin)
    holder.textures = textures
    holder:Hide()
    return holder
end

local function SetNineSliceTexture(holder, texturePath)
    if not holder or holder._texturePath == texturePath then return end
    holder._texturePath = texturePath
    for index = 1, #holder.textures do
        holder.textures[index]:SetTexture(texturePath)
    end
end

local function SetNineSliceColor(holder, red, green, blue, alpha)
    if not holder then return end
    if holder._r == red and holder._g == green and holder._b == blue and holder._a == alpha then
        return
    end
    holder._r, holder._g, holder._b, holder._a = red, green, blue, alpha
    for index = 1, #holder.textures do
        holder.textures[index]:SetVertexColor(red, green, blue, alpha)
    end
end

local executeCurve, executeCurveThreshold

local function ResolveExecuteThreshold()
    return math.max(0.01, math.min(0.99,
        tonumber(Setting("target", "executeThreshold", 0.35)) or 0.35))
end

local function GetExecuteCurve(threshold)
    if executeCurve and executeCurveThreshold == threshold then return executeCurve end
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local curve = C_CurveUtil.CreateColorCurve()
    local epsilon = 0.0001
    curve:AddPoint(0, CreateColor(1, 0.12, 0.04, 1))
    curve:AddPoint(threshold, CreateColor(1, 0.12, 0.04, 1))
    curve:AddPoint(math.min(1, threshold + epsilon), CreateColor(0, 0, 0, 1))
    curve:AddPoint(1, CreateColor(0, 0, 0, 1))
    executeCurve, executeCurveThreshold = curve, threshold
    return curve
end

local function ExecuteGlowAlpha()
    local alpha = tonumber(Setting("target", "executeGlowAlpha", 1)) or 1
    if alpha < 0 then return 0 end
    if alpha > 1 then return 1 end
    return alpha
end

local function CreateExecuteGlowFrame(plate)
    local holder = CreateNineSlice(plate, NAMEPLATE_MEDIA .. "execute-glow.png", 6, 12, "ADD")
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", plate.health, "TOPLEFT", -6, 6)
    holder:SetPoint("BOTTOMRIGHT", plate.health, "BOTTOMRIGHT", 6, -6)
    holder:SetFrameLevel(plate.health:GetFrameLevel() + 5)
    if holder.textures and holder.textures[#holder.textures] then
        holder.textures[#holder.textures]:Hide()
    end
    return holder
end

local function StopExecuteGlowAnimations(frame)
    if not frame then return end
    if frame.SetScript then
        frame:SetScript("OnUpdate", nil)
    end
    if frame.GetAnimationGroups then
        local groups = { frame:GetAnimationGroups() }
        for index = 1, #groups do
            local group = groups[index]
            if group then
                group:Stop()
            end
        end
    end
end

local function EnsureExecuteGlow(plate)
    if plate.executeGlowFill then
        plate.executeGlowFill:Hide()
        plate.executeGlowFill = nil
    end
    if plate.executeGlowFrame and not plate.executeGlowFrame.textures then
        plate.executeGlowFrame:Hide()
        plate.executeGlowFrame = nil
    end
    if not plate.executeGlowFrame then
        -- Static glow never owns an AnimationGroup. Pulse lives on a sibling.
        plate.executeGlowFrame = CreateExecuteGlowFrame(plate)
    end
end

local function EnsureExecuteGlowPulse(plate)
    if plate.executeGlowPulseFrame and plate.executeGlowPulse and plate.executeGlowFade then
        return
    end
    if not plate.executeGlowPulseFrame then
        plate.executeGlowPulseFrame = CreateExecuteGlowFrame(plate)
    end
    local holder = plate.executeGlowPulseFrame
    if not plate.executeGlowPulse then
        local pulse = holder:CreateAnimationGroup()
        pulse:SetLooping("BOUNCE")
        if pulse.SetToFinalAlpha then pulse:SetToFinalAlpha(false) end
        local fade = pulse:CreateAnimation("Alpha")
        fade:SetDuration(0.55)
        if fade.SetSmoothing then fade:SetSmoothing("IN_OUT") end
        plate.executeGlowPulse = pulse
        plate.executeGlowFade = fade
    end
end

local function LayoutExecuteLine(plate)
    if not plate or Setting("target", "executeLine", true) == false then
        if plate and plate.executeLine then plate.executeLine:Hide() end
        if plate then
            plate._executeLineWidth = nil
            plate._executeLineHeight = nil
            plate._executeLineThreshold = nil
        end
        return
    end
    if not plate.executeLineHost then
        local host = CreateFrame("Frame", nil, plate.health)
        host:SetAllPoints(plate.health)
        host:SetFrameLevel(plate.health:GetFrameLevel() + 8)
        host:EnableMouse(false)
        plate.executeLineHost = host
        plate.executeLine = host:CreateTexture(nil, "OVERLAY", nil, 7)
        plate.executeLine:SetColorTexture(1, 0.18, 0.05, 1)
    end
    local width = plate.baseWidth or PLATE_WIDTH
    local height = plate.healthHeight or ENEMY_HEALTH_HEIGHT
    local threshold = ResolveExecuteThreshold()
    if plate._executeLineWidth == width
        and plate._executeLineHeight == height
        and plate._executeLineThreshold == threshold
        and plate.executeLine:IsShown() then
        return
    end
    plate._executeLineWidth = width
    plate._executeLineHeight = height
    plate._executeLineThreshold = threshold
    plate.executeLine:ClearAllPoints()
    plate.executeLine:SetSize(2, height + 2)
    plate.executeLine:SetPoint("CENTER", plate.health, "LEFT", width * threshold, 0)
    plate.executeLineHost:Show()
    plate.executeLine:Show()
end

local function HideExecuteGlow(plate)
    if plate._executeGlowHidden then
        return
    end
    if plate.executeGlowPulse then plate.executeGlowPulse:Stop() end
    StopExecuteGlowAnimations(plate.executeGlowFrame)
    StopExecuteGlowAnimations(plate.executeGlowPulseFrame)
    if plate.executeGlowPulseFrame then plate.executeGlowPulseFrame:Hide() end
    if plate.executeGlowFrame then plate.executeGlowFrame:Hide() end
    if plate.executeGlowFill then plate.executeGlowFill:Hide() end
    plate._executeGlowHidden = true
end

local function PaintExecuteGlow(frame, red, green, blue)
    -- Vertex alpha stays 1. The curve gates via RGB (black = invisible under ADD).
    -- Frame alpha is the only pulse/opacity channel and is never written here.
    SetNineSliceColor(frame, red, green, blue, 1)
    if frame and not frame:IsShown() then
        frame:Show()
    end
end

local function UpdateExecuteGlow(plate, unit)
    if Setting("target", "executeEnabled", false) ~= true then
        HideExecuteGlow(plate)
        return
    end
    plate._executeGlowHidden = nil
    EnsureExecuteGlow(plate)
    local shouldPulse = Setting("target", "executePulse", false) == true
    local glowFrame
    if shouldPulse then
        EnsureExecuteGlowPulse(plate)
        StopExecuteGlowAnimations(plate.executeGlowFrame)
        if plate.executeGlowFrame then plate.executeGlowFrame:Hide() end
        glowFrame = plate.executeGlowPulseFrame
    else
        if plate.executeGlowPulse then plate.executeGlowPulse:Stop() end
        StopExecuteGlowAnimations(plate.executeGlowFrame)
        StopExecuteGlowAnimations(plate.executeGlowPulseFrame)
        if plate.executeGlowPulseFrame then plate.executeGlowPulseFrame:Hide() end
        glowFrame = plate.executeGlowFrame
        if glowFrame then glowFrame:SetAlpha(ExecuteGlowAlpha()) end
    end
    local threshold = ResolveExecuteThreshold()
    local curve = GetExecuteCurve(threshold)
    local painted = false
    if curve and UnitHealthPercent then
        local ok, color = pcall(UnitHealthPercent, unit, true, curve)
        if ok and color and color.GetRGBA then
            local red, green, blue = color:GetRGBA()
            PaintExecuteGlow(glowFrame, red, green, blue)
            painted = true
        end
    end
    if not painted and UnitHealth and UnitHealthMax then
        local health, maximum = UnitHealth(unit), UnitHealthMax(unit)
        if type(health) == "number" and type(maximum) == "number"
            and CanAccess(health) and CanAccess(maximum) and maximum > 0 then
            if health / maximum <= threshold then
                PaintExecuteGlow(glowFrame, 1, 0.12, 0.04)
            else
                PaintExecuteGlow(glowFrame, 0, 0, 0)
            end
        end
    end
    if shouldPulse and plate.executeGlowPulse and plate.executeGlowFade then
        if not plate.executeGlowPulse:IsPlaying() then
            local alpha = ExecuteGlowAlpha()
            plate.executeGlowFade:SetFromAlpha(alpha)
            plate.executeGlowFade:SetToAlpha(alpha * 0.38)
            plate.executeGlowPulse:Play()
        end
    elseif glowFrame then
        -- Show() can resume a leftover Alpha group. Pin the static frame after paint.
        StopExecuteGlowAnimations(glowFrame)
        glowFrame:SetAlpha(ExecuteGlowAlpha())
    end
end

local function UpdateHealth(self)
    local unit = self.unit
    if not unit or not UnitExists(unit) then
        return
    end

    local maximum = UnitHealthMax(unit)
    local current = UnitHealth(unit)
    if type(maximum) == "nil" or type(current) == "nil" then
        return
    end

    -- Midnight can return restricted values here. StatusBar accepts the
    -- values directly; no Lua arithmetic or ordering is performed on them.
    if CanAccess(maximum) and maximum <= 0 then
        maximum = 1
        current = 0
    end
    -- SetMinMaxValues every tick forces a layout pass. Cache the accessible max.
    if CanAccess(maximum) then
        if self._healthMax ~= maximum then
            self._healthMax = maximum
            self.health:SetMinMaxValues(0, maximum)
        end
    else
        self.health:SetMinMaxValues(0, maximum)
    end
    self.health:SetValue(current)

    -- Forever: never attach frames to the health fill texture. At ~0% the fill
    -- width collapses and every child reflow hitchs the whole screen.
    if not FOREVER_CLIENT and Setting("target", "showAbsorb", true) and UnitGetTotalAbsorbs then
        local ok, absorb = pcall(UnitGetTotalAbsorbs, unit)
        local absorbAmount = ok and absorb or 0
        local showAbsorb = absorbAmount
        if type(absorbAmount) == "number" and CanAccess(absorbAmount) then
            showAbsorb = absorbAmount > 0
        elseif type(absorbAmount) ~= "number" then
            showAbsorb = absorbAmount ~= nil
        end
        if showAbsorb then
            if not self.absorbBar then
                self.absorbClip = CreateFrame("Frame", nil, self.health)
                self.absorbClip:SetAllPoints(self.health)
                self.absorbClip:SetClipsChildren(true)
                self.absorbClip:EnableMouse(false)
                self.absorbBar = CreateFrame("StatusBar", nil, self.absorbClip)
                -- Independent bar, not pinned to the fill edge.
                self.absorbBar:SetAllPoints(self.health)
                self.absorbBar:SetStatusBarTexture(NAMEPLATE_MEDIA .. "absorb-default.png")
                self.absorbBar:SetStatusBarColor(0.85, 0.90, 1, 0.35)
                self.absorbBar:SetFrameLevel(self.health:GetFrameLevel() + 1)
                self.absorbBar:EnableMouse(false)
            end
            self.absorbBar:SetMinMaxValues(0, maximum)
            pcall(self.absorbBar.SetValue, self.absorbBar, absorbAmount)
            if not self.absorbBar:IsShown() then
                self.absorbBar:Show()
            end
        elseif self.absorbBar and self.absorbBar:IsShown() then
            self.absorbBar:Hide()
        end
    elseif self.absorbBar and self.absorbBar:IsShown() then
        self.absorbBar:Hide()
    end

    -- Execute line is laid out in ApplyPlateConfiguration, not on every
    -- UNIT_HEALTH (re-anchoring every tick stuttered the screen near execute).
    pcall(UpdateExecuteGlow, self, unit)

    -- Health values may be secret in restricted combat. Like EllesmereUI,
    -- never compare them in Lua: format them only for a FontString display sink.
    local format = Setting("appearance", "healthFormat", "BOTH")
    local currentText = ""
    if format ~= "PERCENT" then
        if AbbreviateNumbers then
            local ok, text = pcall(AbbreviateNumbers, current)
            currentText = (ok and text) or ""
        else
            local ok, text = pcall(string.format, "%s", current)
            currentText = (ok and text) or ""
        end
    end
    local percentText = ""
    local hasPercent = false
    if format ~= "COMPACT"
        and UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        local ok, percent = pcall(UnitHealthPercent, unit, true, CurveConstants.ScaleTo100)
        if ok and type(percent) ~= "nil" then
            local formatted
            ok, formatted = pcall(string.format, "%.0f%%", percent)
            if ok and type(formatted) == "string" then
                percentText = formatted
                hasPercent = true
            end
        end
    end

    if format == "PERCENT" then
        self.healthText:SetText(percentText)
    elseif format == "COMPACT" then
        self.healthText:SetText(currentText)
    elseif format == "PERCENT_COMPACT" then
        if hasPercent then
            self.healthText:SetFormattedText("%s | %s", percentText, currentText)
        else
            self.healthText:SetText(currentText)
        end
    else
        if hasPercent then
            self.healthText:SetFormattedText("%s | %s", currentText, percentText)
        else
            self.healthText:SetText(currentText)
        end
    end
end

local function UpdateName(self)
    local unit = self.unit
    if not unit or not UnitExists(unit) then
        return
    end

    local name = UnitName(unit)
    if type(name) == "nil" then
        name = ""
    end
    self.name:SetFormattedText("%s", name)
end

local function UpdateLevel(self)
    if not self.levelText then
        return
    end
    if Setting("appearance", "showLevel", true) == false then
        if self.levelText:IsShown() then
            self.levelText:Hide()
        end
        return
    end
    local unit = self.unit
    if not unit or not UnitExists(unit) then
        self.levelText:SetText("")
        return
    end
    local level = UnitEffectiveLevel and UnitEffectiveLevel(unit)
    if type(level) == "nil" and UnitLevel then
        level = UnitLevel(unit)
    end
    if type(level) == "nil" then
        self.levelText:SetText("")
        self.levelText:Show()
        return
    end
    if CanAccess(level) then
        if type(level) == "number" and level < 0 then
            self.levelText:SetText("??")
        else
            local ok = pcall(self.levelText.SetFormattedText, self.levelText, "%d", level)
            if not ok then
                self.levelText:SetText("")
            end
        end
        local red, green, blue = 1, 1, 1
        local color
        if GetCreatureDifficultyColor then
            color = GetCreatureDifficultyColor(level)
        elseif GetQuestDifficultyColor then
            color = GetQuestDifficultyColor(level)
        elseif GetDifficultyColor then
            color = GetDifficultyColor(level)
        end
        if type(color) == "table" and CanAccess(color.r) then
            red = tonumber(color.r) or red
            green = tonumber(color.g) or green
            blue = tonumber(color.b) or blue
        end
        self.levelText:SetTextColor(red, green, blue, 1)
    else
        local ok = pcall(self.levelText.SetFormattedText, self.levelText, "%s", level)
        if not ok then
            self.levelText:SetText("")
        end
        self.levelText:SetTextColor(1, 1, 1, 1)
    end
    if not self.levelText:IsShown() then
        self.levelText:Show()
    end
end

local ReclassifyUnit
local ApplyPlateVisualState
local HideStateOverlay

local function PlateOnEvent(self, event)
    if Perf then Perf:Count("Nameplates", "events") end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        self:UpdateHealth()
    elseif event == "UNIT_LEVEL" then
        if self.UpdateLevel then self:UpdateLevel() end
    elseif event == "UNIT_NAME_UPDATE" then
        self:UpdateName()
        if ReclassifyUnit then
            ReclassifyUnit(self.unit)
        end
    elseif event == "UNIT_FLAGS" and ReclassifyUnit then
        if not ReclassifyUnit(self.unit) then
            self:UpdateClassificationState()
            self:UpdateHealthColor()
        end
    elseif event == "UNIT_THREAT_SITUATION_UPDATE"
        or event == "UNIT_THREAT_LIST_UPDATE" then
        -- Dying mobs spam these events. Only recolor — never relayout arrows,
        -- overlays or indicators (that hitch froze the screen at ~0.1% HP).
        self:UpdateHealthColor()
        if ApplyPlateVisualState then ApplyPlateVisualState(self, true) end
    elseif event == "UNIT_FACTION" then
        if not ReclassifyUnit(self.unit) then
            self:UpdateClassificationState()
            self:UpdateHealthColor()
        end
    elseif event == "UNIT_CLASSIFICATION_CHANGED"
        or event == "UNIT_DISPLAYPOWER" then
        self:UpdateClassificationState()
        self:UpdateHealthColor()
        if self.UpdateLevel then self:UpdateLevel() end
        if NP.RefreshPlateIndicators then NP.RefreshPlateIndicators(self, false) end
    end
end

local function BindPlate(self, unit, nativePlate)
    self.unit = unit
    self.nativePlate = nativePlate
    self:SetParent(nativePlate)
    self:ClearAllPoints()
    self:SetPoint("CENTER", nativePlate, "CENTER", 0, 0)
    self._appliedYOffset = nil
    self._visualLayoutKey = nil
    self._appliedScale = nil
    self._healthMax = nil
    self._indicatorLayoutKey = nil
    self._executeGlowHidden = nil
    self._borderR, self._borderG, self._borderB, self._borderA = nil, nil, nil, nil
    self._lastColorReason = nil
    self:SetFrameLevel(nativePlate:GetFrameLevel() + 1)
    if self.indicatorLayer then
        self.indicatorLayer:SetFrameLevel(self:GetFrameLevel() + 20)
    end
    if ApplyPlateConfiguration then ApplyPlateConfiguration(self) end
    self:RegisterUnitEvent("UNIT_HEALTH", unit)
    self:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
    self:RegisterUnitEvent("UNIT_NAME_UPDATE", unit)
    self:RegisterUnitEvent("UNIT_LEVEL", unit)
    self:RegisterUnitEvent("UNIT_FLAGS", unit)
    self:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", unit)
    -- LIST_UPDATE fires on every threat-table tick. Near death that storms
    -- the plate; situation changes are enough for color/border.
    if not FOREVER_CLIENT then
        self:RegisterUnitEvent("UNIT_THREAT_LIST_UPDATE", unit)
    end
    self:RegisterUnitEvent("UNIT_FACTION", unit)
    self:RegisterUnitEvent("UNIT_CLASSIFICATION_CHANGED", unit)
    self:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
    self:UpdateHealth()
    self:UpdateName()
    if self.UpdateLevel then self:UpdateLevel() end
    self:UpdateClassificationState()
    self:UpdateHealthColor()
    if self.kind == "enemy" then
        if NP.RefreshPlateAuras then NP.RefreshPlateAuras(self) end
        if NP.RefreshPlateIndicators then NP.RefreshPlateIndicators(self, true) end
    end
    self:Show()
end

local function UnbindPlate(self)
    if NP.ClearCastState and self.cast then
        NP.ClearCastState(self, true)
    end
    if NP.ClearPlateAuras and (self.debuffRow or self.auraContainers) then
        NP.ClearPlateAuras(self)
    end
    self:UnregisterAllEvents()
    self.health:SetMinMaxValues(0, 1)
    self.health:SetValue(0)
    self.name:SetText("")
    self.healthText:SetText("")
    if self.levelText then
        self.levelText:SetText("")
        self.levelText:Hide()
    end
    self.targetLeft:Hide()
    self.targetRight:Hide()
    HideStateOverlay(self, "target")
    HideStateOverlay(self, "focus")
    HideExecuteGlow(self)
    if self.absorbBar then self.absorbBar:Hide() end
    if self.raidMarker then self.raidMarker:Hide() end
    if self.questIndicator then self.questIndicator:Hide() end
    if self.classIndicator then self.classIndicator:Hide() end
    if self.classIndicator2 then self.classIndicator2:Hide() end
    if self.aggroIndicator then self.aggroIndicator:Hide() end
    self._isTarget = nil
    self._appliedAlpha = nil
    self._visualLayoutKey = nil
    self._appliedScale = nil
    self._healthMax = nil
    self._indicatorLayoutKey = nil
    self._executeGlowHidden = nil
    self._borderR, self._borderG, self._borderB, self._borderA = nil, nil, nil, nil
    self._lastColorReason = nil
    self._colorReason = nil
    self._tapped = nil
    self._lieutenant = nil
    self._bossMob = nil
    self._levelBoss = nil
    self._levelMiniboss = nil
    self._miniboss = nil
    self._classification = nil
    self._isWorldBoss = nil
    self._isRareElite = nil
    self._isElite = nil
    self._isRare = nil
    self._skullBoss = nil
    self._caster = nil
    self._questMob = nil
    self.unit = nil
    self.nativePlate = nil
    self:Hide()
    self:SetParent(UIParent)
    self:ClearAllPoints()
    self:SetAlpha(1)
    self:SetScale(1)
end

local EnemyPlateMixin = {}

function EnemyPlateMixin:SetUnit(unit, nativePlate)
    BindPlate(self, unit, nativePlate)
end

function EnemyPlateMixin:ClearUnit()
    UnbindPlate(self)
end

local FriendlyPlateMixin = {}

function FriendlyPlateMixin:SetUnit(unit, nativePlate)
    BindPlate(self, unit, nativePlate)
end

function FriendlyPlateMixin:ClearUnit()
    UnbindPlate(self)
end

local function CreateEdge(parent, layer)
    local edge = parent:CreateTexture(nil, layer or "OVERLAY")
    edge:SetColorTexture(1, 1, 1, 1)
    return edge
end

local function SetBorderColor(plate, color)
    for index = 1, #plate.border do
        plate.border[index]:SetColorTexture(color[1], color[2], color[3], color[4])
    end
    if plate.assetBorder then
        SetNineSliceColor(plate.assetBorder, color[1], color[2], color[3], color[4])
    end
end

local function ApplyBorderStyle(plate)
    local style = tostring(Setting("appearance", "borderStyle", "PIXEL")):upper()
    local texturePath = NP.BORDER_TEXTURES[style]
    local useAsset = texturePath ~= nil
    for index = 1, #plate.border do plate.border[index]:SetShown(not useAsset) end
    if not useAsset then
        if plate.assetBorder then plate.assetBorder:Hide() end
        return
    end
    if not plate.assetBorder then
        plate.assetBorder = CreateNineSlice(plate.health, texturePath, 2, 8)
        plate.assetBorder:SetFrameLevel(plate.health:GetFrameLevel() + 4)
    else
        SetNineSliceTexture(plate.assetBorder, texturePath)
    end
    plate.assetBorder:Show()
end

local function EnsureStateOverlay(plate, key)
    if plate[key .. "OverlayFill"] then return end
    local fillClip = CreateFrame("Frame", nil, plate.health)
    fillClip:SetClipsChildren(true)
    fillClip:SetFrameLevel(plate.health:GetFrameLevel() + 2)
    fillClip:EnableMouse(false)
    local overlayFill = fillClip:CreateTexture(nil, "ARTWORK")

    -- Forever: never pin clip frames to the health fill texture. At ~0.1%
    -- the fill width collapses and every child reflow freezes the screen.
    if FOREVER_CLIENT then
        fillClip:SetAllPoints(plate.health)
        plate[key .. "OverlayFillClip"] = fillClip
        plate[key .. "OverlayFill"] = overlayFill
        fillClip:Hide()
        return
    end

    local fillTexture = plate.health:GetStatusBarTexture()
    fillClip:SetPoint("TOPLEFT", plate.health, "TOPLEFT", 0, 0)
    fillClip:SetPoint("BOTTOMLEFT", plate.health, "BOTTOMLEFT", 0, 0)
    fillClip:SetPoint("RIGHT", fillTexture, "RIGHT", 0, 0)

    local emptyClip = CreateFrame("Frame", nil, plate.health)
    emptyClip:SetClipsChildren(true)
    emptyClip:SetPoint("TOPRIGHT", plate.health, "TOPRIGHT", 0, 0)
    emptyClip:SetPoint("BOTTOMRIGHT", plate.health, "BOTTOMRIGHT", 0, 0)
    emptyClip:SetPoint("LEFT", fillTexture, "RIGHT", 0, 0)
    emptyClip:SetFrameLevel(plate.health:GetFrameLevel() + 2)
    emptyClip:EnableMouse(false)
    local overlayEmpty = emptyClip:CreateTexture(nil, "ARTWORK")

    plate[key .. "OverlayFillClip"] = fillClip
    plate[key .. "OverlayEmptyClip"] = emptyClip
    plate[key .. "OverlayFill"] = overlayFill
    plate[key .. "OverlayEmpty"] = overlayEmpty
    fillClip:Hide()
    emptyClip:Hide()
end

local function LayoutStateOverlay(plate, key, texturePath, color, alpha)
    EnsureStateOverlay(plate, key)
    local fill = plate[key .. "OverlayFill"]
    local empty = plate[key .. "OverlayEmpty"]
    local nativeWidth = NP.STRIPE_NATIVE_WIDTH or 200
    local crop = math.min(1, (plate.baseWidth or PLATE_WIDTH) / nativeWidth)
    local red, green, blue = ColorComponents(color, 1, 1, 1, 1)
    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", plate.health, "TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMRIGHT", plate.health, "BOTTOMRIGHT", 0, 0)
    fill:SetTexCoord(0, crop, 0, 1)
    fill:SetTexture(texturePath)
    fill:SetVertexColor(red, green, blue, 1)
    fill:SetAlpha(alpha)
    plate[key .. "OverlayFillClip"]:Show()
    if FOREVER_CLIENT or not empty then
        if plate[key .. "OverlayEmptyClip"] then
            plate[key .. "OverlayEmptyClip"]:Hide()
        end
        return
    end
    empty:ClearAllPoints()
    empty:SetPoint("TOPLEFT", plate.health, "TOPLEFT", 0, 0)
    empty:SetPoint("BOTTOMRIGHT", plate.health, "BOTTOMRIGHT", 0, 0)
    empty:SetTexCoord(0, crop, 0, 1)
    empty:SetTexture(texturePath)
    empty:SetVertexColor(red, green, blue, 1)
    empty:SetAlpha(alpha * (tonumber(Setting("target", key .. "OverlayEmptyMultiplier", 0.3)) or 0.3))
    plate[key .. "OverlayEmptyClip"]:Show()
end

HideStateOverlay = function(plate, key)
    local fillClip = plate[key .. "OverlayFillClip"]
    if fillClip then
        fillClip:Hide()
    end
    if plate[key .. "OverlayEmptyClip"] then
        plate[key .. "OverlayEmptyClip"]:Hide()
    end
end

local function ApplyStateOverlays(plate, isTarget, isFocus)
    -- Explicit priority: Target > Focus > normal. A plate can never render
    -- both overlays simultaneously when target and focus are the same unit.
    if isTarget and Setting("target", "targetOverlayEnabled", false) then
        local texture = NP.OVERLAY_TEXTURES[Setting("target", "targetOverlayTexture", "striped-v2")]
        if texture then
            LayoutStateOverlay(plate, "target", texture,
                Setting("target", "targetOverlayColor", nil),
                tonumber(Setting("target", "targetOverlayAlpha", 1)) or 1)
        end
        HideStateOverlay(plate, "focus")
    elseif isFocus and Setting("target", "focusOverlayEnabled", false) then
        local texture = NP.OVERLAY_TEXTURES[Setting("target", "focusOverlayTexture", "striped-v2")]
        if texture then
            LayoutStateOverlay(plate, "focus", texture,
                Setting("target", "focusOverlayColor", nil),
                tonumber(Setting("target", "focusOverlayAlpha", 1)) or 1)
        end
        HideStateOverlay(plate, "target")
    else
        HideStateOverlay(plate, "target")
        HideStateOverlay(plate, "focus")
    end
end

local function VisibleAuraWidth(row, size, spacing)
    if not row or not row.slots then return 0 end
    local shown = math.max(0, tonumber(row.visibleCount) or 0)
    if shown == 0 then return 0 end
    return shown * size + (shown - 1) * spacing
end

local function RefreshSideLayout(plate)
    if not plate or not plate.health then return end
    local targetSettings = Section("target")
    local auraSettings = Section("auras")
    local castSettings = Section("castbars")
    local leftExtent, rightExtent = 0, 0
    local sideGap = math.max(0, tonumber(targetSettings.arrowSpacing) or 6)

    if plate.cast and plate.isCasting and castSettings.showIcon ~= false then
        local reserve = math.max(10, math.min(32, tonumber(castSettings.iconSize) or 15)) + 3
        if castSettings.iconSide == "RIGHT" then rightExtent = reserve else leftExtent = reserve end
    end

    local function AddAura(position, row, sizeKey, spacingKey, enabled)
        if not enabled or (position ~= "LEFT" and position ~= "RIGHT") then return end
        -- Only visible auras reserve space. Empty engine containers stay sized
        -- for their max slots and used to shove the arrows far off the plate.
        local size = math.max(12, math.min(40, tonumber(auraSettings[sizeKey] or auraSettings.size) or NP.AURA_ICON_SIZE))
        local spacing = math.max(0, math.min(12, tonumber(auraSettings[spacingKey]) or NP.AURA_ICON_SPACING))
        local width = VisibleAuraWidth(row, size, spacing)
        if position == "LEFT" then leftExtent = math.max(leftExtent, width) else rightExtent = math.max(rightExtent, width) end
    end
    AddAura(auraSettings.debuffPosition or "TOP", plate.debuffRow,
        "debuffSize", "debuffSpacing",
        auraSettings.debuffs or auraSettings.ownDebuffs or auraSettings.important)
    AddAura(auraSettings.buffPosition or "LEFT", plate.buffRow,
        "buffSize", "buffSpacing", auraSettings.buffs)
    AddAura(auraSettings.ccPosition or "RIGHT", plate.ccRow,
        "ccSize", "ccSpacing", auraSettings.crowdControl)

    if plate.levelText and plate.levelText:IsShown() then
        rightExtent = math.max(rightExtent, 20)
    end

    local arrowScale = math.max(0.5, math.min(3, tonumber(targetSettings.arrowScale) or 1))
    local arrowHeight = math.floor(16 * arrowScale + 0.5)
    local doubleArrows = targetSettings.arrowStyle == "DOUBLE"
    local leftWidth = math.max(1, math.floor(((doubleArrows and 72 or 43) / 66) * arrowHeight + 0.5))
    local rightWidth = math.max(1, math.floor(((doubleArrows and 72 or 36) / 66) * arrowHeight + 0.5))
    -- Never measure the restricted nameplate subtree. The configured height
    -- cached by ApplyPlateConfiguration is a plain profile number.
    local verticalOffset = (arrowHeight - (plate.healthHeight or ENEMY_HEALTH_HEIGHT)) / 2
    plate.targetLeft:ClearAllPoints()
    plate.targetLeft:SetPoint("TOP", plate.health, "TOPLEFT", -(leftExtent + sideGap + leftWidth / 2), verticalOffset)
    plate.targetLeft:SetPoint("BOTTOM", plate.health, "BOTTOMLEFT", -(leftExtent + sideGap + leftWidth / 2), -verticalOffset)
    plate.targetLeft:SetWidth(leftWidth)
    plate.targetRight:ClearAllPoints()
    plate.targetRight:SetPoint("TOP", plate.health, "TOPRIGHT", rightExtent + sideGap + rightWidth / 2, verticalOffset)
    plate.targetRight:SetPoint("BOTTOM", plate.health, "BOTTOMRIGHT", rightExtent + sideGap + rightWidth / 2, -verticalOffset)
    plate.targetRight:SetWidth(rightWidth)
end
NP.RefreshSideLayout = RefreshSideLayout

local function CreateMinimalPlate(plate, mixin, width, healthHeight, healthYOffset, red, green, blue)
    Mixin(plate, mixin)
    plate:SetSize(width, PLATE_HEIGHT)
    plate.baseWidth = width
    plate:EnableMouse(false)
    if plate.SetMouseMotionEnabled then
        plate:SetMouseMotionEnabled(false)
    end

    plate.health = CreateFrame("StatusBar", nil, plate)
    plate.health:SetPoint("CENTER", plate, "CENTER", 0, healthYOffset)
    plate.health:SetSize(width, healthHeight)
    plate.health:SetStatusBarTexture(STATUS_TEXTURE)
    plate.health:SetStatusBarColor(red, green, blue, 1)
    plate.health:EnableMouse(false)

    plate.background = plate.health:CreateTexture(nil, "BACKGROUND")
    plate.background:SetAllPoints()
    plate.background:SetColorTexture(0.03, 0.03, 0.03, 0.90)

    plate.border = {
        CreateEdge(plate.health), CreateEdge(plate.health),
        CreateEdge(plate.health), CreateEdge(plate.health),
    }
    local top, bottom, left, right = unpack(plate.border)
    top:SetPoint("BOTTOMLEFT", plate.health, "TOPLEFT", -1, 0)
    top:SetPoint("BOTTOMRIGHT", plate.health, "TOPRIGHT", 1, 0)
    top:SetHeight(1)
    bottom:SetPoint("TOPLEFT", plate.health, "BOTTOMLEFT", -1, 0)
    bottom:SetPoint("TOPRIGHT", plate.health, "BOTTOMRIGHT", 1, 0)
    bottom:SetHeight(1)
    left:SetPoint("TOPRIGHT", plate.health, "TOPLEFT", 0, 1)
    left:SetPoint("BOTTOMRIGHT", plate.health, "BOTTOMLEFT", 0, -1)
    left:SetWidth(1)
    right:SetPoint("TOPLEFT", plate.health, "TOPRIGHT", 0, 1)
    right:SetPoint("BOTTOMLEFT", plate.health, "BOTTOMRIGHT", 0, -1)
    right:SetWidth(1)
    SetBorderColor(plate, BASE_BORDER)

    plate.name = plate.health:CreateFontString(nil, "OVERLAY")
    plate.name:SetFont("Interface\\AddOns\\RexUI\\media\\fonts\\Expressway.TTF", 9, "OUTLINE")
    plate.name:SetPoint("LEFT", plate.health, "LEFT", 2, 0.5)
    plate.name:SetWidth(80)
    plate.name:SetJustifyH("LEFT")
    plate.name:SetTextColor(1, 1, 1, 1)
    plate.name:SetWordWrap(false)
    plate.name:SetMaxLines(1)

    plate.healthText = plate.health:CreateFontString(nil, "OVERLAY")
    plate.healthText:SetFont("Interface\\AddOns\\RexUI\\media\\fonts\\Expressway.TTF", 9, "OUTLINE")
    plate.healthText:SetPoint("RIGHT", plate.health, "RIGHT", 0, 0.5)
    plate.healthText:SetWidth(68)
    plate.healthText:SetJustifyH("RIGHT")
    plate.healthText:SetTextColor(0.9, 0.9, 0.9, 1)
    plate.healthText:SetWordWrap(false)
    plate.healthText:SetMaxLines(1)

    -- Outside the bar, in the gap before the right target arrow.
    plate.levelText = plate:CreateFontString(nil, "OVERLAY")
    plate.levelText:SetFont("Interface\\AddOns\\RexUI\\media\\fonts\\Expressway.TTF", 10, "OUTLINE")
    plate.levelText:SetPoint("LEFT", plate.health, "RIGHT", 4, 0.5)
    plate.levelText:SetWidth(24)
    plate.levelText:SetJustifyH("LEFT")
    plate.levelText:SetTextColor(1, 1, 1, 1)
    plate.levelText:SetWordWrap(false)
    plate.levelText:SetMaxLines(1)

    local arrowParent = plate.health
    local ok, arrowHost = pcall(CreateFrame, "Frame", nil, plate.health,
        "DisableUntrustedLayoutScriptsTemplate")
    if ok and arrowHost then
        arrowHost:SetAllPoints(plate.health)
        arrowHost:SetFrameLevel(plate.health:GetFrameLevel())
        plate.arrowHost = arrowHost
        arrowParent = arrowHost
    end

    plate.targetLeft = arrowParent:CreateTexture(nil, "OVERLAY")
    plate.targetLeft:SetTexture(NAMEPLATE_MEDIA .. "arrow_left.png")
    plate.targetLeft:SetVertexColor(TARGET_COLOR[1], TARGET_COLOR[2], TARGET_COLOR[3], 1)
    plate.targetLeft:Hide()

    plate.targetRight = arrowParent:CreateTexture(nil, "OVERLAY")
    plate.targetRight:SetTexture(NAMEPLATE_MEDIA .. "arrow_right.png")
    plate.targetRight:SetVertexColor(TARGET_COLOR[1], TARGET_COLOR[2], TARGET_COLOR[3], 1)
    plate.targetRight:Hide()
    RefreshSideLayout(plate)

    plate.UpdateHealth = UpdateHealth
    plate.UpdateName = UpdateName
    plate.UpdateLevel = UpdateLevel
    plate.UpdateClassificationState = NP.UpdateClassificationState
    plate.UpdateHealthColor = NP.UpdateHealthColor
    plate:SetScript("OnEvent", PlateOnEvent)
end

ApplyPlateConfiguration = function(plate)
    local general = Section("general")
    local appearance = Section("appearance")
    local castbars = Section("castbars")
    local targetSettings = Section("target")
    local enemy = plate.kind == "enemy"
    local width = tonumber(enemy and general.enemyWidth or general.friendlyWidth)
        or (enemy and PLATE_WIDTH or FRIENDLY_WIDTH)
    local healthHeight = tonumber(enemy and general.enemyHealthHeight or general.friendlyHealthHeight)
        or (enemy and ENEMY_HEALTH_HEIGHT or FRIENDLY_HEALTH_HEIGHT)
    width = math.max(70, math.min(240, width))
    healthHeight = math.max(6, math.min(30, healthHeight))
    plate.baseWidth = width
    plate.healthHeight = healthHeight
    plate:SetSize(width, PLATE_HEIGHT)
    plate.health:SetSize(width, healthHeight)
    plate.health:SetStatusBarTexture(appearance.texture or STATUS_TEXTURE)
    plate.name:SetWidth(math.min(80, math.max(35, width - 55)))
    plate.healthText:SetWidth(math.min(68, math.max(48, width - 67)))
    plate.name:SetShown(appearance.showName ~= false)
    plate.healthText:SetShown(appearance.showHealthText ~= false)
    if plate.levelText then
        plate.levelText:SetShown(appearance.showLevel ~= false)
        if plate.UpdateLevel then
            plate:UpdateLevel()
        end
    end
    local friendlyNameOnly = false
    if not enemy then
        local isPlayer = plate.unit and UnitIsPlayer and UnitIsPlayer(plate.unit) == true
        friendlyNameOnly = Setting("general", "friendlyNameOnly", false)
            or (isPlayer and Setting("general", "friendlyPlayersNameOnly", false))
            or (not isPlayer and Setting("general", "friendlyNPCsNameOnly", false))
    end
    if not enemy and friendlyNameOnly then
        plate.health:SetHeight(0.001)
        plate.health:SetAlpha(0)
        plate.healthText:Hide()
        plate.background:SetAlpha(0)
        plate.name:ClearAllPoints()
        plate.name:SetPoint("CENTER", plate, "CENTER", 0, 0)
        plate.name:SetWidth(width)
    else
        plate.health:SetAlpha(1)
        plate.background:SetAlpha(1)
    end

    LayoutExecuteLine(plate)

    -- Eigene Y-Position für freundliche Plaketten
    if plate.nativePlate then
        local yOffset = (not enemy) and (tonumber(Setting("general", "friendlyYOffset", 0)) or 0) or 0
        if plate._appliedYOffset ~= yOffset then
            plate._appliedYOffset = yOffset
            plate:ClearAllPoints()
            plate:SetPoint("CENTER", plate.nativePlate, "CENTER", 0, yOffset)
        end
    end
    local backgroundRed, backgroundGreen, backgroundBlue, backgroundAlpha =
        ColorComponents(appearance.backgroundColor, 0.03, 0.03, 0.03,
            tonumber(appearance.backgroundAlpha) or 0.90)
    backgroundAlpha = tonumber(appearance.backgroundAlpha) or backgroundAlpha
    plate.background:SetColorTexture(backgroundRed, backgroundGreen, backgroundBlue, backgroundAlpha)
    -- Fine 1px border: neutral normally, red only while the player has aggro.
    local borderSize = math.max(0, math.min(4, tonumber(appearance.borderSize) or 1))
    plate.border[1]:SetHeight(borderSize); plate.border[2]:SetHeight(borderSize)
    plate.border[3]:SetWidth(borderSize); plate.border[4]:SetWidth(borderSize)
    ApplyBorderStyle(plate)

    local arrowRed, arrowGreen, arrowBlue, arrowAlpha = ColorComponents(
        targetSettings and targetSettings.arrowColor, TARGET_COLOR[1], TARGET_COLOR[2], TARGET_COLOR[3],
        tonumber(targetSettings and targetSettings.arrowAlpha) or 1)
    arrowAlpha = tonumber(targetSettings and targetSettings.arrowAlpha) or arrowAlpha
    if targetSettings and targetSettings.arrowClassColor and UnitClass then
        local _, classFile = UnitClass("player")
        local classColor = classFile and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)
            and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[classFile]
        if classColor then arrowRed, arrowGreen, arrowBlue = classColor.r, classColor.g, classColor.b end
    end
    plate.targetLeft:SetVertexColor(arrowRed, arrowGreen, arrowBlue, arrowAlpha)
    plate.targetRight:SetVertexColor(arrowRed, arrowGreen, arrowBlue, arrowAlpha)
    local arrowSuffix = targetSettings and targetSettings.arrowStyle == "DOUBLE" and "x2" or ""
    plate.targetLeft:SetTexture(NAMEPLATE_MEDIA .. "arrow_left" .. arrowSuffix .. ".png")
    plate.targetRight:SetTexture(NAMEPLATE_MEDIA .. "arrow_right" .. arrowSuffix .. ".png")

    if plate.cast then
        local castHeight = math.max(7, math.min(24, tonumber(castbars.height) or 11))
        local isFocusPlate = plate.unit and UnitExists("focus") and UnitIsUnit(plate.unit, "focus")
        if isFocusPlate then
            castHeight = tonumber(castbars.focusHeight)
                or (castHeight * (tonumber(castbars.focusScale) or 1))
            castHeight = math.max(7, math.min(36, castHeight))
        end
        local iconSize = math.max(10, math.min(32, tonumber(castbars.iconSize) or 15))
        plate.cast:SetSize(width, castHeight)
        plate.cast:SetStatusBarTexture(castbars.texture or "Interface\\AddOns\\RexUI\\media\\statusbars\\bar_serenity.tga")
        plate.castBackground:SetColorTexture(CAST_COLORS.background[1], CAST_COLORS.background[2], CAST_COLORS.background[3], 0.94)
        if plate.castSpark then
            plate.castSpark:ClearAllPoints()
            plate.castSpark:SetPoint("CENTER", plate.cast:GetStatusBarTexture(), "RIGHT", 0, 0)
            plate.castSpark:SetSize(math.max(6, castHeight * 0.9), castHeight * 2.2)
            plate.castSpark:SetShown(castbars.showSpark ~= false)
        end
        local shieldHeight = math.max(8, castHeight * 0.75)
        local shieldWidth = shieldHeight * (29 / 35)
        plate.castLockText:ClearAllPoints()
        plate.castLockText:SetPoint("LEFT", plate.cast, "LEFT", 3, 0)
        plate.castLockText:SetSize(shieldWidth, shieldHeight)
        plate.castName:ClearAllPoints()
        local shieldReserve = castbars.showShield ~= false and (shieldWidth + 6) or 3
        plate.castName:SetPoint("LEFT", plate.cast, "LEFT", shieldReserve, 0)
        plate.castName:SetWidth(math.max(35, width - 42 - shieldReserve))
        plate.castName:SetShown(castbars.showName ~= false)
        plate.castTime:SetShown(castbars.showTime ~= false)
        plate.castIcon:ClearAllPoints()
        if castbars.iconSide == "RIGHT" then
            plate.castIcon:SetPoint("LEFT", plate.cast, "RIGHT", 3, 0)
        else
            plate.castIcon:SetPoint("RIGHT", plate.cast, "LEFT", -3, 0)
        end
        plate.castIcon:SetSize(iconSize, iconSize)
        plate.castTargetName:SetFont("Interface\\AddOns\\RexUI\\media\\fonts\\Expressway.TTF",
            math.max(7, math.min(16, tonumber(castbars.targetNameSize) or 9)), "OUTLINE")
        plate.castTargetName:SetShown(plate.isCasting and castbars.showTargetName ~= false)
        plate.kickReadyText:SetTextColor(CAST_COLORS.kickReady[1], CAST_COLORS.kickReady[2], CAST_COLORS.kickReady[3], 1)
        plate.kickCooldownText:SetTextColor(CAST_COLORS.kickCooldown[1], CAST_COLORS.kickCooldown[2], CAST_COLORS.kickCooldown[3], 1)
        plate.castShield:SetVertexColor(1, 1, 1, 1)
        for index = 1, #plate.importantCastGlow do
            plate.importantCastGlow[index]:SetColorTexture(CAST_COLORS.important[1], CAST_COLORS.important[2], CAST_COLORS.important[3], 0.85)
        end
        if castbars.showIcon == false then
            plate.castIcon:Hide()
        elseif plate.isCasting then
            plate.castIcon:Show()
        end
        if castbars.enabled == false then NP.ClearCastState(plate) end
    end
    if plate.absorbBar then plate.absorbBar:SetWidth(width) end
    RefreshSideLayout(plate)
end

local function InitializeEnemyPlate(plate)
    CreateMinimalPlate(plate, EnemyPlateMixin, PLATE_WIDTH, ENEMY_HEALTH_HEIGHT, 8, 0.78, 0.16, 0.16)
    NP.CreateCastElements(plate)
    NP.CreateAuraElements(plate)
end

local function InitializeFriendlyPlate(plate)
    CreateMinimalPlate(plate, FriendlyPlateMixin, FRIENDLY_WIDTH, FRIENDLY_HEALTH_HEIGHT, 0, 0.18, 0.68, 0.28)
end

local function ResetPooledPlate(_, plate)
    if plate.unit then
        plate:ClearUnit()
    else
        plate:Hide()
        plate:SetParent(UIParent)
        plate:ClearAllPoints()
    end
end

local enemyPool = CreateFramePool(
    "Frame", UIParent, nil, ResetPooledPlate, false, InitializeEnemyPlate
)
local friendlyPool = CreateFramePool(
    "Frame", UIParent, nil, ResetPooledPlate, false, InitializeFriendlyPlate
)

if Perf and Perf.RegisterGauge then
    local function PoolCounts(pool)
        local active = pool.GetNumActive and pool:GetNumActive() or 0
        local idle = type(pool.inactiveObjects) == "table" and #pool.inactiveObjects or 0
        return active, idle
    end
    Perf:RegisterGauge("Nameplates", function()
        local ea, ei = PoolCounts(enemyPool)
        local fa, fi = PoolCounts(friendlyPool)
        return ea + fa, ei + fi, ea + fa + ei + fi
    end)
end

local function FindPlate(unitToken)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
        return nil
    end
    local nativePlate = C_NamePlate.GetNamePlateForUnit(unitToken)
    return nativePlate and plateByNative[nativePlate] or nil
end

ApplyPlateVisualState = function(plate, paintOnly)
    if not plate or not plate.unit then
        return
    end

    local isTarget = Nameplates.targetPlate == plate
    plate._isTarget = isTarget

    local targetSettings = Section("target")
    local targetScale = tonumber(targetSettings.scale) or TARGET_SCALE
    local isFocus = UnitExists("focus") and UnitIsUnit(plate.unit, "focus")
    local isMouseover = Nameplates.mouseoverPlate == plate
    local scale = 1
    if isTarget then
        scale = targetScale
    elseif isFocus then
        scale = tonumber(targetSettings.focusScale) or 1
    end

    if not paintOnly then
        local layoutKey = (isTarget and "1" or "0")
            .. (isFocus and "1" or "0")
            .. (isMouseover and "1" or "0")
            .. tostring(scale)
        if plate._visualLayoutKey ~= layoutKey then
            plate._visualLayoutKey = layoutKey
            if plate._appliedScale ~= scale then
                plate._appliedScale = scale
                plate:SetScale(scale)
            end
            if isTarget then
                plate.targetLeft:SetShown(targetSettings.arrows ~= false)
                plate.targetRight:SetShown(targetSettings.arrows ~= false)
            else
                plate.targetLeft:Hide()
                plate.targetRight:Hide()
            end
            ApplyStateOverlays(plate, isTarget, isFocus and not isTarget)
            RefreshSideLayout(plate)
        end
    end
    local aggro = false
    local secretAggro, hasSecretAggro
    if plate.kind == "enemy" and Setting("threat", "enabled", true) then
        local isTanking
        if UnitDetailedThreatSituation then
            isTanking = UnitDetailedThreatSituation("player", plate.unit)
        end
        if type(isTanking) == "boolean" then
            if CanAccess(isTanking) then
                aggro = isTanking
            else
                secretAggro = isTanking
                hasSecretAggro = true
            end
        else
            local status = NP.GetThreatStatus(plate.unit)
            if status ~= nil then
                if Nameplates.playerIsTank then
                    aggro = status >= 3
                else
                    aggro = status >= 2
                end
            end
        end
    end

    local colors = Section("colors")
    local borderRed, borderGreen, borderBlue, borderAlpha
    if isMouseover and targetSettings.mouseoverHighlight ~= false and not isTarget then
        local c = colors.mouseover or {}
        borderRed, borderGreen, borderBlue, borderAlpha = c.r or 1, c.g or 0.9, c.b or 0.45, 1
    elseif isFocus and targetSettings.focusBorder ~= false and not isTarget then
        local c = colors.focus or {}
        borderRed, borderGreen, borderBlue, borderAlpha = c.r or 0.35, c.g or 0.75, c.b or 1, 1
    elseif plate._isThreatColor and Setting("threat", "borderColor", false)
        and plate._resolvedRed and plate._resolvedGreen and plate._resolvedBlue then
        borderRed, borderGreen, borderBlue, borderAlpha =
            plate._resolvedRed, plate._resolvedGreen, plate._resolvedBlue, 1
    else
        borderRed, borderGreen, borderBlue, borderAlpha =
            BASE_BORDER[1], BASE_BORDER[2], BASE_BORDER[3], BASE_BORDER[4]
    end

    if Setting("threat", "aggroBorder", true) then
        if aggro then
            borderRed, borderGreen, borderBlue, borderAlpha = 1.00, 0.08, 0.08, 1
        elseif hasSecretAggro and C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
            local evaluate = C_CurveUtil.EvaluateColorValueFromBoolean
            borderRed = evaluate(secretAggro, 1.00, borderRed)
            borderGreen = evaluate(secretAggro, 0.08, borderGreen)
            borderBlue = evaluate(secretAggro, 0.08, borderBlue)
        end
    end
    -- Secret curve colors cannot be compared in Lua (Forever taint).
    local canCache = CanAccess(borderRed) and CanAccess(borderGreen)
        and CanAccess(borderBlue) and CanAccess(borderAlpha)
    if canCache
        and plate._borderR == borderRed and plate._borderG == borderGreen
        and plate._borderB == borderBlue and plate._borderA == borderAlpha then
        return
    end
    if canCache then
        plate._borderR, plate._borderG, plate._borderB, plate._borderA =
            borderRed, borderGreen, borderBlue, borderAlpha
    else
        plate._borderR, plate._borderG, plate._borderB, plate._borderA = nil, nil, nil, nil
    end
    SetBorderColor(plate, { borderRed, borderGreen, borderBlue, borderAlpha })
end

-- Mouseover-Hervorhebung: UPDATE_MOUSEOVER_UNIT meldet nur neue Einheiten,
-- deshalb prüft ein kurzer Ticker, wann die Maus die Plakette verlässt.
local function SetMouseoverPlate(plate)
    local old = Nameplates.mouseoverPlate
    if old == plate then return end
    Nameplates.mouseoverPlate = plate
    if old then ApplyPlateVisualState(old) end
    if plate then ApplyPlateVisualState(plate) end
end

local mouseoverTicker
local function HandleMouseoverChanged()
    if Section("target").mouseoverHighlight == false then
        SetMouseoverPlate(nil)
        return
    end
    local plate = UnitExists("mouseover") and FindPlate("mouseover") or nil
    SetMouseoverPlate(plate)
    if plate and not mouseoverTicker and C_Timer and C_Timer.NewTicker then
        mouseoverTicker = C_Timer.NewTicker(0.2, function()
            local current = Nameplates.mouseoverPlate
            if not current or not current.unit or not UnitExists("mouseover") or not UnitIsUnit(current.unit, "mouseover") then
                SetMouseoverPlate(nil)
                if mouseoverTicker then mouseoverTicker:Cancel() end
                mouseoverTicker = nil
            end
        end)
    end
end

local function ApplyPlateAlpha(plate)
    if not plate or not plate.unit then
        return
    end

    local alpha = 1
    if Nameplates.hasTarget
        and plate ~= Nameplates.targetPlate then
        local keepFocus = Setting("target", "focusKeepAlpha", true)
        if keepFocus and UnitExists("focus") and UnitIsUnit(plate.unit, "focus") then
            alpha = 1
        else
            alpha = tonumber(Section("target").nonTargetAlpha) or NON_TARGET_ALPHA
        end
    end
    if plate._appliedAlpha ~= alpha then
        plate._appliedAlpha = alpha
        plate:SetAlpha(alpha)
    end
end

local function ApplyAllPlateAlpha()
    for _, plate in pairs(enemyByUnit) do
        ApplyPlateAlpha(plate)
    end
    for _, plate in pairs(friendlyByUnit) do
        ApplyPlateAlpha(plate)
    end
end

local function ApplyAllPlateStates()
    for _, plate in pairs(enemyByUnit) do
        ApplyPlateVisualState(plate)
    end
    for _, plate in pairs(friendlyByUnit) do
        ApplyPlateVisualState(plate)
    end
end

local function ReleasePlate(plate)
    if not plate then
        return
    end

    local unit = plate.unit
    local nativePlate = plate.nativePlate
    local registry = plate.kind == "enemy" and enemyByUnit or friendlyByUnit
    local pool = plate.kind == "enemy" and enemyPool or friendlyPool

    if unit and registry[unit] == plate then
        registry[unit] = nil
    end
    if nativePlate and plateByNative[nativePlate] == plate then
        plateByNative[nativePlate] = nil
    end
    if Nameplates.targetPlate == plate then
        Nameplates.targetPlate = nil
    end

    -- Restore Blizzard before detaching and releasing the RexUI object.
    NP.RestoreBlizzardVisuals(nativePlate)
    plate:ClearUnit()
    pool:Release(plate)
end

local function AddPlate(unit)
    if Nameplates.settings.enabled == false then return end
    if type(unit) ~= "string" or not UnitExists(unit) then
        return
    end
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
        return
    end

    local nativePlate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nativePlate then
        return
    end

    local oldUnitPlate = enemyByUnit[unit] or friendlyByUnit[unit]
    if oldUnitPlate then
        if oldUnitPlate.nativePlate == nativePlate then
            return
        end
        ReleasePlate(oldUnitPlate)
    end

    local oldNativePlate = plateByNative[nativePlate]
    if oldNativePlate then
        ReleasePlate(oldNativePlate)
    end

    local isEnemy = IsEnemyPlate(unit)
    if not isEnemy and Setting("general", "showFriendly", true) == false then return end
    local pool = isEnemy and enemyPool or friendlyPool
    local registry = isEnemy and enemyByUnit or friendlyByUnit
    local plate = pool:Acquire()
    plate.kind = isEnemy and "enemy" or "friendly"

    registry[unit] = plate
    plateByNative[nativePlate] = plate
    NP.SuppressBlizzardVisuals(nativePlate)
    plate:SetUnit(unit, nativePlate)

    if UnitIsUnit(unit, "target") then
        Nameplates.targetPlate = plate
    end
    ApplyPlateVisualState(plate)
    ApplyPlateAlpha(plate)
end

ReclassifyUnit = function(unit)
    local plate = enemyByUnit[unit] or friendlyByUnit[unit]
    if not plate then
        return false
    end

    -- Dead/ghost units flip flags right before despawn. Rebuilding the plate
    -- there hitchs the screen; keep the existing object until REMOVED.
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
        return false
    end

    local desiredKind = IsEnemyPlate(unit) and "enemy" or "friendly"
    if desiredKind == plate.kind then
        return false
    end

    -- UNIT_FLAGS can change a plate's hostility (for example a duel). Move
    -- it between the two pools; never mutate one object type into the other.
    ReleasePlate(plate)
    AddPlate(unit)
    return true
end

local function RemovePlate(unit)
    local plate = enemyByUnit[unit] or friendlyByUnit[unit]
    if plate then
        ReleasePlate(plate)
    end
end

local manager = CreateFrame("Frame")

local auraDispatcher = CreateFrame("Frame")
auraDispatcher:RegisterEvent("UNIT_AURA")
auraDispatcher:SetScript("OnEvent", function(_, _, unit, updateInfo)
    if Perf then Perf:Count("Nameplates", "events") end
    local plate = enemyByUnit[unit]
    if plate and not plate.usesAuraContainers and NP.PlateNeedsAuraRefresh(plate, updateInfo) then
        NP.RefreshPlateAuras(plate)
    end
end)

local function RefreshThreatContext()
    NP.RefreshRoleContext()
    for _, plate in pairs(enemyByUnit) do
        plate:UpdateHealthColor()
    end
end

local function HandleTargetChanged()
    local oldTarget = Nameplates.targetPlate
    local oldHasTarget = Nameplates.hasTarget
    local newTarget = FindPlate("target")
    local newHasTarget = UnitExists("target") and true or false

    Nameplates.targetPlate = newTarget
    Nameplates.hasTarget = newHasTarget

    if oldTarget then
        ApplyPlateVisualState(oldTarget)
    end
    if newTarget and newTarget ~= oldTarget then
        ApplyPlateVisualState(newTarget)
    end

    -- Switching between two existing targets touches only old and new.
    -- A full alpha pass is necessary only when target existence toggles,
    -- because every non-target plate changes opacity at that boundary.
    if oldHasTarget ~= newHasTarget then
        ApplyAllPlateAlpha()
    else
        ApplyPlateAlpha(oldTarget)
        ApplyPlateAlpha(newTarget)
    end
end

manager:SetScript("OnEvent", function(_, event, unit)
    if Perf then Perf:Count("Nameplates", "events") end
    if event == "NAME_PLATE_UNIT_ADDED" then
        if type(unit) == "string" then
            visibleUnits[unit] = true
            local perfStart = Perf and Perf:Start()
            AddPlate(unit)
            if Perf then Perf:Stop("Nameplates", perfStart, "fullUpdates") end
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if type(unit) == "string" then
            visibleUnits[unit] = nil
            local perfStart = Perf and Perf:Start()
            RemovePlate(unit)
            if Perf then Perf:Stop("Nameplates", perfStart, "partialUpdates") end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        HandleTargetChanged()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        HandleMouseoverChanged()
    elseif event == "PLAYER_FOCUS_CHANGED" then
        for _, plate in pairs(enemyByUnit) do ApplyPlateConfiguration(plate) end
        for _, plate in pairs(friendlyByUnit) do ApplyPlateConfiguration(plate) end
        ApplyAllPlateStates()
        ApplyAllPlateAlpha()
    elseif event == "RAID_TARGET_UPDATE" then
        for _, plate in pairs(enemyByUnit) do
            NP.RefreshPlateIndicators(plate, false)
        end
    elseif event == "QUEST_LOG_UPDATE" then
        for _, plate in pairs(enemyByUnit) do
            NP.RefreshPlateIndicators(plate, true)
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "PLAYER_ROLES_ASSIGNED"
        or event == "GROUP_ROSTER_UPDATE"
        or event == "PLAYER_ENTERING_WORLD" then
        RefreshThreatContext()
    end
end)

function Nameplates:Initialize()
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    local settings = profile and profile.nameplates
    if type(settings) == "table" and settings.schemaVersion == 2
        and type(settings.auras) == "table"
        and type(settings.indicators) == "table"
        and type(settings.filters) == "table" then
        settings.filters.include = type(settings.filters.include) == "table" and settings.filters.include or {}
        settings.filters.exclude = type(settings.filters.exclude) == "table" and settings.filters.exclude or {}
        self.settings = settings
    end
    ApplyIntegrationDefaults(self.settings)
    -- v11: migrate existing test profiles once to the exact Jundies profile
    -- palette supplied by the user. Later manual color changes remain untouched.
    if type(self.settings) == "table" and (tonumber(self.settings.jundiesColorVersion) or 0) < 1 then
        local colors = self.settings.colors
        if type(colors) == "table" then
            local function SetColor(key, r, g, b)
                colors[key] = colors[key] or {}
                colors[key].r, colors[key].g, colors[key].b, colors[key].a = r, g, b, 1
            end
            SetColor("important", 0.5764706, 0.4392157, 0.8588236)
            SetColor("boss", 1, 0, 1)
            SetColor("elite", 0.7450981, 0.1882353, 0.1137255)
            SetColor("caster", 0, 0.8196, 1)
            SetColor("tankAggro", 0.7450981, 0.1882353, 0.1137255)
            SetColor("tankLosing", 1, 0.9137256, 0.2274510)
            SetColor("tankNoAggro", 0.8666667, 0.4352942, 0)
            SetColor("offTank", 0.5019608, 0.5019608, 1)
            SetColor("dpsAggro", 0.8666667, 0.4352942, 0)
            SetColor("threatHigh", 1, 0.8, 0)
            SetColor("threatLow", 0.7450981, 0.1882353, 0.1137255)
            SetColor("threatNone", 0.7450981, 0.1882353, 0.1137255)
        end
        self.settings.indicators = self.settings.indicators or {}
        self.settings.indicators.raidMarker = true
        self.settings.jundiesColorVersion = 1
    end

    if type(self.settings) == "table" and (tonumber(self.settings.jundiesLayoutVersion) or 0) < 1 then
        local general = self.settings.general
        if type(general) == "table" then
            general.enemyWidth = 150
            general.enemyHealthHeight = 20
        end
        self.settings.jundiesLayoutVersion = 1
    end

    -- Remove the sporadic BEREIT/ABK text from existing profiles once. The
    -- option remains available if the user deliberately enables it later.
    if type(self.settings) == "table" and (tonumber(self.settings.cleanCastTextVersion) or 0) < 1 then
        self.settings.castbars = self.settings.castbars or {}
        self.settings.castbars.showKickState = false
        self.settings.cleanCastTextVersion = 1
    end

    SyncConfiguredColors()
    NP.RefreshRoleContext()
    NP.RefreshKickSpell()
    manager:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    manager:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    manager:RegisterEvent("PLAYER_TARGET_CHANGED")
    manager:RegisterEvent("PLAYER_FOCUS_CHANGED")
    manager:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    manager:RegisterEvent("RAID_TARGET_UPDATE")
    manager:RegisterEvent("QUEST_LOG_UPDATE")
    manager:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    manager:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    manager:RegisterEvent("GROUP_ROSTER_UPDATE")
    manager:RegisterEvent("PLAYER_ENTERING_WORLD")

    NP.ApplyClickGeometry()
    if NamePlateDriverFrame and NamePlateDriverFrame.UpdateNamePlateOptions then
        hooksecurefunc(NamePlateDriverFrame, "UpdateNamePlateOptions", NP.ApplyClickGeometry)
    end

    -- A reload can occur while native plates already exist. Adopt them once;
    -- normal operation remains entirely event-driven.
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local nativePlates = C_NamePlate.GetNamePlates()
        if nativePlates then
            for _, nativePlate in ipairs(nativePlates) do
                local unit = nativePlate.namePlateUnitToken
                if type(unit) == "string" then
                    visibleUnits[unit] = true
                    AddPlate(unit)
                end
            end
        end
    end

    self.targetPlate = FindPlate("target")
    self.hasTarget = UnitExists("target") and true or false
    ApplyAllPlateStates()
    ApplyAllPlateAlpha()
end

function Nameplates:RefreshAuras()
    for _, plate in pairs(enemyByUnit) do
        NP.RefreshPlateAuras(plate)
    end
end

function Nameplates:RefreshIndicators(refreshQuest)
    for _, plate in pairs(enemyByUnit) do
        NP.RefreshPlateIndicators(plate, refreshQuest == true)
    end
end

function Nameplates:Apply()
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    if profile and type(profile.nameplates) == "table" then
        self.settings = profile.nameplates
    end
    ApplyIntegrationDefaults(self.settings)
    SyncConfiguredColors()
    local release = {}
    if self.settings.enabled == false then
        for _, plate in pairs(enemyByUnit) do release[#release + 1] = plate end
        for _, plate in pairs(friendlyByUnit) do release[#release + 1] = plate end
    elseif Setting("general", "showFriendly", true) == false then
        for _, plate in pairs(friendlyByUnit) do release[#release + 1] = plate end
    end
    for _, plate in ipairs(release) do ReleasePlate(plate) end

    if self.settings.enabled ~= false and C_NamePlate and C_NamePlate.GetNamePlates then
        for unit in pairs(visibleUnits) do
            AddPlate(unit)
        end
        for _, nativePlate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            local unit = nativePlate.namePlateUnitToken
            if type(unit) == "string" then
                visibleUnits[unit] = true
                if not plateByNative[nativePlate] then AddPlate(unit) end
            end
        end
    end

    for _, plate in pairs(enemyByUnit) do
        ApplyPlateConfiguration(plate)
        plate:UpdateHealth()
        plate:UpdateHealthColor()
        ApplyPlateVisualState(plate)
        ApplyPlateAlpha(plate)
        NP.RefreshPlateAuras(plate)
        NP.RefreshPlateIndicators(plate, true)
        if Setting("castbars", "enabled", true) then
            NP.StartOrRefreshCast(plate, plate._isEmpowered)
            if plate.isCasting then NP.UpdateCastAppearance(plate) end
        else
            NP.ClearCastState(plate)
        end
    end
    for _, plate in pairs(friendlyByUnit) do
        ApplyPlateConfiguration(plate)
        plate:UpdateHealth()
        plate:UpdateHealthColor()
        ApplyPlateVisualState(plate)
        ApplyPlateAlpha(plate)
    end
    NP.ApplyClickGeometry()
end

function Nameplates:SetEnabled(enabled)
    self.settings.enabled = enabled and true or false
    self:Apply()
end

function Nameplates:SetOption(section, key, value)
    local target = self.settings[section]
    if type(target) ~= "table" then return false end
    target[key] = value
    self:Apply()
    return true
end

function Nameplates:SetAuraEnabled(key, enabled)
    if key ~= "buffs" and key ~= "debuffs" and key ~= "ownDebuffs"
        and key ~= "important" and key ~= "crowdControl" then
        return false
    end
    self.settings.auras[key] = enabled and true or false
    self:RefreshAuras()
    return true
end

function Nameplates:SetAuraLayout(size, position)
    size = tonumber(size)
    if not size or size < 12 or size > 40 then return false end
    if position ~= "TOP" and position ~= "BOTTOM" then return false end
    self.settings.auras.size = size
    self.settings.auras.position = position
    self:RefreshAuras()
    return true
end

function Nameplates:SetAuraFilter(spellID, mode, enabled)
    spellID = tonumber(spellID)
    if not spellID or (mode ~= "include" and mode ~= "exclude") then
        return false
    end
    local filters = self.settings.filters
    filters.include[spellID] = nil
    filters.exclude[spellID] = nil
    if enabled then filters[mode][spellID] = true end
    self:RefreshAuras()
    return true
end

function Nameplates:SetIndicatorEnabled(key, enabled)
    if key ~= "raidMarker" and key ~= "quest" and key ~= "boss"
        and key ~= "elite" and key ~= "rare" and key ~= "aggro" then
        return false
    end
    self.settings.indicators[key] = enabled and true or false
    self:RefreshIndicators(key == "quest")
    return true
end

function Nameplates:Shutdown()
    manager:UnregisterAllEvents()
    NP.clickGeometryRetry:UnregisterAllEvents()
    NP.clickGeometryPending = false

    local release = {}
    for _, plate in pairs(enemyByUnit) do
        release[#release + 1] = plate
    end
    for _, plate in pairs(friendlyByUnit) do
        release[#release + 1] = plate
    end
    for index = 1, #release do
        ReleasePlate(release[index])
    end
    for unit in pairs(visibleUnits) do
        visibleUnits[unit] = nil
    end
    self.targetPlate = nil
    self.hasTarget = nil
end


-- ------------------------------------------------------------
-- Gemeinsamer Zustand für die ausgelagerten Nameplate-Dateien
-- ------------------------------------------------------------
NP.AccessibleBoolean = AccessibleBoolean
NP.CanAccess = CanAccess
NP.CreateEdge = CreateEdge
NP.Setting = Setting
NP.activeCasts = activeCasts
NP.enemyByUnit = enemyByUnit
NP.hiddenBlizzardHolder = hiddenBlizzardHolder
NP.nativeFrameState = nativeFrameState
