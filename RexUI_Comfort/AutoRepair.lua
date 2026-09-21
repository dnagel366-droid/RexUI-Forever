-- ============================================================
-- RexUI_Comfort – AutoRepair.lua
-- Automatische Reparatur beim Händler
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

local AutoRepair = CreateFrame("Frame")

-- ------------------------------------------------------------
-- PROFIL
-- ------------------------------------------------------------

local function IsEnabled()

    local profile = Comfort:GetProfile()
    if not profile then return false end

    return profile.autoRepair == true
end

-- ------------------------------------------------------------
-- REPARATUR
-- ------------------------------------------------------------

local function RepairItems()

    if not IsEnabled() then
        return
    end

    if not CanMerchantRepair() then
        return
    end

    local cost, canRepair = GetRepairAllCost()

    if not canRepair or not cost or cost <= 0 then
        return
    end

    if GetMoney() < cost then
        RexUI:PrintMessage("Nicht genug Gold für Reparatur.")
        return
    end

    RepairAllItems(false)

    local gold = math.floor(cost / 10000)
    local silver = math.floor((cost % 10000) / 100)

    RexUI:PrintMessage("Ausrüstung repariert für " .. gold .. "g " .. silver .. "s.")
end

-- ------------------------------------------------------------
-- EVENTS
-- ------------------------------------------------------------

AutoRepair:RegisterEvent("MERCHANT_SHOW")

AutoRepair:SetScript("OnEvent", function()
    RepairItems()
end)

-- ------------------------------------------------------------
-- REGISTRIERUNG
-- ------------------------------------------------------------

Comfort:RegisterModule("AutoRepair", AutoRepair)