-- ============================================================
-- RexUI_Config – Core.lua
-- Konfigurationssystem
-- ============================================================

local RexUI = _G["RexUI"]

if not RexUI then
    return
end

RexUI.ConfigUI = {}
local ConfigUI = RexUI.ConfigUI

local function T(text)
    return RexUI:LocalizeText(text)
end

-- ------------------------------------------------------------
-- LOKALE VARIABLEN
-- ------------------------------------------------------------

ConfigUI.Window = nil

-- ------------------------------------------------------------
-- FENSTER ÖFFNEN
-- ------------------------------------------------------------

function ConfigUI:Open()

    if not self.Window then
        return
    end

    if self.SetMinimized then
        self:SetMinimized(false)
    end
    self.Window:Show()
end

-- ------------------------------------------------------------
-- FENSTER SCHLIEßEN
-- ------------------------------------------------------------

function ConfigUI:Close()

    if not self.Window then
        return
    end

    self.Window:Hide()
end

-- ------------------------------------------------------------
-- FENSTER UMSCHALTEN
-- ------------------------------------------------------------

function ConfigUI:Toggle()

    if not self.Window then
        return
    end

    if self.Window:IsShown() then
        self:Close()
    else
        self:Open()
    end
end

-- ------------------------------------------------------------
-- DIREKT ZU EINER EINSTELLUNGSSEITE
-- ------------------------------------------------------------

function ConfigUI:OpenActionBarSettings(barKey)

    self.selectedBar = barKey or self.selectedBar or "Bar1"
    self:Open()

    if self.SetCategory then
        self:SetCategory("Actionbars")
    end
end

function ConfigUI:OpenMicroMenuSettings()

    self.selectedBar = "MicroMenu"
    self:Open()

    if self.SetCategory then
        self:SetCategory("Actionbars")
    end
end

-- Direkter Sprung vom UnitFrame-Mover in den passenden UnitFrames-Tab.
function ConfigUI:OpenUnitFrameSettings(unitKey)
    local map = {
        player = "player", Spieler = "player",
        target = "target", ["Ziel"] = "target",
        focus = "focus", Fokus = "focus",
        pet = "pet", Begleiter = "pet",
        boss = "boss", Boss = "boss",
    }

    self.UnitFrameMainTab = map[unitKey] or self.UnitFrameMainTab or "player"
    self:Open()

    if self.SetCategory then
        self:SetCategory("UnitFrames")
    end
end

function ConfigUI:OpenNameplateSettings()
    self.NameplateSubTab = "general"
    self:Open()

    if self.SetCategory then
        self:SetCategory("Nameplates")
    end
end

-- ------------------------------------------------------------
-- INITIALISIERUNG
-- ------------------------------------------------------------

function ConfigUI:Init()

    if self.CreateWindow then
        self:CreateWindow()
    end
end

-- ------------------------------------------------------------
-- START
-- Warten auf PLAYER_LOGIN damit alle Module (inkl. ActionBars)
-- vollständig geladen sind, bevor das ConfigUI gebaut wird.
-- ------------------------------------------------------------

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    if RexUI.ConfigUI and RexUI.ConfigUI.Init then
        RexUI.ConfigUI:Init()
    end
end)
-- ------------------------------------------------------------
-- RESET POPUP
-- ------------------------------------------------------------

function ConfigUI:BringPopupToFront(dialog)
    if not dialog then return end
    dialog:SetFrameStrata("TOOLTIP")
    dialog:SetFrameLevel(1000)
    if dialog.Raise then dialog:Raise() end
end

StaticPopupDialogs["REXUI_RESET"] = {

    text = T("Alle RexUI-Profile und Einstellungen für alle Charaktere löschen?\n\nDiese Aktion kann nicht rückgängig gemacht werden."),

    button1 = T("Alles löschen"),

    button2 = T("Nein"),

    OnAccept = function()

        if RexUI.ClearPersistedDatabase then
            RexUI:ClearPersistedDatabase()
        end

        RexUIDB = nil
        RexUICharDB = nil

        ReloadUI()
    end,

    OnShow = function(dialog)
        ConfigUI:BringPopupToFront(dialog)
    end,

    timeout = 0,

    whileDead = true,

    hideOnEscape = true,

    preferredIndex = 3,
}
