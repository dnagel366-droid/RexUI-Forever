local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI
if not RexUI then return end

RexUI.QuestTracker = RexUI.QuestTracker or {}
local QT = RexUI.QuestTracker
RexUI:RegisterModule("QuestTracker", QT)

local function T(text)
    return RexUI:LocalizeText(text)
end

local FONT = "Fonts\\FRIZQT__.TTF"
local TEXTURE = "Interface\\Buttons\\WHITE8X8"

local hiddenFrame = CreateFrame("Frame", nil, UIParent)
hiddenFrame:Hide()

QT.DefaultConfig = {
    enabled = true,
    point = "TOPLEFT",
    relPoint = "TOPLEFT",
    x = 20,
    y = -240,
    width = 280,
    skinHeaders = true,
    titleFontSize = 12,
    objectiveFontSize = 10,
    bgR = 0.035, bgG = 0.035, bgB = 0.035, bgAlpha = 0.75,
    titleR = 1, titleG = 0.91, titleB = 0.471,
    completedR = 0.251, completedG = 1, completedB = 0.349,
    autoHideInstance = false,
    autoAccept = false,
    autoTurnIn = false,
}

local function copyConfig(defaults, saved)
    local cfg = {}
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            cfg[k] = copyConfig(v, saved and type(saved[k]) == "table" and saved[k] or nil)
        elseif saved and saved[k] ~= nil then
            cfg[k] = saved[k]
        else
            cfg[k] = v
        end
    end
    if type(saved) == "table" then
        for k, v in pairs(saved) do
            if cfg[k] == nil then cfg[k] = v end
        end
    end
    return cfg
end

function QT:GetConfig()
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    return copyConfig(self.DefaultConfig, profile and profile.questTracker)
end

function QT:Save(key, value)
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    if not profile then return end
    profile.questTracker = profile.questTracker or {}
    profile.questTracker[key] = value
end

local mover
local _skinned = setmetatable({}, { __mode = "k" })
local SUB_TRACKERS = {
    "ScenarioObjectiveTracker",
    "UIWidgetObjectiveTracker",
    "CampaignQuestObjectiveTracker",
    "QuestObjectiveTracker",
    "AdventureObjectiveTracker",
    "AchievementObjectiveTracker",
    "ProfessionsRecipeTracker",
    "BonusObjectiveTracker",
    "WorldQuestObjectiveTracker",
}

local function GetTitleRGB(cfg) return cfg.titleR or 1, cfg.titleG or 0.91, cfg.titleB or 0.471 end
local function GetCompletedRGB(cfg) return cfg.completedR or 0.251, cfg.completedG or 1, cfg.completedB or 0.349 end
local function GetObjSize(cfg) return cfg.objectiveFontSize or 10 end
local function GetTitleSize(cfg) return cfg.titleFontSize or 12 end

local function StyleFontString(fs, size)
    if not fs then return end
    local _, cur = fs:GetFont()
    pcall(fs.SetFont, fs, FONT, size or cur or 12, "OUTLINE")
end

local function StripTextures(frame)
    if not frame or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region:GetObjectType() == "Texture" and region.SetTexture then
            region:SetTexture("")
        end
    end
end

local function SkinBlock(block, preserveVisuals)
    if not block or _skinned[block] then return end

    -- Match the ElvUI principle for Scenario/UIWidget blocks: Blizzard owns
    -- their contents and state. Do not partially strip a Delve block, because
    -- that creates the mixed Blizzard/RexUI appearance seen on progress UI.
    if not preserveVisuals then
        for _, k in ipairs({"Background", "HeaderBackground", "Stripe", "Sheen", "Glow", "Highlight"}) do
            local r = block[k]
            if r and r.SetAlpha then r:SetAlpha(0) end
        end
    end

    if block.GetRegions then
        local cfg = QT:GetConfig()
        for _, rg in ipairs({ block:GetRegions() }) do
            local ot = rg.GetObjectType and rg:GetObjectType()
            if ot == "FontString" then
                StyleFontString(rg, GetObjSize(cfg))
            end
        end
    end

    if block.lines then
        for _, line in pairs(block.lines) do
            if line and line.Text then
                StyleFontString(line.Text, GetObjSize(QT:GetConfig()))
            end
        end
    end

    _skinned[block] = true
