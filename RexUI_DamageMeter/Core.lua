-- RexUI Damage Meter - Details-style windows using the protected WoW 12 API
local _, ns = ...
local RexUI = ns.RexUI
if not RexUI then return end

local DM = RexUI:CreateModule("DamageMeter")
local Perf = RexUI.Perf
RexUI.DamageMeter = DM

local function T(text)
    return RexUI:LocalizeText(text)
end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\FRIZQT__.TTF"
local REX_MEDIA = "Interface\\AddOns\\RexUI\\media\\"
local MAX_ROWS = 30
local MAX_BREAKDOWN_ROWS = 14

local SKIN_PRESETS = {
    reference = {
        backgroundColor = { r = .060, g = .055, b = .070, a = 1 }, backgroundAlpha = .55,
        headerColor = { r = .018, g = .018, b = .022, a = 1 }, headerAlpha = .94,
        barAlpha = .78, rowBackgroundAlpha = .18, rowHoverAlpha = .12,
        rowHeight = 19, rowSpacing = 0, rowFontSize = 10,
        rowFont = REX_MEDIA .. "fonts\\Barlow Condensed.ttf",
        barTexture = REX_MEDIA .. "statusbars\\bar_serenity.tga",
    },
    detailsDark = {
        backgroundColor = { r = .0941, g = .0941, b = .0941, a = 1 }, backgroundAlpha = .42,
        headerColor = { r = .025, g = .025, b = .030, a = 1 }, headerAlpha = .96,
        barAlpha = .88, rowBackgroundAlpha = .32, rowHoverAlpha = .16,
        rowHeight = 21, rowSpacing = 1, rowFontSize = 11,
        rowFont = REX_MEDIA .. "fonts\\Arial Narrow.ttf",
        barTexture = REX_MEDIA .. "statusbars\\bar_background.tga",
    },
    rexGlass = {
        backgroundColor = { r = .025, g = .035, b = .045, a = 1 }, backgroundAlpha = .30,
        headerColor = { r = .020, g = .055, b = .070, a = 1 }, headerAlpha = .78,
        barAlpha = .68, rowBackgroundAlpha = .12, rowHoverAlpha = .18,
        rowHeight = 20, rowSpacing = 1, rowFontSize = 10,
        rowFont = REX_MEDIA .. "fonts\\Barlow Condensed.ttf",
        barTexture = REX_MEDIA .. "statusbars\\bar_serenity.tga",
    },
    rexCompact = {
        backgroundColor = { r = .035, g = .032, b = .040, a = 1 }, backgroundAlpha = .72,
        headerColor = { r = .018, g = .018, b = .022, a = 1 }, headerAlpha = .98,
        barAlpha = .86, rowBackgroundAlpha = .20, rowHoverAlpha = .14,
        rowHeight = 16, rowSpacing = 0, rowFontSize = 9,
        rowFont = REX_MEDIA .. "fonts\\Arial Narrow.ttf",
        barTexture = REX_MEDIA .. "statusbars\\bar4.tga",
    },
}

local function MeterEnum(name, fallback)
    return Enum and Enum.DamageMeterType and Enum.DamageMeterType[name] or fallback
end

local DISPLAY_CATEGORIES = {
    damage = {
        { id = MeterEnum("DamageDone", 0), label = "Verursachter Schaden", column = "Schaden" },
        { id = MeterEnum("Dps", 1), label = "DPS", column = "DPS", metric = "rate" },
        { id = MeterEnum("DamageTaken", 7), label = "Erlittener Schaden", column = "Schaden" },
        { id = MeterEnum("AvoidableDamageTaken", 8), label = "Vermeidbarer Schaden", column = "Schaden" },
        { id = MeterEnum("EnemyDamageTaken", 10), label = "Gegner erlittener Schaden", column = "Schaden" },
    },
    healing = {
        { id = MeterEnum("HealingDone", 2), label = "Gewirkte Heilung", column = "Heilung" },
        { id = MeterEnum("Hps", 3), label = "HPS", column = "HPS", metric = "rate" },
        { id = MeterEnum("Absorbs", 4), label = "Absorbierte Heilung", column = "Absorb" },
    },
    utility = {
        { id = MeterEnum("Interrupts", 5), label = "Unterbrechungen", column = "Anzahl" },
        { id = MeterEnum("Dispels", 6), label = "Bannungen", column = "Anzahl" },
        { id = MeterEnum("Deaths", 9), label = "Tode", column = "Anzahl" },
    },
}

local DISPLAY_BY_ID = {}
for _, category in pairs(DISPLAY_CATEGORIES) do
    for _, display in ipairs(category) do DISPLAY_BY_ID[display.id] = display end
end

local WINDOW_DEFAULTS = {
    [1] = { enabled = true, width = 280, height = 210, display = MeterEnum("DamageDone", 0), session = "current", locked = true, point = "RIGHT", relPoint = "RIGHT", x = -25, y = -40 },
    [2] = { enabled = false, width = 280, height = 210, display = MeterEnum("HealingDone", 2), session = "current", locked = true, point = "RIGHT", relPoint = "RIGHT", x = -315, y = -40 },
}

local function WindowDefaults(index)
    if WINDOW_DEFAULTS[index] then return WINDOW_DEFAULTS[index] end
    local offset = ((index - 1) % 8) * 24
    return {
        enabled = true, width = 280, height = 210,
        display = MeterEnum("DamageDone", 0), session = "current", locked = true,
        lockControlsVersion = 2, point = "CENTER", relPoint = "CENTER", x = offset, y = -offset,
    }
end

local function Config()
    local p = RexUI:GetProfile()
    return p and p.damageMeter or {}
end

local function CopyMissing(defaults, target)
    target = type(target) == "table" and target or {}
    for key, value in pairs(defaults) do if target[key] == nil then target[key] = value end end
    return target
end

