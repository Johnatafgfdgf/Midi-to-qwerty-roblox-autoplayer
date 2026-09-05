local Mapper = {}

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

function Mapper.mapNotes(notes, profile, settings)
    settings = settings or {}
    local mapped, stats = {}, {total = #notes, mapped = 0, adapted = 0, dropped = 0}
    local transpose = math.clamp(settings.transpose or 0, -24, 24)
    for _, n in ipairs(notes) do
        local pitch, changed = adapt(n.note + transpose, profile, settings.rangeMode or "OctaveFold")
        local token = pitch and profile.map[pitch] or nil
        if token then
            local c = {}; for k, v in pairs(n) do c[k] = v end
            c.mappedNote, c.token, c.originalNote = pitch, token, n.note
            mapped[#mapped + 1] = c
            stats.mapped += 1
            if changed or transpose ~= 0 then stats.adapted += 1 end
        else
            stats.dropped += 1
        end
    end
    stats.coverage = stats.total > 0 and stats.mapped / stats.total or 1
    return mapped, stats
end

function Mapper.toEvents(mappedNotes)
    local events = {}
    for _, n in ipairs(mappedNotes) do
        events[#events + 1] = {time = n.startTime, action = "down", token = n.token, note = n}
        events[#events + 1] = {time = n.endTime, action = "up", token = n.token, note = n}
    end
    table.sort(events, function(a, b)
        if a.time == b.time then return a.action == "up" and b.action ~= "up" end
        return a.time < b.time
    end)
    return events
end

return Mapper
