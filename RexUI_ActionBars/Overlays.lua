-- ============================================================
-- RexUI_ActionBars\Overlays.lua
-- Skalierbare Button-Overlays ohne Blizzard-Globals zu killen.
-- ============================================================

local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI

local AB = RexUI and RexUI.ActionBars
if not AB then return end

local LAB = LibStub and LibStub("LibActionButton-1.0-ElvUI", true)
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
local LBG = LibStub and LibStub("LibButtonGlow-1.0", true)
local GetNextCastSpell = C_AssistedCombat and C_AssistedCombat.GetNextCastSpell

local function releasePixelGlow(button)
    if not (LCG and button) then return end

    local glow = button._PixelGlow
    if not glow then
        button.__RexUIPixelGlowPool = nil
        return
    end

    local currentPool = LCG.GlowFramePool
    local ownerPool = button.__RexUIPixelGlowPool
    local pool

    if ownerPool and ownerPool.activeObjects and ownerPool.activeObjects[glow] then
        pool = ownerPool
    elseif currentPool and currentPool.activeObjects and currentPool.activeObjects[glow] then
        pool = currentPool
    end

    if pool then
        pool:Release(glow)
    else
        glow:SetScript("OnUpdate", nil)
        glow:Hide()
        button._PixelGlow = nil
    end

    button.__RexUIPixelGlowPool = nil
end

local function startPixelGlow(button, color)
    if not (LCG and button) then return end

    local glow = button._PixelGlow
    local currentPool = LCG.GlowFramePool
    if glow and currentPool and currentPool.activeObjects
        and not currentPool.activeObjects[glow] then
        releasePixelGlow(button)
    end

    LCG.PixelGlow_Start(button, color, 8, 0.3, nil, 1)
    button.__RexUIPixelGlowPool = LCG.GlowFramePool
end

-- Ergänzt LibCustomGlow um die von der ActionButton-Bibliothek benötigten Helfer.
if LCG and not LCG.ShowOverlayGlow then
    function LCG.ShowOverlayGlow(button, custom)
        local color = custom and custom.color or { 0.95, 0.95, 0, 0.9 }
        startPixelGlow(button, color)
    end

    function LCG.HideOverlayGlow(button)
        releasePixelGlow(button)
    end
end

-- Stellt die Tabellen für den Assisted-Combat-Ablauf bereit.
if LAB then
    LAB.activeAlerts = LAB.activeAlerts or {}
    LAB.activeAssist = LAB.activeAssist or {}
end

local nativeOverlayNames = {
    "ActionStatus",
    "Border",
    "BorderShadow",
    "SpellActivationAlert",
    "NewActionTexture",
    "TargetReticleAnimFrame",
    "AutoCastOverlay",
    "AutoCastable",
    "ProfessionQualityOverlayFrame",
    "TypeIconOverlayFrame",
}

local ASSISTED_POLL_MIN_RATE = 0.12
local assistedRotationSpells = {}
local assistedManagerInstalled = false
local refreshAssistedCombatFromBlizzard
local installNativeSpellAlertCompatibility
local hideNativeFrame
local ASSIST_NEXT_COLOR = { 0.20, 0.60, 0.95, 0.90 }
local ASSIST_ALTERNATIVE_COLOR = { 0.40, 0.99, 0.20, 0.90 }
local SUPPRESSED_PROC_GLOW_SPELLS = {
    [136] = true, -- Mend Pet
    [982] = true, -- Revive Pet
}

local function hideLibButtonGlowInstant(btn)
    local overlay = btn and btn.__LBGoverlay
    if not overlay then return end

    if overlay.animIn and overlay.animIn:IsPlaying() then
        overlay.animIn:Stop()
    end

    if overlay.animOut and overlay.animOut:IsPlaying() then
        overlay.animOut:Stop()
    end

    overlay:SetAlpha(0)
    overlay:Hide()
    btn.__LBGoverlay = nil
end

