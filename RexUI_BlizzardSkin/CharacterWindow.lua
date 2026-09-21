-- RexUI standalone character window.
-- The Blizzard reputation and currency panes remain untouched and are opened
-- through the bottom navigation. Only the PaperDoll view is replaced.
local _, ns = ...
local RexUI = ns.RexUI
if not RexUI or not RexUI.BlizzardSkin then return end

local Skin = RexUI.BlizzardSkin
local Character = {}
Skin.CharacterWindow = Character

local FONT = "Interface\\AddOns\\RexUI\\media\\fonts\\Barlow Condensed.ttf"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local SLOT_SIZE = 40

local LEFT_SLOTS = {
    { INVSLOT_HEAD or 1, "Kopf" }, { INVSLOT_NECK or 2, "Hals" },
    { INVSLOT_SHOULDER or 3, "Schulter" }, { INVSLOT_BACK or 15, "Rücken" },
    { INVSLOT_CHEST or 5, "Brust" }, { INVSLOT_BODY or 4, "Hemd" },
    { INVSLOT_TABARD or 19, "Wappenrock" }, { INVSLOT_WRIST or 9, "Handgelenke" },
}
local RIGHT_SLOTS = {
    { INVSLOT_HAND or 10, "Hände" }, { INVSLOT_WAIST or 6, "Taille" },
    { INVSLOT_LEGS or 7, "Beine" }, { INVSLOT_FEET or 8, "Füße" },
    { INVSLOT_FINGER1 or 11, "Ring 1" }, { INVSLOT_FINGER2 or 12, "Ring 2" },
    { INVSLOT_TRINKET1 or 13, "Schmuck 1" }, { INVSLOT_TRINKET2 or 14, "Schmuck 2" },
}
local WEAPON_SLOTS = {
    { INVSLOT_MAINHAND or 16, "Waffenhand" },
    { INVSLOT_OFFHAND or INVSLOT_SECONDARYHAND or 17, "Schildhand" },
}

local NATIVE_SLOT_NAMES = {
    [INVSLOT_HEAD or 1] = "CharacterHeadSlot",
    [INVSLOT_NECK or 2] = "CharacterNeckSlot",
    [INVSLOT_SHOULDER or 3] = "CharacterShoulderSlot",
    [INVSLOT_BODY or 4] = "CharacterShirtSlot",
    [INVSLOT_CHEST or 5] = "CharacterChestSlot",
    [INVSLOT_WAIST or 6] = "CharacterWaistSlot",
    [INVSLOT_LEGS or 7] = "CharacterLegsSlot",
    [INVSLOT_FEET or 8] = "CharacterFeetSlot",
    [INVSLOT_WRIST or 9] = "CharacterWristSlot",
    [INVSLOT_HAND or 10] = "CharacterHandsSlot",
    [INVSLOT_FINGER1 or 11] = "CharacterFinger0Slot",
    [INVSLOT_FINGER2 or 12] = "CharacterFinger1Slot",
    [INVSLOT_TRINKET1 or 13] = "CharacterTrinket0Slot",
    [INVSLOT_TRINKET2 or 14] = "CharacterTrinket1Slot",
    [INVSLOT_BACK or 15] = "CharacterBackSlot",
    [INVSLOT_MAINHAND or 16] = "CharacterMainHandSlot",
    [INVSLOT_OFFHAND or INVSLOT_SECONDARYHAND or 17] = "CharacterSecondaryHandSlot",
    [INVSLOT_TABARD or 19] = "CharacterTabardSlot",
}

local ENCHANTABLE = {
    [INVSLOT_HEAD or 1] = true, [INVSLOT_SHOULDER or 3] = true,
    [INVSLOT_BACK or 15] = true, [INVSLOT_CHEST or 5] = true,
    [INVSLOT_WRIST or 9] = true, [INVSLOT_LEGS or 7] = true,
    [INVSLOT_FEET or 8] = true, [INVSLOT_FINGER1 or 11] = true,
    [INVSLOT_FINGER2 or 12] = true, [INVSLOT_MAINHAND or 16] = true,
    [INVSLOT_OFFHAND or INVSLOT_SECONDARYHAND or 17] = true,
}
local EMPTY_SOCKET_ATLAS = {
    EMPTY_SOCKET_META = "socket-meta", EMPTY_SOCKET_RED = "socket-red",
    EMPTY_SOCKET_YELLOW = "socket-yellow", EMPTY_SOCKET_BLUE = "socket-blue",
    EMPTY_SOCKET_PRISMATIC = "socket-prismatic", EMPTY_SOCKET_TINKER = "socket-tinker",
    EMPTY_SOCKET_COGWHEEL = "socket-cogwheel", EMPTY_SOCKET_PRIMORDIAL = "socket-primordial",
}

local SOCKET_SCAN_TOOLTIP_NAME = "RexUICharacterSocketScanTooltip"
local SocketScanTooltip
local function GetSocketScanTooltip()
    if SocketScanTooltip then return SocketScanTooltip end
    SocketScanTooltip = CreateFrame("GameTooltip", SOCKET_SCAN_TOOLTIP_NAME, UIParent, "GameTooltipTemplate")
    SocketScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    return SocketScanTooltip
end
local CREST_CURRENCIES = {
    { label = "Mythisch", oldID = 3347, id = 3446, icon = "Interface\\Icons\\inv_120_crest_myth" },
    { label = "Held", oldID = 3345, id = 3445, icon = "Interface\\Icons\\inv_120_crest_hero" },
    { label = "Champion", oldID = 3343, id = 3444, icon = "Interface\\Icons\\inv_120_crest_champion" },
    { label = "Veteran", oldID = 3341, id = 3443, icon = "Interface\\Icons\\inv_120_crest_veteran" },
    { label = "Abenteurer", oldID = 3383, id = 3442, icon = "Interface\\Icons\\inv_120_crest_adventurer" },
    { label = "Katalysator", oldID = 3378, id = 3465, icon = "Interface\\Icons\\inv_120_crest_adventurer", showMaximum = true },
}

local function Config()
    local profile = RexUI:GetProfile()
    profile.blizzardSkin = profile.blizzardSkin or {}
    return profile.blizzardSkin
end

local function Enabled()
    local config = Config()
    return config.enabled ~= false and config.characterSheet ~= false
end

local function GetColor(key, fallback)
    local r, g, b, a = RexUI:GetColor(key)
    if r == nil then return unpack(fallback or { 1, 1, 1, 1 }) end
    return r, g, b, a or 1
end

local function Text(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size, "OUTLINE")
    fs:SetTextColor(unpack(color or { 1, 1, 1, 1 }))
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

local function Border(frame, r, g, b, a)
    local border = Skin:CreateBorder(frame)
    border:SetAllPoints(frame)
    border:SetFrameLevel((frame:GetFrameLevel() or 1) + 8)
    Skin:SetBorderColor(border, r, g, b, a or 1)
    return border
end

local function CleanText(value)
    if not value or (issecretvalue and issecretvalue(value)) then return "" end
    value = tostring(value)
    value = value:gsub("|cn.-:(.-)|r", "%1")
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("|A.-|a", ""):gsub("|T.-|t", "")
    return value:match("^%s*(.-)%s*$") or ""
end

local function FormatNumber(value)
    if value == nil or (issecretvalue and issecretvalue(value)) then return "--" end
    value = tonumber(value)
    if not value then return "--" end
    if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
    if value >= 1000 then return string.format("%.1fK", value / 1000) end
    return tostring(math.floor(value + 0.5))
