local Analyzer = {}

local function activeKey(e)
    return string.format("%d:%d", e.channel or 0, e.note or -1)
end

local function sustainIntervals(pedalEvents, maxTime)
    local opened, intervals = {}, {}
    for _, e in ipairs(pedalEvents) do
        local k = tostring(e.channel or 0)
        intervals[k] = intervals[k] or {}
        if e.down and not opened[k] then
            opened[k] = e.time
        elseif not e.down and opened[k] then
            intervals[k][#intervals[k] + 1] = {opened[k], e.time}
            opened[k] = nil
        end
    end
    for k, t in pairs(opened) do
        intervals[k] = intervals[k] or {}
        intervals[k][#intervals[k] + 1] = {t, maxTime}
    end
    return intervals
end

local function median(values)
    if #values == 0 then return 0 end
    table.sort(values)
    local m = math.floor((#values + 1) / 2)
    if #values % 2 == 1 then return values[m] end
    return (values[m] + values[m + 1]) / 2
end

function Analyzer.analyze(midi, tempoMap)
    local notes, active, trackInfo = {}, {}, {}
    local maxTime, minNote, maxNote = 0, 127, 0
    local pedalEvents, timeSignatures, keySignatures = {}, {}, {}
    local programs = {}
    local channelInfo = {}

    for _, track in ipairs(midi.tracks) do
        trackInfo[track.index] = {
            index = track.index,
            name = "Track " .. track.index,
            instrument = nil,
            noteCount = 0,
            channels = {},
        }
    end

    for _, e in ipairs(midi.events) do
        e.time = tempoMap:tickToSeconds(e.tick)
        maxTime = math.max(maxTime, e.time)

        if e.type == "meta" then
            if e.subtype == "trackName" and trackInfo[e.track] then trackInfo[e.track].name = e.text end
            if e.subtype == "instrumentName" and trackInfo[e.track] then trackInfo[e.track].instrument = e.text end
            if e.subtype == "timeSignature" then timeSignatures[#timeSignatures + 1] = e end
            if e.subtype == "keySignature" then keySignatures[#keySignatures + 1] = e end

        elseif e.type == "programChange" then
            programs[e.channel] = e.program

        elseif e.type == "controlChange" and e.controller == 64 then
            pedalEvents[#pedalEvents + 1] = {
                time = e.time, tick = e.tick, track = e.track, channel = e.channel,
                down = e.value >= 64, value = e.value,
            }

        elseif e.type == "noteOn" then
            local k = activeKey(e)
            active[k] = active[k] or {}
            active[k][#active[k] + 1] = {
                event = e,
                program = programs[e.channel],
            }
            minNote, maxNote = math.min(minNote, e.note), math.max(maxNote, e.note)
            if trackInfo[e.track] then trackInfo[e.track].channels[e.channel] = true end
            channelInfo[e.channel] = channelInfo[e.channel] or {channel = e.channel, noteCount = 0, pitchMin = 127, pitchMax = 0}
            local ci = channelInfo[e.channel]
            ci.noteCount += 1
            ci.pitchMin, ci.pitchMax = math.min(ci.pitchMin, e.note), math.max(ci.pitchMax, e.note)

        elseif e.type == "noteOff" then
            local q = active[activeKey(e)]
            if q and #q > 0 then
                local record = table.remove(q, 1)
                local on = record.event
                local n = {
                    note = on.note,
                    velocity = on.velocity or 64,
                    startTick = on.tick,
                    endTick = e.tick,
                    startTime = on.time,
                    endTime = math.max(e.time, on.time + .001),
                    track = on.track,
                    offTrack = e.track,
                    channel = on.channel,
                    program = record.program,
                }
                n.duration = n.endTime - n.startTime
                notes[#notes + 1] = n
                if trackInfo[n.track] then trackInfo[n.track].noteCount += 1 end
            end
        end
    end

    for _, q in pairs(active) do
        for _, record in ipairs(q) do
            local on = record.event
            local et = math.max(maxTime, on.time + .08)
            notes[#notes + 1] = {
                note = on.note, velocity = on.velocity or 64,
                startTick = on.tick, endTick = on.tick,
                startTime = on.time, endTime = et, duration = et - on.time,
                track = on.track, channel = on.channel, program = record.program,
                dangling = true,
            }
        end
    end

    table.sort(notes, function(a, b)
        if a.startTime == b.startTime then
            if a.channel == b.channel then return a.note < b.note end
            return (a.channel or 0) < (b.channel or 0)
        end
        return a.startTime < b.startTime
    end)

    local intervals = sustainIntervals(pedalEvents, maxTime)
    for _, n in ipairs(notes) do
        local k = tostring(n.channel or 0)
        for _, iv in ipairs(intervals[k] or {}) do
            if n.endTime >= iv[1] and n.endTime < iv[2] then
                n.keyReleaseTime = n.endTime
                n.endTime = iv[2]
                n.duration = n.endTime - n.startTime
                n.sustained = true
                break
            end
        end
        maxTime = math.max(maxTime, n.endTime)
    end

    local endpoints = {}
    local durations = {}
    for _, n in ipairs(notes) do
        endpoints[#endpoints + 1] = {t = n.startTime, d = 1}
        endpoints[#endpoints + 1] = {t = n.endTime, d = -1}
        durations[#durations + 1] = n.duration
    end
    table.sort(endpoints, function(a, b)
        if a.t == b.t then return a.d < b.d end
        return a.t < b.t
    end)

    local poly, peak = 0, 0
    for _, p in ipairs(endpoints) do
        poly += p.d
        peak = math.max(peak, poly)
    end

    local bpmMin, bpmMax
    for _, s in ipairs(tempoMap.tempoEvents or {}) do
        bpmMin = bpmMin and math.min(bpmMin, s.bpm) or s.bpm
        bpmMax = bpmMax and math.max(bpmMax, s.bpm) or s.bpm
    end

    local dangling = 0
    for _, n in ipairs(notes) do if n.dangling then dangling += 1 end end

    return {
        notes = notes,
        duration = maxTime,
        noteCount = #notes,
        pitchMin = #notes > 0 and minNote or nil,
        pitchMax = #notes > 0 and maxNote or nil,
        peakPolyphony = peak,
        medianNoteDuration = median(durations),
        notesPerSecond = maxTime > 0 and #notes / maxTime or 0,
        tracks = trackInfo,
        channels = channelInfo,
        pedalEvents = pedalEvents,
        timeSignatures = timeSignatures,
        keySignatures = keySignatures,
        bpmMin = bpmMin,
        bpmMax = bpmMax,
        tempoChanges = #(tempoMap.tempoEvents or {}),
        division = midi.division,
        parserWarnings = midi.warnings or {},
        danglingNotes = dangling,
        smfFormat = midi.format,
    }
end

return Analyzer
