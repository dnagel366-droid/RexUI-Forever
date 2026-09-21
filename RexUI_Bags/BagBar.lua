local _, ns = ...
local RexUI = _G.RexUI or ns.RexUI
if not RexUI or not RexUI.Bags then return end

local B = RexUI.Bags
B.EquipmentBagBarActive = true

local bar, eventFrame
local buttons = {}
local updating = false
local BACKPACK_ICON = "Interface\\Icons\\INV_Misc_Bag_08"

local function T(text)
    return RexUI:LocalizeText(text)
end

local function GetConfig()
    local profile = RexUI:GetProfile()
    profile.bags = profile.bags or {}
    return profile.bags
end

local function GetBagIndex(name, fallback)
    return Enum and Enum.BagIndex and Enum.BagIndex[name] or fallback
end

local function GetKeyringBagID()
    if Enum and Enum.BagIndex and Enum.BagIndex.Keyring ~= nil then
        return Enum.BagIndex.Keyring
    end
    if KEYRING_CONTAINER ~= nil then
        return KEYRING_CONTAINER
    end
    if _G.KeyRingButton then
        return -2
    end
    return nil
end

local function GetIcon(button)
    if not button then return nil end
    local name = button.GetName and button:GetName()
    return button.icon or button.Icon or (name and _G[name .. "IconTexture"])
end

local function GetBagStats(bagID)
    local slots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bagID) or 0
    local free = C_Container and C_Container.GetContainerNumFreeSlots and C_Container.GetContainerNumFreeSlots(bagID) or 0
    return tonumber(slots) or 0, tonumber(free) or 0
end

