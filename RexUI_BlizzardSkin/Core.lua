-- ============================================================
-- RexUI_BlizzardSkin - safe first-pass Blizzard UI skinning.
-- ============================================================

local ADDON_NAME, ns = ...
local RexUI = ns.RexUI

if not RexUI then
    return
end

local Skin = RexUI:CreateModule("BlizzardSkin")
RexUI.BlizzardSkin = Skin

local TOOLTIP_NAMES = {
    "GameTooltip",
    "ItemRefTooltip",
    "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "ShoppingTooltip3",
    "EmbeddedItemTooltip",
    "SettingsTooltip",
}

local POPUP_BUTTON_KEYS = {
    "Button1",
    "Button2",
    "Button3",
    "Button4",
    "ExtraButton",
}

local POPUP_BUTTON_COUNT = 4

local MENU_NAMES = {
    "DropDownList1",
    "DropDownList2",
    "DropDownList3",
}

local function GetConfig()
    local profile = RexUI:GetProfile()
    profile.blizzardSkin = profile.blizzardSkin or {}

    return profile.blizzardSkin
end

local function IsEnabled(key)
    local config = GetConfig()

    if config.enabled == false then
        return false
    end

    if key and config[key] == false then
        return false
    end

    return true
end

local function IsProtectedSpellbookFrame(frame)
    while frame do
        if frame == _G.PlayerSpellsFrame
        or frame == _G.SpellBookFrame then
            return true
        end

        frame = frame.GetParent and frame:GetParent()
    end

    return false
end

local function SetRegionAlpha(frame, alpha)
    if not frame or not frame.GetRegions then
        return
    end

    for index = 1, select("#", frame:GetRegions()) do
        local region = select(index, frame:GetRegions())

        if region
        and region.IsObjectType
        and region:IsObjectType("Texture")
        and region.SetAlpha then
            region:SetAlpha(alpha or 0)
        end
    end
end

local function ClearFrameTextures(frame)
    if not frame or not frame.GetRegions then
        return
    end
    if IsProtectedSpellbookFrame(frame) then
        return
    end

    for index = 1, select("#", frame:GetRegions()) do
        local region = select(index, frame:GetRegions())

        if region
        and region.IsObjectType
        and region:IsObjectType("Texture")
        and region ~= frame.RexUISkinBackground then
            if region.SetTexture then
                region:SetTexture(nil)
            end

            if region.SetAtlas then
                region:SetAtlas("")
            end
        end
    end
end

local function KeepTextureHidden(texture)
    if not texture or not texture.SetAlpha then
        return
    end

    texture:SetAlpha(0)

    if texture.RexUISkinHiddenHooked then
        return
    end

    texture.RexUISkinHiddenHooked = true

    hooksecurefunc(texture, "SetAlpha", function(self, alpha)
        if alpha and alpha > 0 then
            self:SetAlpha(0)
        end
    end)

    if texture.Show then
        hooksecurefunc(texture, "Show", function(self)
            self:SetAlpha(0)
        end)
    end
end

local function HideButtonArt(button)
    if not button then
        return
    end
    if IsProtectedSpellbookFrame(button) then
        return
    end

    local fontString = button.GetFontString and button:GetFontString()

    if button.GetRegions then
        for index = 1, select("#", button:GetRegions()) do
            local region = select(index, button:GetRegions())

            if region
            and region ~= fontString
            and region ~= button.RexUISkinButtonBackground
            and region ~= button.RexUISkinButtonHighlight
            and region.IsObjectType
            and region:IsObjectType("Texture") then
                if region.SetTexture then
                    region:SetTexture(nil)
                end

                if region.SetAtlas then
                    region:SetAtlas("")
                end

                KeepTextureHidden(region)
            end
        end
    end

    KeepTextureHidden(button.Left)
    KeepTextureHidden(button.Middle)
    KeepTextureHidden(button.Right)
end

local function GetStaticPopupButton(popup, index)
    if not popup then
        return nil
    end

    local button =
        popup["button" .. index]
        or popup["Button" .. index]

    if button then
        return button
    end

    local popupName = popup.GetName and popup:GetName()
    if popupName then
        return _G[popupName .. "Button" .. index]
    end
end

local function RefreshButtonState(button)
    if not button then
        return
    end

    local enabled =
        not button.IsEnabled
        or button:IsEnabled()

    local fontString = button.GetFontString and button:GetFontString()
    if fontString then
        if enabled then
            fontString:SetTextColor(RexUI:GetColor("text"))
        else
            fontString:SetTextColor(RexUI:GetColor("mutedText"))
        end
    end

    if button.RexUISkinButtonBackground then
        button.RexUISkinButtonBackground:SetAlpha(enabled and 1 or 0.45)
    end
end

function Skin:CreateBorder(parent)
    local border = CreateFrame("Frame", nil, parent)
    local es = RexUI.PixelBorder and RexUI:PixelBorder(1) or 1
    local tex = {}
    tex.TOP = border:CreateTexture(nil, "ARTWORK")
    tex.BOTTOM = border:CreateTexture(nil, "ARTWORK")
    tex.LEFT = border:CreateTexture(nil, "ARTWORK")
    tex.RIGHT = border:CreateTexture(nil, "ARTWORK")
    tex.TOP:SetPoint("TOPLEFT", border, "TOPLEFT")
    tex.TOP:SetPoint("TOPRIGHT", border, "TOPRIGHT")
    tex.TOP:SetHeight(es)
    tex.BOTTOM:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT")
    tex.BOTTOM:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT")
    tex.BOTTOM:SetHeight(es)
    tex.LEFT:SetPoint("TOPLEFT", border, "TOPLEFT")
    tex.LEFT:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT")
    tex.LEFT:SetWidth(es)
    tex.RIGHT:SetPoint("TOPRIGHT", border, "TOPRIGHT")
    tex.RIGHT:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT")
    tex.RIGHT:SetWidth(es)
    border._RexTex = tex
    border:EnableMouse(false)
    return border
