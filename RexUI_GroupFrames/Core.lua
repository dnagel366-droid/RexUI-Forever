-- ============================================================
-- RexUI_GroupFrames - Core.lua
-- Native RexUI party and raid frames
-- ============================================================

local _, ns = ...

local RexUI = ns.RexUI or _G.RexUI
if not RexUI then return end

RexUI.GroupFrames = RexUI.GroupFrames or {}
local GF = RexUI.GroupFrames
RexUI:RegisterModule("GroupFrames", GF)

local TEXTURE = "Interface\\Buttons\\WHITE8X8"
local BAR_TEXTURE = "Interface\\AddOns\\RexUI\\media\\groupframes\\statusbar.tga"
local REDUCED_HEALTH_TEXTURE = "Interface\\AddOns\\RexUI\\media\\groupframes\\reduced-max-health.png"
local FONT = "Interface\\AddOns\\RexUI\\media\\fonts\\Expressway.TTF"
local ROLE_TANK = "Interface\\AddOns\\RexUI\\media\\groupframes\\role-tank.png"
local ROLE_HEALER = "Interface\\AddOns\\RexUI\\media\\groupframes\\role-healer.png"
local ROLE_DAMAGE = "Interface\\AddOns\\RexUI\\media\\groupframes\\role-damage.png"
local HEALTH_BG = 17 / 255
local POWER_BG = 107 / 255

local DEFAULTS = {
    partyEnabled = true,
    raidEnabled = true,
    hideBlizzard = true,
    -- Raid frames use a compact ElvUI-style 5-high group layout.
    -- Eight groups at 90x38 fit into roughly 720x190 instead of ~1000x300.
    frameWidth = 90,
    frameHeight = 38,
    partyFrameWidth = 125,
    partyFrameHeight = 60,
    partyCellSpacing = -1,
    partyShowPowerBar = true,
    partyPowerHeight = 4,
    partyShowRoleIcon = true,
    partyShowRaidMarker = true,
    partyShowReadyCheck = true,
    partyShowLeaderIcon = true,
    partyShowHealthText = true,
    partyShowIncomingHeals = true,
    partyShowAggro = true,
    partyShowDebuffs = true,
    partyDebuffCount = 3,
    partyDebuffSize = 18,
    partyRangeAlpha = 0.45,
    cellSpacing = -1,
    groupSpacing = -1,
    partyShowWhenSolo = false,
    showWhenSolo = false,
    showWhenGroup = false,
    showWhenRaid = true,
    showPowerBar = true,
    powerHeight = 3,
    showHealthText = false,
    showIncomingHeals = true,
    showAggro = true,
    showRoleIcon = true,
    showRaidMarker = true,
    showReadyCheck = true,
    showLeaderIcon = false,
    showDebuffs = true,
    debuffCount = 3,
    debuffSize = 14,
    rangeAlpha = 0.45,
    partyPosition = { point = "CENTER", x = -360, y = 40 },
    raidPosition = { point = "CENTER", x = -315, y = 120 },
}

local partyHeader
local raidHeader
local raidHeaders = {}
local partyMover
local raidMover
local pendingApply
local pendingHideAllMovers
local pendingHidePartyMover
local pendingHideRaidMover
local previewContainer
local previewFrames = {}
local previewCount = 0
local nativePartyFrames = {}
local nativeRaidFrames = {}
local unitFrameMap = {}
local nativeUpdateFrame
local partyContainer
local raidContainer

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local BLIZZARD_GROUP_FRAMES = {
    "PartyFrame",
    "CompactPartyFrame",
    "CompactRaidFrameManager",
    "CompactRaidFrameContainer",
}

local function CopyDefaults(defaults, saved)
    local result = {}
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            result[key] = CopyDefaults(value, type(saved) == "table" and saved[key] or nil)
        elseif type(saved) == "table" and saved[key] ~= nil then
            result[key] = saved[key]
        else
            result[key] = value
        end
    end
    if type(saved) == "table" then
        for key, value in pairs(saved) do
            if result[key] == nil then result[key] = value end
        end
    end
    return result
end

function GF:GetProfileTable()
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    if not profile then return nil end
    profile.groupFrames = type(profile.groupFrames) == "table" and profile.groupFrames or {}

    local saved = profile.groupFrames
    if saved._nativeVersion == nil then
        local legacy = type(profile.groupframes) == "table" and profile.groupframes or nil
        if legacy then
            saved.enabled = legacy.enabled ~= false
            saved.hideBlizzard = legacy.hideBlizzard == true
            saved.partyShowWhenSolo = true
            saved.frameWidth = tonumber(legacy.width) or saved.frameWidth
            saved.frameHeight = tonumber(legacy.height) or saved.frameHeight
            saved.partyFrameWidth = tonumber(legacy.width) or saved.partyFrameWidth
            saved.partyFrameHeight = tonumber(legacy.height) or saved.partyFrameHeight
            saved.cellSpacing = tonumber(legacy.spacing) or saved.cellSpacing
            saved.showRoleIcon = legacy.showRoleIcons ~= false
            saved.showLeaderIcon = legacy.showLeaderIcon == true
            saved.showDebuffs = legacy.showDebuffs ~= false
            saved.debuffCount = tonumber(legacy.auraCount) or saved.debuffCount
            saved.debuffSize = tonumber(legacy.auraSize) or saved.debuffSize

            if legacy.point or legacy.x or legacy.y then
                local position = {
                    point = legacy.point or "CENTER",
                    x = tonumber(legacy.x) or 0,
                    y = tonumber(legacy.y) or 0,
                }
                saved.partyPosition = CopyDefaults(position, nil)
                saved.raidPosition = CopyDefaults(position, nil)
            end
        elseif saved.enabled == nil then
            saved.enabled = true
        end

        saved._nativeVersion = 1
        profile.groupframes = nil
    end
    if saved._nativeVersion < 2 then
        if saved.groupSpacing == nil or saved.groupSpacing == 5 then saved.groupSpacing = -1 end
        if saved.powerHeight == nil or saved.powerHeight == 5 then saved.powerHeight = 4 end
        if saved.showHealthText == nil then saved.showHealthText = false end
        saved._nativeVersion = 2
    end
    if saved._nativeVersion < 3 then
        saved.frameWidth = 125
        saved.frameHeight = 60
        saved.partyFrameWidth = 125
        saved.partyFrameHeight = 60
        saved.cellSpacing = -1
        saved.groupSpacing = -1
        saved.powerHeight = 4
        saved.debuffSize = 18
        saved.debuffCount = 3
        saved.showHealthText = false
        saved.showLeaderIcon = false
        saved._nativeVersion = 3
    end
    if saved._nativeVersion < 4 then
        local oldEnabled = saved.enabled ~= false
        if saved.partyEnabled == nil then saved.partyEnabled = oldEnabled end
        if saved.raidEnabled == nil then saved.raidEnabled = oldEnabled end
        saved.enabled = nil
        saved._nativeVersion = 4
    end
    if saved._nativeVersion < 5 then
        saved.showRoleIcon = true
        saved.showRaidMarker = true
        saved.showHealthText = true
        saved.showLeaderIcon = true
        saved._nativeVersion = 5
    end
    if saved._nativeVersion < 6 then
        saved.partyCellSpacing = saved.partyCellSpacing or saved.cellSpacing or -1
        if saved.partyShowPowerBar == nil then saved.partyShowPowerBar = saved.showPowerBar ~= false end
        saved.partyPowerHeight = saved.partyPowerHeight or saved.powerHeight or 4
        if saved.partyShowRoleIcon == nil then saved.partyShowRoleIcon = saved.showRoleIcon ~= false end
        if saved.partyShowRaidMarker == nil then saved.partyShowRaidMarker = saved.showRaidMarker ~= false end
        if saved.partyShowReadyCheck == nil then saved.partyShowReadyCheck = saved.showReadyCheck ~= false end
        if saved.partyShowLeaderIcon == nil then saved.partyShowLeaderIcon = saved.showLeaderIcon == true end
        if saved.partyShowHealthText == nil then saved.partyShowHealthText = saved.showHealthText == true end
        if saved.partyShowDebuffs == nil then saved.partyShowDebuffs = saved.showDebuffs ~= false end
        saved.partyDebuffCount = saved.partyDebuffCount or saved.debuffCount or 3
        saved.partyDebuffSize = saved.partyDebuffSize or saved.debuffSize or 18
        saved.partyRangeAlpha = saved.partyRangeAlpha or saved.rangeAlpha or 0.45
        saved._nativeVersion = 6
    end
    if saved._nativeVersion < 7 then
        saved.showIncomingHeals = true
        saved.partyShowIncomingHeals = true
        saved._nativeVersion = 7
    end
    if saved._nativeVersion < 8 then
        saved.partyShowWhenSolo = false
        saved.showWhenSolo = false
        saved._nativeVersion = 8
    end
    if saved._nativeVersion < 9 then
        -- 3.5: compact raid layout. Party frames intentionally keep their old size.
        saved.frameWidth = 90
        saved.frameHeight = 38
        saved.cellSpacing = -1
        saved.groupSpacing = -1
        saved.powerHeight = 3
        saved.debuffSize = 14
        saved.showHealthText = false
        saved._nativeVersion = 9
    end
    return saved
