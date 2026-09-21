-- ============================================================
-- RexUI_Config – Window.lua
-- Hauptfenster der Konfiguration
-- ============================================================

local ADDON_NAME, ns = ...

local RexUI =
    ns.RexUI

if not RexUI
or not RexUI.ConfigUI then
    return
end

local ConfigUI =
    RexUI.ConfigUI

-- ------------------------------------------------------------
-- LOKALE VARIABLEN
-- ------------------------------------------------------------

local WINDOW_NAME = "RexUIConfigWindow"
local WINDOW_WIDTH = 1024
local WINDOW_HEIGHT = 720
local MOVER_WINDOW_WIDTH = 690
local MOVER_WINDOW_HEIGHT = 720

local function GetWindowScale()
    local screenWidth = UIParent and UIParent:GetWidth() or WINDOW_WIDTH
    local screenHeight = UIParent and UIParent:GetHeight() or WINDOW_HEIGHT
    local maxWidth = math.max(320, screenWidth - 40)
    local maxHeight = math.max(240, screenHeight - 40)
    local scale = math.min(1, maxWidth / WINDOW_WIDTH, maxHeight / WINDOW_HEIGHT)

    return math.max(0.65, scale)
end

-- ------------------------------------------------------------
-- FENSTER ERSTELLUNG
-- ------------------------------------------------------------

function ConfigUI:CreateWindow()

    local frame = CreateFrame("Frame", WINDOW_NAME, UIParent, "BackdropTemplate")

    local windowScale = GetWindowScale()
    local savedWindow = RexUIDB and RexUIDB.configWindow
    local savedWidth = savedWindow and tonumber(savedWindow.width) or WINDOW_WIDTH
    local savedHeight = savedWindow and tonumber(savedWindow.height) or WINDOW_HEIGHT
    local screenWidth = ((UIParent and UIParent:GetWidth()) or WINDOW_WIDTH) / windowScale
    local screenHeight = ((UIParent and UIParent:GetHeight()) or WINDOW_HEIGHT) / windowScale
    local maxWidth = math.max(920, math.min(1300, screenWidth - 40))
    local maxHeight = math.max(560, math.min(950, screenHeight - 40))
    savedWidth = math.max(920, math.min(savedWidth, maxWidth))
    savedHeight = math.max(560, math.min(savedHeight, maxHeight))
    frame:SetSize(savedWidth, savedHeight)
    frame:SetScale(windowScale)
    frame:SetPoint("CENTER")
    frame:SetClampedToScreen(true)
	
	-- The settings window must remain above unlock movers (which live in
	-- DIALOG), otherwise their labels and click areas bleed through it.
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100)

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        if self._isResizing then return end
        self._dragStartX, self._dragStartY = GetCursorPosition()
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        -- Die kompakte Mover-Position separat speichern. So kann das
        -- Einstellungsfenster beim naechsten Entsperren wieder genau dort
        -- erscheinen, ohne die normale Config-Position zu veraendern.
        if self.MoverCompact then
            RexUIDB = RexUIDB or {}
            RexUIDB.configWindow = RexUIDB.configWindow or {}
            local point, _, relativePoint, xOfs, yOfs = self:GetPoint(1)
            RexUIDB.configWindow.moverPoint = point
            RexUIDB.configWindow.moverRelativePoint = relativePoint
            RexUIDB.configWindow.moverX = xOfs
            RexUIDB.configWindow.moverY = yOfs
        end

        local x, y = GetCursorPosition()
        self._minimizeDragged = self._dragStartX
            and (math.abs(x - self._dragStartX) > 4 or math.abs(y - self._dragStartY) > 4)

        -- Keep the flag through the matching OnMouseUp event, then clear it.
        C_Timer.After(0, function()
            self._minimizeDragged = nil
        end)
    end)

    frame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.Minimized and not self._minimizeDragged and not self._minimizeIgnoreMouseUp then
            ConfigUI:SetMinimized(false)
        end
    end)

    RexUI:ApplyPanelStyle(frame)

frame:SetBackdropColor(0, 0, 0, 0)

local bgFrame = CreateFrame("Frame", nil, frame)
bgFrame:SetAllPoints(frame)
bgFrame:SetFrameLevel(0)

local bgA = bgFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
bgA:SetAllPoints(bgFrame)
bgA:SetTexture("Interface\\AddOns\\RexUI\\media\\background\\rex_bg")
bgA:SetAlpha(1)
bgA:SetTexCoord(0, 1, 0, 1)

