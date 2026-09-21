local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI

local AB = RexUI.ActionBars
if not AB then return end

local LAB = LibStub and LibStub("LibActionButton-1.0-ElvUI", true)
AB.UsesLAB = LAB ~= nil
local WoWRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
-- Forever cannot compile LAB flyout snippets (loadstring_untainted is nil).
-- Leave SpellFlyout to Blizzard, same as Ellesmere.
local UseCustomFlyout = type(loadstring_untainted) == "function"
AB.UseCustomFlyout = UseCustomFlyout

local SetButtonActionTint
local GetButtonActionSlot
local BUTTONS_PER_PAGE = NUM_ACTIONBAR_BUTTONS or 12
local MAX_ACTION_PAGES = 18
local SUPPRESSED_CAST_VFX_SPELLS = {
    [136] = true, -- Mend Pet
    [982] = true, -- Revive Pet
}

local function UseForeverClient()
    local toc = select(4, GetBuildInfo()) or 0
    return toc >= 16000 and toc < 20000
end

local function GetUseOnKeyDown()
    if GetCVarBool then
        local value = GetCVarBool("ActionButtonUseKeyDown")
        if value == true then return true end
        if value == false then return false end
    end

    return true
end
AB.GetUseOnKeyDown = GetUseOnKeyDown

local function RegisterActionButtonClicks(btn, actionSlot)
    if not btn or not btn.RegisterForClicks then return end
    if InCombatLockdown and InCombatLockdown() then return end

    local useOnKeyDown = GetUseOnKeyDown()

    -- LibActionButton on retail deliberately listens to both mouse phases.
    -- Its secure handler uses this attribute to choose the actual cast phase;
    -- replacing its click registration would break that handler.
    if btn.__LAB_Version ~= nil then
        if btn.rexLastClickMode ~= "AnyDownAnyUp" then
            btn:RegisterForClicks("AnyDown", "AnyUp")
            btn.rexLastClickMode = "AnyDownAnyUp"
        end
        if btn.config and btn.config.clickOnDown ~= useOnKeyDown then
            btn.config.clickOnDown = useOnKeyDown
            if btn.UpdateConfig then
                btn:UpdateConfig(btn.config)
            end
        end
        if btn.SetAttribute and btn.rexLastUseOnKeyDown ~= useOnKeyDown then
            btn:SetAttribute("useOnKeyDown", useOnKeyDown)
            btn.rexLastUseOnKeyDown = useOnKeyDown
        end
        return
    end

    -- Retail SecureActionButtons need both phases.  The secure
    -- useOnKeyDown attribute decides which phase executes the action and
    -- also keeps press-and-hold spells, flyouts and modified clicks intact.
    if WoWRetail then
        if btn.rexLastClickMode ~= "AnyDownAnyUp" then
            btn:RegisterForClicks("AnyDown", "AnyUp")
            btn.rexLastClickMode = "AnyDownAnyUp"
        end
    else
        local clickMode = useOnKeyDown and "AnyDown" or "AnyUp"
        if btn.rexLastClickMode ~= clickMode then
            btn:RegisterForClicks(clickMode)
            btn.rexLastClickMode = clickMode
        end
    end

    if btn.SetAttribute and btn.rexLastUseOnKeyDown ~= useOnKeyDown then
        btn:SetAttribute("useOnKeyDown", useOnKeyDown)
        btn.rexLastUseOnKeyDown = useOnKeyDown
    end
end

local function ApplySecureCastAttributes(btn)
    if not btn or not btn.SetAttribute or InCombatLockdown() then return end

    if not btn.rexSecureCastDefaultsApplied then
        btn:SetAttribute("checkselfcast", true)
        btn:SetAttribute("checkfocuscast", true)
        btn.rexSecureCastDefaultsApplied = true
    end

    local mouseoverCast = GetCVarBool and GetCVarBool("enableMouseoverCast") or nil
    if btn.rexLastMouseoverCast ~= mouseoverCast then
        btn:SetAttribute("checkmouseovercast", mouseoverCast)
        btn.rexLastMouseoverCast = mouseoverCast
    end
end

function AB:ApplySecureCastAttributes()
    if InCombatLockdown() then return end
    for _, btn in pairs(self.Buttons or {}) do
        ApplySecureCastAttributes(btn)
    end
end

local function DisableActionButtonDrag(btn)
    if not btn or not btn.RegisterForDrag then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if btn.__LAB_Version ~= nil then return end
    pcall(btn.RegisterForDrag, btn, "")
end

local function IsFlyoutActionButton(btn)
    if not btn or not GetActionInfo then return false end

    local slot = btn.GetAttribute and btn:GetAttribute("action") or btn.slot
    if not slot then return false end

    local ok, actionType = pcall(GetActionInfo, slot)
    return ok and actionType == "flyout"
end

local function IsLABButton(btn)
    return btn and btn.__LAB_Version ~= nil
end

local function IsActionBarLockEnabled()
    if GetCVarBool then
        local locked = GetCVarBool("lockActionBars")
        if locked == false then return false end
        if locked == true then return true end
    end
    return true
end

local function UpdateLABDragLock(btn)
    if not IsLABButton(btn) or InCombatLockdown() then return end
    btn:SetAttribute("LABdisableDragNDrop", nil)
    btn:SetAttribute("buttonlock", IsActionBarLockEnabled() or nil)
    btn:SetAttribute("unlockedpreventdrag", nil)
end

local function SetupLABCombatDragLock(btn)
    if not IsLABButton(btn) or InCombatLockdown() then return end
    if btn:GetAttribute("rexCombatDragLock") then return end

    btn:SetAttribute("rexCombatDragLock", true)
    btn:SetAttribute("LABdisableDragNDrop", nil)
    btn:SetAttribute("buttonlock", IsActionBarLockEnabled() or nil)
    btn:SetAttribute("unlockedpreventdrag", nil)
end

function AB:ApplyClickRegistration()
    if InCombatLockdown() then return end

    for _, btn in pairs(self.Buttons or {}) do
        if btn and btn.RegisterForClicks and btn.SetAttribute then
            RegisterActionButtonClicks(btn)
            DisableActionButtonDrag(btn)
        end
    end
end

local BindingNamePrefixes = {
    Bar1 = "ACTIONBUTTON",
    Bar2 = "MULTIACTIONBAR1BUTTON",
    Bar3 = "MULTIACTIONBAR2BUTTON",
    Bar4 = "MULTIACTIONBAR3BUTTON",
    Bar5 = "MULTIACTIONBAR4BUTTON",
    Bar6 = "MULTIACTIONBAR5BUTTON",
    Bar7 = "MULTIACTIONBAR6BUTTON",
    Bar8 = "MULTIACTIONBAR7BUTTON",
}

local function GetButtonBindingKey(btn)
    if not btn then return nil end

    local prefix = btn.rexBarKey and BindingNamePrefixes[btn.rexBarKey]
    local index = btn.rexIndex or (btn.GetID and btn:GetID())

    if prefix and index then
        return GetBindingKey(prefix .. index)
    end

    if btn.slot then
        return GetBindingKey("ACTIONBUTTON" .. btn.slot)
    end
end

local function FormatBindingText(key)
    if not key or key == "." then return "" end

    key = key:gsub("CTRL%-", "C")
    key = key:gsub("SHIFT%-", "S")
    key = key:gsub("ALT%-", "A")
    key = key:gsub("META%-", "M")
    key = key:gsub("NUMPAD", "N")
    key = key:gsub("MOUSEWHEELUP", "WU")
    key = key:gsub("MOUSEWHEELDOWN", "WD")
    key = key:gsub("BUTTON", "M")
    key = key:gsub("SPACE", "Sp")
    key = key:gsub("INSERT", "Ins")
    key = key:gsub("DELETE", "Del")
    key = key:gsub("HOME", "Hm")
    key = key:gsub("END", "End")
    key = key:gsub("PAGEUP", "PU")
    key = key:gsub("PAGEDOWN", "PD")
    key = key:gsub("PLUS", "+")
    key = key:gsub("MINUS", "-")

    return key
end

