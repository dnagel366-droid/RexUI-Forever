local ADDON_NAME, ns = ...
local RexUI = ns.RexUI

if not RexUI then
    return
end

local Skin = RexUI.BlizzardSkin

if not Skin then
    return
end

local function IsEnabled(key)
    local config = RexUI:GetProfile().blizzardSkin or {}
    if config.enabled == false then return false end
    if key and config[key] == false then return false end
    return true
end

local function ClearFrameTextures(frame)
    if not frame or not frame.GetRegions then return end
    for index = 1, select("#", frame:GetRegions()) do
        local region = select(index, frame:GetRegions())
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            if region.SetTexture then region:SetTexture(nil) end
            if region.SetAtlas then region:SetAtlas("") end
        end
    end
end

local function ApplyPlainPanel(frame, inset)
    if not frame or frame.IsForbidden and frame:IsForbidden() then return end
    inset = inset or 0
    if frame.NineSlice and frame.NineSlice.SetAlpha then frame.NineSlice:SetAlpha(0) end
    if not frame.RexUISkinBackground then
        local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
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
    frame.RexUISkinBorder:ClearAllPoints()
    frame.RexUISkinBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    frame.RexUISkinBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    Skin:SetBorderColor(frame.RexUISkinBorder, RexUI:GetColor("border"))
    frame.RexUISkinBorder:Show()
end

local function StyleFontString(fontString, colorKey)
    if not fontString or not fontString.SetTextColor then return end
    fontString:SetTextColor(RexUI:GetColor(colorKey or "text"))
end

local function HideButtonArt(button)
    if not button then return end
    local fontString = button.GetFontString and button:GetFontString()
    if button.GetRegions then
        for index = 1, select("#", button:GetRegions()) do
            local region = select(index, button:GetRegions())
            if region and region ~= fontString and region ~= button.RexUISkinButtonBackground and region ~= button.RexUISkinButtonHighlight and region.IsObjectType and region:IsObjectType("Texture") then
                if region.SetTexture then region:SetTexture(nil) end
                if region.SetAtlas then region:SetAtlas("") end
            end
        end
    end
end

local function RefreshButtonState(button)
    if not button then return end
    local enabled = not button.IsEnabled or button:IsEnabled()
    local fontString = button.GetFontString and button:GetFontString()
    if fontString then
        if enabled then fontString:SetTextColor(RexUI:GetColor("text"))
        else fontString:SetTextColor(RexUI:GetColor("mutedText")) end
    end
    if button.RexUISkinButtonBackground then
        button.RexUISkinButtonBackground:SetAlpha(enabled and 1 or 0.45)
    end
end

local function StyleButton(button)
    if not button or button.IsForbidden and button:IsForbidden() then return end
    HideButtonArt(button)
    if button.RexUISkinButton then RefreshButtonState(button) return end
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

local function StyleEditBox(editBox)
    if not editBox or editBox.IsForbidden and editBox:IsForbidden() then return end
    -- Preserve the native EditBox insertion caret. Clearing every texture can
    -- remove the blinking cursor together with the template artwork.
    for _, key in ipairs({ "Left", "Middle", "Right", "Background", "Border" }) do
        local texture = editBox[key]
        if texture and texture.SetAlpha then texture:SetAlpha(0) end
    end
    if editBox.NineSlice and editBox.NineSlice.SetAlpha then editBox.NineSlice:SetAlpha(0) end
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
    if editBox.SetTextColor then editBox:SetTextColor(RexUI:GetColor("text")) end
end

function Skin:StyleDungeonReadyDialog(frame)
    if not IsEnabled("lfgQueue") or not frame then return end
    ClearFrameTextures(frame)
    ApplyPlainPanel(frame, 4)
    if frame.CloseButton then Skin:StyleDialogButton(frame.CloseButton) end
    if frame.EnterButton then StyleButton(frame.EnterButton) end
    if frame.DeclineButton then StyleButton(frame.DeclineButton) end
    if frame.Title then StyleFontString(frame.Title, "highlight") end
    if frame.SubTitle then StyleFontString(frame.SubTitle, "text") end
    if frame.Timer then StyleFontString(frame.Timer, "highlight") end
