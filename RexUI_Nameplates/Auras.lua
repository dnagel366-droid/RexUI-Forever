-- ============================================================
-- RexUI - Nameplates / Auras
-- Ausgelagert aus Core.lua; gemeinsamer Zustand liegt in Nameplates.Internal (NP).
-- ============================================================

local ADDON_NAME, ns = ...
local RexUI = ns.RexUI
if not RexUI or not RexUI.Nameplates then return end

local Nameplates = RexUI.Nameplates
local NP = Nameplates.Internal
local Perf = RexUI.Perf

local AURA_ICON_SIZE = NP.AURA_ICON_SIZE
local AURA_ICON_SPACING = NP.AURA_ICON_SPACING
local MAX_BUFFS = NP.MAX_BUFFS
local MAX_CC = NP.MAX_CC
local MAX_DEBUFFS = NP.MAX_DEBUFFS

local CreateFrame = CreateFrame

local function CreateAuraSlot(parent)
    local slot = CreateFrame("Frame", nil, parent)
    slot:SetSize(AURA_ICON_SIZE, AURA_ICON_SIZE)
    slot:EnableMouse(false)
    if slot.SetMouseMotionEnabled then
        slot:SetMouseMotionEnabled(false)
    end

    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetAllPoints()
    slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    slot.cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
    slot.cooldown:SetAllPoints()
    if slot.cooldown.SetDrawEdge then
        slot.cooldown:SetDrawEdge(false)
    end
    if slot.cooldown.SetDrawBling then
        slot.cooldown:SetDrawBling(false)
    end
    if slot.cooldown.SetHideCountdownNumbers then
        slot.cooldown:SetHideCountdownNumbers(false)
    end

    slot.count = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slot.count:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 1, -1)
    slot.count:SetTextColor(1, 1, 1, 1)

    slot.border = {
        NP.CreateEdge(slot), NP.CreateEdge(slot), NP.CreateEdge(slot), NP.CreateEdge(slot),
    }
    local top, bottom, left, right = unpack(slot.border)
    top:SetPoint("BOTTOMLEFT", slot, "TOPLEFT", -1, 0)
    top:SetPoint("BOTTOMRIGHT", slot, "TOPRIGHT", 1, 0)
    top:SetHeight(1)
    bottom:SetPoint("TOPLEFT", slot, "BOTTOMLEFT", -1, 0)
    bottom:SetPoint("TOPRIGHT", slot, "BOTTOMRIGHT", 1, 0)
    bottom:SetHeight(1)
    left:SetPoint("TOPRIGHT", slot, "TOPLEFT", 0, 1)
    left:SetPoint("BOTTOMRIGHT", slot, "BOTTOMLEFT", 0, -1)
    left:SetWidth(1)
    right:SetPoint("TOPLEFT", slot, "TOPRIGHT", 0, 1)
    right:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 0, -1)
    right:SetWidth(1)
    for index = 1, #slot.border do
        slot.border[index]:SetColorTexture(0.08, 0.08, 0.10, 1)
    end
    slot:Hide()
    return slot
end

local function CreateAuraRow(plate, count)
    local row = CreateFrame("Frame", nil, plate)
    row:SetSize(count * AURA_ICON_SIZE + (count - 1) * AURA_ICON_SPACING, AURA_ICON_SIZE)
    row:EnableMouse(false)
    row.slots = {}
    for index = 1, count do
        local slot = CreateAuraSlot(row)
        slot:SetPoint("LEFT", row, "LEFT", (index - 1) * (AURA_ICON_SIZE + AURA_ICON_SPACING), 0)
        row.slots[index] = slot
    end
    row:Hide()
    return row
end

local function InitializeEngineAuraButton(button)
    local size = tonumber(Nameplates.settings.auras.size) or AURA_ICON_SIZE
    button:SetSize(size, size)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(false)
    local count = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    pcall(button.SetMouseClickEnabled, button, false)
    button:SetIcon(icon)
    button:SetDurationCooldown(cooldown)
    button:SetApplicationCount(count, {})