end

local function SafeNumber(fn, ...)
    if type(fn) ~= "function" then return 0 end
    local ok, value = pcall(fn, ...)
    if not ok or (issecretvalue and issecretvalue(value)) then return 0 end
    return tonumber(value) or 0
end

local function SetGradient(texture, side, r, g, b, equipped)
    local strongAlpha = equipped and 0.34 or 0.10
    if texture.SetGradient and CreateColor then
        local mode = Enum and Enum.GradientMode and Enum.GradientMode.Horizontal or "HORIZONTAL"
        local strong = CreateColor(r, g, b, strongAlpha)
        local clear = CreateColor(r, g, b, 0.04)
        local ok
        if side == "right" then
            ok = pcall(texture.SetGradient, texture, mode, clear, strong)
        else
            ok = pcall(texture.SetGradient, texture, mode, strong, clear)
        end
        if not ok then texture:SetColorTexture(r, g, b, strongAlpha * 0.55) end
    else
        texture:SetColorTexture(r, g, b, strongAlpha * 0.55)
    end
end

local function ItemData(slotID)
    local link = GetInventoryItemLink("player", slotID)
    local texture = GetInventoryItemTexture("player", slotID)
    local name, quality, level
    if link then
        if C_Item and C_Item.GetItemInfo then name, _, quality = C_Item.GetItemInfo(link)
        elseif GetItemInfo then name, _, quality = GetItemInfo(link) end
        if C_Item and C_Item.GetDetailedItemLevelInfo then
            local ok, value = pcall(C_Item.GetDetailedItemLevelInfo, link)
            if ok and not (issecretvalue and issecretvalue(value)) then level = value end
        elseif GetDetailedItemLevelInfo then
            local ok, value = pcall(GetDetailedItemLevelInfo, link)
            if ok and not (issecretvalue and issecretvalue(value)) then level = value end
        end
    end
    return link, texture, quality, level, name
end

local function ExtraItemData(slotID)
    local upgrade, enchant = "", ""
    if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then return upgrade, enchant end
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slotID)
    if not ok or not data or not data.lines then return upgrade, enchant end
    if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, data) end
    local enchantType = Enum and Enum.TooltipDataLineType and (Enum.TooltipDataLineType.ItemEnchantmentPermanent or Enum.TooltipDataLineType.ItemEnchant)
    local upgradeType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemUpgradeLevel
    for _, line in ipairs(data.lines) do
        local value = CleanText(line and line.leftText)
        if enchant == "" and ((enchantType and line.type == enchantType) or value:match("^[Vv]erzaubert:") or value:match("^[Ee]nchanted:")) then
            enchant = value:gsub("^[Vv]erzaubert:%s*", ""):gsub("^[Ee]nchanted:%s*", "")
        elseif upgrade == "" and ((upgradeType and line.type == upgradeType) or value:find("%d+/%d+")) then
            local found = value:match("[^:]+:%s*(.+%d+/%d+.*)") or value:match("(.+%d+/%d+.*)")
            if found and #found <= 48 then upgrade = found end
        end
    end
    return upgrade, enchant
end

