local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI
if not RexUI then return end

RexUI.Bags = RexUI.Bags or {}
local B = RexUI.Bags

local function T(text)
    return RexUI:LocalizeText(text)
end

if RexUI.RegisterModule then
    RexUI:RegisterModule("Bags", B)
end

local QUALITY_COLORS = {
    [0] = {0.5, 0.5, 0.5},
    [1] = {1.0, 1.0, 1.0},
    [2] = {0.12, 1.0, 0.12},
    [3] = {0.12, 0.42, 1.0},
    [4] = {0.64, 0.21, 0.93},
    [5] = {1.0, 0.5, 0.0},
    [6] = {0.88, 0.72, 0.16},
}

local bagFrame, mover, eventFrame
local bagButtons = {}
local bagButtonsByKey = {}
local updatingBagBar = false
local searchText = ""
local hiddenBags = {}
local MarkItemMove
local layoutGeneration = 0
local layoutScheduled = false
local professionQualityCache = {}
local lastMerchantEventAt = 0

local LAYOUT_BATCH_SIZE = 24

local function GetConfig()
    local profile = RexUI:GetProfile()
    profile.bags = profile.bags or {}
    return profile.bags
end

local function RegisterUISpecialFrame(frameName)
    if not frameName or not _G.UISpecialFrames then return end

    for _, name in ipairs(_G.UISpecialFrames) do
        if name == frameName then
            return
        end
    end

    tinsert(_G.UISpecialFrames, frameName)
end

local function Save(key, value)
    local profile = RexUI:GetProfile()
    if not profile then return end
    profile.bags = profile.bags or {}
    profile.bags[key] = value
end

local function GetMoneyText()
    local money = GetMoney and GetMoney() or 0
    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100
    return string.format("%s |TInterface\\MoneyFrame\\UI-GoldIcon:11:11:0:0|t %d |TInterface\\MoneyFrame\\UI-SilverIcon:11:11:0:0|t %d |TInterface\\MoneyFrame\\UI-CopperIcon:11:11:0:0|t",
        BreakUpLargeNumbers(gold), silver, copper)
end

local function GetDurabilityPercent()
    local totalCurrent, totalMax = 0, 0

    for slot = 1, 18 do
        local current, maximum = GetInventoryItemDurability(slot)
        if current and maximum and maximum > 0 then
            totalCurrent = totalCurrent + current
            totalMax = totalMax + maximum
        end
    end

    if totalMax == 0 then
        return nil
    end

    return math.floor(((totalCurrent / totalMax) * 100) + 0.5)
end

local function GetDurabilityText()
    local percent = GetDurabilityPercent()
    if not percent then
        return T("Rüstung: --")
    end

    local color = "FF00FF66"
    if percent < 30 then
        color = "FFFF3333"
    elseif percent < 70 then
        color = "FFFFCC00"
    end

    return string.format(T("Rüstung: ") .. "|c%s%d%%|r", color, percent)
end

local function IsForeverClient()
    local toc = select(4, GetBuildInfo())
    toc = tonumber(toc) or 0
    return toc >= 16000 and toc < 20000
end

local function GetPlayerBagSpace()
    local total, free = 0, 0
    local getSlots = C_Container and C_Container.GetContainerNumSlots
    local getFree = C_Container and C_Container.GetContainerNumFreeSlots
    for bagID = 0, 4 do
        local slots = getSlots and getSlots(bagID) or 0
        local empty = getFree and getFree(bagID) or 0
        total = total + (tonumber(slots) or 0)
        free = free + (tonumber(empty) or 0)
    end
    return total, free
end

local function GetBagSpaceText()
    local total, free = GetPlayerBagSpace()
    if total <= 0 then
        return T("Frei: --")
    end
    local color = "FF00FF66"
    if free <= 4 then
        color = "FFFF3333"
    elseif free <= 10 then
        color = "FFFFCC00"
    end
    return string.format(T("Frei: ") .. "|c%s%d|r / %d", color, free, total)
end

local function SlotMatchesSearch(info)
    if searchText == "" then return true end
    if not info or not info.link then return false end

    local name = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(info.link)
    if not name and GetItemInfo then
        name = GetItemInfo(info.link)
    end
    if not name then return true end

    return string.find(string.lower(name), string.lower(searchText), 1, true) ~= nil
end

local function GetQualityColor(quality)
    local c = QUALITY_COLORS[quality]
    if c then return c[1], c[2], c[3] end
    local r, g, b = GetItemQualityColor(quality)
    if r then return r, g, b end
    return 0.5, 0.5, 0.5
end

local function NormalizeProfessionQuality(quality)
    quality = tonumber(quality)
    if not quality or quality <= 0 then return nil end
    if quality > 2 then return 2 end
    return quality
end

local function GetProfessionQualityFromText(text)
    if not text or text == "" then return nil end
    text = tostring(text)

    local tier = text:match("Quality%-Tier(%d)")
        or text:match("Quality_?Tier(%d)")
        or text:match("quality%-tier(%d)")
        or text:match("quality_?tier(%d)")
        or text:match("Professions[^|]-Tier(%d)")
    local quality = NormalizeProfessionQuality(tier)
    if quality then return quality end

    if text:find("Professions", 1, true)
    or text:find("quality", 1, true)
    or text:find("Quality", 1, true) then
        if text:find("Gold", 1, true) or text:find("gold", 1, true) then return 2 end
        if text:find("Silver", 1, true) or text:find("silver", 1, true) then return 1 end
    end

    return nil
end

local function GetProfessionQualityFromTooltip(bagID, slotIndex)
    if not C_TooltipInfo or not C_TooltipInfo.GetBagItem then return nil end

    local ok, data = pcall(C_TooltipInfo.GetBagItem, bagID, slotIndex)
    if not ok or not data or not data.lines then return nil end

    local quality = GetProfessionQualityFromText(data.hyperlink)
    if quality then return quality end

    local qualityLineType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ProfessionCraftingQuality or 12
    for _, line in ipairs(data.lines) do
        if line and TooltipUtil and TooltipUtil.SurfaceArgs then
            pcall(TooltipUtil.SurfaceArgs, line)
        end

        quality = GetProfessionQualityFromText(line and line.leftText)
        if quality then return quality end

        quality = GetProfessionQualityFromText(line and line.rightText)
        if quality then return quality end

        if line and line.type == qualityLineType then
            for _, key in ipairs({ "quality", "qualityID", "qualityIndex", "qualityTier", "craftingQuality", "professionQuality" }) do
                quality = NormalizeProfessionQuality(line[key])
                if quality then return quality end
            end

            if line.args then
                for _, arg in ipairs(line.args) do
                    if type(arg) == "table" then
                        local field = tostring(arg.field or "")
                        if field:find("quality") or field:find("Quality") then
                            quality = NormalizeProfessionQuality(arg.intVal or arg.floatVal or arg.stringVal)
                            if quality then return quality end
                        end
                    end
                end

                for _, arg in ipairs(line.args) do
                    if type(arg) == "table" then
                        quality = NormalizeProfessionQuality(arg.intVal or arg.floatVal or arg.stringVal)
                        if quality then return quality end
                    end
                end
            end

            local text = (line.leftText or "") .. " " .. (line.rightText or "")
            quality = NormalizeProfessionQuality(text:match("(%d+)"))
            if quality then return quality end
        end
    end

    return nil
end

local function GetProfessionQuality(itemLink, bagID, slotIndex)
    local tooltipQuality = GetProfessionQualityFromTooltip(bagID, slotIndex)
    if tooltipQuality then return tooltipQuality end

    local linkQuality = GetProfessionQualityFromText(itemLink)
    if linkQuality then return linkQuality end

    if not itemLink or not C_TradeSkillUI then return nil end

    if C_TradeSkillUI.GetItemReagentQualityByItemInfo then
        local ok, quality = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, itemLink)
        quality = NormalizeProfessionQuality(ok and quality)
        if quality then return quality end
    end

    if C_TradeSkillUI.GetItemCraftedQualityByItemInfo then
        local ok, quality = pcall(C_TradeSkillUI.GetItemCraftedQualityByItemInfo, itemLink)
        quality = NormalizeProfessionQuality(ok and quality)
        if quality then return quality end
    end

    return nil
end

