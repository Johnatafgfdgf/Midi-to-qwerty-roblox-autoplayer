local Humanizer={}

local function fract(x)return x-math.floor(x)end
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
local function hash(seed,x)
    return fract(math.sin((x+seed*.000173)*12.9898+seed*.01337)*43758.5453123)*2-1
end
local function smoothstep(x)return x*x*(3-2*x)end
local function noise(seed,t,scale)
    scale=math.max(scale or 1,.001)
    local x=t/scale;local i=math.floor(x);local f=x-i
    local a,b=hash(seed,i),hash(seed,i+1)
    return a+(b-a)*smoothstep(f)
end
local function copyNote(n)
    local c={};for k,v in pairs(n)do c[k]=v end
    if n.parts then local p={};for k,v in pairs(n.parts)do p[k]=v end;c.parts=p end
    return c
end
local function bpmAdaptive(ms,bpm)
    return (ms or 0)*clamp(120/(bpm or 120),.45,1.30)
end
local function curveVelocity(v,curve,mix)
    v=clamp(v or .7,.03,1);mix=clamp(mix or 0,0,1)
    local target=v
    if curve=="Soft" then target=math.sqrt(v)
    elseif curve=="Expressive" then
        target=v<.5 and 2*v*v or 1-((-2*v+2)^2)/2
    elseif curve=="Strong" then target=v^.72 end
    return clamp(v*(1-mix)+target*mix,.03,1)
end

local PRESETS={
    ["Exact"]={strength=0,timingMs=0,durationVariation=0,chordSpreadMs=0,swingMs=0,rubato=.0,handIndependence=0,phraseExpression=0},
    ["Very Subtle"]={timingMs=3,durationVariation=.008,chordSpreadMs=2,swingMs=.5,rubato=.03,handIndependence=.18,phraseExpression=.18},
    Natural={timingMs=5,durationVariation=.014,chordSpreadMs=4,swingMs=1.0,rubato=.07,handIndependence=.28,phraseExpression=.32},
    Pianist={timingMs=6,durationVariation=.018,chordSpreadMs=5,swingMs=.8,rubato=.11,handIndependence=.38,phraseExpression=.48},
    Soft={timingMs=4,durationVariation=.022,chordSpreadMs=3,swingMs=.5,rubato=.09,handIndependence=.24,phraseExpression=.38},
    Energetic={timingMs=4,durationVariation=.010,chordSpreadMs=3,swingMs=1.4,rubato=.04,handIndependence=.20,phraseExpression=.26},
    Expressive={timingMs=7,durationVariation=.022,chordSpreadMs=6,swingMs=1.2,rubato=.13,handIndependence=.42,phraseExpression=.52},
}

local function effectiveSettings(settings)
    local e={};for k,v in pairs(settings or {})do e[k]=v end
    local p=PRESETS[e.preset]
    if p then for k,v in pairs(p)do if k~="strength" then e[k]=v end end;if p.strength~=nil then e.strength=p.strength end end
    e.strength=clamp(e.enabled==false and 0 or (e.strength or 0),0,1)
    e.timingMs=clamp(e.timingMs or 3,0,30)
    e.durationVariation=clamp(e.durationVariation or .008,0,.35)
    e.chordSpreadMs=clamp(e.chordSpreadMs or 2,0,28)
    e.swingMs=clamp(e.swingMs or 0,0,25)
    e.rubato=clamp(e.rubato or 0,0,.35)
    e.handIndependence=clamp(e.handIndependence or 0,0,1)
    e.phraseExpression=clamp(e.phraseExpression or 0,0,1)
    e.latencyMs=clamp(e.latencyMs or 0,-80,80)
    e.expressionCurve=e.expressionCurve or "Soft"
    return e
end

