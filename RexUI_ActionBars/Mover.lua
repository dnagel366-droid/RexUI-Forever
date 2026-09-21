-- ============================================================
-- RexUI_ActionBars\Mover.lua
-- Wird von RexUI:Unlock() / RexUI:Lock() gesteuert
-- via AB:ShowMovers() / AB:HideMovers()
-- ============================================================

local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI

local AB = RexUI and RexUI.ActionBars
if not AB then return end

local function T(text)
    return RexUI:LocalizeText(text)
end

-- ============================================================
-- ANZEIGENAMEN
-- ============================================================

local moverNames = {
    Bar1        = "Leiste 1",
    Bar2        = "Leiste 2",
    Bar3        = "Leiste 3",
    Bar4        = "Leiste 4",
    Bar5        = "Leiste 5",
    Bar6        = "Leiste 6",
    Bar7        = "Leiste 7",
    Bar8        = "Leiste 8",
    Bar9        = "Leiste 9",
    Bar10       = "Leiste 10",
    StanceBar   = "Haltungsleiste",
    PetBar      = "Begleiterleiste",
}

-- ============================================================
-- MOVER FRAME ERSTELLEN
-- ============================================================

-- ============================================================
-- ACTIONBAR DOCKING / GROUP MOVEMENT
-- Bars snap together while unlocked. Dock links are stored in the profile.
-- Dragging any linked bar moves the whole connected group. Holding SHIFT
-- while starting a drag detaches only that bar so it can be positioned alone.
-- ============================================================

local SNAP_DISTANCE = 14

local function GetActionbarDB()
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    if not profile then return nil end
    return AB.GetCurrentActionBarDB and AB:GetCurrentActionBarDB(profile)
end

local function EnsureBarDB(barKey)
    local db = GetActionbarDB()
    if not db then return nil end
    db[barKey] = db[barKey] or {}
    return db[barKey], db
end

local function DetachBar(barKey)
    local entry, db = EnsureBarDB(barKey)
    if not entry or not db then return end
    entry.dockTo = nil
    -- Remove incoming links too: the selected bar becomes fully independent.
    for key, data in pairs(db) do
        if type(data) == "table" and data.dockTo == barKey then
            data.dockTo = nil
        end
    end
end