local function GetProfessionQualityAtlas(itemLink)
    if not itemLink then return nil end
    local itemID = tonumber(itemLink:match("item:(%d+)"))
    if not itemID then return nil end

    if C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityInfo then
        local ok, qualityInfo = pcall(C_TradeSkillUI.GetItemReagentQualityInfo, itemID)
        if ok and qualityInfo and qualityInfo.iconSmall then
            return qualityInfo.iconSmall
        end
    end
    return nil
end

local function GetProfessionQualityCacheKey(itemLink, bagID, slotIndex)
    if not itemLink then return nil end
    return tostring(bagID) .. ":" .. tostring(slotIndex) .. ":" .. itemLink
end

local function IsMerchantBusy()
    local now = GetTime and GetTime() or 0
    return (_G.MerchantFrame and _G.MerchantFrame:IsShown()) or (now - lastMerchantEventAt < 1.0)
end

local function GetCachedProfessionQuality(itemLink, bagID, slotIndex, skipUncached)
    local key = GetProfessionQualityCacheKey(itemLink, bagID, slotIndex)
    if not key then return nil, nil end

    local cached = professionQualityCache[key]
    if cached then
        return cached.quality, cached.atlas
    end

    if skipUncached then
        return nil, nil
    end

    local quality = GetProfessionQuality(itemLink, bagID, slotIndex)
    local atlas = GetProfessionQualityAtlas(itemLink)
    professionQualityCache[key] = {
        quality = quality or false,
        atlas = atlas or false,
    }

    return quality, atlas
end

local function GetProfessionQualityColor(quality)
    if quality == 1 then return 0.92, 0.92, 0.86 end
    return 1.00, 0.66, 0.12
end

local function SetProfessionQualityDiamond(texture, quality, atlas)
    if texture then texture:Hide() end
    if not quality or quality <= 0 then return end

    if texture then
        if atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
            texture:SetAtlas(atlas)
        else
            local r, g, b = GetProfessionQualityColor(quality)
            texture:SetTexture("Interface\\Buttons\\UI-RaidFrame-Diamond")
            texture:SetVertexColor(r, g, b, 1)
        end
        texture:SetSize(18, 18)
        texture:Show()
    end
end

local function GetSlotInfo(bagID, slotIndex, skipUncachedProfessionQuality)
    local ok, info = pcall(C_Container.GetContainerItemInfo, bagID, slotIndex)
    local link
    local ok2, linkResult = pcall(C_Container.GetContainerItemLink, bagID, slotIndex)
    if ok2 then link = linkResult end

    info = ok and info or nil
    local professionQuality, professionQualityAtlas = GetCachedProfessionQuality(link, bagID, slotIndex, skipUncachedProfessionQuality)

    return {
        bagID = bagID,
        slotIndex = slotIndex,
        icon = info and info.iconFileID,
        count = info and info.stackCount,
        quality = (info and info.quality) or 0,
        isLocked = info and info.isLocked,
        link = link,
        professionQuality = professionQuality,
        professionQualityAtlas = professionQualityAtlas,
        cooldownStart = info and info.cooldownStartTime,
        cooldownDuration = info and info.cooldownDuration,
    }
end

local function AddBagSlots(slots, bagID, skipUncachedProfessionQuality)
    local ok, numSlots = pcall(C_Container.GetContainerNumSlots, bagID)
    if not ok then return end
    if not numSlots or numSlots <= 0 then return end

    for slotIndex = 1, numSlots do
        slots[#slots + 1] = GetSlotInfo(bagID, slotIndex, skipUncachedProfessionQuality)
    end
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

local function HideStrayKeyRing()
    local button = _G.KeyRingButton
    if button then
        local bar = B.EquipmentBagBar
        local parent = button.GetParent and button:GetParent()
        if bar and parent == bar and bar:IsShown() then
            button:SetAlpha(1)
            if button.EnableMouse then button:EnableMouse(true) end
        else
            if button.EnableMouse then button:EnableMouse(false) end
            button:SetAlpha(0)
            button:Hide()
            if GameTooltip and GameTooltip.Hide then
                GameTooltip:Hide()
            end
        end
        if not button._rexKeyringHooked then
            button._rexKeyringHooked = true
            button:HookScript("OnEnter", function()
                local bagBar = B.EquipmentBagBar
                if not (bagBar and bagBar:IsShown()) then
                    if GameTooltip then GameTooltip:Hide() end
                end
            end)
        end
    end

    local keyring = GetKeyringBagID()
    if keyring then
        for i = 1, NUM_CONTAINER_FRAMES or 13 do
            local frame = _G["ContainerFrame" .. i]
            if frame and frame.GetID and frame:GetID() == keyring then
                frame:Hide()
            end
        end
    end
    if _G.KeyRingFrame then
        _G.KeyRingFrame:Hide()
    end
end

local function CollectSlots(frame)
    local slots = {}
    local skipUncachedProfessionQuality = IsMerchantBusy()
    -- Forever: nur Rucksack und die vier Taschen. Schlüsselbund und
    -- Reagenztasche gehören nicht in das gemeinsame Raster.
    for bagID = 0, 4 do
        if not hiddenBags[bagID] then
            AddBagSlots(slots, bagID, skipUncachedProfessionQuality)
        end
    end

    if not IsForeverClient() then
        local reagentContainer = GetBagIndex("ReagentBag", 5)
        if reagentContainer and not hiddenBags[reagentContainer] then
            AddBagSlots(slots, reagentContainer, skipUncachedProfessionQuality)
        end
    end

    return slots
end

local function GetItemButtonParent(bagID)
    local frame = bagFrame
    if not frame or bagID == nil then return frame end

    frame.itemParents = frame.itemParents or {}

    local parent = frame.itemParents[bagID]
    if not parent then
        local suffix = bagID < 0 and ("Neg" .. math.abs(bagID)) or tostring(bagID)
        parent = CreateFrame("Frame", "RexUIBagItemParent" .. suffix, frame)
        parent:SetAllPoints(frame)
        frame.itemParents[bagID] = parent
    end

    parent:SetID(bagID)
    parent:Show()
    return parent
end

local function SplitStack(button, split)
    if C_Container and C_Container.SplitContainerItem then
        C_Container.SplitContainerItem(button:GetBagID(), button:GetID(), split)
    elseif SplitContainerItem then
        SplitContainerItem(button:GetBagID(), button:GetID(), split)
    end
end

local function HandleRexItemModifiedClick(self, button)
    if not self or not self.GetBagID or not self.GetID then return end

    local bagID, slotID = self:GetBagID(), self:GetID()
    if not bagID or not slotID then return end

    local itemLocation
    if ItemLocation and ItemLocation.CreateFromBagAndSlot then
        itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    end

    if IsModifiedClick and IsModifiedClick("EXPANDITEM") and itemLocation then
        if C_Item and C_Item.DoesItemExist and C_Item.DoesItemExist(itemLocation) then
            if C_AzeriteEmpoweredItem
            and C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItem
            and C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItem(itemLocation)
            and C_Item.CanViewItemPowers
            and C_Item.CanViewItemPowers(itemLocation)
            and OpenAzeriteEmpoweredItemUIFromItemLocation then
                OpenAzeriteEmpoweredItemUIFromItemLocation(itemLocation)
                return true
            end

            local heartItemLocation = C_AzeriteItem and C_AzeriteItem.FindActiveAzeriteItem and C_AzeriteItem.FindActiveAzeriteItem()
            if heartItemLocation
            and heartItemLocation.IsEqualTo
            and heartItemLocation:IsEqualTo(itemLocation)
            and OpenAzeriteEssenceUIFromItemLocation then
                OpenAzeriteEssenceUIFromItemLocation(itemLocation)
                return true
            end

            if C_Container and C_Container.SocketContainerItem and C_Container.SocketContainerItem(bagID, slotID) then
                return true
            end
        end
    end

    local itemLink
    if C_Container and C_Container.GetContainerItemLink then
        itemLink = C_Container.GetContainerItemLink(bagID, slotID)
    elseif GetContainerItemLink then
        itemLink = GetContainerItemLink(bagID, slotID)
    end

    if HandleModifiedItemClick and HandleModifiedItemClick(itemLink, itemLocation) then
        return true
    end

    if CursorHasItem and not CursorHasItem()
    and IsModifiedClick and IsModifiedClick("SPLITSTACK")
    and StackSplitFrame then
        local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bagID, slotID)
        local itemCount = info and info.stackCount
        local locked = info and info.isLocked
        if not locked and itemCount and itemCount > 1 then
            self.SplitStack = SplitStack
            StackSplitFrame:OpenStackSplitFrame(itemCount, self, "BOTTOMRIGHT", "TOPRIGHT")
            return true
        end
    end
