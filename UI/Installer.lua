-- ============================================================
-- RexUI - UI/Installer.lua
-- Geführter Installationsassistent (P3): Rolle, Layout, CVars, Abschluss.
-- Wird beim ersten Start statt des reinen Welcome-Screens gezeigt und ist
-- jederzeit über /rexui install erreichbar.
-- ============================================================

local ADDON_NAME, ns = ...
local RexUI = ns.RexUI
if not RexUI then return end

RexUI.Installer = RexUI.Installer or {}
local Installer = RexUI.Installer

local function T(text)
    return RexUI:LocalizeText(text)
end

local WHITE = "Interface\\Buttons\\WHITE8X8"

-- ------------------------------------------------------------
-- Datengrundlage
-- ------------------------------------------------------------

Installer.Roles = {
    { key = "TANK",    label = "Tank",   description = "Bedrohungsfarben und Aggro-Rahmen auf Namensplaketten an, Fokus hervorgehoben." },
    { key = "HEALER",  label = "Heiler", description = "Freundliche Namensplaketten mit Klassenfarben, Schadensmeter zeigt Heilung." },
    { key = "DAMAGER", label = "Schaden", description = "Gegnertypen und Zauberwirker farblich hervorgehoben, Schadensmeter zeigt Schaden." },
}

Installer.Layouts = {
    { key = "classic", label = "Klassisch", description = "Drei Leisten à 12 Buttons untereinander, 32 px." },
    { key = "compact", label = "Kompakt",   description = "Bar 1 und 2 als 2 × 6-Blöcke, Bar 3 seitlich vertikal – wenig Platzbedarf." },
    { key = "minimal", label = "Minimal",   description = "Wie Klassisch, aber ohne Hotkey-/Stapeltexte und ohne Button-Hintergrund." },
}

-- Empfohlene CVars (Name, Wert, Beschreibung). Nur Werte, die keine
-- Neuladung benötigen und keinen Kampfschutz berühren.
Installer.CVars = {
    { "nameplateShowEnemies", "1", "Gegnerische Namensplaketten anzeigen" },
    { "nameplateMotion", "1", "Namensplaketten stapeln statt überlappen" },
    { "nameplateMaxDistance", "60", "Sichtweite der Namensplaketten 60 m" },
    { "nameplateOtherTopInset", "0.08", "Abstand der Plaketten zum oberen Bildschirmrand" },
    { "cameraDistanceMaxZoomFactor", "2.6", "Maximaler Kamera-Zoom" },
    { "autoLootDefault", "1", "Automatisches Plündern" },
    { "ScreenshotQuality", "10", "Screenshot-Qualität maximal" },
    { "floatingCombatTextCombatDamage", "0", "Blizzard-Schadenszahlen über Gegnern aus" },
}

-- ------------------------------------------------------------
-- Anwenden
-- ------------------------------------------------------------

function Installer:DetectRole()
    local role = GetSpecializationRole and GetSpecialization and GetSpecializationRole(GetSpecialization() or 0)
    if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
        return role
    end
    return "DAMAGER"
end

function Installer:ApplyRole(roleKey)
    local profile = RexUI:GetProfile()
    if not profile then return end
    profile.nameplates = profile.nameplates or {}
    local np = profile.nameplates
    np.enabled = true
    np.threat = np.threat or {}
    np.general = np.general or {}
    np.target = np.target or {}
    profile.damageMeter = profile.damageMeter or {}

    -- Erst einen eindeutigen gemeinsamen Ausgangszustand setzen. So entfernt
    -- ein späterer Rollenwechsel auch Werte der zuvor gewählten Rolle.
    np.general.showFriendly = roleKey == "HEALER"
    np.general.friendlyClassColors = roleKey == "HEALER"
    np.general.friendlyNPCsNameOnly = roleKey == "HEALER"
    np.target.focusScale = roleKey == "TANK" and 1.1 or 1.0
    np.threat.enabled = roleKey ~= "HEALER"
    np.threat.aggroGlow = roleKey == "TANK"
    np.threat.borderColor = roleKey == "TANK"
    np.threat.unitTypeColoring = roleKey == "DAMAGER"
    np.threat.casterColor = roleKey == "DAMAGER"
    profile.damageMeter.enabled = true
    profile.damageMeter.windows = profile.damageMeter.windows or {}
    profile.damageMeter.windows[1] = profile.damageMeter.windows[1] or {}
    if roleKey ~= "HEALER" then
        profile.damageMeter.windows[1].display = 0
    end

    if roleKey == "TANK" then
        np.target.focusBorder = true
    elseif roleKey == "HEALER" then
        if Enum and Enum.DamageMeterType and Enum.DamageMeterType.HealingDone then
            profile.damageMeter.windows[1].display = Enum.DamageMeterType.HealingDone
        end
    end

    profile.installerRole = roleKey
