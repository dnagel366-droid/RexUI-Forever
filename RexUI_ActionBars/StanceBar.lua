-- ============================================================
-- RexUI_ActionBars\StanceBar.lua
-- Eigene Stance Bar - kein Blizzard Frame
-- ============================================================

local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI
local AB    = RexUI and RexUI.ActionBars
if not AB then return end

AB.StanceBar = AB.StanceBar or {}
local SB = AB.StanceBar

local MAX_SLOTS = 10

function SB:ApplyClickRegistration()
    if InCombatLockdown() then return end

    local bar = self.frame
    if not bar then return end

    -- One click edge only. Down+Up cast the stance twice and undoes the form.
    for _, btn in ipairs(bar.buttons or {}) do
        if btn.rexLastClickMode ~= "AnyUp" then
            btn:RegisterForClicks("AnyUp")
            btn.rexLastClickMode = "AnyUp"
        end

        if btn.rexLastUseOnKeyDown ~= false then
            btn:SetAttribute("useOnKeyDown", false)
            btn.rexLastUseOnKeyDown = false
        end
    end
end

local function GetSpellName(spellID)
    if not spellID then return nil end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.name then
            return info.name
        end
    end

    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    end

    if GetSpellInfo then
        return GetSpellInfo(spellID)
    end
end

local function GetShapeshiftSlotInfo(index)
    local v1, v2, v3, v4 = GetShapeshiftFormInfo(index)
    if type(v2) == "string" then
        return v1, v3, v4, nil, v2
    end
    return v1, v2, v3, v4, GetSpellName(v4)
end

-- ============================================================
-- CONFIG
-- ============================================================

AB.Config["StanceBar"] = AB.Config["StanceBar"] or {}

local cfg = AB.Config["StanceBar"]

cfg.enabled    = cfg.enabled    ~= nil and cfg.enabled    or true
cfg.buttonSize = cfg.buttonSize or 30
cfg.spacing    = cfg.spacing    or 3
cfg.scale      = cfg.scale      or 1
cfg.alpha      = cfg.alpha      or 1
cfg.rows       = cfg.rows       or 1
cfg.mouseover  = cfg.mouseover  or false
cfg.vertical   = cfg.vertical   or false
cfg.point      = cfg.point      or "CENTER"
cfg.relPoint   = cfg.relPoint   or "CENTER"
cfg.x          = cfg.x          or 0
cfg.y          = cfg.y          or -300
cfg.iconCrop   = cfg.iconCrop   or 0.07
cfg.borderColor = cfg.borderColor or { 0, 0, 0, 1 }
cfg.hoverColor  = cfg.hoverColor  or { 1, 1, 1, 0.18 }
cfg.bgColor     = cfg.bgColor     or { 0.15, 0.15, 0.15, 0.50 }
cfg.borderSize  = cfg.borderSize  or 1
cfg.activeColor = cfg.activeColor or { 0.95, 0.95, 0.95, 1 }
cfg.iconInset   = cfg.iconInset   or 1


-- ============================================================
-- HELPER: Show/Hide sicher aufrufen (kein Taint im Kampf)
-- ============================================================

local function SafeShow(btn)
    if InCombatLockdown() then
        C_Timer.After(0, function()
            if not InCombatLockdown() then
                btn:Show()
            end
        end)
    else
        btn:Show()
    end
end

local function SafeHide(btn)
    if InCombatLockdown() then
        C_Timer.After(0, function()
            if not InCombatLockdown() then
                btn:Hide()
            end
        end)
    else
        btn:Hide()
    end
end

-- ============================================================
-- CREATE
-- ============================================================