end

local function GetItemButtonKey(bagID, slotID)
    local bagKey = bagID < 0 and ("Neg" .. math.abs(bagID)) or tostring(bagID)
    return bagKey .. "_" .. tostring(slotID)
end

local function CreateItemButton(bagID, slotID)
    local parent = GetItemButtonParent(bagID)
    if not parent then return end
    local key = GetItemButtonKey(bagID, slotID)
    -- Blizzard templates stay installed on the item button so protected actions
    -- remain in Blizzard's secure click path.
    -- Kontext implementiert – kein ADDON_ACTION_FORBIDDEN moeglich.
    local ok, btn = pcall(CreateFrame, "ItemButton", "RexUIBagButton" .. key, parent, "ContainerFrameItemButtonTemplate")
    if not ok then
        btn = CreateFrame("ItemButton", "RexUIBagButton" .. key, parent, "ContainerFrameItemButtonTemplate")
    end

    btn.BagID = bagID
    btn.SlotID = slotID
    btn:SetID(slotID)
    btn._rexOwnerFrame = parent:GetParent()
    btn:RegisterForClicks("AnyUp")
    btn:RegisterForDrag("LeftButton")

    -- Leave Blizzard's protected click handlers installed directly on the button.
    -- Calling them from a RexUI wrapper taints UseContainerItem/PickupContainerItem.
    btn:HookScript("OnDragStart", MarkItemMove)
    btn:HookScript("OnReceiveDrag", MarkItemMove)

    -- Blizzard-Texturen entfernen, eigene Optik drüberlegen
    for _, region in ipairs({ btn:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture") then
            region:SetTexture(nil)
            region:SetAlpha(0)
        end
    end

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints(btn)
    btn.bg:SetColorTexture(0.02, 0.015, 0.025, 0.92)

    -- icon: Blizzards eigenes NormalTexture-Icon nutzen
    btn.icon = btn.icon or btn.Icon
    if not btn.icon then
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
    end
    btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn.icon:SetAlpha(1)
    btn.icon:ClearAllPoints()
    btn.icon:SetAllPoints(btn)

    btn.border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    btn.border:SetAllPoints(btn)
    btn.border:SetFrameLevel(btn:GetFrameLevel() + 2)
    btn.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Blizzard nutzt itemButton.count fuer eigene Kauf/Refund-Daten.
    -- RexUI darf dieses Feld nicht mit einem FontString belegen.
    btn.rexCountText = btn.Count
    if btn.count == btn.rexCountText then
        btn.count = nil
    end
    if not btn.rexCountText then
        btn.rexCountText = btn:CreateFontString(nil, "OVERLAY")
        btn.rexCountText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        btn.rexCountText:SetTextColor(1, 1, 1, 1)
    end

    btn.professionQualityIcon = btn:CreateTexture(nil, "OVERLAY")
    btn.professionQualityIcon:SetSize(13, 13)
    btn.professionQualityIcon:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", -1, -1)
    btn.professionQualityIcon:Hide()

    btn.professionQuality = btn:CreateFontString(nil, "OVERLAY")
    btn.professionQuality:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    btn.professionQuality:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", -1, -3)
    btn.professionQuality:SetJustifyH("LEFT")
    btn.professionQuality:Hide()

    -- cooldown: vom Template bereits vorhanden als btn.Cooldown
    btn.cooldown = btn.Cooldown or CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetDrawEdge(false)
    btn.cooldown:SetDrawSwipe(true)
    btn.cooldown:SetSwipeColor(0, 0, 0, 0.8)
    if btn.cooldown.SetHideCountdownNumbers then
        btn.cooldown:SetHideCountdownNumbers(false)
    end

    -- Tooltip: Blizzards OnEnter ist bereits im Template, wir erweitern per HookScript
    btn:HookScript("OnEnter", function(self)
        if not self.SlotID or not self.BagID then return end
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        pcall(GameTooltip.SetBagItem, GameTooltip, self.BagID, self.SlotID)
        GameTooltip:Show()
    end)

    btn:HookScript("OnLeave", function()
        GameTooltip_Hide()
    end)

    return btn
end

local function GetItemButton(info)
    if not info or info.bagID == nil or not info.slotIndex then return end

    local key = GetItemButtonKey(info.bagID, info.slotIndex)
    local btn = bagButtonsByKey[key]
    if not btn then
        btn = CreateItemButton(info.bagID, info.slotIndex)
        bagButtonsByKey[key] = btn
        bagButtons[#bagButtons + 1] = btn
    end

    return btn
end

local function PrecreateItemButtons()
    if not bagFrame then return end

    for _, info in ipairs(CollectSlots()) do
        local btn = GetItemButton(info)
        if btn then
            btn:Hide()
        end
    end
end

local function GetBagSlotStats(bagID)
    local total = C_Container and C_Container.GetContainerNumSlots
        and C_Container.GetContainerNumSlots(bagID) or 0
    local free = C_Container and C_Container.GetContainerNumFreeSlots
        and C_Container.GetContainerNumFreeSlots(bagID) or 0
    return tonumber(total) or 0, tonumber(free) or 0
end

local function GetBagButtonIcon(btn)
    if not btn then return nil end
    local name = btn.GetName and btn:GetName()
    return btn.icon or btn.Icon or (name and _G[name .. "IconTexture"])
end

local function UpdateBagSlotButtonVisual(btn)
    if not btn then return end
    local bagID = btn.bagID
    local total = GetBagSlotStats(bagID)
    local isReagent = bagID == GetBagIndex("ReagentBag", 5)
    local icon = GetBagButtonIcon(btn)
    btn.rexBorder:SetFrameLevel(btn:GetFrameLevel() + 3)

    if icon then
        icon:SetAlpha((total > 0 or bagID == 0) and 1 or 0.30)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
    btn.capacity:SetText(total > 0 and tostring(total) or "+")
    btn.slotLabel:SetText(isReagent and "MAT" or (bagID == 0 and "R" or tostring(bagID)))

    if isReagent then
        btn.rexBorder:SetBackdropBorderColor(0.10, 0.85, 0.72, 1)
        btn.slotLabel:SetTextColor(0.25, 1.00, 0.82, 1)
        btn.capacity:SetTextColor(0.25, 1.00, 0.82, 1)
    else
        btn.rexBorder:SetBackdropBorderColor(0.62, 0.12, 0.80, 0.95)
        btn.slotLabel:SetTextColor(1, 0.82, 1, 1)
        btn.capacity:SetTextColor(1, 1, 1, 1)
    end
end

local function PrepareBlizzardBagButton(btn, bagID)
    if not btn or not bagFrame then return nil end
    btn.bagID = bagID
    btn:SetParent(bagFrame)
    btn:SetSize(22, 22)
    btn:SetFrameLevel(bagFrame:GetFrameLevel() + 6)

    if not btn._rexBagPrepared then
        btn._rexBagPrepared = true

        btn.rexBorder = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        btn.rexBorder:SetAllPoints(btn)
        btn.rexBorder:SetFrameLevel(btn:GetFrameLevel() + 3)
        btn.rexBorder:EnableMouse(false)
        btn.rexBorder:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        btn.rexBorder:SetBackdropColor(0.02, 0.015, 0.025, 0.18)

        btn.slotLabel = btn.rexBorder:CreateFontString(nil, "OVERLAY")
        btn.slotLabel:SetFont(STANDARD_TEXT_FONT, 7, "OUTLINE")
        btn.slotLabel:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -1)

        btn.capacity = btn.rexBorder:CreateFontString(nil, "OVERLAY")
        btn.capacity:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
        btn.capacity:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 1)

        if btn.Count then btn.Count:SetAlpha(0) end

        -- Blizzard behält seine sicheren Klick- und Drag-Skripte. RexUI hängt
        -- nur Zusatzinformationen an den originalen Tooltip an.
        btn:HookScript("OnEnter", function(self)
            local total, free = GetBagSlotStats(self.bagID)
            GameTooltip:AddLine(" ")
            if self.bagID == GetBagIndex("ReagentBag", 5) then
                GameTooltip:AddLine(T("Materialtasche (Reagenzien)"), 0.25, 1.00, 0.82)
            elseif self.bagID == GetKeyringBagID() then
                GameTooltip:AddLine(T("Schlüsselbund"), 1.00, 0.82, 0.20)
            elseif self.bagID == 0 then
                GameTooltip:AddLine(T("Fester Rucksack"), 0.92, 0.20, 1.00)
            else
                GameTooltip:AddLine(string.format(T("Taschenplatz %d"), self.bagID), 0.92, 0.20, 1.00)
            end
            GameTooltip:AddLine(string.format(T("%d Plätze, %d frei"), total, free), 1, 1, 1)
            GameTooltip:Show()
        end)
    end

    UpdateBagSlotButtonVisual(btn)
    return btn
end

local function EnsureBagSlotButtons()
    if not bagFrame then return end
    if B.EquipmentBagBarActive then
        bagFrame.bagSlotButtons = nil
        return
    end

    local buttons = {}
    local candidates = {
        { _G.MainMenuBarBackpackButton, 0 },
        { _G.CharacterBag0Slot, 1 },
        { _G.CharacterBag1Slot, 2 },
        { _G.CharacterBag2Slot, 3 },
        { _G.CharacterBag3Slot, 4 },
    }
    if not IsForeverClient() then
        table.insert(candidates, { _G.CharacterReagentBag0Slot, GetBagIndex("ReagentBag", 5) })
        table.insert(candidates, { _G.KeyRingButton, GetKeyringBagID() })
    end

    for _, candidate in ipairs(candidates) do
        local button = PrepareBlizzardBagButton(candidate[1], candidate[2])
        if button then table.insert(buttons, button) end
    end
    bagFrame.bagSlotButtons = buttons
end

local function UpdateButton(btn, info)
    btn.icon:SetTexture(info.icon or nil)
    btn.icon:SetAlpha(1)
    btn.icon:SetDesaturated(info.isLocked and true or false)
    btn.icon:SetShown(info.icon ~= nil)

    -- Wie ElvUI: Die Spezialtaschenfarbe liegt direkt auf dem vollständigen
    -- normalen Slot-Rahmen. Seltene und höherwertige Gegenstände behalten
    -- Vorrang und verwenden weiterhin ihre Qualitätsfarbe.
    local isReagentSlot = btn.BagID == GetBagIndex("ReagentBag", 5)
    local cfg = GetConfig()
    local r, g, b = 0.23, 0.13, 0.24
    if isReagentSlot and cfg.showReagentSlotColor ~= false then
        local color = cfg.reagentSlotColor or { r = 0.18, g = 0.75, b = 0.50 }
        r, g, b = color.r or 0.18, color.g or 0.75, color.b or 0.50
    end
    if info.icon and info.quality and info.quality > 1 then
        r, g, b = GetQualityColor(info.quality or 0)
    end
    btn.border:SetBackdropBorderColor(r, g, b, 1)

    if info.count and info.count > 1 then
        btn.rexCountText:SetText(info.count)
        btn.rexCountText:Show()
    else
        btn.rexCountText:SetText("")
        btn.rexCountText:Hide()
    end

    SetProfessionQualityDiamond(btn.professionQualityIcon, info.professionQuality, info.professionQualityAtlas)

    btn._rexIsReagentSlot = isReagentSlot

    if info.cooldownDuration and info.cooldownDuration > 0 and info.cooldownStart then
        btn.cooldown:SetCooldown(info.cooldownStart, info.cooldownDuration)
        btn.cooldown:Show()
    else
        btn.cooldown:Hide()
    end

    btn:Show()
end

local function StripTextures(frame)
    if not frame or not frame.GetRegions then return end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            region:SetTexture(nil)
            region:SetAlpha(0)
        end
    end
end

local function HideRegion(region)
    if region and region.Hide then
        region:Hide()
    elseif region and region.SetAlpha then
        region:SetAlpha(0)
    end
end

local function Clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function GetVisualSlotInset()
    return 1
end

local function GetBagFrameScale()
    local cfg = GetConfig()
    return Clamp(cfg.scale or 1, 0.5, 2)
end

local function GetLayoutMetrics()
    local scale = GetBagFrameScale()
    local size = math.floor((30 * scale) + 0.5)
    local spacing = math.max(1, math.floor((2 * scale) + 0.5))
    local topControlSize = math.max(18, math.floor((22 * scale) + 0.5))
    local headerButtonSize = math.max(20, math.floor((22 * scale) + 0.5))
    local searchHeight = math.max(17, math.floor((20 * scale) + 0.5))
    local headerRowGap = math.max(4, math.floor((6 * scale) + 0.5))
    local itemRowGap = math.max(8, math.floor((8 * scale) + 0.5))
    -- Derive the header from the real minimum control sizes. This prevents
    -- small bag scales from shrinking the header underneath its contents.
    local headerRowOffset = 4 + topControlSize + headerRowGap
    local topOffset = headerRowOffset + math.max(headerButtonSize, searchHeight) + itemRowGap
    local horizontalPadding = math.max(12, math.floor((19 * scale) + 0.5))
    local headerHeight = topOffset
    local footerHeight = math.max(8, math.floor((10 * scale) + 0.5))

    return size, spacing, topOffset, horizontalPadding, headerHeight, footerHeight,
        headerRowOffset, headerButtonSize, searchHeight
end

local function SetPixelBorderColor(border, r, g, b, a)
    if not border then return end
    for _, line in ipairs(border) do
        line:SetColorTexture(r, g, b, a)
    end
end

local function CreatePixelBorder(parent, r, g, b, a)
    local border = {}
    for index = 1, 4 do
        border[index] = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    end

    border[1]:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
    border[1]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -1)
    border[1]:SetHeight(1)

    border[2]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 1, 1)
    border[2]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -1, 1)
    border[2]:SetHeight(1)

    border[3]:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
    border[3]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 1, 1)
    border[3]:SetWidth(1)

    border[4]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -1)
    border[4]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -1, 1)
    border[4]:SetWidth(1)

    SetPixelBorderColor(border, r, g, b, a)
    return border
