-- ============================================================
-- RexUI_ActionBars\ZoneAbility.lua
-- Dedicated holder for Blizzard's ZoneAbilityFrame (G-99 etc.).
-- Keeps Omnium, ExtraAction and Vehicle frames untouched.
-- ============================================================

local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI
local AB = RexUI and RexUI.ActionBars
if not AB then return end

AB.ZoneAbility = AB.ZoneAbility or {}
local ZA = AB.ZoneAbility

local DEFAULT_POINT = "BOTTOM"
local DEFAULT_REL_POINT = "BOTTOM"
local DEFAULT_X = 150
local DEFAULT_Y = 300
local DEFAULT_SIZE = 52

local holder
local mover
local eventFrame
local hookedFrame
local restoringParent
local pendingSetup

local function GetDB()
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    if not profile then return nil end

    profile.zoneAbility = profile.zoneAbility or {}
    return profile.zoneAbility
end

local function GetConfig()
    local db = GetDB() or {}

    return {
        point = db.point or DEFAULT_POINT,
        relPoint = db.relPoint or DEFAULT_REL_POINT,
        x = tonumber(db.x) or DEFAULT_X,
        y = tonumber(db.y) or DEFAULT_Y,
    }
end

local function SavePosition(frame)
    local db = GetDB()
    if not db or not frame then return end

    local point, _, relPoint, x, y = frame:GetPoint()
    db.point = point or DEFAULT_POINT
    db.relPoint = relPoint or point or DEFAULT_REL_POINT
    db.x = math.floor((x or 0) + 0.5)
    db.y = math.floor((y or 0) + 0.5)
end

local function EnsureHolder()
    if holder then return holder end

    holder = CreateFrame("Frame", "RexUI_ZoneAbilityHolder", UIParent)
    holder:SetClampedToScreen(true)
    holder:SetMovable(true)
    holder:SetSize(DEFAULT_SIZE, DEFAULT_SIZE)

    local cfg = GetConfig()
    holder:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)

    return holder
end

local function UpdateHolderSize()
    local zoneFrame = _G.ZoneAbilityFrame
    local h = EnsureHolder()
    if not zoneFrame or not zoneFrame.SpellButtonContainer then
        h:SetSize(DEFAULT_SIZE, DEFAULT_SIZE)
        return
    end

    local container = zoneFrame.SpellButtonContainer
    local width = container:GetWidth() or DEFAULT_SIZE
    local height = container:GetHeight() or DEFAULT_SIZE

    h:SetSize(math.max(DEFAULT_SIZE, width), math.max(DEFAULT_SIZE, height))

    if mover and mover:IsShown() then
        mover:ClearAllPoints()
        mover:SetAllPoints(h)
    end
end

local function ReanchorZoneFrame()
    local zoneFrame = _G.ZoneAbilityFrame
    local h = EnsureHolder()
    if not zoneFrame or not h then return end

    zoneFrame:ClearAllPoints()
    zoneFrame:SetAllPoints(h)
    zoneFrame.ignoreInLayout = true

    UpdateHolderSize()
end

local function RestoreParent()
    if restoringParent then return end

    if InCombatLockdown and InCombatLockdown() then
        pendingSetup = true
        return
    end

    local zoneFrame = _G.ZoneAbilityFrame
    local h = EnsureHolder()
    if not zoneFrame or not h or zoneFrame:GetParent() == h then
        ReanchorZoneFrame()
        return
    end

    restoringParent = true
    zoneFrame:SetParent(h)
    restoringParent = false

    ReanchorZoneFrame()
end

function ZA:Setup()
    if InCombatLockdown and InCombatLockdown() then
        pendingSetup = true
        return
    end

    local zoneFrame = _G.ZoneAbilityFrame
    if not zoneFrame then return end

    EnsureHolder()

    if hookedFrame ~= zoneFrame then
        if hooksecurefunc then
            hooksecurefunc(zoneFrame, "SetParent", function(_, parent)
                if restoringParent or parent == holder then return end
                RestoreParent()
            end)

            if zoneFrame.UpdateDisplayedZoneAbilities then
                hooksecurefunc(zoneFrame, "UpdateDisplayedZoneAbilities", function()
                    UpdateHolderSize()
                end)
            end

            if zoneFrame.SpellButtonContainer and zoneFrame.SpellButtonContainer.SetSize then
                hooksecurefunc(zoneFrame.SpellButtonContainer, "SetSize", function()
                    UpdateHolderSize()
                end)
            end
        end

        hookedFrame = zoneFrame
    end

    RestoreParent()
end

local function EnsureMover()
    if mover then return mover end

    local h = EnsureHolder()
    mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    mover:SetAllPoints(h)
    mover:SetFrameStrata("DIALOG")
    mover:SetFrameLevel(500)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:Hide()

    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    mover:SetBackdropColor(0.2, 0.6, 1, 0.2)
    mover:SetBackdropBorderColor(0.2, 0.6, 1, 0.9)

    mover.Label = mover:CreateFontString(nil, "OVERLAY")
    mover.Label:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    mover.Label:SetPoint("CENTER")
    mover.Label:SetText("Zone Ability")

    mover:SetScript("OnDragStart", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        self.dragged = true
        h:StartMoving()
    end)

    mover:SetScript("OnDragStop", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        h:StopMovingOrSizing()
        SavePosition(h)
        self:ClearAllPoints()
        self:SetAllPoints(h)
    end)

    mover:SetScript("OnMouseUp", function(self)
        if self.dragged then
            self.dragged = false
            return
        end

        if RexUI.ConfigUI and RexUI.ConfigUI.Open then
            RexUI.ConfigUI:Open()
            if RexUI.ConfigUI.SetCategory then
                RexUI.ConfigUI:SetCategory("Actionbars")
            end
        end
    end)

    return mover
end

function ZA:ShowMover()
    self:Setup()
    local m = EnsureMover()
    UpdateHolderSize()
    m:ClearAllPoints()
    m:SetAllPoints(EnsureHolder())
    m:Show()
end

function ZA:HideMover()
    if mover then mover:Hide() end
end

function ZA:Initialize()
    if eventFrame then return end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("UPDATE_UI_WIDGET")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and not pendingSetup then return end
        pendingSetup = false
        ZA:Setup()
    end)
end

ZA:Initialize()