end

local function StyleObjectiveLine(line)
    if not line or not line.Text then return end
    StyleFontString(line.Text, GetObjSize(QT:GetConfig()))
    if line.Dash then StyleFontString(line.Dash, GetObjSize(QT:GetConfig())) end
end

local function SkinHeader(header)
    if not header then return end
    local cfg = QT:GetConfig()
    if cfg.skinHeaders == false then return end

    for _, k in ipairs({"Background", "Line", "LineSheen", "LineGlow", "Divider", "Sheen", "Glow"}) do
        local r = header[k]
        if r and r.SetTexture then r:SetTexture("") end
    end
    StripTextures(header)

    local text = header.Text
    if text then
        StyleFontString(text, GetTitleSize(cfg))
        text:SetTextColor(GetTitleRGB(cfg))
    end
end

local function IsDelveTracker(tracker)
    return tracker == _G.ScenarioObjectiveTracker or tracker == _G.UIWidgetObjectiveTracker
end

local function SkinExistingBlocks(tracker)
    if not tracker then return end
    local preserveVisuals = IsDelveTracker(tracker)
    if tracker.Header then
        if preserveVisuals then
            if tracker.Header.SetAlpha then tracker.Header:SetAlpha(1) end
            for _, k in ipairs({"Background", "Line", "LineSheen", "LineGlow", "Divider", "Sheen", "Glow"}) do
                local r = tracker.Header[k]
                if r and r.SetAlpha then r:SetAlpha(0) end
            end
            if tracker.Header.Text then
                StyleFontString(tracker.Header.Text, GetTitleSize(QT:GetConfig()))
                tracker.Header.Text:SetTextColor(GetTitleRGB(QT:GetConfig()))
                tracker.Header.Text:SetAlpha(1)
            end
        else
            SkinHeader(tracker.Header)
        end
    end
    if preserveVisuals and tracker.SetAlpha then tracker:SetAlpha(1) end
    if tracker.usedBlocks then
        for _, byTemplate in pairs(tracker.usedBlocks) do
            if type(byTemplate) == "table" then
                for _, block in pairs(byTemplate) do
                    if type(block) == "table" then SkinBlock(block, preserveVisuals) end
                end
            end
        end
        for _, byTemplate in pairs(tracker.usedBlocks) do
            if type(byTemplate) == "table" then
                for _, block in pairs(byTemplate) do
                    if type(block) == "table" and block.lines then
                        for _, line in pairs(block.lines) do
                            StyleObjectiveLine(line)
                            if preserveVisuals then
                                if line.Text and line.Text.SetAlpha then line.Text:SetAlpha(1) end
                                if line.Dash and line.Dash.SetAlpha then line.Dash:SetAlpha(1) end
                            end
                        end
                        if preserveVisuals and block.SetAlpha then block:SetAlpha(1) end
                    end
                end
            end
        end
    end
end

local _hookedTrackers = setmetatable({}, { __mode = "k" })

-- ObjectiveTracker skinning follows ElvUI's ownership model:
-- Blizzard creates, lays out and updates every tracker/block/widget. RexUI only
-- skins the objects returned by Blizzard's AddBlock/GetProgressBar/GetTimerBar.
local function ClearHeaderBackground(header)
    if not header then return end
    local bg = header.Background
    if bg and bg.SetAtlas then pcall(bg.SetAtlas, bg, nil) end
end

