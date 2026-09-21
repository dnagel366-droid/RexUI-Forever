-- ============================================================
-- RexUI_Comfort – Cinematics.lua
-- Cinematics automatisch überspringen
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

local Cinematics = CreateFrame("Frame")

-- ------------------------------------------------------------
-- PROFIL
-- ------------------------------------------------------------

local function IsEnabled()

    local profile = Comfort:GetProfile()
    if not profile then
        return false
    end

    return profile.skipCinematics == true
end

-- ------------------------------------------------------------
-- CINEMATICS
-- ------------------------------------------------------------

local function SkipCinematic()

    if not IsEnabled() then
        return
    end

    if MovieFrame and MovieFrame:IsShown() then
        MovieFrame:Hide()
    end

    if CinematicFrame and CinematicFrame:IsShown() then
        CinematicFrame_CancelCinematic()
    end

    RexUI:PrintMessage("Cinematic übersprungen.")
end

-- ------------------------------------------------------------
-- EVENTS
-- ------------------------------------------------------------

Cinematics:RegisterEvent("CINEMATIC_START")
Cinematics:RegisterEvent("PLAY_MOVIE")

Cinematics:SetScript("OnEvent", function()
    SkipCinematic()
end)

-- ------------------------------------------------------------
-- REGISTRIERUNG
-- ------------------------------------------------------------

Comfort:RegisterModule("Cinematics", Cinematics)