function DM:GetWindowConfig(index)
    local cfg = Config()
    cfg.windows = type(cfg.windows) == "table" and cfg.windows or {}
    cfg.windows[index] = CopyMissing(WindowDefaults(index), cfg.windows[index])
    local windowCfg = cfg.windows[index]

    if not cfg._referenceStyleV1 then
        cfg.backgroundColor = { r = .060, g = .055, b = .070, a = 1 }
        cfg.backgroundAlpha = .55
        cfg.headerColor = { r = .018, g = .018, b = .022, a = 1 }
        cfg.headerAlpha = .94
        cfg.barColor = { r = .18, g = .48, b = .58, a = 1 }
        cfg.barAlpha = .78
        cfg.rowBackgroundAlpha = .18
        cfg._referenceStyleV1 = true
    end
    if not cfg._rexUIDarkSkinV2 then
        local preset = SKIN_PRESETS.detailsDark
        for key, value in pairs(preset) do
            if type(value) == "table" then
                cfg[key] = { r = value.r, g = value.g, b = value.b, a = value.a }
            else
                cfg[key] = value
            end
        end
        cfg.skinPreset = "detailsDark"
        cfg._rexUIDarkSkinV2 = true
    end
    if not cfg._rexUIReferenceSkinV4 then
        local preset = SKIN_PRESETS.reference
        for key, value in pairs(preset) do
            if type(value) == "table" then
                cfg[key] = { r = value.r, g = value.g, b = value.b, a = value.a }
            else
                cfg[key] = value
            end
        end
        cfg.skinPreset = "reference"
        cfg._rexUIReferenceSkinV4 = true
    end
    if not cfg._rexUIDefaultSkinV5 then
        local preset = SKIN_PRESETS.detailsDark
        for key, value in pairs(preset) do
            if type(value) == "table" then
                cfg[key] = { r = value.r, g = value.g, b = value.b, a = value.a }
            else
                cfg[key] = value
            end
        end
        cfg.skinPreset = "detailsDark"
        cfg._rexUIDefaultSkinV5 = true
    end

    if windowCfg.display == nil then
        windowCfg.display = windowCfg.mode == "healing" and MeterEnum("HealingDone", 2) or MeterEnum("DamageDone", 0)
    end
    if windowCfg.lockControlsVersion ~= 2 then
        windowCfg.locked = true
        windowCfg.lockControlsVersion = 2
    end
    if index == 1 and not cfg._detailsStyleMigrated then
        for _, key in ipairs({ "width", "height", "session", "point", "relPoint", "x", "y" }) do
            if cfg[key] ~= nil then windowCfg[key] = cfg[key] end
        end
        cfg._detailsStyleMigrated = true
    end
    return windowCfg
end

local function IsPlainNumber(value)
    return type(value) == "number" and not (issecretvalue and issecretvalue(value))
end

local function DisplayNumber(value)
    if value == nil then return "" end
    if AbbreviateLargeNumbers then return AbbreviateLargeNumbers(value) end
    if AbbreviateNumbers then return AbbreviateNumbers(value) end
    if not IsPlainNumber(value) then return value end
    if value >= 1000000000 then return string.format("%.1fB", value / 1000000000) end
    if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
    if value >= 1000 then return string.format("%.1fK", value / 1000) end
    return tostring(math.floor(value + 0.5))
end

local function FormatDuration(seconds)
    if not IsPlainNumber(seconds) or seconds <= 0 then return "" end
    return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

local function GetSessionDuration(windowCfg)
    if windowCfg.sessionID and C_DamageMeter and C_DamageMeter.GetAvailableCombatSessions then
        local ok, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
        if ok and type(sessions) == "table" then
            for _, session in ipairs(sessions) do
                if session.sessionID == windowCfg.sessionID and IsPlainNumber(session.durationSeconds) then
                    return session.durationSeconds
                end
            end
        end
        return nil
    end

    if C_DamageMeter and C_DamageMeter.GetSessionDurationSeconds then
        local sessionType = windowCfg.session == "overall"
            and (Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Overall or 0)
            or (Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current or 1)
        local ok, duration = pcall(C_DamageMeter.GetSessionDurationSeconds, sessionType)
        if ok and IsPlainNumber(duration) then return duration end
    end
    return nil
end

local function MeterColor(key, fallback)
    local color = Config()[key]
    return type(color) == "table" and color or fallback
end

function DM:ApplyVisualStyle(window)
    if not window then return end
    local cfg = Config()
    local background = MeterColor("backgroundColor", { r = .060, g = .055, b = .070 })
    local header = MeterColor("headerColor", { r = .018, g = .018, b = .022 })
    local backgroundAlpha = tonumber(cfg.backgroundAlpha) or .55
    local headerAlpha = tonumber(cfg.headerAlpha) or .94
    local rowAlpha = tonumber(cfg.rowBackgroundAlpha) or .18
    local hoverAlpha = tonumber(cfg.rowHoverAlpha) or .12
    local font = cfg.rowFont or SKIN_PRESETS.reference.rowFont
    local fontSize = tonumber(cfg.rowFontSize) or 10
    local barTexture = cfg.barTexture or SKIN_PRESETS.reference.barTexture

    window:SetBackdropColor(background.r or .060, background.g or .055, background.b or .070, backgroundAlpha)
    if window.headerBackground then
        window.headerBackground:SetColorTexture(header.r or .018, header.g or .018, header.b or .022, headerAlpha)
    end
    for _, row in ipairs(window.rows or {}) do
        if row.bg then row.bg:SetColorTexture(background.r or .060, background.g or .055, background.b or .070, rowAlpha) end
        if row.bar then row.bar:SetStatusBarTexture(barTexture) end
        if row.highlight then row.highlight:SetColorTexture(1, 1, 1, hoverAlpha) end
        if row.rank then row.rank:SetFont(font, fontSize, "OUTLINE") end
        if row.name then row.name:SetFont(font, fontSize, "OUTLINE") end
        if row.value then row.value:SetFont(font, fontSize, "OUTLINE") end
    end
    local panel = window.breakdown
    if panel then
        panel:SetBackdropColor(background.r or .060, background.g or .055, background.b or .070, math.min(1, backgroundAlpha + .20))
        panel:SetBackdropBorderColor(.22, .22, .25, 1)
        panel.headerBackground:SetColorTexture(header.r or .018, header.g or .018, header.b or .022, headerAlpha)
        panel.headerLine:SetColorTexture(.22, .22, .25, 1)
        for _, row in ipairs(panel.rows or {}) do
            row.bar:SetStatusBarTexture(barTexture)
            local barColor = MeterColor("barColor", { r = .18, g = .48, b = .58 })
            row.bar:SetStatusBarColor(barColor.r or .18, barColor.g or .48, barColor.b or .58, tonumber(cfg.barAlpha) or .78)
            if row.bg then row.bg:SetColorTexture(background.r or .060, background.g or .055, background.b or .070, rowAlpha) end
            row.name:SetFont(font, math.max(9, fontSize - 1), "OUTLINE")
            row.value:SetFont(font, math.max(9, fontSize - 1), "OUTLINE")
            row.rate:SetFont(font, math.max(9, fontSize - 1), "OUTLINE")
        end
    end
end

function DM:SetSkinPreset(name)
    local preset = SKIN_PRESETS[name]
    if not preset then return end
    local cfg = Config()
    cfg.skinPreset = name
    for key, value in pairs(preset) do
        if type(value) == "table" then
            cfg[key] = { r = value.r, g = value.g, b = value.b, a = value.a }
        else
            cfg[key] = value
        end
    end
    self:Apply()
end

local function CurrentSessionType(windowCfg)
    if windowCfg.session == "overall" then
        return Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Overall or 0
    end
    return Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current or 1
end

function DM:GetSession(windowCfg)
    if not C_DamageMeter then return nil end
    local ok, session
    if windowCfg.sessionID and C_DamageMeter.GetCombatSessionFromID then
        ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, windowCfg.sessionID, windowCfg.display)
    elseif C_DamageMeter.GetCombatSessionFromType then
        ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, CurrentSessionType(windowCfg), windowCfg.display)
    end
    return ok and session or nil