local function isItemActionButton(btn)
    if not (btn and GetActionInfo) then return false end

    local slot = AB.GetButtonActionSlot and AB.GetButtonActionSlot(btn)
        or btn.slot
        or (btn.GetAttribute and btn:GetAttribute("action"))
    if not slot then return false end

    local ok, actionType = pcall(GetActionInfo, slot)
    return ok and actionType == "item"
end

local function suppressItemAssistedFrame(btn, frame)
    if not frame then return end

    if not frame.__RexUIItemAssistSuppressed then
        frame.__RexUIItemAssistSuppressed = true
        frame:HookScript("OnShow", function(self)
            if not isItemActionButton(btn) then
                if self.SetAlpha then self:SetAlpha(1) end
                return
            end
            if self.__RexUIItemAssistHiding then return end
            self.__RexUIItemAssistHiding = true
            if self.SetAlpha then self:SetAlpha(0) end
            self:Hide()
            self.__RexUIItemAssistHiding = nil
        end)
    end

    if frame.SetAlpha then pcall(frame.SetAlpha, frame, 0) end
    if frame.Hide then pcall(frame.Hide, frame) end
end

local function suppressItemAssistedFrames(btn)
    suppressItemAssistedFrame(btn, btn and btn.AssistedCombatHighlightFrame)
    suppressItemAssistedFrame(btn, btn and btn.AssistedCombatRotationFrame)
end

local function setAssistOverlayGlow(btn, active, color)
    if not btn then return end

    -- Keine grüne alternative Empfehlung für Schmuckstücke/Gegenstände.
    if isItemActionButton(btn) then
        suppressItemAssistedFrames(btn)
        if color == ASSIST_ALTERNATIVE_COLOR then
            active = false
            color = nil
        end
    end

    local resolvedColor = active and (color or ASSIST_NEXT_COLOR) or nil
    if btn.__rexAssistGlowActive == (active == true)
        and btn.__rexAssistGlowColor == resolvedColor
        and ((active and btn._PixelGlow) or (not active and not btn._PixelGlow)) then
        return
    end

    btn.__rexAssistGlowActive = active == true
    btn.__rexAssistGlowColor = resolvedColor

    if LCG then
        hideLibButtonGlowInstant(btn)

        if active then
            startPixelGlow(btn, resolvedColor)
        else
            releasePixelGlow(btn)
        end
    elseif LBG then
        if active then
            LBG.ShowOverlayGlow(btn)
        else
            LBG.HideOverlayGlow(btn)
        end
    elseif ActionButton_ShowOverlayGlow and ActionButton_HideOverlayGlow then
        if active then
            ActionButton_ShowOverlayGlow(btn)
        else
            ActionButton_HideOverlayGlow(btn)
        end
    end
end

local function updateCombatOverlayVisuals(btn, cfg)
    if not btn or not cfg then return end

    for _, regionName in ipairs({
        "ActionStatus",
        "Border",
        "BorderShadow",
        "CheckedTexture",
        "HighlightTexture",
        "NewActionTexture",
        "Flash",
        "AutoCastable",
    }) do
        hideNativeFrame(btn[regionName])
    end

    if btn.GetCheckedTexture then
        local ok, texture = pcall(btn.GetCheckedTexture, btn)
        if ok and texture then
            hideNativeFrame(texture)
        end
    end

    local showProcGlow = cfg.showProcGlow ~= false
    local showAssisted = cfg.showAssistedCombat ~= false
    local procActive = showProcGlow and btn.rexProcActive == true
    local assistActive = showAssisted and btn.rexAssistActive == true

    if btn.rexFills then
        if btn.rexFills.proc then
            btn.rexFills.proc:Hide()
        end
        if btn.rexFills.assist then
            btn.rexFills.assist:Hide()
        end
    end

    if btn.rexOverlays then
        if btn.rexOverlays.procGlow then
            btn.rexOverlays.procGlow:Hide()
        end
        if btn.rexOverlays.assistGlow then
            btn.rexOverlays.assistGlow:Hide()
        end
    end

    if btn.rexProcMarching then
        btn.rexProcMarching:Hide()
    end

    if btn.rexAssistMarching then
        btn.rexAssistMarching:Hide()
    end

    local assistColor = btn.rexAssistAlternative and ASSIST_ALTERNATIVE_COLOR or ASSIST_NEXT_COLOR
    setAssistOverlayGlow(btn, procActive or assistActive, assistActive and assistColor or nil)