local function GetLinkedKeys(startKey)
    local _, db = EnsureBarDB(startKey)
    local result, seen, queue = {}, {}, { startKey }
    while #queue > 0 do
        local key = table.remove(queue, 1)
        if not seen[key] then
            seen[key] = true
            result[#result + 1] = key
            local data = db and db[key]
            if data and data.dockTo and not seen[data.dockTo] then
                queue[#queue + 1] = data.dockTo
            end
            if db then
                for other, od in pairs(db) do
                    if type(od) == "table" and od.dockTo == key and not seen[other] then
                        queue[#queue + 1] = other
                    end
                end
            end
        end
    end
    return result
end

local function SaveAbsolutePosition(barKey, bar)
    local entry = EnsureBarDB(barKey)
    if not entry or not bar then return end
    local point, _, relPoint, x, y = bar:GetPoint(1)
    x = math.floor((x or 0) + 0.5)
    y = math.floor((y or 0) + 0.5)
    entry.point, entry.relPoint, entry.x, entry.y = point, relPoint, x, y
    AB.Config = AB.Config or {}
    AB.Config[barKey] = AB.Config[barKey] or {}
    AB.Config[barKey].point, AB.Config[barKey].relPoint = point, relPoint
    AB.Config[barKey].x, AB.Config[barKey].y = x, y
end

local function Rect(bar)
    if not bar then return end
    local l, r, t, b = bar:GetLeft(), bar:GetRight(), bar:GetTop(), bar:GetBottom()
    if not (l and r and t and b) then return end
    return l, r, t, b
end

local function Overlap(a1, a2, b1, b2)
    return math.min(a2, b2) - math.max(a1, b1)
end

local function TrySnapBar(barKey, bar)
    local l, r, t, b = Rect(bar)
    if not l then return false end
    local best
    for otherKey, other in pairs(AB.Bars or {}) do
        if otherKey ~= barKey and other and other:IsShown() then
            local ol, orr, ot, ob = Rect(other)
            if ol then
                local verticalOverlap = Overlap(b, t, ob, ot)
                local horizontalOverlap = Overlap(l, r, ol, orr)
                local candidates = {}
                if verticalOverlap > 4 then
                    candidates[#candidates+1] = { d=math.abs(l-orr), x=orr, y=b, side="LEFT" }
                    candidates[#candidates+1] = { d=math.abs(r-ol), x=ol-(r-l), y=b, side="RIGHT" }
                end
                if horizontalOverlap > 4 then
                    candidates[#candidates+1] = { d=math.abs(b-ot), x=l, y=ot, side="BOTTOM" }
                    candidates[#candidates+1] = { d=math.abs(t-ob), x=l, y=ob-(t-b), side="TOP" }
                end
                for _, c in ipairs(candidates) do
                    if c.d <= SNAP_DISTANCE and (not best or c.d < best.d) then
                        best = { d=c.d, otherKey=otherKey, x=c.x, y=c.y, side=c.side }
                    end
                end
            end
        end
    end
    if not best then return false end

    -- Convert desired bottom-left screen coordinates to UIParent center anchor.
    local scale = UIParent:GetEffectiveScale() or 1
    local uiLeft, uiBottom = UIParent:GetLeft() or 0, UIParent:GetBottom() or 0
    local cx = (best.x - uiLeft) + (bar:GetWidth() or 0)/2
    local cy = (best.y - uiBottom) + (bar:GetHeight() or 0)/2
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
    local entry = EnsureBarDB(barKey)
    if entry then entry.dockTo = best.otherKey end
    SaveAbsolutePosition(barKey, bar)
    return true
end

local function BeginGroupDrag(barKey)
    local detach = IsShiftKeyDown and IsShiftKeyDown()
    if detach then DetachBar(barKey) end
    local keys = detach and { barKey } or GetLinkedKeys(barKey)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    x, y = x / scale, y / scale
    local starts = {}
    for _, key in ipairs(keys) do
        local b = AB.Bars and AB.Bars[key]
        if b then
            local cx, cy = b:GetCenter()
            if cx and cy then starts[key] = { x=cx, y=cy } end
        end
    end
    return { keys=keys, starts=starts, x=x, y=y, detach=detach }
end

local function UpdateGroupDrag(state)
    if not state then return end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    x, y = x / scale, y / scale
    local dx, dy = x-state.x, y-state.y
    for _, key in ipairs(state.keys) do
        local b = AB.Bars and AB.Bars[key]
        local st = state.starts[key]
        if b and st then
            b:ClearAllPoints()
            b:SetPoint("CENTER", UIParent, "BOTTOMLEFT", st.x+dx, st.y+dy)
            if b._mover then
                b._mover:ClearAllPoints()
                b._mover:SetPoint("TOPLEFT", b, "TOPLEFT")
                b._mover:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT")
            end
        end
    end
end

local function EndGroupDrag(barKey, state)
    if not state then return end
    for _, key in ipairs(state.keys) do
        local b = AB.Bars and AB.Bars[key]
        if b then SaveAbsolutePosition(key, b) end
    end
    -- SHIFT means explicit detach, so do not immediately snap it back.
    if not state.detach then TrySnapBar(barKey, AB.Bars and AB.Bars[barKey]) end
end

local function createMover(bar, barKey)

    if bar._mover then return bar._mover end

    local m = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    m:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    m:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    m:SetFrameStrata("DIALOG")
    m:SetFrameLevel(500)

    m:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    m:SetBackdropColor(0.2, 0.6, 1, 0.2)
    m:SetBackdropBorderColor(0.2, 0.6, 1, 0.9)

    -- Label
    local displayName = moverNames[barKey] or barKey
    m.label = m:CreateFontString(nil, "OVERLAY")
    m.label:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    m.label:SetPoint("CENTER")
    m.label:SetText(T(displayName))
    m.label:SetTextColor(1, 1, 1, 1)

    -- Drag
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    m:EnableMouse(true)
    m:RegisterForDrag("LeftButton")

    m:SetScript("OnDragStart", function(self)
        self.dragged = true
        self._groupDrag = BeginGroupDrag(barKey)
        self:SetScript("OnUpdate", function()
            UpdateGroupDrag(self._groupDrag)
        end)
    end)

    m:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        EndGroupDrag(barKey, self._groupDrag)
        self._groupDrag = nil
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        self:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    end)

m:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(T(displayName))
    GameTooltip:AddLine("Leisten rasten aneinander ein und bewegen sich danach gemeinsam.", 1, 1, 1, true)
    GameTooltip:AddLine("SHIFT + Ziehen: Diese Leiste aus der Gruppe lösen.", 0.8, 0.82, 0.9, true)
    GameTooltip:Show()
end)
m:SetScript("OnLeave", function() GameTooltip:Hide() end)

m:SetScript("OnMouseUp", function()

    if m.dragged then
        m.dragged = false
        return
    end

    if RexUI.ConfigUI
    and RexUI.ConfigUI.OpenActionBarSettings then
        RexUI.ConfigUI:OpenActionBarSettings(barKey)
    end
end)

m:Hide()
bar._mover = m
return m
end

function AB:SyncMoverToBar(barKey)
    local bar = self.Bars and self.Bars[barKey]
    local mover = bar and bar._mover
    if not mover then return end

    mover:ClearAllPoints()
    mover:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    mover:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
end

local function ApplyMoverPreviewSize(barKey, bar)
    if not bar or (bar:GetWidth() or 0) >= 10 and (bar:GetHeight() or 0) >= 10 then return end

    local cfg = AB.GetConfig and AB:GetConfig(barKey) or {}
    local slots = (bar.buttons and #bar.buttons > 0 and #bar.buttons) or cfg.slots or 1
    local size, spacing = AB:GetButtonMetrics(cfg, 30, 3)
    local rows
    if barKey == "PetBar" then
        rows = cfg.vertical and slots or 1
    else
        rows = cfg.vertical and slots or math.max(1, math.min(cfg.rows or 1, slots))
    end
    local cols = math.ceil(slots / rows)
    bar:SetSize(
        (cols * size) + ((cols - 1) * spacing),
        (rows * size) + ((rows - 1) * spacing)
    )
end

local function GetVisibilityDriver(barKey, enabled)
    if enabled == false then
        return "hide"
    end

    if barKey == "PetBar" then
        return "[petbattle] hide; [novehicleui,pet,nooverridebar,nopossessbar] show; hide"
    elseif barKey == "Bar1" then
        return "show"
    end

    return "[overridebar][vehicleui][possessbar] hide; show"
end

-- ============================================================
-- SHOW MOVERS  (aufgerufen von RexUI:Unlock)
-- ============================================================

function AB:ShowMovers()

    if InCombatLockdown() then
        AB:RunOutOfCombat("ShowMovers", function()
            AB:ShowMovers()
        end)
        return
    end

    if AB.ApplyLoadedSettings then
        AB:ApplyLoadedSettings()
    end

    for barKey, bar in pairs(AB.Bars) do
        if RegisterStateDriver then
            UnregisterStateDriver(bar, "visibility")
            bar._rexMoverSuspendedVisibility = true
        end

        ApplyMoverPreviewSize(barKey, bar)
        local m = createMover(bar, barKey)
        AB:SyncMoverToBar(barKey)
        m:SetAlpha(1)
        m:EnableMouse(true)
        m:Show()

        -- Sichtbarkeit erzwingen (StanceBar/PetBar ohne Forms/Pet)
        if not bar:IsShown() then
            bar:Show()
        end

        -- Buttons im Unlock-Modus deaktivieren (kein Taint)
        for _, btn in ipairs(bar.buttons or {}) do
            btn:EnableMouse(false)
        end
    end

    if AB.ZoneAbility and AB.ZoneAbility.ShowMover then
        AB.ZoneAbility:ShowMover()
    end
end

-- ============================================================
-- HIDE MOVERS  (aufgerufen von RexUI:Lock)
-- ============================================================

function AB:HideMovers()

    if InCombatLockdown() then
        AB:RunOutOfCombat("HideMovers", function()
            AB:HideMovers()
        end)
        return
    end

    for barKey, bar in pairs(AB.Bars) do
        if bar._mover then
            bar._mover:SetAlpha(0)
            bar._mover:EnableMouse(false)
            bar._mover:Hide()
        end

        if RegisterStateDriver and bar._rexMoverSuspendedVisibility then
            local cfg = AB.GetConfig and AB:GetConfig(barKey)
            RegisterStateDriver(bar, "visibility", GetVisibilityDriver(barKey, not cfg or cfg.enabled ~= false))
            bar._rexMoverSuspendedVisibility = nil
        end

        local cfg = AB.GetConfig and AB:GetConfig(barKey)
        for _, btn in ipairs(bar.buttons or {}) do
            btn:EnableMouse(not cfg or cfg.hidden ~= true)
        end
    end

    -- StanceBar/PetBar natuerlichen Zustand wiederherstellen
    if AB.StanceBar and AB.StanceBar.Update then
        AB.StanceBar:Update()
    end
    if AB.PetBar and AB.PetBar.Update then
        AB.PetBar:Update()
    end

    if AB.ZoneAbility and AB.ZoneAbility.HideMover then
        AB.ZoneAbility:HideMover()
    end
end
