-- ============================================================
-- RexUI - Nameplates / Castbar
-- Ausgelagert aus Core.lua; gemeinsamer Zustand liegt in Nameplates.Internal (NP).
-- ============================================================

local ADDON_NAME, ns = ...
local RexUI = ns.RexUI
if not RexUI or not RexUI.Nameplates then return end

local Nameplates = RexUI.Nameplates
local NP = Nameplates.Internal
local Perf = RexUI.Perf

local CAST_COLORS = NP.CAST_COLORS
local INTERRUPT_SPELLS = NP.INTERRUPT_SPELLS
local PLATE_WIDTH = NP.PLATE_WIDTH

local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitName = UnitName

local function CreateCastElements(plate)
    plate.cast = CreateFrame("StatusBar", nil, plate)
    plate.cast:SetPoint("TOP", plate.health, "BOTTOM", 0, -3)
    plate.cast:SetSize(PLATE_WIDTH, 11)
    plate.cast:SetStatusBarTexture("Interface\\AddOns\\RexUI\\media\\statusbars\\bar_serenity.tga")
    plate.cast:SetStatusBarColor(unpack(CAST_COLORS.normal))
    plate.cast:EnableMouse(false)
    plate.cast:Hide()

    plate.castBackground = plate.cast:CreateTexture(nil, "BACKGROUND")
    plate.castBackground:SetAllPoints()
    plate.castBackground:SetColorTexture(CAST_COLORS.background[1], CAST_COLORS.background[2], CAST_COLORS.background[3], 0.94)

    -- Cast-Spark: hängt an der Füllkante der Statusleiste und folgt ihr auch
    -- dann, wenn Zauberzeiten in Midnight geheim sind (Positionierung durch die Engine).
    plate.castSpark = plate.cast:CreateTexture(nil, "OVERLAY", nil, 7)
    plate.castSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    plate.castSpark:SetBlendMode("ADD")
    plate.castSpark:SetSize(12, 24)
    plate.castSpark:SetPoint("CENTER", plate.cast:GetStatusBarTexture(), "RIGHT", 0, 0)
    plate.castSpark:Hide()

    plate.castBorder = {
        NP.CreateEdge(plate.cast), NP.CreateEdge(plate.cast),
        NP.CreateEdge(plate.cast), NP.CreateEdge(plate.cast),
    }
    local top, bottom, left, right = unpack(plate.castBorder)
    top:SetPoint("BOTTOMLEFT", plate.cast, "TOPLEFT", -1, 0)
    top:SetPoint("BOTTOMRIGHT", plate.cast, "TOPRIGHT", 1, 0)
    top:SetHeight(1)
    bottom:SetPoint("TOPLEFT", plate.cast, "BOTTOMLEFT", -1, 0)
    bottom:SetPoint("TOPRIGHT", plate.cast, "BOTTOMRIGHT", 1, 0)
    bottom:SetHeight(1)
    left:SetPoint("TOPRIGHT", plate.cast, "TOPLEFT", 0, 1)
    left:SetPoint("BOTTOMRIGHT", plate.cast, "BOTTOMLEFT", 0, -1)
    left:SetWidth(1)
    right:SetPoint("TOPLEFT", plate.cast, "TOPRIGHT", 0, 1)
    right:SetPoint("BOTTOMLEFT", plate.cast, "BOTTOMRIGHT", 0, -1)
    right:SetWidth(1)
    for index = 1, #plate.castBorder do
        plate.castBorder[index]:SetColorTexture(0.06, 0.06, 0.08, 1)
    end

    plate.castName = plate.cast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    plate.castName:SetPoint("LEFT", plate.cast, "LEFT", 3, 0)
    plate.castName:SetWidth(78)
    plate.castName:SetJustifyH("LEFT")
    plate.castName:SetWordWrap(false)
    plate.castName:SetMaxLines(1)

    plate.castTime = plate.cast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    plate.castTime:SetPoint("RIGHT", plate.cast, "RIGHT", -3, 0)
    plate.castTime:SetWidth(31)
    plate.castTime:SetJustifyH("RIGHT")
    plate.castTime:SetWordWrap(false)
    plate.castTime:SetMaxLines(1)

    plate.castIcon = plate.cast:CreateTexture(nil, "ARTWORK")
    plate.castIcon:SetPoint("RIGHT", plate.cast, "LEFT", -3, 0)
    plate.castIcon:SetSize(15, 15)
    plate.castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    plate.castIcon:Hide()

    plate.castTargetName = plate.cast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    plate.castTargetName:SetPoint("TOPRIGHT", plate.cast, "BOTTOMRIGHT", 0, -1)
    plate.castTargetName:SetWidth(100)
    plate.castTargetName:SetJustifyH("RIGHT")
    plate.castTargetName:SetWordWrap(false)
    plate.castTargetName:SetMaxLines(1)
    plate.castTargetName:Hide()

    plate.kickReadyText = plate:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    plate.kickReadyText:SetPoint("BOTTOMRIGHT", plate.cast, "TOPRIGHT", 0, 1)
    plate.kickReadyText:SetText("")
    plate.kickReadyText:SetTextColor(unpack(CAST_COLORS.kickReady))
    plate.kickReadyText:SetAlpha(0)

    plate.kickCooldownText = plate:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    plate.kickCooldownText:SetPoint("BOTTOMRIGHT", plate.cast, "TOPRIGHT", 0, 1)
    plate.kickCooldownText:SetText("")
    plate.kickCooldownText:SetTextColor(unpack(CAST_COLORS.kickCooldown))
    plate.kickCooldownText:SetAlpha(0)

    plate.castLockText = CreateFrame("Frame", nil, plate.cast)
    plate.castLockText:SetPoint("LEFT", plate.cast, "LEFT", 3, 0)
    plate.castLockText:SetSize(11, 13)
    plate.castLockText:SetFrameLevel(plate.cast:GetFrameLevel() + 5)
    plate.castLockText:EnableMouse(false)
    plate.castShield = plate.castLockText:CreateTexture(nil, "OVERLAY")
    plate.castShield:SetAllPoints()
    plate.castShield:SetTexture(NP.NAMEPLATE_MEDIA .. "shield.png")
    plate.castLockText:SetAlpha(0)

    plate.importantCastGlow = {
        NP.CreateEdge(plate.cast, "OVERLAY"), NP.CreateEdge(plate.cast, "OVERLAY"),
        NP.CreateEdge(plate.cast, "OVERLAY"), NP.CreateEdge(plate.cast, "OVERLAY"),
    }
    local glowTop, glowBottom, glowLeft, glowRight = unpack(plate.importantCastGlow)
    glowTop:SetPoint("BOTTOMLEFT", plate.cast, "TOPLEFT", -3, 2)
    glowTop:SetPoint("BOTTOMRIGHT", plate.cast, "TOPRIGHT", 3, 2)
    glowTop:SetHeight(2)
    glowBottom:SetPoint("TOPLEFT", plate.cast, "BOTTOMLEFT", -3, -2)
    glowBottom:SetPoint("TOPRIGHT", plate.cast, "BOTTOMRIGHT", 3, -2)
    glowBottom:SetHeight(2)
    glowLeft:SetPoint("TOPRIGHT", plate.cast, "TOPLEFT", -2, 3)
    glowLeft:SetPoint("BOTTOMRIGHT", plate.cast, "BOTTOMLEFT", -2, -3)
    glowLeft:SetWidth(2)
    glowRight:SetPoint("TOPLEFT", plate.cast, "TOPRIGHT", 2, 3)
    glowRight:SetPoint("BOTTOMLEFT", plate.cast, "BOTTOMRIGHT", 2, -3)
    glowRight:SetWidth(2)
    for index = 1, #plate.importantCastGlow do
        local color = CAST_COLORS.important
        plate.importantCastGlow[index]:SetColorTexture(color[1], color[2], color[3], 0.85)
        plate.importantCastGlow[index]:SetAlpha(0)
        plate.importantCastGlow[index]:Hide()
    end
