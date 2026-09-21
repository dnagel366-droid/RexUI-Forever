-- ============================================================
-- RexUI_BuffReminders – fehlende Flasks/Food/Klassenbuffs (P3 MVP)
-- ============================================================

local ADDON_NAME, ns = ...
local RexUI = ns.RexUI or _G.RexUI
if not RexUI then return end

local BR = RexUI:CreateModule("BuffReminders")
RexUI.BuffReminders = BR

local function T(text)
    return RexUI:LocalizeText(text)
end

-- ------------------------------------------------------------
-- DATEN
-- ------------------------------------------------------------

-- Flask-Auren: Das "Benutzen"-Spell des Items ist identisch mit der Aura, auch
-- bei den "Flüchtigen" Kessel-Varianten. IDs aus den 12.1-Clientdaten.
local FLASK_SPELLS = {
    -- Midnight (12.x)
    1235057, -- Flask of Thalassian Resistance (Vielseitigkeit)
    1235108, -- Flask of the Magisters (Meisterschaft)
    1235110, -- Flask of the Blood Knights (Tempo)
    1235111, -- Flask of the Shattered Sun (Kritischer Treffer)
    -- The War Within (11.x) – weiterhin nutzbar, z. B. in älteren Inhalten
    432021, 431971, 431972, 431973, 431974, 432473,
}

-- "Gut gesättigt"-Auren. Jedes Gericht nutzt eine eigene Spell-ID, deshalb
-- wird zusätzlich über den Aura-Namen geprüft (siehe FOOD_NAME_SPELLS).
local FOOD_SPELLS = {
    -- Midnight (12.x): Well Fed
    1219182, 1219183, 1219184, 1219185,
    1232089, 1232091,
    1232313, 1232316, 1232317, 1232318, 1232320, 1232321, 1232324, 1232325,
    1232490, 1232491, 1232492, 1232493, 1232500, 1232501, 1232585,
    1233400, 1233401, 1233402, 1233404, 1233405, 1233406,
    1283372, 1284619, 1294727, 1305151, 1305154,
    -- Midnight (12.x): Hearty Well Fed (Herzhaftes Essen)
    1232076, 1232078, 1233733,
    -- The War Within (11.x)
    461957, 461958, 461959, 461960,
}

-- Referenz-Spells, deren lokalisierter Name für die Namensprüfung genutzt wird.
-- Damit werden auch neue Gerichte erkannt, deren IDs hier noch nicht stehen.
local FOOD_NAME_SPELLS = {
    { id = 1232324, fallback = "Well Fed" },
    { id = 1232076, fallback = "Hearty Well Fed" },
}

-- Klassenbuffs werden nur gemeldet, wenn der Spieler oder ein Gruppenmitglied
-- die passende Klasse hat.
local RAID_BUFFS = {
    { spell = 1126,   class = "DRUID",   fallback = "Mark of the Wild" },
    { spell = 1459,   class = "MAGE",    fallback = "Arcane Intellect" },
    { spell = 21562,  class = "PRIEST",  fallback = "Power Word: Fortitude" },
    { spell = 6673,   class = "WARRIOR", fallback = "Battle Shout" },
    { spell = 462854, class = "SHAMAN",  fallback = "Skyfury" },
}

-- ------------------------------------------------------------
-- HILFSFUNKTIONEN
-- ------------------------------------------------------------

local function GetSpellName(spellId)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellId)
    end
    if GetSpellInfo then
        return (GetSpellInfo(spellId))
    end
end

-- Midnight (12.x): Im Kampf, in Encountern, M+ und PvP liefern die Aura-APIs
-- geheime Werte oder nil. Dann ist der Buff-Zustand unbekannt (nil) und darf
-- nicht als "fehlt" gewertet werden – sonst blinkt die Anzeige im Kampf auf.
local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

local function IsAuraSecret(spellId)
    if C_Secrets and C_Secrets.ShouldSpellAuraBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldSpellAuraBeSecret, spellId)
        if ok and not IsSecret(secret) then
            return secret == true
        end
        return true
    end
    return UnitAffectingCombat ~= nil and UnitAffectingCombat("player") == true
end