end

local function TryCreateEngineAuraContainer(parent, groups)
    if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.LoadAddOn) then return nil end
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    if not ok or not container or not container.AddAuraGroup then return nil end
    container:SetSize(1, 1)
    container._rexButtons = {}
    for _, group in ipairs(groups) do
        local added = pcall(container.AddAuraGroup, container, group.key, group.filter, {
            maxFrameCount = group.count,
            sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.ImportantOnly,
            sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal,
            candidateFilters = group.candidateFilters,
            initializeFrame = function(button)
                InitializeEngineAuraButton(button)
                container._rexButtons[button] = true
            end,
            layout = {
                elementWidth = AURA_ICON_SIZE,
                elementHeight = AURA_ICON_SIZE,
                elementSpacing = AURA_ICON_SPACING,
                lineSpacing = AURA_ICON_SPACING,
            },
        })
        if not added then
            container:Hide()
            return nil
        end
    end
    pcall(container.SetUnit, container, "none")
    return container
end

local function TryCreateEngineAuraElements(plate)
    local debuffs = TryCreateEngineAuraContainer(plate, {
        { key = "include", filter = "HARMFUL", count = MAX_DEBUFFS,
            candidateFilters = { includeSpellIDs = {} } },
        { key = "debuffs", filter = "HARMFUL|INCLUDE_NAME_PLATE_ONLY", count = MAX_DEBUFFS },
        { key = "own", filter = "HARMFUL|INCLUDE_NAME_PLATE_ONLY|PLAYER", count = MAX_DEBUFFS },
        { key = "important", filter = "HARMFUL|INCLUDE_NAME_PLATE_ONLY", count = MAX_DEBUFFS,
            candidateFilters = { isBossAura = true } },
    })
    if not debuffs then return end
    local buffs = TryCreateEngineAuraContainer(plate, {
        { key = "include", filter = "HELPFUL", count = MAX_BUFFS,
            candidateFilters = { includeSpellIDs = {} } },
        { key = "buffs", filter = "HELPFUL|INCLUDE_NAME_PLATE_ONLY", count = MAX_BUFFS },
    })
    local cc = TryCreateEngineAuraContainer(plate, {
        { key = "cc", filter = "HARMFUL|CROWD_CONTROL", count = MAX_CC },
    })
    if not buffs or not cc then
        debuffs:Hide()
        if buffs then buffs:Hide() end
        if cc then cc:Hide() end
        return
    end
    plate.auraContainers = { debuffs = debuffs, buffs = buffs, cc = cc }
    plate.usesAuraContainers = true
end

