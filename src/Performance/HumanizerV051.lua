local Humanizer={}
local function fract(x)return x-math.floor(x)end
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
local function hash(seed,x)return fract(math.sin((x+seed*.000173)*12.9898+seed*.01337)*43758.5453123)*2-1 end
local function smoothstep(x)return x*x*(3-2*x)end
local function noise(seed,t,scale)local x=t/math.max(scale or 1,.001);local i=math.floor(x);local f=x-i;local a,b=hash(seed,i),hash(seed,i+1);return a+(b-a)*smoothstep(f)end
local function copyNote(n)local c={};for k,v in pairs(n)do c[k]=v end;if n.parts then local p={};for k,v in pairs(n.parts)do p[k]=v end;c.parts=p end;return c end
local function normVel(v)v=tonumber(v) or .7;if v>1 then v=v/127 end;return clamp(v,0,1)end
local function bpmAdaptive(ms,bpm)return (ms or 0)*clamp(120/(bpm or 120),.45,1.30)end
local PRESETS={
 Exact={strength=0,timingMs=0,durationVariation=0,chordSpreadMs=0,swingMs=0,rubato=0,handIndependence=0,phraseExpression=0},
 ["Very Subtle"]={strength=.08,timingMs=3,durationVariation=.008,chordSpreadMs=2,swingMs=.4,rubato=.03,handIndependence=.18,phraseExpression=.18},
 Natural={strength=.16,timingMs=5,durationVariation=.014,chordSpreadMs=4,swingMs=.8,rubato=.07,handIndependence=.28,phraseExpression=.32},
 Pianist={strength=.18,timingMs=6,durationVariation=.018,chordSpreadMs=5,swingMs=.8,rubato=.11,handIndependence=.38,phraseExpression=.48},
 Soft={strength=.14,timingMs=4,durationVariation=.022,chordSpreadMs=3,swingMs=.4,rubato=.09,handIndependence=.24,phraseExpression=.38},
 Energetic={strength=.17,timingMs=4,durationVariation=.010,chordSpreadMs=3,swingMs=1.1,rubato=.04,handIndependence=.20,phraseExpression=.26},
 Expressive={strength=.24,timingMs=7,durationVariation=.022,chordSpreadMs=6,swingMs=1.0,rubato=.13,handIndependence=.42,phraseExpression=.52},
}
local function cfg(settings)
 local e={};for k,v in pairs(settings or {})do e[k]=v end;local p=PRESETS[e.preset];if p then for k,v in pairs(p)do if e.preset~="Custom" then e[k]=v end end end
 e.strength=clamp(e.enabled==false and 0 or (e.strength or 0),0,1);e.timingMs=clamp(e.timingMs or 4,0,30);e.durationVariation=clamp(e.durationVariation or .01,0,.35);e.chordSpreadMs=clamp(e.chordSpreadMs or 3,0,28);e.swingMs=clamp(e.swingMs or 0,0,25);e.rubato=clamp(e.rubato or 0,0,.35);e.handIndependence=clamp(e.handIndependence or 0,0,1);e.phraseExpression=clamp(e.phraseExpression or 0,0,1);e.latencyMs=clamp(e.latencyMs or 0,-80,80);e.velocityPreservation=clamp(e.velocityPreservation or .84,.4,1);e.dynamicContour=clamp(e.dynamicContour or .55,0,1);return e
end
local function buildPhrases(notes)
 local p={};for _,n in ipairs(notes)do local id=n.phraseId or 0;local x=p[id] or {start=n.startTime or 0,finish=n.endTime or n.startTime or 0,count=0};x.start=math.min(x.start,n.startTime or 0);x.finish=math.max(x.finish,n.endTime or n.startTime or 0);x.count+=1;p[id]=x end;return p
end
local function phrasePos(n,p)local x=p[n.phraseId or 0];if not x or x.finish-x.start<.001 then return .5 end;return clamp(((n.startTime or 0)-x.start)/(x.finish-x.start),0,1)end
local function dynamicTarget(n,pos,seed,strength,contour)
 local src=normVel(n.velocity);local role=0
 if n.parts then if n.parts.melody then role+=.075 elseif n.parts.bass then role+=.025 else role-=.025 end end
 local shape=(math.sin(pos*math.pi)*.085-(pos>.86 and (pos-.86)/.14*.055 or 0))*contour
 local correlated=noise(seed+701,n.startTime or 0,1.35)*.045*strength
 return clamp(src+role*strength+shape*strength+correlated,.06,.99)