local function ItemSockets(link, slotID)
    local sockets = {}
    if not link then return sockets end

    -- Build the equipped-item tooltip only for detecting empty sockets. Its
    -- Texture1..n regions also contain empty-socket glyphs and therefore cannot
    -- reliably distinguish an inserted gem from an empty socket.
    local scan = GetSocketScanTooltip()
    scan:ClearLines()
    pcall(scan.SetInventoryItem, scan, "player", slotID)

    -- Gem IDs are stored in fields 3..6 of every item string. Reading those
    -- fields gives us a reliable fallback when GetItemGem is unavailable or
    -- temporarily returns nil for an equipped item.
    local gemIDs = {}
    local itemString = link:match("|Hitem:([^|]+)|h") or link:match("item:([^|]+)")
    if itemString then
        local fields = {}
        for value in (itemString .. ":"):gmatch("(.-):") do
            fields[#fields + 1] = value
        end
        for index = 1, 4 do
            local gemID = tonumber(fields[index + 2])
            if gemID and gemID > 0 then gemIDs[index] = gemID end
        end
    end

    -- Prefer the regular API for the localized name and hyperlink, while the
    -- parsed gem ID guarantees that occupied sockets are not lost.
    local getItemGem = GetItemGem or (C_Item and C_Item.GetItemGem)
    for index = 1, 4 do
        local gemID = gemIDs[index]
        local gemName, gemLink
        if getItemGem then
            local ok, apiName, apiLink = pcall(getItemGem, link, index)
            if ok then
                gemName, gemLink = apiName, apiLink
            end
        end
        if gemLink or gemID then
            local texture
            local itemInfo = gemLink or gemID
            if gemID and C_Item and C_Item.GetItemIconByID then
                texture = C_Item.GetItemIconByID(gemID)
            elseif gemID and GetItemIcon then
                texture = GetItemIcon(gemID)
            end
            if C_Item and C_Item.GetItemInfo then
                local cachedName, _, _, _, _, _, _, _, _, cachedIcon = C_Item.GetItemInfo(itemInfo)
                gemName, texture = gemName or cachedName, texture or cachedIcon
            elseif GetItemInfo then
                local cachedName, _, _, _, _, _, _, _, _, cachedIcon = GetItemInfo(itemInfo)
                gemName, texture = gemName or cachedName, texture or cachedIcon
            end
            sockets[#sockets + 1] = {
                texture = texture or 134071,
                label = (gemName and gemName ~= "" and gemName) or "Sockelstein",
            }
        end
    end

    -- Empty sockets are exposed in the inventory tooltip. Count all localized
    -- EMPTY_SOCKET_* strings, not only prismatic sockets.
    local emptyCount, emptyAtlas = 0, "socket-prismatic"
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slotID)
        if ok and data and data.lines then
            if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, data) end
            for _, line in ipairs(data.lines) do
                local text = CleanText(line and line.leftText)
                for globalName, atlas in pairs(EMPTY_SOCKET_ATLAS) do
                    local socketText = _G[globalName]
                    if socketText and socketText ~= "" and text:find(CleanText(socketText), 1, true) then
                        emptyCount = emptyCount + 1
                        emptyAtlas = atlas
                        break
                    end
                end
            end
        end
    end

    -- GetItemStats reports the item's socket capacity on clients where the
    -- tooltip does not surface every empty socket as a separate text line.
    -- Subtract the occupied sockets so a filled socket is never duplicated as
    -- an empty square, while all remaining free sockets stay visible.
    local getItemStats = GetItemStats or (C_Item and C_Item.GetItemStats)
    if getItemStats then
        local stats = getItemStats(link)
        if stats then
            local socketCapacity = 0
            for key, count in pairs(stats) do
                if EMPTY_SOCKET_ATLAS[key] and tonumber(count) and count > 0 then
                    socketCapacity = socketCapacity + tonumber(count)
                    emptyAtlas = EMPTY_SOCKET_ATLAS[key]
                end
            end
            local remainingSockets = math.max(0, socketCapacity - #sockets)
            emptyCount = math.max(emptyCount, remainingSockets)
        end
    end
    for _ = 1, math.min(emptyCount, 4 - #sockets) do
        sockets[#sockets + 1] = { atlas = emptyAtlas, missing = true, label = "Sockelstein fehlt" }
    end
    scan:Hide()
    return sockets
end

local function PositionSocket(socket, row, side, index, count)
    socket:ClearAllPoints()
    if side == "left" then
        local y = (((count + 1) / 2) - index) * 13
        socket:SetPoint("CENTER", row, "LEFT", -9, y)
    elseif side == "right" then
        local y = (((count + 1) / 2) - index) * 13
        socket:SetPoint("CENTER", row, "RIGHT", 9, y)
    else
        local x = (index - ((count + 1) / 2)) * 16
        socket:SetPoint("BOTTOM", row, "TOP", x, 2)
    end
end

local function CreateSocket(row, side, index)
    local socket = CreateFrame("Frame", nil, row)
    socket:SetSize(14, 14)
    socket:SetFrameLevel(row:GetFrameLevel() + 4)
    -- Socket markers live OUTSIDE the equipment icon: left gear -> left side,
    -- right gear -> right side. Start centered; UpdateGearSlot distributes
    -- multiple markers symmetrically around the row centre.
    PositionSocket(socket, row, side, index, 1)
    local bg = socket:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.01, 0.01, 0.018, 0.98)
    socket.bg = bg
    socket.emptyBorder = Border(socket, 1, 1, 1, 1)
    local icon = socket:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    socket.icon = icon
    socket:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, side == "right" and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
        GameTooltip:SetText(self.label or "Sockel", self.missing and 1 or 0.4, self.missing and 0.2 or 0.9, self.missing and 0.15 or 1)
        GameTooltip:Show()
    end)
    socket:SetScript("OnLeave", function() GameTooltip:Hide() end)
    socket:Hide()
    return socket
end

local function CreateGearSlot(parent, slotID, label, side)
    -- ChonkyCharacterSheet approach: keep Blizzard's ORIGINAL PaperDoll slot button
    -- as the clickable object. RexUI only reparents/repositions/skins it. This is
    -- essential on Midnight because enchants, weapon oils and cursor items rely on
    -- Blizzard's secure PaperDoll click path and must not be forwarded by addon Lua.
    local nativeName = NATIVE_SLOT_NAMES[slotID]
    local button = nativeName and _G[nativeName]
    if not button then
        -- Visual fallback only. Normally all Retail PaperDoll slots exist here.
        button = CreateFrame("Button", nil, parent)
        button:EnableMouse(false)
    else
        if not button._rexuiOriginalParent then
            button._rexuiOriginalParent = button:GetParent()
        end
        button:SetParent(parent)
        button:Show()
    end
    button:ClearAllPoints()
    button:SetSize(SLOT_SIZE, SLOT_SIZE)
    button:SetFrameLevel((parent:GetFrameLevel() or 1) + 20)
    button.slotID, button.side, button.label = slotID, side, label

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(SLOT_SIZE)
    row:SetWidth(side == "bottom" and 180 or 195)
    row:SetFrameLevel((parent:GetFrameLevel() or 1) + 18)
    if side == "left" then row:SetPoint("TOPLEFT", button)
    elseif side == "right" then row:SetPoint("TOPRIGHT", button)
    else row:SetPoint("BOTTOM", button, "TOP", 0, 5) end

    local shade = row:CreateTexture(nil, "BACKGROUND", nil, -2)
    shade:SetAllPoints()
    shade:SetColorTexture(0.005, 0.005, 0.012, 0.54)
    local gradient = row:CreateTexture(nil, "BACKGROUND", nil, -1)
    gradient:SetAllPoints()
    gradient:SetTexture(WHITE)
    row.gradient = gradient

    local justify = side == "right" and "RIGHT" or (side == "bottom" and "CENTER" or "LEFT")
    row.name = Text(row, 12, { 0.98, 0.98, 1, 1 }, justify)
    row.meta = Text(row, 11, { 0.92, 0.92, 0.96, 1 }, justify)
    row.enchant = Text(row, 11, { 0.3, 1, 0.4, 1 }, justify)
    for _, fs in ipairs({ row.name, row.meta, row.enchant }) do
        if fs.SetWordWrap then fs:SetWordWrap(false) end
        if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
        if fs.SetMaxLines then fs:SetMaxLines(1) end
    end
    if side == "left" then
        row.name:SetPoint("TOPLEFT", 47, -1); row.name:SetPoint("RIGHT", -5, 0)
        row.meta:SetPoint("TOPLEFT", 47, -15); row.meta:SetPoint("RIGHT", -5, 0)
        row.enchant:SetPoint("TOPLEFT", 47, -29); row.enchant:SetPoint("RIGHT", -5, 0)
    elseif side == "right" then
        row.name:SetPoint("TOPLEFT", 5, -1); row.name:SetPoint("RIGHT", -47, 0)
        row.meta:SetPoint("TOPLEFT", 5, -15); row.meta:SetPoint("RIGHT", -47, 0)
        row.enchant:SetPoint("TOPLEFT", 5, -29); row.enchant:SetPoint("RIGHT", -47, 0)
    else
        row.name:SetPoint("TOPLEFT", 4, -1); row.name:SetPoint("RIGHT", -4, 0)
        row.meta:SetPoint("TOPLEFT", 4, -15); row.meta:SetPoint("RIGHT", -4, 0)
        row.enchant:SetPoint("TOPLEFT", 4, -29); row.enchant:SetPoint("RIGHT", -4, 0)
    end
    row.sockets = {}
    for index = 1, 4 do row.sockets[index] = CreateSocket(row, side, index) end
    button.row = row

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.018, 0.018, 0.028, 1)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon = icon
    button.border = Border(button, 0.24, 0.22, 0.3, 1)

    -- IMPORTANT: do not replace OnClick/OnMouseDown/OnReceiveDrag and do not call
    -- PaperDollItemSlotButton_OnClick/PickupInventoryItem from RexUI. The native
    -- Blizzard button keeps all of its original scripts and secure behavior.
    -- Its own tooltip scripts are retained for the same reason.
    return button
end

