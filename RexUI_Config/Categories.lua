-- ============================================================
-- RexUI_Config – Categories.lua
-- Linke Kategorien der Konfiguration
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

local function T(text)
    return RexUI:LocalizeText(text)
end
-- ------------------------------------------------------------
-- LOKALE VARIABLEN
-- ------------------------------------------------------------

local MAIN_CATEGORIES = {
    { name = "Start", tabs = { "Start" } },
    { name = "Übersicht", tabs = { "Allgemein" } },
    { name = "Frames", tabs = { "UnitFrames", "Gruppenframes" } },
    { name = "Namensplaketten", tabs = { "Nameplates" } },
    { name = "Aktionsleisten & UI", tabs = { "Actionbars", "Minimap" } },
    { name = "Interface", tabs = { "Chat", "Taschen", "Schadensmeter", "Blizzard Skin" } },
    { name = "Komfort", tabs = { "Komfort" } },
    { name = "Profile", tabs = { "Profile", "Import", "Export" } },
}

local CATEGORY_GROUPS = {
    { label = "RexUI", categories = { "Start", "Übersicht", "Frames", "Namensplaketten", "Aktionsleisten & UI", "Interface", "Komfort", "Profile" } },
}

local MAIN_BY_NAME, MAIN_BY_CHILD = {}, {}
for _, entry in ipairs(MAIN_CATEGORIES) do
    MAIN_BY_NAME[entry.name] = entry
    for _, child in ipairs(entry.tabs) do MAIN_BY_CHILD[child] = entry.name end
end

local CATEGORIES = {}
for _, group in ipairs(CATEGORY_GROUPS) do
    for _, category in ipairs(group.categories) do
        CATEGORIES[#CATEGORIES + 1] = category
    end
end

local CATEGORY_SEARCH_KEYWORDS = {
    ["Übersicht"] = "allgemein layout wartung",
    ["Frames"] = "unitframes spieler ziel fokus begleiter boss gruppenframes party raid",
    ["Aktionsleisten & UI"] = "actionbars aktionsleisten micromenu minimap ui hud",
    ["Interface"] = "chat taschen bags schadensmeter damage meter blizzard skin",
    ["Profile"] = "profile profil import export",
    ["Gruppenframes"] = "gruppe party raid frames heiler tank buffs debuffs dispel hovercast clickcast aura",
    ["Start"] = "start dashboard status quick toggles schnellzugriff schnell wechseln",
    ["Allgemein"] = "layout unlock entsperren editmode wartung reset",
    ["Komfort"] = "repair reparatur junk verkaufen cinematic talking head quest kampflog",
    ["Actionbars"] = "leisten buttons mouseover größe abstand hotkeys cooldown xpbar ruf erfahrung statusleisten petbar",
    ["Taschen"] = "bags taschen inventory beutel position scale",
    ["Blizzard Skin"] = "skin tooltip popup menu lfg freunde chat",
    ["Minimap"] = "karte clock uhr ort tracking kalender mail queue zoom",
    ["UnitFrames"] = "unitframes spieler player ziel target fokus focus begleiter pet boss leben mana castbar portrait debuffs",
    ["Namensplaketten"] = "nameplates namensplaketten gegner freundlich target threat castbar auren buffs debuffs indikatoren filter",
    ["Schadensmeter"] = "schaden damage meter dps hps heilung overall segmente fenster",
    ["Chat"] = "chat tabs copy scroll hintergrund alpha",
    ["Profile"] = "profile profil vorlage kopieren aktivieren löschen",
    ["Import"] = "import string profil einfügen",
    ["Export"] = "export string teilen profil",
}

-- ------------------------------------------------------------
-- KATEGORIE PANEL
-- ------------------------------------------------------------

function ConfigUI:CreateCategoryPanel()

    local panel = CreateFrame("Frame", nil, self.Window)
    panel:SetWidth(210)
    panel:SetPoint("TOPLEFT", 15, -82)
    panel:SetPoint("BOTTOMLEFT", 15, 50)
    panel:SetClipsChildren(true)

    self.Window.CategoryPanel = panel
end

-- ------------------------------------------------------------
-- SUCHFELD
-- ------------------------------------------------------------

function ConfigUI:CreateCategorySearch(parent)

    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(180, 28)
    box:SetPoint("TOPLEFT", 15, -12)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontNormal")
    box:SetTextInsets(8, 8, 0, 0)
    box:EnableMouse(true)

    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    box:SetBackdropColor(0.06, 0.02, 0.09, 0.88)
    box:SetBackdropBorderColor(0.45, 0.12, 0.65, 0.75)
    box:SetTextColor(1, 1, 1, 1)

    box.Placeholder = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    box.Placeholder:SetPoint("LEFT", 8, 0)
    box.Placeholder:SetText(T("Suchen..."))
    box.Placeholder:SetTextColor(RexUI:GetColor("mutedText"))

    box:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        self.Placeholder:SetShown(text == "")

        if ConfigUI.FilterCategories then
            ConfigUI:FilterCategories(text)
        end
    end)

    box:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    self.CategorySearchBox = box
