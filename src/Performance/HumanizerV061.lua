local Humanizer={}

local function fract(x)return x-math.floor(x)end
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
local function hash(seed,x)return fract(math.sin((x+seed*.000173)*12.9898+seed*.01337)*43758.5453123)*2-1 end
local function smoothstep(x)return x*x*(3-2*x)end
local function noise(seed,t,scale)
    local x=t/math.max(scale or 1,.001);local i=math.floor(x);local f=x-i
    local a,b=hash(seed,i),hash(seed,i+1)
    return a+(b-a)*smoothstep(f)
end
local function copyNote(n)
    local c={};for k,v in pairs(n)do c[k]=v end
    if n.parts then local p={};for k,v in pairs(n.parts)do p[k]=v end;c.parts=p end
    return c
end
local function normVel(v)
    v=tonumber(v) or .7;if v>1 then v=v/127 end;return clamp(v,0,1)
end
local function bpmScale(bpm)return clamp(120/math.max(40,bpm or 120),.55,1.30)end

-- Values below are real musical ranges. Strength blends into them once.
-- Previous builds multiplied the preset values by a tiny preset strength a second
-- time, reducing a nominal 6 ms variation to around 1 ms.
local PRESETS={
    Exact={defaultStrength=0,timingMs=0,phraseMs=0,handMs=0,microMs=0,chordSpreadMs=0,rubatoMs=0,durationVariation=0,dynamicContour=0},
    ["Very Subtle"]={defaultStrength=.38,timingMs=5,phraseMs=5,handMs=3,microMs=1.5,chordSpreadMs=5,rubatoMs=4,durationVariation=.012,dynamicContour=.24},
    Natural={defaultStrength=.56,timingMs=8,phraseMs=8,handMs=4.5,microMs=2.2,chordSpreadMs=8,rubatoMs=7,durationVariation=.020,dynamicContour=.38},
    Pianist={defaultStrength=.68,timingMs=10,phraseMs=11,handMs=6,microMs=2.8,chordSpreadMs=11,rubatoMs=10,durationVariation=.027,dynamicContour=.52},
    Expressive={defaultStrength=.82,timingMs=14,phraseMs=15,handMs=8,microMs=3.6,chordSpreadMs=16,rubatoMs=14,durationVariation=.038,dynamicContour=.66},
}

local function cfg(settings)
    local src=settings or {};local e={};for k,v in pairs(src)do e[k]=v end
    local p=PRESETS[e.preset] or PRESETS.Pianist
    e.strength=clamp(e.enabled==false and 0 or (tonumber(e.strength) or p.defaultStrength),0,1)
    e.timingMs=clamp(tonumber(e.timingMs) or p.timingMs,0,30)
    e.phraseMs=clamp(tonumber(e.phraseMs) or p.phraseMs,0,30)
    e.handMs=clamp(tonumber(e.handMs) or p.handMs,0,20)
    e.microMs=clamp(tonumber(e.microMs) or p.microMs,0,10)
    e.chordSpreadMs=clamp(tonumber(e.chordSpreadMs) or p.chordSpreadMs,0,30)
    e.rubatoMs=clamp(tonumber(e.rubatoMs) or p.rubatoMs,0,30)
    e.durationVariation=clamp(tonumber(e.durationVariation) or p.durationVariation,0,.12)
    e.dynamicContour=clamp(tonumber(e.dynamicContour) or p.dynamicContour,0,1)
    e.velocityPreservation=clamp(tonumber(e.velocityPreservation) or .88,.45,1)
    e.latencyMs=clamp(tonumber(e.latencyMs) or 0,-80,80)
    e.preset=e.preset or "Pianist"
    return e,p
end

local function buildPhrases(notes)
    local p={}
    for _,n in ipairs(notes)do
        local id=n.phraseId or 0
        local x=p[id] or {start=n.startTime or 0,finish=n.endTime or n.startTime or 0,count=0}
        x.start=math.min(x.start,n.startTime or 0);x.finish=math.max(x.finish,n.endTime or n.startTime or 0);x.count+=1;p[id]=x
    end
    return p
end
local function phrasePos(n,phrases)
    local x=phrases[n.phraseId or 0]
    if not x or x.finish-x.start<.001 then return .5 end
    return clamp(((n.startTime or 0)-x.start)/(x.finish-x.start),0,1)