local function ClearHotkeyRegion(region)
    if not region then return end

    if region.rexClearingHotkey then return end
    region.rexClearingHotkey = true

    if region.SetText then pcall(region.SetText, region, "") end
    if region.SetAlpha then pcall(region.SetAlpha, region, 0) end
    if region.SetTextColor then pcall(region.SetTextColor, region, 1, 1, 1, 0) end
    if region.SetWidth then pcall(region.SetWidth, region, 0.001) end
    if region.SetHeight then pcall(region.SetHeight, region, 0.001) end
    if region.SetScale then pcall(region.SetScale, region, 0.001) end
    if region.Hide then pcall(region.Hide, region) end

    region.rexClearingHotkey = nil
end

-- All three native regions belong to the same action button. Keep one weak
-- maintenance set so the fallback ticker never processes a button up to three
-- times during the same pass.
local nativeMaintenanceButtons = setmetatable({}, { __mode = "k" })
local nativeHotkeyTicker
local HideNativeHotkey
local HideNativeCount
local HideNativeName
local ClearNativeCountRegion

local function NeedsNativeHotkeyTicker()
    if InCombatLockdown and InCombatLockdown() then return true end
    if UnitExists("target") or UnitExists("focus") then return true end
    return false
end

local function UpdateNativeHotkeyButton(btn)
    HideNativeHotkey(btn)
    if HideNativeCount then
        HideNativeCount(btn)
    end
    if HideNativeName then
        HideNativeName(btn)
    end

    if btn.rexNativeHotkeys then
        for region in pairs(btn.rexNativeHotkeys) do
            ClearHotkeyRegion(region)
        end
    end

    if btn.rexNativeCounts then
        for region in pairs(btn.rexNativeCounts) do
            ClearNativeCountRegion(region)
        end
    end

    if btn.rexNativeNames then
        for region in pairs(btn.rexNativeNames) do
            ClearNativeCountRegion(region)
        end
    end

    if SetButtonActionTint then
        SetButtonActionTint(btn)
    end
end

local function EnsureNativeHotkeyTicker()
    if nativeHotkeyTicker or not C_Timer or not C_Timer.NewTicker then return end
    if not NeedsNativeHotkeyTicker() then return end

    nativeHotkeyTicker = C_Timer.NewTicker(0.5, function(ticker)
        if not NeedsNativeHotkeyTicker() then
            ticker:Cancel()
            nativeHotkeyTicker = nil
            return
        end

        local hasButtons = false

        for btn in pairs(nativeMaintenanceButtons) do
            hasButtons = true
            UpdateNativeHotkeyButton(btn)
        end

        if not hasButtons then
            ticker:Cancel()
            nativeHotkeyTicker = nil
        end
    end)
end

