-- ============================================================
-- RexUI - Widgets.lua
-- ============================================================

local ADDON_NAME, ns = ...

local RexUI =
    ns.RexUI

if not RexUI then
    return
end

RexUI.UI =
    RexUI.UI
    or {}

local UI =
    RexUI.UI
-- ------------------------------------------------------------
-- PANEL
-- ------------------------------------------------------------

function UI:CreatePanel(name, parent, width, height)

    local frame = CreateFrame(
        "Frame",
        name,
        parent or UIParent,
        "BackdropTemplate"
    )

    frame:SetSize(width, height)

    frame:SetBackdrop({

        bgFile =
            "Interface\\Buttons\\WHITE8X8",

        edgeFile =
            "Interface\\Buttons\\WHITE8X8",

        edgeSize = 1,
    })

    frame:SetBackdropColor(
        0.02,
        0.03,
        0.05,
        0.96
    )

    frame:SetBackdropBorderColor(
        0.75,
        0.20,
        1.00,
        0.90
    )

    -- SHADOW

    local shadow = frame:CreateTexture(
        nil,
        "BACKGROUND"
    )

    shadow:SetPoint(
        "TOPLEFT",
        2,
        -2
    )

    shadow:SetPoint(
        "BOTTOMRIGHT",
        -2,
        2
    )

    shadow:SetColorTexture(
        0,
        0,
        0,
        0.35
    )

    return frame
end

-- ------------------------------------------------------------
-- TITLE
-- ------------------------------------------------------------

function UI:CreateTitle(parent, text, size)

    local title = parent:CreateFontString(
        nil,
        "OVERLAY"
    )

    local font = RexUI and RexUI.Theme and RexUI.Theme.Font or "Fonts\\FRIZQT__.TTF"
    title:SetFont(
        font,
        size or 18,
        "OUTLINE"
    )

    local textR, textG, textB, textA
    if RexUI and RexUI.GetColor then
        textR, textG, textB, textA = RexUI:GetColor("text")
    end
    title:SetTextColor(textR or 1, textG or 1, textB or 1, textA or 1)

    title:SetText(text)

    return title
end

-- ------------------------------------------------------------
-- TEXT
-- ------------------------------------------------------------

function UI:CreateText(parent, text, size)

    local fs = parent:CreateFontString(
        nil,
        "OVERLAY"
    )

    local font = RexUI and RexUI.Theme and RexUI.Theme.Font or "Fonts\\FRIZQT__.TTF"
    fs:SetFont(
        font,
        size or 12,
        ""
    )

    local textR, textG, textB, textA
    if RexUI and RexUI.GetColor then
        textR, textG, textB, textA = RexUI:GetColor("subtext")
    end
    fs:SetTextColor(textR or 1, textG or 1, textB or 1, textA or 1)

    fs:SetText(text)

    return fs
end

-- ------------------------------------------------------------
-- BUTTON
-- ------------------------------------------------------------

function UI:CreateButton(parent, text, width, height)

    local button = CreateFrame(
        "Button",
        nil,
        parent,
        "BackdropTemplate"
    )

    button:SetSize(
        width or 180,
        height or 34
    )

    button:SetBackdrop({

        bgFile =
            "Interface\\Buttons\\WHITE8X8",

        edgeFile =
            "Interface\\Buttons\\WHITE8X8",

        edgeSize = 1,
    })

    button:SetBackdropColor(
        0.05,
        0.06,
        0.10,
        0.95
    )

    button:SetBackdropBorderColor(
        0.80,
        0.25,
        1.00,
        0.90
    )

    local label = button:CreateFontString(
        nil,
        "OVERLAY"
    )

    label:SetPoint("CENTER")

    local font = RexUI and RexUI.Theme and RexUI.Theme.Font or "Fonts\\FRIZQT__.TTF"
    label:SetFont(
        font,
        13,
        "OUTLINE"
    )

    label:SetTextColor(
        1,
        1,
        1,
        1
    )

    label:SetText(text)

    button.Label = label
	
	button:SetScript(
    "OnMouseDown",
    function(self)

        self:SetBackdropColor(
            0.10,
            0.10,
            0.14,
            1
        )

    end
)

button:SetScript(
    "OnMouseUp",
    function(self)

        self:SetBackdropColor(
            0.02,
            0.03,
            0.05,
            0.96
        )

    end
)

    return button
end