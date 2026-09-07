local H=R('Performance/Humanizer');local P=R('Performance/PhraseEngine');local G=R('Profiles/GameProfile')
local notes={}
for phrase=0,2 do for i=0,15 do
 notes[#notes+1]={index=#notes+1,note=60+i%4,velocity=80,startTime=phrase*4+i*.25,endTime=phrase*4+i*.25+.22,duration=.22,startTick=(phrase*4+i*.25)*960,track=1,channel=1,parts={hand='Right',melody=true}}
end end
P.annotate(notes,120,nil,{}, {type='PPQN',ppqn=480})
check('motifs repeat with occurrence metadata',function()assert(notes[1].motifOccurrence==1 and notes[17].motifOccurrence==2 and notes[33].motifOccurrence==3)end)
local settings=H.applyPreset({strength=1},'Pianist')
local exact=H.generate(notes,{preset='Exact',strength=1},{seed=123})
local pianist,stats=H.generate(notes,settings,{seed=123,bpm=120})
check('Exact preserves pitch velocity start end and count',function()assert(#exact==#notes);for i,n in ipairs(exact)do local o=notes[i];assert(n.note==o.note and n.velocity==o.velocity and n.startTime==o.startTime and n.endTime==o.endTime)end end)
check('Pianist measurably differs from Exact',function()assert(stats.averageTimingMs>1 and stats.maxTimingMs>stats.averageTimingMs);print('METRICS Pianist',stats.averageTimingMs,stats.maxTimingMs,stats.stdTimingMs)end)
check('intensity zero is original for every preset',function()for name in pairs(H.presets)do local out=H.generate(notes,{preset=name,strength=0},{seed=99});for i,n in ipairs(out)do assert(n.startTime==notes[i].startTime and n.endTime==notes[i].endTime)end end end)
check('fixed seed deterministic; auto seed unique',function()local out=H.generate(notes,settings,{seed=123});for i,n in ipairs(out)do assert(n.startTime==pianist[i].startTime)end;assert(H.autoSeed()~=H.autoSeed())end)
check('phrase layers exceed individual jitter',function()local maxPhrase,maxMicro=0,0;for _,n in ipairs(pianist)do maxPhrase=math.max(maxPhrase,math.abs(n.layers.PhraseTempoCurve));maxMicro=math.max(maxMicro,math.abs(n.layers.MicroTiming))end;assert(maxPhrase>maxMicro*4)end)
check('humanized pedal release moves with attack',function()local n=G.copy(notes[8]);n.keyReleaseTime=n.startTime+.1;n.endTime=n.startTime+1;n.duration=1;local o=H.generate({n},settings,{seed=456})[1];assert(o.keyReleaseTime>o.startTime and o.keyReleaseTime<o.endTime and math.abs((o.keyReleaseTime-o.startTime)-.1)<.01)end)
check('nonstructural chords roll selectively; structural hits align',function()
 local chord={};for _,pitch in ipairs({60,64,67,72})do local n=G.copy(notes[2]);n.note=pitch;n.index=pitch;n.beat=.5;n.phraseId=1;chord[#chord+1]=n end
 local out,s=H.generate(chord,settings,{seed=99});assert(s.chordRolls==1);local a=out[1].layers.ChordInterpretation;local varied=false;for _,n in ipairs(out)do if n.layers.ChordInterpretation~=a then varied=true end end;assert(varied)
 for _,n in ipairs(chord)do n.beat=0 end;local _,s2=H.generate(chord,settings,{seed=99});assert(s2.chordRolls==0)
end)
check('global game song override precedence and isolation',function()local g={playback={speed=1,transpose=0},parts={enabledTracks={}}};local a=G.resolve(g,{playback={transpose=12}},{playback={speed=.75}});assert(a.playback.speed==.75 and a.playback.transpose==12 and g.playback.speed==1);local b=G.resolve(g,{playback={transpose=12}},{});assert(b.playback.speed==1)end)
check('State observers share speed and can unsubscribe',function()local s=R('State/PlayerState').new({speed=1});local a,b;local off=s:subscribe(function(v)a=v.speed end);s:subscribe(function(v)b=v.speed end);s:patch({speed=1.25});assert(a==b and b==1.25);off();s:patch({speed=1.5});assert(a==1.25 and b==1.5)end)
local Mapper=R('Piano/Mapper');local Adapter=R('Input/InputAdapter');local Manager=R('Player/NoteManager');local Scheduler=R('Player/Scheduler')
check('900 ms hold no longer cut to 260 ms',function()local a=Adapter.new();a:strike('a',{holdMs=900});advance(.3);assert(a.heldStrike.A);advance(.61);assert(not a.heldStrike.A)end)
check('new retrigger old delayed callback is harmless',function()local a=Adapter.new();a:strike('a',{holdMs=200});advance(.1);a:strike('a',{holdMs=900});advance(.15);assert(a.heldStrike.A);a:releaseExpressive();local count=#keyLog;advance(1);assert(#keyLog==count)end)
check('speed scales hold and preserves song clock',function()local a=Adapter.new();local s=Scheduler.new(Manager.new(a));s:setEvents({{time=0,action='strike',token='a',holdMs=900}},3);s:setSpeed(2);s:play();advance(.01);assert(a.heldStrike.A);advance(.46);assert(not a.heldStrike.A);local before=s:getPosition();s:setSpeed(.5);assert(math.abs(before-s:getPosition())<.0001);s:stop()end)
check('seek and pause resume reconstruct active hold',function()local a=Adapter.new();local s=Scheduler.new(Manager.new(a));s:setEvents({{time=0,action='strike',token='a',holdMs=900}},3);s:seek(.4,true);assert(a.heldStrike.A);s:pause();assert(not a.heldStrike.A);s:play();assert(a.heldStrike.A);s:stop();advance(1);assert(not a.heldStrike.A)end)
check('A B loop excludes notes beyond B',function()local a=Adapter.new();local s=Scheduler.new(Manager.new(a));s:setEvents({{time=.6,action='strike',token='z',holdMs=100}},2);s:setAB(0,.5);s:play();local start=#keyLog;advance(.7);for i=start+1,#keyLog do assert(not (keyLog[i][2] and keyLog[i][3]==90))end;s:stop()end)
check('tempo map changes, same tick final tempo wins',function()local t=R('MIDI/TempoMap').new({division={type='PPQN',ppqn=480},events={{type='meta',subtype='tempo',tick=0,microsecondsPerQuarter=1000000},{type='meta',subtype='tempo',tick=480,microsecondsPerQuarter=500000}}});assert(t:tickToSeconds(480)==1 and t:tickToSeconds(960)==1.5)end)
check('SMPTE ticks are time based',function()local t=R('MIDI/TempoMap').new({division={type='SMPTE',fps=25,ticksPerFrame=40},events={}});assert(t:tickToSeconds(1000)==1)end)
local a={notes=G.copy(notes),tracks={{index=1,name='Right'},{index=2,name='Left'}},division={type='PPQN',ppqn=480},duration=12,bpmMin=120,timeSignatures={}}
for _,n in ipairs(a.notes)do if n.index%2==0 then n.track=2;n.note-=12 end end
local config=G.copy(R('ConfigDefaults'));config.humanize.preset='Exact';config.playback.mode='Right'
local profile=R('Piano/Profiles').get('RobloxVirtualPiano61')
check('final timeline filters LH audio and visual together',function()local t=R('Performance/PerformanceTimeline').build(R,a,nil,config,profile,42);assert(#t.notes>0 and #t.notes<#a.notes);for _,n in ipairs(t.notes)do assert(n.parts.hand=='Right')end;for _,e in ipairs(t.events)do assert(e.note.parts.hand=='Right')end end)
check('disabled track disappears from final timeline',function()config.playback.mode='Both';config.parts.enabledTracks[2]=false;local t=R('Performance/PerformanceTimeline').build(R,a,nil,config,profile,42);for _,n in ipairs(t.notes)do assert(n.track~=2)end end)
check('physical key geometry: accidental overlaps two whites',function()local k=R('UI/KeyboardGeometry').build(60,72);assert(k[61].black and not k[60].black and k[61].width<k[60].width);assert(math.abs(k[61].center-k[62].x)<1e-9)end)
check('all window bounds and normalization',function()local L=R('UI/Layout');for _,v in ipairs({{1280,720},{1920,864},{2400,1080},{390,844},{844,390}})do for _,m in ipairs({'Full','Compact','Mini','Hidden'})do local w,h=L.bounds(v[1],v[2],m);local x,y=L.clamp(-100,10000,w,h,v[1],v[2]);assert(x>=0 and y>=0 and x+w<=v[1]and y+h<=v[2]);local n=L.normalized(x,y,w,h,v[1],v[2]);local rx,ry=L.position(v[1],v[2],w,h,n);assert(math.abs(rx-x)<.001 and math.abs(ry-y)<.001)end end end)
check('Cloud results empty errors cancel timeout',function()
 local P=R('Cloud/CloudProvider');local p=P.new({search=function(_,q)if q=='error'then error('network')end;return q=='empty'and {}or {{name='fixture'}}end},{timeoutSeconds=.1})
 p:search('ok',function(r)assert(#r==1)end);assert(p.state=='Results');p:search('empty',function(r)assert(#r==0)end);assert(p.state=='Empty');p:search('error',function(r,e)assert(not r and e)end);assert(p.state=='Error');p:cancel();assert(p.state=='Idle')
 local originalSpawn=task.spawn;local pending;task.spawn=function(f)pending=f end
 local called=0;p:search('late',function()called+=1 end);advance(.2);assert(called==1 and p.state=='Offline');pending();assert(called==1)
 p:search('cancel',function()called+=1 end);p:cancel();pending();advance(.2);assert(called==1)
 task.spawn=originalSpawn
end)