local function CreateAuraElements(plate)
    TryCreateEngineAuraElements(plate)
    if not plate.usesAuraContainers then
        plate.debuffRow = CreateAuraRow(plate, MAX_DEBUFFS)
        plate.buffRow = CreateAuraRow(plate, MAX_BUFFS)
        plate.ccRow = CreateAuraRow(plate, MAX_CC)
    end

    local indicatorParent = plate.arrowHost or plate
    plate.indicatorLayer = CreateFrame("Frame", nil, indicatorParent)
    plate.indicatorLayer:SetAllPoints(indicatorParent)
    plate.indicatorLayer:SetFrameLevel(plate:GetFrameLevel() + 20)
    plate.indicatorLayer:EnableMouse(false)

    plate.raidMarker = plate.indicatorLayer:CreateTexture(nil, "OVERLAY", nil, 7)
    plate.raidMarker:SetSize(22, 22)
    -- Keep the icon inside RexUI's 44px plate frame so Blizzard/native
    -- nameplate clipping cannot cut it away.
    plate.raidMarker:SetPoint("TOP", plate, "TOP", 0, -1)
    plate.raidMarker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    plate.raidMarker:Hide()

    plate.questIndicator = plate.indicatorLayer:CreateTexture(nil, "OVERLAY")
    plate.questIndicator:SetSize(10, 10)
    -- Quest and classification indicators share one stable row to the right
    -- of the target arrow. This prevents the quest badge from covering the
    -- left arrow and keeps all unit-type information in the same place.
    plate.questIndicator:SetPoint("LEFT", plate.targetRight, "RIGHT", 3, 0)
    plate.questIndicator:SetTexture("Interface\\TARGETINGFRAME\\PortraitQuestBadge")
    plate.questIndicator:SetTexCoord(2/32, 26/32, 1/32, 31/32)
    plate.questIndicator:Hide()

    plate.classIndicator = plate.indicatorLayer:CreateTexture(nil, "OVERLAY")
    plate.classIndicator:SetSize(12, 12)
    plate.classIndicator:SetPoint("LEFT", plate.targetRight, "RIGHT", 3, 0)
    plate.classIndicator:Hide()

    plate.classIndicator2 = plate.indicatorLayer:CreateTexture(nil, "OVERLAY")
    plate.classIndicator2:SetSize(12, 12)
    plate.classIndicator2:SetPoint("LEFT", plate.classIndicator, "RIGHT", 1, 0)
    plate.classIndicator2:Hide()

    plate.aggroIndicator = plate.indicatorLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    plate.aggroIndicator:SetPoint("LEFT", plate.health, "LEFT", 3, 0)
    plate.aggroIndicator:SetText("!")
    plate.aggroIndicator:SetTextColor(1.00, 0.18, 0.12, 1)
    plate.aggroIndicator:Hide()

    plate.aggroBlinkAnimation = plate.aggroIndicator:CreateAnimationGroup()
    plate.aggroBlinkAnimation:SetLooping("REPEAT")
    local fadeOut = plate.aggroBlinkAnimation:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0.15)
    fadeOut:SetDuration(0.45)
    fadeOut:SetOrder(1)
    local fadeIn = plate.aggroBlinkAnimation:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0.15)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.45)
    fadeIn:SetOrder(2)
end


local function ClearAuraSlot(slot)
    slot.auraInstanceID = nil
    slot.spellID = nil
    slot.icon:SetTexture(nil)
    slot.count:SetText("")
    if slot.cooldown.Clear then
        slot.cooldown:Clear()
    elseif slot.cooldown.SetCooldown then
        slot.cooldown:SetCooldown(0, 0)
    end
    slot:Hide()
end

local function ClearAuraRow(row)
    if not row then return end
    for index = 1, #row.slots do
        ClearAuraSlot(row.slots[index])
    end
    row.visibleCount = 0
    row:Hide()
end

local function ActiveSpellMap(source)
    local result
    for spellID, enabled in pairs(source or {}) do
        if enabled then
            result = result or {}
            result[spellID] = true
        end
    end
    return result
end

local AURA_POSITION_VALID = {
    TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
    TOPLEFT = true, TOPRIGHT = true, CENTER = true,
}

local AURA_LAYOUT_DEFAULTS = {
    debuff = { position = "TOP", x = 0, y = 20 },
    buff = { position = "LEFT", x = -7, y = 0 },
    cc = { position = "RIGHT", x = 34, y = 0 },
}

local function GetAuraLayout(settings, key)
    local defaults = AURA_LAYOUT_DEFAULTS[key]
    local position = settings[key .. "Position"]
    local legacy = not AURA_POSITION_VALID[position]
    if legacy then
        if settings.position == "BOTTOM" then
            position = "BOTTOM"
        else
            position = defaults.position
        end
    end

    local size = tonumber(settings[key .. "Size"] or settings.size) or AURA_ICON_SIZE
    local spacing = tonumber(settings[key .. "Spacing"])
    size = math.max(12, math.min(40, size))
    spacing = math.max(0, math.min(12, spacing or AURA_ICON_SPACING))

    local x = tonumber(settings[key .. "X"])
    local y = tonumber(settings[key .. "Y"])
    if legacy and settings.position == "BOTTOM" then
        x = x or 0
        local order = key == "debuff" and 0 or key == "buff" and 1 or 2
        y = y or (-5 - order * (size + 3))
    else
        x = x or defaults.x
        y = y or defaults.y
    end
    return { position = position, x = x, y = y, size = size, spacing = spacing }
