-- ============================================================
-- RexUI - Nameplates / Constants
-- Feste Darstellungswerte. Konfigurierbare Standardwerte kommen ausschließlich
-- aus dem versionierten Datenbankschema (Database.lua → profile.nameplates).
-- ============================================================

local ADDON_NAME, ns = ...
local RexUI = ns.RexUI
if not RexUI or not RexUI.Nameplates then return end

local NP = RexUI.Nameplates.Internal

NP.PLATE_WIDTH = 150
NP.PLATE_HEIGHT = 44
NP.ENEMY_HEALTH_HEIGHT = 20
NP.FRIENDLY_WIDTH = 108
NP.FRIENDLY_HEALTH_HEIGHT = 10
NP.CLICK_INSET = -10000
NP.TARGET_SCALE = 1.20
NP.NON_TARGET_ALPHA = 0.42
NP.STATUS_TEXTURE = "Interface\\AddOns\\RexUI\\media\\statusbars\\bar_background.tga"
NP.NAMEPLATE_MEDIA = "Interface\\AddOns\\RexUI\\media\\nameplates\\"

-- The supplied stripe PNGs are 400 physical pixels wide and authored as
-- 2x UI art.  Their native WoW layout width is therefore 200 UI pixels.
-- Bars up to that width crop the common canvas instead of stretching it.
NP.STRIPE_NATIVE_WIDTH = 200
NP.OVERLAY_TEXTURES = {
    ["striped-v2"] = NP.NAMEPLATE_MEDIA .. "striped-v2.png",
    ["striped-wide-v2"] = NP.NAMEPLATE_MEDIA .. "striped-wide-v2.png",
    ["stripes-medium"] = NP.NAMEPLATE_MEDIA .. "stripes-medium.png",
    ["stripes-small-close"] = NP.NAMEPLATE_MEDIA .. "stripes-small-close.png",
    ["stripes-small-spread"] = NP.NAMEPLATE_MEDIA .. "stripes-small-spread.png",
    ["striped-tiny"] = NP.NAMEPLATE_MEDIA .. "striped-tiny.png",
}
NP.BORDER_TEXTURES = {
    SIMPLE = NP.NAMEPLATE_MEDIA .. "border-simple.png",
    COLORLESS = NP.NAMEPLATE_MEDIA .. "border-colorless.png",
    REFERENCE = NP.NAMEPLATE_MEDIA .. "border.png",
}

NP.BASE_BORDER = { 0.08, 0.08, 0.10, 1 }
NP.TARGET_COLOR = { 1.00, 1.00, 1.00, 1 }

NP.HEALTH_COLORS = {
    enemy =       { 0.745098, 0.188235, 0.113725 },
    neutral =     { 1.000000, 0.796078, 0.207843 },
    friendly =    { 0.023529, 0.823529, 0.023529 },
    tapped =      { 0.38, 0.38, 0.38 },
    -- Plater 652 unit-type defaults (implemented independently).
    important =   { 0.576471, 0.439216, 0.858824 }, -- Jundies miniboss
    boss =        { 1.000000, 0.000000, 1.000000 }, -- Jundies boss
    rare =        { 0.150000, 0.720000, 0.780000 },
    elite =       { 0.745098, 0.188235, 0.113725 }, -- Jundies elite fallback
    caster =      { 0.000000, 0.819600, 1.000000 },
    trivial =     { 0.46, 0.46, 0.50 },
    tankAggro =   { 0.745098, 0.188235, 0.113725 }, -- Jundies tank aggro
    tankLosing =  { 1.000000, 0.913726, 0.227451 }, -- Jundies tank pulling
    tankNoAggro = { 0.866667, 0.435294, 0.000000 }, -- Jundies tank no aggro
    offTank =     { 0.501961, 0.501961, 1.000000 }, -- Jundies another tank
    tankTakeover ={ 0.541176, 0.431373, 0.000000 },
    dpsAggro =    { 0.866667, 0.435294, 0.000000 }, -- Jundies DPS aggro
    threatHigh =  { 1.000000, 0.800000, 0.000000 }, -- Jundies DPS pulling
    threatLow =   { 0.745098, 0.188235, 0.113725 }, -- Jundies DPS no aggro
    threatNone =  { 0.745098, 0.188235, 0.113725 }, -- Jundies DPS no aggro
    solo =        { 0.501961, 0.501961, 1.000000 },
    nonTankTarget={ 0.501961, 0.501961, 1.000000 },
    outOfCombat = { 0.745098, 0.188235, 0.113725 },
}

NP.CAST_COLORS = {
    normal =        { 1.000000, 1.000000, 0.000000 },
    channel =       { 1.000000, 1.000000, 0.035294 },
    empowered =     { 0.019608, 0.980392, 0.019608 },
    kickReady =     { 0.16, 0.82, 0.34 },
    kickCooldown =  { 1.00, 0.48, 0.08 },
    uninterruptible={ 0.800000, 0.301961, 0.301961 },
    important =     { 0.788235, 0.309804, 0.309804 },
    interrupted =   { 0.800000, 0.301961, 0.301961 },
    succeeded =     { 0.278431, 0.752941, 0.235294 },
    background =    { 0.243137, 0.243137, 0.243137 },
}

NP.INTERRUPT_SPELLS = {
    6552, 96231, 147362, 187707, 1766, 15487, 47528, 57994,
    2139, 19647, 89766, 116705, 106839, 78675, 183752, 351338,
}

NP.AURA_ICON_SIZE = 20
NP.AURA_ICON_SPACING = 2
-- Kapazität der Aura-Reihen (Frames pro Plakette). Die tatsächlich gezeigte
-- Anzahl kommt aus profile.nameplates.auras.maxDebuffs/maxBuffs/maxCC.
NP.MAX_DEBUFFS = 8
NP.MAX_BUFFS = 6
NP.MAX_CC = 4

-- Rahmenfarben nach Bannbarkeit (nur außerhalb geheimer Aura-Daten verfügbar)
NP.DISPEL_COLORS = {
    Magic   = { 0.20, 0.60, 1.00 },
    Curse   = { 0.60, 0.00, 1.00 },
    Disease = { 0.60, 0.40, 0.00 },
    Poison  = { 0.00, 0.60, 0.00 },
    Enrage  = { 1.00, 0.55, 0.10 },
}
