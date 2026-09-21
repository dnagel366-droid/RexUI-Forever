local ADDON_NAME, ns = ...
local RexUI = ns.RexUI
if not RexUI then return end

local Skin = RexUI.BlizzardSkin
if not Skin then return end

local MEDIA = "Interface\\AddOns\\RexUI\\media\\basics\\"
local FACTION_TEX = {
    Alliance = MEDIA .. "alliance.png",
    Horde    = MEDIA .. "horde.png",
}
local NEUTRAL_TEX = MEDIA .. "neutral.png"
local OFFLINE_ICON = MEDIA .. "offline.png"
local CLASS_COORDS = CLASS_ICON_TCOORDS or {}
local TILE_BG = { 0, 0, 0, 0.10 }

local FFD = setmetatable({}, { __mode = "k" })
local function GetFFD(frame)
    local d = FFD[frame]
    if not d then d = {}; FFD[frame] = d end
    return d
end

local function GetConfig()
    local profile = RexUI:GetProfile()
    profile.blizzardSkin = profile.blizzardSkin or {}
    return profile.blizzardSkin
end

local function IsEnabled(key)
    local config = GetConfig()
    if config.enabled == false then return false end
    if key and config[key] == false then return false end
    return true
end

local _friendCache = {}
local _FC_WOW_OFFSET = 10000

local function BuildClassNameLookup()
    local lookup = {}
    if LOCALIZED_CLASS_NAMES_MALE then
        for token, name in pairs(LOCALIZED_CLASS_NAMES_MALE) do lookup[name] = token end
    end
    if LOCALIZED_CLASS_NAMES_FEMALE then
        for token, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do lookup[name] = token end
    end
    return lookup
end
local classByLocalName = setmetatable({}, { __index = function(t, k)
    local v = BuildClassNameLookup()[k]
    t[k] = v
    return v
end})

local function GetClassFile(bnetInfo, wowInfo)
    if bnetInfo and bnetInfo.gameAccountInfo then
        local gi = bnetInfo.gameAccountInfo
        if gi.classID and gi.classID > 0 then
            local _, f = GetClassInfo(gi.classID)
            return f
        end
        if gi.className then return classByLocalName[gi.className] end
    elseif wowInfo and wowInfo.className then
        return classByLocalName[wowInfo.className]
    end
end

local function RefreshCache()
    wipe(_friendCache)
    for i = 1, BNGetNumFriends() do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info then _friendCache[i] = info end
    end
    for i = 1, C_FriendList.GetNumFriends() do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info then _friendCache[i + _FC_WOW_OFFSET] = info end
    end
end

local function GetCached(button)
    if not button or not button.buttonType or not button.id then return end
    if button.buttonType == FRIENDS_BUTTON_TYPE_BNET then
        return _friendCache[button.id]
    elseif button.buttonType == FRIENDS_BUTTON_TYPE_WOW then
        return _friendCache[button.id + _FC_WOW_OFFSET]
    end
end

local _orbFile, _orbL, _orbR, _orbT, _orbB
do
    local oi = C_Texture.GetAtlasInfo("lootroll-animreveal-a")
    if oi then
        _orbFile = oi.file
        local w, h = oi.rightTexCoord - oi.leftTexCoord, oi.bottomTexCoord - oi.topTexCoord
        _orbL, _orbR, _orbT, _orbB = oi.leftTexCoord, oi.leftTexCoord + w/6, oi.topTexCoord, oi.topTexCoord + h/2
    end
end

local function StripTextures(f)
    if not f then return end
    for i = 1, select("#", f:GetRegions()) do
        local r = select(i, f:GetRegions())
        if r:IsObjectType("Texture") then r:SetAlpha(0) end
    end
end

local function ApplyPanel(frame, inset)
    if not frame then return end
    inset = inset or 0
    if frame.NineSlice then frame.NineSlice:SetAlpha(0) end
    if not frame.RexBg then
        frame.RexBg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        frame.RexBg:SetAllPoints()
        frame.RexBg:SetColorTexture(RexUI:GetColor("background"))
    end
    if not frame.RexBorder then
        frame.RexBorder = Skin:CreateBorder(frame)
        frame.RexBorder:SetFrameLevel((frame:GetFrameLevel() or 1) + 1)
    end
    frame.RexBorder:ClearAllPoints()
    frame.RexBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    frame.RexBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    Skin:SetBorderColor(frame.RexBorder, RexUI:GetColor("border"))
    frame.RexBorder:Show()
end

