local TempoMap = {}
TempoMap.__index = TempoMap

local function segmentIndexByTick(segs, tick)
    local lo, hi = 1, #segs
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if segs[mid].tick <= tick then lo = mid else hi = mid - 1 end
    end
    return lo
end

local function segmentIndexBySeconds(segs, seconds)
    local lo, hi = 1, #segs
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if segs[mid].seconds <= seconds then lo = mid else hi = mid - 1 end
    end
    return lo
end

function TempoMap.new(midi)
    local self = setmetatable({
        division = midi.division,
        segments = {},
        tempoEvents = {},
        sourceFormat = midi.format,
    }, TempoMap)

    if midi.division.type == "SMPTE" then return self end

    local tempos = {{tick = 0, us = 500000, order = -1}}
    for _, e in ipairs(midi.events) do
        if e.type == "meta" and e.subtype == "tempo" and e.microsecondsPerQuarter and e.microsecondsPerQuarter > 0 then
            tempos[#tempos + 1] = {tick = e.tick, us = e.microsecondsPerQuarter, order = e.sequence or 0}
        end
    end

    table.sort(tempos, function(a, b)
        if a.tick == b.tick then return (a.order or 0) < (b.order or 0) end
        return a.tick < b.tick
    end)

    local dedup = {}
    for _, t in ipairs(tempos) do
        if #dedup > 0 and dedup[#dedup].tick == t.tick then dedup[#dedup] = t
        else dedup[#dedup + 1] = t end
    end

    local seconds = 0
    for i, t in ipairs(dedup) do
        if i > 1 then
            local prev = dedup[i - 1]
            seconds += (t.tick - prev.tick) * prev.us / (midi.division.ppqn * 1000000)
        end
        local seg = {tick = t.tick, seconds = seconds, us = t.us, bpm = 60000000 / t.us}
        self.segments[i] = seg
        self.tempoEvents[i] = seg
    end
    return self
end

function TempoMap:tickToSeconds(tick)
    tick = math.max(0, tonumber(tick) or 0)
    if self.division.type == "SMPTE" then
        return tick / (self.division.fps * self.division.ticksPerFrame)
    end
    local s = self.segments[segmentIndexByTick(self.segments, tick)]
    return s.seconds + (tick - s.tick) * s.us / (self.division.ppqn * 1000000)
end

function TempoMap:secondsToTick(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    if self.division.type == "SMPTE" then
        return seconds * self.division.fps * self.division.ticksPerFrame
    end
    local s = self.segments[segmentIndexBySeconds(self.segments, seconds)]
    return s.tick + (seconds - s.seconds) * self.division.ppqn * 1000000 / s.us
end

function TempoMap:bpmAtTick(tick)
    if self.division.type == "SMPTE" then return nil end
    return self.segments[segmentIndexByTick(self.segments, math.max(0, tick or 0))].bpm
end

function TempoMap:bpmAtSeconds(seconds)
    if self.division.type == "SMPTE" then return nil end
    return self.segments[segmentIndexBySeconds(self.segments, math.max(0, seconds or 0))].bpm
end

return TempoMap