end

function Skin:SetBorderColor(border, ...)
    if not border or not border._RexTex then return end
    local r, g, b, a
    local first = ...
    if type(first) == "table" then
        r, g, b, a = first[1], first[2], first[3], first[4]
    else
        r, g, b, a = ...
    end
    if not r then return end
    g, b, a = g or r, b or r, a or 1
    for _, tex in pairs(border._RexTex) do
        tex:SetColorTexture(r, g, b, a)
    end
end

local function StyleEditBox(editBox)
    if not editBox
    or editBox.IsForbidden and editBox:IsForbidden() then
        return
    end

    -- Do not clear every EditBox texture here. Blizzard can expose the
    -- insertion caret as an EditBox-owned texture, so clearing all regions
    -- also makes the blinking text cursor disappear. Hide only the template
    -- artwork we replace with the RexUI background and border.
    KeepTextureHidden(editBox.Left)
    KeepTextureHidden(editBox.Middle)
    KeepTextureHidden(editBox.Right)
    KeepTextureHidden(editBox.Background)
    KeepTextureHidden(editBox.Border)

    if editBox.NineSlice and editBox.NineSlice.SetAlpha then
        editBox.NineSlice:SetAlpha(0)
    end

    if not editBox.RexUISkinEditBoxBackground then
        local bg = editBox:CreateTexture(nil, "BACKGROUND", nil, -6)
        bg:SetPoint("TOPLEFT", editBox, "TOPLEFT", 0, 0)
        bg:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 0, 0)
        editBox.RexUISkinEditBoxBackground = bg
    end

    editBox.RexUISkinEditBoxBackground:SetColorTexture(RexUI:GetColor("panel"))

    if not editBox.RexUISkinEditBoxBorder then
        local border = Skin:CreateBorder(editBox)
        border:SetPoint("TOPLEFT", editBox, "TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 0, 0)
        border:SetFrameLevel((editBox:GetFrameLevel() or 1) + 1)
        editBox.RexUISkinEditBoxBorder = border
    end
    Skin:SetBorderColor(editBox.RexUISkinEditBoxBorder, RexUI:GetColor("border"))

    if editBox.SetTextColor then
        editBox:SetTextColor(RexUI:GetColor("text"))
    end

    if editBox.SetHighlightColor then
        local r, g, b = RexUI:GetColor("highlight")
        editBox:SetHighlightColor(r, g, b, 0.35)
    end

    local function RefreshEditBoxFocus(frame)
        if not frame.RexUISkinEditBoxBorder then return end

        if frame:HasFocus() then
            Skin:SetBorderColor(
                frame.RexUISkinEditBoxBorder,
                RexUI:GetColor("highlight")
            )
        else
            Skin:SetBorderColor(
                frame.RexUISkinEditBoxBorder,
                RexUI:GetColor("border")
            )
        end
    end

    if not editBox.RexUISkinEditBoxFocusHooked then
        editBox.RexUISkinEditBoxFocusHooked = true
        editBox:HookScript("OnEditFocusGained", RefreshEditBoxFocus)
        editBox:HookScript("OnEditFocusLost", RefreshEditBoxFocus)
    end

    RefreshEditBoxFocus(editBox)
end

local function GetLayer(frame, layer, subLevel)
    local texture = frame:CreateTexture(nil, layer or "BACKGROUND", nil, subLevel or 0)
    texture:SetAllPoints(frame)

    return texture
end

local function ApplyPlainPanel(frame, inset)
    if not frame or frame.IsForbidden and frame:IsForbidden() then
        return
    end
    if IsProtectedSpellbookFrame(frame) then
        return
    end

    inset = inset or 0

    if frame.NineSlice and frame.NineSlice.SetAlpha then
        frame.NineSlice:SetAlpha(0)
    end

    if not frame.RexUISkinBackground then
        local bg = GetLayer(frame, "BACKGROUND", -7)
        frame.RexUISkinBackground = bg
    end

    frame.RexUISkinBackground:ClearAllPoints()
    frame.RexUISkinBackground:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    frame.RexUISkinBackground:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    frame.RexUISkinBackground:SetColorTexture(RexUI:GetColor("background"))

    if not frame.RexUISkinBorder then
        local border = Skin:CreateBorder(frame)
        border:SetFrameLevel((frame:GetFrameLevel() or 1) + 1)
        frame.RexUISkinBorder = border
    end

    local b = frame.RexUISkinBorder
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    b:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    Skin:SetBorderColor(b, RexUI:GetColor("border"))
    b:Show()
end

local function StyleFontString(fontString, colorKey)
    if not fontString or not fontString.SetTextColor then
        return
    end

    fontString:SetTextColor(RexUI:GetColor(colorKey or "text"))
end

local function StyleButton(button)
    if not button
    or button.IsForbidden and button:IsForbidden() then
        return
    end
    if IsProtectedSpellbookFrame(button) then
        return
    end

    HideButtonArt(button)

    if button.RexUISkinButton then
        RefreshButtonState(button)
        return
    end

    button.RexUISkinButton = true

    local bg = button:CreateTexture(nil, "BACKGROUND", nil, -6)
    bg:SetPoint("TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", -2, 2)
    bg:SetColorTexture(RexUI:GetColor("panel"))
    button.RexUISkinButtonBackground = bg

    local border = Skin:CreateBorder(button)
    border:SetPoint("TOPLEFT", 2, -2)
    border:SetPoint("BOTTOMRIGHT", -2, 2)
    border:SetFrameLevel((button:GetFrameLevel() or 1) + 1)
    Skin:SetBorderColor(border, RexUI:GetColor("border"))
    button.RexUISkinButtonBorder = border

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", 2, -2)
    highlight:SetPoint("BOTTOMRIGHT", -2, 2)
    highlight:SetColorTexture(RexUI:GetColor("hover"))
    highlight:SetAlpha(0.25)
    button.RexUISkinButtonHighlight = highlight

    StyleFontString(button:GetFontString(), "text")
    RefreshButtonState(button)

    button:HookScript("OnEnable", RefreshButtonState)
    button:HookScript("OnDisable", RefreshButtonState)

    button:HookScript("OnEnter", function(self)
        if self.RexUISkinButtonBorder then
            Skin:SetBorderColor(self.RexUISkinButtonBorder, RexUI:GetColor("highlight"))
        end
    end)

    button:HookScript("OnLeave", function(self)
        if self.RexUISkinButtonBorder then
            Skin:SetBorderColor(self.RexUISkinButtonBorder, RexUI:GetColor("border"))
        end
    end)
end

function Skin:StyleTooltip(tooltip)
    if not IsEnabled("tooltips") or not tooltip then
        return
    end

    ApplyPlainPanel(tooltip, 0)
end

function Skin:StyleStaticPopup(popup)
    if not IsEnabled("staticPopups") or not popup then
        return
    end

    ClearFrameTextures(popup)

    if popup.BG and popup.BG.SetAlpha then
        popup.BG:SetAlpha(0)
    end

    ApplyPlainPanel(popup, 0)

    for index = 1, POPUP_BUTTON_COUNT do
        local button = GetStaticPopupButton(popup, index)
        StyleButton(button)
        RefreshButtonState(button)
    end

    for _, key in ipairs(POPUP_BUTTON_KEYS) do
        StyleButton(popup[key])
        RefreshButtonState(popup[key])
    end

    if popup.UpdateRecapButton and not popup.RexUISkinRecapHooked then
        popup.RexUISkinRecapHooked = true

        hooksecurefunc(popup, "UpdateRecapButton", function(frame)
            for index = 1, POPUP_BUTTON_COUNT do
                RefreshButtonState(GetStaticPopupButton(frame, index))
            end
        end)
    end

    local editBox =
        popup.editBox
        or popup.EditBox
        or (popup.GetName and _G[popup:GetName() .. "EditBox"])

    if editBox then
        StyleEditBox(editBox)
    end
end

function Skin:StyleDropdownMenu(menu)
    if not IsEnabled("dropdownMenus") or not menu then
        return
    end

    ApplyPlainPanel(menu, 0)
end

function Skin:StyleContextMenu(menu)
    if not IsEnabled("dropdownMenus")
    or not menu
    or menu.IsForbidden and menu:IsForbidden() then
        return
    end

    -- Modern Blizzard menu compositor frames disallow CreateTexture/CreateFontString.
    -- Keep this path readjust-only: recolor existing textures, create nothing.
    if menu.NineSlice and menu.NineSlice.SetAlpha then
        menu.NineSlice:SetAlpha(0)
    end

    if menu.GetRegions then
        for index = 1, select("#", menu:GetRegions()) do
            local region = select(index, menu:GetRegions())

            if region
            and region ~= menu.RexUISkinBackground
            and region.IsObjectType
            and region:IsObjectType("Texture") then
                region:SetColorTexture(RexUI:GetColor("background"))
                region:SetAlpha(0.96)
                region:ClearAllPoints()
                region:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -1)
                region:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -1, 1)
            end
        end
    end
