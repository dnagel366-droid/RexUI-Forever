-- ============================================================
-- RexUI_ActionBars\Cooldowns.lua
-- FX/Cooldown Manager fuer RexUI ActionButtons.
-- ============================================================

local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI

local AB = RexUI and RexUI.ActionBars
if not AB then return end

AB.Cooldowns = AB.Cooldowns or {}
local CD = AB.Cooldowns
local COOLDOWN_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local COOLDOWN_FONT_SIZE = 11
local EDGE_R, EDGE_G, EDGE_B, EDGE_A = 0.82, 0.86, 0.90, 0.85

local function getSpellName(spellID)
    if not spellID then return nil end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        return info and info.name
    end

    if GetSpellInfo then
        return GetSpellInfo(spellID)
    end
end

local function getItemName(itemID)
    if not itemID then return nil end

    if C_Item and C_Item.GetItemInfo then
        local itemName = C_Item.GetItemInfo(itemID)
        return itemName
    end

    if GetItemInfo then
        return GetItemInfo(itemID)
    end
end

local function getActionSpell(slot)
    if C_ActionBar and C_ActionBar.GetSpell then
        local ok, spellID = pcall(C_ActionBar.GetSpell, slot)
        if ok and spellID then return spellID end
    end

    if GetActionSpell then
        local ok, spellID = pcall(GetActionSpell, slot)
        if ok and spellID then return spellID end
    end
end

local function actionHasMountName(id, castName)
    if not id or not castName or not C_MountJournal then return false end

    if C_MountJournal.GetMountInfoByID then
        local ok, name, spellID = pcall(C_MountJournal.GetMountInfoByID, id)
        if ok and name == castName then return true end
    end

    if C_MountJournal.GetMountInfoBySpellID then
        local ok, name = pcall(C_MountJournal.GetMountInfoBySpellID, id)
        if ok and name == castName then return true end
    end

    return false
end
local function getActiveCastInfo()
    local name, _, _, startMS, endMS, _, _, _, spellID = UnitCastingInfo("player")
    if not name then
        name, _, _, startMS, endMS, _, _, spellID = UnitChannelInfo("player")
    end

    if not name or not startMS or not endMS or endMS <= startMS then
        return nil
    end

    return name, startMS / 1000, (endMS - startMS) / 1000, spellID
end

local function actionMatchesCast(slot, castName, castSpellID)
    if not slot or not castName then return false end

    local actionSpell = getActionSpell(slot)
    if actionSpell then
        if castSpellID and actionSpell == castSpellID then return true end
        if getSpellName(actionSpell) == castName then return true end
        if actionHasMountName(actionSpell, castName) then return true end
    end

    local actionType, id, subType = GetActionInfo(slot)
    if actionType == "spell" then
        if castSpellID and id == castSpellID then return true end
        if getSpellName(id) == castName then return true end
        return actionHasMountName(id, castName)
    elseif actionType == "item" then
        return getItemName(id) == castName
    elseif actionType == "macro" then
        if GetMacroSpell then
            local macroSpell = GetMacroSpell(id)
            if macroSpell then
                if castSpellID and macroSpell == castSpellID then return true end
                if getSpellName(macroSpell) == castName then return true end
                if actionHasMountName(macroSpell, castName) then return true end
            end
        end

        if GetMacroItem then
            local macroItem = GetMacroItem(id)
            if macroItem and getItemName(macroItem) == castName then
                return true
            end
        end
    elseif actionType == "companion" or actionType == "mount" then
        if castSpellID and id == castSpellID then return true end
        if getSpellName(id) == castName then return true end
        return actionHasMountName(id, castName)
    end

    local actionText = GetActionText and GetActionText(slot)
    return actionText == castName
end