local function UpdateGearSlot(button)
    local link, texture, quality, level, name = ItemData(button.slotID)
    button.icon:SetTexture(texture or 134400)
    button.icon:SetDesaturated(not texture)
    button.icon:SetAlpha(texture and 1 or 0.22)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    local r, g, b = color and color.r or 0.28, color and color.g or 0.27, color and color.b or 0.32
    Skin:SetBorderColor(button.border, r, g, b, link and 1 or 0.45)
    SetGradient(button.row.gradient, button.side, r, g, b, link ~= nil)
    button.row.name:SetText(name or "")
    button.row.name:SetTextColor(r, g, b)

    local upgrade, enchant = ExtraItemData(button.slotID)
    local meta = level and ("Stufe " .. tostring(math.floor(level + 0.5))) or ""
    if upgrade ~= "" then meta = meta .. (meta ~= "" and "  •  " or "") .. upgrade end
    button.row.meta:SetText(meta)

    if link and ENCHANTABLE[button.slotID] then
        if enchant ~= "" then
            button.row.enchant:SetText(enchant)
            button.row.enchant:SetTextColor(0.28, 1, 0.42, 1)
        else
            button.row.enchant:SetText("<Verzauberung fehlt>")
            button.row.enchant:SetTextColor(1, 0.18, 0.12, 1)
        end
        button.row.enchant:Show()
    else
        button.row.enchant:Hide()
    end

    local sockets = ItemSockets(link, button.slotID)
    local visibleSocketCount = math.min(#sockets, #button.row.sockets)
    for index, socket in ipairs(button.row.sockets) do
        local data = sockets[index]
        if data then
            PositionSocket(socket, button.row, button.side, index, visibleSocketCount)
            socket.icon:SetVertexColor(1, 1, 1, 1)
            socket.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            if data.missing then
                -- Empty socket: deliberately no dark Blizzard socket glyph. A crisp
                -- white square is much easier to see against RexUI's dark gear rows.
                socket.icon:SetTexture(nil)
                if socket.icon.SetAtlas then socket.icon:SetAtlas(nil) end
                socket.bg:SetColorTexture(0.025, 0.025, 0.035, 1)
                Skin:SetBorderColor(socket.emptyBorder, 1, 1, 1, 1)
            else
                if data.atlas and socket.icon.SetAtlas then socket.icon:SetAtlas(data.atlas)
                else socket.icon:SetTexture(data.texture or 134071) end
                socket.bg:SetColorTexture(0.01, 0.01, 0.018, 0.98)
                -- Filled sockets use the gem itself as the visible socket colour.
                Skin:SetBorderColor(socket.emptyBorder, 0.72, 0.72, 0.78, 1)
            end
            socket.label, socket.missing = data.label, data.missing
            socket:Show()
        else socket:Hide() end
    end
end

local function CreateTab(parent, label, width)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 31)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.018, 0.018, 0.028, 0.98)
    button.bg = bg
    button.text = Text(button, 12, { 0.68, 0.67, 0.73, 1 }, "CENTER")
    button.text:SetPoint("CENTER")
    button.text:SetText(label)
    button.underline = button:CreateTexture(nil, "OVERLAY")
    button.underline:SetHeight(2)
    button.underline:SetPoint("BOTTOMLEFT")
    button.underline:SetPoint("BOTTOMRIGHT")
    button.underline:SetColorTexture(GetColor("highlight", { 0.75, 0.2, 1, 1 }))
    button.underline:Hide()
    button.topLine = button:CreateTexture(nil, "BORDER")
    button.topLine:SetHeight(1)
    button.topLine:SetPoint("TOPLEFT", 1, 0)
    button.topLine:SetPoint("TOPRIGHT", -1, 0)
    button.topLine:SetColorTexture(0.22, 0.22, 0.28, 0.8)
    button.rightLine = button:CreateTexture(nil, "BORDER")
    button.rightLine:SetWidth(1)
    button.rightLine:SetPoint("TOPRIGHT", 0, -4)
    button.rightLine:SetPoint("BOTTOMRIGHT", 0, 4)
    button.rightLine:SetColorTexture(0.22, 0.22, 0.28, 0.65)
    button.bottomLine = button:CreateTexture(nil, "BORDER")
    button.bottomLine:SetHeight(1)
    button.bottomLine:SetPoint("BOTTOMLEFT", 1, 0)
    button.bottomLine:SetPoint("BOTTOMRIGHT", -1, 0)
    button.bottomLine:SetColorTexture(0.22, 0.22, 0.28, 0.8)
    button:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
    button:SetScript("OnLeave", function(self)
        if not self.active then self.text:SetTextColor(0.68, 0.67, 0.73) end
    end)
    function button:SetActive(active)
        self.active = active
        self.underline:SetShown(active)
        if active then self.text:SetTextColor(GetColor("highlight", { 0.75, 0.2, 1, 1 }))
        else self.text:SetTextColor(0.68, 0.67, 0.73) end
    end
    return button
end

local function CreateStatRow(parent, y, label, iconTexture)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 8, y)
    row:SetPoint("TOPRIGHT", -8, y)
    row:SetHeight(21)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.025, 0.025, 0.038, 0.82)
    if iconTexture then
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(14, 14)
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetTexture(iconTexture)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
    row.label = Text(row, 12, { 0.88, 0.88, 0.92, 1 }, "LEFT")
    row.label:SetPoint("LEFT", iconTexture and 22 or 6, 0)
    row.label:SetText(label)
    row.value = Text(row, 12, { 1, 1, 1, 1 }, "RIGHT")
    row.value:SetPoint("RIGHT", -6, 0)
    row.label:SetPoint("RIGHT", row.value, "LEFT", -5, 0)
    local divider = row:CreateTexture(nil, "BORDER")
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", 4, 0)
    divider:SetPoint("BOTTOMRIGHT", -4, 0)
    divider:SetColorTexture(0.22, 0.22, 0.28, 0.65)
    row.divider = divider
    if row.label.SetWordWrap then row.label:SetWordWrap(false) end
    if row.label.SetMaxLines then row.label:SetMaxLines(1) end
    return row
end

local function CreateSection(parent, y, label)
    local fs = Text(parent, 12, { GetColor("highlight", { 0.75, 0.2, 1, 1 }) }, "LEFT")
    fs:SetPoint("TOPLEFT", 8, y)
    fs:SetText(string.upper(label))
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", -8, 0)
    line:SetColorTexture(GetColor("highlight", { 0.75, 0.2, 1, 0.8 }))
end