end

local RexUIGameMenuHooked = false

function Skin:StyleGameMenu()
    if not IsEnabled("gameMenu") or not GameMenuFrame then
        return
    end

    ApplyPlainPanel(GameMenuFrame, 4)

    if GameMenuFrame.Header and GameMenuFrame.Header.Text then
        StyleFontString(GameMenuFrame.Header.Text, "highlight")
    end

    if GameMenuFrame.buttonPool and GameMenuFrame.buttonPool.EnumerateActive then
        for button in GameMenuFrame.buttonPool:EnumerateActive() do
            StyleButton(button)
        end
    end
end

local function EnsureRexUIGameMenuHook()
    if RexUIGameMenuHooked or not GameMenuFrame then return end
    RexUIGameMenuHooked = true

    local rexButton
    local function openRexUI()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        HideUIPanel(GameMenuFrame)
        if RexUI.ConfigUI and RexUI.ConfigUI.Toggle then
            RexUI.ConfigUI:Toggle()
        end
    end

    hooksecurefunc(GameMenuFrame, "Reset", function()
        rexButton = nil
    end)

    hooksecurefunc(GameMenuFrame, "Layout", function()
        if not rexButton then
            rexButton = GameMenuFrame:AddButton("RexUI", openRexUI)
            if rexButton and StyleButton then
                StyleButton(rexButton)
            end
        end
        if not rexButton then return end
        if not GameMenuFrame.buttonPool or not GameMenuFrame.buttonPool.EnumerateActive then return end

        local anchorBtn
        for menuBtn in GameMenuFrame.buttonPool:EnumerateActive() do
            if menuBtn ~= rexButton then
                local text = menuBtn:GetText()
                if text == GAMEMENU_OPTIONS then
                    anchorBtn = menuBtn
                    break
                end
            end
        end
        if not anchorBtn then return end

        local anchorBottom = anchorBtn:GetBottom()
        if not anchorBottom then return end

        local offset = 4
        rexButton:ClearAllPoints()
        rexButton:SetPoint("TOP", anchorBtn, "BOTTOM", 0, -offset)

        local dy = rexButton:GetHeight() + offset
        for menuBtn in GameMenuFrame.buttonPool:EnumerateActive() do
            if menuBtn ~= rexButton and menuBtn ~= anchorBtn then
                local top = menuBtn:GetTop()
                if top and top < anchorBottom + 2 then
                    local p, rel, rp, x, y = menuBtn:GetPoint(1)
                    if p then
                        menuBtn:ClearAllPoints()
                        menuBtn:SetPoint(p, rel, rp, x, (y or 0) - dy)
                    end
                end
            end
        end
    end)
