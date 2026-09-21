-- ============================================================
-- RexUI - Unlock.lua
-- ============================================================

local ADDON_NAME, ns = ...

local RexUI =
    ns.RexUI

if not RexUI then
    return
end

-- ------------------------------------------------------------
-- STATE
-- ------------------------------------------------------------

RexUI.Unlocked = false
RexUI.PendingUnlockState = nil

local unlockCombatFrame = CreateFrame("Frame")
unlockCombatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
unlockCombatFrame:SetScript("OnEvent", function()
    local pendingState = RexUI.PendingUnlockState
    if pendingState == nil then return end
    RexUI.PendingUnlockState = nil
    if pendingState then
        RexUI:Unlock()
    else
        RexUI:Lock()
    end
end)

-- ------------------------------------------------------------
-- UNLOCK
-- ------------------------------------------------------------

function RexUI:Unlock()
    if InCombatLockdown and InCombatLockdown() then
        self.PendingUnlockState = true
        self:PrintMessage("Positionen werden nach dem Kampf entsperrt.")
        return
    end

    self.PendingUnlockState = nil
    self.Unlocked = true

    -- ElvUI-artige Logik: Entsperren veraendert das Configfenster nicht.
    -- Nur die Mover werden aktiviert. Die Config bleibt normal bedienbar.

    -- ActionBars
    if self.ActionBars
    and self.ActionBars.ShowMovers then

        self.ActionBars:ShowMovers()
    end

    if self.MicroMenu
    and self.MicroMenu.ShowMover then

        self.MicroMenu:ShowMover()
    end

    if self.Minimap
    and self.Minimap.ShowMover then

        self.Minimap:ShowMover()
    end

    if self.Bags
    and self.Bags.ShowMover then

        self.Bags:ShowMover()
    end

    if self.UnitFrames
    and self.UnitFrames.ShowMovers then

        self.UnitFrames:ShowMovers()
    end

    if self.GroupFrames
    and self.GroupFrames.ShowMover then

        self.GroupFrames:ShowMover()
    end

    if self.QuestTracker
    and self.QuestTracker.ShowMover then

        self.QuestTracker:ShowMover()
    end

    if self.StatusBars
    and self.StatusBars.ShowMover then

        self.StatusBars:ShowMover()
    end

    if self.RaidUtility
    and self.RaidUtility.ShowMover then

        self.RaidUtility:ShowMover()
    end

    if self.MythicTimer
    and self.MythicTimer.ShowMover then

        self.MythicTimer:ShowMover()
    end

    if self.ConfigUI and self.ConfigUI.UpdateHeaderUnlockButton then
        self.ConfigUI:UpdateHeaderUnlockButton()
    end

    self:PrintMessage("Positionen entsperrt.")
end

-- ------------------------------------------------------------
-- LOCK
-- ------------------------------------------------------------

function RexUI:Lock()
    if InCombatLockdown and InCombatLockdown() then
        self.PendingUnlockState = false
        self:PrintMessage("Positionen werden nach dem Kampf gesperrt.")
        return
    end

    self.PendingUnlockState = nil
    self.Unlocked = false

    -- Das Sperren beendet nur den Mover-Modus.
    -- Groesse, Position und Inhalt der Config bleiben unangetastet.

    -- ActionBars
    if self.ActionBars
    and self.ActionBars.HideMovers then

        self.ActionBars:HideMovers()
    end

    if self.MicroMenu
    and self.MicroMenu.HideMover then

        self.MicroMenu:HideMover()
    end

    if self.Minimap
    and self.Minimap.HideMover then

        self.Minimap:HideMover()
    end

    if self.Bags
    and self.Bags.HideMover then

        self.Bags:HideMover()
    end

    if self.UnitFrames
    and self.UnitFrames.HideMovers then

        self.UnitFrames:HideMovers()
    end

    if self.GroupFrames
    and self.GroupFrames.HideMover then

        self.GroupFrames:HideMover()
    end

    if self.QuestTracker
    and self.QuestTracker.HideMover then

        self.QuestTracker:HideMover()
    end

    if self.StatusBars
    and self.StatusBars.HideMover then

        self.StatusBars:HideMover()
    end

    if self.RaidUtility
    and self.RaidUtility.HideMover then

        self.RaidUtility:HideMover()
    end

    if self.MythicTimer
    and self.MythicTimer.HideMover then

        self.MythicTimer:HideMover()
    end

    if self.ConfigUI and self.ConfigUI.UpdateHeaderUnlockButton then
        self.ConfigUI:UpdateHeaderUnlockButton()
    end

    self:PrintMessage("Positionen gesperrt.")
end

-- ------------------------------------------------------------
-- TOGGLE
-- ------------------------------------------------------------

function RexUI:ToggleUnlock()

    if self.Unlocked then
        self:Lock()
    else
        self:Unlock()
    end
end
