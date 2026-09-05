local VoiceSeparator={}

function VoiceSeparator.assign(notes,window)
    window=window or .03
    local voices={}
    local groups,group,anchor={},nil,nil
    local function flush()
        if not group or #group==0 then return end
        table.sort(group,function(a,b) return a.note<b.note end)
        local used={}
        for _,n in ipairs(group) do
            local best,bestDist=nil,math.huge
            for id,v in ipairs(voices) do
                if not used[id] then
                    local gap=n.startTime-(v.time or -999)
                    local dist=math.abs(n.note-(v.pitch or n.note))+(gap>1.5 and 8 or 0)
                    if dist<bestDist then best,bestDist=id,dist end
                end
            end
            if not best or bestDist>18 then voices[#voices+1]={}; best=#voices end
            used[best]=true; voices[best].pitch=n.note; voices[best].time=n.startTime
            n.parts=n.parts or {}; n.parts.voice=best
        end
    end
    for _,n in ipairs(notes) do
        if not anchor or n.startTime-anchor<=window then anchor=anchor or n.startTime; group=group or {}; group[#group+1]=n
        else flush(); group={n}; anchor=n.startTime end
    end
    flush()
    return notes,#voices
end

return VoiceSeparator