end

function Skin:HookTooltips()
    for _, name in ipairs(TOOLTIP_NAMES) do
        local tooltip = _G[name]

        if tooltip and not tooltip.RexUISkinHooked then
            tooltip.RexUISkinHooked = true
            tooltip:HookScript("OnShow", function(frame)
                Skin:StyleTooltip(frame)
            end)
        end
    end

    if TooltipDataProcessor
    and TooltipDataProcessor.AddTooltipPostCall
    and Enum
    and Enum.TooltipDataType
    and not self.TooltipProcessorHooked then
        self.TooltipProcessorHooked = true

        local function addTooltipPostCall(tooltipType)
            if tooltipType then
                TooltipDataProcessor.AddTooltipPostCall(tooltipType, function(tooltip)
                    Skin:StyleTooltip(tooltip)
                end)
            end
        end

        addTooltipPostCall(Enum.TooltipDataType.Item)
        addTooltipPostCall(Enum.TooltipDataType.Spell)
        addTooltipPostCall(Enum.TooltipDataType.Unit)
    end
end

function Skin:HookStaticPopups()
    for index = 1, STATICPOPUP_NUMDIALOGS or 4 do
        local popup = _G["StaticPopup" .. index]

        if popup and not popup.RexUISkinHooked then
            popup.RexUISkinHooked = true
            popup:HookScript("OnShow", function(frame)
                Skin:StyleStaticPopup(frame)
            end)
        end
    end
end

function Skin:HookDropdownMenus()
    for _, name in ipairs(MENU_NAMES) do
        local menu = _G[name]

        if menu and not menu.RexUISkinHooked then
            menu.RexUISkinHooked = true
            menu:HookScript("OnShow", function(frame)
                Skin:StyleDropdownMenu(frame)
            end)
        end
    end
end

function Skin:HookContextMenus()
    if self.ContextMenusHooked
    or not Menu
    or not Menu.GetManager then
        return
    end

    local manager = Menu.GetManager()
    if not manager then
        return
    end

    self.ContextMenusHooked = true

    local function styleOpenMenu(menuDescription)
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if manager.GetOpenMenu then
                    Skin:StyleContextMenu(manager:GetOpenMenu())
                end

                if menuDescription and menuDescription.AddMenuAcquiredCallback then
                    menuDescription:AddMenuAcquiredCallback(function(frame)
                        C_Timer.After(0, function()
                            Skin:StyleContextMenu(frame)
                        end)
                    end)
                end
            end)
        elseif manager.GetOpenMenu then
            Skin:StyleContextMenu(manager:GetOpenMenu())
        end
    end

    if manager.OpenMenu then
        hooksecurefunc(manager, "OpenMenu", function(_, _, menuDescription)
            styleOpenMenu(menuDescription)
        end)
    end

    if manager.OpenContextMenu then
        hooksecurefunc(manager, "OpenContextMenu", function(_, _, menuDescription)
            styleOpenMenu(menuDescription)
        end)
    end
end

function Skin:HookGameMenu()
    if self.GameMenuHooked or not GameMenuFrame then
        return
    end

    self.GameMenuHooked = true

    EnsureRexUIGameMenuHook()

    if GameMenuFrame.InitButtons then
        hooksecurefunc(GameMenuFrame, "InitButtons", function()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    Skin:StyleGameMenu()
                end)
            else
                Skin:StyleGameMenu()
            end
        end)
    end

    GameMenuFrame:HookScript("OnShow", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                Skin:StyleGameMenu()
            end)
        else
            Skin:StyleGameMenu()
        end
    end)
end

local function StyleCloseButton(button)
    if not button or button.IsForbidden and button:IsForbidden() then return end
    if button.RexUISkinCloseButton then return end
    button.RexUISkinCloseButton = true
    ClearFrameTextures(button)
    if button.NormalTexture then KeepTextureHidden(button.NormalTexture) end
    if button.PushedTexture then KeepTextureHidden(button.PushedTexture) end
    if button.HighlightTexture then KeepTextureHidden(button.HighlightTexture) end
    if button.DisabledTexture then KeepTextureHidden(button.DisabledTexture) end
    local x = button:CreateFontString(nil, "OVERLAY")
    x:SetFont("Fonts\\FRIZQT__.TTF", 16, "")
    x:SetText("x")
    x:SetTextColor(RexUI:GetColor("text"))
    x:SetAlpha(0.5)
    x:SetPoint("CENTER", -2, -2)
    button.RexUISkinCloseX = x
    button:HookScript("OnEnter", function(self)
        if self.RexUISkinCloseX then self.RexUISkinCloseX:SetAlpha(0.9) end
    end)
    button:HookScript("OnLeave", function(self)
        if self.RexUISkinCloseX then self.RexUISkinCloseX:SetAlpha(0.5) end
    end)
end