end

local function isRexActionButton(btn)
    return btn and (
        btn.rexBarKey
        or btn.stanceIndex
        or btn.petIndex
        or btn:GetName() and string.match(btn:GetName(), "^RexUI_")
    )
end

hideNativeFrame = function(frame)
    if not frame then return end
    if frame._rexNativeHidden
    and (not frame.IsShown or not frame:IsShown()) then
        return
    end

    if frame.SetAlpha then pcall(frame.SetAlpha, frame, 0) end
    if frame.Hide then pcall(frame.Hide, frame) end
    if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end

    if frame.GetRegions then
        for i = 1, frame:GetNumRegions() do
            local region = select(i, frame:GetRegions())
            if region then
                if region.SetAlpha then pcall(region.SetAlpha, region, 0) end
                if region.Hide then pcall(region.Hide, region) end
            end
        end
    end

    if frame.GetChildren then
        for i = 1, frame:GetNumChildren() do
            hideNativeFrame(select(i, frame:GetChildren()))
        end
    end

    frame._rexNativeHidden = true
end

local function scaleAssistedCombatFrames(btn)
    if not btn then return end

    local width = btn.GetWidth and btn:GetWidth() or 45
    local scale = (width and width > 0 and width or 45) / 45

    if btn.AssistedCombatHighlightFrame then
        btn.AssistedCombatHighlightFrame:SetScale(scale)
    end

    if btn.AssistedCombatRotationFrame then
        btn.AssistedCombatRotationFrame:SetScale(scale)
    end
end

local function isHiddenNativeOverrideButton(btn)
    local name = btn and btn.GetName and btn:GetName()
    return name and (
        string.match(name, "^OverrideActionBarButton%d+$")
        or string.match(name, "^PossessButton%d+$")
    )
end

local function ensureHiddenNativeAssistedCombatFrame(btn)
    -- Do not create or hook children on Blizzard override/possess buttons.
    -- Those buttons are protected and owned by ActionBarController.
end

local function ensureHiddenNativeAssistedCombatFrames()
    -- See ensureHiddenNativeAssistedCombatFrame.
end

installNativeSpellAlertCompatibility = function()
    -- Keep Blizzard's spell-alert manager unmodified to avoid tainting native
    -- protected action buttons during override/vehicle transitions.
end

local function hookAssistedCombatRotationFrame(btn)
    if not btn or btn._rexAssistRotationHooked then return end
    if not btn.UpdateAssistedCombatRotationFrame or not hooksecurefunc then return end

    btn._rexAssistRotationHooked = true
    hooksecurefunc(btn, "UpdateAssistedCombatRotationFrame", function(self)
        scaleAssistedCombatFrames(self)
    end)
end

local function getButtonSpellID(btn)
    if not btn then return nil end

    if btn.GetSpellId then
        local ok, spellID = pcall(btn.GetSpellId, btn)
        if ok and spellID then
            return spellID
        end
    end

    if btn.spellID then
        return btn.spellID
    end

    local slot = AB.GetButtonActionSlot and AB:GetButtonActionSlot(btn) or btn.slot
    if not slot or not HasAction(slot) then return nil end

    local actionType, id = GetActionInfo(slot)
    if actionType == "spell" then
        return id
    end

    if actionType == "macro" and GetMacroSpell then
        return GetMacroSpell(id)
    end
end

