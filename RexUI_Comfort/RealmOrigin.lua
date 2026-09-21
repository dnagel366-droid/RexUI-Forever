-- ============================================================
-- RexUI_Comfort - RealmOrigin.lua
-- Eigenstaendige Realm-Herkunft im Gruppenbrowser
-- ============================================================

local ADDON_NAME, ns = ...

local RexUI = ns.RexUI
if not RexUI or not RexUI.Comfort then return end

local Comfort = RexUI.Comfort
local RealmOrigin = CreateFrame("Frame")

RexUI.RealmOrigin = RealmOrigin

-- Eigene, kompakte RexUI-Zuordnung. Nicht aufgefuehrte EU-Realms
-- gelten als englisch/international, US-Realms als nordamerikanisch.
local EU_REALMS = {}
local AMERICAS_REALMS = {}

local function NormalizeRealm(realm)
    if type(realm) ~= "string" then return nil end
    return realm:lower():gsub("[%s%-']", "")
end

local function AddRealms(target, code, realms)
    for realm in realms:gmatch("[^,]+") do
        target[NormalizeRealm(realm)] = code
    end
end

AddRealms(EU_REALMS, "DE", [[
Aegwynn,Aman'Thul,Anetheron,Antonidas,Area 52,Arthas,Arygos,Azshara,
Baelgun,Blackhand,Blackmoore,Blackrock,Blutkessel,Dalvengyr,Das Konsortium,
Das Syndikat,Der Mithrilorden,Der Rat von Dalaran,Die Aldor,Die Arguswacht,
Die ewige Wacht,Die Nachtwache,Die Silberne Hand,Die Todeskrallen,Durotan,
Echsenkessel,Eredar,Festung der Stuerme,Forscherliga,Garrosh,Gilneas,
Gorgonnash,Gul'dan,Kargath,Khaz'goroth,Krag'jin,Kult der Verdammten,Lothar,
Madmortem,Mal'Ganis,Malorne,Malygos,Mannoroth,Mug'thol,Nefarian,Nazjatar,
Nozdormu,Onyxia,Perenolde,Proudmoore,Rexxar,Sen'jin,Shattrath,Taerar,
Tanzwut,Teldrassil,Thrall,Tirion,Todeswache,Un'Goro,Vek'lor,Wrathbringer,
Zirkel des Cenarius,Zuluhed
]])

AddRealms(EU_REALMS, "FR", [[
Archimonde,Arak-arahm,Chants eternels,Cho'gall,Confrerie du Thorium,
Conseil des Ombres,Dalaran,Drek'Thar,Eitrigg,Elune,Garona,Hyjal,Illidan,
Kael'thas,Kirin Tor,Krasus,La Croisade ecarlate,Les Clairvoyants,
Les Sentinelles,Marecage de Zangar,Medivh,Ner'zhul,Rashgarroth,Sargeras,
Sinstralis,Suramar,Temple noir,Throk'Feroth,Uldaman,Varimathras,Vol'jin,Ysondre
]])

AddRealms(EU_REALMS, "ES", [[
C'Thun,Colinas Pardas,Dun Modr,Exodar,Los Errantes,Minahonda,Sanguino,
Shen'dralar,Tyrande,Uldum,Zul'jin
]])

