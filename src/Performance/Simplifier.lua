local Simplifier={}

local function importance(n)
    local score=(n.velocity or 64)*0.2
    if n.parts then
        if n.parts.melody then score+=120 end
        if n.parts.bass then score+=100 end
        if n.parts.hand=="Right" then score+=4 end
    end
    score+=n.note*0.03
    return score
end

function Simplifier.apply(notes,settings)
    settings=settings or {}
    local maxKeys=math.clamp(settings.maxSimultaneousKeys or 10,1,16)
    local window=(settings.chordWindowMs or 10)/1000
    local grouped,out,group,anchor={},{},{},nil
    local function flush()
        if #group<=maxKeys then for _,n in ipairs(group) do out[#out+1]=n end
        else
            table.sort(group,function(a,b) return importance(a)>importance(b) end)
            for i=1,maxKeys do out[#out+1]=group[i] end
        end
        group={}
    end
    for _,n in ipairs(notes) do
        if not anchor or n.startTime-anchor<=window then anchor=anchor or n.startTime; group[#group+1]=n
        else flush(); anchor=n.startTime; group[#group+1]=n end
    end
    flush()
    table.sort(out,function(a,b) return a.startTime==b.startTime and a.note<b.note or a.startTime<b.startTime end)

    local maxNps=settings.maxNotesPerSecond or 0
    if maxNps>0 then
        local buckets,kept={},{}
        for _,n in ipairs(out) do
            local b=math.floor(n.startTime)
            buckets[b]=buckets[b] or {}; buckets[b][#buckets[b]+1]=n
        end
        for _,list in pairs(buckets) do
            if #list>maxNps then table.sort(list,function(a,b) return importance(a)>importance(b) end) end
            for i=1,math.min(#list,maxNps) do kept[#kept+1]=list[i] end
        end
        out=kept; table.sort(out,function(a,b) return a.startTime<b.startTime end)
    end
    return out,{before=#notes,after=#out,removed=#notes-#out}
end

return Simplifier
