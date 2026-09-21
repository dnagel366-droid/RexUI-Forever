local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI
if not RexUI then return end

RexUI.MicroMenu = RexUI.MicroMenu or {}
local MM = RexUI.MicroMenu

MM.DefaultConfig = {
    enabled = true,
    point = "BOTTOM",
    relPoint = "BOTTOM",
    x = 0,
    y = 40,
}

local function copyConfig(defaults, saved)
    local cfg = {}
    for k, v in pairs(defaults) do
        cfg[k] = v
    end
    if type(saved) == "table" then
        for k, v in pairs(saved) do
            cfg[k] = v
        end
    end
    return cfg
end

function MM:GetConfig()
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    return copyConfig(self.DefaultConfig, profile and profile.microMenu)
end

function MM:Save(key, value)
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    if not profile then return end
    profile.microMenu = profile.microMenu or {}
    profile.microMenu[key] = value
end

local MICRO_BUTTONS = {
    "CharacterMicroButton",
    "ProfessionMicroButton",
    "PlayerSpellsMicroButton",
    "AchievementMicroButton",
    "QuestLogMicroButton",
    "GuildMicroButton",
    "LFDMicroButton",
    "CollectionsMicroButton",
    "EJMicroButton",
    "StoreMicroButton",
    "MainMenuMicroButton",
}

local function StyleMicroButton(button)
    if not button or button.rexStyled then return end
    button.rexStyled = true

    local hover = button:CreateTexture(nil, "HIGHLIGHT", nil, 4)
    hover:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    hover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    hover:SetColorTexture(1, 1, 1, 0.12)
    hover:SetBlendMode("ADD")
    button.rexHover = hover

    local press = button:CreateTexture(nil, "OVERLAY", nil, 5)
    press:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    press:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    press:SetColorTexture(0, 0, 0, 1)
    press:SetBlendMode("BLEND")
    press:SetAlpha(0)
    button.rexPress = press

    local fadeGroup = press:CreateAnimationGroup()
    local fade = fadeGroup:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.12)
    fade:SetToAlpha(0)
    fade:SetDuration(0.08)
    if fade.SetSmoothing then
        fade:SetSmoothing("OUT")
    end
    fadeGroup:SetScript("OnFinished", function()
        press:SetAlpha(0)
    end)
    press.rexReleaseFade = fadeGroup

    button:HookScript("OnMouseDown", function(self, mouseButton)
        if mouseButton ~= "LeftButton" or not self.rexPress then return end
        if self.rexPress.rexReleaseFade then
            self.rexPress.rexReleaseFade:Stop()
        end
        self.rexPress:SetAlpha(0.18)
    end)

    button:HookScript("OnMouseUp", function(self)
        if not self.rexPress then return end
        if self.rexPress.rexReleaseFade then
            self.rexPress:SetAlpha(0.12)
            self.rexPress.rexReleaseFade:Play()
        else
            self.rexPress:SetAlpha(0)
        end
    end)

    button:HookScript("OnLeave", function(self)
        if self.rexPress then
            self.rexPress:SetAlpha(0)
        end
    end)
end

function MM:StyleButtons()
    for _, name in ipairs(MICRO_BUTTONS) do
        StyleMicroButton(_G[name])
    end
end

function MM:Update()
    if InCombatLockdown and InCombatLockdown() then
        self.needsCombatUpdate = true
        return
    end

    self.needsCombatUpdate = nil

    local cfg = self:GetConfig()
    local menu = _G.MicroMenuContainer or _G.MicroMenu
    if not menu then return end

    menu:ClearAllPoints()
    menu:SetPoint(cfg.point or "BOTTOM", UIParent, cfg.relPoint or cfg.point or "BOTTOM", cfg.x or 0, cfg.y or 40)

    if cfg.enabled == false then
        menu:SetAlpha(0)
        menu:EnableMouse(false)
        if self.Mover then self.Mover:Hide() end
        return
    end

    menu:SetAlpha(1)
    menu:EnableMouse(true)
    self:StyleButtons()

    if self.Mover then
        self.Mover:SetShown(RexUI.Unlocked == true or (RexUI.ConfigUI and RexUI.ConfigUI.actionbarMoversUnlocked == true))
    end
