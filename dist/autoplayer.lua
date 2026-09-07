-- Generated from clean src modules. Build: python scripts/build.py
local env=(getgenv and getgenv())or _G
if env.MIDIQWERTY and env.MIDIQWERTY.destroy then env.MIDIQWERTY.destroy()end
local boot=Instance.new('ScreenGui');boot.Name='MIDIQWERTY_LOADING';boot.ResetOnSpawn=false;boot.DisplayOrder=22000
local parent=(gethui and gethui())or game:GetService('CoreGui');if not pcall(function()boot.Parent=parent end)then boot.Parent=game:GetService('Players').LocalPlayer:WaitForChild('PlayerGui')end
local label=Instance.new('TextLabel');label.Size=UDim2.fromOffset(290,52);label.Position=UDim2.fromOffset(16,70);label.BackgroundColor3=Color3.fromRGB(17,22,34);label.TextColor3=Color3.fromRGB(237,240,249);label.TextSize=14;label.Font=Enum.Font.Gotham;label.Text='Inicializando…';label.Parent=boot
local round=Instance.new('UICorner');round.CornerRadius=UDim.new(0,14);round.Parent=label
local modules={}
modules['Cloud/CloudProvider']=function()
-- Transport injection separates verified service routes from cancellation/state logic.
local P={};P.__index=P
function P.new(transport,options)
 return setmetatable({transport=transport,options=options or {},generation=0,state='Idle',lastError=nil},P)