local function BuildWindow()
    if Character.Window then return Character.Window end
    local frame = CreateFrame("Frame", "RexUICharacterWindow", UIParent)
    frame:SetSize(940, 620)
    frame:SetPoint("CENTER", 0, 10)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()
    Character.Window = frame
    UISpecialFrames[#UISpecialFrames + 1] = "RexUICharacterWindow"

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(GetColor("panel", { 0.008, 0.008, 0.015, 0.98 }))
    Border(frame, GetColor("highlight", { 0.7, 0.16, 1, 1 }))
    local topLine = frame:CreateTexture(nil, "OVERLAY")
    topLine:SetHeight(2); topLine:SetPoint("TOPLEFT"); topLine:SetPoint("TOPRIGHT")
    topLine:SetColorTexture(GetColor("highlight", { 0.75, 0.2, 1, 1 }))

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(26, 26); close:SetPoint("TOPRIGHT", -5, -5)
    close.text = Text(close, 18, { 0.72, 0.71, 0.77, 1 }, "CENTER")
    close.text:SetPoint("CENTER", 0, 1); close.text:SetText("×")
    close:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
    close:SetScript("OnLeave", function(self) self.text:SetTextColor(0.72, 0.71, 0.77) end)
    close:SetScript("OnClick", function() frame:Hide() end)

    frame.nameText = Text(frame, 17, { 0.96, 0.96, 0.98, 1 }, "CENTER")
    frame.nameText:SetPoint("TOP", frame, "TOPLEFT", 348, -9)
    frame.specText = Text(frame, 12, { GetColor("highlight", { 0.75, 0.2, 1, 1 }) }, "CENTER")
    frame.specText:SetPoint("TOP", frame.nameText, "BOTTOM", 0, -1)
    frame.levelText = Text(frame, 10, { 0.72, 0.71, 0.78, 1 }, "CENTER")
    frame.levelText:SetPoint("TOP", frame.specText, "BOTTOM", 0, -1)

    frame.ratingLabel = Text(frame, 11, { 0.88, 0.87, 0.92, 1 }, "RIGHT")
    frame.ratingLabel:SetPoint("TOPRIGHT", -280, -12); frame.ratingLabel:Hide()
    frame.ratingValue = Text(frame, 18, { 1, 1, 1, 1 }, "RIGHT")
    frame.ratingValue:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    frame.ratingValue:SetPoint("TOPRIGHT", -280, -29)
    frame.ratingValue:Hide()

    local main = CreateFrame("Frame", nil, frame)
    main:SetPoint("TOPLEFT", 18, -67); main:SetPoint("BOTTOMLEFT", 18, 47); main:SetWidth(660)
    main:SetFrameLevel(frame:GetFrameLevel() + 2)
    frame.main = main
    local mainBg = main:CreateTexture(nil, "BACKGROUND")
    mainBg:SetAllPoints(); mainBg:SetColorTexture(0.004, 0.004, 0.01, 0.48)

    local model = CreateFrame("PlayerModel", nil, main)
    model:SetAllPoints(main)
    model:SetFrameLevel(main:GetFrameLevel() + 1)
    model:SetUnit("player"); model:SetPortraitZoom(0)
    if model.SetCamDistanceScale then model:SetCamDistanceScale(2.05) end
    model:EnableMouse(true); model:EnableMouseWheel(true)
    model:SetScript("OnMouseWheel", function(self, delta)
        self.RexZoom = math.max(0, math.min(1, (self.RexZoom or 0) + delta * 0.07))
        self:SetPortraitZoom(self.RexZoom)
    end)
    model:SetScript("OnMouseDown", function(self) self.dragging = true; self.cursorX = GetCursorPosition() end)
    model:SetScript("OnMouseUp", function(self) self.dragging = nil end)
    model:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local x = GetCursorPosition(); local dx = (x - (self.cursorX or x)) / self:GetEffectiveScale()
        self.cursorX = x; self:SetFacing((self:GetFacing() or 0) + dx * 0.012)
    end)
    frame.model = model

    frame.slots = {}
    for index, data in ipairs(LEFT_SLOTS) do
        local slot = CreateGearSlot(main, data[1], data[2], "left")
        slot:SetPoint("TOPLEFT", 18, -13 - ((index - 1) * 48))
        frame.slots[#frame.slots + 1] = slot
    end
    for index, data in ipairs(RIGHT_SLOTS) do
        local slot = CreateGearSlot(main, data[1], data[2], "right")
        slot:SetPoint("TOPRIGHT", -18, -13 - ((index - 1) * 48))
        frame.slots[#frame.slots + 1] = slot
    end
    for index, data in ipairs(WEAPON_SLOTS) do
        local weaponSide = index == 1 and "left" or "right"
        local slot = CreateGearSlot(main, data[1], data[2], weaponSide)
        if index == 1 then slot:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 18, 5)
        else slot:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -18, 5) end
        frame.slots[#frame.slots + 1] = slot
    end

    local side = CreateFrame("Frame", nil, frame)
    side:SetPoint("TOPLEFT", 692, -67); side:SetPoint("BOTTOMRIGHT", -18, 47)
    side:SetFrameLevel(frame:GetFrameLevel() + 4)
    local sideBg = side:CreateTexture(nil, "BACKGROUND")
    sideBg:SetAllPoints(); sideBg:SetColorTexture(0.006, 0.006, 0.012, 0.94)
    Border(side, 0.18, 0.16, 0.24, 1)
    frame.side = side

    frame.sideTabs = {}
    local tabInfo = { { "Charakter", "stats" }, { "Titel", "titles" } }
    for index, info in ipairs(tabInfo) do
        local tab = CreateTab(side, info[1], 76)
        tab:SetPoint("TOPLEFT", (index - 1) * 76, 0)
        tab.mode = info[2]
        tab:SetScript("OnClick", function() Character:SetSideMode(info[2]) end)
        frame.sideTabs[index] = tab
    end

    frame.itemLevelLabel = Text(side, 10, { 0.68, 0.67, 0.73, 1 }, "LEFT")
    frame.itemLevelLabel:SetPoint("TOPLEFT", 10, -40)
    frame.itemLevelLabel:SetText("GEGENSTANDSSTUFE")
    frame.itemLevelValue = Text(side, 18, { GetColor("highlight", { 0.75, 0.2, 1, 1 }) }, "LEFT")
    frame.itemLevelValue:SetPoint("TOPLEFT", 10, -53)
    frame.itemLevel = { value = frame.itemLevelValue }

    local stats = CreateFrame("ScrollFrame", nil, side)
    stats:SetPoint("TOPLEFT", 0, -78); stats:SetPoint("BOTTOMRIGHT")
    stats:EnableMouseWheel(true)
    stats:SetClipsChildren(true)
    frame.statsPanel = stats
    local statsContent = CreateFrame("Frame", nil, stats)
    statsContent:SetSize(228, 590)
    stats:SetScrollChild(statsContent)
    frame.statsContent = statsContent
    stats:SetScript("OnMouseWheel", function(self, delta)
        local maximum = math.max(0, statsContent:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(maximum, self:GetVerticalScroll() - delta * 42)))
    end)
    local scrollBar = CreateFrame("Slider", nil, side)
    scrollBar:SetPoint("TOPRIGHT", 1, -83)
    scrollBar:SetPoint("BOTTOMRIGHT", 1, 7)
    scrollBar:SetWidth(9)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, math.max(0, statsContent:GetHeight() - 400))
    scrollBar:SetValueStep(21)
    scrollBar:SetObeyStepOnDrag(false)
    local track = scrollBar:CreateTexture(nil, "BACKGROUND")
    track:SetWidth(2); track:SetPoint("TOP"); track:SetPoint("BOTTOM")
    track:SetColorTexture(0.18, 0.18, 0.23, 0.8)
    local thumb = scrollBar:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(7, 42); thumb:SetColorTexture(0.62, 0.62, 0.68, 0.95)
    scrollBar:SetThumbTexture(thumb)
    scrollBar:SetScript("OnValueChanged", function(_, value) stats:SetVerticalScroll(value) end)
    stats:HookScript("OnMouseWheel", function(self) scrollBar:SetValue(self:GetVerticalScroll()) end)
    stats:HookScript("OnSizeChanged", function(self)
        local maximum = math.max(0, statsContent:GetHeight() - self:GetHeight())
        scrollBar:SetMinMaxValues(0, maximum)
        scrollBar:SetShown(maximum > 0)
    end)
    frame.statsScrollBar = scrollBar
    CreateSection(statsContent, -2, "Attribute")
    frame.primary = CreateStatRow(statsContent, -24, "Primärwert")
    frame.stamina = CreateStatRow(statsContent, -47, "Ausdauer")
    frame.health = CreateStatRow(statsContent, -70, "Gesundheit")
    frame.armor = CreateStatRow(statsContent, -93, "Rüstung")
    CreateSection(statsContent, -124, "Sekundär")
    frame.crit = CreateStatRow(statsContent, -146, "Kritischer Treffer")
    frame.haste = CreateStatRow(statsContent, -169, "Tempo")
    frame.mastery = CreateStatRow(statsContent, -192, "Meisterschaft")
    frame.vers = CreateStatRow(statsContent, -215, "Vielseitigkeit")
    CreateSection(statsContent, -246, "Allgemein")
    frame.durability = CreateStatRow(statsContent, -268, "Haltbarkeit", "Interface\\Cursor\\repairnpc")
    frame.leech = CreateStatRow(statsContent, -291, "Lebensraub", "Interface\\Icons\\spell_shadow_lifedrain02")
    frame.avoidance = CreateStatRow(statsContent, -314, "Vermeidung", "Interface\\Icons\\ability_rogue_quickrecovery")
    frame.speedRating = CreateStatRow(statsContent, -337, "Geschwindigkeit", "Interface\\Icons\\ability_rogue_sprint")
    frame.movement = CreateStatRow(statsContent, -360, "Bewegung", "Interface\\Icons\\ability_mount_nightmarehorse")
    CreateSection(statsContent, -391, "Abzeichen")
    frame.crestRows = {}
    for index, data in ipairs(CREST_CURRENCIES) do
        local row = CreateStatRow(statsContent, -413 - ((index - 1) * 23), data.label, data.icon)
        row.currency = data
        frame.crestRows[index] = row
    end

    local titles = CreateFrame("Frame", nil, side)
    titles:SetPoint("TOPLEFT", 0, -78); titles:SetPoint("BOTTOMRIGHT")
    titles:SetClipsChildren(true)
    titles:Hide(); frame.titlesPanel = titles
    titles.heading = Text(titles, 12, { GetColor("highlight", { 0.75, 0.2, 1, 1 }) }, "LEFT")
    titles.heading:SetPoint("TOPLEFT", 10, -8); titles.heading:SetText("BEKANNTE TITEL")
    titles.rows = {}
    for index = 1, 15 do
        local row = CreateFrame("Button", nil, titles)
        row:SetPoint("TOPLEFT", 8, -31 - ((index - 1) * 25)); row:SetPoint("TOPRIGHT", -8, -31 - ((index - 1) * 25)); row:SetHeight(22)
        local rowBg = row:CreateTexture(nil, "BACKGROUND"); rowBg:SetAllPoints(); rowBg:SetColorTexture(0.025, 0.025, 0.038, 0.82)
        local separator = row:CreateTexture(nil, "BORDER")
        separator:SetHeight(1); separator:SetPoint("BOTTOMLEFT", 3, 0); separator:SetPoint("BOTTOMRIGHT", -3, 0)
        separator:SetColorTexture(0.58, 0.58, 0.64, 0.42)
        row.separator = separator
        row.text = Text(row, 11, { 0.82, 0.82, 0.87, 1 }, "LEFT"); row.text:SetPoint("LEFT", 7, 0); row.text:SetPoint("RIGHT", -7, 0)
        row:SetScript("OnClick", function(self)
            if self.titleID and SetCurrentTitle then
                -- Mark the clicked title immediately. GetCurrentTitle() is updated by
                -- the client asynchronously, so waiting for it caused the highlight
                -- to appear only after changing tabs.
                Character.PendingTitleID = self.titleID
                SetCurrentTitle(self.titleID)
                Character:RefreshTitles()

                -- Re-read the authoritative title for a short period and drop the
                -- optimistic selection as soon as the client confirms the change.
                if C_Timer and C_Timer.After then
                    local attempts = 0
                    local function ConfirmTitleChange()
                        attempts = attempts + 1
                        local current = GetCurrentTitle and GetCurrentTitle() or 0
                        if current == Character.PendingTitleID or attempts >= 10 then
                            Character.PendingTitleID = nil
                        end
                        if Character.Window and Character.Window:IsShown() and Character.Window.sideMode == "titles" then
                            Character:RefreshTitles()
                        end
                        if Character.PendingTitleID and attempts < 10 then
                            C_Timer.After(0.05, ConfirmTitleChange)
                        end
                    end
                    C_Timer.After(0.05, ConfirmTitleChange)
                end
            end
        end)
        row:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
        row:SetScript("OnLeave", function(self) if not self.current then self.text:SetTextColor(0.82, 0.82, 0.87) end end)
        titles.rows[index] = row
    end
    titles.offset = 0
    titles:EnableMouseWheel(true)
    titles:SetScript("OnMouseWheel", function(_, delta)
        local maximum = math.max(0, #(frame.knownTitles or {}) - #titles.rows)
        titles.offset = math.max(0, math.min(maximum, (titles.offset or 0) - delta * 3))
        Character:RefreshTitles()
    end)
    local titleScrollBar = CreateFrame("Slider", nil, side)
    titleScrollBar:SetPoint("TOPRIGHT", 1, -99)
    titleScrollBar:SetPoint("BOTTOMRIGHT", 1, 10)
    titleScrollBar:SetWidth(9)
    titleScrollBar:SetOrientation("VERTICAL")
    titleScrollBar:SetValueStep(1)
    titleScrollBar:SetObeyStepOnDrag(true)
    local titleTrack = titleScrollBar:CreateTexture(nil, "BACKGROUND")
    titleTrack:SetWidth(2); titleTrack:SetPoint("TOP"); titleTrack:SetPoint("BOTTOM")
    titleTrack:SetColorTexture(0.18, 0.18, 0.23, 0.8)
    local titleThumb = titleScrollBar:CreateTexture(nil, "ARTWORK")
    titleThumb:SetSize(7, 42); titleThumb:SetColorTexture(0.62, 0.62, 0.68, 0.95)
    titleScrollBar:SetThumbTexture(titleThumb)
    titleScrollBar:SetScript("OnValueChanged", function(_, value)
        titles.offset = math.floor(value + 0.5)
        Character:RefreshTitles()
    end)
    frame.titleScrollBar = titleScrollBar
    titleScrollBar:Hide()


    local specLabel = Text(frame, 11, { 0.9, 0.89, 0.94, 1 }, "LEFT")
    specLabel:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 4, -31)
    specLabel:SetText("Spezialisierung:")
    local specButton = CreateFrame("Button", nil, frame)
    specButton:SetSize(132, 25)
    specButton:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", -4, -38)
    local specBg = specButton:CreateTexture(nil, "BACKGROUND"); specBg:SetAllPoints(); specBg:SetColorTexture(0.025, 0.025, 0.038, 0.98)
    Border(specButton, 0.42, 0.40, 0.48, 1)
    specButton.text = Text(specButton, 12, { 1, 1, 1, 1 }, "LEFT")
    specButton.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    specButton.text:SetPoint("LEFT", 9, 0); specButton.text:SetPoint("RIGHT", -27, 0)
    specButton.arrow = Text(specButton, 14, { 0.92, 0.92, 0.96, 1 }, "CENTER")
    specButton.arrow:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    specButton.arrow:SetPoint("RIGHT", -8, 0); specButton.arrow:SetText("v")
    specButton:SetScript("OnEnter", function(self) Border(self, GetColor("highlight", { 0.75, 0.2, 1, 1 })) end)
    specButton:SetScript("OnLeave", function(self) Border(self, 0.42, 0.40, 0.48, 1) end)
    specButton:SetScript("OnClick", function(self)
        if InCombatLockdown and InCombatLockdown() then
            if UIErrorsFrame then UIErrorsFrame:AddMessage("Spezialisierung kann im Kampf nicht gewechselt werden.", 1, 0.25, 0.2) end
            return
        end
        local current = GetSpecialization and GetSpecialization() or 0
        local count = GetNumSpecializations and GetNumSpecializations() or 0
        local function SelectSpec(index)
            if index == current then return end
            if SetSpecialization then
                SetSpecialization(index)
            elseif C_SpecializationInfo and C_SpecializationInfo.SetSpecialization then
                C_SpecializationInfo.SetSpecialization(index)
            end
        end
        -- Retail's current menu system first; EasyMenu remains a compatibility fallback.
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, function(_, rootDescription)
                for index = 1, count do
                    local _, name = GetSpecializationInfo(index)
                    if name then
                        local specIndex = index
                        local radio = rootDescription:CreateRadio(name, function() return specIndex == (GetSpecialization and GetSpecialization() or 0) end, function() SelectSpec(specIndex) end)
                        if radio and radio.SetTooltip then radio:SetTooltip(function(tooltip) tooltip:SetText("Spezialisierung wechseln") end) end
                    end
                end
            end)
        elseif EasyMenu then
            frame.specMenu = frame.specMenu or CreateFrame("Frame", "RexUICharacterSpecMenu", frame, "UIDropDownMenuTemplate")
            local menu = {}
            for index = 1, count do
                local _, name = GetSpecializationInfo(index)
                if name then
                    local specIndex = index
                    menu[#menu + 1] = { text = name, checked = specIndex == current, func = function() SelectSpec(specIndex) end }
                end
            end
            EasyMenu(menu, frame.specMenu, self, 0, 0, "MENU")
        end
    end)
    frame.specButton = specButton

    frame.bottomTabs = {}
    local bottomInfo = { { "Charakter", "character" }, { "Ruf", "reputation" }, { "Abzeichen", "currency" } }
    for index, info in ipairs(bottomInfo) do
        local tab = CreateTab(frame, info[1], 105)
        tab:SetPoint("BOTTOMLEFT", 18 + ((index - 1) * 108), 8)
        tab.mode = info[2]
        tab:SetScript("OnClick", function() Character:OpenBottomMode(info[2]) end)
        tab:SetActive(info[2] == "character")
        frame.bottomTabs[index] = tab
    end

    frame:SetScript("OnShow", function()
        Character:RefreshModel()
        Character:Refresh()
    end)
    return frame
