-- ============================================================
-- RexUI_ActionBars\Styling.lua
-- ============================================================

local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI

local AB = RexUI.ActionBars
if not AB then return end

local ACTIONBAR_FONT = (RexUI.Theme and RexUI.Theme.Font) or STANDARD_TEXT_FONT
local MEDIA_PATH = "Interface\\AddOns\\RexUI\\RexUI_ActionBars\\Media\\"
local HOVER_BORDER_ALPHA = 0.36

-- Keep module-local artwork in one place.  WoW loads texture files lazily, so
-- these paths need no separate TOC entries and remain safe for all bar types.
AB.Media = AB.Media or {
    edge = MEDIA_PATH .. "edge.png",
    hover = MEDIA_PATH .. "highlight-3.png",
    highlight2 = MEDIA_PATH .. "highlight-2.png",
    highlight4 = MEDIA_PATH .. "highlight-4.png",
    assistedCombat = MEDIA_PATH .. "assist-plus.tga",
}

local function HideTexture(tex)
    if not tex then return end
    if tex.SetTexture then pcall(tex.SetTexture, tex, nil) end
    if tex.SetAlpha then pcall(tex.SetAlpha, tex, 0) end
    if tex.Hide then pcall(tex.Hide, tex) end
end

local function SetPixelLinesColor(lines, r, g, b, a)
    if not lines then return end
    for _, line in ipairs(lines) do
        line:SetColorTexture(r, g, b, a or 1)
    end
end

local function CreatePixelLines(parent, inset, r, g, b, a)
    inset = RexUI.PixelSize and RexUI:PixelSize(inset or 1) or (inset or 1)
    local thickness = RexUI.PixelBorder and RexUI:PixelBorder(1) or 1
    local lines = {}
    for index = 1, 4 do
        lines[index] = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    end

    lines[1]:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset)
    lines[1]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -inset)
    lines[1]:SetHeight(thickness)
    lines[2]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset, inset)
    lines[2]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset)
    lines[2]:SetHeight(thickness)
    lines[3]:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset)
    lines[3]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset, inset)
    lines[3]:SetWidth(thickness)
    lines[4]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -inset)
    lines[4]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset)
    lines[4]:SetWidth(thickness)

    SetPixelLinesColor(lines, r, g, b, a)
    return lines
end

function AB:SetButtonBorderColor(btn, r, g, b, a)
    if not btn or not btn.border then return end

    a = a or 1
    if btn.rexBorderR == r
        and btn.rexBorderG == g
        and btn.rexBorderB == b
        and btn.rexBorderA == a then
        return
    end
    btn.rexBorderR, btn.rexBorderG, btn.rexBorderB, btn.rexBorderA = r, g, b, a

    if btn.border.SetBackdropBorderColor then
        btn.border:SetBackdropBorderColor(0, 0, 0, 0)
    end
    SetPixelLinesColor(btn.border.rexPixelLines, r, g, b, a)
end

function AB:StyleBarBackdrop(bar)
    if not bar then return end
    if not bar.rexBackdrop then
        local backdrop = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        backdrop:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
        backdrop:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
        backdrop:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))
        backdrop:EnableMouse(false)
        backdrop:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        backdrop:SetBackdropColor(0.04, 0.03, 0.05, 0.22)
        backdrop.rexPixelLines = CreatePixelLines(backdrop, 1, 0.14, 0.12, 0.16, 0.48)
        bar.rexBackdrop = backdrop
    end
    -- Bars 1-8 and the stance bar show only their individual button borders.
    -- The Pet Bar keeps its unchanged 4.6 backdrop.
    bar.rexBackdrop:SetShown(bar.rexBarKey == "PetBar")
end

local function StylePushedTexture(btn, iconInset)
    if not btn or not btn.GetPushedTexture then return end

    local ok, pushed = pcall(btn.GetPushedTexture, btn)
    if not ok or not pushed then return end

    pushed:ClearAllPoints()
    pushed:SetPoint("TOPLEFT", btn, "TOPLEFT", iconInset, -iconInset)
    pushed:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -iconInset, iconInset)
    pushed:SetColorTexture(0, 0, 0, 1)
    pushed:SetBlendMode("BLEND")
    pushed:SetDrawLayer("OVERLAY", 6)
    pushed:SetAlpha(0)
    pushed:Show()

    btn.rexPushedTexture = pushed
