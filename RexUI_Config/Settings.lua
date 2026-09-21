-- ============================================================
-- RexUI_Config - Settings.lua
-- Rechter Einstellungsbereich der Konfiguration
-- ============================================================

local RexUI = _G["RexUI"]

if not RexUI or not RexUI.ConfigUI then
    return
end

local ConfigUI = RexUI.ConfigUI

local function T(text)
    return RexUI:LocalizeText(text)
end

local function CreateEditBox(parent, x, y, width, height, multiline)
    width = width or 220
    height = height or 28

    local box
    local backdrop

    if multiline then
        -- Profilstrings wie in RexHeal direkt in einer mehrzeiligen EditBox
        -- anzeigen. Das verschachtelte ScrollingEditBoxTemplate blieb auf
        -- manchen Clients unsichtbar.
        box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
        box:SetSize(width, height)
        box:SetPoint("TOPLEFT", x or 20, y or -100)
        box:SetClipsChildren(true)
        backdrop = box
    else
        box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
        box:SetSize(width, height)
        box:SetPoint("TOPLEFT", x or 20, y or -100)
        backdrop = box
    end

    box:SetAutoFocus(false)
    box:SetFontObject("GameFontNormal")
    box:SetTextInsets(8, 8, 6, 6)
    box:SetMultiLine(multiline == true)
    box:SetMaxLetters(0)
    box:EnableMouse(true)

    if multiline then
        box:SetJustifyH("LEFT")
        box:SetJustifyV("TOP")
    end

    backdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })

    backdrop:SetBackdropColor(0.08, 0.02, 0.12, 1)
    backdrop:SetBackdropBorderColor(0.45, 0.12, 0.65, 0.90)
    box:SetTextColor(1, 1, 1, 1)

    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    return box
end

local function CreateProfileStringBox(parent, x, y, width, height)
    width = width or 540
    height = height or 120

    -- RexHeal-Modell: eine direkte mehrzeilige EditBox, damit WoW den
    -- normalen Schreibcursor und die native Klickposition verwendet.
    local clip = CreateFrame("Frame", nil, parent)
    clip:SetSize(width, height)
    clip:SetPoint("TOPLEFT", x or 20, y or -100)
    clip:SetClipsChildren(true)

    local box = CreateFrame("EditBox", nil, clip, "BackdropTemplate")
    box:SetAllPoints()
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    box:SetBackdropColor(0.08, 0.02, 0.12, 1)
    box:SetBackdropBorderColor(0.45, 0.12, 0.65, 0.90)
    box:EnableMouse(true)
    box:SetAutoFocus(false)
    box:SetMultiLine(true)
    box:SetFontObject(ChatFontNormal)
    box:SetMaxLetters(0)
    box:SetTextColor(1, 1, 1, 1)
    box:SetJustifyH("LEFT")
    box:SetJustifyV("TOP")
    box:SetTextInsets(4, 4, 4, 4)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    box._rexClip = clip
    return box
end

local function CreateLabel(parent, text, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", x or 20, y or -100)
    label:SetText(T(text or ""))
    label:SetTextColor(RexUI:GetColor("text"))

    return label
end

local function CreateFlow(content, startY)
    local flow = {
        content = content,
        x = 20,
        y = startY or -55,
        width = 540,
    }

    function flow:Advance(amount)
        self.y = self.y - (amount or 24)
        return self.y
    end

    function flow:Description(text)
        ConfigUI:CreateDescription(self.content, text, self.x, self.y)
        self:Advance(44)
    end

    function flow:Divider()
        ConfigUI:CreateDivider(self.content, self.x, self.y, self.width)
        self:Advance(28)
    end

    function flow:Label(text)
        CreateLabel(self.content, text, self.x, self.y)
        self:Advance(27)
    end

    function flow:EditBox(width, height, multiline)
        local box = CreateEditBox(self.content, self.x, self.y, width or self.width, height or 28, multiline)
        self:Advance((height or 28) + 16)
        return box
    end

    function flow:ProfileStringBox(width, height)
        local box = CreateProfileStringBox(self.content, self.x, self.y, width or self.width, height or 120)
        self:Advance((height or 120) + 16)
        return box
    end

    function flow:Button(text, width, height, callback)
        local button = ConfigUI:CreateButton(self.content, text, self.x, self.y, width or 220, height or 32, callback)
        self:Advance((height or 32) + 26)
        return button
    end

    function flow:Finish()
        local height = math.max(520, math.abs(self.y) + 40)
        self.content:SetHeight(height)
    end

    return flow
end

local function CreateQuickToggle(parent, label, description, x, y, checked, callback)
    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    card:SetSize(260, 66)
    card:SetPoint("TOPLEFT", x, y)
    card.Checked = checked == true

    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    card:SetBackdropColor(0.07, 0.02, 0.10, 0.88)
    card:SetBackdropBorderColor(0.45, 0.12, 0.65, 0.45)

    card.Title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.Title:SetPoint("TOPLEFT", 12, -11)
    card.Title:SetWidth(178)
    card.Title:SetJustifyH("LEFT")
    card.Title:SetText(T(label or ""))
    card.Title:SetTextColor(RexUI:GetColor("text"))

    card.Description = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.Description:SetPoint("TOPLEFT", 12, -34)
    card.Description:SetWidth(175)
    card.Description:SetJustifyH("LEFT")
    card.Description:SetText(T(description or ""))
    card.Description:SetTextColor(RexUI:GetColor("mutedText"))

    card.State = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.State:SetPoint("RIGHT", -14, 0)

    local function Refresh()
        if card.Checked then
            card.State:SetText(T("AN"))
            card.State:SetTextColor(RexUI:GetColor("highlight"))
            card:SetBackdropBorderColor(0.75, 0.20, 1.00, 0.85)
        else
            card.State:SetText(T("AUS"))
            card.State:SetTextColor(RexUI:GetColor("mutedText"))
            card:SetBackdropBorderColor(0.45, 0.12, 0.65, 0.45)
        end
    end

    card:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.11, 0.03, 0.16, 0.95)
    end)

    card:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.07, 0.02, 0.10, 0.88)
    end)

    card:SetScript("OnClick", function(self)
        self.Checked = not self.Checked
        Refresh()

        if callback then
            callback(self.Checked)
        end
    end)

    Refresh()

    return card
end

local function CreateJumpButton(parent, label, x, y, category)
    return ConfigUI:CreateButton(parent, label, x, y, 165, 30, function()
        ConfigUI:SetCategory(category)
    end)
end

local function CreateInfoCard(parent, title, value, x, y, width)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(width or 165, 56)
    card:SetPoint("TOPLEFT", x, y)
    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    card:SetBackdropColor(0.06, 0.02, 0.09, 0.82)
    card:SetBackdropBorderColor(0.45, 0.12, 0.65, 0.36)

    local titleText = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    titleText:SetPoint("TOPLEFT", 10, -9)
    titleText:SetText(T(title or ""))
    titleText:SetTextColor(RexUI:GetColor("mutedText"))

    local valueText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valueText:SetPoint("BOTTOMLEFT", 10, 10)
    valueText:SetWidth((width or 165) - 20)
    valueText:SetJustifyH("LEFT")
    valueText:SetText(T(value or "-"))
    valueText:SetTextColor(RexUI:GetColor("text"))

    return card
end

local function MarkReloadRequired()
    ConfigUI.ReloadRequired = true
    if ConfigUI.ReloadBar then
        ConfigUI.ReloadBar:Show()
    end
end

local function CreateReloadBar(parent, y)
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar:SetSize(540, 42)
    bar:SetPoint("TOPLEFT", 20, y or -640)
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    bar:SetBackdropColor(0.10, 0.03, 0.12, 0.94)
    bar:SetBackdropBorderColor(0.75, 0.20, 1.00, 0.65)

    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", 12, 0)
    text:SetText(T("Reload erforderlich"))
    text:SetTextColor(RexUI:GetColor("highlight"))

    ConfigUI:CreateButton(bar, "Reload UI", 410, -6, 110, 28, function()
        ReloadUI()
    end)

    ConfigUI.ReloadBar = bar
    bar:SetShown(ConfigUI.ReloadRequired == true)

    return bar
end

local function ResetTableFromDefaults(target, defaults)
    if type(target) ~= "table" or type(defaults) ~= "table" then
        return
    end

    wipe(target)

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = {}
            ResetTableFromDefaults(target[key], value)
        else
            target[key] = value
        end
    end
end

local function ResetProfileSection(sectionKey)
    local profile = RexUI:GetProfile()
    local defaults = RexUI.defaults and RexUI.defaults.profile and RexUI.defaults.profile[sectionKey]

    if not profile or type(defaults) ~= "table" then
        return false
    end

    profile[sectionKey] = profile[sectionKey] or {}
    ResetTableFromDefaults(profile[sectionKey], defaults)

    if RexUI.ApplyProfileSettings then
        RexUI:ApplyProfileSettings()
    end

    return true
end

function ConfigUI:ResetNameplateSettings()
    local profile = RexUI:GetProfile()
    local defaults = RexUI.defaults and RexUI.defaults.profile and RexUI.defaults.profile.nameplates
    local settings = profile and profile.nameplates
    if type(settings) ~= "table" or type(defaults) ~= "table" then
        return false
    end

    -- Reset the complete configuration without changing the user's selected
    -- nameplate system.
    local wasEnabled = settings.enabled ~= false
    ResetTableFromDefaults(settings, defaults)
    settings.enabled = wasEnabled

    local module = RexUI.modules and RexUI.modules.Nameplates
    if module and module.Apply then
        module:Apply()
    end

    if self.UpdateSettings then
        self:UpdateSettings("Nameplates")
    end
    return true
end

