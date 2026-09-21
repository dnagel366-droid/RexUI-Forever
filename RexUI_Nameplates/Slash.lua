-- ============================================================
-- RexUI - Nameplates / Slash
-- Ausgelagert aus Core.lua; gemeinsamer Zustand liegt in Nameplates.Internal (NP).
-- ============================================================

local ADDON_NAME, ns = ...
local RexUI = ns.RexUI
if not RexUI or not RexUI.Nameplates then return end

local Nameplates = RexUI.Nameplates
local NP = Nameplates.Internal
local Perf = RexUI.Perf

local function NameplateChat(message)
    message = "|cff9ad9ff" .. RexUI:LocalizeText("RexUI-Namensplaketten") .. ":|r " .. RexUI:LocalizeText(tostring(message))
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    elseif print then
        print(message)
    end
end

local function ParseToggle(value)
    value = string.lower(tostring(value or ""))
    if value == "ein" or value == "on" or value == "1" or value == "true" then return true end
    if value == "aus" or value == "off" or value == "0" or value == "false" then return false end
    return nil
end

local AURA_COMMANDS = {
    buffs = "buffs", debuffs = "debuffs", own = "ownDebuffs",
    important = "important", cc = "crowdControl",
}
local INDICATOR_COMMANDS = {
    raid = "raidMarker", quest = "quest", boss = "boss",
    elite = "elite", rare = "rare", aggro = "aggro",
}

local function HandleNameplateSlash(message)
    local command, first, second = tostring(message or ""):match("^(%S*)%s*(%S*)%s*(%S*)")
    command = string.lower(command or "")
    first = string.lower(first or "")
    if AURA_COMMANDS[command] then
        local enabled = ParseToggle(first)
        if enabled == nil then
            NameplateChat("Benutzung: /rexnp " .. command .. " ein|aus")
            return
        end
        Nameplates:SetAuraEnabled(AURA_COMMANDS[command], enabled)
        NameplateChat(command .. " = " .. (enabled and "ein" or "aus"))
    elseif INDICATOR_COMMANDS[command] then
        local enabled = ParseToggle(first)
        if enabled == nil then
            NameplateChat("Benutzung: /rexnp " .. command .. " ein|aus")
            return
        end
        Nameplates:SetIndicatorEnabled(INDICATOR_COMMANDS[command], enabled)
        NameplateChat(command .. " = " .. (enabled and "ein" or "aus"))
    elseif command == "size" then
        local size = tonumber(first)
        local position = string.upper(second or "")
        if not Nameplates:SetAuraLayout(size, position) then
            NameplateChat("Benutzung: /rexnp size 12-40 top|bottom")
            return
        end
        NameplateChat("Auragröße " .. size .. ", Position " .. position)
    elseif command == "include" or command == "exclude" then
        local spellID = tonumber(first)
        if not Nameplates:SetAuraFilter(spellID, command, true) then
            NameplateChat("Benutzung: /rexnp " .. command .. " SPELLID")
            return
        end
        NameplateChat("Filter " .. command .. " für " .. spellID .. " gesetzt")
    elseif command == "clear" then
        local spellID = tonumber(first)
        if not spellID then
            NameplateChat("Benutzung: /rexnp clear SPELLID")
            return
        end
        Nameplates:SetAuraFilter(spellID, "include", false)
        NameplateChat("Filter für " .. spellID .. " entfernt")
    else
        NameplateChat("Befehle: buffs, debuffs, own, important, cc, raid, quest, boss, elite, rare, aggro, size, include, exclude, clear")
    end
end

if SlashCmdList then
    SLASH_REXUINAMEPLATES1 = "/rexnp"
    SlashCmdList.REXUINAMEPLATES = HandleNameplateSlash
end