local function StyleCloseButton(btn)
    if not btn or GetFFD(btn).done then return end
    GetFFD(btn).done = true
    StripTextures(btn)
    local x = btn:CreateFontString(nil, "OVERLAY")
    x:SetFont(STANDARD_TEXT_FONT, 14, "THICKOUTLINE")
    x:SetTextColor(1, 1, 1, 0.5)
    x:SetText("x")
    x:SetPoint("CENTER", 2, -1)
    btn:HookScript("OnEnter", function() x:SetTextColor(1, 1, 1, 0.9) end)
    btn:HookScript("OnLeave", function() x:SetTextColor(1, 1, 1, 0.5) end)
end

local function SkinFriendButton(button)
    if GetFFD(button).skinned then return end
    GetFFD(button).skinned = true

    local name = button.name or button.Name
    local info = button.info or button.Info

    if not GetFFD(button).tile then
        local t = button:CreateTexture(nil, "BACKGROUND", nil, 2)
        t:SetAllPoints()
        t:SetColorTexture(TILE_BG[1], TILE_BG[2], TILE_BG[3], TILE_BG[4])
        GetFFD(button).tile = t
    end

    if name then
        name:SetFont(STANDARD_TEXT_FONT, 12, "")
        name:SetShadowOffset(1, -1)
        name:SetShadowColor(0, 0, 0, 0.8)
        local p1, rel, p2, x, y = name:GetPoint(1)
        if p1 then name:SetPoint(p1, rel, p2, (x or 0) + 20, y or 0) end
    end
    if info then
        info:SetFont(STANDARD_TEXT_FONT, 9, "")
        info:SetShadowOffset(1, -1)
        info:SetShadowColor(0, 0, 0, 0.8)
    end

    local hover = button:CreateTexture(nil, "ARTWORK", nil, -7)
    hover:SetAllPoints()
    hover:SetAtlas("groupfinder-highlightbar-green")
    hover:SetDesaturated(true)
    hover:SetVertexColor(0.4, 0.7, 1.0)
    hover:Hide()
    local hoverFill = button:CreateTexture(nil, "ARTWORK", nil, -8)
    hoverFill:SetAllPoints()
    hoverFill:SetColorTexture(1, 1, 1, 0.02)
    hoverFill:SetBlendMode("ADD")
    hoverFill:Hide()
    button:HookScript("OnEnter", function() hover:Show(); hoverFill:Show() end)
    button:HookScript("OnLeave", function() hover:Hide(); hoverFill:Hide() end)
end