local function StyleActivityCard(frame, isSelected)
    if not frame or frame.IsForbidden and frame:IsForbidden() then return end
    ClearFrameTextures(frame)
    if frame.Border then KeepTextureHidden(frame.Border) end
    if frame.SelectedTexture then KeepTextureHidden(frame.SelectedTexture) end
    if frame.ItemGlow then KeepTextureHidden(frame.ItemGlow) end
    if frame.UnselectedFrame then frame.UnselectedFrame:SetAlpha(0) end
    if frame.Background then KeepTextureHidden(frame.Background) end

    if not frame.RexUISkinCardBg then
        local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        bg:SetPoint("TOPLEFT", 3, -3)
        bg:SetPoint("BOTTOMRIGHT", -3, 3)
        frame.RexUISkinCardBg = bg
    end
    frame.RexUISkinCardBg:SetColorTexture(RexUI:GetColor("panel"))
    frame.RexUISkinCardBg:SetAlpha(0.8)

    if not frame.RexUISkinCardBorder then
        local border = Skin:CreateBorder(frame)
        border:SetFrameLevel((frame:GetFrameLevel() or 1) + 1)
        frame.RexUISkinCardBorder = border
    end
    local cb = frame.RexUISkinCardBorder
    cb:ClearAllPoints()
    cb:SetPoint("TOPLEFT", 3, -3)
    cb:SetPoint("BOTTOMRIGHT", -3, 3)
    Skin:SetBorderColor(cb, RexUI:GetColor(isSelected and "highlight" or "border"))
    cb:SetAlpha(isSelected and 1 or 0.5)
    cb:Show()

    if frame.Threshold then StyleFontString(frame.Threshold, "mutedText") end
    if frame.Progress then StyleFontString(frame.Progress, "text") end

    if frame.ItemFrame then
        if frame.ItemFrame.Icon then
            local iconFile = frame.ItemFrame.Icon:GetTexture()
            ClearFrameTextures(frame.ItemFrame)
            frame.ItemFrame.Icon:SetTexture(iconFile)
            frame.ItemFrame.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            frame.ItemFrame.Icon:Show()
        else
            ClearFrameTextures(frame.ItemFrame)
        end
    end

    if frame.UncollectedGlow then
        KeepTextureHidden(frame.UncollectedGlow)
    end
end

local function StyleCharacterTabs(selected)
    selected = selected or (_G.CharacterFrame and _G.CharacterFrame.selectedTab) or 1
    for i = 1, 3 do
        local tab = _G["CharacterFrameTab" .. i]
        if tab then
            ClearFrameTextures(tab)
            if tab.Left then tab.Left:SetTexture(nil) end
            if tab.Middle then tab.Middle:SetTexture(nil) end
            if tab.Right then tab.Right:SetTexture(nil) end
            if tab.LeftDisabled then tab.LeftDisabled:SetTexture(nil) end
            if tab.MiddleDisabled then tab.MiddleDisabled:SetTexture(nil) end
            if tab.RightDisabled then tab.RightDisabled:SetTexture(nil) end
            local hl = tab:GetHighlightTexture()
            if hl then hl:SetTexture(nil) end
            if tab.RexUISkinTabBg then
                tab.RexUISkinTabBg:SetColorTexture(RexUI:GetColor("panel"))
            else
                local bg = tab:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(RexUI:GetColor("panel"))
                tab.RexUISkinTabBg = bg
            end
            if not tab.RexUISkinTabUnderline then
                local ul = tab:CreateTexture(nil, "OVERLAY")
                ul:SetHeight(2)
                ul:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
                ul:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
                ul:SetColorTexture(RexUI:GetColor("highlight"))
                ul:Hide()
                tab.RexUISkinTabUnderline = ul
            end
            if tab:GetFontString() then
                if i == selected then
                    tab:GetFontString():SetTextColor(RexUI:GetColor("highlight"))
                else
                    tab:GetFontString():SetTextColor(RexUI:GetColor("mutedText"))
                end
            end
            if tab.RexUISkinTabUnderline then
                tab.RexUISkinTabUnderline:SetShown(i == selected)
            end
        end
    end
end

local CHARACTER_EQUIPMENT_SLOTS = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot",
    "TabardSlot", "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot", "MainHandSlot",
    "SecondaryHandSlot",
}

local SLOT_HEAD = INVSLOT_HEAD or 1
local SLOT_NECK = INVSLOT_NECK or 2
local SLOT_SHOULDER = INVSLOT_SHOULDER or 3
local SLOT_BODY = INVSLOT_BODY or 4
local SLOT_CHEST = INVSLOT_CHEST or 5
local SLOT_WAIST = INVSLOT_WAIST or 6
local SLOT_LEGS = INVSLOT_LEGS or 7
local SLOT_FEET = INVSLOT_FEET or 8
local SLOT_WRIST = INVSLOT_WRIST or 9
local SLOT_HAND = INVSLOT_HAND or 10
local SLOT_FINGER1 = INVSLOT_FINGER1 or 11
local SLOT_FINGER2 = INVSLOT_FINGER2 or 12
local SLOT_TRINKET1 = INVSLOT_TRINKET1 or 13
local SLOT_TRINKET2 = INVSLOT_TRINKET2 or 14
local SLOT_BACK = INVSLOT_BACK or 15
local SLOT_MAINHAND = INVSLOT_MAINHAND or 16
local SLOT_OFFHAND = INVSLOT_OFFHAND or INVSLOT_SECONDARYHAND or 17
local SLOT_TABARD = INVSLOT_TABARD or 19

local CHARACTER_LEFT_SLOTS = {
    [SLOT_HEAD] = true,
    [SLOT_NECK] = true,
    [SLOT_SHOULDER] = true,
    [SLOT_BACK] = true,
    [SLOT_CHEST] = true,
    [SLOT_BODY] = true,
    [SLOT_TABARD] = true,
    [SLOT_WRIST] = true,
}

local CHARACTER_RIGHT_SLOTS = {
    [SLOT_HAND] = true,
    [SLOT_WAIST] = true,
    [SLOT_LEGS] = true,
    [SLOT_FEET] = true,
    [SLOT_FINGER1] = true,
    [SLOT_FINGER2] = true,
    [SLOT_TRINKET1] = true,
    [SLOT_TRINKET2] = true,
}

local CHARACTER_BOTTOM_SLOTS = {
    [SLOT_MAINHAND] = true,
    [SLOT_OFFHAND] = true,
}

