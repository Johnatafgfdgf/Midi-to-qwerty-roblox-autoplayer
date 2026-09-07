local T={}
function T.build(R,analysis,tempo,config,profile,seed)
 R('Parts/Separator').classify(analysis,config.parts)
 R('Parts/VoiceSeparator').assign(analysis.notes,.03)
 R('Performance/Articulation').annotate(analysis.notes)
 R('Performance/PhraseEngine').annotate(analysis.notes,analysis.bpmMin or 120,tempo,analysis.timeSignatures,analysis.division)
 local filtered=R('Parts/Separator').filter(analysis.notes,config.playback.mode,config.parts)
 if config.playback.quantization~='Off' then filtered=R('Performance/Quantizer').apply(filtered,analysis.division,tempo,config.playback.quantization)end
 local simplified,ss=R('Performance/Simplifier').apply(filtered,config.playback)
 local notes,stats=R('Performance/Humanizer').generate(simplified,config.humanize,{seed=seed,bpm=analysis.bpmMin or 120,chordWindowMs=config.playback.chordWindowMs})
 local mapped,mapStats=R('Piano/Mapper').mapNotes(notes,profile,config.playback)
 local events=R('Piano/Mapper').toEvents(mapped,config.playback)
 local duration=analysis.duration or 0
 for _,e in ipairs(events)do
  if e.note then
   e.note.executionStart=e.time
   if e.action=='strike' or e.action=='tap' then e.note.executionEnd=e.time+(e.holdMs or 18)/1000 end
  end
  duration=math.max(duration,e.time+(e.holdMs or 0)/1000)
 end
 for _,n in ipairs(mapped)do n.executionStart=n.startTime;n.executionEnd=n.executionEnd or n.keyReleaseTime or n.endTime end
 return {notes=mapped,events=events,duration=duration,seed=seed,stats=stats,mapping=mapStats,simplification=ss,originalCount=#analysis.notes,filteredCount=#filtered}
end
function T.csv(timeline)
 local lines={'originalStart,performanceStart,deltaMs,originalIOI,performanceIOI,hand,phrase,chord,velocity,holdMs'}
 local prevOriginal,prevFinal
 for _,n in ipairs(timeline.notes)do
  local o=n.originalStartTime or n.startTime
  lines[#lines+1]=string.format('%.6f,%.6f,%.3f,%.6f,%.6f,%s,%s,%s,%.4f,%.3f',o,n.startTime,(n.startTime-o)*1000,prevOriginal and o-prevOriginal or 0,prevFinal and n.startTime-prevFinal or 0,n.parts and n.parts.hand or 'Right',tostring(n.phraseId or 0),tostring(n.chordId or 0),n.expressiveVelocity or n.velocity or 0,((n.executionEnd or n.endTime)-n.startTime)*1000)
  prevOriginal,prevFinal=o,n.startTime
 end
 return table.concat(lines,'\n')
end
return T
