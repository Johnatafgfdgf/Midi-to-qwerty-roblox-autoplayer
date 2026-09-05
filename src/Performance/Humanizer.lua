local Humanizer = {}

local function fract(x) return x - math.floor(x) end
local function hash(seed, x)
    return fract(math.sin((x + seed * 0.00017) * 12.9898 + seed * 0.013) * 43758.5453) * 2 - 1
end
local function smoothstep(x) return x * x * (3 - 2 * x) end
local function noise(seed, t, scale)
    local x = t / scale
    local i, f = math.floor(x), x - math.floor(x)
    local a, b = hash(seed, i), hash(seed, i + 1)
    return a + (b - a) * smoothstep(f)
end
local function copyNote(n)
    local c = {}
    for k, v in pairs(n) do c[k] = v end
    if n.parts then local p = {}; for k, v in pairs(n.parts) do p[k] = v end; c.parts = p end
    return c
end

local function bpmAdaptive(maxMs, bpm)
    bpm = bpm or 120
    return maxMs * math.clamp(120 / bpm, 0.45, 1.35)
end

function Humanizer.generate(notes, settings, context)
    settings = settings or {}
    context = context or {}
    local strength = settings.enabled == false and 0 or math.clamp(settings.strength or 0, 0, 1)
    local seed = context.seed or settings.fixedSeed or 12345
    local out = {}
    if strength <= 0 then
        for i, n in ipairs(notes) do out[i] = copyNote(n) end
        return out, {seed = seed, averageTimingMs = 0, maxTimingMs = 0}
    end

    local baseMax = bpmAdaptive(settings.timingMs or 9, context.bpm or 120) * strength
    local durationVar = (settings.durationVariation or 0.018) * strength
    local handFactor = settings.handIndependence or 0.35
    local phraseFactor = settings.phraseExpression or 0.35
    local sumAbs, peak = 0, 0

    for i, n in ipairs(notes) do
        local densityScale = 1
        local prev, nextN = notes[i - 1], notes[i + 1]
        if prev and nextN then
            local span = math.max(nextN.startTime - prev.startTime, 0.03)
            local localRate = 2 / span
            densityScale = math.clamp(10 / math.max(localRate, 1), 0.45, 1)
        end
        local maxMs = baseMax * densityScale
        local global = noise(seed + 11, n.startTime, 5.0) * 0.22
        local phrase = noise(seed + 29, n.startTime, 1.6) * 0.34 * phraseFactor
        local handSeed = n.parts and n.parts.hand == "Left" and 101 or 211
        local hand = noise(seed + handSeed, n.startTime, 1.05) * 0.28 * handFactor
        local noteMicro = hash(seed + 997, i) * 0.16
        local offsetMs = math.clamp((global + phrase + hand + noteMicro) * maxMs, -maxMs, maxMs)
        local c = copyNote(n)
        c.originalStartTime, c.originalEndTime = n.startTime, n.endTime
        c.startTime = math.max(0, n.startTime + offsetMs / 1000)
        local dFactor = 1 + hash(seed + 4001, i) * durationVar
        c.endTime = math.max(c.startTime + 0.008, n.startTime + n.duration * dFactor + offsetMs / 1000)
        c.duration = c.endTime - c.startTime
        c.humanOffsetMs = offsetMs
        out[i] = c
        sumAbs += math.abs(offsetMs)
        peak = math.max(peak, math.abs(offsetMs))
    end

    table.sort(out, function(a, b)
        if a.startTime == b.startTime then return a.note < b.note end
        return a.startTime < b.startTime
    end)

    local chordWindow = (context.chordWindowMs or 10) / 1000
    local spreadMax = (settings.chordSpreadMs or 8) * strength
    local group = {}
    local function flushChord()
        if #group < 2 or spreadMax <= 0 then table.clear(group); return end
        table.sort(group, function(a, b) return a.note < b.note end)
        local span = math.min(spreadMax, 2 + (#group - 1) * 1.25)
        for j, n in ipairs(group) do
            local rel = (#group == 1) and 0 or ((j - 1) / (#group - 1) - 0.5)
            local delta = rel * span / 1000
            n.startTime = math.max(0, n.startTime + delta)
            n.endTime = math.max(n.startTime + 0.008, n.endTime + delta)
        end
        table.clear(group)
    end
    local anchor
    for _, n in ipairs(out) do
        if not anchor or math.abs(n.originalStartTime - anchor) <= chordWindow then
            anchor = anchor or n.originalStartTime
            group[#group + 1] = n
        else
            flushChord(); anchor = n.originalStartTime; group[#group + 1] = n
        end
    end
    flushChord()

    table.sort(out, function(a, b) return a.startTime == b.startTime and a.note < b.note or a.startTime < b.startTime end)
    return out, {seed = seed, averageTimingMs = #out > 0 and sumAbs / #out or 0, maxTimingMs = peak}
end

function Humanizer.autoSeed()
    local t = os.clock() * 100000 + tick() * 1000
    return math.floor(t % 2147483646) + 1
end

return Humanizer
