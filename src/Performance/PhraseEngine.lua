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
