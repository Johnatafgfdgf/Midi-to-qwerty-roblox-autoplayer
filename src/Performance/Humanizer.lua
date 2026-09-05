local Humanizer={}
local function fract(x)return x-math.floor(x) end
local function hash(seed,x)return fract(math.sin((x+seed*.00017)*12.9898+seed*.013)*43758.5453)*2-1 end
local function smoothstep(x)return x*x*(3-2*x) end
local function noise(seed,t,scale)local x=t/scale;local i,f=math.floor(x),x-math.floor(x);local a,b=hash(seed,i),hash(seed,i+1);return a+(b-a)*smoothstep(f) end
local function copyNote(n)local c={};for k,v in pairs(n) do c[k]=v end;if n.parts then local p={};for k,v in pairs(n.parts) do p[k]=v end;c.parts=p end;return c end
local function bpmAdaptive(maxMs,bpm)return maxMs*math.clamp(120/(bpm or 120),.45,1.35) end
function Humanizer.generate(notes,settings,context)
    settings=settings or {};context=context or {};local strength=settings.enabled==false and 0 or math.clamp(settings.strength or 0,0,1);local seed=context.seed or settings.fixedSeed or 12345;local out={}
    if strength<=0 then for i,n in ipairs(notes) do out[i]=copyNote(n) end;return out,{seed=seed,averageTimingMs=0,maxTimingMs=0} end
    local baseMax=bpmAdaptive(settings.timingMs or 9,context.bpm or 120)*strength;local durationVar=(settings.durationVariation or .018)*strength;local handFactor=settings.handIndependence or .35;local phraseFactor=settings.phraseExpression or .35;local sumAbs,peak=0,0
    for i,n in ipairs(notes) do
        local densityScale=1;local prev,nextN=notes[i-1],notes[i+1];if prev and nextN then local span=math.max(nextN.startTime-prev.startTime,.03);densityScale=math.clamp(10/math.max(2/span,1),.45,1) end
        local velocityScale=math.clamp(1.18-(n.velocity or 64)/180,.62,1.05);local maxMs=baseMax*densityScale*velocityScale
        local global=noise(seed+11,n.startTime,5)*.22;local phrase=noise(seed+29+(n.phraseId or 0)*7,n.startTime,1.6)*.34*phraseFactor;local handSeed=n.parts and n.parts.hand=="Left" and 101 or 211;local hand=noise(seed+handSeed,n.startTime,1.05)*.28*handFactor;local noteMicro=hash(seed+997,i)*.16
        local offsetMs=math.clamp((global+phrase+hand+noteMicro)*maxMs,-maxMs,maxMs);local c=copyNote(n);c.originalStartTime,c.originalEndTime=n.startTime,n.endTime;c.startTime=math.max(0,n.startTime+offsetMs/1000)
        local artScale=n.articulation=="Staccato" and .45 or n.articulation=="Legato" and .55 or 1;local dFactor=1+hash(seed+4001,i)*durationVar*artScale;c.endTime=math.max(c.startTime+.008,n.startTime+n.duration*dFactor+offsetMs/1000);c.duration=c.endTime-c.startTime;c.humanOffsetMs=offsetMs;out[i]=c;sumAbs+=math.abs(offsetMs);peak=math.max(peak,math.abs(offsetMs))
    end
    table.sort(out,function(a,b)return a.startTime==b.startTime and a.note<b.note or a.startTime<b.startTime end)
    local chordWindow=(context.chordWindowMs or 10)/1000;local spreadMax=(settings.chordSpreadMs or 8)*strength;local group={};local anchor
    local function flush() if #group>=2 and spreadMax>0 then table.sort(group,function(a,b)return a.note<b.note end);local span=math.min(spreadMax,2+(#group-1)*1.25);for j,n in ipairs(group) do local rel=(j-1)/(#group-1)-.5;local d=rel*span/1000;n.startTime=math.max(0,n.startTime+d);n.endTime=math.max(n.startTime+.008,n.endTime+d) end end;table.clear(group) end
    for _,n in ipairs(out) do if not anchor or math.abs(n.originalStartTime-anchor)<=chordWindow then anchor=anchor or n.originalStartTime;group[#group+1]=n else flush();anchor=n.originalStartTime;group[#group+1]=n end end;flush();table.sort(out,function(a,b)return a.startTime==b.startTime and a.note<b.note or a.startTime<b.startTime end)
    return out,{seed=seed,averageTimingMs=#out>0 and sumAbs/#out or 0,maxTimingMs=peak}
end
function Humanizer.autoSeed()local t=os.clock()*100000+tick()*1000;return math.floor(t%2147483646)+1 end
return Humanizer
