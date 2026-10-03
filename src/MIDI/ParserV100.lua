local Parser = {}

local Reader = {}
Reader.__index = Reader

function Reader.new(data, startPos, endPos, label)
    return setmetatable({
        data = data,
        pos = startPos or 1,
        limit = endPos or #data,
        label = label or "MIDI",
    }, Reader)
end

function Reader:remaining()
    return math.max(0, self.limit - self.pos + 1)
end

function Reader:fail(message)
    error(string.format("%s at byte %d: %s", self.label, self.pos, message), 0)
end

function Reader:u8()
    if self.pos > self.limit then self:fail("unexpected end of data") end
    local v = string.byte(self.data, self.pos)
    self.pos += 1
    return v
end

function Reader:u16()
    local a, b = self:u8(), self:u8()
    return a * 256 + b
end

function Reader:u32()
    local a, b, c, d = self:u8(), self:u8(), self:u8(), self:u8()
    return ((a * 256 + b) * 256 + c) * 256 + d
end

function Reader:str(n)
    n = tonumber(n) or 0
    if n < 0 or self.pos + n - 1 > self.limit then self:fail("string exceeds chunk boundary") end
    local s = string.sub(self.data, self.pos, self.pos + n - 1)
    self.pos += n
    return s
end

function Reader:vlq()
    local value = 0
    for i = 1, 4 do
        local b = self:u8()
        value = value * 128 + bit32.band(b, 0x7F)
        if b < 0x80 then return value end
        if i == 4 then self:fail("invalid VLQ longer than 4 bytes") end
    end
end

local function divisionInfo(raw)
    if raw < 0x8000 then
        assert(raw > 0, "Invalid PPQN division: 0")
        return {type = "PPQN", ppqn = raw, raw = raw}
    end
    local high = bit32.rshift(raw, 8)
    if high >= 128 then high -= 256 end
    local fpsCode = -high
    local valid = fpsCode == 24 or fpsCode == 25 or fpsCode == 29 or fpsCode == 30
    assert(valid, "Invalid SMPTE frame code: " .. tostring(fpsCode))
    local ticksPerFrame = bit32.band(raw, 0xFF)
    assert(ticksPerFrame > 0, "Invalid SMPTE ticks-per-frame: 0")
    return {
        type = "SMPTE",
        fps = fpsCode == 29 and 29.97 or fpsCode,
        fpsCode = fpsCode,
        ticksPerFrame = ticksPerFrame,
        raw = raw,
    }
end

local channelDataLength = {
    [0x80] = 2, [0x90] = 2, [0xA0] = 2, [0xB0] = 2,
    [0xC0] = 1, [0xD0] = 1, [0xE0] = 2,
}

local systemCommonLength = {
    [0xF1] = 1,
    [0xF2] = 2,
    [0xF3] = 1,
    [0xF6] = 0,
}

local function checkDataByte(r, value)
    if value >= 0x80 then r:fail(string.format("invalid MIDI data byte 0x%02X", value)) end
    return value
end

