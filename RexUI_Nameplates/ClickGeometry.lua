-- ============================================================
-- RexUI - Nameplates / ClickGeometry
-- Ausgelagert aus Core.lua; gemeinsamer Zustand liegt in Nameplates.Internal (NP).
-- ============================================================

local ADDON_NAME, ns = ...
local RexUI = ns.RexUI
if not RexUI or not RexUI.Nameplates then return end

local Nameplates = RexUI.Nameplates
local NP = Nameplates.Internal
local Perf = RexUI.Perf

local CLICK_INSET = NP.CLICK_INSET
local PLATE_HEIGHT = NP.PLATE_HEIGHT
local PLATE_WIDTH = NP.PLATE_WIDTH

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown

NP.clickGeometryPending = false
local clickGeometryRetry = CreateFrame("Frame")
local originalScaleCVars

local function ApplyClickGeometry()
    if InCombatLockdown() then
        NP.clickGeometryPending = true
        clickGeometryRetry:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    NP.clickGeometryPending = false
    clickGeometryRetry:UnregisterEvent("PLAYER_REGEN_ENABLED")

    if Nameplates.settings.enabled == false then
        if originalScaleCVars and SetCVar then
            for key, value in pairs(originalScaleCVars) do
                if value ~= nil then pcall(SetCVar, key, value) end
            end
        end
        if C_NamePlateManager and C_NamePlateManager.SetNamePlateHitTestInsets
            and Enum and Enum.NamePlateType then
            pcall(C_NamePlateManager.SetNamePlateHitTestInsets, Enum.NamePlateType.Enemy, 0, 0, 0, 0)
            pcall(C_NamePlateManager.SetNamePlateHitTestInsets, Enum.NamePlateType.Friendly, 0, 0, 0, 0)
        end
        Nameplates.clickGeometrySupported = false
        return
    end

    -- Blizzard normally scales the native nameplate by distance and selection.
    -- RexUI owns target scaling itself; pinning the native base to 1 prevents
    -- two visually different bar geometries for otherwise identical mobs.
    if SetCVar then
        if not originalScaleCVars and GetCVar then
            originalScaleCVars = {
                nameplateMinScale = GetCVar("nameplateMinScale"),
                nameplateMaxScale = GetCVar("nameplateMaxScale"),
                nameplateSelectedScale = GetCVar("nameplateSelectedScale"),
                nameplateMotion = GetCVar("nameplateMotion"),
                nameplateOverlapV = GetCVar("nameplateOverlapV"),
            }
        end
        pcall(SetCVar, "nameplateMinScale", 1)
        pcall(SetCVar, "nameplateMaxScale", 1)
        pcall(SetCVar, "nameplateSelectedScale", 1)
        pcall(SetCVar, "nameplateMotion", NP.Setting("general", "stacking", true) and 1 or 0)
        local stackSpacing = math.max(0.5, math.min(2,
            tonumber(NP.Setting("general", "stackSpacing", 1)) or 1))
        pcall(SetCVar, "nameplateOverlapV", stackSpacing)
    end

    local sizeSupported = C_NamePlate and C_NamePlate.SetNamePlateSize
    local insetSupported = C_NamePlateManager
        and C_NamePlateManager.SetNamePlateHitTestInsets
        and Enum and Enum.NamePlateType

    local sizeOK = false
    local insetOK = false
    if sizeSupported then
        local configuredWidth = math.max(70, math.min(240,
            tonumber(NP.Setting("general", "hitboxWidth",
                NP.Setting("general", "enemyWidth", PLATE_WIDTH))) or PLATE_WIDTH))
        local configuredHeight = math.max(20, math.min(80,
            tonumber(NP.Setting("general", "hitboxHeight", PLATE_HEIGHT)) or PLATE_HEIGHT))
        sizeOK = pcall(C_NamePlate.SetNamePlateSize, configuredWidth, configuredHeight)
        if C_NamePlate.SetNamePlateFriendlySize then
            local friendlyWidth = math.max(70, math.min(240,
                tonumber(NP.Setting("general", "friendlyHitboxWidth", configuredWidth)) or configuredWidth))
            local friendlyHeight = math.max(20, math.min(80,
                tonumber(NP.Setting("general", "friendlyHitboxHeight", configuredHeight)) or configuredHeight))
            pcall(C_NamePlate.SetNamePlateFriendlySize, friendlyWidth, friendlyHeight)
        end
    end
    if insetSupported then
        local enemyOK = pcall(
            C_NamePlateManager.SetNamePlateHitTestInsets,
            Enum.NamePlateType.Enemy,
            CLICK_INSET, CLICK_INSET, CLICK_INSET, CLICK_INSET
        )
        -- Click-through für freundliche Plaketten: riesige positive Insets lassen
        -- keine klickbare Fläche übrig.
        local friendlyInset = NP.Setting("general", "friendlyClickThrough", false) and 10000 or CLICK_INSET
        local friendlyOK = pcall(
            C_NamePlateManager.SetNamePlateHitTestInsets,
            Enum.NamePlateType.Friendly,
            friendlyInset, friendlyInset, friendlyInset, friendlyInset
        )
        insetOK = enemyOK and friendlyOK
    end

    Nameplates.clickGeometrySupported = sizeOK and insetOK
end

clickGeometryRetry:SetScript("OnEvent", function()
    if NP.clickGeometryPending then
        ApplyClickGeometry()
    end
end)


-- Für andere Nameplate-Dateien sichtbar machen
NP.ApplyClickGeometry = ApplyClickGeometry
NP.clickGeometryRetry = clickGeometryRetry