function CD:UpdateAllForCast()
    local castName, castStart, castDuration, castSpellID = getActiveCastInfo()
    if not castName then
        -- A cast just ended/cancelled.  Let the normal cooldown API provide
        -- the authoritative post-cast state; never synthesize one from a
        -- spell's tooltip cast time.
        if self.QueueUpdateAll then
            self:QueueUpdateAll()
        else
            self:UpdateAll()
        end
        return
    end

    local seen = {}
    local matched = false
    local hadBarButtons = false

    local function updateCastButton(btn)
        if btn and not seen[btn] then
            seen[btn] = true
            local isMatch = self:StartActionCast(btn, castName, castStart, castDuration, castSpellID)
            if not isMatch then
                self:StopActionCastPulse(btn)
            end
            matched = isMatch or matched
        end
    end

    for _, bar in pairs(AB.Bars or {}) do
        for _, btn in ipairs(bar.buttons or {}) do
            hadBarButtons = true
            updateCastButton(btn)
        end
    end

    if not hadBarButtons then
        for _, btn in pairs(AB.Buttons or {}) do
            updateCastButton(btn)
        end
    end

    if matched then
        return
    end

    if self.QueueUpdateAll then
        self:QueueUpdateAll()
    elseif not matched then
        self:UpdateAll()
    end
end

local function getCooldownInfo(slot)
    if C_ActionBar and C_ActionBar.GetActionCooldown then
        local ok, info = pcall(C_ActionBar.GetActionCooldown, slot)
        if ok then
            return info
        end
    end

    if GetActionCooldown then
        local ok, startTime, duration, isActive, modRate = pcall(GetActionCooldown, slot)
        if ok then
            return {
                startTime = startTime,
                duration = duration,
                isActive = isActive,
                modRate = modRate,
            }
        end
    end
end

local function getChargeInfo(slot)
    if C_ActionBar and C_ActionBar.GetActionCharges then
        local ok, info = pcall(C_ActionBar.GetActionCharges, slot)
        if ok then
            return info
        end
    end
end

local function getDurationObject(btn, slot, charge)
    local method = charge and btn.GetChargeDuration or btn.GetCooldownDuration
    if method then
        local ok, durationObject = pcall(method, btn)
        if ok and durationObject then return durationObject end
    end

    local api = C_ActionBar and (charge and C_ActionBar.GetActionChargeDuration or C_ActionBar.GetActionCooldownDuration)
    if api then
        local ok, durationObject = pcall(api, slot)
        if ok then return durationObject end
    end
end

local function clearCooldown(cooldown)
    if not cooldown then return end

    if not cooldown.rexLastCooldownKey
    and cooldown.rexSwipeShown == false
    and cooldown.rexBlingShown == false then
        return
    end

    cooldown.rexLastCooldownKey = nil
    cooldown.rexSwipeShown = false
    cooldown.rexBlingShown = false

    if cooldown.SetDrawSwipe then
        pcall(cooldown.SetDrawSwipe, cooldown, false)
    end
    if cooldown.SetDrawBling then
        pcall(cooldown.SetDrawBling, cooldown, false)
    end

    if cooldown.Clear then
        pcall(cooldown.Clear, cooldown)
    else
        pcall(cooldown.SetCooldown, cooldown, 0, 0)
    end
end

function CD:ClearButton(btn)
    if not btn then return end
    clearCooldown(btn.cooldown)
    clearCooldown(btn.chargeCooldown)
    self:StopActionCastPulse(btn)
end

function CD:SetActionCastEdge(btn, active)
    local cooldown = btn and btn.cooldown
    if not cooldown then return end

    if active then
        if cooldown.rexCastEdgeActive then return end
        cooldown.rexCastEdgeActive = true

        -- Native CooldownFrame route: the edge travels
        -- with the swipe, instead of adding a separate frame above the icon.
        cooldown:SetDrawEdge(true)
        cooldown:SetDrawSwipe(true)
        cooldown:SetDrawBling(false)
        if cooldown.SetEdgeTexture then
            cooldown:SetEdgeTexture((AB.Media and AB.Media.edge) or "Interface\\Cooldown\\star4")
        end
        if cooldown.SetEdgeColor then
            cooldown:SetEdgeColor(EDGE_R, EDGE_G, EDGE_B, EDGE_A)
        end
        cooldown:SetSwipeColor(0, 0, 0, 0.66)
        return
    end

    if not cooldown.rexCastEdgeActive then return end
    cooldown.rexCastEdgeActive = nil

    local cfg = btn.rexBarKey and AB:GetConfig(btn.rexBarKey) or AB:GetConfig("Defaults")
    cooldown:SetDrawEdge(cfg.showCooldownEdge == true)
    if cooldown.SetEdgeColor then
        cooldown:SetEdgeColor(EDGE_R, EDGE_G, EDGE_B, EDGE_A)
    end
    cooldown:SetDrawSwipe(cfg.showCooldownSwipe ~= false)
    cooldown:SetDrawBling(cfg.showCooldownSwipe ~= false)
    cooldown:SetSwipeColor(0, 0, 0, cfg.cooldownSwipeAlpha or 0.80)