-- true/false = bekannt, nil = zurzeit nicht ermittelbar
local function HasAuraById(spellId)
    if IsAuraSecret(spellId) then return nil end

    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellId)
        if not ok or IsSecret(aura) then return nil end
        return aura ~= nil
    end

    local found = false
    if AuraUtil and AuraUtil.ForEachAura then
        AuraUtil.ForEachAura("player", "HELPFUL", nil, function(aura)
            if aura and not IsSecret(aura) and not IsSecret(aura.spellId) and aura.spellId == spellId then
                found = true
                return true
            end
        end, true)
    end
    return found
end

local function HasAuraByName(name, referenceSpellId)
    if not name or name == "" then return false end
    if referenceSpellId and IsAuraSecret(referenceSpellId) then return nil end

    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
        if not ok or IsSecret(aura) then return nil end
        return aura ~= nil
    end
    if AuraUtil and AuraUtil.FindAuraByName then
        local ok, aura = pcall(AuraUtil.FindAuraByName, name, "player", "HELPFUL")
        if not ok or IsSecret(aura) then return nil end
        return aura ~= nil
    end
    return false
end

-- Kombiniert Teilprüfungen: true sobald eine zutrifft, nil wenn eine
-- unbekannt ist und keine zutrifft, sonst false.
local function Combine(current, result)
    if result == true or current == true then return true end
    if result == nil or current == nil then return nil end
    return false
end

local function HasAnyAuraById(spellIds)
    local state = false
    for _, id in ipairs(spellIds) do
        state = Combine(state, HasAuraById(id))
        if state == true then return true end
    end
    return state
end

local function HasFlask()
    return HasAnyAuraById(FLASK_SPELLS)
end

local function HasFood()
    local state = HasAnyAuraById(FOOD_SPELLS)
    if state == true then return true end
    for _, entry in ipairs(FOOD_NAME_SPELLS) do
        state = Combine(state, HasAuraByName(GetSpellName(entry.id), entry.id))
        if state == true then return true end
        state = Combine(state, HasAuraByName(entry.fallback, entry.id))
        if state == true then return true end
    end
    return state
end

-- ------------------------------------------------------------
-- WAFFENÖL / TEMPORÄRE WAFFENVERZAUBERUNG
-- ------------------------------------------------------------

local INVSLOT_MAINHAND = INVSLOT_MAINHAND or 16
local INVSLOT_OFFHAND = INVSLOT_OFFHAND or 17
local ITEM_CLASS_WEAPON = Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2

local function IsWeaponInSlot(slot)
    local itemId = GetInventoryItemID and GetInventoryItemID("player", slot)
    if not itemId then return false end

    local classId
    if C_Item and C_Item.GetItemInfoInstant then
        classId = select(6, C_Item.GetItemInfoInstant(itemId))
    elseif GetItemInfoInstant then
        classId = select(6, GetItemInfoInstant(itemId))
    end
    -- Ohne Klasseninfo (Item noch nicht geladen) im Zweifel als Waffe behandeln,
    -- damit die Erinnerung nicht fälschlich ausbleibt.
    return classId == nil or classId == ITEM_CLASS_WEAPON
end

-- true = alle getragenen Waffen haben eine temporäre Verzauberung (Öl, Wetzstein,
-- Schamanen-Waffenbuff). Ohne Waffe in der Waffenhand gibt es nichts zu melden.
local function HasWeaponOil()
    if not GetWeaponEnchantInfo then return true end
    if not IsWeaponInSlot(INVSLOT_MAINHAND) then return true end

    local ok, hasMainHand, _, _, _, hasOffHand = pcall(GetWeaponEnchantInfo)
    if not ok or IsSecret(hasMainHand) or IsSecret(hasOffHand) then return nil end
    if not hasMainHand then return false end
    if IsWeaponInSlot(INVSLOT_OFFHAND) and not hasOffHand then return false end
    return true
end

-- ------------------------------------------------------------
-- GRUPPENZUSAMMENSETZUNG
-- ------------------------------------------------------------

function BR:UpdateGroupClasses()
    local classes = self.groupClasses or {}
    for key in pairs(classes) do classes[key] = nil end

    local _, playerClass = UnitClass("player")
    if playerClass then classes[playerClass] = true end

    local prefix, count
    if IsInRaid and IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers and GetNumGroupMembers() or 0
    else
        prefix, count = "party", math.max(0, (GetNumGroupMembers and GetNumGroupMembers() or 1) - 1)
    end

    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) then
            local _, classFile = UnitClass(unit)
            if classFile then classes[classFile] = true end
        end
    end

    self.groupClasses = classes
    return classes
