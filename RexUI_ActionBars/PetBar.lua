-- ============================================================
-- RexUI_ActionBars\PetBar.lua
-- Eigene Pet Action Bar - kein Blizzard Frame
-- Selber Aufbau wie StanceBar.lua
-- ============================================================

local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI
local AB    = RexUI and RexUI.ActionBars
if not AB then return end

AB.PetBar = AB.PetBar or {}
local PB = AB.PetBar

local MAX_SLOTS = 10   -- WoW hat 10 Pet-Action-Slots

function PB:ApplyClickRegistration()
    if InCombatLockdown() then return end

    local bar = self.frame
    if not bar then return end

    for _, btn in ipairs(bar.buttons or {}) do
        -- PetActionButtonTemplate calls CastPetAction itself. Registering both
        -- phases executes that handler twice and can make abilities appear
        -- unresponsive. Blizzard's own PetBar deliberately uses AnyUp only.
        if btn.rexLastClickMode ~= "AnyUp" then
            btn:RegisterForClicks("AnyUp")
            btn.rexLastClickMode = "AnyUp"
        end
    end
end

-- ============================================================
-- CONFIG
-- ============================================================

AB.Config["PetBar"] = AB.Config["PetBar"] or {}

local cfg = AB.Config["PetBar"]

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
cfg.y          = cfg.y          or -340
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

local function HideNativePetButtonArt(btn)
    if not btn then return end

    local function clear(method)
        if btn[method] then
            pcall(btn[method], btn, "")
        end
    end

    clear("SetNormalTexture")
    clear("SetPushedTexture")
    clear("SetHighlightTexture")
    clear("SetCheckedTexture")

    for _, region in ipairs({
        btn.NormalTexture,
        btn.PushedTexture,
        btn.HighlightTexture,
        btn.CheckedTexture,
        btn.Border,
        btn.BorderShadow,
        btn.SlotArt,
        btn.SlotBackground,
        btn.SpellHighlightTexture,
        btn.NewActionTexture,
        btn.Flash,
    }) do
        if region then
            if region.SetAlpha then pcall(region.SetAlpha, region, 0) end
            if region.Hide then pcall(region.Hide, region) end
        end
    end
end

-- ============================================================
-- CREATE
-- ============================================================

