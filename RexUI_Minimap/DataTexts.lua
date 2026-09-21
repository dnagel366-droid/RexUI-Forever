local _, ns = ...
local RexUI = _G.RexUI or ns.RexUI
if not RexUI then return end

-- DataTexts wird bewusst vor dem Minimap-Core geladen. Dadurch existiert die
-- Datentext-Engine bereits, wenn der Core die Minimap zum ersten Mal anwendet,
-- und der alte Fallback kann beim Login nicht mehr versehentlich übernehmen.
RexUI.Minimap = RexUI.Minimap or {}
local M = RexUI.Minimap
local DT = M.DataTexts or {}
M.DataTexts = DT

DT.RegisteredDataTexts = DT.RegisteredDataTexts or {}
DT.DataTextList = DT.DataTextList or {}
DT.AssignedDataTexts = DT.AssignedDataTexts or {}

local SLOT_KEYS = { "dataTextLeft", "dataTextCenter", "dataTextRight" }
local SLOT_DEFAULTS = { "GUILD", "SYSTEM", "BNET" }

local function T(text)
    return RexUI:LocalizeText(text)
end

local function SafeNumber(value)
    if value == nil then return 0 end
    if canaccessvalue and not canaccessvalue(value) then return 0 end
    return tonumber(value) or 0
end

local function FriendClassColor(className, classID)
    local classFile
    if classID and classID > 0 and GetClassInfo then
        local _, resolvedClassFile = GetClassInfo(classID)
        classFile = resolvedClassFile
    end
    if not classFile and className then
        if LOCALIZED_CLASS_NAMES_MALE then
            for token, localizedName in pairs(LOCALIZED_CLASS_NAMES_MALE) do
                if localizedName == className then classFile = token break end
            end
        end
        if not classFile and LOCALIZED_CLASS_NAMES_FEMALE then
            for token, localizedName in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
                if localizedName == className then classFile = token break end
            end
        end
    end
    return classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
end

local function AddOnlineWoWFriends(tooltip)
    tooltip:AddLine(" ")
    tooltip:AddLine(T("WoW-Freunde"), 0.40, 0.78, 1)

    local shown = 0
    local total = C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends() or 0
    for index = 1, SafeNumber(total) do
        local info = C_FriendList.GetFriendInfoByIndex and C_FriendList.GetFriendInfoByIndex(index)
        if info and info.connected and info.name then
            shown = shown + 1
            local color = FriendClassColor(info.className)
            local name = Ambiguate and Ambiguate(info.name, "none") or info.name
            tooltip:AddDoubleLine(name, info.area or "", color and color.r or 1, color and color.g or 1, color and color.b or 1, 0.70, 0.70, 0.70)
        end
    end
    if shown == 0 then tooltip:AddLine(T("Niemand online"), 0.60, 0.60, 0.60) end
end

local function IsRetailWoWFriendGame(game)
    local wowClient = BNET_CLIENT_WOW or "WoW"
    return game and game.isOnline and game.clientProgram == wowClient
end

local function CountOnlineBattleNetWoWFriends()
    local online = 0
    local total = BNGetNumFriends and BNGetNumFriends() or 0
    for index = 1, SafeNumber(total) do
        local info = C_BattleNet and C_BattleNet.GetFriendAccountInfo and C_BattleNet.GetFriendAccountInfo(index)
        if info and IsRetailWoWFriendGame(info.gameAccountInfo) then
            online = online + 1
        end
    end
    return online
end

local function AddOnlineBattleNetFriends(tooltip)
    tooltip:AddLine(" ")
    tooltip:AddLine(T("Battle.net-Freunde"), 0.40, 0.78, 1)

    local shown = 0
    local total = BNGetNumFriends and BNGetNumFriends() or 0
    for index = 1, SafeNumber(total) do
        local info = C_BattleNet and C_BattleNet.GetFriendAccountInfo and C_BattleNet.GetFriendAccountInfo(index)
        local game = info and info.gameAccountInfo
        if IsRetailWoWFriendGame(game) then
            shown = shown + 1
            local accountName = info.accountName or info.battleTag or game.characterName or UNKNOWN
            local displayName = accountName
            if game.clientProgram == BNET_CLIENT_WOW and game.characterName and game.characterName ~= accountName then
                displayName = format("%s (%s)", accountName, game.characterName)
            end
            local location = game.areaName or game.clientProgram or ""
            local color = FriendClassColor(game.className, game.classID)
            tooltip:AddDoubleLine(displayName, location, color and color.r or 0.51, color and color.g or 0.77, color and color.b or 1, 0.70, 0.70, 0.70)
        end
    end
    if shown == 0 then tooltip:AddLine(T("Niemand online"), 0.60, 0.60, 0.60) end