local function SkinQuestIcon(button)
    if not button or button.rexSkinned then return end
    button.rexSkinned = true
    if button.SetSize then button:SetSize(24, 24) end
    if button.SetNormalTexture then button:SetNormalTexture(TEXTURE) local n=button:GetNormalTexture(); if n then n:SetAlpha(0) end end
    if button.SetPushedTexture then button:SetPushedTexture(TEXTURE) local n=button:GetPushedTexture(); if n then n:SetAlpha(0) end end
    local hi = button.GetHighlightTexture and button:GetHighlightTexture()
    if hi and hi.SetColorTexture then hi:SetColorTexture(1,1,1,.25) end
    local icon = button.icon or button.Icon
    if icon and icon.SetTexCoord then
        icon:SetTexCoord(.08,.92,.08,.92)
    end
end

local function HandleBlock(_, block)
    if not block then return end
    SkinQuestIcon(block.ItemButton)
    SkinQuestIcon(block.itemButton)
    local check = block.currentLine and block.currentLine.Check
    if check and not check.rexSkinned then
        if check.SetAtlas then pcall(check.SetAtlas, check, 'checkmark-minimal') end
        if check.SetDesaturated then check:SetDesaturated(true) end
        if check.SetVertexColor then check:SetVertexColor(0,1,0) end
        check.rexSkinned = true
    end
end

local function SkinStatusBar(bar)
    if not bar or bar.rexTrackerBarSkinned then return end
    bar.rexTrackerBarSkinned = true
    StripTextures(bar)
    if bar.SetStatusBarTexture then bar:SetStatusBarTexture(TEXTURE) end

    local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetPoint("TOPLEFT", -1, 1)
    bg:SetPoint("BOTTOMRIGHT", 1, -1)
    bg:SetColorTexture(.035,.035,.035,.95)
    bar.rexTrackerBG = bg

    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({ edgeFile = TEXTURE, edgeSize = 1 })
    border:SetBackdropBorderColor(.12,.12,.12,1)
    border:SetFrameLevel(math.max(0, bar:GetFrameLevel()))
    border:EnableMouse(false)
    bar.rexTrackerBorder = border
end

local function HandleProgressBar(tracker, key)
    local progress = tracker and tracker.usedProgressBars and tracker.usedProgressBars[key]
    local bar = progress and progress.Bar
    if not bar then return end
    SkinStatusBar(bar)
    local label = bar.Label
    if label then
        StyleFontString(label, GetObjSize(QT:GetConfig()))
        label:ClearAllPoints()
        label:SetPoint("CENTER", bar)
    end
    local icon = bar.Icon
    if icon and icon.IsShown and icon:IsShown() and not icon.rexSkinned then
        icon.rexSkinned = true
        if icon.SetMask then pcall(icon.SetMask, icon, '') end
        if icon.SetTexCoord then icon:SetTexCoord(.08,.92,.08,.92) end
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", bar, "RIGHT", 4, 0)
    end
end

local function HandleTimerBar(tracker, key)
    local timer = tracker and tracker.usedTimerBars and tracker.usedTimerBars[key]
    local bar = timer and timer.Bar
    if bar then SkinStatusBar(bar) end
end

local function StyleHeader(header)
    if not header then return end
    local cfg = QT:GetConfig()
    ClearHeaderBackground(header)
    if header.Text then
        StyleFontString(header.Text, GetTitleSize(cfg))
        header.Text:SetTextColor(GetTitleRGB(cfg))
    end
    local min = header.MinimizeButton
    if min and min.SetSize then min:SetSize(15,15) end
end

local function HookObjectiveTracker(tracker)
    if not tracker or _hookedTrackers[tracker] then return end
    _hookedTrackers[tracker] = true
    StyleHeader(tracker.Header)

    if tracker.AddBlock then
        hooksecurefunc(tracker, "AddBlock", HandleBlock)
    end
    if tracker.GetProgressBar then
        hooksecurefunc(tracker, "GetProgressBar", function(self, key)
            HandleProgressBar(self, key)
        end)
    end
    if tracker.GetTimerBar then
        hooksecurefunc(tracker, "GetTimerBar", function(self, key)
            HandleTimerBar(self, key)
        end)
    end