end

function AB:ApplyButtonStateVisual(btn, cfg)
    if not btn or not cfg then return end

    local isNormalActionButton = btn.rexBarKey and string.match(btn.rexBarKey, "^Bar%d+$") ~= nil
    local stableBorderActive
    if btn.rexBarKey == "PetBar" and btn.rexPetCommandActive ~= nil then
        stableBorderActive = btn.rexPetCommandActive
    elseif isNormalActionButton then
        stableBorderActive = false
    else
        stableBorderActive = btn.GetChecked and btn:GetChecked()
    end

    if btn.border then
        -- Normal action buttons keep one immutable outer border. Hover already
        -- has its own texture and active actions use the inner overlay, so no
        -- combat event can flash a white frame around these buttons anymore.
        if isNormalActionButton then
            AB:SetButtonBorderColor(btn, unpack(cfg.borderColor))
        elseif btn.rexHovered then
            AB:SetButtonBorderColor(btn,
                cfg.hoverColor[1],
                cfg.hoverColor[2],
                cfg.hoverColor[3],
                HOVER_BORDER_ALPHA
            )
        else
            AB:SetButtonBorderColor(btn, unpack(stableBorderActive and (cfg.activeColor or cfg.hoverColor) or cfg.borderColor))
        end
    end
    if btn.activeOverlay then
        btn.activeOverlay:SetAlpha(btn.rexActionActive == true and 1 or 0)
    end
end

-- ============================================================
-- STYLE BUTTON
-- Erwartet: btn mit btn.icon, btn.cooldown (bereits erstellt)
-- ============================================================

