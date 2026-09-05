local Analyzer = {}

local function keyOf(e) return string.format("%d:%d:%d", e.track or 0, e.channel or 0, e.note or -1) end

function Analyzer.analyze(midi, tempoMap)
    local notes, active, trackInfo = {}, {}, {}
    local maxTime, minNote, maxNote = 0, 127, 0
    local pedalEvents, timeSignatures = {}, {}
    local programs = {}

    for _, track in ipairs(midi.tracks) do
        trackInfo[track.index] = {index = track.index, name = "Track " .. track.index, instrument = nil, noteCount = 0}
    end

    for _, e in ipairs(midi.events) do
        e.time = tempoMap:tickToSeconds(e.tick)
        if e.time > maxTime then maxTime = e.time end
        if e.type == "meta" then
            if e.subtype == "trackName" and trackInfo[e.track] then trackInfo[e.track].name = e.text end
            if e.subtype == "instrumentName" and trackInfo[e.track] then trackInfo[e.track].instrument = e.text end
            if e.subtype == "timeSignature" then timeSignatures[#timeSignatures + 1] = e end
        elseif e.type == "programChange" then
            programs[string.format("%d:%d", e.track, e.channel)] = e.program
        elseif e.type == "controlChange" and e.controller == 64 then
            pedalEvents[#pedalEvents + 1] = {time = e.time, tick = e.tick, track = e.track, channel = e.channel, down = e.value >= 64, value = e.value}
        elseif e.type == "noteOn" then
            local k = keyOf(e)
            active[k] = active[k] or {}
            active[k][#active[k] + 1] = e
            minNote, maxNote = math.min(minNote, e.note), math.max(maxNote, e.note)
        elseif e.type == "noteOff" then
            local k = keyOf(e)
            local q = active[k]
            if q and #q > 0 then
                local on = table.remove(q, 1)
                local n = {
                    note = on.note, velocity = on.velocity or 64,
                    startTick = on.tick, endTick = e.tick,
                    startTime = on.time, endTime = math.max(e.time, on.time + 0.001),
                    duration = math.max(e.time - on.time, 0.001),
                    track = on.track, channel = on.channel,
                    program = programs[string.format("%d:%d", on.track, on.channel)],
                }
                notes[#notes + 1] = n
                if trackInfo[n.track] then trackInfo[n.track].noteCount += 1 end
            end
        end
    end

    for _, q in pairs(active) do
        for _, on in ipairs(q) do
            local endTime = math.max(maxTime, on.time + 0.08)
            notes[#notes + 1] = {
                note = on.note, velocity = on.velocity or 64,
                startTick = on.tick, endTick = on.tick,
                startTime = on.time, endTime = endTime, duration = endTime - on.time,
                track = on.track, channel = on.channel,
                program = programs[string.format("%d:%d", on.track, on.channel)], dangling = true,
            }
        end
    end

    table.sort(notes, function(a, b)
        if a.startTime == b.startTime then return a.note < b.note end
        return a.startTime < b.startTime
    end)

    local endpoints = {}
    for _, n in ipairs(notes) do
        endpoints[#endpoints + 1] = {t = n.startTime, d = 1}
        endpoints[#endpoints + 1] = {t = n.endTime, d = -1}
        maxTime = math.max(maxTime, n.endTime)
    end
    table.sort(endpoints, function(a, b) return a.t == b.t and a.d < b.d or a.t < b.t end)
    local poly, peak = 0, 0
    for _, p in ipairs(endpoints) do poly += p.d; peak = math.max(peak, poly) end

    local bpmMin, bpmMax = nil, nil
    for _, s in ipairs(tempoMap.tempoEvents or {}) do
        bpmMin = bpmMin and math.min(bpmMin, s.bpm) or s.bpm
        bpmMax = bpmMax and math.max(bpmMax, s.bpm) or s.bpm
    end

    return {
        notes = notes,
        duration = maxTime,
        noteCount = #notes,
        pitchMin = #notes > 0 and minNote or nil,
        pitchMax = #notes > 0 and maxNote or nil,
        peakPolyphony = peak,
        tracks = trackInfo,
        pedalEvents = pedalEvents,
        timeSignatures = timeSignatures,
        bpmMin = bpmMin, bpmMax = bpmMax,
        tempoChanges = #(tempoMap.tempoEvents or {}),
    }
end

return Analyzer