function PB:Create()

    if self.frame then return end

    local cfg = AB:GetConfig("PetBar")

    -- Gespeicherte Position aus Profil laden
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    local actionbars = AB.GetCurrentActionBarDB and AB:GetCurrentActionBarDB(profile)

    if actionbars
    and actionbars["PetBar"] then

        local db = actionbars["PetBar"]

        cfg.point    = db.point    or cfg.point
        cfg.relPoint = db.relPoint or cfg.relPoint
        cfg.x        = db.x        or cfg.x
        cfg.y        = db.y        or cfg.y
    end

    -- --------------------------------------------------------
    -- BAR FRAME
    -- --------------------------------------------------------

    local bar = CreateFrame("Frame", "RexUI_PetBar", UIParent, "SecureHandlerStateTemplate")
    bar:SetFrameStrata("MEDIUM")
    bar:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)
    local initialSize, initialSpacing = AB:GetButtonMetrics(cfg, 30, 3)
    bar:SetSize((MAX_SLOTS * initialSize) + ((MAX_SLOTS - 1) * initialSpacing), initialSize)
    bar:SetScale(cfg.scale)
    bar:SetAlpha(cfg.alpha)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar.rexBarKey = "PetBar"
    if AB.StyleBarBackdrop then AB:StyleBarBackdrop(bar) end

    if RegisterStateDriver then
        RegisterStateDriver(bar, "visibility", "[petbattle] hide; [novehicleui,pet,nooverridebar,nopossessbar] show; hide")
    end

    bar.buttons = {}

    -- --------------------------------------------------------
    -- BUTTONS
    -- --------------------------------------------------------

    for i = 1, MAX_SLOTS do

        local btn = CreateFrame(
            "CheckButton",
            "RexUI_PetButton" .. i,
            bar,
            "PetActionButtonTemplate"
        )

        btn:SetSize(initialSize, initialSize)
        -- Native pet buttons cast through their template's OnClick handler,
        -- not through SecureActionButton's useOnKeyDown attribute.
        btn:RegisterForClicks("AnyUp")
        btn.rexLastClickMode = "AnyUp"
        if btn.SetHitRectInsets then
            btn:SetHitRectInsets(0, 0, 0, 0)
        end
        btn:SetID(i)
        -- Current Blizzard PetActionButtonMixin reads `index`, while its
        -- click handler reads GetID(). Both must identify the same pet slot.
        btn.index = i
        btn.actionIndex = i
        btn.commandName = "BONUSACTIONBUTTON" .. i
        btn.rexBarKey = "PetBar"
        HideNativePetButtonArt(btn)

  

        -- Initiale Position (wird von Update neu gesetzt)
        if i == 1 then
            btn:SetPoint("LEFT", bar, "LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", bar.buttons[i - 1], "RIGHT", initialSpacing, 0)
        end

        -- ------------------------------------------------
        -- ICON
        -- ------------------------------------------------

        if btn.icon and btn.icon.SetAlpha then
            btn.icon:SetAlpha(0)
        end

        btn.RexUIIcon = btn.RexUIIcon or btn:CreateTexture(nil, "ARTWORK")
        btn.icon = btn.RexUIIcon
        btn.icon:SetPoint("TOPLEFT",     btn, "TOPLEFT",      cfg.iconInset, -cfg.iconInset)
        btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -cfg.iconInset,  cfg.iconInset)
        btn.icon:SetTexCoord(
            cfg.iconCrop, 1 - cfg.iconCrop,
            cfg.iconCrop, 1 - cfg.iconCrop
        )
        btn.icon:Show()

        -- ------------------------------------------------
        -- AUTOKAST-Indikator (kleines Dreieck oben-links)
        -- ------------------------------------------------

        btn.autoCast = btn:CreateTexture(nil, "OVERLAY")
        btn.autoCast:SetSize(8, 8)
        btn.autoCast:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        btn.autoCast:SetTexture("Interface\\Buttons\\UI-AutoCastableOverlay")
        btn.autoCast:SetTexCoord(0.05, 0.30, 0.05, 0.30)
        btn.autoCast:Hide()

        -- Wie ElvUI den nativen Blizzard-Autocast-Rahmen verwenden. Auf
        -- Retail zeigt ShowAutoCastEnabled den animierten aktiven Zustand
        -- deutlich um den gesamten Button; das kleine Dreieck bleibt nur
        -- als Fallback für Clients ohne diesen Overlay erhalten.
        btn.rexNativeAutoCast = btn.AutoCastOverlay or btn.AutoCastable

        -- RexUI's generic overlay manager suppresses every child exposed as
        -- button.AutoCastOverlay and hooks its OnShow to hide it again. Pet
        -- buttons own this visual themselves, so keep the frame under the
        -- PetBar-specific reference before StyleButton sees the button.
        if btn.AutoCastOverlay == btn.rexNativeAutoCast then
            btn.AutoCastOverlay = nil
        end

        if btn.rexNativeAutoCast then
            local overlay = btn.rexNativeAutoCast
            if overlay.ClearAllPoints and overlay.SetPoint then
                overlay:ClearAllPoints()
                overlay:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 3)
                overlay:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 3, -3)
            end
            if overlay.SetFrameLevel and btn.GetFrameLevel then
                overlay:SetFrameLevel(btn:GetFrameLevel() + 4)
            end
            if overlay.SetAlpha then overlay:SetAlpha(1) end
            if overlay.Hide then overlay:Hide() end
        end

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

        -- ElvUI-artige Aktivanzeige: weiße ADD-Fläche für den laufenden
        -- Befehl und ein rotes Pulsieren für den aktiven Angriff.
        btn.petActiveOverlay = btn:CreateTexture(nil, "OVERLAY", nil, 5)
        btn.petActiveOverlay:SetAllPoints(btn.icon)
        btn.petActiveOverlay:SetColorTexture(1, 1, 1, 0.30)
        btn.petActiveOverlay:SetBlendMode("ADD")
        btn.petActiveOverlay:Hide()

        btn.petAttackFlash = btn:CreateTexture(nil, "OVERLAY", nil, 4)
        btn.petAttackFlash:SetAllPoints(btn.icon)
        btn.petAttackFlash:SetColorTexture(1, 0.20, 0.20, 0.42)
        btn.petAttackFlash:SetBlendMode("ADD")
        btn.petAttackFlash:Hide()

        btn.petAttackFlashAnim = btn.petAttackFlash:CreateAnimationGroup()
        btn.petAttackFlashAnim:SetLooping("BOUNCE")
        local attackPulse = btn.petAttackFlashAnim:CreateAnimation("Alpha")
        attackPulse:SetFromAlpha(0.10)
        attackPulse:SetToAlpha(0.42)
        attackPulse:SetDuration(0.35)
        if attackPulse.SetSmoothing then
            attackPulse:SetSmoothing("IN_OUT")
        end

        -- ------------------------------------------------
        -- TOOLTIP
        -- ------------------------------------------------

        btn:SetScript("OnEnter", function(self)
            AB:SetButtonBorderColor(btn,
                cfg.hoverColor[1],
                cfg.hoverColor[2],
                cfg.hoverColor[3],
                1
            )
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            GameTooltip:SetPetAction(self.actionIndex)
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function(self)
            AB:SetButtonBorderColor(btn, unpack(cfg.borderColor))
            GameTooltip_Hide()
        end)

        if AB.EnableButtonFeedback then
            AB:EnableButtonFeedback(btn)
        end
        if AB.StyleButton then
            AB:StyleButton(btn, cfg)
        end

        -- Wie ElvUI bleiben die geschützten Pet-Buttons dauerhaft aufgebaut.
        -- Nur der sichere Visibility-Driver blendet die komplette Leiste um.
        btn:Show()
        bar.buttons[i] = btn
    end

    self.frame = bar

    -- In AB.Bars eintragen fuer Mover/Mouseover
    AB.Bars["PetBar"] = bar

    PB:Update()
