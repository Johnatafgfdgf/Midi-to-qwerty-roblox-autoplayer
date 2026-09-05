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