end

function Character:SetSideMode(mode)
    local frame = BuildWindow()
    frame.sideMode = mode
    frame.statsPanel:SetShown(mode == "stats")
    frame.titlesPanel:SetShown(mode == "titles")
    if frame.statsScrollBar then frame.statsScrollBar:SetShown(mode == "stats") end
    if frame.titleScrollBar then frame.titleScrollBar:SetShown(mode == "titles") end
    for _, tab in ipairs(frame.sideTabs) do tab:SetActive(tab.mode == mode) end
    if mode == "titles" then self:RefreshTitles() end
end

function Character:RefreshTitles()
    local frame = BuildWindow()
    local known = {}
    local count = GetNumTitles and GetNumTitles() or 0
    for id = 1, count do
        if IsTitleKnown and IsTitleKnown(id) then
            local name = GetTitleName and GetTitleName(id)
            if name and name ~= "" then known[#known + 1] = { id = id, name = name:gsub("%%s", UnitName("player") or "") } end
        end
    end
    table.sort(known, function(a, b) return a.name < b.name end)
    frame.knownTitles = known
    if frame.titleScrollBar then
        local maximum = math.max(0, #known - #frame.titlesPanel.rows)
        frame.titleScrollBar:SetMinMaxValues(0, maximum)
        frame.titleScrollBar:SetShown(frame.sideMode == "titles" and maximum > 0)
        if (frame.titlesPanel.offset or 0) > maximum then frame.titlesPanel.offset = maximum end
        frame.titleScrollBar:SetValue(frame.titlesPanel.offset or 0)
    end
    local current = GetCurrentTitle and GetCurrentTitle() or 0
    -- Use the clicked title immediately while the game client is still updating
    -- GetCurrentTitle(). This makes the selection highlight truly live.
    local highlightedTitle = Character.PendingTitleID or current
    for index, row in ipairs(frame.titlesPanel.rows) do
        local data = known[(frame.titlesPanel.offset or 0) + index]
        if data then
            row.titleID = data.id; row.current = data.id == highlightedTitle
            row.text:SetText(data.name)
            if row.current then row.text:SetTextColor(GetColor("highlight", { 0.75, 0.2, 1, 1 }))
            else row.text:SetTextColor(0.82, 0.82, 0.87) end
            row:Show()
        else row:Hide() end
    end
end

local function RatingPercent(index)
    if not GetCombatRatingBonus then return "--" end
    local value = SafeNumber(GetCombatRatingBonus, index)
    return string.format("%.1f%%", value)
end

local function DurabilityValue()
    local currentTotal, maximumTotal, repairTotal = 0, 0, 0
    local scanner = _G.RexUIDurabilityScanner
    if not scanner then
        scanner = CreateFrame("GameTooltip", "RexUIDurabilityScanner", UIParent, "GameTooltipTemplate")
        scanner:SetOwner(UIParent, "ANCHOR_NONE")
        _G.RexUIDurabilityScanner = scanner
    end
    for slotID = 1, 19 do
        local current, maximum = GetInventoryItemDurability(slotID)
        if current and maximum and maximum > 0 then
            currentTotal = currentTotal + current
            maximumTotal = maximumTotal + maximum
            scanner:ClearLines()
            local _, _, repairCost = scanner:SetInventoryItem("player", slotID)
            if not (issecretvalue and issecretvalue(repairCost)) and type(repairCost) == "number" then
                repairTotal = repairTotal + repairCost
            end
        end
    end
    local percent = maximumTotal > 0 and (currentTotal / maximumTotal) * 100 or 100
    local result = string.format("%.0f%%", percent)
    if repairTotal > 0 and GetMoneyString then result = result .. " · " .. GetMoneyString(repairTotal, true) end
    return result
end

local function RefreshCrests(frame)
    if not frame.crestRows then return end
    local toc = select(4, GetBuildInfo()) or 0
    for _, row in ipairs(frame.crestRows) do
        local data = row.currency
        local id = toc >= 120100 and data.id or data.oldID
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id)
        local quantity, maximum = 0, 0
        if info then
            if not (issecretvalue and issecretvalue(info.quantity)) then quantity = tonumber(info.quantity) or 0 end
            if not (issecretvalue and issecretvalue(info.maxQuantity)) then maximum = tonumber(info.maxQuantity) or 0 end
            if data.showMaximum and info.name and info.name ~= "" then row.label:SetText(info.name) end
            if row.icon and info.iconFileID then row.icon:SetTexture(info.iconFileID) end
        end
        if data.showMaximum and maximum > 0 then row.value:SetText(FormatNumber(quantity) .. "/" .. FormatNumber(maximum))
        else row.value:SetText(FormatNumber(quantity)) end
    end
end

function Character:RefreshStats()
    local frame = BuildWindow()

    -- Midnight can return secret values while the character frame is opened from
    -- protected item/enchant interactions. Never compare, format or do arithmetic
    -- with such values; show a placeholder until normal readable values return.
    local function ReadNumber(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, value = pcall(fn, ...)
        if not ok or value == nil or (issecretvalue and issecretvalue(value)) then return nil end
        return tonumber(value)
    end
    local function ReadSecond(fn, ...)
        if type(fn) ~= "function" then return nil end
        local results = { pcall(fn, ...) }
        if not results[1] then return nil end
        local value = results[3]
        if value == nil or (issecretvalue and issecretvalue(value)) then return nil end
        return tonumber(value)
    end

    local avg = ReadSecond(GetAverageItemLevel)
    frame.itemLevel.value:SetText(avg and avg > 0 and string.format("%.2f", avg) or "--")

    local strength = ReadSecond(UnitStat, "player", 1)
    local agility = ReadSecond(UnitStat, "player", 2)
    local intellect = ReadSecond(UnitStat, "player", 4)
    local primary
    for _, value in ipairs({ strength, agility, intellect }) do
        if value ~= nil and (primary == nil or value > primary) then primary = value end
    end
    frame.primary.value:SetText(FormatNumber(primary))
    frame.stamina.value:SetText(FormatNumber(ReadSecond(UnitStat, "player", 3)))
    frame.health.value:SetText(FormatNumber(ReadNumber(UnitHealthMax, "player")))
    frame.armor.value:SetText(FormatNumber(ReadSecond(UnitArmor, "player")))
    frame.crit.value:SetText(RatingPercent(CR_CRIT_MELEE or 9))

    local haste = ReadNumber(GetHaste)
    frame.haste.value:SetText(haste and string.format("%.1f%%", haste) or "--")
    local mastery = ReadNumber(GetMasteryEffect)
    frame.mastery.value:SetText(mastery and string.format("%.1f%%", mastery) or "--")
    local vers = ReadNumber(GetCombatRatingBonus, CR_VERSATILITY_DAMAGE_DONE or 29)
    frame.vers.value:SetText(vers and string.format("%.1f%%", vers) or "--")
    frame.durability.value:SetText(DurabilityValue())

    local function SetRating(row, index)
        local bonus = ReadNumber(GetCombatRatingBonus, index)
        local rating = ReadNumber(GetCombatRating, index)
        if bonus and rating then row.value:SetText(string.format("(%.1f%%) %s", bonus, FormatNumber(rating)))
        else row.value:SetText("--") end
    end
    SetRating(frame.leech, CR_LIFESTEAL or 17)
    SetRating(frame.avoidance, CR_AVOIDANCE or 21)
    SetRating(frame.speedRating, CR_SPEED or 14)

    local currentSpeed, runSpeed
    if GetUnitSpeed then
        local ok, a, b = pcall(GetUnitSpeed, "player")
        if ok then currentSpeed, runSpeed = a, b end
    end
    if (currentSpeed ~= nil and issecretvalue and issecretvalue(currentSpeed)) or
       (runSpeed ~= nil and issecretvalue and issecretvalue(runSpeed)) then
        frame.movement.value:SetText("--")
    else
        local movementSpeed = tonumber(runSpeed) or tonumber(currentSpeed)
        frame.movement.value:SetText(movementSpeed and string.format("%.0f%%", (movementSpeed / 7) * 100) or "--")
    end
    RefreshCrests(frame)
end

function Character:RefreshModel()
    local frame = Character.Window
    if not frame or not frame:IsShown() or not frame.model then return end
    local function Apply()
        if not frame:IsShown() then return end
        frame.model:SetUnit("player")
        frame.model:SetPortraitZoom(0)
        if frame.model.SetCamDistanceScale then frame.model:SetCamDistanceScale(2.05) end
    end
    Apply()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, Apply)
        C_Timer.After(0.08, Apply)
    end
end

function Character:RefreshHeader()
    local frame = BuildWindow()
    local name = UnitName("player") or "Charakter"
    local specIndex = GetSpecialization and GetSpecialization()
    local specName = specIndex and select(2, GetSpecializationInfo(specIndex)) or ""
    local className, classFile = UnitClass("player")
    frame.nameText:SetText(name)
    local classColor = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS) and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[classFile]
    if classColor then frame.nameText:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
    else frame.nameText:SetTextColor(0.96, 0.96, 0.98, 1) end
    frame.specText:SetText(specName ~= "" and (specName .. (className and (" · " .. className) or "")) or (className or ""))
    if frame.specButton and frame.specButton.text then frame.specButton.text:SetText(specName ~= "" and specName or "Auswählen") end
    frame.levelText:SetText("Stufe " .. tostring(UnitLevel("player") or "--"))