end

-- Blizzard wendet das Edit-Mode-Layout teilweise erst nach dem eigentlichen
-- Enter/Exit-Aufruf an. Wir überschreiben deshalb keine SetPoint-Methode,
-- sondern setzen RexUIs gespeicherte Position nur kurz danach erneut.
function MM:QueueUpdate()
    self._updateGeneration = (self._updateGeneration or 0) + 1
    local generation = self._updateGeneration

    local function refresh()
        if MM._updateGeneration ~= generation then return end
        MM:Update()
    end

    refresh()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, refresh)
        C_Timer.After(0.10, refresh)
    end
end

function MM:CreateMover()
    if self.Mover then return end

    local menu = _G.MicroMenuContainer or _G.MicroMenu
    if not menu then return end

    local mover = CreateFrame("Frame", nil, menu)
    mover:SetAllPoints(menu)
    mover:SetFrameLevel(menu:GetFrameLevel() + 10)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")

    mover.Bg = mover:CreateTexture(nil, "BACKGROUND")
    mover.Bg:SetColorTexture(0.2, 0.6, 1, 0.2)
    mover.Bg:SetAllPoints(mover)

    mover.Label = mover:CreateFontString(nil, "OVERLAY")
    mover.Label:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    mover.Label:SetPoint("CENTER")
    mover.Label:SetText("MicroMenu")

    mover:SetScript("OnDragStart", function()
        mover.dragged = true
        menu:SetMovable(true)
        menu:StartMoving()
    end)

    mover:SetScript("OnDragStop", function()
        menu:StopMovingOrSizing()
        local point, _, relPoint, x, y = menu:GetPoint()
        if point then
            MM:Save("point", point)
            MM:Save("relPoint", relPoint or point)
            MM:Save("x", math.floor((x or 0) + 0.5))
            MM:Save("y", math.floor((y or 0) + 0.5))
        end
    end)

    mover:SetScript("OnMouseUp", function()
        if mover.dragged then
            mover.dragged = false
            return
        end
        if RexUI.ConfigUI and RexUI.ConfigUI.OpenMicroMenuSettings then
            RexUI.ConfigUI:OpenMicroMenuSettings()
        end
    end)

    mover:Hide()
    self.Mover = mover
end

function MM:ShowMover()
    local cfg = self:GetConfig()
    if self.Mover then self.Mover:SetShown(cfg.enabled ~= false) end
end

function MM:HideMover()
    if self.Mover then self.Mover:Hide() end
end

function MM:Initialize()
    local menu = _G.MicroMenuContainer or _G.MicroMenu
    if not menu then return end

    self:CreateMover()
    self:StyleButtons()
    self:Update()

    if not self._microButtonsHooked and _G.UpdateMicroButtons then
        self._microButtonsHooked = true
        hooksecurefunc("UpdateMicroButtons", function()
            MM:QueueUpdate()
        end)
    end

    if not self._editModeHooked and _G.EditModeManagerFrame then
        self._editModeHooked = true
        if _G.EditModeManagerFrame.EnterEditMode then
            hooksecurefunc(_G.EditModeManagerFrame, "EnterEditMode", function()
                MM:QueueUpdate()
            end)
        end
        if _G.EditModeManagerFrame.ExitEditMode then
            hooksecurefunc(_G.EditModeManagerFrame, "ExitEditMode", function()
                MM:QueueUpdate()
            end)
        end
    end

    if not self.CombatFrame then
        local combatFrame = CreateFrame("Frame")
        combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        combatFrame:SetScript("OnEvent", function()
            if MM.needsCombatUpdate then
                MM:Update()
            end
        end)
        self.CombatFrame = combatFrame
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    if not RexUI.MicroMenu then return end

    if event == "PLAYER_LOGIN" then
        RexUI.MicroMenu:Initialize()
    else
        -- Das Blizzard-Layout kann beim Weltbeitritt noch einmal angewendet
        -- werden. Danach gewinnt wieder die in RexUI gespeicherte Position.
        RexUI.MicroMenu:QueueUpdate()
    end
end)