end

function DM:GetSourceBreakdown(windowCfg, source)
    if not C_DamageMeter or not source then return nil end
    local ok, result
    if windowCfg.sessionID and C_DamageMeter.GetCombatSessionSourceFromID then
        ok, result = pcall(C_DamageMeter.GetCombatSessionSourceFromID, windowCfg.sessionID, windowCfg.display, source.sourceGUID, source.sourceCreatureID)
    elseif C_DamageMeter.GetCombatSessionSourceFromType then
        ok, result = pcall(C_DamageMeter.GetCombatSessionSourceFromType, CurrentSessionType(windowCfg), windowCfg.display, source.sourceGUID, source.sourceCreatureID)
    end
    return ok and result or nil
end

function DM:RefreshWindow(window)
    if not window then return end
    local rootCfg = Config()
    local windowCfg = self:GetWindowConfig(window.index)
    local visible = rootCfg.enabled ~= false and windowCfg.enabled ~= false
    window:SetShown(visible)
    if not visible then return end

    local session = self:GetSession(windowCfg)
    local list = session and session.combatSources or {}
    local display = DISPLAY_BY_ID[windowCfg.display] or { label = "Schaden", column = "Schaden" }
    local useRate = display.metric == "rate"
    -- WoW 12 markiert Damage-Meter-Werte im Kampf als geheim. Die von der
    -- Sitzung vorberechneten Werte dürfen direkt an UI-Elemente übergeben
    -- werden; eigene Vergleiche oder Additionen würden falsche Ergebnisse
    -- erzeugen bzw. die geschützten Werte verwerfen.
    local maxValue = session and session.maxAmount or 1
    local selectedTotal = session and session.totalAmount or 0
    if IsPlainNumber(maxValue) and maxValue <= 0 then
        maxValue = 1
    end

    local segmentLabel = windowCfg.sessionID and (windowCfg.sessionName or "Segment") or (windowCfg.session == "overall" and "Overall" or "Aktueller Kampf")
    window.title:SetText(T(display.label))
    local duration = FormatDuration(GetSessionDuration(windowCfg))
    window.segment:SetText(T(segmentLabel) .. (duration ~= "" and ("  •  " .. duration) or ""))
    self:UpdateWindowLockVisual(window)

    local meterCfg = Config()
    local rowHeight = tonumber(meterCfg.rowHeight) or 19
    local rowSpacing = tonumber(meterCfg.rowSpacing) or 0
    local shownRows = math.min(MAX_ROWS, math.max(3, math.floor((window:GetHeight() - 44) / (rowHeight + rowSpacing))))
    local maxOffset = math.max(0, #list - shownRows)
    window.offset = math.min(window.offset or 0, maxOffset)
    window.total:SetText("")
    for i, row in ipairs(window.rows) do
        local source = list[i + window.offset]
        row:SetShown(i <= shownRows and source ~= nil)
        row.source = source
        if source and i <= shownRows then
            row.bar:SetMinMaxValues(0, maxValue)
            row.bar:SetValue(source.totalAmount)
            row.name:SetText(source.name)
            row.value:SetText(DisplayNumber(useRate and source.amountPerSecond or source.totalAmount))
            row.rank:SetText(i + window.offset)

            -- The native damage-meter source already gives us the stable class
            -- filename (PALADIN, SHAMAN, ...).  Use Blizzard's individual class
            -- atlas and keep it independent from the StatusBar. Atlas names use
            -- lower-case class tokens.
            local specIconID = source.specIconID
            local classFilename = source.classFilename

            if classFilename and classFilename ~= "" then
                row.icon:SetTexture(nil)
                row.icon:SetTexCoord(0, 1, 0, 1)
                local atlas = "classicon-" .. string.lower(classFilename)
                local atlasExists = not C_Texture or not C_Texture.GetAtlasExists or C_Texture.GetAtlasExists(atlas)
                if atlasExists then
                    row.icon:SetAtlas(atlas, false)
                    row.icon:SetVertexColor(1, 1, 1, 1)
                    row.icon:Show()
                elseif specIconID and specIconID ~= 0 then
                    row.icon:SetAtlas(nil)
                    row.icon:SetTexture(specIconID)
                    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    row.icon:SetVertexColor(1, 1, 1, 1)
                    row.icon:Show()
                else
                    row.icon:SetAtlas(nil)
                    row.icon:SetTexture(nil)
                    row.icon:Hide()
                end
            elseif specIconID and specIconID ~= 0 then
                row.icon:SetAtlas(nil)
                row.icon:SetTexture(specIconID)
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.icon:SetVertexColor(1, 1, 1, 1)
                row.icon:Show()
            else
                row.icon:SetAtlas(nil)
                row.icon:SetTexture(nil)
                row.icon:Hide()
            end
            local meterCfg = Config()
            local alpha = tonumber(meterCfg.barAlpha) or .78
            local c = meterCfg.useClassColors ~= false and source.classFilename and RAID_CLASS_COLORS and RAID_CLASS_COLORS[source.classFilename]
            if c then
                row.bar:SetStatusBarColor(c.r * .90, c.g * .90, c.b * .90, alpha)
            else
                local color = MeterColor("barColor", { r = .18, g = .48, b = .58 })
                row.bar:SetStatusBarColor(color.r or .18, color.g or .48, color.b or .58, alpha)
            end
        end
    end
end

function DM:Refresh()
    local perfStart = Perf and Perf:Start()
    for _, window in ipairs(self.windows or {}) do self:RefreshWindow(window) end
    if Perf then Perf:Stop("DamageMeter", perfStart, "fullUpdates") end
end

function DM:SaveWindow(window)
    if not window then return end
    local cfg = self:GetWindowConfig(window.index)
    local point, _, relPoint, x, y = window:GetPoint(1)
    cfg.point, cfg.relPoint, cfg.x, cfg.y = point, relPoint, x, y
    cfg.width, cfg.height = math.floor(window:GetWidth() + 0.5), math.floor(window:GetHeight() + 0.5)
end

function DM:LayoutWindow(window)
    if not window then return end
    local cfg = Config()
    local rowHeight = tonumber(cfg.rowHeight) or 19
    local rowSpacing = tonumber(cfg.rowSpacing) or 0
    local stride = rowHeight + rowSpacing
    for i, row in ipairs(window.rows) do
        row:SetHeight(rowHeight)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 2, -26 - ((i - 1) * stride))
        row:SetPoint("RIGHT", -2, 0)
    end
end

function DM:SetSecondWindowEnabled(enabled)
    self:SetWindowEnabled(2, enabled)
end