function Humanizer.generate(notes,settings,context)
    local cfg=effectiveSettings(settings or {});context=context or {}
    local strength=cfg.strength
    local seed=context.seed or cfg.fixedSeed or 12345
    local bpm=context.bpm or 120
    local out={}
    if strength<=0 then
        for i,n in ipairs(notes)do out[i]=copyNote(n)end
        return out,{seed=seed,averageTimingMs=0,maxTimingMs=0,preset=cfg.preset or "Exact",latencyMs=cfg.latencyMs or 0}
    end

    local timingMax=bpmAdaptive(cfg.timingMs,bpm)*strength
    local latency=(cfg.latencyMs or 0)/1000
    local chordWindow=(context.chordWindowMs or 10)/1000
    local swing=(cfg.swingMs or 0)*strength/1000
    local durationVar=cfg.durationVariation*strength
    local rubatoMs=bpmAdaptive(10,bpm)*cfg.rubato*strength
    local handMs=bpmAdaptive(7,bpm)*cfg.handIndependence*strength
    local phraseMs=bpmAdaptive(10,bpm)*cfg.phraseExpression*strength
    local sumAbs,peak=0,0

    -- Group musical attacks first so chord identity is preserved.
    local groupId=0;local groupAnchor=nil
    local attackGroup={}
    for i,n in ipairs(notes)do
        if not groupAnchor or math.abs((n.startTime or 0)-groupAnchor)>chordWindow then
            groupId+=1;groupAnchor=n.startTime or 0
        end
        attackGroup[i]=groupId
    end

    for i,n in ipairs(notes)do
        local c=copyNote(n)
        local base=n.startTime or 0
        local prev,nextN=notes[i-1],notes[i+1]
        local densityScale=1
        if prev and nextN then
            local span=math.max((nextN.startTime or base)-(prev.startTime or base),.03)
            densityScale=clamp(10/math.max(2/span,1),.42,1)
        end

        local velocity=n.velocity or .7
        if velocity>1 then velocity=velocity/127 end
        local accentStability=clamp(1.12-velocity*.38,.72,1.08)
        local maxMs=timingMax*densityScale*accentStability

        -- Correlated layers: global -> phrase -> hand -> tiny note microvariation.
        local global=noise(seed+11,base,5.2)*.26*maxMs
        local phraseId=n.phraseId or 0
        local phrase=noise(seed+31+phraseId*17,base,1.75)*phraseMs
        local handSide=(n.parts and n.parts.hand=="Left") and -1 or 1
        local handCurve=noise(seed+(handSide<0 and 103 or 211),base,1.10)*handMs
        local micro=hash(seed+997,i)*maxMs*.14

        -- Very small alternating swing component. It never changes note pitch/order.
        local sw=((i%2)==0 and 1 or -1)*swing
        local rub=math.sin(base*.83+(phraseId*.41))*rubatoMs/1000
        local offsetSec=(global+phrase+handCurve+micro)/1000 + sw + rub + latency

        -- Keep strong chord members close to the same attack before spread is applied.
        local maxOffset=(maxMs+math.abs(rubatoMs)+math.abs(handMs)+math.abs(phraseMs))/1000 + math.abs(latency)
        offsetSec=clamp(offsetSec,-maxOffset,maxOffset)
        c.originalStartTime=n.startTime;c.originalEndTime=n.endTime
        c.startTime=math.max(0,base+offsetSec)

        local dur=n.duration or math.max(.02,(n.endTime or base+.08)-base)
        local artScale=n.articulation=="Staccato" and .45 or n.articulation=="Legato" and .60 or 1
        local dFactor=1+hash(seed+4001,i)*durationVar*artScale
        c.endTime=math.max(c.startTime+.008,base+dur*dFactor+offsetSec)
        c.duration=c.endTime-c.startTime
        c.velocity=curveVelocity(velocity,cfg.expressionCurve,strength)
        c.humanOffsetMs=offsetSec*1000
        c.attackGroup=attackGroup[i]
        out[i]=c
        sumAbs+=math.abs(c.humanOffsetMs);peak=math.max(peak,math.abs(c.humanOffsetMs))
    end

    table.sort(out,function(a,b)
        if a.startTime==b.startTime then return (a.note or 0)<(b.note or 0) end
        return a.startTime<b.startTime
    end)

    -- Natural chord spread, bounded and deterministic. Structural attacks remain tight.
    local spreadMax=cfg.chordSpreadMs*strength
    if spreadMax>0 then
        local group={};local gid=nil
        local function flush()
            if #group>=2 then
                table.sort(group,function(a,b)return (a.note or 0)<(b.note or 0)end)
                local span=math.min(spreadMax,1.5+(#group-1)*1.15)
                for j,n in ipairs(group)do
                    local rel=(j-1)/(#group-1)-.5
                    local d=rel*span/1000
                    n.startTime=math.max(0,n.startTime+d)
                    n.endTime=math.max(n.startTime+.008,n.endTime+d)
                end
            end
            group={}
        end
        for _,n in ipairs(out)do
            if gid==nil or n.attackGroup==gid then gid=n.attackGroup;group[#group+1]=n
            else flush();gid=n.attackGroup;group[#group+1]=n end
        end
        flush()
    end

    for _,n in ipairs(out)do n.attackGroup=nil end
    table.sort(out,function(a,b)
        if a.startTime==b.startTime then return (a.note or 0)<(b.note or 0) end
        return a.startTime<b.startTime
    end)

    return out,{
        seed=seed,averageTimingMs=#out>0 and sumAbs/#out or 0,maxTimingMs=peak,
        preset=cfg.preset or "Custom",latencyMs=cfg.latencyMs,curve=cfg.expressionCurve,
        swingMs=cfg.swingMs,rubato=cfg.rubato,handIndependence=cfg.handIndependence,
    }
end

function Humanizer.autoSeed()
    local t=os.clock()*100000+(tick and tick() or os.time())*1000
    return math.floor(t%2147483646)+1
end

return Humanizer