end

function BR:GetMissingRaidBuffs(missing)
    local classes = self.groupClasses or self:UpdateGroupClasses()

    for _, entry in ipairs(RAID_BUFFS) do
        if classes[entry.class] then
            local has = self:Remember("raid" .. entry.spell, HasAuraById(entry.spell))
            if has == false then
                missing[#missing + 1] = GetSpellName(entry.spell) or entry.fallback
            end
        end
    end
end

-- Liefert den aktuellen Zustand oder – falls er gerade nicht ermittelbar ist
-- (geheime Aura-Daten) – den letzten bekannten Zustand von vor dem Kampf.
function BR:Remember(key, state)
    self.lastKnown = self.lastKnown or {}
    if state == nil then
        return self.lastKnown[key]
    end
    self.lastKnown[key] = state
    return state
end

-- ------------------------------------------------------------
-- KONFIGURATION / UI
-- ------------------------------------------------------------

function BR:GetConfig()
    local profile = RexUI.GetProfile and RexUI:GetProfile()
    profile = profile or {}
    profile.buffReminders = type(profile.buffReminders) == "table" and profile.buffReminders or {
        enabled = true,
        onlyInstance = true,
        flask = true,
        food = true,
        raidBuffs = true,
        weaponOil = true,
    }
    return profile.buffReminders
end

local DEFAULT_POSITION = { point = "TOP", relPoint = "TOP", x = 0, y = -80 }

function BR:Position()
    if not self.frame then return end
    local cfg = self:GetConfig()
    self.frame:ClearAllPoints()
    self.frame:SetPoint(
        cfg.point or DEFAULT_POSITION.point,
        UIParent,
        cfg.relPoint or cfg.point or DEFAULT_POSITION.relPoint,
        cfg.x or DEFAULT_POSITION.x,
        cfg.y or DEFAULT_POSITION.y
    )
end

function BR:CreateUI()
    if self.frame then return end
    local frame = CreateFrame("Frame", "RexUI_BuffRemindersFrame", UIParent)
    frame:SetSize(180, 48)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0.08, 0.08, 0.10, 0.82)
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.text:SetPoint("CENTER")
    frame.text:SetTextColor(1, 0.82, 0.35)
    frame:Hide()
    self.frame = frame
    self:Position()
end

-- ------------------------------------------------------------
-- MOVER (RexUI:Unlock / RexUI:Lock)
-- ------------------------------------------------------------

function BR:CreateMover()
    if self.Mover then return end
    self:CreateUI()

    local mover = CreateFrame("Frame", "RexUI_BuffRemindersMover", UIParent)
    mover:SetFrameStrata("HIGH")
    mover:SetFrameLevel(500)
    mover:SetClampedToScreen(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:Hide()

    mover.Bg = mover:CreateTexture(nil, "BACKGROUND")
    mover.Bg:SetAllPoints(mover)
    mover.Bg:SetColorTexture(0.2, 0.6, 1, 0.25)

    mover.Label = mover:CreateFontString(nil, "OVERLAY")
    mover.Label:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    mover.Label:SetPoint("CENTER")
    mover.Label:SetText(T("Buff-Erinnerungen"))

    mover:SetScript("OnDragStart", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        self:SetMovable(true)
        self:StartMoving()
    end)

    mover:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetMovable(false)

        local left, bottom, width, height = self:GetRect()
        if left then
            local centerX, centerY = UIParent:GetCenter()
            local cfg = BR:GetConfig()
            cfg.point = "CENTER"
            cfg.relPoint = "CENTER"
            cfg.x = math.floor((left + width / 2 - centerX) + 0.5)
            cfg.y = math.floor((bottom + height / 2 - centerY) + 0.5)
            BR:Position()
        end
        BR:UpdateMover()
    end)

    self.Mover = mover
end

function BR:UpdateMover()
    if not self.Mover or not self.frame then return end
    self.Mover:ClearAllPoints()
    self.Mover:SetSize(self.frame:GetWidth(), self.frame:GetHeight())
    self.Mover:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
end

function BR:ShowMover()
    self:CreateMover()
    self:Refresh()
    self:UpdateMover()
    self.Mover:Show()
end

function BR:HideMover()
    if self.Mover then self.Mover:Hide() end
    self:Refresh()