end

function GF:GetConfig()
    return CopyDefaults(DEFAULTS, self:GetProfileTable())
end

function GF:Save(key, value)
    local saved = self:GetProfileTable()
    if saved then saved[key] = value end
end

local function GetPartyConfig(cfg)
    local party = CopyDefaults(cfg, nil)
    party.cellSpacing = cfg.partyCellSpacing
    party.showPowerBar = cfg.partyShowPowerBar
    party.powerHeight = cfg.partyPowerHeight
    party.showRoleIcon = cfg.partyShowRoleIcon
    party.showRaidMarker = cfg.partyShowRaidMarker
    party.showReadyCheck = cfg.partyShowReadyCheck
    party.showLeaderIcon = cfg.partyShowLeaderIcon
    party.showHealthText = cfg.partyShowHealthText
    party.showIncomingHeals = cfg.partyShowIncomingHeals
    party.showAggro = cfg.partyShowAggro
    party.showDebuffs = cfg.partyShowDebuffs
    party.debuffCount = cfg.partyDebuffCount
    party.debuffSize = cfg.partyDebuffSize
    party.rangeAlpha = cfg.partyRangeAlpha
    return party
end

local function GetRuntimeConfigs()
    local cfg = GF.Config
    if not cfg then
        cfg = GF:GetConfig()
        GF.Config = cfg
    end
    local partyCfg = GF.PartyConfig
    if not partyCfg then
        partyCfg = GetPartyConfig(cfg)
        GF.PartyConfig = partyCfg
    end
    return cfg, partyCfg
end

local function CreateBorder(parent)
    local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({ edgeFile = TEXTURE, edgeSize = 1 })
    border:SetBackdropBorderColor(0, 0, 0, 1)
    border:SetFrameLevel(parent:GetFrameLevel() + 4)
    return border
end

local function CreateAggroBorder(parent)
    local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", 2, -2)
    border:SetBackdrop({ edgeFile = TEXTURE, edgeSize = 2 })
    border:SetBackdropBorderColor(1, 0.1, 0.05, 1)
    border:SetFrameLevel(parent:GetFrameLevel() + 22)
    border:Hide()
    return border
end

local function CreateFont(parent, size, justify)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, size or 10, "")
    text:SetJustifyH(justify or "LEFT")
    text:SetTextColor(1, 1, 1, 0.9)
    text:SetShadowColor(0, 0, 0, 0)
    text:SetShadowOffset(0, 0)
    if text.SetWordWrap then text:SetWordWrap(false) end
    return text
end

local function CreateStatusBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(BAR_TEXTURE)
    if bar:GetStatusBarTexture() then bar:GetStatusBarTexture():SetHorizTile(false) end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.bg:SetColorTexture(HEALTH_BG, HEALTH_BG, HEALTH_BG, 0.5)
    bar.border = CreateBorder(bar)
    return bar
end

local function SaveMoverPosition(mover, key)
    local saved = GF:GetProfileTable()
    if not saved then return end
    local x, y = mover:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not x or not y or not ux or not uy then return end
    saved[key] = { point = "CENTER", x = math.floor(x - ux + 0.5), y = math.floor(y - uy + 0.5) }
end

local function CreateMover(name, label, positionKey)
    local mover = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    mover:SetFrameStrata("DIALOG")
    mover:SetClampedToScreen(true)
    mover:SetMovable(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetBackdrop({ bgFile = TEXTURE, edgeFile = TEXTURE, edgeSize = 1 })
    mover:SetBackdropColor(0.18, 0.03, 0.24, 0.75)
    mover:SetBackdropBorderColor(0.85, 0.25, 1, 1)
    local text = CreateFont(mover, 12, "CENTER")
    text:SetPoint("CENTER")
    text:SetText(label)
    mover:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then self:StartMoving() end
    end)
    mover:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveMoverPosition(self, positionKey)
    end)
    mover:Hide()
    return mover
end

local function PositionMover(mover, position, width, height)
    mover:ClearAllPoints()
    mover:SetPoint(position.point or "CENTER", UIParent, position.point or "CENTER", position.x or 0, position.y or 0)
    mover:SetSize(math.max(130, width), math.max(32, height))
end

local PREVIEW_NAMES = {
    "Rexora", "Kaelis", "Nyra", "Tharon", "Mirel",
    "Vexin", "Arielle", "Doran", "Luneth", "Corvin",
    "Seris", "Bram", "Ylva", "Tavian", "Neris",
    "Rovan", "Elira", "Fenric", "Maelis", "Korin",
}

local PREVIEW_CLASSES = {
    "WARRIOR", "PRIEST", "PALADIN", "DRUID", "MONK",
    "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "ROGUE",
    "HUNTER", "DEMONHUNTER", "EVOKER",
}