local function PostUpdateFriendButton(button)
    if not button or not button.buttonType or not IsEnabled("friends") then return end
    if button.buttonType == FRIENDS_BUTTON_TYPE_DIVIDER then return end
    SkinFriendButton(button)

    local fav = button.Favorite
    if fav then fav:SetAlpha(0) end
    local si = button.statusIcon or button.StatusIcon
    if si then si:SetAlpha(0) end
    local st = button.status
    if st and st:IsObjectType("Texture") then st:SetAlpha(0) end
    local gi = button.gameIcon
    if gi then gi:SetAlpha(0) end

    local curType, curId = button.buttonType, button.id or 0
    if GetFFD(button).stampType == curType and GetFFD(button).stampId == curId then return end
    GetFFD(button).stampType = curType
    GetFFD(button).stampId = curId

    local cached = GetCached(button)
    if not cached then return end

    local bnetInfo, wowInfo
    if button.buttonType == FRIENDS_BUTTON_TYPE_BNET then bnetInfo = cached else wowInfo = cached end

    local name = button.name or button.Name
    local info = button.info or button.Info

    if info and name then
        info:ClearAllPoints()
        info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    end

    local classFile = GetClassFile(bnetInfo, wowInfo)

    if not GetFFD(button).classIcon then
        GetFFD(button).classIcon = button:CreateTexture(nil, "ARTWORK", nil, 2)
    end
    local icon = GetFFD(button).classIcon
    local h = button:GetHeight() - 4
    local isOnline = (bnetInfo and bnetInfo.gameAccountInfo and bnetInfo.gameAccountInfo.isOnline) or
                     (wowInfo and wowInfo.connected)
    local isRetail = (bnetInfo and bnetInfo.gameAccountInfo and bnetInfo.gameAccountInfo.clientProgram == BNET_CLIENT_WOW) or
                     (wowInfo and wowInfo.connected)

    if isOnline and isRetail and classFile and CLASS_COORDS[classFile] then
        icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        icon:SetTexCoord(unpack(CLASS_COORDS[classFile]))
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", button, "LEFT", 4, 0)
        icon:SetPoint("TOP", button, "TOP", 0, -3)
        icon:SetPoint("BOTTOM", button, "BOTTOM", 0, 3)
        icon:SetWidth(h - 6)
        icon:SetDesaturated(false)
        icon:SetAlpha(1)
        icon:Show()
    elseif isOnline then
        icon:SetSize(math.floor(h * 0.75), math.floor(h * 0.75))
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", button, "LEFT", 4 + math.floor((h - h * 0.75) / 2), 0)
        if gi then
            local t = gi:GetTexture()
            if t then icon:SetTexture(t) end
        end
        icon:SetTexCoord(0, 1, 0, 1)
        icon:SetDesaturated(false)
        icon:SetAlpha(1)
        icon:Show()
    else
        icon:SetSize(math.floor(h * 0.75), math.floor(h * 0.75))
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", button, "LEFT", 4 + math.floor((h - h * 0.75) / 2), 0)
        icon:SetTexture(OFFLINE_ICON)
        icon:SetTexCoord(0, 1, 0, 1)
        icon:SetDesaturated(false)
        icon:SetAlpha(0.5)
        icon:Show()
    end

    if classFile and isOnline then
        local cc = RAID_CLASS_COLORS[classFile]
        if cc and name then name:SetTextColor(cc.r, cc.g, cc.b) end
    elseif name then
        local nc = FRIENDS_BNET_NAME_COLOR or { r = 0.51, g = 0.773, b = 1.0 }
        name:SetTextColor(1, 1, 1, 0.8)
    end

    if not GetFFD(button).factionBg then
        GetFFD(button).factionBg = button:CreateTexture(nil, "BACKGROUND", nil, 3)
    end
    local fb = GetFFD(button).factionBg
    local factionName = bnetInfo and bnetInfo.gameAccountInfo and bnetInfo.gameAccountInfo.factionName
    if isOnline and isRetail and factionName then
        fb:SetTexture(FACTION_TEX[factionName] or NEUTRAL_TEX)
        fb:SetTexCoord(0, 1, 0, 1)
        fb:ClearAllPoints()
        fb:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        fb:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        fb:SetAlpha(0.2)
        fb:Show()
    else
        fb:Hide()
    end

    if not GetFFD(button).statusOrb then
        GetFFD(button).statusOrb = button:CreateTexture(nil, "OVERLAY", nil, 3)
        GetFFD(button).statusOrb:SetSize(18, 18)
        if _orbFile then
            GetFFD(button).statusOrb:SetTexture(_orbFile)
            GetFFD(button).statusOrb:SetTexCoord(_orbL, _orbR, _orbT, _orbB)
        else
            GetFFD(button).statusOrb:SetAtlas("lootroll-animreveal-a")
            GetFFD(button).statusOrb:SetTexCoord(0, 1/6, 0, 0.5)
        end
    end
    local orb = GetFFD(button).statusOrb
    orb:ClearAllPoints()
    if name then
        local tw = name:GetStringWidth() or 0
        orb:SetPoint("TOPLEFT", name, "TOPLEFT", tw - 1, 2)
    end
    if isOnline then
        local isAFK, isDND = false, false
        if bnetInfo then
            isAFK, isDND = bnetInfo.isAFK, bnetInfo.isDND
        elseif wowInfo then
            isAFK, isDND = wowInfo.afk, wowInfo.dnd
        end
        if isDND then orb:SetVertexColor(1, 0.2, 0.2, 1)
        elseif isAFK then orb:SetVertexColor(1, 0.8, 0, 1)
        else orb:SetVertexColor(0.2, 1, 0.2, 1) end
        orb:Show()
    else
        orb:SetVertexColor(0.4, 0.4, 0.4, 0.6)
        orb:Show()
    end
end

local function ProcessFriendButtons()
    local sb = FriendsListFrame and FriendsListFrame.ScrollBox
    if not sb then return end
    for _, btn in sb:EnumerateFrames() do
        if btn.buttonType and btn.buttonType ~= FRIENDS_BUTTON_TYPE_DIVIDER then
            GetFFD(btn).stampType = nil
            PostUpdateFriendButton(btn)
        end
    end
end

