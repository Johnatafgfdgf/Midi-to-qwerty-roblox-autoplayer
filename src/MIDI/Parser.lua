local Parser = {}

local Reader = {}
Reader.__index = Reader
function Reader.new(data, startPos, endPos)
    return setmetatable({data = data, pos = startPos or 1, limit = endPos or #data}, Reader)
end
function Reader:remaining() return self.limit - self.pos + 1 end
function Reader:u8()
    assert(self.pos <= self.limit, "Unexpected end of MIDI data")
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
    assert(self.pos + n - 1 <= self.limit, "Unexpected end of MIDI string")
    local s = string.sub(self.data, self.pos, self.pos + n - 1)
    self.pos += n
    return s
end
function Reader:vlq()
    local value = 0
    for _ = 1, 4 do
        local b = self:u8()
        value = value * 128 + bit32.band(b, 0x7F)
        if b < 0x80 then return value end
    end
    error("Invalid MIDI VLQ (more than 4 bytes)")
end

local function divisionInfo(raw)
    if raw < 0x8000 then
        return {type = "PPQN", ppqn = raw, raw = raw}
    end
    local high = bit32.rshift(raw, 8)
    if high >= 128 then high -= 256 end
    local fpsCode = -high
    local fps = fpsCode == 29 and 29.97 or fpsCode
    return {type = "SMPTE", fps = fps, ticksPerFrame = bit32.band(raw, 0xFF), raw = raw}
end

local channelDataLength = {
    [0x80] = 2, [0x90] = 2, [0xA0] = 2, [0xB0] = 2,
    [0xC0] = 1, [0xD0] = 1, [0xE0] = 2,
}

local function parseTrack(data, startPos, endPos, trackIndex)
    local r = Reader.new(data, startPos, endPos)
    local tick, running = 0, nil
    local events = {}
    while r.pos <= r.limit do
        local delta = r:vlq()
        tick += delta
        if r.pos > r.limit then break end
        local first = r:u8()
        local status, data1
        if first < 0x80 then
            assert(running, "Running status without previous channel status")
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
                events[#events + 1] = e
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
            elseif metaType == 0x03 then
                e.subtype, e.text = "trackName", payload
            elseif metaType == 0x04 then
                e.subtype, e.text = "instrumentName", payload
            elseif metaType == 0x01 then
                e.subtype, e.text = "text", payload
            else
                e.subtype = "metaOther"
            end
            events[#events + 1] = e
        elseif status == 0xF0 or status == 0xF7 then
            running = nil
            local len = r:vlq()
            events[#events + 1] = {tick = tick, track = trackIndex, type = "sysex", status = status, data = r:str(len)}
        else
            local family = bit32.band(status, 0xF0)
            local len = channelDataLength[family]
            assert(len, string.format("Unsupported MIDI status 0x%02X", status))
            running = status
            local channel = bit32.band(status, 0x0F) + 1
            local a = data1 or r:u8()
            local b = len == 2 and r:u8() or nil
            local e = {tick = tick, track = trackIndex, channel = channel, status = status}
            if family == 0x80 then
                e.type, e.note, e.velocity = "noteOff", a, b
            elseif family == 0x90 then
                if b == 0 then e.type = "noteOff" else e.type = "noteOn" end
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
            events[#events + 1] = e
        end
    end
    return events
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
    local midi = {
        format = format,
        declaredTrackCount = trackCount,
        division = divisionInfo(divisionRaw),
        tracks = {},
        events = {},
        warnings = {},
    }
    for trackIndex = 1, trackCount do
        if r:remaining() < 8 then
            midi.warnings[#midi.warnings + 1] = "MIDI ended before all declared tracks"
            break
        end
        local chunkId, len = r:str(4), r:u32()
        if chunkId ~= "MTrk" then error("Expected MTrk, found " .. tostring(chunkId)) end
        local startPos = r.pos
        local endPos = startPos + len - 1
        assert(endPos <= #data, "Track chunk exceeds file size")
        local events = parseTrack(data, startPos, endPos, trackIndex)
        midi.tracks[trackIndex] = {index = trackIndex, events = events}
        for _, e in ipairs(events) do midi.events[#midi.events + 1] = e end
        r.pos = endPos + 1
    end
    table.sort(midi.events, function(a, b)
        if a.tick == b.tick then return (a.track or 0) < (b.track or 0) end
        return a.tick < b.tick
    end)
    return midi
end

Parser.Reader = Reader
return Parser
