-- ============================================================
-- RexUI - Nameplates / Init
-- Legt das Modul und den geteilten internen Namensraum an. Muss vor allen
-- anderen Nameplate-Dateien geladen werden.
-- ============================================================

local ADDON_NAME, ns = ...
local RexUI = ns.RexUI
if not RexUI then return end

local Nameplates = RexUI:CreateModule("Nameplates")
RexUI.Nameplates = Nameplates

-- Interner Namensraum für Funktionen, Tabellen und Konstanten, die mehrere
-- Nameplate-Dateien gemeinsam nutzen.
Nameplates.Internal = {}