local function CharacterSlotCanHaveEnchant(slotID)
    return slotID == SLOT_HEAD
        or slotID == SLOT_SHOULDER
        or slotID == SLOT_BACK
        or slotID == SLOT_CHEST
        or slotID == SLOT_WRIST
        or slotID == SLOT_LEGS
        or slotID == SLOT_FEET
        or slotID == SLOT_FINGER1
        or slotID == SLOT_FINGER2
        or slotID == SLOT_MAINHAND
        or slotID == SLOT_OFFHAND
end

local function CharacterSlotCanShowGems(slotID)
    return slotID == SLOT_NECK
end

local function GetItemEnchantId(itemLink)
    if not itemLink then return 0 end
    local _, enchantId = itemLink:match("item:(%d+):(%d+)")
    return tonumber(enchantId) or 0
end

local function CleanEnchantText(text)
    if not text or text == "" then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    text = text:gsub("^Verzaubert:%s*", "")
    text = text:gsub("^Enchanted:%s*", "")
    if text == "" then return nil end
    return text
end

local function GetEquippedEnchantName(slotID)
    if not slotID then return nil end

    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slotID)
        if ok and data and data.lines then
            local enchantLineType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemEnchantmentPermanent or 15
            for _, line in ipairs(data.lines) do
                if TooltipUtil and TooltipUtil.SurfaceArgs then
                    pcall(TooltipUtil.SurfaceArgs, line)
                end

                if line and line.type == enchantLineType then
                    local text = CleanEnchantText(line.leftText)
                    if text then return text end
                end
            end

            for index, line in ipairs(data.lines) do
                local text = CleanEnchantText(line and line.leftText)
                local color = line and line.leftColor
                local isGreen = color and color.g and color.g > 0.75 and (color.r or 0) < 0.35
                if index > 1 and text and isGreen then
                    return text
                end
            end
        end
    end

    if _G.CreateFrame then
        local scanner = _G.RexUIEnchantScannerTooltip
        if not scanner then
            scanner = CreateFrame("GameTooltip", "RexUIEnchantScannerTooltip", UIParent, "GameTooltipTemplate")
            scanner:SetOwner(UIParent, "ANCHOR_NONE")
            _G.RexUIEnchantScannerTooltip = scanner
        end

        scanner:ClearLines()
        scanner:SetInventoryItem("player", slotID)
        for index = 2, scanner:NumLines() do
            local line = _G["RexUIEnchantScannerTooltipTextLeft" .. index]
            local text = CleanEnchantText(line and line:GetText())
            local r, g = 1, 1
            if line and line.GetTextColor then
                r, g = line:GetTextColor()
            end
            if text and g and g > 0.75 and (r or 0) < 0.35 then
                return text
            end
        end
    end

    return nil
end

local function GetGemText(itemLink)
    if not itemLink then return nil end

    local gems = {}
    if GetItemGem then
        for index = 1, 4 do
            local ok, gemName, gemLink = pcall(GetItemGem, itemLink, index)
            if ok then
                local text = gemName
                if (not text or text == "") and gemLink and C_Item and C_Item.GetItemInfo then
                    text = C_Item.GetItemInfo(gemLink)
                elseif (not text or text == "") and gemLink and GetItemInfo then
                    text = GetItemInfo(gemLink)
                end

                text = CleanEnchantText(text)
                if text then
                    gems[#gems + 1] = text
                end
            end
        end
    end

    if #gems == 0 then return nil end
    if #gems == 1 then return gems[1] end
    if #gems == 2 then return gems[1] .. " / " .. gems[2] end
    return gems[1] .. " +" .. tostring(#gems - 1)
end

local function PositionCharacterSlotText(slot)
    if not slot then return end
    local slotID = slot:GetID()
    local ilvl = slot.RexUIItemLevelText
    local enchant = slot.RexUIEnchantText

    if ilvl then ilvl:ClearAllPoints() end
    if enchant then enchant:ClearAllPoints() end

    if slotID <= 5 or slotID == 9 or slotID == 15 or slotID == (INVSLOT_TABARD or 19) then
        -- Links: Text rechts neben dem Slot (zur Mitte)
        if ilvl then
            ilvl:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 40, 3)
            ilvl:SetJustifyH("LEFT")
        end
        if enchant then
            enchant:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 45, 18)
            enchant:SetJustifyH("LEFT")
        end
    elseif (slotID >= 6 and slotID <= 8) or (slotID >= 10 and slotID <= 14) then
        -- Rechts: Text links neben dem Slot (zur Mitte)
        if ilvl then
            ilvl:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -40, 3)
            ilvl:SetJustifyH("RIGHT")
        end
        if enchant then
            enchant:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -45, 18)
            enchant:SetJustifyH("RIGHT")
        end
    else
        -- Waffen/Schild unter dem Slot
        if ilvl then
            ilvl:SetPoint("BOTTOM", slot, "BOTTOM", 0, 46)
            ilvl:SetJustifyH("CENTER")
        end
        if enchant then
            if slotID == 16 then
                enchant:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -40, 3)
                enchant:SetJustifyH("RIGHT")
            else
                enchant:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 40, 3)
                enchant:SetJustifyH("LEFT")
            end
        end
    end
end

local function EnsureCharacterSlotOverlay(slot)
    if not slot or slot.RexUICharacterInfoOverlay then return end
    slot.RexUICharacterInfoOverlay = true

    local ilvl = slot:CreateFontString(nil, "OVERLAY")
    ilvl:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    ilvl:SetWidth(42)
    slot.RexUIItemLevelText = ilvl

    local enchant = slot:CreateFontString(nil, "OVERLAY")
    enchant:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    enchant:SetWidth(118)
    if enchant.SetWordWrap then enchant:SetWordWrap(false) end
    if enchant.SetNonSpaceWrap then enchant:SetNonSpaceWrap(false) end
    if enchant.SetMaxLines then enchant:SetMaxLines(1) end
    slot.RexUIEnchantText = enchant

    PositionCharacterSlotText(slot)