function DM:GetWindowCount()
    local cfg = Config()
    if IsPlainNumber(cfg.windowCount) then return math.max(0, math.floor(cfg.windowCount)) end
    local windows, highest = cfg.windows or {}, 0
    for index in pairs(windows) do if type(index) == "number" and index > highest then highest = index end end
    cfg.windowCount = highest
    return highest
end

function DM:SetWindowEnabled(index, enabled)
    self:GetWindowConfig(index).enabled = enabled == true
    self:EnsureWindows(); self:Apply()
end

function DM:AddWindow()
    local index = self:GetWindowCount() + 1
    Config().windowCount = index
    local cfg = self:GetWindowConfig(index)
    cfg.enabled, cfg.locked = true, true
    self:EnsureWindows(); self:Apply()
    return index
end

function DM:DeleteWindow(index)
    local rootCfg = Config()
    rootCfg.windows = type(rootCfg.windows) == "table" and rootCfg.windows or {}
    local count = self:GetWindowCount()
    if type(index) ~= "number" or index < 1 or index > count then return end

    local removed = self.windows and self.windows[index]
    if removed then
        if removed.menu then removed.menu:Hide() end
        if removed.submenu then removed.submenu:Hide() end
        if removed.breakdown then removed.breakdown:Hide() end
        removed:Hide()
    end

    table.remove(rootCfg.windows, index)
    rootCfg.windowCount = count - 1
    if self.windows then
        table.remove(self.windows, index)
        for newIndex, window in ipairs(self.windows) do window.index = newIndex end
        self.frame = self.windows[1]
    end
    self:Apply()
end

function DM:EnsureWindows()
    if not self.windows then return end
    local count = self:GetWindowCount()
    for index = #self.windows + 1, count do self.windows[index] = self:CreateWindow(index) end
end

function DM:ResetLayout()
    for i = 1, self:GetWindowCount() do
        local cfg = self:GetWindowConfig(i)
        for key, value in pairs(WindowDefaults(i)) do cfg[key] = value end
        cfg.sessionID = nil
    end
    self:Apply()
end

function DM:Apply()
    if not self.windows then return end
    if self.enabled == false or Config().enabled == false then
        self:StopUpdater()
        for _, window in ipairs(self.windows) do window:Hide() end
        return
    end
    self:StartUpdater()
    self:EnsureWindows()
    for _, window in ipairs(self.windows) do
        local cfg = self:GetWindowConfig(window.index)
        window:ClearAllPoints()
        window:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)
        window:SetSize(cfg.width, cfg.height)
        self:ApplyVisualStyle(window)
        self:SaveWindow(window)
        self:LayoutWindow(window)
    end
    self:Refresh()
end

function DM:ShowMover()
    for _, window in ipairs(self.windows or {}) do if self:GetWindowConfig(window.index).enabled ~= false then window:Show() end end
end

function DM:HideMover()
    for _, window in ipairs(self.windows or {}) do self:SaveWindow(window) end
    self:Apply()
end

local function CreateSmallButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 20, 18)
    button:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    button:SetBackdropColor(0.08, 0.08, 0.09, 0.98)
    button:SetBackdropBorderColor(0.30, 0.30, 0.34, 1)
    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text:SetFont(FONT, 9, "OUTLINE")
    button.text:SetPoint("CENTER")
    button.text:SetText(T(text))
    button:SetScript("OnEnter", function(self) self:SetBackdropColor(0.30, 0.12, 0.42, 1) end)
    button:SetScript("OnLeave", function(self) self:SetBackdropColor(0.08, 0.08, 0.09, 0.98) end)
    return button
end

local function CreateOptionsButton(parent, tooltip)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(14, 14)
    button:SetBackdrop({bgFile=WHITE}); button:SetBackdropColor(.055,.055,.06,0)
    button.lines = {}
    for i = 1, 3 do
        local line = button:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(.72,.72,.76,1); line:SetSize(8,1); line:SetPoint("TOPLEFT",3,-3-((i-1)*4))
        local knob = button:CreateTexture(nil, "OVERLAY")
        knob:SetColorTexture(.92,.92,.95,1); knob:SetSize(2,3); knob:SetPoint("CENTER",line,"LEFT",i==2 and 6 or 2,0)
        button.lines[#button.lines+1],button.lines[#button.lines+2]=line,knob
    end
    if tooltip then
        button:SetScript("OnEnter", function(self) self:SetBackdropColor(.18,.18,.21,.9); GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(T(tooltip)); GameTooltip:Show() end)
        button:SetScript("OnLeave", function(self) self:SetBackdropColor(.055,.055,.06,0); GameTooltip:Hide() end)
    end
    return button
end

function DM:UpdateWindowLockVisual(window)
    if not window or not window.lockButton then return end
    local locked = self:GetWindowConfig(window.index).locked == true
    local color = locked and .42 or .66
    local green = locked and .42 or .58
    local blue = locked and .45 or .70
    for _, part in ipairs(window.lockButton.parts or {}) do
        part:SetColorTexture(color, green, blue, locked and .62 or .78)
    end
    if window.lockButton.shackleRight then
        window.lockButton.shackleRight:SetShown(locked)
    end
    window.leftResize:SetShown(not locked)
    window.rightResize:SetShown(not locked)
    if window.dragHint then window.dragHint:SetShown(not locked) end
    if window.segment then window.segment:SetShown(locked) end
    if window.headerLine then window.headerLine:SetColorTexture(locked and .22 or .55, locked and .22 or .65, locked and .25 or .75, 1) end
    window:SetBackdropBorderColor(locked and .22 or .55, locked and .22 or .65, locked and .25 or .75, 1)
end

function DM:ToggleWindowLock(window)
    local cfg = self:GetWindowConfig(window.index)
    cfg.locked = not cfg.locked
    if cfg.locked then self:SaveWindow(window) end
    self:UpdateWindowLockVisual(window)
end

local function CreateMenuButton(parent, text, y, callback, arrow)
    local button = CreateFrame("Button", nil, parent)
    button:SetPoint("TOPLEFT", 4, y)
    button:SetPoint("TOPRIGHT", -4, y)
    button:SetHeight(22)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0)
    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, 10, "OUTLINE"); label:SetPoint("LEFT", 7, 0); label:SetText(T(text)); label:SetTextColor(0.95, 0.76, 0.20)
    if arrow then
        local marker = button:CreateFontString(nil, "OVERLAY")
        marker:SetFont(FONT, 10, "OUTLINE"); marker:SetPoint("RIGHT", -6, 0); marker:SetText(">")
    end
    button:SetScript("OnEnter", function() bg:SetColorTexture(0.40, 0.30, 0.02, 0.72) end)
    button:SetScript("OnLeave", function() bg:SetColorTexture(0, 0, 0, 0) end)
    button:SetScript("OnClick", callback)
    return button
end

function DM:CloseMenus(window)
    window.menu:Hide()
    window.submenu:Hide()
end