local function parseTrack(data, startPos, endPos, trackIndex, warnings, sequenceBase)
    local r = Reader.new(data, startPos, endPos, "MTrk #" .. tostring(trackIndex))
    local tick, running = 0, nil
    local events = {}
    local sequence = sequenceBase or 0

    local function add(e)
        sequence += 1
        e.sequence = sequence
        events[#events + 1] = e
    end

    while r.pos <= r.limit do
        local delta = r:vlq()
        tick += delta
        if r.pos > r.limit then
            warnings[#warnings + 1] = "Track " .. trackIndex .. " ends immediately after a delta-time"
            break
        end

        local first = r:u8()
        local status, data1
        if first < 0x80 then
            if not running then r:fail("running status without previous channel status") end
            status, data1 = running, first
        else
            status = first
        end

        if status == 0xFF then
            running = nil
            local metaType = r:u8()
            local len = r:vlq()
            local payload = r:str(len)
            local e = {tick = tick, track = trackIndex, type = "meta", metaType = metaType, data = payload}
            if metaType == 0x2F then
                e.subtype = "endTrack"
                add(e)
                if r:remaining() > 0 then
                    warnings[#warnings + 1] = string.format("Track %d has %d byte(s) after End-of-Track", trackIndex, r:remaining())
                end
                break
            elseif metaType == 0x51 and len == 3 then
                local a, b, c = string.byte(payload, 1, 3)
                e.subtype = "tempo"
                e.microsecondsPerQuarter = a * 65536 + b * 256 + c
            elseif metaType == 0x58 and len >= 4 then
                local nn, dd, cc, bb = string.byte(payload, 1, 4)
                e.subtype = "timeSignature"
                e.numerator, e.denominator = nn, 2 ^ dd
                e.clocksPerClick, e.notes32PerQuarter = cc, bb
            elseif metaType == 0x59 and len >= 2 then
                local sf, mi = string.byte(payload, 1, 2)
                if sf >= 128 then sf -= 256 end
                e.subtype, e.sharpsFlats, e.minor = "keySignature", sf, mi == 1
            elseif metaType == 0x03 then
                e.subtype, e.text = "trackName", payload
            elseif metaType == 0x04 then
                e.subtype, e.text = "instrumentName", payload
            elseif metaType == 0x01 or metaType == 0x02 or metaType == 0x05 or metaType == 0x06 or metaType == 0x07 then
                e.subtype, e.text = "text", payload
            else
                e.subtype = "metaOther"
            end
            add(e)

        elseif status == 0xF0 or status == 0xF7 then
            running = nil
            local len = r:vlq()
            add({tick = tick, track = trackIndex, type = "sysex", status = status, data = r:str(len)})

        elseif status >= 0xF8 and status <= 0xFE then
            warnings[#warnings + 1] = string.format("Track %d contains non-SMF realtime status 0x%02X", trackIndex, status)
            add({tick = tick, track = trackIndex, type = "systemRealtime", status = status})

        elseif systemCommonLength[status] ~= nil then
            running = nil
            local len = systemCommonLength[status]
            local bytes = {}
            for i = 1, len do bytes[i] = checkDataByte(r, r:u8()) end
            warnings[#warnings + 1] = string.format("Track %d contains non-standard system-common status 0x%02X", trackIndex, status)
            add({tick = tick, track = trackIndex, type = "systemCommon", status = status, dataBytes = bytes})

        else
            local family = bit32.band(status, 0xF0)
            local len = channelDataLength[family]
            if not len or status > 0xEF then r:fail(string.format("unsupported MIDI status 0x%02X", status)) end
            running = status

            local channel = bit32.band(status, 0x0F) + 1
            local a = checkDataByte(r, data1 or r:u8())
            local b = len == 2 and checkDataByte(r, r:u8()) or nil
            local e = {tick = tick, track = trackIndex, channel = channel, status = status}

            if family == 0x80 then
                e.type, e.note, e.velocity = "noteOff", a, b
            elseif family == 0x90 then
                e.type = b == 0 and "noteOff" or "noteOn"
                e.note, e.velocity = a, b
            elseif family == 0xA0 then
                e.type, e.note, e.pressure = "polyPressure", a, b
            elseif family == 0xB0 then
                e.type, e.controller, e.value = "controlChange", a, b
            elseif family == 0xC0 then
                e.type, e.program = "programChange", a
            elseif family == 0xD0 then
                e.type, e.pressure = "channelPressure", a
            elseif family == 0xE0 then
                e.type, e.value = "pitchBend", (b * 128 + a) - 8192
            end
            add(e)
        end
    end

    return events, sequence
end

function Parser.parse(data)
    assert(type(data) == "string" and #data >= 14, "Invalid or empty MIDI data")
    local r = Reader.new(data)
    assert(r:str(4) == "MThd", "Missing MThd header")
    local headerLen = r:u32()
    assert(headerLen >= 6, "Invalid MIDI header length")

    local format, trackCount, divisionRaw = r:u16(), r:u16(), r:u16()
    if headerLen > 6 then r:str(headerLen - 6) end
    assert(format >= 0 and format <= 2, "Unsupported SMF format: " .. tostring(format))
    assert(trackCount > 0, "MIDI declares zero tracks")

    local warnings = {}
    if format == 0 and trackCount ~= 1 then
        warnings[#warnings + 1] = "SMF format 0 should contain exactly one track"
    elseif format == 2 then
        warnings[#warnings + 1] = "SMF format 2 contains independent sequences; playback is merged by absolute tick"
    end

    local midi = {
        format = format,
        declaredTrackCount = trackCount,
        division = divisionInfo(divisionRaw),
        tracks = {},
        events = {},
        warnings = warnings,
        byteLength = #data,
        parserVersion = 3,
    }

    local trackIndex, sequence = 0, 0
    while trackIndex < trackCount and r:remaining() >= 8 do
        local chunkId, len = r:str(4), r:u32()
        local startPos = r.pos
        local endPos = startPos + len - 1
        assert(endPos <= #data, string.format("Chunk %s exceeds file size", tostring(chunkId)))

        if chunkId == "MTrk" then
            trackIndex += 1
            local events
            events, sequence = parseTrack(data, startPos, endPos, trackIndex, warnings, sequence)
            midi.tracks[trackIndex] = {index = trackIndex, events = events}
            for _, e in ipairs(events) do midi.events[#midi.events + 1] = e end
        else
            warnings[#warnings + 1] = string.format("Skipped unknown chunk '%s' (%d bytes)", tostring(chunkId), len)
        end
        r.pos = endPos + 1
    end

    if trackIndex < trackCount then
        warnings[#warnings + 1] = string.format("MIDI ended after %d/%d declared track(s)", trackIndex, trackCount)
    end
    if r:remaining() > 0 then
        warnings[#warnings + 1] = string.format("%d trailing byte(s) after parsed chunks", r:remaining())
    end

    table.sort(midi.events, function(a, b)
        if a.tick ~= b.tick then return a.tick < b.tick end
        if (a.track or 0) ~= (b.track or 0) then return (a.track or 0) < (b.track or 0) end
        return (a.sequence or 0) < (b.sequence or 0)
    end)

    return midi
end

Parser.Reader = Reader
return Parser