end

-- Im Entsperr-Modus bleibt das Fenster mit Beispieltext sichtbar, damit es sich
-- auch außerhalb von Instanzen bzw. mit allen Buffs verschieben lässt.
function BR:ShowPreview()
    self:CreateUI()
    self.frame.text:SetText(T("Fehlt: ") .. table.concat({ T("Flask"), T("Essen"), T("Waffenöl") }, ", "))
    self.frame:SetWidth(math.max(180, math.ceil(self.frame.text:GetStringWidth()) + 32))
    self.frame:Show()
    self:UpdateMover()
end

function BR:Refresh()
    if RexUI.Unlocked then
        self:ShowPreview()
        return
    end
    local Perf = RexUI.Perf
    local perfStart = Perf and Perf:Start()
    self:Evaluate()
    if Perf then Perf:Stop("BuffReminders", perfStart, "fullUpdates") end
end

function BR:Evaluate()

    local cfg = self:GetConfig()
    if not cfg.enabled then
        if self.frame then self.frame:Hide() end
        return
    end

    if cfg.onlyInstance then
        local inInstance = IsInInstance and select(1, IsInInstance())
        if not inInstance then
            if self.frame then self.frame:Hide() end
            return
        end
    end

    self:CreateUI()
    local missing = {}

    -- "== false" statt "not": nil bedeutet unbekannt und wird nie als fehlend gemeldet.
    if cfg.flask ~= false and self:Remember("flask", HasFlask()) == false then
        missing[#missing + 1] = T("Flask")
    end
    if cfg.food ~= false and self:Remember("food", HasFood()) == false then
        missing[#missing + 1] = T("Essen")
    end
    if cfg.weaponOil ~= false and self:Remember("weaponOil", HasWeaponOil()) == false then
        missing[#missing + 1] = T("Waffenöl")
    end
    if cfg.raidBuffs ~= false then
        self:GetMissingRaidBuffs(missing)
    end

    if #missing == 0 then
        self.frame:Hide()
        return
    end

    self.frame.text:SetText(T("Fehlt: ") .. table.concat(missing, ", "))
    self.frame:SetWidth(math.max(180, math.ceil(self.frame.text:GetStringWidth()) + 32))
    self.frame:Show()
end

function BR:Initialize()
    self.frameEvent = CreateFrame("Frame")
    self:RegisterEvents(self.frameEvent, {
        "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE",
        "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_ENABLED",
    })
    self.unitEvent = CreateFrame("Frame")
    self:RegisterEvents(self.unitEvent, { "UNIT_AURA", "UNIT_INVENTORY_CHANGED" }, "player")

    local function OnEvent(_, event)
        if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "GROUP_ROSTER_UPDATE" then
            self.groupClasses = nil
        end
        self:QueueRefresh()
    end
    self.frameEvent:SetScript("OnEvent", OnEvent)
    self.unitEvent:SetScript("OnEvent", OnEvent)
end

function BR:Enable()
    if self:GetConfig().enabled == false then
        self:Disable()
        return
    end
    self.enabled = true
    self:ResumeEvents()
    -- Ablaufende Waffenöle lösen kein Event aus; deshalb ein langsamer Sicherheits-Tick.
    if not self.ticker and C_Timer and C_Timer.NewTicker then
        self.ticker = C_Timer.NewTicker(20, function() self:Refresh() end)
    end
    self:QueueRefresh()
end

function BR:Disable()
    self.enabled = false
    self:SuspendEvents()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    if self.timer then
        self.timer:Cancel()
        self.timer = nil
    end
    if self.frame then self.frame:Hide() end
    if self.Mover then self.Mover:Hide() end
end

function BR:QueueRefresh()
    if self.enabled == false or self.timer then return end
    -- NewTimer (statt After) liefert ein Handle, damit die Drossel greift und
    -- Disable() den ausstehenden Refresh abbrechen kann.
    if C_Timer and C_Timer.NewTimer then
        self.timer = C_Timer.NewTimer(0.4, function()
            self.timer = nil
            self:Refresh()
        end)
    else
        self:Refresh()
    end
end

function BR:ApplyProfile()
    if self:GetConfig().enabled == false then
        if self.enabled ~= false then self:Disable() end
        return
    end
    if self.enabled ~= true then
        self:Enable()
        return
    end
    self:Refresh()
end
