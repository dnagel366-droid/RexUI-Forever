-- ============================================================
-- RexUI_ActionBars\QuickKeybind.lua
-- Blizzard Quick Keybind integration for RexUI-owned action buttons.
-- Mirrors the proven EllesmereUI approach: native binding commandName +
-- QuickKeybindButtonTemplateMixin on each visible RexUI action button.
-- ============================================================

local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI
if not RexUI then return end

RexUI.ActionBars = RexUI.ActionBars or {}
local AB = RexUI.ActionBars

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

local initialized = setmetatable({}, { __mode = "k" })
local qkbOpen = false
local hiddenBarState = {}

local function GetProfile()
    return RexUI and RexUI.db and RexUI.db.profile
end

local function IsKeybindingEnabled()
    local p = GetProfile()
    if not p then return true end
    p.actionbars = p.actionbars or {}
    return p.actionbars.keybindingEnabled ~= false
end

function AB:IsKeybindingEnabled()
    return IsKeybindingEnabled()
end
-- /kb is launched directly from gameplay. Blizzard's QuickKeybind frame can
-- restore the Settings/Game Menu stack when it closes. Remember what was open
-- before RexUI started QKB so we only dismiss panels that QKB itself exposed.
local launchState = { active = false, settingsShown = false, gameMenuShown = false }

local function IsShown(frame)
    return frame and frame.IsShown and frame:IsShown() or false
end

local function RestoreGameplayAfterQuickKeybind()
    if not launchState.active then return end
    local settingsWasShown = launchState.settingsShown
    local gameMenuWasShown = launchState.gameMenuShown
    launchState.active = false

    -- Let Blizzard finish QuickKeybind's own close handler first, then remove
    -- only menu layers that were not visible when /kb was invoked.
    C_Timer.After(0, function()
        local settings = _G.SettingsPanel
        if settings and IsShown(settings) and not settingsWasShown then
            if HideUIPanel then HideUIPanel(settings) else settings:Hide() end
        end
        local gameMenu = _G.GameMenuFrame
        if gameMenu and IsShown(gameMenu) and not gameMenuWasShown then
            if HideUIPanel then HideUIPanel(gameMenu) else gameMenu:Hide() end
        end
    end)
end

local function GetCommandName(btn)
    if not btn then return nil end
    local prefix = BindingNamePrefixes[btn.rexBarKey]
    local index = btn.rexIndex or (btn.GetID and btn:GetID())
    if prefix and index and index > 0 then
        return prefix .. index
    end
    return nil
end

local function EnsureHighlight(btn)
    if btn.QuickKeybindHighlightTexture then return end
    local tex = btn:CreateTexture(nil, "OVERLAY", nil, 7)
    tex:SetAllPoints(btn)
    tex:SetColorTexture(1, 1, 1, 0.18)
    tex:Hide()
    btn.QuickKeybindHighlightTexture = tex
end

local function InitializeButton(btn)
    if not btn or initialized[btn] then return end
    local command = GetCommandName(btn)
    if not command then return end

    btn.commandName = command
    EnsureHighlight(btn)

    if QuickKeybindButtonTemplateMixin then
        Mixin(btn, QuickKeybindButtonTemplateMixin)
        if btn.QuickKeybindButtonOnShow then btn:HookScript("OnShow", btn.QuickKeybindButtonOnShow) end
        if btn.QuickKeybindButtonOnHide then btn:HookScript("OnHide", btn.QuickKeybindButtonOnHide) end
        if btn.QuickKeybindButtonOnClick then btn:HookScript("OnClick", btn.QuickKeybindButtonOnClick) end
        if btn.QuickKeybindButtonOnEnter then btn:HookScript("OnEnter", btn.QuickKeybindButtonOnEnter) end
        if btn.QuickKeybindButtonOnLeave then btn:HookScript("OnLeave", btn.QuickKeybindButtonOnLeave) end
        initialized[btn] = true
    end
end

local function ForEachButton(fn)
    for _, bar in pairs(AB.Bars or {}) do
        if bar and bar.buttons then
            for _, btn in ipairs(bar.buttons) do
                if btn then fn(btn) end
            end
        end
    end
end

local function SetMode(show)
    qkbOpen = show and true or false

    -- Like EllesmereUI, temporarily surface bars that are enabled but normally
    -- hidden. Truly disabled bars stay disabled and are never exposed.
    for barKey, bar in pairs(AB.Bars or {}) do
        local cfg = AB.GetConfig and AB:GetConfig(barKey)
        if bar and cfg and cfg.enabled ~= false then
            if qkbOpen then
                hiddenBarState[bar] = { alpha = bar:GetAlpha(), hidden = cfg.hidden == true }
                if cfg.hidden == true then
                    bar:SetAlpha(1)
                    bar:EnableMouse(true)
                    for _, btn in ipairs(bar.buttons or {}) do btn:EnableMouse(true) end
                end
            else
                local old = hiddenBarState[bar]
                if old then
                    bar:SetAlpha(old.hidden and 0 or (old.alpha or cfg.alpha or 1))
                    if old.hidden then
                        bar:EnableMouse(false)
                        for _, btn in ipairs(bar.buttons or {}) do btn:EnableMouse(false) end
                    end
                    hiddenBarState[bar] = nil
                end
            end
        end
    end

    ForEachButton(function(btn)
        InitializeButton(btn)
        if btn.commandName then
            if btn.DoModeChange then
                pcall(btn.DoModeChange, btn, qkbOpen)
            elseif btn.QuickKeybindHighlightTexture then
                btn.QuickKeybindHighlightTexture:SetShown(qkbOpen)
            end
        end
    end)
