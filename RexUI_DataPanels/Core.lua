-- ============================================================
-- RexUI_DataPanels – frei platzierbare Datenpanels (P3)
-- Nutzt die Datentext-Engine der Minimap (RexUI.Minimap.DataTexts), ist aber
-- unabhängig von der Minimap positionierbar. Bis zu drei Panels mit je 1–5 Slots.
-- ============================================================

local ADDON_NAME, ns = ...
local RexUI = ns.RexUI or _G.RexUI
if not RexUI then return end

local DP = RexUI:CreateModule("DataPanels")
RexUI.DataPanels = DP

local MAX_PANELS = 3
local MAX_SLOTS = 5
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function T(text)
    return RexUI:LocalizeText(text)
end

local function GetEngine()
    return RexUI.Minimap and RexUI.Minimap.DataTexts
end

function DP:GetConfig()
    local profile = RexUI.GetProfile and RexUI:GetProfile() or {}
    profile.dataPanels = type(profile.dataPanels) == "table" and profile.dataPanels or { enabled = false, panels = {} }
    profile.dataPanels.panels = type(profile.dataPanels.panels) == "table" and profile.dataPanels.panels or {}
    return profile.dataPanels
end

function DP:GetPanelConfig(index)
    local cfg = self:GetConfig()
    local defaults = RexUI.defaults and RexUI.defaults.profile and RexUI.defaults.profile.dataPanels
    local panelDefault = defaults and defaults.panels and defaults.panels[index] or {}
    local panel = cfg.panels[index]
    if type(panel) ~= "table" then
        panel = {}
        for key, value in pairs(panelDefault) do
            if type(value) == "table" then
                panel[key] = {}
                for k, v in pairs(value) do panel[key][k] = v end
            else
                panel[key] = value
            end
        end
        cfg.panels[index] = panel
    end
    panel.slots = type(panel.slots) == "table" and panel.slots or {}
    panel.numSlots = math.max(1, math.min(MAX_SLOTS, tonumber(panel.numSlots) or 2))
    return panel
end

-- ------------------------------------------------------------
-- Frames
-- ------------------------------------------------------------

function DP:CreatePanel(index)
    self.frames = self.frames or {}
    if self.frames[index] then return self.frames[index] end

    local frame = CreateFrame("Frame", "RexUI_DataPanel" .. index, UIParent, "BackdropTemplate")
    frame:SetSize(300, 20)
    frame:SetFrameStrata("LOW")
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame.panelIndex = index
    frame.slotKeys = {}
    for slotIndex = 1, MAX_SLOTS do
        frame.slotKeys[slotIndex] = "slot" .. slotIndex
    end
    -- Speichert Slot-Zuweisungen in der Panel-Konfiguration statt im Minimap-Profil.
    frame.saveSlot = function(slot, name)
        local panelCfg = DP:GetPanelConfig(index)
        panelCfg.slots[slot.pointIndex] = name
    end
    frame:Hide()
    self.frames[index] = frame
    return frame
end

function DP:ApplyPanel(index)
    local engine = GetEngine()
    if not engine or not engine.RegisterPanel then return end

    local cfg = self:GetConfig()
    local panelCfg = self:GetPanelConfig(index)
    local frame = self:CreatePanel(index)

    if self.enabled == false or cfg.enabled == false or panelCfg.enabled == false then
        if engine.Panels and engine.Panels[frame] then
            for _, slot in ipairs(frame.dataPanels or {}) do
                slot:UnregisterAllEvents()
                slot:SetScript("OnUpdate", nil)
                slot._rexDataTextActive = false
            end
        end
        frame:Hide()
        return
    end

    local width = math.max(60, math.min(1200, tonumber(panelCfg.width) or 300))
    local height = math.max(12, math.min(60, tonumber(panelCfg.height) or 20))
    frame:SetSize(width, height)
    frame:ClearAllPoints()
    frame:SetPoint(panelCfg.point or "BOTTOM", UIParent, panelCfg.relPoint or panelCfg.point or "BOTTOM", panelCfg.x or 0, panelCfg.y or 0)

    if panelCfg.backdrop == false then
        frame:SetBackdropColor(0, 0, 0, 0)
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    else
        frame:SetBackdropColor(0.02, 0.015, 0.025, 0.92)
        frame:SetBackdropBorderColor(0.45, 0.12, 0.65, 0.95)
    end

    engine:RegisterPanel(frame, panelCfg.numSlots)
    for slotIndex = 1, panelCfg.numSlots do
        local slot = frame.dataPanels[slotIndex]
        local name = panelCfg.slots[slotIndex] or "NONE"
        if not engine.RegisteredDataTexts[name] then name = "NONE" end
        if not slot._rexDataTextActive or slot.dataTextName ~= name or not engine.AssignedDataTexts[slot] then
            engine:AssignPanelToDataText(slot, name)
        else
            engine:UpdateSlot(slot, "DISPLAY_REFRESH")
        end
    end
    frame:Show()