local function rebuildAssistedRotationSpells()
    wipe(assistedRotationSpells)

    if AssistedCombatManager and AssistedCombatManager.rotationSpells then
        local foundSpells = false
        for spellID, active in pairs(AssistedCombatManager.rotationSpells) do
            if active then
                assistedRotationSpells[spellID] = true
                foundSpells = true
            end
        end

        if foundSpells then
            return
        end
    end

    if not C_AssistedCombat or not C_AssistedCombat.GetRotationSpells then
        return
    end

    local ok, spells = pcall(C_AssistedCombat.GetRotationSpells)
    if not ok or not spells then
        return
    end

    for _, spellID in ipairs(spells) do
        assistedRotationSpells[spellID] = true
    end
end

local function getButtonAssistedSpellID(btn)
    local id = getButtonSpellID(btn)
    if not id then return nil end

    if AssistedCombatManager and AssistedCombatManager.IsRotationSpell then
        local ok, isRotationSpell = pcall(
            AssistedCombatManager.IsRotationSpell,
            AssistedCombatManager,
            id
        )
        if ok and isRotationSpell then
            return id
        end
    end

    return assistedRotationSpells[id] and id or nil
end
local function isAssistedCombatActionButton(btn)
    if not btn then return false end

    local slot = AB.GetButtonActionSlot and AB:GetButtonActionSlot(btn) or btn.slot
    if not slot then return false end

    local hasActionAPI = C_ActionBar and C_ActionBar.HasAction or HasAction
    if not hasActionAPI or not hasActionAPI(slot) then return false end

    if C_ActionBar and C_ActionBar.IsAssistedCombatAction then
        local ok, isAssist = pcall(C_ActionBar.IsAssistedCombatAction, slot)
        if ok then
            return isAssist == true
        end
    end

    local actionType, _, subType = GetActionInfo(slot)
    return actionType == "spell" and subType == "assistedcombat"
end

local function forEachRexActionButton(callback)
    local seen = {}

    for _, bar in pairs(AB.Bars or {}) do
        for _, btn in ipairs(bar.buttons or {}) do
            if btn and not seen[btn] then
                seen[btn] = true
                callback(btn)
            end
        end
    end

    for _, btn in pairs(AB.Buttons or {}) do
        if btn and not seen[btn] then
            seen[btn] = true
            callback(btn)
        end
    end
end

local function hasAssistedCombatActionButton()
    local found = false
    forEachRexActionButton(function(btn)
        if isAssistedCombatActionButton(btn) then
            found = true
        end
    end)

    return found
end

local function hideNativeQualityOverlay(btn)
    if not btn then return end

    local overlay = btn.ProfessionQualityOverlayFrame
    if overlay then
        hideNativeFrame(overlay)

        if not overlay._rexQualitySuppressed then
            overlay._rexQualitySuppressed = true
            overlay:HookScript("OnShow", function(self)
                hideNativeFrame(self)
            end)
        end
    end

    if btn.TypeIconOverlayFrame then
        hideNativeFrame(btn.TypeIconOverlayFrame)
    end
end

local function hideAllNativeQualityOverlays()
    forEachRexActionButton(hideNativeQualityOverlay)
end

function AB:AssistedUpdate(nextSpell)
    if not LAB or not LAB.activeButtons or not _G.AssistedCombatManager then return end

    -- Direkt über die aktiven LAB-Buttons gehen, die Spell-ID am Button lesen
    -- und den Blizzard-Manager abfragen.
    for button in next, LAB.activeButtons do
        if isRexActionButton(button) then
            local spellID = button:GetSpellId()
            local nextcast = spellID and spellID == nextSpell
            local alertActive = spellID and LAB.activeAlerts[spellID]

            if (nextcast or alertActive)
                and _G.AssistedCombatManager:IsRotationSpell(spellID) then
                button.rexAssistActive = true
                button.rexAssistAlternative = alertActive and not nextcast or false
                setAssistOverlayGlow(
                    button,
                    true,
                    nextcast and ASSIST_NEXT_COLOR or ASSIST_ALTERNATIVE_COLOR
                )
                LAB.activeAssist[spellID] = true
            elseif spellID and not alertActive then
                button.rexAssistActive = false
                button.rexAssistAlternative = false
                setAssistOverlayGlow(button, button.rexProcActive == true, nil)
                if LAB.activeAssist[spellID] then
                    LAB.activeAssist[spellID] = nil
                end
            end
        end
    end
