local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI
if not RexUI then return end

RexUI.GridOverlay = RexUI.GridOverlay or {}
local GO = RexUI.GridOverlay

local frame
local gridSize = 50
local gridLines = {}

local function RebuildGrid()
    for _, l in ipairs(gridLines) do
        l:Hide()
        l:SetParent(nil)
    end
    gridLines = {}

    if not frame or not frame:IsShown() then return end

    local sw, sh = GetScreenWidth(), GetScreenHeight()

    local hLines = math.floor(sh / gridSize)
    for i = 1, hLines do
        local y = i * gridSize
        local tex = frame:CreateTexture(nil, "OVERLAY", nil, 1)
        tex:SetColorTexture(0.3, 0.6, 1, 0.08)
        tex:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, y)
        tex:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, y)
        tex:SetHeight(1)
        table.insert(gridLines, tex)
    end

    local vLines = math.floor(sw / gridSize)
    for i = 1, vLines do
        local x = i * gridSize
        local tex = frame:CreateTexture(nil, "OVERLAY", nil, 1)
        tex:SetColorTexture(0.3, 0.6, 1, 0.08)
        tex:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, 0)
        tex:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, 0)
        tex:SetWidth(1)
        table.insert(gridLines, tex)
    end

    local centerH = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    centerH:SetColorTexture(1, 0.5, 0, 0.2)
    centerH:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, sh / 2)
    centerH:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, sh / 2)
    centerH:SetHeight(1)
    table.insert(gridLines, centerH)

    local centerV = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    centerV:SetColorTexture(1, 0.5, 0, 0.2)
    centerV:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", sw / 2, 0)
    centerV:SetPoint("TOPLEFT", UIParent, "TOPLEFT", sw / 2, 0)
    centerV:SetWidth(1)
    table.insert(gridLines, centerV)

    local midDot = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    midDot:SetColorTexture(1, 0.5, 0, 0.4)
    midDot:SetSize(4, 4)
    midDot:SetPoint("CENTER")
    table.insert(gridLines, midDot)
end

function GO:Show()
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)
        frame:SetAllPoints(UIParent)
        frame:SetFrameStrata("TOOLTIP")
        frame:EnableMouse(false)
    end
    frame:Show()
    RebuildGrid()
end

function GO:Hide()
    if frame then frame:Hide() end
    for _, l in ipairs(gridLines) do
        l:Hide()
        l:SetParent(nil)
    end
    gridLines = {}
end

function GO:Toggle()
    if frame and frame:IsShown() then
        self:Hide()
        RexUI:PrintMessage("Raster ausgeblendet.")
    else
        self:Show()
        RexUI:PrintMessage("Raster eingeblendet (Rasterweite: " .. gridSize .. "px).")
    end
end

function GO:SetGridSize(size)
    gridSize = math.max(10, math.floor(size))
    if frame and frame:IsShown() then
        RebuildGrid()
        RexUI:PrintMessage("Rasterweite auf " .. gridSize .. "px geändert.")
    end
end

function GO:GetGridSize()
    return gridSize
end

function GO:IsShown()
    return frame and frame:IsShown()
end