StaticPopupDialogs["REXUI_RESET_NAMEPLATES"] = {
    text = T("Alle RexUI-Namensplaketten-Einstellungen auf Werkseinstellungen zurücksetzen?\n\nFarben, Größen, Positionen, Auren, Filter und Indikatoren werden zurückgesetzt. Die Auswahl RexUI aktiv oder aus bleibt erhalten."),
    button1 = T("Zurücksetzen"),
    button2 = T("Abbrechen"),
    OnAccept = function()
        if ConfigUI:ResetNameplateSettings() then
            RexUI:PrintMessage("Namensplaketten-Einstellungen zurückgesetzt.")
        end
    end,
    OnShow = function(dialog)
        ConfigUI:BringPopupToFront(dialog)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ------------------------------------------------------------
-- EINSTELLUNGS PANEL
-- ------------------------------------------------------------

function ConfigUI:CreateSettingsPanel()

    local panel = CreateFrame("Frame", nil, self.Window)
    panel:SetPoint("TOPLEFT", self.Window, "TOPLEFT", 240, -82)
    panel:SetPoint("BOTTOMRIGHT", self.Window, "BOTTOMRIGHT", -15, 50)
    panel:SetClipsChildren(true)

    self.Window.SettingsPanel = panel
end

-- ------------------------------------------------------------
-- INHALT LEEREN
-- ------------------------------------------------------------

function ConfigUI:ClearSettings()

    local panel = self.Window.SettingsPanel
    if not panel then return end

    local function HideFrameTree(frame)
        if not frame then return end

        for _, child in ipairs({ frame:GetChildren() }) do
            HideFrameTree(child)
        end

        frame:Hide()
        frame:ClearAllPoints()
    end

    if panel.MainTabs then
        HideFrameTree(panel.MainTabs)
        panel.MainTabs:SetParent(nil)
        panel.MainTabs = nil
    end

    if panel.ScrollFrame then
        HideFrameTree(panel.ScrollFrame)
        panel.ScrollFrame:SetParent(nil)
        panel.ScrollFrame = nil
    end

    if panel.Content then
        HideFrameTree(panel.Content)
        panel.Content:SetParent(nil)
        panel.Content = nil
    end
end

-- ------------------------------------------------------------
-- TITEL ERSTELLEN
-- ------------------------------------------------------------

function ConfigUI:CreateSettingsTitle(parent, text)

    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetText(T(text))
    title:SetTextColor(
    0.85,
    0.25,
    1.00,
    1
)

    return title
end


-- ------------------------------------------------------------
-- EINSTELLUNGEN AKTUALISIEREN
-- ------------------------------------------------------------

function ConfigUI:UpdateSettings(category)

    self:ClearSettings()

    local panel = self.Window.SettingsPanel
    if not panel then return end

    local profile = RexUI:GetProfile()
    if not profile then return end

    profile.general = profile.general or {}
    profile.comfort = profile.comfort or {}

    local scrollFrame, content = self:CreateScrollFrame(panel)

    -- Normal bleibt das bisherige 600px-Raster. Im entsperrten Arbeitsmodus
    -- nutzt der Inhalt dagegen die tatsaechlich verfuegbare Fensterbreite.
    local availableWidth = panel:GetWidth() or 645
    local contentWidth = (self.Window and self.Window.MoverCompact)
        and math.max(500, availableWidth - 25)
        or 600
    content:SetWidth(contentWidth)
    content:SetHeight(1200)

    panel.ScrollFrame = scrollFrame
    panel.Content = content

    category = category or "Start"

    self:CreateSettingsTitle(content, category == "Nameplates" and "Namensplaketten" or category)

    if category == "Start" then
        profile.minimap = profile.minimap or {}
        profile.blizzardSkin = profile.blizzardSkin or {}
        profile.bags = profile.bags or {}
        local tabs = {{id="status",label="Status"},{id="quick",label="Quick Toggles"},{id="switch",label="Schnell wechseln"}}
        local activeTab = self.StartSubTab or "status"
        for i,t in ipairs(tabs) do
            local id=t.id
            local btn=self:CreateButton(content,t.label,20+((i-1)*178),-58,170,28,function() self.StartSubTab=id; self:UpdateSettings("Start") end)
            if id==activeTab then btn:Disable(); btn.Background:SetColorTexture(0.34,0.10,0.45,1); btn.Text:SetTextColor(RexUI:GetColor("highlight")); btn.Border:SetAlpha(1) end
        end
        self:CreateDivider(content,20,-100,540)
        if activeTab=="status" then
            self:CreateHeader(content,"Status",20,-135)
            CreateInfoCard(content,"Profil",RexUI:GetCurrentProfile() or "Default",20,-180,165)
            CreateInfoCard(content,"Version",tostring(RexUI.GetVersion and RexUI:GetVersion() or RexUI.version or "-"),205,-180,165)
            CreateInfoCard(content,"Layout",RexUI.Unlocked and "Entsperrt" or "Gesperrt",390,-180,165)
            CreateReloadBar(content,-295); content:SetHeight(390)
        elseif activeTab=="quick" then
            self:CreateHeader(content,"Quick Toggles",20,-135)
            CreateQuickToggle(content,"Auto Repair","Beim Händler reparieren",20,-180,profile.comfort.autoRepair==true,function(v) profile.comfort.autoRepair=v end)
            CreateQuickToggle(content,"Sell Junk","Graue Items verkaufen",300,-180,profile.comfort.sellJunk==true,function(v) profile.comfort.sellJunk=v end)
            CreateQuickToggle(content,"Cinematics","Sequenzen überspringen",20,-260,profile.comfort.skipCinematics==true,function(v) profile.comfort.skipCinematics=v end)
            CreateQuickToggle(content,"Talking Head","Dialogfenster ausblenden",300,-260,profile.comfort.hideTalkingHead==true,function(v) profile.comfort.hideTalkingHead=v end)
            CreateQuickToggle(content,"Minimap","RexUI-Minimap anzeigen",20,-420,profile.minimap.enabled~=false,function(v) profile.minimap.enabled=v; if RexUI.Minimap and RexUI.Minimap.Update then RexUI.Minimap:Update() end end)
            CreateQuickToggle(content,"Blizzard Skin","Blizzard-Fenster stylen",300,-420,profile.blizzardSkin.enabled~=false,function(v) profile.blizzardSkin.enabled=v; MarkReloadRequired(); RexUI:SetModuleEnabled("BlizzardSkin", v); if v and RexUI.BlizzardSkin and RexUI.BlizzardSkin.Refresh then RexUI.BlizzardSkin:Refresh() end end)
            content:SetHeight(540)
        else
            self:CreateHeader(content,"Schnell wechseln",20,-135)
            CreateJumpButton(content,"Actionbars",20,-180,"Actionbars"); CreateJumpButton(content,"Komfort",205,-180,"Komfort"); CreateJumpButton(content,"Profile",390,-180,"Profile")
            CreateJumpButton(content,"Minimap",20,-220,"Minimap"); CreateJumpButton(content,"Taschen",205,-220,"Taschen"); CreateJumpButton(content,"Import",390,-220,"Import")
            content:SetHeight(340)
        end
        return
    end

    if category == "Allgemein" then
        local tabs = {
            { id = "layout", label = "Layout" },
            { id = "graphics", label = "Grafik" },
            { id = "maintenance", label = "Wartung" },
        }
        local activeTab = self.GeneralSubTab or "layout"
        if activeTab == "status" then
            activeTab = "layout"
            self.GeneralSubTab = "layout"
        end
        local tabWidth, tabGap = 170, 12
        for index, tabInfo in ipairs(tabs) do
            local tabID = tabInfo.id
            local button = self:CreateButton(content, tabInfo.label, 20 + ((index - 1) * (tabWidth + tabGap)), -82, tabWidth, 28, function()
                self.GeneralSubTab = tabID
                self:UpdateSettings("Allgemein")
            end)
            if tabID == activeTab then
                button:Disable()
                button.Background:SetColorTexture(0.34, 0.10, 0.45, 1)
                button.Text:SetTextColor(RexUI:GetColor("highlight"))
                button.Border:SetAlpha(1)
            end
        end

        self:CreateDivider(content, 20, -125, 540)

        if activeTab == "layout" then
            self:CreateHeader(content, "Layout", 20, -155)
            CreateLabel(content, "Version " .. tostring(RexUI.GetVersion and RexUI:GetVersion() or RexUI.version or "-"), 20, -190)
            self:CreateButton(content, "UI entsperren / sperren", 20, -230, 220, 32, function()
                if RexUI.ToggleUnlock then RexUI:ToggleUnlock() end
            end)
            self:CreateButton(content, "Blizzard EditMode öffnen", 260, -230, 220, 32, function()
                if EditModeManagerFrame then ShowUIPanel(EditModeManagerFrame) end
            end)
            content:SetHeight(330)

        elseif activeTab == "graphics" then
            local optimizer = RexUI.GraphicsOptimizer
            self:CreateHeader(content, "FPS- & Grafikoptimierung", 20, -155)
            self:CreateDescription(content, "Drei umschaltbare Profile auf Basis der aktuellen ElvUI-Retail-Performance-Empfehlungen. Separate Raid-Grafik wird aktiviert; wichtige Partikel und projizierte Bodeneffekte bleiben sichtbar. Die ursprünglichen Werte werden vor dem ersten Profilwechsel einmalig gesichert.", 20, -195)

            local activePreset = optimizer and optimizer.GetActivePreset and optimizer:GetActivePreset()
            local presetButtons = {
                { id = "raid", label = "Optimal für Raid & M+", tooltip = "Höchste Kampfübersicht und möglichst stabile FPS in Raids und Mythic+." },
                { id = "balanced", label = "Ausgewogen", tooltip = "Gute Bildqualität bei stabiler Leistung für den normalen Spielbetrieb." },
                { id = "quality", label = "Beste Grafik", tooltip = "Hohe Open-World-Qualität; das separate Raid-Profil bleibt leistungsoptimiert." },
            }
            for index, presetInfo in ipairs(presetButtons) do
                local id = presetInfo.id
                local button = self:CreateButton(content, presetInfo.label, 20 + ((index - 1) * 180), -285, 170, 34, function()
                    if optimizer and optimizer.ApplyPreset then
                        optimizer:ApplyPreset(id)
                        ConfigUI:UpdateSettings("Allgemein")
                    end
                end, presetInfo.tooltip)
                if activePreset == id then
                    button:Disable()
                    button.Background:SetColorTexture(0.34, 0.10, 0.45, 1)
                    button.Border:SetAlpha(1)
                end
            end

            local restoreButton = self:CreateButton(content, "Ursprüngliche Einstellungen wiederherstellen", 125, -345, 330, 34, function()
                if optimizer and optimizer.Restore then
                    optimizer:Restore()
                    ConfigUI:UpdateSettings("Allgemein")
                end
            end, "Stellt die vor der Optimierung gesicherten Grafikwerte wieder her.")
            if not (optimizer and optimizer.HasBackup and optimizer:HasBackup()) then
                restoreButton:Disable()
            end

            local profileDescriptions = {
                raid = "Optimal für Raid & M+: Priorisiert maximale und stabile Kampf-FPS. Schatten, Wasser, Sichtweite, Umgebung und Bodenobjekte werden stark reduziert; SSAO, Tiefen- und Compute-Effekte sind aus. Texturen, Konturen, wichtige Partikel und projizierte Bodeneffekte bleiben gut sichtbar. Dieses Profil reduziert auch die normalen Grafikwerte und ist deshalb ebenso für Mythic+ geeignet.",
                balanced = "Ausgewogen: Verwendet mittlere Schatten, Sichtweite und Umgebungsdetails außerhalb großer Kämpfe. In Raids greift weiterhin das separate Performance-Profil mit essenzieller Zauberdichte und sichtbaren Bodeneffekten. Empfohlen für den täglichen Spielbetrieb auf durchschnittlicher Hardware.",
                quality = "Beste Grafik: Erhöht Sichtweite, Schatten, Wasser und Umgebungsdetails außerhalb großer Kämpfe. Texturen und Effekte werden hochwertig dargestellt. Das separate Raid-Profil bleibt trotzdem auf Leistung und Mechanik-Sichtbarkeit optimiert. Empfohlen für leistungsstarke Grafikkarten.",
            }
            local activeNames = {
                raid = "Optimal für Raid & M+",
                balanced = "Ausgewogen",
                quality = "Beste Grafik",
            }
            local activeName = activeNames[activePreset]
            self:CreateHeader(content, activeName and ("Aktives Profil: " .. activeName) or "Profilunterschiede", 20, -420)
            self:CreateDescription(content, profileDescriptions[activePreset] or "Wähle eines der drei Profile aus. Danach wird hier genau erklärt, welche Prioritäten und Grafikbereiche dieses Profil verwendet.", 20, -460)
            content:SetHeight(590)

        else
            self:CreateHeader(content, "Wartung", 20, -155)
            self:CreateButton(content, "Alle RexUI-Profile löschen", 20, -200, 260, 32, function()
                StaticPopup_Show("REXUI_RESET")
            end)
            self:CreateDescription(content, "Achtung: Dieser Reset löscht alle gespeicherten RexUI-Profile und Einstellungen für alle Charaktere. Danach wird die UI neu geladen.", 20, -240)
            self:CreateButton(content, "Komfort zurücksetzen", 20, -300, 170, 30, function()
                if ResetProfileSection("comfort") then
                    RexUI:PrintMessage("Komfort-Einstellungen zurückgesetzt.")
                    ConfigUI:UpdateSettings("Allgemein")
                end
            end, "Setzt nur die Komfort-Einstellungen des aktiven Profils zurück.")
            self:CreateButton(content, "Minimap zurücksetzen", 205, -300, 170, 30, function()
                if ResetProfileSection("minimap") then
                    RexUI:PrintMessage("Minimap-Einstellungen zurückgesetzt.")
                    ConfigUI:UpdateSettings("Allgemein")
                end
            end, "Setzt nur die Minimap-Einstellungen des aktiven Profils zurück.")
            self:CreateButton(content, "Taschen zurücksetzen", 390, -300, 170, 30, function()
                if ResetProfileSection("bags") then
                    RexUI:PrintMessage("Taschen-Einstellungen zurückgesetzt.")
                    ConfigUI:UpdateSettings("Allgemein")
                end
            end, "Setzt nur die Taschen-Einstellungen des aktiven Profils zurück.")
            content:SetHeight(390)
        end
        return
    end

	-- ========================================================
    -- ACTIONBARS
    -- ========================================================

    if category == "Actionbars" then

        local moverCompact = self.Window and self.Window.MoverCompact == true
        local pageWidth = math.max(500, content:GetWidth() or 600)

        ConfigUI.selectedBar =
            ConfigUI.selectedBar
            or "Bar1"

        local AB = _G["RexUI"] and _G["RexUI"].ActionBars
        local MM = _G["RexUI"] and _G["RexUI"].MicroMenu
        local isMicroMenu = ConfigUI.selectedBar == "MicroMenu"
        local isKeybinding = ConfigUI.selectedBar == "Keybindings"
        local isXPBar = ConfigUI.selectedBar == "XPBar"

        if not isMicroMenu and not isKeybinding and not isXPBar and not AB then
            self:CreateDescription(
                content,
                "ActionBars nicht geladen.",
                20,
                -55
            )
            return
        end

        local config
        if isKeybinding or isXPBar then
            config = {}
        elseif isMicroMenu then
            profile.microMenu = profile.microMenu or {}
            config = (MM and MM.GetConfig and MM:GetConfig()) or profile.microMenu
            if not config then return end
        else
            config = AB:GetConfig(ConfigUI.selectedBar)
            if not config then return end
        end

        if InCombatLockdown and InCombatLockdown() then
            self:CreateDescription(
                content,
                "Im Kampf können geschützte Leisten nicht vollständig geändert werden. Nach dem Kampf sind alle Optionen wieder verfügbar.",
                20,
                -88
            )
        end

        -- Shared ActionBar layout metrics must be defined before the global buttons.
        -- The previous cleanup referenced buttonWidth/spacing before their local
        -- declarations, which made them nil in compact mover mode.
        local startX = 20
        local startY = -120
        local buttonHeight = 28
        local spacing = moverCompact and 8 or 10
        local selectorColumns = moverCompact and 2 or 3
        local selectorAreaWidth = moverCompact and math.min(250, math.floor(pageWidth * 0.38)) or 380
        local buttonWidth = moverCompact and math.floor((selectorAreaWidth - spacing) / 2) or 120

        local unlockButton
        unlockButton = self:CreateButton(
            content,
            RexUI.Unlocked and "UI sperren" or "UI entsperren",
            moverCompact and 20 or 410,
            moverCompact and -360 or -120,
            moverCompact and buttonWidth or 130,
            28,
            function()
                if RexUI.ToggleUnlock then
                    RexUI:ToggleUnlock()
                end

            if unlockButton and unlockButton.Text then
                    unlockButton.Text:SetText(T(RexUI.Unlocked and "UI sperren" or "UI entsperren"))
                end
            end
        )

        local gridButton = self:CreateButton(
            content,
            "Raster anzeigen",
            moverCompact and (20 + buttonWidth + spacing) or 410,
            moverCompact and -360 or -160,
            moverCompact and buttonWidth or 130,
            28,
            function()
                if RexUI.GridOverlay and RexUI.GridOverlay.Toggle then
                    RexUI.GridOverlay:Toggle()
                    if gridButton and gridButton.Text then
                        gridButton.Text:SetText(T(
                            RexUI.GridOverlay:IsShown()
                            and "Raster ausblenden" or "Raster anzeigen"
                        ))
                    end
                end
            end
        )

        local keybindTab = self:CreateButton(
            content,
            "Tastenbelegung",
            moverCompact and 20 or 410,
            moverCompact and -400 or -200,
            moverCompact and buttonWidth or 130,
            28,
            function()
                ConfigUI.selectedBar = "Keybindings"
                ConfigUI:UpdateSettings("Actionbars")
            end
        )
        if isKeybinding then
            keybindTab:Disable()
            keybindTab.Background:SetColorTexture(0.42, 0.08, 0.58, 1)
            keybindTab.Text:SetTextColor(1, 1, 1)
            keybindTab.Border:SetAlpha(1)
        end

        self:CreateDivider(
            content,
            20,
            -125,
            540
        )

        -- ----------------------------------------------------
        -- BAR BUTTONS
        -- ----------------------------------------------------

        local bars = {
            { key = "Bar1", label = "Bar1" },
            { key = "Bar2", label = "Bar2" },
            { key = "Bar3", label = "Bar3" },
            { key = "Bar4", label = "Bar4" },
            { key = "Bar5", label = "Bar5" },
            { key = "Bar6", label = "Bar6" },
            { key = "Bar7", label = "Bar7" },
            { key = "Bar8", label = "Bar8" },
            { key = "PetBar", label = "PetBar" },
            { key = "StanceBar", label = "Haltungsleiste" },
            { key = "XPBar", label = "XPBar und Ruf" },
            { key = "MicroMenu", label = "MicroMenu" },
        }

        for index, barData in ipairs(bars) do

            local row =
                math.floor((index - 1) / selectorColumns)

            local col =
                (index - 1) % selectorColumns

            local x =
                startX
                + (col * (buttonWidth + spacing))

            local y =
                startY
                - (row * 40)

            local barButton = self:CreateButton(
                content,
                barData.label,
                x,
                y,
                buttonWidth,
                buttonHeight,
                function()
                    ConfigUI.selectedBar = barData.key
                    ConfigUI:UpdateSettings("Actionbars")
                end
            )
            if barData.key == ConfigUI.selectedBar then
                barButton:Disable()
                barButton.Background:SetColorTexture(0.42, 0.08, 0.58, 1)
                barButton.Text:SetTextColor(1, 1, 1)
                barButton.Border:SetAlpha(1)
            end
        end

        -- ----------------------------------------------------
        -- Selected bar is indicated directly by the highlighted selector button.

        -- ----------------------------------------------------
        -- DIVIDER
        -- ----------------------------------------------------

        self:CreateDivider(
            content,
            moverCompact and (selectorAreaWidth + 55) or 20,
            moverCompact and -120 or -305,
            moverCompact and math.max(260, pageWidth - selectorAreaWidth - 75) or 540
        )

        -- ----------------------------------------------------
        -- QUICK KEYBIND CONTROLS
        -- ----------------------------------------------------

        if isKeybinding then
            local panelY = moverCompact and -155 or -345
            profile.actionbars = profile.actionbars or {}
            self:CreateCheckbox(
                content,
                "RexUI-Tastenbelegung aktivieren",
                settingsX or 20,
                panelY,
                profile.actionbars.keybindingEnabled ~= false,
                function(value)
                    if AB and AB.SetKeybindingEnabled then AB:SetKeybindingEnabled(value) end
                    ConfigUI:UpdateSettings("Actionbars")
                end
            )
            self:CreateDescription(
                content,
                "Schnelle Tastenbelegung",
                settingsX or 20,
                panelY - 45
            )
            self:CreateDescription(
                content,
                "Fahre mit der Maus über einen Aktionsbutton und drücke die gewünschte Taste. Die Belegungen werden über das normale WoW-Tastaturbelegungssystem gespeichert.",
                settingsX or 20,
                panelY - 80
            )
            self:CreateButton(
                content,
                "Schnelle Tastenbelegung starten",
                settingsX or 20,
                panelY - 140,
                moverCompact and math.min(300, settingsWidth or 300) or 300,
                32,
                function()
                    -- Quick-Keybind must be unobstructed. Close RexUI config first;
                    -- the binding dialog returns directly to gameplay on OK/Cancel.
                    if ConfigUI and ConfigUI.Close then
                        ConfigUI:Close()
                    end
                    if AB and AB.OpenQuickKeybind then
                        AB:OpenQuickKeybind()
                    end
                end
            )
            self:CreateDescription(
                content,
                "Schnellbefehl: /kb",
                settingsX or 20,
                panelY - 190
            )
            content:SetHeight(math.max(content:GetHeight() or 0, 560))
            return
        end

        -- ----------------------------------------------------
        -- MICRO MENU CONTROLS
        -- ----------------------------------------------------

        if ConfigUI.selectedBar == "MicroMenu" then

            profile.microMenu =
                profile.microMenu or {}

            local function save(key, value)
                profile.microMenu[key] = value
                if MM and MM.Update then
                    MM:Update()
                end
            end

            self:CreateCheckbox(
                content,
                "Micro-Menüleiste anzeigen",
                20,
                -370,
                config.enabled ~= false,
                function(value)
                    save("enabled", value)
                end
            )

            self:CreateButton(
                content,
                "Blizzard Edit-Mode öffnen",
                20,
                -420,
                200,
                30,
                function()
                    if _G.EditModeManagerFrame then
                        _G.EditModeManagerFrame:Show()
                    end
                end
            )

            return
        end

        if isXPBar then
            profile.statusbars = profile.statusbars or {}
            local statusbars = profile.statusbars
            local SB = RexUI.StatusBars
            local panelY = moverCompact and -155 or -345
            self:CreateHeader(content, "XPBar und Ruf", settingsX or 20, panelY)
            self:CreateCheckbox(content, "Erfahrungsleiste anzeigen", settingsX or 20, panelY - 50, SB and SB.IsXPEnabled and SB:IsXPEnabled() or false, function(value)
                statusbars.xpEnabled = value == true
                if SB and SB.SetXPEnabled then SB:SetXPEnabled(value) end
                if SB and SB.Update then SB:Update() end
            end)
            self:CreateCheckbox(content, "Rufleiste bei Max-Level anzeigen", settingsX or 20, panelY - 90, statusbars.showReputationAtMax ~= false, function(value)
                statusbars.showReputationAtMax = value
                if SB and SB.Update then SB:Update() end
            end)
            self:CreateCheckbox(content, "Text nur bei Mouseover", settingsX or 20, panelY - 130, statusbars.showTextOnMouseover ~= false, function(value)
                statusbars.showTextOnMouseover = value
                if SB and SB.Update then SB:Update() end
            end)
            content:SetHeight(math.max(content:GetHeight() or 0, 560))
            return
        end

        local actionbars = AB.GetCurrentActionBarDB and AB:GetCurrentActionBarDB(profile)
        if not actionbars then
            profile.actionbars = profile.actionbars or {}
            actionbars = profile.actionbars
        end

        local settingsX = moverCompact and (selectorAreaWidth + 55) or 20
        local settingsWidth = moverCompact and math.max(280, pageWidth - settingsX - 20) or 600
        local secondX = moverCompact and (settingsX + math.floor(settingsWidth / 2)) or 330
        local firstSliderX = settingsX
        local sliderWidth = moverCompact and math.max(105, math.floor(settingsWidth / 2) - 92) or 220
        local enableY = moverCompact and -145 or -335
        local checkY = moverCompact and -180 or -370
        local sliderY1 = moverCompact and -235 or -435
        local sliderY2 = moverCompact and -305 or -505
        local sliderY3 = moverCompact and -375 or -575

        -- ----------------------------------------------------
        -- ENABLE
        -- ----------------------------------------------------

        self:CreateCheckbox(
            content,
            "Bar aktivieren",
            settingsX,
            enableY,
            config.enabled ~= false,
            function(value)

                -- Direkt auf AB.Config schreiben, nicht auf
                -- die lokale config-Kopie von GetConfig()
                AB.Config[ConfigUI.selectedBar] =
                    AB.Config[ConfigUI.selectedBar] or {}

                AB.Config[ConfigUI.selectedBar].enabled = value

                actionbars[ConfigUI.selectedBar] =
                    actionbars[ConfigUI.selectedBar] or {}

                actionbars[ConfigUI.selectedBar].enabled =
                    value

                if AB.UpdateBar then
                    AB:UpdateBar(ConfigUI.selectedBar)
                end
            end
        )
		
-- ----------------------------------------------------
-- MOUSEOVER
-- ----------------------------------------------------

self:CreateCheckbox(
    content,
    "Mouseover",
    settingsX,
    checkY,
    config.mouseover == true,
    function(value)

        AB.Config[ConfigUI.selectedBar] = AB.Config[ConfigUI.selectedBar] or {}
        AB.Config[ConfigUI.selectedBar].mouseover = value
		
		actionbars[ConfigUI.selectedBar] =
		actionbars[ConfigUI.selectedBar] or {}

	actionbars[ConfigUI.selectedBar].mouseover =
    value

        local bar = AB.Bars[ConfigUI.selectedBar]
        if not bar then return end

        if value then
            if AB.Mouseover and AB.Mouseover.Apply then
                AB.Mouseover:Apply(bar)
            end
        else
            if AB.Mouseover and AB.Mouseover.Remove then
                AB.Mouseover:Remove(bar)
            end
        end
    end
)


self:CreateCheckbox(
    content,
    "Bar ausblenden (Keybinds bleiben aktiv)",
    settingsX,
    checkY - 38,
    config.hidden == true,
    function(value)
        AB.Config[ConfigUI.selectedBar] = AB.Config[ConfigUI.selectedBar] or {}
        AB.Config[ConfigUI.selectedBar].hidden = value
        actionbars[ConfigUI.selectedBar] = actionbars[ConfigUI.selectedBar] or {}
        actionbars[ConfigUI.selectedBar].hidden = value
        if AB.UpdateBar then AB:UpdateBar(ConfigUI.selectedBar) end
        if AB.ApplyKeybindRouting then AB:ApplyKeybindRouting() end
    end
)


self:CreateCheckbox(
    content,
    "Vertikal",
    secondX,
    checkY,
    config.vertical == true,
    function(value)
        AB.Config[ConfigUI.selectedBar] = AB.Config[ConfigUI.selectedBar] or {}
        AB.Config[ConfigUI.selectedBar].vertical = value
        if ConfigUI.selectedBar == "PetBar" then
            AB.Config[ConfigUI.selectedBar].rows = 1
        end

        actionbars[ConfigUI.selectedBar] = actionbars[ConfigUI.selectedBar] or {}
        actionbars[ConfigUI.selectedBar].vertical = value
        if ConfigUI.selectedBar == "PetBar" then
            actionbars[ConfigUI.selectedBar].rows = 1
        end

        if ConfigUI.selectedBar == "PetBar"
        and AB.PetBar and AB.PetBar.SetVertical then
            AB.PetBar:SetVertical(value)
        elseif AB.UpdateBar then
            AB:UpdateBar(ConfigUI.selectedBar)
        end
    end
)


        -- ----------------------------------------------------
        -- BUTTONS
        -- ----------------------------------------------------

        local buttonsSlider = self:CreateSlider(
            content,
            "Buttons",
            firstSliderX,
            sliderY1,
            1,
            12,
            config.buttons,
            1,
            function(value)

    AB.Config[ConfigUI.selectedBar] =
        AB.Config[ConfigUI.selectedBar] or {}

    AB.Config[ConfigUI.selectedBar].slots =
        math.floor(value)

    AB.Config[ConfigUI.selectedBar].buttons =
        math.floor(value)

    actionbars[ConfigUI.selectedBar] =
        actionbars[ConfigUI.selectedBar] or {}

    actionbars[ConfigUI.selectedBar].slots =
        math.floor(value)

    actionbars[ConfigUI.selectedBar].buttons =
        math.floor(value)

    if AB.UpdateBar then
        AB:UpdateBar(ConfigUI.selectedBar)
    end
end
        )

        local sizeSlider = self:CreateSlider(
            content,
            "Buttongröße",
            secondX,
            sliderY1,
            20,
            60,
            config.buttonSize,
            1,
function(value)

    AB.Config[ConfigUI.selectedBar] =
        AB.Config[ConfigUI.selectedBar] or {}

    AB.Config[ConfigUI.selectedBar].buttonSize =
        math.floor(value)

    actionbars[ConfigUI.selectedBar] =
        actionbars[ConfigUI.selectedBar] or {}

    actionbars[ConfigUI.selectedBar].buttonSize =
        math.floor(value)

    if AB.UpdateBar then
        AB:UpdateBar(ConfigUI.selectedBar)
    end
end
        )

        local spacingSlider = self:CreateSlider(
            content,
            "Abstand",
            firstSliderX,
            sliderY2,
            -3,
            20,
            config.spacing,
            1,
            function(value)

    AB.Config[ConfigUI.selectedBar] =
        AB.Config[ConfigUI.selectedBar] or {}

    AB.Config[ConfigUI.selectedBar].spacing =
        math.floor(value)

    actionbars[ConfigUI.selectedBar] =
        actionbars[ConfigUI.selectedBar] or {}

    actionbars[ConfigUI.selectedBar].spacing =
        math.floor(value)

    if AB.UpdateBar then
        AB:UpdateBar(ConfigUI.selectedBar)
    end
end
        )

        local scaleSlider = self:CreateSlider(
            content,
            "Skalierung",
            secondX,
            sliderY2,
            0.5,
            2,
            config.scale,
            0.05,
            function(value)
                AB.Config[ConfigUI.selectedBar] = AB.Config[ConfigUI.selectedBar] or {}
                AB.Config[ConfigUI.selectedBar].scale = value
				actionbars[ConfigUI.selectedBar] =
    actionbars[ConfigUI.selectedBar] or {}

actionbars[ConfigUI.selectedBar].scale =
    value
                if AB.UpdateBar then AB:UpdateBar(ConfigUI.selectedBar) end
            end
        )

        local rowsSlider = self:CreateSlider(
            content,
            "Reihen",
            firstSliderX,
            sliderY3,
            1,
            12,
            config.rows,
            1,
            function(value)
                AB.Config[ConfigUI.selectedBar] = AB.Config[ConfigUI.selectedBar] or {}
                AB.Config[ConfigUI.selectedBar].rows = math.floor(value)
				actionbars[ConfigUI.selectedBar] =
    actionbars[ConfigUI.selectedBar] or {}

actionbars[ConfigUI.selectedBar].rows =
    math.floor(value)
                if AB.UpdateBar then AB:UpdateBar(ConfigUI.selectedBar) end
            end
        )

        if moverCompact then
            for _, slider in ipairs({ buttonsSlider, sizeSlider, spacingSlider, scaleSlider, rowsSlider }) do
                if slider then slider:SetWidth(sliderWidth) end
            end
        end

        -- Im Mover-Modus liegen Auswahl und Einstellungen nebeneinander.
        -- Dadurch bleiben die Bar-Optionen auch bei einem kleineren Fenster
        -- sichtbar, statt unterhalb des Fensterrands zu verschwinden.
        content:SetHeight(moverCompact and 455 or 650)
        return
    end

    if category == "Nameplates" then
        profile.nameplates = type(profile.nameplates) == "table" and profile.nameplates or {}
        local cfg = profile.nameplates
        cfg.general = type(cfg.general) == "table" and cfg.general or {}
        cfg.appearance = type(cfg.appearance) == "table" and cfg.appearance or {}
        cfg.target = type(cfg.target) == "table" and cfg.target or {}
        cfg.threat = type(cfg.threat) == "table" and cfg.threat or {}
        if cfg.threat.unitTypeColoring == nil then
            cfg.threat.unitTypeColoring = cfg.threat.importantNPCs ~= false
        end
        cfg.castbars = type(cfg.castbars) == "table" and cfg.castbars or {}
        cfg.colors = type(cfg.colors) == "table" and cfg.colors or {}
        cfg.auras = type(cfg.auras) == "table" and cfg.auras or {}
        cfg.indicators = type(cfg.indicators) == "table" and cfg.indicators or {}
        cfg.filters = type(cfg.filters) == "table" and cfg.filters or { include = {}, exclude = {} }
        cfg.filters.include = type(cfg.filters.include) == "table" and cfg.filters.include or {}
        cfg.filters.exclude = type(cfg.filters.exclude) == "table" and cfg.filters.exclude or {}
        local NP = RexUI.modules and RexUI.modules.Nameplates
        local function apply()
            if NP and NP.Apply then NP:Apply() end
        end
        local function save(section, key, value)
            cfg[section][key] = value
            apply()
        end
        -- Fallbacks kommen ausschließlich aus dem versionierten Datenbankschema,
        -- damit UI und Modul nie unterschiedliche Standardwerte zeigen.
        local npDefaults = RexUI.defaults and RexUI.defaults.profile and RexUI.defaults.profile.nameplates or {}
        local function val(section, key)
            local value = cfg[section] and cfg[section][key]
            if value == nil then
                value = npDefaults[section] and npDefaults[section][key]
            end
            return value
        end
        local tabs = {
            { "general", "Allgemein" }, { "appearance", "Darstellung" },
            { "colors", "Farben" }, { "target", "Ziel & Bedrohung" },
            { "castbars", "Zauberleisten" }, { "auras", "Auren" },
            { "indicators", "Indikatoren" }, { "filters", "Aurenfilter" },
        }
        local activeTab = self.NameplateSubTab or "general"
        local tabWidth, tabGap = 128, 7
        for index, tab in ipairs(tabs) do
            local id = tab[1]
            local column = (index - 1) % 4
            local row = math.floor((index - 1) / 4)
            local button = self:CreateButton(content, tab[2], 20 + column * (tabWidth + tabGap), -58 - row * 35,
                tabWidth, 28, function() self.NameplateSubTab = id; self:UpdateSettings("Nameplates") end)
            if id == activeTab then
                button:Disable(); button.Background:SetColorTexture(0.34, 0.10, 0.45, 1)
                button.Text:SetTextColor(RexUI:GetColor("highlight")); button.Border:SetAlpha(1)
            end
        end
        self:CreateDivider(content, 20, -132, 540)

        if activeTab == "general" then
            self:CreateHeader(content, "Allgemein", 20, -165)
            self:CreateDescription(content, "Wichtig: Verwende immer nur ein Namensplaketten-System. Wenn Plater aktiv ist, müssen die RexUI-Namensplaketten ausgeschaltet sein.", 20, -198)
            self:CreateCheckbox(content, "RexUI-Namensplaketten aktivieren", 20, -265, cfg.enabled ~= false, function(v)
                cfg.enabled = v; if NP and NP.SetEnabled then NP:SetEnabled(v) else apply() end
            end)
            self:CreateCheckbox(content, "Freundliche Namensplaketten anzeigen", 300, -265, cfg.general.showFriendly ~= false, function(v) save("general", "showFriendly", v) end)
            self:CreateCheckbox(content, "Freundlich nur Name (ohne Balken)", 20, -330, cfg.general.friendlyNameOnly == true, function(v) save("general", "friendlyNameOnly", v) end)
            self:CreateDescription(content, "Aus: Blizzard zeigt freundliche Namensplaketten unverändert. An: RexUI übernimmt die Darstellung freundlicher Einheiten.", 20, -365)
            self:CreateSlider(content, "Breite gegnerischer Namensplaketten", 20, -430, 70, 240, val("general", "enemyWidth"), 1, function(v) save("general", "enemyWidth", math.floor(v)) end)
            self:CreateSlider(content, "Höhe gegnerischer Lebensbalken", 300, -430, 6, 30, val("general", "enemyHealthHeight"), 1, function(v) save("general", "enemyHealthHeight", math.floor(v)) end)
            self:CreateSlider(content, "Breite freundlicher Namensplaketten", 20, -510, 70, 240, val("general", "friendlyWidth"), 1, function(v) save("general", "friendlyWidth", math.floor(v)) end)
            self:CreateSlider(content, "Höhe freundlicher Lebensbalken", 300, -510, 6, 30, val("general", "friendlyHealthHeight"), 1, function(v) save("general", "friendlyHealthHeight", math.floor(v)) end)
            self:CreateButton(content, "RexUI-Namensplaketten zurücksetzen", 20, -600, 280, 32, function()
                StaticPopup_Show("REXUI_RESET_NAMEPLATES")
            end, "Setzt Farben, Größen, Positionen, Auren, Filter und Indikatoren zurück.")
            self:CreateDescription(content, "Die aktuelle Auswahl RexUI aktiv oder aus bleibt beim Zurücksetzen erhalten.", 20, -645)
            self:CreateHeader(content, "Freundliche Einheiten", 20, -700)
            self:CreateCheckbox(content, "Spieler: nur Name", 20, -745, cfg.general.friendlyPlayersNameOnly == true, function(v) save("general", "friendlyPlayersNameOnly", v) end)
            self:CreateCheckbox(content, "NPCs: nur Name", 300, -745, cfg.general.friendlyNPCsNameOnly == true, function(v) save("general", "friendlyNPCsNameOnly", v) end)
            self:CreateCheckbox(content, "Klassenfarben für Spieler", 20, -790, val("general", "friendlyClassColors") ~= false, function(v) save("general", "friendlyClassColors", v) end)
            self:CreateCheckbox(content, "Click-through (nicht anklickbar)", 300, -790, cfg.general.friendlyClickThrough == true, function(v)
                save("general", "friendlyClickThrough", v); if NP and NP.Internal and NP.Internal.ApplyClickGeometry then NP.Internal.ApplyClickGeometry() end
            end, "Freundliche Namensplaketten lassen sich dann nicht mehr anklicken; Gegner bleiben klickbar.")
            self:CreateSlider(content, "Y-Versatz freundlicher Plaketten", 20, -860, -60, 60, val("general", "friendlyYOffset") or 0, 1, function(v) save("general", "friendlyYOffset", math.floor(v)) end)
            self:CreateHeader(content, "Stacking & Klickfläche", 20, -930)
            self:CreateCheckbox(content, "Namensplaketten stapeln", 20, -975, val("general", "stacking") ~= false, function(v) save("general", "stacking", v) end)
            self:CreateSlider(content, "Stack-Abstand", 300, -975, 0.5, 2, val("general", "stackSpacing") or 1, .05, function(v) save("general", "stackSpacing", v) end)
            self:CreateSlider(content, "Hitbox-Breite Gegner", 20, -1055, 70, 240, val("general", "hitboxWidth") or val("general", "enemyWidth"), 1, function(v) save("general", "hitboxWidth", math.floor(v)) end)
            self:CreateSlider(content, "Hitbox-Höhe Gegner", 300, -1055, 20, 80, val("general", "hitboxHeight") or 44, 1, function(v) save("general", "hitboxHeight", math.floor(v)) end)
            content:SetHeight(1160)
        elseif activeTab == "appearance" then
            self:CreateHeader(content, "Sichtbarkeit", 20, -165)
            self:CreateCheckbox(content, "Namen anzeigen", 20, -210, cfg.appearance.showName ~= false, function(v) save("appearance", "showName", v) end)
            self:CreateCheckbox(content, "Lebenspunkte anzeigen", 300, -210, cfg.appearance.showHealthText ~= false, function(v) save("appearance", "showHealthText", v) end)
            self:CreateCheckbox(content, "Level anzeigen", 20, -245, cfg.appearance.showLevel ~= false, function(v) save("appearance", "showLevel", v) end)

            self:CreateHeader(content, "Lebenspunkte", 20, -275)
            self:CreateDropdown(content, "Lebenspunkteformat", 20, -320, 250, {
                { value = "PERCENT", label = "Prozent (73%)" },
                { value = "COMPACT", label = "Kompakt (125k)" },
                { value = "BOTH", label = "Kompakt | Prozent" },
                { value = "PERCENT_COMPACT", label = "Prozent | Kompakt" },
            }, val("appearance", "healthFormat") or "BOTH", function(v) save("appearance", "healthFormat", v) end)
            self:CreateSlider(content, "Hintergrund-Deckkraft", 300, -320, 0, 1, val("appearance", "backgroundAlpha"), 0.05, function(v) save("appearance", "backgroundAlpha", v) end)

            self:CreateHeader(content, "Lebensbalken", 20, -400)
            self:CreateDropdown(content, "Textur", 20, -445, 250, {
                { value = "Interface\\AddOns\\RexUI\\media\\statusbars\\bar_background.tga", label = "RexUI Hintergrund" },
                { value = "Interface\\AddOns\\RexUI\\media\\statusbars\\bar_serenity.tga", label = "RexUI Sanft" },
                { value = "Interface\\TargetingFrame\\UI-StatusBar", label = "Blizzard" },
            }, cfg.appearance.texture, function(v) save("appearance", "texture", v) end)
            local backgroundColor = cfg.appearance.backgroundColor or { r=.03, g=.03, b=.03, a=val("appearance", "backgroundAlpha") or .5 }
            cfg.appearance.backgroundColor = backgroundColor
            self:CreateColorPicker(content, "Hintergrundfarbe", 300, -445, backgroundColor, function(color)
                cfg.appearance.backgroundColor = color
                if color.a ~= nil then cfg.appearance.backgroundAlpha = color.a end
                apply()
            end, "Farbe und Deckkraft des leeren Lebensbereichs.", true, true)

            self:CreateHeader(content, "Rahmen", 20, -525)
            self:CreateDropdown(content, "Rahmenstil", 20, -570, 250, {
                { value = "PIXEL", label = "RexUI Pixel (Standard)" },
                { value = "SIMPLE", label = "Simple" },
                { value = "COLORLESS", label = "Colorless" },
                { value = "REFERENCE", label = "Referenz-Rahmen" },
            }, val("appearance", "borderStyle") or "PIXEL", function(v) save("appearance", "borderStyle", v) end)
            self:CreateSlider(content, "Randstärke", 300, -570, 0, 4, val("appearance", "borderSize"), 1, function(v) save("appearance", "borderSize", math.floor(v)) end)
            content:SetHeight(670)
        elseif activeTab == "colors" then
            self:CreateHeader(content, "Farben – Plater-Sortierung", 20, -165)
            self:CreateDescription(content, "Jeder Farbwert wird direkt als HEX-Code angezeigt. Ein Klick auf das Farbfeld öffnet die Farbauswahl.", 20, -198)

            local defaults = RexUI.defaults and RexUI.defaults.profile and RexUI.defaults.profile.nameplates
                and RexUI.defaults.profile.nameplates.colors or {}
            local function ensureColor(key)
                if type(cfg.colors[key]) ~= "table" then
                    local source = defaults[key] or { r = 1, g = 1, b = 1, a = 1 }
                    cfg.colors[key] = { r = source.r, g = source.g, b = source.b, a = source.a or 1 }
                end
                return cfg.colors[key]
            end
            local function picker(key, label, x, y)
                self:CreateColorPicker(content, label, x, y, ensureColor(key), function() apply() end, nil, true)
            end

            self:CreateHeader(content, "Bedrohungs-Modifikationen", 20, -250)
            self:CreateCheckbox(content, "Lebensbalkenfarbe", 20, -290, cfg.threat.healthBarColor ~= false, function(v) save("threat", "healthBarColor", v) end)
            self:CreateCheckbox(content, "Rahmenfarbe", 300, -290, cfg.threat.borderColor == true, function(v) save("threat", "borderColor", v) end)
            self:CreateCheckbox(content, "Namensfarbe", 20, -335, cfg.threat.nameColor == true, function(v) save("threat", "nameColor", v) end)

            self:CreateHeader(content, "Standardfarben überschreiben", 20, -390)
            self:CreateCheckbox(content, "Aktiviert", 20, -430, cfg.threat.overrideBaseColors ~= false, function(v) save("threat", "overrideBaseColors", v) end)
            picker("enemy", "Feindlich", 20, -475)
            picker("neutral", "Neutral", 300, -475)
            picker("friendly", "Freundlich", 20, -527)

            self:CreateHeader(content, "Farbe bei Spiel als TANK", 20, -585)
            picker("tankAggro", "Greift Dich an", 20, -625)
            picker("offTank", "Greift anderen Tank an", 300, -625)
            picker("tankLosing", "Greift Dich an - niedrige Bedrohung", 20, -677)
            picker("tankNoAggro", "Keine Bedrohung", 300, -677)
            picker("tankTakeover", "Von anderem Tank übernehmen", 20, -729)

            self:CreateHeader(content, "Farbe bei Spiel als DD oder Heiler", 20, -787)
            picker("dpsAggro", "Greift Dich an", 20, -827)
            picker("threatHigh", "Hohe Bedrohung", 300, -827)
            picker("threatNone", "Keine Bedrohung", 20, -879)
            self:CreateCheckbox(content, "Allein-Farbe verwenden", 300, -879, cfg.threat.useSoloColor == true, function(v) save("threat", "useSoloColor", v) end)
            picker("solo", "Allein-Farbe", 20, -931)
            self:CreateCheckbox(content, "Auf Keine-Tank-Aggro prüfen", 300, -931, cfg.threat.checkNoTankAggro == true, function(v) save("threat", "checkNoTankAggro", v) end)
            picker("nonTankTarget", "Greift nicht-Tank-Spieler an", 20, -983)
            picker("outOfCombat", "Einheit nicht im Kampf", 300, -983)
            picker("tapped", "Einheit getappt", 20, -1035)

            self:CreateHeader(content, "Einheitentyp-Färbung", 20, -1093)
            self:CreateCheckbox(content, "Aktiviert", 20, -1133, cfg.threat.unitTypeColoring ~= false, function(v) save("threat", "unitTypeColoring", v) end)
            self:CreateCheckbox(content, "Bedrohungsfarben nicht überschreiben", 300, -1133, cfg.threat.unitTypesDontOverrideThreat == true, function(v) save("threat", "unitTypesDontOverrideThreat", v) end)
            picker("boss", "Boss", 20, -1180)
            picker("important", "Miniboss", 300, -1180)
            picker("caster", "Zauberwirker", 20, -1232)
            self:CreateCheckbox(content, "Elite aktivieren", 300, -1232, cfg.threat.eliteColor == true, function(v) save("threat", "eliteColor", v) end)
            picker("elite", "Elite", 20, -1284)
            self:CreateCheckbox(content, "Unbedeutend aktivieren", 300, -1284, cfg.threat.trivialColor == true, function(v) save("threat", "trivialColor", v) end)
            picker("trivial", "Unbedeutend", 20, -1336)

            self:CreateHeader(content, "Verschiedenes", 20, -1394)
            self:CreateCheckbox(content, "Aggro-Blinken aktivieren", 20, -1434, cfg.threat.aggroBlink == true, function(v) save("threat", "aggroBlink", v) end)
            self:CreateCheckbox(content, "Roten Aggro-Rand anzeigen", 300, -1434, val("threat", "aggroBorder") ~= false, function(v) save("threat", "aggroBorder", v) end)

            self:CreateHeader(content, "Weitere RexUI-Farben", 20, -1492)
            picker("target", "Zielpfeile", 20, -1532)
            picker("focus", "Fokus-Rahmen", 300, -1532)
            picker("mouseover", "Mouseover-Rahmen", 20, -1584)
            content:SetHeight(1660)
        elseif activeTab == "target" then
            self:CreateHeader(content, "Zielzustand", 20, -165)
            self:CreateDescription(content, "Darstellung des aktuellen Ziels. Bedrohungsfarben werden im Abschnitt darunter aktiviert und im Tab Farben angepasst.", 20, -198)
            self:CreateSlider(content, "Größe des aktuellen Ziels", 20, -255, 1, 1.5, val("target", "scale"), .01, function(v) save("target", "scale", v) end,
                "1,00 bedeutet normale Größe; höhere Werte vergrößern nur die aktuell ausgewählte Namensplakette.")
            self:CreateSlider(content, "Deckkraft anderer Namensplaketten", 300, -255, .1, 1, val("target", "nonTargetAlpha"), .01, function(v) save("target", "nonTargetAlpha", v) end)
            self:CreateCheckbox(content, "Fokus nicht abdunkeln", 20, -330, cfg.target.focusKeepAlpha ~= false, function(v) save("target", "focusKeepAlpha", v) end)
            self:CreateCheckbox(content, "Absorb anzeigen", 300, -330, cfg.target.showAbsorb ~= false, function(v) save("target", "showAbsorb", v) end)
            self:CreateCheckbox(content, "Execute / Low-HP Glow", 20, -375, cfg.target.executeEnabled == true, function(v) save("target", "executeEnabled", v) end,
                "Roter Glow um die Plakette unterhalb der eingestellten Schwelle. Gilt für alle Spezialisierungen.")
            self:CreateCheckbox(content, "Execute-Linie anzeigen", 20, -410, val("target", "executeLine") ~= false, function(v) save("target", "executeLine", v) end)
            self:CreateSlider(content, "Execute-Schwelle", 20, -445, 0.05, 0.5, val("target", "executeThreshold"), 0.01, function(v) save("target", "executeThreshold", v) end)
            self:CreateSlider(content, "Execute-Glow Deckkraft", 300, -445, 0, 1, val("target", "executeGlowAlpha") or 1, .05, function(v) save("target", "executeGlowAlpha", v) end)

            self:CreateHeader(content, "Bedrohung", 20, -580)
            self:CreateCheckbox(content, "Bedrohungsfarben verwenden", 20, -625, cfg.threat.enabled ~= false, function(v) save("threat", "enabled", v) end)
            self:CreateCheckbox(content, "Gegnertypen automatisch färben", 300, -625, cfg.threat.unitTypeColoring ~= false, function(v) save("threat", "unitTypeColoring", v) end)
            self:CreateCheckbox(content, "Zauberwirker automatisch erkennen", 20, -670, cfg.threat.casterColor ~= false, function(v) save("threat", "casterColor", v) end)
            self:CreateDescription(content, "Boss, Miniboss, seltene Gegner, Elite und Zauberwirker erkennt RexUI automatisch über die WoW-Gegnerdaten.", 20, -715)

            self:CreateHeader(content, "Fokus & Mouseover", 20, -770)
            self:CreateSlider(content, "Größe des Fokus", 20, -815, 1, 1.5, val("target", "focusScale") or 1, .01, function(v) save("target", "focusScale", v) end,
                "Vergrößert die Namensplakette des Fokusziels, solange es nicht gleichzeitig das aktuelle Ziel ist.")
            self:CreateCheckbox(content, "Fokus-Rahmen einfärben", 300, -815, val("target", "focusBorder") ~= false, function(v) save("target", "focusBorder", v) end)
            self:CreateCheckbox(content, "Mouseover hervorheben", 20, -885, val("target", "mouseoverHighlight") ~= false, function(v) save("target", "mouseoverHighlight", v) end,
                "Färbt den Rahmen der Namensplakette unter dem Mauszeiger. Farben im Tab Farben (Fokus, Mouseover).")

            self:CreateHeader(content, "Zielpfeile", 20, -950)
            self:CreateCheckbox(content, "Zielpfeile anzeigen", 20, -995, cfg.target.arrows ~= false, function(v) save("target", "arrows", v) end)
            self:CreateCheckbox(content, "Spieler-Klassenfarbe", 300, -995, val("target", "arrowClassColor") == true, function(v) save("target", "arrowClassColor", v) end)
            self:CreateDropdown(content, "Pfeilstil", 20, -1060, 250, {
                { value = "SINGLE", label = "Einfach" },
                { value = "DOUBLE", label = "Doppelt" },
            }, val("target", "arrowStyle") or "SINGLE", function(v) save("target", "arrowStyle", v) end)
            self:CreateSlider(content, "Pfeilgröße", 300, -1060, .5, 3, val("target", "arrowScale") or 1, .05, function(v) save("target", "arrowScale", v) end)
            self:CreateSlider(content, "Abstand", 20, -1135, 0, 30, val("target", "arrowSpacing") or 6, 1, function(v) save("target", "arrowSpacing", math.floor(v)) end)
            self:CreateSlider(content, "Deckkraft", 300, -1135, 0, 1, val("target", "arrowAlpha") or 1, .05, function(v) save("target", "arrowAlpha", v) end)
            local arrowColor = cfg.target.arrowColor or { r=1, g=1, b=1, a=1 }; cfg.target.arrowColor = arrowColor
            self:CreateColorPicker(content, "Pfeilfarbe", 20, -1205, arrowColor, function(color) cfg.target.arrowColor=color; apply() end, nil, true, true)

            local overlayTextures = {
                {value="striped-v2",label="Striped"},{value="striped-wide-v2",label="Striped Wide"},
                {value="stripes-medium",label="Medium"},{value="stripes-small-close",label="Small Close"},
                {value="stripes-small-spread",label="Small Spread"},{value="striped-tiny",label="Tiny"},
            }
            self:CreateHeader(content, "Ziel-Overlay", 20, -1270)
            self:CreateCheckbox(content, "Aktiv", 20, -1315, val("target", "targetOverlayEnabled") == true, function(v) save("target", "targetOverlayEnabled", v) end)
            self:CreateDropdown(content, "Textur", 300, -1315, 250, overlayTextures, val("target", "targetOverlayTexture") or "striped-v2", function(v) save("target", "targetOverlayTexture", v) end)
            self:CreateSlider(content, "Deckkraft", 20, -1390, 0, 1, val("target", "targetOverlayAlpha") or 1, .05, function(v) save("target", "targetOverlayAlpha", v) end)
            local targetOverlayColor = cfg.target.targetOverlayColor or {r=1,g=1,b=1,a=1}; cfg.target.targetOverlayColor=targetOverlayColor
            self:CreateColorPicker(content, "Farbe", 300, -1390, targetOverlayColor, function(color) cfg.target.targetOverlayColor=color; apply() end, nil, true, true)

            self:CreateHeader(content, "Fokus-Overlay", 20, -1470)
            self:CreateCheckbox(content, "Aktiv", 20, -1515, val("target", "focusOverlayEnabled") == true, function(v) save("target", "focusOverlayEnabled", v) end)
            self:CreateDropdown(content, "Textur", 300, -1515, 250, overlayTextures, val("target", "focusOverlayTexture") or "striped-v2", function(v) save("target", "focusOverlayTexture", v) end)
            self:CreateSlider(content, "Deckkraft", 20, -1590, 0, 1, val("target", "focusOverlayAlpha") or 1, .05, function(v) save("target", "focusOverlayAlpha", v) end)
            local focusOverlayColor = cfg.target.focusOverlayColor or {r=1,g=1,b=1,a=1}; cfg.target.focusOverlayColor=focusOverlayColor
            self:CreateColorPicker(content, "Farbe", 300, -1590, focusOverlayColor, function(color) cfg.target.focusOverlayColor=color; apply() end, nil, true, true)
            content:SetHeight(1690)
        elseif activeTab == "castbars" then
            self:CreateHeader(content, "Zauberleisten", 20, -165)
            self:CreateDescription(content, "Die wichtigsten Plater-Einstellungen für gegnerische Zauberleisten. Alle Farben zeigen ihren HEX-Code live an.", 20, -198)

            local defaults = RexUI.defaults and RexUI.defaults.profile and RexUI.defaults.profile.nameplates
                and RexUI.defaults.profile.nameplates.colors or {}
            local function ensureCastColor(key)
                if type(cfg.colors[key]) ~= "table" then
                    local source = defaults[key] or { r = 1, g = 1, b = 1, a = 1 }
                    cfg.colors[key] = { r = source.r, g = source.g, b = source.b, a = source.a or 1 }
                end
                return cfg.colors[key]
            end
            local function castPicker(key, label, x, y)
                self:CreateColorPicker(content, label, x, y, ensureCastColor(key), function() apply() end, nil, true)
            end

            self:CreateHeader(content, "Zauberleisten-Aussehen", 20, -250)
            self:CreateCheckbox(content, "Zauberleiste anzeigen", 20, -290, cfg.castbars.enabled ~= false, function(v) save("castbars", "enabled", v) end)
            self:CreateCheckbox(content, "Zaubername anzeigen", 300, -290, cfg.castbars.showName ~= false, function(v) save("castbars", "showName", v) end)
            self:CreateCheckbox(content, "Cast-Spark anzeigen", 300, -380, val("castbars", "showSpark") ~= false, function(v) save("castbars", "showSpark", v) end)
            self:CreateCheckbox(content, "Zauberzeit anzeigen", 20, -335, cfg.castbars.showTime ~= false, function(v) save("castbars", "showTime", v) end)
            self:CreateCheckbox(content, "Wichtige Zauber hervorheben", 20, -380, cfg.castbars.showImportantGlow ~= false, function(v) save("castbars", "showImportantGlow", v) end)
            self:CreateDropdown(content, "Textur", 20, -445, 250, {
                { value = "Interface\\AddOns\\RexUI\\media\\statusbars\\bar_serenity.tga", label = "RexUI Sanft" },
                { value = "Interface\\AddOns\\RexUI\\media\\statusbars\\bar_background.tga", label = "RexUI Hintergrund" },
                { value = "Interface\\TargetingFrame\\UI-StatusBar", label = "Blizzard" },
            }, cfg.castbars.texture, function(v) save("castbars", "texture", v) end)
            self:CreateSlider(content, "Höhe", 300, -445, 7, 24, val("castbars", "height"), 1, function(v) save("castbars", "height", math.floor(v)) end)

            self:CreateHeader(content, "Zauberleisten-Farben", 20, -525)
            castPicker("castNormal", "Normal", 20, -565)
            castPicker("castChannel", "Kanalisierte", 300, -565)
            castPicker("castEmpowered", "Verstärkt", 20, -617)
            castPicker("castImportant", "Wichtig", 300, -617)
            castPicker("castProtected", "Nicht unterbrechbar", 20, -669)
            castPicker("castInterrupted", "Unterbrochen", 300, -669)
            castPicker("castSucceeded", "Erfolgreich", 20, -721)
            castPicker("castBackground", "Hintergrundfarbe", 300, -721)

            self:CreateHeader(content, "Zielname der Zauberleiste", 20, -790)
            self:CreateCheckbox(content, "Zielname anzeigen", 20, -830, cfg.castbars.showTargetName ~= false, function(v) save("castbars", "showTargetName", v) end)
            self:CreateSlider(content, "Schriftgröße", 300, -830, 7, 16, val("castbars", "targetNameSize"), 1, function(v) save("castbars", "targetNameSize", math.floor(v)) end)

            self:CreateHeader(content, "Zaubersymbol", 20, -910)
            self:CreateCheckbox(content, "Symbol anzeigen", 20, -950, cfg.castbars.showIcon ~= false, function(v) save("castbars", "showIcon", v) end)
            self:CreateDropdown(content, "Seite", 300, -950, 250, {
                { value = "LEFT", label = "Links" }, { value = "RIGHT", label = "Rechts" },
            }, val("castbars", "iconSide"), function(v) save("castbars", "iconSide", v) end)
            self:CreateSlider(content, "Symbolgröße", 20, -1020, 10, 32, val("castbars", "iconSize"), 1, function(v) save("castbars", "iconSize", math.floor(v)) end)
            self:CreateCheckbox(content, "Schild bei nicht unterbrechbar", 300, -1020, cfg.castbars.showShield ~= false, function(v) save("castbars", "showShield", v) end)
            self:CreateSlider(content, "Fokus-Castbar Skalierung", 20, -1090, .75, 2, val("castbars", "focusScale") or 1, .05, function(v) save("castbars", "focusScale", v) end)
            content:SetHeight(1190)
        elseif activeTab == "auras" then
            self:CreateHeader(content, "Auren", 20, -165)
            self:CreateDescription(content, "Stärkungszauber, Schwächungszauber und Kontrolleffekte lassen sich getrennt positionieren. X und Y verschieben die jeweilige Reihe sofort.", 20, -198)
            local auraChecks = {{"buffs","Stärkungszauber"},{"debuffs","Schwächungszauber"},{"ownDebuffs","Eigene Schwächungszauber"},{"important","Wichtige Auren"},{"crowdControl","Kontrolleffekte"}}
            for index, item in ipairs(auraChecks) do
                local key = item[1]
                local x = index % 2 == 1 and 20 or 300
                local y = -245 - math.floor((index - 1) / 2) * 50
                self:CreateCheckbox(content, item[2], x, y, cfg.auras[key] ~= false, function(v)
                    if NP and NP.SetAuraEnabled then NP:SetAuraEnabled(key, v) else save("auras", key, v) end
                end)
            end
            local positions = {
                {value="TOP",label="Oben mittig"},{value="TOPLEFT",label="Oben links"},
                {value="TOPRIGHT",label="Oben rechts"},{value="BOTTOM",label="Unten"},
                {value="LEFT",label="Links"},{value="RIGHT",label="Rechts"},
                {value="CENTER",label="Frei ab Balkenmitte"},
            }
            local defaults = {
                debuff={position="TOP",x=0,y=20,size=20,spacing=2},
                buff={position="LEFT",x=-7,y=0,size=20,spacing=2},
                cc={position="RIGHT",x=34,y=0,size=20,spacing=2},
            }
            local function createAuraLayoutSection(key, title, y)
                local d = defaults[key]
                self:CreateHeader(content, title, 20, y)
                self:CreateDropdown(content, "Position", 20, y - 55, 250, positions,
                    cfg.auras[key .. "Position"] or d.position,
                    function(v) save("auras", key .. "Position", v) end)
                self:CreateSlider(content, "Größe", 300, y - 55, 12, 40,
                    cfg.auras[key .. "Size"] or cfg.auras.size or d.size, 1,
                    function(v) save("auras", key .. "Size", math.floor(v)) end)
                self:CreateSlider(content, "X-Position", 20, y - 135, -200, 200,
                    cfg.auras[key .. "X"] or d.x, 1,
                    function(v) save("auras", key .. "X", math.floor(v)) end)
                self:CreateSlider(content, "Y-Position", 300, y - 135, -200, 200,
                    cfg.auras[key .. "Y"] or d.y, 1,
                    function(v) save("auras", key .. "Y", math.floor(v)) end)
                self:CreateSlider(content, "Symbolabstand", 20, y - 215, 0, 12,
                    cfg.auras[key .. "Spacing"] or d.spacing, 1,
                    function(v) save("auras", key .. "Spacing", math.floor(v)) end)
            end
            createAuraLayoutSection("debuff", "Position der Schwächungszauber", -405)
            createAuraLayoutSection("buff", "Position der Stärkungszauber", -685)
            createAuraLayoutSection("cc", "Position der Kontrolleffekte", -965)
            self:CreateHeader(content, "Anzahl & Rahmen", 20, -1245)
            self:CreateSlider(content, "Max. Schwächungszauber", 20, -1300, 0, 8, val("auras", "maxDebuffs") or 5, 1, function(v) save("auras", "maxDebuffs", math.floor(v)) end)
            self:CreateSlider(content, "Max. Stärkungszauber", 300, -1300, 0, 6, val("auras", "maxBuffs") or 4, 1, function(v) save("auras", "maxBuffs", math.floor(v)) end)
            self:CreateSlider(content, "Max. Kontrolleffekte", 20, -1380, 0, 4, val("auras", "maxCC") or 2, 1, function(v) save("auras", "maxCC", math.floor(v)) end)
            self:CreateCheckbox(content, "Rahmen nach Bannbarkeit färben", 300, -1380, val("auras", "dispelBorders") ~= false, function(v) save("auras", "dispelBorders", v) end,
                "Magie blau, Fluch violett, Krankheit braun, Gift grün, Wutanfall orange. Im Kampf, in M+ und PvP sind Aura-Daten geheim; dann bleibt der Rahmen neutral.")
            content:SetHeight(1470)
        elseif activeTab == "indicators" then
            self:CreateHeader(content, "Indikatoren", 20, -165)
            self:CreateDescription(content, "Quest-, Elite-, Selten- und Bosssymbole stehen gemeinsam rechts neben dem doppelten Zielpfeil. Aggro wird als rotes ! im Balken angezeigt.", 20, -198)
            local checks = {{"raidMarker","Zielmarkierungen"},{"quest","Questziel"},{"boss","Boss"},{"elite","Elite"},{"rare","Selten"},{"aggro","Aggro"}}
            for index, item in ipairs(checks) do
                local key = item[1]
                local x = index % 2 == 1 and 20 or 300
                local y = -245 - math.floor((index - 1) / 2) * 55
                self:CreateCheckbox(content, item[2], x, y, cfg.indicators[key] ~= false, function(v)
                    if NP and NP.SetIndicatorEnabled then NP:SetIndicatorEnabled(key, v) else save("indicators", key, v) end
                end)
            end
            content:SetHeight(450)
        else
            self:CreateHeader(content, "Aurenfilter", 20, -165)
            self:CreateDescription(content, "Hier bestimmst du per Zauber-ID, welche Stärkungs- oder Schwächungszauber immer beziehungsweise niemals auf Namensplaketten erscheinen. Ohne Einträge arbeitet RexUI mit den normalen WoW-Aurenregeln.", 20, -205)
            local box = CreateEditBox(content, 20, -265, 250, 30, false)
            box:SetNumeric(true)
            self:CreateButton(content, "Immer anzeigen", 300, -265, 115, 30, function()
                local id = tonumber(box:GetText()); if id and NP then NP:SetAuraFilter(id, "include", true) end
            end)
            self:CreateButton(content, "Nie anzeigen", 425, -265, 115, 30, function()
                local id = tonumber(box:GetText()); if id and NP then NP:SetAuraFilter(id, "exclude", true) end
            end)
            self:CreateButton(content, "Eintrag entfernen", 300, -320, 240, 30, function()
                local id = tonumber(box:GetText()); if id and NP then NP:SetAuraFilter(id, "include", false) end
            end)
            local function activeFilterIDs(bucket)
                local ids = {}
                for spellID, enabled in pairs(bucket or {}) do
                    if enabled then ids[#ids + 1] = tonumber(spellID) or spellID end
                end
                table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
                return #ids > 0 and table.concat(ids, ", ") or T("keine")
            end
            self:CreateDescription(content, T("Immer anzeigen") .. ": " .. activeFilterIDs(cfg.filters.include), 20, -375)
            self:CreateDescription(content, T("Nie anzeigen") .. ": " .. activeFilterIDs(cfg.filters.exclude), 20, -405)
            content:SetHeight(430)
        end
        return
    end

    if category == "Gruppenframes" then
        local groupFrames = RexUI.GroupFrames
        local cfg = groupFrames and groupFrames.GetConfig and groupFrames:GetConfig()

        if not cfg then
            self:CreateDescription(content, "Die Gruppenframe-Einstellungen werden noch geladen. Bitte öffne diese Kategorie nach /reload erneut.", 20, -55)
            content:SetHeight(260)
            return
        end

        local function apply(key, value)
            cfg[key] = value
            if groupFrames.Save then groupFrames:Save(key, value) end
            if groupFrames.Apply then groupFrames:Apply() end
            if groupFrames.IsPreviewShown and groupFrames:IsPreviewShown() and groupFrames.ShowPreview then
                local activePreview = groupFrames.GetPreviewCount and groupFrames:GetPreviewCount() or (self.GroupFramePreviewCount or 20)
                groupFrames:ShowPreview(activePreview)
            end
        end

        local tabs = {
            { id = "general", label = "Allgemein" },
            { id = "party", label = "Party" },
            { id = "raid", label = "Raid" },
            { id = "indicators", label = "Anzeigen" },
        }
        local activeTab = self.GroupFrameSubTab or "general"
        local tabWidth, tabGap = 104, 5
        for index, tabInfo in ipairs(tabs) do
            local tabID = tabInfo.id
            local button = self:CreateButton(content, tabInfo.label, 20 + ((index - 1) * (tabWidth + tabGap)), -58, tabWidth, 28, function()
                self.GroupFrameSubTab = tabID
                self:UpdateSettings("Gruppenframes")
            end)
            if tabID == activeTab then
                button:Disable()
                button.Background:SetColorTexture(0.34, 0.10, 0.45, 1)
                button.Text:SetTextColor(RexUI:GetColor("highlight"))
                button.Border:SetAlpha(1)
            end
        end

        self:CreateDivider(content, 20, -100, 540)

        if activeTab == "general" then
            self:CreateHeader(content, "Allgemein", 20, -135)
            self:CreateCheckbox(content, "Gruppenframes aktivieren", 20, -220, cfg.partyEnabled ~= false, function(v) apply("partyEnabled", v) end)
            self:CreateCheckbox(content, "Raidframes aktivieren", 300, -220, cfg.raidEnabled ~= false, function(v) apply("raidEnabled", v) end)
            self:CreateCheckbox(content, "Blizzard-Gruppenframes anzeigen", 20, -265, cfg.hideBlizzard == false, function(v) apply("hideBlizzard", not v) end)
            content:SetHeight(380)

        elseif activeTab == "party" then
            self:CreateHeader(content, "Partyframes", 20, -135)
            self:CreateSlider(content, "Framebreite", 20, -220, 40, 300, cfg.partyFrameWidth or 125, 1, function(v) apply("partyFrameWidth", v) end)
            self:CreateSlider(content, "Framehöhe", 300, -220, 20, 150, cfg.partyFrameHeight or 60, 1, function(v) apply("partyFrameHeight", v) end)
            self:CreateSlider(content, "Abstand der Spieler", 20, -300, -10, 20, cfg.partyCellSpacing or -1, 1, function(v) apply("partyCellSpacing", v) end)
            self:CreateSlider(content, "Powerleistenhöhe", 300, -300, 2, 20, cfg.partyPowerHeight or 4, 1, function(v) apply("partyPowerHeight", v) end)

            self:CreateDivider(content, 20, -360, 540)
            self:CreateHeader(content, "Party-Testmodus", 20, -390)
            self:CreateButton(content, "Party-Testmodus AN/AUS", 20, -470, 210, 32, function()
                if not groupFrames then return end
                if groupFrames.IsPartyPreviewShown and groupFrames:IsPartyPreviewShown() then
                    if groupFrames.HidePreview then groupFrames:HidePreview() end
                elseif groupFrames.ShowPreview then
                    groupFrames:ShowPreview(5)
                end
            end)
            self:CreateButton(content, "Partyframes entsperren", 20, -525, 210, 32, function()
                if groupFrames and groupFrames.ShowPartyMover then groupFrames:ShowPartyMover() end
            end)
            self:CreateButton(content, "Partyframes sperren", 250, -525, 210, 32, function()
                if groupFrames and groupFrames.HidePartyMover then groupFrames:HidePartyMover() end
            end)
            content:SetHeight(650)

        elseif activeTab == "raid" then
            self:CreateHeader(content, "Raidframes", 20, -135)
            self:CreateSlider(content, "Framebreite", 20, -220, 40, 300, cfg.frameWidth or 90, 1, function(v) apply("frameWidth", v) end)
            self:CreateSlider(content, "Framehöhe", 300, -220, 20, 150, cfg.frameHeight or 38, 1, function(v) apply("frameHeight", v) end)
            self:CreateSlider(content, "Abstand der Spieler", 20, -300, -10, 20, cfg.cellSpacing or -1, 1, function(v) apply("cellSpacing", v) end)
            self:CreateSlider(content, "Abstand der Gruppen", 300, -300, -10, 40, cfg.groupSpacing or -1, 1, function(v) apply("groupSpacing", v) end)
            self:CreateSlider(content, "Powerleistenhöhe", 20, -380, 2, 20, cfg.powerHeight or 3, 1, function(v) apply("powerHeight", v) end)

            self:CreateDivider(content, 20, -440, 540)
            self:CreateHeader(content, "Raid-Testmodus", 20, -470)
            self.GroupFramePreviewCount = self.GroupFramePreviewCount or 20
            self:CreateSlider(content, "Spieler im Test", 20, -525, 10, 40, self.GroupFramePreviewCount, 5, function(v)
                v = math.max(10, math.min(40, math.floor((v + 2) / 5) * 5))
                self.GroupFramePreviewCount = v
                if groupFrames and groupFrames.IsRaidPreviewShown and groupFrames:IsRaidPreviewShown() and groupFrames.ShowPreview then
                    groupFrames:ShowPreview(v)
                end
            end)
            self:CreateButton(content, "Raid-Testmodus AN/AUS", 20, -615, 210, 32, function()
                if not groupFrames then return end
                if groupFrames.IsRaidPreviewShown and groupFrames:IsRaidPreviewShown() then
                    if groupFrames.HidePreview then groupFrames:HidePreview() end
                elseif groupFrames.ShowPreview then
                    groupFrames:ShowPreview(self.GroupFramePreviewCount or 20)
                end
            end)
            self:CreateButton(content, "Raidframes entsperren", 20, -670, 210, 32, function()
                if groupFrames and groupFrames.ShowRaidMover then groupFrames:ShowRaidMover() end
            end)
            self:CreateButton(content, "Raidframes sperren", 250, -670, 210, 32, function()
                if groupFrames and groupFrames.HideRaidMover then groupFrames:HideRaidMover() end
            end)
            content:SetHeight(800)

        elseif activeTab == "indicators" then
            self:CreateHeader(content, "Party-Anzeigen", 20, -135)
            self:CreateCheckbox(content, "Ressourcenleiste", 20, -180, cfg.partyShowPowerBar ~= false, function(v) apply("partyShowPowerBar", v) end)
            self:CreateCheckbox(content, "Rollensymbole", 300, -180, cfg.partyShowRoleIcon ~= false, function(v) apply("partyShowRoleIcon", v) end)
            self:CreateCheckbox(content, "Raidmarkierungen", 20, -220, cfg.partyShowRaidMarker ~= false, function(v) apply("partyShowRaidMarker", v) end)
            self:CreateCheckbox(content, "Bereitschaftscheck", 300, -220, cfg.partyShowReadyCheck ~= false, function(v) apply("partyShowReadyCheck", v) end)
            self:CreateCheckbox(content, "Gruppenleiter", 20, -260, cfg.partyShowLeaderIcon == true, function(v) apply("partyShowLeaderIcon", v) end)
            self:CreateCheckbox(content, "Gesundheit in Prozent", 300, -260, cfg.partyShowHealthText == true, function(v) apply("partyShowHealthText", v) end)
            self:CreateCheckbox(content, "Debuffs", 20, -300, cfg.partyShowDebuffs ~= false, function(v) apply("partyShowDebuffs", v) end)
            self:CreateCheckbox(content, "Eingehende Heilung", 300, -300, cfg.partyShowIncomingHeals ~= false, function(v) apply("partyShowIncomingHeals", v) end)
            self:CreateCheckbox(content, "Aggro-Rahmen", 20, -340, cfg.partyShowAggro ~= false, function(v) apply("partyShowAggro", v) end)

            self:CreateDivider(content, 20, -395, 540)
            self:CreateHeader(content, "Raid-Anzeigen", 20, -425)
            self:CreateCheckbox(content, "Ressourcenleiste", 20, -470, cfg.showPowerBar ~= false, function(v) apply("showPowerBar", v) end)
            self:CreateCheckbox(content, "Rollensymbole", 300, -470, cfg.showRoleIcon ~= false, function(v) apply("showRoleIcon", v) end)
            self:CreateCheckbox(content, "Raidmarkierungen", 20, -510, cfg.showRaidMarker ~= false, function(v) apply("showRaidMarker", v) end)
            self:CreateCheckbox(content, "Bereitschaftscheck", 300, -510, cfg.showReadyCheck ~= false, function(v) apply("showReadyCheck", v) end)
            self:CreateCheckbox(content, "Gruppenleiter", 20, -550, cfg.showLeaderIcon == true, function(v) apply("showLeaderIcon", v) end)
            self:CreateCheckbox(content, "Gesundheit in Prozent", 300, -550, cfg.showHealthText == true, function(v) apply("showHealthText", v) end)
            self:CreateCheckbox(content, "Debuffs", 20, -590, cfg.showDebuffs ~= false, function(v) apply("showDebuffs", v) end)
            self:CreateCheckbox(content, "Eingehende Heilung", 300, -590, cfg.showIncomingHeals ~= false, function(v) apply("showIncomingHeals", v) end)
            self:CreateCheckbox(content, "Aggro-Rahmen", 20, -630, cfg.showAggro ~= false, function(v) apply("showAggro", v) end)
            content:SetHeight(760)

        end
        return
    end


    if category == "UnitFrames" then
        profile.unitframes = type(profile.unitframes) == "table" and profile.unitframes or {}

        local unitTabs = {
            { id = "player", label = "Spieler" },
            { id = "target", label = "Ziel" },
            { id = "focus", label = "Fokus" },
            { id = "pet", label = "Begleiter" },
            { id = "boss", label = "Boss" },
        }
        local unitKey = self.UnitFrameMainTab or "player"
        local unitLabel = "Spieler"
        for i, t in ipairs(unitTabs) do
            local id = t.id
            if id == unitKey then unitLabel = t.label end
            local btn = self:CreateButton(content, t.label, 20 + ((i - 1) * 108), -20, 100, 28, function()
                self.UnitFrameMainTab = id
                self:UpdateSettings("UnitFrames")
            end)
            if id == unitKey then
                btn:Disable()
                btn.Background:SetColorTexture(0.34, 0.10, 0.45, 1)
                btn.Text:SetTextColor(RexUI:GetColor("highlight"))
                btn.Border:SetAlpha(1)
            end
        end

        profile.unitframes[unitKey] = type(profile.unitframes[unitKey]) == "table" and profile.unitframes[unitKey] or {}
        local cfg = profile.unitframes[unitKey]
        local UF = _G["RexUI"] and _G["RexUI"].UnitFrames
        local defaultByUnit = {
            player = { enabled = true, width = 220, healthHeight = 42, powerHeight = 7, scale = 1, healthFormat = "PERCENT", healthBackgroundColor = { r = 17/255, g = 17/255, b = 17/255, a = 0.5 }, showCastbar = false, castbarPlacement = "INSIDE", showPortrait = false, showLevel = false, showRaidMarker = false, showDebuffs = false, debuffSize = 20, debuffRows = 1, debuffX = 0, debuffY = -4, showCombatIndicator = true, showClassPower = true, classPowerHeight = 12, castbarColor = { r = 0.20, g = 0.55, b = 0.95, a = 1 } },
            pet = { enabled = true, width = 180, healthHeight = 28, powerHeight = 5, scale = 1, healthBackgroundColor = { r = 17/255, g = 17/255, b = 17/255, a = 0.5 }, showCastbar = false, castbarPlacement = "INSIDE", showPortrait = false, showLevel = false, showRaidMarker = false, showDebuffs = false, debuffSize = 18, debuffRows = 1, debuffX = 0, debuffY = -4 },
            target = { enabled = true, width = 220, healthHeight = 42, powerHeight = 7, scale = 1, healthFormat = "PERCENT", healthBackgroundColor = { r = 17/255, g = 17/255, b = 17/255, a = 0.5 }, showCastbar = true, castbarPlacement = "INSIDE", showPortrait = true, showLevel = true, showRaidMarker = true, showDebuffs = true, debuffSize = 22, debuffRows = 2, debuffX = 0, debuffY = -4, showBuffs = true, buffSize = 20, buffRows = 1, buffX = 0, buffY = -4, showThreat = true, rangeFade = true },
            focus = { enabled = true, width = 180, healthHeight = 34, powerHeight = 6, scale = 1, healthFormat = "PERCENT", healthBackgroundColor = { r = 17/255, g = 17/255, b = 17/255, a = 0.5 }, showCastbar = true, castbarPlacement = "INSIDE", showPortrait = true, showLevel = true, showRaidMarker = true, showDebuffs = true, debuffSize = 20, debuffRows = 2, debuffX = 0, debuffY = -4, showBuffs = true, buffSize = 18, buffRows = 1, buffX = 0, buffY = -4, showThreat = true, rangeFade = true },
            boss = { enabled = true, width = 190, healthHeight = 34, powerHeight = 6, scale = 1, count = 5, spacing = 12, healthFormat = "PERCENT", healthBackgroundColor = { r = 17/255, g = 17/255, b = 17/255, a = 0.5 }, showCastbar = true, castbarPlacement = "INSIDE", showPortrait = false, showLevel = true, showRaidMarker = true, showDebuffs = false, debuffSize = 20, debuffRows = 1, debuffX = 0, debuffY = -4, showThreat = true, rangeFade = true },
        }
        local defaults = defaultByUnit[unitKey] or {}

        local function option(key, fallback)
            if cfg[key] ~= nil then return cfg[key] end
            if defaults[key] ~= nil then return defaults[key] end
            return fallback
        end

        local function save(key, value)
            cfg[key] = value
            if UF and UF.Apply then UF:Apply() end
        end

        local stateKey = "UnitFrameSubTab_" .. unitKey
        local activeTab = self[stateKey] or "general"
        local tabs = {{id="general",label="Allgemein"},{id="appearance",label="Darstellung"},{id="indicators",label="Anzeigen"}}
        for i,t in ipairs(tabs) do
            local id=t.id
            local btn=self:CreateButton(content,t.label,20+((i-1)*178),-72,170,28,function() self[stateKey]=id; self:UpdateSettings(category) end)
            if id==activeTab then btn:Disable(); btn.Background:SetColorTexture(0.34,0.10,0.45,1); btn.Text:SetTextColor(RexUI:GetColor("highlight")); btn.Border:SetAlpha(1) end
        end
        self:CreateDivider(content,20,-114,540)
        if activeTab=="general" then
            self:CreateCheckbox(content,T(unitLabel).." "..T("Frame aktivieren"),20,-159,option("enabled",true)~=false,function(v) save("enabled",v) end)
            -- Einheitliches Zweispaltenraster fuer Spieler, Ziel, Fokus,
            -- Begleiter und Boss. Eine Slider-Zeile braucht etwa 70 Pixel.
            local function CreateGeneralSlider(label, x, y, minValue, maxValue, currentValue, valueStep, onChanged)
                local slider = self:CreateSlider(content, label, x, y, minValue, maxValue, currentValue, valueStep, onChanged)
                -- 190 + 18 Abstand + 55 Wertefeld = 263 Pixel; beide Spalten
                -- passen damit ohne Beruehrung in das 540-Pixel-Raster.
                slider:SetWidth(190)
                return slider
            end

            CreateGeneralSlider("Breite",20,-214,120,360,option("width",unitKey=="boss" and 190 or unitKey=="focus" and 180 or 220),5,function(v) save("width",math.floor(v)) end)
            CreateGeneralSlider("Lebenshoehe",300,-214,24,70,option("healthHeight",unitKey=="focus" and 34 or 42),1,function(v) save("healthHeight",math.floor(v)) end)
            CreateGeneralSlider("Powerhoehe",20,-289,0,18,option("powerHeight",7),1,function(v) save("powerHeight",math.floor(v)) end)
            CreateGeneralSlider("Skalierung",300,-289,0.5,2,option("scale",1),0.05,function(v) save("scale",v) end)
            if unitKey=="boss" then
                CreateGeneralSlider("Boss-Anzahl",20,-364,1,5,option("count",5),1,function(v) save("count",math.floor(v)) end)
                CreateGeneralSlider("Abstand",300,-364,0,30,option("spacing",12),1,function(v) save("spacing",math.floor(v)) end)
                content:SetHeight(510)
            else
                content:SetHeight(440)
            end
        elseif activeTab=="appearance" then
            self:CreateCheckbox(content,"Castbar anzeigen",20,-159,option("showCastbar",true)==true,function(v) save("showCastbar",v) end)
            local placement=option("castbarPlacement","INSIDE")=="BELOW" and "BELOW" or "INSIDE"; local placementButton
            placementButton=self:CreateButton(content,placement=="INSIDE" and "Castbar: Im Frame" or "Castbar: Unten",300,-152,180,28,function() placement=placement=="INSIDE" and "BELOW" or "INSIDE"; save("castbarPlacement",placement); if placementButton and placementButton.Text then placementButton.Text:SetText(T(placement=="INSIDE" and "Castbar: Im Frame" or "Castbar: Unten")) end end)
            self:CreateCheckbox(content,"Portrait anzeigen",20,-204,option("showPortrait",false)==true,function(v) save("showPortrait",v) end)
            if unitKey=="player" or unitKey=="target" or unitKey=="focus" or unitKey=="boss" then self:CreateDropdown(content,"Gesundheitsanzeige",20,-259,250,{{value="PERCENT",label="Prozent (100%)"},{value="COMPACT",label="Kompakt (125k)"}},option("healthFormat","PERCENT"),function(v) save("healthFormat",v) end,"Wählt die Gesundheitsanzeige für dieses Unitframe.") end
            local healthBackgroundColor = cfg.healthBackgroundColor
            if type(healthBackgroundColor) ~= "table" then
                healthBackgroundColor = { r = 17/255, g = 17/255, b = 17/255, a = 0.5 }
                cfg.healthBackgroundColor = healthBackgroundColor
            end
            self:CreateColorPicker(content,"Lebensbalken-Hintergrund",20,-314,healthBackgroundColor,function(color)
                cfg.healthBackgroundColor = color
                if UF and UF.Apply then UF:Apply() end
            end, "Farbe und Deckkraft des fehlenden Lebensbereichs für dieses Unitframe.", true, true)
            if unitKey=="player" then
                local castbarColor = cfg.castbarColor
                if type(castbarColor) ~= "table" then castbarColor = { r = 0.20, g = 0.55, b = 0.95, a = 1 } end
                self:CreateColorPicker(content,"Eigene Castbar-Farbe",300,-259,castbarColor,function(color)
                    cfg.castbarColor = color
                    if UF and UF.Apply then UF:Apply() end
                end, "Legt die Farbe deiner eigenen Spieler-Castbar fest.")
                content:SetHeight(500)
            else
                -- Target, Focus and Boss use the fixed enemy-cast palette.
                content:SetHeight(465)
            end
        else
            self:CreateCheckbox(content,"Level anzeigen",20,-159,option("showLevel",false)==true,function(v) save("showLevel",v) end)
            self:CreateCheckbox(content,"Raidmarker anzeigen",300,-159,option("showRaidMarker",false)==true,function(v) save("showRaidMarker",v) end)
            if unitKey=="player" then
                self:CreateCheckbox(content,"Kampfpunkt anzeigen",20,-204,option("showCombatIndicator",true)==true,function(v) save("showCombatIndicator",v) end)
                self:CreateCheckbox(content,"Klassenressourcen anzeigen",300,-204,option("showClassPower",true)~=false,function(v) save("showClassPower",v) end)
                self:CreateSlider(content,"Höhe der Klassenressourcen",20,-269,8,24,option("classPowerHeight",12),1,function(v) save("classPowerHeight",math.floor(v)) end); content:SetHeight(420)
            elseif unitKey=="target" or unitKey=="focus" then
                self:CreateCheckbox(content,"Aggro-Rand",20,-204,option("showThreat",true)==true,function(v) save("showThreat",v) end); self:CreateCheckbox(content,"Range-Fade",300,-204,option("rangeFade",true)==true,function(v) save("rangeFade",v) end)
                self:CreateHeader(content,"Auren",20,-249)
                self:CreateCheckbox(content,"Buffs anzeigen",20,-289,option("showBuffs",true)==true,function(v) save("showBuffs",v) end)
                self:CreateCheckbox(content,"Debuffs anzeigen",300,-289,option("showDebuffs",true)==true,function(v) save("showDebuffs",v) end)
                self:CreateSlider(content,"Buff-Größe",20,-354,14,34,option("buffSize",unitKey=="target" and 20 or 18),1,function(v) save("buffSize",math.floor(v)) end); self:CreateSlider(content,"Buff-X",300,-354,-120,120,option("buffX",0),1,function(v) save("buffX",math.floor(v)) end)
                self:CreateSlider(content,"Buff-Reihen",20,-429,1,4,option("buffRows",1),1,function(v) save("buffRows",math.floor(v)) end); self:CreateSlider(content,"Buff-Y",300,-429,-120,40,option("buffY",-4),1,function(v) save("buffY",math.floor(v)) end)
                self:CreateSlider(content,"Debuff-Größe",20,-504,14,34,option("debuffSize",unitKey=="target" and 22 or 20),1,function(v) save("debuffSize",math.floor(v)) end); self:CreateSlider(content,"Debuff-X",300,-504,-120,120,option("debuffX",0),1,function(v) save("debuffX",math.floor(v)) end)
                self:CreateSlider(content,"Debuff-Reihen",20,-579,1,4,option("debuffRows",2),1,function(v) save("debuffRows",math.floor(v)) end); self:CreateSlider(content,"Debuff-Y",300,-579,-120,40,option("debuffY",-4),1,function(v) save("debuffY",math.floor(v)) end); content:SetHeight(730)
            elseif unitKey=="boss" then self:CreateCheckbox(content,"Aggro-Rand",20,-204,option("showThreat",true)==true,function(v) save("showThreat",v) end); self:CreateCheckbox(content,"Range-Fade",300,-204,option("rangeFade",true)==true,function(v) save("rangeFade",v) end); content:SetHeight(350)
            else content:SetHeight(300) end
        end
        return
    end

    if category == "Taschen" then
        profile.bags = profile.bags or {}
        local bagCfg, B = profile.bags, RexUI.Bags
        local function save(key, value) profile.bags[key] = value end
        local function refreshBags() if B and B.Refresh then B:Refresh() end end
        local tabs = {{"general","Allgemein"},{"popup","Taschen-Popup"},{"reagent","Reagenzientasche"}}
        local activeTab = self.BagsSubTab or "general"
        for i,t in ipairs(tabs) do
            local id=t[1]
            local b=self:CreateButton(content,t[2],20+(i-1)*180,-82,170,28,function() self.BagsSubTab=id; self:UpdateSettings("Taschen") end)
            if id==activeTab then b:Disable(); b.Background:SetColorTexture(.34,.10,.45,1); b.Text:SetTextColor(RexUI:GetColor("highlight")); b.Border:SetAlpha(1) end
        end
        self:CreateDivider(content,20,-125,540)
        if activeTab=="general" then
            self:CreateSlider(content,"Skalierung",20,-175,.5,2,bagCfg.scale or 1,.05,function(v) save("scale",v); refreshBags() end)
            self:CreateButton(content,"Taschenposition zurücksetzen",20,-255,240,30,function()
                if B and B.ResetPosition then B:ResetPosition() else save("bagPoint","CENTER"); save("bagRelPoint","CENTER"); save("bagX",0); save("bagY",0) end
            end)
            self:CreateDescription(content,"Zum Verschieben die UI über den zentralen Entsperren-Button freigeben.",20,-305)
            content:SetHeight(390)
        elseif activeTab=="popup" then
            self:CreateSlider(content,"Button-Größe",20,-175,20,64,bagCfg.barButtonSize or 28,1,function(v) save("barButtonSize",v); if B and B.RefreshBagBar then B:RefreshBagBar() end end)
            self:CreateSlider(content,"Button-Abstand",300,-175,0,20,bagCfg.barSpacing or 2,1,function(v) save("barSpacing",v); if B and B.RefreshBagBar then B:RefreshBagBar() end end)
            self:CreateDescription(content,"Die originalen Taschenbuttons lassen sich über das Rucksacksymbol einblenden.",20,-265)
            content:SetHeight(350)
        else
            bagCfg.reagentSlotColor = bagCfg.reagentSlotColor or {r=.18,g=.75,b=.50,a=1}
            if bagCfg.showReagentSlotColor==nil then bagCfg.showReagentSlotColor=true end
            self:CreateCheckbox(content,"Reagenzienplätze hervorheben",20,-175,bagCfg.showReagentSlotColor~=false,function(v) save("showReagentSlotColor",v); refreshBags() end)
            self:CreateColorPicker(content,"Reagenzienfarbe",20,-230,bagCfg.reagentSlotColor,refreshBags)
            self:CreateDescription(content,"Der vollständige Slot-Rahmen wird gefärbt. Qualitätsfarben seltener Gegenstände haben Vorrang.",20,-290)
            content:SetHeight(380)
        end
        return
    end

    if category == "Blizzard Skin" then

        profile.blizzardSkin =
            profile.blizzardSkin or {}

        local skin =
            profile.blizzardSkin

        local function save(key, value)
            skin[key] = value
            MarkReloadRequired()

            if RexUI.BlizzardSkin
            and RexUI.BlizzardSkin.Refresh then
                RexUI.BlizzardSkin:Refresh()
            end
        end

        self:CreateDescription(
            content,
            "Gezielte RexUI-Skins für sichere Blizzard-Fenster.",
            20,
            -55
        )

        self:CreateDivider(content, 20, -90, 540)

        self:CreateCheckbox(
            content,
            "Blizzard Skin aktivieren",
            20,
            -120,
            skin.enabled ~= false,
            function(value)
                save("enabled", value)
            end
        )

        self:CreateCheckbox(
            content,
            "ESC-Menü stylen",
            20,
            -165,
            skin.gameMenu ~= false,
            function(value)
                save("gameMenu", value)
            end
        )

        self:CreateCheckbox(
            content,
            "Tooltips stylen",
            20,
            -205,
            skin.tooltips ~= false,
            function(value)
                save("tooltips", value)
            end
        )

        self:CreateCheckbox(
            content,
            "Popups stylen",
            20,
            -245,
            skin.staticPopups ~= false,
            function(value)
                save("staticPopups", value)
            end
        )

        self:CreateCheckbox(
            content,
            "Kontextmenues stylen",
            20,
            -285,
            skin.dropdownMenus ~= false,
            function(value)
                save("dropdownMenus", value)
            end
        )

        self:CreateCheckbox(
            content,
            "LFG-Queue-Popups stylen",
            20,
            -320,
            skin.lfgQueue ~= false,
            function(value)
                save("lfgQueue", value)
            end
        )

        self:CreateCheckbox(
            content,
            "Quick-Keybind-Popup stylen",
            20,
            -355,
            skin.keybind ~= false,
            function(value)
                save("keybind", value)
            end
        )

        self:CreateCheckbox(
            content,
            "Charakterfenster stylen",
            20,
            -390,
            skin.characterSheet ~= false,
            function(value)
                save("characterSheet", value)
            end
        )

        self:CreateCheckbox(
            content,
            "Inspektionsfenster stylen",
            20,
            -425,
            skin.inspect ~= false,
            function(value)
                save("inspect", value)
            end
        )

        self:CreateCheckbox(
            content,
            "Freundesliste stylen",
            20,
            -460,
            skin.friends ~= false,
            function(value)
                save("friends", value)
            end
        )

        self:CreateDivider(content, 20, -530, 540)

        self:CreateDescription(
            content,
            "Hinweis: Abschalten entfernt neue Skins nach Reload vollständig. Bereits offene Fenster können bis zum nächsten Öffnen so bleiben.",
            20,
            -565
        )

        CreateReloadBar(content, -625)

        content:SetHeight(760)

        return
    end

    if category == "Minimap" then

        profile.minimap = profile.minimap or {}

        local cfg = profile.minimap
        local MM = _G["RexUI"] and _G["RexUI"].Minimap

        local function save(key, value)
            cfg[key] = value
            if MM and MM.Update then
                MM:Update()
            end
        end

        -- Minimap in kompakte Unterseiten aufteilen. Die Einstellungen selbst
        -- bleiben unveraendert; nur ihre Darstellung in der Config wird sortiert.
        local tabs = {
            { id = "general", label = "Allgemein" },
            { id = "display", label = "Anzeige" },
            { id = "databar", label = "Datenleiste" },
        }
        local activeTab = self.MinimapSubTab or "general"
        if activeTab == "panels" then
            activeTab = "databar"
            self.MinimapSubTab = activeTab
        end
        local tabWidth, tabGap = 170, 10
        for index, tabInfo in ipairs(tabs) do
            local tabID = tabInfo.id
            local button = self:CreateButton(content, tabInfo.label, 20 + ((index - 1) * (tabWidth + tabGap)), -82, tabWidth, 28, function()
                self.MinimapSubTab = tabID
                self:UpdateSettings("Minimap")
            end)
            if tabID == activeTab then
                button:Disable()
                button.Background:SetColorTexture(0.34, 0.10, 0.45, 1)
                button.Text:SetTextColor(RexUI:GetColor("highlight"))
                button.Border:SetAlpha(1)
            end
        end
        self:CreateDivider(content, 20, -125, 540)

        if activeTab == "general" then
            self:CreateCheckbox(content, "Minimap aktivieren", 20, -170, cfg.enabled ~= false, function(value)
                save("enabled", value)
            end)
            self:CreateSlider(content, "Größe", 20, -235, 100, 400, cfg.size or 160, 5, function(value)
                save("size", math.floor(value))
            end)
            self:CreateSlider(content, "Randstärke", 300, -235, 0, 4, cfg.borderSize or 1, 1, function(value)
                save("borderSize", math.floor(value))
            end)
            self:CreateSlider(content, "Queue-Auge Skalierung", 20, -325, 35, 300, (cfg.queueScale or 1) * 100, 10, function(value)
                save("queueScale", value / 100)
                if MM and MM.UpdateQueue then
                    MM:UpdateQueue()
                elseif MM and MM.Update then
                    MM:Update()
                end
            end)
            self:CreateDescription(content, "Der Battle.net-Popup-Mover erscheint beim Entsperren der Positionen.", 20, -405)
            content:SetHeight(500)

        elseif activeTab == "display" then
            self:CreateCheckbox(content, "Uhr anzeigen", 20, -170, cfg.showClock ~= false, function(value)
                save("showClock", value)
            end)
            self:CreateCheckbox(content, "Ortsname anzeigen", 300, -170, cfg.showLocation ~= false, function(value)
                save("showLocation", value)
            end)
            self:CreateCheckbox(content, "Scrollen zum Zoomen", 20, -215, cfg.scrollZoom ~= false, function(value)
                save("scrollZoom", value)
            end)
            self:CreateDivider(content, 20, -270, 540)
            self:CreateHeader(content, "Indikatoren ausblenden", 20, -300)
            self:CreateCheckbox(content, "Tracking verstecken", 20, -345, cfg.hideTracking == true, function(value)
                save("hideTracking", value)
            end)
            self:CreateCheckbox(content, "Kalender verstecken", 300, -345, cfg.hideCalendar == true, function(value)
                save("hideCalendar", value)
            end)
            self:CreateCheckbox(content, "Post verstecken", 20, -390, cfg.hideMail == true, function(value)
                save("hideMail", value)
            end)
            content:SetHeight(490)

        else
            self:CreateCheckbox(content, "Datenleiste anzeigen", 20, -170, cfg.showDataBar ~= false, function(value)
                save("showDataBar", value)
            end)

            local dataTextOptions = {}
            local dataTextSystem = MM and MM.DataTexts
            if dataTextSystem and dataTextSystem.DataTextList then
                for _, name in ipairs(dataTextSystem.DataTextList) do
                    local provider = dataTextSystem.RegisteredDataTexts[name]
                    if provider then
                        table.insert(dataTextOptions, { value = name, label = provider.label or name })
                    end
                end
            end
            if #dataTextOptions == 0 then
                dataTextOptions = {
                    { value = "NONE", label = "Leer" },
                    { value = "TIME", label = "Uhrzeit" },
                    { value = "GOLD", label = "Gold" },
                    { value = "DURABILITY", label = "Haltbarkeit" },
                    { value = "SYSTEM", label = "FPS und Latenz" },
                    { value = "BAGS", label = "Freie Taschenplätze" },
                    { value = "GUILD", label = "Gilde" },
                    { value = "BNET", label = "Freunde" },
                    { value = "COORDINATES", label = "Koordinaten" },
                    { value = "LOCATION", label = "Gebiet" },
                }
            end

            self:CreateMenuDropdown(content, "Links", 20, -230, 170, dataTextOptions, cfg.dataTextLeft or "GUILD", function(value)
                save("dataTextLeft", value)
            end, "Bestimmt den linken Datentext unter der Minimap.")
            self:CreateMenuDropdown(content, "Mitte", 205, -230, 170, dataTextOptions, cfg.dataTextCenter or "SYSTEM", function(value)
                save("dataTextCenter", value)
            end, "Bestimmt den mittleren Datentext unter der Minimap.")
            self:CreateMenuDropdown(content, "Rechts", 390, -230, 170, dataTextOptions, cfg.dataTextRight or "BNET", function(value)
                save("dataTextRight", value)
            end, "Bestimmt den rechten Datentext unter der Minimap.")

            self:CreateCheckbox(content, "Hintergrund", 20, -295, cfg.dataBarBackdrop ~= false, function(value) save("dataBarBackdrop", value) end)
            self:CreateCheckbox(content, "Rahmen", 300, -295, cfg.dataBarBorder ~= false, function(value) save("dataBarBorder", value) end)

            cfg.dataBarBackgroundColor = cfg.dataBarBackgroundColor or { r = .10, g = .10, b = .10, a = 1 }
            cfg.dataBarBorderColor = cfg.dataBarBorderColor or { r = .15, g = .15, b = .15, a = 1 }
            cfg.dataBarTextColor = cfg.dataBarTextColor or { r = .92, g = .92, b = .92, a = 1 }
            if cfg.dataBarBackgroundAlpha == nil then cfg.dataBarBackgroundAlpha = cfg.dataBarPanelTransparency and .80 or 1 end
            if cfg.dataBarBorderAlpha == nil then cfg.dataBarBorderAlpha = .95 end
            if cfg.dataBarTextAlpha == nil then cfg.dataBarTextAlpha = 1 end

            self:CreateSlider(content, "Hintergrund-Transparenz", 20, -370, 0, 1, cfg.dataBarBackgroundAlpha, .05, function(value)
                save("dataBarBackgroundAlpha", value)
            end)
            self:CreateSlider(content, "Rahmen-Transparenz", 300, -370, 0, 1, cfg.dataBarBorderAlpha, .05, function(value)
                save("dataBarBorderAlpha", value)
            end)
            self:CreateSlider(content, "Text-Transparenz", 20, -455, 0, 1, cfg.dataBarTextAlpha, .05, function(value)
                save("dataBarTextAlpha", value)
            end)

            local function updateDataBarStyle()
                if MM and MM.Update then MM:Update() end
            end
            self:CreateColorPicker(content, "Hintergrundfarbe", 20, -535, cfg.dataBarBackgroundColor, updateDataBarStyle)
            self:CreateColorPicker(content, "Rahmenfarbe", 300, -535, cfg.dataBarBorderColor, updateDataBarStyle)
            self:CreateColorPicker(content, "Textfarbe", 20, -585, cfg.dataBarTextColor, updateDataBarStyle)
            content:SetHeight(670)
        end

        return
    end

    if category == "Schadensmeter" then
        profile.damageMeter = profile.damageMeter or {}
        local cfg, meter = profile.damageMeter, RexUI.DamageMeter
        local tabs={{"general","Allgemein"},{"appearance","Aussehen"}}
        local activeTab=self.DamageMeterSubTab or "general"
        for i,t in ipairs(tabs) do
            local id=t[1]
            local b=self:CreateButton(content,t[2],20+(i-1)*270,-82,260,28,function() self.DamageMeterSubTab=id; self:UpdateSettings("Schadensmeter") end)
            if id==activeTab then b:Disable(); b.Background:SetColorTexture(.34,.10,.45,1); b.Text:SetTextColor(RexUI:GetColor("highlight")); b.Border:SetAlpha(1) end
        end
        self:CreateDivider(content,20,-125,540)
        if activeTab=="general" then
            self:CreateCheckbox(content,"Schadensmeter aktivieren",20,-170,cfg.enabled~=false,function(v) cfg.enabled=v; if meter and meter.Apply then meter:Apply() end end)
            local count=meter and meter.GetWindowCount and meter:GetWindowCount() or (cfg.windowCount or 0)
            self:CreateHeader(content,"Fenster: "..tostring(count),20,-220)
            self:CreateButton(content,"Neues Fenster erstellen",20,-270,220,32,function() if meter and meter.AddWindow then meter:AddWindow(); ConfigUI:SetCategory("Schadensmeter") end end)
            self:CreateButton(content,"Fensterpositionen zurücksetzen",260,-270,250,32,function() if meter and meter.ResetLayout then meter:ResetLayout() end end)
            self:CreateDescription(content,"Im Fenster wählst du über das Zahnrad Schaden, DPS, Heilung, HPS und Kampfsegmente.",20,-330)
            content:SetHeight(420)
        else
            cfg.backgroundColor=cfg.backgroundColor or {r=.060,g=.055,b=.070,a=1}; cfg.headerColor=cfg.headerColor or {r=.018,g=.018,b=.022,a=1}; cfg.barColor=cfg.barColor or {r=.18,g=.48,b=.58,a=1}
            if cfg.backgroundAlpha==nil then cfg.backgroundAlpha=.55 end; if cfg.headerAlpha==nil then cfg.headerAlpha=.94 end; if cfg.barAlpha==nil then cfg.barAlpha=.78 end; if cfg.rowBackgroundAlpha==nil then cfg.rowBackgroundAlpha=.18 end; if cfg.rowHoverAlpha==nil then cfg.rowHoverAlpha=.12 end; if cfg.useClassColors==nil then cfg.useClassColors=true end
            local function applyStyle() if meter and meter.Apply then meter:Apply() end end
            self:CreateMenuDropdown(content,"Skin",20,-175,260,{{value="detailsDark",label="RexUI"},{value="rexGlass",label="RexUI Glas"},{value="rexCompact",label="RexUI Kompakt"},{value="reference",label="RexUI Klassisch"}},cfg.skinPreset or "detailsDark",function(v) if meter and meter.SetSkinPreset then meter:SetSkinPreset(v) end end)
            self:CreateSlider(content,"Fenster-Transparenz",20,-260,0,1,cfg.backgroundAlpha,.05,function(v) cfg.backgroundAlpha=v; applyStyle() end)
            self:CreateSlider(content,"Kopfzeilen-Transparenz",300,-260,0,1,cfg.headerAlpha,.05,function(v) cfg.headerAlpha=v; applyStyle() end)
            self:CreateSlider(content,"Datenbalken-Transparenz",20,-345,0,1,cfg.barAlpha,.05,function(v) cfg.barAlpha=v; applyStyle() end)
            self:CreateSlider(content,"Zeilenhintergrund",300,-345,0,1,cfg.rowBackgroundAlpha,.05,function(v) cfg.rowBackgroundAlpha=v; applyStyle() end)
            self:CreateSlider(content,"Mouseover-Transparenz",20,-430,0,.5,cfg.rowHoverAlpha,.02,function(v) cfg.rowHoverAlpha=v; applyStyle() end)
            self:CreateColorPicker(content,"Fensterfarbe",20,-510,cfg.backgroundColor,applyStyle); self:CreateColorPicker(content,"Kopfzeilenfarbe",300,-510,cfg.headerColor,applyStyle)
            self:CreateColorPicker(content,"Datenbalkenfarbe",20,-565,cfg.barColor,applyStyle); self:CreateCheckbox(content,"Klassenfarben für Datenbalken",300,-565,cfg.useClassColors~=false,function(v) cfg.useClassColors=v; applyStyle() end)
            content:SetHeight(650)
        end
        return
    end

    if category == "Chat" then
        profile.blizzardSkin=profile.blizzardSkin or {}; profile.blizzardSkin.chat=profile.blizzardSkin.chat or {}
        local chatCfg=profile.blizzardSkin.chat
        local function saveChat(k,v) chatCfg[k]=v; if RexUI.BlizzardSkin and RexUI.BlizzardSkin.Refresh then RexUI.BlizzardSkin:Refresh() end end
        local tabs={{"general","Allgemein"},{"appearance","Darstellung"},{"sidebar","Chat-Leiste"},{"sounds","Sounds"}}
        local activeTab=self.ChatSubTab or "general"
        local w,g=125,10
        for i,t in ipairs(tabs) do local id=t[1]; local b=self:CreateButton(content,t[2],20+(i-1)*(w+g),-82,w,28,function() self.ChatSubTab=id; self:UpdateSettings("Chat") end); if id==activeTab then b:Disable(); b.Background:SetColorTexture(.34,.10,.45,1); b.Text:SetTextColor(RexUI:GetColor("highlight")); b.Border:SetAlpha(1) end end
        self:CreateDivider(content,20,-125,540)
        if activeTab=="general" then
            self:CreateCheckbox(content,"Chat-Skin aktivieren",20,-170,chatCfg.enabled~=false,function(v) saveChat("enabled",v) end)
            self:CreateDropdown(content,"Zeitstempel",20,-230,240,{{value="none",label="Aus"},{value="%H:%M ",label="24 Stunden"},{value="%H:%M:%S ",label="24 Stunden mit Sekunden"},{value="%I:%M ",label="12 Stunden"},{value="blizzard",label="Blizzard-Einstellung"}},chatCfg.timestampFormat or "%H:%M ",function(v) saveChat("timestampFormat",v) end)
            self:CreateCheckbox(content,"Chat bei Inaktivität abdunkeln",20,-310,chatCfg.idleFade~=false,function(v) saveChat("idleFade",v) end)
            self:CreateSlider(content,"Wartezeit",20,-375,5,60,chatCfg.idleFadeDelay or 15,1,function(v) saveChat("idleFadeDelay",v) end)
            self:CreateSlider(content,"Abdunkelung",300,-375,0,90,chatCfg.idleFadeStrength or 40,5,function(v) saveChat("idleFadeStrength",v) end)
            content:SetHeight(470)
        elseif activeTab=="appearance" then
            self:CreateSlider(content,"Chat-Hintergrund",20,-175,0,1,chatCfg.bgAlpha or .70,.05,function(v) saveChat("bgAlpha",v) end); self:CreateSlider(content,"Texteingabe-Hintergrund",300,-175,0,1,chatCfg.ebAlpha or .50,.05,function(v) saveChat("ebAlpha",v) end)
            self:CreateSlider(content,"Chat-Tabs Hintergrund",20,-260,0,1,chatCfg.tabAlpha or .70,.05,function(v) saveChat("tabAlpha",v) end); self:CreateSlider(content,"Linke Chat-Leiste",300,-260,0,1,chatCfg.sidebarAlpha or .70,.05,function(v) saveChat("sidebarAlpha",v) end)
            self:CreateSlider(content,"Schriftgröße",20,-345,10,18,chatCfg.fontSize or 12,1,function(v) saveChat("fontSize",v) end); self:CreateSlider(content,"Zeilenabstand",300,-345,0,8,chatCfg.lineSpacing or 1,1,function(v) saveChat("lineSpacing",v) end)
            content:SetHeight(440)
        elseif activeTab=="sidebar" then
            self:CreateCheckbox(content,"Freundesliste",20,-175,chatCfg.showfriends~=false,function(v) saveChat("showfriends",v) end); self:CreateCheckbox(content,"Chat kopieren",300,-175,chatCfg.showcopy~=false,function(v) saveChat("showcopy",v) end)
            self:CreateCheckbox(content,"Ruhesteine",20,-220,chatCfg.showportals~=false,function(v) saveChat("showportals",v) end); self:CreateCheckbox(content,"Sprachchat",300,-220,chatCfg.showvoice~=false,function(v) saveChat("showvoice",v) end)
            self:CreateCheckbox(content,"RexUI-Einstellungen",20,-265,chatCfg.showsettings~=false,function(v) saveChat("showsettings",v) end); self:CreateCheckbox(content,"Zum neuesten Beitrag",300,-265,chatCfg.showscroll~=false,function(v) saveChat("showscroll",v) end)
            content:SetHeight(350)
        else
            local soundOptions={
                {value="none",label="Kein Sound"},
                {value="whisper",label="Whisper"},
                {value="alarm",label="Alarm"},
                {value="alert",label="Alert"},
                {value="info",label="Info"},
                {value="long",label="Long"},
                {value="spell_on_you",label="Spell on You"},
                {value="spell_under_you",label="Spell under You"},
            }
            -- Migrate the temporary generic sound choices from the previous build.
            local migrate={sound1="whisper",sound2="alert",sound3="alarm",sound4="long",sound5="info",sound6="spell_on_you",sound7="spell_under_you",rexwhisper="whisper"}
            chatCfg.guildSoundSelection=migrate[chatCfg.guildSoundSelection] or chatCfg.guildSoundSelection or (chatCfg.guildSound==false and "none" or "alert")
            chatCfg.whisperSoundSelection=migrate[chatCfg.whisperSoundSelection] or chatCfg.whisperSoundSelection or (chatCfg.whisperSound==false and "none" or "whisper")
            local soundFiles={alarm="Alarm.ogg",alert="Alert.ogg",info="Info.ogg",long="Long.ogg",spell_on_you="spell_on_you.ogg",spell_under_you="spell_under_you.ogg",whisper="Whisper.ogg"}
            local function testSound(value)
                local file=soundFiles[value]
                if file then PlaySoundFile("Interface\\AddOns\\RexUI\\media\\Sounds\\"..file,"Master") end
            end
            self:CreateMenuDropdown(content,"Gildennachrichten",20,-175,300,soundOptions,chatCfg.guildSoundSelection,function(v) saveChat("guildSoundSelection",v) end)
            self:CreateButton(content,"Testen",335,-175,100,30,function() testSound(chatCfg.guildSoundSelection) end)
            self:CreateMenuDropdown(content,"Whisper",20,-225,300,soundOptions,chatCfg.whisperSoundSelection,function(v) saveChat("whisperSoundSelection",v) end)
            self:CreateButton(content,"Testen",335,-225,100,30,function() testSound(chatCfg.whisperSoundSelection) end)
            self:CreateDescription(content,"Dropdown öffnen, Sound auswählen und direkt testen. Eigene Gildennachrichten lösen keinen Ton aus.",20,-285)
            content:SetHeight(360)
        end
        return
    end

    if category == "Profile" then

        local currentProfile = RexUI:GetCurrentProfile() or "Default"

        self:CreateDescription(
            content,
            "Profile speichern RexUI-Einstellungen pro Charakter. UI-Skalierung bleibt bei Blizzard.",
            20,
            -55
        )

        self:CreateDivider(content, 20, -90, 540)

        CreateInfoCard(content, "Aktives Profil", currentProfile, 20, -120, 260)

        self:CreateButton(content, "Aktuelles Profil exportieren", 310, -132, 190, 30, function()
            ConfigUI:SetCategory("Export")
        end)

        self:CreateDivider(content, 20, -195, 540)
        self:CreateHeader(content, "Neues Profil", 20, -225)

        local nameBox = CreateEditBox(content, 20, -260, 260, 28, false)
        nameBox:SetText("")

        self:CreateButton(content, "Als Vorlage sichern", 310, -260, 150, 30, function()
            local newProfileName = nameBox:GetText()
            local ok, message = RexUI:CreateProfile(newProfileName, true)
            if ok then
                RexUI:SetProfile(newProfileName)
                return
            end
            RexUI:PrintMessage(message or (ok and "Profil erstellt." or "Profil konnte nicht erstellt werden."))
            ConfigUI:UpdateSettings("Profile")
        end)

        local y = -390
        local profiles = {}
        for _, profileName in ipairs(RexUI:GetProfileList() or {}) do
            if profileName ~= "Default" then
                profiles[#profiles + 1] = profileName
            end
        end
        table.sort(profiles, function(a, b)
            if a == b then return false end
            if a == currentProfile then return true end
            if b == currentProfile then return false end
            return string.lower(a) < string.lower(b)
        end)

        self:CreateDivider(content, 20, -305, 540)
        self:CreateHeader(content, "Gespeicherte Profile", 20, -325)
        CreateLabel(content, "Profil", 32, -365)
        CreateLabel(content, "Status", 272, -365)
        CreateLabel(content, "Aktion", 417, -365)

        for _, profileName in ipairs(profiles) do
            local rowProfileName = profileName
            local isCurrent = rowProfileName == currentProfile
            local row = CreateFrame("Frame", nil, content, "BackdropTemplate")
            row:SetSize(540, 38)
            row:SetPoint("TOPLEFT", 20, y)
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            row:SetBackdropColor(isCurrent and 0.20 or 0.06, isCurrent and 0.04 or 0.02, isCurrent and 0.28 or 0.09, 0.88)
            row:SetBackdropBorderColor(isCurrent and 0.80 or 0.30, isCurrent and 0.22 or 0.08, isCurrent and 1.00 or 0.42, isCurrent and 0.95 or 0.65)

            local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            name:SetPoint("LEFT", 12, 0)
            name:SetWidth(205)
            name:SetJustifyH("LEFT")
            name:SetWordWrap(false)
            name:SetText(rowProfileName)
            name:SetTextColor(isCurrent and 0.95 or 0.86, isCurrent and 0.70 or 0.86, isCurrent and 1.00 or 0.92, 1)

            local activate = self:CreateButton(row, isCurrent and "Aktiv" or "Aktivieren", 225, -5, 125, 28, function()
                if rowProfileName ~= currentProfile then
                    RexUI:SetProfile(rowProfileName)
                end
            end)
            local remove = self:CreateButton(row, "Löschen", 385, -5, 125, 28, function()
                local ok, message = RexUI:DeleteProfile(rowProfileName)
                RexUI:PrintMessage(message or (ok and "Profil gelöscht." or "Profil konnte nicht gelöscht werden."))
                ConfigUI:UpdateSettings("Profile")
            end)
            if isCurrent then
                activate:Disable()
                remove:Disable()
            end

            y = y - 46
        end

        content:SetHeight(math.max(570, math.abs(y) + 30))

        return
    end

    if category == "Import" then

        local flow = CreateFlow(content, -55)

        flow:Description(
            "RexUI-Profilstring einfügen und importieren."
        )

        flow:Divider()
        flow:Label("Import")
        local importBox = flow:ProfileStringBox(540, 120)
        importBox:SetText("")

        flow:Button("Import", 120, 28, function()
            local ok, message = RexUI:ImportProfile(importBox:GetText())
            if not ok then
                RexUI:PrintMessage(message or "Import fehlgeschlagen.")
            end
        end)

        flow:Finish()

        return
    end

    if category == "Export" then

        local flow = CreateFlow(content, -55)

        flow:Description(
            "Exportiere das aktive Profil. UI-Skalierung wird nicht exportiert. Nach dem Export auf Markieren klicken und den String mit Strg+C kopieren."
        )

        flow:Divider()
        flow:Label("Export")
        local exportBox = flow:ProfileStringBox(540, 120)
        exportBox:SetText("")

        local buttonY = flow.y
        ConfigUI:CreateButton(content, "Export", 20, buttonY, 120, 28, function()
            local exportString, message = RexUI:ExportProfile()
            if exportString then
                exportBox:SetText(exportString)
                exportBox:SetFocus()
                exportBox:HighlightText()
            else
                RexUI:PrintMessage(message or "Export fehlgeschlagen.")
            end
        end)
        ConfigUI:CreateButton(content, "Markieren", 148, buttonY, 120, 28, function()
            exportBox:SetFocus()
            exportBox:HighlightText()
        end)
        flow:Advance(50)

        flow:Finish()

        return
    end

    if category == "Komfort" then
        profile.questTracker=profile.questTracker or {}; profile.comfort.realmOrigin=profile.comfort.realmOrigin or {}; local realmOrigin=profile.comfort.realmOrigin
        local function RefreshRealmOrigin() if RexUI.RealmOrigin and RexUI.RealmOrigin.Refresh then RexUI.RealmOrigin:Refresh() end end
        local tabs={{"general","Allgemein"},{"quests","Quests & Dialoge"},{"instances","Instanzen"},{"realm","Realm-Herkunft"},{"combat","Kampf-Tools"}}
        local activeTab=self.ComfortSubTab or "general"
        if activeTab == "integrations" then activeTab = "general"; self.ComfortSubTab = "general" end; local w,g=96,5
        for i,t in ipairs(tabs) do local id=t[1]; local b=self:CreateButton(content,t[2],20+(i-1)*(w+g),-82,w,28,function() self.ComfortSubTab=id; self:UpdateSettings("Komfort") end); if id==activeTab then b:Disable(); b.Background:SetColorTexture(.34,.10,.45,1); b.Text:SetTextColor(RexUI:GetColor("highlight")); b.Border:SetAlpha(1) end end
        if activeTab=="general" then
            self:CreateCheckbox(content,"Automatische Reparatur",20,-145,profile.comfort.autoRepair==true,function(v) profile.comfort.autoRepair=v end)
            self:CreateCheckbox(content,"Graue Gegenstände verkaufen",300,-145,profile.comfort.sellJunk==true,function(v) profile.comfort.sellJunk=v end)
            content:SetHeight(250)
        elseif activeTab=="combat" then
            profile.cooldownManager = profile.cooldownManager or { enabled = true, backdrop = true }
            local cdm = profile.cooldownManager
            self:CreateCheckbox(content,"Cooldown-Manager Skin",20,-145,cdm.enabled~=false,function(v) cdm.enabled=v; RexUI:SetModuleEnabled("CooldownManager", v) end)
            content:SetHeight(250)
        elseif activeTab=="quests" then
            self:CreateCheckbox(content,"Cinematics überspringen",20,-145,profile.comfort.skipCinematics==true,function(v) profile.comfort.skipCinematics=v end)
            self:CreateCheckbox(content,"Talking Head ausblenden",300,-145,profile.comfort.hideTalkingHead==true,function(v) profile.comfort.hideTalkingHead=v end)
            self:CreateCheckbox(content,"Quests automatisch annehmen",20,-190,profile.questTracker.autoAccept==true,function(v) profile.questTracker.autoAccept=v end)
            self:CreateCheckbox(content,"Quests automatisch abgeben",300,-190,profile.questTracker.autoTurnIn==true,function(v) profile.questTracker.autoTurnIn=v end)
            content:SetHeight(310)
        elseif activeTab=="instances" then
            self:CreateCheckbox(content,"Questtracker in Instanzen ausblenden",300,-145,profile.questTracker.autoHideInstance==true,function(v) profile.questTracker.autoHideInstance=v; local QT=RexUI.QuestTracker; if QT and QT.UpdateAutoHide then local otf=_G.ObjectiveTrackerFrame; if otf then otf:SetParent(UIParent) end; C_Timer.After(.1,QT.UpdateAutoHide) end end)
            self:CreateDropdown(content,"Kampflog",20,-220,240,{{value="OFF",label="Aus"},{value="RAID",label="Raid"}},profile.comfort.combatLogMode == "RAID" and "RAID" or "OFF",function(v) profile.comfort.combatLogMode=v; ConfigUI:UpdateSettings("Komfort") end)
            content:SetHeight(350)
        else
            self:CreateCheckbox(content,"Realm-Herkunft anzeigen",20,-145,realmOrigin.enabled~=false,function(v) realmOrigin.enabled=v; RefreshRealmOrigin() end)
            self:CreateCheckbox(content,"Bei Bewerbern",300,-145,realmOrigin.showApplicants~=false,function(v) realmOrigin.showApplicants=v; RefreshRealmOrigin() end)
            self:CreateCheckbox(content,"Bei Gruppenleitern",20,-190,realmOrigin.showLeaders~=false,function(v) realmOrigin.showLeaders=v; RefreshRealmOrigin() end)
            self:CreateCheckbox(content,"In Tooltips",300,-190,realmOrigin.showTooltips~=false,function(v) realmOrigin.showTooltips=v end)
            self:CreateCheckbox(content,"Bezeichnung im Tooltip",20,-235,realmOrigin.showNames~=false,function(v) realmOrigin.showNames=v end)
            self:CreateCheckbox(content,"Nur andere Realm-Sprache",300,-235,realmOrigin.onlyDifferent==true,function(v) realmOrigin.onlyDifferent=v; RefreshRealmOrigin() end)
            self:CreateDropdown(content,"Region",20,-310,240,{{value="AUTO",label="Automatisch"},{value="EU",label="Europa"},{value="US",label="Amerika / Ozeanien"}},realmOrigin.region or "AUTO",function(v) realmOrigin.region=v; RefreshRealmOrigin() end)
            content:SetHeight(420)
        end
        return
    end
end