end

local function AnchorAuraFrame(frame, plate, layout)
    frame:ClearAllPoints()
    if layout.position == "BOTTOM" then
        frame:SetPoint("TOP", plate.cast, "BOTTOM", layout.x, layout.y)
    elseif layout.position == "LEFT" then
        frame:SetPoint("BOTTOMRIGHT", plate.health, "BOTTOMLEFT", layout.x, layout.y)
    elseif layout.position == "RIGHT" then
        frame:SetPoint("BOTTOMLEFT", plate.health, "BOTTOMRIGHT", layout.x, layout.y)
    elseif layout.position == "TOPLEFT" then
        frame:SetPoint("BOTTOMLEFT", plate.health, "TOPLEFT", layout.x, layout.y)
    elseif layout.position == "TOPRIGHT" then
        frame:SetPoint("BOTTOMRIGHT", plate.health, "TOPRIGHT", layout.x, layout.y)
    elseif layout.position == "CENTER" then
        frame:SetPoint("CENTER", plate.health, "CENTER", layout.x, layout.y)
    else
        frame:SetPoint("BOTTOM", plate.health, "TOP", layout.x, layout.y)
    end

    if frame.SetFlowLayoutAnchorPoint then
        local anchorPoint = layout.position == "LEFT" and "BOTTOMRIGHT"
            or layout.position == "RIGHT" and "BOTTOMLEFT"
            or layout.position == "BOTTOM" and "TOPLEFT"
            or layout.position == "TOPRIGHT" and "BOTTOMRIGHT"
            or "BOTTOMLEFT"
        pcall(frame.SetFlowLayoutAnchorPoint, frame, anchorPoint)
    end
    if frame.SetFlowLayoutGrowthDirection and AnchorUtil and AnchorUtil.FlowDirection then
        local horizontal = layout.position == "LEFT"
            and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right
        local vertical = layout.position == "BOTTOM"
            and AnchorUtil.FlowDirection.Down or AnchorUtil.FlowDirection.Up
        pcall(frame.SetFlowLayoutGrowthDirection, frame, horizontal, vertical)
    end
end

-- Konfigurierte Maximalzahlen, begrenzt durch die Kapazität der Reihen.
local function AuraLimit(settings, key, cap)
    local value = tonumber(settings and settings[key])
    if not value then return math.min(cap, key == "maxDebuffs" and 5 or key == "maxBuffs" and 4 or 2) end
    return math.max(0, math.min(cap, math.floor(value)))
end
NP.AuraLimit = AuraLimit

local function ConfigureEngineAuraContainer(container, counts, includeMap, excludeMap, size, spacing)
    local layout = {
        elementWidth = size, elementHeight = size,
        elementSpacing = spacing, lineSpacing = spacing,
    }
    for key, count in pairs(counts) do
        pcall(container.SetAuraGroupMaxFrameCount, container, key, count)
        if container.SetAuraGroupLayout then
            pcall(container.SetAuraGroupLayout, container, key, layout)
        end
    end
    for button in pairs(container._rexButtons or {}) do
        pcall(button.SetSize, button, size, size)
    end
    if counts.include ~= nil and container.SetAuraGroupCandidateFilters then
        pcall(container.SetAuraGroupCandidateFilters, container, "include", {
            includeSpellIDs = includeMap or {},
        })
    end
    if excludeMap and container.SetAuraGroupCandidateFilters then
        for key in pairs(counts) do
            if key ~= "include" then
                local candidate = { excludeSpellIDs = excludeMap }
                if key == "important" then candidate.isBossAura = true end
                pcall(container.SetAuraGroupCandidateFilters, container, key, candidate)
            end
        end
    end