end

local function isAssistedCombatActive()
    if GetCVarBool and GetCVarBool("assistedCombatHighlight") then
        return true
    end

    if C_ActionBar and C_ActionBar.HasAssistedCombatActionButtons then
        local ok, hasButtons = pcall(C_ActionBar.HasAssistedCombatActionButtons)
        return ok and hasButtons == true
    end

    return false
end

local function suppressNativeOverlay(btn, name)
    local frame = btn and btn[name]
    if not frame then return end

    btn.rexOverlayStates = btn.rexOverlayStates or {}

    if not frame._rexSuppressed then
        frame._rexSuppressed = true

        frame:HookScript("OnShow", function(self)
            btn.rexOverlayStates[name] = true
            self._rexSuppressing = true
            hideNativeFrame(self)
            self._rexSuppressing = nil

            C_Timer.After(0, function()
                if AB.UpdateButtonOverlays then
                    local cfg = btn.rexBarKey and AB:GetConfig(btn.rexBarKey) or AB:GetConfig("Defaults")
                    AB:UpdateButtonOverlays(btn, cfg)
                end
            end)
        end)

        frame:HookScript("OnHide", function(self)
            if self._rexSuppressing then return end

            btn.rexOverlayStates[name] = false
            C_Timer.After(0, function()
                if AB.UpdateButtonOverlays then
                    local cfg = btn.rexBarKey and AB:GetConfig(btn.rexBarKey) or AB:GetConfig("Defaults")
                    AB:UpdateButtonOverlays(btn, cfg)
                end
            end)
        end)
    end

    if frame.IsShown and frame:IsShown() then
        btn.rexOverlayStates[name] = true
        frame._rexSuppressing = true
        hideNativeFrame(frame)
        frame._rexSuppressing = nil
    else
        hideNativeFrame(frame)
    end
end

function AB:RefreshAssistedCombatOverlays(force)
    refreshAssistedCombatFromBlizzard(force)
end

function AB:UpdateButtonOverlays(btn, cfg)
    if not btn or not cfg then return end
    if InCombatLockdown and InCombatLockdown() then
        updateCombatOverlayVisuals(btn, cfg)
        return
    end

    local inset = cfg.overlayInset or -6
    local showProcGlow = cfg.showProcGlow ~= false
    local showAssisted = cfg.showAssistedCombat ~= false
    local showNewAction = cfg.showNewAction ~= false
    local spellID = getButtonSpellID(btn)

    if spellID and SUPPRESSED_PROC_GLOW_SPELLS[spellID] then
        btn.rexProcActive = false
    end

    for _, regionName in ipairs({
        "ActionStatus",
        "Border",
        "BorderShadow",
        "SpellHighlightTexture",
        "HighlightTexture",
        "CheckedTexture",
        "NewActionTexture",
        "Flash",
        "AutoCastable",
        "ProfessionQualityOverlayFrame",
        "TypeIconOverlayFrame",
    }) do
        hideNativeFrame(btn[regionName])
    end

    hideNativeQualityOverlay(btn)

    if btn.GetCheckedTexture then
        local ok, texture = pcall(btn.GetCheckedTexture, btn)
        if ok and texture then
            hideNativeFrame(texture)
        end
    end

    if btn.Flash then
        btn.Flash:SetTexture(nil)
    end

    if C_SpellActivationOverlay
        and C_SpellActivationOverlay.IsSpellOverlayed
        and spellID then
        local alertActive = C_SpellActivationOverlay.IsSpellOverlayed(spellID) == true
        local isAssistRotation = getButtonAssistedSpellID(btn) ~= nil
        btn.rexProcActive = alertActive and not isAssistRotation
        if not (alertActive and isAssistRotation and btn.rexAssistActive) then
            btn.rexAssistAlternative = false
        end
    end

    for _, name in ipairs(nativeOverlayNames) do
        suppressNativeOverlay(btn, name)
    end
    scaleAssistedCombatFrames(btn)
    hookAssistedCombatRotationFrame(btn)

    local procActive = showProcGlow and btn.rexProcActive == true
    local assistActive = showAssisted and btn.rexAssistActive == true

    if btn.rexOverlays and btn.rexOverlays.proc then
        btn.rexOverlays.proc:Hide()
    end

    if btn.rexButtonSwipe then
        btn.rexButtonSwipe:Hide()
    end

    local procMarching = btn.rexProcMarching
    if procMarching then
        procMarching:Hide()
    end

    -- Hide frames from older builds so the pixel glow stays the only assist cue.
    if btn.rexOverlays and btn.rexOverlays.assist then
        btn.rexOverlays.assist:Hide()
    end

    if btn.rexAssistSwipe then
        btn.rexAssistSwipe:Hide()
    end

    local assistMarching = btn.rexAssistMarching
    if assistMarching then
        assistMarching:Hide()
    end

    local assistColor = btn.rexAssistAlternative and ASSIST_ALTERNATIVE_COLOR or ASSIST_NEXT_COLOR
    setAssistOverlayGlow(btn, procActive or assistActive, assistActive and assistColor or nil)
