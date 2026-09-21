-- ============================================================
-- RexUI_CooldownManager – Blizzard-CDM Skin (P3 MVP)
-- ============================================================

local ADDON_NAME, ns = ...
local RexUI = ns.RexUI or _G.RexUI
if not RexUI then return end

local CDM = RexUI:CreateModule("CooldownManager")
RexUI.CooldownManager = CDM

local VIEWER_NAMES = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "BuffBarCooldownViewer",
}

function CDM:GetConfig()
    local profile = RexUI.GetProfile and RexUI:GetProfile() or {}
    profile.cooldownManager = type(profile.cooldownManager) == "table" and profile.cooldownManager or {
        enabled = true,
        backdrop = true,
    }
    return profile.cooldownManager
end

local function SkinFrame(frame)
    if not frame or frame.rexCDMSkinned then return end
    frame.rexCDMSkinned = true
    if frame.SetBackdrop then
        pcall(frame.SetBackdrop, frame, {
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        pcall(frame.SetBackdropColor, frame, 0.06, 0.06, 0.08, 0.75)
        pcall(frame.SetBackdropBorderColor, frame, 0, 0, 0, 1)
    else
        if not frame.rexBg then
            frame.rexBg = frame:CreateTexture(nil, "BACKGROUND")
            frame.rexBg:SetAllPoints()
            frame.rexBg:SetColorTexture(0.06, 0.06, 0.08, 0.75)
        end
        frame.rexBg:Show()
    end
end

-- Stellt den Blizzard-Zustand wieder her, wenn Skin oder Modul abgeschaltet werden.
local function UnskinFrame(frame)
    if not frame or not frame.rexCDMSkinned then return end
    frame.rexCDMSkinned = nil
    if frame.SetBackdrop then
        pcall(frame.SetBackdrop, frame, nil)
    end
    if frame.rexBg then
        frame.rexBg:Hide()
    end
end

function CDM:ForEachViewer(callback)
    for _, name in ipairs(VIEWER_NAMES) do
        local frame = _G[name]
        if frame then callback(frame) end
    end
end

function CDM:Apply()
    local cfg = self:GetConfig()
    if self.enabled == false or not cfg.enabled or not cfg.backdrop then
        self:ForEachViewer(UnskinFrame)
        return
    end
    self:ForEachViewer(SkinFrame)
end

function CDM:Initialize()
    self.events = CreateFrame("Frame")
    self:RegisterEvents(self.events, { "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED" })
    self.events:SetScript("OnEvent", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, function() CDM:Apply() end)
        else
            CDM:Apply()
        end
    end)
end

function CDM:Enable()
    if not self:GetConfig().enabled then
        self:Disable()
        return
    end
    self.enabled = true
    self:ResumeEvents()
    self:Apply()
end

function CDM:Disable()
    self.enabled = false
    self:SuspendEvents()
    self:ForEachViewer(UnskinFrame)
end

function CDM:ApplyProfile()
    if not self:GetConfig().enabled then
        if self.enabled ~= false then self:Disable() end
        return
    end
    if self.enabled ~= true then
        self:Enable()
        return
    end
    self:Apply()
end