end

function CD:ShowActionCastPulse(btn)
    -- Kept as the existing call site; the visual is now the native edge.
    self:SetActionCastEdge(btn, true)
end

function CD:StopActionCastPulse(btn)
    self:SetActionCastEdge(btn, false)
end

local function setCooldownSwipe(cooldown, shown, bling)
    if not cooldown then return end

    shown = shown == true
    bling = bling == true

    if cooldown.SetDrawSwipe and cooldown.rexSwipeShown ~= shown then
        cooldown.rexSwipeShown = shown
        pcall(cooldown.SetDrawSwipe, cooldown, shown == true)
    end
    if cooldown.SetDrawBling and cooldown.rexBlingShown ~= bling then
        cooldown.rexBlingShown = bling
        pcall(cooldown.SetDrawBling, cooldown, bling == true)
    end
end

-- FIX: Wiederholtes SetCooldown mit identischen Start/Dauer-Werten laesst
-- die Cooldown-Zahl "zucken", weil Blizzard den Zahlen-Tick intern
-- zuruecksetzt. Nur wirklich aufrufen, wenn sich was geaendert hat.
local function getCooldownKey(start, duration, modRate)
    local ok, key = pcall(function()
        return tostring(start) .. ":" .. tostring(duration) .. ":" .. tostring(modRate or 1)
    end)

    if ok then return key end
end

local function applyCooldown(cooldown, start, duration, modRate)
    if not cooldown then return false end

    local key = getCooldownKey(start, duration, modRate)
    if key and cooldown.rexLastCooldownKey == key then
        return true
    end

    -- Retail's CooldownFrame accepts modRate.  Omitting it causes the visual
    -- countdown to drift for haste/time-rate modified cooldowns.
    local ok = pcall(cooldown.SetCooldown, cooldown, start, duration, modRate or 1)
    if ok then
        cooldown.rexLastCooldownKey = key
    end
    return ok
end

local function applyDurationObject(cooldown, durationObject)
    if not cooldown or not durationObject or not cooldown.SetCooldownFromDurationObject then
        return false
    end

    local ok = pcall(cooldown.SetCooldownFromDurationObject, cooldown, durationObject)
    if ok then
        cooldown.rexLastCooldownKey = nil
    end
    return ok
end

local function styleCooldownFont(region)
    if not region or not region.SetFont then return end
    if region.rexCooldownFontStyled then return end

    local ok, font = pcall(region.GetFont, region)
    if ok then
        pcall(region.SetFont, region, font or COOLDOWN_FONT, COOLDOWN_FONT_SIZE, "OUTLINE")
    end
    if region.SetTextColor then
        pcall(region.SetTextColor, region, 1, 1, 1, 1)
    end
    if region.SetShadowColor then
        pcall(region.SetShadowColor, region, 0, 0, 0, 1)
    end
    if region.SetShadowOffset then
        pcall(region.SetShadowOffset, region, 1, -1)
    end

    region.rexCooldownFontStyled = true

end

local function styleCooldownTextRegions(frame, depth)
    if not frame or (depth or 0) > 3 then return end

    if frame.GetRegions then
        for i = 1, frame:GetNumRegions() do
            styleCooldownFont(select(i, frame:GetRegions()))
        end
    end

    if frame.GetChildren then
        for i = 1, frame:GetNumChildren() do
            styleCooldownTextRegions(select(i, frame:GetChildren()), (depth or 0) + 1)
        end
    end