end

local function UpdateCharacterSlotInfo(slot)
    if not slot then return end
    EnsureCharacterSlotOverlay(slot)
    PositionCharacterSlotText(slot)

    local slotID = slot:GetID()
    local itemLink = slotID and GetInventoryItemLink("player", slotID)

    if itemLink then
        if slotID == SLOT_BODY or slotID == SLOT_TABARD then
            slot.RexUIItemLevelText:Hide()
            slot.RexUIEnchantText:Hide()
            return
        end

        local ilvl = nil
        if GetDetailedItemLevelInfo then
            local ok, detailedIlvl = pcall(GetDetailedItemLevelInfo, itemLink)
            if ok then ilvl = detailedIlvl end
        end
        if not ilvl and GetItemInfo then
            local _, _, _, fallbackIlvl = GetItemInfo(itemLink)
            ilvl = fallbackIlvl
        end

        if ilvl and ilvl > 0 then
            slot.RexUIItemLevelText:SetFormattedText("%d", math.floor(ilvl + 0.5))
            slot.RexUIItemLevelText:SetTextColor(RexUI:GetColor("highlight"))
            slot.RexUIItemLevelText:Show()
        else
            slot.RexUIItemLevelText:Hide()
        end

        local extraText
        local extraR, extraG, extraB = 0.25, 1, 0.25
        if CharacterSlotCanHaveEnchant(slotID) then
            extraText = GetEquippedEnchantName(slotID)
        elseif CharacterSlotCanShowGems(slotID) then
            extraText = GetGemText(itemLink)
            extraR, extraG, extraB = 0.20, 0.75, 1.00
        end

        if CharacterSlotCanHaveEnchant(slotID) or CharacterSlotCanShowGems(slotID) then
            if extraText then
                slot.RexUIEnchantText:SetText(extraText)
                slot.RexUIEnchantText:SetTextColor(extraR, extraG, extraB, 1)
                slot.RexUIEnchantText:Show()
            else
                slot.RexUIEnchantText:Hide()
            end
        else
            slot.RexUIEnchantText:Hide()
        end
    else
        slot.RexUIItemLevelText:Hide()
        slot.RexUIEnchantText:Hide()
    end
end

local function UpdateCharacterEquipmentInfo()
    if not _G.CharacterFrame or not _G.CharacterFrame:IsShown() then return end
    local config = GetConfig()
    if config.enabled == false or config.characterSheet == false then return end

    for _, slotName in ipairs(CHARACTER_EQUIPMENT_SLOTS) do
        UpdateCharacterSlotInfo(_G["Character" .. slotName])
    end

    if _G.PaperDollFrame then
        if not _G.PaperDollFrame.RexUIAverageItemLevelText then
            local fs = _G.PaperDollFrame:CreateFontString(nil, "OVERLAY")
            fs:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
            fs:SetPoint("TOP", _G.PaperDollFrame, "TOP", 0, -12)
            fs:SetTextColor(RexUI:GetColor("highlight"))
            _G.PaperDollFrame.RexUIAverageItemLevelText = fs
        end

        local avg = 0
        if GetAverageItemLevel then
            local equipped = select(2, GetAverageItemLevel())
            avg = equipped or 0
        end

        if avg and avg > 0 then
            _G.PaperDollFrame.RexUIAverageItemLevelText:SetFormattedText("%.2f", avg)
            _G.PaperDollFrame.RexUIAverageItemLevelText:Show()
        else
            _G.PaperDollFrame.RexUIAverageItemLevelText:Hide()
        end
    end
end

function Skin:StyleCharacterFrame(frame)
    if not frame then return end
    local config = GetConfig()
    if config.enabled == false or config.characterSheet == false then return end
    if frame.RexUISkinCharacterDone then return end
    frame.RexUISkinCharacterDone = true

    if frame.NineSlice then frame.NineSlice:SetAlpha(0) end
    if frame.Portrait then frame.Portrait:SetAlpha(0) end
    if frame.TitleBg then frame.TitleBg:SetAlpha(0) end
    if frame.TopTileStreaks then frame.TopTileStreaks:SetAlpha(0) end

    if CharacterFrameInset and CharacterFrameInset.NineSlice then
        CharacterFrameInset.NineSlice:SetAlpha(0)
    end
    if CharacterFrameInsetBG then CharacterFrameInsetBG:SetAlpha(0) end
    if CharacterFrameInset and CharacterFrameInset.Bg then
        CharacterFrameInset.Bg:SetAlpha(0)
    end
    if CharacterModelFrameBackgroundOverlay then CharacterModelFrameBackgroundOverlay:SetAlpha(0) end
    if CharacterModelFrameBackgroundTopLeft then CharacterModelFrameBackgroundTopLeft:SetAlpha(0) end
    if CharacterModelFrameBackgroundBotLeft then CharacterModelFrameBackgroundBotLeft:SetAlpha(0) end
    if CharacterModelFrameBackgroundTopRight then CharacterModelFrameBackgroundTopRight:SetAlpha(0) end
    if CharacterModelFrameBackgroundBotRight then CharacterModelFrameBackgroundBotRight:SetAlpha(0) end

    ClearFrameTextures(frame)

    ApplyPlainPanel(frame, 4)

    if CharacterFrameTitleText then
        StyleFontString(CharacterFrameTitleText, "highlight")
    end

    StyleCharacterTabs(frame.selectedTab)

    -- Style standalone PVP/Guild frames: background only, preserve all textures/layout
    local function StyleStandaloneBg(s)
        if not s or s.RexUISkinBgSet then return end
        s.RexUISkinBgSet = true
        local bg = s:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(RexUI:GetColor("panel"))
    end
    local standaloneNames = { "PVPFrame", "GuildFrame" }
    for _, sn in ipairs(standaloneNames) do
        local s = _G[sn]
        if s then
            StyleStandaloneBg(s)
            s:HookScript("OnShow", StyleStandaloneBg)
        end
    end

    for _, pane in ipairs({ _G.PaperDollFrame, _G.ReputationFrame, _G.TokenFrame }) do
        if pane and not pane.RexUISkinPaneHooked then
            pane.RexUISkinPaneHooked = true
            pane:HookScript("OnShow", function() StyleCharacterTabs() end)
        end
    end
    StyleCharacterTabs(frame.selectedTab)

    local closeBtn = frame.CloseButton or _G.CharacterFrameCloseButton
    if closeBtn then
        StyleCloseButton(closeBtn)
    end

    UpdateCharacterEquipmentInfo()
