-- ============================================================
-- RexUI – Persist.lua
-- Recovery-Schicht für den WoW-Forever-SavedVariables-Bug
-- ============================================================
-- Der Client schreibt Account-SavedVariables weiterhin, liest RexUIDB
-- nach einem Neustart (und oft auch nach /reload) aber nicht wieder ein.
-- Die SavedVariables von Blizzard_AddOnList werden dagegen erneut geladen:
-- die globale Tabelle g_addonCategoriesCollapsed überlebt /reload und
-- einen vollständigen Client-Start.
--
-- RexUI hängt die lebende RexUIDB-Tabelle dort unter einem eigenen
-- Schlüssel als Referenz ein. Blizzard serialisiert sie mit seiner
-- eigenen Datei. Beim Login wird RexUIDB daraus nur dann wiederhergestellt,
-- wenn die normale SavedVariable leer ist.
--
-- Keine CVars, keine Makros, kein Schreiben ins WTF-Verzeichnis,
-- keine Änderung an Blizzard-Dateien. RexUIDB bleibt die Datenbasis.
-- ============================================================

local ADDON_NAME, ns = ...
local RexUI = ns.RexUI
if not RexUI then
    return
end

local HOST_GLOBAL = "g_addonCategoriesCollapsed"
local ACCOUNT_KEY = "__rexui_account"
local CHARACTER_KEY = "__rexui_character"
local FLUSH_INTERVAL = 5

local watching = false
local elapsedSinceFlush = 0
local adoptedAccount
local adoptedCharacter

local function IsPopulated(value)
    return type(value) == "table" and next(value) ~= nil
end

local function GetHostTable()
    local host = _G[HOST_GLOBAL]
    if type(host) == "table" then
        return host
    end
end

local function GetCharacterSlot()
    local name = UnitName and UnitName("player")
    local realm = GetRealmName and GetRealmName()
    if type(name) ~= "string" or name == "" or type(realm) ~= "string" or realm == "" then
        return nil
    end

    return name .. "-" .. realm:gsub("%s+", "")
end

local function GetCharacterMap(host, create)
    local map = host[CHARACTER_KEY]
    if type(map) ~= "table" then
        if not create then
            return nil
        end
        map = {}
        host[CHARACTER_KEY] = map
    end
    return map
end

local function AdoptAccount(db)
    if type(db) ~= "table" then
        return
    end
    RexUIDB = db
    adoptedAccount = db
    if RexUI.db then
        RexUI.db = db
        RexUI.profile = db.profile
    end
end

local function AdoptCharacter(db)
    if type(db) ~= "table" then
        return
    end
    RexUICharDB = db
    adoptedCharacter = db
end

local function RecoverAccount(host)
    if IsPopulated(RexUIDB) then
        adoptedAccount = adoptedAccount or RexUIDB
        return false
    end

    local stored = host[ACCOUNT_KEY]
    if not IsPopulated(stored) then
        return false
    end

    AdoptAccount(stored)
    return true
end

local function RecoverCharacter(host)
    local slot = GetCharacterSlot()
    if not slot then
        return false
    end

    if IsPopulated(RexUICharDB) then
        adoptedCharacter = adoptedCharacter or RexUICharDB
        return false
    end

    local map = GetCharacterMap(host, false)
    local stored = map and map[slot]
    if not IsPopulated(stored) then
        return false
    end

    AdoptCharacter(stored)
    return true
end

local function AttachAccount(host)
    if type(RexUIDB) ~= "table" then
        return
    end

    local existing = host[ACCOUNT_KEY]
    if existing == RexUIDB or adoptedAccount == RexUIDB or not IsPopulated(existing) then
        host[ACCOUNT_KEY] = RexUIDB
        adoptedAccount = RexUIDB
    end
end

local function AttachCharacter(host)
    local slot = GetCharacterSlot()
    if not slot then
        return
    end

    if type(RexUICharDB) ~= "table" then
        RexUICharDB = {}
    end

    local map = GetCharacterMap(host, true)
    local existing = map[slot]
    if existing == RexUICharDB or adoptedCharacter == RexUICharDB or not IsPopulated(existing) then
        map[slot] = RexUICharDB
        adoptedCharacter = RexUICharDB
    end
end

local function AttachToHost()
    local host = GetHostTable()
    if not host then
        return false
    end

    AttachAccount(host)
    AttachCharacter(host)
    return true
end

function RexUI:RecoverPersistedDatabase()
    local host = GetHostTable()
    if not host then
        return false
    end

    local restoredAccount = RecoverAccount(host)
    local restoredCharacter = RecoverCharacter(host)
    return restoredAccount or restoredCharacter
end

function RexUI:StartPersistence()
    watching = true
    elapsedSinceFlush = 0
    self:RecoverPersistedDatabase()
    AttachToHost()
end

function RexUI:FlushPersistence()
    if not watching then
        return false
    end
    return AttachToHost()
end

function RexUI:ClearPersistedDatabase()
    watching = false
    adoptedAccount = nil
    adoptedCharacter = nil

    local host = GetHostTable()
    if host then
        host[ACCOUNT_KEY] = nil
        host[CHARACTER_KEY] = nil
    end
end

RexUI:RecoverPersistedDatabase()

if not _G.CreateFrame then
    return
end

local persistFrame = CreateFrame("Frame")
persistFrame:RegisterEvent("PLAYER_LOGOUT")
persistFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
persistFrame:RegisterEvent("ADDON_LOADED")
persistFrame:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == ADDON_NAME or addonName == "Blizzard_AddOnList" then
            RexUI:RecoverPersistedDatabase()
            RexUI:FlushPersistence()
        end
        return
    end

    RexUI:FlushPersistence()
end)
persistFrame:SetScript("OnUpdate", function(_, elapsed)
    if not watching then
        return
    end

    elapsedSinceFlush = elapsedSinceFlush + elapsed
    if elapsedSinceFlush < FLUSH_INTERVAL then
        return
    end

    elapsedSinceFlush = 0
    AttachToHost()
end)