end

function DP:Apply()
    for index = 1, MAX_PANELS do
        self:ApplyPanel(index)
    end
    if RexUI.Unlocked then
        self:ShowMover()
    else
        self:HideMover()
    end
end

-- ------------------------------------------------------------
-- Mover
-- ------------------------------------------------------------

function DP:CreateMover(index)
    self.movers = self.movers or {}
    if self.movers[index] then return self.movers[index] end
    local frame = self:CreatePanel(index)

    local mover = CreateFrame("Frame", nil, UIParent)
    mover:SetFrameStrata("HIGH")
    mover:SetFrameLevel(500)
    mover:SetClampedToScreen(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:Hide()
    mover.Bg = mover:CreateTexture(nil, "BACKGROUND")
    mover.Bg:SetAllPoints(mover)
    mover.Bg:SetColorTexture(0.2, 0.6, 1, 0.25)
    mover.Label = mover:CreateFontString(nil, "OVERLAY")
    mover.Label:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    mover.Label:SetPoint("CENTER")
    mover.Label:SetText(T("Datenpanel") .. " " .. index)

    mover:SetScript("OnDragStart", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        self:SetMovable(true)
        self:StartMoving()
    end)
    mover:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetMovable(false)
        local left, bottom, width, height = self:GetRect()
        if left then
            local centerX, centerY = UIParent:GetCenter()
            local panelCfg = DP:GetPanelConfig(index)
            panelCfg.point = "CENTER"
            panelCfg.relPoint = "CENTER"
            panelCfg.x = math.floor((left + width / 2 - centerX) + 0.5)
            panelCfg.y = math.floor((bottom + height / 2 - centerY) + 0.5)
            DP:ApplyPanel(index)
        end
        self:ClearAllPoints()
        self:SetAllPoints(frame)
    end)

    self.movers[index] = mover
    return mover
end

function DP:ShowMover()
    local cfg = self:GetConfig()
    for index = 1, MAX_PANELS do
        local panelCfg = self:GetPanelConfig(index)
        local frame = self:CreatePanel(index)
        local mover = self:CreateMover(index)
        if cfg.enabled ~= false and panelCfg.enabled ~= false and self.enabled ~= false then
            frame:Show()
            mover:ClearAllPoints()
            mover:SetAllPoints(frame)
            mover:Show()
        else
            mover:Hide()
        end
    end
end

function DP:HideMover()
    for _, mover in pairs(self.movers or {}) do
        mover:Hide()
    end
end

-- ------------------------------------------------------------
-- Lebenszyklus
-- ------------------------------------------------------------

function DP:Initialize()
    self.frames = {}
end

function DP:Enable()
    if self:GetConfig().enabled == false then
        self:Disable()
        return
    end
    self.enabled = true
    self:Apply()
end

function DP:Disable()
    self.enabled = false
    for _, frame in pairs(self.frames or {}) do
        for _, slot in ipairs(frame.dataPanels or {}) do
            slot:UnregisterAllEvents()
            slot:SetScript("OnUpdate", nil)
            slot._rexDataTextActive = false
        end
        frame:Hide()
    end
    self:HideMover()
end

function DP:ApplyProfile()
    if self:GetConfig().enabled == false then
        if self.enabled ~= false then self:Disable() end
        return
    end
    if self.enabled ~= true then
        self:Enable()
        return
    end
    self:Apply()
end
