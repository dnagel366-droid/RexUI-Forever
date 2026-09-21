-- ============================================================
-- RexUI - Profiles.lua
-- Profiles, per-character selection, import and export.
-- ============================================================

local ADDON_NAME, ns = ...
local RexUI = ns.RexUI

if not RexUI then
    return
end

local EXPORT_PREFIX = "!RexUI:1!"
local RAW_EXPORT_PREFIX = "!RexUIRAW:1!"
local PACKED_PROFILES_VERSION = 1
local PACKED_CHUNK_SIZE = 180
local DeserializeTable
local packedProfilesRestored = false

local function CopyTableDeep(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}

    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = CopyTableDeep(value)
        else
            copy[key] = value
        end
    end

    return copy
end

local function MergeDefaults(defaults, target)
    if type(defaults) ~= "table" then
        return target
    end

    if type(target) ~= "table" then
        target = {}
    end

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = MergeDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

local function Trim(value)
    value = tostring(value or "")
    return value:match("^%s*(.-)%s*$") or ""
end

local function GetCharacterKey()
    local name = UnitName and UnitName("player") or "Unknown"
    local realm = GetRealmName and GetRealmName() or "Realm"

    realm = tostring(realm or "Realm"):gsub("%s+", "")

    return tostring(name or "Unknown") .. "-" .. realm
end

local function GetCharacterProfileName(characterKey)
    return tostring(characterKey or GetCharacterKey())
end

local function GetLibDeflate()
    if not LibStub then return nil end

    local ok, lib = pcall(LibStub.GetLibrary, LibStub, "LibDeflate", true)
    if ok then
        return lib
    end
end

local function DecodePackedTable(prefix, countKey)
    if not RexUIDB or RexUIDB.packedProfilesVersion ~= PACKED_PROFILES_VERSION then
        return nil
    end

    local count = tonumber(RexUIDB[countKey])
    if not count or count < 1 or count ~= math.floor(count) then
        return nil
    end

    local chunks = {}
    for index = 1, count do
        local chunk = RexUIDB[prefix .. index]
        if type(chunk) ~= "string" or chunk == "" then
            return nil
        end
        chunks[index] = chunk
    end

    local lib = GetLibDeflate()
    if not lib or type(DeserializeTable) ~= "function" then
        return nil
    end

    local decoded = lib:DecodeForPrint(table.concat(chunks))
    if not decoded then
        return nil
    end

    local payload = lib:DecompressDeflate(decoded)
    if not payload then
        return nil
    end

    local data = DeserializeTable(payload)
    if type(data) ~= "table" or data.version ~= PACKED_PROFILES_VERSION then
        return nil
    end

    return data
end

local function RestorePackedProfiles(overwrite)
    if packedProfilesRestored or not RexUIDB then return end
    packedProfilesRestored = true

    RexUIDB.profiles = type(RexUIDB.profiles) == "table" and RexUIDB.profiles or {}

    local packed = DecodePackedTable("packedProfiles", "packedProfilesCount")
    if packed and type(packed.profiles) == "table" then
        for profileName, profile in pairs(packed.profiles) do
            if type(profileName) == "string" and type(profile) == "table"
                and (overwrite or RexUIDB.profiles[profileName] == nil) then
                RexUIDB.profiles[profileName] = profile
            end
        end

        if type(packed.currentProfile) == "string"
            and RexUIDB.profiles[packed.currentProfile]
            and (overwrite
                or type(RexUIDB.currentProfile) ~= "string"
                or not RexUIDB.profiles[RexUIDB.currentProfile]) then
            RexUIDB.currentProfile = packed.currentProfile
        end
    end

    local active = DecodePackedTable("packedActiveProfile", "packedActiveProfileCount")
    if active and type(active.currentProfile) == "string" and type(active.profile) == "table"
        and (overwrite or RexUIDB.profiles[active.currentProfile] == nil) then
        RexUIDB.profiles[active.currentProfile] = active.profile
        if overwrite then
            RexUIDB.currentProfile = active.currentProfile
        end
    end
end

