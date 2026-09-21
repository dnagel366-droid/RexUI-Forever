-- ============================================================
-- RexUI_ActionBars\States.lua
-- Paging fuer Bar1 (Seiten 1-8 per Keybind/Modifier)
-- ============================================================

local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI

local AB = RexUI.ActionBars
if not AB then return end

-- ============================================================
-- AKTUELLER PAGE STATE
-- ============================================================

AB.CurrentPage = 1

local NUM_NORMAL_PAGES = NUM_ACTIONBAR_PAGES or 6
local BUTTONS_PER_PAGE = NUM_ACTIONBAR_BUTTONS or 12
local DEFAULT_ACTION_KEYS = {
    "1", "2", "3", "4", "5", "6",
    "7", "8", "9", "0", "-", "=",
}

local function CallActionBar(method, globalName)
    local fn = C_ActionBar and C_ActionBar[method]
    if type(fn) == "function" then
        local ok, value = pcall(fn)
        if ok then
            return value
        end
    end

    if globalName then
        fn = _G[globalName]
        if type(fn) == "function" then
            local ok, value = pcall(fn)
            if ok then
                return value
            end
        end
    end

    return nil
end

local function GetBonusOffset()
    return CallActionBar("GetBonusBarOffset", "GetBonusBarOffset") or 0
end

local function GetVehiclePage()
    local page = CallActionBar("GetVehicleBarIndex", "GetVehicleBarIndex")
    if page and page > 0 then
        return page
    end
    return 12
end

local function GetOverridePage()
    local page = CallActionBar("GetOverrideBarIndex", "GetOverrideBarIndex")
    if page and page > 0 then
        return page
    end
    return 14
end

local function GetTempShapeshiftPage()
    local page = CallActionBar("GetTempShapeshiftBarIndex", "GetTempShapeshiftBarIndex")
    if page and page > 0 then
        return page
    end
    return nil
end

local function UseForeverPageDriver()
    local toc = select(4, GetBuildInfo()) or 0
    return toc >= 16000 and toc < 20000
end

-- Combat AttributeDriver needs a page for every bonusbar:N up front.
-- Seed with the client page count; overwrite from C_ActionBar.GetBonusBarIndex
-- when the client actually reports that offset. No class/form names.
local bonusPageByOffset = {}
for n = 1, 5 do
    bonusPageByOffset[n] = NUM_NORMAL_PAGES + n
end

local function RememberCurrentBonusPage()
    local hasBonus = CallActionBar("HasBonusActionBar", "HasBonusActionBar")
    local offset = GetBonusOffset()
    local page = CallActionBar("GetBonusBarIndex", "GetBonusBarIndex")
    if not hasBonus and not (offset and offset > 0) then
        return false
    end
    if not offset or offset <= 0 or not page or page <= 0 then
        return false
    end
    if bonusPageByOffset[offset] == page then
        return false
    end
    bonusPageByOffset[offset] = page
    return true
end

local SyncForeverBar1FromAttributes

local function ForEachBar1PageMapping(add)
    local overridePage = GetOverridePage()
    local vehiclePage = GetVehiclePage()
    add("[overridebar]", overridePage)
    add("[vehicleui][possessbar]", vehiclePage)

    -- Retail fallback only. Forever uses ForEachForeverBar1PageMapping.
    for n = 1, 5 do
        add(("[bonusbar:%d]"):format(n), NUM_NORMAL_PAGES + n)
    end

    for i = 2, NUM_NORMAL_PAGES do
        add(("[bar:%d]"):format(i), i)
    end

    add(nil, 1)
end

-- Ellesmere order: override/vehicle, then [bar:2-6], then form bonus bars.
-- Do not AND [bar:1] onto bonusbar (leave/re-enter would stick on page 1).
-- Do not put [shapeshift] first: Forever reports it for bear/cat and would
-- steal the match before [bonusbar:3] (bear = page 9).
local function ForEachForeverBar1PageMapping(add)
    add("[overridebar]", GetOverridePage())
    add("[vehicleui][possessbar]", GetVehiclePage())

    for i = 2, NUM_NORMAL_PAGES do
        add(("[bar:%d]"):format(i), i)
    end

    RememberCurrentBonusPage()
    for n = 1, 5 do
        add(("[bonusbar:%d]"):format(n), bonusPageByOffset[n] or (NUM_NORMAL_PAGES + n))
    end

    add(nil, 1)
end

