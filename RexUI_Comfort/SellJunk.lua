-- ============================================================
-- RexUI_Comfort - SellJunk.lua
-- Graue Gegenstaende automatisch verkaufen
-- ============================================================

local ADDON_NAME, ns = ...

local RexUI =
    ns.RexUI

if not RexUI
or not RexUI.Comfort then
    return
end

local Comfort =
    RexUI.Comfort

-- ------------------------------------------------------------
-- LOKALE VARIABLEN
-- ------------------------------------------------------------

local SellJunk = CreateFrame("Frame")
local isSelling = false
local pendingItems = {}
local pendingValue = 0

local SELL_BATCH_SIZE = 4
local SELL_BATCH_DELAY = 0.08
local MAX_SCAN_ATTEMPTS = 5
local SCAN_RETRY_DELAY = 0.2
local POOR_ITEM_QUALITY =
    (Enum and Enum.ItemQuality and Enum.ItemQuality.Poor)
    or LE_ITEM_QUALITY_POOR
    or 0

local function StopSelling()
    isSelling = false
    wipe(pendingItems)
    pendingValue = 0
end

-- ------------------------------------------------------------
-- PROFIL
-- ------------------------------------------------------------

local function IsEnabled()

    local profile = Comfort:GetProfile()
    if not profile then return false end

    return profile.sellJunk == true
end

-- ------------------------------------------------------------
-- VERKAUF
-- ------------------------------------------------------------

local function PrintSoldValue(totalValue)
    if totalValue <= 0 then return end

    local gold = math.floor(totalValue / 10000)
    local silver = math.floor((totalValue % 10000) / 100)

    RexUI:PrintMessage(
        "Graue Gegenstaende verkauft fuer "
        .. gold .. "g "
        .. silver .. "s."
    )
end