end

local hookInstalled = false
local function InstallFrameHooks()
    if hookInstalled or not QuickKeybindFrame then return false end
    hookInstalled = true
    QuickKeybindFrame:HookScript("OnShow", function() SetMode(true) end)
    QuickKeybindFrame:HookScript("OnHide", function()
        SetMode(false)
        RestoreGameplayAfterQuickKeybind()
        C_Timer.After(0, function() if AB.ApplyKeybindRouting then AB:ApplyKeybindRouting() end end)
    end)
    return true
end

local function EnsureBindingFrames()
    if not AB.BindingOwner then
        AB.BindingOwner = CreateFrame("Frame", "RexUI_ActionBarBindingOwner", UIParent)
    end
    if not AB.BindingBlocker then
        AB.BindingBlocker = CreateFrame("Button", "RexUI_ActionBarBindingBlocker", UIParent, "SecureActionButtonTemplate")
        AB.BindingBlocker:SetSize(1, 1)
        AB.BindingBlocker:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -100, -100)
        AB.BindingBlocker:SetAlpha(0)
        AB.BindingBlocker:EnableMouse(false)
        AB.BindingBlocker:Show()
    end
end

function AB:ApplyKeybindRouting()
    if InCombatLockdown() then return end
    EnsureBindingFrames()
    local owner = AB.BindingOwner
    ClearOverrideBindings(owner)

    local enabled = IsKeybindingEnabled()
    local seen = {}
    local function route(bindingName, buttonName)
        for _, key in ipairs({ GetBindingKey(bindingName) }) do
            if key and not seen[key] then
                seen[key] = true
                SetOverrideBindingClick(owner, false, key, enabled and buttonName or AB.BindingBlocker:GetName(), "LeftButton")
            end
        end
    end

    for barKey, bar in pairs(AB.Bars or {}) do
        local prefix = BindingNamePrefixes[barKey]
        local cfg = AB.GetConfig and AB:GetConfig(barKey)
        if prefix and bar and bar.buttons and cfg and cfg.enabled ~= false then
            for i, btn in ipairs(bar.buttons) do
                local name = btn and btn:GetName()
                if name then
                    route(prefix .. i, name)
                    if barKey == "Bar1" then
                        route("OVERRIDEACTIONBUTTON" .. i, name)
                        route("VEHICLEACTIONBUTTON" .. i, name)
                        route("POSSESSBUTTON" .. i, name)
                    end
                end
            end
        end
    end
end

function AB:SetKeybindingEnabled(value)
    local p = GetProfile()
    if not p then return end
    p.actionbars = p.actionbars or {}
    p.actionbars.keybindingEnabled = value and true or false
    self:ApplyKeybindRouting()
end

function AB:OpenQuickKeybind()
    if not IsKeybindingEnabled() then
        if UIErrorsFrame then UIErrorsFrame:AddMessage("RexUI: Tastenbelegung ist deaktiviert.", 1, 0.82, 0.2) end
        return
    end
    if InCombatLockdown() then
        if UIErrorsFrame then UIErrorsFrame:AddMessage("RexUI: Tastaturbelegung ist im Kampf nicht verfügbar.", 1, 0.2, 0.2) end
        return
    end

    if not C_AddOns.IsAddOnLoaded("Blizzard_QuickKeybind") then
        local loaded = C_AddOns.LoadAddOn("Blizzard_QuickKeybind")
        if not loaded then
            print("|cffff3333RexUI:|r Blizzard_QuickKeybind konnte nicht geladen werden.")
            return
        end
    end

    InstallFrameHooks()
    ForEachButton(InitializeButton)

    -- Capture the pre-/kb UI state immediately before showing QKB. This keeps
    -- normal Blizzard Settings usage intact while making the slash-command
    -- flow return straight to gameplay after OK or Cancel.
    launchState.active = true
    launchState.settingsShown = IsShown(_G.SettingsPanel)
    launchState.gameMenuShown = IsShown(_G.GameMenuFrame)

    if QuickKeybindFrame then
        QuickKeybindFrame:Show()
        SetMode(true)
    else
        launchState.active = false
        print("|cffff3333RexUI:|r Quick-Keybind-Fenster ist nicht verfügbar.")
    end
end

SLASH_REXUIQUICKKEYBIND1 = "/kb"
SLASH_REXUIQUICKKEYBIND2 = "/rexkb"
SlashCmdList["REXUIQUICKKEYBIND"] = function()
    AB:OpenQuickKeybind()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addonName)
    if event == "PLAYER_LOGIN" then
        ForEachButton(function(btn)
            btn.commandName = GetCommandName(btn)
        end)
        if AB.ApplyKeybindRouting then AB:ApplyKeybindRouting() end
        if C_AddOns.IsAddOnLoaded("Blizzard_QuickKeybind") then
            InstallFrameHooks()
            ForEachButton(InitializeButton)
        end
    elseif event == "ADDON_LOADED" and addonName == "Blizzard_QuickKeybind" then
        InstallFrameHooks()
        ForEachButton(InitializeButton)
    end
end)
