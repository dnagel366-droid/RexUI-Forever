-- ============================================================
-- RexUI - Nameplates / Threat
-- Ausgelagert aus Core.lua; gemeinsamer Zustand liegt in Nameplates.Internal (NP).
-- ============================================================

local ADDON_NAME, ns = ...
local RexUI = ns.RexUI
if not RexUI or not RexUI.Nameplates then return end

local Nameplates = RexUI.Nameplates
local NP = Nameplates.Internal
local Perf = RexUI.Perf

local HEALTH_COLORS = NP.HEALTH_COLORS

local UnitAffectingCombat = UnitAffectingCombat
local UnitClassification = UnitClassification
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local UnitEffectiveLevel = UnitEffectiveLevel
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitHasPowerType = UnitHasPowerType
local UnitIsLieutenant = UnitIsLieutenant
local UnitIsTapDenied = UnitIsTapDenied
local UnitIsUnit = UnitIsUnit
local UnitReaction = UnitReaction
local UnitSelectionColor = UnitSelectionColor
local UnitThreatSituation = UnitThreatSituation

local otherTankTokens = {}

local function RefreshRoleContext()
    local role
    if GetSpecialization and GetSpecializationRole then
        local specialization = GetSpecialization()
        if specialization then
            role = GetSpecializationRole(specialization)
        end
    end
    if type(role) ~= "string" or not NP.CanAccess(role) or role == "NONE" then
        role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") or "NONE"
    end
    if type(role) ~= "string" or not NP.CanAccess(role) then
        role = "NONE"
    end
    Nameplates.playerRole = role
    Nameplates.playerIsTank = role == "TANK"

    for index = #otherTankTokens, 1, -1 do
        otherTankTokens[index] = nil
    end
    local prefix, count
    if IsInRaid and IsInRaid() then
        prefix = "raid"
        count = GetNumGroupMembers and GetNumGroupMembers() or 0
    elseif IsInGroup and IsInGroup() then
        prefix = "party"
        count = math.max(0, (GetNumGroupMembers and GetNumGroupMembers() or 1) - 1)
    end
    if not prefix then
        return
    end
    for index = 1, count do
        local token = prefix .. index
        if not UnitIsUnit(token, "player") then
            local assignedRole = UnitGroupRolesAssigned(token)
            if type(assignedRole) == "string"
                and NP.CanAccess(assignedRole)
                and assignedRole == "TANK" then
                otherTankTokens[#otherTankTokens + 1] = token
            end
        end
    end
end

local function ResolveOffTankColor(unit, base, playerStatus)
    if #otherTankTokens == 0 or not UnitDetailedThreatSituation then
        return false
    end

    base = base or HEALTH_COLORS.tankNoAggro
    local offTank = HEALTH_COLORS.offTank
    local red, green, blue = base[1], base[2], base[3]
    local secretEvaluated = false
    local evaluateSecret = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean

    for index = 1, #otherTankTokens do
        local isTanking, otherThreatStatus = UnitDetailedThreatSituation(otherTankTokens[index], unit)
        if type(isTanking) == "boolean" then
            if NP.CanAccess(isTanking) then
                if isTanking then
                    local pulling = playerStatus == 1
                        and type(otherThreatStatus) == "number" and NP.CanAccess(otherThreatStatus)
                        and otherThreatStatus >= 2
                    local color = pulling and HEALTH_COLORS.tankTakeover or offTank
                    return true, color[1], color[2], color[3], pulling and "tankTakeover" or "offTank"
                end
            elseif evaluateSecret then
                secretEvaluated = true
                red = evaluateSecret(isTanking, offTank[1], red)
                green = evaluateSecret(isTanking, offTank[2], green)
                blue = evaluateSecret(isTanking, offTank[3], blue)
            end
        end
    end
    return secretEvaluated, red, green, blue, secretEvaluated and "offTank" or nil
end

local function GetThreatStatus(unit)
    if not UnitThreatSituation then
        return nil
    end
    local status = UnitThreatSituation("player", unit)
    if type(status) ~= "number" or not NP.CanAccess(status) then
        return nil
    end
    return status
end

local CLASSIFICATION_LABELS = {
    worldboss = true,
    rareelite = true,
    elite = true,
    rare = true,
    normal = true,
    trivial = true,
    minus = true,
}

local function AccessibleString(value)
    return type(value) == "string" and NP.CanAccess(value) and value or nil
end

local function ClassificationEquals(value, expected)
    local text = AccessibleString(value)
    if text then
        return text == expected
    end
    if type(value) == "nil" then
        return false
    end
    local ok, matched = pcall(function()
        return value == expected
    end)
    return ok and matched == true
end

local function ClassificationFromTooltip(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then
        return nil
    end
    local ok, info = pcall(C_TooltipInfo.GetUnit, unit)
    if not ok or not info or not info.lines then
        return nil
    end
    local lineTypes = Enum and Enum.TooltipDataLineType
    for _, line in ipairs(info.lines) do
        local lineType = line.type
        local left = AccessibleString(line.leftText)
        if not left then
            -- continue
        else
            local useLine = true
            if lineTypes and lineTypes.UnitClassification and NP.CanAccess(lineType) then
                useLine = lineType == lineTypes.UnitClassification
            end
            if useLine or (lineTypes and lineTypes.UnitClassification and not NP.CanAccess(lineType)) then
                local lower = strlower((left:gsub("^%s+", ""):gsub("%s+$", "")))
                if lower == "rareelite" or lower == "rare elite"
                    or lower == "seltener elite" or lower == "selten elite"
                    or lower == "elite selten" then
                    return "rareelite"
                end
                if lower == "worldboss" or lower == "boss" then
                    return "worldboss"
                end
                if lower == "elite" then
                    return "elite"
                end
                if lower == "rare" or lower == "selten" or lower == "seltenes" then
                    return "rare"
                end
            end
        end
    end
    return nil
end

local function ReadClassification(unit)
    local classification = UnitClassification and UnitClassification(unit)
    local accessible = AccessibleString(classification)
    if accessible and CLASSIFICATION_LABELS[accessible] then
        return accessible
    end
    for _, expected in ipairs({ "rareelite", "worldboss", "elite", "rare", "trivial", "minus", "normal" }) do
        if ClassificationEquals(classification, expected) then
            return expected
        end
    end
    return ClassificationFromTooltip(unit) or "normal"
end

local function UpdateClassificationState(self)
    local unit = self.unit
    if not unit then
        return
    end

    self._tapped = UnitIsTapDenied and NP.AccessibleBoolean(UnitIsTapDenied(unit)) or false
    self._lieutenant = UnitIsLieutenant and NP.AccessibleBoolean(UnitIsLieutenant(unit)) or false
    self._bossMob = UnitIsBossMob and NP.AccessibleBoolean(UnitIsBossMob(unit)) or false

    local classification = ReadClassification(unit)
    self._classification = classification
    self._isWorldBoss = classification == "worldboss"
    self._isRareElite = classification == "rareelite"
    self._isElite = classification == "elite" or classification == "rareelite"
    self._isRare = classification == "rare" or classification == "rareelite"

    local effectiveLevel = UnitEffectiveLevel and UnitEffectiveLevel(unit)
    local playerLevel = UnitEffectiveLevel and UnitEffectiveLevel("player")
    local unitLevel = UnitLevel and UnitLevel(unit)
    self._skullBoss = (type(effectiveLevel) == "number"
            and NP.CanAccess(effectiveLevel) and effectiveLevel == -1)
        or (type(unitLevel) == "number"
            and NP.CanAccess(unitLevel) and unitLevel == -1)

    self._levelBoss = false
    self._levelMiniboss = false
    if type(effectiveLevel) == "number" and NP.CanAccess(effectiveLevel)
        and type(playerLevel) == "number" and NP.CanAccess(playerLevel) then
        self._levelBoss = effectiveLevel == playerLevel + 2
        self._levelMiniboss = effectiveLevel == playerLevel + 1
    end
    self._miniboss = self._levelMiniboss or self._bossMob or self._lieutenant

    -- Match Plater's current automatic caster signal: Paladin NPCs or mana users.
    -- Never inspect a secret class value on Midnight.
    self._caster = false
    local classBase = UnitClassBase and UnitClassBase(unit)
    if type(classBase) == "string" and NP.CanAccess(classBase) and classBase == "PALADIN" then
        self._caster = true
    elseif UnitPowerType and Enum and Enum.PowerType then
        local powerType = UnitPowerType(unit)
        if type(powerType) == "number" and NP.CanAccess(powerType) then
            self._caster = powerType == Enum.PowerType.Mana
        elseif UnitHasPowerType then
            self._caster = NP.AccessibleBoolean(UnitHasPowerType(unit, Enum.PowerType.Mana))
        end
    elseif UnitHasPowerType and Enum and Enum.PowerType then
        self._caster = NP.AccessibleBoolean(UnitHasPowerType(unit, Enum.PowerType.Mana))
    end
end

local function ColorValues(key, reason)
    local color = HEALTH_COLORS[key]
    return color[1], color[2], color[3], reason or key
end

-- Plater reads the displayed unit's reaction toward the player and reduces
-- the result to hostile, neutral or friendly. Keep the same argument order;
-- reversing it can classify special encounter NPCs as neutral incorrectly.
local function GetNormalizedReaction(unit)
    local reaction = UnitReaction and UnitReaction(unit, "player")
    if type(reaction) ~= "number" or not NP.CanAccess(reaction) then
        return nil
    end
    if reaction <= 3 then return 3 end
    if reaction >= 5 then return 5 end
    return 4
end

local function ResolveBaseColor(plate)
    if plate.kind == "friendly" then
        if NP.Setting("general", "friendlyClassColors", true) and UnitIsPlayer and UnitIsPlayer(plate.unit) then
            local _, classFile = UnitClass(plate.unit)
            local palette = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
            local classColor = classFile and palette and palette[classFile]
            if classColor and NP.CanAccess(classColor.r) then
                return classColor.r, classColor.g, classColor.b, "class"
            end
        end
        return ColorValues("friendly")
    end

    if NP.Setting("threat", "overrideBaseColors", true) == false and UnitSelectionColor then
        local red, green, blue = UnitSelectionColor(plate.unit, true)
        if type(red) == "number" and type(green) == "number" and type(blue) == "number"
            and NP.CanAccess(red) and NP.CanAccess(green) and NP.CanAccess(blue) then
            return red, green, blue, "blizzard"
        end
    end

    local reaction = GetNormalizedReaction(plate.unit)
    if reaction == 4 then
        return ColorValues("neutral")
    end
    return ColorValues("enemy")
end

local function HasTankAggro(unit)
    for index = 1, #otherTankTokens do
        local tankStatus = UnitThreatSituation and UnitThreatSituation(otherTankTokens[index], unit)
        if type(tankStatus) == "number" and NP.CanAccess(tankStatus) and tankStatus >= 2 then
            return true
        end
    end
    return false
end

local function ResolveThreatColor(plate, status, grouped)
    local unit = plate.unit
    if Nameplates.playerIsTank then
        local key = status >= 3 and "tankAggro" or (status == 2 and "tankLosing" or "tankNoAggro")
        local evaluated, red, green, blue, reason = ResolveOffTankColor(unit, HEALTH_COLORS[key], status)
        if evaluated then return red, green, blue, reason or "offTank" end
        return ColorValues(key)
    end

    if not grouped then
        if NP.Setting("threat", "useSoloColor", false) and status >= 1 then
            return ColorValues("solo")
        end
        return nil
    end
    if status >= 2 then return ColorValues("dpsAggro") end
    if NP.Setting("threat", "checkNoTankAggro", false) and not HasTankAggro(unit) then
        return ColorValues("nonTankTarget")
    end
    if status == 1 then return ColorValues("threatHigh") end
    return ColorValues("threatNone")
end

-- One priority chain, matching the groups and switches shown in Plater.
local function ResolveHealthColor(plate)
    if plate.kind == "friendly" then return ResolveBaseColor(plate) end
    if plate._tapped then return ColorValues("tapped") end

    local unit = plate.unit
    local threatEnabled = NP.Setting("threat", "enabled", true)
    local status = threatEnabled and (GetThreatStatus(unit) or 0) or nil
    local grouped = IsInGroup and IsInGroup() or false
    local inCombat
    if UnitAffectingCombat then inCombat = NP.AccessibleBoolean(UnitAffectingCombat(unit)) end
    local threatRed, threatGreen, threatBlue, threatReason
    -- A neutral unit with no threat should keep its reaction color, even
    -- while the player is in a group.
    if threatEnabled and (GetNormalizedReaction(unit) ~= 4 or status > 0) then
        threatRed, threatGreen, threatBlue, threatReason = ResolveThreatColor(plate, status, grouped)
    end
    local badThreat = threatReason == "tankLosing" or threatReason == "tankNoAggro"
        or threatReason == "offTank" or threatReason == "tankTakeover"
        or threatReason == "dpsAggro" or threatReason == "threatHigh"
        or threatReason == "nonTankTarget"

    -- Plater v652 always preserves warning colors while the unit is in combat.
    -- Good states may yield to unit-type colors unless the option below forbids it.
    if threatRed and inCombat ~= false
        and (badThreat or NP.Setting("threat", "unitTypesDontOverrideThreat", false)) then
        return threatRed, threatGreen, threatBlue, threatReason
    end

    local classification = plate._classification or "normal"
    if NP.Setting("threat", "unitTypeColoring", NP.Setting("threat", "importantNPCs", true)) then
        if plate._isWorldBoss or classification == "worldboss" or plate._skullBoss or plate._levelBoss then
            return ColorValues("boss")
        elseif plate._miniboss then
            return ColorValues("important", "miniboss")
        elseif plate._isRare or plate._isRareElite or classification == "rare" or classification == "rareelite" then
            return ColorValues("rare")
        elseif NP.Setting("threat", "casterColor", true) and plate._caster then
            return ColorValues("caster")
        elseif NP.Setting("threat", "eliteColor", false)
            and (plate._isElite or classification == "elite" or classification == "rareelite") then
            return ColorValues("elite")
        elseif NP.Setting("threat", "trivialColor", false)
            and (classification == "trivial" or classification == "minus") then
            return ColorValues("trivial")
        end
    end

    if UnitAffectingCombat then
        local neutral = GetNormalizedReaction(unit) == 4
        if inCombat == false and not neutral then return ColorValues("outOfCombat") end
    end

    if threatRed then return threatRed, threatGreen, threatBlue, threatReason end
    return ResolveBaseColor(plate)
end

local THREAT_COLOR_REASONS = {
    tankAggro = true, tankLosing = true, tankNoAggro = true,
    offTank = true, tankTakeover = true, dpsAggro = true,
    threatHigh = true, threatNone = true, solo = true,
    nonTankTarget = true, outOfCombat = true,
}

local function UpdateHealthColor(self)
    if not self.unit then
        return
    end
    local red, green, blue, reason = ResolveHealthColor(self)
    self._colorReason = reason
    self._isThreatColor = THREAT_COLOR_REASONS[reason] == true
    if self._resolvedRed == red and self._resolvedGreen == green
        and self._resolvedBlue == blue and self._lastColorReason == reason then
        return
    end
    self._lastColorReason = reason
    self._resolvedRed, self._resolvedGreen, self._resolvedBlue = red, green, blue
    if not self._isThreatColor or NP.Setting("threat", "healthBarColor", true) then
        self.health:SetStatusBarColor(red, green, blue, 1)
    else
        local baseRed, baseGreen, baseBlue = ResolveBaseColor(self)
        self.health:SetStatusBarColor(baseRed, baseGreen, baseBlue, 1)
    end
    if self._isThreatColor and NP.Setting("threat", "nameColor", false) then
        self.name:SetTextColor(red, green, blue, 1)
    else
        self.name:SetTextColor(1, 1, 1, 1)
    end
end


-- Für andere Nameplate-Dateien sichtbar machen
NP.GetThreatStatus = GetThreatStatus
NP.RefreshRoleContext = RefreshRoleContext
NP.UpdateClassificationState = UpdateClassificationState
NP.UpdateHealthColor = UpdateHealthColor