local function GetBagIDs()
    local bags = {}
    local added = {}
    local lastBag = NUM_BAG_SLOTS or 4

    for bag = BACKPACK_CONTAINER or 0, lastBag do
        if not added[bag] then
            bags[#bags + 1] = bag
            added[bag] = true
        end
    end

    local reagentBag = REAGENTBAG_CONTAINER
        or (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag)

    if reagentBag and not added[reagentBag] then
        bags[#bags + 1] = reagentBag
    end

    return bags
end

local function GetContainerItemInfoSafe(bag, slot)
    if not C_Container or not C_Container.GetContainerItemInfo then
        return nil
    end

    local ok, itemInfo = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if ok then
        return itemInfo
    end

    return nil
end

local function GetContainerItemLinkSafe(bag, slot, itemInfo)
    if itemInfo and itemInfo.hyperlink then
        return itemInfo.hyperlink
    end

    if not C_Container or not C_Container.GetContainerItemLink then
        return nil
    end

    local ok, itemLink = pcall(C_Container.GetContainerItemLink, bag, slot)
    if ok then
        return itemLink
    end

    return nil
end

local function UseContainerItemSafe(bag, slot)
    if not C_Container or not C_Container.UseContainerItem then
        return false
    end

    local ok = pcall(C_Container.UseContainerItem, bag, slot)
    return ok == true
end

local function IsPoorItem(quality, itemLink)
    if quality == POOR_ITEM_QUALITY then
        return true
    end

    return type(itemLink) == "string"
        and itemLink:find("|cff9d9d9d", 1, true) ~= nil
end

local function SafeGetItemInfo(item)
    if item == nil then
        return
    end

    if C_Item and type(C_Item.GetItemInfo) == "function" then
        local ok, a, b, c, d, e, f, g, h, i, j, k = pcall(C_Item.GetItemInfo, item)
        if ok then
            return a, b, c, d, e, f, g, h, i, j, k
        end
    end

    if type(GetItemInfo) == "function" then
        local ok, a, b, c, d, e, f, g, h, i, j, k = pcall(GetItemInfo, item)
        if ok then
            return a, b, c, d, e, f, g, h, i, j, k
        end
    end
end

local function GetItemPrice(itemLink, itemID)
    if itemLink then
        local itemPrice = select(11, SafeGetItemInfo(itemLink))
        if itemPrice then
            return itemPrice
        end
    end

    if itemID then
        local itemPrice = select(11, SafeGetItemInfo(itemID))
        if itemPrice then
            return itemPrice
        end
    end

    return nil
end

local function RequestItemData(itemID)
    if itemID
    and C_Item
    and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
end

local function ScanJunkItems()
    wipe(pendingItems)
    pendingValue = 0

    local needsRetry = false

    for _, bag in ipairs(GetBagIDs()) do
        local numSlots = 0

        if C_Container and C_Container.GetContainerNumSlots then
            local ok, result = pcall(C_Container.GetContainerNumSlots, bag)
            if ok and result then
                numSlots = result
            end
        end

        for slot = 1, numSlots do
            local itemInfo = GetContainerItemInfoSafe(bag, slot)

            if itemInfo and not itemInfo.isLocked then
                local itemLink = GetContainerItemLinkSafe(bag, slot, itemInfo)
                local quality = itemInfo.quality
                local itemPrice = GetItemPrice(itemLink, itemInfo.itemID)

                if not itemLink and itemInfo.itemID then
                    needsRetry = true
                    RequestItemData(itemInfo.itemID)
                end

                if quality == nil and (itemLink or itemInfo.itemID) then
                    if itemInfo.itemID and C_Item and type(C_Item.GetItemQualityByID) == "function" then
                        local ok, result = pcall(C_Item.GetItemQualityByID, itemInfo.itemID)
                        if ok then
                            quality = result
                        end
                    end
                    if quality == nil then
                        _, _, quality = SafeGetItemInfo(itemLink or itemInfo.itemID)
                    end
                end

                if IsPoorItem(quality, itemLink) then
                    if itemPrice and itemPrice > 0 and not itemInfo.hasNoValue then
                        pendingValue = pendingValue + (itemPrice * (itemInfo.stackCount or 1))

                        pendingItems[#pendingItems + 1] = {
                            bag = bag,
                            slot = slot,
                        }
                    elseif itemPrice == nil then
                        needsRetry = true
                        RequestItemData(itemInfo.itemID)
                    end
                end
            end
        end
    end

    return needsRetry
end

local function SellNextBatch()
    if not isSelling then return end

    if (InCombatLockdown and InCombatLockdown())
    or not MerchantFrame
    or not MerchantFrame:IsShown() then
        StopSelling()
        return
    end

    for _ = 1, SELL_BATCH_SIZE do
        local item = tremove(pendingItems, 1)
        if not item then
            local totalValue = pendingValue
            isSelling = false
            pendingValue = 0
            PrintSoldValue(totalValue)
            return
        end

        local itemInfo = GetContainerItemInfoSafe(item.bag, item.slot)
        if itemInfo then
            UseContainerItemSafe(item.bag, item.slot)
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(SELL_BATCH_DELAY, SellNextBatch)
    else
        SellNextBatch()
    end
end

local function SellItems(scanAttempt, force)
    if (not force and not IsEnabled())
    or isSelling
    or (InCombatLockdown and InCombatLockdown()) then
        return
    end

    scanAttempt = scanAttempt or 1

    local needsRetry = ScanJunkItems()
    if #pendingItems == 0 then
        if needsRetry
        and scanAttempt < MAX_SCAN_ATTEMPTS
        and C_Timer
        and C_Timer.After then
            C_Timer.After(SCAN_RETRY_DELAY, function()
                SellItems(scanAttempt + 1, force)
            end)
        end

        return
    end

    isSelling = true
    SellNextBatch()
end

function SellJunk:SellNow()
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    SellItems(1, true)
end

-- ------------------------------------------------------------
-- EVENTS
-- ------------------------------------------------------------

SellJunk:RegisterEvent("MERCHANT_SHOW")
SellJunk:RegisterEvent("MERCHANT_UPDATE")
SellJunk:RegisterEvent("MERCHANT_CLOSED")

SellJunk:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_CLOSED" then
        StopSelling()
        return
    end

    if event == "MERCHANT_SHOW"
    and C_Timer
    and C_Timer.After then
        C_Timer.After(0.2, SellItems)
    end

    SellItems()
end)

-- ------------------------------------------------------------
-- REGISTRIERUNG
-- ------------------------------------------------------------

Comfort:RegisterModule("SellJunk", SellJunk)