end

local function StyleControlButton(button)
    if not button then return end

    if not button._rexControlSkinned then
        button._rexControlSkinned = true
        StripTextures(button)

        button.RexUIBackdrop = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.RexUIBackdrop:SetAllPoints(button)
        button.RexUIBackdrop:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
        button.RexUIBackdrop:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })

        local icon = button.Icon or button.icon or button:GetNormalTexture()
        if icon then
            button.RexUIIcon = icon
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
            icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            icon:SetAlpha(1)
            icon:Show()
        end
    end

    button.RexUIBackdrop:SetBackdropColor(0.02, 0.015, 0.025, 0.95)
    button.RexUIBackdrop:SetBackdropBorderColor(0.62, 0.12, 0.80, 0.95)
end

local function StyleBlizzardItemButton(button)
    if not button or button._rexSkinned then return end
    button._rexSkinned = true

    StripTextures(button)

    if button.SetBackdrop then
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        button:SetBackdropColor(0.02, 0.015, 0.025, 0.92)
        button:SetBackdropBorderColor(0.23, 0.13, 0.24, 0.95)
    elseif not button.RexUIBackdrop then
        button.RexUIBackdrop = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.RexUIBackdrop:SetAllPoints(button)
        button.RexUIBackdrop:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
        button.RexUIBackdrop:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        button.RexUIBackdrop:SetBackdropColor(0.02, 0.015, 0.025, 0.92)
        button.RexUIBackdrop:SetBackdropBorderColor(0.23, 0.13, 0.24, 0.95)
    end

    local icon = button.icon or button.Icon
    if icon then
        button.RexUIIcon = icon
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon:SetAlpha(1)
    end

    HideRegion(button.IconBorder)
    HideRegion(button.NormalTexture)
    HideRegion(button.NewItemTexture)
    HideRegion(button.BattlepayItemTexture)

    if button.searchOverlay and button.searchOverlay.SetColorTexture then
        button.searchOverlay:SetColorTexture(0, 0, 0, 0.75)
    end
end

local function ApplyBlizzardItemButtonConfig(button)
    local icon = button and (button.RexUIIcon or button.icon or button.Icon)
    if not icon then return end

    local inset = GetVisualSlotInset()
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
end

