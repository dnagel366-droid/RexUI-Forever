-- ============================================================
-- RexUI_ActionBars\Layout.lua
-- Layout Engine - horizontal, vertikal, Grid
-- ============================================================

local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI

local AB = RexUI and RexUI.ActionBars
if not AB then return end

-- ============================================================
-- LAYOUT BAR
-- cfg.rows     = 1        -> eine Reihe horizontal
-- cfg.rows     > 1        -> Grid (mehrere Reihen)
-- cfg.vertical = true     -> eine Spalte vertikal
-- ============================================================

function AB:GetButtonMetrics(cfg, fallbackSize, fallbackSpacing)
    cfg = cfg or {}

    local requestedSize = cfg.buttonSize or fallbackSize or 36
    local requestedSpacing = cfg.spacing
    if requestedSpacing == nil then
        requestedSpacing = fallbackSpacing or 3
    end

    return requestedSize, requestedSpacing
end

function AB:LayoutButtonGrid(bar, buttons, visibleCount, cfg, fallbackSize, fallbackSpacing)
    if not bar or not buttons or visibleCount <= 0 then return end

    local size, spacing = AB:GetButtonMetrics(cfg, fallbackSize, fallbackSpacing)
    local rows = cfg.vertical and visibleCount or math.max(1, math.min(cfg.rows or 1, visibleCount))
    local cols = math.ceil(visibleCount / rows)
    local placed = {}

    for index, btn in ipairs(buttons) do
        if btn:IsShown() and #placed < visibleCount then
            placed[#placed + 1] = { button = btn, sourceIndex = index }
        end
    end

    local signatureParts = {
        tostring(size), tostring(spacing), tostring(rows), tostring(cols), tostring(visibleCount),
    }
    for _, entry in ipairs(placed) do
        signatureParts[#signatureParts + 1] = tostring(entry.sourceIndex)
    end
    local signature = table.concat(signatureParts, ":")

    -- Pet- and stance-cooldown events may fire repeatedly without changing
    -- any geometry. Re-anchoring every button for those visual-only updates
    -- caused the bars to visibly twitch.
    if bar.rexLayoutSignature == signature then return end
    bar.rexLayoutSignature = signature

    for index, entry in ipairs(placed) do
        local btn = entry.button
        btn:SetSize(size, size)
        btn:ClearAllPoints()

        if index == 1 then
            btn:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        elseif (index - 1) % cols == 0 then
            btn:SetPoint("TOPLEFT", placed[index - cols].button, "BOTTOMLEFT", 0, -spacing)
        else
            btn:SetPoint("LEFT", placed[index - 1].button, "RIGHT", spacing, 0)
        end
    end

    bar:SetSize(
        (cols * size) + ((cols - 1) * spacing),
        (rows * size) + ((rows - 1) * spacing)
    )
end

function AB:LayoutBar(barKey)

    local bar = AB.Bars[barKey]
    if not bar then return end

    if InCombatLockdown() then
        AB:RunOutOfCombat("LayoutBar_" .. barKey, function()
            AB:LayoutBar(barKey)
        end)
        return
    end

    local cfg     = AB:GetConfig(barKey)
    local slots   = cfg.slots or (bar.buttons and #bar.buttons) or 0

    for i, btn in ipairs(bar.buttons) do
        if i > slots then
            btn:Hide()
        else
            btn:Show()
        end

    end

    AB:LayoutButtonGrid(bar, bar.buttons, slots, cfg, 36, 3)
end

-- ============================================================
-- LAYOUT ALL
-- ============================================================

function AB:LayoutAllBars()
    if InCombatLockdown() then
        AB:RunOutOfCombat("LayoutAllBars", function()
            AB:LayoutAllBars()
        end)
        return
    end

    for barKey in pairs(AB.Bars) do
        AB:LayoutBar(barKey)
    end
end