end


local activeKickSpell
local castProgressDriver = CreateFrame("Frame")
castProgressDriver:Hide()

local function EvaluateBoolean(value, whenTrue, whenFalse)
    if type(value) ~= "boolean" then
        return whenFalse
    end
    if C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        return C_CurveUtil.EvaluateColorValueFromBoolean(value, whenTrue, whenFalse)
    end
    if NP.CanAccess(value) then
        return value and whenTrue or whenFalse
    end
    return whenFalse
end

local function RefreshKickSpell()
    activeKickSpell = nil
    if not IsPlayerSpell then
        return
    end
    for index = 1, #INTERRUPT_SPELLS do
        local spellID = INTERRUPT_SPELLS[index]
        if IsPlayerSpell(spellID) then
            activeKickSpell = spellID
            return
        end
    end
end

local function GetKickReady()
    if not activeKickSpell or not C_Spell then
        return nil
    end
    if C_Spell.GetSpellCooldownDuration then
        local ok, duration = pcall(C_Spell.GetSpellCooldownDuration, activeKickSpell)
        if ok and duration and duration.IsZero then
            return duration:IsZero()
        end
    end
    if C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, activeKickSpell)
        if ok and type(info) == "table"
            and type(info.duration) == "number" and NP.CanAccess(info.duration) then
            return info.duration == 0
        end
    end
    return nil