end

local function styleBlizzardCooldownText(cooldown, hidden)
    if not cooldown then return end

    cooldown.noCooldownCount = true
    cooldown.noOCC = true

    -- FIX: gleicher Wert erneut an SetHideCountdownNumbers laesst Blizzard
    -- die Zahl intern zuruecksetzen -> sichtbares Zucken bei jedem Update.
    local hiddenState = (hidden == true)
    if cooldown.rexHiddenState == hiddenState then
        return
    end
    cooldown.rexHiddenState = hiddenState

    if cooldown.SetHideCountdownNumbers then
        pcall(cooldown.SetHideCountdownNumbers, cooldown, hidden == true)
    end

    if not hidden then
        styleCooldownTextRegions(cooldown)
    end
end

local function styleButtonCooldownText(btn)
    if not btn then return end

    local hidden = btn.rexShowCooldownText == false
    styleBlizzardCooldownText(btn.cooldown, hidden)
    styleBlizzardCooldownText(btn.chargeCooldown, hidden)
end

local function hasPlainDuration(info)
    if not info or not info.duration or not info.startTime then return false end

    local ok, active = pcall(function()
        return info.duration > 0
    end)

    return ok and active == true
end

local function isActiveCooldown(info)
    if not info then return false end
    if info.isActive == true then return true end
    return hasPlainDuration(info)
end

function CD:Create(btn)
    if not btn then return end
    if btn.rexShowCooldownText == nil then
        btn.rexShowCooldownText = true
    end

    local cd = btn.cooldown
    if cd then
        cd:ClearAllPoints()
        cd:SetAllPoints(btn.icon or btn)
        cd:SetDrawEdge(false)
        if cd.SetEdgeColor then
            cd:SetEdgeColor(EDGE_R, EDGE_G, EDGE_B, EDGE_A)
        end
        cd:SetDrawSwipe(true)
        cd:SetDrawBling(true)
        cd:SetSwipeColor(0, 0, 0, 0.80)
        cd:SetFrameLevel(btn:GetFrameLevel() + 1)
        cd:EnableMouse(false)
        styleBlizzardCooldownText(cd, btn.rexShowCooldownText == false)
    else
        cd = CreateFrame(
            "Cooldown",
            btn:GetName() and (btn:GetName() .. "Cooldown") or nil,
            btn,
            "CooldownFrameTemplate"
        )

        cd:SetAllPoints(btn.icon or btn)
        cd:SetDrawEdge(false)
        if cd.SetEdgeColor then
            cd:SetEdgeColor(EDGE_R, EDGE_G, EDGE_B, EDGE_A)
        end
        cd:SetDrawSwipe(true)
        cd:SetDrawBling(true)
        cd:SetSwipeColor(0, 0, 0, 0.80)
        cd:SetFrameLevel(btn:GetFrameLevel() + 1)
        cd:EnableMouse(false)

        styleBlizzardCooldownText(cd, btn.rexShowCooldownText == false)

        btn.cooldown = cd
    end

    if not btn.chargeCooldown then
        local chargeCooldown = CreateFrame(
            "Cooldown",
            btn:GetName() and (btn:GetName() .. "ChargeCooldown") or nil,
            btn,
            "CooldownFrameTemplate"
        )

        chargeCooldown:SetAllPoints(btn.icon or btn)
        chargeCooldown:SetDrawEdge(false)
        chargeCooldown:SetDrawSwipe(true)
        chargeCooldown:SetDrawBling(false)
        chargeCooldown:SetSwipeColor(0, 0, 0, 0.80)
        chargeCooldown:SetFrameLevel(btn:GetFrameLevel() + 2)
        chargeCooldown:EnableMouse(false)

        styleBlizzardCooldownText(chargeCooldown, btn.rexShowCooldownText == false)

        btn.chargeCooldown = chargeCooldown
    end

end