function SB:Create()



    if self.frame then return end

    local cfg = AB:GetConfig("StanceBar")

    local profile = RexUI.GetProfile and RexUI:GetProfile()
    local actionbars = AB.GetCurrentActionBarDB and AB:GetCurrentActionBarDB(profile)

    if actionbars
    and actionbars["StanceBar"] then

        local db = actionbars["StanceBar"]

        cfg.point    = db.point    or cfg.point
        cfg.relPoint = db.relPoint or cfg.relPoint
        cfg.x        = db.x        or cfg.x
        cfg.y        = db.y        or cfg.y
    end
    -- --------------------------------------------------------
    -- BAR FRAME
    -- --------------------------------------------------------

    local bar = CreateFrame("Frame", "RexUI_StanceBar", UIParent)
    bar:SetFrameStrata("MEDIUM")
    bar:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)
    local initialSize, initialSpacing = AB:GetButtonMetrics(cfg, 30, 3)
    bar:SetSize((MAX_SLOTS * initialSize) + ((MAX_SLOTS - 1) * initialSpacing), initialSize)
    bar:SetScale(cfg.scale)
    bar:SetAlpha(cfg.alpha)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar.rexBarKey = "StanceBar"
    if AB.StyleBarBackdrop then AB:StyleBarBackdrop(bar) end

    bar.buttons = {}

    -- --------------------------------------------------------
    -- BUTTONS
    -- --------------------------------------------------------

    for i = 1, MAX_SLOTS do

        local btn = CreateFrame(
            "CheckButton",
            "RexUI_StanceButton" .. i,
            bar,
            "SecureActionButtonTemplate"
        )

        btn:SetSize(initialSize, initialSize)
        btn:RegisterForClicks("AnyUp")
        btn.rexLastClickMode = "AnyUp"
        btn:SetAttribute("useOnKeyDown", false)
        btn.rexLastUseOnKeyDown = false
        if btn.SetHitRectInsets then
            btn:SetHitRectInsets(0, 0, 0, 0)
        end
        btn:SetID(i)
        btn.stanceIndex = i
        btn.rexBarKey = "StanceBar"

        btn:SetAttribute("type", "spell")

        -- Position (wird von Update neu gesetzt)
        if i == 1 then
            btn:SetPoint("LEFT", bar, "LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", bar.buttons[i - 1], "RIGHT", initialSpacing, 0)
        end

        -- ------------------------------------------------
        -- ICON
        -- ------------------------------------------------

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetPoint("TOPLEFT",     btn, "TOPLEFT",      cfg.iconInset, -cfg.iconInset)
        btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -cfg.iconInset,  cfg.iconInset)
        btn.icon:SetTexCoord(
            cfg.iconCrop, 1 - cfg.iconCrop,
            cfg.iconCrop, 1 - cfg.iconCrop
        )
        btn.icon:Show()

        -- ------------------------------------------------
        -- HINTERGRUND
        -- ------------------------------------------------

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints(btn)
        btn.bg:SetColorTexture(unpack(cfg.bgColor))

        -- ------------------------------------------------
        -- BORDER
        -- ------------------------------------------------

        btn.border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        btn.border:SetAllPoints(btn)
        btn.border:SetFrameLevel(btn:GetFrameLevel() + 2)
        btn.border:EnableMouse(false)
        btn.border:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = RexUI.PixelBorder and RexUI:PixelBorder(cfg.borderSize) or cfg.borderSize,
        })
        AB:SetButtonBorderColor(btn, unpack(cfg.borderColor))

        -- ------------------------------------------------
        -- HOVER
        -- ------------------------------------------------

        btn.hover = btn:CreateTexture(nil, "HIGHLIGHT")
        btn.hover:SetAllPoints(btn)
        btn.hover:SetTexture((AB.Media and AB.Media.hover) or "Interface\\Buttons\\WHITE8x8")
        btn.hover:SetVertexColor(unpack(cfg.hoverColor))
        btn.hover:SetBlendMode("ADD")

        btn.pushedOverlay = btn:CreateTexture(nil, "OVERLAY", nil, 6)
        btn.pushedOverlay:SetAllPoints(btn.icon or btn)
        btn.pushedOverlay:SetColorTexture(0, 0, 0, 0.18)
        btn.pushedOverlay:SetBlendMode("BLEND")
        btn.pushedOverlay:SetAlpha(0)

        -- ------------------------------------------------
        -- COOLDOWN
        -- ------------------------------------------------

        btn.cooldown = CreateFrame(
            "Cooldown",
            "RexUI_StanceCD" .. i,
            btn,
            "CooldownFrameTemplate"
        )
        btn.cooldown:SetAllPoints(btn.icon)
        btn.cooldown:SetDrawEdge(false)
        btn.cooldown:SetSwipeColor(0, 0, 0, 0.8)
        btn.cooldown:SetFrameLevel(btn:GetFrameLevel() + 1)
        btn.cooldown:EnableMouse(false)

        -- Klick wird vom SecureActionButtonTemplate ueber sichere Attribute ausgefuehrt.

        -- ------------------------------------------------
        -- TOOLTIP
        -- ------------------------------------------------

        btn:HookScript("OnEnter", function(self)
            AB:SetButtonBorderColor(btn,
                cfg.hoverColor[1],
                cfg.hoverColor[2],
                cfg.hoverColor[3],
                1
            )
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            GameTooltip:SetShapeshift(self.stanceIndex)
            GameTooltip:Show()
        end)

        btn:HookScript("OnLeave", function(self)
            AB:SetButtonBorderColor(btn, unpack(cfg.borderColor))
            GameTooltip_Hide()
        end)

        if AB.EnableButtonFeedback then
            AB:EnableButtonFeedback(btn)
        end
        if AB.StyleButton then
            AB:StyleButton(btn, cfg)
        end

        btn:Hide()
        bar.buttons[i] = btn
    end

    self.frame = bar

    -- Auch in AB.Bars eintragen fuer Mover/Mouseover
    AB.Bars["StanceBar"] = bar

    SB:Update()