end

local function SetImportantGlow(plate, alpha)
    for index = 1, #plate.importantCastGlow do
        local edge = plate.importantCastGlow[index]
        edge:Show()
        edge:SetAlpha(alpha)
    end
end

local function HideImportantGlow(plate)
    for index = 1, #plate.importantCastGlow do
        plate.importantCastGlow[index]:SetAlpha(0)
        plate.importantCastGlow[index]:Hide()
    end
end

local function UpdateCastAppearance(plate)
    if not plate or not plate.isCasting then
        return
    end

    local kickReady = GetKickReady()
    plate._kickReady = kickReady
    local uninterruptible = plate._castUninterruptible
    if type(uninterruptible) == "nil" then
        uninterruptible = false
    end
    local important = plate._castImportant
    if type(important) == "nil" then
        important = false
    end

    local base = plate._isEmpowered and CAST_COLORS.empowered
        or (plate._isChannel and CAST_COLORS.channel)
        or CAST_COLORS.normal
    local importantColor = CAST_COLORS.important
    local locked = CAST_COLORS.uninterruptible

    local red, green, blue = base[1], base[2], base[3]
    red = EvaluateBoolean(important, importantColor[1], red)
    green = EvaluateBoolean(important, importantColor[2], green)
    blue = EvaluateBoolean(important, importantColor[3], blue)
    red = EvaluateBoolean(uninterruptible, locked[1], red)
    green = EvaluateBoolean(uninterruptible, locked[2], green)
    blue = EvaluateBoolean(uninterruptible, locked[3], blue)
    plate.cast:SetStatusBarColor(red, green, blue, 1)

    local interruptibleAlpha = EvaluateBoolean(uninterruptible, 0, 1)
    local readyAlpha = 0
    local cooldownAlpha = 0
    if type(kickReady) == "boolean" then
        readyAlpha = EvaluateBoolean(kickReady, interruptibleAlpha, 0)
        cooldownAlpha = EvaluateBoolean(kickReady, 0, interruptibleAlpha)
    end
    -- Text statuses are intentionally disabled. Interruptibility remains
    -- visible through the configured cast-bar colors.
    plate.kickReadyText:SetAlpha(0)
    plate.kickCooldownText:SetAlpha(0)
    plate.castLockText:SetAlpha(NP.Setting("castbars", "showShield", true)
        and EvaluateBoolean(uninterruptible, 1, 0) or 0)

    local importantAlpha = EvaluateBoolean(important, 1, 0)
    SetImportantGlow(plate, NP.Setting("castbars", "showImportantGlow", true) and importantAlpha or 0)
end