end

-- ------------------------------------------------------------
-- KATEGORIE BUTTON DESIGN
-- ------------------------------------------------------------

function ConfigUI:UpdateCategoryButton(button, active)

    if not button then return end

    if active then
        button.Background:SetColorTexture(0.10, 0.03, 0.14, 0.78)
        button.Background:SetAlpha(0.72)
        button.Text:SetTextColor(RexUI:GetColor("highlight"))
    else
        button.Background:SetColorTexture(0, 0, 0, 0)
        button.Background:SetAlpha(0)
        button.Text:SetTextColor(RexUI:GetColor("text"))
    end
end

-- ------------------------------------------------------------
-- KATEGORIE BUTTON ERSTELLUNG
-- ------------------------------------------------------------

function ConfigUI:CreateCategoryButton(parent, text, index)

    local button = CreateFrame("Button", nil, parent)
    button:SetSize(180, 30)
    button.CategoryName = text

    button.Background = button:CreateTexture(nil, "BACKGROUND")
    button.Background:SetAllPoints(button)
    button.Background:SetColorTexture(0, 0, 0, 0)

    button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.Text:SetPoint("LEFT", 10, 0)
    button.Text:SetText(T(text))
    button.Text:SetTextColor(RexUI:GetColor("text"))

    button:SetScript("OnEnter", function(self)
        if ConfigUI.CurrentCategory ~= text then
            self.Background:SetColorTexture(RexUI:GetColor("hover"))
            self.Background:SetAlpha(0.15)
        end
    end)

    button:SetScript("OnLeave", function(self)
        ConfigUI:UpdateCategoryButton(self, ConfigUI.CurrentCategory == text)
    end)

    button:SetScript("OnClick", function()
        ConfigUI:SetCategory(text)
    end)

    return button
end

-- ------------------------------------------------------------
-- KATEGORIEN ERSTELLEN
-- ------------------------------------------------------------

function ConfigUI:LayoutCategories()
    local child = self.CategoryScrollChild
    if not child then return end

    local y = 0

    for groupIndex, group in ipairs(CATEGORY_GROUPS) do
        local hasVisibleCategory = false
        for _, name in ipairs(group.categories) do
            local button = self.CategoryButtons and self.CategoryButtons[name]
            if button and button:IsShown() then
                hasVisibleCategory = true
                break
            end
        end

        local header = self.CategoryGroupHeaders and self.CategoryGroupHeaders[groupIndex]
        if header then
            header:SetShown(hasVisibleCategory)
        end

        if hasVisibleCategory then
            if header then
                header:ClearAllPoints()
                header:SetPoint("TOPLEFT", child, "TOPLEFT", 8, -y)
            end
            y = y + 22

            for _, name in ipairs(group.categories) do
                local button = self.CategoryButtons and self.CategoryButtons[name]
                if button and button:IsShown() then
                    button:ClearAllPoints()
                    button:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
                    y = y + 32
                end
            end

            y = y + 8
        end
    end

    local visibleHeight = self.CategoryScrollFrame and self.CategoryScrollFrame:GetHeight() or 1
    child:SetHeight(math.max(visibleHeight, y))
end

function ConfigUI:CreateCategories()

    self:CreateCategoryPanel()
    self:CreateCategorySearch(self.Window.CategoryPanel)

    local scrollFrame = CreateFrame("ScrollFrame", nil, self.Window.CategoryPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 15, -47)
    scrollFrame:SetPoint("BOTTOMRIGHT", -15, 30)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        local target = self:GetVerticalScroll() - (delta * 42)
        self:SetVerticalScroll(math.max(0, math.min(range, target)))
    end)

    local scrollBar = scrollFrame.ScrollBar or scrollFrame.Scrollbar
    if scrollBar then
        scrollBar:SetAlpha(0)
        scrollBar:EnableMouse(false)
        if scrollBar.ScrollUpButton then scrollBar.ScrollUpButton:Hide() end
        if scrollBar.ScrollDownButton then scrollBar.ScrollDownButton:Hide() end
        if scrollBar.ThumbTexture then scrollBar.ThumbTexture:SetAlpha(0) end
        if scrollBar.Track then scrollBar.Track:SetAlpha(0) end
    end

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(180, 1)
    scrollFrame:SetScrollChild(scrollChild)

    self.CategoryScrollFrame = scrollFrame
    self.CategoryScrollChild = scrollChild

    self.CategoryButtons = {}
    self.CategoryOrder = {}
    self.CategoryGroupHeaders = {}

    local categoryIndex = 0
    for groupIndex, group in ipairs(CATEGORY_GROUPS) do
        local header = CreateFrame("Frame", nil, scrollChild)
        header:SetSize(176, 22)

        header.Background = header:CreateTexture(nil, "BACKGROUND")
        header.Background:SetAllPoints()
        header.Background:SetColorTexture(0.22, 0.03, 0.31, 0.88)

        header.Text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header.Text:SetPoint("LEFT", 10, 0)
        header.Text:SetPoint("RIGHT", -6, 0)
        header.Text:SetJustifyH("LEFT")
        header.Text:SetText(T(group.label):upper())
        header.Text:SetTextColor(1, 1, 1, 0.92)

        self.CategoryGroupHeaders[groupIndex] = header

        for _, name in ipairs(group.categories) do
            categoryIndex = categoryIndex + 1
            local button = self:CreateCategoryButton(scrollChild, name, categoryIndex)
            self.CategoryButtons[name] = button
            self.CategoryOrder[categoryIndex] = name
        end
    end

    local result = self.Window.CategoryPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    result:SetPoint("BOTTOMLEFT", 18, 8)
    result:SetWidth(176)
    result:SetJustifyH("LEFT")
    result:SetTextColor(RexUI:GetColor("mutedText"))
    result:SetText("")
    self.CategorySearchResult = result

    self:LayoutCategories()
