-- ============================================================
-- RexUI – Database.lua
-- SavedVariables und Datenbank
-- ============================================================

local ADDON_NAME, ns = ...

local RexUI =
    ns.RexUI

if not RexUI then
    return
end
-- ------------------------------------------------------------
-- DEFAULTS
-- ------------------------------------------------------------

local DB_DEFAULTS = {

    profile = {

        -- ----------------------------------------------------
        -- THEME
        -- ----------------------------------------------------

        theme = "MidnightPurple",
		
		firstLaunch = true,

        -- ----------------------------------------------------
        -- GENERAL
        -- ----------------------------------------------------

        general = {

            enabled = true,

            hideBlizzardActionBars = true,
        },

        -- RexUI Nameplates 2.0 schema. This is intentionally versioned so
        -- profile migration can distinguish it from the removed legacy
        -- nameplate implementation.
        nameplates = {
            schemaVersion = 2,
            enabled = true,
            general = {
                enemyWidth = 150,
                enemyHealthHeight = 20,
                friendlyWidth = 108,
                friendlyHealthHeight = 10,
                showFriendly = false,
                friendlyNameOnly = false,
                friendlyPlayersNameOnly = false,
                friendlyNPCsNameOnly = false,
                friendlyClassColors = true,
                friendlyClickThrough = false,
                friendlyYOffset = 0,
                stacking = true,
                stackSpacing = 1.0,
                hitboxWidth = 150,
                hitboxHeight = 44,
                friendlyHitboxWidth = 108,
                friendlyHitboxHeight = 44,
            },
            appearance = {
                texture = "Interface\\AddOns\\RexUI\\media\\statusbars\\bar_background.tga",
                showName = true,
                showHealthText = true,
                showLevel = true,
                healthFormat = "BOTH",
                backgroundAlpha = 0.50,
                backgroundColor = { r = 0.03, g = 0.03, b = 0.03, a = 0.50 },
                borderSize = 1,
                borderStyle = "PIXEL",
            },
            target = {
                arrows = true,
                arrowStyle = "SINGLE",
                arrowScale = 1.0,
                arrowSpacing = 6,
                arrowAlpha = 1.0,
                arrowClassColor = false,
                arrowColor = { r = 1, g = 1, b = 1, a = 1 },
                scale = 1.20,
                nonTargetAlpha = 0.42,
                focusKeepAlpha = true,
                focusScale = 1.0,
                focusBorder = true,
                mouseoverHighlight = true,
                executeLine = true,
                executeEnabled = false,
                executeThreshold = 0.35,
                executeGlowAlpha = 1.0,
                executePulse = false,
                showAbsorb = true,
                targetOverlayEnabled = false,
                targetOverlayTexture = "striped-v2",
                targetOverlayColor = { r = 1, g = 1, b = 1, a = 1 },
                targetOverlayAlpha = 1.0,
                targetOverlayEmptyMultiplier = 0.30,
                focusOverlayEnabled = false,
                focusOverlayTexture = "striped-v2",
                focusOverlayColor = { r = 1, g = 1, b = 1, a = 1 },
                focusOverlayAlpha = 1.0,
                focusOverlayEmptyMultiplier = 0.30,
            },
            threat = {
                enabled = true,
                healthBarColor = true,
                borderColor = true,
                nameColor = false,
                overrideBaseColors = true,
                unitTypeColoring = true,
                unitTypesDontOverrideThreat = false,
                casterColor = true,
                eliteColor = false,
                trivialColor = false,
                useSoloColor = false,
                checkNoTankAggro = false,
                aggroBlink = false,
                aggroBorder = true,
            },
            castbars = {
                enabled = true,
                texture = "Interface\\AddOns\\RexUI\\media\\statusbars\\bar_serenity.tga",
                height = 11,
                showName = true,
                showTime = true,
                showIcon = true,
                showShield = true,
                iconSide = "LEFT",
                iconSize = 15,
                showTargetName = true,
                targetNameSize = 9,
                showKickState = false,
                showImportantGlow = true,
                showSpark = true,
                focusScale = 1.0,
            },
            colors = {
                enemy = { r = 0.7450981, g = 0.1882353, b = 0.1137255, a = 1 },
                neutral = { r = 1, g = 0.7960784, b = 0.2078431, a = 1 },
                friendly = { r = 0.0235294, g = 0.8235294, b = 0.0235294, a = 1 },
                tapped = { r = 0.4666667, g = 0.4666667, b = 0.4666667, a = 1 },
                important = { r = 0.5764706, g = 0.4392157, b = 0.8588236, a = 1 },
                boss = { r = 1, g = 0, b = 1, a = 1 },
                rare = { r = 0.15, g = 0.72, b = 0.78, a = 1 },
                elite = { r = 0.7450981, g = 0.1882353, b = 0.1137255, a = 1 },
                caster = { r = 0, g = 0.8196, b = 1, a = 1 },
                trivial = { r = 0.46, g = 0.46, b = 0.50, a = 1 },
                tankAggro = { r = 0.7450981, g = 0.1882353, b = 0.1137255, a = 1 },
                tankLosing = { r = 1, g = 0.9137256, b = 0.2274510, a = 1 },
                tankNoAggro = { r = 0.8666667, g = 0.4352942, b = 0, a = 1 },
                offTank = { r = 0.5019608, g = 0.5019608, b = 1, a = 1 },
                tankTakeover = { r = 0.5411765, g = 0.4313725, b = 0, a = 1 },
                dpsAggro = { r = 0.8666667, g = 0.4352942, b = 0, a = 1 },
                threatHigh = { r = 1, g = 0.8, b = 0, a = 1 },
                threatLow = { r = 0.7450981, g = 0.1882353, b = 0.1137255, a = 1 },
                threatNone = { r = 0.7450981, g = 0.1882353, b = 0.1137255, a = 1 },
                solo = { r = 0.5019608, g = 0.5019608, b = 1, a = 1 },
                nonTankTarget = { r = 0.5019608, g = 0.5019608, b = 1, a = 1 },
                outOfCombat = { r = 0.7450981, g = 0.1882353, b = 0.1137255, a = 1 },
                target = { r = 1, g = 1, b = 1, a = 1 },
                focus = { r = 0.35, g = 0.75, b = 1, a = 1 },
                mouseover = { r = 1, g = 0.9, b = 0.45, a = 1 },
                castNormal = { r = 1, g = 1, b = 0, a = 1 },
                castChannel = { r = 1, g = 1, b = 0.0352941, a = 1 },
                castEmpowered = { r = 0, g = 1, b = 0, a = 1 },
                castInterruptible = { r = 1, g = 1, b = 0, a = 1 },
                castKickReady = { r = 0.16, g = 0.82, b = 0.34, a = 1 },
                castKickCooldown = { r = 1, g = 0.48, b = 0.08, a = 1 },
                castProtected = { r = 0.8, g = 0.3019608, b = 0.3019608, a = 1 },
                castImportant = { r = 0.8, g = 0.3019608, b = 0.3019608, a = 1 },
                castInterrupted = { r = 0.8, g = 0.3019608, b = 0.3019608, a = 1 },
                castSucceeded = { r = 0.2784314, g = 0.7529412, b = 0.2352941, a = 1 },
                castBackground = { r = 0.2117647, g = 0.2117647, b = 0.2117647, a = 1 },
            },
            auras = {
                buffs = true,
                debuffs = true,
                ownDebuffs = true,
                important = true,
                crowdControl = true,
                maxDebuffs = 5,
                maxBuffs = 4,
                maxCC = 2,
                dispelBorders = true,
                size = 20,
                position = "TOP",
                debuffPosition = "TOP",
                debuffX = 0,
                debuffY = 20,
                debuffSize = 20,
                debuffSpacing = 2,
                buffPosition = "LEFT",
                buffX = -7,
                buffY = 0,
                buffSize = 20,
                buffSpacing = 2,
                ccPosition = "RIGHT",
                ccX = 34,
                ccY = 0,
                ccSize = 20,
                ccSpacing = 2,
            },
            indicators = {
                raidMarker = true,
                quest = true,
                boss = true,
                elite = true,
                rare = true,
                aggro = true,
            },
            filters = {
                include = {},
                exclude = {},
            },
        },

        -- ----------------------------------------------------
        -- COMFORT
        -- ----------------------------------------------------

        comfort = {

            autoRepair = true,

            sellJunk = true,

            quickLoot = false,

            skipCinematics = false,

            hideTalkingHead = false,

            autoInsertKeystone = true,

            actionbarLock = true,

            realmOrigin = {
                enabled = true,
                region = "AUTO",
                showApplicants = true,
                showLeaders = true,
                showTooltips = true,
                showNames = true,
                onlyDifferent = false,
            },
        },

        cooldownManager = {
            enabled = true,
            backdrop = true,
        },

        -- ----------------------------------------------------
        -- POSITIONS
        -- ----------------------------------------------------

        positions = {},

        -- ----------------------------------------------------
        -- ACTIONBARS
        -- ----------------------------------------------------

        actionbars = {

            enabled = true,
            elvButtonStyleVersion = 0,
        },

        -- ----------------------------------------------------
        -- STATUSBARS
        -- ----------------------------------------------------

        statusbars = {

            enabled = true,
            xpEnabled = false,
            showReputationAtMax = true,
            width = 420,
            height = 10,
            point = "CENTER",
            relPoint = "CENTER",
            x = 0,
            y = -305,
            scale = 1,
            alpha = 1,
            showTextOnMouseover = true,
        },

        -- ----------------------------------------------------
        -- MINIMAP
        -- ----------------------------------------------------

        minimap = {

            enabled = true,
            size = 160,
            borderSize = 1,
            showClock = true,
            showLocation = true,
            showDataBar = true,
            dataTextLayoutVersion = 4,
            dataTextLeft = "GUILD",
            dataTextCenter = "SYSTEM",
            dataTextRight = "BNET",
            dataBarBackdrop = true,
            dataBarBorder = true,
            dataBarPanelTransparency = false,
            dataBarBackgroundColor = { r = 0.10, g = 0.10, b = 0.10, a = 1 },
            dataBarBackgroundAlpha = 1.00,
            dataBarBorderColor = { r = 0.15, g = 0.15, b = 0.15, a = 1 },
            dataBarBorderAlpha = 0.95,
            dataBarTextColor = { r = 0.92, g = 0.92, b = 0.92, a = 1 },
            dataBarTextAlpha = 1.00,
            bnetToastPoint = "TOPRIGHT",
            bnetToastX = -4,
            bnetToastY = -274,
            scrollZoom = true,
            hideTracking = false,
            hideCalendar = false,
            hideMail = false,
        },

        -- ----------------------------------------------------
        -- BLIZZARD SKIN
        -- ----------------------------------------------------

        blizzardSkin = {

            enabled = true,

            gameMenu = true,

            tooltips = true,

            staticPopups = true,

            dropdownMenus = true,

            chat = {

                enabled = true,

                bgAlpha = 0.70,

                ebAlpha = 0.50,

                tabAlpha = 0.70,

                sidebarAlpha = 0.70,

                fontSize = 12,

                lineSpacing = 1,

                timestampFormat = "%H:%M ",

                idleFade = true,

                idleFadeDelay = 15,

                idleFadeStrength = 40,

                showfriends = true,

                showcopy = true,

                showportals = true,

                showvoice = true,

                showsettings = true,

                showscroll = true,

                showkeys = true,

                guildSound = true,
                guildSoundSelection = "alert",

                whisperSound = true,
                whisperSoundSelection = "whisper",

            },

        },

        -- ----------------------------------------------------
        -- MICRO MENU
        -- ----------------------------------------------------

        microMenu = {

            enabled = true,

            hideBlizzard = true,

            buttonSize = 18,

            spacing = 1,

            scale = 1.5,

            alpha = 1,

            mouseover = false,

            compactVersion = 3,

            dungeonPoint = "BOTTOMRIGHT",

            dungeonRelPoint = "BOTTOMRIGHT",

            dungeonX = -18,

            dungeonY = 138,
        },

        -- ----------------------------------------------------
        -- RAID UTILITY
        -- ----------------------------------------------------

        raidUtility = {

            enabled = true,

            point = "TOP",

            relPoint = "TOP",

            x = -400,

            y = 1,

            showMarkers = true,

            pullTimer = 10,
        },

        -- ----------------------------------------------------
        -- DAMAGE METER
        -- ----------------------------------------------------

        damageMeter = {
            enabled = true,
            skinPreset = "detailsDark",
            backgroundColor = { r = 0.0941, g = 0.0941, b = 0.0941, a = 1 },
            backgroundAlpha = 0.42,
            headerColor = { r = 0.025, g = 0.025, b = 0.030, a = 1 },
            headerAlpha = 0.96,
            barColor = { r = 0.18, g = 0.48, b = 0.58, a = 1 },
            barAlpha = 0.88,
            rowBackgroundAlpha = 0.32,
            rowHoverAlpha = 0.16,
            rowHeight = 21,
            rowSpacing = 1,
            rowFontSize = 11,
            rowFont = "Interface\\AddOns\\RexUI\\media\\fonts\\Arial Narrow.ttf",
            barTexture = "Interface\\AddOns\\RexUI\\media\\statusbars\\bar_background.tga",
            useClassColors = true,
            windowCount = 1,
            windows = {
                {
                    enabled = true,
                    width = 280,
                    height = 210,
                    display = 0,
                    session = "current",
                    locked = true,
                    lockControlsVersion = 2,
                    point = "RIGHT",
                    relPoint = "RIGHT",
                    x = -25,
                    y = -40,
                },
            },
        },

        -- ----------------------------------------------------
        -- GUILD KEYSTONE OVERVIEW
        -- ----------------------------------------------------

        guildKeys = {
            enabled = true,
            staleAfter = 1800,
            cacheLifetime = 691200,
        },

        -- ----------------------------------------------------
        -- MYTHIC+ TIMER
        -- ----------------------------------------------------

        mythicTimer = {
            enabled = true,
            point = "TOP",
            relPoint = "TOP",
            x = 0,
            y = -75,
            width = 330,
            scale = 1,
            updateRate = 0.2,
            showDungeonName = true,
            showKeyLevel = true,
            showAffixes = true,
            showBosses = true,
            showForces = true,
            showForcesCount = true,
            showDeaths = true,
            showDeathPenalty = true,
            showChestTimers = true,
            showComparison = true,
            compareLowerKey = true,
            hideBlizzardTracker = true,
            bestTimes = {},
            history = {},
        },

        -- ----------------------------------------------------
        -- UNITFRAMES
        -- ----------------------------------------------------

        unitframes = {

            enabled = true,

            hideBlizzard = true,

            player = {
                enabled = true,
                width = 220,
                healthHeight = 42,
                powerHeight = 7,
                scale = 1,
                point = "CENTER",
                relPoint = "CENTER",
                x = -280,
                y = -185,
                healthFormat = "PERCENT",
                healthBackgroundColor = { r = 17/255, g = 17/255, b = 17/255, a = 0.5 },
                showCastbar = false,
                castbarPlacement = "INSIDE",
                showPortrait = false,
                showLevel = false,
                showRaidMarker = false,
                showDebuffs = false,
                debuffSize = 20,
                debuffRows = 1,
            },

            pet = {
                enabled = true,
                width = 180,
                healthHeight = 28,
                powerHeight = 5,
                scale = 1,
                point = "CENTER",
                relPoint = "CENTER",
                x = -280,
                y = -235,
                healthBackgroundColor = { r = 17/255, g = 17/255, b = 17/255, a = 0.5 },
                showCastbar = false,
                castbarPlacement = "INSIDE",
                showPortrait = false,
                showLevel = false,
                showRaidMarker = false,
                showDebuffs = false,
                debuffSize = 18,
                debuffRows = 1,
            },

            target = {
                enabled = true,
                width = 220,
                healthHeight = 42,
                powerHeight = 7,
                scale = 1,
                point = "CENTER",
                relPoint = "CENTER",
                x = 280,
                y = -185,
                healthFormat = "PERCENT",
                healthBackgroundColor = { r = 17/255, g = 17/255, b = 17/255, a = 0.5 },
                showCastbar = true,
                castbarPlacement = "INSIDE",
                showPortrait = true,
                showLevel = true,
                showRaidMarker = true,
                showDebuffs = true,
                debuffSize = 22,
                debuffRows = 2,
                debuffX = 0,
                debuffY = -4,
                showBuffs = true,
                buffSize = 20,
                buffRows = 1,
                buffX = 0,
                buffY = -4,
            },

            focus = {
                enabled = true,
                width = 180,
                healthHeight = 34,
                powerHeight = 6,
                scale = 1,
                point = "CENTER",
                relPoint = "CENTER",
                x = 330,
                y = -80,
                healthFormat = "PERCENT",
                healthBackgroundColor = { r = 17/255, g = 17/255, b = 17/255, a = 0.5 },
                showCastbar = true,
                castbarPlacement = "INSIDE",
                showPortrait = true,
                showLevel = true,
                showRaidMarker = true,
                showDebuffs = true,
                debuffSize = 20,
                debuffRows = 2,
                debuffX = 0,
                debuffY = -4,
                showBuffs = true,
                buffSize = 18,
                buffRows = 1,
                buffX = 0,
                buffY = -4,
            },

            boss = {
                enabled = true,
                width = 190,
                healthHeight = 34,
                powerHeight = 6,
                scale = 1,
                point = "RIGHT",
                relPoint = "RIGHT",
                x = -220,
                y = 155,
                spacing = 12,
                count = 5,
                healthFormat = "PERCENT",
                healthBackgroundColor = { r = 17/255, g = 17/255, b = 17/255, a = 0.5 },
                showCastbar = true,
                castbarPlacement = "INSIDE",
                showPortrait = false,
                showLevel = true,
                showRaidMarker = true,
                showDebuffs = false,
                debuffSize = 20,
                debuffRows = 1,
            },
        },

        -- ----------------------------------------------------
        -- BAGS
        -- ----------------------------------------------------

        bags = {

            bagPoint = "CENTER",

            bagRelPoint = "CENTER",

            bagX = 0,

            bagY = 0,

            scale = 1,

            elvWindowLayoutVersion = 0,

            barButtonSize = 28,

            barSpacing = 2,

            showReagentSlotColor = true,

            reagentSlotColor = { r = 0.18, g = 0.75, b = 0.50, a = 1 },

        },
    },
}

