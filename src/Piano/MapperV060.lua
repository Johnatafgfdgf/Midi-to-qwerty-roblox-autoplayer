local Mapper = {}

local function clone(n)
    local c = {}
    for k,v in pairs(n) do c[k] = v end
    if n.parts then
        local p = {}
        for k,v in pairs(n.parts) do p[k] = v end
        c.parts = p
    end
    return c
end

local function adapt(note, profile, mode)
    if note >= profile.lowest and note <= profile.highest then return note, false end
    if mode == "Strict" then return nil, false end
    if mode == "Clamp" then return math.clamp(note, profile.lowest, profile.highest), true end
    local n = note
    while n < profile.lowest do n += 12 end
    while n > profile.highest do n -= 12 end
    if n >= profile.lowest and n <= profile.highest then return n, true end
    return nil, false
end

local function coverage(notes, profile, base, shift)
    if #notes == 0 then return 1 end
    local hit = 0
    for _,n in ipairs(notes) do
        local p = n.note + base + shift
        if p >= profile.lowest and p <= profile.highest then hit += 1 end
    end
    return hit / #notes
end

local function smartShift(notes, profile, base)
    local baseCoverage = coverage(notes, profile, base, 0)
    local best, bestCoverage = 0, baseCoverage
    for _,s in ipairs({-24,-12,12,24}) do
        local c = coverage(notes, profile, base, s)
        if c > bestCoverage + 1e-9 then best, bestCoverage = s, c end
    end
    if bestCoverage - baseCoverage < .08 then return 0, baseCoverage end
    return best, bestCoverage
end

local function normalizedVelocity(n)
    local v = n.expressiveVelocity or n.velocity or n.originalVelocity or .7
    if v > 1 then v = v / 127 end
    return math.clamp(v, 0, 1)
end

local function priority(n)
    local score = normalizedVelocity(n) * 30
    if n.parts then
        if n.parts.melody then score += 120 end
        if n.parts.bass then score += 90 end
        if n.parts.hand == "Right" then score += 3 end
    end
    return score
end

function Mapper.mapNotes(notes, profile, settings)
    settings = settings or {}
    local mapped = {}
    local stats = {total=#notes,mapped=0,adapted=0,dropped=0,collisions=0,deduped=0}
    local transpose = math.clamp(settings.transpose or 0, -24, 24)
    local range = settings.rangeMode or "SmartOctave"
    local smart = 0
    if range == "SmartOctave" then
        smart, stats.smartCoverage = smartShift(notes, profile, transpose)
        range = "OctaveFold"
    end
    stats.smartTranspose = smart

    for _,n in ipairs(notes) do
        local target, changed = adapt(n.note + transpose + smart, profile, range)
        local token = target and profile.map[target] or nil
        if token then
            local c = clone(n)
            c.mappedNote, c.token, c.originalNote = target, token, n.note
            mapped[#mapped+1] = c
            stats.mapped += 1
            if changed or transpose + smart ~= 0 then stats.adapted += 1 end
        else
            stats.dropped += 1
        end
    end

    table.sort(mapped,function(a,b)
        if a.startTime == b.startTime then
            if a.token == b.token then return priority(a) > priority(b) end
            return tostring(a.token) < tostring(b.token)
        end
        return a.startTime < b.startTime
    end)

    local deduped, lastByToken = {}, {}
    local window = (settings.collisionWindowMs or 2.5) / 1000
    for _,n in ipairs(mapped) do
        local prev = lastByToken[n.token]
        if prev and math.abs((prev.startTime or 0) - (n.startTime or 0)) <= window and prev.originalNote ~= n.originalNote then
            stats.collisions += 1
            stats.deduped += 1
            if priority(n) > priority(prev) then
                local idx = prev.__idx
                n.__idx = idx
                deduped[idx] = n
                lastByToken[n.token] = n
            end
        else
            n.__idx = #deduped + 1
            deduped[#deduped+1] = n
            lastByToken[n.token] = n
        end
    end
    for _,n in ipairs(deduped) do n.__idx = nil end
    stats.mapped = #deduped
    stats.coverage = stats.total > 0 and (#deduped / stats.total) or 1
    return deduped, stats
end

local function articulationFactor(n, influence)
    influence = math.clamp(influence or .78, 0, 1)
    local target = 1
    if n.articulation == "Staccato" then target = .50
    elseif n.articulation == "Legato" then target = .98
    elseif n.articulation == "Accent" then target = .82
    elseif n.articulation == "Sustain" then target = .95 end
    return 1 + (target - 1) * influence
end

local function holdFromMidi(n, expr, nextSameStart)
    expr = expr or {}
    local start = n.startTime or 0
    -- keyReleaseTime is preferred when sustain pedal extended endTime. The keyboard
    -- key should mirror the finger release, not remain physically held for the pedal.
    local releaseTime = n.keyReleaseTime or n.endTime or (start + (n.duration or .08))
    local midiMs = math.max(1, (releaseTime - start) * 1000)
    local mode = expr.durationMode or "MIDI"
    local hold
    if mode == "Fixed" then
        hold = expr.fixedHoldMs or 42
    else
        hold = midiMs * math.clamp(expr.holdScale or .90, .1, 1.25)
        hold *= articulationFactor(n, expr.articulationInfluence)
        local v = normalizedVelocity(n)
        local velInf = math.clamp(expr.velocityInfluence or .12, 0, 1)
        hold *= 1 + (v - .5) * .10 * velInf
    end

    local minHold = math.clamp(expr.minHoldMs or 18, 6, 200)
    local maxHold = math.clamp(expr.maxHoldMs or 650, minHold, 2000)
    hold = math.clamp(hold, minHold, maxHold)

    if nextSameStart then
        local gap = math.max(3, expr.releaseGapMs or 8)
        local available = (nextSameStart - start) * 1000 - gap
        if available > 0 then hold = math.min(hold, math.max(6, available)) end
    end
    return hold
end

local function eventRank(e)
    if e.action == "up" then return 1 end
    if e.action == "strike" or e.action == "tap" then return 2 end
    return 3
end

function Mapper.toEvents(mappedNotes, settings)
    settings = settings or {}
    local expr = settings.expression or {}
    local events = {}
    local nextByToken = {}
    local nextSame = {}

    for i = #mappedNotes, 1, -1 do
        local n = mappedNotes[i]
        nextSame[i] = nextByToken[n.token]
        nextByToken[n.token] = n.startTime
    end

    for i,n in ipairs(mappedNotes) do
        if settings.triggerMode == "Hold" then
            events[#events+1] = {time=n.startTime,action="down",token=n.token,note=n,velocity=normalizedVelocity(n)}
            events[#events+1] = {time=n.keyReleaseTime or n.endTime,action="up",token=n.token,note=n,velocity=normalizedVelocity(n)}
        else
            local action = expr.enabled == false and "tap" or "strike"
            events[#events+1] = {
                time = n.startTime,
                action = action,
                token = n.token,
                note = n,
                velocity = normalizedVelocity(n),
                holdMs = holdFromMidi(n, expr, nextSame[i]),
                nativeVelocity = expr.nativeVelocity ~= false,
            }
        end
    end

    table.sort(events,function(a,b)
        if a.time == b.time then
            local ar, br = eventRank(a), eventRank(b)
            if ar == br then return tostring(a.token) < tostring(b.token) end
            return ar < br
        end
        return a.time < b.time
    end)
    return events
end

return Mapper