end

function Installer:ApplyLayout(layoutKey)
    local AB = RexUI.ActionBars
    if not AB or not AB.ApplyLayoutPreset then return end
    local profile = RexUI:GetProfile()
    local actionbars = profile and AB.GetCurrentActionBarDB and AB:GetCurrentActionBarDB(profile)

    local function SetBarValues(barKey, values)
        AB.Config[barKey] = AB.Config[barKey] or {}
        if actionbars then actionbars[barKey] = actionbars[barKey] or {} end
        for key, value in pairs(values) do
            AB.Config[barKey][key] = value
            if actionbars then actionbars[barKey][key] = value end
        end
        if AB.InvalidateConfigCache then AB:InvalidateConfigCache(barKey) end
        if AB.UpdateBar then AB:UpdateBar(barKey) end
    end

    if layoutKey == "compact" then
        AB:ApplyLayoutPreset("Bar1", "compact")
        AB:ApplyLayoutPreset("Bar2", "compact")
        AB:ApplyLayoutPreset("Bar3", "side")
        SetBarValues("Bar1", { enabled = true, hidden = false, point = "CENTER", relPoint = "CENTER", x = -105, y = -240, showHotkey = true, showCount = true, showButtonBackground = true })
        SetBarValues("Bar2", { enabled = true, hidden = false, point = "CENTER", relPoint = "CENTER", x = 105, y = -240, showHotkey = true, showCount = true, showButtonBackground = true })
        SetBarValues("Bar3", { enabled = true, hidden = false, point = "CENTER", relPoint = "CENTER", x = 240, y = -240, showHotkey = true, showCount = true, showButtonBackground = true })
    elseif layoutKey == "minimal" then
        for _, barKey in ipairs({ "Bar1", "Bar2", "Bar3" }) do
            AB:ApplyLayoutPreset(barKey, "classic")
            AB:ApplyLayoutPreset(barKey, "minimal")
        end
        SetBarValues("Bar1", { enabled = true, hidden = false, point = "CENTER", relPoint = "CENTER", x = 0, y = -260 })
        SetBarValues("Bar2", { enabled = true, hidden = false, point = "CENTER", relPoint = "CENTER", x = 0, y = -220 })
        SetBarValues("Bar3", { enabled = true, hidden = false, point = "CENTER", relPoint = "CENTER", x = 0, y = -180 })
    else
        for _, barKey in ipairs({ "Bar1", "Bar2", "Bar3" }) do
            AB:ApplyLayoutPreset(barKey, "classic")
        end
        SetBarValues("Bar1", { enabled = true, hidden = false, point = "CENTER", relPoint = "CENTER", x = 0, y = -260, showHotkey = true, showCount = true, showButtonBackground = true })
        SetBarValues("Bar2", { enabled = true, hidden = false, point = "CENTER", relPoint = "CENTER", x = 0, y = -220, showHotkey = true, showCount = true, showButtonBackground = true })
        SetBarValues("Bar3", { enabled = true, hidden = false, point = "CENTER", relPoint = "CENTER", x = 0, y = -180, showHotkey = true, showCount = true, showButtonBackground = true })
    end

    if profile then
        profile.installerLayout = layoutKey
    end
end

function Installer:ApplyCVars()
    local applied = 0
    for _, entry in ipairs(self.CVars) do
        if SetCVar then
            local ok = pcall(SetCVar, entry[1], entry[2])
            if ok then applied = applied + 1 end
        end
    end
    return applied
end

function Installer:Finish(openEditor)
    local profile = RexUI:GetProfile()
    -- Die endgültige Auswahl erneut anwenden. Dadurch funktioniert auch ein
    -- Abschluss nach einem zurück/vor-Wechsel zuverlässig und unabhängig
    -- davon, wann die ActionBars beim ersten Login initialisiert wurden.
    self:ApplyRole(self.selectedRole or self:DetectRole())
    self:ApplyLayout(self.selectedLayout or "classic")
    if profile then
        profile.firstLaunch = false
        profile.installerCompleted = true
    end
    if RexUI.ApplyProfileSettings then
        pcall(RexUI.ApplyProfileSettings, RexUI)
    end
    if self.frame then self.frame:Hide() end
    if openEditor and RexUI.ConfigUI and RexUI.ConfigUI.Open then
        RexUI.ConfigUI:Open()
    end
    RexUI:PrintMessage(T("Einrichtung abgeschlossen. /rexui öffnet die Konfiguration."))
end

-- ------------------------------------------------------------
-- Oberfläche
-- ------------------------------------------------------------

local function StyleBackdrop(frame, bgAlpha)
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(0.05, 0.02, 0.08, bgAlpha or 0.96)
    frame:SetBackdropBorderColor(0.45, 0.12, 0.65, 0.95)
