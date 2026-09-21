-- ============================================================
-- RexUI - GraphicsOptimizer.lua
-- Optional FPS/clarity preset with reversible CVar backup.
-- ============================================================

local _, ns = ...
local RexUI = ns.RexUI or _G.RexUI
if not RexUI then return end

local Optimizer = {}
RexUI.GraphicsOptimizer = Optimizer

local RAID_GUIDE_VALUES = {
    { "RAIDsettingsEnabled", "1" },
    { "RAIDgraphicsShadowQuality", "1" },
    { "RAIDgraphicsLiquidDetail", "1" },
    { "RAIDgraphicsParticleDensity", "3" },
    { "RAIDgraphicsSSAO", "0" },
    { "RAIDgraphicsDepthEffects", "0" },
    { "RAIDgraphicsComputeEffects", "0" },
    { "RAIDgraphicsOutlineMode", "2" },
    { "RAIDgraphicsTextureResolution", "2" },
    { "RAIDgraphicsSpellDensity", "0" },
    { "RAIDgraphicsProjectedTextures", "1" },
    { "RAIDgraphicsViewDistance", "0" },
    { "RAIDgraphicsEnvironmentDetail", "0" },
    { "RAIDgraphicsGroundClutter", "0" },
    { "RAIDWaterDetail", "0" },
    { "RAIDweatherDensity", "0" },
}

local ADVANCED_GUIDE_VALUES = {
    { "RenderScale", "1" },
    { "gxVSync", "0" },
    { "tripleBuffering", "0" },
    { "textureFilteringMode", "5" },
    { "rtShadowQuality", "0" },
    { "VRSMode", "0" },
    { "useTargetFPS", "0" },
}

local function BuildValues(openWorldValues)
    local values = {}
    for _, entry in ipairs(openWorldValues) do values[#values + 1] = entry end
    for _, entry in ipairs(RAID_GUIDE_VALUES) do values[#values + 1] = entry end
    for _, entry in ipairs(ADVANCED_GUIDE_VALUES) do values[#values + 1] = entry end
    return values
end

local PRESETS = {
    raid = {
        label = "Optimal für Raid & M+",
        values = BuildValues({
            { "graphicsShadowQuality", "1" }, { "graphicsLiquidDetail", "0" },
            { "graphicsParticleDensity", "3" }, { "graphicsSSAO", "0" },
            { "graphicsDepthEffects", "0" }, { "graphicsComputeEffects", "0" },
            { "graphicsOutlineMode", "2" }, { "graphicsTextureResolution", "2" },
            { "graphicsSpellDensity", "0" }, { "graphicsProjectedTextures", "1" },
            { "graphicsViewDistance", "0" }, { "graphicsEnvironmentDetail", "0" },
            { "graphicsGroundClutter", "0" },
        }),
    },
    balanced = {
        label = "Ausgewogen",
        values = BuildValues({
            { "graphicsShadowQuality", "2" }, { "graphicsLiquidDetail", "1" },
            { "graphicsParticleDensity", "3" }, { "graphicsSSAO", "1" },
            { "graphicsDepthEffects", "1" }, { "graphicsComputeEffects", "1" },
            { "graphicsOutlineMode", "2" }, { "graphicsTextureResolution", "2" },
            { "graphicsSpellDensity", "1" }, { "graphicsProjectedTextures", "1" },
            { "graphicsViewDistance", "3" }, { "graphicsEnvironmentDetail", "3" },
            { "graphicsGroundClutter", "2" },
        }),
    },
    quality = {
        label = "Beste Grafik",
        values = BuildValues({
            { "graphicsShadowQuality", "4" }, { "graphicsLiquidDetail", "3" },
            { "graphicsParticleDensity", "5" }, { "graphicsSSAO", "3" },
            { "graphicsDepthEffects", "3" }, { "graphicsComputeEffects", "3" },
            { "graphicsOutlineMode", "2" }, { "graphicsTextureResolution", "3" },
            { "graphicsSpellDensity", "2" }, { "graphicsProjectedTextures", "1" },
            { "graphicsViewDistance", "7" }, { "graphicsEnvironmentDetail", "7" },
            { "graphicsGroundClutter", "7" },
        }),
    },
}

local function ReadCVar(name)
    if C_CVar and C_CVar.GetCVar then
        local ok, value = pcall(C_CVar.GetCVar, name)
        if ok then return value end
    end
    if GetCVar then
        local ok, value = pcall(GetCVar, name)
        if ok then return value end
    end
end

local function WriteCVar(name, value)
    if C_CVar and C_CVar.SetCVar then
        local ok = pcall(C_CVar.SetCVar, name, tostring(value))
        if ok then return true end
    end
    if SetCVar then
        return pcall(SetCVar, name, tostring(value))
    end
    return false
end

local function BackupStore(create)
    if not RexUIDB then
        if not create then return nil end
        RexUIDB = {}
    end
    if create then
        RexUIDB.graphicsOptimizerBackup = RexUIDB.graphicsOptimizerBackup or {}
    end
    return RexUIDB.graphicsOptimizerBackup
end

function Optimizer:HasBackup()
    return type(BackupStore(false)) == "table"
end

function Optimizer:ApplyPreset(presetID)
    local preset = PRESETS[presetID] or PRESETS.balanced
    local backup = BackupStore(true)

    -- Keep the first snapshot so repeated clicks never destroy the restore point.
    for _, entry in ipairs(preset.values) do
        local name = entry[1]
        if backup[name] == nil then backup[name] = ReadCVar(name) end
    end
    local changed = 0
    for _, entry in ipairs(preset.values) do
        if WriteCVar(entry[1], entry[2]) then changed = changed + 1 end
    end

    RexUIDB.graphicsOptimizerPreset = presetID
    RexUI:PrintMessage("Grafikprofil '" .. preset.label .. "' angewendet (" .. changed .. " Einstellungen).")
    return changed
end

function Optimizer:Apply()
    return self:ApplyPreset("balanced")
end

function Optimizer:Restore()
    local backup = BackupStore(false)
    if type(backup) ~= "table" then
        RexUI:PrintMessage("Keine gesicherten Grafikeinstellungen vorhanden.")
        return 0
    end

    local restored = 0
    -- Every preset uses the same CVar keys; balanced is the canonical restore list.
    for _, entry in ipairs(PRESETS.balanced.values) do
        local value = backup[entry[1]]
        if value ~= nil and WriteCVar(entry[1], value) then restored = restored + 1 end
    end
    -- Restore Contrast only for users upgrading from the earlier optimizer build.
    if backup.Contrast ~= nil and WriteCVar("Contrast", backup.Contrast) then
        restored = restored + 1
    end

    RexUIDB.graphicsOptimizerBackup = nil
    RexUIDB.graphicsOptimizerPreset = nil
    RexUI:PrintMessage("Grafikeinstellungen wiederhergestellt (" .. restored .. " Einstellungen).")
    return restored
end

function Optimizer:GetPreset(presetID)
    return PRESETS[presetID or "balanced"]
end

function Optimizer:GetActivePreset()
    return RexUIDB and RexUIDB.graphicsOptimizerPreset
end