local bgB = bgFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
bgB:SetAllPoints(bgFrame)
bgB:SetAlpha(0)
bgB:SetTexCoord(0, 1, 0, 1)

frame.BgFrame = bgFrame
frame.BgA = bgA
frame.BgB = bgB

frame:SetBackdropBorderColor(
    0.75,
    0.20,
    1.00,
    0.90
)

    frame:Hide()

    self.Window = frame

    if not tContains(UISpecialFrames, WINDOW_NAME) then
        tinsert(UISpecialFrames, WINDOW_NAME)
    end

    self:CreateTitle()
    self:CreateHeaderUnlockButton()
    self:CreateCloseButton()
	self:CreateMinimizeButton()

    self:CreateCategories()
    self:CreateSettingsPanel()
    self:CreateResizeGrip()

    -- Normale Config und kompakter Mover speichern getrennte Groessen.
    -- Dadurch kann der Resize-Griff in beiden Modi verwendet werden, ohne
    -- dass ein Modus den anderen beim naechsten Oeffnen aufzieht.

    self:SetCategory("Start")

    -- Das Layout skaliert auf kleineren Bildschirmen automatisch herunter.
end

-- ------------------------------------------------------------
-- KOMPAKTER MOVER-MODUS
-- Beim Entsperren bleibt die aktuell geoeffnete Einstellungsseite sichtbar,
-- aber die Navigation wird ausgeblendet und das Fenster schmal.
-- ------------------------------------------------------------

function ConfigUI:SetMoverCompactMode(enabled)
    local window = self.Window
    if not window or not window:IsShown() then return end

    enabled = enabled == true
    if window.MoverCompact == enabled then return end
    window.MoverCompact = enabled
    self:UpdateResizeBounds()

    if enabled then
        if self.SetMinimized then self:SetMinimized(false) end

        if window.SetResizable then window:SetResizable(true) end
        if window.ResizeGrip then window.ResizeGrip:Show() end

        -- Normale Position merken, damit Sperren wieder exakt zur normalen
        -- Config zurueckkehrt.
        window.NormalPoint = { window:GetPoint(1) }
        window.NormalSize = { window:GetWidth(), window:GetHeight() }

        local cfg = RexUIDB and RexUIDB.configWindow
        local moverWidth = cfg and tonumber(cfg.moverWidth) or MOVER_WINDOW_WIDTH
        local moverHeight = cfg and tonumber(cfg.moverHeight) or MOVER_WINDOW_HEIGHT
        moverWidth = math.max(560, math.min(moverWidth, 1100))
        moverHeight = math.max(480, math.min(moverHeight, 900))
        window:SetSize(moverWidth, moverHeight)
        if window.CategoryPanel then window.CategoryPanel:Hide() end

        if window.SettingsPanel then
            window.SettingsPanel:ClearAllPoints()
            window.SettingsPanel:SetPoint("TOPLEFT", window, "TOPLEFT", 15, -82)
            window.SettingsPanel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -15, 50)
        end

        -- Gespeicherte Arbeitsposition verwenden. Beim ersten Mal rechts am
        -- Bildschirm platzieren, damit die zentralen ActionBars frei bleiben.
        window:ClearAllPoints()
        cfg = RexUIDB and RexUIDB.configWindow
        if cfg and cfg.moverPoint then
            window:SetPoint(cfg.moverPoint, UIParent, cfg.moverRelativePoint or cfg.moverPoint, cfg.moverX or 0, cfg.moverY or 0)
        else
            window:SetPoint("RIGHT", UIParent, "RIGHT", -24, 0)
        end
    else
        if window.ResizeGrip then window.ResizeGrip:Show() end
        if window.SetResizable then window:SetResizable(true) end
        local normalWidth = window.NormalSize and window.NormalSize[1] or WINDOW_WIDTH
        local normalHeight = window.NormalSize and window.NormalSize[2] or WINDOW_HEIGHT
        window:SetSize(normalWidth, normalHeight)
        if window.CategoryPanel then window.CategoryPanel:Show() end

        if window.SettingsPanel then
            window.SettingsPanel:ClearAllPoints()
            window.SettingsPanel:SetPoint("TOPLEFT", window, "TOPLEFT", 240, -82)
            window.SettingsPanel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -15, 50)
        end

        window:ClearAllPoints()
        if window.NormalPoint and window.NormalPoint[1] then
            window:SetPoint(unpack(window.NormalPoint))
        else
            window:SetPoint("CENTER")
        end
        window.NormalPoint = nil
        window.NormalSize = nil
    end