local function BuildDriverFromPages(mapPage, foreach)
    local conditions = {}
    foreach = foreach or ForEachBar1PageMapping
    foreach(function(cond, page)
        local value = mapPage(page)
        if cond then
            conditions[#conditions + 1] = ("%s %d"):format(cond, value)
        else
            conditions[#conditions + 1] = tostring(value)
        end
    end)
    return table.concat(conditions, "; ")
end

local function BuildBar1PageConditions()
    return BuildDriverFromPages(function(page)
        return page
    end)
end

local function BuildBar1ActionConditions(buttonIndex)
    return BuildDriverFromPages(function(page)
        return ((page - 1) * BUTTONS_PER_PAGE) + buttonIndex
    end)
end

local function BuildForeverBar1PageConditions()
    return BuildDriverFromPages(function(page)
        return page
    end, ForEachForeverBar1PageMapping)
end

local function BuildForeverBar1ActionConditions(buttonIndex)
    return BuildDriverFromPages(function(page)
        return ((page - 1) * BUTTONS_PER_PAGE) + buttonIndex
    end, ForEachForeverBar1PageMapping)
end

local function IsActive(name)
    local value = CallActionBar(name, name)
    return value and true or false
end

-- Same order as ActionBarController_UpdateAll.
function AB:GetEffectivePage()
    if IsActive("HasVehicleActionBar") then
        local page = CallActionBar("GetVehicleBarIndex", "GetVehicleBarIndex")
        if page and page > 0 then
            return page, 0
        end
    end

    if IsActive("HasOverrideActionBar") then
        local page = CallActionBar("GetOverrideBarIndex", "GetOverrideBarIndex")
        if page and page > 0 then
            return page, 0
        end
    end

    -- Ellesmere does not page MainBar on [shapeshift]. Forever reports a temp
    -- shapeshift bar for bear/cat, which would freeze Bar1 on the wrong page.
    if not UseForeverPageDriver() and IsActive("HasTempShapeshiftActionBar") then
        local page = CallActionBar("GetTempShapeshiftBarIndex", "GetTempShapeshiftBarIndex")
        if page and page > 0 then
            return page, 0
        end
    end

    local actionPage = CallActionBar("GetActionBarPage", "GetActionBarPage") or 1
    local hasBonus = IsActive("HasBonusActionBar")
    if not hasBonus then
        local offset = GetBonusOffset()
        hasBonus = offset and offset > 0
    end
    if hasBonus and actionPage == 1 then
        local bonusPage = CallActionBar("GetBonusBarIndex", "GetBonusBarIndex")
        if bonusPage and bonusPage > 0 then
            return bonusPage, GetBonusOffset()
        end
    end

    return actionPage, 0
end

local function ApplyPage(page)
    local bar = AB.Bars["Bar1"]
    if not bar then return end

    if not InCombatLockdown() then
        bar:SetAttribute("actionpage", page)
        bar:SetAttribute("state", page)
    end

    local offset = (page - 1) * BUTTONS_PER_PAGE

    for i, btn in ipairs(bar.buttons) do
        local slot = offset + i

        btn.slot = slot
        btn.action = slot

        if not InCombatLockdown() then
            btn:SetID(0)
            btn:SetAttribute("type", "action")
            btn:SetAttribute("action", slot)
            btn:SetAttribute("state", page)
            if btn.SetState then
                btn:SetState(page, "action", slot)
            end
        end

    end

    -- Forever cannot compile _childupdate-rex-page (tonumber in RestrictedExecution).
    -- AttributeDriver already owns the action slot.
    if not UseForeverPageDriver() and not InCombatLockdown() and bar.ChildUpdate then
        bar:ChildUpdate("rex-page", page)
    end

    if UseForeverPageDriver() then
        SyncForeverBar1FromAttributes()
    end

    if AB.MarkDirty and not InCombatLockdown() then
        if AB.MarkBarDirty then
            AB:MarkBarDirty("Bar1")
        else
            AB:MarkDirty()
        end
        if AB.ScheduleDirtyFlush then
            AB:ScheduleDirtyFlush()
        end
    end

    if AB.RefreshAssistedCombatOverlays and not InCombatLockdown() then
        AB:RefreshAssistedCombatOverlays(true)
    end

    if AB.PageDisplay and not InCombatLockdown() then
        AB.PageDisplay:SetText(page)
    end

    if not InCombatLockdown() then
        if AB.QueueBar1BindingUpdate then
            AB:QueueBar1BindingUpdate()
        elseif AB.UpdateBar1Bindings then
            AB:UpdateBar1Bindings()
        end
    end
end

-- ============================================================
-- BAR1 KEYBINDS
-- ============================================================

function AB:UpdateBar1Bindings()
    if AB.ApplyKeybindRouting then
        return AB:ApplyKeybindRouting()
    end
    local bar = AB.Bars["Bar1"]
    if not bar or InCombatLockdown() then
        return
    end

    local owner = AB.BindingOwner or bar
    ClearOverrideBindings(owner)

    local seenKeys = {}
    local effectivePage = self:GetEffectivePage()
    local useDragonFallbackKeys =
        self:IsOverrideActive()
        or (effectivePage and effectivePage > NUM_NORMAL_PAGES)

    local function bindKeysToButton(bindingName, buttonName)
        local bound = false
        local keys = { GetBindingKey(bindingName) }

        for _, key in ipairs(keys) do

            if key and not seenKeys[key] then
                seenKeys[key] = true
                bound = true
                SetOverrideBindingClick(
                    owner,
                    false,
                    key,
                    buttonName,
                    "LeftButton"
                )
            end
        end

        return bound
    end

    local function bindFallbackKey(index, buttonName)
        if not useDragonFallbackKeys then return end

        local key = DEFAULT_ACTION_KEYS[index]
        if not key or seenKeys[key] then return end

        seenKeys[key] = true
        SetOverrideBindingClick(
            owner,
            false,
            key,
            buttonName,
            "LeftButton"
        )
    end

    for i, btn in ipairs(bar.buttons or {}) do
        local buttonName = btn and btn:GetName()

        if buttonName then
            local bound = false
            bound = bindKeysToButton("ACTIONBUTTON" .. i, buttonName) or bound
            bound = bindKeysToButton("OVERRIDEACTIONBUTTON" .. i, buttonName) or bound
            bound = bindKeysToButton("VEHICLEACTIONBUTTON" .. i, buttonName) or bound
            bound = bindKeysToButton("POSSESSBUTTON" .. i, buttonName) or bound

            if not bound then
                bindFallbackKey(i, buttonName)
            end
        end
    end
end

function AB:QueueBar1BindingUpdate()
    if InCombatLockdown() then
        return
    end

    self.bar1BindingUpdateToken = (self.bar1BindingUpdateToken or 0) + 1
    local token = self.bar1BindingUpdateToken

    if self.pendingBar1BindingUpdate then
        return
    end

    self.pendingBar1BindingUpdate = true

    C_Timer.After(0, function()
        AB.pendingBar1BindingUpdate = false

        if InCombatLockdown() then
            return
        end

        if token ~= AB.bar1BindingUpdateToken then
            AB:QueueBar1BindingUpdate()
            return
        end

        if AB.UpdateBar1Bindings then
            AB:UpdateBar1Bindings()
        end

        C_Timer.After(0.15, function()
            if token ~= AB.bar1BindingUpdateToken then
                return
            end

            if not InCombatLockdown() and AB.UpdateBar1Bindings then
                AB:UpdateBar1Bindings()
            end
        end)
    end)
end

-- ============================================================
-- SET PAGE
-- Wechselt Bar1 auf eine andere Actionbar-Seite (1-8).
-- Aendert die Slot-Nummern der Bar1-Buttons live.
-- ============================================================

function AB:SetPage(page)

    page = math.max(1, page)

    if AB.CurrentPage == page then return end

    AB.CurrentPage = page

    ApplyPage(page)
end

-- ============================================================
-- GET PAGE
-- ============================================================

function AB:GetPage()
    return AB.CurrentPage
end

-- ============================================================
-- PAGE DISPLAY (kleiner Text ueber Bar1)
-- Wird in Initialize() erstellt wenn Bar1 existiert
-- ============================================================

function AB:CreatePageDisplay()
    -- Seitenzahl bewusst nicht anzeigen. Das Actionbar-Paging bleibt unverändert aktiv.
    AB.PageDisplay = nil
end

-- ============================================================
-- KEYBIND SUPPORT
-- Registriert ACTIONBAR_PAGE_CHANGED Event und
-- liest Blizzard-seitigen Page-Wechsel (z.B. per
-- GetActionBarPage()) aus.
-- ============================================================

function AB:InitStates()

    AB:CreatePageDisplay()

    RememberCurrentBonusPage()
    local page = AB:GetEffectivePage()
    AB.CurrentPage = page

    if AB.PageDisplay then
        AB.PageDisplay:SetText(page)
    end

    if AB.InitSecurePageDriver then
        AB:InitSecurePageDriver()
    end

    ApplyPage(page)
end


function AB:ResolveForeverBar1Slot(btn)
    if not btn then return nil end
    local index = btn.rexIndex or (btn.GetAttribute and tonumber(btn:GetAttribute("rexIndex")))
    local attrSlot = btn.GetAttribute and tonumber(btn:GetAttribute("action"))
    if not index then
        return attrSlot or btn.slot
    end
    local page = self.GetEffectivePage and self:GetEffectivePage() or self.CurrentPage or 1
    local computed = ((page - 1) * BUTTONS_PER_PAGE) + index
    -- In combat the AttributeDriver can lag one frame behind C_ActionBar.
    -- Paint from the bonus page the client reports so bear/cat icons swap now.
    if InCombatLockdown and InCombatLockdown() then
        return computed
    end
    return attrSlot or computed
end

function SyncForeverBar1FromAttributes()
    local bar = AB.Bars and AB.Bars["Bar1"]
    if not bar then return end

    local page = (AB.GetEffectivePage and AB:GetEffectivePage())
        or (bar.GetAttribute and tonumber(bar:GetAttribute("actionpage")))
    if page then
        AB.CurrentPage = page
    end

    for _, btn in ipairs(bar.buttons or {}) do
        local slot = AB:ResolveForeverBar1Slot(btn)
        if slot then
            btn.slot = slot
            btn.action = slot
            btn._state_action = slot
            -- Never call LAB UpdateAction here: it re-reads labaction-<state>
            -- and undoes the AttributeDriver while state is still the old page.
            if AB.UpdateButtonCombatVisuals then
                AB:UpdateButtonCombatVisuals(btn)
            end
        end
    end
end

local function WatchForeverActionAttribute(btn)
    if btn._rexForeverActionWatch then return end
    btn._rexForeverActionWatch = true
    btn:HookScript("OnAttributeChanged", function(self, name)
        if name ~= "action" and name ~= "state" and name ~= "actionpage" then
            return
        end
        local slot = AB:ResolveForeverBar1Slot(self)
        if not slot or self._rexForeverLastSlot == slot then
            return
        end
        self._rexForeverLastSlot = slot
        self.slot = slot
        self.action = slot
        self._state_action = slot
        if AB.UpdateButtonCombatVisuals then
            AB:UpdateButtonCombatVisuals(self)
        end
    end)
end

local function ApplyForeverAttributePageDriver(bar)
    if not RegisterAttributeDriver then return end

    local pageDriver = BuildForeverBar1PageConditions()
    RegisterAttributeDriver(bar, "actionpage", pageDriver)
    RegisterAttributeDriver(bar, "state", pageDriver)

    for i, btn in ipairs(bar.buttons or {}) do
        -- Drive LAB state so GetAction() matches the bonus page, and action
        -- so SecureActionButton clicks the bear/cat slot in combat.
        RegisterAttributeDriver(btn, "state", pageDriver)
        RegisterAttributeDriver(btn, "action", BuildForeverBar1ActionConditions(i))
        WatchForeverActionAttribute(btn)
    end

    SyncForeverBar1FromAttributes()
end

AB.UseForeverPageDriver = UseForeverPageDriver
AB.SyncForeverBar1FromAttributes = SyncForeverBar1FromAttributes

function AB:InitSecurePageDriver()
    local bar = AB.Bars["Bar1"]
    if not bar then return end

    -- Forever RestrictedExecution cannot compile any addon _onstate body.
    -- Drive actionpage/action with Blizzard's AttributeDriver instead.
    if UseForeverPageDriver() then
        ApplyForeverAttributePageDriver(bar)
        return
    end

    if not RegisterStateDriver then return end

    if not bar._rexPageDriverScripted then
        bar:SetAttribute("_onstate-page", [[
            newstate = tonumber(newstate) or 1
            self:SetAttribute("state", newstate)
            self:SetAttribute("actionpage", newstate)
            self:ChildUpdate("rex-page", newstate)
        ]])
        bar._rexPageDriverScripted = true
    end

    RegisterStateDriver(bar, "page", BuildBar1PageConditions())
end

function AB:RefreshPageDriver()
    local bar = AB.Bars["Bar1"]
    if not bar then return end

    if UseForeverPageDriver() then
        ApplyForeverAttributePageDriver(bar)
        return
    end

    if not RegisterStateDriver then return end
    RegisterStateDriver(bar, "page", BuildBar1PageConditions())
end
-- ============================================================
-- EVENT: ACTIONBAR_PAGE_CHANGED
-- Wird von Core.lua weitergeleitet
-- ============================================================

function AB:OnPageChanged()
    -- Leaving a form must re-read C_ActionBar. Do not keep a previous page.
    local cacheChanged = RememberCurrentBonusPage()
    local page = AB:GetEffectivePage()
    AB.CurrentPage = page

    if cacheChanged and UseForeverPageDriver() and not InCombatLockdown() then
        local bar = AB.Bars and AB.Bars["Bar1"]
        if bar then
            ApplyForeverAttributePageDriver(bar)
        end
    end

    ApplyPage(page)
end