function CD:Style(btn, cfg)
    if not btn or not btn.cooldown then return end

    if btn.icon and btn.rexIconDesaturated then
        btn.icon:SetDesaturated(false)
        btn.rexIconDesaturated = false
    end

    btn.cooldown:ClearAllPoints()
    btn.cooldown:SetAllPoints(btn.icon or btn)
    btn.cooldown:SetDrawEdge(cfg.showCooldownEdge == true)
    if btn.cooldown.SetEdgeColor then
        btn.cooldown:SetEdgeColor(EDGE_R, EDGE_G, EDGE_B, EDGE_A)
    end
    btn.cooldown:SetDrawSwipe(cfg.showCooldownSwipe ~= false)
    btn.cooldown:SetDrawBling(cfg.showCooldownSwipe ~= false)
    btn.cooldown:SetSwipeColor(0, 0, 0, cfg.cooldownSwipeAlpha or 0.80)
    btn.cooldown:SetFrameLevel(btn:GetFrameLevel() + 1)
    btn.cooldown:EnableMouse(false)

    btn.rexShowCooldownText = cfg.showCooldownText ~= false
    styleBlizzardCooldownText(btn.cooldown, not btn.rexShowCooldownText)

    if btn.chargeCooldown then
        btn.chargeCooldown:ClearAllPoints()
        btn.chargeCooldown:SetAllPoints(btn.icon or btn)
        btn.chargeCooldown:SetDrawEdge(cfg.showCooldownEdge == true)
        btn.chargeCooldown:SetDrawSwipe(cfg.showCooldownSwipe ~= false)
        btn.chargeCooldown:SetDrawBling(false)
        btn.chargeCooldown:SetSwipeColor(0, 0, 0, cfg.cooldownSwipeAlpha or 0.80)
        btn.chargeCooldown:SetFrameLevel(btn:GetFrameLevel() + 2)
        btn.chargeCooldown:EnableMouse(false)

        styleBlizzardCooldownText(btn.chargeCooldown, not btn.rexShowCooldownText)
    end
end

function CD:StartActionCast(btn, castName, castStart, castDuration, castSpellID)
    if not btn or not btn.cooldown then return end
    local slot = AB:GetButtonActionSlot(btn) or btn.slot
    if not slot then return end

    if castName and actionMatchesCast(slot, castName, castSpellID) then
        applyCooldown(btn.cooldown, castStart, castDuration)
        self:ShowActionCastPulse(btn)
        styleButtonCooldownText(btn)
        return true
    end
