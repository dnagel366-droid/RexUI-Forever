local ADDON_NAME, ns = ...
local RexUI = ns.RexUI

if not RexUI then return end

local Skin = RexUI.BlizzardSkin
if not Skin then return end

local function T(text)
    return RexUI:LocalizeText(text)
end

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

-- Weak-keyed lookup for InspectFrame internal state
local InspectFFD = setmetatable({}, { __mode = "k" })
local function IIFD(frame)
    local d = InspectFFD[frame]
    if not d then d = {}; InspectFFD[frame] = d end
    return d
end

local INSPECT_ALL_SLOTS = {
    "InspectHeadSlot", "InspectNeckSlot", "InspectShoulderSlot", "InspectBackSlot",
    "InspectChestSlot", "InspectShirtSlot", "InspectTabardSlot", "InspectWristSlot",
    "InspectHandsSlot", "InspectWaistSlot", "InspectLegsSlot", "InspectFeetSlot",
    "InspectTrinket0Slot", "InspectTrinket1Slot", "InspectFinger0Slot", "InspectFinger1Slot",
    "InspectMainHandSlot", "InspectSecondaryHandSlot",
}

local INSPECT_SLOT_GRID = {
    InspectHeadSlot = {col = 0, row = 0},
    InspectNeckSlot = {col = 0, row = 1},
    InspectShoulderSlot = {col = 0, row = 2},
    InspectBackSlot = {col = 0, row = 3},
    InspectChestSlot = {col = 0, row = 4},
    InspectShirtSlot = {col = 0, row = 5},
    InspectTabardSlot = {col = 0, row = 6},
    InspectWristSlot = {col = 0, row = 7},
    InspectHandsSlot = {col = 1, row = 0},
    InspectWaistSlot = {col = 1, row = 1},
    InspectLegsSlot = {col = 1, row = 2},
    InspectFeetSlot = {col = 1, row = 3},
    InspectFinger0Slot = {col = 1, row = 4},
    InspectFinger1Slot = {col = 1, row = 5},
    InspectTrinket0Slot = {col = 1, row = 6},
    InspectTrinket1Slot = {col = 1, row = 7},
    InspectMainHandSlot = {slot = "MainHand"},
    InspectSecondaryHandSlot = {slot = "SecondaryHand"},
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

local INSPECT_LEFT_SLOTS = {
    [SLOT_HEAD] = true,
    [SLOT_NECK] = true,
    [SLOT_SHOULDER] = true,
    [SLOT_BACK] = true,
    [SLOT_CHEST] = true,
    [SLOT_BODY] = true,
    [SLOT_TABARD] = true,
    [SLOT_WRIST] = true,
}

local INSPECT_RIGHT_SLOTS = {
    [SLOT_HAND] = true,
    [SLOT_WAIST] = true,
    [SLOT_LEGS] = true,
    [SLOT_FEET] = true,
    [SLOT_FINGER1] = true,
    [SLOT_FINGER2] = true,
    [SLOT_TRINKET1] = true,
    [SLOT_TRINKET2] = true,
}

local INSPECT_BOTTOM_SLOTS = {
    [SLOT_MAINHAND] = true,
    [SLOT_OFFHAND] = true,
}

local ENCHANT_SLOTS = {
    [SLOT_HEAD] = true,
    [SLOT_SHOULDER] = true,
    [SLOT_BACK] = true,
    [SLOT_CHEST] = true,
    [SLOT_WRIST] = true,
    [SLOT_LEGS] = true,
    [SLOT_FEET] = true,
    [SLOT_FINGER1] = true,
    [SLOT_FINGER2] = true,
    [SLOT_MAINHAND] = true,
    [SLOT_OFFHAND] = true,
}

local GEM_SLOTS = {
    [SLOT_NECK] = true,
}

local function GetEnchantId(itemLink)
    if not itemLink then return 0 end
    local _, id = itemLink:match("item:(%d+):(%d+)")
    return tonumber(id) or 0
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

local function GetInspectEnchantName(unit, slotID)
    if not unit or not slotID then return nil end

    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local ok, data = pcall(C_TooltipInfo.GetInventoryItem, unit, slotID)
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

local function PositionInspectSlotText(slot)
    if not slot then return end
    local slotID = slot:GetID()
    local ilvl = IIFD(slot).ilvlText
    local enchant = IIFD(slot).enchantText

    if ilvl then ilvl:ClearAllPoints() end
    if enchant then enchant:ClearAllPoints() end

    if INSPECT_LEFT_SLOTS[slotID] then
        if ilvl then
            ilvl:SetPoint("LEFT", slot, "RIGHT", 5, -8)
            ilvl:SetJustifyH("LEFT")
        end
        if enchant then
            enchant:SetPoint("LEFT", slot, "RIGHT", 5, 8)
            enchant:SetJustifyH("LEFT")
        end
    elseif INSPECT_RIGHT_SLOTS[slotID] then
        if ilvl then
            ilvl:SetPoint("RIGHT", slot, "LEFT", -5, -8)
            ilvl:SetJustifyH("RIGHT")
        end
        if enchant then
            enchant:SetPoint("RIGHT", slot, "LEFT", -5, 8)
            enchant:SetJustifyH("RIGHT")
        end
    elseif INSPECT_BOTTOM_SLOTS[slotID] then
        if ilvl then
            ilvl:SetPoint("BOTTOM", slot, "TOP", 0, 2)
            ilvl:SetJustifyH("CENTER")
        end
        if enchant then
            enchant:SetPoint("TOP", slot, "BOTTOM", 0, -2)
            enchant:SetJustifyH("CENTER")
        end
    end
end

local function EnsureInspectSlotInfo(slot)
    if not slot then return end

    if not IIFD(slot).ilvlText then
        local fs = slot:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        fs:SetWidth(42)
        IIFD(slot).ilvlText = fs
    end

    if not IIFD(slot).enchantText then
        local fs = slot:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
        fs:SetWidth(118)
        if fs.SetWordWrap then fs:SetWordWrap(false) end
        if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
        if fs.SetMaxLines then fs:SetMaxLines(1) end
        IIFD(slot).enchantText = fs
    end

    PositionInspectSlotText(slot)
end

local function UpdateSlotEnchant(slotName, slotID, frame)
    local slot = _G[slotName]
    if not slot then return end
    local unit = frame.unit or "inspect"
    local itemLink = GetInventoryItemLink(unit, slotID)
    EnsureInspectSlotInfo(slot)

    if not itemLink or slotID == SLOT_BODY or slotID == SLOT_TABARD then
        IIFD(slot).ilvlText:Hide()
        IIFD(slot).enchantText:Hide()
        return
    end

    local ilvl
    if GetDetailedItemLevelInfo then
        local ok, detailedIlvl = pcall(GetDetailedItemLevelInfo, itemLink)
        if ok then ilvl = detailedIlvl end
    end
    if not ilvl and GetItemInfo then
        local _, _, _, fallbackIlvl = GetItemInfo(itemLink)
        ilvl = fallbackIlvl
    end

    if ilvl and ilvl > 0 then
        IIFD(slot).ilvlText:SetFormattedText("%d", math.floor(ilvl + 0.5))
        IIFD(slot).ilvlText:SetTextColor(RexUI:GetColor("highlight"))
        IIFD(slot).ilvlText:Show()
    else
        IIFD(slot).ilvlText:Hide()
    end

    local extraText
    local extraR, extraG, extraB = 0.25, 1, 0.25
    if ENCHANT_SLOTS[slotID] then
        extraText = GetInspectEnchantName(unit, slotID)
    elseif GEM_SLOTS[slotID] then
        extraText = GetGemText(itemLink)
        extraR, extraG, extraB = 0.20, 0.75, 1.00
    end

    if ENCHANT_SLOTS[slotID] or GEM_SLOTS[slotID] then
        if extraText then
            IIFD(slot).enchantText:SetText(extraText)
            IIFD(slot).enchantText:SetTextColor(extraR, extraG, extraB, 1)
            IIFD(slot).enchantText:Show()
        else
            IIFD(slot).enchantText:Hide()
        end
    else
        IIFD(slot).enchantText:Hide()
    end
end

local function UpdateAllSlotEnchants(frame)
    if not frame then return end
    for _, slotName in ipairs(INSPECT_ALL_SLOTS) do
        local slot = _G[slotName]
        if slot then UpdateSlotEnchant(slotName, slot:GetID(), frame) end
    end
end

local function InspectRestyleButton(btn, labelText, anchor, xOff, frame)
    if not btn then return end
    if btn.RexUIRestyled then return end
    btn.RexUIRestyled = true
    btn:ClearAllPoints()
    btn:SetPoint(anchor, frame, anchor, xOff, 8)
    btn:SetSize(90, 21)
    btn:SetFrameLevel(frame:GetFrameLevel() + 20)
    for _, region in ipairs({btn:GetRegions()}) do
        if region.SetTexture then region:SetTexture(nil); region:Hide()
        elseif region.SetTextColor then region:SetTextColor(0, 0, 0, 0) end
    end
    local bg = btn:CreateTexture(nil, "BACKGROUND", nil, -6)
    bg:SetAllPoints()
    bg:SetColorTexture(RexUI:GetColor("panel"))
    local border = Skin:CreateBorder(btn)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", 0, 0)
    border:SetFrameLevel(btn:GetFrameLevel() + 1)
    Skin:SetBorderColor(border, RexUI:GetColor("border"))
    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetFont(STANDARD_TEXT_FONT, 11, "")
    fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
    fs:SetText(T(labelText))
    fs:SetTextColor(RexUI:GetColor("text"))
    btn:HookScript("OnEnter", function() fs:SetTextColor(RexUI:GetColor("highlight")) end)
    btn:HookScript("OnLeave", function() fs:SetTextColor(RexUI:GetColor("text")) end)
    btn:Show()
end

function Skin:StyleInspectFrame(frame)
    if not IsEnabled("inspect") or not frame then return end

    -- Always hide unnamed decoration children of PVP / Guild panels (Blizzard restores them)
    for _, pvpGuild in ipairs({_G.InspectPVPFrame, _G.InspectGuildFrame}) do
        if pvpGuild then
            for i = 1, pvpGuild:GetNumChildren() do
                local c = select(i, pvpGuild:GetChildren())
                if c and not c:GetName() then c:SetAlpha(0) end
            end
        end
    end

    if frame.RexUISkinInspectDone then return end
    frame.RexUISkinInspectDone = true

    for _, elem in ipairs({frame.NineSlice, frame.Background, frame.TitleBg,
                           frame.TopTileStreaks, frame.Portrait, frame.Bg}) do
        if elem then elem:SetAlpha(0) end
    end

    if InspectFrameBg then InspectFrameBg:SetAlpha(0) end
    if InspectFrameInset then
        if InspectFrameInset.NineSlice then InspectFrameInset.NineSlice:SetAlpha(0) end
        if InspectFrameInset.Bg then InspectFrameInset.Bg:SetAlpha(0) end
    end

    for _, elem in ipairs({InspectModelFrameBackgroundOverlay,
                           InspectModelFrameBorderRight, InspectModelFrameBorderLeft,
                           InspectModelFrameBorderBottom, InspectModelFrameBorderTop,
                           InspectModelFrameBorderBottomRight, InspectModelFrameBorderBottomLeft,
                           InspectModelFrameBorderTopRight, InspectModelFrameBorderTopLeft,
                           InspectModelFrameBackgroundTopLeft, InspectModelFrameBackgroundTopRight,
                           InspectModelFrameBackgroundBotLeft, InspectModelFrameBackgroundBotRight}) do
        if elem then elem:SetAlpha(0) end
    end

    if frame.PaperDollFrame and frame.PaperDollFrame.InnerBorder then
        for _, n in ipairs({"Top", "Bottom", "Left", "Right", "TopLeft", "TopRight", "BottomLeft", "BottomRight"}) do
            if frame.PaperDollFrame.InnerBorder[n] then frame.PaperDollFrame.InnerBorder[n]:SetAlpha(0) end
        end
    end

    ApplyPlainPanel(frame, 4)

    if not IIFD(frame).textOverlay then
        local ov = CreateFrame("Frame", nil, frame)
        ov:SetFrameLevel(frame:GetFrameLevel() + 25)
        ov:SetAllPoints(frame)
        IIFD(frame).textOverlay = ov
    end

    local inspectTitle = _G.InspectFrameTitleText or frame.TitleText
    if inspectTitle then StyleFontString(inspectTitle, "highlight") end

    -- Close button
    local closeBtn = frame.CloseButton or _G.InspectFrameCloseButton
    if closeBtn then StyleCloseButton(closeBtn) end

    -- Restyle Talente + Anprobe buttons
    local pdFrame = _G.InspectPaperDollItemsFrame
    if pdFrame then
        local talentsBtn = pdFrame.InspectTalents
        for i = 1, pdFrame:GetNumChildren() do
            local c = select(i, pdFrame:GetChildren())
            if c and c:GetObjectType() == "Button" and not c:GetName() and c ~= talentsBtn then
                c:SetAlpha(0); c:EnableMouse(false)
            end
        end
        InspectRestyleButton(talentsBtn, "Talente", "BOTTOMRIGHT", -7, frame)
    end
    local viewBtn = InspectPaperDollFrame and InspectPaperDollFrame.ViewButton
    InspectRestyleButton(viewBtn, "Anprobe", "BOTTOMLEFT", 10, frame)

    -- Tabs
    for i = 1, 3 do
        local tab = _G["InspectFrameTab" .. i]
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
                tab:GetFontString():SetTextColor(RexUI:GetColor("text"))
            end
        end
    end

    local function UpdateInspectTabVisuals()
        local selected = frame.selectedTab or 1
        for i = 1, 3 do
            local tab = _G["InspectFrameTab" .. i]
            if tab then
                local isActive = i == selected
                if tab.RexUISkinTabUnderline then
                    tab.RexUISkinTabUnderline:SetShown(isActive)
                end
                if tab:GetFontString() then
                    if isActive then
                        tab:GetFontString():SetTextColor(RexUI:GetColor("highlight"))
                    else
                        tab:GetFontString():SetTextColor(RexUI:GetColor("mutedText"))
                    end
                end
            end
        end
    end

    for i = 1, 3 do
        local tab = _G["InspectFrameTab" .. i]
        if tab then tab:HookScript("OnClick", UpdateInspectTabVisuals) end
    end
    UpdateInspectTabVisuals()

    -- Style slots: border + bg only, DON'T hide existing textures (item icons)
    for _, slotName in ipairs(INSPECT_ALL_SLOTS) do
        local slot = _G[slotName]
        if slot then
            slot:Show()
            if not slot.RexUISkinInspectSlot then
                slot.RexUISkinInspectSlot = true
                local bg = slot:CreateTexture(nil, "BACKGROUND", nil, -6)
                bg:SetPoint("TOPLEFT", 2, -2)
                bg:SetPoint("BOTTOMRIGHT", -2, 2)
                bg:SetColorTexture(RexUI:GetColor("panel"))
                slot.RexUISkinButtonBackground = bg
                local border = Skin:CreateBorder(slot)
                border:SetPoint("TOPLEFT", 2, -2)
                border:SetPoint("BOTTOMRIGHT", -2, 2)
                border:SetFrameLevel((slot:GetFrameLevel() or 1) + 1)
                slot.RexUISkinButtonBorder = border
            end
            local itemLink = GetInventoryItemLink("inspect", slot:GetID())
            local borderR, borderG, borderB = 0.4, 0.4, 0.4
            if itemLink then
                local _, _, rarity = GetItemInfo(itemLink)
                if rarity then borderR, borderG, borderB = C_Item.GetItemQualityColor(rarity) end
            end
            if slot.RexUISkinButtonBorder then
                Skin:SetBorderColor(slot.RexUISkinButtonBorder, {borderR, borderG, borderB, 1})
            end
        end
    end

    UpdateAllSlotEnchants(frame)

    -- Average item level
    local function GetAvgIlvl()
        if not frame.unit then return 0 end
        if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
            local ilvl = C_PaperDollInfo.GetInspectItemLevel(frame.unit)
            if ilvl and ilvl > 0 then return ilvl end
        end
        return 0
    end
    local avg = GetAvgIlvl()
    if avg > 0 then
        if not IIFD(frame).avgIlvlText then
            local fs = frame:CreateFontString(nil, "OVERLAY")
            fs:SetFont(STANDARD_TEXT_FONT, 16, "")
            local r, g, b = RexUI:GetColor("highlight")
            fs:SetTextColor(r, g, b, 1)
            fs:SetJustifyH("CENTER")
            fs:SetPoint("TOP", frame, "TOP", 0, -43)
            IIFD(frame).avgIlvlText = fs
        end
        IIFD(frame).avgIlvlText:SetFormattedText("%.2f", avg)
        IIFD(frame).avgIlvlText:Show()
    end
end

local function StyleInspectSlotsOnReady()
    if not InspectFrame or not InspectFrame.unit then return end
    if not IsEnabled("inspect") then return end
    local config = GetConfig()
    if config.enabled == false or config.inspect == false then return end
    local frame = InspectFrame
    local pdFrame = _G.InspectPaperDollItemsFrame
    if not pdFrame then return end

    for slotName, gridPos in pairs(INSPECT_SLOT_GRID) do
        local slot = _G[slotName]
        if slot then
            local itemLink = GetInventoryItemLink("inspect", slot:GetID())
            local borderR, borderG, borderB = 0.4, 0.4, 0.4
            if itemLink then
                local _, _, rarity = GetItemInfo(itemLink)
                if rarity then borderR, borderG, borderB = C_Item.GetItemQualityColor(rarity) end
            end
            if slot.RexUISkinButtonBorder then
                Skin:SetBorderColor(slot.RexUISkinButtonBorder, {borderR, borderG, borderB, 1})
            end
        end
    end

    local avg = 0
    if frame.unit and C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        avg = C_PaperDollInfo.GetInspectItemLevel(frame.unit) or 0
    end
    if avg > 0 and IIFD(frame).avgIlvlText then
        IIFD(frame).avgIlvlText:SetFormattedText("%.2f", avg)
        IIFD(frame).avgIlvlText:Show()
    end

    UpdateAllSlotEnchants(frame)
end

function Skin:HookInspectFrame()
    if self.InspectHooked then return end

    local function SetupInspectFrame(frame)
        if self.InspectHooked then return end
        self.InspectHooked = true

        local inspectReadyFrame = CreateFrame("Frame")
        Skin:RegisterEvents(inspectReadyFrame, { "INSPECT_READY", "GET_ITEM_INFO_RECEIVED" })
        inspectReadyFrame:SetScript("OnEvent", function()
            StyleInspectSlotsOnReady()
            if C_Timer and C_Timer.After then
                C_Timer.After(0.2, StyleInspectSlotsOnReady)
            end
        end)

        frame:HookScript("OnShow", function()
            Skin:StyleInspectFrame(frame)
            C_Timer.After(0.1, function()
                StyleInspectSlotsOnReady()
            end)
        end)

        frame:HookScript("OnHide", function()
            frame.RexUISkinInspectDone = false
        end)
    end

    if _G.InspectFrame then
        SetupInspectFrame(_G.InspectFrame)
        if _G.InspectFrame:IsShown() then
            Skin:StyleInspectFrame(_G.InspectFrame)
            C_Timer.After(0.1, StyleInspectSlotsOnReady)
        end
        return
    end

    local addonFrame = CreateFrame("Frame")
    addonFrame:RegisterEvent("ADDON_LOADED")
    addonFrame:SetScript("OnEvent", function(_, _, addon)
        if addon == "Blizzard_InspectUI" then
            addonFrame:UnregisterAllEvents()
            if _G.InspectFrame then
                local frame = _G.InspectFrame
                SetupInspectFrame(frame)
                if frame:IsShown() then
                    Skin:StyleInspectFrame(frame)
                    C_Timer.After(0.1, StyleInspectSlotsOnReady)
                end
            end
        end
    end)
end
