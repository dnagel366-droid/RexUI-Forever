-- ============================================================
-- RexUI_Config – Scroll.lua
-- Scrollbereich der Einstellungen
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
-- SCROLLFRAME ERSTELLUNG
-- ------------------------------------------------------------

function ConfigUI:CreateScrollFrame(parent)

    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")

    scrollFrame:SetPoint("TOPLEFT", 10, ConfigUI.ActiveMainCategory and -46 or -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    scrollFrame:EnableMouseWheel(true)

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        if range <= 0 then
            return
        end

        local step = 42
        local target = self:GetVerticalScroll() - (delta * step)
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

    local content = CreateFrame("Frame", nil, scrollFrame)

    content:SetSize(1, 1)

    scrollFrame:SetScrollChild(content)

    return scrollFrame, content
end