end

-- ============================================================
-- UPDATE
-- Icons, aktive Form, Cooldowns, Bar-Groesse
-- ============================================================

function SB:UpdateCombatVisuals()
    local bar = self.frame
    if not bar then return end

    local cfg = AB:GetConfig("StanceBar")
    local numForms = GetNumShapeshiftForms() or 0

    for i, btn in ipairs(bar.buttons) do
        if i <= numForms then
            local texture, isActive, isCastable = GetShapeshiftSlotInfo(i)

            if btn.icon then
                btn.icon:SetTexture(texture)
                btn.icon:SetVertexColor(
                    isCastable and 1 or 0.4,
                    isCastable and 1 or 0.4,
                    isCastable and 1 or 0.4
                )
            end

            if btn.SetChecked then
                pcall(btn.SetChecked, btn, isActive)
            end

            if btn.border then
                if isActive then
                    AB:SetButtonBorderColor(btn, unpack(cfg.activeColor))
                else
                    AB:SetButtonBorderColor(btn, unpack(cfg.borderColor))
                end
            end

            if btn.cooldown then
                local start, duration, enable = GetShapeshiftFormCooldown(i)
                if duration and duration > 0 then
                    pcall(btn.cooldown.SetCooldown, btn.cooldown, start or 0, duration, enable)
                elseif btn.cooldown.Clear then
                    pcall(btn.cooldown.Clear, btn.cooldown)
                else
                    pcall(btn.cooldown.SetCooldown, btn.cooldown, 0, 0)
                end
            end
        end
    end
end