end
function Humanizer.generate(notes,settings,context)
 local c=cfg(settings);context=context or {};local seed=context.seed or c.fixedSeed or 12345;local bpm=context.bpm or 120;local strength=c.strength;local out={};local phrases=buildPhrases(notes)
 if strength<=0 then for i,n in ipairs(notes)do local x=copyNote(n);x.originalVelocity=normVel(n.velocity);x.expressiveVelocity=x.originalVelocity;out[i]=x end;return out,{seed=seed,averageTimingMs=0,maxTimingMs=0,velocityMin=0,velocityMax=1,preset=c.preset or "Exact"}end
 local timingMax=bpmAdaptive(c.timingMs,bpm)*strength;local latency=(c.latencyMs or 0)/1000;local chordWindow=(context.chordWindowMs or 10)/1000;local durationVar=c.durationVariation*strength;local rubatoMs=bpmAdaptive(9,bpm)*c.rubato*strength;local handMs=bpmAdaptive(6,bpm)*c.handIndependence*strength;local phraseMs=bpmAdaptive(8,bpm)*c.phraseExpression*strength
 local prevByHand={};local sumAbs,peak=0,0;local vmin,vmax=1,0;local groupId,groupAnchor=0,nil
 for i,n in ipairs(notes)do
   local base=n.startTime or 0;if not groupAnchor or math.abs(base-groupAnchor)>chordWindow then groupId+=1;groupAnchor=base end
   local x=copyNote(n);local pos=phrasePos(n,phrases);local src=normVel(n.velocity);local dyn=dynamicTarget(n,pos,seed,strength,c.dynamicContour)
   local expressive=clamp(src*c.velocityPreservation+dyn*(1-c.velocityPreservation),.05,1)
   -- If the MIDI itself is nearly flat, phrase dynamics gain a little more weight.
   expressive=clamp(expressive+(dyn-src)*.28*c.dynamicContour,.05,1)
   x.originalVelocity=src;x.expressiveVelocity=expressive;x.velocity=expressive;vmin=math.min(vmin,expressive);vmax=math.max(vmax,expressive)
   local prev,nextN=notes[i-1],notes[i+1];local densityScale=1;if prev and nextN then local span=math.max((nextN.startTime or base)-(prev.startTime or base),.03);densityScale=clamp(10/math.max(2/span,1),.42,1)end
   local accentStability=clamp(1.15-expressive*.42,.70,1.08);local maxMs=timingMax*densityScale*accentStability
   local global=noise(seed+11,base,5.2)*.24*maxMs;local phraseId=n.phraseId or 0;local phrase=noise(seed+31+phraseId*17,base,1.75)*phraseMs
   local hand=(n.parts and n.parts.hand) or "Right";local handCurve=noise(seed+(hand=="Left" and 103 or 211),base,1.1)*handMs
   local micro=hash(seed+997,i)*maxMs*.12
   local prevHand=prevByHand[hand];local leapDelay=0;if prevHand then local leap=math.abs((n.note or 0)-(prevHand.note or 0));if leap>7 then leapDelay=math.min((leap-7)*.11,2.2)*strength end end;prevByHand[hand]=n
   local breath=(pos>.76 and ((pos-.76)/.24)^2 or -math.sin(pos*math.pi)*.16)*rubatoMs
   local sw=((i%2)==0 and 1 or -1)*(c.swingMs or 0)*strength*.35
   local offsetMs=global+phrase+handCurve+micro+leapDelay+breath+sw+(c.latencyMs or 0)
   local capMs=maxMs+math.abs(phraseMs)+math.abs(handMs)+math.abs(rubatoMs)+math.abs(c.latencyMs or 0)+3;offsetMs=clamp(offsetMs,-capMs,capMs)
   x.originalStartTime=n.startTime;x.originalEndTime=n.endTime;x.startTime=math.max(0,base+offsetMs/1000)
   local dur=n.duration or math.max(.02,(n.endTime or base+.08)-base);local artScale=n.articulation=="Staccato" and .45 or n.articulation=="Legato" and .65 or 1
   local dynDur=1+(expressive-.5)*.045*strength;local dFactor=(1+hash(seed+4001,i)*durationVar*artScale)*dynDur;x.endTime=math.max(x.startTime+.008,base+dur*dFactor+offsetMs/1000);x.duration=x.endTime-x.startTime;x.humanOffsetMs=offsetMs;x.attackGroup=groupId
   out[i]=x;sumAbs+=math.abs(offsetMs);peak=math.max(peak,math.abs(offsetMs))
 end
 -- Hand-specific chord rolls. Forte structural chords stay tighter; softer ones breathe more.
 table.sort(out,function(a,b)if a.attackGroup==b.attackGroup then return (a.note or 0)<(b.note or 0)end;return (a.startTime or 0)<(b.startTime or 0)end)
 local groups={};for _,n in ipairs(out)do groups[n.attackGroup]=groups[n.attackGroup] or {};groups[n.attackGroup][#groups[n.attackGroup]+1]=n end
 for gid,g in pairs(groups)do
   if #g>=2 and c.chordSpreadMs>0 then
      local avg=0;for _,n in ipairs(g)do avg+=n.expressiveVelocity or .7 end;avg/=#g
      local span=math.min(c.chordSpreadMs*strength*(1.12-avg*.42),1.4+(#g-1)*1.1)
      local left,right={},{};for _,n in ipairs(g)do if n.parts and n.parts.hand=="Left" then left[#left+1]=n else right[#right+1]=n end end
      local function roll(list,dir)
         if #list<2 then return end;table.sort(list,function(a,b)return (a.note or 0)<(b.note or 0)end);if dir<0 then local rev={};for i=#list,1,-1 do rev[#rev+1]=list[i]end;list=rev end
         for j,n in ipairs(list)do local rel=(j-1)/(#list-1)-.5;local d=rel*span/1000;n.startTime=math.max(0,n.startTime+d);n.endTime=math.max(n.startTime+.008,n.endTime+d)end
      end
      roll(left,1);local rdir=hash(seed+811,gid)>-.18 and 1 or -1;roll(right,rdir)
   end
 end
 for _,n in ipairs(out)do n.attackGroup=nil end
 table.sort(out,function(a,b)if a.startTime==b.startTime then return (a.note or 0)<(b.note or 0)end;return a.startTime<b.startTime end)
 return out,{seed=seed,averageTimingMs=#out>0 and sumAbs/#out or 0,maxTimingMs=peak,velocityMin=vmin,velocityMax=vmax,preset=c.preset or "Custom",nativePressureRequested=true}
end
function Humanizer.autoSeed()local t=os.clock()*100000+(tick and tick() or os.time())*1000;return math.floor(t%2147483646)+1 end
return Humanizer
