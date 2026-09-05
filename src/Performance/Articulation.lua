local Articulation = {}

function Articulation.annotate(notes)
    local byVoice={}
    for _,n in ipairs(notes) do
        local key=string.format("%d:%d:%s",n.track or 0,n.channel or 0,n.parts and n.parts.hand or "?")
        byVoice[key]=byVoice[key] or {}; byVoice[key][#byVoice[key]+1]=n
    end
    for _,list in pairs(byVoice) do
        table.sort(list,function(a,b) return a.startTime<b.startTime end)
        for i,n in ipairs(list) do
            local nextN=list[i+1]
            local ioi=nextN and math.max(nextN.startTime-n.startTime,0.001) or n.duration
            local ratio=n.duration/math.max(ioi,0.001)
            if ratio>=1.02 then n.articulation="Legato"
            elseif ratio<=0.42 then n.articulation="Staccato"
            elseif (n.velocity or 64)>=108 then n.articulation="Accent"
            else n.articulation="Normal" end
        end
    end
    return notes
end

return Articulation