AddRealms(EU_REALMS, "IT", [[Nemesis,Pozzo dell'Eternita]])
AddRealms(EU_REALMS, "PT", [[Aggra]])

-- Schreibweisen mit diakritischen Zeichen, wie sie der Client liefert.
AddRealms(EU_REALMS, "DE", [[Festung der Stürme]])
AddRealms(EU_REALMS, "FR", [[
Chants éternels,Confrérie du Thorium,La Croisade écarlate,Marécage de Zangar
]])
AddRealms(EU_REALMS, "IT", [[Pozzo dell'Eternità]])

AddRealms(EU_REALMS, "RU", [[
Борейская тундра,Вечная Песня,Галакронд,Голдринн,Гордунни,Гром,
Дракономор,Король-лич,Пиратская бухта,Подземье,Разувий,Ревущий фьорд,
Свежеватель Душ,Седогрив,Страж Смерти,Термоштепсель,Ткач Смерти,
Черный Шрам,Ясеневый лес
]])

AddRealms(AMERICAS_REALMS, "BR", [[Azralon,Gallywix,Goldrinn,Nemesis,Tol Barad]])
AddRealms(AMERICAS_REALMS, "LA", [[Drakkari,Quel'Thalas,Ragnaros]])
AddRealms(AMERICAS_REALMS, "OC", [[
Aman'Thul,Barthilas,Caelestrasz,Dath'Remar,Dreadmaul,Frostmourne,Gundrak,
Jubei'Thos,Khaz'goroth,Nagrand,Saurfang
]])

local NAMES_DE = {
    DE = "Deutsch", EN = "Englisch / International", FR = "Französisch",
    ES = "Spanisch", IT = "Italienisch", PT = "Portugiesisch",
    RU = "Russisch", US = "Nordamerika", BR = "Brasilien",
    LA = "Lateinamerika", OC = "Ozeanien",
}

local NAMES_EN = {
    DE = "German", EN = "English / International", FR = "French",
    ES = "Spanish", IT = "Italian", PT = "Portuguese", RU = "Russian",
    US = "North America", BR = "Brazil", LA = "Latin America", OC = "Oceania",
}

local trackedMarkers = setmetatable({}, { __mode = "k" })
local hooks = {}

local FLAG_PATH = "Interface\\AddOns\\RexUI\\media\\realmflags\\"
local FLAG_FILES = {
    DE = "de", EN = "gb", FR = "fr", ES = "es", IT = "it", PT = "pt",
    RU = "ru", US = "us", BR = "br", LA = "mx", OC = "au",
}

local function GetFlagMarkup(code)
    local file = FLAG_FILES[code]
    return file and ("|T" .. FLAG_PATH .. file .. ":9:15|t") or nil
end

local function GetSettings()
    local profile = Comfort:GetProfile()
    return profile and profile.realmOrigin
end

local function IsAccessible(value)
    if value == nil then return false end
    if issecretvalue and issecretvalue(value) then return false end
    if canaccessvalue and not canaccessvalue(value) then return false end
    return true
end

local function GetRegion()
    local settings = GetSettings()
    local configured = settings and settings.region or "AUTO"
    if configured == "EU" or configured == "US" then return configured end

    local region = GetCurrentRegion and GetCurrentRegion()
    if region == 3 then return "EU" end
    if region == 1 then return "US" end
end

local function GetRealmCode(realm)
    local normalized = NormalizeRealm(realm)
    if not normalized then return nil end

    local region = GetRegion()
    if region == "EU" then
        return EU_REALMS[normalized] or "EN"
    elseif region == "US" then
        return AMERICAS_REALMS[normalized] or "US"
    end
end

local function SplitPlayerName(fullName)
    if not IsAccessible(fullName) or type(fullName) ~= "string" then return nil, nil end

    local name, realm = fullName:match("^([^%-]+)%-(.+)$")
    if not name then name = fullName end
    if not realm or realm == "" then realm = GetRealmName and GetRealmName() end
    return name, realm
end

local function GetRealmLabel(realm)
    local code = GetRealmCode(realm)
    local names = RexUI.isGerman and NAMES_DE or NAMES_EN
    return code, code and (names[code] or code)
end

local function ShouldShowRealm(realm)
    local settings = GetSettings()
    if not settings or settings.enabled == false or not realm then return false end

    if settings.onlyDifferent then
        return GetRealmCode(realm) ~= GetRealmCode(GetRealmName and GetRealmName())
    end
    return true
end

local function SetRowMarker(row, anchor, realm, xOffset, yOffset)
    if not row then return end

    if not row.RexUIRealmOrigin then
        row.RexUIRealmOrigin = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        trackedMarkers[row] = row.RexUIRealmOrigin
    end

    local flag = row.RexUIRealmOrigin
    flag:ClearAllPoints()

    if ShouldShowRealm(realm) then
        local code = GetRealmCode(realm)
        local markup = GetFlagMarkup(code)
        flag:SetPoint("LEFT", anchor or row, "RIGHT", xOffset or 0, yOffset or 0)
        flag:SetText(markup or "")
        flag:SetShown(markup ~= nil)
    else
        flag:SetText("")
        flag:Hide()
    end
end

local function AddTooltipFlagLine(tooltip, realm, includeName)
    local code, name = GetRealmLabel(realm)
    local markup = code and GetFlagMarkup(code)
    if not markup then return end

    if includeName then
        tooltip:AddLine(markup .. " |cffffffff-|r |cffffffff" .. name .. "|r")
    else
        tooltip:AddLine(markup)
    end
end

local function PrepareTooltip(tooltip)
    if tooltip.RexUIRealmOriginClearHook then return end

    tooltip:HookScript("OnTooltipCleared", function(self)
        self.RexUIRealmOriginResultID = nil
        self.RexUIRealmOriginUnitGUID = nil
    end)
    tooltip.RexUIRealmOriginClearHook = true
end

local function UpdateApplicant(member, applicantID, memberIndex)
    local settings = GetSettings()
    if not settings or settings.enabled == false or settings.showApplicants == false then
        SetRowMarker(member, member and member.Name, nil, -10, 0)
        return
    end
    if not C_LFGList or not C_LFGList.GetApplicantMemberInfo then return end

    local fullName = C_LFGList.GetApplicantMemberInfo(applicantID, memberIndex)
    local _, realm = SplitPlayerName(fullName)
    SetRowMarker(member, member and member.Name, realm, -10, 0)
end

local function GetSearchRealm(resultID)
    if not C_LFGList or not C_LFGList.GetSearchResultInfo then return nil end

    -- Gleicher Ablauf wie im Referenz-Addon: leaderName direkt lesen,
    -- mit Ambiguate zerlegen und den Realm aus dem Vollnamen gewinnen.
    -- pcall verhindert lediglich, dass ein geschuetzter Midnight-Wert
    -- einen Lua-Fehler im restlichen RexUI ausloest.
    local ok, realm = pcall(function()
        local info = C_LFGList.GetSearchResultInfo(resultID)
        local leaderName = info and info.leaderName
        if leaderName == nil then return nil end

        local shortName = Ambiguate(leaderName, "short")
        local fullName = Ambiguate(leaderName, "mail")

        if shortName == fullName then
            return GetRealmName and GetRealmName()
        end

        return fullName:sub(shortName:len() + 2)
    end)

    if ok then return realm end
    return nil
end

local function UpdateSearchResult(button)
    local settings = GetSettings()
    if not settings or settings.enabled == false or settings.showLeaders == false then
        SetRowMarker(button, button and button.Name, nil, 5, 0)
        return
    end
    if not button or not button.resultID or not C_LFGList or not C_LFGList.GetSearchResultInfo then return end

    local realm = GetSearchRealm(button.resultID)
    local premadeFilterLoaded = C_AddOns
        and C_AddOns.IsAddOnLoaded
        and C_AddOns.IsAddOnLoaded("PremadeGroupsFilter")
    SetRowMarker(button, button.Name, realm, premadeFilterLoaded and -10 or 5, premadeFilterLoaded and 1.5 or 0)
end

local function AddSearchTooltip(tooltip, resultID)
    local settings = GetSettings()
    if not settings or settings.enabled == false or settings.showTooltips == false then return end
    if not tooltip or not C_LFGList or not C_LFGList.GetSearchResultInfo then return end

    PrepareTooltip(tooltip)
    if tooltip.RexUIRealmOriginResultID == resultID then return end

    local realm = GetSearchRealm(resultID)
    if realm and ShouldShowRealm(realm) then
        tooltip:AddLine(" ")
        AddTooltipFlagLine(tooltip, realm, settings.showNames ~= false)
        tooltip.RexUIRealmOriginResultID = resultID
        tooltip:Show()
    end
end

local function GetTooltipUnit(tooltip, data)
    local tooltipData = data
    if not IsAccessible(tooltipData) and tooltip.GetPrimaryTooltipData then
        tooltipData = tooltip:GetPrimaryTooltipData()
    end

    if IsAccessible(tooltipData) then
        local guid = tooltipData.guid
        if IsAccessible(guid) and UnitTokenFromGUID then
            local unit = UnitTokenFromGUID(guid)
            if IsAccessible(unit) and unit ~= "none" then
                return unit, guid
            end
        end
    end

    if tooltip.GetUnit then
        local _, unit = tooltip:GetUnit()
        if IsAccessible(unit) and unit ~= "none" then
            local guid = UnitGUID and UnitGUID(unit)
            return unit, IsAccessible(guid) and guid or unit
        end
    end
end

local function AddUnitTooltip(tooltip, data)
    local settings = GetSettings()
    if not settings or settings.enabled == false or settings.showTooltips == false then return end

    local unit, guid = GetTooltipUnit(tooltip, data)
    if not unit then return end

    PrepareTooltip(tooltip)
    if guid and tooltip.RexUIRealmOriginUnitGUID == guid then return end

    local name, realm
    if UnitFullName then
        name, realm = UnitFullName(unit)
    else
        name, realm = UnitName(unit)
    end
    if not IsAccessible(name) or (realm and not IsAccessible(realm)) then return end
    if not realm or realm == "" then realm = GetRealmName and GetRealmName() end

    if realm and ShouldShowRealm(realm) then
        AddTooltipFlagLine(tooltip, realm, settings.showNames ~= false)
        tooltip.RexUIRealmOriginUnitGUID = guid
        tooltip:Show()
    end
end

local function InstallHooks()
    if not hooks.applicants and type(_G.LFGListApplicationViewer_UpdateApplicantMember) == "function" then
        hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", UpdateApplicant)
        hooks.applicants = true
    end
    if not hooks.results and type(_G.LFGListSearchEntry_Update) == "function" then
        hooksecurefunc("LFGListSearchEntry_Update", UpdateSearchResult)
        hooks.results = true
    end
    if not hooks.searchTooltip and type(_G.LFGListUtil_SetSearchEntryTooltip) == "function" then
        hooksecurefunc("LFGListUtil_SetSearchEntryTooltip", AddSearchTooltip)
        hooks.searchTooltip = true
    end
    if not hooks.unitTooltip and TooltipDataProcessor and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
            if tooltip == GameTooltip then AddUnitTooltip(tooltip, data) end
        end)
        hooks.unitTooltip = true
    end
end

function RealmOrigin:Refresh()
    for _, flag in pairs(trackedMarkers) do
        flag:SetText("")
        flag:Hide()
    end
    InstallHooks()
end

RealmOrigin:RegisterEvent("PLAYER_LOGIN")
RealmOrigin:RegisterEvent("ADDON_LOADED")
RealmOrigin:SetScript("OnEvent", InstallHooks)

Comfort:RegisterModule("RealmOrigin", RealmOrigin)
