-- ============================================================
-- RexUI_ActionBars\Config.lua
-- ============================================================

local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI

RexUI.ActionBars        = RexUI.ActionBars or {}
local AB                = RexUI.ActionBars
AB.Config               = AB.Config or {}
AB.ConfigCache          = AB.ConfigCache or {}
AB.ConfigCacheVersion   = AB.ConfigCacheVersion or 0

-- ============================================================
-- DEFAULT TEMPLATE
-- Wird von allen Bars geerbt - nur Abweichungen ueberschreiben
-- ============================================================

AB.Config.Defaults = {

    enabled      = true,
    slots        = 12,
    buttonSize   = 32,
    spacing      = 2,

    point        = "CENTER",
    relPoint     = "CENTER",
    x            = 0,
    y            = 0,

    scale        = 1.0,
    alpha        = 1.0,
    hidden       = false, -- invisible but remains active for keybind/CDM players

    iconCrop     = 0.055,
    iconInset    = 2,

    bgColor      = { 0.15, 0.15, 0.15, 0.50 },
    borderColor  = { 0, 0, 0, 1 },
    activeColor  = { 0.95,  0.95,  0.95, 1.0  },
    borderSize   = 1,
    hoverColor   = { 1.0,   1.0,   1.0,  0.22 },
    activeOverlayColor = { 0.0, 0.0, 0.0, 0.16 },

    showHotkey   = true,
    showCount    = true,
    hotkeyFontSize = 9,
    countFontSize  = 11,
    showCooldown = true,

    showCooldownSwipe   = true,
    showCooldownEdge    = true,
    showCooldownText    = true,
    cooldownSwipeAlpha  = 0.80,
    desaturateOnCooldown = false,

    showProcGlow        = true,
    showAssistedCombat  = true,
    showNewAction       = true,
    overlayInset        = -2,
}

-- ============================================================
-- GET CONFIG
-- Gibt eine Bar-Config zurueck, fehlende Keys aus Defaults
-- ============================================================

function AB:InvalidateConfigCache(key)
    if key then
        AB.ConfigCache[key] = nil
    else
        wipe(AB.ConfigCache)
    end
    AB.ConfigCacheVersion = (AB.ConfigCacheVersion or 0) + 1
end

function AB:GetConfig(key)
    key = key or "Defaults"

    local cached = AB.ConfigCache[key]
    if cached and cached.version == AB.ConfigCacheVersion then
        return cached.config
    end

    local cfg    = AB.Config[key] or {}
    local def    = AB.Config.Defaults
    local result = {}
    for k, v in pairs(def) do
        result[k] = (cfg[k] ~= nil) and cfg[k] or v
    end
    for k, v in pairs(cfg) do
        result[k] = v
    end
    -- Alias: Settings.lua nutzt "buttons", intern heisst es "slots"
    result.buttons = result.buttons or result.slots
    result.rows    = result.rows    or 1

    AB.ConfigCache[key] = {
        version = AB.ConfigCacheVersion,
        config = result,
    }
    return result
end

-- ============================================================
-- BAR 1-8
-- Slot-Mapping:
--   Bar1  ->   1-12  (paged)
--   Bar2  ->  61-72  (MultiBarBottomLeft)
--   Bar3  ->  49-60  (MultiBarBottomRight)
--   Bar4  ->  25-36  (MultiBarRight)
--   Bar5  ->  37-48  (MultiBarLeft)
--   Bar6  -> 145-156 (MultiBar5)
--   Bar7  -> 157-168 (MultiBar6)
--   Bar8  -> 169-180 (MultiBar7)
-- ============================================================

AB.Config.Bar1 = { enabled = true,  y = -260 }
AB.Config.Bar2 = { enabled = true,  y = -220 }
AB.Config.Bar3 = { enabled = true, y = -180 }
AB.Config.Bar4 = { enabled = true, y = -140 }
AB.Config.Bar5 = { enabled = true, y = -100 }
AB.Config.Bar6 = { enabled = true, y =  -60 }
AB.Config.Bar7 = { enabled = true, y =  -20 }
AB.Config.Bar8 = { enabled = true, y =   20 }


-- ============================================================
-- BAR REGISTRY
-- Reihenfolge und Slot-Offsets fuer Core.lua
-- ============================================================

AB.BarRegistry = {
    { key = "Bar1", offset =   0 },
    { key = "Bar2", offset =  60 },
    { key = "Bar3", offset =  48 },
    { key = "Bar4", offset =  24 },
    { key = "Bar5", offset =  36 },
    { key = "Bar6", offset = 144 },
    { key = "Bar7", offset = 156 },
    { key = "Bar8", offset = 168 },
}