end

function Character:Refresh()
    local frame = BuildWindow()
    self:RefreshHeader()
    self:RefreshStats()
    for _, slot in ipairs(frame.slots) do UpdateGearSlot(slot) end
    if frame.sideMode == "titles" then self:RefreshTitles() end
end

function Character:OpenBottomMode(mode)
    local frame = BuildWindow()
    if mode == "character" then
        if _G.CharacterFrame and _G.CharacterFrame:IsShown() then HideUIPanel(_G.CharacterFrame) end
        frame:Show(); return
    end
    frame:Hide()
    if Character.OriginalToggleCharacter then
        Character.OriginalToggleCharacter(mode == "reputation" and "ReputationFrame" or "TokenFrame")
    elseif ToggleCharacter then
        ToggleCharacter(mode == "reputation" and "ReputationFrame" or "TokenFrame")
    end
end

function Character:Toggle()
    local frame = BuildWindow()
    if frame:IsShown() then frame:Hide()
    else
        if _G.CharacterFrame and _G.CharacterFrame:IsShown() then HideUIPanel(_G.CharacterFrame) end
        frame:Show()
    end
end

function Character:InstallHooks()
    if self.HooksInstalled then return end
    self.HooksInstalled = true
    BuildWindow()
    self:SetSideMode("stats")

    local function HookToggleCharacter()
        if _G.ToggleCharacter and not Character.OriginalToggleCharacter then
            Character.OriginalToggleCharacter = _G.ToggleCharacter
            _G.ToggleCharacter = function(frameName, ...)
                if frameName == "PaperDollFrame" and Enabled() then
                    -- Enchant / weapon-oil targeting can ask Blizzard to open the
                    -- PaperDollFrame. Do not open RexUI automatically in that path;
                    -- the player can open the character window manually when they
                    -- actually want to apply the item to an equipment slot.
                    local targeting = (SpellIsTargeting and SpellIsTargeting()) or false
                    if targeting then return end
                    Character:Toggle()
                    return
                end
                return Character.OriginalToggleCharacter(frameName, ...)
            end
        end
    end
    HookToggleCharacter()

    local function HookNativeCharacterTab()
        local tab = _G.CharacterFrameTab1
        if tab and not tab.RexUIStandaloneHooked then
            tab.RexUIStandaloneHooked = true
            tab:HookScript("OnClick", function()
                if not Enabled() then return end
                C_Timer.After(0, function()
                    if _G.CharacterFrame and _G.CharacterFrame:IsShown() then HideUIPanel(_G.CharacterFrame) end
                    BuildWindow():Show()
                end)
            end)
        end
    end
    HookNativeCharacterTab()

    local events = CreateFrame("Frame")
    Skin:RegisterEvents(events, {
        "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "GET_ITEM_INFO_RECEIVED",
        "PLAYER_LEVEL_UP", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "UPDATE_SHAPESHIFT_FORM",
        "UPDATE_SHAPESHIFT_FORMS", "UNIT_MODEL_CHANGED", "CHALLENGE_MODE_COMPLETED",
        "UPDATE_INVENTORY_DURABILITY", "CURRENCY_DISPLAY_UPDATE", "ADDON_LOADED",
    })
    events:SetScript("OnEvent", function(_, event, arg1)
        if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
        if event == "UNIT_MODEL_CHANGED" and arg1 and arg1 ~= "player" then return end
        if event == "ADDON_LOADED" then HookToggleCharacter(); HookNativeCharacterTab() end
        if Character.Window and Character.Window:IsShown() then
            if event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" or event == "UNIT_MODEL_CHANGED" then
                Character:RefreshModel()
            end
            Character:Refresh()
            if C_Timer and C_Timer.After then C_Timer.After(0.2, function() if Character.Window:IsShown() then Character:Refresh() end end) end
        end
    end)
    self.EventFrame = events
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function() Character:InstallHooks() end)
