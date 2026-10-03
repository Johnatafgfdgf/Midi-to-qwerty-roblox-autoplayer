local Mapper = {}

local shiftedSymbols = {
    ["!"]="1", ["@"]="2", ["#"]="3", ["$"]="4", ["%"]="5",
    ["^"]="6", ["&"]="7", ["*"]="8", ["("]="9", [")"]="0",
}

local function clone(n)
    local c = {}
    for k, v in pairs(n) do c[k] = v end
    if n.parts then
        c.parts = {}
        for k, v in pairs(n.parts) do c.parts[k] = v end
    end
    return c
end

local function physicalToken(token)
    if shiftedSymbols[token] then return shiftedSymbols[token] end
    if type(token) == "string" and token:match("%u") then return string.lower(token) end
    return token
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

local function normalizedVelocity(n)
    local v = n.expressiveVelocity or n.velocity or n.originalVelocity or .7
    if v > 1 then v /= 127 end
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

local function weightedCoverage(notes, profile, base, shift)
    if #notes == 0 then return 1 end
    local hit, total = 0, 0
    for _, n in ipairs(notes) do
        local weight = 1 + priority(n) / 160
        local p = n.note + base + shift
        total += weight
        if p >= profile.lowest and p <= profile.highest then hit += weight end
    end
    return total > 0 and hit / total or 1
end

local function smartShift(notes, profile, base)
    local best, bestScore = 0, weightedCoverage(notes, profile, base, 0)
    local baseScore = bestScore
    for s = -36, 36, 12 do
        if s ~= 0 then
            local coverage = weightedCoverage(notes, profile, base, s)
            local score = coverage - math.abs(s) / 12 * .006
            if score > bestScore + 1e-9 then
                best, bestScore = s, score
            end
        end
    end
    if bestScore - baseScore < .055 then return 0, baseScore end
    return best, weightedCoverage(notes, profile, base, best)
end

function Mapper.mapNotes(notes, profile, settings)
    settings = settings or {}
    local mapped = {}
    local stats = {
        total = #notes, mapped = 0, adapted = 0, dropped = 0,
        collisions = 0, physicalCollisions = 0, deduped = 0,
    }

    local transpose = math.clamp(settings.transpose or 0, -24, 24)
    local range = settings.rangeMode or "SmartOctave"
    local smart = 0
    if range == "SmartOctave" then
        smart, stats.smartCoverage = smartShift(notes, profile, transpose)
        range = "OctaveFold"
    end
    stats.smartTranspose = smart

    for _, n in ipairs(notes) do
        local target, changed = adapt(n.note + transpose + smart, profile, range)
        local token = target and profile.map[target] or nil
        if token then
            local c = clone(n)
            c.mappedNote, c.token, c.originalNote = target, token, n.note
            c.physicalToken = physicalToken(token)
            mapped[#mapped + 1] = c
            stats.mapped += 1
            if changed or transpose + smart ~= 0 then stats.adapted += 1 end
        else
            stats.dropped += 1
        end
    end

    table.sort(mapped, function(a, b)
        if a.startTime == b.startTime then
            if a.physicalToken == b.physicalToken then return priority(a) > priority(b) end
            return tostring(a.token) < tostring(b.token)
        end
        return a.startTime < b.startTime
    end)

    local deduped, lastByPhysical = {}, {}
    local window = (settings.collisionWindowMs or 2.5) / 1000
    for _, n in ipairs(mapped) do
        local id = n.physicalToken
        local prev = lastByPhysical[id]
        if prev and math.abs((prev.startTime or 0) - (n.startTime or 0)) <= window and prev.originalNote ~= n.originalNote then
            stats.collisions += 1
            stats.physicalCollisions += 1
            stats.deduped += 1
            if priority(n) > priority(prev) then
                local idx = prev.__idx
                n.__idx = idx
                deduped[idx] = n
                lastByPhysical[id] = n
            end
        else
            n.__idx = #deduped + 1
            deduped[#deduped + 1] = n
            lastByPhysical[id] = n
        end
    end

    for _, n in ipairs(deduped) do n.__idx = nil end
    stats.mapped = #deduped
    stats.coverage = stats.total > 0 and (#deduped / stats.total) or 1
    stats.weightedCoverage = weightedCoverage(notes, profile, transpose, smart)
    return deduped, stats
end

local function articulationFactor(n, influence)
    influence = math.clamp(influence or .82, 0, 1)
    local target = 1
    if n.articulation == "Staccato" then target = .50
    elseif n.articulation == "Legato" then target = .98
    elseif n.articulation == "Accent" then target = .84
    elseif n.articulation == "Sustain" then target = .96 end
    return 1 + (target - 1) * influence
end

local function humanizedRelease(n)
    local start = n.startTime or 0
    local offset = (n.humanOffsetMs or 0) / 1000
    local shiftedKeyRelease = n.keyReleaseTime and (n.keyReleaseTime + offset) or nil
    local endTime = n.endTime
    if shiftedKeyRelease and endTime then
        if n.articulation == "Staccato" then return math.min(shiftedKeyRelease, endTime) end
        return math.max(start + .006, shiftedKeyRelease)
    end
    return endTime or shiftedKeyRelease or (start + (n.duration or .08))
end

local function holdFromMidi(n, expr, nextSameStart)
    expr = expr or {}
    local start = n.startTime or 0
    local releaseTime = humanizedRelease(n)
    local midiMs = math.max(1, (releaseTime - start) * 1000)
    local mode = expr.durationMode or "MIDI"
    local hold

    if mode == "Fixed" then
        hold = expr.fixedHoldMs or 42
    else
        hold = midiMs * math.clamp(expr.holdScale or .96, .1, 1.35)
        hold *= articulationFactor(n, expr.articulationInfluence)
        local v = normalizedVelocity(n)
        local velInf = math.clamp(expr.velocityInfluence or .14, 0, 1)
        hold *= 1 + (v - .5) * .10 * velInf
    end

    local minHold = math.clamp(expr.minHoldMs or 14, 6, 500)
    local maxHold = math.clamp(expr.maxHoldMs or 6000, minHold, 15000)
    hold = math.clamp(hold, minHold, maxHold)

    if nextSameStart then
        local gap = math.max(3, expr.releaseGapMs or 7)
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
    local events, nextByPhysical, nextSame = {}, {}, {}

    for i = #mappedNotes, 1, -1 do
        local n = mappedNotes[i]
        local id = n.physicalToken or physicalToken(n.token)
        nextSame[i] = nextByPhysical[id]
        nextByPhysical[id] = n.startTime
    end

    local sequence = 0
    local function add(e)
        sequence += 1
        e.sequence = sequence
        events[#events + 1] = e
    end

    for i, n in ipairs(mappedNotes) do
        if settings.triggerMode == "Hold" then
            add({time = n.startTime, action = "down", token = n.token, note = n, velocity = normalizedVelocity(n)})
            add({time = humanizedRelease(n), action = "up", token = n.token, note = n, velocity = normalizedVelocity(n)})
        else
            local action = expr.enabled == false and "tap" or "strike"
            add({
                time = n.startTime, action = action, token = n.token, note = n,
                velocity = normalizedVelocity(n),
                holdMs = holdFromMidi(n, expr, nextSame[i]),
                nativeVelocity = expr.nativeVelocity ~= false,
            })
        end
    end

    table.sort(events, function(a, b)
        if a.time == b.time then
            local ar, br = eventRank(a), eventRank(b)
            if ar == br then return (a.sequence or 0) < (b.sequence or 0) end
            return ar < br
        end
        return a.time < b.time
    end)
    return events
end

return Mapper
