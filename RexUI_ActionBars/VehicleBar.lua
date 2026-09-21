-- ============================================================
-- RexUI_ActionBars\VehicleBar.lua
-- Vehicle/Override action slots are owned by Bar1 secure paging.
-- The leave button is a separate protected action. RexUI keeps its own
-- visible skin/position, but securely forwards the click to Blizzard's native vehicle-leave button whenever that button is available.
-- ============================================================

local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI
local AB = RexUI and RexUI.ActionBars
if not AB then return end

AB.VehicleBar = AB.VehicleBar or {}
local VB = AB.VehicleBar

function VB:GetBlizzardLeaveButton()
    -- Retail has moved the vehicle leave button between action-bar containers
    -- over time. Prefer explicit Blizzard references and only fall back to
    -- well-known globals. We never reparent or modify the native secure button.
    local candidates = {
        _G.MainMenuBarVehicleLeaveButton,
        _G.VehicleLeaveButton,
        _G.MainActionBar and (_G.MainActionBar.vehicleLeaveButton or _G.MainActionBar.VehicleLeaveButton),
        _G.OverrideActionBar and (_G.OverrideActionBar.LeaveButton or _G.OverrideActionBar.leaveButton),
        _G.OverrideActionBarLeaveFrame and (_G.OverrideActionBarLeaveFrame.LeaveButton or _G.OverrideActionBarLeaveFrame.leaveButton),
    }

    for _, candidate in ipairs(candidates) do
        if candidate and candidate ~= self.button and candidate.Click then
            return candidate
        end
    end

    -- Some Blizzard versions expose the leave control as the frame itself.
    local leaveFrame = _G.OverrideActionBarLeaveFrame
    if leaveFrame and leaveFrame ~= self.button and leaveFrame.Click then
        return leaveFrame
    end
end

function VB:ApplySecureAction()
    local button = self.button
    if not button or (InCombatLockdown and InCombatLockdown()) then return end

    local native = self:GetBlizzardLeaveButton()
    if native then
        -- Secure click forwarding preserves Blizzard's own leave-vehicle logic
        -- for vehicle, override and possess states.
        button:SetAttribute("type", "click")
        button:SetAttribute("clickbutton", native)
        self.nativeButton = native
    else
        -- Defensive fallback for unusual load orders. PLAYER_ENTERING_WORLD and
        -- vehicle events call this again once Blizzard's action bar is ready.
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", "/leavevehicle")
        button:SetAttribute("clickbutton", nil)
        self.nativeButton = nil
    end
end

function VB:ApplyClickRegistration()
    local button = self.button
    if not button or (InCombatLockdown and InCombatLockdown()) then return end

    local useOnKeyDown = AB.GetUseOnKeyDown and AB:GetUseOnKeyDown()
        or not GetCVarBool or GetCVarBool("ActionButtonUseKeyDown") == true
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("useOnKeyDown", useOnKeyDown)
    self:ApplySecureAction()
end

AB.Config["VehicleBar"] = AB.Config["VehicleBar"] or {
    buttonSize = 36,
    iconInset = 2,
    showHotkey = false,
    showCount = false,
    showCooldown = false,
}

local UPDATE_EVENTS = {
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "UPDATE_BONUS_ACTIONBAR",
    "UPDATE_OVERRIDE_ACTIONBAR",
    "UPDATE_VEHICLE_ACTIONBAR",
    "UNIT_ENTERED_VEHICLE",
    "UNIT_EXITED_VEHICLE",
    "VEHICLE_UPDATE",
    "UPDATE_POSSESS_BAR",
    "PLAYER_CONTROL_GAINED",
    "PLAYER_CONTROL_LOST",
}

function VB:IsActive()
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

function VB:Update()
    if InCombatLockdown and InCombatLockdown() then
        if AB.RunOutOfCombat then
            AB:RunOutOfCombat("VehicleBar_Update", function()
                VB:Update()
            end)
        end
        return
    end

    if not self.button then
        return
    end

    self:ApplySecureAction()
    self:Layout()
end

function VB:Layout()
    local button = self.button
    if not button then return end

    if InCombatLockdown and InCombatLockdown() then
        if AB.RunOutOfCombat then
            AB:RunOutOfCombat("VehicleBar_Layout", function()
                VB:Layout()
            end)
        end
        return
    end

    button:ClearAllPoints()

    local bar1 = AB.Bars and AB.Bars.Bar1
    if bar1 then
        button:SetPoint("LEFT", bar1, "RIGHT", 8, 0)
    else
        button:SetPoint("BOTTOM", UIParent, "BOTTOM", 260, 120)
    end
end

function VB:CreateLeaveButton()
    if self.button or (InCombatLockdown and InCombatLockdown()) then
        return self.button
    end

    local cfg = AB:GetConfig("VehicleBar")
    local button = CreateFrame("Button", "RexUIVehicleLeaveButton", UIParent, "SecureActionButtonTemplate")
    button:SetSize(cfg.buttonSize or 36, cfg.buttonSize or 36)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(50)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("useOnKeyDown", AB.GetUseOnKeyDown and AB:GetUseOnKeyDown()
        or not GetCVarBool or GetCVarBool("ActionButtonUseKeyDown") == true)
    if button.SetHitRectInsets then
        button:SetHitRectInsets(0, 0, 0, 0)
    end
    -- The secure action is bound below to Blizzard's native leave button.
    -- A macro is used only as a defensive fallback if Blizzard's button has
    -- not been created yet.

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.08, 0.08, 0.9)
    button.bg = bg

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", -4, 4)
    icon:SetTexture("Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up")
    button.icon = icon
    button.rexBarKey = "VehicleBar"

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER", 0, 0)
    text:SetText("X")
    text:SetTextColor(1, 0.25, 0.2)
    button.text = text

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(_G.LEAVE_VEHICLE or RexUI:LocalizeText("Fahrzeug verlassen"))
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Reuse the same pixel border, cropped icon and click feedback as every
    -- other RexUI action bar button.  This is visual-only; the secure vehicle
    -- action and Blizzard visibility driver remain untouched.
    if AB.StyleButton then
        AB:StyleButton(button, cfg)
    end
    if AB.EnableButtonFeedback then
        AB:EnableButtonFeedback(button)
    end

    if RegisterStateDriver then
        -- Do not rely only on the three action-bar states. Some quest vehicles/possessions
        -- expose a vehicle unit or CanExitVehicle without enabling vehicleui/overridebar/possessbar.
        -- The broader secure driver keeps the button available in those cases, including
        -- quest-specific vehicle states, while remaining combat-safe.
        RegisterStateDriver(button, "visibility", "[petbattle] hide; [canexitvehicle][vehicleui][overridebar][possessbar][@vehicle,exists] show; hide")
    else
        button:Hide()
    end

    self.button = button
    self:ApplyClickRegistration()
    self:Layout()

    return button
end

function VB:Initialize()
    if self.initialized then return end
    self.initialized = true

    local eventFrame = CreateFrame("Frame")
    self.eventFrame = eventFrame

    for _, event in ipairs(UPDATE_EVENTS) do
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        if unit and unit ~= "player" then return end

        if not VB.button then
            VB:CreateLeaveButton()
        end

        VB:Update()

        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(0.2, function()
                VB:CreateLeaveButton()
                VB:Update()
            end)
        end
    end)

    C_Timer.After(0, function()
        VB:CreateLeaveButton()
        VB:Update()
    end)
end

VB:Initialize()
