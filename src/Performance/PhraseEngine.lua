local PhraseEngine={}
function PhraseEngine.annotate(notes,bpm)
    bpm=bpm or 120;local breakGap=math.clamp(60/bpm*1.4,.32,.9);local byHand={Left={},Right={},Other={}}
    for _,n in ipairs(notes) do local h=n.parts and n.parts.hand or "Other";byHand[h]=byHand[h] or {};byHand[h][#byHand[h]+1]=n end
    local nextId=0
    for _,list in pairs(byHand) do table.sort(list,function(a,b)return a.startTime<b.startTime end);local lastEnd=-999;local pid
        for _,n in ipairs(list) do if n.startTime-lastEnd>breakGap then nextId+=1;pid=nextId end;n.phraseId=pid;lastEnd=math.max(lastEnd,n.endTime) end
    end
    return notes,nextId
end
return PhraseEngine