end

function AB:UpdateAllButtonOverlays()
    forEachRexActionButton(function(btn)
        local cfg = btn.rexBarKey and AB:GetConfig(btn.rexBarKey) or AB:GetConfig("Defaults")
        AB:UpdateButtonOverlays(btn, cfg)
    end)
end

local function setProcState(spellID, active)
    if not spellID then return end

    if SUPPRESSED_PROC_GLOW_SPELLS[spellID] then
        active = false
    end

    if LAB and LAB.activeAlerts then
        LAB.activeAlerts[spellID] = active == true or nil
    end

    for _, btn in pairs(AB.Buttons or {}) do
        local btnSpellID = getButtonSpellID(btn)
        if btnSpellID == spellID then
            local isAssistRotation = getButtonAssistedSpellID(btn) ~= nil
            btn.rexProcActive = active == true and not isAssistRotation
            btn.rexAssistAlternative = false
            local cfg = btn.rexBarKey and AB:GetConfig(btn.rexBarKey) or AB:GetConfig("Defaults")
            AB:UpdateButtonOverlays(btn, cfg)
        end
    end
end

function AB:GetUpdateRate()
    local rate = ASSISTED_POLL_MIN_RATE

    if AssistedCombatManager and AssistedCombatManager.GetUpdateRate then
        rate = AssistedCombatManager:GetUpdateRate() or rate
    elseif GetCVar then
        rate = tonumber(GetCVar("assistedCombatIconUpdateRate")) or rate
    end

    return math.max(ASSISTED_POLL_MIN_RATE, math.min(rate, 1))
end

function AB:AssistedOnUpdate(elapsed)
    self.updateTimeLeft = self.updateTimeLeft - elapsed

    if self.updateTimeLeft <= 0 then
        self.updateTimeLeft = self:GetUpdateRate()

        local checkForVisibleButton = false
        local spellID = GetNextCastSpell(checkForVisibleButton)

        if spellID ~= self.lastNextCastSpellID then
            self.lastNextCastSpellID = spellID
            self:UpdateAllAssistedHighlightFramesForSpell(spellID)
        else
            -- Auch bei unveränderter Spell-ID neu prüfen: Nach Benutzung eines
            -- Schmuckstücks ändert sich nur dessen Zustand/Cooldown.
            AB:AssistedUpdate(spellID)
        end
    end
end

