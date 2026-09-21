-- ============================================================
-- RexUI – Theme.lua
-- Farben und Design
-- ============================================================

local ADDON_NAME, ns = ...

local RexUI =
    ns.RexUI

if not RexUI then
    return
end

RexUI.Theme =
    RexUI.Theme
    or {}

local Theme =
    RexUI.Theme

-- ------------------------------------------------------------
-- THEMES
-- ------------------------------------------------------------

Theme.List = {

    MidnightPurple = {

        name = "Midnight Purple",

        background = {
            0.01,
            0.01,
            0.02,
            0.96
        },

        panel = {
            0.08,
            0.02,
            0.12,
            0.96
        },

        border = {
            0.45,
            0.12,
            0.65,
            0.90
        },

        highlight = {
            0.85,
            0.25,
            1.00,
            1.00
        },

        hover = {
            0.35,
            0.10,
            0.45,
            1.00
        },

        text = {
            0.92,
            0.92,
            0.96,
            1.00
        },

        mutedText = {
            0.60,
            0.58,
            0.68,
            1.00
        },

        glow = {
            0.70,
            0.25,
            1.00,
            0.60
        },
    },
}

-- ------------------------------------------------------------
-- THEME INITIALISIEREN
-- ------------------------------------------------------------

function RexUI:InitTheme()

    local profile =
        self:GetProfile()

    local themeName =
        profile
        and profile.theme
        or "MidnightPurple"

    self.theme =
        Theme.List[themeName]
        or Theme.List.MidnightPurple

end

-- ------------------------------------------------------------
-- THEME ABRUFEN
-- ------------------------------------------------------------

function RexUI:GetTheme()

    return self.theme
        or Theme.List.MidnightPurple
end

-- ------------------------------------------------------------
-- THEME SETZEN
-- ------------------------------------------------------------

function Theme:SetTheme(name)

    if not Theme.List[name] then
        return
    end

    if not RexUI or not RexUI.db then return end

    RexUI.db.profile.theme =
        name

    RexUI.theme =
        Theme.List[name]

    RexUI:PrintMessage(
        "Theme gewechselt: "
        .. name
    )

    ReloadUI()
end

-- ------------------------------------------------------------
-- FARBE ABRUFEN
-- ------------------------------------------------------------

function RexUI:GetColor(key)

    local theme =
        self:GetTheme()

    if theme
    and theme[key] then

        return unpack(theme[key])
    end

    return 1, 1, 1, 1
end

-- ------------------------------------------------------------
-- PANEL STYLE
-- ------------------------------------------------------------

function RexUI:ApplyPanelStyle(frame)

    if not frame then
        return
    end

    frame:SetBackdrop({

        bgFile =
            "Interface\\Buttons\\WHITE8X8",

        edgeFile =
            "Interface\\Buttons\\WHITE8X8",

        edgeSize = self.PixelBorder and self:PixelBorder(1) or 1,
    })

    frame:SetBackdropColor(
        self:GetColor("panel")
    )

    frame:SetBackdropBorderColor(
        self:GetColor("border")
    )
end

-- ------------------------------------------------------------
-- BORDER
-- ------------------------------------------------------------

function RexUI:CreateBorder(frame)

    if not frame then
        return
    end

    if frame.RexUIBorder then
        return
    end

    local border =
        CreateFrame(
            "Frame",
            nil,
            frame,
            "BackdropTemplate"
        )

    local pixel = self.PixelSize and self:PixelSize(1) or 1

    border:SetPoint(
        "TOPLEFT",
        -pixel,
        pixel
    )

    border:SetPoint(
        "BOTTOMRIGHT",
        pixel,
        -pixel
    )

    border:SetBackdrop({

        edgeFile =
            "Interface\\Buttons\\WHITE8X8",

        edgeSize = self.PixelBorder and self:PixelBorder(1) or 1,
    })

    border:SetBackdropBorderColor(
        self:GetColor("border")
    )

    frame.RexUIBorder =
        border
end

-- ------------------------------------------------------------
-- HOVER
-- ------------------------------------------------------------

function RexUI:SetHover(frame)

    if not frame then
        return
    end

    frame:HookScript(
        "OnEnter",
        function(self)

            if self.RexUIBorder then

                self.RexUIBorder:SetBackdropBorderColor(
                    RexUI:GetColor("hover")
                )

            end
        end
    )

    frame:HookScript(
        "OnLeave",
        function(self)

            if self.RexUIBorder then

                self.RexUIBorder:SetBackdropBorderColor(
                    RexUI:GetColor("border")
                )

            end
        end
    )
end

-- ------------------------------------------------------------
-- BUTTON STYLE
-- ------------------------------------------------------------

function RexUI:StyleButton(button)

    if not button then
        return
    end

    self:ApplyPanelStyle(button)

    self:CreateBorder(button)

    self:SetHover(button)
end

-- ------------------------------------------------------------
-- FONT
-- ------------------------------------------------------------

Theme.Font =
    "Fonts\\FRIZQT__.TTF"