local function UpdateBlizzardItemButton(button)
    if not button then return end

    StyleBlizzardItemButton(button)
    ApplyBlizzardItemButtonConfig(button)

    local bagID = button.GetBagID and button:GetBagID()
    local slotID = button.GetID and button:GetID()
    if button.GetSlotAndBagID then
        slotID, bagID = button:GetSlotAndBagID()
    end

    local info = bagID and slotID and GetSlotInfo(bagID, slotID, IsMerchantBusy())
    if not info then return end

    local icon = button.RexUIIcon or button.icon or button.Icon
    if icon then
        if info.icon then
            icon:SetTexture(info.icon)
            icon:SetAlpha(1)
            icon:Show()
        else
            icon:SetTexture(nil)
            icon:SetAlpha(0)
            icon:Hide()
        end
    end

    HideRegion(button.IconQuestTexture)
    HideRegion(button.JunkIcon)
    HideRegion(button.UpgradeIcon)
    HideRegion(button.ItemContextOverlay)

    local r, g, b = 0.23, 0.13, 0.24
    if info.icon and info.quality and info.quality > 1 then
        r, g, b = GetQualityColor(info.quality or 0)
    end

    if button.SetBackdropBorderColor then
        button:SetBackdropBorderColor(r, g, b, 1)
    elseif button.RexUIBackdrop then
        button.RexUIBackdrop:SetBackdropBorderColor(r, g, b, 1)
    end

    if not button.RexUIProfessionQuality then
        local tex = button:CreateTexture(nil, "OVERLAY")
        tex:SetSize(13, 13)
        tex:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -1, -1)
        tex:Hide()
        button.RexUIProfessionQualityIcon = tex

        local fs = button:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
        fs:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -1, -3)
        fs:SetJustifyH("LEFT")
        button.RexUIProfessionQuality = fs
    end

    SetProfessionQualityDiamond(button.RexUIProfessionQualityIcon, info.professionQuality, info.professionQualityAtlas)
end

local function StyleBlizzardContainer(frame)
    if not frame then return end

    if not frame._rexContainerSkinned then
        frame._rexContainerSkinned = true

        StripTextures(frame)

        HideRegion(frame.Bg)
        HideRegion(frame.Background)
        HideRegion(frame.NineSlice)
        HideRegion(frame.TopTileStreaks)
        HideRegion(frame.Portrait)
        HideRegion(frame.PortraitContainer)

        if frame.TitleContainer then
            StripTextures(frame.TitleContainer)
            HideRegion(frame.TitleContainer.Background)
            HideRegion(frame.TitleContainer.Left)
            HideRegion(frame.TitleContainer.Middle)
            HideRegion(frame.TitleContainer.Right)
        end

        if not frame.RexUIPanel then
            frame.RexUIPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
            frame.RexUIPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            frame.RexUIPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            frame.RexUIPanel:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
            frame.RexUIPanel:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
        end

        frame.RexUIPanel:SetBackdropColor(0.02, 0.015, 0.025, 0.90)
        frame.RexUIPanel:SetBackdropBorderColor(0.62, 0.12, 0.80, 0.95)

        if frame.TitleContainer and frame.TitleContainer.TitleText then
            frame.TitleContainer.TitleText:SetTextColor(0.92, 0.20, 1.00, 1)
        end

        StyleControlButton(frame.CloseButton)
        StyleControlButton(frame.PortraitButton)
        if frame.PortraitButton then
            frame.PortraitButton:SetSize(frame == _G.ContainerFrameCombinedBags and 34 or 28, frame == _G.ContainerFrameCombinedBags and 34 or 28)
            frame.PortraitButton:ClearAllPoints()
            frame.PortraitButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
        end

        if frame.UpdateItems then
            pcall(hooksecurefunc, frame, "UpdateItems", function(container)
                StyleBlizzardContainer(container)
            end)
        end
    end

    pcall(frame.SetScale, frame, GetBagFrameScale())

    if frame.RexUIPanel then
        frame.RexUIPanel:SetBackdropColor(0.02, 0.015, 0.025, 0.90)
        frame.RexUIPanel:SetBackdropBorderColor(0.62, 0.12, 0.80, 0.95)
    end

    if frame.EnumerateValidItems then
        for _, button in frame:EnumerateValidItems() do
            UpdateBlizzardItemButton(button)
        end
    end
end

local function SkinAllBlizzardBags()
    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar("combinedBags", "1")
    elseif SetCVar then
        SetCVar("combinedBags", "1")
    end

    for i = 1, NUM_CONTAINER_FRAMES or 5 do
        StyleBlizzardContainer(_G["ContainerFrame" .. i])
    end

    StyleBlizzardContainer(_G.ContainerFrameCombinedBags)

    if _G.BagItemSearchBox and not _G.BagItemSearchBox._rexSkinned then
        local searchBox = _G.BagItemSearchBox
        searchBox._rexSkinned = true

        StripTextures(searchBox)

        if not searchBox.RexUIBackdrop then
            searchBox.RexUIBackdrop = CreateFrame("Frame", nil, searchBox, "BackdropTemplate")
            searchBox.RexUIBackdrop:SetPoint("TOPLEFT", searchBox, "TOPLEFT", -2, 2)
            searchBox.RexUIBackdrop:SetPoint("BOTTOMRIGHT", searchBox, "BOTTOMRIGHT", 2, -2)
            searchBox.RexUIBackdrop:SetFrameLevel(math.max(0, searchBox:GetFrameLevel() - 1))
            searchBox.RexUIBackdrop:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
        end
    end

    if _G.BagItemSearchBox and _G.BagItemSearchBox.RexUIBackdrop then
        _G.BagItemSearchBox.RexUIBackdrop:SetBackdropColor(0.02, 0.015, 0.025, 0.92)
        _G.BagItemSearchBox.RexUIBackdrop:SetBackdropBorderColor(0.62, 0.12, 0.80, 0.95)
    end

    StyleControlButton(_G.BagItemAutoSortButton)
end

function B:Refresh()
    self:UpdateBagBar()
    if bagFrame and bagFrame:IsShown() then
        self:ScheduleLayout()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            B:UpdateBagBar()
            if bagFrame and bagFrame:IsShown() then
                B:ScheduleLayout()
            end
        end)
    end
end

function B:UpdateBagBar()
    if B.EquipmentBagBarActive and B.UpdateEquipmentBagBar then
        B:UpdateEquipmentBagBar()
        return
    end
    if InCombatLockdown and InCombatLockdown() then return end
    if updatingBagBar then return end
    updatingBagBar = true

    local bar = _G.BagsBar
    if bar then
        bar:Hide()
        bar:SetAlpha(0)
        bar:EnableMouse(false)
        if bar.UnregisterAllEvents then
            bar:UnregisterAllEvents()
        end
    end

    if _G.BagBarExpandToggle then
        _G.BagBarExpandToggle:Hide()
        _G.BagBarExpandToggle:SetAlpha(0)
        _G.BagBarExpandToggle:EnableMouse(false)
    end
    HideStrayKeyRing()

    -- Blizzards originale Taschenbuttons weiterverwenden. Dadurch
    -- bleiben geschützte Klick-, Tooltip- und Drag-and-drop-Skripte unangetastet.
    EnsureBagSlotButtons()
    if bagFrame and bagFrame.bagSlotButtons then
        for _, bagButton in ipairs(bagFrame.bagSlotButtons) do
            bagButton:SetParent(bagFrame)
            bagButton:SetAlpha(1)
            bagButton:EnableMouse(true)
            bagButton:Show()
        end
    end

    updatingBagBar = false
    if bagFrame and bagFrame:IsShown() and B.ScheduleLayout then
        B:ScheduleLayout()
    end
end

