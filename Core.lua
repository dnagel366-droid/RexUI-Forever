-- ============================================================
-- RexUI - Core.lua
-- Hauptdatei und Addon-Start
-- ============================================================

local ADDON_NAME, ns = ...

local RexUI = {}

ns.RexUI = RexUI
_G["RexUI"] = RexUI  -- global damit alle Module es finden

-- ------------------------------------------------------------
-- LOKALE VARIABLEN
-- ------------------------------------------------------------

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local VERSION = GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "Version") or "1.4"

-- ------------------------------------------------------------
-- CORE
-- ------------------------------------------------------------

RexUI.name = ADDON_NAME
RexUI.version = VERSION
RexUI.oUF = ns.oUF or _G.RexUI_oUF

RexUI.modules = {}
RexUI.moduleOrder = {}

-- ------------------------------------------------------------
-- CREATE MODULE
-- ------------------------------------------------------------

function RexUI:CreateModule(name)

    if not name then
        return
    end

    local module = {
        name = name,
        enabled = false,
        initialized = false,
    }

    -- Einheitlicher Modul-Lebenszyklus (P0.3). Module dürfen jede Stufe überschreiben.
    function module:Initialize()
        -- nur dauerhafte Daten / Tabellen anlegen
    end

    -- Events über diese Helfer registrieren, damit Disable() ein Modul
    -- vollständig ereignisfrei stellen und Enable() es wieder anbinden kann.
    function module:RegisterEvents(frame, events, unit)
        if not frame or type(events) ~= "table" then return end
        self._eventFrames = self._eventFrames or {}

        local entry
        for _, existing in ipairs(self._eventFrames) do
            if existing.frame == frame and existing.unit == unit then
                entry = existing
                break
            end
        end
        if not entry then
            entry = { frame = frame, events = {}, unit = unit }
            self._eventFrames[#self._eventFrames + 1] = entry
        end

        for _, event in ipairs(events) do
            entry.events[#entry.events + 1] = event
            if self.enabled ~= false then
                if unit then
                    frame:RegisterUnitEvent(event, unit)
                else
                    frame:RegisterEvent(event)
                end
            end
        end
    end

    function module:SuspendEvents()
        for _, entry in ipairs(self._eventFrames or {}) do
            entry.frame:UnregisterAllEvents()
        end
    end

    function module:ResumeEvents()
        for _, entry in ipairs(self._eventFrames or {}) do
            for _, event in ipairs(entry.events) do
                if entry.unit then
                    entry.frame:RegisterUnitEvent(event, entry.unit)
                else
                    entry.frame:RegisterEvent(event)
                end
            end
        end
    end

    function module:Enable()
        self.enabled = true
        self:ResumeEvents()
    end

    function module:Disable()
        self.enabled = false
        self:SuspendEvents()
    end

    function module:ApplyProfile()
        if self.Apply then
            self:Apply()
        elseif self.Update then
            self:Update()
        elseif self.Refresh then
            self:Refresh()
        end
    end

    function module:Shutdown()
        if self.Disable then
            self:Disable()
        end
    end

    if not self.modules[name] then
        self.moduleOrder[#self.moduleOrder + 1] = name
    end
    self.modules[name] = module

    return module
end

-- ------------------------------------------------------------
-- MODULE ENABLE / DISABLE (aus den Einstellungen)
-- ------------------------------------------------------------

function RexUI:SetModuleEnabled(name, enabled)
    local module = self.modules and self.modules[name]
    if not module then return end

    if enabled then
        if module.enabled ~= true and module.Enable then
            module:Enable()
        end
        if module.ApplyProfile then
            module:ApplyProfile()
        end
    elseif module.enabled ~= false and module.Disable then
        module:Disable()
    end
end

-- ------------------------------------------------------------
-- REGISTER MODULE
-- ------------------------------------------------------------

function RexUI:RegisterModule(name, module)

    if not name
    or not module then
        return
    end

    if not self.modules[name] then
        self.moduleOrder[#self.moduleOrder + 1] = name
    end
    self.modules[name] = module
end

-- ------------------------------------------------------------
-- PRINT
-- ------------------------------------------------------------

function RexUI:PrintMessage(text)

    if not text then
        return
    end

    print(
        "|cff4cc9ff[RexUI]|r "
        .. (self.LocalizeText and self:LocalizeText(text) or text)
    )
end

-- ------------------------------------------------------------
-- VERSION
-- ------------------------------------------------------------

function RexUI:GetVersion()

    return VERSION
end

-- ------------------------------------------------------------
-- UNIT TOOLTIP LEVEL
-- ------------------------------------------------------------

local function AccessibleNumber(value)
    if value == nil then return nil end
    if canaccessvalue and not canaccessvalue(value) then return nil end
    return tonumber(value)
end

function RexUI:CorrectUnitTooltipLevel(tooltip, unit)
    if not tooltip or not unit or not UnitExists(unit) then return end

    local actualLevel = AccessibleNumber(UnitLevel and UnitLevel(unit))
    local effectiveLevel = AccessibleNumber(UnitEffectiveLevel and UnitEffectiveLevel(unit))
    if not actualLevel or actualLevel <= 0 or not effectiveLevel or actualLevel == effectiveLevel then return end

    local tooltipName = tooltip.GetName and tooltip:GetName()
    if not tooltipName then return end

    local oldLevel = tostring(math.floor(effectiveLevel + 0.5))
    local newLevel = tostring(math.floor(actualLevel + 0.5))
    local lineCount = tooltip.NumLines and tooltip:NumLines() or 0

    for index = 2, math.min(lineCount, 6) do
        local line = _G[tooltipName .. "TextLeft" .. index]
        local text = line and line:GetText()
        local lower = type(text) == "string" and text:lower() or ""
        if lower:find("stufe", 1, true) or lower:find("level", 1, true) then
            local searchFrom = 1
            while true do
                local first, last = text:find(oldLevel, searchFrom, true)
                if not first then break end
                local before = first > 1 and text:sub(first - 1, first - 1) or ""
                local after = last < #text and text:sub(last + 1, last + 1) or ""
                if not before:match("%d") and not after:match("%d") then
                    line:SetText(text:sub(1, first - 1) .. newLevel .. text:sub(last + 1))
                    return
                end
                searchFrom = last + 1
            end
        end
    end
end

function RexUI:AddUnitTooltipRealm(tooltip, unit)
    if not tooltip or not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return end

    local _, realm
    if UnitFullName then
        _, realm = UnitFullName(unit)
    end
    if not realm or realm == "" then
        local _
        _, realm = UnitName(unit)
    end
    if not realm or realm == "" then
        realm = GetRealmName and GetRealmName()
    end
    if not realm or realm == "" then return end

    local label = self.LocalizeText and self:LocalizeText("Server") or "Server"
    tooltip:AddDoubleLine(label, realm, 0.55, 0.80, 1, 1, 1, 1)
end

function RexUI:ShowUnitTooltip(owner, unit, anchor)
    if not GameTooltip or not owner or not unit or not UnitExists(unit) then return end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:SetUnit(unit)
    self:CorrectUnitTooltipLevel(GameTooltip, unit)
    self:AddUnitTooltipRealm(GameTooltip, unit)
    GameTooltip:Show()

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(owner) and UnitExists(unit) then
                RexUI:CorrectUnitTooltipLevel(GameTooltip, unit)
                GameTooltip:Show()
            end
        end)
    end
end

-- ------------------------------------------------------------
-- INITIALIZE
-- ------------------------------------------------------------

function RexUI:Initialize()

    -- DATABASE
    if self.InitDatabase then
        self:InitDatabase()
    end

    -- PROFILES
    if self.InitProfiles then
        self:InitProfiles()
    end

    if self.FlushPersistence then
        self:FlushPersistence()
    end

    -- THEME
    if self.InitTheme then
        self:InitTheme()
    end

    -- MODULES: Initialize → Enable (P0.3)
    for _, moduleName in ipairs(self.moduleOrder) do
        local module = self.modules[moduleName]

        if module then
            if module.Initialize and not module.initialized then
                module:Initialize()
                module.initialized = true
            end
            if module.Enable and module.enabled ~= true then
                module:Enable()
            end
        end
    end

-- FIRST START

if self.db
and self.db.profile
and self.db.profile.firstLaunch then

    if self.Welcome
    and self.Welcome.Show then

        self.Welcome:Show()

    end

    self.db.profile.firstLaunch = false
end

    self:PrintMessage("Eternal v" .. VERSION .. " geladen. /rexui")
end

-- ------------------------------------------------------------
-- EVENT FRAME
-- ------------------------------------------------------------

RexUI.frame =
    CreateFrame("Frame")

RexUI.frame:RegisterEvent(
    "PLAYER_LOGIN"
)

RexUI.frame:SetScript("OnEvent", function(_, event)

    if event == "PLAYER_LOGIN" then

        RexUI:Initialize()
    end
end)

-- ------------------------------------------------------------
-- SLASH COMMAND
-- ------------------------------------------------------------

SLASH_REXUI1 = "/rexui"

SlashCmdList["REXUI"] = function(input)

    input = string.lower(tostring(input or ""))

    if input == "version"
    or input == "ver" then
        RexUI:PrintMessage("Version " .. RexUI:GetVersion())
        return
    end

    if input == "install"
    or input == "setup"
    or input == "einrichten" then
        if RexUI.Welcome and RexUI.Welcome.Show then
            RexUI.Welcome:Show()
        end
        return
    end

    if input == "help"
    or input == "hilfe" then
        RexUI:PrintMessage("/rexui - Konfiguration öffnen")
        RexUI:PrintMessage("/rexui install - Willkommensfenster öffnen")
        RexUI:PrintMessage("/rexui version - geladene Version anzeigen")
        RexUI:PrintMessage("/rexui help - Hilfe anzeigen")
        RexUI:PrintMessage("/rexperf - Performance-Messung (on|off|report)")
        return
    end

    if RexUI.ConfigUI
    and RexUI.ConfigUI.Toggle then

        RexUI.ConfigUI:Toggle()

        return
    end

    RexUI:PrintMessage(
        "Die Konfiguration ist noch nicht geladen."
    )
end

SLASH_REXCASTDEBUG1 = "/rexcastdebug"

SlashCmdList["REXCASTDEBUG"] = function()
    local AB = RexUI.ActionBars
    local CD = AB and AB.Cooldowns

    if not CD or not CD.SetDebug or not CD.IsDebugEnabled then
        RexUI:PrintMessage("CastDebug ist noch nicht geladen.")
        return
    end

    CD:SetDebug(not CD:IsDebugEnabled())
    RexUI:PrintMessage("CastDebug: " .. (CD:IsDebugEnabled() and "an" or "aus"))
end

SLASH_REXGRID1 = "/rexgrid"
SlashCmdList["REXGRID"] = function(arg)
    if RexUI.GridOverlay and RexUI.GridOverlay.Toggle then
        local n = tonumber(arg)
        if n and n >= 10 then
            RexUI.GridOverlay:SetGridSize(n)
        end
        RexUI.GridOverlay:Toggle()
    else
        RexUI:PrintMessage("GridOverlay ist noch nicht geladen.")
    end
end

local function GetMouseFocus()
    local frames = _G.GetMouseFoci()
    return frames and frames[1]
end

local function GetFrameName(frame)
    if frame.GetDebugName then
        return frame:GetDebugName()
    elseif frame.GetName then
        return frame:GetName()
    end
    return tostring(frame)
end

SLASH_GETPOINT1 = "/getpoint"
SlashCmdList["GETPOINT"] = function(arg)
    local frame = (arg ~= "" and _G[arg]) or GetMouseFocus()
    if not frame then return end
    local point, relativeTo, relativePoint, xOffset, yOffset = frame:GetPoint()
    print(GetFrameName(frame), point, GetFrameName(relativeTo), relativePoint, xOffset, yOffset)
end

SLASH_FRAME1 = "/frame"
SlashCmdList["FRAME"] = function(arg)
    local frame = (arg ~= "" and _G[arg]) or GetMouseFocus()
    if not frame then return end
    _G.FRAME = frame
    RexUI:PrintMessage("_G.FRAME = " .. GetFrameName(frame))
    if arg:match("%S") and _G.TableAttributeDisplay then
        _G.TableAttributeDisplay:InspectTable(frame)
        _G.TableAttributeDisplay:Show()
    end
end

SLASH_TEXLIST1 = "/texlist"
SlashCmdList["TEXLIST"] = function(arg)
    local frame = (arg ~= "" and _G[arg]) or _G.FRAME
    if not frame then return end
    for _, region in next, { frame:GetRegions() } do
        if region.IsObjectType and region:IsObjectType("Texture") then
            print(region:GetTexture() or "nil", region:GetName() or "unnamed", region:GetDrawLayer())
        end
    end
end