end

-- ============================================================
-- UPDATE
-- Icons, aktiver Slot, Cooldowns, AutoCast, Bar-Groesse
-- ============================================================

function PB:Update(forceLayout)

    local bar = self.frame
    if not bar then return end

    local cfg = AB:GetConfig("PetBar")
    local visibleSlots = math.max(1, math.min(MAX_SLOTS, tonumber(cfg.slots) or MAX_SLOTS))

    if cfg.hidden == true then
        bar:SetAlpha(0)
    elseif cfg.mouseover ~= true then
        bar:SetAlpha(cfg.alpha or 1)
    end

    for i, btn in ipairs(bar.buttons) do
        HideNativePetButtonArt(btn)

        -- Protected pet buttons stay allocated, but the configured count may
        -- safely change out of combat without rebuilding the secure bar.
        if not InCombatLockdown() then
            btn:SetShown(i <= visibleSlots)
        end

        -- Korrekte Signatur laut Blizzard:
        -- name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID
        local name, texture, isToken, isActive,
              isAutocastable, autoCastActive, spellID =
            GetPetActionInfo(i)

        local show = name ~= nil or texture ~= nil

        if show then

            -- ------------------------------------------------
            -- ICON
            -- isToken=true  -> texture ist ein globaler Variablen-Name
            --                  z.B. "PET_ATTACK_TEXTURE"
            -- isToken=false -> texture ist direkter Pfad/FileID
            -- ------------------------------------------------

            if btn.icon then

                local resolvedTexture
                if isToken then
                    resolvedTexture = _G[texture]
                else
                    resolvedTexture = texture
                end

                btn.icon:SetTexture(
                    resolvedTexture or "Interface\\Icons\\INV_Misc_QuestionMark"
                )

                if resolvedTexture then
                    local usable = GetPetActionSlotUsable(i)
                    local shade = usable and 1 or 0.4
                    btn.icon:SetVertexColor(shade, shade, shade)
                    if btn.icon.SetDesaturation then
                        btn.icon:SetDesaturation(usable and 0 or 1)
                    end
                    btn.icon:Show()
                else
                    btn.icon:Hide()
                end
            end

            -- ------------------------------------------------
            -- ACTIVE (Button gedrueckt / aktive Faehigkeit)
            -- ------------------------------------------------

            local commandActive = isActive and name ~= "PET_ACTION_FOLLOW"
            btn.rexPetCommandActive = commandActive == true
            btn:SetChecked(commandActive)

            if btn.petActiveOverlay then
                btn.petActiveOverlay:SetShown(commandActive)
            end

            local attackActive = commandActive
                and IsPetAttackAction
                and IsPetAttackAction(i)
            if btn.petAttackFlash and btn.petAttackFlashAnim then
                if attackActive then
                    btn.petAttackFlash:Show()
                    if not btn.petAttackFlashAnim:IsPlaying() then
                        btn.petAttackFlashAnim:Play()
                    end
                else
                    btn.petAttackFlashAnim:Stop()
                    btn.petAttackFlash:Hide()
                end
            end

            if btn.border then
                if commandActive then
                    AB:SetButtonBorderColor(btn, unpack(cfg.activeColor))
                else
                    AB:SetButtonBorderColor(btn, unpack(cfg.borderColor))
                end
            end

            -- ------------------------------------------------
            -- AUTOCAST-INDIKATOR
            -- ------------------------------------------------

            local nativeAutoCast = btn.rexNativeAutoCast
            if nativeAutoCast then
                if nativeAutoCast.SetAlpha then nativeAutoCast:SetAlpha(1) end
                nativeAutoCast:SetShown(isAutocastable == true)
                if nativeAutoCast.ShowAutoCastEnabled then
                    nativeAutoCast:ShowAutoCastEnabled(autoCastActive == true)
                elseif nativeAutoCast.SetVertexColor then
                    if autoCastActive then
                        nativeAutoCast:SetVertexColor(1, 0.82, 0.12, 1)
                    else
                        nativeAutoCast:SetVertexColor(0.35, 0.35, 0.35, 0.65)
                    end
                end
            end

            if btn.autoCast then
                if not nativeAutoCast and isAutocastable then
                    btn.autoCast:Show()
                    btn.autoCast:SetVertexColor(
                        autoCastActive and 1 or 0.4,
                        autoCastActive and 0.82 or 0.4,
                        autoCastActive and 0.12 or 0.4,
                        1
                    )
                else
                    btn.autoCast:Hide()
                end
            end

        
        else
            -- Clear visual state immediately when a slot disappears. These are
            -- visual-only operations and are safe in combat; deferring them can
            -- leave a stale autocast ring or active state behind.
            btn.rexPetCommandActive = false
            btn:SetChecked(false)
            if btn.petActiveOverlay then
                btn.petActiveOverlay:Hide()
            end
            if btn.petAttackFlashAnim then
                btn.petAttackFlashAnim:Stop()
            end
            if btn.petAttackFlash then
                btn.petAttackFlash:Hide()
            end
            if btn.rexNativeAutoCast then
                if btn.rexNativeAutoCast.ShowAutoCastEnabled then
                    btn.rexNativeAutoCast:ShowAutoCastEnabled(false)
                end
                btn.rexNativeAutoCast:Hide()
            end
            if btn.autoCast then
                btn.autoCast:Hide()
            end
        end
    end

    -- --------------------------------------------------------
    -- LAYOUT  (ClearAllPoints/SetPoint sind im Kampf gesperrt)
    -- --------------------------------------------------------

    local function doLayout()
        if forceLayout then
            bar.rexLayoutSignature = nil
        end
        if bar.rexBackdrop then bar.rexBackdrop:Show() end

        -- Die PetBar kennt nur zwei feste Formen: eine horizontale Reihe
        -- oder eine vertikale Spalte. Ein alter rows-Wert darf das nicht
        -- ueberschreiben.
        local layoutCfg = {}
        for key, value in pairs(cfg) do
            layoutCfg[key] = value
        end
        layoutCfg.rows = 1
        AB:LayoutButtonGrid(bar, bar.buttons, visibleSlots, layoutCfg, 30, 3)
        if AB.SyncMoverToBar then
            AB:SyncMoverToBar("PetBar")
        end
    end
    if InCombatLockdown() then
        PB._pendingLayout = true
    else
        doLayout()
    end