local function GetCastSnapshot(unit, forceEmpowered)
    local name, _, texture, startMS, endMS, _, castGUID, uninterruptible, spellID = UnitCastingInfo(unit)
    local isChannel = false
    if type(name) == "nil" then
        name, _, texture, startMS, endMS, _, uninterruptible, spellID = UnitChannelInfo(unit)
        isChannel = true
        castGUID = nil
    end
    if type(name) == "nil" then
        return nil
    end
    return {
        name = name,
        texture = texture,
        startMS = startMS,
        endMS = endMS,
        castGUID = castGUID,
        uninterruptible = type(uninterruptible) == "nil" and false or uninterruptible,
        spellID = spellID,
        isChannel = isChannel,
        isEmpowered = forceEmpowered and true or false,
    }
end

local function ConfigureNativeCastTimer(plate)
    if not plate.cast.SetTimerDuration then
        return false
    end
    local duration
    local direction
    if plate._isChannel then
        if plate._isEmpowered and UnitEmpoweredChannelDuration then
            duration = UnitEmpoweredChannelDuration(plate.unit, true)
        end
        if type(duration) == "nil" and UnitChannelDuration then
            duration = UnitChannelDuration(plate.unit)
        end
        direction = Enum and Enum.StatusBarTimerDirection
            and ((plate._isEmpowered and Enum.StatusBarTimerDirection.ElapsedTime)
                or Enum.StatusBarTimerDirection.RemainingTime)
    elseif UnitCastingDuration then
        duration = UnitCastingDuration(plate.unit)
        direction = Enum and Enum.StatusBarTimerDirection
            and Enum.StatusBarTimerDirection.ElapsedTime
    end
    if type(duration) == "nil" then
        return false
    end
    plate._durationObject = duration
    plate.cast:SetReverseFill(false)
    local ok = pcall(plate.cast.SetTimerDuration, plate.cast, duration, nil, direction)
    return ok
end

local function MirrorBlizzardCast(plate)
    local unitFrame = plate.nativePlate and plate.nativePlate.UnitFrame
    local blizzardCast = unitFrame and unitFrame.castBar
    if not blizzardCast or not blizzardCast.GetMinMaxValues or not blizzardCast.GetValue then
        return false
    end
    local minimum, maximum = blizzardCast:GetMinMaxValues()
    local value = blizzardCast:GetValue()
    if type(minimum) == "nil" or type(maximum) == "nil" or type(value) == "nil" then
        return false
    end
    plate.cast:SetMinMaxValues(minimum, maximum)
    plate.cast:SetValue(value)
    if blizzardCast.GetReverseFill then
        plate.cast:SetReverseFill(blizzardCast:GetReverseFill())
    end
    return true
end

local function UpdateManualCastProgress(plate, nowMS)
    local startMS, endMS = plate._castStartMS, plate._castEndMS
    if type(startMS) ~= "number" or type(endMS) ~= "number"
        or not NP.CanAccess(startMS) or not NP.CanAccess(endMS) then
        plate.castTime:SetText("")
        return
    end
    local total = math.max(0.001, (endMS - startMS) / 1000)
    local remaining = math.max(0, (endMS - nowMS) / 1000)
    plate.castTime:SetFormattedText("%.1f", remaining)
    if not plate._nativeCastTimer and not MirrorBlizzardCast(plate) then
        plate.cast:SetMinMaxValues(0, total)
        if plate._isChannel and not plate._isEmpowered then
            plate.cast:SetReverseFill(true)
            plate.cast:SetValue(remaining)
        else
            plate.cast:SetReverseFill(false)
            plate.cast:SetValue(math.min(total, math.max(0, (nowMS - startMS) / 1000)))
        end
    end
end

castProgressDriver:SetScript("OnUpdate", function()
    if Perf then Perf:Count("Nameplates", "onUpdates") end
    local nowMS = GetTime() * 1000
    for plate in pairs(NP.activeCasts) do
        if not plate.isCasting or not plate.unit then
            NP.activeCasts[plate] = nil
        else
            local duration = plate._durationObject
            if duration and duration.GetRemainingDuration then
                plate.castTime:SetFormattedText("%.1f", duration:GetRemainingDuration())
            else
                UpdateManualCastProgress(plate, nowMS)
            end
        end
    end
    if not next(NP.activeCasts) then
        castProgressDriver:Hide()
    end
end)

