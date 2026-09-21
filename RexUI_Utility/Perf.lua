-- ============================================================
-- RexUI_Utility/Perf.lua
-- Optionaler Performance-Zähler (/rexperf). Standard: vollständig inaktiv.
-- ============================================================

local ADDON_NAME, ns = ...
local RexUI = ns.RexUI or _G.RexUI
if not RexUI then return end

local Perf = RexUI:CreateModule("Perf")
RexUI.Perf = Perf

Perf.measuring = false
Perf.startedAt = 0
Perf.stats = {}

local GetTime = GetTime
local collectgarbage = collectgarbage

local function EnsureBucket(name)
    local bucket = Perf.stats[name]
    if not bucket then
        bucket = {
            events = 0,
            fullUpdates = 0,
            partialUpdates = 0,
            auraScans = 0,
            auraEntries = 0,
            onUpdates = 0,
            framesCreated = 0,
            poolActive = 0,
            poolIdle = 0,
            cpuMs = 0,
        }
        Perf.stats[name] = bucket
    end
    return bucket
end

function Perf:IsEnabled()
    return self.measuring == true
end

function Perf:Reset()
    if wipe then
        wipe(self.stats)
    else
        for key in pairs(self.stats) do
            self.stats[key] = nil
        end
    end
    self.startedAt = GetTime and GetTime() or 0
end

function Perf:StartMeasuring()
    if self.measuring then return end
    self.measuring = true
    self:Reset()
    if RexUI.PrintMessage then
        RexUI:PrintMessage("Perf: an – /rexperf report")
    end
end

function Perf:StopMeasuring()
    if not self.measuring then return end
    self.measuring = false
    if RexUI.PrintMessage then
        RexUI:PrintMessage("Perf: aus")
    end
end

function Perf:Toggle()
    if self.measuring then
        self:StopMeasuring()
    else
        self:StartMeasuring()
    end
end

function Perf:Count(moduleName, key, amount)
    if not self.measuring then return end
    local bucket = EnsureBucket(moduleName or "Core")
    local field = key or "events"
    bucket[field] = (bucket[field] or 0) + (amount or 1)
end

function Perf:Time(moduleName, fn)
    if not self.measuring then
        return fn()
    end

    local start = (debugprofilestop and debugprofilestop()) or 0
    local ok, a, b, c, d, e, f = pcall(fn)
    local elapsed = ((debugprofilestop and debugprofilestop()) or 0) - start
    self:Count(moduleName, "cpuMs", elapsed)
    if not ok then
        error(a, 0)
    end
    return a, b, c, d, e, f
end

-- Leichtgewichtige Zeitmessung ohne Closure-Allokation:
--   local t = Perf:Start()  ...  Perf:Stop("Modul", t)
-- Ohne aktive Messung kostet das Paar nur zwei Funktionsaufrufe.
function Perf:Start()
    if not self.measuring or not debugprofilestop then return nil end
    return debugprofilestop()
end

function Perf:Stop(moduleName, startTime, key)
    if not startTime or not self.measuring then return end
    local bucket = EnsureBucket(moduleName or "Core")
    bucket.cpuMs = (bucket.cpuMs or 0) + (debugprofilestop() - startTime)
    if key then
        bucket[key] = (bucket[key] or 0) + 1
    end
end

-- Module können Momentaufnahmen liefern (z. B. Pool-Belegung), die erst im
-- Report abgefragt werden und damit im Normalbetrieb nichts kosten.
Perf.gauges = {}

function Perf:RegisterGauge(moduleName, fn)
    if type(fn) == "function" then
        self.gauges[moduleName] = fn
    end
end

function Perf:CollectGauges()
    for moduleName, fn in pairs(self.gauges) do
        local ok, active, idle, frames = pcall(fn)
        if ok then
            local bucket = EnsureBucket(moduleName)
            if active then bucket.poolActive = active end
            if idle then bucket.poolIdle = idle end
            if frames then bucket.framesCreated = frames end
        end
    end
end

function Perf:SnapshotMemory()
    if collectgarbage then
        return collectgarbage("count")
    end
    return 0
end

function Perf:Report()
    if not RexUI.PrintMessage then return end

    if not self.measuring then
        RexUI:PrintMessage("Perf ist aus. /rexperf on")
        return
    end

    self:CollectGauges()
    local elapsed = math.max(0.001, (GetTime and GetTime() or 0) - (self.startedAt or 0))
    local mem = self:SnapshotMemory()
    RexUI:PrintMessage(string.format("Perf-Report (%.1fs, Speicher %.1f KiB)", elapsed, mem))

    local names = {}
    for name in pairs(self.stats) do
        names[#names + 1] = name
    end
    table.sort(names)

    if #names == 0 then
        RexUI:PrintMessage("Noch keine Messwerte.")
        return
    end

    for _, name in ipairs(names) do
        local s = self.stats[name]
        local eps = (s.events or 0) / elapsed
        RexUI:PrintMessage(string.format(
            "%s | Events/s %.1f | Full %d Partial %d | Auren %d/%d | OnUpdate %d | Frames %d Pool %d/%d | CPU %.1f ms",
            name,
            eps,
            s.fullUpdates or 0,
            s.partialUpdates or 0,
            s.auraScans or 0,
            s.auraEntries or 0,
            s.onUpdates or 0,
            s.framesCreated or 0,
            s.poolActive or 0,
            s.poolIdle or 0,
            s.cpuMs or 0
        ))
    end
end

function Perf:Initialize()
    -- bewusst leer: kein Laufzeitaufwand ohne /rexperf on
end

function Perf:Enable()
    -- Lebenszyklus: Modul ist aktiv, Messung bleibt aus
    self.enabled = true
end

function Perf:Disable()
    self:StopMeasuring()
    self.enabled = false
end

function Perf:Shutdown()
    self:StopMeasuring()
    if wipe then
        wipe(self.stats)
    end
end

SLASH_REXPERF1 = "/rexperf"
SlashCmdList["REXPERF"] = function(input)
    input = string.lower(tostring(input or ""):match("^%s*(.-)%s*$") or "")

    if input == "on" or input == "an" or input == "enable" then
        Perf:StartMeasuring()
        return
    end
    if input == "off" or input == "aus" or input == "disable" then
        Perf:StopMeasuring()
        return
    end
    if input == "reset" or input == "clear" then
        Perf:Reset()
        if RexUI.PrintMessage then
            RexUI:PrintMessage("Perf: Zähler zurückgesetzt")
        end
        return
    end
    if input == "report" or input == "status" or input == "" then
        if input == "" and not Perf:IsEnabled() then
            Perf:Toggle()
            return
        end
        Perf:Report()
        return
    end
    if input == "toggle" then
        Perf:Toggle()
        return
    end

    if RexUI.PrintMessage then
        RexUI:PrintMessage("/rexperf on|off|toggle|reset|report")
    end
end
