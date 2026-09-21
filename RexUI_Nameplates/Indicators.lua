-- ============================================================
-- RexUI - Nameplates / Indicators
-- Ausgelagert aus Core.lua; gemeinsamer Zustand liegt in Nameplates.Internal (NP).
-- ============================================================

local ADDON_NAME, ns = ...
local RexUI = ns.RexUI
if not RexUI or not RexUI.Nameplates then return end

local Nameplates = RexUI.Nameplates
local NP = Nameplates.Internal
local Perf = RexUI.Perf

local GetRaidTargetIndex = GetRaidTargetIndex
local SetRaidTargetIconTexture = SetRaidTargetIconTexture
local UnitThreatSituation = UnitThreatSituation

local function IsQuestUnit(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit
        and Enum and Enum.TooltipDataLineType) then
        return false
    end
    local ok, info = pcall(C_TooltipInfo.GetUnit, unit)
    if not ok or not info or not info.lines then return false end
    local lineTypes = Enum.TooltipDataLineType
    local questID
    for _, line in ipairs(info.lines) do
        local lineType = line.type
        if NP.CanAccess(lineType) and lineType == lineTypes.QuestTitle then
            questID = NP.IsAccessibleNumber(line.id) and line.id or nil
        elseif NP.CanAccess(lineType) and lineType == lineTypes.QuestObjective then
            local completed = NP.AccessibleBoolean(line.completed)
            local owned = true
            if questID and C_QuestLog and C_QuestLog.IsOnQuest then
                local questOK, isOnQuest = pcall(C_QuestLog.IsOnQuest, questID)
                owned = questOK and isOnQuest == true
            end
            if completed == false and owned then return true end
        end
    end
    return false
end

local function ApplyClassificationIndicator(texture, kind)
    if not texture then return end
    texture:SetDesaturated(false)
    texture:SetVertexColor(1, 1, 1, 1)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetSize(12, 12)

    if kind == "elite" then
        texture:SetTexture("Interface\\GLUES\\CharacterSelect\\Glues-AddOn-Icons")
        texture:SetTexCoord(0.75, 1, 0, 1)
        texture:SetVertexColor(1, 0.8, 0, 1)
    elseif kind == "rare" then
        texture:SetTexture("Interface\\GLUES\\CharacterSelect\\Glues-AddOn-Icons")
        texture:SetTexCoord(0.75, 1, 0, 1)
        texture:SetDesaturated(true)
    elseif kind == "worldboss" then
        texture:SetTexture("Interface\\Scenarios\\ScenarioIcon-Boss")
    else
        texture:Hide()
        return
    end
    texture:Show()
end

local function ClassificationStyle(plate, settings)
    if settings.boss and (plate._skullBoss or plate._isWorldBoss or plate._classification == "worldboss") then
        return "worldboss"
    end
    if settings.rare and (plate._isRareElite or plate._classification == "rareelite") then
        return "elite", "rare"
    end
    if settings.rare and (plate._isRare or plate._classification == "rare") then
        return "rare"
    end
    if settings.elite and (plate._isElite or plate._classification == "elite") then
        return "elite"
    end
    return nil
end

NP.RefreshPlateIndicators = function(plate, refreshQuest)
    if not plate or not plate.unit or not plate.raidMarker then return end
    local settings = Nameplates.settings.indicators

    local raidIndex
    if settings.raidMarker ~= false and GetRaidTargetIndex then
        raidIndex = GetRaidTargetIndex(plate.unit)
    end

    -- Midnight can return the raid-target index as a secret value. Do not
    -- inspect, compare or type-check it here. Plater passes that value straight
    -- back into Blizzard's SetRaidTargetIconTexture helper, which is allowed.
    -- Evaluate visibility with Blizzard's curve helper so the secret value is
    -- never branched on in Lua.
    if raidIndex ~= nil and SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(plate.raidMarker, raidIndex)
        if C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
            local hasMark = raidIndex ~= nil
            plate.raidMarker:SetAlpha(C_CurveUtil.EvaluateColorValueFromBoolean(hasMark, 1, 0))
            plate.raidMarker:Show()
        else
            plate.raidMarker:SetAlpha(1)
            plate.raidMarker:Show()
        end
    else
        plate.raidMarker:Hide()
    end

    if refreshQuest then
        plate._questMob = IsQuestUnit(plate.unit)
    end
    local questShown = settings.quest ~= false and plate._questMob == true
    plate.questIndicator:SetShown(questShown)

    local afterPlate = plate.health
    local afterX = 26
    if plate.levelText and plate.levelText:IsShown() then
        afterPlate = plate.levelText
        afterX = 4
    elseif plate.targetRight and plate.targetRight:IsShown() then
        afterPlate = plate.targetRight
        afterX = 3
    end
    plate.questIndicator:ClearAllPoints()
    plate.questIndicator:SetPoint("LEFT", afterPlate, "RIGHT", afterX, 0)
    plate.classIndicator:ClearAllPoints()
    if questShown then
        plate.classIndicator:SetPoint("LEFT", plate.questIndicator, "RIGHT", 2, 0)
    else
        plate.classIndicator:SetPoint("LEFT", afterPlate, "RIGHT", afterX, 0)
    end

    local classKind, classKind2 = ClassificationStyle(plate, settings)
    if classKind then
        ApplyClassificationIndicator(plate.classIndicator, classKind)
    else
        plate.classIndicator:Hide()
    end
    if classKind2 then
        ApplyClassificationIndicator(plate.classIndicator2, classKind2)
    else
        plate.classIndicator2:Hide()
    end

    local aggro = false
    if settings.aggro and NP.Setting("threat", "aggroBlink", false) and UnitThreatSituation then
        local status = UnitThreatSituation("player", plate.unit)
        if NP.IsAccessibleNumber(status) then aggro = status >= 2 end
    end
    plate.aggroIndicator:SetShown(aggro)
    if plate.aggroBlinkAnimation then
        if aggro then
            if not plate.aggroBlinkAnimation:IsPlaying() then plate.aggroBlinkAnimation:Play() end
        else
            plate.aggroBlinkAnimation:Stop()
            plate.aggroIndicator:SetAlpha(1)
        end
    end
    local layoutKey = (questShown and "1" or "0") .. tostring(classKind or "") .. tostring(classKind2 or "")
    if plate._indicatorLayoutKey ~= layoutKey then
        plate._indicatorLayoutKey = layoutKey
        if NP.RefreshSideLayout then NP.RefreshSideLayout(plate) end
    end
end