local function SanitizeProfile(profile)
    local incomingNameplates = type(profile) == "table" and profile.nameplates or nil
    local isNewNameplates = type(incomingNameplates) == "table"
        and incomingNameplates.schemaVersion == 2
    profile = MergeDefaults(RexUI.defaults.profile, profile)

    profile.general = profile.general or {}
    profile.general.uiScale = nil

    local legacyNameplates = isNewNameplates and nil or incomingNameplates
    local legacyColors = type(legacyNameplates) == "table" and legacyNameplates.colors
    if type(legacyColors) == "table" then
        profile.unitframes = type(profile.unitframes) == "table" and profile.unitframes or {}
        local enemyColors = type(profile.unitframes.enemyCastColors) == "table"
            and profile.unitframes.enemyCastColors or {}
        profile.unitframes.enemyCastColors = enemyColors

        for newKey, oldKey in pairs({
            interruptible = "castInterruptible",
            protected = "castProtected",
            interrupted = "castInterrupted",
        }) do
            if type(enemyColors[newKey]) ~= "table" and type(legacyColors[oldKey]) == "table" then
                enemyColors[newKey] = CopyTableDeep(legacyColors[oldKey])
            end
        end
    end
    if not isNewNameplates then
        profile.nameplates = nil
        if RexUI.defaults.profile.nameplates then
            profile.nameplates = MergeDefaults(RexUI.defaults.profile.nameplates, nil)
        end
    end

    local damageMeter = profile.damageMeter
    if type(damageMeter) == "table" and type(damageMeter.barTexture) == "string" then
        local legacyPrefix = "Interface\\AddOns\\RexUI\\media\\nameplates\\rexui\\"
        local statusbarPrefix = "Interface\\AddOns\\RexUI\\media\\statusbars\\"
        local fileName = damageMeter.barTexture:match("^" .. legacyPrefix .. "(.+)$")
        if fileName == "bar_background.tga" or fileName == "bar_serenity.tga" or fileName == "bar4.tga" then
            damageMeter.barTexture = statusbarPrefix .. fileName
        end
    end

    return profile
end

local function EnsureProfileStorage()
    if not RexUIDB then return end
    if not RexUI or not RexUI.defaults then return end

    RestorePackedProfiles()
    RexUIDB.profiles = RexUIDB.profiles or {}
    RexUIDB.profileKeys = RexUIDB.profileKeys or {}
    RexUIDB.profileKeyManual = RexUIDB.profileKeyManual or {}
    RexUIDB.currentProfile = RexUIDB.currentProfile or "Default"

    if not RexUIDB.profiles.Default then
        RexUIDB.profiles.Default = SanitizeProfile(CopyTableDeep(RexUIDB.profile or RexUI.defaults.profile))
    end
end

