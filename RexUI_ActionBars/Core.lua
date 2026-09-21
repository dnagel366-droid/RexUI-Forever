-- ============================================================
-- RexUI_ActionBars\Core.lua
-- Modulstart, Events und combat-sichere Deferred-Tasks.
-- ============================================================

local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI

RexUI.ActionBars = RexUI.ActionBars or {}
local AB = RexUI.ActionBars

AB.Bars = AB.Bars or {}
AB.Buttons = AB.Buttons or {}
AB.Deferred = AB.Deferred or {}
AB.frame = AB.frame or CreateFrame("Frame")
AB.BindingOwner = AB.BindingOwner or CreateFrame("Frame", "RexUI_ActionBarBindOwner", UIParent)
AB.BindingOwner:SetSize(1, 1)
AB.BindingOwner:Show()
AB.HiddenFrame = AB.HiddenFrame or CreateFrame("Frame", nil, UIParent)
AB.HiddenFrame:SetSize(1, 1)
AB.HiddenFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
AB.HiddenFrame:Hide()

-- Blizzard muss seine nativen ActionButtons und deren interne Registrierungen
-- vollständig selbst verwalten. Änderungen an den Registry-Tabellen verunreinigen
-- seit WoW 12.1 den geschützten Cooldown-Pfad und führen bei geheimen Werten zu
-- Fehlern in ActionButton_ApplyCooldown.

function AB:RunOutOfCombat(key, callback)
    if not InCombatLockdown() then
        callback()
        return
    end

    self.Deferred[key or callback] = callback
end

function AB:FlushDeferred()
    if InCombatLockdown() then return end

    local pending = self.Deferred
    self.Deferred = {}

    for _, callback in pairs(pending) do
        callback()
    end
end

function AB:HideBlizzardBars(visualOnly)
    if InCombatLockdown() then
        self:RunOutOfCombat("HideBlizzardBars", function()
            AB:HideBlizzardBars(visualOnly)
        end)
        return
    end

    local function fadeFrame(frame)
        if not frame then return end

        securecall(frame.SetAlpha, frame, 0)
        securecall(frame.EnableMouse, frame, false)

        if frame.Selection then
            securecall(frame.Selection.Hide, frame.Selection)
            securecall(frame.Selection.SetAlpha, frame.Selection, 0)
        end

        if frame.EndCaps then securecall(frame.EndCaps.Hide, frame.EndCaps) end
        if frame.BorderArt then securecall(frame.BorderArt.Hide, frame.BorderArt) end
        if frame.ArtContainer then securecall(frame.ArtContainer.Hide, frame.ArtContainer) end
    end

    -- Keep Blizzard action buttons visually untouched. Their owning containers
    -- are faded below. We only disable mouse input on the native buttons while
    -- out of combat so invisible Blizzard bars cannot intercept clicks.
    -- IMPORTANT: do not SetAlpha/Hide/SetAttribute on these buttons; those visual/
    -- secure-state writes were the source of the 12.1 taint regression.
    local function disableNativeButtonMouse(button)
        if not button then return end
        securecall(button.EnableMouse, button, false)
    end

    local function disableNativeButtonRange(prefix, count)
        for i = 1, count do
            disableNativeButtonMouse(_G[prefix .. i])
        end
    end
    local frameNames = {
        "MainActionBar",
        "MainMenuBar",
        "MainMenuBarArtFrame",
        "MainMenuExpBar",
        "MainMenuBarMaxLevelBar",
        "StatusTrackingBarManager",
        "MicroButtonAndBagsBar",
        "OverrideActionBar",
        "OverrideActionBarButtonFrame",
        "OverrideActionBarLeaveFrame",
        "VehicleMenuBar",
        "PossessBarFrame",
        "StanceBar",
        "StanceBarFrame",
        "ShapeshiftBarFrame",
        "PetActionBar",
        "PetActionBarFrame",
        "MultiBarBottomLeft",
        "MultiBarBottomRight",
        "MultiBarLeft",
        "MultiBarRight",
        "MultiBar5",
        "MultiBar6",
        "MultiBar7",
    }

    for _, name in ipairs(frameNames) do
        fadeFrame(_G[name])
    end

    -- Alpha 0 on a parent does NOT stop secure child buttons from receiving
    -- mouse clicks. Disable only mouse input; leave their visuals and secure
    -- attributes alone. HideBlizzardBars already defers this work until combat
    -- lockdown has ended.
    disableNativeButtonRange("ActionButton", 12)
    disableNativeButtonRange("MultiBarBottomLeftButton", 12)
    disableNativeButtonRange("MultiBarBottomRightButton", 12)
    disableNativeButtonRange("MultiBarLeftButton", 12)
    disableNativeButtonRange("MultiBarRightButton", 12)
    disableNativeButtonRange("MultiBar5Button", 12)
    disableNativeButtonRange("MultiBar6Button", 12)
    disableNativeButtonRange("MultiBar7Button", 12)
    disableNativeButtonRange("StanceButton", 10)
    disableNativeButtonRange("PetActionButton", 10)

    if _G.ActionBarController then
        -- _G.ActionBarController:UnregisterAllEvents() -- Events behalten! Sonst fehlt Boss-Button + OverrideActionBar
    end