local function UpdateCastTargetName(plate)
    if not plate or not plate.castTargetName or not plate.isCasting
        or NP.Setting("castbars", "showTargetName", true) == false then
        if plate and plate.castTargetName then plate.castTargetName:Hide() end
        return
    end
    local targetUnit = plate.unit and (plate.unit .. "target")
    if not targetUnit or not UnitExists(targetUnit) then
        plate.castTargetName:Hide()
        return
    end
    local targetName = UnitName(targetUnit)
    if type(targetName) == "nil" then
        plate.castTargetName:Hide()
        return
    end
    plate.castTargetName:SetFormattedText("%s", targetName)
    plate.castTargetName:Show()
end

NP.ClearCastState = function(plate, recycling)
    NP.activeCasts[plate] = nil
    plate.isCasting = nil
    plate._isChannel = nil
    plate._isEmpowered = nil
    plate._castGUID = nil
    plate._castSpellID = nil
    plate._castStartMS = nil
    plate._castEndMS = nil
    plate._castUninterruptible = nil
    plate._castImportant = nil
    plate._kickReady = nil
    plate._durationObject = nil
    plate._nativeCastTimer = nil
    plate._castResultToken = nil
    plate._castResultActive = nil
    plate.castName:SetText("")
    plate.castTime:SetText("")
    plate.castTargetName:SetText("")
    plate.castTargetName:Hide()
    plate.kickReadyText:SetAlpha(0)
    plate.kickCooldownText:SetAlpha(0)
    plate.castLockText:SetAlpha(0)
    plate.castIcon:SetTexture(nil)
    plate.castIcon:Hide()
    HideImportantGlow(plate)
    plate.cast:SetMinMaxValues(0, 1)
    plate.cast:SetValue(0)
    plate.cast:SetReverseFill(false)
    plate.cast:Hide()
    if NP.RefreshSideLayout then NP.RefreshSideLayout(plate) end
    if not next(NP.activeCasts) then
        castProgressDriver:Hide()
    end
end

local function StartOrRefreshCast(plate, empowered)
    if not plate or not plate.unit or not plate.cast then
        return
    end
    if NP.Setting("castbars", "enabled", true) == false then
        NP.ClearCastState(plate)
        return
    end
    local snapshot = GetCastSnapshot(plate.unit, empowered)
    if not snapshot then
        if not plate._castResultActive then
            NP.ClearCastState(plate)
        end
        return
    end

    plate._castResultToken = nil
    plate._castResultActive = nil
    plate.isCasting = true
    plate._isChannel = snapshot.isChannel
    plate._isEmpowered = snapshot.isEmpowered
    plate._castGUID = snapshot.castGUID
    plate._castSpellID = snapshot.spellID
    plate._castStartMS = snapshot.startMS
    plate._castEndMS = snapshot.endMS
    plate._castUninterruptible = snapshot.uninterruptible

    if snapshot.isEmpowered then
        plate.castName:SetFormattedText(RexUI:LocalizeText("VERSTÄRKT: %s"), snapshot.name)
    else
        plate.castName:SetFormattedText("%s", snapshot.name)
    end
    if NP.Setting("castbars", "showIcon", true) ~= false and type(snapshot.texture) ~= "nil" then
        plate.castIcon:SetTexture(snapshot.texture)
        plate.castIcon:Show()
    else
        plate.castIcon:SetTexture(nil)
        plate.castIcon:Hide()
    end

    plate._castImportant = false
    if C_Spell and C_Spell.IsSpellImportant then
        local spellID = snapshot.spellID
        if type(spellID) == "nil" then
            spellID = 0
        end
        local ok, important = pcall(C_Spell.IsSpellImportant, spellID)
        if ok and type(important) == "boolean" then
            plate._castImportant = important
        end
    end

    plate.cast:Show()
    if NP.RefreshSideLayout then NP.RefreshSideLayout(plate) end
    UpdateCastTargetName(plate)
    plate._nativeCastTimer = ConfigureNativeCastTimer(plate)
    NP.activeCasts[plate] = true
    castProgressDriver:Show()
    UpdateCastAppearance(plate)