function B:UpdateLayout(targetFrame)
    local frame = targetFrame or bagFrame
    if type(self) == "table" and self.isBagFrame then
        frame = self
    end
    if not frame then return end
    frame._rexLayoutGeneration = (frame._rexLayoutGeneration or 0) + 1
    frame._rexLayoutReady = true
    local generation = frame._rexLayoutGeneration

    local size, spacing, topOffset, horizontalPadding, headerHeight, footerHeight,
        headerRowOffset, headerButtonSize, searchHeight = GetLayoutMetrics()
    EnsureBagSlotButtons()

    local items = CollectSlots(frame)
    local numItems = #items

    if numItems == 0 then
        frame:SetScale(1)
        frame:SetSize(180, 60)
        frame:Show()
        return
    end

    local cols = 16
    local rows = math.ceil(numItems / cols)

    local gridW = horizontalPadding * 2 + cols * (size + spacing) - spacing
    local gridH = headerHeight + rows * (size + spacing) - spacing + footerHeight
    frame:SetScale(1)
    frame:SetSize(gridW, gridH)
    if frame.closeButton then
        local controlSize = math.max(18, math.floor((22 * GetBagFrameScale()) + 0.5))
        frame.closeButton:SetSize(controlSize, controlSize)
        frame.closeButton:ClearAllPoints()
        frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -2)
    end
    if frame.helpButton and frame.closeButton then
        local controlSize = math.max(16, math.floor((18 * GetBagFrameScale()) + 0.5))
        frame.helpButton:SetSize(controlSize, controlSize)
        frame.helpButton:ClearAllPoints()
        frame.helpButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -1, 0)
    end
    if frame.headerButtons then
        local buttonSize = headerButtonSize
        local buttonSpacing = math.max(2, math.floor((3 * GetBagFrameScale()) + 0.5))
        local anchor = frame
        for index = #frame.headerButtons, 1, -1 do
            local button = frame.headerButtons[index]
            button:SetSize(buttonSize, buttonSize)
            button:ClearAllPoints()
            if anchor == frame then
                button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -horizontalPadding, -headerRowOffset)
            else
                button:SetPoint("RIGHT", anchor, "LEFT", -buttonSpacing, 0)
            end
            button:Show()
            anchor = button
        end
    end
    if frame.searchBox then
        local headerButtonCount = frame.headerButtons and #frame.headerButtons or 0
        local buttonSize = headerButtonSize
        local buttonSpacing = math.max(2, math.floor((3 * GetBagFrameScale()) + 0.5))
        local controlsWidth = headerButtonCount * buttonSize + math.max(0, headerButtonCount - 1) * buttonSpacing

        frame.searchBox:ClearAllPoints()
        frame.searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", horizontalPadding, -headerRowOffset)
        frame.searchBox:SetSize(math.max(120, gridW - horizontalPadding * 2 - controlsWidth - 5), searchHeight)
    end
    if frame.moneyText then
        frame.moneyText:SetText(GetMoneyText())
        frame.moneyText:ClearAllPoints()
        if frame.helpButton then
            frame.moneyText:SetPoint("RIGHT", frame.helpButton, "LEFT", -8, 0)
        else
            frame.moneyText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -5)
        end
    end
    if frame.durabilityText then
        frame.durabilityText:SetText(GetDurabilityText())
        frame.durabilityText:ClearAllPoints()
        if frame.moneyText then
            frame.durabilityText:SetPoint("RIGHT", frame.moneyText, "LEFT", -10, 0)
        else
            frame.durabilityText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -150, -5)
        end
        frame.durabilityText:Show()
    end
    if frame.spaceText then
        frame.spaceText:SetText(GetBagSpaceText())
        frame.spaceText:ClearAllPoints()
        if frame.durabilityText then
            frame.spaceText:SetPoint("RIGHT", frame.durabilityText, "LEFT", -10, 0)
        elseif frame.moneyText then
            frame.spaceText:SetPoint("RIGHT", frame.moneyText, "LEFT", -10, 0)
        else
            frame.spaceText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -220, -5)
        end
        frame.spaceText:Show()
    end
    frame:Show()

    for _, btn in ipairs(bagButtons) do
        if btn._rexOwnerFrame == frame then
            btn._rexLayoutActive = false
        end
    end

    local function LayoutButtonRange(firstIndex)
        if generation ~= frame._rexLayoutGeneration or not frame or not frame:IsShown() then
            return
        end

        local lastIndex = math.min(numItems, firstIndex + LAYOUT_BATCH_SIZE - 1)

        for i = firstIndex, lastIndex do
            local info = items[i]
            local btn = GetItemButton(info)
            if not btn then return end
            btn._rexLayoutActive = true

            btn:SetSize(size, size)

            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", horizontalPadding + col * (size + spacing), -topOffset - row * (size + spacing))

            btn.icon:ClearAllPoints()
            btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
            btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)

            btn.cooldown:ClearAllPoints()
            btn.cooldown:SetAllPoints(btn.icon)

            btn.rexCountText:ClearAllPoints()
            btn.rexCountText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)

            UpdateButton(btn, info)
            if SlotMatchesSearch(info) then
                btn:SetAlpha(1)
            else
                btn:SetAlpha(0.25)
            end
        end

        if lastIndex < numItems then
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    LayoutButtonRange(lastIndex + 1)
                end)
            else
                LayoutButtonRange(lastIndex + 1)
            end
            return
        end

        for _, btn in ipairs(bagButtons) do
            if btn._rexOwnerFrame == frame and not btn._rexLayoutActive then
                btn:Hide()
            end
        end
    end

    LayoutButtonRange(1)
end

function B:ScheduleLayout(targetFrame)
    if targetFrame and not targetFrame:IsShown() then return end
    if not targetFrame and not (bagFrame and bagFrame:IsShown()) then return end
    if layoutScheduled then return end
    if InCombatLockdown and InCombatLockdown() then return end

    layoutScheduled = true

    local function RunLayout()
        layoutScheduled = false

        if targetFrame then
            if targetFrame:IsShown() then
                B:UpdateLayout(targetFrame)
            end
            return
        end

        if bagFrame and bagFrame:IsShown() then
            B:UpdateLayout(bagFrame)
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(IsMerchantBusy() and 0.18 or 0.05, RunLayout)
    else
        RunLayout()
    end
end

local lastShowAt = 0
local lastItemMoveAt = 0
local bagFrameOpen = false

local function IsBackpackOpen()
    if IsBagOpen then
        return IsBagOpen(BACKPACK_CONTAINER or 0)
    end

    return false
end

local function GiveZero()
    return 0
end

local function DisableBlizzardFrame(frame, noRight)
    if not frame or frame._rexDisabled then return end
    frame._rexDisabled = true

    frame:SetScript("OnShow", nil)
    frame:SetScript("OnHide", nil)
    frame:UnregisterAllEvents()
    frame:ClearAllPoints()
    frame.GetRight = noRight and GiveZero or nil

    pcall(hooksecurefunc, frame, "SetPoint", frame.ClearAllPoints)
end

local function DisableBlizzardBags()
    for i = 1, NUM_CONTAINER_FRAMES or 5 do
        DisableBlizzardFrame(_G["ContainerFrame" .. i])
    end

    local combinedBag = _G.ContainerFrameCombinedBags
    if combinedBag then
        DisableBlizzardFrame(combinedBag)

        if combinedBag.RegisterEvent then
            combinedBag:RegisterEvent("BAG_CONTAINER_UPDATE")
        end
    end
    HideStrayKeyRing()
end

local function ShowBagFrame(skipSound)
    if not bagFrame then return end
    HideStrayKeyRing()
    if bagFrameOpen and bagFrame:IsShown() then
        return
    end

    lastShowAt = GetTime and GetTime() or 0
    bagFrameOpen = true
    if not skipSound and PlaySound and SOUNDKIT and SOUNDKIT.IG_BACKPACK_OPEN then
        PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
    end
    local cfg = GetConfig()
    bagFrame:ClearAllPoints()
    bagFrame:SetPoint(cfg.bagPoint or "CENTER", UIParent, cfg.bagRelPoint or "CENTER", cfg.bagX or 0, cfg.bagY or 0)

    if InCombatLockdown and InCombatLockdown() then
        -- Alle Taschenplätze wurden außerhalb des Kampfes vorab erzeugt.
        -- Das Layout muss beim Öffnen trotzdem neu gesammelt werden, weil das
        -- zuletzt vorbereitete Layout unvollständig oder veraltet sein kann.
        B:UpdateLayout()
    else
        B:UpdateBagBar()
        B:UpdateLayout()
    end

    bagFrame:Show()

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            B:UpdateBagBar()
        end)
    end
end

local function HideBagFrame(skipSound)
    local now = GetTime and GetTime() or 0
    if now - lastShowAt < 0.15 then return end

    bagFrameOpen = false
    if bagFrame then
        if B.HideEquipmentBagsInFrame then B:HideEquipmentBagsInFrame(bagFrame) end
        bagFrame:Hide()
        if not skipSound and PlaySound and SOUNDKIT and SOUNDKIT.IG_BACKPACK_CLOSE then
            PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
        end
    end
