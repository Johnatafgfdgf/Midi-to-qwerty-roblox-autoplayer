local Humanizer = {}

local function fract(x) return x-math.floor(x) end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function hash(seed,x)
    return fract(math.sin((x+seed*.000173)*12.9898+seed*.01337)*43758.5453123)*2-1
end
local function smoothstep(x) return x*x*(3-2*x) end
local function noise(seed,t,scale)
    local x=t/math.max(scale or 1,.001)
    local i=math.floor(x); local f=x-i
    local a,b=hash(seed,i),hash(seed,i+1)
    return a+(b-a)*smoothstep(f)
end
local function copyNote(n)
    local c={}
    for k,v in pairs(n) do c[k]=v end
    if n.parts then
        c.parts={}
        for k,v in pairs(n.parts) do c.parts[k]=v end
    end
    return c
end
local function normVel(v)
    v=tonumber(v) or .7
    if v>1 then v=v/127 end
    return clamp(v,0,1)
end
local function bpmScale(bpm)
    return clamp(120/math.max(40,bpm or 120),.48,1.35)
end

local PRESETS = {
    Exact={strength=0,timingMs=0,phraseMs=0,handMs=0,microMs=0,chordSpreadMs=0,rubatoMs=0,localTempoPercent=0,motifVariation=0,durationVariation=0,dynamicContour=0,velocityPreservation=1},
    ["Very Subtle"]={strength=.38,timingMs=5,phraseMs=6,handMs=3,microMs=1.2,chordSpreadMs=4,rubatoMs=4,localTempoPercent=.8,motifVariation=.18,durationVariation=.010,dynamicContour=.25,velocityPreservation=.92},
    Natural={strength=.56,timingMs=8,phraseMs=10,handMs=4.5,microMs=1.8,chordSpreadMs=7,rubatoMs=7,localTempoPercent=1.5,motifVariation=.34,durationVariation=.018,dynamicContour=.40,velocityPreservation=.89},
    Pianist={strength=.72,timingMs=11,phraseMs=14,handMs=7,microMs=2.6,chordSpreadMs=12,rubatoMs=12,localTempoPercent=2.2,motifVariation=.48,durationVariation=.030,dynamicContour=.58,velocityPreservation=.86},
    Expressive={strength=.86,timingMs=15,phraseMs=19,handMs=9,microMs=3.2,chordSpreadMs=17,rubatoMs=16,localTempoPercent=3.2,motifVariation=.68,durationVariation=.044,dynamicContour=.72,velocityPreservation=.82},
}

function Humanizer.getPreset(name)
    local src=PRESETS[name]
    if not src then return nil end
    local out={preset=name}
    for k,v in pairs(src) do out[k]=v end
    return out
end

function Humanizer.applyPreset(settings,name)
    settings=settings or {}
    local p=Humanizer.getPreset(name)
    if not p then return settings end
    for k,v in pairs(p) do settings[k]=v end
    settings.enabled=name~="Exact"
    settings.preset=name
    return settings
end

local function config(settings)
    local s={}
    for k,v in pairs(settings or {}) do s[k]=v end
    local p=PRESETS[s.preset] or PRESETS.Pianist
    if s.preset~="Custom" then
        for k,v in pairs(p) do if s[k]==nil then s[k]=v end end
    end
    s.strength=clamp(s.enabled==false and 0 or (tonumber(s.strength) or p.strength),0,1)
    s.timingMs=clamp(tonumber(s.timingMs) or p.timingMs,0,35)
    s.phraseMs=clamp(tonumber(s.phraseMs) or p.phraseMs,0,40)
    s.handMs=clamp(tonumber(s.handMs) or p.handMs,0,24)
    s.microMs=clamp(tonumber(s.microMs) or p.microMs,0,8)
    s.chordSpreadMs=clamp(tonumber(s.chordSpreadMs) or p.chordSpreadMs,0,28)
    s.rubatoMs=clamp(tonumber(s.rubatoMs) or p.rubatoMs,0,30)
    s.localTempoPercent=clamp(tonumber(s.localTempoPercent) or p.localTempoPercent,0,5)
    s.motifVariation=clamp(tonumber(s.motifVariation) or p.motifVariation,0,1)
    s.durationVariation=clamp(tonumber(s.durationVariation) or p.durationVariation,0,.09)
    s.dynamicContour=clamp(tonumber(s.dynamicContour) or p.dynamicContour,0,1)
    s.velocityPreservation=clamp(tonumber(s.velocityPreservation) or p.velocityPreservation,.45,1)
    s.latencyMs=clamp(tonumber(s.latencyMs) or 0,-80,80)
    s.preset=s.preset or "Pianist"
    return s
