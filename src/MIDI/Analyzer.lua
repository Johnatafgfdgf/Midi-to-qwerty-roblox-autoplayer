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