end

function Skin:StyleRoleCheckPopup(frame)
    if not IsEnabled("lfgQueue") or not frame then return end
    ClearFrameTextures(frame)
    ApplyPlainPanel(frame, 4)
    if frame.AcceptButton then StyleButton(frame.AcceptButton) end
    if frame.DeclineButton then StyleButton(frame.DeclineButton) end
    for _, suffix in ipairs({"Tank", "Healer", "DPS"}) do
        local roleButton = frame["RoleButton" .. suffix]
        if roleButton then
            if roleButton.CheckButton then
                ClearFrameTextures(roleButton.CheckButton)
            end
            ClearFrameTextures(roleButton)
            local label = roleButton.GetFontString and roleButton:GetFontString()
            if label then StyleFontString(label) end
        end
    end
    if frame.Title then StyleFontString(frame.Title, "highlight") end
end

function Skin:StyleApplicationDialog(frame)
    if not IsEnabled("lfgQueue") or not frame then return end
    ApplyPlainPanel(frame, 4)
    if frame.SignUpButton then StyleButton(frame.SignUpButton) end
    if frame.CancelButton then StyleButton(frame.CancelButton) end
    if frame.Description then StyleEditBox(frame.Description) end
    if frame.Title then StyleFontString(frame.Title, "highlight") end
    for _, key in ipairs({"TankButton", "HealerButton", "DamagerButton"}) do
        local btn = frame[key]
        if btn then StyleFontString(btn.GetFontString and btn:GetFontString()) end
    end
end

function Skin:StyleInviteDialog(frame)
    if not IsEnabled("lfgQueue") or not frame then return end
    ApplyPlainPanel(frame, 4)
    if frame.AcceptButton then StyleButton(frame.AcceptButton) end
    if frame.DeclineButton then StyleButton(frame.DeclineButton) end
    if frame.AcknowledgeButton then StyleButton(frame.AcknowledgeButton) end
    if frame.Title then StyleFontString(frame.Title, "highlight") end
    if frame.Name then StyleFontString(frame.Name, "highlight") end
end

function Skin:StyleDialogButton(button)
    if not button or button.IsForbidden and button:IsForbidden() then return end
    HideButtonArt(button)
    if button.RexUISkinDialogButton then return end
    button.RexUISkinDialogButton = true
    local bg = button:CreateTexture(nil, "BACKGROUND", nil, -6)
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(RexUI:GetColor("border"))
    bg:SetAlpha(0.5)
    button.RexUISkinDialogBg = bg
end

function Skin:HookDungeonReadyDialog()
    local frame = _G.LFGDungeonReadyDialog
    if frame and not frame.RexUISkinLFGHooked then
        frame.RexUISkinLFGHooked = true
        frame:HookScript("OnShow", function(f)
            Skin:StyleDungeonReadyDialog(f)
        end)
    end
end

function Skin:HookRoleCheckPopup()
    local frame = _G.LFDRoleCheckPopup
    if frame and not frame.RexUISkinLFGHooked then
        frame.RexUISkinLFGHooked = true
        frame:HookScript("OnShow", function(f)
            Skin:StyleRoleCheckPopup(f)
        end)
    end
end

function Skin:HookApplicationDialog()
    local frame = _G.LFGListApplicationDialog
    if frame and not frame.RexUISkinLFGHooked then
        frame.RexUISkinLFGHooked = true
        frame:HookScript("OnShow", function(f)
            Skin:StyleApplicationDialog(f)
        end)
    end
end

function Skin:HookInviteDialog()
    local frame = _G.LFGListInviteDialog
    if frame and not frame.RexUISkinLFGHooked then
        frame.RexUISkinLFGHooked = true
        frame:HookScript("OnShow", function(f)
            Skin:StyleInviteDialog(f)
        end)
    end
end

function Skin:HookLFGPopups()
    self:HookDungeonReadyDialog()
    self:HookRoleCheckPopup()
    self:HookApplicationDialog()
    self:HookInviteDialog()
end