function SB:Update()

    local bar = self.frame
    if not bar then return end

    if InCombatLockdown() then
        SB:UpdateCombatVisuals()
        SB._pendingLayout = true
        return
    end

    local cfg = AB:GetConfig("StanceBar")
    local numForms = GetNumShapeshiftForms() or 0
    local visibleForms = math.min(numForms, math.max(1, math.min(MAX_SLOTS, tonumber(cfg.slots) or MAX_SLOTS)))
    local visible  = 0

    for i, btn in ipairs(bar.buttons) do

        if i <= visibleForms then

            local texture, isActive, isCastable, spellID, spellName =
                GetShapeshiftSlotInfo(i)

            btn.spellID = spellID

            -- ------------------------------------------------
            -- ICON
            -- ------------------------------------------------

            if btn.icon then

                btn.icon:SetTexture(texture)

                btn.icon:SetVertexColor(
                    isCastable and 1 or 0.4,
                    isCastable and 1 or 0.4,
                    isCastable and 1 or 0.4
                )
            end

            -- ------------------------------------------------
            -- SECURE ACTION
            -- ------------------------------------------------

            if not InCombatLockdown() then
                -- Stance-index macro: one secure click enters, switches, or leaves.
                -- [noform]/[form] cannot switch Form A → Form B. Raw spell+Down/Up
                -- recasts the same form twice and cancels it.
                if spellName then
                    btn:SetAttribute("type", "macro")
                    btn:SetAttribute("macrotext", ("/cast [nostance:%d] %s\n/cancelform [stance:%d]"):format(i, spellName, i))
                    btn:SetAttribute("spell", nil)
                elseif spellID then
                    btn:SetAttribute("type", "spell")
                    btn:SetAttribute("spell", spellID)
                    btn:SetAttribute("macrotext", nil)
                end
            end

            -- ------------------------------------------------
            -- ACTIVE
            -- ------------------------------------------------

            btn:SetChecked(isActive)

            if btn.border then

                if isActive then
                    AB:SetButtonBorderColor(btn,
                        unpack(cfg.activeColor)
                    )
                else
                    AB:SetButtonBorderColor(btn,
                        unpack(cfg.borderColor)
                    )
                end
            end

            -- ------------------------------------------------
            -- COOLDOWN
            -- ------------------------------------------------

            if btn.cooldown then

                local start, duration, enable =
                    GetShapeshiftFormCooldown(i)

                if duration and duration > 0 then
                    pcall(btn.cooldown.SetCooldown, btn.cooldown, start or 0, duration, enable)
                elseif btn.cooldown.Clear then
                    pcall(btn.cooldown.Clear, btn.cooldown)
                else
                    pcall(btn.cooldown.SetCooldown, btn.cooldown, 0, 0)
                end
            end

            -- ------------------------------------------------
            -- SHOW  (FIX: SafeShow statt btn:Show())
            -- ------------------------------------------------

            if AB.UpdateButtonOverlays then
                AB:UpdateButtonOverlays(btn, cfg)
            end

            SafeShow(btn)

            visible = visible + 1

        else

            btn.spellID = nil
            btn.rexAssistActive = false
            if AB.UpdateButtonOverlays then
                AB:UpdateButtonOverlays(btn, cfg)
            end

            -- FIX: SafeHide statt btn:Hide()
            SafeHide(btn)

        end
    end

    -- --------------------------------------------------------
    -- BAR SIZE + LAYOUT
    -- FIX: ClearAllPoints/SetPoint/SetSize sind im Kampf gesperrt
    -- --------------------------------------------------------

    local function doLayout()
        if bar.rexBackdrop then bar.rexBackdrop:SetShown(visible > 0) end
        if visible <= 0 then
            bar:SetSize(1, 1)
            return
        end

        AB:LayoutButtonGrid(bar, bar.buttons, visible, cfg, 30, 3)
    end
    if InCombatLockdown() then
        -- Layout nach Kampfende nachholen (PLAYER_REGEN_ENABLED)
        SB._pendingLayout = true
    else
        doLayout()
    end
end

-- ============================================================
-- EVENTS
-- ============================================================

SB.eventFrame = CreateFrame("Frame")
SB.eventFrame:RegisterEvent("PLAYER_LOGIN")
SB.eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
SB.eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
SB.eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN")
-- FIX: PLAYER_REGEN_ENABLED abonnieren um nach Kampf nachzuziehen
SB.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

SB.eventFrame:SetScript("OnEvent", function(_, event)

    if event == "PLAYER_LOGIN" then

        SB:Create()

        C_Timer.After(0.2, function()
            SB:Update()
        end)

        return
    end

    -- FIX: Nach Kampfende Show/Hide + Layout nachholen
    if event == "PLAYER_REGEN_ENABLED" then
        C_Timer.After(0, function()
            SB:Update()
            SB._pendingLayout = false
        end)
        return
    end

    SB:Update()
end)