end

local function EachTracker(fn)
    local seen = {}
    local otf = _G.ObjectiveTrackerFrame
    local modules = otf and (otf.modules or otf.MODULES)
    if modules then
        for _, tracker in ipairs(modules) do
            if tracker and not seen[tracker] then seen[tracker]=true; fn(tracker) end
        end
    end
    for _, name in ipairs(SUB_TRACKERS) do
        local tracker = _G[name]
        if tracker and not seen[tracker] then seen[tracker]=true; fn(tracker) end
    end
end

function QT:ApplySkin()
    local cfg = self:GetConfig()
    if cfg.enabled == false then return end
    local otf = _G.ObjectiveTrackerFrame
    if not otf then return end

    -- Main header + every Blizzard subtracker are skinned through secure hooks,
    -- exactly like ElvUI: no SetParent/SetHeight/SetAlpha/widget-pool ownership.
    StyleHeader(otf.Header)
    EachTracker(HookObjectiveTracker)

    -- Skin bars/blocks that existed before RexUI installed its hooks.
    EachTracker(function(tracker)
        StyleHeader(tracker.Header)
        if tracker.usedProgressBars then
            for key in pairs(tracker.usedProgressBars) do HandleProgressBar(tracker, key) end
        end
        if tracker.usedTimerBars then
            for key in pairs(tracker.usedTimerBars) do HandleTimerBar(tracker, key) end
        end
        if tracker.usedBlocks then
            for _, pool in pairs(tracker.usedBlocks) do
                if type(pool)=="table" then
                    for _, block in pairs(pool) do
                        if type(block)=="table" then HandleBlock(tracker, block) end
                    end
                end
            end
        end
    end)
end

function QT:CreateMover()
    if mover then return end

    mover = CreateFrame("Frame", nil, UIParent)
    mover:SetFrameLevel(500)
    mover:SetSize(150, 40)
    mover:SetClampedToScreen(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:Hide()

    mover.Bg = mover:CreateTexture(nil, "BACKGROUND")
    mover.Bg:SetAllPoints(mover)
    mover.Bg:SetColorTexture(0.2, 0.6, 1, 0.25)

    mover.Label = mover:CreateFontString(nil, "OVERLAY")
    mover.Label:SetFont(FONT, 9, "OUTLINE")
    mover.Label:SetPoint("CENTER")
    mover.Label:SetText(T("Questverfolgung"))

    mover:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        local otf = _G.ObjectiveTrackerFrame
        if otf then
            local w = otf:GetWidth() or 280
            local h = otf:GetHeight() or 60
            self:SetSize(w, h)
        else
            self:SetSize(280, 60)
        end
        self:SetMovable(true)
        self:StartMoving()
    end)

    mover:SetScript("OnDragStop", function(self)
        if InCombatLockdown() then return end
        self:StopMovingOrSizing()
        self:SetMovable(false)

        local left, bottom, w, h = self:GetRect()
        if left then
            local cx, cy = UIParent:GetCenter()
            local fx = math.floor((left + w / 2 - cx) + 0.5)
            local fy = math.floor((bottom + h / 2 - cy) + 0.5)
            QT:Save("point", "CENTER")
            QT:Save("relPoint", "CENTER")
            QT:Save("x", fx)
            QT:Save("y", fy)
            local otf = _G.ObjectiveTrackerFrame
            if otf then
                otf:ClearAllPoints()
                otf:SetPoint("CENTER", UIParent, "CENTER", fx, fy)
            end
        end
    end)

    mover:SetScript("OnMouseUp", function(self)
        if self.dragged then
            self.dragged = false
            return end
        if RexUI.ConfigUI and RexUI.ConfigUI.Open then
            RexUI.ConfigUI:Open()
        end
    end)
end