end
function P:cancel()self.generation+=1;self.state='Idle'end
function P:health()return self.transport and {available=true,state=self.state}or {available=false,state='Unsupported'}end
function P:_request(method,arg,callback)
 self:cancel();local generation=self.generation
 if not self.transport or not self.transport[method]then self.state='Unsupported';self.lastError='Provider sem contrato público validado';callback(nil,self.lastError);return end
 self.state='Loading';local done=false
 local function finish(result,err)
  if done or generation~=self.generation then return end;done=true
  self.lastError=err;self.state=err and 'Error' or (type(result)=='table' and #result==0 and 'Empty'or 'Results');callback(result,err)
 end
 task.delay(self.options.timeoutSeconds or 6,function()if not done and generation==self.generation then self.state='Offline';done=true;self.lastError='Timeout';callback(nil,'Timeout')end end)
 task.spawn(function()local ok,res,err=pcall(self.transport[method],self.transport,arg);if ok then finish(res,err)else finish(nil,tostring(res))end end)
end
function P:search(q,cb)self:_request('search',q,cb)end
function P:getSong(id,cb)self:_request('getSong',id,cb)end
function P:download(song,cb)self:_request('download',song,cb)end
function P:diagnostics()return {state=self.state,error=self.lastError,verified=self.transport~=nil}end
return P

end
modules['Cloud/DodoProvider']=function()
local D={}
function D.new(R,FS,options)
 local provider=R('Cloud/CloudProvider').new(nil,options)
 provider.lastError='Dodo Cloud indisponível: autenticação/contrato de serviço não validados para este cliente. Biblioteca local disponível.'
 return provider
end
return D

end
modules['ConfigDefaults']=function()
return {
    version = 12,
    midiFolders = {
        "Delta/Workspace/MIDI",
        "Delta/Workspace/Midis",
        "Delta/Workspace/Songs",
        "Delta/Workspace/Music",
        "Delta/Workspace",
        "Workspace/MIDI",
        "MIDI",
    },
    playback = {
        speed = 1.0,
        mode = "Both",
        transpose = 0,
        rangeMode = "SmartOctave",
        lateMode = "CatchUp",
        maxLateMs = 140,
        chordWindowMs = 9,
        collisionWindowMs = 2.5,
        loopSong = false,
        quantization = "Off",
        maxSimultaneousKeys = 16,
        maxNotesPerSecond = 0,
        triggerMode = "Tap",
        loopA = nil,
        loopB = nil,
        expression = {
            enabled = true,
            nativeVelocity = true,
            durationMode = "MIDI",
            minHoldMs = 16,
            maxHoldMs = 900,
            holdScale = .96,
            releaseGapMs = 7,
            velocityInfluence = .12,
            articulationInfluence = .78,
        },
    },
    parts = {
        splitMode = "Auto",
        splitNote = 60,
        percussion = false,
        enabledTracks = {},
        enabledChannels = {},
    },
    humanize = {
        preset = "Pianist",
        enabled = true,
        strength = 1.0,
        timingMs = 10,
        phraseMs = 11,
        handMs = 6,
        microMs = 2.8,
        chordSpreadMs = 11,
        rubatoMs = 10,
        durationVariation = .027,
        latencyMs = 0,
        velocityPreservation = .88,
        dynamicContour = .52,
        seedMode = "Auto",
        fixedSeed = 12345,
    },
    ui = {
        state = "Full",
        activeTab = "Library",
        librarySource = "Local",
        floatingX = .84,
        floatingY = .72,
        pianoRoll = true,
        pianoRollLookAhead = 2.6,
        songFilter = "All",
        songSort = "A-Z",
        performanceMode = false,
        transitions = true,
        lastSeenChangelog = "",
    },
    cloud = {
        enabled = true,
        provider = "Dodo",
        timeoutSeconds = 6,
        downloadFolder = "Delta/Workspace/MIDI/Cloud",
    },
    pianoProfile = "RobloxVirtualPiano61",
}

end
modules['Export/Exporter']=function()
local Exporter={}
local function safe(s) return (s or "song"):gsub("[^%w%-%._]","_") end
local function stamp() return os.date("!%Y%m%d_%H%M%S") end
function Exporter.sequence(FS,item,mapped)
    FS.ensureFolder("MIDIQWERTY/exports")
    local lines={"# QWERTY performance export: "..(item.name or item.path)}
    for _,n in ipairs(mapped or {}) do lines[#lines+1]=string.format("[%08.3f] %s  MIDI:%d",n.startTime,n.token,n.originalNote or n.note) end
    local path="MIDIQWERTY/exports/"..safe(item.name).."_"..stamp().."_qwerty.txt"; FS.write(path,table.concat(lines,"\n")); return path
end
function Exporter.analysis(FS,item,a)
    FS.ensureFolder("MIDIQWERTY/exports")
    local lines={"MIDI Analysis","File: "..(item.name or item.path),string.format("Duration: %.3fs",a.duration or 0),"Notes: "..tostring(a.noteCount),"Tracks: "..tostring(#(a.tracks or {})),"Pitch range: "..tostring(a.pitchMin)..".."..tostring(a.pitchMax),"Peak polyphony: "..tostring(a.peakPolyphony),"Hand split: "..tostring(a.handSplit),"Voice count: "..tostring(a.voiceCount)}
    local path="MIDIQWERTY/exports/"..safe(item.name).."_"..stamp().."_analysis.txt"; FS.write(path,table.concat(lines,"\n")); return path
end
return Exporter

end
modules['Input/InputAdapter']=function()
local InputAdapter={};InputAdapter.__index=InputAdapter

local shiftedSymbols={["!"]="1",["@"]="2",["#"]="3",["$"]="4",["%"]="5",["^"]="6",["&"]="7",["*"]="8",["("]="9",[")"]="0"}
local digitEnum={["0"]="Zero",["1"]="One",["2"]="Two",["3"]="Three",["4"]="Four",["5"]="Five",["6"]="Six",["7"]="Seven",["8"]="Eight",["9"]="Nine"}

local function envFn(name)
    local env=(getgenv and getgenv()) or _G
    local v=rawget(env,name) or rawget(_G,name)
    return type(v)=="function" and v or nil
end
local function spec(token)
    if type(token)~="string" or #token~=1 then return nil end
    local base,shift=token,false
    if shiftedSymbols[token] then base,shift=shiftedSymbols[token],true
    elseif token:match("%u") then base,shift=string.lower(token),true end
    if not base:match("[%a%d]") then return nil end
    local upper=string.upper(base)
    return {token=token,base=base,shift=shift,vk=string.byte(upper),enumName=base:match("%d") and digitEnum[base] or upper,physical=upper}
end

function InputAdapter.new()
    local self=setmetatable({shiftRefs=0,strikeGen={},heldStrike={}},InputAdapter)
    self.keypress=envFn("keypress") or envFn("key_press") or envFn("key_down")
    self.keyrelease=envFn("keyrelease") or envFn("key_release") or envFn("key_up")
    self.velocityHook=envFn("MIDIQWERTY_VELOCITY_STRIKE")
    self.backend="Unavailable"
    if self.keypress and self.keyrelease then self.backend="ExecutorKeyEvents"
    else
        local ok,vim=pcall(game.GetService,game,"VirtualInputManager")
        if ok and vim then self.vim,self.backend=vim,"VirtualInputManager" end
    end
    if self.velocityHook then self.backend=self.backend.." + VelocityHook" end
    return self
end
function InputAdapter:physicalId(token)local s=spec(token);return s and s.physical or tostring(token)end
function InputAdapter:_sendKey(down,s)
    if self.backend:find("ExecutorKeyEvents",1,true) then
        local f=down and self.keypress or self.keyrelease
        return pcall(f,s.vk)
    elseif self.vim then
        local keyCode=Enum.KeyCode[s.enumName]
        if not keyCode then return false,"Unsupported KeyCode: "..tostring(s.enumName) end
        return pcall(self.vim.SendKeyEvent,self.vim,down,keyCode,false,game)
    end
    return false,"No keyboard input backend available"
end
function InputAdapter:_shift(down)
    if self.backend:find("ExecutorKeyEvents",1,true) then
        local f=down and self.keypress or self.keyrelease;return pcall(f,0x10)
    elseif self.vim then return pcall(self.vim.SendKeyEvent,self.vim,down,Enum.KeyCode.LeftShift,false,game) end
    return false
end

function InputAdapter:strike(token,opts)
    opts=opts or {}
    local s=spec(token);if not s then return false,"Unsupported token: "..tostring(token) end
    local velocity=math.clamp(tonumber(opts.velocity) or .7,0,1)
    local holdMs=math.clamp(tonumber(opts.holdMs) or 34,6,2000)
    if self.velocityHook and opts.nativeVelocity~=false then
        local ok,res=pcall(self.velocityHook,token,velocity,opts)
        if ok and res~=false then return true end
    end

    local id=s.physical
    local gen=(self.strikeGen[id] or 0)+1;self.strikeGen[id]=gen
    -- Explicit release before retrigger makes repeated notes register even if
    -- the previous expressive hold has not finished yet.
    if self.heldStrike[id] then pcall(function()self:_sendKey(false,self.heldStrike[id])end) end
    self.heldStrike[id]=s
    if s.shift then self:_shift(true) end
    local ok,err=self:_sendKey(true,s)
    -- Shift is only needed for the key-down identity. Releasing it immediately
    -- prevents it leaking into neighbouring white notes in dense chords.
    if s.shift then self:_shift(false) end
    if not ok then self.heldStrike[id]=nil;return false,err end
    task.delay(holdMs/1000,function()
        if self.strikeGen[id]~=gen then return end
        local held=self.heldStrike[id]
        if held then pcall(function()self:_sendKey(false,held)end) end
        if self.strikeGen[id]==gen then self.heldStrike[id]=nil end
    end)
    return true
end
function InputAdapter:tap(token)return self:strike(token,{holdMs=18,velocity=.7,nativeVelocity=false})end

function InputAdapter:press(token)
    local s=spec(token);if not s then return false,"Unsupported token: "..tostring(token) end
    if s.shift then if self.shiftRefs==0 then self:_shift(true) end;self.shiftRefs+=1 end
    local ok,err=self:_sendKey(true,s)
    if not ok and s.shift then self.shiftRefs=math.max(0,self.shiftRefs-1);if self.shiftRefs==0 then self:_shift(false)end end
    return ok,err
end
function InputAdapter:release(token)
    local s=spec(token);if not s then return false,"Unsupported token: "..tostring(token) end
    local ok,err=self:_sendKey(false,s)
    if s.shift then self.shiftRefs=math.max(0,self.shiftRefs-1);if self.shiftRefs==0 then self:_shift(false)end end
    return ok,err
end
function InputAdapter:releaseModifiers()if self.shiftRefs>0 then self:_shift(false)end;self.shiftRefs=0 end
function InputAdapter:releaseExpressive()
    for id,s in pairs(self.heldStrike)do pcall(function()self:_sendKey(false,s)end);self.heldStrike[id]=nil;self.strikeGen[id]=(self.strikeGen[id] or 0)+1 end
end
function InputAdapter:diagnostics()
    return {backend=self.backend,available=self.backend~="Unavailable",nativeVelocity=self.velocityHook~=nil,expressiveStrike=true}
end
return InputAdapter

end
modules['MIDI/Analyzer']=function()
local Analyzer = {}
local function keyOf(e) return string.format("%d:%d:%d", e.track or 0, e.channel or 0, e.note or -1) end

local function sustainIntervals(pedalEvents,maxTime)
    local opened,intervals={},{}
    for _,e in ipairs(pedalEvents) do
        local k=string.format("%d:%d",e.track,e.channel); intervals[k]=intervals[k] or {}
        if e.down and not opened[k] then opened[k]=e.time elseif not e.down and opened[k] then intervals[k][#intervals[k]+1]={opened[k],e.time}; opened[k]=nil end
    end
    for k,t in pairs(opened) do intervals[k]=intervals[k] or {}; intervals[k][#intervals[k]+1]={t,maxTime} end
    return intervals
end

function Analyzer.analyze(midi, tempoMap)
    local notes,active,trackInfo={}, {}, {}
    local maxTime,minNote,maxNote=0,127,0
    local pedalEvents,timeSignatures={},{}
    local programs={}
    for _,track in ipairs(midi.tracks) do trackInfo[track.index]={index=track.index,name="Track "..track.index,instrument=nil,noteCount=0,channels={}} end
    for _,e in ipairs(midi.events) do
        e.time=tempoMap:tickToSeconds(e.tick); maxTime=math.max(maxTime,e.time)
        if e.type=="meta" then
            if e.subtype=="trackName" and trackInfo[e.track] then trackInfo[e.track].name=e.text end
            if e.subtype=="instrumentName" and trackInfo[e.track] then trackInfo[e.track].instrument=e.text end
            if e.subtype=="timeSignature" then timeSignatures[#timeSignatures+1]=e end
        elseif e.type=="programChange" then programs[string.format("%d:%d",e.track,e.channel)]=e.program
        elseif e.type=="controlChange" and e.controller==64 then pedalEvents[#pedalEvents+1]={time=e.time,tick=e.tick,track=e.track,channel=e.channel,down=e.value>=64,value=e.value}
        elseif e.type=="noteOn" then
            local k=keyOf(e); active[k]=active[k] or {}; active[k][#active[k]+1]=e; minNote=math.min(minNote,e.note); maxNote=math.max(maxNote,e.note)
            if trackInfo[e.track] then trackInfo[e.track].channels[e.channel]=true end
        elseif e.type=="noteOff" then
            local k=keyOf(e); local q=active[k]
            if q and #q>0 then
                local on=table.remove(q,1)
                local n={note=on.note,velocity=on.velocity or 64,startTick=on.tick,endTick=e.tick,startTime=on.time,endTime=math.max(e.time,on.time+.001),track=on.track,channel=on.channel,program=programs[string.format("%d:%d",on.track,on.channel)]}
                n.duration=n.endTime-n.startTime; notes[#notes+1]=n; if trackInfo[n.track] then trackInfo[n.track].noteCount+=1 end
            end
        end
    end
    for _,q in pairs(active) do for _,on in ipairs(q) do local et=math.max(maxTime,on.time+.08); notes[#notes+1]={note=on.note,velocity=on.velocity or 64,startTick=on.tick,endTick=on.tick,startTime=on.time,endTime=et,duration=et-on.time,track=on.track,channel=on.channel,dangling=true} end end
    table.sort(notes,function(a,b) return a.startTime==b.startTime and a.note<b.note or a.startTime<b.startTime end)

    local intervals=sustainIntervals(pedalEvents,maxTime)
    for _,n in ipairs(notes) do
        local k=string.format("%d:%d",n.track,n.channel)
        for _,iv in ipairs(intervals[k] or {}) do if n.endTime>=iv[1] and n.endTime<iv[2] then n.keyReleaseTime=n.endTime; n.endTime=iv[2]; n.duration=n.endTime-n.startTime; n.sustained=true; break end end
        maxTime=math.max(maxTime,n.endTime)
    end

    local endpoints={}; for _,n in ipairs(notes) do endpoints[#endpoints+1]={t=n.startTime,d=1}; endpoints[#endpoints+1]={t=n.endTime,d=-1} end
    table.sort(endpoints,function(a,b) return a.t==b.t and a.d<b.d or a.t<b.t end); local poly,peak=0,0; for _,p in ipairs(endpoints) do poly+=p.d; peak=math.max(peak,poly) end
    local bpmMin,bpmMax=nil,nil; for _,s in ipairs(tempoMap.tempoEvents or {}) do bpmMin=bpmMin and math.min(bpmMin,s.bpm) or s.bpm; bpmMax=bpmMax and math.max(bpmMax,s.bpm) or s.bpm end
    return {notes=notes,duration=maxTime,noteCount=#notes,pitchMin=#notes>0 and minNote or nil,pitchMax=#notes>0 and maxNote or nil,peakPolyphony=peak,tracks=trackInfo,pedalEvents=pedalEvents,timeSignatures=timeSignatures,bpmMin=bpmMin,bpmMax=bpmMax,tempoChanges=#(tempoMap.tempoEvents or {}),division=midi.division}
end
return Analyzer

end
modules['MIDI/Parser']=function()
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

end
modules['MIDI/TempoMap']=function()
local TempoMap = {}
TempoMap.__index = TempoMap

function TempoMap.new(midi)
    local self = setmetatable({division = midi.division, segments = {}, tempoEvents = {}}, TempoMap)
    if midi.division.type == "SMPTE" then return self end
    local tempos = {{tick = 0, us = 500000, order = 0}}
    for _, e in ipairs(midi.events) do
        if e.type == "meta" and e.subtype == "tempo" and e.microsecondsPerQuarter and e.microsecondsPerQuarter > 0 then
            tempos[#tempos + 1] = {tick = e.tick, us = e.microsecondsPerQuarter, order = #tempos}
        end
    end
    table.sort(tempos, function(a, b) if a.tick==b.tick then return a.order<b.order end;return a.tick < b.tick end)
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

end
modules['Main']=function()
local Main={}
function Main.start(ctx)
 local R=ctx.Require;local FS=R('Storage/FileSystem');local G=R('Profiles/GameProfile');local Defaults=R('ConfigDefaults');local Human=R('Performance/Humanizer');local Pipeline=R('Performance/PerformanceTimeline')
 FS.ensureFolder('MIDIQWERTY')
 -- Development config is isolated from stable; old versions can still run unchanged.
 local global=G.merge(G.copy(Defaults),FS.loadJson('MIDIQWERTY/settings-v070.json',{}))
 local gameProfiles=G.new(FS,game.GameId,game.PlaceId)
 local library=R('Storage/Library').new(FS);library.data.songOverridesV070=library.data.songOverridesV070 or {}
 local config=G.resolve(global,gameProfiles:get(),nil)
 local function normalize()for _,k in ipairs({'enabledTracks','enabledChannels'})do local map={};for n,v in pairs(config.parts[k]or {})do map[tonumber(n)or n]=v end;config.parts[k]=map end end
 normalize()
 local profiles=R('Piano/ProfileStore').new(FS,R('Piano/Profiles'))
 local adapter=R('Input/InputAdapter').new();local manager=R('Player/NoteManager').new(adapter);local scheduler=R('Player/Scheduler').new(manager)
 local state=R('State/PlayerState').new({song=false,playing=false,position=0,duration=0,speed=config.playback.speed,loop=config.playback.loopSong,hands=config.playback.mode,humanPreset=config.humanize.preset,humanStrength=config.humanize.strength,performanceSeed=0,uiMode='Full'})
 local cloud=R('Cloud/DodoProvider').new(R,FS,config.cloud)
 local current,timeline,app;local songs={};local queue={};local destroyed=false
 local function saveGlobal()FS.saveJson('MIDIQWERTY/settings-v070.json',global)end
 local function toast(text)if app then app:toast(text)end end
 local function sync()
  state:patch({song=current and current.item or false,playing=scheduler:isPlaying(),position=scheduler:getPosition(),duration=timeline and timeline.duration or 0,speed=config.playback.speed,loop=config.playback.loopSong,hands=config.playback.mode,humanPreset=config.humanize.preset,humanStrength=config.humanize.strength,performanceSeed=current and current.seed or 0})
 end
 local function resolvedProfile()return profiles:get(config.pianoProfile)or profiles:get(Defaults.pianoProfile)end
 local function rebuild(keep,newSeed)
  if not current then sync();return end
  local pos=scheduler:getPosition();local playing=scheduler:isPlaying()
  local seed=current.seed
  if newSeed or not seed then seed=config.humanize.seedMode=='Fixed' and config.humanize.fixedSeed or Human.autoSeed()end
  local ok,result=pcall(Pipeline.build,R,current.analysis,current.tempo,config,resolvedProfile(),seed)
  if not ok then toast('Falha na interpretação; reprodução anterior preservada.');warn(result);return false end
  current.seed=seed;timeline=result;scheduler:setEvents(timeline.events,timeline.duration);scheduler:setOptions(config.playback);scheduler:setSpeed(config.playback.speed);scheduler:setAB(config.playback.loopA,config.playback.loopB)
  if keep then scheduler:seek(math.min(pos,timeline.duration),false)end
  app:setTimeline(timeline,resolvedProfile());if playing then scheduler:play()end;sync();return true
 end
 local function scan()
  songs=FS.scanMidi(config.midiFolders);local ranks={};for i,v in ipairs(library.data.recent)do ranks[v.path]=i end
  for _,s in ipairs(songs)do s.favorite=library:isFavorite(s.path);s.recentRank=ranks[s.path];local m=library.data.metadata and library.data.metadata[s.path];if m then s.duration=m.duration;s.bpm=m.bpm end end
  app:setSongs(songs)
 end
 local function updateConfig(nextConfig)
  table.clear(config);G.merge(config,nextConfig);normalize()
 end
 local function selectSong(item,play)
  local data,err=FS.read(item.path);if not data then toast('Não foi possível ler o MIDI.');warn(err);return false end
  local ok,result=pcall(function()local midi=R('MIDI/Parser').parse(data);local tempo=R('MIDI/TempoMap').new(midi);return {midi=midi,tempo=tempo,analysis=R('MIDI/Analyzer').analyze(midi,tempo)}end)
  if not ok then toast('Arquivo MIDI inválido.');warn(result);return false end
  scheduler:stop();current={item=item,analysis=result.analysis,tempo=result.tempo,midi=result.midi}
  updateConfig(G.resolve(global,gameProfiles:get(),library.data.songOverridesV070[item.path]))
  if not rebuild(false,true)then return false end
  library:touch(item.path);library.data.metadata=library.data.metadata or {};library.data.metadata[item.path]={duration=result.analysis.duration,bpm=math.floor(result.analysis.bpmMin or 120)};library:save();scan()
  state:patch({metadata=string.format('%s · %d BPM · %d notas',app:time(timeline.duration),math.floor(result.analysis.bpmMin or 120),#timeline.notes)})
  app:showTab('Player');if play then scheduler:play()end;sync();toast('MIDI carregado.');return true
 end
 local function subset()
  return {pianoProfile=config.pianoProfile,playback=G.copy(config.playback),parts=G.copy(config.parts),humanize=G.copy(config.humanize)}
 end
 local cb={}
 cb.position=function()return scheduler:getPosition()end
 cb.selectSong=selectSong;cb.refresh=scan
 cb.saveUI=function(ui)global.ui=G.copy(ui);saveGlobal()end
 cb.playPause=function()
  if not current then toast('Escolha uma música.');return end
  if scheduler:isPlaying()then scheduler:pause()else scheduler:play()end;sync()
 end
 cb.seek=function(t)if current then scheduler:seek(t,scheduler:isPlaying());sync()end end
 cb.setSpeed=function(v)if type(v)~='number' or v~=v then return end;config.playback.speed=math.clamp(v,.25,2);scheduler:setSpeed(config.playback.speed);sync()end
 cb.speedStep=function(direction)cb.setSpeed(math.floor((config.playback.speed+direction*.05)*100+.5)/100)end
 cb.hands=function(v)config.playback.mode=v;rebuild(true,false);sync()end
 cb.preset=function(v)config.humanize=Human.applyPreset(config.humanize,v);rebuild(true,false);sync()end
 cb.strength=function(v)config.humanize.strength=math.clamp(v,0,1);rebuild(true,false);sync()end
 cb.newPerformance=function()if config.humanize.seedMode=='Fixed'then toast('Seed fixa: interpretação reproduzível.');else rebuild(true,true);toast('Nova interpretação criada.')end end
 cb.humanParameter=function(k,v)config.humanize=Human.applyPreset(config.humanize,config.humanize.preset);config.humanize.preset='Custom';config.humanize[k]=v;rebuild(true,false);sync()end
 cb.seed=function(v)config.humanize.seedMode=v and 'Fixed' or 'Auto';if v then config.humanize.fixedSeed=math.clamp(v,1,2147483646)end;rebuild(true,true);sync()end
 cb.track=function(index,on)config.parts.enabledTracks[index]=on;rebuild(true,false)end
 cb.split=function(n)config.parts.splitMode=n and 'Fixed' or 'Auto';config.parts.splitNote=n or 60;rebuild(true,false)end
 cb.analysis=function()return current and current.analysis end
 cb.transpose=function(v)config.playback.transpose=v;rebuild(true,false)end
 cb.range=function(v)config.playback.rangeMode=v;rebuild(true,false)end
 cb.maxKeys=function(v)config.playback.maxSimultaneousKeys=v;rebuild(true,false)end
 cb.panic=function()scheduler:pause();manager:releaseAll();sync();toast('Teclas liberadas.')end
 cb.loop=function()config.playback.loopSong=not config.playback.loopSong;scheduler:setOptions(config.playback);sync()end
 cb.markA=function()config.playback.loopA=scheduler:getPosition();toast('Início A marcado.')end
 cb.markB=function()config.playback.loopB=scheduler:getPosition();scheduler:setAB(config.playback.loopA,config.playback.loopB);toast(scheduler.loopB and 'Trecho A–B ativado.'or 'Marque B depois de A.')end
 cb.clearAB=function()config.playback.loopA=nil;config.playback.loopB=nil;scheduler:setAB(nil,nil);toast('Trecho A–B removido.')end
 cb.favorite=function(item)library:toggleFavorite(item.path);scan()end
 cb.enqueue=function(song,first)if first then table.insert(queue,1,song)else queue[#queue+1]=song end;toast('Música adicionada à fila.')end
 cb.queue=function()return queue end
 cb.removeQueue=function(i)table.remove(queue,i)end
 local function step(d)
  local index=0;for i,s in ipairs(songs)do if current and s.path==current.item.path then index=i end end
  if #songs>0 then selectSong(songs[(index-1+d)%#songs+1],scheduler:isPlaying())end
 end
 cb.next=function()if #queue>0 then selectSong(table.remove(queue,1),true)else step(1)end end
 cb.previous=function()step(-1)end
 cb.saveGame=function()local ok=gameProfiles:save(subset());toast(ok and 'Perfil do jogo salvo.'or 'Não foi possível salvar o perfil.')end
 cb.saveSong=function()if not current then toast('Selecione uma música.');return end;library.data.songOverridesV070[current.item.path]=subset();library:save();toast('Ajustes da música salvos.')end
 cb.resetOverrides=function()gameProfiles:save({});if current then library.data.songOverridesV070[current.item.path]=nil;library:save()end;updateConfig(G.copy(global));rebuild(true,false);sync();toast('Padrões globais restaurados.')end
 cb.profileCopy=function()return G.copy(resolvedProfile())end
 cb.testToken=function(token)scheduler:pause();manager:releaseAll();manager:tap(token);sync();toast('Tecla de teste enviada: '..token)end
 cb.saveCalibration=function(p)
  for n=p.lowest,p.highest do if not p.map[n]then toast('Há notas sem mapeamento neste alcance.');return false end end
  p.id='Game_'..tostring(game.GameId)..'_'..tostring(game.PlaceId);p.name='Piano deste jogo';profiles:saveProfile(p);config.pianoProfile=p.id;cb.saveGame();rebuild(true,false);return true
 end
 cb.reconnect=function()scheduler:pause();manager:releaseAll();adapter=R('Input/InputAdapter').new();manager.adapter=adapter;sync();toast('Input reinicializado.')end
 cb.exportPerformance=function()if timeline then local ok=FS.write('MIDIQWERTY/performance.csv',Pipeline.csv(timeline));toast(ok and 'Análise salva em MIDIQWERTY/performance.csv'or 'Não foi possível salvar a análise.')end end
 cb.cancelCloud=function()cloud:cancel()end
 cb.searchCloud=function(q)cloud:search(q,function(results,err)if not destroyed then app:setCloud(results,err or cloud.lastError)end end)end
 cb.download=function(song)cloud:download(song,function(path,err)if not destroyed then if path then scan();toast('MIDI baixado.')else toast(err or 'Cloud indisponível.')end end end)end
 cb.diagnostics=function()
  local c=cloud:diagnostics();local stats=scheduler.stats;local m=timeline and timeline.mapping or {};local p=timeline and timeline.stats or {}
  return string.format('Backend: %s\nCloud: %s\n%s\n\nEventos: %d\nAtrasados: %d\nDrift pico: %.2f ms\nCobertura: %.1f%%\nColisões: %d\nTiming médio: %.3f ms\nSeed: %s\n\nPrioridade: global → jogo → música\nVelocity física depende do piano/backend.\nPedal preservado nos dados; não há CC64 universal via QWERTY.',adapter.backend,c.state,c.error or '',stats.processed,stats.late,stats.driftPeakMs,(m.coverage or 0)*100,m.collisions or 0,p.averageTimingMs or 0,tostring(current and current.seed or '—'))
 end
 app=R('UI/App').new(R,state,cb,config)
 scheduler.onPosition=function()sync()end
 scheduler.onFinished=function()sync();if #queue>0 then selectSong(table.remove(queue,1),true)end end
 scan();sync()
 local public={app=app,store=state,callbacks=cb}
 function public.show()app:setMode('Full')end
 function public.hide()app:setMode('Hidden')end
 function public.stop()scheduler:stop();sync()end
 function public.state()return state.value end
 function public.destroy()destroyed=true;cloud:cancel();scheduler:stop();manager:releaseAll();app:destroy();state:destroy()end
 function public.runUITest()return R('UI/TestHarness').run(app,state,cb)end
 local env=(getgenv and getgenv())or _G;env.MIDIQWERTY=public;return public
end
return Main

end
modules['Parts/Separator']=function()
local Separator={}
local function lower(s) return string.lower(s or "") end
local leftHints={"left hand","left"," l.h","lh","bass"}; local rightHints={"right hand","right"," r.h","rh","treble","melody"}
local function containsAny(text,list) text=" "..lower(text).." "; for _,token in ipairs(list) do if string.find(text,token,1,true) then return true end end return false end
local function kmeansSplit(notes) if #notes==0 then return 60 end local c1,c2=48,72; for _=1,8 do local s1,n1,s2,n2=0,0,0,0; for _,n in ipairs(notes) do if math.abs(n.note-c1)<=math.abs(n.note-c2) then s1+=n.note;n1+=1 else s2+=n.note;n2+=1 end end; if n1>0 then c1=s1/n1 end; if n2>0 then c2=s2/n2 end end; if c1>c2 then c1,c2=c2,c1 end; return math.clamp(math.floor((c1+c2)/2+.5),48,72) end
local function groups(notes,w) local out,g={},nil; for _,n in ipairs(notes) do if not g or n.startTime-g.time>w then g={time=n.startTime,notes={}};out[#out+1]=g end;g.notes[#g.notes+1]=n end;return out end
function Separator.classify(analysis,options)
    options=options or {}; local notes=analysis.notes; local split=options.splitMode=="Fixed" and (options.splitNote or 60) or kmeansSplit(notes); local state={Left={pitch=split-7,time=-1},Right={pitch=split+7,time=-1}}; local confSum=0
    for index,n in ipairs(notes) do n.index=index;n.parts={};n.parts.track=n.track;n.parts.channel=n.channel;n.parts.percussion=n.channel==10; local info=analysis.tracks[n.track] or {}; local label=(info.name or "").." "..(info.instrument or "");local explicit;if containsAny(label,leftHints) and not containsAny(label,rightHints) then explicit="Left" end;if containsAny(label,rightHints) and not containsAny(label,leftHints) then explicit="Right" end
        local hand,confidence=explicit,1
        if not hand then local function score(which) local s=state[which];local pitchBias=which=="Left" and (n.note-split) or (split-n.note);local distance=math.abs(n.note-s.pitch);local dt=s.time<0 and 2 or math.min(n.startTime-s.time,2);return pitchBias*1.35+distance*(.38-.12*dt) end;local ls,rs=score("Left"),score("Right");hand=ls<=rs and "Left" or "Right";confidence=math.clamp(math.abs(ls-rs)/18,0,1) end
        if options.splitMode=="Fixed" then hand=n.note<(options.splitNote or 60) and "Left" or "Right" end;local correction=options.handCorrections and options.handCorrections[tostring(n.index)];if correction=="Left" or correction=="Right" then hand=correction end;n.parts.hand=hand;n.parts.handConfidence=confidence;confSum+=confidence;state[hand].pitch=n.note;state[hand].time=n.startTime
    end
    local gs=groups(notes,.035);local lm,lb
    for _,g in ipairs(gs) do table.sort(g.notes,function(a,b)return a.note<b.note end);local bass,melody=g.notes[1],g.notes[#g.notes];if #g.notes>1 then local bs=-math.huge;for _,n in ipairs(g.notes) do local cont=lm and -math.abs(n.note-lm)*.35 or 0;local s=n.note*.75+n.velocity*.12+cont;if s>bs then bs=s;melody=n end end;local low=math.huge;for _,n in ipairs(g.notes) do local cont=lb and math.abs(n.note-lb)*.25 or 0;local s=n.note+cont-n.velocity*.03;if s<low then low=s;bass=n end end end;melody.parts.melody=true;bass.parts.bass=true;lm,lb=melody.note,bass.note end
    for _,n in ipairs(notes) do n.parts.accompaniment=not n.parts.melody end
    analysis.handSplit=split;analysis.handConfidence=#notes>0 and confSum/#notes or 0;return analysis
end
function Separator.shouldInclude(n,mode,options) options=options or {};if n.parts.percussion and not options.percussion then return false end;if options.enabledTracks and next(options.enabledTracks) and options.enabledTracks[n.track]==false then return false end;if options.enabledChannels and next(options.enabledChannels) and options.enabledChannels[n.channel]==false then return false end;if mode=="Left" then return n.parts.hand=="Left" elseif mode=="Right" then return n.parts.hand=="Right" elseif mode=="Melody" then return n.parts.melody==true elseif mode=="Accompaniment" then return n.parts.accompaniment==true elseif mode=="Bass" then return n.parts.bass==true elseif type(mode)=="string" and mode:match("^Voice%d+$") then return n.parts.voice==tonumber(mode:match("%d+")) end;return true end
function Separator.filter(notes,mode,options) local out={};for _,n in ipairs(notes) do if Separator.shouldInclude(n,mode,options) then out[#out+1]=n end end;return out end
return Separator

end
modules['Parts/VoiceSeparator']=function()
local VoiceSeparator={}

function VoiceSeparator.assign(notes,window)
    window=window or .03
    local voices={}
    local groups,group,anchor={},nil,nil
    local function flush()
        if not group or #group==0 then return end
        table.sort(group,function(a,b) return a.note<b.note end)
        local used={}
        for _,n in ipairs(group) do
            local best,bestDist=nil,math.huge
            for id,v in ipairs(voices) do
                if not used[id] then
                    local gap=n.startTime-(v.time or -999)
                    local dist=math.abs(n.note-(v.pitch or n.note))+(gap>1.5 and 8 or 0)
                    if dist<bestDist then best,bestDist=id,dist end
                end
            end
            if not best or bestDist>18 then voices[#voices+1]={}; best=#voices end
            used[best]=true; voices[best].pitch=n.note; voices[best].time=n.startTime
            n.parts=n.parts or {}; n.parts.voice=best
        end
    end
    for _,n in ipairs(notes) do
        if not anchor or n.startTime-anchor<=window then anchor=anchor or n.startTime; group=group or {}; group[#group+1]=n
        else flush(); group={n}; anchor=n.startTime end
    end
    flush()
    return notes,#voices
end

return VoiceSeparator

end
modules['Performance/Articulation']=function()
local Articulation = {}

function Articulation.annotate(notes)
    local byVoice={}
    for _,n in ipairs(notes) do
        local key=string.format("%d:%d:%s",n.track or 0,n.channel or 0,n.parts and n.parts.hand or "?")
        byVoice[key]=byVoice[key] or {}; byVoice[key][#byVoice[key]+1]=n
    end
    for _,list in pairs(byVoice) do
        table.sort(list,function(a,b) return a.startTime<b.startTime end)
        for i,n in ipairs(list) do
            local nextN=list[i+1]
            local ioi=nextN and math.max(nextN.startTime-n.startTime,0.001) or n.duration
            local ratio=n.duration/math.max(ioi,0.001)
            if ratio>=1.02 then n.articulation="Legato"
            elseif ratio<=0.42 then n.articulation="Staccato"
            elseif (n.velocity or 64)>=108 then n.articulation="Accent"
            else n.articulation="Normal" end
        end
    end
    return notes
end

return Articulation

end
modules['Performance/Humanizer']=function()
local H={}
local function copy(n)local c=table.clone(n);if n.parts then c.parts=table.clone(n.parts)end;return c end
local function noise(seed,t,scale)
 local function hash(x)return (math.sin(x*12.9898+seed*.017)*43758.5453)%1*2-1 end
 local x=t/scale;local i=math.floor(x);local f=x-i;f=f*f*(3-2*f);return hash(i)*(1-f)+hash(i+1)*f
end
H.presets={
 Exact={timingMs=0,phraseMs=0,handMs=0,microMs=0,chordSpreadMs=0,rubatoMs=0,durationVariation=0,dynamicContour=0,motifVariation=0,velocityPreservation=1},
 Subtle={timingMs=3,phraseMs=5,handMs=2,microMs=.6,chordSpreadMs=4,rubatoMs=4,durationVariation=.01,dynamicContour=.15,motifVariation=.15,velocityPreservation=.95},
 Natural={timingMs=6,phraseMs=11,handMs=4,microMs=1,chordSpreadMs=9,rubatoMs=10,durationVariation=.02,dynamicContour=.35,motifVariation=.3,velocityPreservation=.9},
 Pianist={timingMs=9,phraseMs=18,handMs=6,microMs=1.3,chordSpreadMs=15,rubatoMs=17,durationVariation=.03,dynamicContour=.55,motifVariation=.6,velocityPreservation=.85},
 Expressive={timingMs=13,phraseMs=25,handMs=9,microMs=1.8,chordSpreadMs=22,rubatoMs=24,durationVariation=.05,dynamicContour=.8,motifVariation=.85,velocityPreservation=.8},
}
function H.applyPreset(settings,name)
 if name=='Very Subtle'then name='Subtle'end
 local out=table.clone(settings);out.preset=name
 if H.presets[name]then for k,v in pairs(H.presets[name])do out[k]=v end end
 return out
end
local seedCounter=0
function H.autoSeed()seedCounter+=1;return (math.floor(os.clock()*100000)+os.time()+seedCounter*7919)%2147483646+1 end
function H.generate(notes,settings,context)
 context=context or {};settings=settings or {};local c=H.applyPreset(settings,settings.preset or 'Pianist');local s=math.clamp(c.strength or 1,0,1)
 if c.enabled==false or c.preset=='Exact'then s=0 end
 local seed=context.seed or c.fixedSeed or 12345;local out={};local groups={};local group
 for _,n in ipairs(notes)do
  if not group or n.startTime-group.time>(context.chordWindowMs or 9)/1000 then group={time=n.startTime,notes={}};groups[#groups+1]=group end
  group.notes[#group.notes+1]=n
 end
 local previous={};local sum,sq,peak=0,0,0;local appliedRolls=0
 for gi,g in ipairs(groups)do
  local byHand={Left={},Right={}}
  for _,n in ipairs(g.notes)do local h=n.parts and n.parts.hand or 'Right';byHand[h][#byHand[h]+1]=n end
  for _,hand in ipairs({'Left','Right'})do
   local list=byHand[hand];table.sort(list,function(a,b)return a.note<b.note end)
   local structural=#byHand.Left>0 and #byHand.Right>0
   for j,n in ipairs(list)do
    local x=copy(n);local t=n.startTime;local bpm=n.localBpm or context.bpm or 120;local beat=60/math.max(20,bpm)
    local p=math.clamp((t-(n.phraseStart or t))/math.max(.01,(n.phraseEnd or n.endTime)-(n.phraseStart or t)),0,1)
    local occurrence=n.motifOccurrence or 1;local motif=1+(((occurrence-1)%3)-1)*.18*(c.motifVariation or 0)
    local nextGroup=groups[gi+1];local gap=nextGroup and nextGroup.time-t or beat;local density=math.clamp(gap/beat*4,.3,1)
    local scale=math.clamp(beat/.5,.45,1.5);local localBeat=n.beat or t/beat
    local anchor=structural or math.abs(localBeat-math.floor(localBeat+.5))<.02
    local global=noise(seed,t,8)*(c.timingMs or 0)
    local phrase=(math.sin(p*math.pi*2)*-.45+math.sin(p*math.pi)*-.3)*(c.phraseMs or 0)*motif
    local rubato=(p>.72 and ((p-.72)/.28)^2 or 0)*(c.rubatoMs or 0)*motif
    local handCurve=noise(seed+(hand=='Left' and 101 or 307),t,1.8)*(c.handMs or 0)*(anchor and .18 or 1)
    local micro=noise(seed+911+(n.index or gi),t,.1)*(c.microMs or 0)*density
    local leap=previous[hand] and math.max(0,math.abs(n.note-previous[hand])-7)*.18 or 0;previous[hand]=n.note
    local roll=0
    -- Only selected, non-structural, sufficiently spacious chords; direction stable per phrase/hand.
    if #list>=3 and not anchor and gap>beat*.22 and (n.phraseId or 1)%3~=0 then
     local direction=hand=='Left' and 1 or ((n.phraseId or 1)%2==0 and -1 or 1)
     roll=((j-1)/(#list-1)-.5)*direction*(c.chordSpreadMs or 0)*density;if j==1 then appliedRolls+=1 end
    end
    local offset=(global+phrase+rubato+handCurve+micro+math.min(3,leap)+roll)*s*scale
    local cap=math.min(65,math.max(1,gap*280));offset=math.clamp(offset,-cap,cap)
    x.originalStartTime=t;x.originalEndTime=n.endTime;x.originalKeyReleaseTime=n.keyReleaseTime or n.endTime
    x.originalVelocity=n.velocity;x.startTime=math.max(0,t+offset/1000);local delta=x.startTime-t
    local factor=1+(c.durationVariation or 0)*s*math.sin(p*math.pi)*(n.articulation=='Staccato' and -.5 or .5)
    x.keyReleaseTime=x.startTime+math.max(.001,((n.keyReleaseTime or n.endTime)-t)*factor)
    x.endTime=math.max(x.keyReleaseTime,n.endTime+delta);x.duration=x.endTime-x.startTime
    local v=n.velocity or 64;local normalized=v>1 and v/127 or v
    local dynamic=(math.sin(p*math.pi)*.08-p*.025)*(c.dynamicContour or 0)*s*motif
    x.expressiveVelocity=math.clamp(normalized+dynamic*(1-(c.velocityPreservation or .9)),0,1)
    x.humanOffsetMs=delta*1000;x.chordId=gi
    x.layers={GlobalTempoCurve=global*s*scale,PhraseTempoCurve=(phrase+rubato)*s*scale,HandCurve=handCurve*s*scale,ChordInterpretation=roll*s*scale,MicroTiming=micro*s*scale,PhraseDynamics=dynamic}
    if s==0 then x=copy(n);x.originalStartTime=t;x.originalEndTime=n.endTime;x.originalKeyReleaseTime=n.keyReleaseTime or n.endTime;x.originalVelocity=n.velocity;x.humanOffsetMs=0;x.chordId=gi;x.expressiveVelocity=normalized end
    local a=math.abs(x.humanOffsetMs);sum+=a;sq+=a*a;peak=math.max(peak,a);out[#out+1]=x
   end
  end
 end
 table.sort(out,function(a,b)if a.startTime==b.startTime then return (a.index or 0)<(b.index or 0)end;return a.startTime<b.startTime end)
 local mean=#out>0 and sum/#out or 0
 return out,{seed=seed,preset=c.preset,strength=s,averageTimingMs=mean,maxTimingMs=peak,stdTimingMs=math.sqrt(math.max(0,(#out>0 and sq/#out or 0)-mean*mean)),humanizedCount=s>0 and #out or 0,chordRolls=s>0 and appliedRolls or 0}
end
return H

end
modules['Performance/PerformanceTimeline']=function()
local T={}
function T.build(R,analysis,tempo,config,profile,seed)
 R('Parts/Separator').classify(analysis,config.parts)
 R('Parts/VoiceSeparator').assign(analysis.notes,.03)
 R('Performance/Articulation').annotate(analysis.notes)
 R('Performance/PhraseEngine').annotate(analysis.notes,analysis.bpmMin or 120,tempo,analysis.timeSignatures,analysis.division)
 local filtered=R('Parts/Separator').filter(analysis.notes,config.playback.mode,config.parts)
 if config.playback.quantization~='Off' then filtered=R('Performance/Quantizer').apply(filtered,analysis.division,tempo,config.playback.quantization)end
 local simplified,ss=R('Performance/Simplifier').apply(filtered,config.playback)
 local notes,stats=R('Performance/Humanizer').generate(simplified,config.humanize,{seed=seed,bpm=analysis.bpmMin or 120,chordWindowMs=config.playback.chordWindowMs})
 local mapped,mapStats=R('Piano/Mapper').mapNotes(notes,profile,config.playback)
 local events=R('Piano/Mapper').toEvents(mapped,config.playback)
 local duration=analysis.duration or 0
 for _,e in ipairs(events)do
  if e.note then
   e.note.executionStart=e.time
   if e.action=='strike' or e.action=='tap' then e.note.executionEnd=e.time+(e.holdMs or 18)/1000 end
  end
  duration=math.max(duration,e.time+(e.holdMs or 0)/1000)
 end
 for _,n in ipairs(mapped)do n.executionStart=n.startTime;n.executionEnd=n.executionEnd or n.keyReleaseTime or n.endTime end
 return {notes=mapped,events=events,duration=duration,seed=seed,stats=stats,mapping=mapStats,simplification=ss,originalCount=#analysis.notes,filteredCount=#filtered}
end
function T.csv(timeline)
 local lines={'originalStart,performanceStart,deltaMs,originalIOI,performanceIOI,hand,phrase,chord,velocity,holdMs'}
 local prevOriginal,prevFinal
 for _,n in ipairs(timeline.notes)do
  local o=n.originalStartTime or n.startTime
  lines[#lines+1]=string.format('%.6f,%.6f,%.3f,%.6f,%.6f,%s,%s,%s,%.4f,%.3f',o,n.startTime,(n.startTime-o)*1000,prevOriginal and o-prevOriginal or 0,prevFinal and n.startTime-prevFinal or 0,n.parts and n.parts.hand or 'Right',tostring(n.phraseId or 0),tostring(n.chordId or 0),n.expressiveVelocity or n.velocity or 0,((n.executionEnd or n.endTime)-n.startTime)*1000)
  prevOriginal,prevFinal=o,n.startTime
 end
 return table.concat(lines,'\n')
end
return T

end
modules['Performance/PhraseEngine']=function()
local P={}
function P.annotate(notes,bpm,tempo,meterEvents,division)
 local ppqn=division and division.ppqn
 local phrases={};local id=0;local startBeat=-1;local lastEnd=-999;local numerator,denominator=4,4;local meterIndex=1;local meters=meterEvents or {}
 for _,n in ipairs(notes)do
  while meters[meterIndex] and (meters[meterIndex].tick or 0)<=(n.startTick or 0)do local m=meters[meterIndex];numerator=m.numerator or 4;denominator=m.denominator or 4;meterIndex+=1 end
  local b=tempo and tempo:bpmAtTick(n.startTick or 0) or bpm or 120
  n.localBpm=b or bpm or 120;n.beat=ppqn and (n.startTick or 0)/ppqn or n.startTime*n.localBpm/60
  n.meter=numerator;n.beatsPerBar=numerator*4/denominator;n.subdivision=math.floor((n.beat%1)*4+.5)%4
  if id==0 or n.startTime-lastEnd>60/n.localBpm*1.2 or n.beat-startBeat>=n.beatsPerBar*2 then id+=1;startBeat=n.beat;phrases[id]={start=n.startTime,finish=n.endTime,notes={}}end
  n.phraseId=id;local p=phrases[id];p.finish=math.max(p.finish,n.endTime);p.notes[#p.notes+1]=n
  lastEnd=math.max(lastEnd,n.keyReleaseTime or n.endTime)
 end
 -- Transposition-invariant melody interval + rhythm fingerprint, phrase aligned.
 local motifs={}
 for _,p in ipairs(phrases)do
  local melody={};for _,n in ipairs(p.notes)do if n.parts and n.parts.melody then melody[#melody+1]=n end end
  local signature={};for i=2,math.min(#melody,13)do signature[#signature+1]=tostring(melody[i].note-melody[i-1].note)..':'..tostring(math.floor((melody[i].beat-melody[i-1].beat)*8+.5))end
  local key=#signature>=3 and table.concat(signature,',') or 'unique:'..tostring(p.start)
  motifs[key]=(motifs[key] or 0)+1
  for _,n in ipairs(p.notes)do n.motifId=key;n.motifOccurrence=motifs[key];n.phraseStart=p.start;n.phraseEnd=p.finish end
 end
 return notes,id
end
return P

end
modules['Performance/Quantizer']=function()
local Quantizer={}
local denominators={["1/4"]=4,["1/8"]=8,["1/16"]=16,["1/32"]=32}

function Quantizer.apply(notes,division,tempoMap,mode)
    local denom=denominators[mode]
    if not denom or division.type~="PPQN" then return notes end
    local step=division.ppqn*4/denom
    local out={}
    for _,n in ipairs(notes) do
        local c={}; for k,v in pairs(n) do c[k]=v end
        local st=math.floor(n.startTick/step+.5)*step
        local et=math.max(st+1,math.floor(n.endTick/step+.5)*step)
        c.startTime=tempoMap:tickToSeconds(st); c.endTime=tempoMap:tickToSeconds(et); c.duration=math.max(.001,c.endTime-c.startTime)
        out[#out+1]=c
    end
    table.sort(out,function(a,b) return a.startTime<b.startTime end)
    return out
end
return Quantizer

end
modules['Performance/Simplifier']=function()
local Simplifier={}

local function importance(n)
    local score=(n.velocity or 64)*0.2
    if n.parts then
        if n.parts.melody then score+=120 end
        if n.parts.bass then score+=100 end
        if n.parts.hand=="Right" then score+=4 end
    end
    score+=n.note*0.03
    return score
end

function Simplifier.apply(notes,settings)
    settings=settings or {}
    local maxKeys=math.clamp(settings.maxSimultaneousKeys or 10,1,16)
    local window=(settings.chordWindowMs or 10)/1000
    local grouped,out,group,anchor={},{},{},nil
    local function flush()
        if #group<=maxKeys then for _,n in ipairs(group) do out[#out+1]=n end
        else
            table.sort(group,function(a,b) return importance(a)>importance(b) end)
            for i=1,maxKeys do out[#out+1]=group[i] end
        end
        group={}
    end
    for _,n in ipairs(notes) do
        if not anchor or n.startTime-anchor<=window then anchor=anchor or n.startTime; group[#group+1]=n
        else flush(); anchor=n.startTime; group[#group+1]=n end
    end
    flush()
    table.sort(out,function(a,b) return a.startTime==b.startTime and a.note<b.note or a.startTime<b.startTime end)

    local maxNps=settings.maxNotesPerSecond or 0
    if maxNps>0 then
        local buckets,kept={},{}
        for _,n in ipairs(out) do
            local b=math.floor(n.startTime)
            buckets[b]=buckets[b] or {}; buckets[b][#buckets[b]+1]=n
        end
        for _,list in pairs(buckets) do
            if #list>maxNps then table.sort(list,function(a,b) return importance(a)>importance(b) end) end
            for i=1,math.min(#list,maxNps) do kept[#kept+1]=list[i] end
        end
        out=kept; table.sort(out,function(a,b) return a.startTime<b.startTime end)
    end
    return out,{before=#notes,after=#out,removed=#notes-#out}
end

return Simplifier

end
modules['Piano/Mapper']=function()
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

end
modules['Piano/ProfileStore']=function()
local ProfileStore={}; ProfileStore.__index=ProfileStore
local HttpService=game:GetService("HttpService")
function ProfileStore.new(FS,builtin)
    local self=setmetatable({FS=FS,builtin=builtin,path="MIDIQWERTY/profiles.json",custom={}},ProfileStore)
    local raw=FS.loadJson(self.path,{})
    for id,p in pairs(raw) do
        local map={}; for k,v in pairs(p.map or {}) do map[tonumber(k) or k]=v end
        p.map=map; self.custom[id]=p
    end
    return self
end
function ProfileStore:get(id) return self.custom[id] or self.builtin.get(id) end
function ProfileStore:saveProfile(profile)
    assert(type(profile)=="table" and profile.id and profile.map,"Invalid profile")
    self.custom[profile.id]=profile
    local serial={}; for id,p in pairs(self.custom) do local m={}; for k,v in pairs(p.map) do m[tostring(k)]=v end; serial[id]={id=p.id,name=p.name,lowest=p.lowest,highest=p.highest,map=m} end
    self.FS.saveJson(self.path,serial); return true
end
function ProfileStore:setMapping(id,note,token)
    local base=self:get(id); if not base then return false end
    local p={id=id,name=base.name,lowest=base.lowest,highest=base.highest,map={}}; for k,v in pairs(base.map) do p.map[k]=v end
    p.map[note]=token; return self:saveProfile(p)
end
return ProfileStore

end
modules['Piano/Profiles']=function()
local Profiles = {}

-- Standard Roblox / Virtual Piano layout: 36 white keys laid out as
-- 1234567890 qwertyuiop asdfghjkl zxcvbnm, with Shift producing the
-- chromatic black key where that piano key actually has a sharp.
-- The musical range is C2..C7 (MIDI 36..96), exactly 61 chromatic notes.
local WHITE = "1234567890qwertyuiopasdfghjklzxcvbnm"
local WHITE_PC = {[0]=true,[2]=true,[4]=true,[5]=true,[7]=true,[9]=true,[11]=true}
local SHIFT_DIGIT = { ["1"]="!",["2"]="@",["3"]="#",["4"]="$",["5"]="%",["6"]="^",["7"]="&",["8"]="*",["9"]="(",["0"]=")" }

local function shifted(token)
    return SHIFT_DIGIT[token] or string.upper(token)
end

local function buildStandardMap(lowest, highest)
    local map, whiteIndex, previousWhite = {}, 1, nil
    for midi = lowest, highest do
        local pc = midi % 12
        if WHITE_PC[pc] then
            local token = string.sub(WHITE, whiteIndex, whiteIndex)
            assert(token ~= "", "Standard piano profile exhausted white keys")
            map[midi] = token
            previousWhite = token
            whiteIndex += 1
        else
            assert(previousWhite, "Black key cannot precede first white key")
            map[midi] = shifted(previousWhite)
        end
    end
    assert(whiteIndex - 1 == #WHITE, "Standard piano profile did not consume exactly 36 white keys")
    return map
end

Profiles.RobloxVirtualPiano61 = {
    id = "RobloxVirtualPiano61",
    name = "Roblox / Virtual Piano 61 (C2-C7)",
    lowest = 36,
    highest = 96,
    map = buildStandardMap(36, 96),
}

-- Compatibility alias for older saved configs. It intentionally points at
-- the corrected 61-note profile rather than the old erroneous 69-note map.
Profiles.VirtualPiano61 = Profiles.RobloxVirtualPiano61

function Profiles.get(name)
    return Profiles[name] or Profiles.RobloxVirtualPiano61
end

function Profiles.list()
    local out, seen = {}, {}
    for k, v in pairs(Profiles) do
        if type(v) == "table" and v.map and not seen[v] then
            seen[v] = true
            out[#out + 1] = {id = v.id or k, name = v.name}
        end
    end
    table.sort(out, function(a,b) return a.name < b.name end)
    return out
end

return Profiles

end
modules['Player/NoteManager']=function()
local NoteManager={};NoteManager.__index=NoteManager
function NoteManager.new(adapter)return setmetatable({adapter=adapter,refs={},tokens={},activeCount=0},NoteManager)end
function NoteManager:strike(token,opts)return self.adapter:strike(token,opts)end
function NoteManager:tap(token)return self.adapter:tap(token)end
function NoteManager:down(token)
    local id=self.adapter:physicalId(token);local count=self.refs[id] or 0;self.refs[id]=count+1;self.tokens[id]=token
    if count==0 then local ok,err=self.adapter:press(token);if not ok then self.refs[id]=nil;self.tokens[id]=nil;return false,err end;self.activeCount+=1 end
    return true
end
function NoteManager:up(token)
    local id=self.adapter:physicalId(token);local count=self.refs[id] or 0;if count<=0 then return true end
    count-=1
    if count==0 then self.refs[id]=nil;local original=self.tokens[id] or token;self.tokens[id]=nil;self.adapter:release(original);self.activeCount=math.max(0,self.activeCount-1) else self.refs[id]=count end
    return true
end
function NoteManager:releaseAll()
    for id,token in pairs(self.tokens)do pcall(function()self.adapter:release(token)end);self.refs[id],self.tokens[id]=nil,nil end
    if self.adapter.releaseExpressive then pcall(function()self.adapter:releaseExpressive()end)end
    if self.adapter.releaseModifiers then pcall(function()self.adapter:releaseModifiers()end)end
    self.activeCount=0
end
return NoteManager

end
modules['Player/Scheduler']=function()
local Scheduler={}
Scheduler.__index=Scheduler
local RunService=game:GetService("RunService")

local function lowerBound(events,t)
    local lo,hi=1,#events+1
    while lo<hi do
        local mid=math.floor((lo+hi)/2)
        if mid<=#events and events[mid].time<t then lo=mid+1 else hi=mid end
    end
    return lo
end

function Scheduler.new(noteManager)
    local s=setmetatable({},Scheduler)
    s.noteManager=noteManager;s.events={};s.index=1;s.duration=0;s.position=0;s.speed=1;s.playing=false;s.paused=false
    s.loopSong=false;s.loopA=nil;s.loopB=nil;s.maxLateMs=140;s.lateMode="CatchUp"
    s.stats={processed=0,skipped=0,late=0,driftSumMs=0,driftPeakMs=0,catchups=0}
    s.lastUi=0;s.uiInterval=.05
    return s
end

function Scheduler:setEvents(events,duration,rebuildAt)
    self:stop(false);self.events=events or {};self.duration=duration or 0;self.rebuildAt=rebuildAt;self.index=1;self.position=0
    self.stats={processed=0,skipped=0,late=0,driftSumMs=0,driftPeakMs=0,catchups=0}
end
function Scheduler:setOptions(o)
    o=o or {};self.maxLateMs=o.maxLateMs or self.maxLateMs;self.lateMode=o.lateMode or self.lateMode;self.loopSong=o.loopSong==true
end
function Scheduler:setAB(a,b)
    if a and b and b>a then self.loopA,self.loopB=math.clamp(a,0,self.duration),math.clamp(b,0,self.duration)else self.loopA,self.loopB=nil,nil end
end
function Scheduler:_clockPosition()
    if not self.playing then return self.position end
    return self.positionAnchor+(os.clock()-self.clockAnchor)*self.speed
end
function Scheduler:_shouldSkip(e,lateMs)
    if self.lateMode=="CatchUp" then return false end
    if (e.action~="down" and e.action~="tap" and e.action~="strike") or lateMs<=self.maxLateMs then return false end
    if self.lateMode=="SkipLate" then return true end
    local n=e.note;if n and n.parts and (n.parts.melody or n.parts.bass)then return false end
    local v=e.velocity or(n and n.velocity)or .5;if v>1 then v=v/127 end;if v>=.82 then return false end
    return lateMs>self.maxLateMs*2.5
end
function Scheduler:_process(p)
    while self.index<=#self.events do
        local e=self.events[self.index];if e.time>p then break end
        local late=math.max(0,(p-e.time)*1000)
        self.stats.processed+=1;self.stats.driftSumMs+=late;self.stats.driftPeakMs=math.max(self.stats.driftPeakMs,late);if late>self.maxLateMs then self.stats.late+=1 end
        if self:_shouldSkip(e,late) then self.stats.skipped+=1
        elseif e.action=="strike" then self.noteManager:strike(e.token,{velocity=e.velocity,holdMs=e.holdMs and math.max(6,(e.holdMs-math.max(0,p-e.time)*1000)/self.speed),nativeVelocity=e.nativeVelocity,note=e.note})
        elseif e.action=="tap" then self.noteManager:tap(e.token)
        elseif e.action=="down" then self.noteManager:down(e.token)
        else self.noteManager:up(e.token) end
        if late>self.maxLateMs and(e.action=="strike" or e.action=="tap" or e.action=="down")then self.stats.catchups+=1 end
        if self.onEvent then pcall(self.onEvent,e)end
        self.index+=1
    end
end
function Scheduler:_connect()
    if self.connection then self.connection:Disconnect()end
    self.connection=RunService.Heartbeat:Connect(function()
        if not self.playing then return end
        local p=self:_clockPosition();self:_process(self.loopB and math.min(p,self.loopB-.000001) or p)
        if self.loopB and p>=self.loopB then self:seek(self.loopA or 0,true);return end
        local now=os.clock()
        if self.onPosition and now-self.lastUi>=self.uiInterval then self.lastUi=now;self.onPosition(math.min(p,self.duration),self.duration,self.stats)end
        if p>=self.duration then
            if self.loopSong and self.duration>0 then self:seek(0,true)
            else
                self:stop(false);self.position=self.duration
                if self.onPosition then self.onPosition(self.duration,self.duration,self.stats)end
                if self.onFinished then self.onFinished()end
            end
        end
    end)
end
function Scheduler:play()
    if self.playing then return end
    if self.position>=self.duration then self.position,self.index=0,1 end
    self.noteManager:releaseAll()
    if self.position>0 then self:_restore(self.position)end
    self.positionAnchor,self.clockAnchor=self.position,os.clock();self.playing,self.paused=true,false;self.lastUi=0;self:_connect()
end
function Scheduler:pause()
    if not self.playing then return end
    self.position=math.min(self:_clockPosition(),self.duration);self.playing,self.paused=false,true
    if self.connection then self.connection:Disconnect();self.connection=nil end
    self.noteManager:releaseAll();if self.onPosition then self.onPosition(self.position,self.duration,self.stats)end
end
function Scheduler:stop(reset)
    if self.playing then self.position=math.min(self:_clockPosition(),self.duration)end
    self.playing,self.paused=false,false;if self.connection then self.connection:Disconnect();self.connection=nil end
    self.noteManager:releaseAll();if reset~=false then self.position,self.index=0,1 end
end
function Scheduler:seek(pos,keep)
    local was=keep==nil and self.playing or keep
    if self.playing then self:pause()else self.noteManager:releaseAll()end
    self.position=math.clamp(pos or 0,0,self.duration);self.index=lowerBound(self.events,self.position)
    if was then self:play()elseif self.onPosition then self.onPosition(self.position,self.duration,self.stats)end
end
function Scheduler:_restore(pos)
    self.noteManager:releaseAll()
    -- Scan only the bounded physical hold horizon, not the full piece.
    local first=lowerBound(self.events,math.max(0,pos-2.001))
    local active={}
    for i=first,#self.events do
        local e=self.events[i];if e.time>=pos then break end
        local id=self.noteManager.adapter:physicalId(e.token)
        if e.action=="strike" and e.time+(e.holdMs or 0)/1000>pos then active[id]=e end
    end
    for _,e in pairs(active)do self.noteManager:strike(e.token,{velocity=e.velocity,holdMs=(e.time+e.holdMs/1000-pos)*1000/self.speed,nativeVelocity=e.nativeVelocity,note=e.note})end
    if self.rebuildAt then self.rebuildAt(pos)end
end
function Scheduler:setSpeed(v)
    v=math.clamp(v or 1,.25,2)
    if self.playing then self.position=self:_clockPosition();self.positionAnchor,self.clockAnchor=self.position,os.clock()end
    self.speed=v
    if self.playing then self:_restore(self.position)end
end
function Scheduler:isPlaying()return self.playing end
function Scheduler:getPosition()return self:_clockPosition()end
return Scheduler

end
modules['Profiles/GameProfile']=function()
local G={};G.__index=G
function G.copy(v)if type(v)~='table' then return v end;local o={};for k,x in pairs(v)do o[k]=G.copy(x)end;return o end
function G.merge(a,b)
 for k,v in pairs(b or {})do
  if type(v)=='table' and type(a[k])=='table' and k~='enabledTracks' and k~='enabledChannels' and k~='handCorrections' then G.merge(a[k],v)else a[k]=G.copy(v)end
 end
 return a
end
function G.resolve(global,gameProfile,song)return G.merge(G.merge(G.copy(global),gameProfile),song)end
function G.new(FS,gameId,placeId)
 return setmetatable({FS=FS,path='MIDIQWERTY/game-profiles.json',key=tostring(gameId)..':'..tostring(placeId),data=FS.loadJson('MIDIQWERTY/game-profiles.json',{})},G)
end
function G:get()return self.data[self.key] or {}end
function G:save(settings)self.data[self.key]=G.copy(settings);return self.FS.saveJson(self.path,self.data)end
return G

end
modules['State/PlayerState']=function()
local State={};State.__index=State
function State.new(initial)return setmetatable({value=initial or {},listeners={},revision=0},State)end
function State:patch(values)
 for k,v in pairs(values)do self.value[k]=v end
 self.revision+=1
 for _,fn in pairs(self.listeners)do fn(self.value,self.revision)end
end
function State:subscribe(fn)
 local token={};self.listeners[token]=fn;fn(self.value,self.revision)
 return function()self.listeners[token]=nil end
end
function State:destroy()table.clear(self.listeners)end
return State

end
modules['Storage/Cache']=function()
local Cache={}
local HttpService=game:GetService("HttpService")
local function checksum(data)local h=2166136261;for i=1,#data do h=bit32.bxor(h,string.byte(data,i));h=(h*16777619)%4294967296 end;return string.format("%08x_%d",h,#data) end
function Cache.key(data)return checksum(data) end
function Cache.path(key)return "MIDIQWERTY/cache/"..key..".json" end
local function sanitize(a)
    local out={duration=a.duration,noteCount=a.noteCount,pitchMin=a.pitchMin,pitchMax=a.pitchMax,peakPolyphony=a.peakPolyphony,bpmMin=a.bpmMin,bpmMax=a.bpmMax,tempoChanges=a.tempoChanges,division=a.division,notes={},tracks={},pedalEvents={},timeSignatures={}}
    for _,n in ipairs(a.notes or {}) do out.notes[#out.notes+1]={note=n.note,velocity=n.velocity,startTick=n.startTick,endTick=n.endTick,startTime=n.startTime,endTime=n.endTime,duration=n.duration,track=n.track,channel=n.channel,program=n.program,dangling=n.dangling,sustained=n.sustained,keyReleaseTime=n.keyReleaseTime} end
    for i,t in ipairs(a.tracks or {}) do local ch={};for k,v in pairs(t.channels or {}) do if v then ch[#ch+1]=tonumber(k) or k end end;out.tracks[i]={index=t.index,name=t.name,instrument=t.instrument,noteCount=t.noteCount,channels=ch} end
    for _,p in ipairs(a.pedalEvents or {}) do out.pedalEvents[#out.pedalEvents+1]={time=p.time,tick=p.tick,track=p.track,channel=p.channel,down=p.down,value=p.value} end
    for _,s in ipairs(a.timeSignatures or {}) do out.timeSignatures[#out.timeSignatures+1]={time=s.time,tick=s.tick,numerator=s.numerator,denominator=s.denominator} end
    return out
end
local function restore(a)
    for _,t in ipairs(a.tracks or {}) do local set={};for _,ch in ipairs(t.channels or {}) do set[tonumber(ch) or ch]=true end;t.channels=set end
    return a
end
function Cache.load(FS,key)local raw=FS.read(Cache.path(key));if not raw then return nil end;local ok,v=pcall(HttpService.JSONDecode,HttpService,raw);if not ok or type(v)~="table" or v.cacheVersion~=2 then return nil end;return restore(v.analysis) end
function Cache.save(FS,key,analysis)FS.ensureFolder("MIDIQWERTY/cache");local ok,raw=pcall(HttpService.JSONEncode,HttpService,{cacheVersion=2,analysis=sanitize(analysis)});if not ok then return false end;return FS.write(Cache.path(key),raw) end
return Cache

end
modules['Storage/FileSystem']=function()
local FileSystem = {}

local function fn(name)
    local env = (getgenv and getgenv()) or _G
    local value = rawget(env, name) or rawget(_G, name)
    return type(value) == "function" and value or nil
end

function FileSystem.capabilities()
    return {
        readfile = fn("readfile") ~= nil,
        writefile = fn("writefile") ~= nil,
        listfiles = fn("listfiles") ~= nil,
        isfile = fn("isfile") ~= nil,
        isfolder = fn("isfolder") ~= nil,
        makefolder = fn("makefolder") ~= nil,
    }
end

function FileSystem.ensureFolder(path)
    local isfolder, makefolder = fn("isfolder"), fn("makefolder")
    if isfolder and isfolder(path) then return true end
    if not makefolder then return false end
    local ok = pcall(makefolder, path)
    return ok
end

function FileSystem.read(path)
    local readfile = fn("readfile")
    if not readfile then return nil, "readfile unavailable" end
    local ok, data = pcall(readfile, path)
    if not ok then return nil, tostring(data) end
    return data
end

function FileSystem.write(path, data)
    local writefile = fn("writefile")
    if not writefile then return false, "writefile unavailable" end
    local ok, err = pcall(writefile, path, data)
    return ok, ok and nil or tostring(err)
end

local function normalizedExtension(path)
    return string.lower(path:match("%.([^%./\\]+)$") or "")
end

function FileSystem.scanMidi(folders)
    local listfiles, isfolder = fn("listfiles"), fn("isfolder")
    if not listfiles then return {}, "listfiles unavailable" end
    local found, seen = {}, {}
    for _, folder in ipairs(folders or {}) do
        local exists = true
        if isfolder then
            local ok, result = pcall(isfolder, folder)
            exists = ok and result
        end
        if exists then
            local ok, files = pcall(listfiles, folder)
            if ok and type(files) == "table" then
                for _, path in ipairs(files) do
                    local ext = normalizedExtension(path)
                    if (ext == "mid" or ext == "midi") and not seen[path] then
                        seen[path] = true
                        found[#found + 1] = {
                            path = path,
                            name = path:match("([^/\\]+)$") or path,
                        }
                    end
                end
            end
        end
    end
    table.sort(found, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
    return found
end

function FileSystem.loadJson(path, fallback)
    local HttpService = game:GetService("HttpService")
    local data = FileSystem.read(path)
    if not data then return fallback end
    local ok, decoded = pcall(HttpService.JSONDecode, HttpService, data)
    return ok and decoded or fallback
end

function FileSystem.saveJson(path, value)
    local HttpService = game:GetService("HttpService")
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, value)
    if not ok then return false, tostring(encoded) end
    return FileSystem.write(path, encoded)
end

return FileSystem

end
modules['Storage/Library']=function()
local Library={}; Library.__index=Library
function Library.new(FS)
    local self=setmetatable({FS=FS,path="MIDIQWERTY/library.json"},Library)
    self.data=FS.loadJson(self.path,{favorites={},recent={},history={},songOverrides={},playlists={}})
    return self
end
function Library:save() self.FS.saveJson(self.path,self.data) end
function Library:isFavorite(path) return self.data.favorites[path]==true end
function Library:toggleFavorite(path) self.data.favorites[path]=not self:isFavorite(path); self:save(); return self.data.favorites[path] end
function Library:touch(path)
    local r={path=path,time=os.time()}; local out={r}
    for _,x in ipairs(self.data.recent) do if x.path~=path and #out<30 then out[#out+1]=x end end
    self.data.recent=out; local h=self.data.history[path] or {plays=0,totalSeconds=0}; h.plays+=1; h.lastPlayed=os.time(); self.data.history[path]=h; self:save()
end
function Library:addPlayedSeconds(path,seconds) local h=self.data.history[path] or {plays=0,totalSeconds=0}; h.totalSeconds=(h.totalSeconds or 0)+math.max(0,seconds or 0); self.data.history[path]=h; self:save() end
function Library:getOverride(path) return self.data.songOverrides[path] or {} end
function Library:setOverride(path,key,value) self.data.songOverrides[path]=self.data.songOverrides[path] or {}; self.data.songOverrides[path][key]=value; self:save() end
return Library

end
modules['UI/App']=function()
local App={};App.__index=App
function App.new(R,state,cb,config)
 local C=R('UI/Components');local Layout=R('UI/Layout');local UIS=game:GetService('UserInputService');local Run=game:GetService('RunService');local Tween=game:GetService('TweenService')
 local self=setmetatable({R=R,C=C,state=state,cb=cb,config=config,windows={},controls={},subscriptions={},connections={},songs={},cloudSongs={},filter='All',source='Local',tab='Library',mode='Full',lastMode='Compact',rolls={},actions={},modal=nil},App)
 self.router=R('UI/InputRouter').new(UIS)
 local gui=C.new('ScreenGui',nil,{Name='MIDIQWERTY_GLASS',ResetOnSpawn=false,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=20000})
 local parent=(gethui and gethui())or game:GetService('CoreGui');if not pcall(function()gui.Parent=parent end)then gui.Parent=game:GetService('Players').LocalPlayer:WaitForChild('PlayerGui')end;self.gui=gui
 self.root=C.new('Frame',gui,{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)})
 local function listen(fn)local off=state:subscribe(fn);self.subscriptions[#self.subscriptions+1]=off end
 local function button(parent,text,fn,primary)local b=C.button(parent,text,fn,primary);return b end
 local function bindDrag(handle,window,mode,tap)
  local origin
  self.router:bind(handle,{begin=function()origin=window.Position end,move=function(p,drag)
   if not drag then return end;local start=self.router.owner.start;local v=self.root.AbsoluteSize
   local x,y=Layout.clamp(origin.X.Offset+p.X-start.X,origin.Y.Offset+p.Y-start.Y,window.AbsoluteSize.X,window.AbsoluteSize.Y,v.X,v.Y);window.Position=UDim2.fromOffset(x,y)
  end,finish=function(_,drag)
   if drag then local v=self.root.AbsoluteSize;config.ui.positions=config.ui.positions or {};config.ui.positions[mode]=Layout.normalized(window.Position.X.Offset,window.Position.Y.Offset,window.AbsoluteSize.X,window.AbsoluteSize.Y,v.X,v.Y);cb.saveUI(config.ui)
   elseif tap then tap()end
  end})
 end
 local function window(mode)
  local w=C.surface(self.root,{Name=mode,Visible=false});self.windows[mode]=w
  local header=C.row(w,48);header.Active=true;header.Position=UDim2.fromOffset(12,4);header.Size=UDim2.new(1,-24,0,48);bindDrag(header,w,mode)
  return w,header
 end
 local full,header=window('Full')
 local brand=C.label(header,'MIDI / QWERTY',15);brand.Font=Enum.Font.GothamBold;brand.Size=UDim2.new(1,-146,1,0)
 local compactButton=button(header,'▣',function()self:setMode('Compact')end);compactButton.Position=UDim2.new(1,-140,0,2)
 local miniButton=button(header,'—',function()self:setMode('Mini')end);miniButton.Position=UDim2.new(1,-92,0,2)
 local hideButton=button(header,'×',function()self:setMode('Hidden')end);hideButton.Position=UDim2.new(1,-44,0,2)
 local nav=C.row(full,44);nav.Position=UDim2.fromOffset(12,56);nav.Size=UDim2.new(1,-24,0,44)
 self.nav=C.segmented(nav,{{label='Músicas',value='Library'},{label='Player',value='Player'},{label='Expressão',value='Performance'},{label='Ajustes',value='Settings'}},function(v)self:showTab(v)end)
 self.pages={}
 for _,name in ipairs({'Library','Player','Performance','Settings'})do
  local p=C.new('ScrollingFrame',full,{Name=name,BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(16,112),Size=UDim2.new(1,-32,1,-128),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,Visible=false});self.pages[name]=p;C.list(p,8)
 end
 local function seek(parent)
  local bar=C.seekbar(parent,self.router,state,cb.seek);self.subscriptions[#self.subscriptions+1]=bar.unsubscribe
  local times=C.row(parent,16);local elapsed=C.label(times,'00:00',11);elapsed.Size=UDim2.fromScale(.5,1);elapsed.TextColor3=C.colors.muted
  local total=C.label(times,'00:00',11);total.Position=UDim2.fromScale(.5,0);total.Size=UDim2.fromScale(.5,1);total.TextXAlignment=Enum.TextXAlignment.Right;total.TextColor3=C.colors.muted
  listen(function(s)elapsed.Text=self:time(s.position);total.Text=self:time(s.duration)end)
 end
 local function speed(parent)
  local speed=C.speed(parent,self.router,state,cb.speedStep,function()self:speedPicker()end,cb.setSpeed);self.subscriptions[#self.subscriptions+1]=speed.unsubscribe;return speed.frame
 end
 local function transport(parent,small)
  local row=C.row(parent,48)
  local prev=button(row,'‹',cb.previous);prev.Position=UDim2.fromOffset(0,2)
  local play=button(row,'▶',cb.playPause,true);play.Position=UDim2.fromOffset(48,0);play.Size=UDim2.fromOffset(64,48);play.TextSize=23
  local next=button(row,'›',cb.next);next.Position=UDim2.fromOffset(104,2);play.Size=UDim2.fromOffset(52,48)
  local speedFrame=speed(row);speedFrame.Position=UDim2.new(1,-152,0,2);speedFrame.Size=UDim2.fromOffset(152,44)
  listen(function(s)play.Text=s.playing and 'Ⅱ' or '▶'end)
  return row
 end
 local function hands(parent)
  local control=C.segmented(parent,{{label='LH',value='Left'},{label='Ambas',value='Both'},{label='RH',value='Right'}},cb.hands);listen(function(s)control.set(s.hands)end);return control.frame
 end
 local function songTitle(parent)
  local title=C.label(parent,'Escolha uma música',17);title.Font=Enum.Font.GothamBold;title.Size=UDim2.new(1,0,0,26)
  listen(function(s)title.Text=s.song and s.song.name or 'Escolha uma música'end);return title
 end
 local function roll(parent,height)
  local r=R('UI/PianoRoll').new(parent,C,R('UI/KeyboardGeometry'));r.frame.Size=UDim2.new(1,0,0,height);self.rolls[#self.rolls+1]=r;return r
 end
 -- Full Player: spacious controls, full roll, secondary tools in a sheet.
 local p=self.pages.Player;songTitle(p)
 local meta=C.label(p,'',12);meta.TextColor3=C.colors.muted;listen(function(s)meta.Text=s.metadata or 'MIDI → interpretação → piano do jogo'end)
 roll(p,124);seek(p);transport(p);hands(p)
 local human=button(p,'Pianist',function()self:humanPicker()end);human.Size=UDim2.new(1,0,0,44)
 listen(function(s)human.Text=(s.humanPreset or 'Exact')..'  ·  '..math.floor((s.humanStrength or 0)*100)..'%   ⌄'end)
 local tools=button(p,'Fila · Loop · Soltar teclas',function()self:playerTools()end);tools.Size=UDim2.new(1,0,0,44)
 -- Compact: no library/sidebar; controls remain outside the roll.
 local compact,ch=window('Compact');local ct=C.label(ch,'',14);ct.Size=UDim2.new(1,-144,1,0);listen(function(s)ct.Text=s.song and s.song.name or 'Escolha uma música'end)
 for i,x in ipairs({{'↗','Full'},{'—','Mini'},{'×','Hidden'}})do local b=button(ch,x[1],function()self:setMode(x[2])end);b.Position=UDim2.new(1,-(4-i)*48+4,0,2)end
 local content=C.new('ScrollingFrame',compact,{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(12,56),Size=UDim2.new(1,-24,1,-66),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=2});C.list(content,2)
 roll(content,76);seek(content);transport(content,true)
 local quick=C.row(content,44);local hf=hands(quick);hf.Size=UDim2.new(.52,-4,1,0)
 local hp=button(quick,'',function()self:humanPicker()end);hp.Position=UDim2.fromScale(.52,0);hp.Size=UDim2.new(.48,0,1,0);hp.TextSize=12
 listen(function(s)hp.Text=(s.humanPreset or 'Exact')..' '..math.floor((s.humanStrength or 0)*100)..'% ⌄'end)
 -- Mini: a distinct two-row transport with seek, no piano roll.
 local mini,mh=window('Mini');local mt=C.label(mh,'',13);mt.Size=UDim2.new(1,-96,1,0);listen(function(s)mt.Text=s.song and s.song.name or 'Nenhuma música'end)
 local expand=button(mh,'↗',function()self:setMode('Compact')end);expand.Position=UDim2.new(1,-92,0,2)
 local hidden=button(mh,'×',function()self:setMode('Hidden')end);hidden.Position=UDim2.new(1,-44,0,2)
 local miniBody=C.new('Frame',mini,{BackgroundTransparency=1,Position=UDim2.fromOffset(12,50),Size=UDim2.new(1,-24,1,-60)});C.list(miniBody,0)
 local miniRow=C.row(miniBody,44);local mp=button(miniRow,'▶',cb.playPause,true);mp.Size=UDim2.fromOffset(54,44);listen(function(s)mp.Text=s.playing and 'Ⅱ' or '▶'end)
 local tm=C.label(miniRow,'',11);tm.Position=UDim2.fromOffset(64,0);tm.Size=UDim2.new(1,-248,1,0);tm.TextWrapped=true;tm.TextTruncate=Enum.TextTruncate.None;listen(function(s)tm.Text=self:time(s.position)..'\n'..self:time(s.duration)end)
 local sp=speed(miniRow);sp.Position=UDim2.new(1,-152,0,0);sp.Size=UDim2.fromOffset(152,44)
 local sb=C.seekbar(miniBody,self.router,state,cb.seek);self.subscriptions[#self.subscriptions+1]=sb.unsubscribe
 -- Hidden restores the preceding playback surface, never Full.
 local bubble=button(self.root,'♪',nil,true);bubble.Name='Hidden';bubble.Size=UDim2.fromOffset(56,56);bubble.TextSize=24;self.windows.Hidden=bubble
 bindDrag(bubble,bubble,'Hidden',function()self:setMode(self.lastMode)end)
 -- Library.
 p=self.pages.Library
 local source=C.segmented(p,{{label='Local',value='Local'},{label='Cloud',value='Cloud'}},function(v)self.source=v;self:renderSongs();if v=='Cloud'then self:searchCloud()end end);self.sourceControl=source;source.set('Local')
 self.search=C.textbox(p,'Buscar música');self.search:GetPropertyChangedSignal('Text'):Connect(function()if self.source=='Local'then self:renderSongs()else self:searchCloud()end end)
 local filters=C.segmented(p,{{label='Todas',value='All'},{label='Recentes',value='Recent'},{label='Favoritas',value='Favorites'}},function(v)self.filter=v;self.filterControl.set(v);self:renderSongs()end);self.filterControl=filters;filters.set('All')
 local refresh=button(p,'Atualizar biblioteca',cb.refresh);refresh.Size=UDim2.new(1,0,0,44)
 self.songList=C.new('Frame',p,{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y});C.list(self.songList,6)
 -- Performance uses presets first; technical knobs remain inside Advanced.
 p=self.pages.Performance
 local intro=C.label(p,'Interpretação musical',20);intro.Size=UDim2.new(1,0,0,30)
 local preset=button(p,'Escolher interpretação',function()self:humanPicker()end);preset.Size=UDim2.new(1,0,0,44)
 local strength=C.label(p,'Intensidade',14)
 local intensity=C.slider(p,self.router,0,1,state.value.humanStrength or 1,cb.strength,function(v)return math.floor(v*100)..'%'end)
 listen(function(s)strength.Text='Intensidade · '..math.floor(s.humanStrength*100)..'%';if not intensity.dragging then intensity:set(s.humanStrength)end end)
 for _,x in ipairs({{'Nova interpretação',cb.newPerformance},{'Tracks e mãos',function()self:tracks()end},{'Advanced ›',function()self:advanced()end}})do local b=button(p,x[1],x[2]);b.Size=UDim2.new(1,0,0,44)end
 -- Settings: persistent choices and technical tools, no status wall.
 p=self.pages.Settings
 for _,x in ipairs({{'Calibrar piano',function()self:calibrate()end},{'Salvar perfil deste jogo',cb.saveGame},{'Salvar ajustes desta música',cb.saveSong},{'Restaurar padrões globais',cb.resetOverrides},{'Conversão e alcance',function()self:conversion()end},{'Reset UI Position',function()config.ui.positions={};self:resize();cb.saveUI(config.ui)end},{'Reconectar input',cb.reconnect},{'Diagnostics',function()self:diagnostics()end},{'Novidades • 0.7.0-rc.1',function()self:changelog()end}})do local b=button(p,x[1],x[2]);b.Size=UDim2.new(1,0,0,44)end
 self.toastLabel=C.label(self.root,'',13);self.toastLabel.Name='Toast';self.toastLabel.Visible=false;self.toastLabel.BackgroundColor3=C.colors.panel;self.toastLabel.BackgroundTransparency=.05;self.toastLabel.TextXAlignment=Enum.TextXAlignment.Center;self.toastLabel.TextWrapped=true;self.toastLabel.Size=UDim2.new(1,-32,0,44);self.toastLabel.Position=UDim2.new(.5,0,1,-56);self.toastLabel.AnchorPoint=Vector2.new(.5,0);self.C.new('UISizeConstraint',self.toastLabel,{MaxSize=Vector2.new(420,44),MinSize=Vector2.new(0,0)});self.toastLabel.ZIndex=40;C.round(self.toastLabel,12)
 self.connections[#self.connections+1]=self.root:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()self:resize()end)
 self.connections[#self.connections+1]=Run.RenderStepped:Connect(function()
  local pos=cb.position();for _,r in ipairs(self.rolls)do if self.mode=='Compact' and r.frame:IsDescendantOf(compact)or self.mode=='Full' and self.tab=='Player' and r.frame:IsDescendantOf(full)then r:update(pos)end end
 end)
 self:resize();self:showTab('Library');self:setMode('Full')
 self.actions={Library=function()self:setMode('Full');self:showTab('Library')end,Player=function()self:setMode('Full');self:showTab('Player')end,Performance=function()self:showTab('Performance')end,Settings=function()self:showTab('Settings')end,Compact=function()self:setMode('Compact')end,Mini=function()self:setMode('Mini')end,Hidden=function()self:setMode('Hidden')end,Restore=function()self:setMode(self.lastMode)end,Seek=function()cb.seek(state.value.duration*.5)end,SpeedPlus=function()cb.speedStep(1)end,SpeedMinus=function()cb.speedStep(-1)end,Play=cb.playPause,Pause=cb.playPause,LH=function()cb.hands('Left')end,RH=function()cb.hands('Right')end,Both=function()cb.hands('Both')end}
 return self
end
function App:time(t)t=math.max(0,t or 0);return string.format('%02d:%02d',math.floor(t/60),math.floor(t%60))end
function App:resize()
 self.router:cancel();local L=self.R('UI/Layout');local v=self.root.AbsoluteSize
 for mode,w in pairs(self.windows)do local width,height=L.bounds(v.X,v.Y,mode);w.Size=UDim2.fromOffset(width,height);local x,y=L.position(v.X,v.Y,width,height,self.config.ui.positions and self.config.ui.positions[mode]);w.Position=UDim2.fromOffset(x,y)end
end
function App:setMode(mode)
 assert(self.windows[mode],'Invalid UI mode');self.router:cancel();self:closeModal()
 if self.mode=='Mini' or self.mode=='Compact'then self.lastMode=self.mode end
 self.mode=mode;for name,w in pairs(self.windows)do w.Visible=name==mode end
 if self.config.ui.transitions~=false then local w=self.windows[mode];local scale=w:FindFirstChild('TransitionScale');if not scale then scale=self.C.new('UIScale',w,{Name='TransitionScale',Scale=1})end;scale.Scale=.98;game:GetService('TweenService'):Create(scale,TweenInfo.new(.15),{Scale=1}):Play()end
 self.state:patch({uiMode=mode});self.config.ui.state=mode;self.cb.saveUI(self.config.ui)
end
function App:showTab(tab)
 self.tab=tab;self.nav.set(tab)
 for name,p in pairs(self.pages)do p.Visible=name==tab;if name==tab and self.config.ui.transitions~=false then p.Position=UDim2.fromOffset(24,112);game:GetService('TweenService'):Create(p,TweenInfo.new(.14),{Position=UDim2.fromOffset(16,112)}):Play()end end
end
function App:toast(message)
 self.toastSequence=(self.toastSequence or 0)+1;local id=self.toastSequence;self.toastLabel.Text=message;self.toastLabel.Visible=true
 task.delay(2.6,function()if not self.destroyed and id==self.toastSequence then self.toastLabel.Visible=false end end)
end
function App:closeModal()if self.modal then self.router:cancel();self.modal:Destroy();self.modal=nil end end
function App:sheet(title)
 self:closeModal();local body;self.modal,body=self.C.modal(self.root,title,function()self:closeModal()end);return body
end
function App:sheetButton(body,text,fn,primary)local b=self.C.button(body,text,fn,primary);b.Size=UDim2.new(1,0,0,44);return b end
function App:speedPicker()
 local b=self:sheet('Velocidade')
 for _,v in ipairs({.25,.5,.75,.9,1,1.1,1.25,1.5,1.75,2})do self:sheetButton(b,string.format('%.2f×',v),function()self.cb.setSpeed(v);self:closeModal()end,v==self.state.value.speed)end
 self.C.slider(b,self.router,.25,2,self.state.value.speed,function(v)self.cb.setSpeed(math.floor(v*100+.5)/100)end,function(v)return string.format('%.2f×',v)end)
end
function App:humanPicker()
 local b=self:sheet('Interpretação')
 for _,v in ipairs({'Exact','Subtle','Natural','Pianist','Expressive','Custom'})do self:sheetButton(b,v,function()self.cb.preset(v);self:closeModal()end,v==self.state.value.humanPreset)end
 self:sheetButton(b,'Nova interpretação',function()self.cb.newPerformance();self:closeModal()end)
end
function App:setSongs(songs)self.songs=songs;self:renderSongs()end
function App:searchCloud()
 self.searchGeneration=(self.searchGeneration or 0)+1;local id=self.searchGeneration;self.cb.cancelCloud()
 task.delay(.4,function()if self.destroyed or id~=self.searchGeneration or self.source~='Cloud'then return end;self.cb.searchCloud(self.search.Text)end)
end
function App:renderSongs()
 self.sourceControl.set(self.source)
 for _,c in ipairs(self.songList:GetChildren())do if not c:IsA('UIListLayout')then c:Destroy()end end
 local songs={};local query=string.lower(self.search.Text)
 for _,s in ipairs(self.source=='Local' and self.songs or self.cloudSongs)do
  if string.find(string.lower(s.name),query,1,true) and (self.filter~='Favorites' or s.favorite)and(self.filter~='Recent' or s.recentRank)then songs[#songs+1]=s end
 end
 if self.filter=='Recent'then table.sort(songs,function(a,b)return a.recentRank<b.recentRank end)end
 if #songs==0 then
  local title=self.C.label(self.songList,self.source=='Cloud' and 'Dodo Cloud indisponível' or '♪  Nenhuma música ainda',18);title.Size=UDim2.new(1,0,0,52)
  local sub=self.C.label(self.songList,self.source=='Cloud' and (self.cloudMessage or 'Consulte Diagnostics para detalhes.')or 'Adicione arquivos .mid em\nDelta/Workspace/MIDI/',13);sub.TextWrapped=true;sub.TextTruncate=Enum.TextTruncate.None;sub.Size=UDim2.new(1,0,0,58);sub.TextColor3=self.C.colors.muted
 end
 for _,song in ipairs(songs)do
  local row=self.C.row(self.songList,60);row.Name='SongRow'
  local name=self.C.label(row,song.name,14);name.Size=UDim2.new(1,-150,0,30)
  local meta=self.C.label(row,song.duration and (self:time(song.duration)..' · '..tostring(song.bpm or '—')..' BPM')or 'MIDI local',11);meta.Position=UDim2.fromOffset(0,30);meta.Size=UDim2.new(1,-150,0,24);meta.TextColor3=self.C.colors.muted
  local fav=self.C.button(row,song.favorite and '★' or '☆',function()self.cb.favorite(song)end);fav.Position=UDim2.new(1,-144,0,8)
  local more=self.C.button(row,'⋯',function()self:songActions(song)end);more.Position=UDim2.new(1,-96,0,8)
  local play=self.C.button(row,'▶',function()if self.source=='Cloud'then self.cb.download(song)else self.cb.selectSong(song,true)end end,true);play.Position=UDim2.new(1,-48,0,8)
 end
end
function App:songActions(song)
 local b=self:sheet(song.name)
 self:sheetButton(b,'Abrir no Player',function()self.cb.selectSong(song,false);self:closeModal()end)
 self:sheetButton(b,'Tocar agora',function()self.cb.selectSong(song,true);self:closeModal()end)
 self:sheetButton(b,'Tocar depois',function()self.cb.enqueue(song,true);self:closeModal()end)
 self:sheetButton(b,'Adicionar à fila',function()self.cb.enqueue(song,false);self:closeModal()end)
end
function App:playerTools()
 local b=self:sheet('Reprodução')
 self:sheetButton(b,'Soltar todas as teclas',function()self.cb.panic();self:closeModal()end)
 self:sheetButton(b,self.state.value.loop and 'Desativar loop' or 'Repetir música',function()self.cb.loop();self:closeModal()end)
 self:sheetButton(b,'Marcar início A',function()self.cb.markA()end);self:sheetButton(b,'Marcar fim B',function()self.cb.markB()end);self:sheetButton(b,'Limpar A–B',self.cb.clearAB)
 for i,s in ipairs(self.cb.queue())do self:sheetButton(b,tostring(i)..' · '..s.name,function()self.cb.removeQueue(i);self:playerTools()end)end
end
function App:tracks()
 local b=self:sheet('Tracks e mãos');local a=self.cb.analysis()
 if not a then self.C.label(b,'Selecione uma música primeiro.',14);return end
 for _,t in ipairs(a.tracks)do local on=self.config.parts.enabledTracks[t.index]~=false;self:sheetButton(b,(on and '● 'or '○ ')..t.name,function()self.cb.track(t.index,not on);self:tracks()end)end
 self:sheetButton(b,'Divisão automática',function()self.cb.split(nil);self:tracks()end)
 local input=self.C.textbox(b,'Divisão manual: nota MIDI (0–127)');input.Text=tostring(self.config.parts.splitNote or 60)
 self:sheetButton(b,'Aplicar divisão manual',function()local n=tonumber(input.Text);if n then self.cb.split(math.clamp(math.floor(n),0,127))end end)
end
function App:advanced()
 local b=self:sheet('Expressão · Advanced')
 for _,x in ipairs({{'timingMs','Tempo global',0,20},{'phraseMs','Frases',0,30},{'rubatoMs','Rubato',0,30},{'handMs','Independência das mãos',0,15},{'chordSpreadMs','Acordes',0,30},{'microMs','Microtiming',0,3},{'durationVariation','Articulação',0,.08},{'velocityPreservation','Preservar velocity',0,1},{'dynamicContour','Dinâmica',0,1},{'motifVariation','Variação de motivos',0,1}})do
  self.C.label(b,x[2],14);self.C.slider(b,self.router,x[3],x[4],self.config.humanize[x[1]] or 0,function(v)self.cb.humanParameter(x[1],v)end)
 end
 local seed=self.C.textbox(b,'Seed numérica');seed.Text=tostring(self.state.value.performanceSeed or 12345)
 self:sheetButton(b,'Usar seed fixa',function()local v=tonumber(seed.Text);if v then self.cb.seed(math.floor(v))end end)
 self:sheetButton(b,'Seed automática',function()self.cb.seed(nil)end)
 self:sheetButton(b,'Exportar análise da interpretação',self.cb.exportPerformance)
end
function App:conversion()
 local b=self:sheet('Piano do jogo')
 self.C.label(b,'Transposição',14);self.C.slider(b,self.router,-24,24,self.config.playback.transpose,function(v)self.cb.transpose(math.floor(v+.5))end)
 for _,v in ipairs({'Strict','SmartOctave','OctaveFold','Clamp'})do self:sheetButton(b,v,function()self.cb.range(v)end)end
 self.C.label(b,'Máximo de teclas simultâneas',14);self.C.slider(b,self.router,1,16,self.config.playback.maxSimultaneousKeys,function(v)self.cb.maxKeys(math.floor(v+.5))end)
end
function App:calibrate(step,draft)
 step=step or 1;draft=draft or self.cb.profileCopy();local tests={60,72,84};local note=tests[step]
 local b=self:sheet(note and ('Calibrar · '..({'C4','C5','C6'})[step])or 'Calibrar · alcance')
 if note then
  local input=self.C.textbox(b,'Tecla QWERTY correspondente');input.Text=draft.map[note] or ''
  self:sheetButton(b,'Testar tecla',function()if #input.Text==1 then self.cb.testToken(input.Text)end end)
  self:sheetButton(b,'Está correto · continuar',function()if #input.Text~=1 then self:toast('Informe uma tecla.');return end;draft.map[note]=input.Text;self:calibrate(step+1,draft)end,true)
 else
  local low=self.C.textbox(b,'Nota mais grave');low.Text=tostring(draft.lowest)
  local high=self.C.textbox(b,'Nota mais aguda');high.Text=tostring(draft.highest)
  self:sheetButton(b,'Salvar perfil deste jogo',function()local l,h=tonumber(low.Text),tonumber(high.Text);if l and h and l>=0 and h<=127 and l<h then draft.lowest=math.floor(l);draft.highest=math.floor(h);if self.cb.saveCalibration(draft)then self:closeModal()end else self:toast('Confira o alcance MIDI.')end end,true)
 end
end
function App:diagnostics()
 local b=self:sheet('Diagnostics');local text=self.C.label(b,self.cb.diagnostics(),12);text.TextWrapped=true;text.TextTruncate=Enum.TextTruncate.None;text.TextYAlignment=Enum.TextYAlignment.Top;text.Size=UDim2.new(1,0,0,360)
end
function App:changelog()
 local b=self:sheet('Novidades · 0.7.0-rc.1');local t=self.C.label(b,'Glass/dark com Full, Compact, Mini e bolha.\n\nVelocidade −/+ sincronizada. Seek com preview e confirmação no release.\n\nInterpretação por frases e motivos. Perfil por jogo e calibração guiada.\n\nRC: testes no Roblox e no aparelho ainda necessários.',14);t.TextWrapped=true;t.TextTruncate=Enum.TextTruncate.None;t.Size=UDim2.new(1,0,0,240);self.config.ui.lastSeenChangelog='0.7.0-rc.1';self.cb.saveUI(self.config.ui)
end
function App:setTimeline(t,profile)for _,r in ipairs(self.rolls)do r:setTimeline(t,profile)end end
function App:setCloud(results,message)self.cloudSongs=results or {};self.cloudMessage=message;self:renderSongs()end
function App:destroy()self.destroyed=true;self.router:destroy();for _,off in ipairs(self.subscriptions)do off()end;for _,c in ipairs(self.connections)do c:Disconnect()end;self.gui:Destroy()end
return App

end
modules['UI/Components']=function()
local C={}
C.colors={bg=Color3.fromRGB(13,17,27),panel=Color3.fromRGB(25,30,46),edge=Color3.fromRGB(67,74,101),text=Color3.fromRGB(241,243,251),muted=Color3.fromRGB(163,173,194),accent=Color3.fromRGB(150,118,245),left=Color3.fromRGB(74,215,186),right=Color3.fromRGB(158,127,255)}
function C.new(class,parent,props)
 local o=Instance.new(class);for k,v in pairs(props or {})do o[k]=v end;o.Parent=parent;return o
end
function C.round(o,r)C.new('UICorner',o,{CornerRadius=UDim.new(0,r or 12)})end
function C.surface(parent,props)
 local f=C.new('Frame',parent,{BackgroundColor3=C.colors.bg,BackgroundTransparency=.08,BorderSizePixel=0});for k,v in pairs(props or {})do f[k]=v end
 C.round(f,18);C.new('UIStroke',f,{Color=C.colors.edge,Transparency=.42,Thickness=1})
 C.new('UIGradient',f,{Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(181,190,219)),Rotation=80})
 return f
end
function C.label(parent,text,size)
 return C.new('TextLabel',parent,{BackgroundTransparency=1,Text=text or '',TextColor3=C.colors.text,TextSize=size or 14,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,Size=UDim2.new(1,0,0,24),TextTruncate=Enum.TextTruncate.AtEnd})
end
function C.button(parent,text,fn,primary)
 local b=C.new('TextButton',parent,{Name=text,Text=text,TextXAlignment=Enum.TextXAlignment.Center,TextSize=14,Font=primary and Enum.Font.GothamBold or Enum.Font.GothamMedium,TextColor3=primary and C.colors.bg or C.colors.text,BackgroundColor3=primary and C.colors.accent or C.colors.panel,BackgroundTransparency=primary and 0 or .15,AutoButtonColor=false,BorderSizePixel=0,Size=UDim2.fromOffset(44,44)})
 C.round(b,primary and 16 or 10)
 if fn then b.Activated:Connect(fn)end
 b.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then b.BackgroundTransparency=.35 end end)
 b.InputEnded:Connect(function()b.BackgroundTransparency=primary and 0 or .15 end)
 return b
end
C.IconButton=C.button
function C.textbox(parent,placeholder)
 local b=C.new('TextBox',parent,{PlaceholderText=placeholder,Text='',ClearTextOnFocus=false,TextSize=14,Font=Enum.Font.Gotham,TextColor3=C.colors.text,PlaceholderColor3=C.colors.muted,BackgroundColor3=C.colors.panel,BorderSizePixel=0,Size=UDim2.new(1,0,0,44),TextXAlignment=Enum.TextXAlignment.Left});C.round(b,12);C.new('UIPadding',b,{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)});return b
end
function C.list(parent,gap)
 return C.new('UIListLayout',parent,{Padding=UDim.new(0,gap or 8),SortOrder=Enum.SortOrder.LayoutOrder})
end
function C.row(parent,height)return C.new('Frame',parent,{BackgroundTransparency=1,Size=UDim2.new(1,0,0,height or 44)})end
function C.segmented(parent,items,callback)
 local f=C.row(parent);local buttons={}
 for i,item in ipairs(items)do local b=C.button(f,item.label,function()callback(item.value)end);b.Size=UDim2.new(1/#items,-4,1,0);b.Position=UDim2.new((i-1)/#items,2,0,0);buttons[item.value]=b end
 return {frame=f,set=function(v)for key,b in pairs(buttons)do b.BackgroundColor3=key==v and C.colors.accent or C.colors.panel;b.TextColor3=key==v and C.colors.bg or C.colors.text end end}
end
function C.toggle(parent,text,value,callback)local b=C.button(parent,'',function()value=not value;callback(value)end);b.Size=UDim2.new(1,0,0,44);b.Text=text..(value and '  • ON' or '  • OFF');return b end
function C.slider(parent,router,min,max,value,commit,format)
 local f=C.row(parent,44);f.Active=true
 local track=C.new('Frame',f,{Position=UDim2.new(0,10,.5,-3),Size=UDim2.new(1,-20,0,6),BackgroundColor3=C.colors.edge,BorderSizePixel=0});C.round(track,3)
 local fill=C.new('Frame',track,{Size=UDim2.fromScale(0,1),BackgroundColor3=C.colors.accent,BorderSizePixel=0});C.round(fill,3)
 local thumb=C.new('Frame',track,{Size=UDim2.fromOffset(14,14),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(0,.5),BackgroundColor3=C.colors.text,BorderSizePixel=0});C.round(thumb,7)
 local hint=C.label(f,'',12);hint.Size=UDim2.fromOffset(74,28);hint.BackgroundColor3=C.colors.panel;hint.BackgroundTransparency=0;hint.Visible=false;hint.TextXAlignment=Enum.TextXAlignment.Center;C.round(hint,8)
 local self={frame=f,dragging=false,value=value}
 function self:set(v)self.value=math.clamp(v,min,max);local r=max>min and (self.value-min)/(max-min)or 0;fill.Size=UDim2.fromScale(r,1);thumb.Position=UDim2.fromScale(r,.5)end
 local function preview(p)local r=math.clamp((p.X-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1);self:set(min+r*(max-min));hint.Text=format and format(self.value) or string.format('%.2f',self.value);hint.Position=UDim2.fromOffset(math.clamp(p.X-f.AbsolutePosition.X-37,0,math.max(0,f.AbsoluteSize.X-74)),-24)end
 router:bind(f,{begin=function(p)self.dragging=true;hint.Visible=true;preview(p)end,move=function(p)preview(p)end,finish=function(p)preview(p);self.dragging=false;hint.Visible=false;commit(self.value)end,cancel=function()self.dragging=false;hint.Visible=false end})
 self:set(value);return self
end
function C.seekbar(parent,router,state,seek)
 local s=C.slider(parent,router,0,1,0,function(r)if state.value.duration>0 then seek(r*state.value.duration)end end,function(r)local t=r*(state.value.duration or 0);return string.format('%02d:%02d',t//60,t%60)end)
 s.unsubscribe=state:subscribe(function(v)if not s.dragging then s:set(v.duration>0 and v.position/v.duration or 0)end end);return s
end
function C.speed(parent,router,state,step,select,setSpeed)
 local f=C.row(parent);local minus=C.button(f,'−',nil);minus.Size=UDim2.fromOffset(44,44)
 local value=C.button(f,'1.00×',select);value.Position=UDim2.fromOffset(48,0);value.Size=UDim2.new(1,-96,1,0);value.BackgroundTransparency=.6
 local plus=C.button(f,'+',nil);plus.Position=UDim2.new(1,-44,0,0)
 for _,x in ipairs({{minus,-1},{plus,1}})do
  local generation=0;local repeated=false
  router:bind(x[1],{begin=function()generation+=1;local g=generation;repeated=false;task.delay(.4,function()if g~=generation or not router.owner then return end;repeated=true;local function repeatStep()if g~=generation or not router.owner then return end;step(x[2]);task.delay(.11,repeatStep)end;repeatStep()end)end,finish=function(_,drag)generation+=1;if not drag and not repeated then step(x[2])end end,cancel=function()generation+=1 end})
 end
 local unsub=state:subscribe(function(s)value.Text=string.format('%.2f×',s.speed or 1)end)
 return {frame=f,unsubscribe=unsub}
end
function C.modal(root,title,close)
 local overlay=C.new('Frame',root,{Name='Modal',BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.45,Size=UDim2.fromScale(1,1),Active=true,ZIndex=30})
 local box=C.surface(overlay,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(1,-32,1,-32),ZIndex=31})
 C.new('UISizeConstraint',box,{MaxSize=Vector2.new(470,540),MinSize=Vector2.new(0,0)})
 local label=C.label(box,title,18);label.Position=UDim2.fromOffset(16,10);label.Size=UDim2.new(1,-80,0,44)
 local x=C.button(box,'×',close);x.Position=UDim2.new(1,-56,0,10)
 local scale=C.new('UIScale',box,{Scale=.97});game:GetService('TweenService'):Create(scale,TweenInfo.new(.15),{Scale=1}):Play()
 local body=C.new('ScrollingFrame',box,{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(16,66),Size=UDim2.new(1,-32,1,-80),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3});C.list(body,10)
 return overlay,body
end
C.BottomSheet=C.modal;C.Modal=C.modal;C.Button=C.button;C.Slider=C.slider;C.SeekBar=C.seekbar;C.SpeedControl=C.speed;C.SegmentedControl=C.segmented;C.Toggle=C.toggle
return C

end
modules['UI/InputRouter']=function()
local Router={};Router.__index=Router
function Router.new(UIS)
 local self=setmetatable({connections={},owner=nil,threshold=8,bindings={}},Router)
 self.connections[1]=UIS.InputChanged:Connect(function(i)
  local o=self.owner;if not o then return end
  if i==o.input or (o.mouse and i.UserInputType==Enum.UserInputType.MouseMovement)then
   local distance=(i.Position-o.start).Magnitude
   if distance>=self.threshold then o.drag=true end
   if o.handlers.move then o.handlers.move(i.Position,o.drag)end
  end
 end)
 self.connections[2]=UIS.InputEnded:Connect(function(i)
  local o=self.owner;if o and (i==o.input or (o.mouse and i.UserInputType==Enum.UserInputType.MouseButton1))then
   self.owner=nil;if o.handlers.finish then o.handlers.finish(i.Position,o.drag)end
  end
 end)
 return self
end
function Router:bind(object,handlers)
 local c=object.InputBegan:Connect(function(i)
  local mouse=i.UserInputType==Enum.UserInputType.MouseButton1
  if self.owner or (not mouse and i.UserInputType~=Enum.UserInputType.Touch)then return end
  self.owner={object=object,input=i,mouse=mouse,start=i.Position,handlers=handlers,drag=false}
  if handlers.begin then handlers.begin(i.Position)end
 end)
 local token={};self.bindings[token]=c
 local destroyed;destroyed=object.Destroying:Connect(function()c:Disconnect();self.bindings[token]=nil;if self.owner and self.owner.object==object then self:cancel()end;destroyed:Disconnect()end)
 return c
end
function Router:cancel()local o=self.owner;self.owner=nil;if o and o.handlers.cancel then o.handlers.cancel()end end
function Router:destroy()self:cancel();for _,c in pairs(self.bindings)do c:Disconnect()end;table.clear(self.bindings);for _,c in ipairs(self.connections)do c:Disconnect()end;table.clear(self.connections)end
return Router

end
modules['UI/KeyboardGeometry']=function()
local K={}
function K.black(n)local p=n%12;return p==1 or p==3 or p==6 or p==8 or p==10 end
function K.build(low,high)
 -- Include bounding white keys when a range starts or ends on an accidental.
 if K.black(low)then low-=1 end;if K.black(high)then high+=1 end
 local whites=0;for n=low,high do if not K.black(n)then whites+=1 end end
 local keys={};local index=0
 for n=low,high do
  local b=K.black(n)
  if b then keys[n]={x=(index-.31)/whites,width=.62/whites,black=true,center=index/whites}
  else keys[n]={x=index/whites,width=1/whites,black=false,center=(index+.5)/whites};index+=1 end
 end
 return keys,low,high
end
return K

end
modules['UI/Layout']=function()
local L={}
function L.bounds(vw,vh,mode)
 local aw,ah=math.max(1,vw-24),math.max(1,vh-24)
 local w,h
 if mode=='Full' then w=math.min(680,aw);h=math.min(540,ah)
 elseif mode=='Compact' then w=math.min(480,aw);h=math.min(330,ah)
 elseif mode=='Mini' then w=math.min(420,aw);h=156
 else w,h=56,56 end
 return w,math.min(h,ah)
end
function L.clamp(x,y,w,h,vw,vh)return math.clamp(x,0,math.max(0,vw-w)),math.clamp(y,0,math.max(0,vh-h))end
function L.position(vw,vh,w,h,saved)
 return L.clamp(saved and saved.x*(vw-w) or 12,saved and saved.y*(vh-h) or 12,w,h,vw,vh)
end
function L.normalized(x,y,w,h,vw,vh)return {x=x/math.max(1,vw-w),y=y/math.max(1,vh-h)}end
return L

end
modules['UI/PianoRoll']=function()
local Roll={};Roll.__index=Roll
function Roll.new(parent,C,Geometry)
 local self=setmetatable({C=C,geometry=Geometry,notes={},pool={},keys={},lookAhead=2.6},Roll)
 self.frame=C.surface(parent,{Name='PianoRoll',Size=UDim2.new(1,0,0,120),BackgroundColor3=Color3.fromRGB(8,12,21),ClipsDescendants=true})
 self.lanes=C.new('Frame',self.frame,{BackgroundTransparency=1,Size=UDim2.new(1,0,1,-30),ClipsDescendants=true})
 self.keyboard=C.new('Frame',self.frame,{BackgroundTransparency=1,Position=UDim2.new(0,0,1,-30),Size=UDim2.new(1,0,0,30)})
 local line=C.new('Frame',self.frame,{Position=UDim2.new(0,0,1,-31),Size=UDim2.new(1,0,0,1),BackgroundColor3=C.colors.accent,BorderSizePixel=0});line.ZIndex=5
 self.empty=C.label(self.lanes,'Selecione uma música para acompanhar as notas',12);self.empty.Size=UDim2.fromScale(1,1);self.empty.TextXAlignment=Enum.TextXAlignment.Center;self.empty.TextColor3=C.colors.muted
 return self
end
function Roll:setTimeline(timeline,profile)
 self.notes=timeline and timeline.notes or {};self.empty.Visible=#self.notes==0
 for _,k in pairs(self.keys)do k:Destroy()end;self.keys={}
 self.positions=self.geometry.build(profile.lowest,profile.highest)
 for n,p in pairs(self.positions)do
  local key=self.C.new('Frame',self.keyboard,{Name=tostring(n),BorderSizePixel=0,Position=UDim2.fromScale(p.x,0),Size=UDim2.new(p.width,-1,p.black and .62 or 1,0),BackgroundColor3=p.black and Color3.fromRGB(13,17,26) or Color3.fromRGB(191,201,217),ZIndex=p.black and 4 or 3})
  self.keys[n]=key
 end
 self.maxHold=0;for _,n in ipairs(self.notes)do self.maxHold=math.max(self.maxHold,(n.executionEnd or n.endTime)-n.startTime)end
end
function Roll:update(pos)
 if not self.frame.Visible then return end
 local height=self.lanes.AbsoluteSize.Y
 for n,key in pairs(self.keys)do key.BackgroundColor3=self.positions[n].black and Color3.fromRGB(13,17,26) or Color3.fromRGB(191,201,217)end
 local lo,hi=1,#self.notes+1
 while lo<hi do local mid=math.floor((lo+hi)/2);if mid<=#self.notes and self.notes[mid].startTime<pos-self.maxHold then lo=mid+1 else hi=mid end end
 local used=0
 for i=lo,#self.notes do
  local n=self.notes[i];if n.startTime>pos+self.lookAhead then break end
  local ending=n.executionEnd or n.keyReleaseTime or n.endTime
  local p=self.positions[n.mappedNote or n.note]
  if p and ending>=pos then
   used+=1;local block=self.pool[used]
   if not block then block=self.C.new('Frame',self.lanes,{BorderSizePixel=0});self.C.round(block,3);self.pool[used]=block end
   local color=n.parts and n.parts.hand=='Left' and self.C.colors.left or self.C.colors.right
   local y1=height-(ending-pos)/self.lookAhead*height;local y2=height-(n.startTime-pos)/self.lookAhead*height
   block.Position=UDim2.new(p.x,1,0,math.max(0,y1));block.Size=UDim2.new(p.width,-2,0,math.max(2,math.min(height,y2)-math.max(0,y1)));block.BackgroundColor3=color;block.Visible=true
   block.BackgroundTransparency=n.startTime<=pos and .02 or .18
   if n.startTime<=pos and self.keys[n.mappedNote or n.note]then self.keys[n.mappedNote or n.note].BackgroundColor3=color end
  end
 end
 for i=used+1,#self.pool do self.pool[i].Visible=false end
end
return Roll

end
modules['UI/TestHarness']=function()
local H={}
function H.run(app,state,cb)
 local results={}
 local function test(name,fn)local ok,err=pcall(fn);results[#results+1]={name=name,status=ok and 'PASS'or 'FAIL',error=not ok and tostring(err)or nil};print(name,ok and 'PASS'or tostring(err))end
 for _,name in ipairs({'Library','Player','Performance','Settings','Compact','Mini','Hidden','Restore'})do test(name,function()app.actions[name]();assert(app.windows[app.mode].Visible)end)end
 test('Speed +/− shared',function()local before=state.value.speed;cb.setSpeed(1);app.actions.SpeedPlus();assert(state.value.speed==1.05);app.actions.SpeedMinus();assert(state.value.speed==1);cb.setSpeed(before)end)
 for _,name in ipairs({'LH','RH','Both'})do test(name,function()app.actions[name]();assert(state.value.hands==({LH='Left',RH='Right',Both='Both'})[name])end)end
 for _,name in ipairs({'Exact','Subtle','Natural','Pianist','Expressive','Custom'})do test('Preset '..name,function()cb.preset(name);assert(state.value.humanPreset==name)end)end
 if state.value.song then
  test('Play/Pause',function()if state.value.playing then cb.playPause()end;cb.playPause();assert(state.value.playing);cb.playPause();assert(not state.value.playing)end)
  test('Seek',function()cb.seek(state.value.duration*.5);assert(math.abs(state.value.position-state.value.duration*.5)<.05)end)
 else results[#results+1]={name='Play/Pause/Seek',status='SKIP',error='Selecione um MIDI primeiro.'}end
 app:setMode('Compact');return results
end
return H

end
local cache={};local loading={}
local function R(name)
 if cache[name] then return cache[name]end
 assert(not loading[name], 'Circular dependency: '..name);loading[name]=true
 if name:match('MIDI/')then label.Text='Carregando MIDI engine…'elseif name:match('Input/')then label.Text='Preparando input…'elseif name:match('UI/')then label.Text='Montando interface…'end
 local result=assert(modules[name],'Missing module '..name)();cache[name]=result;loading[name]=nil;return result
end
local ok,result=pcall(function()return R('Main').start({Require=R})end)
boot:Destroy()
if not ok then error('[MIDIQWERTY RC] '..tostring(result),0)end
return result