local function SkinFriendsFrame()
    if not IsEnabled("friends") then return end
    local frame = _G.FriendsFrame
    if not frame or GetFFD(frame).done then return end

    GetFFD(frame).done = true
    local fontPath = STANDARD_TEXT_FONT

    -- Hide Blizzard chrome (visual only)
    if frame.NineSlice then frame.NineSlice:Hide() end
    if frame.Bg then frame.Bg:Hide() end
    if frame.TitleBg then frame.TitleBg:Hide() end
    if frame.TopTileStreaks then frame.TopTileStreaks:SetAlpha(0) end
    if frame.PortraitContainer then frame.PortraitContainer:Hide() end
    if frame.portrait then frame.portrait:Hide() end
    if frame.PortraitFrame then frame.PortraitFrame:Hide() end
    for _, k in ipairs({"TopBorder","TopRightCorner","RightBorder","BottomRightCorner","BottomBorder","BottomLeftCorner","LeftBorder","TopLeftCorner","BtnCornerLeft","BtnCornerRight"}) do
        if frame[k] then frame[k]:Hide() end
    end
    if frame.Inset then
        if frame.Inset.NineSlice then frame.Inset.NineSlice:Hide() end
        if frame.Inset.Bg then frame.Inset.Bg:Hide() end
    end

    -- Background + Border (ApplyPanel style) — no resize, no overlays
    frame.RexBg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    frame.RexBg:SetAllPoints()
    frame.RexBg:SetColorTexture(RexUI:GetColor("background"))
    frame.RexBorder = Skin:CreateBorder(frame)
    frame.RexBorder:SetFrameLevel((frame:GetFrameLevel() or 1) + 1)
    Skin:SetBorderColor(frame.RexBorder, RexUI:GetColor("border"))
    frame.RexBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.RexBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.RexBorder:Show()

    -- Title
    local _, bt = BNGetInfo()
    local titleText = bt or FRIENDS
    if frame.TitleContainer then
        local t = frame.TitleContainer.TitleText or frame.TitleContainer:GetFontString()
        if t then t:SetAlpha(0) end
    end
    local tlbl = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tlbl:SetFont(fontPath, 11, "")
    tlbl:SetTextColor(1, 1, 1, 0.8)
    tlbl:SetPoint("TOP", frame, "TOP", 0, -6)
    tlbl:SetText(titleText)

    -- Divider
    local div = frame:CreateTexture(nil, "OVERLAY")
    div:SetColorTexture(1, 1, 1, 0.08)
    div:SetHeight(1)
    div:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -26)
    div:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -26)

    -- Tab header cleanup
    if frame.FriendsTabHeader then
        for _, r in ipairs({frame.FriendsTabHeader:GetRegions()}) do
            if r and r:IsObjectType("Texture") then r:SetTexture(nil); r:SetAtlas(nil) end
        end
    end

    -- Tabs
    local customTabs = {}
    for i = 1, frame.numTabs or 4 do
        local tab = _G["FriendsFrameTab" .. i]
        if tab then
            for _, r in ipairs({tab:GetRegions()}) do
                if r and r:IsObjectType("Texture") then r:SetTexture(nil); r:SetAtlas(nil) end
            end
            if tab.Left then tab.Left:SetTexture(nil) end
            if tab.Middle then tab.Middle:SetTexture(nil) end
            if tab.Right then tab.Right:SetTexture(nil) end
            local hl = tab:GetHighlightTexture()
            if hl then hl:SetTexture(nil) end

            if not GetFFD(tab).bg then
                GetFFD(tab).bg = tab:CreateTexture(nil, "BACKGROUND")
                GetFFD(tab).bg:SetAllPoints()
                GetFFD(tab).bg:SetColorTexture(0.025, 0.035, 0.045, 0.8)
            end

            local blizLabel = tab:GetFontString()
            local labelText = blizLabel and blizLabel:GetText() or ("Tab " .. i)
            if blizLabel then blizLabel:SetTextColor(0, 0, 0, 0) end
            tab:SetPushedTextOffset(0, 0)

            if not GetFFD(tab).fs then
                GetFFD(tab).fs = tab:CreateFontString(nil, "OVERLAY")
                GetFFD(tab).fs:SetFont(fontPath, 9, "")
                GetFFD(tab).fs:SetPoint("CENTER", tab, "CENTER")
                GetFFD(tab).fs:SetText(labelText)
            end

            if not GetFFD(tab).ul then
                GetFFD(tab).ul = tab:CreateTexture(nil, "OVERLAY")
                GetFFD(tab).ul:SetHeight(2)
                GetFFD(tab).ul:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 3, 1)
                GetFFD(tab).ul:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, 1)
                GetFFD(tab).ul:SetColorTexture(RexUI:GetColor("accent"))
                GetFFD(tab).ul:Hide()
            end
            customTabs[i] = tab
        end
    end

    local function UpdateTabs()
        local sel = PanelTemplates_GetSelectedTab(frame) or 1
        for i, t in ipairs(customTabs) do
            local act = (i == sel)
            if GetFFD(t).fs then GetFFD(t).fs:SetTextColor(1, 1, 1, act and 1 or 0.5) end
            if GetFFD(t).ul then GetFFD(t).ul:SetShown(act) end
        end
    end
    hooksecurefunc(frame, "Show", UpdateTabs)
    hooksecurefunc("PanelTemplates_SelectTab", function(f, idx)
        if f == frame then UpdateTabs() end
    end)

    -- Tab frame onshow hooks
    for idx, sf in ipairs({FriendsListFrame, WhoFrame, RaidFrame, QuickJoinFrame}) do
        if sf then
            sf:HookScript("OnShow", function()
                UpdateTabs()
                if idx == 1 then RefreshCache(); ProcessFriendButtons() end
            end)
        end
    end

    -- Scrollbar
    local bar = FriendsListFrame and FriendsListFrame.ScrollBar
    if bar then
        StripTextures(bar)
        if bar.Background then bar.Background:Hide() end
        if bar.Back then bar.Back:SetAlpha(0); bar.Back:SetSize(1, 0.001) end
        if bar.Forward then bar.Forward:SetAlpha(0); bar.Forward:SetSize(1, 0.001) end
        local track = bar.Track
        if track then
            track:DisableDrawLayer("ARTWORK")
            track:DisableDrawLayer("BACKGROUND")
            track:ClearAllPoints()
            track:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
            track:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
        end
        local thumb = bar.GetThumb and bar:GetThumb()
        if thumb then
            thumb:DisableDrawLayer("ARTWORK")
            thumb:DisableDrawLayer("BACKGROUND")
            local tex = thumb:CreateTexture(nil, "OVERLAY")
            tex:SetColorTexture(1, 1, 1, 0.4)
            tex:SetWidth(3)
            tex:SetPoint("TOP", thumb, "TOP", 0, 0)
            tex:SetPoint("BOTTOM", thumb, "BOTTOM", 0, 0)
            tex:SetPoint("RIGHT", thumb, "RIGHT", 0, 0)
        end
        bar:SetWidth(5)
        bar:SetAlpha(0.6)
        bar:HookScript("OnEnter", function() bar:SetAlpha(0.95) end)
        bar:HookScript("OnLeave", function() bar:SetAlpha(0.6) end)
    end

    -- Bottom buttons
    local addBtn, msgBtn = _G.FriendsFrameAddFriendButton, _G.FriendsFrameSendMessageButton
    for _, btn in ipairs({addBtn, msgBtn}) do
        if btn then
            StripTextures(btn)
            local text = btn:GetFontString()
            if text then
                text:SetFont(fontPath, 9, "")
                text:SetTextColor(1, 1, 1, 0.5)
            end
            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(); bg:SetColorTexture(0.025, 0.035, 0.045, 0.92)
            local bdr = Skin:CreateBorder(btn)
            bdr:SetAllPoints(); bdr:SetFrameLevel(btn:GetFrameLevel() + 1)
            Skin:SetBorderColor(bdr, RexUI:GetColor("border"))
        end
    end

    -- Event frame
    local evtFrame = CreateFrame("Frame")
    Skin:RegisterEvents(evtFrame, { "FRIENDLIST_UPDATE", "BN_FRIEND_LIST_SIZE_CHANGED", "BN_FRIEND_INFO_CHANGED" })
    evtFrame:SetScript("OnEvent", function()
        RefreshCache()
        local sb = FriendsListFrame and FriendsListFrame.ScrollBox
        if sb then
            for _, btn in sb:EnumerateFrames() do GetFFD(btn).stampType = nil end
        end
        ProcessFriendButtons()
    end)

    -- Friend button update hook
    pcall(hooksecurefunc, "FriendsFrame_UpdateFriendButton", function(button)
        if button and button.buttonType and button.buttonType ~= FRIENDS_BUTTON_TYPE_DIVIDER then
            GetFFD(button).stampType = nil
        end
    end)

    -- Close button
    StyleCloseButton(frame.CloseButton or _G.FriendsFrameCloseButton)

    UpdateTabs()
end

function Skin:HookFriendsFrame()
    if self.FriendsHooked then return end
    self.FriendsHooked = true

    local frame = _G.FriendsFrame
    if frame then
        SkinFriendsFrame()
        frame:HookScript("OnShow", SkinFriendsFrame)
    else
        local e = CreateFrame("Frame")
        e:RegisterEvent("ADDON_LOADED")
        e:SetScript("OnEvent", function(self, ev, addon)
            if addon == "Blizzard_FriendsFrame"
            or addon == "Blizzard_SocialUI" then
                self:UnregisterAllEvents()
                C_Timer.After(0.1, function()
                    if _G.FriendsFrame then
                        SkinFriendsFrame()
                        _G.FriendsFrame:HookScript("OnShow", SkinFriendsFrame)
                    end
                end)
            end
        end)
    end
end