function QT:ShowMover()
    if not mover then self:CreateMover() end
    local otf = _G.ObjectiveTrackerFrame
    if not otf or not mover then return end

    mover:ClearAllPoints()
    local w = otf:GetWidth() or 280
    local h = otf:GetHeight() or 60
    mover:SetSize(w, h)
    mover:SetPoint("TOPLEFT", otf, "TOPLEFT", 0, 0)
    mover:Show()
end

function QT:HideMover()
    if mover then mover:Hide() end
end

local function PositionTracker()
    local cfg = QT:GetConfig()
    local otf = _G.ObjectiveTrackerFrame
    if not otf then return end
    otf:ClearAllPoints()
    otf:SetPoint(cfg.point or "TOPLEFT", UIParent, cfg.relPoint or cfg.point or "TOPLEFT", cfg.x or 20, cfg.y or -240)
end

local autoFrame
local function InstallAutoQuests()
    if autoFrame then return end
    autoFrame = CreateFrame("Frame")
    autoFrame:RegisterEvent("QUEST_DETAIL")
    autoFrame:RegisterEvent("QUEST_COMPLETE")
    autoFrame:RegisterEvent("GOSSIP_SHOW")
    autoFrame:SetScript("OnEvent", function(_, event)
        local cfg = QT:GetConfig()
        if cfg.enabled == false then return end
        if event == "QUEST_DETAIL" then
            if cfg.autoAccept then AcceptQuest() end
        elseif event == "QUEST_COMPLETE" then
            if cfg.autoTurnIn then
                if IsShiftKeyDown() then return end
                local num = GetNumQuestChoices()
                if num <= 1 then GetQuestReward(num) end
            end
        elseif event == "GOSSIP_SHOW" then
            if C_GossipInfo then
                if cfg.autoTurnIn and C_GossipInfo.GetActiveQuests then
                    local active = C_GossipInfo.GetActiveQuests()
                    if active then
                        for _, q in ipairs(active) do
                            if q.questID and q.isComplete then
                                C_GossipInfo.SelectActiveQuest(q.questID)
                                return
                            end
                        end
                    end
                end
                if cfg.autoAccept and C_GossipInfo.GetAvailableQuests then
                    local avail = C_GossipInfo.GetAvailableQuests()
                    if avail and #avail > 0 and avail[1].questID then
                        C_GossipInfo.SelectAvailableQuest(avail[1].questID)
                    end
                end
            end
        end
    end
)
end

local _autoHidden = false
local _collapsed = false

local function Collapse()
    local otf = _G.ObjectiveTrackerFrame
    if not otf or _collapsed or InCombatLockdown() then return end
    _collapsed = true
    otf:SetParent(hiddenFrame)
end

local function Expand()
    local otf = _G.ObjectiveTrackerFrame
    if not otf or not _collapsed or InCombatLockdown() then return end
    _collapsed = false
    otf:SetParent(UIParent)
end

local function ShouldAutoHide()
    local cfg = QT:GetConfig()
    if cfg.autoHideInstance ~= true then return false end
    local _, instanceType = GetInstanceInfo()
    return instanceType == "raid" or instanceType == "arena" or instanceType == "party"
end

local function UpdateAutoHide()
    if ShouldAutoHide() then
        Collapse()
    else
        Expand()
    end
end
QT.UpdateAutoHide = UpdateAutoHide

local zoneFrame = CreateFrame("Frame")
zoneFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
zoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneFrame:SetScript("OnEvent", UpdateAutoHide)

function QT:Update()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingUpdate = true
        return
    end

    self.pendingUpdate = nil
    PositionTracker()
    self:ApplySkin()
    self:CreateMover()
    UpdateAutoHide()

    if RexUI.Unlocked then
        self:ShowMover()
    else
        self:HideMover()
    end
end

function QT:Initialize()
    if self.initialized then return end
    self.initialized = true

    self:Update()
    InstallAutoQuests()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    initFrame:UnregisterAllEvents()
    if RexUI.QuestTracker then
        RexUI.QuestTracker:Initialize()
    end
end)

local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function()
    if QT.pendingUpdate then
        QT:Update()
    end
end)