end

local function CastEventMatches(plate, castGUID)
    if type(castGUID) == "nil" or type(plate._castGUID) == "nil" then
        return true
    end
    if not NP.CanAccess(castGUID) or not NP.CanAccess(plate._castGUID) then
        return true
    end
    return castGUID == plate._castGUID
end

local function ShowCastResult(plate, text, color, duration)
    if not plate or not plate.cast then
        return
    end
    NP.activeCasts[plate] = nil
    plate.isCasting = nil
    plate._durationObject = nil
    plate._nativeCastTimer = nil
    plate._castResultActive = true
    local token = {}
    plate._castResultToken = token
    plate.cast:SetMinMaxValues(0, 1)
    plate.cast:SetValue(1)
    plate.cast:SetReverseFill(false)
    plate.cast:SetStatusBarColor(color[1], color[2], color[3], 1)
    plate.castName:SetText(text)
    plate.castTime:SetText("")
    plate.castTargetName:Hide()
    plate.castIcon:Hide()
    plate.kickReadyText:SetAlpha(0)
    plate.kickCooldownText:SetAlpha(0)
    plate.castLockText:SetAlpha(0)
    HideImportantGlow(plate)
    plate.cast:Show()
    if not next(NP.activeCasts) then
        castProgressDriver:Hide()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(duration, function()
            if plate._castResultToken == token and plate.unit then
                NP.ClearCastState(plate)
            end
        end)
    end
end


local castDispatcher = CreateFrame("Frame")
for _, event in ipairs({
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_EMPOWER_UPDATE",
    "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    "UNIT_TARGET",
}) do
    castDispatcher:RegisterEvent(event)
end

castDispatcher:SetScript("OnEvent", function(_, event, unit, castGUID)
    if Perf then Perf:Count("Nameplates", "events") end
    local plate = NP.enemyByUnit[unit]
    if not plate or not plate.cast then
        return
    end

    if event == "UNIT_TARGET" then
        UpdateCastTargetName(plate)
    elseif event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_DELAYED"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
        or event == "UNIT_SPELLCAST_EMPOWER_START"
        or event == "UNIT_SPELLCAST_EMPOWER_UPDATE"
        or event == "UNIT_SPELLCAST_INTERRUPTIBLE"
        or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        local empowered = event == "UNIT_SPELLCAST_EMPOWER_START"
            or event == "UNIT_SPELLCAST_EMPOWER_UPDATE"
            or plate._isEmpowered
        StartOrRefreshCast(plate, empowered)
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        if CastEventMatches(plate, castGUID) then
            ShowCastResult(plate, "UNTERBROCHEN", CAST_COLORS.interrupted, 0.8)
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if plate.isCasting and not plate._isChannel and CastEventMatches(plate, castGUID) then
            ShowCastResult(plate, "ERFOLG", CAST_COLORS.succeeded, 0.45)
        end
    elseif event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        if CastEventMatches(plate, castGUID) and not plate._castResultActive then
            NP.ClearCastState(plate)
        end
    end
end)

local kickWatcher = CreateFrame("Frame")
kickWatcher:RegisterEvent("SPELL_UPDATE_COOLDOWN")
kickWatcher:RegisterEvent("SPELLS_CHANGED")
kickWatcher:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
kickWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
kickWatcher:SetScript("OnEvent", function(_, event)
    if event ~= "SPELL_UPDATE_COOLDOWN" then
        RefreshKickSpell()
    end
    for plate in pairs(NP.activeCasts) do
        UpdateCastAppearance(plate)
    end
end)


-- Für andere Nameplate-Dateien sichtbar machen
NP.CreateCastElements = CreateCastElements
NP.RefreshKickSpell = RefreshKickSpell
NP.StartOrRefreshCast = StartOrRefreshCast
NP.UpdateCastAppearance = UpdateCastAppearance
