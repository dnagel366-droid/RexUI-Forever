-- ============================================================
-- RexUI_ActionBars\Mouseover.lua
-- Fade in/out fuer Bars mit mouseover = true
-- ============================================================

local AddOnName, ns = ...
local RexUI = _G["RexUI"] or ns.RexUI

local AB = RexUI and RexUI.ActionBars
if not AB then return end

AB.Mouseover = AB.Mouseover or {}
local MO = AB.Mouseover

local FADE_IN  = 0.12
local FADE_OUT = 0.32
local HOLD     = 0.35
local activeFades = {}
local fadeFrame = CreateFrame("Frame")
fadeFrame:Hide()

local function IsMouseOverBar(bar)
    if not bar then return false end
    if bar.IsMouseOver and bar:IsMouseOver() then return true end

    if bar._tracker and bar._tracker.IsMouseOver and bar._tracker:IsMouseOver() then
        return true
    end

    for _, btn in ipairs(bar.buttons or {}) do
        if btn.IsMouseOver and btn:IsMouseOver() then
            return true
        end
    end

    return false
end

local function GetTargetAlpha(bar)
    local barKey = bar and bar.rexBarKey
    local cfg = barKey and AB.GetConfig and AB:GetConfig(barKey)
    if cfg and cfg.hidden == true then return 0 end
    return (cfg and cfg.alpha) or 1
end

-- ============================================================
-- FADE
-- ============================================================

local function fade(bar, toAlpha, duration)

    if duration <= 0 then
        activeFades[bar] = nil
        bar:SetAlpha(toAlpha)
        if not next(activeFades) then
            fadeFrame:Hide()
        end
        return
    end

    activeFades[bar] = {
        from = bar:GetAlpha(),
        to = toAlpha,
        duration = duration,
        elapsed = 0,
    }
    fadeFrame:Show()
end

fadeFrame:SetScript("OnUpdate", function(_, elapsed)
    for bar, state in pairs(activeFades) do
        if not bar._mouseoverApplied then
            activeFades[bar] = nil
        else
            state.elapsed = state.elapsed + elapsed
            local pct = math.min(state.elapsed / state.duration, 1)
            bar:SetAlpha(state.from + (state.to - state.from) * pct)
            if pct >= 1 then
                activeFades[bar] = nil
            end
        end
    end

    if not next(activeFades) then
        fadeFrame:Hide()
    end
end)

-- ============================================================
-- APPLY
-- ============================================================

function MO:Apply(bar)

    if not bar or bar._mouseoverApplied then return end
    bar._mouseoverApplied = true

    bar:SetAlpha(0)

    local function onEnter()

    if not bar._mouseoverApplied then
        return
    end

    bar._fadeToken = (bar._fadeToken or 0) + 1

    fade(bar, GetTargetAlpha(bar), FADE_IN)
end

   local function onLeave()

    if not bar._mouseoverApplied then
        return
    end

    bar._fadeToken = (bar._fadeToken or 0) + 1
    local fadeToken = bar._fadeToken

    C_Timer.After(HOLD, function()

        if not bar._mouseoverApplied or fadeToken ~= bar._fadeToken then
            return
        end

        if not IsMouseOverBar(bar) then
            fade(bar, 0, FADE_OUT)
        end
    end)
end

    -- Tracker ueber der gesamten Bar
    if not bar._tracker then
        local t = CreateFrame("Frame", nil, bar)
        t:SetAllPoints(bar)
        t:SetFrameLevel(bar:GetFrameLevel() - 1)
        t:SetScript("OnEnter", onEnter)
        t:SetScript("OnLeave", onLeave)
        bar._tracker = t
    end

    for _, btn in ipairs(bar.buttons or {}) do
        if not btn._mouseoverHooked then
            btn._mouseoverHooked = true
            btn:HookScript("OnEnter", onEnter)
            btn:HookScript("OnLeave", function()
                bar._leaveCheckToken = (bar._leaveCheckToken or 0) + 1
                local token = bar._leaveCheckToken
                C_Timer.After(0.05, function()
                    if token ~= bar._leaveCheckToken then
                        return
                    end
                    if not IsMouseOverBar(bar) then
                        onLeave()
                    end
                end)
            end)
        end
    end
end

-- ============================================================
-- REMOVE
-- ============================================================

function MO:Remove(bar)

    if not bar then return end
    bar._mouseoverApplied = false

    activeFades[bar] = nil
    if not next(activeFades) then fadeFrame:Hide() end
    bar._fadeToken = (bar._fadeToken or 0) + 1
    if bar._tracker    then bar._tracker:Hide(); bar._tracker:SetParent(nil); bar._tracker = nil end

    bar:SetAlpha(GetTargetAlpha(bar))
end

-- ============================================================
-- COMBAT: Mouseover Bars im Kampf immer zeigen
-- ============================================================

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event)

    for barKey, bar in pairs(AB.Bars) do
        local cfg = AB.Config[barKey]
        if cfg and cfg.mouseover then
            if event == "PLAYER_REGEN_DISABLED" then
                activeFades[bar] = nil
                if not next(activeFades) then fadeFrame:Hide() end
                bar._fadeToken = (bar._fadeToken or 0) + 1
                bar:SetAlpha(GetTargetAlpha(bar))
            else
                bar._fadeToken = (bar._fadeToken or 0) + 1
                local fadeToken = bar._fadeToken
                C_Timer.After(2, function()
                    if bar._mouseoverApplied and fadeToken == bar._fadeToken and not IsMouseOverBar(bar) then
                        fade(bar, 0, FADE_OUT)
                    end
                end)
            end
        end
    end
end)
