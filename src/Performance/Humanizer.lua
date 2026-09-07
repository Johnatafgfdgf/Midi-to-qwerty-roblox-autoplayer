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