function DM:PopulateSubmenu(window, items)
    for _, button in ipairs(window.submenu.buttons) do button:Hide() end
    window.submenu.buttons = {}
    local height = math.max(30, (#items * 23) + 8)
    window.submenu:SetHeight(height)
    for i, item in ipairs(items) do
        local selected = item
        local button = CreateMenuButton(window.submenu, selected.label, -4 - ((i - 1) * 23), function()
            selected.callback()
            DM:CloseMenus(window)
            DM:RefreshWindow(window)
        end)
        window.submenu.buttons[#window.submenu.buttons + 1] = button
    end
    window.submenu:Show()
end

function DM:ShowDisplayCategory(window, category)
    local items = {}
    for _, display in ipairs(DISPLAY_CATEGORIES[category] or {}) do
        local displayID, displayLabel = display.id, display.label
        items[#items + 1] = { label = displayLabel, callback = function()
            local cfg = self:GetWindowConfig(window.index)
            cfg.display = displayID
        end }
    end
    self:PopulateSubmenu(window, items)
end

function DM:ShowSegmentMenu(window)
    local items = {
        { label = "Aktueller Kampf", callback = function() local c = self:GetWindowConfig(window.index); c.session = "current"; c.sessionID = nil; c.sessionName = nil end },
        { label = "Overall", callback = function() local c = self:GetWindowConfig(window.index); c.session = "overall"; c.sessionID = nil; c.sessionName = nil end },
    }
    if C_DamageMeter and C_DamageMeter.GetAvailableCombatSessions then
        local ok, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
        if ok and type(sessions) == "table" then
            local added = 0
            for i = #sessions, 1, -1 do
                local session = sessions[i]
                if session and session.sessionID and added < 8 then
                    added = added + 1
                    local sessionID = session.sessionID
                    local sessionName = session.name or (RexUI:LocalizeText("Kampf ") .. tostring(sessionID))
                    local label = sessionName
                    local storedDuration = FormatDuration(session.durationSeconds)
                    if storedDuration ~= "" then label = label .. "  (" .. storedDuration .. ")" end
                    items[#items + 1] = { label = label, callback = function()
                        local c = self:GetWindowConfig(window.index); c.session = "history"; c.sessionID = sessionID; c.sessionName = sessionName
                    end }
                end
            end
        end
    end
    self:PopulateSubmenu(window, items)
end

function DM:GetTargetBreakdown(windowCfg, source)
    local result = {}
    if not source or not IsPlainNumber(source.totalAmount) then return result end
    if issecretvalue and issecretvalue(source.name) then return result end
    local targetCfg = {
        session = windowCfg.session, sessionID = windowCfg.sessionID,
        display = MeterEnum("EnemyDamageTaken", 10),
    }
    local targetSession = self:GetSession(targetCfg)
    for _, target in ipairs(targetSession and targetSession.combatSources or {}) do
        local targetSource = self:GetSourceBreakdown(targetCfg, target)
        local amount = 0
        for _, spell in ipairs(targetSource and targetSource.combatSpells or {}) do
            local details = spell.combatSpellDetails
            local unitName = type(details) == "table" and details.unitName
            if unitName and not (issecretvalue and issecretvalue(unitName)) and unitName == source.name and IsPlainNumber(spell.totalAmount) then amount = amount + spell.totalAmount end
        end
        if amount > 0 then result[#result + 1] = { name = target.name, totalAmount = amount, amountPerSecond = 0, icon = 132337 } end
    end
    table.sort(result, function(a, b) return a.totalAmount > b.totalAmount end)
    return result
end

function DM:RenderBreakdown(window, mode)
    local panel, source = window.breakdown, window.breakdown.source
    if not source then return end
    local cfg = self:GetWindowConfig(window.index)
    local data = self:GetSourceBreakdown(cfg, source)
    local entries = mode == "targets" and self:GetTargetBreakdown(cfg, source) or (data and data.combatSpells or {})
    local total = data and data.totalAmount or source.totalAmount
    local maxAmount = data and data.maxAmount or (entries[1] and entries[1].totalAmount) or 1
    if IsPlainNumber(maxAmount) and maxAmount <= 0 then maxAmount = 1 end
    panel.mode = mode
    local headerColor = MeterColor("headerColor", { r = .018, g = .018, b = .022 })
    local function SetTabStyle(tab, selected)
        local lift = selected and .12 or .035
        tab:SetBackdropColor(
            math.min(1, (headerColor.r or .018) + lift),
            math.min(1, (headerColor.g or .018) + lift),
            math.min(1, (headerColor.b or .022) + lift),
            selected and 1 or .92
        )
    end
    SetTabStyle(panel.spellsTab, mode == "spells")
    SetTabStyle(panel.targetsTab, mode == "targets")
    panel.summary:SetText(T("Gesamt") .. "  " .. DisplayNumber(total) .. "     " .. T("Pro Sekunde") .. "  " .. DisplayNumber(source.amountPerSecond))
    for i, row in ipairs(panel.rows) do
        local entry = entries[i]
        row:SetShown(entry ~= nil)
        row.entry = entry
        if entry then
            local name, texture = entry.name, entry.icon
            if mode == "spells" and C_Spell then
                if C_Spell.GetSpellName then local ok, value = pcall(C_Spell.GetSpellName, entry.spellID); if ok then name = value end end
                if C_Spell.GetSpellTexture then local ok, value = pcall(C_Spell.GetSpellTexture, entry.spellID); if ok then texture = value end end
            end
            row.name:SetText(name or UNKNOWN); row.icon:SetTexture(texture or 134400)
            row.value:SetText(DisplayNumber(entry.totalAmount)); row.rate:SetText(DisplayNumber(entry.amountPerSecond))
            row.bar:SetMinMaxValues(0, maxAmount); row.bar:SetValue(entry.totalAmount or 0)
        end
    end
end

function DM:ShowBreakdown(window, source)
    if not source then return end
    local panel = window.breakdown
    panel.source = source
    panel.title:SetText(T("Spieleranalyse: ") .. tostring(source.name or UNKNOWN))
    panel:Show()
    panel:Raise()
    self:RenderBreakdown(window, "spells")
end

function DM:CreateBreakdown(window)
    local panel = CreateFrame("Frame", "RexUIDamageAnalysis" .. window.index, UIParent, "BackdropTemplate")
    local cfg = self:GetWindowConfig(window.index)
    panel:SetPoint(cfg.analysisPoint or "CENTER", UIParent, cfg.analysisRelPoint or "CENTER", cfg.analysisX or ((window.index - 1) * 24), cfg.analysisY or 20)
    panel:SetSize(430, 390)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        local windowCfg = DM:GetWindowConfig(window.index)
        windowCfg.analysisPoint, windowCfg.analysisRelPoint = point, relPoint
        windowCfg.analysisX, windowCfg.analysisY = x, y
    end)
    panel:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    panel:SetBackdropColor(0.025, 0.025, 0.03, 0.98)
    panel:SetBackdropBorderColor(0.32, 0.32, 0.36, 1)
    panel.headerBackground = panel:CreateTexture(nil, "BACKGROUND")
    panel.headerBackground:SetPoint("TOPLEFT", 1, -1)
    panel.headerBackground:SetPoint("TOPRIGHT", -1, -1)
    panel.headerBackground:SetHeight(26)
    panel.headerBackground:SetColorTexture(.045, .035, .055, .98)
    panel.headerLine = panel:CreateTexture(nil, "ARTWORK")
    panel.headerLine:SetPoint("TOPLEFT", 1, -27)
    panel.headerLine:SetPoint("TOPRIGHT", -1, -27)
    panel.headerLine:SetHeight(1)
    panel.headerLine:SetColorTexture(.30, .10, .42, 1)
    panel.title = panel:CreateFontString(nil, "OVERLAY")
    panel.title:SetFont(FONT, 11, "OUTLINE"); panel.title:SetPoint("TOPLEFT", 8, -8); panel.title:SetPoint("RIGHT", -30, 0); panel.title:SetJustifyH("LEFT")
    local close = CreateSmallButton(panel, "x", 20); close:SetPoint("TOPRIGHT", -5, -5); close:SetScript("OnClick", function() panel:Hide() end)
    panel.summary = panel:CreateFontString(nil, "OVERLAY"); panel.summary:SetFont(FONT, 10, "OUTLINE"); panel.summary:SetPoint("TOPLEFT", 9, -30); panel.summary:SetTextColor(0.75, 0.75, 0.80)
    panel.spellsTab = CreateSmallButton(panel, "Zauber", 80); panel.spellsTab:SetPoint("TOPLEFT", 8, -49); panel.spellsTab:SetScript("OnClick", function() DM:RenderBreakdown(window, "spells") end)
    panel.targetsTab = CreateSmallButton(panel, "Ziele", 80); panel.targetsTab:SetPoint("LEFT", panel.spellsTab, "RIGHT", 4, 0); panel.targetsTab:SetScript("OnClick", function() DM:RenderBreakdown(window, "targets") end)
    local headers = panel:CreateFontString(nil, "OVERLAY"); headers:SetFont(FONT, 9, "OUTLINE"); headers:SetPoint("TOPLEFT", 35, -75); headers:SetPoint("RIGHT", -8, 0); headers:SetText("Name                                             " .. T("Gesamt") .. "       /s"); headers:SetTextColor(0.55, 0.55, 0.60)
    panel.rows = {}
    for i = 1, MAX_BREAKDOWN_ROWS do
        local row = CreateFrame("Button", nil, panel)
        row:SetHeight(18); row:SetPoint("TOPLEFT", 7, -88 - ((i - 1) * 19)); row:SetPoint("RIGHT", -7, 0)
        row.bar = CreateFrame("StatusBar", nil, row); row.bar:SetAllPoints(); row.bar:SetStatusBarTexture(WHITE); row.bar:SetStatusBarColor(0.36, 0.08, 0.55, 0.70)
        local bg = row.bar:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.06, 0.06, 0.07, 0.9); row.bg = bg
        row.icon = row.bar:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(16, 16); row.icon:SetPoint("LEFT"); row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.name = row.bar:CreateFontString(nil, "OVERLAY"); row.name:SetFont(FONT, 9, "OUTLINE"); row.name:SetPoint("LEFT", 21, 0); row.name:SetPoint("RIGHT", -115, 0); row.name:SetJustifyH("LEFT")
        row.value = row.bar:CreateFontString(nil, "OVERLAY"); row.value:SetFont(FONT, 9, "OUTLINE"); row.value:SetPoint("RIGHT", -52, 0)
        row.rate = row.bar:CreateFontString(nil, "OVERLAY"); row.rate:SetFont(FONT, 9, "OUTLINE"); row.rate:SetPoint("RIGHT", -2, 0); row.rate:SetTextColor(0.8, 0.8, 0.83)
        row:SetScript("OnEnter", function(self)
            local e = self.entry; if not e then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(self.name:GetText() or "")
            GameTooltip:AddDoubleLine(T("Gesamt"), DisplayNumber(e.totalAmount), 1, 1, 1, 1, 1, 1)
            GameTooltip:AddDoubleLine(T("Pro Sekunde"), DisplayNumber(e.amountPerSecond), 1, 1, 1, 1, 1, 1)
            if not (issecretvalue and issecretvalue(e.overkillAmount)) and e.overkillAmount then GameTooltip:AddDoubleLine("Overkill", DisplayNumber(e.overkillAmount), 1, 0.4, 0.4, 1, 1, 1) end
            if not (issecretvalue and issecretvalue(e.isAvoidable)) and e.isAvoidable then GameTooltip:AddLine(T("Vermeidbarer Treffer"), 1, 0.35, 0.2) end
            if not (issecretvalue and issecretvalue(e.isDeadly)) and e.isDeadly then GameTooltip:AddLine(T("Toedlicher Treffer"), 1, 0.15, 0.15) end
            GameTooltip:Show()
        end); row:SetScript("OnLeave", GameTooltip_Hide)
        panel.rows[i] = row
    end
    panel:Hide()
    window.breakdown = panel
end

function DM:CreateWindow(index)
    local frame = CreateFrame("Frame", "RexUIDamageMeter" .. index, UIParent, "BackdropTemplate")
    frame.index = index
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(.060, .055, .070, .55)
    frame:SetBackdropBorderColor(0.22, 0.22, 0.25, 1)
    frame:SetMovable(true); frame:SetResizable(true); frame:SetClampedToScreen(false); frame:SetResizeBounds(240, 125, 600, 650)

    frame.headerBackground=frame:CreateTexture(nil,"BACKGROUND"); frame.headerBackground:SetPoint("TOPLEFT",1,-1); frame.headerBackground:SetPoint("TOPRIGHT",-1,-1); frame.headerBackground:SetHeight(24); frame.headerBackground:SetColorTexture(.018,.018,.022,.94)
    frame.headerLine=frame:CreateTexture(nil,"ARTWORK"); frame.headerLine:SetPoint("TOPLEFT",1,-24); frame.headerLine:SetPoint("TOPRIGHT",-1,-24); frame.headerLine:SetHeight(1); frame.headerLine:SetColorTexture(.22,.22,.25,1)

    local titleButton = CreateFrame("Frame", nil, frame)
    titleButton:SetPoint("TOPLEFT", 5, -2); titleButton:SetSize(135, 21)
    frame.title = titleButton:CreateFontString(nil, "OVERLAY")
    frame.title:SetFont(FONT, 11, "OUTLINE"); frame.title:SetPoint("LEFT", 2, 0); frame.title:SetTextColor(.95,.95,.97)
    frame.segment = frame:CreateFontString(nil, "OVERLAY"); frame.segment:SetFont(FONT, 9, "OUTLINE"); frame.segment:SetPoint("TOP", 18, -7); frame.segment:SetTextColor(.70,.70,.74)
    frame.dragHint = frame:CreateFontString(nil,"OVERLAY"); frame.dragHint:SetFont(FONT,8,"OUTLINE"); frame.dragHint:SetPoint("TOP",0,-9); frame.dragHint:SetText(T("Kopfzeile ziehen")); frame.dragHint:SetTextColor(.82,.55,.92); frame.dragHint:Hide()

    local menu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    menu:SetPoint("TOPLEFT", titleButton, "BOTTOMLEFT", 0, -2); menu:SetSize(145, 125); menu:SetFrameStrata("DIALOG"); menu:SetFrameLevel(frame:GetFrameLevel() + 30)
    menu:SetClampedToScreen(true)
    menu:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }); menu:SetBackdropColor(0.02, 0.02, 0.025, 0.99); menu:SetBackdropBorderColor(0.38, 0.38, 0.42, 1); menu:Hide()
    frame.menu = menu
    local submenu = CreateFrame("Frame", nil, menu, "BackdropTemplate")
    submenu:SetPoint("TOPLEFT", menu, "TOPRIGHT", 3, 0); submenu:SetWidth(210); submenu:SetFrameStrata("DIALOG"); submenu:SetFrameLevel(menu:GetFrameLevel() + 5)
    submenu:SetClampedToScreen(true)
    submenu:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }); submenu:SetBackdropColor(0.02, 0.02, 0.025, 0.99); submenu:SetBackdropBorderColor(0.38, 0.38, 0.42, 1); submenu.buttons = {}; submenu:Hide()
    frame.submenu = submenu
    CreateMenuButton(menu, "Schaden", -4, function() DM:ShowDisplayCategory(frame, "damage") end, true)
    CreateMenuButton(menu, "Heilung", -27, function() DM:ShowDisplayCategory(frame, "healing") end, true)
    CreateMenuButton(menu, "Sonstiges", -50, function() DM:ShowDisplayCategory(frame, "utility") end, true)
    CreateMenuButton(menu, "Segmente", -73, function() DM:ShowSegmentMenu(frame) end, true)
    CreateMenuButton(menu, "Zurücksetzen", -96, function()
        if C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then
            C_DamageMeter.ResetAllCombatSessions()
        end
        DM:CloseMenus(frame)
        DM:Refresh()
    end)

    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT", 4, -2); drag:SetPoint("TOPRIGHT", -45, -2); drag:SetHeight(21); drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() if not DM:GetWindowConfig(frame.index).locked then frame:StartMoving() end end)
    drag:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        DM:SaveWindow(frame)
    end)
    drag:SetScript("OnEnter",function() if not DM:GetWindowConfig(frame.index).locked then frame.headerBackground:SetColorTexture(.09,.09,.11,.98) end end)
    drag:SetScript("OnLeave",function() DM:ApplyVisualStyle(frame) end)

    local closeButton = CreateSmallButton(frame, "X", 15)
    closeButton:SetSize(15, 15); closeButton:SetPoint("TOPRIGHT", -4, -5)
    closeButton:SetBackdropColor(.055,.055,.06,0); closeButton:SetBackdropBorderColor(.30,.30,.34,0)
    closeButton.text:SetTextColor(.78,.78,.82)
    closeButton:SetScript("OnEnter", function(self) self:SetBackdropColor(.18,.18,.21,.9); self.text:SetTextColor(1,1,1); GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(T("Fenster löschen")); GameTooltip:Show() end)
    closeButton:SetScript("OnLeave", function(self) self:SetBackdropColor(.055,.055,.06,0); self.text:SetTextColor(.78,.78,.82); GameTooltip:Hide() end)
    closeButton:SetScript("OnClick", function()
        DM:DeleteWindow(frame.index)
    end)
    local optionsButton = CreateOptionsButton(frame, "Anzeige, DPS/HPS und Segmente")
    optionsButton:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
    local function PositionMenus()
        local frameX, frameY = frame:GetCenter()
        local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()

        menu:ClearAllPoints()
        if type(frameY) == "number" and type(screenHeight) == "number" and frameY < screenHeight * 0.42 then
            menu:SetPoint("BOTTOMRIGHT", optionsButton, "TOPRIGHT", 0, 2)
        else
            menu:SetPoint("TOPRIGHT", optionsButton, "BOTTOMRIGHT", 0, -2)
        end

        submenu:ClearAllPoints()
        if type(frameX) == "number" and type(screenWidth) == "number" and frameX > screenWidth * 0.62 then
            submenu:SetPoint("TOPRIGHT", menu, "TOPLEFT", -3, 0)
        else
            submenu:SetPoint("TOPLEFT", menu, "TOPRIGHT", 3, 0)
        end
    end
    optionsButton:SetScript("OnClick", function()
        PositionMenus()
        menu:SetShown(not menu:IsShown())
        if not menu:IsShown() then submenu:Hide() end
    end)
    PositionMenus()

    frame.lockButton = CreateFrame("Button", nil, frame)
    frame.lockButton:SetSize(15, 15)
    frame.lockButton:SetPoint("BOTTOMLEFT", 3, 3)
    frame.lockButton:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.lockButton.parts = {}
    local lockBody = frame.lockButton:CreateTexture(nil, "ARTWORK")
    lockBody:SetSize(8, 6); lockBody:SetPoint("BOTTOM", 0, 1)
    frame.lockButton.parts[#frame.lockButton.parts + 1] = lockBody
    local shackleLeft = frame.lockButton:CreateTexture(nil, "ARTWORK")
    shackleLeft:SetSize(1, 5); shackleLeft:SetPoint("BOTTOMLEFT", lockBody, "TOPLEFT", 1, -1)
    frame.lockButton.parts[#frame.lockButton.parts + 1] = shackleLeft
    local shackleTop = frame.lockButton:CreateTexture(nil, "ARTWORK")
    shackleTop:SetSize(6, 1); shackleTop:SetPoint("BOTTOMLEFT", shackleLeft, "TOPLEFT", 0, 0)
    frame.lockButton.parts[#frame.lockButton.parts + 1] = shackleTop
    local shackleRight = frame.lockButton:CreateTexture(nil, "ARTWORK")
    shackleRight:SetSize(1, 5); shackleRight:SetPoint("TOPRIGHT", shackleTop, "BOTTOMRIGHT", 0, 0)
    frame.lockButton.parts[#frame.lockButton.parts + 1] = shackleRight
    frame.lockButton.shackleRight = shackleRight
    frame.lockButton:SetScript("OnClick", function() DM:ToggleWindowLock(frame) end)
    frame.lockButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(T(DM:GetWindowConfig(frame.index).locked and "Fenster freigeben" or "Fenster sperren"))
        GameTooltip:Show()
    end); frame.lockButton:SetScript("OnLeave", GameTooltip_Hide)

    local function CreateResizeGrip(side)
        local grip = CreateFrame("Button", nil, frame)
        grip:SetSize(18, 18); grip:SetFrameLevel(frame:GetFrameLevel() + 15)
        grip:SetPoint(side == "left" and "BOTTOMLEFT" or "BOTTOMRIGHT", side == "left" and 18 or -1, 1)
        grip.lines = {}
        for i = 1, 3 do
            local texture = grip:CreateTexture(nil, "OVERLAY")
            texture:SetColorTexture(.50,.50,.55,.9); texture:SetHeight(1)
            texture:SetWidth(4 + ((i - 1) * 4))
            texture:SetPoint("BOTTOM" .. (side == "left" and "LEFT" or "RIGHT"), side == "left" and 2 or -2, 2 + ((i - 1) * 4))
            grip.lines[i] = texture
        end
        grip:RegisterForDrag("LeftButton")
        grip:SetScript("OnDragStart", function() if not DM:GetWindowConfig(frame.index).locked then frame:StartSizing(side == "left" and "BOTTOMLEFT" or "BOTTOMRIGHT") end end)
        grip:SetScript("OnDragStop", function()
            frame:StopMovingOrSizing()
            DM:SaveWindow(frame)
            DM:LayoutWindow(frame)
            DM:RefreshWindow(frame)
        end)
        grip:SetScript("OnEnter", function() for _,line in ipairs(grip.lines) do line:SetColorTexture(.85,.85,.90,1) end end)
        grip:SetScript("OnLeave", function() for _,line in ipairs(grip.lines) do line:SetColorTexture(.50,.50,.55,.9) end end)
        return grip
    end
    frame.leftResize = CreateResizeGrip("left")
    frame.rightResize = CreateResizeGrip("right")

    frame.rows = {}
    frame.header = frame:CreateFontString(nil, "OVERLAY"); frame.header:Hide()
    frame.headerMetric = frame:CreateFontString(nil, "OVERLAY"); frame.headerMetric:Hide()
    frame.total = frame:CreateFontString(nil, "OVERLAY"); frame.total:SetFont(FONT, 9, "OUTLINE"); frame.total:SetPoint("BOTTOMLEFT", 23, 6); frame.total:SetTextColor(0.62, 0.62, 0.68)
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, frame)
        row:RegisterForClicks("LeftButtonUp")
        -- Keep the class icon outside the StatusBar.  StatusBars crop/redraw their
        -- own fill texture when the value changes, so decorative textures should
        -- not be children of the bar (same layout principle used by Details!).
        local iconHolder = CreateFrame("Frame", nil, row)
        iconHolder:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        iconHolder:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        iconHolder:SetWidth(19)
        iconHolder:SetFrameLevel(row:GetFrameLevel() + 3)

        row.icon = iconHolder:CreateTexture(nil, "OVERLAY", nil, 7)
        row.icon:SetPoint("CENTER")
        row.icon:SetSize(17, 17)
        row.icon:SetTexCoord(0, 1, 0, 1)
        row.icon:SetAlpha(1)

        local bar = CreateFrame("StatusBar", nil, row)
        bar:SetPoint("TOPLEFT", row, "TOPLEFT", 20, 0)
        bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        bar:SetStatusBarTexture(WHITE); bar:SetStatusBarColor(0.36, 0.08, 0.55, 0.82)
        local bg = row:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(.060,.055,.070,.18)
        local highlight = row:CreateTexture(nil, "OVERLAY"); highlight:SetAllPoints(); highlight:SetColorTexture(1,1,1,.12); highlight:Hide()
        local rank = bar:CreateFontString(nil, "OVERLAY"); rank:SetFont(FONT,10,"OUTLINE"); rank:SetPoint("LEFT",3,0); rank:SetTextColor(.82,.82,.85)
        local name = bar:CreateFontString(nil, "OVERLAY"); name:SetFont(FONT,10,"OUTLINE"); name:SetPoint("LEFT",19,0); name:SetPoint("RIGHT",-72,0); name:SetJustifyH("LEFT")
        local value = bar:CreateFontString(nil, "OVERLAY"); value:SetFont(FONT,10,"OUTLINE"); value:SetPoint("RIGHT",-5,0)
        row.bar, row.bg, row.highlight, row.name, row.rank, row.value = bar, bg, highlight, name, rank, value
        row:SetScript("OnClick", function(self) DM:ShowBreakdown(frame, self.source) end)
        row:SetScript("OnEnter", function(self)
            local source = self.source; if not source then return end
            self.highlight:Show()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(source.name or UNKNOWN)
            GameTooltip:AddDoubleLine(T("Gesamt"), DisplayNumber(source.totalAmount), 1, 1, 1, 1, 1, 1)
            GameTooltip:AddDoubleLine(T("Pro Sekunde"), DisplayNumber(source.amountPerSecond), 1, 1, 1, 1, 1, 1)
            GameTooltip:AddLine(T("Klicken: Spieleranalyse"), 0.55, 0.8, 1)
            GameTooltip:Show()
        end); row:SetScript("OnLeave", function(self) self.highlight:Hide(); GameTooltip:Hide() end)
        frame.rows[i] = row
    end

    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        frame.offset = math.max(0, (frame.offset or 0) - delta)
        DM:RefreshWindow(frame)
    end)

    self:CreateBreakdown(frame)
    frame:SetScript("OnSizeChanged", function() DM:LayoutWindow(frame); DM:RefreshWindow(frame) end)
    return frame
end

function DM:Initialize()
    self.windows = {}
    local cfg = Config()
    cfg.windows = type(cfg.windows) == "table" and cfg.windows or {}
    local count = self:GetWindowCount()
    for index in pairs(cfg.windows) do
        if type(index) == "number" and index > count then cfg.windows[index] = nil end
    end
    for index = 1, count do self.windows[index] = self:CreateWindow(index) end
    self.frame = self.windows[1]
    self.updater = CreateFrame("Frame")
    self:Apply()
end

-- Der 0,5-Sekunden-Updater läuft nur, solange das Modul aktiv ist.
function DM:StartUpdater()
    if not self.updater or self.updaterRunning then return end
    self.updaterRunning = true
    local elapsed = 0
    self.updater:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed > 0.5 then elapsed = 0; DM:Refresh() end
    end)
end

function DM:StopUpdater()
    if not self.updater then return end
    self.updaterRunning = nil
    self.updater:SetScript("OnUpdate", nil)
end

function DM:Enable()
    if Config().enabled == false then
        self:Disable()
        return
    end
    self.enabled = true
    self:ResumeEvents()
    self:Apply()
end

function DM:Disable()
    self.enabled = false
    self:SuspendEvents()
    self:StopUpdater()
    for _, window in ipairs(self.windows or {}) do window:Hide() end
end

function DM:ApplyProfile()
    if Config().enabled == false then
        if self.enabled ~= false then self:Disable() end
        return
    end
    if self.enabled ~= true then
        self:Enable()
        return
    end
    self:Apply()
end