end

local function RefreshEngineAuras(plate)
    local containers = plate.auraContainers
    if not containers then return false end
    local auraSettings = Nameplates.settings.auras
    local includeMap = ActiveSpellMap(Nameplates.settings.filters.include)
    local excludeMap = ActiveSpellMap(Nameplates.settings.filters.exclude)
    local hasIncludes = includeMap and true or false
    local debuffLayout = GetAuraLayout(auraSettings, "debuff")
    local buffLayout = GetAuraLayout(auraSettings, "buff")
    local ccLayout = GetAuraLayout(auraSettings, "cc")

    local maxDebuffs = AuraLimit(auraSettings, "maxDebuffs", MAX_DEBUFFS)
    local maxBuffs = AuraLimit(auraSettings, "maxBuffs", MAX_BUFFS)
    local maxCC = AuraLimit(auraSettings, "maxCC", MAX_CC)

    ConfigureEngineAuraContainer(containers.debuffs, {
        include = hasIncludes and maxDebuffs or 0,
        debuffs = auraSettings.debuffs and maxDebuffs or 0,
        own = (not auraSettings.debuffs and auraSettings.ownDebuffs) and maxDebuffs or 0,
        important = (not auraSettings.debuffs and auraSettings.important) and maxDebuffs or 0,
    }, includeMap, excludeMap, debuffLayout.size, debuffLayout.spacing)
    ConfigureEngineAuraContainer(containers.buffs, {
        include = hasIncludes and maxBuffs or 0,
        buffs = auraSettings.buffs and maxBuffs or 0,
    }, includeMap, excludeMap, buffLayout.size, buffLayout.spacing)
    ConfigureEngineAuraContainer(containers.cc, {
        cc = auraSettings.crowdControl and maxCC or 0,
    }, nil, excludeMap, ccLayout.size, ccLayout.spacing)

    AnchorAuraFrame(containers.debuffs, plate, debuffLayout)
    AnchorAuraFrame(containers.buffs, plate, buffLayout)
    AnchorAuraFrame(containers.cc, plate, ccLayout)

    for _, container in pairs(containers) do
        container:Show()
        if container._rexUnit ~= plate.unit then
            container._rexUnit = plate.unit
            pcall(container.SetUnit, container, plate.unit)
        end
        pcall(container.UpdateAllAuras, container)
    end
    ClearAuraRow(plate.debuffRow)
    ClearAuraRow(plate.buffRow)
    ClearAuraRow(plate.ccRow)
    return true
end

NP.ClearPlateAuras = function(plate)
    if plate.auraContainers then
        for _, container in pairs(plate.auraContainers) do
            container._rexUnit = nil
            pcall(container.SetUnit, container, "none")
            container:Hide()
        end
    end
    ClearAuraRow(plate.debuffRow)
    ClearAuraRow(plate.buffRow)
    ClearAuraRow(plate.ccRow)
end

local function LayoutAuraRows(plate)
    local settings = Nameplates.settings.auras
    local rows = {
        { plate.debuffRow, AuraLimit(settings, "maxDebuffs", MAX_DEBUFFS), GetAuraLayout(settings, "debuff") },
        { plate.buffRow, AuraLimit(settings, "maxBuffs", MAX_BUFFS), GetAuraLayout(settings, "buff") },
        { plate.ccRow, AuraLimit(settings, "maxCC", MAX_CC), GetAuraLayout(settings, "cc") },
    }
    for _, data in ipairs(rows) do
        local row, count, layout = data[1], data[2], data[3]
        local size, spacing = layout.size, layout.spacing
        row.maxVisible = count
        row:SetSize(math.max(1, count) * size + (math.max(1, count) - 1) * spacing, size)
        for index = 1, #row.slots do
            local slot = row.slots[index]
            slot:SetSize(size, size)
            slot:ClearAllPoints()
            if layout.position == "LEFT" or layout.position == "TOPRIGHT" then
                slot:SetPoint("RIGHT", row, "RIGHT", -(index - 1) * (size + spacing), 0)
            else
                slot:SetPoint("LEFT", row, "LEFT", (index - 1) * (size + spacing), 0)
            end
        end
        AnchorAuraFrame(row, plate, layout)
    end