local function StyleButton(button, bagID)
    if not button then return end
    button.BagID = bagID
    button.rexBagID = bagID
    button:SetParent(bar)
    button:SetFrameLevel(bar:GetFrameLevel() + 3)

    local icon = GetIcon(button)
    if icon then
        if bagID == GetBagIndex("Backpack", 0) then
            -- Retail's backpack texture is designed for a circular mask and
            -- appears almost black after converting the button to a square.
            icon:SetTexture(BACKPACK_ICON)
        end
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon:SetAlpha(1)
        icon:Show()
    end
    if button.CircleMask then button.CircleMask:Hide() end
    if button.GetNormalTexture and button:GetNormalTexture() then button:GetNormalTexture():SetAlpha(0) end

    if not button.rexBarBorder then
        local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
        border:SetAllPoints(button)
        border:SetFrameLevel(button:GetFrameLevel() + 2)
        border:EnableMouse(false)
        border:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        border:SetBackdropColor(0.06, 0.06, 0.06, 0.35)
        button.rexBarBorder = border

        button.rexBarText = border:CreateFontString(nil, "OVERLAY")
        button.rexBarText:SetFont("Interface\\AddOns\\RexUI\\media\\fonts\\Barlow Condensed.ttf", 10, "OUTLINE")
        button.rexBarText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)

        button.rexBagType = border:CreateFontString(nil, "OVERLAY")
        button.rexBagType:SetFont("Interface\\AddOns\\RexUI\\media\\fonts\\Barlow Condensed.ttf", 8, "OUTLINE")
        button.rexBagType:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)

        button:HookScript("OnEnter", function(self)
            if bar then bar:SetAlpha(1) end
            if GameTooltip.IsForbidden and GameTooltip:IsForbidden() then return end
            local total, free = GetBagStats(self.rexBagID)
            GameTooltip:AddLine(" ")
            if self.rexBagID == GetBagIndex("ReagentBag", 5) then
                GameTooltip:AddLine(T("Materialtasche (Reagenzien)"), 0.25, 1, 0.82)
            elseif self.rexBagID == GetKeyringBagID() then
                GameTooltip:AddLine(T("Schlüsselbund"), 1.00, 0.82, 0.20)
            elseif self.rexBagID == GetBagIndex("Backpack", 0) then
                GameTooltip:AddLine(T("Fester Rucksack"), 1, 1, 1)
            else
                GameTooltip:AddLine(format(T("Taschenplatz %d"), self.rexBagID), 1, 1, 1)
            end
            GameTooltip:AddLine(format(T("%d Plätze, %d frei"), total, free), 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function()
            if bar then bar:SetAlpha(1) end
        end)
        button:HookScript("OnMouseDown", function(_, mouseButton)
            if mouseButton == "LeftButton" and B.MarkItemMove then B:MarkItemMove() end
        end)
        button:HookScript("OnDragStart", function()
            if B.MarkItemMove then B:MarkItemMove() end
        end)
        button:HookScript("OnReceiveDrag", function()
            if B.MarkItemMove then B:MarkItemMove() end
        end)
    end
end

local function UpdateButton(button)
    if not button then return end
    local bagID = button.rexBagID
    local total = GetBagStats(bagID)
    local reagent = bagID == GetBagIndex("ReagentBag", 5)
    local backpack = bagID == GetBagIndex("Backpack", 0)
    local icon = GetIcon(button)

    if icon then
        if backpack then
            -- Blizzard can restore its circular texture during bag updates.
            icon:SetTexture(BACKPACK_ICON)
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            icon:SetAlpha(1)
            icon:Show()
        end
        icon:SetDesaturated(total == 0 and not backpack)
    end
    -- Die originalen Taschenicons bleiben unverfaelscht. Die
    -- Kapazitaet und der Taschentyp stehen ausschliesslich im Tooltip.
    button.rexBarText:SetText("")
    button.rexBarText:Hide()
    button.rexBagType:SetText("")
    button.rexBagType:Hide()
    if reagent then
        button.rexBarBorder:SetBackdropBorderColor(0.10, 0.85, 0.72, 1)
        button.rexBarText:SetTextColor(0.25, 1, 0.82, 1)
        button.rexBagType:SetTextColor(0.25, 1, 0.82, 1)
    else
        button.rexBarBorder:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
        button.rexBarText:SetTextColor(1, 1, 1, 1)
    end

    if button.Count then button.Count:Hide() end
end

local function PositionBar()
    if not bar then return end
    local cfg = GetConfig()
    local size = math.max(20, math.min(64, tonumber(cfg.barButtonSize) or 28))
    local spacing = math.max(0, math.min(20, tonumber(cfg.barSpacing) or 2))
    local attachedFrame = B.EquipmentBagBarAttachedFrame
    local mainMover = B.MainBagMover
    local padding = 3
    local count = #buttons
    local barWidth = count * size + math.max(0, count - 1) * spacing + padding * 2
    local barHeight = size + padding * 2

    bar:SetSize(barWidth, barHeight)
    bar:ClearAllPoints()
    if attachedFrame then
        bar:SetPoint("BOTTOMLEFT", attachedFrame, "TOPLEFT", 0, 4)
        bar:SetFrameLevel(attachedFrame:GetFrameLevel() + 20)
        bar:EnableMouse(true)
        bar:SetBackdropColor(0.02, 0.015, 0.025, 0.96)
        bar:SetBackdropBorderColor(0.62, 0.12, 0.80, 0.95)
    elseif mainMover then
        mainMover:SetSize(math.max(200, barWidth + 10), 45 + barHeight)
        bar:SetPoint("BOTTOM", mainMover, "BOTTOM", 0, 5)
        bar:SetFrameLevel(mainMover:GetFrameLevel() + 1)
        bar:EnableMouse(false)
        bar:SetBackdropColor(0, 0, 0, 0)
        bar:SetBackdropBorderColor(0, 0, 0, 0)
    else
        bar:SetPoint("CENTER", UIParent, "CENTER")
        bar:SetBackdropColor(0, 0, 0, 0)
        bar:SetBackdropBorderColor(0, 0, 0, 0)
    end
    bar:SetAlpha(1)

    local previous
    for _, button in ipairs(buttons) do
        button:SetSize(size, size)
        button:ClearAllPoints()
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", spacing, 0)
        else
            button:SetPoint("LEFT", bar, "LEFT", padding, 0)
        end
        button:Show()
        button:EnableMouse(attachedFrame ~= nil)
        previous = button
        UpdateButton(button)
    end
end

function B:InitializeEquipmentBagBar()
    if bar or (InCombatLockdown and InCombatLockdown()) then return end

    bar = CreateFrame("Frame", "RexUI_EquipmentBagBar", UIParent, "BackdropTemplate")
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(20)
    bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
    bar:SetScript("OnLeave", function(self) self:SetAlpha(1) end)
    B.EquipmentBagBar = bar

    local blizzardBar = _G.BagsBar
    if blizzardBar then
        blizzardBar:Hide()
        blizzardBar:SetAlpha(0)
        blizzardBar:EnableMouse(false)
        if blizzardBar.UnregisterAllEvents then blizzardBar:UnregisterAllEvents() end
    end
    if _G.BagBarExpandToggle then
        _G.BagBarExpandToggle:Hide()
        _G.BagBarExpandToggle:EnableMouse(false)
    end

    local candidates = {
        { _G.MainMenuBarBackpackButton, GetBagIndex("Backpack", 0) },
        { _G.CharacterBag0Slot, 1 },
        { _G.CharacterBag1Slot, 2 },
        { _G.CharacterBag2Slot, 3 },
        { _G.CharacterBag3Slot, 4 },
        { _G.CharacterReagentBag0Slot, GetBagIndex("ReagentBag", 5) },
        { _G.KeyRingButton, GetKeyringBagID() },
    }
    for _, candidate in ipairs(candidates) do
        if candidate[1] then
            table.insert(buttons, candidate[1])
            StyleButton(candidate[1], candidate[2])
        end
    end

    if _G.CharacterReagentBag0Slot and _G.CharacterReagentBag0Slot.SetBarExpanded then
        hooksecurefunc(_G.CharacterReagentBag0Slot, "SetBarExpanded", function()
            B:UpdateEquipmentBagBar()
        end)
    end

    PositionBar()
    bar:Hide()

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("BAG_SLOT_FLAGS_UPDATED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and not bar then B:InitializeEquipmentBagBar() end
        B:UpdateEquipmentBagBar()
    end)

end

function B:UpdateEquipmentBagBar()
    if updating then return end
    if not bar then
        self:InitializeEquipmentBagBar()
        return
    end
    if InCombatLockdown and InCombatLockdown() then return end
    updating = true
    for _, button in ipairs(buttons) do
        if button:GetParent() ~= bar then button:SetParent(bar) end
    end
    PositionBar()
    if not bar:IsShown() and _G.KeyRingButton then
        _G.KeyRingButton:EnableMouse(false)
        _G.KeyRingButton:SetAlpha(0)
        _G.KeyRingButton:Hide()
        if GameTooltip then GameTooltip:Hide() end
    end
    updating = false
end

function B:ShowBagBarMover()
    self:InitializeEquipmentBagBar()
    self.EquipmentBagBarAttachedFrame = nil
    PositionBar()
    if bar then bar:Show() end
end

function B:HideBagBarMover()
    if bar then bar:Hide() end
    self.EquipmentBagBarAttachedFrame = nil
end

function B:ToggleEquipmentBagsInFrame(parent)
    self:InitializeEquipmentBagBar()
    if not bar or not parent or (InCombatLockdown and InCombatLockdown()) then return end

    if self.EquipmentBagBarAttachedFrame == parent and bar:IsShown() then
        bar:Hide()
        self.EquipmentBagBarAttachedFrame = nil
        PositionBar()
        return
    end

    self.EquipmentBagBarAttachedFrame = parent
    PositionBar()
    bar:Show()
end

function B:HideEquipmentBagsInFrame(parent)
    if self.EquipmentBagBarAttachedFrame and (not parent or self.EquipmentBagBarAttachedFrame == parent) then
        if bar then bar:Hide() end
        self.EquipmentBagBarAttachedFrame = nil
        PositionBar()
    end
end

function B:ResetBagBarPosition()
    if self.ResetPosition then self:ResetPosition() end
    PositionBar()
end

function B:RefreshBagBar()
    self:UpdateEquipmentBagBar()
end
