-- ============================================================
-- RexUI_Comfort – CombatLog.lua
-- Automatisches Kampflog für Raids
-- ============================================================

local ADDON_NAME, ns = ...

local RexUI =
    ns.RexUI

if not RexUI
or not RexUI.Comfort then
    return
end

local Comfort =
    RexUI.Comfort

-- ------------------------------------------------------------
-- LOKALE VARIABLEN
-- ------------------------------------------------------------

local CombatLog = CreateFrame("Frame")
local lastState = nil

-- ------------------------------------------------------------
-- PROFIL
-- ------------------------------------------------------------

local function GetMode()

    local profile = Comfort:GetProfile()
    if not profile then
        return "OFF"
    end

    return profile.combatLogMode or "OFF"
end

-- ------------------------------------------------------------
-- INSTANZ PRÜFEN
-- ------------------------------------------------------------

local function ShouldEnableLog()

    local mode = GetMode()

    if mode == "OFF" then
        return false
    end

    local inInstance, instanceType = IsInInstance()

    if not inInstance then
        return false
    end

    local isRaid = instanceType == "raid"
    -- Retail profiles may still contain BOTH; retain its Raid behavior.
    return isRaid and (mode == "RAID" or mode == "BOTH")
end

-- ------------------------------------------------------------
-- KAMPFLOG AKTUALISIEREN
-- ------------------------------------------------------------

local function UpdateCombatLog()

    local enabled = ShouldEnableLog()

    if lastState == enabled then
        return
    end

    lastState = enabled

    LoggingCombat(enabled)
end

-- ------------------------------------------------------------
-- EVENTS
-- ------------------------------------------------------------

CombatLog:RegisterEvent("PLAYER_ENTERING_WORLD")
CombatLog:RegisterEvent("ZONE_CHANGED_NEW_AREA")

CombatLog:SetScript("OnEvent", function()
    C_Timer.After(1, function()
        UpdateCombatLog()
    end)
end)

-- ------------------------------------------------------------
-- REGISTRIERUNG
-- ------------------------------------------------------------

Comfort:RegisterModule("CombatLog", CombatLog)
