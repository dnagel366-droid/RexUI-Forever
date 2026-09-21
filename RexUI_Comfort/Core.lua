-- ============================================================
-- RexUI_Comfort – Core.lua
-- Komfortsystem
-- ============================================================

local ADDON_NAME, ns = ...

local RexUI =
    ns.RexUI

if not RexUI then
    return
end

RexUI.Comfort =
    RexUI.Comfort
    or {}

local Comfort =
    RexUI.Comfort
-- ------------------------------------------------------------
-- LOKALE VARIABLEN
-- ------------------------------------------------------------

Comfort.Modules = {}

-- ------------------------------------------------------------
-- MODUL REGISTRIERUNG
-- ------------------------------------------------------------

function Comfort:RegisterModule(name, module)

    if not name or not module then
        return
    end

    self.Modules[name] = module
end

-- ------------------------------------------------------------
-- PROFIL
-- ------------------------------------------------------------

function Comfort:GetProfile()

    if not RexUI.db then
        return nil
    end

    return RexUI.db.profile.comfort
end

-- ------------------------------------------------------------
-- INITIALISIERUNG
-- ------------------------------------------------------------

function Comfort:Init()

end

-- ------------------------------------------------------------
-- START
-- ------------------------------------------------------------

Comfort:Init()