end

function Skin:HookCharacterFrame()
    local frame = _G.CharacterFrame
    if not frame or frame.RexUISkinHooked then return end
    frame.RexUISkinHooked = true

    local function FindAndStylePane(pane)
        if not pane then return end
        if not pane.RexUISkinBg then
            pane.RexUISkinBg = pane:CreateTexture(nil, "BACKGROUND")
            pane.RexUISkinBg:SetAllPoints()
            pane.RexUISkinBg:SetColorTexture(RexUI:GetColor("panel"))
        end
        for i = 1, pane:GetNumRegions() do
            local r = select(i, pane:GetRegions())
            if r and r:IsObjectType("FontString") then
                local txt = r:GetText()
                if txt and txt ~= "" then
                    r:SetTextColor(RexUI:GetColor("text"))
                end
            end
        end
    end

    local function FindVisibleContentPane()
        local byName = { _G.PaperDollFrame, _G.CharacterPVPFrame, _G.CharacterGuildFrame }
        for _, p in ipairs(byName) do if p and p:IsShown() then return p end end
        local inset = _G.CharacterFrameInset or frame
        for i = 1, inset:GetNumChildren() do
            local child = select(i, inset:GetChildren())
            if child and child:IsShown() and child:GetObjectType() == "Frame" and child ~= frame and (not child:GetName() or child:GetName() ~= "") then
                local w = child:GetWidth() or 0
                if w > 200 then return child end
            end
        end
    end

    local function StyleVisiblePane()
        FindAndStylePane(FindVisibleContentPane())
    end

    for ti = 1, 3 do
        local tab = _G["CharacterFrameTab" .. ti]
        if tab then
            tab:HookScript("OnClick", function()
                StyleVisiblePane()
                StyleCharacterTabs()
            end)
        end
    end

    frame:HookScript("OnShow", function(self)
        Skin:StyleCharacterFrame(self)
        C_Timer.After(0.1, StyleVisiblePane)
        C_Timer.After(0.1, UpdateCharacterEquipmentInfo)
    end)

    frame:HookScript("OnHide", function(self)
        self.RexUISkinCharacterDone = false
    end)

    if PanelTemplates_SelectTab then
        hooksecurefunc("PanelTemplates_SelectTab", function(f, idx)
            if f == _G.CharacterFrame then StyleCharacterTabs(idx) end
        end)
    end

    if not Skin.CharacterInfoEventFrame then
        local events = CreateFrame("Frame")
        Skin:RegisterEvents(events, { "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "GET_ITEM_INFO_RECEIVED" })
        events:SetScript("OnEvent", function(_, event, unit)
            if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
            UpdateCharacterEquipmentInfo()
            if C_Timer and C_Timer.After then
                C_Timer.After(0.2, UpdateCharacterEquipmentInfo)
            end
        end)
        Skin.CharacterInfoEventFrame = events
    end
end

function Skin:Refresh()
    self:StyleGameMenu()

    for _, name in ipairs(TOOLTIP_NAMES) do
        self:StyleTooltip(_G[name])
    end

    for index = 1, STATICPOPUP_NUMDIALOGS or 4 do
        self:StyleStaticPopup(_G["StaticPopup" .. index])
    end

    for _, name in ipairs(MENU_NAMES) do
        self:StyleDropdownMenu(_G[name])
    end

    self:StyleDungeonReadyDialog(_G.LFGDungeonReadyDialog)
    self:StyleRoleCheckPopup(_G.LFDRoleCheckPopup)
    self:StyleApplicationDialog(_G.LFGListApplicationDialog)
    self:StyleInviteDialog(_G.LFGListInviteDialog)
    self:StyleQuickKeybindFrame(_G.QuickKeybindFrame)
    self:StyleCharacterFrame(_G.CharacterFrame)
    Skin:StyleInspectFrame(_G.InspectFrame)
    self:RefreshChatConfig()
end

-- Hooks (hooksecurefunc/HookScript) lassen sich nicht zurücknehmen; ein Wechsel
-- der Skin-Option erfordert deshalb weiterhin einen Reload. Disable stellt aber
-- alle eigenen Event-Frames ruhig, sodass das Modul keine Arbeit mehr verrichtet.
function Skin:Enable()
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    if profile and profile.blizzardSkin and profile.blizzardSkin.enabled == false then
        self:Disable()
        return
    end
    self.enabled = true
    self:ResumeEvents()
end

function Skin:Disable()
    self.enabled = false
    self:SuspendEvents()
end

function Skin:Initialize()
    self:HookTooltips()
    self:HookStaticPopups()
    self:HookDropdownMenus()
    self:HookContextMenus()
    self:HookGameMenu()
    self:HookLFGPopups()
    self:HookQuickKeybindFrame()
    self:HookCharacterFrame()
    self:HookInspectFrame()
    self:HookFriendsFrame()
    self:HookChat()

    self:Refresh()
end
