local Mapper = {}

local function clone(n)
    local c = {}
    for k,v in pairs(n) do c[k] = v end
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
    local bestShift, bestCoverage = 0, baseCoverage
    for _,s in ipairs({-24,-12,12,24}) do
        local c = coverage(notes, profile, base, s)
        if c > bestCoverage + 1e-9 then
            bestShift, bestCoverage = s, c
        end
    end
    -- Do not move the whole song an octave for a tiny coverage gain.
    if bestCoverage - baseCoverage < 0.10 then return 0, baseCoverage end
    return bestShift, bestCoverage
end

local function priority(n)
    local p = n.velocity or 64
    if n.parts then
        if n.parts.melody then p += 1000 end
        if n.parts.bass then p += 700 end
    end
    return p
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

    -- When octave folding makes two different MIDI pitches land on the exact
    -- same QWERTY key at the same musical attack, one physical piano key cannot
    -- represent both. Triggering it twice sounds like an accidental double hit,
    -- so keep the most musically important note and count the collision.
    local deduped = {}
    local lastByToken = {}
    local window = (settings.collisionWindowMs or 2.5) / 1000
    for _,n in ipairs(mapped) do
        local prev = lastByToken[n.token]
        if prev and math.abs((prev.startTime or 0) - (n.startTime or 0)) <= window and prev.originalNote ~= n.originalNote then
            stats.collisions += 1
            stats.deduped += 1
            if priority(n) > priority(prev) then
                local idx = prev.__dedupeIndex
                n.__dedupeIndex = idx
                deduped[idx] = n
                lastByToken[n.token] = n
            end
        else
            n.__dedupeIndex = #deduped + 1
            deduped[#deduped+1] = n
            lastByToken[n.token] = n
        end
    end
    for _,n in ipairs(deduped) do n.__dedupeIndex = nil end

    stats.mapped = #deduped
    stats.coverage = stats.total > 0 and (#deduped / stats.total) or 1
    return deduped, stats
end

local function eventRank(e)
    if e.action == "up" then return 1 end
    if e.action == "tap" then return 2 end
    return 3
end

function Mapper.toEvents(mappedNotes, settings)
    settings = settings or {}
    local triggerMode = settings.triggerMode or "Tap"
    local events = {}
    for _,n in ipairs(mappedNotes) do
        if triggerMode == "Hold" then
            events[#events+1] = {time=n.startTime, action="down", token=n.token, note=n}
            events[#events+1] = {time=n.endTime, action="up", token=n.token, note=n}
        else
            events[#events+1] = {time=n.startTime, action="tap", token=n.token, note=n}
        end
    end
    table.sort(events, function(a,b)
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