end

function AB:QueueHideBlizzardBars(visualOnly)
    if self.pendingBlizzardBarHide then return end
    self.pendingBlizzardBarHide = true

    C_Timer.After(0, function()
        AB.pendingBlizzardBarHide = false
        AB:HideBlizzardBars(visualOnly)
    end)
end

function AB:IsOverrideActive()
    local checks = {
        "HasOverrideActionBar",
        "HasVehicleActionBar",
        "HasPossessBar",
    }

    for _, name in ipairs(checks) do
        local fn = _G[name]
        if fn then
            local ok, active = pcall(fn)
            if ok and active then
                return true
            end
        end
    end

    return false
end

function AB:UpdateOverrideVisibility()
    if InCombatLockdown() then
        self:RunOutOfCombat("UpdateOverrideVisibility", function()
            AB:UpdateOverrideVisibility()
        end)
        return
    end

    local overrideActive = self:IsOverrideActive()

    for barKey, bar in pairs(self.Bars or {}) do
        local cfg = self.GetConfig and self:GetConfig(barKey)
        local enabled = not cfg or cfg.enabled ~= false

        if self.ApplyBarVisibility then
            self:ApplyBarVisibility(barKey, bar, enabled)
        elseif RegisterStateDriver then
            RegisterStateDriver(bar, "visibility", enabled and (barKey == "Bar1" and "show" or "[petbattle][overridebar][vehicleui][possessbar] hide; show") or "hide")
        elseif enabled then
            bar:Show()
        else
            bar:Hide()
        end
    end

end