end

local function buildPhrases(notes)
    local phrases={}
    for _,n in ipairs(notes) do
        local id=n.phraseId or 0
        local p=phrases[id] or {start=n.startTime or 0,finish=n.endTime or n.startTime or 0,count=0}
        p.start=math.min(p.start,n.startTime or 0)
        p.finish=math.max(p.finish,n.endTime or n.startTime or 0)
        p.count+=1
        phrases[id]=p
    end
    return phrases
end
local function phrasePos(n,phrases)
    local p=phrases[n.phraseId or 0]
    if not p or p.finish-p.start<.001 then return .5 end
    return clamp(((n.startTime or 0)-p.start)/(p.finish-p.start),0,1)
end

local function densityScale(notes,i)
    local base=notes[i].startTime or 0
    local a=notes[math.max(1,i-2)]
    local b=notes[math.min(#notes,i+2)]
    if not a or not b then return 1 end
    local span=math.max(.04,(b.startTime or base)-(a.startTime or base))
    local rate=math.max(1,4/span)
    return clamp(11/rate,.36,1)
end

local function motifSignatures(notes)
    local ids={}
    local seen={}
    local nextId=1
    for i=1,#notes do
        local a=notes[i]
        local b=notes[i+1]
        local c=notes[i+2]
        if b and c then
            local hand=(a.parts and a.parts.hand) or "?"
            if ((b.parts and b.parts.hand) or "?")==hand and ((c.parts and c.parts.hand) or "?")==hand then
                local d1=clamp((b.note or 0)-(a.note or 0),-12,12)
                local d2=clamp((c.note or 0)-(b.note or 0),-12,12)
                local dt1=math.floor(math.max(.01,(b.startTime or 0)-(a.startTime or 0))*20+.5)
                local dt2=math.floor(math.max(.01,(c.startTime or 0)-(b.startTime or 0))*20+.5)
                local key=hand..":"..d1..":"..d2..":"..dt1..":"..dt2
                if not seen[key] then seen[key]=nextId;nextId+=1 end
                ids[i]=seen[key]
            end
        end
    end
    return ids
end

local function dynamicVelocity(n,pos,seed,s)
    local src=normVel(n.velocity)
    local role=0
    if n.parts then
        if n.parts.melody then role=.065
        elseif n.parts.bass then role=.025
        else role=-.018 end
    end
    local arch=math.sin(pos*math.pi)*.085
    local ending=pos>.82 and -((pos-.82)/.18)*.06 or 0
    local phraseMotion=noise(seed+707,n.startTime or 0,1.7)*.035
    local target=clamp(src+(arch+ending+phraseMotion)*s.dynamicContour+role*s.strength,.05,1)
    local expressive=src*s.velocityPreservation+target*(1-s.velocityPreservation)
    -- If source velocity is nearly flat, let the phrase contour still breathe a little.
    expressive+= (target-src)*.24*s.dynamicContour
    return clamp(expressive,.05,.99)
end

local function safeOffset(notes,i,base,offsetMs,absoluteCap)
    local cap=absoluteCap
    local prev=notes[i-1]
    local nxt=notes[i+1]
    if prev then
        local gap=(base-(prev.startTime or base))*1000
        if gap>1 then cap=math.min(cap,math.max(2,gap*.30)) end
    end
    if nxt then
        local gap=((nxt.startTime or base)-base)*1000
        if gap>1 then cap=math.min(cap,math.max(2,gap*.30)) end
    end
    return clamp(offsetMs,-cap,cap)
end

function Humanizer.generate(notes,settings,context)
    local s=config(settings)
    context=context or {}
    local seed=context.seed or s.fixedSeed or 12345
    local bpm=context.bpm or 120
    local bs=bpmScale(bpm)
    local phrases=buildPhrases(notes)
    local motifs=motifSignatures(notes)
    local out={}

    if s.strength<=0 then
        for i,n in ipairs(notes) do
            local x=copyNote(n)
            x.originalVelocity=normVel(n.velocity)
            x.expressiveVelocity=x.originalVelocity
            x.humanOffsetMs=0
            x.localTempoPercent=0
            out[i]=x
        end
        return out,{seed=seed,preset="Exact",strength=0,averageTimingMs=0,meanSignedMs=0,stdTimingMs=0,maxTimingMs=0,averageHandDifferenceMs=0,averageChordSpreadMs=0,localTempoMin=0,localTempoMax=0,velocityMin=0,velocityMax=1,humanizedCount=0}
    end

    local strength=s.strength
    local beatMs=60000/math.max(30,bpm)
    local timingRange=s.timingMs*bs*strength
    local phraseRange=s.phraseMs*bs*strength
    local handRange=s.handMs*bs*strength
    local microRange=s.microMs*bs*strength
    local rubatoRange=s.rubatoMs*bs*strength
    local tempoPct=s.localTempoPercent*strength
    local durationVar=s.durationVariation*strength
    local chordWindow=(context.chordWindowMs or 10)/1000
    local prevByHand={}
    local motifUse={}
    local signedOffsets={}
    local vmin,vmax=1,0
    local tempoMin,tempoMax=0,0

    for i,n in ipairs(notes) do
        local x=copyNote(n)
        local base=n.startTime or 0
        local pos=phrasePos(n,phrases)
        local dens=densityScale(notes,i)
        local expressive=dynamicVelocity(n,pos,seed,s)
        x.originalVelocity=normVel(n.velocity)
        x.expressiveVelocity=expressive
        x.velocity=expressive
        vmin=math.min(vmin,expressive);vmax=math.max(vmax,expressive)

        local phraseId=n.phraseId or 0
        local hand=(n.parts and n.parts.hand) or "Right"
        local global=noise(seed+13,base,5.1)*timingRange*.30
        local phraseNoise=noise(seed+31+phraseId*19,base,1.4)*phraseRange*.46
        local phraseShape=(math.sin(pos*math.pi*2-.65)*.30 + (pos>.78 and ((pos-.78)/.22)^2*.58 or 0))*phraseRange
        local handCurve=noise(seed+(hand=="Left" and 107 or 223),base,1.05)*handRange
        local micro=hash(seed+997,i)*microRange*dens
        local rubato=(math.sin(pos*math.pi)*-.24 + (pos>.70 and ((pos-.70)/.30)^2*.72 or 0))*rubatoRange

        -- Continuous local tempo warp. This is the main source of long-range human timing.
        local localPct=noise(seed+401+phraseId*7,base,2.6)*tempoPct
        localPct += math.sin(pos*math.pi*2)*tempoPct*.24
        tempoMin=math.min(tempoMin,localPct);tempoMax=math.max(tempoMax,localPct)
        local tempoWarp=(localPct/100)*beatMs*.62

        local prev=prevByHand[hand]
        local leap=0
        if prev then
            local semis=math.abs((n.note or 0)-(prev.note or 0))
            local dt=math.max(.02,base-(prev.startTime or 0))
            if semis>7 and dt<.55 then leap=math.min(5,(semis-7)*.32)*strength*bs end
        end
        prevByHand[hand]=n

        local motif=motifs[i]
        local motifOffset=0
        if motif then
            motifUse[motif]=(motifUse[motif] or 0)+1
            local occurrence=motifUse[motif]
            if occurrence>1 then
                motifOffset=noise(seed+1201+motif,occurrence,1)*s.motifVariation*strength*8*bs
            end
        end

        local offsetMs=(global+phraseNoise+phraseShape+handCurve+micro+rubato+tempoWarp+leap+motifOffset+s.latencyMs)*dens
        offsetMs*=clamp(1.15-expressive*.30,.78,1.08)
        local absoluteCap=math.max(5,timingRange+phraseRange*.72+handRange+rubatoRange+math.abs(tempoWarp)+microRange+4)
        offsetMs=safeOffset(notes,i,base,offsetMs,absoluteCap)

        x.originalStartTime=n.startTime
        x.originalEndTime=n.endTime
        x.startTime=math.max(0,base+offsetMs/1000)
        local dur=n.duration or math.max(.02,(n.endTime or base+.08)-base)
        local durNoise=hash(seed+4001,i)*durationVar
        local articulation=n.articulation=="Staccato" and .64 or n.articulation=="Legato" and 1.02 or 1
        local dFactor=(1+durNoise)*articulation
        x.endTime=math.max(x.startTime+.008,x.startTime+dur*dFactor)
        x.duration=x.endTime-x.startTime
        x.humanOffsetMs=offsetMs
        x.localTempoPercent=localPct
        x.__group=0
        out[#out+1]=x
        signedOffsets[#signedOffsets+1]=offsetMs
    end

    table.sort(out,function(a,b)
        if a.startTime==b.startTime then return (a.note or 0)<(b.note or 0) end
        return a.startTime<b.startTime
    end)

    -- Group attacks and interpret chords by hand.
    local gid,anchor=0,nil
    for _,n in ipairs(out) do
        local t=n.startTime or 0
        if not anchor or math.abs(t-anchor)>chordWindow then gid+=1;anchor=t end
        n.__group=gid
    end
    local groups={}
    for _,n in ipairs(out) do groups[n.__group]=groups[n.__group] or {};table.insert(groups[n.__group],n) end
    local totalSpread,spreadGroups=0,0
    local handDiffSum,handDiffCount=0,0
    for groupId,g in pairs(groups) do
        if #g>=2 and s.chordSpreadMs>0 then
            local left,right={},{}
            for _,n in ipairs(g) do
                if n.parts and n.parts.hand=="Left" then table.insert(left,n) else table.insert(right,n) end
            end
            local amount=s.chordSpreadMs*bs*strength
            local function roll(list,dir,scale)
                if #list<2 then return 0 end
                table.sort(list,function(a,b)return (a.note or 0)<(b.note or 0) end)
                if dir<0 then local r={};for j=#list,1,-1 do table.insert(r,list[j]) end;list=r end
                local minT,maxT=math.huge,-math.huge
                for j,n in ipairs(list) do
                    local rel=(j-1)/(#list-1)-.5
                    local d=rel*amount*scale/1000
                    n.startTime=math.max(0,n.startTime+d)
                    n.endTime=math.max(n.startTime+.008,n.endTime+d)
                    n.humanOffsetMs=(n.humanOffsetMs or 0)+d*1000
                    minT=math.min(minT,n.startTime);maxT=math.max(maxT,n.startTime)
                end
                return math.max(0,(maxT-minT)*1000)
            end
            local lSpread=roll(left,1,.72)
            local rdir=hash(seed+811,groupId)>.12 and 1 or -1
            local rSpread=roll(right,rdir,1)
            local spread=math.max(lSpread,rSpread)
            if spread>0 then totalSpread+=spread;spreadGroups+=1 end
            if #left>0 and #right>0 then
                local la,ra=0,0
                for _,n in ipairs(left) do la+=n.startTime end;la/=#left
                for _,n in ipairs(right) do ra+=n.startTime end;ra/=#right
                handDiffSum+=math.abs(la-ra)*1000;handDiffCount+=1
            end
        end
    end
    for _,n in ipairs(out) do n.__group=nil end
    table.sort(out,function(a,b)
        if a.startTime==b.startTime then return (a.note or 0)<(b.note or 0) end
        return a.startTime<b.startTime
    end)

    local meanSigned=0
    for _,v in ipairs(signedOffsets) do meanSigned+=v end
    meanSigned=#signedOffsets>0 and meanSigned/#signedOffsets or 0
    local absSum,peak,sq=0,0,0
    for _,v in ipairs(signedOffsets) do
        absSum+=math.abs(v);peak=math.max(peak,math.abs(v));sq+=(v-meanSigned)^2
    end
    local meanAbs=#signedOffsets>0 and absSum/#signedOffsets or 0
    local std=#signedOffsets>0 and math.sqrt(sq/#signedOffsets) or 0

    return out,{
        seed=seed,preset=s.preset,strength=strength,humanizedCount=#out,
        averageTimingMs=meanAbs,meanSignedMs=meanSigned,stdTimingMs=std,maxTimingMs=peak,
        averageHandDifferenceMs=handDiffCount>0 and handDiffSum/handDiffCount or 0,
        averageChordSpreadMs=spreadGroups>0 and totalSpread/spreadGroups or 0,
        localTempoMin=tempoMin,localTempoMax=tempoMax,
        velocityMin=vmin,velocityMax=vmax,
    }
end

function Humanizer.autoSeed()
    local t=os.clock()*100000+(tick and tick() or os.time())*1000
    return math.floor(t%2147483646)+1
end

return Humanizer
