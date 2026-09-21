-- ============================================================
-- RexUI - Nameplates / BlizzardPlates
-- Ausgelagert aus Core.lua; gemeinsamer Zustand liegt in Nameplates.Internal (NP).
-- ============================================================

local ADDON_NAME, ns = ...
local RexUI = ns.RexUI
if not RexUI or not RexUI.Nameplates then return end

local Nameplates = RexUI.Nameplates
local NP = Nameplates.Internal
local Perf = RexUI.Perf

local function SuppressBlizzardVisuals(nativePlate)
    local unitFrame = nativePlate and nativePlate.UnitFrame
    if not unitFrame then
        return
    end

    local state = NP.nativeFrameState[unitFrame]
    if not state then
        state = {}
        NP.nativeFrameState[unitFrame] = state
    end

    if not state.active then
        state.originalAlpha = unitFrame:GetAlpha()
        state.active = true

        -- Blizzard's aura buttons are mouse-enabled children. Alpha alone
        -- would leave an invisible click/tooltip trap over the native plate.
        local auras = unitFrame.AurasFrame
        if auras then
            state.aurasParent = auras:GetParent()
            state.aurasMoved = pcall(auras.SetParent, auras, NP.hiddenBlizzardHolder)
        end

        -- Keep Blizzard's soft-target reticle live and outside the alpha-zero
        -- UnitFrame. The native nameplate remains the targeting owner.
        local softTarget = unitFrame.SoftTargetFrame
        if softTarget then
            state.softTargetParent = softTarget:GetParent()
            state.softTargetAlpha = softTarget:GetAlpha()
            state.softTargetMoved = pcall(softTarget.SetParent, softTarget, nativePlate)
            if state.softTargetMoved then
                softTarget:SetAlpha(1)
            end
        end
    end

    if not state.hooked and hooksecurefunc then
        local ok = pcall(hooksecurefunc, unitFrame, "SetAlpha", function(frame)
            local currentState = NP.nativeFrameState[frame]
            if currentState and currentState.active and not currentState.applying then
                currentState.applying = true
                frame:SetAlpha(0)
                currentState.applying = false
            end
        end)
        state.hooked = ok
    end

    state.applying = true
    unitFrame:SetAlpha(0)
    state.applying = false
end

local function RestoreBlizzardVisuals(nativePlate)
    local unitFrame = nativePlate and nativePlate.UnitFrame
    local state = unitFrame and NP.nativeFrameState[unitFrame]
    if not state or not state.active then
        return
    end

    local alpha = state.originalAlpha
    state.active = false
    state.originalAlpha = nil

    if state.aurasMoved and unitFrame.AurasFrame then
        unitFrame.AurasFrame:SetParent(state.aurasParent or unitFrame)
    end
    state.aurasParent = nil
    state.aurasMoved = nil

    if state.softTargetMoved and unitFrame.SoftTargetFrame then
        unitFrame.SoftTargetFrame:SetParent(state.softTargetParent or unitFrame)
        unitFrame.SoftTargetFrame:SetAlpha(state.softTargetAlpha or 1)
    end
    state.softTargetParent = nil
    state.softTargetAlpha = nil
    state.softTargetMoved = nil

    if type(alpha) == "nil" then
        alpha = 1
    end
    unitFrame:SetAlpha(alpha)
end


-- Für andere Nameplate-Dateien sichtbar machen
NP.RestoreBlizzardVisuals = RestoreBlizzardVisuals
NP.SuppressBlizzardVisuals = SuppressBlizzardVisuals