HideNativeHotkey = function(btn)
    if not btn then return end

    if btn.rexNativeHotkeyInitialized then
        if btn.rexNativeHotkeys then
            for region in pairs(btn.rexNativeHotkeys) do
                ClearHotkeyRegion(region)
            end
        end
        nativeMaintenanceButtons[btn] = true
        EnsureNativeHotkeyTicker()
        return
    end

    local regions = {
        btn.hotkey,
        btn.HotKey,
    }

    local name = btn.GetName and btn:GetName()
    if name then
        regions[#regions + 1] = _G[name .. "HotKey"]
    end

    if btn.TextOverlayContainer then
        regions[#regions + 1] = btn.TextOverlayContainer.HotKey
        if name then
            regions[#regions + 1] = _G[name .. "TextOverlayContainerHotKey"]
        end
    end

    btn.rexNativeHotkeyRegions = regions
    btn.rexNativeHotkeys = btn.rexNativeHotkeys or {}

    for _, region in ipairs(regions) do
        if region then
            btn.rexNativeHotkeys[region] = true

            ClearHotkeyRegion(region)

            if not region.rexRangeDotSuppressed then
                region.rexRangeDotSuppressed = true

                if region.Show then
                    hooksecurefunc(region, "Show", function(self)
                        if not self.rexClearingHotkey then
                            ClearHotkeyRegion(self)
                        end
                    end)
                end

                if region.SetText then
                    hooksecurefunc(region, "SetText", function(self)
                        if not self.rexClearingHotkey then
                            ClearHotkeyRegion(self)
                        end
                    end)
                end
            end
        end
    end

    btn.rexNativeHotkeyInitialized = true
    nativeMaintenanceButtons[btn] = true
    EnsureNativeHotkeyTicker()
end

local nativeHotkeyEventFrame = CreateFrame("Frame")
nativeHotkeyEventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
nativeHotkeyEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
nativeHotkeyEventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
nativeHotkeyEventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
nativeHotkeyEventFrame:SetScript("OnEvent", EnsureNativeHotkeyTicker)

ClearNativeCountRegion = function(region)
    if not region then return end

    if region.rexClearingCount then return end
    region.rexClearingCount = true

    if region.SetText then pcall(region.SetText, region, "") end
    if region.SetAlpha then pcall(region.SetAlpha, region, 0) end
    if region.SetTextColor then pcall(region.SetTextColor, region, 1, 1, 1, 0) end
    if region.SetWidth then pcall(region.SetWidth, region, 0.001) end
    if region.SetHeight then pcall(region.SetHeight, region, 0.001) end
    if region.SetScale then pcall(region.SetScale, region, 0.001) end
    if region.Hide then pcall(region.Hide, region) end

    region.rexClearingCount = nil
end

HideNativeCount = function(btn)
    if not btn then return end

    if btn.rexNativeCountInitialized then
        if btn.rexNativeCounts then
            for region in pairs(btn.rexNativeCounts) do
                ClearNativeCountRegion(region)
            end
        end
        nativeMaintenanceButtons[btn] = true
        EnsureNativeHotkeyTicker()
        return
    end

    local regions = {
        btn.Count,
        btn.count,
    }

    local name = btn.GetName and btn:GetName()
    if name then
        regions[#regions + 1] = _G[name .. "Count"]
    end

    if btn.TextOverlayContainer then
        regions[#regions + 1] = btn.TextOverlayContainer.Count
        if name then
            regions[#regions + 1] = _G[name .. "TextOverlayContainerCount"]
        end
    end

    btn.rexNativeCountRegions = regions
    btn.rexNativeCounts = btn.rexNativeCounts or {}

    for _, region in ipairs(regions) do
        if region and region ~= btn.countText then
            btn.rexNativeCounts[region] = true
            ClearNativeCountRegion(region)

            if not region.rexCountSuppressed then
                region.rexCountSuppressed = true

                if region.Show then
                    hooksecurefunc(region, "Show", function(self)
                        if not self.rexClearingCount then
                            ClearNativeCountRegion(self)
                        end
                    end)
                end

                if region.SetText then
                    hooksecurefunc(region, "SetText", function(self)
                        if not self.rexClearingCount then
                            ClearNativeCountRegion(self)
                        end
                    end)
                end
            end
        end
    end

    btn.rexNativeCountInitialized = true
    nativeMaintenanceButtons[btn] = true
    EnsureNativeHotkeyTicker()
end

HideNativeName = function(btn)
    if not btn then return end

    if btn.rexNativeNameInitialized then
        if btn.rexNativeNames then
            for region in pairs(btn.rexNativeNames) do
                ClearNativeCountRegion(region)
            end
        end
        nativeMaintenanceButtons[btn] = true
        EnsureNativeHotkeyTicker()
        return
    end

    local regions = {
        btn.Name,
        btn.name,
        btn.MacroName,
        btn.macroName,
    }

    local name = btn.GetName and btn:GetName()
    if name then
        regions[#regions + 1] = _G[name .. "Name"]
        regions[#regions + 1] = _G[name .. "MacroName"]
    end

    if btn.TextOverlayContainer then
        regions[#regions + 1] = btn.TextOverlayContainer.Name
        regions[#regions + 1] = btn.TextOverlayContainer.MacroName
        if name then
            regions[#regions + 1] = _G[name .. "TextOverlayContainerName"]
            regions[#regions + 1] = _G[name .. "TextOverlayContainerMacroName"]
        end
    end

    btn.rexNativeNames = btn.rexNativeNames or {}

    for _, region in ipairs(regions) do
        if region then
            btn.rexNativeNames[region] = true
            ClearNativeCountRegion(region)

            if not region.rexNameSuppressed then
                region.rexNameSuppressed = true

                if region.Show then
                    hooksecurefunc(region, "Show", function(self)
                        if not self.rexClearingCount then
                            ClearNativeCountRegion(self)
                        end
                    end)
                end

                if region.SetText then
                    hooksecurefunc(region, "SetText", function(self)
                        if not self.rexClearingCount then
                            ClearNativeCountRegion(self)
                        end
                    end)
                end
            end
        end
    end

    btn.rexNativeNameInitialized = true
    nativeMaintenanceButtons[btn] = true
    EnsureNativeHotkeyTicker()
end

local function HideNativeIconRegions(btn)
    if not btn then return end

    if btn.rexNativeIconRegions then
        for _, region in ipairs(btn.rexNativeIconRegions) do
            if region and region ~= btn.RexUIIcon and region ~= btn.icon then
                if region.SetTexture then region:SetTexture(nil) end
                if region.SetAlpha then region:SetAlpha(0) end
                if region.Hide then region:Hide() end
            end
        end
        return
    end

    local regions = {
        btn.Icon,
        btn.iconTexture,
    }

    local name = btn.GetName and btn:GetName()
    if name then
        regions[#regions + 1] = _G[name .. "Icon"]
    end

    btn.rexNativeIconRegions = regions

    for _, region in ipairs(regions) do
        if region and region ~= btn.RexUIIcon and region ~= btn.icon then
            if region.SetTexture then region:SetTexture(nil) end
            if region.SetAlpha then region:SetAlpha(0) end
            if region.Hide then region:Hide() end
        end
    end
end

local function ClearEmptySlotVisuals(btn)
    if not btn then return end

    if btn.SetChecked then
        pcall(btn.SetChecked, btn, false)
    end
    if btn.emptySlot then
        btn.emptySlot:Show()
    end

    local textures = {
        btn.CheckedTexture,
        btn.ActionStatus,
        btn.NewActionTexture,
        btn.Flash,
    }

    for _, texture in ipairs(textures) do
        if texture then
            if texture.SetTexture then texture:SetTexture(nil) end
            if texture.SetAlpha then texture:SetAlpha(0) end
            if texture.Hide then texture:Hide() end
        end
    end
end

local function HideNativeCheckedVisuals(btn)
    if not btn then return end

    local textures = {
        btn.CheckedTexture,
        btn.ActionStatus,
        btn.Border,
        btn.BorderShadow,
    }

    if btn.GetCheckedTexture then
        local ok, texture = pcall(btn.GetCheckedTexture, btn)
        if ok and texture then
            textures[#textures + 1] = texture
        end
    end

    local name = btn.GetName and btn:GetName()
    if name then
        textures[#textures + 1] = _G[name .. "CheckedTexture"]
        textures[#textures + 1] = _G[name .. "ActionStatus"]
        textures[#textures + 1] = _G[name .. "Border"]
    end

    for _, texture in ipairs(textures) do
        if texture then
            if texture.SetTexture then texture:SetTexture(nil) end
            if texture.SetColorTexture then texture:SetColorTexture(0, 0, 0, 0) end
            if texture.SetAlpha then texture:SetAlpha(0) end
            if texture.Hide then texture:Hide() end
        end
    end
end

local function HasActionSafe(slot)
    local ok, hasAction = pcall(function()
        local hasActionAPI = C_ActionBar and C_ActionBar.HasAction or HasAction
        return hasActionAPI(slot) == true
    end)

    return ok and hasAction == true
end

local function IsActionUsableViaPet(slot)
    if not GetActionInfo or not GetPetActionInfo or not GetPetActionSlotUsable then
        return false
    end

    local okAction, actionType, actionId, _, actionSpellId = pcall(GetActionInfo, slot)
    if not okAction or actionType ~= "spell" then
        return false
    end

    -- Retail can expose the actual spell ID as the fourth return value.
    -- Fall back to the action ID for clients where both are identical.
    local spellId = actionSpellId or actionId
    if not spellId then return false end

    for petSlot = 1, (NUM_PET_ACTION_SLOTS or 10) do
        local okPet, _, _, _, _, _, _, petSpellId = pcall(GetPetActionInfo, petSlot)
        if okPet and petSpellId == spellId then
            local okUsable, usable = pcall(GetPetActionSlotUsable, petSlot)
            if okUsable and usable == true then
                return true
            end
        end
    end

    return false
end

local function ConfigureLABUsability(btn)
    if not IsLABButton(btn) or btn.rexUsabilityConfigured then return end

    -- LibActionButton exclusively owns range and usability updates.
    if btn.config and btn.config.colors then
        btn.config.colors.range = { 0.80, 0.10, 0.10 }
        btn.config.colors.mana = { 0.50, 0.50, 1.00 }
        btn.config.colors.usable = { 1.00, 1.00, 1.00 }
        btn.config.colors.notUsable = { 0.40, 0.40, 0.40 }
        btn.config.outOfRangeColoring = "button"
        btn.config.clickOnDown = GetUseOnKeyDown()
        btn.config.targetReticle = true
        btn.config.spellCastVFX = false
        if btn.UpdateConfig then
            btn:UpdateConfig(btn.config)
        end
    end

    btn.rexUsabilityConfigured = true
end

local function GetUsableTint(slot)
    local ok, r, g, b = pcall(function()
        -- Use the global API. C_ActionBar.IsUsableAction on Forever/Midnight
        -- can stay secret or always-true, so LAB never grays rage-starved spells.
        local isUsableAction = _G.IsUsableAction
        if type(isUsableAction) ~= "function" then
            return 1, 1, 1
        end

        local isUsable, notEnoughMana = isUsableAction(slot)

        if not isUsable and IsActionUsableViaPet(slot) then
            isUsable = true
            notEnoughMana = false
        end

        if isUsable then
            return 1, 1, 1
        end

        -- No rage/energy/mana: gray, as on classic bars.
        return 0.40, 0.40, 0.40
    end)

    if ok then
        return r or 1, g or 1, b or 1
    end

    return 1, 1, 1
end

local function IsActionOutOfRangeSafe(slot)
    if not IsActionInRange then return false end

    local ok, outOfRange = pcall(function()
        local inRange = IsActionInRange(slot)
        return inRange == false or inRange == 0
    end)

    return ok and outOfRange == true
end

SetButtonActionTint = function(btn)
    if not btn or not btn.icon or not btn.slot then return end

    -- Retail LAB owns this tint. Forever never gets ACTION_USABLE_CHANGED,
    -- so LAB leaves rage-starved spells white.
    if IsLABButton(btn) and not UseForeverClient() then return end

    if HasActionSafe(btn.slot) then
        local r, g, b = GetUsableTint(btn.slot)

        if IsActionOutOfRangeSafe(btn.slot) then
            r, g, b = 0.80, 0.10, 0.10
        end

        btn.icon:SetVertexColor(r, g, b, 1)
    else
        btn.icon:SetVertexColor(1, 1, 1, 1)
    end
end

function AB:UpdateButtonActionTint(btn)
    SetButtonActionTint(btn)
end

if LAB and LAB.RegisterCallback and UseForeverClient() then
    LAB.RegisterCallback(AB, "OnButtonUsable", function(_, btn)
        SetButtonActionTint(btn)
    end)
end

function AB:UpdateUsableVisuals()
    local seen = {}

    for _, bar in pairs(AB.Bars or {}) do
        for _, btn in ipairs(bar.buttons or {}) do
            if btn and not seen[btn] then
                seen[btn] = true
                SetButtonActionTint(btn)
            end
        end
    end
end

local function SetButtonCheckedVisual(btn, active, equipped)
    if not btn then return end

    btn.rexActionActive = active == true
    btn.rexActionEquipped = equipped == true
    if btn.SetChecked then
        pcall(btn.SetChecked, btn, false)
    end
    HideNativeCheckedVisuals(btn)

    if not btn.rexMouseDown and btn.pushedOverlay then
        btn.pushedOverlay:SetAlpha(0)
    end

    if not btn.rexMouseDown and btn.rexPushedTexture then
        btn.rexPushedTexture:SetAlpha(0)
    end

    if AB.ApplyButtonStateVisual then
        local cfg = btn.rexBarKey and AB:GetConfig(btn.rexBarKey) or AB:GetConfig("Defaults")
        AB:ApplyButtonStateVisual(btn, cfg)
    end
end

local function UpdateButtonCheckedState(btn, slot, hasAction)
    if not btn or not slot or not hasAction then
        SetButtonCheckedVisual(btn, false, false)
        return
    end

    local active = false
    if IsCurrentAction then
        local ok, result = pcall(IsCurrentAction, slot)
        active = active or (ok and result == true)
    end
    if IsAutoRepeatAction then
        local ok, result = pcall(IsAutoRepeatAction, slot)
        active = active or (ok and result == true)
    end

    local equipped = false
    if IsEquippedAction then
        local ok, result = pcall(IsEquippedAction, slot)
        equipped = ok and result == true
    end

    SetButtonCheckedVisual(btn, active, equipped)
end

function AB:UpdateActionStateVisuals()
    -- AB.Buttons contains only the normal action buttons. Pet and stance bars
    -- maintain their own stable active state and must not be reset here.
    for _, btn in pairs(self.Buttons or {}) do
        local slot = GetButtonActionSlot(btn)
        UpdateButtonCheckedState(btn, slot, slot and HasActionSafe(slot) or false)
    end
end

local function GetActionTextureSafe(slot, actionType, actionId)
    local texture

    local getActionTextureAPI = C_ActionBar and C_ActionBar.GetActionTexture or GetActionTexture
    if getActionTextureAPI then
        local ok, result = pcall(getActionTextureAPI, slot)
        if ok then
            texture = result
        end
    end

    -- WoW 12.1: Der Combat-Assist-Slot wechselt
    -- seinen dargestellten Zauber dynamisch. Falls der Slot noch keine Textur
    -- liefert, die Textur des aktuellen Assisted-Combat-Zaubers verwenden.
    if not texture and C_ActionBar and C_ActionBar.IsAssistedCombatAction
        and C_ActionBar.IsAssistedCombatAction(slot)
        and C_AssistedCombat and C_AssistedCombat.GetActionSpell then
        local spellID = C_AssistedCombat.GetActionSpell()
        if spellID and C_Spell and C_Spell.GetSpellTexture then
            texture = C_Spell.GetSpellTexture(spellID)
        end
    end

    if texture or not actionType or not actionId then
        return texture
    end

    if actionType == "spell" then
        if C_Spell and C_Spell.GetSpellTexture then
            local ok, result = pcall(C_Spell.GetSpellTexture, actionId)
            if ok and result then return result end
        end
        if GetSpellTexture then
            local ok, result = pcall(GetSpellTexture, actionId)
            if ok and result then return result end
        end
    elseif actionType == "item" then
        if C_Item and C_Item.GetItemIconByID then
            local ok, result = pcall(C_Item.GetItemIconByID, actionId)
            if ok and result then return result end
        end
        if GetItemIcon then
            local ok, result = pcall(GetItemIcon, actionId)
            if ok and result then return result end
        end
    elseif actionType == "macro" and GetMacroInfo then
        local ok, _, result = pcall(GetMacroInfo, actionId)
        if ok and result then return result end
    end

    return nil
end

local function GetDisplayCountText(slot, actionType, actionId)
    -- Retail/Midnight can return a protected/secret display-count value in combat.
    -- Do not tonumber(), compare or format that value: pass it straight to SetText(),
    -- matching LibActionButton/Blizzard behavior.
    if C_ActionBar and C_ActionBar.GetActionDisplayCount then
        local ok, value = pcall(C_ActionBar.GetActionDisplayCount, slot)
        if ok and value ~= nil then
            return value
        end
    end

    -- Legacy/item fallback. These paths return ordinary numeric values.
    local value
    if GetActionCount then
        local ok, result = pcall(GetActionCount, slot)
        if ok then value = result end
    end

    if (not value or value <= 0) and actionType == "item" and actionId then
        if C_Item and C_Item.GetItemCount then
            local ok, result = pcall(C_Item.GetItemCount, actionId, false, false, true)
            if ok then value = result end
        elseif GetItemCount then
            local ok, result = pcall(GetItemCount, actionId, false, true)
            if ok then value = result end
        end
    end

    value = tonumber(value)
    if not value or value <= 1 then
        return ""
    end

    if value >= 1000000 then
        return string.format("%.1fm", value / 1000000):gsub("%.0m", "m")
    elseif value >= 10000 then
        return string.format("%dk", math.floor(value / 1000))
    elseif value >= 1000 then
        return string.format("%.1fk", value / 1000):gsub("%.0k", "k")
    end

    return tostring(value)
end

local function UpdateButtonCountText(btn)
    if not btn or not btn.countText then return end

    local slot = GetButtonActionSlot(btn)
    local text = ""
    if slot and HasActionSafe(slot) then
        local ok, actionType, actionId = pcall(GetActionInfo, slot)
        text = GetDisplayCountText(slot, ok and actionType or nil, ok and actionId or nil)
    end

    -- Midnight may return a protected display-count value in combat.  Pass it
    -- straight through; comparing it with the current FontString text is not
    -- permitted for secret values.
    btn.countText:SetText(text)
    HideNativeCount(btn)
end

function AB:UpdateDisplayCounts()
    local seen = {}

    for _, bar in pairs(self.Bars or {}) do
        for _, btn in ipairs(bar.buttons or {}) do
            if btn and not seen[btn] then
                seen[btn] = true
                UpdateButtonCountText(btn)
            end
        end
    end

    for _, btn in pairs(self.Buttons or {}) do
        if btn and not seen[btn] then
            seen[btn] = true
            UpdateButtonCountText(btn)
        end
    end
end

function AB:QueueDisplayCountRefresh()
    if self.pendingDisplayCountRefresh then return end
    self.pendingDisplayCountRefresh = true

    C_Timer.After(0, function()
        AB.pendingDisplayCountRefresh = false
        AB:UpdateDisplayCounts()
    end)
end

local function ConfigureBar1ButtonStates(btn, index)
    if not btn or not index then return end

    for page = 1, MAX_ACTION_PAGES do
        local action = ((page - 1) * BUTTONS_PER_PAGE) + index
        if btn.SetState then
            btn:SetState(page, "action", action)
        end
        if btn.SetAttribute then
            btn:SetAttribute("labtype-" .. page, "action")
            btn:SetAttribute("labaction-" .. page, action)
        end
    end
end

GetButtonActionSlot = function(btn)
    if not btn then return nil end

    if UseForeverClient() and btn.rexBarKey == "Bar1" and AB.ResolveForeverBar1Slot then
        return AB:ResolveForeverBar1Slot(btn)
    end

    local attributeSlot = btn.GetAttribute and btn:GetAttribute("action")
    attributeSlot = tonumber(attributeSlot) or attributeSlot

    if btn.rexBarKey == "Bar1" and attributeSlot then
        return attributeSlot
    end

    return btn.slot or attributeSlot
end
AB.GetButtonActionSlot = GetButtonActionSlot   -- NEU: für Cooldowns.lua nutzbar machen

function AB:IsActionbarLocked()
    return InCombatLockdown and InCombatLockdown()
end

function AB:SetActionbarLocked(locked)
    if InCombatLockdown() then
        AB:RunOutOfCombat("SetActionbarLocked", function()
            AB:SetActionbarLocked(locked)
        end)
        return
    end

    for _, btn in pairs(AB.Buttons or {}) do
        UpdateLABDragLock(btn)
    end
end

function AB:CursorHasAction()
    if GetCursorInfo then
        local kind = GetCursorInfo()
        if kind then return true end
    end
    if CursorHasItem and CursorHasItem() then return true end
    if CursorHasSpell and CursorHasSpell() then return true end
    if CursorHasMacro and CursorHasMacro() then return true end

    return false
end

local function NotifyButtonActionChanged(btn, slot)
    slot = slot or (btn and btn.slot)

    if btn and AB.UpdateButton then
        AB:UpdateButton(btn)
    end

    if EventRegistry and btn then
        EventRegistry:TriggerEvent("ActionButton.OnActionChanged", btn)
    end

    if slot and AB.MarkDirty and AB.ScheduleDirtyFlush then
        AB:MarkDirty(slot)
        AB:ScheduleDirtyFlush()
    end
end

local function GetDragSlot(btn)
    if AB.GetButtonActionSlot then
        return AB:GetButtonActionSlot(btn)
    end
    return btn and ((btn.GetAttribute and btn:GetAttribute("action")) or btn.slot)
end

local function IsPickupModifier()
    if IsModifiedClick and IsModifiedClick("PICKUPACTION") then
        return true
    end
    return IsShiftKeyDown and IsShiftKeyDown()
end

local function CanPickupFromBar()
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    if not IsActionBarLockEnabled() then
        return true
    end
    return IsPickupModifier()
end

local function MarkSlotDirty(slot)
    if slot and AB.MarkDirty and AB.ScheduleDirtyFlush then
        AB:MarkDirty(slot)
        AB:ScheduleDirtyFlush()
    end
end

function AB:PickupButtonAction(btn)
    if not btn or InCombatLockdown() then return end
    if not CanPickupFromBar() then return end
    local slot = GetDragSlot(btn)
    if not slot then return end

    pcall(PickupAction, slot)
    MarkSlotDirty(slot)
end

function AB:PlaceButtonAction(btn)
    if not btn or InCombatLockdown() then return end
    if not AB:CursorHasAction() then return end
    local slot = GetDragSlot(btn)
    if not slot then return end

    PlaceAction(slot)
    NotifyButtonActionChanged(btn, slot)
end

function AB:EnableButtonDragDrop(btn)
    if not btn then return end

    -- LAB drag used WrapScript. Forever cannot compile those bodies, so LAB
    -- and native buttons both use PickupAction/PlaceAction out of combat.
    if btn.RegisterForDrag and not InCombatLockdown() then
        pcall(btn.RegisterForDrag, btn, "LeftButton", "RightButton")
    end

    local canWrap = type(loadstring_untainted) == "function"
    if canWrap and SecureHandlerWrapScript and not btn:GetAttribute("rexPickupWrap") and not InCombatLockdown() then
        btn:SetAttribute("rexPickupWrap", true)
        SecureHandlerWrapScript(btn, "OnClick", btn, [[
            if IsModifiedClick("PICKUPACTION") then
                local cur = self:GetAttribute("useOnKeyDown")
                if cur ~= false then
                    self:SetAttribute("rexKeyDownBackup", cur or true)
                    self:SetAttribute("useOnKeyDown", false)
                end
            end
        ]], [[
            if self:GetAttribute("rexKeyDownBackup") then
                self:SetAttribute("useOnKeyDown", self:GetAttribute("rexKeyDownBackup"))
                self:SetAttribute("rexKeyDownBackup", nil)
            end
        ]])
    end

    btn:SetScript("OnDragStart", function(self)
        if not CanPickupFromBar() then return end
        local slot = GetDragSlot(self)
        if not slot then return end
        pcall(PickupAction, slot)
        MarkSlotDirty(slot)
    end)

    btn:SetScript("OnReceiveDrag", function(self)
        if InCombatLockdown() then return end
        local slot = GetDragSlot(self)
        if not slot then return end
        pcall(PlaceAction, slot)
        NotifyButtonActionChanged(self, slot)
    end)
end

function AB:PlayButtonPress(btn, down)
    if not btn then return end

    down = down == true
    btn.rexMouseDown = down or nil
    local alpha = down and (btn.rexPressAlpha or 0.22) or 0

    if btn.pushedOverlay and btn.pushedOverlay.rexReleaseFade then
        btn.pushedOverlay.rexReleaseFade:Stop()
    end

    if btn.rexPushedTexture then
        btn.rexPushedTexture:SetAlpha(alpha)
        if down then
            btn.rexPushedTexture:Show()
        end
    elseif btn.GetPushedTexture then
        local ok, pushed = pcall(btn.GetPushedTexture, btn)
        if ok and pushed then
            pushed:SetAlpha(alpha)
            if down then
                pushed:Show()
            end
            btn.rexPushedTexture = pushed
        end
    end

    if btn.pushedOverlay then
        if down then
            btn.pushedOverlay:SetAlpha(alpha)
        else
            btn.pushedOverlay:SetAlpha(0)
        end
    end

    if not down then
        -- Only the released button needs an immediate tint correction.  LAB
        -- and ACTIONBAR_UPDATE_USABLE remain authoritative for global state.
        SetButtonActionTint(btn)
    end
end

function AB:EnableButtonFeedback(btn)
    if not btn or btn.rexFeedbackEnabled then return end
    if IsFlyoutActionButton(btn) then return end
    btn.rexFeedbackEnabled = true

    btn:HookScript("OnMouseDown", function(self, button)
        if button == "LeftButton" or button == "RightButton" then
            AB:PlayButtonPress(self, true)
        end
    end)

    btn:HookScript("OnMouseUp", function(self)
        AB:PlayButtonPress(self, false)
    end)

    btn:HookScript("OnLeave", function(self)
        AB:PlayButtonPress(self, false)
    end)

    btn:HookScript("OnHide", function(self)
        AB:PlayButtonPress(self, false)
    end)
end

local function UpdateFlyoutArrow(btn)
    if btn and btn.flyoutArrow then
        btn.flyoutArrow:Hide()
    end
end

local function RemoveFrameFromActionMap(registry, btn)
    if not registry or type(registry.actions) ~= "table" then return end

    for action, frames in pairs(registry.actions) do
        if type(frames) == "table" then
            frames[btn] = nil
        elseif frames == btn then
            registry.actions[action] = nil
        end
    end
end

local function RemoveFrameFromFrameRegistry(registry, btn)
    if not registry or type(registry.frames) ~= "table" then return end

    for key, frame in pairs(registry.frames) do
        if frame == btn then
            registry.frames[key] = nil
        end
    end
end

local function DisableNativeActionButtonUpdates(btn)
    if not btn then return end
    if IsLABButton(btn) then return end

    if btn._rexNativeUpdatesDisabled then
        RemoveFrameFromFrameRegistry(_G.ActionBarButtonEventsFrame, btn)
        RemoveFrameFromFrameRegistry(_G.ActionBarActionEventsFrame, btn)
        return
    end

    btn._rexNativeUpdatesDisabled = true

    if btn.UnregisterActionBarButtonCheckFrames and btn.action then
        pcall(btn.UnregisterActionBarButtonCheckFrames, btn, btn.action)
    end

    RemoveFrameFromFrameRegistry(_G.ActionBarButtonEventsFrame, btn)
    RemoveFrameFromFrameRegistry(_G.ActionBarActionEventsFrame, btn)
    RemoveFrameFromActionMap(_G.ActionBarButtonRangeCheckFrame, btn)
    RemoveFrameFromActionMap(_G.ActionBarButtonUsableWatcherFrame, btn)

    if _G.ActionBarActionEventsFrame and _G.ActionBarActionEventsFrame.UnregisterFrame then
        pcall(_G.ActionBarActionEventsFrame.UnregisterFrame, _G.ActionBarActionEventsFrame, btn)
    end

    if _G.ActionBarButtonUpdateFrame and _G.ActionBarButtonUpdateFrame.UnregisterFrame then
        pcall(_G.ActionBarButtonUpdateFrame.UnregisterFrame, _G.ActionBarButtonUpdateFrame, btn)
    end

    if btn.UnregisterAllEvents then
        pcall(btn.UnregisterAllEvents, btn)
    end

    if btn.SetScript then
        pcall(btn.SetScript, btn, "OnEvent", nil)
        pcall(btn.SetScript, btn, "OnAttributeChanged", nil)
    end

    btn.UpdateAction = function() end
    btn.UpdateButtonArt = function() end
end

function AB:CreateBar(barKey, cfg, slotOffset)

    if not cfg or not cfg.enabled then return end

    if InCombatLockdown() then
        AB:RunOutOfCombat("CreateBar_" .. barKey, function()
            AB:CreateBar(barKey, cfg, slotOffset)
        end)
        return
    end

    slotOffset = slotOffset or 0

    local oldBar = AB.Bars[barKey] or _G["RexUI_" .. barKey]
    if oldBar then
        if UnregisterStateDriver then
            pcall(UnregisterStateDriver, oldBar, "visibility")
            pcall(UnregisterStateDriver, oldBar, "page")
        end
        oldBar:Hide()
        oldBar:SetParent(nil)
        for _, btn in ipairs(oldBar.buttons or {}) do
            if btn then
                if btn.UnregisterAllEvents then
                    btn:UnregisterAllEvents()
                end
                btn:Hide()
                btn:SetParent(nil)
            end
            AB.Buttons[btn.rexBaseSlot or btn.slot] = nil
        end
        oldBar.buttons = nil
        AB.Bars[barKey] = nil
    end

    local barWidth =
        (cfg.buttonSize * cfg.slots)
        + (cfg.spacing   * (cfg.slots - 1))

    local bar = CreateFrame(
        "Frame",
        "RexUI_" .. barKey,
        UIParent,
        "SecureHandlerStateTemplate"
    )

    bar:SetSize(barWidth, cfg.buttonSize)
    bar:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)
    bar:SetScale(cfg.scale)
    bar:SetAlpha(cfg.alpha)
    bar:SetFrameStrata("MEDIUM")
    if AB.StyleBarBackdrop then AB:StyleBarBackdrop(bar) end

    bar.buttons = {}
    bar.rexBarKey = barKey

    local flyoutHandler
    if UseCustomFlyout and LAB then
        pcall(function()
            if not LAB.flyoutHandler then
                local dummy = LAB:CreateButton(1, "RexUI_FlyoutDummyBtn", UIParent)
                if dummy then
                    dummy:SetScale(0.001)
                    dummy:SetAlpha(0)
                    dummy:Hide()
                end
            end
            flyoutHandler = LAB.flyoutHandler
        end)
    end

    if UseCustomFlyout and flyoutHandler and bar.SetFrameRef then
        bar:SetFrameRef("flyoutHandler", flyoutHandler)
    end

    -- Like ElvUI, create the complete secure button set once and only control
    -- how many buttons are visible in LayoutBar().  Creating only cfg.slots
    -- made a bar impossible to grow after login without a UI reload.
    for i = 1, BUTTONS_PER_PAGE do

        local slot = slotOffset + i
        -- Flyout-Richtung anhand der echten Bildschirmposition bestimmen
        -- cfg.y allein reicht nicht – Bar am unteren Rand muss nach UP öffnen
        local flyoutDirection = "UP"
        if bar and bar.GetBottom then
            local barBottom = bar:GetBottom() or 0
            local screenHeight = UIParent:GetHeight() or 768
            -- Wenn Bar in der oberen Hälfte → nach DOWN, sonst → nach UP
            if barBottom > screenHeight * 0.5 then
                flyoutDirection = "DOWN"
            end
        elseif cfg.y and cfg.y > (UIParent:GetHeight() or 768) * 0.5 then
            flyoutDirection = "DOWN"
        end

        local buttonName = "RexUI_" .. barKey .. "Button" .. i
        local btn
        if LAB then
            btn = LAB:CreateButton(slot, buttonName, bar, {
                flyoutDirection = flyoutDirection,
                clickOnDown = GetUseOnKeyDown(),
                targetReticle = true,
                spellCastVFX = false,
                showGrid = true,
                hideElements = {
                    hotkey = true,
                    macro = true,
                    count = true,
                },
            })
        else
            btn = CreateFrame(
                "CheckButton",
                buttonName,
                bar,
                "ActionBarButtonTemplate, SecureActionButtonTemplate"
            )
            DisableNativeActionButtonUpdates(btn)
        end

        btn:HookScript("OnEnter", function(self)
            local tooltipSlot = GetButtonActionSlot(self)
            if tooltipSlot then
                GameTooltip_SetDefaultAnchor(GameTooltip, self)
                GameTooltip:SetAction(tooltipSlot)
                GameTooltip:Show()
            end
        end)
        btn:HookScript("OnLeave", function()
            GameTooltip_Hide()
        end)
        btn:SetSize(cfg.buttonSize, cfg.buttonSize)
        if btn.SetHitRectInsets then
            btn:SetHitRectInsets(0, 0, 0, 0)
        end
        RegisterActionButtonClicks(btn, slot)
        ApplySecureCastAttributes(btn)
        DisableActionButtonDrag(btn)
        btn:SetAttribute("type",   "action")
        btn:SetAttribute("action", slot)
        if IsLABButton(btn) then
            if barKey ~= "Bar1" then
                btn:SetState(0, "action", slot)
            end
            SetupLABCombatDragLock(btn)
            UpdateLABDragLock(btn)
        end
        btn:SetAttribute("rexIndex", i)
        btn:SetAttribute("flyoutDirection", flyoutDirection)
        if barKey == "Bar1" then
            ConfigureBar1ButtonStates(btn, i)
        end
        -- Forever RestrictedExecution cannot compile tonumber in _childupdate.
        -- Bar1 paging uses RegisterAttributeDriver instead (States.lua).
        if not UseForeverClient() then
            if barKey == "Bar1" then
                btn:SetAttributeNoHandler(
                    "_childupdate-rex-page",
                    ("local page = tonumber(message) or 1; local slot = %d + (page - 1) * %d; self:SetAttribute('state', page); self:SetAttribute('type', 'action'); self:SetAttribute('action', slot); if self:GetAttribute('UpdateState') then self:RunAttribute('UpdateState', page) end"):format(
                        i,
                        BUTTONS_PER_PAGE
                    )
                )
            else
                btn:SetAttributeNoHandler(
                    "_childupdate-rex-page",
                    ("local page = tonumber(message) or 1; local slot = %d + (page - 1) * %d; self:SetAttribute('type', 'action'); self:SetAttribute('action', slot); self:SetAttribute('labtype-0', 'action'); self:SetAttribute('labaction-0', slot); if self:GetAttribute('UpdateState') then self:RunAttribute('UpdateState', self:GetAttribute('state')) end"):format(
                        i,
                        BUTTONS_PER_PAGE
                    )
                )
            end
        end

        if UseCustomFlyout then
            btn:SetAttribute("LABUseCustomFlyout", true)
        end

        btn:SetID(0)

        btn.slot = slot
        btn.action = slot
        btn.rexBaseSlot = slot
        btn.rexIndex = i
        btn.rexBarKey = barKey
        ConfigureLABUsability(btn)
        btn.popupOffset = 4
        btn.popupCrossAxisSize = cfg.buttonSize + 12
        DisableNativeActionButtonUpdates(btn)
        DisableActionButtonDrag(btn)

        if not btn.GetPopupDirection then
            btn.GetPopupDirection = function(self)
                -- Dynamisch berechnen basierend auf aktueller Bildschirmposition
                local bottom = self:GetBottom() or 0
                local screenHeight = UIParent:GetHeight() or 768
                if bottom > screenHeight * 0.5 then
                    return "DOWN"
                end
                return "UP"
            end
        end

        btn.RexUIUpdateFlyoutArrow = function(self)
            UpdateFlyoutArrow(self)
        end

        if barKey == "Bar1" then
            if bar.SetFrameRef then
                bar:SetFrameRef("button" .. i, btn)
            elseif SecureHandlerSetFrameRef then
                SecureHandlerSetFrameRef(bar, "button" .. i, btn)
            end
        end

        if IsLABButton(btn) and btn.icon then
            btn.RexUIIcon = nil
        else
            btn.RexUIIcon =
                btn.RexUIIcon
                or btn:CreateTexture(nil, "ARTWORK", nil, 1)

            btn.icon = btn.RexUIIcon
        end
        local iconInset = cfg.iconInset or 2
        local iconCrop = cfg.iconCrop or 0.07
        btn.icon:ClearAllPoints()
        btn.icon:SetDrawLayer("ARTWORK", 1)
        btn.icon:SetPoint("TOPLEFT",     btn, "TOPLEFT",      iconInset, -iconInset)
        btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -iconInset,  iconInset)
        btn.icon:SetTexCoord(iconCrop, 1 - iconCrop, iconCrop, 1 - iconCrop)
        btn.icon:SetAlpha(1)
        btn.icon:Show()
        HideNativeIconRegions(btn)
        HideNativeCount(btn)
        HideNativeName(btn)

        if AB.Cooldowns and AB.Cooldowns.Create then
            AB.Cooldowns:Create(btn)
        end

        AB:StyleButton(btn, cfg)
        AB:EnableButtonDragDrop(btn)
        AB:EnableButtonFeedback(btn)
        if AB.Cooldowns and AB.Cooldowns.Style then
            AB.Cooldowns:Style(btn, cfg)
        end
        if AB.UpdateButtonOverlays then
            AB:UpdateButtonOverlays(btn, cfg)
        end

        UpdateFlyoutArrow(btn)

        if UseCustomFlyout and flyoutHandler and not IsLABButton(btn) then
            SecureHandlerSetFrameRef(bar, "flyoutHandler", flyoutHandler)
            SecureHandlerWrapScript(btn, "OnClick", bar, [[
                local type, action = GetActionInfo(self:GetAttribute("action"))
                if type == "flyout" then
                    local fh = owner:GetFrameRef("flyoutHandler")
                    if fh and not down then
                        fh:SetAttribute("flyoutParentHandle", self)
                        fh:RunAttribute("HandleFlyout", action)
                    end
                    return false
                end
                local fh = owner:GetFrameRef("flyoutHandler")
                if fh then
                    fh:Hide()
                end
            ]])
        end

        bar.buttons[i] = btn
        AB.Buttons[slot] = btn
    end

    if UseCustomFlyout and flyoutHandler then
        if bar.SetFrameRef then
            bar:SetFrameRef("flyoutHandler", flyoutHandler)
        elseif SecureHandlerSetFrameRef then
            pcall(SecureHandlerSetFrameRef, bar, "flyoutHandler", flyoutHandler)
        end
    end

    AB.Bars[barKey] = bar

    if AB.FinalizeBar then
        AB:FinalizeBar(barKey, cfg)
    end

    return bar
end

if UseCustomFlyout and LAB then
    local function EnsureLABFlyoutHandler()
        if InCombatLockdown() then return nil end
        if LAB.flyoutHandler then return LAB.flyoutHandler end

        local ok, btn = pcall(function()
            return LAB:CreateButton(1, "RexUI_FlyoutDummyBtn", UIParent)
        end)
        if ok and btn then
            btn:SetScale(0.001)
            btn:SetAlpha(0)
            btn:Hide()
        end

        return LAB.flyoutHandler
    end

    local function SyncAndDiscover()
        if InCombatLockdown() then return end
        local fh = EnsureLABFlyoutHandler()
        if not fh then return end

        if LAB.DiscoverFlyoutSpells then
            pcall(LAB.DiscoverFlyoutSpells, LAB)
        end
        if LAB.UpdateFlyoutHandlerScripts then
            pcall(LAB.UpdateFlyoutHandlerScripts, LAB)
        end

        fh:Hide()

        for _, bar in pairs(AB.Bars or {}) do
            if bar.SetFrameRef then
                pcall(bar.SetFrameRef, bar, "flyoutHandler", fh)
            elseif SecureHandlerSetFrameRef then
                pcall(SecureHandlerSetFrameRef, bar, "flyoutHandler", fh)
            end
        end
    end

    local f = CreateFrame("Frame")
    local function RegisterEventSafe(event)
        pcall(f.RegisterEvent, f, event)
    end

    RegisterEventSafe("PLAYER_LOGIN")
    RegisterEventSafe("SPELLS_CHANGED")
    RegisterEventSafe("SPELL_FLYOUT_UPDATE")
    RegisterEventSafe("LEARNED_SPELL_IN_TAB")
    RegisterEventSafe("LEARNED_SPELL_IN_SKILL_LINE")
    RegisterEventSafe("COMPANION_UPDATE")
    RegisterEventSafe("PET_STABLE_UPDATE")
    RegisterEventSafe("MOUNT_JOURNAL_USABILITY_CHANGED")
    f:SetScript("OnEvent", function(self, event)
        C_Timer.After(0.5, SyncAndDiscover)
    end)
    C_Timer.After(1, SyncAndDiscover)
end

function AB:UpdateButton(btn)

    if not btn then return end

    local name = btn:GetName()
    if name and (
        name:find("Override")
        or name:find("Vehicle")
        or name:find("Possess")
        or name:find("ExtraAction")
    ) then
        return
    end

    local slot = GetButtonActionSlot(btn)
    if not slot then return end
    btn.slot = slot
    btn.action = slot

    HideNativeIconRegions(btn)
    HideNativeCount(btn)
    HideNativeName(btn)
    local hasAction = HasActionSafe(slot)
    if not hasAction then
        ClearEmptySlotVisuals(btn)
        if AB.Cooldowns and AB.Cooldowns.ClearButton then
            AB.Cooldowns:ClearButton(btn)
        end
    end

    local ok, actionType, actionId, subType = true, nil, nil, nil
    if hasAction then
        ok, actionType, actionId, subType = pcall(function()
            return GetActionInfo(slot)
        end)
        if not ok then
            actionType, actionId, subType = nil, nil, nil
        end
    end

    if IsLABButton(btn) and btn.config then
        local spellID
        if actionType == "spell" then
            spellID = actionId
        elseif actionType == "macro" and GetMacroSpell then
            spellID = GetMacroSpell(actionId)
        end

        -- RexUI uses its own cooldown/cast feedback. Disable LibActionButton's
        -- native spell-cast VFX globally; otherwise cast-time spells (e.g. Wrath)
        -- draw the large yellow border/glow around the action button.
        local showCastVFX = false
        if btn.config.spellCastVFX ~= showCastVFX then
            btn.config.spellCastVFX = showCastVFX
            if btn.SpellCastAnimFrame then
                btn.SpellCastAnimFrame:Hide()
            end
            if btn.UpdateConfig then
                btn:UpdateConfig(btn.config)
            end
        elseif btn.SpellCastAnimFrame and btn.SpellCastAnimFrame:IsShown() then
            btn.SpellCastAnimFrame:Hide()
        end
    end

    if not InCombatLockdown() then
        RegisterActionButtonClicks(btn, slot)
        DisableActionButtonDrag(btn)
        btn:SetAttribute("type", "action")
        btn:SetAttribute("action", slot)
        if IsLABButton(btn) then
            if btn.rexBarKey == "Bar1" then
                ConfigureBar1ButtonStates(btn, btn.rexIndex or (btn.GetAttribute and btn:GetAttribute("rexIndex")))
            else
                btn:SetState(0, "action", slot)
            end
            UpdateLABDragLock(btn)
            ApplySecureCastAttributes(btn)
            if btn.UpdateAction then
                btn:UpdateAction()
            end
        end
        DisableNativeActionButtonUpdates(btn)
    end

    local texture = hasAction and GetActionTextureSafe(slot, actionType, actionId) or nil

    if btn.emptySlot then
        btn.emptySlot:SetShown(not texture)
    end

    if btn.icon then
        local cfg = btn.rexBarKey and AB:GetConfig(btn.rexBarKey) or AB:GetConfig("Defaults")
        local iconInset = cfg.iconInset or 2
        local iconCrop = cfg.iconCrop or 0.07
        if not InCombatLockdown() and not btn.rexIconPointsSet then
            btn.icon:ClearAllPoints()
            btn.icon:SetPoint("TOPLEFT",     btn, "TOPLEFT",      iconInset, -iconInset)
            btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -iconInset,  iconInset)
            btn.rexIconPointsSet = true
        end
        btn.icon:SetDrawLayer("ARTWORK", 1)
        btn.icon:SetTexCoord(iconCrop, 1 - iconCrop, iconCrop, 1 - iconCrop)
        if not IsLABButton(btn) then
            btn.icon:SetVertexColor(1, 1, 1, 1)
        end
        btn.icon:Show()

        if texture then
            btn.icon:SetTexture(texture)
            btn.icon:SetAlpha(1)
            btn.icon:Show()
        else
            btn.icon:SetTexture(nil)
            btn.icon:SetAlpha(0)
            btn.icon:Hide()
        end
    end

    SetButtonActionTint(btn)

    UpdateButtonCountText(btn)

    HideNativeHotkey(btn)
    HideNativeName(btn)

    if btn.hotkeyText then
        local key = GetButtonBindingKey(btn)
        local text = FormatBindingText(key)
        if btn.hotkeyText:GetText() ~= text then
            btn.hotkeyText:SetText(text)
        end
    end

    if AB.UpdateButtonOverlays and not InCombatLockdown() then
        local cfg = btn.rexBarKey and AB:GetConfig(btn.rexBarKey) or AB:GetConfig("Defaults")
        AB:UpdateButtonOverlays(btn, cfg)
    end

    UpdateButtonCheckedState(btn, slot, hasAction)

    if not InCombatLockdown() then
        UpdateFlyoutArrow(btn)
    end
end

function AB:UpdateButtonCombatVisuals(btn)
    if not btn then return end

    local foreverBar1 = UseForeverClient() and btn.rexBarKey == "Bar1"
    -- LAB UpdateAction reads labaction-<state>. Forever pages via AttributeDriver
    -- on action; calling UpdateAction in combat paints the previous form's icons.
    if IsLABButton(btn) and btn.UpdateAction and not foreverBar1 then
        btn:UpdateAction()
    end

    HideNativeCount(btn)
    HideNativeHotkey(btn)
    HideNativeName(btn)

    local slot
    if foreverBar1 and AB.ResolveForeverBar1Slot then
        slot = AB:ResolveForeverBar1Slot(btn)
    end
    slot = slot
        or btn._state_action
        or (btn.GetAttribute and btn:GetAttribute("action"))
        or btn.slot
    if not slot then return end

    btn.slot = slot
    btn.action = slot

    local hasAction = HasActionSafe(slot)
    local texture
    if hasAction then
        local ok, actionType, actionId = pcall(function()
            return GetActionInfo(slot)
        end)
        texture = GetActionTextureSafe(slot, ok and actionType or nil, ok and actionId or nil)
    end

    if btn.icon then
        local cfg = btn.rexBarKey and AB:GetConfig(btn.rexBarKey) or AB:GetConfig("Defaults")
        local iconCrop = cfg.iconCrop or 0.07
        btn.icon:SetDrawLayer("ARTWORK", 1)
        btn.icon:SetTexCoord(iconCrop, 1 - iconCrop, iconCrop, 1 - iconCrop)

        if btn.emptySlot then
            btn.emptySlot:SetShown(not texture)
        end

        if texture then
            btn.icon:SetTexture(texture)
            btn.icon:SetAlpha(1)
            btn.icon:Show()
        else
            btn.icon:SetTexture(nil)
            btn.icon:SetAlpha(0)
            btn.icon:Hide()
        end
    end

    SetButtonActionTint(btn)

    -- Display counts (e.g. Blood DK Bone Shield) can change while in combat.
    -- The normal UpdateButton() path already refreshes countText, but combat
    -- dirty flushes use UpdateButtonCombatVisuals(), so refresh it here too.
    UpdateButtonCountText(btn)

    UpdateButtonCheckedState(btn, slot, hasAction)
end

function AB:UpdateAllButtons()
    local seen = {}

    for _, bar in pairs(AB.Bars or {}) do
        for _, btn in ipairs(bar.buttons or {}) do
            if btn and not seen[btn] then
                seen[btn] = true
                AB:UpdateButton(btn)
            end
        end
    end

    for _, btn in pairs(AB.Buttons or {}) do
        if btn and not seen[btn] then
            seen[btn] = true
            AB:UpdateButton(btn)
        end
    end
end

function AB:GetBarVisibilityDriver(barKey, enabled)
    if enabled == false then
        return "hide"
    end

    if barKey == "Bar1" then
        return "show"
    elseif barKey == "PetBar" then
        return "[petbattle] hide; [novehicleui,pet,nooverridebar,nopossessbar] show; hide"
    elseif barKey == "StanceBar" then
        return "[petbattle][overridebar][vehicleui][possessbar] hide; show"
    end

    return "[petbattle][overridebar][vehicleui][possessbar] hide; show"
end

function AB:ApplyBarVisibility(barKey, bar, enabled)
    if not bar then return end

    if RegisterStateDriver then
        RegisterStateDriver(bar, "visibility", self:GetBarVisibilityDriver(barKey, enabled))
    else
        bar:SetShown(enabled ~= false)
    end
end

function AB:FinalizeBar(barKey, cfg)
    if not barKey then return end

    local bar = AB.Bars and AB.Bars[barKey]
    if not bar then return end

    cfg = cfg or AB:GetConfig(barKey)
    local enabled = cfg.enabled ~= false

    AB:ApplyBarVisibility(barKey, bar, enabled)
    if not enabled then return end

    bar:ClearAllPoints()
    bar:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)
    bar:SetScale(cfg.scale or 1)
    bar:SetFrameStrata(cfg.frameStrata or "MEDIUM")
    bar:EnableMouse(cfg.hidden ~= true)

    if AB.LayoutBar and bar.buttons then
        AB:LayoutBar(barKey)
    elseif bar.buttons then
        local size = cfg.buttonSize or 36
        local spacing = cfg.spacing or 3
        local slots = cfg.slots or #bar.buttons
        bar:SetSize((size * slots) + (spacing * math.max(0, slots - 1)), size)
    end

    for _, btn in ipairs(bar.buttons or {}) do
        btn:EnableMouse(cfg.hidden ~= true)

        if AB.StyleButton then
            AB:StyleButton(btn, cfg)
        end
        if AB.Cooldowns and AB.Cooldowns.Style then
            AB.Cooldowns:Style(btn, cfg)
        end
        if AB.UpdateButtonOverlays then
            AB:UpdateButtonOverlays(btn, cfg)
        end
    end

    if cfg.mouseover then
        if AB.Mouseover and AB.Mouseover.Apply then
            AB.Mouseover:Apply(bar)
        end
    else
        if AB.Mouseover and AB.Mouseover.Remove then
            AB.Mouseover:Remove(bar)
        end
        bar:SetAlpha(cfg.hidden == true and 0 or (cfg.alpha or 1))
    end

    if cfg.hidden == true then bar:SetAlpha(0) end

    for _, btn in ipairs(bar.buttons or {}) do
        AB:UpdateButton(btn)
    end
end

function AB:UpdateBar(barKey)

    if not barKey then return end

    if InCombatLockdown() then
        AB:RunOutOfCombat("UpdateBar_" .. barKey, function()
            AB:UpdateBar(barKey)
        end)
        return
    end

    local bar = AB.Bars[barKey]
    if AB.InvalidateConfigCache then
        AB:InvalidateConfigCache(barKey)
    end
    local cfg = AB:GetConfig(barKey)

    if barKey == "PetBar" or barKey == "StanceBar" then
        local module
        if barKey == "PetBar" then
            module = AB.PetBar
        else
            module = AB.StanceBar
        end

        if not bar and cfg.enabled ~= false and module and module.Create then
            module:Create()
            bar = AB.Bars[barKey]
        end

        if bar then
            AB:ApplyBarVisibility(barKey, bar, cfg.enabled ~= false)
            bar:ClearAllPoints()
            bar:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)
            bar:SetScale(cfg.scale or 1)

            if not cfg.mouseover then
                bar:SetAlpha(cfg.hidden == true and 0 or (cfg.alpha or 1))
            end
            if cfg.hidden == true then bar:SetAlpha(0) end
            bar:EnableMouse(cfg.hidden ~= true)
            for _, btn in ipairs(bar.buttons or {}) do btn:EnableMouse(cfg.hidden ~= true) end

            if cfg.mouseover then
                if AB.Mouseover and AB.Mouseover.Apply then
                    AB.Mouseover:Apply(bar)
                end
            elseif AB.Mouseover and AB.Mouseover.Remove then
                AB.Mouseover:Remove(bar)
            end
        end

        if cfg.enabled ~= false and module and module.Update then
            module:Update()
        end

        return
    end

    if not bar then

        if cfg.enabled ~= false then

            local offset = 0

            for _, entry in ipairs(AB.BarRegistry or {}) do
                if entry.key == barKey then
                    offset = entry.offset
                    break
                end
            end

            AB:CreateBar(barKey, cfg, offset)
        end

        return
    end

    AB:FinalizeBar(barKey, cfg)
end