end

local function ShortMoney(copper)
    copper = SafeNumber(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    if gold > 0 then return format("%dg %ds", gold, silver) end
    return format("%ds", silver)
end

local function ClampAlpha(value, fallback)
    value = tonumber(value)
    if value == nil then value = fallback or 1 end
    return math.max(0, math.min(1, value))
end

function DT:ApplySlotStyle(slot, cfg)
    if not slot or not slot.text then return end

    if not cfg then
        local profile = RexUI.GetProfile and RexUI:GetProfile()
        cfg = profile and profile.minimap or {}
    end

    local color = cfg.dataBarTextColor or { r = 0.92, g = 0.92, b = 0.92 }
    local r, g, b = color.r or 0.92, color.g or 0.92, color.b or 0.92
    local alpha = ClampAlpha(cfg.dataBarTextAlpha, 1)

    if slot._rexHovered then
        -- Der Hoverzustand bleibt auch bei laufenden Wertaktualisierungen stabil.
        r, g, b = r + ((1 - r) * 0.35), g + ((1 - g) * 0.35), b + ((1 - b) * 0.35)
        alpha = math.max(alpha, 0.90)
    end

    slot.text:SetTextColor(r, g, b, 1)
    slot.text:SetAlpha(alpha)
    if slot.hoverTexture then
        local accent = cfg.dataBarBorderColor or color
        slot.hoverTexture:SetColorTexture(accent.r or r, accent.g or g, accent.b or b, 0.14)
        slot.hoverTexture:SetShown(slot._rexHovered == true)
    end
end

function DT:RegisterDatatext(name, data)
    if type(name) ~= "string" or type(data) ~= "table" then return end
    data.name = name
    self.RegisteredDataTexts[name] = data
    for _, registeredName in ipairs(self.DataTextList) do
        if registeredName == name then return data end
    end
    table.insert(self.DataTextList, name)
    return data
end

function DT:UpdateSlot(slot, event, ...)
    local provider = self.AssignedDataTexts[slot]
    if not provider then
        slot.text:SetText("")
        return
    end

    if provider.onEvent then
        pcall(provider.onEvent, provider, slot, event, ...)
    end

    local ok, text = pcall(provider.getText, provider, slot)
    slot.text:SetText(ok and text or "--")
    self:ApplySlotStyle(slot)
    slot.text:Show()
end

function DT:ShowTooltip(slot)
    local provider = self.AssignedDataTexts[slot]
    if not provider then return end

    GameTooltip:SetOwner(slot, "ANCHOR_BOTTOM")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(T(provider.label or provider.name), 1, 1, 1)
    if provider.onTooltipShow then
        pcall(provider.onTooltipShow, provider, slot, GameTooltip)
    end
    GameTooltip:AddLine(" ")
    if provider.clickText then
        GameTooltip:AddLine(T(provider.clickText), 0.70, 0.70, 0.70)
    end
    GameTooltip:AddLine(T("Alt + Rechtsklick: Datentext auswählen"), 0.70, 0.70, 0.70)
    GameTooltip:Show()
end

function DT:GetNextDatatext(current)
    local currentIndex = 0
    for index, name in ipairs(self.DataTextList) do
        if name == current then currentIndex = index break end
    end
    return self.DataTextList[(currentIndex % #self.DataTextList) + 1]
end

function DT:SetSlotDatatext(slot, name)
    if not slot or not self.RegisteredDataTexts[name] then return end
    local panel = slot.panel or slot:GetParent()
    if panel and panel.saveSlot then
        -- Freie Datenpanels speichern in ihrer eigenen Konfiguration.
        panel.saveSlot(slot, name)
    else
        M:Save(slot.settingKey, name)
    end
    self:AssignPanelToDataText(slot, name)
end

function DT:OpenSelectionMenu(slot)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(slot, function(_, rootDescription)
            rootDescription:CreateTitle(T("Datentext auswählen"))
            for _, name in ipairs(self.DataTextList) do
                local selectedName = name
                local provider = self.RegisteredDataTexts[selectedName]
                rootDescription:CreateRadio(
                    T(provider.label or selectedName),
                    function() return slot.dataTextName == selectedName end,
                    function() self:SetSlotDatatext(slot, selectedName) end
                )
            end
        end)
    else
        self:SetSlotDatatext(slot, self:GetNextDatatext(slot.dataTextName))
    end
end

function DT:AssignPanelToDataText(slot, name)
    slot:UnregisterAllEvents()
    slot:SetScript("OnUpdate", nil)
    slot.elapsed = 0

    local provider = self.RegisteredDataTexts[name] or self.RegisteredDataTexts.NONE
    self.AssignedDataTexts[slot] = provider
    slot.dataTextName = provider.name
    slot._rexDataTextActive = true

    if provider.events then
        for _, event in ipairs(provider.events) do
            pcall(slot.RegisterEvent, slot, event)
        end
    end

    slot:SetScript("OnEvent", function(frame, event, ...)
        self:UpdateSlot(frame, event, ...)
    end)
    if provider.interval then
        slot:SetScript("OnUpdate", function(frame, elapsed)
            frame.elapsed = frame.elapsed + elapsed
            if frame.elapsed >= provider.interval then
                frame.elapsed = 0
                local Perf = RexUI.Perf
                local perfStart = Perf and Perf:Start()
                self:UpdateSlot(frame, "ON_UPDATE")
                if Perf then Perf:Stop("Minimap", perfStart, "onUpdates") end
            end
        end)
    end
    self:UpdateSlot(slot, "FORCE_UPDATE")
end

function DT:RegisterPanel(panel, numberOfSlots)
    panel.dataPanels = panel.dataPanels or {}
    self.Panels = self.Panels or {}
    self.Panels[panel] = true
    local slotKeys = panel.slotKeys or SLOT_KEYS
    for index = 1, numberOfSlots do
        local slot = panel.dataPanels[index]
        if not slot then
            slot = CreateFrame("Button", nil, panel)
            slot:RegisterForClicks("AnyUp")
            slot.settingKey = slotKeys[index] or ("slot" .. index)
            slot.pointIndex = index
            slot.panel = panel
            slot.text = slot:CreateFontString(nil, "OVERLAY")
            slot.text:SetFont("Interface\\AddOns\\RexUI\\media\\fonts\\Barlow Condensed.ttf", 12, "OUTLINE")
            slot.text:SetAllPoints()
            slot.text:SetJustifyH("CENTER")
            slot.text:SetJustifyV("MIDDLE")
            slot.hoverTexture = slot:CreateTexture(nil, "BACKGROUND")
            slot.hoverTexture:SetAllPoints()
            slot.hoverTexture:Hide()
            slot:SetScript("OnEnter", function(frame)
                frame._rexHovered = true
                self:ApplySlotStyle(frame)
                self:ShowTooltip(frame)
            end)
            slot:SetScript("OnLeave", function(frame)
                frame._rexHovered = false
                self:ApplySlotStyle(frame)
                GameTooltip_Hide()
            end)
            slot:SetScript("OnClick", function(frame, button)
                local provider = self.AssignedDataTexts[frame]
                if button == "RightButton" and IsAltKeyDown and IsAltKeyDown() then
                    self:OpenSelectionMenu(frame)
                elseif provider and provider.onClick then
                    pcall(provider.onClick, provider, frame, button)
                end
            end)
            panel.dataPanels[index] = slot
        end

        -- Vier Pixel Innenrand und vier Pixel Abstand
        -- zwischen den Datentexten.
        local panelWidth, panelHeight = panel:GetSize()
        panelWidth = tonumber(panelWidth) or 160
        panelHeight = tonumber(panelHeight) or 20
        if panelWidth < 40 then panelWidth = 160 end
        if panelHeight < 8 then panelHeight = 20 end
        slot:SetSize((panelWidth / numberOfSlots) - 4, panelHeight - 4)
        slot:SetFrameLevel(panel:GetFrameLevel() + 1)
        slot:SetAlpha(1)
        slot:Show()
        slot.text:SetDrawLayer("OVERLAY", 7)
        self:ApplySlotStyle(slot)
        slot.text:Show()
        slot:ClearAllPoints()
        local previous = index == 1 and panel or panel.dataPanels[index - 1]
        slot:SetPoint("LEFT", previous, index == 1 and "LEFT" or "RIGHT", 4, 0)
    end
    -- Überzählige Slots (nach Verkleinern) deaktivieren
    for index = numberOfSlots + 1, #panel.dataPanels do
        local slot = panel.dataPanels[index]
        slot:UnregisterAllEvents()
        slot:SetScript("OnUpdate", nil)
        slot._rexDataTextActive = false
        self.AssignedDataTexts[slot] = nil
        slot:Hide()
    end
end

function DT:CreatePanel(minimap)
    if self.Panel then return self.Panel end
    local panel = CreateFrame("Frame", "RexUI_MinimapDataBar", UIParent, "BackdropTemplate")
    panel:SetSize(160, 20)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(0.02, 0.015, 0.025, 0.92)
    panel:SetScript("OnSizeChanged", function(frame)
        if DT._panelLayouting then return end
        DT._panelLayouting = true
        DT:RegisterPanel(frame, #SLOT_KEYS)
        DT._panelLayouting = nil
    end)
    self.Panel = panel
    self:RegisterPanel(panel, #SLOT_KEYS)
    return panel
end

function DT:CreateMover()
    local panel = self.Panel
    if not panel then return end
    if self.Mover then
        self.Mover:ClearAllPoints()
        self.Mover:SetAllPoints(panel)
        return self.Mover
    end

    local mover = CreateFrame("Frame", "RexUI_MinimapDataBarMover", panel)
    mover:SetAllPoints(panel)
    mover:SetFrameLevel(panel:GetFrameLevel() + 50)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")

    mover.Background = mover:CreateTexture(nil, "BACKGROUND")
    mover.Background:SetAllPoints()
    mover.Background:SetColorTexture(0.2, 0.6, 1, 0.28)

    mover.Label = mover:CreateFontString(nil, "OVERLAY")
    mover.Label:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    mover.Label:SetPoint("CENTER")
    mover.Label:SetText(T("Datenleiste"))

    mover:SetScript("OnDragStart", function()
        if InCombatLockdown and InCombatLockdown() then return end
        panel:StartMoving()
    end)
    mover:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        local panelX, panelY = panel:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        if panelX and panelY and parentX and parentY then
            M:Save("dataBarManualPosition", true)
            M:Save("dataBarPoint", "CENTER")
            M:Save("dataBarRelPoint", "CENTER")
            M:Save("dataBarX", math.floor(panelX - parentX + 0.5))
            M:Save("dataBarY", math.floor(panelY - parentY + 0.5))
            panel:ClearAllPoints()
            panel:SetPoint("CENTER", UIParent, "CENTER", panelX - parentX, panelY - parentY)
        end
    end)
    mover:Hide()
    self.Mover = mover
    return mover
end

function DT:ShowMover()
    local panel = self.Panel
    if not panel or not panel:IsShown() then return end
    local mover = self:CreateMover()
    if mover then mover:Show() end
end

function DT:HideMover()
    if self.Mover then self.Mover:Hide() end
end

function DT:Apply(minimap, cfg, forceRebuild)
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    local saved = profile and profile.minimap
    if saved and saved.dataTextLayoutVersion ~= 4 then
        -- Bestehende Auswahl behalten und nur den neuen mittleren Slot ergänzen.
        saved.dataTextLayoutVersion = 4
        saved.dataTextLeft = saved.dataTextLeft or "GUILD"
        saved.dataTextCenter = saved.dataTextCenter or "SYSTEM"
        saved.dataTextRight = saved.dataTextRight or "BNET"
        cfg.dataTextLayoutVersion = 4
        cfg.dataTextLeft = saved.dataTextLeft
        cfg.dataTextCenter = saved.dataTextCenter
        cfg.dataTextRight = saved.dataTextRight
    end

    if cfg.showDataBar == false then
        self:Hide()
        return
    end

    local panel = self:CreatePanel(minimap)
    panel:SetParent(UIParent)
    local minimapWidth = tonumber(minimap:GetWidth()) or tonumber(cfg.size) or 160
    if minimapWidth < 40 then minimapWidth = tonumber(cfg.size) or 160 end
    panel:SetSize(minimapWidth, 20)
    panel:ClearAllPoints()
    if cfg.dataBarManualPosition then
        local point = cfg.dataBarPoint or "CENTER"
        panel:SetPoint(point, UIParent, cfg.dataBarRelPoint or point, cfg.dataBarX or 0, cfg.dataBarY or 0)
    else
        panel:SetPoint("TOP", minimap, "BOTTOM", 0, -3)
    end
    panel:SetFrameLevel(minimap:GetFrameLevel() + 25)
    self:RegisterPanel(panel, #SLOT_KEYS)

    local r, g, b, a = 0.15, 0.15, 0.15, 0.95
    if minimap.RexUIBorder and minimap.RexUIBorder.GetBackdropBorderColor then
        r, g, b, a = minimap.RexUIBorder:GetBackdropBorderColor()
    end
    if cfg.dataBarBackdrop == false then
        panel:SetBackdropColor(0, 0, 0, 0)
    else
        local color = cfg.dataBarBackgroundColor or { r = 0.10, g = 0.10, b = 0.10 }
        local alpha = tonumber(cfg.dataBarBackgroundAlpha)
        if alpha == nil then alpha = cfg.dataBarPanelTransparency and 0.80 or 1.00 end
        panel:SetBackdropColor(color.r or 0.10, color.g or 0.10, color.b or 0.10, alpha)
    end
    if cfg.dataBarBorder == false then
        panel:SetBackdropBorderColor(0, 0, 0, 0)
    else
        local color = cfg.dataBarBorderColor
        local alpha = tonumber(cfg.dataBarBorderAlpha)
        if color then r, g, b = color.r or r, color.g or g, color.b or b end
        panel:SetBackdropBorderColor(r, g, b, alpha == nil and a or alpha)
    end

    for index = 1, #SLOT_KEYS do
        local slot = panel.dataPanels[index]
        local name = cfg[SLOT_KEYS[index]] or SLOT_DEFAULTS[index]
        if forceRebuild or not slot._rexDataTextActive or slot.dataTextName ~= name or not self.AssignedDataTexts[slot] then
            self:AssignPanelToDataText(slot, name)
        else
            -- Nur den sichtbaren Wert erneuern; keine Anbieter-Nebenwirkungen
            -- wie eine neue Gildenroster-Abfrage bei reinen Stiländerungen.
            self:UpdateSlot(slot, "DISPLAY_REFRESH")
        end
    end
    panel:Show()
end

function DT:Hide()
    if not self.Panel then return end
    self:HideMover()
    self.Panel:Hide()
    for _, slot in ipairs(self.Panel.dataPanels or {}) do
        slot:UnregisterAllEvents()
        slot:SetScript("OnUpdate", nil)
        slot._rexDataTextActive = false
        slot._rexHovered = false
    end
end

function DT:RefreshVisibleData(event, ...)
    for panel in pairs(self.Panels or {}) do
        if panel:IsShown() then
            for _, slot in ipairs(panel.dataPanels or {}) do
                if self.AssignedDataTexts[slot] and slot:IsShown() then
                    self:UpdateSlot(slot, event or "DISPLAY_REFRESH", ...)
                end
            end
        end
    end
end

function DT:Initialize()
    if self.Initialized then return end
    self.Initialized = true

    -- Wie bei ElvUI wird das Panel einmal beim Laden des Moduls erzeugt.
    -- PLAYER_ENTERING_WORLD ist danach nur noch fuer Datenupdates zustaendig
    -- und nicht mehr fuer die Erzeugung der Frames.
    local minimap = _G.Minimap
    if minimap then
        local panel = self:CreatePanel(minimap)
        panel:Hide()
    end

    local eventFrame = CreateFrame("Frame")
    self.EventFrame = eventFrame
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
    eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    eventFrame:RegisterEvent("BN_CONNECTED")
    eventFrame:RegisterEvent("BN_FRIEND_INFO_CHANGED")
    eventFrame:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
    eventFrame:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
    eventFrame:RegisterEvent("FRIENDLIST_UPDATE")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            if IsInGuild and IsInGuild() then
                if C_GuildInfo and C_GuildInfo.GuildRoster then
                    pcall(C_GuildInfo.GuildRoster)
                elseif GuildRoster then
                    pcall(GuildRoster)
                end
            end
        end
        DT:RefreshVisibleData(event, ...)
    end)
end

DT:RegisterDatatext("NONE", {
    label = "Leer",
    getText = function() return "" end,
})

DT:RegisterDatatext("TIME", {
    label = "Uhrzeit", interval = 1, clickText = "Linksklick: Kalender – Rechtsklick: Zeitmanager",
    getText = function()
        -- Bewusst ohne eigene Sonderoptionen: lokale Zeit im kompakten
        -- 24-Stunden-Format, wie sie in der Minimap-Leiste erwartet wird.
        local localInfo = date and GetServerTime and date("*t", GetServerTime())
        if localInfo then
            return format("%02d:%02d", localInfo.hour or 0, localInfo.min or 0)
        end

        local getGameTime = GetGameTime or GameTime_GetGameTime
        local hour, minute = getGameTime()
        return format("%02d:%02d", hour or 0, minute or 0)
    end,
    onTooltipShow = function(_, _, tooltip)
        local cfg = M:GetConfig()
        local getGameTime = GetGameTime or GameTime_GetGameTime
        local realmHour, realmMinute = getGameTime()
        local localInfo = date and GetServerTime and date("*t", GetServerTime())
        if localInfo then tooltip:AddDoubleLine(T("Lokale Zeit"), format("%02d:%02d", localInfo.hour, localInfo.min), 0.8, 0.8, 0.8, 1, 1, 1) end
        tooltip:AddDoubleLine(T("Realmzeit"), format("%02d:%02d", realmHour or 0, realmMinute or 0), 0.8, 0.8, 0.8, 1, 1, 1)
        if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
            local dailyReset = C_DateAndTime.GetSecondsUntilDailyReset()
            if dailyReset then tooltip:AddDoubleLine(T("Täglicher Reset"), SecondsToTime(dailyReset), 0.8, 0.8, 0.8, 1, 1, 1) end
        end
        if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
            local weeklyReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
            if weeklyReset then tooltip:AddDoubleLine(T("Wöchentlicher Reset"), SecondsToTime(weeklyReset), 0.8, 0.8, 0.8, 1, 1, 1) end
        end
    end,
    onClick = function(_, _, button)
        if button == "RightButton" then
            if _G.TimeManagerFrame and ToggleFrame then ToggleFrame(_G.TimeManagerFrame)
            elseif ToggleTimeManager then ToggleTimeManager() end
        elseif _G.GameTimeFrame and _G.GameTimeFrame.Click then
            _G.GameTimeFrame:Click()
        end
    end,
})

DT:RegisterDatatext("GOLD", {
    label = "Gold", events = { "PLAYER_MONEY" }, clickText = "Klicken: Taschen öffnen",
    getText = function() return ShortMoney(GetMoney()) end,
    onTooltipShow = function(_, _, tooltip)
        tooltip:AddDoubleLine(T("Aktueller Charakter"), GetMoneyString(GetMoney(), true), 0.8, 0.8, 0.8, 1, 1, 1)
    end,
    onClick = function()
        if RexUI.Bags and RexUI.Bags.ToggleAllBags then RexUI.Bags:ToggleAllBags()
        elseif ToggleAllBags then ToggleAllBags() end
    end,
})

DT:RegisterDatatext("DURABILITY", {
    label = "Haltbarkeit", events = { "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED", "MERCHANT_SHOW" },
    clickText = "Klicken: Charakterfenster öffnen",
    getText = function()
        local lowest
        for slot = 1, 18 do
            local current, maximum = GetInventoryItemDurability(slot)
            if current and maximum and maximum > 0 then
                local percent = current / maximum * 100
                lowest = not lowest and percent or math.min(lowest, percent)
            end
        end
        if not lowest then return T("Rüstung --") end
        local color = lowest <= 25 and "|cffff4040" or (lowest <= 50 and "|cffffb020" or "|cff40ff70")
        return format("%s%d%%|r", color, math.floor(lowest + 0.5))
    end,
    onTooltipShow = function(_, _, tooltip)
        for slot = 1, 18 do
            local current, maximum = GetInventoryItemDurability(slot)
            if current and maximum and maximum > 0 then
                local item = GetInventoryItemLink("player", slot)
                if item then tooltip:AddDoubleLine(item, format("%d%%", math.floor(current / maximum * 100 + 0.5)), 1, 1, 1, 0.8, 0.8, 0.8) end
            end
        end
    end,
    onClick = function() if ToggleCharacter then ToggleCharacter("PaperDollFrame") end end,
})

DT:RegisterDatatext("SYSTEM", {
    label = "FPS und Latenz", interval = 1,
    getText = function()
        local _, _, _, world = GetNetStats()
        return format("%d FPS %dms", math.floor(GetFramerate() + 0.5), SafeNumber(world))
    end,
    onTooltipShow = function(_, _, tooltip)
        local bandwidthIn, bandwidthOut, home, world = GetNetStats()
        tooltip:AddDoubleLine(T("Heimlatenz"), format("%d ms", SafeNumber(home)), 0.8, 0.8, 0.8, 1, 1, 1)
        tooltip:AddDoubleLine(T("Weltlatenz"), format("%d ms", SafeNumber(world)), 0.8, 0.8, 0.8, 1, 1, 1)
        tooltip:AddDoubleLine(T("Download/Upload"), format("%.1f / %.1f KB/s", SafeNumber(bandwidthIn), SafeNumber(bandwidthOut)), 0.8, 0.8, 0.8, 1, 1, 1)
    end,
})

DT:RegisterDatatext("BAGS", {
    label = "Freie Taschenplätze", events = { "BAG_UPDATE_DELAYED" }, clickText = "Klicken: Taschen öffnen",
    getText = function()
        local free = C_Container and C_Container.CalculateTotalNumberOfFreeBagSlots and C_Container.CalculateTotalNumberOfFreeBagSlots() or 0
        return format("Taschen %d", SafeNumber(free))
    end,
    onClick = function()
        if RexUI.Bags and RexUI.Bags.ToggleAllBags then RexUI.Bags:ToggleAllBags()
        elseif ToggleAllBags then ToggleAllBags() end
    end,
})

local cachedGuildMOTD

local function RefreshGuildMOTDCache()
    if InCombatLockdown and InCombatLockdown() then return end
    if not IsInGuild or not IsInGuild() then
        cachedGuildMOTD = nil
        return
    end
    if C_GuildInfo and C_GuildInfo.GetMOTD then
        local ok, motd = pcall(C_GuildInfo.GetMOTD)
        if ok and type(motd) == "string" then cachedGuildMOTD = motd end
    end
end

DT:RegisterDatatext("GUILD", {
    label = "Gilde", events = { "PLAYER_ENTERING_WORLD", "PLAYER_GUILD_UPDATE", "GUILD_ROSTER_UPDATE", "GUILD_MOTD", "PLAYER_REGEN_ENABLED" }, clickText = "Klicken: Gilde öffnen",
    getText = function()
        if not IsInGuild or not IsInGuild() then return T("Keine Gilde") end
        local _, mobileOrOnline, online = GetNumGuildMembers()
        online = online or mobileOrOnline or 0
        return format("Gilde: %d", SafeNumber(online))
    end,
    onEvent = function(_, _, event)
        if (event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_GUILD_UPDATE" or event == "FORCE_UPDATE") and IsInGuild and IsInGuild() then
            if not _G.GuildFrame and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_GuildUI") end
            if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster()
            elseif GuildRoster then GuildRoster() end
        end
        RefreshGuildMOTDCache()
    end,
    onTooltipShow = function(_, _, tooltip)
        if not IsInGuild or not IsInGuild() then return end
        local total, mobileOrOnline, online = GetNumGuildMembers()
        online = online or mobileOrOnline or 0
        local guildName, guildRank = GetGuildInfo("player")
        tooltip:AddDoubleLine(guildName or T("Gilde"), format("%s: %d/%d", T("Gilde"), SafeNumber(online), SafeNumber(total)), 0.4, 0.78, 1, 0.4, 0.78, 1)
        if guildRank then tooltip:AddLine(guildRank, 0.75, 0.9, 1) end
        -- Nie aus dem Mouseover-Handler aufrufen: GetMOTD ist im Kampf geschützt.
        local motd = cachedGuildMOTD
        if motd and motd ~= "" then
            tooltip:AddLine(" ")
            tooltip:AddLine(format("%s - %s", T("Gildennachricht"), motd), 0.75, 0.9, 1, true)
        end
        local shown = 0
        for index = 1, SafeNumber(total) do
            local name, _, _, level, _, zone, _, _, connected, _, className, _, _, isMobile = GetGuildRosterInfo(index)
            if name and (connected or isMobile) then
                shown = shown + 1
                if shown <= 20 then
                    local color = className and RAID_CLASS_COLORS and RAID_CLASS_COLORS[className]
                    tooltip:AddDoubleLine(format("%s %s", level or "", Ambiguate and Ambiguate(name, "short") or name), zone or "", color and color.r or 1, color and color.g or 1, color and color.b or 1, 0.65, 0.65, 0.65)
                end
            end
        end
    end,
    onClick = function()
        if InCombatLockdown and InCombatLockdown() then return end
        if not _G.GuildFrame and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_GuildUI") end
        if ToggleGuildFrame then ToggleGuildFrame()
        elseif ToggleFriendsFrame then ToggleFriendsFrame(_G.FRIEND_TAB_GUILD or 3) end
    end,
})

DT:RegisterDatatext("BNET", {
    label = "Freunde",
    interval = 1,
    events = { "BN_CONNECTED", "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE", "FRIENDLIST_UPDATE" },
    clickText = "Klicken: Freunde öffnen",
    getText = function()
        local onlineBNet = CountOnlineBattleNetWoWFriends()
        local onlineWoW = C_FriendList and C_FriendList.GetNumOnlineFriends and C_FriendList.GetNumOnlineFriends() or 0
        return format("Freunde: %d", SafeNumber(onlineWoW) + SafeNumber(onlineBNet))
    end,
    onTooltipShow = function(_, _, tooltip)
        AddOnlineWoWFriends(tooltip)
        AddOnlineBattleNetFriends(tooltip)
    end,
    onClick = function()
        if ToggleFriendsFrame then ToggleFriendsFrame(_G.FRIEND_TAB_FRIENDS or 1) end
    end,
})

DT:RegisterDatatext("COORDINATES", {
    label = "Koordinaten", interval = 0.25, clickText = "Klicken: Weltkarte öffnen",
    getText = function()
        local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
        if not position then return "--  --" end
        local x, y = position:GetXY()
        if canaccessvalue and (not canaccessvalue(x) or not canaccessvalue(y)) then return "--  --" end
        return format("%.1f %.1f", x * 100, y * 100)
    end,
    onClick = function() if ToggleWorldMap then ToggleWorldMap() end end,
})

DT:RegisterDatatext("LOCATION", {
    label = "Gebiet", events = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }, clickText = "Klicken: Weltkarte öffnen",
    getText = function() return GetMinimapZoneText() or "" end,
    onClick = function() if ToggleWorldMap then ToggleWorldMap() end end,
})


-- Providers sind jetzt vollstaendig registriert; Panel/Event-Lifecycle starten.
DT:Initialize()
