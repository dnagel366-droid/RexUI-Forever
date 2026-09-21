-- ============================================================
-- RexUI_Utility\PixelPerfect.lua
-- Pixel snapping helpers for crisp borders, sizes and offsets.
-- ============================================================

local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI
if not RexUI then return end

RexUI.Pixel = RexUI.Pixel or {}
local Pixel = RexUI.Pixel

local floor = math.floor
local abs = math.abs

Pixel.mult = 1
Pixel.physicalWidth = 0
Pixel.physicalHeight = 0

function Pixel:Refresh()
    local width, height
    if GetPhysicalScreenSize then
        width, height = GetPhysicalScreenSize()
    end
    self.physicalWidth = width or GetScreenWidth() or 0
    self.physicalHeight = height or GetScreenHeight() or 768

    local uiScale = UIParent and UIParent.GetScale and UIParent:GetScale() or 1
    local perfect = self.physicalHeight > 0 and (768 / self.physicalHeight) or 1

    self.perfect = perfect
    self.mult = perfect / uiScale
end

function Pixel:Scale(value)
    if not value or value == 0 then return value or 0 end

    local mult = self.mult or 1
    if mult == 1 then return value end

    local step = mult > 0 and abs(mult) or 1
    if step == 0 then return value end

    if value > 0 then
        return value - (value % step)
    end

    return value + ((-value) % step)
end

function Pixel:Snap(value)
    return floor((value or 0) + 0.5)
end

function Pixel:Size(value)
    return self:Scale(value or 0)
end

function Pixel:Border(size)
    return self:Scale(size or 1)
end

function Pixel:SetSize(frame, width, height)
    if not frame then return end
    frame:SetSize(self:Size(width), self:Size(height or width))
end

function Pixel:SetPoint(frame, point, relativeTo, relativePoint, x, y)
    if not frame then return end
    frame:SetPoint(point, relativeTo, relativePoint, self:Size(x or 0), self:Size(y or 0))
end

function RexUI:PixelRefresh()
    Pixel:Refresh()
end

function RexUI:PixelScale(value)
    return Pixel:Scale(value)
end

function RexUI:PixelSize(value)
    return Pixel:Size(value)
end

function RexUI:PixelBorder(size)
    return Pixel:Border(size)
end

function RexUI:PixelSetSize(frame, width, height)
    Pixel:SetSize(frame, width, height)
end

function RexUI:PixelSetPoint(frame, point, relativeTo, relativePoint, x, y)
    Pixel:SetPoint(frame, point, relativeTo, relativePoint, x, y)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UI_SCALE_CHANGED")
frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
frame:SetScript("OnEvent", function()
    Pixel:Refresh()
end)

Pixel:Refresh()