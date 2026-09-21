local ADDON_NAME, ns = ...
local RexUI = ns.RexUI

if not RexUI then return end

local Skin = RexUI.BlizzardSkin
if not Skin then return end

local function GetConfig()
    local profile = RexUI:GetProfile()
    profile.blizzardSkin = profile.blizzardSkin or {}
    return profile.blizzardSkin
end

local function IsEnabled(key)
    local config = GetConfig()
    if config.enabled == false then return false end
    if key and config[key] == false then return false end
    return true
end

local function StyleFontString(fontString, colorKey)
    if not fontString or not fontString.SetTextColor then return end
    fontString:SetTextColor(RexUI:GetColor(colorKey or "text"))
end

local function KeepTextureHidden(texture)
    if not texture or not texture.SetAlpha then return end
    texture:SetAlpha(0)
    if texture.RexUISkinHiddenHooked then return end
    texture.RexUISkinHiddenHooked = true
    hooksecurefunc(texture, "SetAlpha", function(self, alpha)
        if alpha and alpha > 0 then self:SetAlpha(0) end
    end)
    if texture.Show then
        hooksecurefunc(texture, "Show", function(self) self:SetAlpha(0) end)
    end
end

function Skin:StyleQuickKeybindFrame(frame)
    if not IsEnabled("keybind") or not frame then return end

    if frame.NineSlice and frame.NineSlice.SetAlpha then
        frame.NineSlice:SetAlpha(0)
    end

    if frame.GetRegions then
        for index = 1, select("#", frame:GetRegions()) do
            local region = select(index, frame:GetRegions())
            if region
            and region.IsObjectType
            and region:IsObjectType("Texture") then
                if region.SetTexture then region:SetTexture(nil) end
                if region.SetAtlas then region:SetAtlas("") end
                KeepTextureHidden(region)
            end
        end
    end

    if not frame.RexUISkinBackground then
        local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame.RexUISkinBackground = bg
    end
    frame.RexUISkinBackground:SetColorTexture(RexUI:GetColor("panel"))

    if not frame.RexUISkinBorder then
        local border = Skin:CreateBorder(frame)
        border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        border:SetFrameLevel((frame:GetFrameLevel() or 1) + 1)
        frame.RexUISkinBorder = border
    end
    Skin:SetBorderColor(frame.RexUISkinBorder, RexUI:GetColor("border"))
    frame.RexUISkinBorder:Show()

    if frame.Text then StyleFontString(frame.Text, "highlight") end
    if frame.SubText then StyleFontString(frame.SubText, "text") end
    if frame.Label then StyleFontString(frame.Label, "text") end
end

function Skin:HookQuickKeybindFrame()
    local frame = _G.QuickKeybindFrame
    if frame and not frame.RexUISkinHooked then
        frame.RexUISkinHooked = true
        frame:HookScript("OnShow", function(f)
            Skin:StyleQuickKeybindFrame(f)
        end)
    end
end