local function SerializeValue(value, depth)
    depth = depth or 0

    if depth > 20 then
        return "nil"
    end

    local valueType = type(value)

    if valueType == "number" or valueType == "boolean" then
        return tostring(value)
    elseif valueType == "string" then
        return string.format("%q", value)
    elseif valueType ~= "table" then
        return "nil"
    end

    local keys = {}

    for key in pairs(value) do
        if type(key) == "string" or type(key) == "number" then
            keys[#keys + 1] = key
        end
    end

    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    local parts = { "{" }

    for _, key in ipairs(keys) do
        local encodedKey

        if type(key) == "string" and key:match("^[%a_][%w_]*$") then
            encodedKey = key
        else
            encodedKey = "[" .. SerializeValue(key, depth + 1) .. "]"
        end

        parts[#parts + 1] = encodedKey .. "=" .. SerializeValue(value[key], depth + 1) .. ","
    end

    parts[#parts + 1] = "}"

    return table.concat(parts)
end

DeserializeTable = function(payload)
    if type(payload) ~= "string" or payload == "" then
        return nil, "Leerer Import."
    end

    local loader = loadstring or load
    if type(loader) ~= "function" then
        return nil, "Import wird von dieser Lua-Version nicht unterstützt."
    end

    local chunk, errorMessage = loader("return " .. payload)
    if not chunk then
        return nil, errorMessage
    end

    if setfenv then
        setfenv(chunk, {})
    end

    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then
        return nil, result
    end

    return result
end

local function EncodePackedTable(data)
    local lib = GetLibDeflate()
    if not lib then return nil end

    local payload = SerializeValue(data)
    local compressed = lib:CompressDeflate(payload, { level = 9 })
    if not compressed then return nil end

    return lib:EncodeForPrint(compressed)
end

local function ReplacePackedChunks(prefix, countKey, encoded)
    local newCount = math.ceil(#encoded / PACKED_CHUNK_SIZE)

    for index = 1, newCount do
        local first = (index - 1) * PACKED_CHUNK_SIZE + 1
        RexUIDB[prefix .. index] = encoded:sub(first, first + PACKED_CHUNK_SIZE - 1)
    end

    local staleKeys = {}
    for key in pairs(RexUIDB) do
        local index = type(key) == "string" and tonumber(key:match("^" .. prefix .. "(%d+)$"))
        if index and index > newCount then
            staleKeys[#staleKeys + 1] = key
        end
    end
    for _, key in ipairs(staleKeys) do
        RexUIDB[key] = nil
    end

    RexUIDB[countKey] = newCount
end

function RexUI:PackProfilesForStorage()
    if not RexUIDB or type(RexUIDB.profiles) ~= "table" then
        return false
    end

    local currentProfile = self:GetCurrentProfile()
    local activeProfile = RexUIDB.profiles[currentProfile]
    if type(currentProfile) ~= "string" or type(activeProfile) ~= "table" then
        return false
    end

    local packedProfiles = EncodePackedTable({
        version = PACKED_PROFILES_VERSION,
        currentProfile = currentProfile,
        profiles = RexUIDB.profiles,
    })
    local packedActiveProfile = EncodePackedTable({
        version = PACKED_PROFILES_VERSION,
        currentProfile = currentProfile,
        profile = activeProfile,
    })

    -- Keep the normal tables untouched unless both replacement payloads were
    -- built successfully. This makes a compression failure non-destructive.
    if not packedProfiles or not packedActiveProfile then
        return false
    end

    ReplacePackedChunks("packedProfiles", "packedProfilesCount", packedProfiles)
    ReplacePackedChunks("packedActiveProfile", "packedActiveProfileCount", packedActiveProfile)
    RexUIDB.packedProfilesVersion = PACKED_PROFILES_VERSION
    RexUIDB.lastSavedProfile = currentProfile

    -- The packed payloads are now the canonical on-disk representation.
    RexUIDB.profiles = nil
    RexUIDB.profile = nil
    return true
end

function RexUI:InitProfiles()
    EnsureProfileStorage()

    local characterKey = GetCharacterKey()
    local characterProfile = GetCharacterProfileName(characterKey)

    -- Gespeicherte Profilwahl respektieren
    if RexUIDB.profileKeys[characterKey] then
        local manualProfile = RexUIDB.profileKeys[characterKey]
        if RexUIDB.profiles[manualProfile] then
            RexUIDB.profiles[manualProfile] = SanitizeProfile(RexUIDB.profiles[manualProfile])
            RexUIDB.currentProfile = manualProfile
            RexUIDB.profileKeyManual[characterKey] = true
            self.characterKey = characterKey
            self.currentProfile = manualProfile
            self.db.profile = RexUIDB.profiles[manualProfile]
            self.profile = self.db.profile
            return
        end
    end

    -- Existiert noch kein Charakter-eigenes Profil?
    if not RexUIDB.profiles[characterProfile] then
        -- Gab es vorher eine manuelle Profil-Zuweisung? Dann übernehmen
        local oldProfile = RexUIDB.profileKeys and RexUIDB.profileKeys[characterKey]
        if oldProfile and RexUIDB.profiles[oldProfile] then
            RexUIDB.profiles[characterProfile] = CopyTableDeep(RexUIDB.profiles[oldProfile])
        else
            RexUIDB.profiles[characterProfile] = CopyTableDeep(RexUI.defaults.profile)
        end
    end

    RexUIDB.profiles[characterProfile] = SanitizeProfile(RexUIDB.profiles[characterProfile])
    RexUIDB.profileKeys[characterKey] = characterProfile
    RexUIDB.profileKeyManual[characterKey] = nil
    RexUIDB.currentProfile = characterProfile

    self.characterKey = characterKey
    self.currentProfile = characterProfile
    self.db.profile = RexUIDB.profiles[characterProfile]
    self.profile = self.db.profile

end

function RexUI:GetProfile()
    return self.db and self.db.profile
end

function RexUI:GetCurrentProfile()
    return self.currentProfile or (RexUIDB and RexUIDB.currentProfile) or "Default"
end

function RexUI:GetCharacterKey()
    self.characterKey = self.characterKey or GetCharacterKey()
    return self.characterKey
end

function RexUI:GetProfileList()
    EnsureProfileStorage()

    local list = {}

    for profileName in pairs(RexUIDB.profiles) do
        list[#list + 1] = profileName
    end

    table.sort(list)
    return list
end

function RexUI:CreateProfile(profileName, copyCurrent)
    EnsureProfileStorage()

    profileName = Trim(profileName)
    if profileName == "" then
        return false, "Bitte Profilnamen eingeben."
    end

    if RexUIDB.profiles[profileName] then
        return false, "Profil existiert bereits."
    end

    local profile = SanitizeProfile(copyCurrent and CopyTableDeep(self:GetProfile()) or CopyTableDeep(RexUI.defaults.profile))
    local AB = self.ActionBars
    if AB and AB.GetCurrentSpecKey then
        profile.lastActionBarSpec = AB:GetCurrentSpecKey()
    end
    RexUIDB.profiles[profileName] = profile

    self:PrintMessage("Profil erstellt: " .. profileName)
    return true
end

function RexUI:SetProfile(profileName)
    EnsureProfileStorage()

    profileName = Trim(profileName)
    if profileName == "" then
        return false, "Bitte Profilnamen eingeben."
    end

    RexUIDB.profiles[profileName] =
        SanitizeProfile(RexUIDB.profiles[profileName] or CopyTableDeep(RexUI.defaults.profile))

    RexUIDB.currentProfile = profileName
    RexUIDB.profileKeys[self:GetCharacterKey()] = profileName
    RexUIDB.profileKeyManual[self:GetCharacterKey()] = true

    self.currentProfile = profileName
    self.db.profile = RexUIDB.profiles[profileName]
    self.profile = self.db.profile

    self:PrintMessage("Profil gewechselt: " .. profileName)

    if self.ApplyProfileSettings then
        self:ApplyProfileSettings()
    end

    if ReloadUI then
        ReloadUI()
    end
    return true
end

function RexUI:DeleteProfile(profileName)
    EnsureProfileStorage()

    profileName = Trim(profileName)
    if profileName == "" then
        return false, "Bitte Profilnamen eingeben."
    end

    if profileName == "Default" then
        return false, "Default kann nicht gelöscht werden."
    end

    if not RexUIDB.profiles[profileName] then
        return false, "Profil nicht gefunden."
    end

    if profileName == self.currentProfile then
        return false, "Aktives Profil erst wechseln, dann löschen."
    end

    RexUIDB.profiles[profileName] = nil

    for characterKey, assignedProfile in pairs(RexUIDB.profileKeys or {}) do
        if assignedProfile == profileName then
            RexUIDB.profileKeys[characterKey] = nil
            if RexUIDB.profileKeyManual then
                RexUIDB.profileKeyManual[characterKey] = nil
            end
        end
    end

    self:PrintMessage("Profil gelöscht: " .. profileName)
    return true, "Profil gelöscht: " .. profileName
end

function RexUI:CopyProfileSettings(sourceProfileName)
    EnsureProfileStorage()

    sourceProfileName = Trim(sourceProfileName)
    if sourceProfileName == "" then
        return false, "Kein Quellprofil angegeben."
    end

    local source = RexUIDB.profiles[sourceProfileName]
    if not source then
        return false, "Quellprofil nicht gefunden: " .. sourceProfileName
    end

    local current = self:GetProfile()
    if not current then
        return false, "Kein aktives Profil."
    end

    for k, v in pairs(source) do
        if k ~= "general" or v then
            if type(v) == "table" then
                current[k] = CopyTableDeep(v)
            else
                current[k] = v
            end
        end
    end

    self:PrintMessage("Einstellungen kopiert von: " .. sourceProfileName)

    ReloadUI()
    return true
end

function RexUI:ResetProfile()
    EnsureProfileStorage()

    RexUIDB.profiles[self.currentProfile] = SanitizeProfile(CopyTableDeep(RexUI.defaults.profile))
    self.db.profile = RexUIDB.profiles[self.currentProfile]
    self.profile = self.db.profile

    self:PrintMessage("Profil zurückgesetzt.")

    ReloadUI()
end

function RexUI:ApplyProfileSettings()
    if self.InitTheme then
        pcall(self.InitTheme, self)
    end

    local AB = self.ActionBars
    if AB then
        if AB.ApplyLoadedSettings then pcall(AB.ApplyLoadedSettings, AB) end
        if AB.QueueStateRefresh then pcall(AB.QueueStateRefresh, AB) end
        if AB.MarkDirty then pcall(AB.MarkDirty, AB) end
        if AB.ScheduleDirtyFlush then pcall(AB.ScheduleDirtyFlush, AB) end
        if AB.ApplyProfile then pcall(AB.ApplyProfile, AB) end
    end

    -- Einheitlicher ApplyProfile-Pfad für registrierte Module (P0.3)
    for _, moduleName in ipairs(self.moduleOrder or {}) do
        local module = self.modules and self.modules[moduleName]
        if module and module.ApplyProfile then
            pcall(module.ApplyProfile, module)
        end
    end

    local modules = {
        { object = self.Minimap, method = "Update" },
        { object = self.MicroMenu, method = "Update" },
        { object = self.UnitFrames, method = "Apply" },
        { object = self.modules and self.modules.Nameplates, method = "Apply" },
        { object = self.modules and self.modules.GroupFrames, method = "Apply" },
        { object = self.GroupFrames, method = "Apply" },
        { object = self.modules and self.modules.StatusBars, method = "Update" },
        { object = self.StatusBars, method = "Update" },
        { object = self.modules and self.modules.RaidUtility, method = "Position" },
        { object = self.RaidUtility, method = "Position" },
        { object = self.modules and self.modules.RaidUtility, method = "UpdateAvailability" },
        { object = self.RaidUtility, method = "UpdateAvailability" },
        { object = self.modules and self.modules.GuildKeys, method = "RefreshRows" },
        { object = self.QuestTracker, method = "Update" },
        { object = self.DamageMeter, method = "Apply" },
        { object = self.MythicTimer, method = "Apply" },
        { object = self.Bags, method = "Refresh" },
        { object = self.Bags, method = "ApplyBindings" },
        { object = self.BlizzardSkin, method = "Refresh" },
        { object = self.RealmOrigin, method = "Refresh" },
    }

    for _, entry in ipairs(modules) do
        local object = entry.object
        local method = object and object[entry.method]
        if method then
            pcall(method, object)
        end
    end

    if self.ConfigUI
    and self.ConfigUI.Window
    and self.ConfigUI.Window:IsShown()
    and self.ConfigUI.SetCategory
    and self.ConfigUI.CurrentCategory then
        local function RefreshConfig()
            if RexUI.ConfigUI
            and RexUI.ConfigUI.Window
            and RexUI.ConfigUI.Window:IsShown()
            and RexUI.ConfigUI.CurrentCategory then
                RexUI.ConfigUI:SetCategory(RexUI.ConfigUI.CurrentCategory)
            end
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(0, RefreshConfig)
        else
            RefreshConfig()
        end
    end
end

-- ------------------------------------------------------------
-- Teilprofile (P3): exportier-/importierbare Abschnitte
-- ------------------------------------------------------------

RexUI.ProfileSections = {
    { key = "actionbars",  label = "Actionbars",        paths = { "actionbars", "actionbarsBySpec", "microMenu" } },
    { key = "nameplates",  label = "Namensplaketten",   paths = { "nameplates" } },
    { key = "unitframes",  label = "Unitframes",        paths = { "unitframes" } },
    { key = "groupframes", label = "Gruppenframes",     paths = { "groupFrames" } },
    { key = "colors",      label = "Farben & Theme",    paths = { "theme" } },
    { key = "minimap",     label = "Minimap & Datenleiste", paths = { "minimap" } },
    { key = "bags",        label = "Taschen",           paths = { "bags" } },
    { key = "chat",        label = "Chat & Blizzard-Skin", paths = { "blizzardSkin" } },
    { key = "tools",       label = "Kampf-Tools & Komfort", paths = { "comfort", "cooldownManager", "statusbars", "raidUtility", "damageMeter", "guildKeys", "mythicTimer", "questTracker", "realmOrigin", "positions" } },
}

function RexUI:GetProfileSection(key)
    for _, section in ipairs(self.ProfileSections) do
        if section.key == key then return section end
    end
end

local function ResolveExportProfile(self, profileName)
    profileName = Trim(profileName)
    if profileName == "" then
        profileName = self.currentProfile or "Default"
    end

    local stored = RexUIDB.profiles[profileName]
    local currentName = self.currentProfile or (RexUIDB and RexUIDB.currentProfile)
    local live = self.GetProfile and self:GetProfile()
    if profileName == currentName and type(live) == "table" then
        if stored ~= live then
            RexUIDB.profiles[profileName] = live
        end
        return live, profileName
    end
    return stored, profileName
end

local function LiveXPEnabled()
    local SB = RexUI.StatusBars
    if SB and SB.IsXPEnabled then
        return SB:IsXPEnabled() == true
    end
    return type(RexUICharDB) == "table"
        and type(RexUICharDB.statusbars) == "table"
        and RexUICharDB.statusbars.xpEnabled == true
end

local function StampXPEnabled(profile, isCurrent)
    if type(profile) ~= "table" then
        return
    end
    profile.statusbars = profile.statusbars or {}
    if isCurrent then
        profile.statusbars.xpEnabled = profile.statusbars.xpEnabled == true or LiveXPEnabled()
    elseif profile.statusbars.xpEnabled == nil then
        profile.statusbars.xpEnabled = false
    end
end

local function SyncProfileForExport(profile, isCurrent)
    if type(profile) ~= "table" then
        return
    end
    local SB = RexUI.StatusBars
    if SB and SB.SyncToProfile then
        SB:SyncToProfile(profile)
    end
    StampXPEnabled(profile, isCurrent)
    local AB = RexUI.ActionBars
    if AB and AB.FlushDeferred then
        pcall(AB.FlushDeferred, AB)
    end
end

-- Exportiert nur die gewählten Abschnitte (Liste von Abschnittsschlüsseln).
function RexUI:ExportProfileSections(sectionKeys, profileName)
    EnsureProfileStorage()

    local profile
    profile, profileName = ResolveExportProfile(self, profileName)
    if not profile then
        return nil, "Profil nicht gefunden."
    end

    local currentName = self.currentProfile or (RexUIDB and RexUIDB.currentProfile)
    SyncProfileForExport(profile, profileName == currentName)
    local sanitized = SanitizeProfile(CopyTableDeep(profile))
    StampXPEnabled(sanitized, profileName == currentName)
    local sections = {}
    local count = 0
    for _, key in ipairs(sectionKeys or {}) do
        local section = self:GetProfileSection(key)
        if section then
            sections[key] = {}
            for _, path in ipairs(section.paths) do
                if sanitized[path] ~= nil then
                    sections[key][path] = sanitized[path]
                end
            end
            count = count + 1
        end
    end
    if count == 0 then
        return nil, "Keine Abschnitte gewählt."
    end

    local payload = SerializeValue({
        version = 2,
        addon = "RexUI",
        profileName = profileName,
        partial = true,
        sections = sections,
    })

    local lib = GetLibDeflate()
    if lib then
        local compressed = lib:CompressDeflate(payload, { level = 9 })
        if compressed then
            return EXPORT_PREFIX .. lib:EncodeForPrint(compressed)
        end
    end
    return RAW_EXPORT_PREFIX .. payload
end

-- Übernimmt Abschnitte aus einem Teilprofil in das aktive Profil.
function RexUI:ImportProfileSections(data)
    if type(data) ~= "table" or type(data.sections) ~= "table" then
        return false, "Kein Teilprofil."
    end
    local profile = self:GetProfile()
    if not profile then
        return false, "Kein aktives Profil."
    end

    local imported = {}
    for key, content in pairs(data.sections) do
        local section = self:GetProfileSection(key)
        if section and type(content) == "table" then
            for _, path in ipairs(section.paths) do
                if content[path] ~= nil then
                    profile[path] = CopyTableDeep(content[path])
                end
            end
            imported[#imported + 1] = section.label
        end
    end
    if #imported == 0 then
        return false, "Teilprofil enthält keine bekannten Abschnitte."
    end

    -- Fehlende Standardwerte ergänzen, damit neue Schlüssel nie fehlen.
    if self.defaults and self.defaults.profile then
        MergeDefaults(self.defaults.profile, profile)
    end

    if profile.statusbars and profile.statusbars.xpEnabled ~= nil then
        local SB = self.StatusBars or (self.modules and self.modules.StatusBars)
        if SB and SB.SetXPEnabled then
            SB:SetXPEnabled(profile.statusbars.xpEnabled == true)
        end
    end

    if self.ApplyProfileSettings then
        self:ApplyProfileSettings()
    end
    table.sort(imported)
    self:PrintMessage("Teilprofil importiert: " .. table.concat(imported, ", "))
    return true, imported
end

function RexUI:ExportProfile(profileName)
    EnsureProfileStorage()

    local profile
    profile, profileName = ResolveExportProfile(self, profileName)
    if not profile then
        return nil, "Profil nicht gefunden."
    end

    local currentName = self.currentProfile or (RexUIDB and RexUIDB.currentProfile)
    SyncProfileForExport(profile, profileName == currentName)
    local sanitized = SanitizeProfile(CopyTableDeep(profile))
    StampXPEnabled(sanitized, profileName == currentName)

    local payload = SerializeValue({
        version = 1,
        addon = "RexUI",
        profileName = profileName,
        profile = sanitized,
    })

    local lib = GetLibDeflate()
    if lib then
        local compressed = lib:CompressDeflate(payload, { level = 9 })
        if compressed then
            return EXPORT_PREFIX .. lib:EncodeForPrint(compressed)
        end
    end

    return RAW_EXPORT_PREFIX .. payload
end

function RexUI:ImportProfile(importString, profileName)
    EnsureProfileStorage()

    importString = Trim(importString)
    profileName = Trim(profileName)

    if importString == "" then
        return false, "Import-String fehlt."
    end

    local payload

    if importString:sub(1, #EXPORT_PREFIX) == EXPORT_PREFIX then
        local lib = GetLibDeflate()
        if not lib then
            return false, "LibDeflate fehlt."
        end

        local decoded = lib:DecodeForPrint(importString:sub(#EXPORT_PREFIX + 1))
        if not decoded then
            return false, "Import-String ungueltig."
        end

        payload = lib:DecompressDeflate(decoded)
    elseif importString:sub(1, #RAW_EXPORT_PREFIX) == RAW_EXPORT_PREFIX then
        payload = importString:sub(#RAW_EXPORT_PREFIX + 1)
    else
        return false, "Kein RexUI-Profilstring."
    end

    local data, errorMessage = DeserializeTable(payload)
    if data and data.addon == "RexUI" and data.partial == true and type(data.sections) == "table" then
        return self:ImportProfileSections(data)
    end
    if not data or data.addon ~= "RexUI" or type(data.profile) ~= "table" then
        return false, "Profil konnte nicht gelesen werden: " .. tostring(errorMessage or "")
    end

    -- Ein Import ohne neuen Namen ersetzt das aktuell aktive
    -- Profil. Ein angegebener Name legt weiterhin ein separates Profil an.
    if profileName == "" then
        profileName = self:GetCurrentProfile()
    end

    local incomingXP
    if type(data.profile.statusbars) == "table" and data.profile.statusbars.xpEnabled ~= nil then
        incomingXP = data.profile.statusbars.xpEnabled == true
    end

    RexUIDB.profiles[profileName] = SanitizeProfile(CopyTableDeep(data.profile))
    if incomingXP ~= nil then
        RexUIDB.profiles[profileName].statusbars = RexUIDB.profiles[profileName].statusbars or {}
        RexUIDB.profiles[profileName].statusbars.xpEnabled = incomingXP
    end
    RexUIDB.currentProfile = profileName
    RexUIDB.profileKeys[self:GetCharacterKey()] = profileName
    RexUIDB.profileKeyManual[self:GetCharacterKey()] = true
    self.currentProfile = profileName
    self.db.profile = RexUIDB.profiles[profileName]
    self.profile = self.db.profile

    local SB = self.StatusBars or (self.modules and self.modules.StatusBars)
    if SB and SB.SetXPEnabled and incomingXP ~= nil then
        SB:SetXPEnabled(incomingXP)
    end

    if self.ApplyProfileSettings then
        self:ApplyProfileSettings()
    end

    self:PrintMessage("Profil importiert: " .. profileName)
    return true, profileName
end

local profileStorageFrame = CreateFrame("Frame")
profileStorageFrame:RegisterEvent("PLAYER_LOGOUT")
profileStorageFrame:SetScript("OnEvent", function()
    RexUI:PackProfilesForStorage()
end)
