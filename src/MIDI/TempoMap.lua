local TempoMap = {}
TempoMap.__index = TempoMap

function TempoMap.new(midi)
    local self = setmetatable({division = midi.division, segments = {}, tempoEvents = {}}, TempoMap)
    if midi.division.type == "SMPTE" then return self end
    local tempos = {{tick = 0, us = 500000}}
    for _, e in ipairs(midi.events) do
        if e.type == "meta" and e.subtype == "tempo" and e.microsecondsPerQuarter and e.microsecondsPerQuarter > 0 then
            tempos[#tempos + 1] = {tick = e.tick, us = e.microsecondsPerQuarter}
        end
    end
    table.sort(tempos, function(a, b) return a.tick < b.tick end)
    local dedup = {}
    for _, t in ipairs(tempos) do
        if #dedup > 0 and dedup[#dedup].tick == t.tick then
            dedup[#dedup] = t
        else
            dedup[#dedup + 1] = t
        end
    end
    local seconds = 0
    for i, t in ipairs(dedup) do
        if i > 1 then
            local prev = dedup[i - 1]
            seconds += (t.tick - prev.tick) * prev.us / (midi.division.ppqn * 1000000)
        end
        self.segments[i] = {tick = t.tick, seconds = seconds, us = t.us, bpm = 60000000 / t.us}
        self.tempoEvents[i] = self.segments[i]
    end
    return self
end

function TempoMap:tickToSeconds(tick)
    if self.division.type == "SMPTE" then
        local rate = self.division.fps * self.division.ticksPerFrame
        return tick / rate
    end
    local segs = self.segments
    local lo, hi = 1, #segs
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if segs[mid].tick <= tick then lo = mid else hi = mid - 1 end
    end
    local s = segs[lo]
    return s.seconds + (tick - s.tick) * s.us / (self.division.ppqn * 1000000)
end

function TempoMap:bpmAtTick(tick)
    if self.division.type == "SMPTE" then return nil end
    local segs = self.segments
    local lo, hi = 1, #segs
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if segs[mid].tick <= tick then lo = mid else hi = mid - 1 end
    end
    return segs[lo].bpm
end

return TempoMap