function AB:StyleButton(btn, cfg)

    if not btn or not cfg then return end
    local iconInset = cfg.iconInset or 2
    local iconCrop = cfg.iconCrop or 0.07
    local name = btn.GetName and btn:GetName()

    -- --------------------------------------------------------
    -- BLIZZARD TEXTUREN ENTFERNEN
    -- --------------------------------------------------------

    -- nur aufrufen wenn die Methode existiert
    local function safeClear(method)
        if btn[method] then
            pcall(btn[method], btn, "")
        end
    end

    safeClear("SetNormalTexture")
    safeClear("SetPushedTexture")
    safeClear("SetHighlightTexture")
    safeClear("SetCheckedTexture")

    -- sicherheitshalber alpha = 0 auf allen Blizzard-Layers
    for _, method in ipairs({
        "GetNormalTexture",
        "GetHighlightTexture",
        "GetPushedTexture",
        "GetCheckedTexture",
    }) do
        if btn[method] then
            local ok, tex = pcall(btn[method], btn)
            if ok and tex then
                tex:SetAlpha(0)
                tex:Hide()
            end
        end
    end

    if btn.GetCheckedTexture then
        local ok, tex = pcall(btn.GetCheckedTexture, btn)
        if ok and tex then
            tex:SetColorTexture(0, 0, 0, 0)
            tex:SetAlpha(0)
            tex:Hide()
        end
    end

    if btn.ActionStatus then
        btn.ActionStatus:SetAlpha(0)
        btn.ActionStatus:Hide()
    end

    HideTexture(btn.SlotBackground or (name and _G[name .. "SlotBackground"]))
    HideTexture(btn.NewActionTexture or (name and _G[name .. "NewActionTexture"]))

    -- --------------------------------------------------------
    -- HINTERGRUND (unter dem Icon)
    -- --------------------------------------------------------

    if not btn.bg then

        btn.bg = btn:CreateTexture(nil, "BACKGROUND", nil, -8)
        btn.bg:SetAllPoints(btn)
    end
    btn.bg:SetColorTexture(unpack(cfg.bgColor))

    if not btn.emptySlot then
        btn.emptySlot = btn:CreateTexture(nil, "BACKGROUND", nil, -7)
    end
    btn.emptySlot:ClearAllPoints()
    btn.emptySlot:SetPoint("TOPLEFT", btn, "TOPLEFT", iconInset, -iconInset)
    btn.emptySlot:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -iconInset, iconInset)
    btn.emptySlot:SetColorTexture(0, 0, 0, 0.03)

    -- --------------------------------------------------------
    -- ICON
    -- --------------------------------------------------------

    if btn.icon then

        btn.icon:ClearAllPoints()
        btn.icon:SetPoint("TOPLEFT",     btn, "TOPLEFT",      iconInset, -iconInset)
        btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -iconInset,  iconInset)
        btn.icon:SetTexCoord(
            iconCrop,
            1 - iconCrop,
            iconCrop,
            1 - iconCrop
        )
        btn.icon:SetDrawLayer("ARTWORK", 0)
        btn.icon:SetAlpha(1)
        btn.icon:Show()
    end

    -- --------------------------------------------------------
    -- RAND (BackdropTemplate)
    -- --------------------------------------------------------

    if not btn.border then

        btn.border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        btn.border:SetAllPoints(btn)
        btn.border:SetFrameLevel(btn:GetFrameLevel() + 2)
        btn.border:EnableMouse(false)
    end
    btn.border:EnableMouse(false)

    btn.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = RexUI.PixelBorder and RexUI:PixelBorder(cfg.borderSize) or cfg.borderSize,
    })
    btn.border:SetBackdropBorderColor(0, 0, 0, 0)
    if not btn.border.rexPixelLines then
        btn.border.rexPixelLines = CreatePixelLines(btn.border, 1, unpack(cfg.borderColor))
    end
    AB:SetButtonBorderColor(btn, unpack(cfg.borderColor))

    if not btn.innerBorder then
        btn.innerBorder = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        btn.innerBorder:SetFrameLevel(btn:GetFrameLevel() + 3)
        btn.innerBorder:EnableMouse(false)
    end
    btn.innerBorder:EnableMouse(false)
    btn.innerBorder:ClearAllPoints()
    btn.innerBorder:SetPoint("TOPLEFT", btn, "TOPLEFT", iconInset, -iconInset)
    btn.innerBorder:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -iconInset, iconInset)
    btn.innerBorder:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn.innerBorder:SetBackdropBorderColor(0, 0, 0, 0)

    -- --------------------------------------------------------
    -- HOVER HIGHLIGHT
    -- --------------------------------------------------------

    if not btn.hover then

        btn.hover = btn:CreateTexture(nil, "HIGHLIGHT")
        btn.hover:SetBlendMode("ADD")
    end
    btn.hover:SetTexture(AB.Media.hover)
    btn.hover:SetVertexColor(unpack(cfg.hoverColor))
    btn.hover:ClearAllPoints()
    btn.hover:SetPoint("TOPLEFT", btn, "TOPLEFT", iconInset, -iconInset)
    btn.hover:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -iconInset, iconInset)

    -- --------------------------------------------------------
    -- CLICK / PUSHED FEEDBACK
    -- --------------------------------------------------------

    if not btn.pushedOverlay then
        btn.pushedOverlay = btn:CreateTexture(nil, "OVERLAY", nil, 6)
        btn.pushedOverlay:SetAllPoints(btn.icon or btn)
    end
    btn.rexPressAlpha = cfg.pressAlpha or 0.18
    btn.pushedOverlay:ClearAllPoints()
    btn.pushedOverlay:SetPoint("TOPLEFT", btn, "TOPLEFT", iconInset, -iconInset)
    btn.pushedOverlay:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -iconInset, iconInset)
    btn.pushedOverlay:SetColorTexture(0, 0, 0, 1)
    btn.pushedOverlay:SetBlendMode("BLEND")
    btn.pushedOverlay:SetAlpha(0)
    if not btn.pushedOverlay.rexReleaseFade then
        local group = btn.pushedOverlay:CreateAnimationGroup()
        local fade = group:CreateAnimation("Alpha")
        fade:SetFromAlpha(0.10)
        fade:SetToAlpha(0)
        fade:SetDuration(0.08)
        if fade.SetSmoothing then
            fade:SetSmoothing("OUT")
        end
        group:SetScript("OnFinished", function()
            btn.pushedOverlay:SetAlpha(0)
        end)
        btn.pushedOverlay.rexReleaseFade = group
    end
    StylePushedTexture(btn, iconInset)

    if not btn.activeOverlay then
        btn.activeOverlay = btn:CreateTexture(nil, "OVERLAY", nil, 5)
        btn.activeOverlay:SetBlendMode("ADD")
    end
    btn.activeOverlay:ClearAllPoints()
    btn.activeOverlay:SetPoint("TOPLEFT", btn, "TOPLEFT", iconInset, -iconInset)
    btn.activeOverlay:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -iconInset, iconInset)
    btn.activeOverlay:SetColorTexture(unpack(cfg.activeOverlayColor or { 0, 0, 0, 0.16 }))
    btn.activeOverlay:SetAlpha(btn.rexActionActive == true and 1 or 0)

    -- --------------------------------------------------------
    -- COOLDOWN
    -- --------------------------------------------------------

    if btn.cooldown and cfg.showCooldown then

        btn.cooldown:SetAllPoints(btn.icon or btn)
        btn.cooldown:SetDrawEdge(false)
        if btn.cooldown.SetEdgeColor then
            btn.cooldown:SetEdgeColor(0.82, 0.86, 0.90, 0.85)
        end
        btn.cooldown.noCooldownCount = true
        btn.cooldown.noOCC = true
        btn.cooldown:SetHideCountdownNumbers(cfg.showCooldownText == false)
        btn.cooldown:SetSwipeColor(0, 0, 0, cfg.cooldownSwipeAlpha or 0.80)
        btn.cooldown:SetFrameLevel(btn:GetFrameLevel() + 1)
        btn.cooldown:EnableMouse(false)

        if btn.cooldown.GetRegions then
            for i = 1, btn.cooldown:GetNumRegions() do
                local region = select(i, btn.cooldown:GetRegions())
                if region and region.SetFont then
                    local ok, font = pcall(region.GetFont, region)
                    if ok then
                        pcall(region.SetFont, region, font or STANDARD_TEXT_FONT, 12, "OUTLINE")
                    end
                end
            end
        end
    end

    -- --------------------------------------------------------
    -- HOTKEY TEXT
    -- --------------------------------------------------------

    if not btn.hotkeyText then
        btn.hotkeyText = btn:CreateFontString(nil, "OVERLAY")
    end
    btn.hotkeyText:ClearAllPoints()
    btn.hotkeyText:SetDrawLayer("OVERLAY", 7)
    btn.hotkeyText:SetFont(ACTIONBAR_FONT, cfg.hotkeyFontSize or 9, "OUTLINE")
    btn.hotkeyText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -iconInset, -iconInset)
    btn.hotkeyText:SetWidth(math.max(1, (cfg.buttonSize or 34) - (iconInset * 2) - 2))
    btn.hotkeyText:SetHeight(math.max(1, (cfg.hotkeyFontSize or 9) + 2))
    btn.hotkeyText:SetJustifyH("RIGHT")
    btn.hotkeyText:SetTextColor(0.78, 0.78, 0.80, 1)
    btn.hotkeyText:SetShadowColor(0, 0, 0, 0.95)
    btn.hotkeyText:SetShadowOffset(1, -1)
    btn.hotkeyText:SetAlpha(cfg.showHotkey and 1 or 0)

    -- --------------------------------------------------------
    -- COUNT TEXT (Stack-Anzahl)
    -- --------------------------------------------------------

    if not btn.countText then
        btn.countText = btn:CreateFontString(nil, "OVERLAY")
    end
    btn.countText:ClearAllPoints()
    btn.countText:SetDrawLayer("OVERLAY", 7)
    btn.countText:SetFont(ACTIONBAR_FONT, cfg.countFontSize or 11, "OUTLINE")
    btn.countText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -iconInset, iconInset)
    btn.countText:SetJustifyH("RIGHT")
    btn.countText:SetTextColor(0.98, 0.98, 1, 1)
    btn.countText:SetShadowColor(0, 0, 0, 0.95)
    btn.countText:SetShadowOffset(1, -1)
    btn.countText:SetAlpha(cfg.showCount and 1 or 0)

    AB:ApplyButtonStateVisual(btn, cfg)

    -- --------------------------------------------------------
    -- HOVER SCRIPTS  (Border-Farbe)
    -- --------------------------------------------------------

    if not btn._styledHooks then

        btn._styledHooks = true

        btn:HookScript("OnEnter", function(self)
            local currentCfg = self.rexBarKey and AB:GetConfig(self.rexBarKey) or cfg
            self.rexHovered = true
            AB:ApplyButtonStateVisual(self, currentCfg)
        end)

        btn:HookScript("OnLeave", function(self)
            local currentCfg = self.rexBarKey and AB:GetConfig(self.rexBarKey) or cfg
            self.rexHovered = nil
            AB:ApplyButtonStateVisual(self, currentCfg)
        end)
    end
end