end

local function IsItemOnCursor()
    if CursorHasItem and CursorHasItem() then return true end

    if GetCursorInfo then
        local kind = GetCursorInfo()
        return kind == "item"
    end

    return false
end

MarkItemMove = function()
    lastItemMoveAt = GetTime and GetTime() or 0
end

function B:MarkItemMove()
    MarkItemMove()
end

local function IsRecentItemMove()
    local now = GetTime and GetTime() or 0
    return now - lastItemMoveAt < 1.00
end

local function HideBagFrameFromExternalClose()
    if IsItemOnCursor() or IsRecentItemMove() then
        if B.UpdateLayout then
            B:UpdateLayout()
        end
        return
    end

    HideBagFrame(true)
end

function B:OpenBags()
    if not bagFrame then return end
    if bagFrameOpen or bagFrame:IsShown() then return end

    ShowBagFrame()
end

function B:CloseAllBags()
    if not bagFrame then return true end
    if not bagFrameOpen and not bagFrame:IsShown() then return true end

    lastShowAt = 0
    HideBagFrame()
end

function B:ToggleAllBags()
    if not bagFrame then return end

    if IsBackpackOpen() then
        ShowBagFrame()
    else
        lastShowAt = 0
        HideBagFrame()
    end
end

function B:ToggleBackpack()
    self:ToggleAllBags()
end

function B:Toggle()
    self:ToggleAllBags()
end

function B:ResetPosition()
    Save("bagPoint", "CENTER")
    Save("bagRelPoint", "CENTER")
    Save("bagX", 0)
    Save("bagY", 0)

    if bagFrame then
        bagFrame:ClearAllPoints()
        bagFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        if bagFrame:IsShown() and self.UpdateLayout then
            self:UpdateLayout()
        end
    end

    if mover then
        mover:ClearAllPoints()
        mover:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    if RexUI.PrintMessage then
        RexUI:PrintMessage("Taschenposition zurückgesetzt.")
    end
end

local function InstallHooks()
    if _G.BagsBar and _G.BagsBar.Layout then
        pcall(hooksecurefunc, _G.BagsBar, "Layout", function()
            B:UpdateBagBar()
        end)
    end

    if _G.MainMenuBarBagManager and _G.MainMenuBarBagManager.OnExpandBarChanged then
        pcall(hooksecurefunc, _G.MainMenuBarBagManager, "OnExpandBarChanged", function()
            B:UpdateBagBar()
        end)
    end

    pcall(hooksecurefunc, "OpenAllBags", function()
        if not bagFrame then return end
        B:OpenBags()
    end)

    pcall(hooksecurefunc, "ToggleAllBags", function()
        if not bagFrame then return end
        B:ToggleAllBags()
    end)

    pcall(hooksecurefunc, "ToggleBackpack", function()
        if not bagFrame then return end
        B:ToggleBackpack()
    end)

    pcall(hooksecurefunc, "ToggleBag", function()
        if not bagFrame then return end
        B:ToggleAllBags()
        HideStrayKeyRing()
    end)

    if ToggleKeyRing then
        pcall(hooksecurefunc, "ToggleKeyRing", function()
            if not bagFrame then return end
            B:OpenBags()
            HideStrayKeyRing()
        end)
    end

    pcall(hooksecurefunc, "CloseAllBags", function()
        HideBagFrameFromExternalClose()
    end)

    pcall(hooksecurefunc, "CloseBag", function()
        -- Blizzard closes the individual container while an equipped bag is
        -- exchanged. A combined bag window must stay open and only relayout.
        if bagFrame and bagFrame:IsShown() then
            B:ScheduleLayout()
        end
    end)

end

function B:CreateMover()
    if mover then return end
    if InCombatLockdown() then return end

    mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    mover:SetSize(200, 45)
    self.MainBagMover = mover
    mover:SetClampedToScreen(true)
    mover:SetMovable(true)
    mover:SetFrameLevel(100)

    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    mover:SetBackdropColor(0.2, 0.6, 1, 0.2)
    mover:SetBackdropBorderColor(0.2, 0.6, 1, 0.9)

    local label = mover:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    label:SetPoint("TOP", mover, "TOP", 0, -8)
    label:SetText(T("Taschen"))
    label:SetTextColor(1, 1, 1, 1)

    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")

    mover:SetScript("OnDragStart", function()
        mover.dragged = true
        mover:StartMoving()
    end)

    mover:SetScript("OnDragStop", function()
        mover:StopMovingOrSizing()
        local point, _, relPoint, x, y = mover:GetPoint()
        if point then
            Save("bagPoint", point)
            Save("bagRelPoint", relPoint or point)
            Save("bagX", math.floor((x or 0) + 0.5))
            Save("bagY", math.floor((y or 0) + 0.5))
        end
    end)

    mover:SetScript("OnMouseUp", function(self)
        if self.dragged then
            self.dragged = false
            return
        end
        if RexUI.ConfigUI and RexUI.ConfigUI.Open then
            RexUI.ConfigUI:Open()
            if RexUI.ConfigUI.SetCategory then
                RexUI.ConfigUI:SetCategory("Taschen")
            end
        end
    end)

    mover:Hide()
end

function B:ShowMover()
    if InCombatLockdown() then
        if RexUI.ActionBars and RexUI.ActionBars.RunOutOfCombat then
            RexUI.ActionBars:RunOutOfCombat("BagsShowMover", function()
                B:ShowMover()
            end)
        end
        return
    end

    B:CreateMover()
    if mover then
        local cfg = GetConfig()
        mover:ClearAllPoints()
        mover:SetPoint(cfg.bagPoint or "CENTER", UIParent, cfg.bagRelPoint or "CENTER", cfg.bagX or 0, cfg.bagY or 0)
        mover:Show()
    end
    if B.ShowBagBarMover then B:ShowBagBarMover() end
end

function B:HideMover()
    if mover then
        mover:Hide()
    end
    if B.HideBagBarMover then B:HideBagBarMover() end
end