-- ------------------------------------------------------------
-- COPY DEFAULTS
-- ------------------------------------------------------------

local function CopyDefaults(src, dst)

    if type(src) ~= "table" then
        return dst
    end

    if type(dst) ~= "table" then
        dst = {}
    end

    for key, value in pairs(src) do

        if type(value) == "table" then

            dst[key] =
                CopyDefaults(
                    value,
                    dst[key]
                )

        elseif dst[key] == nil then

            dst[key] = value
        end
    end

    return dst
end

-- ------------------------------------------------------------
-- INIT DATABASE
-- ------------------------------------------------------------

function RexUI:InitDatabase()

    -- --------------------------------------------------------
    -- SAVEDVARIABLE
    -- --------------------------------------------------------

    if self.RecoverPersistedDatabase then
        self:RecoverPersistedDatabase()
    end

    RexUIDB =
        RexUIDB
        or {}

    -- Never merge the new schema into a table owned by the removed legacy
    -- nameplate system. Dropping that table before CopyDefaults guarantees
    -- the Step-5 profile is created solely from the new implementation.
    local savedProfile = type(RexUIDB.profile) == "table" and RexUIDB.profile or nil
    local savedNameplates = savedProfile and savedProfile.nameplates
    if type(savedNameplates) == "table" and savedNameplates.schemaVersion ~= 2 then
        savedProfile.nameplates = nil
    end

    -- Das ResourceBars-Modul wurde entfernt; alte Einstellungen nicht weiter mitschleppen.
    if savedProfile then
        savedProfile.resourceBars = nil
    end

    -- --------------------------------------------------------
    -- COPY DEFAULTS
    -- --------------------------------------------------------

    CopyDefaults(
        DB_DEFAULTS,
        RexUIDB
    )

    -- --------------------------------------------------------
    -- GLOBAL DB
    -- --------------------------------------------------------

    self.db = RexUIDB

    -- --------------------------------------------------------
    -- PROFILE SHORTCUT
    -- --------------------------------------------------------

    self.profile =
        self.db.profile

    if self.StartPersistence then
        self:StartPersistence()
    end

end

-- ------------------------------------------------------------
-- GET PROFILE
-- ------------------------------------------------------------

function RexUI:GetProfile()

    return self.db.profile
end
-- ------------------------------------------------------------
-- GLOBAL DEFAULTS
-- ------------------------------------------------------------

RexUI.defaults =
    DB_DEFAULTS