local function CopyTableLocal(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = CopyTableLocal(v)
    end
    return dst
end

local function HasActionBarLayoutData(db)
    if type(db) ~= "table" then return false end

    for key, value in pairs(db) do
        if type(value) == "table"
        and (tostring(key):match("^Bar%d+$") or key == "PetBar" or key == "StanceBar") then
            if value.x ~= nil or value.y ~= nil then
                return true
            end
        end
    end

    return false
end

local function LayoutWeight(db)
    if not HasActionBarLayoutData(db) then
        return 0
    end

    local weight = 0
    for key, value in pairs(db) do
        if type(value) == "table"
        and (tostring(key):match("^Bar%d+$") or key == "PetBar" or key == "StanceBar")
        and (value.x ~= nil or value.y ~= nil) then
            weight = weight + 1
            for _ in pairs(value) do
                weight = weight + 1
            end
        end
    end
    return weight
end

local SPEC_CLASS = {
    ["253"] = "HUNTER", ["254"] = "HUNTER", ["255"] = "HUNTER",
    ["102"] = "DRUID", ["103"] = "DRUID", ["104"] = "DRUID", ["105"] = "DRUID",
    ["65"] = "PALADIN", ["66"] = "PALADIN", ["70"] = "PALADIN",
    ["262"] = "SHAMAN", ["263"] = "SHAMAN", ["264"] = "SHAMAN",
    ["71"] = "WARRIOR", ["72"] = "WARRIOR", ["73"] = "WARRIOR",
    ["250"] = "DEATHKNIGHT", ["251"] = "DEATHKNIGHT", ["252"] = "DEATHKNIGHT",
    ["268"] = "MONK", ["269"] = "MONK", ["270"] = "MONK",
    ["577"] = "DEMONHUNTER", ["581"] = "DEMONHUNTER",
    ["256"] = "PRIEST", ["257"] = "PRIEST", ["258"] = "PRIEST",
    ["62"] = "MAGE", ["63"] = "MAGE", ["64"] = "MAGE",
    ["259"] = "ROGUE", ["260"] = "ROGUE", ["261"] = "ROGUE",
    ["265"] = "WARLOCK", ["266"] = "WARLOCK", ["267"] = "WARLOCK",
    ["1467"] = "EVOKER", ["1468"] = "EVOKER", ["1473"] = "EVOKER",
}

local function SpecClass(specKey)
    return SPEC_CLASS[tostring(specKey or "")]
end

local function IsCharacterOwnedProfile(profileName)
    local characterKey = RexUI.GetCharacterKey and RexUI:GetCharacterKey()
    return type(profileName) == "string"
        and type(characterKey) == "string"
        and profileName == characterKey
end

local function PickRichestSpecKey(bySpec, currentSpecKey)
    local currentClass = SpecClass(currentSpecKey)
    local bestKey, bestWeight
    for specKey, specData in pairs(bySpec) do
        if specKey ~= "0" and HasActionBarLayoutData(specData) then
            local weight = LayoutWeight(specData)
            if type(specData.PetBar) == "table" and specData.PetBar.enabled == false then
                weight = weight + 50
            end
            local otherClass = SpecClass(specKey)
            if currentClass and otherClass and otherClass ~= currentClass then
                weight = weight + 100
            elseif specKey ~= currentSpecKey then
                weight = weight + 10
            end
            if not bestWeight or weight > bestWeight then
                bestKey = specKey
                bestWeight = weight
            end
        end
    end
    return bestKey
end

local function PickHomeSpecKey(profile, currentSpecKey)
    local bySpec = profile and profile.actionbarsBySpec
    if type(bySpec) ~= "table" then
        return currentSpecKey
    end

    local profileName = RexUI.GetCurrentProfile and RexUI:GetCurrentProfile()
    local owned = IsCharacterOwnedProfile(profileName)
    local stored = profile.lastActionBarSpec

    -- Trust a stored home spec only for the owner, or when it is not the
    -- viewer's spec (Fix19 could stamp the viewer spec onto a named profile).
    if type(stored) == "string" and HasActionBarLayoutData(bySpec[stored]) then
        if owned or stored ~= currentSpecKey then
            return stored
        end
    end

    if owned and HasActionBarLayoutData(bySpec[currentSpecKey]) then
        profile.lastActionBarSpec = currentSpecKey
        return currentSpecKey
    end

    -- Named / foreign profile: use that profile's richest saved layout.
    local bestKey = PickRichestSpecKey(bySpec, currentSpecKey)
    if bestKey then
        if not owned then
            profile.lastActionBarSpec = bestKey
        end
        return bestKey
    end

    return currentSpecKey
end

local function GetFallbackActionBarSource(profile, currentSpecKey, previousSpecKey)
    if type(profile) ~= "table" then return nil end

    local bySpec = profile.actionbarsBySpec

    if previousSpecKey
    and type(bySpec) == "table"
    and previousSpecKey ~= currentSpecKey
    and HasActionBarLayoutData(bySpec[previousSpecKey]) then
        return bySpec[previousSpecKey]
    end

    if HasActionBarLayoutData(profile.actionbars) then
        return profile.actionbars
    end

    local fallback
    local fallbackWeight = 0
    if type(bySpec) == "table" then
        for specKey, specData in pairs(bySpec) do
            if specKey ~= currentSpecKey and specKey ~= "0" then
                local weight = LayoutWeight(specData)
                if weight > fallbackWeight then
                    fallback = specData
                    fallbackWeight = weight
                end
            end
        end
        if not fallback and HasActionBarLayoutData(bySpec["0"]) then
            fallback = bySpec["0"]
        end
    end

    return fallback or profile.actionbars
end

function AB:GetCurrentSpecKey()
    local specIndex = GetSpecialization and GetSpecialization()
    if specIndex and GetSpecializationInfo then
        local specID = GetSpecializationInfo(specIndex)
        if specID then
            return tostring(specID)
        end
    end
    return tostring(specIndex or "default")
end

function AB:GetCurrentActionBarDB(profile)
    profile = profile or (RexUI.GetProfile and RexUI:GetProfile())
    if not profile then return nil end

    local specKey = AB:GetCurrentSpecKey()
    local previousSpecKey = self.CurrentSpecKey
    profile.actionbars = profile.actionbars or {}
    profile.actionbarsBySpec = profile.actionbarsBySpec or {}
    self.CurrentSpecKey = specKey

    local homeKey = PickHomeSpecKey(profile, specKey)
    local homeData = profile.actionbarsBySpec[homeKey]
    if HasActionBarLayoutData(homeData) then
        return homeData
    end

    local source = GetFallbackActionBarSource(profile, specKey, previousSpecKey)
    if HasActionBarLayoutData(source) and homeKey == specKey then
        profile.actionbarsBySpec[specKey] = CopyTableLocal(source)
        return profile.actionbarsBySpec[specKey]
    end

    if HasActionBarLayoutData(source) then
        return CopyTableLocal(source)
    end

    return profile.actionbarsBySpec[specKey] or profile.actionbars
end

function AB:CaptureBaseConfig()
    if self.BaseConfig then return end
    self.BaseConfig = {}
    for key, cfg in pairs(self.Config or {}) do
        if key ~= "Defaults" then
            self.BaseConfig[key] = CopyTableLocal(cfg)
        end
    end
end

function AB:ResetConfigToBase()
    self:CaptureBaseConfig()
    if self.InvalidateConfigCache then
        self:InvalidateConfigCache()
    end
    for key, cfg in pairs(self.BaseConfig or {}) do
        self.Config[key] = CopyTableLocal(cfg)
    end
    if self.InvalidateConfigCache then
        self:InvalidateConfigCache()
    end
end

function AB:ApplyLoadedSettings()
    if InCombatLockdown and InCombatLockdown() then
        AB:RunOutOfCombat("ApplyLoadedSettings", function()
            AB:ApplyLoadedSettings()
        end)
        return
    end

    self:LoadProfileSettings()
    if self.InvalidateConfigCache then
        self:InvalidateConfigCache()
    end

    for _, entry in ipairs(AB.BarRegistry or {}) do
        AB:UpdateBar(entry.key)
    end
    AB:UpdateBar("PetBar")
    AB:UpdateBar("StanceBar")
end

function AB:LoadProfileSettings()
    local profile = RexUI:GetProfile()
    if not profile then return end

    AB:ResetConfigToBase()
    local actionbars = AB:GetCurrentActionBarDB(profile)
    if not actionbars then return end

    if (tonumber(actionbars.elvButtonStyleVersion) or 0) < 1 then
        for _, savedData in pairs(actionbars) do
            if type(savedData) == "table" and tonumber(savedData.buttonSize) == 34 then
                savedData.buttonSize = 32
            end
        end
        actionbars.elvButtonStyleVersion = 1
    end

    local function clampNumber(value, minValue, maxValue, fallback, integer)
        value = tonumber(value)

        if not value then
            return fallback
        end

        value = math.max(minValue, math.min(maxValue, value))

        if integer then
            value = math.floor(value + 0.5)
        end

        return value
    end

    local function sanitizeBarData(barKey, savedData)
        if type(savedData) ~= "table" then
            actionbars[barKey] = nil
            return nil
        end

        local validPoints = {
            TOPLEFT = true,
            TOP = true,
            TOPRIGHT = true,
            LEFT = true,
            CENTER = true,
            RIGHT = true,
            BOTTOMLEFT = true,
            BOTTOM = true,
            BOTTOMRIGHT = true,
        }

        local maxSlots = (barKey == "PetBar" or barKey == "StanceBar") and 10 or 12
        savedData.slots = clampNumber(savedData.slots or savedData.buttons, 1, maxSlots, nil, true)
        savedData.buttons = savedData.slots
        savedData.buttonSize = clampNumber(savedData.buttonSize, 20, 60, nil, true)
        savedData.spacing = clampNumber(savedData.spacing, -3, 20, nil, true)
        savedData.scale = clampNumber(savedData.scale, 0.5, 2, nil, false)
        savedData.alpha = clampNumber(savedData.alpha, 0.05, 1, nil, false)
        savedData.rows = clampNumber(savedData.rows, 1, 12, nil, true)

        if savedData.x ~= nil then
            savedData.x = clampNumber(savedData.x, -5000, 5000, 0, true)
        end

        if savedData.y ~= nil then
            savedData.y = clampNumber(savedData.y, -5000, 5000, 0, true)
        end

        if savedData.enabled ~= nil then
            savedData.enabled = savedData.enabled == true
        end

        if savedData.vertical ~= nil then
            savedData.vertical = savedData.vertical == true
        end

        if savedData.mouseover ~= nil then
            savedData.mouseover = savedData.mouseover == true
        end

        if savedData.point ~= nil and not validPoints[savedData.point] then
            savedData.point = nil
        end

        if savedData.relPoint ~= nil and not validPoints[savedData.relPoint] then
            savedData.relPoint = nil
        end

        return savedData
    end

    for barKey, savedData in pairs(actionbars) do
        if AB.Config and AB.Config[barKey] then
            savedData = sanitizeBarData(barKey, savedData)

            if savedData then
                for key, value in pairs(savedData) do
                    if value ~= nil then
                        AB.Config[barKey][key] = value
                    end
                end
            end
        end
    end

    if AB.InvalidateConfigCache then
        AB:InvalidateConfigCache()
    end
end

-- ============================================================
-- UPDATE BAR (Ein/Ausschalten einer Bar zur Laufzeit)
-- ============================================================
function AB:UpdateBar(key)
    if not key then return end

    if AB.InvalidateConfigCache then
        AB:InvalidateConfigCache(key)
    end

    local cfg = AB:GetConfig(key)
    local bar = AB.Bars and AB.Bars[key]

    if cfg.enabled then
        -- Bar einschalten
        if not bar then
            -- Bar noch nicht erstellt → jetzt erstellen
            local entry
            for _, e in ipairs(AB.BarRegistry or {}) do
                if e.key == key then entry = e; break end
            end
            if entry then
                AB:CreateBar(key, cfg, entry.offset)
                bar = AB.Bars[key]
                if bar and cfg.mouseover and AB.Mouseover and AB.Mouseover.Apply then
                    AB.Mouseover:Apply(bar)
                end
                if AB.UpdateAllButtons then AB:UpdateAllButtons() end
                if AB.UpdateAllButtonOverlays then AB:UpdateAllButtonOverlays() end
            end
        else
            -- Bar existiert → Visibility-Driver updaten
            local visibility = key == "PetBar"
                and "[petbattle] hide; [novehicleui,pet,nooverridebar,nopossessbar] show; hide"
                or "[petbattle][vehicleui][overridebar][possessbar] hide; show"
            RegisterStateDriver(bar, "visibility", visibility)
        end
    else
        -- Bar ausschalten
        if bar then
            RegisterStateDriver(bar, "visibility", "hide")
        end
    end
end

function AB:Initialize()
	if self.initialized then return end
	self.initialized = true

    if self.UsesLAB then
        -- LAB already owns these high-frequency events for every normal action
        -- button. Pet and stance bars have their own dedicated dispatchers.
        for _, event in ipairs({
            "ACTIONBAR_UPDATE_COOLDOWN",
            "ACTIONBAR_UPDATE_USABLE",
            "UNIT_SPELLCAST_START",
            "UNIT_SPELLCAST_STOP",
            "UNIT_SPELLCAST_FAILED",
            "UNIT_SPELLCAST_INTERRUPTED",
            "UNIT_SPELLCAST_CHANNEL_START",
            "UNIT_SPELLCAST_CHANNEL_STOP",
            "UNIT_SPELLCAST_DELAYED",
            "UNIT_SPELLCAST_CHANNEL_UPDATE",
        }) do
            -- Forever LAB listens to ACTION_USABLE_CHANGED (Midnight), which
            -- does not fire here. Keep ACTIONBAR_UPDATE_USABLE for rage tint.
            local toc = select(4, GetBuildInfo()) or 0
            if event == "ACTIONBAR_UPDATE_USABLE" and toc >= 16000 and toc < 20000 then
                -- keep registered
            else
                self.frame:UnregisterEvent(event)
            end
        end
    end

    local toc = select(4, GetBuildInfo()) or 0
    if toc >= 16000 and toc < 20000 then
        if self.frame.RegisterUnitEvent then
            pcall(self.frame.RegisterUnitEvent, self.frame, "UNIT_POWER_UPDATE", "player")
            pcall(self.frame.RegisterUnitEvent, self.frame, "UNIT_POWER_FREQUENT", "player")
        end
    end

    -- Respect the game's ActionButtonUseKeyDown setting.  Changing a player's
    -- input preference here makes clicks feel inconsistent and, more
    -- importantly, leaves the saved CVar changed after RexUI is disabled.

	self:HideBlizzardBars()
	self:LoadProfileSettings()

    for _, entry in ipairs(AB.BarRegistry or {}) do
        local cfg = AB:GetConfig(entry.key)

        if cfg.enabled then
            AB:CreateBar(entry.key, cfg, entry.offset)

            local bar = AB.Bars[entry.key]
            if bar and cfg.mouseover and AB.Mouseover and AB.Mouseover.Apply then
                AB.Mouseover:Apply(bar)
            end
        end
    end

    if AB.LayoutAllBars then
        AB:LayoutAllBars()
    end

    if AB.InitStates then
        AB:InitStates()
    end

    if AB.UpdateAllButtons then
        AB:UpdateAllButtons()
    end

    if AB.Cooldowns then
        if AB.Cooldowns.QueueUpdateAll then
            AB.Cooldowns:QueueUpdateAll()
        elseif AB.Cooldowns.UpdateAll then
            AB.Cooldowns:UpdateAll()
        end
    end

    if AB.UpdateAllButtonOverlays then
        AB:UpdateAllButtonOverlays()
    end

    AB:UpdateOverrideVisibility()

    C_Timer.After(0, function() AB:QueueHideBlizzardBars(true) end)
    C_Timer.After(2, function() AB:QueueHideBlizzardBars(true) end)
    C_Timer.After(2.1, function() AB:UpdateOverrideVisibility() end)
end

-- Do not hook ActionBarController_UpdateAll. Running RexUI code directly after
-- Blizzard's protected controller updates can taint MultiBarRight:ShowBase().

-- Dirty-Slot-Tracking: nur geänderte Slots updaten
AB.DirtySlots = {}
AB.pendingDirtyFlush = false
AB.dirtyFlushRetries = 0

function AB:MarkDirty(slot)
    slot = tonumber(slot) or slot

    if slot and slot ~= 0 then
        self.DirtySlots[slot] = true
    else
        for s in pairs(self.Buttons) do
            self.DirtySlots[s] = true
        end
    end
end

function AB:MarkBarDirty(barKey)
    local bar = self.Bars and self.Bars[barKey]
    if not bar or not bar.buttons then
        self:MarkDirty()
        return
    end

    for _, btn in ipairs(bar.buttons) do
        local slot = btn and (btn.slot or btn.action)
        if slot then
            self.DirtySlots[slot] = true
        end
    end
end

local function ScheduleDirtyFlush()
    if AB.pendingDirtyFlush then return end
    AB.pendingDirtyFlush = true
    -- Coalesce event storms, but repaint on the next frame rather than adding
    -- a visible 50 ms wait. This mirrors EUI's central dispatcher cadence.
    C_Timer.After(0, function()
        AB.pendingDirtyFlush = false

        if type(AB.UpdateButton) ~= "function" then
            AB.dirtyFlushRetries = (AB.dirtyFlushRetries or 0) + 1
            if AB.dirtyFlushRetries < 20 then
                ScheduleDirtyFlush()
            end
            return
        end

        AB.dirtyFlushRetries = 0
        local currentPage = AB.GetEffectivePage and AB:GetEffectivePage()
        local updatedButtons = {}

        local function updateDirtyButton(btn)
            if not btn or updatedButtons[btn] then return end
            updatedButtons[btn] = true

            if InCombatLockdown() and AB.UpdateButtonCombatVisuals then
                AB:UpdateButtonCombatVisuals(btn)
            else
                AB:UpdateButton(btn)
            end
        end

        for slot in pairs(AB.DirtySlots) do
            local btn = AB.Buttons[slot]
            local pageButton
            local numericSlot = tonumber(slot)
            if numericSlot and AB.Bars and AB.Bars.Bar1 and AB.GetEffectivePage then
                local page = math.floor((numericSlot - 1) / (NUM_ACTIONBAR_BUTTONS or 12)) + 1
                if page == currentPage then
                    local index = ((numericSlot - 1) % (NUM_ACTIONBAR_BUTTONS or 12)) + 1
                    pageButton = AB.Bars.Bar1.buttons and AB.Bars.Bar1.buttons[index]
                end
            end

            updateDirtyButton(btn)
            updateDirtyButton(pageButton)
        end
        wipe(AB.DirtySlots)
    end)
end

function AB:ScheduleDirtyFlush()
    ScheduleDirtyFlush()
end

AB.pendingUsableRefresh = false

function AB:QueueUsableRefresh()
    if self.pendingUsableRefresh then return end
    self.pendingUsableRefresh = true

    C_Timer.After(0, function()
        AB.pendingUsableRefresh = false
        if AB.UpdateUsableVisuals then
            AB:UpdateUsableVisuals()
        else
            AB:MarkDirty()
            ScheduleDirtyFlush()
        end
    end)
end

AB.pendingStateRefresh = false
AB.pendingCombatStateVisualRefresh = 0

function AB:QueueStateRefresh()
    if self.pendingStateRefresh then return end
    self.pendingStateRefresh = true

    C_Timer.After(0, function()
        AB.pendingStateRefresh = false

        AB:HideBlizzardBars()

        local inCombat = InCombatLockdown()

        if not inCombat and AB.RefreshPageDriver then
            AB:RefreshPageDriver()
        end
        if not inCombat and AB.OnPageChanged then
            AB:OnPageChanged()
        end
        AB:UpdateOverrideVisibility()
        if AB.QueueBar1BindingUpdate then
            AB:QueueBar1BindingUpdate()
        end

        C_Timer.After(0.2, function() AB:QueueHideBlizzardBars(true) end)
        C_Timer.After(0.8, function() AB:QueueHideBlizzardBars(true) end)
    end)
end

function AB:QueueCombatStateVisualRefresh()
    self.pendingCombatStateVisualRefresh = (self.pendingCombatStateVisualRefresh or 0) + 1
    local token = self.pendingCombatStateVisualRefresh

    -- Secure paging has already selected the action.  Repaint on the next
    -- frame instead of adding an artificial 80 ms visual delay; the token
    -- still coalesces event storms from form, vehicle and override changes.
    C_Timer.After(0, function()
        if token ~= AB.pendingCombatStateVisualRefresh then return end
        if not InCombatLockdown() then return end

        if AB.GetEffectivePage then
            local page = AB:GetEffectivePage()
            AB.CurrentPage = page
            if AB.PageDisplay then
                AB.PageDisplay:SetText(page)
            end
        end

        local bar = AB.Bars and AB.Bars.Bar1
        if not bar or not bar.buttons or not AB.UpdateButtonCombatVisuals then return end

        local foreverBar1 = AB.UseForeverPageDriver and AB.UseForeverPageDriver()
        if foreverBar1 and AB.ResolveForeverBar1Slot then
            for _, btn in ipairs(bar.buttons) do
                local slot = AB:ResolveForeverBar1Slot(btn)
                if slot then
                    btn.slot = slot
                    btn.action = slot
                    btn._state_action = slot
                    btn._rexForeverLastSlot = slot
                end
                AB:UpdateButtonCombatVisuals(btn)
                if AB.Cooldowns and AB.Cooldowns.Update then
                    AB.Cooldowns:Update(btn)
                end
            end
            return
        end

        for _, btn in ipairs(bar.buttons) do
            AB:UpdateButtonCombatVisuals(btn)
            -- FIX: Cooldown synchron zum Icon-Refresh aktualisieren, statt ihn
            -- den unabhängig getimten ACTIONBAR_UPDATE_COOLDOWN-Events zu überlassen
            -- (verhindert Zucken durch mehrfache, unkoordinierte Updates beim Formwechsel)
            if AB.Cooldowns and AB.Cooldowns.Update then
                AB.Cooldowns:Update(btn)
            end
        end
    end)
end

AB.frame:RegisterEvent("PLAYER_LOGIN")
AB.frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
AB.frame:RegisterEvent("ACTIONBAR_UPDATE_STATE")
AB.frame:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
AB.frame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
AB.frame:RegisterEvent("BAG_UPDATE")
AB.frame:RegisterEvent("BAG_UPDATE_DELAYED")
AB.frame:RegisterEvent("SPELL_UPDATE_CHARGES")
AB.frame:RegisterUnitEvent("UNIT_AURA", "player")
AB.frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
AB.frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
AB.frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
AB.frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
AB.frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
AB.frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
AB.frame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
AB.frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
AB.frame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
AB.frame:RegisterEvent("UPDATE_BINDINGS")
AB.frame:RegisterEvent("CVAR_UPDATE")
AB.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
AB.frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
AB.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
AB.frame:RegisterEvent("SPELLS_CHANGED")
AB.frame:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
AB.frame:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
AB.frame:RegisterEvent("UPDATE_POSSESS_BAR")
AB.frame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
AB.frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
AB.frame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
AB.frame:RegisterEvent("UPDATE_SHAPESHIFT_USABLE")
AB.frame:RegisterEvent("UNIT_ENTERED_VEHICLE")
AB.frame:RegisterEvent("UNIT_EXITED_VEHICLE")

AB.frame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        AB:Initialize()
        return
    end

    -- Cast-Events und Cooldown brauchen kein volles Button-Update
    if event == "UNIT_SPELLCAST_START"
    or event == "UNIT_SPELLCAST_STOP"
    or event == "UNIT_SPELLCAST_FAILED"
    or event == "UNIT_SPELLCAST_INTERRUPTED"
    or event == "UNIT_SPELLCAST_CHANNEL_START"
    or event == "UNIT_SPELLCAST_CHANNEL_STOP"
    or event == "UNIT_SPELLCAST_DELAYED"
    or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        if AB.UsesLAB then return end
        if AB.Cooldowns then
            if AB.Cooldowns.UpdateAllForCast then
                AB.Cooldowns:UpdateAllForCast()
            elseif AB.Cooldowns.QueueUpdateAll then
                AB.Cooldowns:QueueUpdateAll()
            elseif AB.Cooldowns.UpdateAll then
                AB.Cooldowns:UpdateAll()
            end
        end
        return
    end

    -- Display counts can be driven by player auras (for example DK Bone Shield).
    -- Refresh only the custom count strings instead of rebuilding every button.
    if event == "UNIT_AURA" then
        if AB.QueueDisplayCountRefresh then
            AB:QueueDisplayCountRefresh()
        elseif AB.UpdateDisplayCounts then
            AB:UpdateDisplayCounts()
        end
        return
    end

    if event == "ACTIONBAR_UPDATE_COOLDOWN" then
        if AB.UsesLAB then return end
        if AB.Cooldowns then
            if AB.Cooldowns.QueueUpdateAll then
                AB.Cooldowns:QueueUpdateAll()
            elseif AB.Cooldowns.UpdateAll then
                AB.Cooldowns:UpdateAll()
            end
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        AB:FlushDeferred()
        if AB.ApplyClickRegistration then
            AB:ApplyClickRegistration()
        end
        if AB.ApplySecureCastAttributes then
            AB:ApplySecureCastAttributes()
        end
        if AB.PetBar and AB.PetBar.ApplyClickRegistration then
            AB.PetBar:ApplyClickRegistration()
        end
        if AB.StanceBar and AB.StanceBar.ApplyClickRegistration then
            AB.StanceBar:ApplyClickRegistration()
        end
        AB:MarkDirty()
        ScheduleDirtyFlush()
        if AB.UpdateAllButtonOverlays then
            AB:UpdateAllButtonOverlays()
        end
        if AB.RefreshPageDriver then
            AB:RefreshPageDriver()
        end
        if AB.OnPageChanged then
            AB:OnPageChanged()
        end
        if AB.QueueBar1BindingUpdate then
            AB:QueueBar1BindingUpdate()
        elseif AB.UpdateBar1Bindings then
            AB:UpdateBar1Bindings()
        end
        AB:UpdateOverrideVisibility()
        return
    end

    if event == "UPDATE_BINDINGS" then
        if AB.QueueBar1BindingUpdate then
            AB:QueueBar1BindingUpdate()
        elseif AB.UpdateBar1Bindings then
            AB:UpdateBar1Bindings()
        end
        AB:MarkDirty()
        ScheduleDirtyFlush()
        return
    end

    if event == "ACTIONBAR_PAGE_CHANGED" then
        if InCombatLockdown() then
            AB:QueueCombatStateVisualRefresh()
            return
        end

        if AB.OnPageChanged then
            AB:OnPageChanged()
        end
        if AB.QueueBar1BindingUpdate then
            AB:QueueBar1BindingUpdate()
        end
        if AB.MarkBarDirty then
            AB:MarkBarDirty("Bar1")
        else
            AB:MarkDirty()
        end
        ScheduleDirtyFlush()
        return
    end

    if event == "CVAR_UPDATE" then
        -- CVAR_UPDATE is very noisy.  Click registration only depends on this
        -- one CVar, so do not touch every secure button for unrelated changes.
        if unit == "enableMouseoverCast" then
            if AB.ApplySecureCastAttributes then
                AB:ApplySecureCastAttributes()
            end
            return
        end
        if unit ~= "ActionButtonUseKeyDown" and unit ~= "lockActionBars" then
            return
        end
        if unit == "lockActionBars" then
            if AB.SetActionbarLocked then
                AB:SetActionbarLocked()
            end
            return
        end
        if AB.ApplyClickRegistration then
            AB:ApplyClickRegistration()
        end
        if AB.PetBar and AB.PetBar.ApplyClickRegistration then
            AB.PetBar:ApplyClickRegistration()
        end
        if AB.StanceBar and AB.StanceBar.ApplyClickRegistration then
            AB.StanceBar:ApplyClickRegistration()
        end
        if AB.VehicleBar and AB.VehicleBar.ApplyClickRegistration then
            AB.VehicleBar:ApplyClickRegistration()
        end
        return
    end

    -- Events mit Slot-Parameter: nur den spezifischen Slot markieren
    if event == "ACTIONBAR_UPDATE_USABLE"
    or event == "UNIT_POWER_UPDATE"
    or event == "UNIT_POWER_FREQUENT" then
        local toc = select(4, GetBuildInfo()) or 0
        local forever = toc >= 16000 and toc < 20000
        if AB.UsesLAB and not forever then return end
        if AB.QueueUsableRefresh then
            AB:QueueUsableRefresh()
        else
            AB:MarkDirty(unit)
            ScheduleDirtyFlush()
        end
        return
    end

    if event == "ACTIONBAR_UPDATE_STATE" then
        -- This event changes active/checked state, not button layout or icon
        -- ownership. A full UpdateButton pass made LAB and RexUI repaint the
        -- same icons in quick succession.
        if AB.UpdateActionStateVisuals then
            AB:UpdateActionStateVisuals()
        end
        return
    end

    if event == "ACTIONBAR_SLOT_CHANGED" then
        AB:MarkDirty(unit)
        ScheduleDirtyFlush()
        if AB.Cooldowns then
            if unit and unit ~= 0 and AB.Cooldowns.QueueUpdateSlot then
                AB.Cooldowns:QueueUpdateSlot(unit)
            elseif AB.Cooldowns.QueueUpdateAll then
                AB.Cooldowns:QueueUpdateAll()
            elseif AB.Cooldowns.UpdateAll then
                AB.Cooldowns:UpdateAll()
            end
        end
        return
    end

    local pageChangingEvent =
        event == "UPDATE_BONUS_ACTIONBAR"
        or event == "UPDATE_SHAPESHIFT_FORM"
        or event == "UPDATE_SHAPESHIFT_FORMS"
        or event == "UPDATE_SHAPESHIFT_USABLE"
        or event == "PLAYER_ENTERING_WORLD"

    -- Große State-Änderungen: außerhalb des Kampfes komplett, im Kampf nur Bar1-Visuals.
    if event == "UPDATE_OVERRIDE_ACTIONBAR"
    or event == "UPDATE_VEHICLE_ACTIONBAR"
    or event == "UPDATE_POSSESS_BAR"
    or pageChangingEvent
    or event == "UNIT_ENTERED_VEHICLE"
    or event == "UNIT_EXITED_VEHICLE"
    or event == "SPELLS_CHANGED" then
        if InCombatLockdown() then
            if pageChangingEvent then
                AB:QueueCombatStateVisualRefresh()
            end
            return
        end

        AB:QueueStateRefresh()
        AB:MarkDirty()
        ScheduleDirtyFlush()
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        AB:ApplyLoadedSettings()
        AB:QueueStateRefresh()
        AB:MarkDirty()
        ScheduleDirtyFlush()
        return
    end

    if event == "BAG_UPDATE"
    or event == "BAG_UPDATE_DELAYED"
    or event == "SPELL_UPDATE_CHARGES" then
        if AB.QueueDisplayCountRefresh then
            AB:QueueDisplayCountRefresh()
        elseif AB.UpdateDisplayCounts then
            AB:UpdateDisplayCounts()
        else
            AB:MarkDirty()
            ScheduleDirtyFlush()
        end
        return
    end

    -- Sonstige seltene Ereignisse
    AB:MarkDirty()
    ScheduleDirtyFlush()
end)