end

local function CreateButton(parent, text, width, height, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 160, height or 32)
    StyleBackdrop(button, 0.95)
    button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.Text:SetPoint("CENTER")
    button.Text:SetText(T(text))
    button.Text:SetTextColor(0.9, 0.85, 1, 1)
    button:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.85, 0.35, 1, 1) end)
    button:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.45, 0.12, 0.65, 0.95) end)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreateChoice(parent, entry, index, selectedKey, onSelect)
    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    card:SetSize(720, 62)
    card:SetPoint("TOPLEFT", 40, -130 - (index - 1) * 72)
    StyleBackdrop(card, 0.9)
    card.Title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.Title:SetPoint("TOPLEFT", 16, -10)
    card.Title:SetText(T(entry.label))
    card.Desc = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.Desc:SetPoint("TOPLEFT", 16, -34)
    card.Desc:SetPoint("RIGHT", -16, 0)
    card.Desc:SetJustifyH("LEFT")
    card.Desc:SetText(T(entry.description))
    local function Refresh(selected)
        if selected then
            card:SetBackdropColor(0.26, 0.07, 0.34, 0.95)
            card:SetBackdropBorderColor(0.85, 0.35, 1, 1)
        else
            card:SetBackdropColor(0.05, 0.02, 0.08, 0.9)
            card:SetBackdropBorderColor(0.45, 0.12, 0.65, 0.95)
        end
    end
    card.Refresh = Refresh
    Refresh(selectedKey == entry.key)
    card:SetScript("OnClick", function() onSelect(entry.key) end)
    return card
end

function Installer:Create()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "RexUIInstallerFrame", UIParent, "BackdropTemplate")
    frame:SetSize(820, 620)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    StyleBackdrop(frame, 0.97)

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.Title:SetPoint("TOP", 0, -22)
    frame.Title:SetTextColor(0.85, 0.25, 1, 1)

    frame.Step = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Step:SetPoint("TOPRIGHT", -20, -16)

    frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Text:SetPoint("TOPLEFT", 40, -70)
    frame.Text:SetPoint("RIGHT", -40, 0)
    frame.Text:SetJustifyH("LEFT")
    frame.Text:SetJustifyV("TOP")
    frame.Text:SetHeight(50)

    frame.Content = CreateFrame("Frame", nil, frame)
    frame.Content:SetPoint("TOPLEFT", 0, -120)
    frame.Content:SetPoint("BOTTOMRIGHT", 0, 70)

    frame.Back = CreateButton(frame, "Zurück", 140, 32, function() Installer:GoTo(Installer.step - 1) end)
    frame.Back:SetPoint("BOTTOMLEFT", 30, 22)
    frame.Skip = CreateButton(frame, "Überspringen", 160, 32, function() Installer:Finish(false) end)
    frame.Skip:SetPoint("BOTTOM", 0, 22)
    frame.Next = CreateButton(frame, "Weiter", 140, 32, function() Installer:Advance() end)
    frame.Next:SetPoint("BOTTOMRIGHT", -30, 22)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() frame:Hide() end)

    self.frame = frame
    self.widgets = {}
    return frame
end

function Installer:ClearContent()
    for _, widget in ipairs(self.widgets or {}) do
        widget:Hide()
        widget:SetParent(nil)
    end
    self.widgets = {}
end

local STEPS = { "welcome", "role", "layout", "cvars", "finish" }