end

function PB:SetVertical(vertical)
    local cfg = AB.Config and AB.Config.PetBar
    if not cfg then return end

    cfg.vertical = vertical == true
    cfg.rows = 1
    if AB.InvalidateConfigCache then
        AB:InvalidateConfigCache("PetBar")
    end
    if InCombatLockdown() then
        self._pendingLayout = true
        self._pendingForceLayout = true
    else
        self:Update(true)
    end
end

-- ============================================================
-- EVENTS
-- ============================================================

PB.eventFrame = CreateFrame("Frame")
PB.eventFrame:RegisterEvent("PLAYER_LOGIN")
PB.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
PB.eventFrame:RegisterEvent("PET_BAR_UPDATE")
PB.eventFrame:RegisterEvent("PET_BAR_UPDATE_COOLDOWN")
PB.eventFrame:RegisterEvent("PET_BAR_UPDATE_USABLE")
PB.eventFrame:RegisterEvent("PET_BAR_HIDEGRID")
PB.eventFrame:RegisterEvent("PET_BAR_SHOWGRID")
PB.eventFrame:RegisterEvent("PET_UI_UPDATE")
PB.eventFrame:RegisterEvent("UNIT_PET")
PB.eventFrame:RegisterEvent("UNIT_FLAGS")
PB.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
PB.eventFrame:RegisterEvent("PLAYER_CONTROL_GAINED")
PB.eventFrame:RegisterEvent("PLAYER_CONTROL_LOST")
PB.eventFrame:RegisterEvent("PLAYER_FARSIGHT_FOCUS_CHANGED")
PB.eventFrame:RegisterEvent("SPELLS_CHANGED")

PB.eventFrame:SetScript("OnEvent", function(_, event, arg1)

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then

        PB:Create()

        C_Timer.After(0.2, function()
            PB:Update()
        end)

        return
    end

    -- FIX: Kein Update wenn OverrideActionBar aktiv ist
    -- (Fahrzeuge, Drachen-Reiten etc.) - verhindert Taint auf Blizzard Cooldowns
    if OverrideActionBar and OverrideActionBar:IsShown() then
        return
    end

    if event == "UNIT_PET" and arg1 ~= "player" then
        return
    end

    -- Der aktuelle Helfen-/Defensiv-/Passivstatus kommt über UNIT_FLAGS pet.
    if event == "UNIT_FLAGS" and arg1 ~= "pet" then
        return
    end

    -- Nach Kampfende geschützte Layout-Änderungen nachholen und den aktuellen
    -- Pet-Zustand noch einmal vollständig zeichnen.
    if event == "PLAYER_REGEN_ENABLED" then
        C_Timer.After(0, function()
            PB:Update(PB._pendingForceLayout == true)
            PB._pendingLayout = false
            PB._pendingForceLayout = false
        end)
        return
    end

    PB:Update()
end)
