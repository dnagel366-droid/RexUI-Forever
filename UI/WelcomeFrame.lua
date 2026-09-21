local ADDON_NAME, ns = ...

local RexUI = ns.RexUI
if not RexUI then return end

RexUI.Welcome = RexUI.Welcome or {}
local Welcome = RexUI.Welcome

local TEXTURE_PATH = "Interface\\AddOns\\RexUI\\media\\welcome\\"
local ART_W, ART_H = 1024, 1024
local TEX_W, TEX_H = 1024, 1024

local function OpenConfigImport(frame)
    if RexUI.ConfigUI and RexUI.ConfigUI.Window and RexUI.ConfigUI.Open and RexUI.ConfigUI.SetCategory then
        frame:Hide()
        RexUI.ConfigUI:Open()
        RexUI.ConfigUI:SetCategory("Import")
    else
        RexUI:PrintMessage(RexUI:LocalizeText("Config noch nicht geladen."))
    end
end

local function FitFrame(frame)
    local parentW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
    local parentH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
    -- Keep the window smaller so bottom UI (Issue Reporter) stays clickable.
    local scale = math.min(0.70, (parentW - 96) / ART_W, (parentH - 200) / ART_H)
    if scale < 0.35 then
        scale = 0.35
    end
    frame:SetScale(scale)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 48)
    if frame.SetClampedToScreen then
        frame:SetClampedToScreen(true)
    end
end

function Welcome:Create()
    local isGerman = RexUI.isGerman == true
    if not isGerman and GetLocale then
        isGerman = GetLocale() == "deDE"
    end
    local textureName = isGerman and "welcome_forever" or "welcome_forever_enUS"

    local frame = CreateFrame("Frame", "RexUIWelcomeFrame", UIParent)
    frame:SetSize(ART_W, ART_H)
    frame:SetFrameStrata("HIGH")
    if frame.SetClipsChildren then
        frame:SetClipsChildren(true)
    end
    FitFrame(frame)

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(TEXTURE_PATH .. textureName)
    background:SetSize(TEX_W, TEX_H)
    background:ClearAllPoints()
    background:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)

    local button = CreateFrame("Button", nil, frame)
    button:SetSize(450, 76)
    button:SetPoint("BOTTOM", frame, "BOTTOM", 0, 68)
    button:SetFrameLevel(frame:GetFrameLevel() + 2)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.70, 0.29, 1.00, 0.12)

    button:SetScript("OnClick", function()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        elseif PlaySound then
            PlaySound(856)
        end
        OpenConfigImport(frame)
    end)

    frame:Hide()
    Welcome.frame = frame
end

function Welcome:Show()
    if not Welcome.frame then
        Welcome:Create()
    else
        FitFrame(Welcome.frame)
    end
    Welcome.frame:Show()
end