function B:Initialize()
    if self._initialized then return end
    self._initialized = true

    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar("combinedBags", "1")
    elseif SetCVar then
        SetCVar("combinedBags", "1")
    end

    local profile = RexUI:GetProfile()
    if profile then
        profile.bags = profile.bags or {}
        if profile.bags.elvWindowLayoutVersion ~= 2 then
            -- Alte Profile enthielten oft noch 0,9. Das Referenzlayout mit
            -- 16 x 30-Pixel-Slots benoetigt bei Standardskalierung 540 Pixel.
            profile.bags.scale = 1
            profile.bags.elvWindowLayoutVersion = 2
        end
    end

    bagFrame = CreateFrame("Frame", "RexUIBagsFrame", UIParent, "BackdropTemplate")
    bagFrame.isBagFrame = true
    bagFrame:SetFrameStrata("MEDIUM")
    bagFrame:SetFrameLevel(10)
    bagFrame:SetClampedToScreen(true)
    RegisterUISpecialFrame("RexUIBagsFrame")

    bagFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    bagFrame:SetBackdropColor(0.02, 0.015, 0.025, 0.92)
    bagFrame:SetBackdropBorderColor(0.62, 0.12, 0.80, 0.95)

    local cfg = GetConfig()
    bagFrame:SetPoint(cfg.bagPoint or "CENTER", UIParent, cfg.bagRelPoint or "CENTER", cfg.bagX or 0, cfg.bagY or 0)

    local title = bagFrame:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    title:SetPoint("TOP", bagFrame, "TOP", 0, -5)
    title:SetText(T("Taschen"))
    title:SetTextColor(0.92, 0.20, 1.00, 1)
    title:Hide()
    bagFrame.title = title

    local close = CreateFrame("Button", nil, bagFrame, "BackdropTemplate")
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", bagFrame, "TOPRIGHT", -4, -4)
    close:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    close:SetBackdropColor(0.02, 0.015, 0.025, 0.95)
    close:SetBackdropBorderColor(0.62, 0.12, 0.80, 0.95)
    close.text = close:CreateFontString(nil, "OVERLAY")
    close.text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    close.text:SetPoint("CENTER")
    close.text:SetText("X")
    close.text:SetTextColor(0.92, 0.20, 1.00, 1)
    close:SetScript("OnClick", function()
        HideBagFrame()
    end)
    bagFrame.closeButton = close

    local help = CreateFrame("Button", nil, bagFrame)
    help:SetSize(16, 16)
    help:SetPoint("RIGHT", close, "LEFT", -1, 0)
    help.text = help:CreateFontString(nil, "OVERLAY")
    help.text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    help.text:SetPoint("CENTER")
    help.text:SetText("?")
    help.text:SetTextColor(1, 0.82, 0, 1)
    help:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(T("Taschen"), 0.92, 0.20, 1.00)
        GameTooltip:AddLine(T("Suche links, Taschenaktionen rechts und alle Gegenstände in einem gemeinsamen Raster."), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    help:SetScript("OnLeave", GameTooltip_Hide)
    bagFrame.helpButton = help

    local function CreateHeaderAction(texture, atlas, tooltipTitle, tooltipText, onClick)
        local button = CreateFrame("Button", nil, bagFrame, "BackdropTemplate")
        button:SetSize(20, 20)
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        button:SetBackdropColor(0.02, 0.015, 0.025, 0.95)
        button:SetBackdropBorderColor(0, 0, 0, 0)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        if atlas then
            button.icon:SetAtlas(texture)
        else
            button.icon:SetTexture(texture)
        end
        if button.icon.SetSnapToPixelGrid then button.icon:SetSnapToPixelGrid(false) end
        if button.icon.SetTexelSnappingBias then button.icon:SetTexelSnappingBias(0) end

        button.border = CreatePixelBorder(button, 0.62, 0.12, 0.80, 0.95)
        button:SetScript("OnEnter", function(self)
            SetPixelBorderColor(self.border, 0.92, 0.20, 1.00, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(T(tooltipTitle), 0.92, 0.20, 1.00)
            if tooltipText then GameTooltip:AddLine(T(tooltipText), 0.8, 0.8, 0.8, true) end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function(self)
            SetPixelBorderColor(self.border, 0.62, 0.12, 0.80, 0.95)
            GameTooltip_Hide()
        end)
        button:SetScript("OnClick", onClick)
        return button
    end

    local vendor = CreateHeaderAction(
        "Interface\\Icons\\INV_Misc_Coin_01", false,
        "Graue Gegenstände verkaufen", "Nur verfügbar, wenn ein Händler geöffnet ist.",
        function()
            local sellJunk = RexUI.Comfort and RexUI.Comfort.Modules and RexUI.Comfort.Modules.SellJunk
            if sellJunk and sellJunk.SellNow then sellJunk:SellNow() end
        end
    )
    local bagsToggle = CreateHeaderAction(
        "Interface\\Icons\\INV_Misc_Bag_08", false,
        "Taschen an-/ausschalten", "Blendet die ausgerüsteten Taschenplätze oberhalb des Taschenfensters ein oder aus.",
        function()
            if B.ToggleEquipmentBagsInFrame then B:ToggleEquipmentBagsInFrame(bagFrame) end
        end
    )
    local sort = CreateHeaderAction(
        "bags-button-autosort-up", true,
        "Taschen sortieren", "Sortiert alle Gegenstände automatisch.",
        function()
            if InCombatLockdown and InCombatLockdown() then return end
            if C_Container and C_Container.SortBags then C_Container.SortBags() end
        end
    )
    local stack = CreateHeaderAction(
        "Interface\\Icons\\INV_Crate_06", false,
        "Gegenstände stapeln", "Führt Stapel zusammen und räumt die Taschen auf.",
        function()
            if InCombatLockdown and InCombatLockdown() then return end
            if C_Container and C_Container.SortBags then C_Container.SortBags() end
        end
    )
    bagFrame.vendorButton = vendor
    bagFrame.bagsButton = bagsToggle
    bagFrame.sortButton = sort
    bagFrame.stackButton = stack
    bagFrame.headerButtons = { vendor, bagsToggle, sort, stack }

    EnsureBagSlotButtons()

    local searchBox = CreateFrame("EditBox", nil, bagFrame, "BackdropTemplate")
    searchBox:SetSize(160, 18)
    searchBox:SetPoint("TOPLEFT", bagFrame, "TOPLEFT", 10, -24)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject(GameFontNormalSmall)
    searchBox:SetTextInsets(22, 8, 2, 2)
    searchBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    searchBox:SetBackdropColor(0.02, 0.015, 0.025, 0.95)
    searchBox:SetBackdropBorderColor(0, 0, 0, 0)
    searchBox:SetTextColor(0.9, 0.9, 0.9, 1)
    -- EditBox clips child regions along its lower edge on some UI scales.
    -- Draw the outline in a separate sibling frame above the EditBox.
    searchBox.borderFrame = CreateFrame("Frame", nil, bagFrame)
    searchBox.borderFrame:SetAllPoints(searchBox)
    searchBox.borderFrame:SetFrameLevel(searchBox:GetFrameLevel() + 5)
    searchBox.borderFrame:EnableMouse(false)
    searchBox.border = CreatePixelBorder(searchBox.borderFrame, 0.62, 0.12, 0.80, 0.95)
    searchBox.searchIcon = searchBox:CreateTexture(nil, "ARTWORK")
    searchBox.searchIcon:SetSize(12, 12)
    searchBox.searchIcon:SetPoint("LEFT", searchBox, "LEFT", 5, 0)
    local hasSearchAtlas = pcall(searchBox.searchIcon.SetAtlas, searchBox.searchIcon, "common-search-magnifyingglass")
    if not hasSearchAtlas then
        searchBox.searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    end
    searchBox.searchIcon:SetVertexColor(0.65, 0.65, 0.65, 1)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    searchBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText() or ""
        if B.ScheduleLayout then
            B:ScheduleLayout()
        end
    end)
    searchBox.placeholder = searchBox:CreateFontString(nil, "OVERLAY")
    searchBox.placeholder:SetFont(STANDARD_TEXT_FONT, 10)
    searchBox.placeholder:SetPoint("LEFT", searchBox, "LEFT", 22, 0)
    searchBox.placeholder:SetText(T("Suchen"))
    searchBox.placeholder:SetTextColor(0.55, 0.55, 0.55, 1)
    searchBox:HookScript("OnTextChanged", function(self)
        searchBox.placeholder:SetShown((self:GetText() or "") == "")
    end)
    bagFrame.searchBox = searchBox

    local moneyText = bagFrame:CreateFontString(nil, "OVERLAY")
    moneyText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    moneyText:SetPoint("RIGHT", help, "LEFT", -8, 0)
    moneyText:SetTextColor(1, 0.82, 0, 1)
    moneyText:SetText(GetMoneyText())
    bagFrame.moneyText = moneyText

    local durabilityText = bagFrame:CreateFontString(nil, "OVERLAY")
    durabilityText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    durabilityText:SetPoint("RIGHT", moneyText, "LEFT", -10, 0)
    durabilityText:SetTextColor(0.9, 0.9, 0.9, 1)
    durabilityText:SetText(GetDurabilityText())
    bagFrame.durabilityText = durabilityText

    local spaceText = bagFrame:CreateFontString(nil, "OVERLAY")
    spaceText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    spaceText:SetPoint("RIGHT", durabilityText, "LEFT", -10, 0)
    spaceText:SetTextColor(0.9, 0.9, 0.9, 1)
    spaceText:SetText(GetBagSpaceText())
    bagFrame.spaceText = spaceText

    bagFrame:Hide()

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("ITEM_UNLOCKED")
    eventFrame:RegisterEvent("PLAYER_MONEY")
    eventFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    eventFrame:RegisterEvent("MERCHANT_CLOSED")

    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" or event == "MERCHANT_CLOSED" then
            lastMerchantEventAt = GetTime and GetTime() or 0
        end

        if not (bagFrame and bagFrame:IsShown()) then return end
        B:ScheduleLayout()

        if event == "BAG_UPDATE_DELAYED" and C_Timer and C_Timer.After then
            -- At this point Retail has committed the new capacity. Run one
            -- final pass so rows and frame height match the equipped bags.
            C_Timer.After(0.10, function()
                if bagFrame and bagFrame:IsShown() and not (InCombatLockdown and InCombatLockdown()) then
                    B:UpdateLayout(bagFrame)
                end
            end)
        end
    end)

    DisableBlizzardBags()
    InstallHooks()
    PrecreateItemButtons()
    B:UpdateLayout()
    bagFrame:Hide()
    bagFrameOpen = false
    B:UpdateBagBar()

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            B:UpdateBagBar()
        end)
    end
end