end
local function densityScale(notes,i)
    local n=notes[i];local base=n.startTime or 0
    local a=notes[math.max(1,i-2)];local b=notes[math.min(#notes,i+2)]
    if not a or not b then return 1 end
    local span=math.max(.04,(b.startTime or base)-(a.startTime or base))
    local rate=math.max(1,4/span)
    return clamp(12/rate,.42,1)
end
local function dynamicVelocity(n,pos,seed,strength,contour)
    local src=normVel(n.velocity);local role=0
    if n.parts then
        if n.parts.melody then role=.06 elseif n.parts.bass then role=.025 else role=-.025 end
    end
    local arch=math.sin(pos*math.pi)*.075
    local phraseEnd=pos>.82 and -((pos-.82)/.18)*.055 or 0
    local longCurve=noise(seed+707,n.startTime or 0,1.8)*.035
    local target=src+(arch+phraseEnd+longCurve)*contour+role*strength
    return clamp(src*(.72+.28*1)+target*(1-(.72+.28*1)),.05,.99)
end

local function groupChords(notes,window)
    local gid=0;local anchor=nil
    for _,n in ipairs(notes)do
        local t=n.startTime or 0
        if not anchor or math.abs(t-anchor)>window then gid+=1;anchor=t end
        n.__humanGroup=gid
    end
end

function Humanizer.generate(notes,settings,context)
    local c,preset=cfg(settings);context=context or {}
    local seed=context.seed or c.fixedSeed or 12345;local bpm=context.bpm or 120
    local out={};local phrases=buildPhrases(notes)
    if c.strength<=0 then
        for i,n in ipairs(notes)do local x=copyNote(n);x.originalVelocity=normVel(n.velocity);x.expressiveVelocity=x.originalVelocity;x.humanOffsetMs=0;out[i]=x end
        return out,{seed=seed,averageTimingMs=0,maxTimingMs=0,stdTimingMs=0,velocityMin=0,velocityMax=1,preset="Exact",humanizedCount=0}
    end

    local bs=bpmScale(bpm);local s=c.strength
    -- one and only one master blend
    local timingRange=c.timingMs*bs*s
    local phraseRange=c.phraseMs*bs*s
    local handRange=c.handMs*bs*s
    local microRange=c.microMs*bs*s
    local rubatoRange=c.rubatoMs*bs*s
    local durationVar=c.durationVariation*s
    local chordWindow=(context.chordWindowMs or 8)/1000
    local prevByHand={};local offsets={};local vmin,vmax=1,0

    for i,n in ipairs(notes)do
        local x=copyNote(n);local base=n.startTime or 0;local pos=phrasePos(n,phrases);local dens=densityScale(notes,i)
        local src=normVel(n.velocity)
        local dyn=dynamicVelocity(n,pos,seed,s,c.dynamicContour)
        local expressive=clamp(src*c.velocityPreservation+dyn*(1-c.velocityPreservation),.05,1)
        x.originalVelocity=src;x.expressiveVelocity=expressive;x.velocity=expressive
        vmin=math.min(vmin,expressive);vmax=math.max(vmax,expressive)

        -- correlated musical layers, not independent random jitter
        local global=noise(seed+13,base,4.8)*timingRange*.35
        local phraseId=n.phraseId or 0
        local phrase=noise(seed+31+phraseId*19,base,1.35)*phraseRange*.62
        local phraseArc=(math.sin(pos*math.pi*2-.65)*.36 + (pos>.82 and (pos-.82)/.18*.50 or 0))*phraseRange
        local hand=(n.parts and n.parts.hand) or "Right"
        local handCurve=noise(seed+(hand=="Left" and 107 or 223),base,1.0)*handRange
        local micro=hash(seed+997,i)*microRange*dens
        local prev=prevByHand[hand];local leap=0
        if prev then
            local semis=math.abs((n.note or 0)-(prev.note or 0));local dt=math.max(.02,base-(prev.startTime or 0))
            if semis>7 and dt<.5 then leap=math.min(4.5,(semis-7)*.30)*s*bs end
        end
        prevByHand[hand]=n
        local rubato=(math.sin(pos*math.pi)*-.28 + (pos>.72 and ((pos-.72)/.28)^2*.72 or 0))*rubatoRange
        local offsetMs=(global+phrase+phraseArc+handCurve+micro+leap+rubato+c.latencyMs)*dens

        -- Strong attacks are a little steadier, a common pianist behaviour.
        offsetMs*=clamp(1.16-expressive*.32,.78,1.08)

        -- Safety: don't move a note more than 32% of the local gap to the previous
        -- event, so expressive timing never scrambles a fast run.
        local prevAny=notes[i-1]
        if prevAny then
            local gap=(base-(prevAny.startTime or base))*1000
            if gap>1 then local cap=math.max(2,gap*.32);offsetMs=clamp(offsetMs,-cap,cap) end
        end
        local absoluteCap=math.max(4,timingRange+phraseRange+handRange+rubatoRange+microRange)
        offsetMs=clamp(offsetMs,-absoluteCap,absoluteCap)

        x.originalStartTime=n.startTime;x.originalEndTime=n.endTime
        x.startTime=math.max(0,base+offsetMs/1000)
        local dur=n.duration or math.max(.02,(n.endTime or base+.08)-base)
        local durNoise=hash(seed+4001,i)*durationVar
        local articulation=n.articulation=="Staccato" and .62 or n.articulation=="Legato" and 1.03 or 1
        local dFactor=(1+durNoise)*articulation
        x.endTime=math.max(x.startTime+.008,x.startTime+dur*dFactor)
        x.duration=x.endTime-x.startTime;x.humanOffsetMs=offsetMs
        out[#out+1]=x;offsets[#offsets+1]=offsetMs
    end

    table.sort(out,function(a,b)if a.startTime==b.startTime then return (a.note or 0)<(b.note or 0)end;return a.startTime<b.startTime end)
    groupChords(out,chordWindow)
    local groups={}
    for _,n in ipairs(out)do groups[n.__humanGroup]=groups[n.__humanGroup] or {};groups[n.__humanGroup][#groups[n.__humanGroup]+1]=n end
    for gid,g in pairs(groups)do
        if #g>=2 and c.chordSpreadMs>0 then
            local left,right={},{}
            for _,n in ipairs(g)do if n.parts and n.parts.hand=="Left" then left[#left+1]=n else right[#right+1]=n end end
            local function roll(list,dir,amount)
                if #list<2 then return end
                table.sort(list,function(a,b)return (a.note or 0)<(b.note or 0)end)
                if dir<0 then local r={};for i=#list,1,-1 do r[#r+1]=list[i]end;list=r end
                for j,n in ipairs(list)do
                    local rel=(j-1)/(#list-1)-.5;local d=rel*amount/1000
                    n.startTime=math.max(0,n.startTime+d);n.endTime=math.max(n.startTime+.008,n.endTime+d);n.humanOffsetMs=(n.humanOffsetMs or 0)+d*1000
                end
            end
            local amount=c.chordSpreadMs*bs*s
            roll(left,1,amount*.78)
            roll(right,hash(seed+811,gid)>.18 and -1 or 1,amount)
        end
    end
    for _,n in ipairs(out)do n.__humanGroup=nil end
    table.sort(out,function(a,b)if a.startTime==b.startTime then return (a.note or 0)<(b.note or 0)end;return a.startTime<b.startTime end)

    local sum,peak=0,0
    for _,n in ipairs(out)do local a=math.abs(n.humanOffsetMs or 0);sum+=a;peak=math.max(peak,a)end
    local mean=#out>0 and sum/#out or 0;local sq=0
    for _,n in ipairs(out)do local d=math.abs(n.humanOffsetMs or 0)-mean;sq+=d*d end
    local std=#out>0 and math.sqrt(sq/#out) or 0
    return out,{seed=seed,averageTimingMs=mean,maxTimingMs=peak,stdTimingMs=std,velocityMin=vmin,velocityMax=vmax,preset=c.preset,humanizedCount=#out,strength=s}
end

function Humanizer.autoSeed()
    local t=os.clock()*100000+(tick and tick() or os.time())*1000
    return math.floor(t%2147483646)+1
end
return Humanizer