end
function CD:Update(btn)
    if not btn or not btn.cooldown then return end

    -- LibActionButton is the single source of truth for normal action buttons.
    -- RexUI only styles those cooldown frames; programming them twice caused
    -- redundant work and occasional swipe/state races.
    if btn.__LAB_Version ~= nil then
        styleButtonCooldownText(btn)
        return
    end

    local slot = AB:GetButtonActionSlot(btn) or btn.slot
    if not slot then return end

    local castName, castStart, castDuration, castSpellID = getActiveCastInfo()
    if castName and actionMatchesCast(slot, castName, castSpellID) then
        applyCooldown(btn.cooldown, castStart, castDuration)
        clearCooldown(btn.chargeCooldown)
        self:ShowActionCastPulse(btn)
        styleButtonCooldownText(btn)
        return
    end

    self:StopActionCastPulse(btn)

    local info = getCooldownInfo(slot)
    local durationObject = getDurationObject(btn, slot, false)
    if info and info.isActive and applyDurationObject(btn.cooldown, durationObject) then
        local showSwipe = not info.isOnGCD
        setCooldownSwipe(btn.cooldown, showSwipe, showSwipe)
    elseif hasPlainDuration(info) then
        local showSwipe = not (info and info.isOnGCD == true)
        local st, dur = info.startTime, info.duration
        if type(st) == "number" and type(dur) == "number" then
            applyCooldown(btn.cooldown, st, dur, info.modRate)
        else
            clearCooldown(btn.cooldown)
        end
        setCooldownSwipe(btn.cooldown, showSwipe, showSwipe)
    elseif isActiveCooldown(info) then
        setCooldownSwipe(btn.cooldown, not (info and info.isOnGCD == true), not (info and info.isOnGCD == true))
    else
        clearCooldown(btn.cooldown)
    end

    if btn.icon then
        local cfg = btn.rexBarKey and AB:GetConfig(btn.rexBarKey) or AB:GetConfig("Defaults")
        local desaturated = cfg.desaturateOnCooldown == true
            and info
            and isActiveCooldown(info)
            and info.isOnGCD == false
            or false
        if btn.rexIconDesaturated ~= desaturated then
            btn.rexIconDesaturated = desaturated
            btn.icon:SetDesaturated(desaturated)
        end
    end

    local chargeInfo = getChargeInfo(slot)
    local chargeDurationObject = getDurationObject(btn, slot, true)
    if chargeInfo and chargeInfo.isActive and applyDurationObject(btn.chargeCooldown, chargeDurationObject) then
        setCooldownSwipe(btn.chargeCooldown, true, false)
    elseif chargeInfo and chargeInfo.maxCharges and chargeInfo.maxCharges > 1 then
        if hasPlainDuration(chargeInfo) and btn.chargeCooldown then
            local st, dur = chargeInfo.startTime, chargeInfo.duration
            if type(st) == "number" and type(dur) == "number" then
                applyCooldown(btn.chargeCooldown, st, dur, chargeInfo.modRate)
            else
                clearCooldown(btn.chargeCooldown)
            end
            setCooldownSwipe(btn.chargeCooldown, true, false)
        elseif isActiveCooldown(chargeInfo) then
            setCooldownSwipe(btn.chargeCooldown, true, false)
        else
            clearCooldown(btn.chargeCooldown)
        end
    else
        clearCooldown(btn.chargeCooldown)
    end

    styleButtonCooldownText(btn)
end

function CD:UpdateAll()
    local seen = {}

    for _, bar in pairs(AB.Bars or {}) do
        for _, btn in ipairs(bar.buttons or {}) do
            if btn and not seen[btn] then
                seen[btn] = true
                self:Update(btn)
            end
        end
    end

    for _, btn in pairs(AB.Buttons or {}) do
        if btn and not seen[btn] then
            seen[btn] = true
            self:Update(btn)
        end
    end
end

function CD:UpdateSlot(slot)
    slot = tonumber(slot) or slot
    if not slot then return end

    local seen = {}
    local function update(btn)
        if btn and not seen[btn] then
            seen[btn] = true
            self:Update(btn)
        end
    end

    update(AB.Buttons and AB.Buttons[slot])

    local numericSlot = tonumber(slot)
    if numericSlot and AB.Bars and AB.Bars.Bar1 and AB.GetEffectivePage then
        local currentPage = AB:GetEffectivePage()
        local page = math.floor((numericSlot - 1) / (NUM_ACTIONBAR_BUTTONS or 12)) + 1
        if page == currentPage then
            local index = ((numericSlot - 1) % (NUM_ACTIONBAR_BUTTONS or 12)) + 1
            local bar = AB.Bars.Bar1
            update(bar.buttons and bar.buttons[index])
        end
    end
end

function CD:QueueUpdateAll()
    if self.pendingUpdateAll then return end
    self.pendingUpdateAll = true

    C_Timer.After(0, function()
        CD.pendingUpdateAll = false
        CD:UpdateAll()
    end)
end

function CD:QueueUpdateSlot(slot)
    slot = tonumber(slot) or slot
    if not slot then
        self:QueueUpdateAll()
        return
    end

    self.pendingSlots = self.pendingSlots or {}
    self.pendingSlots[slot] = true

    if self.pendingSlotUpdate then return end
    self.pendingSlotUpdate = true

    C_Timer.After(0, function()
        CD.pendingSlotUpdate = false

        local slots = CD.pendingSlots
        CD.pendingSlots = nil
        if not slots then return end

        for dirtySlot in pairs(slots) do
            CD:UpdateSlot(dirtySlot)
        end
    end)
end