end

local function IsAccessibleNumber(value)
    return type(value) == "number" and NP.CanAccess(value)
end

local function AuraSpellID(data)
    local spellID = data and data.spellId
    if not IsAccessibleNumber(spellID) then
        spellID = data and data.spellID
    end
    return IsAccessibleNumber(spellID) and spellID or nil
end

local function AuraAllowed(data, mode)
    if not data then return false end
    local spellID = AuraSpellID(data)
    local filters = Nameplates.settings.filters
    if spellID and filters.exclude[spellID] then
        return false
    end
    if spellID and filters.include[spellID] then
        return true
    end
    if mode == "include" then
        return false
    end
    if mode ~= "important" then
        return true
    end
    for _, key in ipairs({ "isBossAura", "isPriorityAura", "nameplateShowAll", "nameplateShowPersonal" }) do
        local value = NP.AccessibleBoolean(data[key])
        if value == true then
            return true
        end
    end
    return false
end

local function ForEachAura(unit, filter, callback)
    if AuraUtil and AuraUtil.ForEachAura then
        local ok = pcall(AuraUtil.ForEachAura, unit, filter, nil, callback, true)
        if ok then return end
    end
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
    for index = 1, 40 do
        local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
        if not ok or not data then break end
        if callback(data) then break end
    end
end

local function ApplyDispelBorder(slot, data)
    local color
    if Nameplates.settings.auras.dispelBorders ~= false then
        local dispelName = data and data.dispelName
        if type(dispelName) == "string" and NP.CanAccess(dispelName) then
            color = NP.DISPEL_COLORS and NP.DISPEL_COLORS[dispelName]
        end
    end
    color = color or { 0.08, 0.08, 0.10 }
    for index = 1, #slot.border do
        slot.border[index]:SetColorTexture(color[1], color[2], color[3], 1)
    end
end

local function SetAuraSlot(slot, unit, data)
    slot.auraInstanceID = nil
    slot.spellID = AuraSpellID(data)
    slot.icon:SetTexture(data.icon)
    slot.count:SetText("")
    ApplyDispelBorder(slot, data)

    local applications = data.applications
    if IsAccessibleNumber(applications) and applications > 1 then
        slot.count:SetText(applications)
    end

    local instanceID = data.auraInstanceID
    if NP.CanAccess(instanceID) and type(instanceID) ~= "nil" then
        slot.auraInstanceID = instanceID
        if C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount then
            local ok, display = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, instanceID)
            if ok and type(display) ~= "nil" then
                slot.count:SetText(display)
            end
        end
        if C_UnitAuras and C_UnitAuras.GetAuraDuration
            and slot.cooldown.SetCooldownFromDurationObject then
            local ok, duration = pcall(C_UnitAuras.GetAuraDuration, unit, instanceID)
            if ok and duration then
                slot.cooldown:SetCooldownFromDurationObject(duration)
            end
        end
    end
    slot:Show()
end