function AB:RotationUpdate()
    if _G.AssistedCombatManager then
        _G.AssistedCombatManager:ForceUpdateAtEndOfFrame()
    end
end

local function installAssistedCombatManager()
    local manager = _G.AssistedCombatManager
    if not manager or not GetNextCastSpell then return false end
    if not manager.UpdateAllAssistedHighlightFramesForSpell or not hooksecurefunc then return false end

    if not assistedManagerInstalled then
        -- Post-Hook, Rotation-Callback und Austausch der OnUpdate-Funktion
        -- des Blizzard-Managers.
        hooksecurefunc(manager, "UpdateAllAssistedHighlightFramesForSpell", AB.AssistedUpdate)
        if _G.EventRegistry then
            _G.EventRegistry:RegisterCallback(
                "AssistedCombatManager.RotationSpellsUpdated",
                AB.RotationUpdate
            )
        end
        assistedManagerInstalled = true
    end

    manager.OnUpdate = AB.AssistedOnUpdate
    manager:ForceUpdateAtEndOfFrame()
    AB:AssistedUpdate(manager.lastNextCastSpellID)
    return true
end

function refreshAssistedCombatFromBlizzard(force)
    installAssistedCombatManager()

    local manager = _G.AssistedCombatManager
    if not manager or not assistedManagerInstalled then return end

    if force then
        manager:ForceUpdateAtEndOfFrame()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
eventFrame:RegisterEvent("CVAR_UPDATE")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
installNativeSpellAlertCompatibility()
ensureHiddenNativeAssistedCombatFrames()

if C_Timer then
    C_Timer.After(0, function()
        installNativeSpellAlertCompatibility()
        ensureHiddenNativeAssistedCombatFrames()
    end)
end

local function ensureAssistedPoll()
    -- Kompatibilitätsname für bestehende Aufrufer. Seit WoW 12.1 übernimmt
    -- ausschließlich der Blizzard-Manager das Polling.
    installAssistedCombatManager()
end

local function refreshAssistedCombatSoon(force)
    if C_Timer then
        C_Timer.After(0, function()
            rebuildAssistedRotationSpells()
            ensureAssistedPoll()
            refreshAssistedCombatFromBlizzard(force)
        end)
    else
        rebuildAssistedRotationSpells()
        ensureAssistedPoll()
        refreshAssistedCombatFromBlizzard(force)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_ActionBar" or arg1 == AddOnName then
            installNativeSpellAlertCompatibility()
            ensureHiddenNativeAssistedCombatFrames()
            refreshAssistedCombatSoon(true)
        end
        return
    end

    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        setProcState(arg1, event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
        refreshAssistedCombatFromBlizzard()
        return
    end

    if event == "SPELLS_CHANGED"
    or event == "PLAYER_ENTERING_WORLD"
    or event == "PLAYER_SPECIALIZATION_CHANGED"
    or event == "ACTIVE_TALENT_GROUP_CHANGED"
    or event == "CVAR_UPDATE" then
        installNativeSpellAlertCompatibility()
        ensureHiddenNativeAssistedCombatFrames()
        rebuildAssistedRotationSpells()
        ensureAssistedPoll()
        refreshAssistedCombatSoon(true)
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        ensureAssistedPoll()
        refreshAssistedCombatFromBlizzard()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        ensureAssistedPoll()
        refreshAssistedCombatFromBlizzard()
        return
    end

    if event == "ACTIONBAR_SLOT_CHANGED" then
        if C_Timer then
            C_Timer.After(0, function()
                ensureHiddenNativeAssistedCombatFrames()
                hideAllNativeQualityOverlays()
                refreshAssistedCombatSoon(true)
            end)
        else
            ensureHiddenNativeAssistedCombatFrames()
            hideAllNativeQualityOverlays()
            refreshAssistedCombatSoon(true)
        end
        return
    end

    ensureAssistedPoll()
    refreshAssistedCombatFromBlizzard(event == "ACTIONBAR_SLOT_CHANGED")
end)

ensureAssistedPoll()