end

-- ------------------------------------------------------------
-- RESIZE-GRENZEN
-- Normale Config braucht genug Platz fuer Kategorien + rechte Seite.
-- Im kompakten Mover-Modus darf das Fenster deutlich schmaler werden.
-- ------------------------------------------------------------

function ConfigUI:UpdateResizeBounds()
    local f = self.Window
    if not f then return end

    local minW = f.MoverCompact and 560 or 920
    local minH = f.MoverCompact and 480 or 560
    local scale = math.max(0.01, f:GetScale() or 1)
    local screenW = ((UIParent and UIParent:GetWidth()) or 1920) / scale
    local screenH = ((UIParent and UIParent:GetHeight()) or 1080) / scale
    local maxW = math.max(minW, math.min(1300, screenW - 40))
    local maxH = math.max(minH, math.min(950, screenH - 40))

    if f.SetResizeBounds then
        f:SetResizeBounds(minW, minH, maxW, maxH)
    elseif f.SetMinResize then
        f:SetMinResize(minW, minH)
        if f.SetMaxResize then f:SetMaxResize(maxW, maxH) end
    end
end

-- ------------------------------------------------------------
-- RESIZE GRIFF
-- ------------------------------------------------------------

function ConfigUI:CreateResizeGrip()

    local f = self.Window
    if not f then return end

    if f.SetResizable then f:SetResizable(true) end

    -- Grenzen richten sich nach dem aktuellen Modus. Dadurch kann der
    -- Mover kompakt bleiben, waehrend die normale Config nie so schmal
    -- wird, dass die rechte Seite ueber die Kategorien laeuft.
    self:UpdateResizeBounds()

    local grip = CreateFrame("Frame", nil, f)
    grip:SetSize(22, 22)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    grip:SetFrameLevel(f:GetFrameLevel() + 20)

    local tex = grip:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(grip)
    tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

    grip:SetScript("OnEnter", function()
        tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    end)
    grip:SetScript("OnLeave", function()
        tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    end)
    local function FinishSizing()
        if not f._isResizing then return end
        f:StopMovingOrSizing()
        f._isResizing = nil
        RexUIDB = RexUIDB or {}
        RexUIDB.configWindow = RexUIDB.configWindow or {}
        local width = math.floor(f:GetWidth() + 0.5)
        local height = math.floor(f:GetHeight() + 0.5)
        if f.MoverCompact then
            RexUIDB.configWindow.moverWidth = width
            RexUIDB.configWindow.moverHeight = height
        else
            RexUIDB.configWindow.width = width
            RexUIDB.configWindow.height = height
        end
    end

    grip:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        f:StopMovingOrSizing()
        f._isResizing = true
        -- Der zweite Parameter bindet den Startpunkt an die aktuelle
        -- Mausposition. So springt das Fenster beim Greifen nicht mehr
        -- schlagartig auf die maximale Groesse.
        f:StartSizing("BOTTOMRIGHT", true)
    end)
    grip:SetScript("OnDragStop", FinishSizing)
    grip:SetScript("OnMouseUp", FinishSizing)

    grip:Show()
    f.ResizeGrip = grip
end

-- ------------------------------------------------------------
-- TITEL ERSTELLUNG
-- ------------------------------------------------------------

function ConfigUI:CreateTitle()

    local logo = self.Window:CreateTexture(nil, "ARTWORK")
    logo:SetSize(28, 28)
    logo:SetPoint("TOPLEFT", 18, -12)
    logo:SetTexture("Interface\\AddOns\\RexUI\\media\\logo")

    self.Window.Logo = logo

end

-- ------------------------------------------------------------
-- ZENTRALER UI ENTSPERREN / SPERREN BUTTON
-- Bleibt im Header immer erreichbar und nutzt ausschliesslich die
-- zentrale RexUI:ToggleUnlock()-Logik.
-- ------------------------------------------------------------

function ConfigUI:UpdateHeaderUnlockButton()
    local button = self.Window and self.Window.HeaderUnlockButton
    if not button then return end

    local unlocked = RexUI.Unlocked == true
    if button.Text then
        button.Text:SetText(unlocked and "UI sperren" or "UI entsperren")
    end

    if button.Background then
        if unlocked then
            button.Background:SetColorTexture(0.32, 0.08, 0.42, 0.96)
        else
            button.Background:SetColorTexture(0.12, 0.12, 0.14, 0.94)
        end
    end