end

-- ------------------------------------------------------------
-- KATEGORIEN FILTERN
-- ------------------------------------------------------------

function ConfigUI:FilterCategories(query)

    query = string.lower(query or "")

    local firstMatch
    for _, name in ipairs(self.CategoryOrder or CATEGORIES) do
        local button = self.CategoryButtons and self.CategoryButtons[name]
        if button then
            local haystack = string.lower(name .. " " .. T(name) .. " " .. (CATEGORY_SEARCH_KEYWORDS[name] or ""))
            local visible = query == "" or string.find(haystack, query, 1, true) ~= nil

            button:SetShown(visible)

            if visible then
                firstMatch = firstMatch or name
            end
        end
    end

    self:LayoutCategories()

    if self.CategoryScrollFrame then
        self.CategoryScrollFrame:SetVerticalScroll(0)
    end

    if self.CategorySearchResult then
        if query == "" then
            self.CategorySearchResult:SetText("")
        elseif firstMatch then
            self.CategorySearchResult:SetText(T("Treffer: ") .. T(firstMatch))
        else
            self.CategorySearchResult:SetText(T("Kein Treffer"))
        end
    end
end

-- ------------------------------------------------------------
-- KATEGORIE SETZEN
-- ------------------------------------------------------------

function ConfigUI:CreateMainCategoryTabs(mainName, activeChild)
    local panel = self.Window and self.Window.SettingsPanel
    local entry = MAIN_BY_NAME[mainName]
    if not panel or not entry or #entry.tabs <= 1 then return end

    local holder = CreateFrame("Frame", nil, panel)
    holder:SetPoint("TOPLEFT", 10, -18)
    holder:SetPoint("TOPRIGHT", -10, -18)
    holder:SetHeight(34)
    holder:SetFrameLevel(panel:GetFrameLevel() + 20)
    panel.MainTabs = holder

    local count = #entry.tabs
    local gap = 6
    local width = math.max(90, ((panel:GetWidth() or 645) - 20 - gap * (count - 1)) / count)
    for i, child in ipairs(entry.tabs) do
        local tabName = child
        local btn = self:CreateButton(holder, T(tabName), (i - 1) * (width + gap), 0, width, 28, function()
            self.ActiveMainChild = self.ActiveMainChild or {}
            self.ActiveMainChild[mainName] = tabName
            self:SetCategory(tabName)
        end)
        btn:SetFrameLevel(holder:GetFrameLevel() + 1)
        local active = tabName == activeChild
        if btn.Background then
            if active then
                btn.Background:SetColorTexture(0.42, 0.08, 0.55, 0.95)
                btn.Background:SetAlpha(1)
            else
                btn.Background:SetColorTexture(0.10, 0.03, 0.14, 0.78)
                btn.Background:SetAlpha(0.72)
            end
        end
        if btn.Text then btn.Text:SetTextColor(active and 1 or 0.88, active and 0.72 or 0.88, 1, 1) end
    end
end

function ConfigUI:SetCategory(name)
    local mainName = MAIN_BY_NAME[name] and name or MAIN_BY_CHILD[name] or name
    local entry = MAIN_BY_NAME[mainName]
    local child = name
    if entry then
        self.ActiveMainChild = self.ActiveMainChild or {}
        if MAIN_BY_CHILD[name] == mainName then self.ActiveMainChild[mainName] = name end
        child = self.ActiveMainChild[mainName] or entry.tabs[1]
        self.ActiveMainChild[mainName] = child
    end

    self.CurrentCategory = mainName
    self.CurrentSettingsCategory = child
    self.ActiveMainCategory = entry and mainName or nil

    if self.CategoryButtons then
        for categoryName, button in pairs(self.CategoryButtons) do
            self:UpdateCategoryButton(button, categoryName == mainName)
        end
    end

    if self.UpdateSettings then self:UpdateSettings(child) end
    if entry then self:CreateMainCategoryTabs(mainName, child) end
end