local function FillAuraRow(row, unit, requests)
    ClearAuraRow(row)
    local limit = math.min(#row.slots, row.maxVisible or #row.slots)
    local nextSlot = 1
    local seen = {}
    for _, request in ipairs(requests) do
        if request.enabled and nextSlot <= limit then
            ForEachAura(unit, request.filter, function(data)
                local spellID = AuraSpellID(data)
                local duplicate = spellID and seen[spellID]
                if not duplicate and AuraAllowed(data, request.mode) then
                    if spellID then seen[spellID] = true end
                    SetAuraSlot(row.slots[nextSlot], unit, data)
                    nextSlot = nextSlot + 1
                    if nextSlot > limit then return true end
                end
                return false
            end)
        end
    end
    row.visibleCount = nextSlot - 1
    row:SetShown(nextSlot > 1)
end

-- Delta-Verarbeitung für UNIT_AURA: Nur neu zeichnen, wenn die Änderung die
-- Plakette betreffen kann. Geheime oder fehlende Payloads erzwingen den
-- vollständigen Refresh (Midnight liefert im Kampf geheime Payloads).
local function PlateShowsAuraInstance(plate, instanceID)
    for _, row in ipairs({ plate.debuffRow, plate.buffRow, plate.ccRow }) do
        if row and row.slots then
            for _, slot in ipairs(row.slots) do
                if slot.auraInstanceID == instanceID then return true end
            end
        end
    end
    return false
end

NP.PlateNeedsAuraRefresh = function(plate, updateInfo)
    if type(updateInfo) ~= "table" or not NP.CanAccess(updateInfo) then
        return true
    end
    local isFull = updateInfo.isFullUpdate
    if not NP.CanAccess(isFull) or isFull == true then
        return true
    end

    local added = updateInfo.addedAuras
    if added ~= nil then
        if not NP.CanAccess(added) or (type(added) == "table" and #added > 0) then
            return true
        end
    end

    -- Entfernte oder geänderte Auren sind nur relevant, wenn sie gerade gezeigt werden.
    for _, key in ipairs({ "removedAuraInstanceIDs", "updatedAuraInstanceIDs" }) do
        local list = updateInfo[key]
        if list ~= nil then
            if not NP.CanAccess(list) or type(list) ~= "table" then
                return true
            end
            for _, instanceID in ipairs(list) do
                if not NP.CanAccess(instanceID) or PlateShowsAuraInstance(plate, instanceID) then
                    return true
                end
            end
        end
    end

    if Perf then Perf:Count("Nameplates", "partialUpdates") end
    return false
end

NP.RefreshPlateAuras = function(plate)
    if not plate or not plate.unit then return end
    if plate.usesAuraContainers and RefreshEngineAuras(plate) then
        if NP.RefreshSideLayout then NP.RefreshSideLayout(plate) end
        return
    end
    if not plate.debuffRow then return end
    local perfStart = Perf and Perf:Start()
    LayoutAuraRows(plate)
    local settings = Nameplates.settings.auras
    local hasIncludes = next(Nameplates.settings.filters.include) ~= nil
    FillAuraRow(plate.debuffRow, plate.unit, {
        { enabled = hasIncludes, filter = "HARMFUL", mode = "include" },
        { enabled = settings.important, filter = "HARMFUL|INCLUDE_NAME_PLATE_ONLY", mode = "important" },
        { enabled = settings.ownDebuffs, filter = "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY", mode = "own" },
        { enabled = settings.debuffs, filter = "HARMFUL|INCLUDE_NAME_PLATE_ONLY", mode = "debuff" },
    })
    FillAuraRow(plate.buffRow, plate.unit, {
        { enabled = hasIncludes, filter = "HELPFUL", mode = "include" },
        { enabled = settings.buffs, filter = "HELPFUL|INCLUDE_NAME_PLATE_ONLY", mode = "buff" },
    })
    FillAuraRow(plate.ccRow, plate.unit, {
        { enabled = settings.crowdControl, filter = "HARMFUL|CROWD_CONTROL", mode = "cc" },
    })
    if NP.RefreshSideLayout then NP.RefreshSideLayout(plate) end
    if Perf then Perf:Stop("Nameplates", perfStart, "auraScans") end
end


-- Für andere Nameplate-Dateien sichtbar machen
NP.CreateAuraElements = CreateAuraElements
NP.IsAccessibleNumber = IsAccessibleNumber