local function CreatePreviewUnit(index)
    local frame = CreateFrame("Frame", nil, previewContainer)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(previewContainer:GetFrameLevel() + 2)

    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetAllPoints()
    frame.background:SetColorTexture(0, 0, 0, 0)

    frame.health = CreateStatusBar(frame)
    frame.health:SetPoint("TOPLEFT")
    frame.health:SetPoint("TOPRIGHT")
    local classToken = PREVIEW_CLASSES[((index - 1) % #PREVIEW_CLASSES) + 1]
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    frame.health:SetStatusBarColor(color and color.r or 0.5, color and color.g or 0.5, color and color.b or 0.5, 1)
    frame.health:SetMinMaxValues(0, 100)
    frame.health:SetValue(math.max(24, 100 - ((index * 7) % 72)))

    frame.power = CreateStatusBar(frame)
    frame.power:SetPoint("BOTTOMLEFT")
    frame.power:SetPoint("BOTTOMRIGHT")
    frame.power:SetStatusBarColor(0.18, 0.48, 0.92, 1)
    frame.power.bg:SetColorTexture(POWER_BG, POWER_BG, POWER_BG, 0.4)
    frame.power:SetMinMaxValues(0, 100)
    frame.power:SetValue(35 + ((index * 11) % 65))

    frame.incomingHealClip = CreateFrame("Frame", nil, frame.health)
    frame.incomingHealClip:SetAllPoints(frame.health)
    frame.incomingHealClip:SetClipsChildren(true)
    frame.incomingHeal = CreateFrame("StatusBar", nil, frame.incomingHealClip)
    frame.incomingHeal:SetStatusBarTexture(TEXTURE)
    frame.incomingHeal:SetStatusBarColor(102 / 255, 243 / 255, 102 / 255, 0.75)
    frame.incomingHeal:SetMinMaxValues(0, 100)
    frame.incomingHeal:SetValue(index % 3 == 0 and 18 or 0)
    frame.incomingHeal:SetFrameLevel(frame.health:GetFrameLevel() + 2)

    frame.reducedHealth = CreateFrame("StatusBar", nil, frame.health)
    frame.reducedHealth:SetStatusBarTexture(REDUCED_HEALTH_TEXTURE)
    local reducedFill = frame.reducedHealth:GetStatusBarTexture()
    if reducedFill then
        reducedFill:SetDrawLayer("ARTWORK", 3)
        reducedFill:SetHorizTile(true)
        reducedFill:SetVertTile(true)
    end
    frame.reducedHealth:SetStatusBarColor(0.7, 0.1, 0.1, 1)
    frame.reducedHealth:SetReverseFill(true)
    frame.reducedHealth:SetAllPoints(frame.health)
    frame.reducedHealth:SetFrameLevel(frame.health:GetFrameLevel() + 3)
    frame.reducedHealth:SetMinMaxValues(0, 1)
    frame.reducedHealth:SetValue(index == 4 and 0.2 or 0)
    frame.reducedHealthBg = frame.reducedHealth:CreateTexture(nil, "ARTWORK", nil, 2)
    if reducedFill then frame.reducedHealthBg:SetAllPoints(reducedFill) end
    frame.reducedHealthBg:SetColorTexture(0, 0, 0, 1)

    frame.textLayer = CreateFrame("Frame", nil, frame)
    frame.textLayer:SetAllPoints(frame.health)
    frame.textLayer:SetFrameLevel(frame:GetFrameLevel() + 18)

    frame.name = CreateFont(frame.textLayer, 10, "LEFT")
    frame.name:SetPoint("TOPLEFT", frame.health, "TOPLEFT", 3, -3)
    frame.name:SetPoint("RIGHT", frame.health, "RIGHT", -3, 0)
    frame.name:SetText(PREVIEW_NAMES[index] or ("Spieler " .. index))

    frame.healthText = CreateFont(frame.textLayer, 10, "RIGHT")
    frame.healthText:SetPoint("CENTER", frame.health, "CENTER", 0, 0)
    frame.healthText:SetText(tostring(math.max(24, 100 - ((index * 7) % 72))) .. "%")
    frame.indicatorLayer = CreateFrame("Frame", nil, frame)
    frame.indicatorLayer:SetAllPoints(frame)
    frame.indicatorLayer:SetFrameLevel(frame:GetFrameLevel() + 20)

    frame.role = frame.indicatorLayer:CreateTexture(nil, "OVERLAY")
    frame.role:SetSize(13, 13)
    frame.role:SetPoint("BOTTOMLEFT", frame.health, "BOTTOMLEFT", 0, 0)
    frame.role:SetTexture(index == 1 and ROLE_TANK or index == 2 and ROLE_HEALER or ROLE_DAMAGE)
    frame.role:SetTexCoord(0, 1, 0, 1)
    frame.role:Show()

    frame.marker = frame.indicatorLayer:CreateTexture(nil, "OVERLAY")
    frame.marker:SetSize(16, 16)
    frame.marker:SetPoint("CENTER", frame.health, "CENTER", 0, 0)
    if SetRaidTargetIconTexture then SetRaidTargetIconTexture(frame.marker, ((index - 1) % 8) + 1) end

    frame.readyIcon = frame.indicatorLayer:CreateTexture(nil, "OVERLAY")
    frame.readyIcon:SetSize(20, 20)
    frame.readyIcon:SetPoint("CENTER", frame.health, "CENTER", 0, 0)
    frame.readyIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")

    frame.leaderIcon = frame.indicatorLayer:CreateTexture(nil, "OVERLAY")
    frame.leaderIcon:SetSize(14, 14)
    frame.leaderIcon:SetPoint("TOP", frame.health, "TOP", 0, 0)
    frame.leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")

    frame.debuffs = {}
    local debuffTextures = { 136071, 135846, 136182 }
    for auraIndex = 1, 3 do
        local icon = frame.indicatorLayer:CreateTexture(nil, "OVERLAY")
        icon:SetTexture(debuffTextures[auraIndex])
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        frame.debuffs[auraIndex] = icon
    end

    frame.border = CreateBorder(frame)
    previewFrames[index] = frame
    return frame
end

local function ApplyPreviewUnit(frame, index, cfg, party)
    local width = party and cfg.partyFrameWidth or cfg.frameWidth
    local height = party and cfg.partyFrameHeight or cfg.frameHeight
    local powerHeight = cfg.showPowerBar and math.max(2, cfg.powerHeight or 4) or 0
    frame:SetSize(width, height)
    local compactRaid = not party and height <= 42
    local fontSize = compactRaid and 9 or 10
    local roleSize = compactRaid and 11 or 13
    local markerSize = compactRaid and 13 or 16
    local readySize = compactRaid and 17 or 20
    local leaderSize = compactRaid and 11 or 14
    frame.name:SetFont(FONT, fontSize, "")
    frame.healthText:SetFont(FONT, fontSize, "")
    frame.role:SetSize(roleSize, roleSize)
    frame.marker:SetSize(markerSize, markerSize)
    frame.readyIcon:SetSize(readySize, readySize)
    frame.leaderIcon:SetSize(leaderSize, leaderSize)

    frame.health:ClearAllPoints()
    frame.health:SetPoint("TOPLEFT")
    frame.health:SetPoint("TOPRIGHT")
    if powerHeight > 0 then
        frame.power:SetHeight(powerHeight)
        frame.power:Show()
        frame.health:SetPoint("BOTTOM", frame.power, "TOP", 0, 0)
    else
        frame.power:Hide()
        frame.health:SetPoint("BOTTOM")
    end

    frame.incomingHeal:ClearAllPoints()
    frame.incomingHeal:SetPoint("TOPLEFT", frame.health:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    frame.incomingHeal:SetPoint("BOTTOMLEFT", frame.health:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    frame.incomingHeal:SetWidth(width)
    frame.incomingHeal:SetShown(cfg.showIncomingHeals ~= false)
    frame.reducedHealth:SetShown(index == 4 or index == 11)

    frame.role:SetShown(cfg.showRoleIcon ~= false)
    frame.healthText:SetShown(cfg.showHealthText == true)
    frame.marker:SetShown(cfg.showRaidMarker ~= false and index <= 8)
    frame.readyIcon:SetShown(cfg.showReadyCheck ~= false and index == 3)
    frame.leaderIcon:SetShown(cfg.showLeaderIcon == true and index == 1)
    for auraIndex, icon in ipairs(frame.debuffs) do
        icon:SetSize(cfg.debuffSize, cfg.debuffSize)
        icon:ClearAllPoints()
        icon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3 - ((auraIndex - 1) * (cfg.debuffSize + 2)), -3)
        icon:SetShown(cfg.showDebuffs ~= false and auraIndex <= cfg.debuffCount)
    end
end

function GF:ShowPreview(count)
    if InCombatLockdown() then
        RexUI:PrintMessage("Der Gruppenframe-Testmodus kann im Kampf nicht gestartet werden.")
        return
    end

    local cfg = self:GetConfig()
    local party = count == 5
    if (party and cfg.partyEnabled == false) or (not party and cfg.raidEnabled == false) then
        self:HidePreview()
        RexUI:PrintMessage(party and "Gruppenframes sind deaktiviert." or "Raidframes sind deaktiviert.")
        return
    end

    cfg = party and GetPartyConfig(cfg) or cfg
    count = tonumber(count) or 20
    if count <= 5 then
        count = 5
    else
        count = math.max(10, math.min(40, math.floor((count + 2) / 5) * 5))
    end
    previewCount = count
    if not previewContainer then
        previewContainer = CreateFrame("Frame", "RexUI_GroupFramesPreview", UIParent)
        previewContainer:SetClampedToScreen(true)
        -- The preview follows the real RexUI mover. Position changes are made
        -- through the normal mover so test and live raid frames always match.
        previewContainer:EnableMouse(false)
    end
    previewContainer:SetFrameStrata("DIALOG")

    if party then
        previewContainer:SetSize(
            cfg.partyFrameWidth,
            (count * cfg.partyFrameHeight) + ((count - 1) * cfg.cellSpacing)
        )
    else
        local columns = math.ceil(count / 5)
        previewContainer:SetSize(
            (columns * cfg.frameWidth) + ((columns - 1) * cfg.groupSpacing),
            (5 * cfg.frameHeight) + (4 * cfg.cellSpacing)
        )
    end

    -- Use the exact saved mover position. This keeps the preview at the same
    -- location after toggling it, changing the player count, or reloading UI.
    previewContainer:ClearAllPoints()
    local anchorMover = party and partyMover or raidMover
    if anchorMover then
        previewContainer:SetPoint("TOPLEFT", anchorMover, "TOPLEFT", 0, 0)
    else
        local position = party and cfg.partyPosition or cfg.raidPosition
        previewContainer:SetPoint(position.point or "CENTER", UIParent, position.point or "CENTER", position.x or 0, position.y or 0)
    end

    for index = 1, 40 do
        local frame = previewFrames[index] or CreatePreviewUnit(index)
        frame:ClearAllPoints()
        if index <= count then
            ApplyPreviewUnit(frame, index, cfg, party)
            if party then
                frame:SetPoint("TOPLEFT", previewContainer, "TOPLEFT", 0, -((index - 1) * (cfg.partyFrameHeight + cfg.cellSpacing)))
            else
                local column = math.floor((index - 1) / 5)
                local row = (index - 1) % 5
                frame:SetPoint("TOPLEFT", previewContainer, "TOPLEFT",
                    column * (cfg.frameWidth + cfg.groupSpacing),
                    -(row * (cfg.frameHeight + cfg.cellSpacing)))
            end
            frame:Show()
        else
            frame:Hide()
        end
    end

    previewContainer:Show()
end

function GF:HidePreview()
    previewCount = 0
    if previewContainer then previewContainer:Hide() end
end

function GF:IsPreviewShown()
    return previewCount > 0 and previewContainer and previewContainer:IsShown()
end

function GF:IsPartyPreviewShown()
    return previewCount == 5 and previewContainer and previewContainer:IsShown()
end

function GF:IsRaidPreviewShown()
    return previewCount >= 10 and previewContainer and previewContainer:IsShown()
end

function GF:GetPreviewCount()
    return previewCount
end

local function SafeHealthPercent(unit)
    if not unit or not UnitExists(unit) then return nil end
    if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        local ok, value = pcall(UnitHealthPercent, unit, true, CurveConstants.ScaleTo100)
        if ok then
            if IsSecret(value) then return value end
            if type(value) == "number" then return value end
        end
    end
    local ok, current, maximum = pcall(function()
        return UnitHealth(unit), UnitHealthMax(unit)
    end)
    if not ok or type(current) ~= "number" or type(maximum) ~= "number" then return nil end
    if IsSecret(current) or IsSecret(maximum) then return nil end
    if maximum <= 0 then return nil end
    return math.floor((current / maximum) * 100 + 0.5)
end

local function SetRoleTexture(texture, role)
    local path = role == "TANK" and ROLE_TANK
        or role == "HEALER" and ROLE_HEALER
        or role == "DAMAGER" and ROLE_DAMAGE
    if not path then texture:Hide(); return end
    texture:SetTexture(path)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:Show()
end

local function CreateRealButtonVisual(button, party)
    button._rexParty = party == true
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("*type1", "target")
    button:SetAttribute("*type2", "togglemenu")

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetAllPoints()
    button.background:SetColorTexture(0, 0, 0, 0)

    button.health = CreateStatusBar(button)
    button.health:SetPoint("TOPLEFT")
    button.health:SetPoint("TOPRIGHT")
    button.health:SetMinMaxValues(0, 100)
    button.health:SetValue(100)

    button.power = CreateStatusBar(button)
    button.power:SetPoint("BOTTOMLEFT")
    button.power:SetPoint("BOTTOMRIGHT")
    button.power:SetStatusBarColor(0.18, 0.48, 0.92, 1)
    button.power.bg:SetColorTexture(POWER_BG, POWER_BG, POWER_BG, 0.4)

    button.incomingHealClip = CreateFrame("Frame", nil, button.health)
    button.incomingHealClip:SetAllPoints(button.health)
    button.incomingHealClip:SetClipsChildren(true)
    button.incomingHeal = CreateFrame("StatusBar", nil, button.incomingHealClip)
    button.incomingHeal:SetStatusBarTexture(TEXTURE)
    button.incomingHeal:SetStatusBarColor(102 / 255, 243 / 255, 102 / 255, 0.75)
    button.incomingHeal:SetMinMaxValues(0, 1)
    button.incomingHeal:SetValue(0)
    button.incomingHeal:SetFrameLevel(button.health:GetFrameLevel() + 2)

    button.reducedHealth = CreateFrame("StatusBar", nil, button.health)
    button.reducedHealth:SetStatusBarTexture(REDUCED_HEALTH_TEXTURE)
    local reducedFill = button.reducedHealth:GetStatusBarTexture()
    if reducedFill then
        reducedFill:SetDrawLayer("ARTWORK", 3)
        reducedFill:SetHorizTile(true)
        reducedFill:SetVertTile(true)
    end
    button.reducedHealth:SetStatusBarColor(0.7, 0.1, 0.1, 1)
    button.reducedHealth:SetReverseFill(true)
    button.reducedHealth:SetAllPoints(button.health)
    button.reducedHealth:SetFrameLevel(button.health:GetFrameLevel() + 3)
    button.reducedHealth:SetMinMaxValues(0, 1)
    button.reducedHealth:SetValue(0)
    button.reducedHealthBg = button.reducedHealth:CreateTexture(nil, "ARTWORK", nil, 2)
    if reducedFill then button.reducedHealthBg:SetAllPoints(reducedFill) end
    button.reducedHealthBg:SetColorTexture(0, 0, 0, 1)

    button.textLayer = CreateFrame("Frame", nil, button)
    button.textLayer:SetAllPoints(button.health)
    button.textLayer:SetFrameLevel(button:GetFrameLevel() + 18)

    button.nameText = CreateFont(button.textLayer, 10, "LEFT")
    button.nameText:SetPoint("TOPLEFT", button.health, "TOPLEFT", 3, -3)
    button.nameText:SetPoint("RIGHT", button.health, "RIGHT", -3, 0)

    button.healthText = CreateFont(button.textLayer, 10, "RIGHT")
    button.healthText:SetPoint("CENTER", button.health, "CENTER", 0, 0)

    button.indicatorLayer = CreateFrame("Frame", nil, button)
    button.indicatorLayer:SetAllPoints(button)
    button.indicatorLayer:SetFrameLevel(button:GetFrameLevel() + 20)

    button.roleIcon = button.indicatorLayer:CreateTexture(nil, "OVERLAY")
    button.roleIcon:SetSize(13, 13)
    button.roleIcon:SetPoint("BOTTOMLEFT", button.health, "BOTTOMLEFT", 0, 0)

    button.raidMarker = button.indicatorLayer:CreateTexture(nil, "OVERLAY")
    button.raidMarker:SetSize(16, 16)
    button.raidMarker:SetPoint("CENTER", button.health, "CENTER", 0, 0)

    button.readyIcon = button.indicatorLayer:CreateTexture(nil, "OVERLAY")
    button.readyIcon:SetSize(20, 20)
    button.readyIcon:SetPoint("CENTER", button.health, "CENTER", 0, 0)

    button.leaderIcon = button.indicatorLayer:CreateTexture(nil, "OVERLAY")
    button.leaderIcon:SetSize(14, 14)
    button.leaderIcon:SetPoint("TOP", button.health, "TOP", 0, 0)
    button.leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")

    button.debuffIcons = {}
    for index = 1, 3 do
        local icon = button.indicatorLayer:CreateTexture(nil, "OVERLAY")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.debuffIcons[index] = icon
    end

    button.border = CreateBorder(button)
    button.aggroBorder = CreateAggroBorder(button)
    button:SetScript("OnEnter", function(self)
        local unit = self:GetAttribute("unit")
        if RexUI.ShowUnitTooltip then RexUI:ShowUnitTooltip(self, unit, "ANCHOR_RIGHT") end
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    _G.ClickCastFrames = _G.ClickCastFrames or {}
    _G.ClickCastFrames[button] = true
end

local function ApplyRealButtonLayout(button, cfg)
    local width = button._rexParty and cfg.partyFrameWidth or cfg.frameWidth
    local height = button._rexParty and cfg.partyFrameHeight or cfg.frameHeight
    local powerHeight = cfg.showPowerBar and math.max(2, cfg.powerHeight or 4) or 0
    button:SetSize(width, height)

    -- Keep indicators readable on compact raid cells without letting them dominate the frame.
    -- Party frames retain the previous visual sizes.
    local compactRaid = not button._rexParty and height <= 42
    local fontSize = compactRaid and 9 or 10
    local roleSize = compactRaid and 11 or 13
    local markerSize = compactRaid and 13 or 16
    local readySize = compactRaid and 17 or 20
    local leaderSize = compactRaid and 11 or 14
    button.nameText:SetFont(FONT, fontSize, "")
    button.healthText:SetFont(FONT, fontSize, "")
    button.roleIcon:SetSize(roleSize, roleSize)
    button.raidMarker:SetSize(markerSize, markerSize)
    button.readyIcon:SetSize(readySize, readySize)
    button.leaderIcon:SetSize(leaderSize, leaderSize)

    button.health:ClearAllPoints()
    button.health:SetPoint("TOPLEFT")
    button.health:SetPoint("TOPRIGHT")
    if powerHeight > 0 then
        button.power:SetHeight(powerHeight)
        button.power:Show()
        button.health:SetPoint("BOTTOM", button.power, "TOP", 0, 0)
    else
        button.power:Hide()
        button.health:SetPoint("BOTTOM")
    end
    button.textLayer:SetAllPoints(button.health)
    button.incomingHeal:ClearAllPoints()
    button.incomingHeal:SetPoint("TOPLEFT", button.health:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    button.incomingHeal:SetPoint("BOTTOMLEFT", button.health:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    button.incomingHeal:SetWidth(width)
    button.incomingHeal:SetShown(cfg.showIncomingHeals ~= false)
    button.healthText:SetShown(cfg.showHealthText == true)
    for index, icon in ipairs(button.debuffIcons) do
        icon:SetSize(cfg.debuffSize, cfg.debuffSize)
        icon:ClearAllPoints()
        icon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3 - ((index - 1) * (cfg.debuffSize + 2)), -3)
    end
end

local function HasUpdateEvent(event, name)
    return event == name or (type(event) == "table" and event[name] == true)
end

local function UpdateRealButton(button, cfg, event)
    if not button:IsShown() then return end
    local unit = button:GetAttribute("unit")
    if not unit or not UnitExists(unit) then return end

    local full = event == nil
    local identityDirty = full or HasUpdateEvent(event, "UNIT_NAME_UPDATE")
        or HasUpdateEvent(event, "UNIT_CONNECTION") or HasUpdateEvent(event, "UNIT_LEVEL")
    local healthDirty = full or HasUpdateEvent(event, "UNIT_HEALTH")
        or HasUpdateEvent(event, "UNIT_MAXHEALTH") or HasUpdateEvent(event, "UNIT_CONNECTION")
    local predictionDirty = healthDirty or HasUpdateEvent(event, "UNIT_HEAL_PREDICTION")
    local powerDirty = full or HasUpdateEvent(event, "UNIT_POWER_UPDATE")
        or HasUpdateEvent(event, "UNIT_MAXPOWER") or HasUpdateEvent(event, "UNIT_CONNECTION")
    local auraDirty = full or HasUpdateEvent(event, "UNIT_AURA")
    local threatDirty = full or HasUpdateEvent(event, "UNIT_THREAT_SITUATION_UPDATE")
        or HasUpdateEvent(event, "UNIT_THREAT_LIST_UPDATE")
    local rangeDirty = healthDirty or HasUpdateEvent(event, "UNIT_IN_RANGE_UPDATE")

    if identityDirty then
        local name = UnitName(unit)
        button.nameText:SetText(name or "")
    end

    if healthDirty then
        local percent = SafeHealthPercent(unit)
        button.health:SetMinMaxValues(0, 100)
        if IsSecret(percent) then
            button.health:SetValue(percent)
            button.healthText:SetFormattedText("%.0f%%", percent)
        elseif type(percent) == "number" then
            button.health:SetValue(percent)
            local ok = pcall(button.healthText.SetFormattedText, button.healthText, "%d%%", percent)
            if not ok then button.healthText:SetText("") end
        else
            button.health:SetValue(100)
            button.healthText:SetText("")
        end

        local _, class = UnitClass(unit)
        local color = class and not IsSecret(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if UnitIsConnected(unit) == false then
            button.health:SetStatusBarColor(0.3, 0.3, 0.3, 0.3)
            button.health.bg:SetColorTexture(0.4, 0.4, 0.4, 1)
        elseif UnitIsDeadOrGhost(unit) then
            button.health:SetStatusBarColor(0.3, 0.3, 0.3, 0.5)
            button.health.bg:SetColorTexture(36 / 255, 23 / 255, 23 / 255, 1)
        else
            if color then button.health:SetStatusBarColor(color.r, color.g, color.b, 1)
            else button.health:SetStatusBarColor(0.25, 0.72, 0.35, 1) end
            button.health.bg:SetColorTexture(HEALTH_BG, HEALTH_BG, HEALTH_BG, 0.5)
        end
        button.nameText:SetTextColor(1, 1, 1, 0.9)
        button.healthText:SetTextColor(1, 1, 1, 0.9)
    end

    if predictionDirty and cfg.showIncomingHeals ~= false then
        local maximum = UnitHealthMax(unit)
        local incoming = 0
        if UnitGetIncomingHeals then incoming = UnitGetIncomingHeals(unit) end
        local maximumIsSecret = IsSecret(maximum)
        if not maximumIsSecret and (type(maximum) ~= "number" or maximum <= 0) then
            button.incomingHeal:Hide()
        else
            if not IsSecret(incoming) and type(incoming) ~= "number" then incoming = 0 end
            local rangeOK = pcall(button.incomingHeal.SetMinMaxValues, button.incomingHeal, 0, maximum)
            local valueOK = pcall(button.incomingHeal.SetValue, button.incomingHeal, incoming)
            button.incomingHeal:SetShown(rangeOK and valueOK)
        end
    elseif predictionDirty then
        button.incomingHeal:Hide()
    end

    if healthDirty and GetUnitTotalModifiedMaxHealthPercent then
        local reduced = GetUnitTotalModifiedMaxHealthPercent(unit)
        if not IsSecret(reduced) and type(reduced) ~= "number" then
            button.reducedHealth:Hide()
        else
            local ok = pcall(button.reducedHealth.SetValue, button.reducedHealth, reduced)
            button.reducedHealth:SetShown(ok)
        end
    elseif healthDirty then
        button.reducedHealth:Hide()
    end

    if powerDirty and cfg.showPowerBar then
        local current, maximum = UnitPower(unit), UnitPowerMax(unit)
        pcall(button.power.SetMinMaxValues, button.power, 0, maximum)
        pcall(button.power.SetValue, button.power, current)
        local powerType, powerToken = UnitPowerType(unit)
        local powerColor
        if PowerBarColor and not IsSecret(powerType) and not IsSecret(powerToken) then
            powerColor = PowerBarColor[powerToken] or PowerBarColor[powerType]
        end
        if powerColor then
            button.power:SetStatusBarColor(powerColor.r, powerColor.g, powerColor.b, 1)
        else
            button.power:SetStatusBarColor(0.18, 0.48, 0.92, 1)
        end
    end

    if full then
        local role = UnitGroupRolesAssigned(unit)
        if cfg.showRoleIcon and not IsSecret(role) then SetRoleTexture(button.roleIcon, role)
        else button.roleIcon:Hide() end

        local marker = cfg.showRaidMarker and GetRaidTargetIndex(unit)
        if IsSecret(marker) then
            button.raidMarker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
            if button.raidMarker.SetSpriteSheetCell then
                pcall(button.raidMarker.SetSpriteSheetCell, button.raidMarker, marker, 4, 4, 64, 64)
            end
            button.raidMarker:Show()
        elseif marker and SetRaidTargetIconTexture then
            SetRaidTargetIconTexture(button.raidMarker, marker)
            button.raidMarker:Show()
        else
            button.raidMarker:Hide()
        end

        if cfg.showReadyCheck then
            local status = GetReadyCheckStatus and GetReadyCheckStatus(unit)
            if IsSecret(status) then
                button.readyIcon:Hide()
            elseif status == "ready" then
                button.readyIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
                button.readyIcon:Show()
            elseif status == "notready" then
                button.readyIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
                button.readyIcon:Show()
            elseif status == "waiting" then
                button.readyIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
                button.readyIcon:Show()
            else
                button.readyIcon:Hide()
            end
        else
            button.readyIcon:Hide()
        end

        local isLeader = UnitIsGroupLeader(unit)
        local isAssistant = UnitIsGroupAssistant(unit)
        if cfg.showLeaderIcon and not IsSecret(isLeader) and isLeader then
            button.leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
            button.leaderIcon:Show()
        elseif cfg.showLeaderIcon and not IsSecret(isAssistant) and isAssistant then
            button.leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
            button.leaderIcon:Show()
        else
            button.leaderIcon:Hide()
        end
    end

    if threatDirty then
        local threat = cfg.showAggro and UnitThreatSituation and UnitThreatSituation(unit)
        if IsSecret(threat) or type(threat) ~= "number" or threat < 2 then
            button.aggroBorder:Hide()
        else
            if threat >= 3 then
                button.aggroBorder:SetBackdropBorderColor(1, 0.08, 0.04, 1)
            else
                button.aggroBorder:SetBackdropBorderColor(1, 0.5, 0.05, 1)
            end
            button.aggroBorder:Show()
        end
    end

    if auraDirty then
        for index, icon in ipairs(button.debuffIcons) do
            local aura
            if cfg.showDebuffs and index <= cfg.debuffCount and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                local ok, result = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HARMFUL")
                if ok then aura = result end
            end
            if aura then
                local ok = pcall(icon.SetTexture, icon, aura.icon)
                icon:SetShown(ok)
            else
                icon:Hide()
            end
        end
    end

    if rangeDirty then
        if UnitIsUnit(unit, "player") then
            button:SetAlpha(1)
        elseif UnitIsConnected(unit) == false then
            button:SetAlpha(0.8)
        elseif UnitPhaseReason and UnitPhaseReason(unit) then
            button:SetAlpha(cfg.rangeAlpha)
        else
            local inRange = UnitInRange(unit)
            if button.SetAlphaFromBoolean and (IsSecret(inRange) or inRange ~= nil) then
                button:SetAlphaFromBoolean(inRange, 1, cfg.rangeAlpha)
            else
                button:SetAlpha(1)
            end
        end
    end

    if (full or healthDirty) and GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button) then
        RexUI:ShowUnitTooltip(button, unit, "ANCHOR_RIGHT")
    end
end

local function UpdateAllRealButtons()
    local cfg, partyCfg = GetRuntimeConfigs()
    wipe(unitFrameMap)
    for _, button in ipairs(nativePartyFrames) do
        local unit = button:GetAttribute("unit")
        if type(unit) == "string" then
            local entry = unitFrameMap[unit]
            if not entry then entry = {}; unitFrameMap[unit] = entry end
            entry.party = button
        end
        UpdateRealButton(button, partyCfg)
    end
    for _, button in ipairs(nativeRaidFrames) do
        local unit = button:GetAttribute("unit")
        if type(unit) == "string" then
            local entry = unitFrameMap[unit]
            if not entry then entry = {}; unitFrameMap[unit] = entry end
            entry.raid = button
        end
        UpdateRealButton(button, cfg)
    end
end

local function UpdateRealButtonsForUnit(unit, event)
    if type(unit) ~= "string" then return end

    local entry = unitFrameMap[unit]
    -- UNIT_* events are global and also arrive for target, focus and dozens of
    -- Ignore everything that is not represented by our group headers.
    if not entry then return end

    -- Secure headers may exchange their unit attributes after a roster change.
    -- Rebuild once on a stale hit instead of scanning all 45 buttons per event.
    if (entry.party and entry.party:GetAttribute("unit") ~= unit)
        or (entry.raid and entry.raid:GetAttribute("unit") ~= unit) then
        UpdateAllRealButtons()
        entry = unitFrameMap[unit]
        if not entry then return end
    end

    local cfg, partyCfg = GetRuntimeConfigs()
    if entry.party then UpdateRealButton(entry.party, partyCfg, event) end
    if entry.raid then UpdateRealButton(entry.raid, cfg, event) end
end

local UNIT_SCOPED_EVENTS = {
    UNIT_HEALTH = true,
    UNIT_MAXHEALTH = true,
    UNIT_HEAL_PREDICTION = true,
    UNIT_POWER_UPDATE = true,
    UNIT_MAXPOWER = true,
    UNIT_NAME_UPDATE = true,
    UNIT_CONNECTION = true,
    UNIT_AURA = true,
    UNIT_LEVEL = true,
    UNIT_IN_RANGE_UPDATE = true,
    UNIT_THREAT_SITUATION_UPDATE = true,
    UNIT_THREAT_LIST_UPDATE = true,
}

local pendingUnitUpdates = {}
local pendingUnitQueue = {}
local pendingUnitQueueHead = 1
local pendingUnitQueueTail = 0
local pendingEventPool = {}
local UNIT_UPDATES_PER_TICK = 8
local unitUpdateDriver = CreateFrame("Frame")
unitUpdateDriver:Hide()

unitUpdateDriver:SetScript("OnUpdate", function(self)
    local Perf = RexUI.Perf
    local perfStart = Perf and Perf:Start()
    local processed = 0
    while processed < UNIT_UPDATES_PER_TICK do
        local updateUnit = pendingUnitQueue[pendingUnitQueueHead]
        if not updateUnit then break end

        pendingUnitQueue[pendingUnitQueueHead] = nil
        pendingUnitQueueHead = pendingUnitQueueHead + 1
        local updateEvent = pendingUnitUpdates[updateUnit]
        pendingUnitUpdates[updateUnit] = nil

        if updateEvent then
            UpdateRealButtonsForUnit(updateUnit, updateEvent)
            wipe(updateEvent)
            pendingEventPool[#pendingEventPool + 1] = updateEvent
        end
        processed = processed + 1
    end
    if Perf then
        Perf:Stop("GroupFrames", perfStart, "onUpdates")
        if processed > 0 then Perf:Count("GroupFrames", "partialUpdates", processed) end
    end

    if not pendingUnitQueue[pendingUnitQueueHead] then
        wipe(pendingUnitQueue)
        pendingUnitQueueHead = 1
        pendingUnitQueueTail = 0
        self:Hide()
    end
end)

local function QueueRealButtonUpdate(unit, event)
    if type(unit) ~= "string" then return end
    if not unitFrameMap[unit] then return end

    local events = pendingUnitUpdates[unit]
    if not events then
        events = table.remove(pendingEventPool) or {}
        pendingUnitUpdates[unit] = events
        pendingUnitQueueTail = pendingUnitQueueTail + 1
        pendingUnitQueue[pendingUnitQueueTail] = unit
    end
    events[event] = true
    unitUpdateDriver:Show()
end

local function SetupRealButtonEvents()
    if nativeUpdateFrame then return end
    nativeUpdateFrame = CreateFrame("Frame")
    for _, event in ipairs({
        "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_HEAL_PREDICTION", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER",
        "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_AURA",
        "UNIT_LEVEL", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD",
        "UNIT_IN_RANGE_UPDATE",
        "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE",
        "READY_CHECK", "READY_CHECK_CONFIRM",
        "READY_CHECK_FINISHED", "PLAYER_ROLES_ASSIGNED", "RAID_TARGET_UPDATE",
        "GROUP_ROSTER_UPDATE",
    }) do
        nativeUpdateFrame:RegisterEvent(event)
    end
    nativeUpdateFrame:SetScript("OnEvent", function(_, event, unit)
        if UNIT_SCOPED_EVENTS[event] then
            QueueRealButtonUpdate(unit, event)
            return
        end
        if event == "GROUP_ROSTER_UPDATE" and C_Timer and C_Timer.After then
            C_Timer.After(0, UpdateAllRealButtons)
            return
        end
        UpdateAllRealButtons()
    end)
end

function GF:CreateHeaders()
    if partyHeader or InCombatLockdown() then return end
    local cfg = self:GetConfig()

    partyMover = CreateMover("RexUI_PartyFramesMover", "RexUI Gruppenframes", "partyPosition")
    raidMover = CreateMover("RexUI_RaidFramesMover", "RexUI Raidframes", "raidPosition")

    partyContainer = CreateFrame("Frame", "RexUI_PartyFramesContainer", UIParent)
    partyContainer:SetPoint("TOPLEFT", partyMover, "TOPLEFT")
    partyContainer:SetSize(cfg.partyFrameWidth, cfg.partyFrameHeight * 5)
    partyContainer:Show()

    raidContainer = CreateFrame("Frame", "RexUI_RaidFramesContainer", UIParent)
    raidContainer:SetPoint("TOPLEFT", raidMover, "TOPLEFT")
    raidContainer:SetSize((cfg.frameWidth + cfg.groupSpacing) * 8, cfg.frameHeight * 5)
    raidContainer:Show()

    partyHeader = CreateFrame("Frame", "RexUI_PartyFrames", partyContainer, "SecureGroupHeaderTemplate")
    partyHeader:SetPoint("TOPLEFT", partyContainer, "TOPLEFT", 0, 0)
    partyHeader:SetAttribute("template", "SecureUnitButtonTemplate")
    partyHeader:SetAttribute("templateType", "Button")
    partyHeader:SetAttribute("point", "TOP")
    partyHeader:SetAttribute("xOffset", 0)
    partyHeader:SetAttribute("yOffset", -(cfg.partyCellSpacing))
    partyHeader:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
    partyHeader:SetAttribute("showRaid", false)
    partyHeader:SetAttribute("showParty", true)
    partyHeader:SetAttribute("showPlayer", true)
    partyHeader:SetAttribute("showSolo", cfg.partyShowWhenSolo)
    partyHeader:SetAttribute("maxColumns", 1)
    partyHeader:SetAttribute("unitsPerColumn", 5)
    partyHeader:SetAttribute("sortMethod", "INDEX")
    partyHeader:SetAttribute("startingIndex", -4)
    partyHeader:Show()
    partyHeader:SetAttribute("startingIndex", 1)

    for index = 1, 5 do
        local button = partyHeader[index]
        if button then
            CreateRealButtonVisual(button, true)
            nativePartyFrames[#nativePartyFrames + 1] = button
        end
    end

    for group = 1, 8 do
        local header = CreateFrame("Frame", "RexUI_RaidGroupHeader" .. group, raidContainer, "SecureGroupHeaderTemplate")
        header:SetPoint("TOPLEFT", raidContainer, "TOPLEFT", (group - 1) * (cfg.frameWidth + cfg.groupSpacing), 0)
        header:SetAttribute("template", "SecureUnitButtonTemplate")
        header:SetAttribute("templateType", "Button")
        header:SetAttribute("point", "TOP")
        header:SetAttribute("xOffset", 0)
        header:SetAttribute("yOffset", -(cfg.cellSpacing))
        header:SetAttribute("groupFilter", tostring(group))
        header:SetAttribute("showRaid", true)
        header:SetAttribute("showParty", group == 1 and cfg.showWhenGroup)
        header:SetAttribute("showPlayer", true)
        header:SetAttribute("showSolo", group == 1 and cfg.showWhenSolo)
        header:SetAttribute("maxColumns", 1)
        header:SetAttribute("unitsPerColumn", 5)
        header:SetAttribute("sortMethod", "INDEX")
        header:SetAttribute("startingIndex", -4)
        header:Show()
        header:SetAttribute("startingIndex", 1)

        for index = 1, 5 do
            local button = header[index]
            if button then
                CreateRealButtonVisual(button, false)
                nativeRaidFrames[#nativeRaidFrames + 1] = button
            end
        end
        raidHeaders[group] = header
    end
    raidHeader = raidHeaders[1]

    SetupRealButtonEvents()
    self:Apply()
    -- Forever RestrictedExecution has no SetWidth/SetHeight. Header children
    -- are sized from normal Lua in ApplyRealButtonLayout. Do not refresh the
    -- SecureGroupHeader here; that rebuilds a restricted config body.
    C_Timer.After(0, UpdateAllRealButtons)
end

local function HookBlizzardGroupFrame(frame)
    if not frame or frame._rexGFVisibilityHooked then return end

    frame._rexGFVisibilityHooked = true
    hooksecurefunc(frame, "Show", function(self)
        local cfg = GF:GetConfig()
        if not cfg or cfg.hideBlizzard == false then return end

        self:SetAlpha(0)
        if InCombatLockdown() then
            pendingApply = true
        else
            self:Hide()
        end
    end)
end

function GF:ApplyBlizzardVisibility(cfg)
    cfg = cfg or self:GetConfig()
    if InCombatLockdown() then
        pendingApply = true
        return
    end

    local hide = cfg.hideBlizzard ~= false
    for _, frameName in ipairs(BLIZZARD_GROUP_FRAMES) do
        local frame = _G[frameName]
        if frame then
            HookBlizzardGroupFrame(frame)
            frame:SetAlpha(hide and 0 or 1)
            if hide then
                frame:Hide()
            else
                frame:Show()
            end
        end
    end

    if not hide and CompactRaidFrameManager_UpdateShown then
        CompactRaidFrameManager_UpdateShown()
    end
    if not hide and UIParent_ManageFramePositions then
        UIParent_ManageFramePositions()
    end
end

local function ApplyContainerVisibility(frame, condition)
    if not frame or not RegisterStateDriver then return end
    if UnregisterStateDriver then
        UnregisterStateDriver(frame, "visibility")
    end
    RegisterStateDriver(frame, "visibility", condition)
end

function GF:Apply()
    if not partyHeader then return end
    if InCombatLockdown() then
        pendingApply = true
        return
    end

    local cfg = self:GetConfig()
    local partyCfg = GetPartyConfig(cfg)
    self.Config = cfg
    self.PartyConfig = partyCfg
    -- Party and raid frames are intentionally independent:
    -- party frames are party-only, raid frames are raid-only.
    local partyVisibility = cfg.partyEnabled and "[group:party,nogroup:raid] show; hide" or "hide"
    local raidVisibility = cfg.raidEnabled and "[group:raid] show; hide" or "hide"
    ApplyContainerVisibility(partyContainer, partyVisibility)
    ApplyContainerVisibility(raidContainer, raidVisibility)
    partyHeader:ClearAllPoints()
    partyHeader:SetPoint("TOPLEFT", partyContainer, "TOPLEFT", 0, 0)
    if cfg.partyEnabled then
        partyHeader:Show()
    else
        partyHeader:Hide()
    end
    if cfg.raidEnabled then
        for _, header in ipairs(raidHeaders) do header:Show() end
    else
        for _, header in ipairs(raidHeaders) do header:Hide() end
    end
    partyHeader:SetAttribute("showParty", cfg.partyEnabled)
    partyHeader:SetAttribute("showSolo", false)
    partyHeader:SetAttribute("yOffset", -(cfg.partyCellSpacing))

    for group, header in ipairs(raidHeaders) do
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", raidContainer, "TOPLEFT", (group - 1) * (cfg.frameWidth + cfg.groupSpacing), 0)
        header:SetAttribute("showRaid", cfg.raidEnabled)
        header:SetAttribute("showParty", false)
        header:SetAttribute("showSolo", false)
        header:SetAttribute("yOffset", -(cfg.cellSpacing))
    end

    PositionMover(partyMover, cfg.partyPosition, cfg.partyFrameWidth, cfg.partyFrameHeight * 5)
    PositionMover(raidMover, cfg.raidPosition, (cfg.frameWidth + cfg.groupSpacing) * 8, cfg.frameHeight * 5)
    if not cfg.partyEnabled and partyMover then partyMover:Hide() end
    if not cfg.raidEnabled and raidMover then raidMover:Hide() end

    if partyContainer then partyContainer:SetSize(cfg.partyFrameWidth, cfg.partyFrameHeight * 5) end
    if raidContainer then raidContainer:SetSize((cfg.frameWidth + cfg.groupSpacing) * 8, cfg.frameHeight * 5) end
    for _, button in ipairs(nativePartyFrames) do ApplyRealButtonLayout(button, partyCfg) end
    for _, button in ipairs(nativeRaidFrames) do ApplyRealButtonLayout(button, cfg) end
    UpdateAllRealButtons()

    self:ApplyBlizzardVisibility(cfg)
    if (previewCount == 5 and not cfg.partyEnabled) or (previewCount == 20 and not cfg.raidEnabled) then
        self:HidePreview()
    elseif previewCount > 0 then
        self:ShowPreview(previewCount)
    end
end

function GF:ShowMover()
    if InCombatLockdown() then
        RexUI:PrintMessage("Gruppenframes können im Kampf nicht positioniert werden.")
        return
    end
    if not partyMover or not raidMover then
        self:CreateHeaders()
    end
    local cfg = self:GetConfig()
    if cfg.partyEnabled == false and cfg.raidEnabled == false then
        RexUI:PrintMessage("Gruppen- und Raidframes sind deaktiviert.")
        return
    end
    if partyMover then partyMover:SetShown(cfg.partyEnabled ~= false) end
    if raidMover then raidMover:SetShown(cfg.raidEnabled ~= false) end
end

function GF:HideMover()
    if InCombatLockdown() then
        pendingHideAllMovers = true
        return
    end
    pendingHideAllMovers = nil
    if partyMover then partyMover:Hide() end
    if raidMover then raidMover:Hide() end
end

function GF:ShowPartyMover()
    if InCombatLockdown() then
        RexUI:PrintMessage("Partyframes können im Kampf nicht positioniert werden.")
        return
    end
    if not partyMover then self:CreateHeaders() end
    local cfg = self:GetConfig()
    if cfg.partyEnabled == false then
        RexUI:PrintMessage("Partyframes sind deaktiviert.")
        return
    end
    if raidMover then raidMover:Hide() end
    if partyMover then partyMover:Show() end
end

function GF:HidePartyMover()
    if InCombatLockdown() then
        pendingHidePartyMover = true
        return
    end
    pendingHidePartyMover = nil
    if partyMover then partyMover:Hide() end
end

function GF:ShowRaidMover()
    if InCombatLockdown() then
        RexUI:PrintMessage("Raidframes können im Kampf nicht positioniert werden.")
        return
    end
    if not raidMover then self:CreateHeaders() end
    local cfg = self:GetConfig()
    if cfg.raidEnabled == false then
        RexUI:PrintMessage("Raidframes sind deaktiviert.")
        return
    end
    if partyMover then partyMover:Hide() end
    if raidMover then raidMover:Show() end
end

function GF:HideRaidMover()
    if InCombatLockdown() then
        pendingHideRaidMover = true
        return
    end
    pendingHideRaidMover = nil
    if raidMover then raidMover:Hide() end
end

function GF:ToggleMover()
    if (partyMover and partyMover:IsShown()) or (raidMover and raidMover:IsShown()) then
        self:HideMover()
    else
        self:ShowMover()
    end
end

function GF:Initialize()
    self.initialized = true

    self:CreateHeaders()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if pendingHideAllMovers then
                pendingHidePartyMover = nil
                pendingHideRaidMover = nil
                GF:HideMover()
            else
                if pendingHidePartyMover then GF:HidePartyMover() end
                if pendingHideRaidMover then GF:HideRaidMover() end
            end
            if pendingApply then
                pendingApply = nil
                GF:Apply()
            end
        elseif (event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD") and not InCombatLockdown() then
            C_Timer.After(0, function() GF:Apply() end)
        end
    end)
end

SLASH_REXUIGROUPFRAMES1 = "/rexframes"
SlashCmdList.REXUIGROUPFRAMES = function(input)
    input = string.lower(strtrim(tostring(input or "")))

    local requestedCount = tonumber(input:match("^test(%d+)$") or input)
    if requestedCount and requestedCount >= 10 and requestedCount <= 40 and requestedCount % 5 == 0 then
        GF:ShowPreview(requestedCount)
        RexUI:PrintMessage(string.format("%der-Raidtest gestartet.", requestedCount))
        return
    end
    if input == "test" then
        GF:ShowPreview(20)
        RexUI:PrintMessage("20er-Raidtest gestartet.")
        return
    end
    if input == "test5" or input == "5" then
        GF:ShowPreview(5)
        RexUI:PrintMessage("5er-Gruppentest gestartet.")
        return
    end
    if input == "stop" or input == "aus" then
        GF:HidePreview()
        RexUI:PrintMessage("Gruppenframe-Test beendet.")
        return
    end
    if input == "mover" then
        GF:ToggleMover()
        return
    end

    local cfg = GF:GetConfig()
    RexUI:PrintMessage(string.format(
        "Gruppenframes: Modul=%s, PartyHeader=%s, RaidHeader=%s, Buttons=%d, Gruppe=%s, Raid=%s, Solo=%s",
        GF.initialized and "geladen" or "nicht initialisiert",
        partyHeader and "ja" or "nein",
        raidHeader and "ja" or "nein",
        #nativePartyFrames + #nativeRaidFrames,
        cfg.partyEnabled and "an" or "aus",
        cfg.raidEnabled and "an" or "aus",
        cfg.partyShowWhenSolo and "an" or "aus"
    ))
    RexUI:PrintMessage("Befehle: /rexframes test5, /rexframes 10/15/20/25/30/35/40, /rexframes stop, /rexframes mover")
end