end

function ConfigUI:CreateHeaderUnlockButton()
    local f = self.Window
    if not f then return end

    local button = CreateFrame("Button", nil, f, "BackdropTemplate")
    button:SetSize(126, 24)
    -- Unterhalb des RexUI-Logos, aber weiterhin komplett im Headerbereich.
    button:SetPoint("TOPLEFT", f, "TOPLEFT", 42, -47)
    button:SetFrameLevel(f:GetFrameLevel() + 10)

    button.Background = button:CreateTexture(nil, "BACKGROUND")
    button.Background:SetAllPoints()

    button.Border = button:CreateTexture(nil, "BORDER")
    button.Border:SetPoint("TOPLEFT", -1, 1)
    button.Border:SetPoint("BOTTOMRIGHT", 1, -1)
    button.Border:SetColorTexture(0.55, 0.18, 0.72, 0.85)

    local inner = button:CreateTexture(nil, "ARTWORK")
    inner:SetPoint("TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", -1, 1)
    inner:SetColorTexture(0.08, 0.08, 0.10, 1)
    button.Inner = inner

    -- Background liegt ueber Inner nur als Statusflaeche mit leichter Transparenz.
    button.Background:SetDrawLayer("ARTWORK", 1)
    button.Background:SetAlpha(0.82)

    button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.Text:SetPoint("CENTER", 0, 0)
    button.Text:SetTextColor(1, 1, 1, 1)

    button:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        if RexUI.ToggleUnlock then
            RexUI:ToggleUnlock()
        end
        ConfigUI:UpdateHeaderUnlockButton()
    end)

    button:SetScript("OnEnter", function(self)
        if self.Background then self.Background:SetAlpha(1) end
    end)
    button:SetScript("OnLeave", function(self)
        if self.Background then self.Background:SetAlpha(0.82) end
    end)

    f.HeaderUnlockButton = button
    self:UpdateHeaderUnlockButton()
end

-- ------------------------------------------------------------
-- SCHLIEßEN BUTTON
-- ------------------------------------------------------------

function ConfigUI:CreateCloseButton()

    local button = CreateFrame("Button", nil, self.Window)
    button:SetSize(28, 28)
    button:SetPoint("TOPRIGHT", -24, -18)

    button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    button.Text:SetPoint("CENTER")
    button.Text:SetText("X")
    button.Text:SetTextColor(RexUI:GetColor("highlight"))

    button:SetScript("OnClick", function()
        ConfigUI:Close()
    end)

    self.Window.CloseButton = button
end

-- ------------------------------------------------------------
-- MINIMIEREN BUTTON
-- ------------------------------------------------------------

function ConfigUI:CreateMinimizeButton()

    local button = CreateFrame("Button", nil, self.Window)
    button:SetSize(28, 28)
    button:SetPoint("RIGHT", self.Window.CloseButton, "LEFT", -4, 0)

    button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    button.Text:SetPoint("CENTER")
    button.Text:SetText("_")
    button.Text:SetTextColor(RexUI:GetColor("highlight"))

    button:SetScript("OnClick", function()
        local window = ConfigUI.Window
        if window then
            ConfigUI:SetMinimized(not window.Minimized)
        end
    end)

    self.Window.MinimizeButton = button
end

-- ------------------------------------------------------------
-- MINIMIZE / RESTORE
-- ------------------------------------------------------------

function ConfigUI:SetMinimized(minimized)
    local window = self.Window
    if not window or window.Minimized == minimized then return end

    window.Minimized = minimized == true
    if window.Minimized then
        window._minimizeIgnoreMouseUp = true
        C_Timer.After(0, function()
            window._minimizeIgnoreMouseUp = nil
        end)
        window.ExpandedHeight = window:GetHeight()

        if window.CategoryPanel then window.CategoryPanel:Hide() end
        if window.SettingsPanel then window.SettingsPanel:Hide() end
        if window.ResizeGrip then window.ResizeGrip:Hide() end

        window:SetHeight(48)
        return
    end

    if window.CategoryPanel then window.CategoryPanel:Show() end
    if window.SettingsPanel then window.SettingsPanel:Show() end
    if window.ResizeGrip then window.ResizeGrip:Show() end

    window:SetHeight(window.ExpandedHeight or WINDOW_HEIGHT)
end
