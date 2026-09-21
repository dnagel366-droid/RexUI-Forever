-- ============================================================
-- RexUI_Comfort – TalkingHead.lua
-- Talking Head Fenster ausblenden
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

local TalkingHead = CreateFrame("Frame")

-- ------------------------------------------------------------
-- PROFIL
-- ------------------------------------------------------------

local function IsEnabled()

    local profile = Comfort:GetProfile()
    if not profile then
        return false
    end

    return profile.hideTalkingHead == true
end

-- ------------------------------------------------------------
-- TALKING HEAD AUSBLENDEN
-- ------------------------------------------------------------

local function HideTalkingHead()

    if not IsEnabled() then
        return
    end

    if TalkingHeadFrame then
        TalkingHeadFrame:Hide()
    end
end

-- ------------------------------------------------------------
-- EVENTS
-- ------------------------------------------------------------

TalkingHead:RegisterEvent("TALKINGHEAD_REQUESTED")

TalkingHead:SetScript("OnEvent", function()
    C_Timer.After(0.1, function()
        HideTalkingHead()
    end)
end)

-- ------------------------------------------------------------
-- REGISTRIERUNG
-- ------------------------------------------------------------

Comfort:RegisterModule("TalkingHead", TalkingHead)