function Installer:GoTo(index)
    index = math.max(1, math.min(#STEPS, index or 1))
    self.step = index
    local frame = self:Create()
    self:ClearContent()

    local stepKey = STEPS[index]
    frame.Step:SetText(string.format(T("Schritt %d von %d"), index, #STEPS))
    frame.Back:SetShown(index > 1)
    frame.Skip:SetShown(index < #STEPS)
    frame.Next.Text:SetText(T(index == #STEPS and "Fertig" or "Weiter"))

    local widgets = self.widgets
    local content = frame.Content

    if stepKey == "welcome" then
        frame.Title:SetText("RexUI Eternal " .. (RexUI.GetVersion and RexUI:GetVersion() or ""))
        frame.Text:SetText(T("Willkommen! Dieser Assistent richtet RexUI in wenigen Schritten ein: Rolle, Actionbar-Layout und empfohlene Spieleinstellungen. Alles lässt sich später unter /rexui ändern."))
        local logo = content:CreateTexture(nil, "ARTWORK")
        -- Das vollständige 860x700-Bild proportional in den Inhaltsbereich
        -- einpassen. Die frühere TexCoord zeigte nur einen schmalen Ausschnitt.
        logo:SetSize(528, 430)
        logo:SetPoint("CENTER")
        local welcomeTexture = RexUI.isGerman and "welcome" or "welcome_enUS"
        logo:SetTexture("Interface\\AddOns\\RexUI\\media\\welcome\\" .. welcomeTexture)
        logo:SetTexCoord(0, 1, 0, 1)
        widgets[#widgets + 1] = logo
    elseif stepKey == "role" then
        frame.Title:SetText(T("Rolle"))
        frame.Text:SetText(T("Wähle deine Hauptrolle. RexUI passt Namensplaketten und Schadensmeter passend an. Erkannt wurde:") .. " " .. T(self.selectedRole == "TANK" and "Tank" or self.selectedRole == "HEALER" and "Heiler" or "Schaden"))
        local cards = {}
        for i, entry in ipairs(self.Roles) do
            cards[i] = CreateChoice(frame, entry, i, self.selectedRole, function(key)
                self.selectedRole = key
                for j, c in ipairs(cards) do c.Refresh(self.Roles[j].key == key) end
            end)
            widgets[#widgets + 1] = cards[i]
        end
    elseif stepKey == "layout" then
        frame.Title:SetText(T("Actionbar-Layout"))
        frame.Text:SetText(T("Wähle ein Ausgangslayout für Bar 1 bis 3. Größe, Reihen und Position kannst du danach im Editor frei anpassen."))
        local cards = {}
        for i, entry in ipairs(self.Layouts) do
            cards[i] = CreateChoice(frame, entry, i, self.selectedLayout, function(key)
                self.selectedLayout = key
                for j, c in ipairs(cards) do c.Refresh(self.Layouts[j].key == key) end
            end)
            widgets[#widgets + 1] = cards[i]
        end
    elseif stepKey == "cvars" then
        frame.Title:SetText(T("Spieleinstellungen"))
        frame.Text:SetText(T("Diese Einstellungen (CVars) empfiehlt RexUI. Sie werden beim Klick auf Weiter gesetzt, wenn der Haken aktiv ist."))
        local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 40, -125)
        check:SetChecked(self.applyCVars ~= false)
        check:SetScript("OnClick", function(btn) self.applyCVars = btn:GetChecked() == true end)
        local checkLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        checkLabel:SetPoint("LEFT", check, "RIGHT", 6, 0)
        checkLabel:SetText(T("Empfohlene Einstellungen übernehmen"))
        widgets[#widgets + 1] = check
        widgets[#widgets + 1] = checkLabel
        for i, entry in ipairs(self.CVars) do
            local line = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            line:SetPoint("TOPLEFT", 60, -165 - (i - 1) * 22)
            line:SetText(string.format("|cff9ad9ff%s|r = %s   –   %s", entry[1], entry[2], T(entry[3])))
            widgets[#widgets + 1] = line
        end
    elseif stepKey == "finish" then
        frame.Title:SetText(T("Fertig"))
        frame.Text:SetText(T("RexUI ist eingerichtet. Mit /rexui öffnest du jederzeit den Editor; Entsperren zeigt Mover für alle Elemente."))
        local summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        summary:SetPoint("TOPLEFT", 40, -140)
        summary:SetJustifyH("LEFT")
        summary:SetText(string.format("%s: %s\n%s: %s\n%s: %s",
            T("Rolle"), T(self.selectedRole == "TANK" and "Tank" or self.selectedRole == "HEALER" and "Heiler" or "Schaden"),
            T("Layout"), T(self.selectedLayout == "compact" and "Kompakt" or self.selectedLayout == "minimal" and "Minimal" or "Klassisch"),
            T("Spieleinstellungen"), T(self.applyCVars ~= false and "übernommen" or "unverändert")))
        widgets[#widgets + 1] = summary
        local openEditor = CreateButton(frame, "Editor öffnen", 200, 34, function() Installer:Finish(true) end)
        openEditor:SetPoint("TOPLEFT", 40, -230)
        widgets[#widgets + 1] = openEditor
    end

    frame:Show()
end

function Installer:Advance()
    local stepKey = STEPS[self.step or 1]
    if stepKey == "role" then
        self:ApplyRole(self.selectedRole)
    elseif stepKey == "layout" then
        self:ApplyLayout(self.selectedLayout)
    elseif stepKey == "cvars" then
        if self.applyCVars ~= false then
            local count = self:ApplyCVars()
            RexUI:PrintMessage(string.format(T("%d Spieleinstellungen gesetzt."), count))
        end
    elseif stepKey == "finish" then
        self:Finish(false)
        return
    end
    self:GoTo((self.step or 1) + 1)
end

function Installer:Show()
    self.selectedRole = self.selectedRole or self:DetectRole()
    self.selectedLayout = self.selectedLayout or "classic"
    if self.applyCVars == nil then self.applyCVars = true end
    self:GoTo(1)
end

