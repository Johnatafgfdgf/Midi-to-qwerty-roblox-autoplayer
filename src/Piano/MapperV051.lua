local Mapper={}
local function clone(n)local c={};for k,v in pairs(n)do c[k]=v end;if n.parts then local p={};for k,v in pairs(n.parts)do p[k]=v end;c.parts=p end;return c end
local function adapt(note,profile,mode)
    if note>=profile.lowest and note<=profile.highest then return note,false end
    if mode=="Strict" then return nil,false end
    if mode=="Clamp" then return math.clamp(note,profile.lowest,profile.highest),true end
    local n=note;while n<profile.lowest do n+=12 end;while n>profile.highest do n-=12 end
    if n>=profile.lowest and n<=profile.highest then return n,true end
    return nil,false
end
local function coverage(notes,profile,base,shift)
    if #notes==0 then return 1 end;local hit=0
    for _,n in ipairs(notes)do local p=n.note+base+shift;if p>=profile.lowest and p<=profile.highest then hit+=1 end end
    return hit/#notes
end
local function smartShift(notes,profile,base)
    local bc=coverage(notes,profile,base,0);local best,bestc=0,bc
    for _,s in ipairs({-24,-12,12,24})do local c=coverage(notes,profile,base,s);if c>bestc+1e-9 then best,bestc=s,c end end
    if bestc-bc<.08 then return 0,bc end;return best,bestc
end
local function priority(n)
    local v=n.velocity or .7;if v>1 then v=v/127 end;local score=v*30
    if n.parts then if n.parts.melody then score+=120 end;if n.parts.bass then score+=90 end;if n.parts.hand=="Right" then score+=3 end end
    return score
end
function Mapper.mapNotes(notes,profile,settings)
    settings=settings or {};local mapped={};local stats={total=#notes,mapped=0,adapted=0,dropped=0,collisions=0,deduped=0}
    local transpose=math.clamp(settings.transpose or 0,-24,24);local range=settings.rangeMode or "SmartOctave";local smart=0
    if range=="SmartOctave" then smart,stats.smartCoverage=smartShift(notes,profile,transpose);range="OctaveFold" end
    stats.smartTranspose=smart
    for _,n in ipairs(notes)do
        local target,changed=adapt(n.note+transpose+smart,profile,range);local token=target and profile.map[target] or nil
        if token then local c=clone(n);c.mappedNote,c.token,c.originalNote=target,token,n.note;mapped[#mapped+1]=c;stats.mapped+=1;if changed or transpose+smart~=0 then stats.adapted+=1 end else stats.dropped+=1 end
    end
    table.sort(mapped,function(a,b)if a.startTime==b.startTime then if a.token==b.token then return priority(a)>priority(b) end;return tostring(a.token)<tostring(b.token) end;return a.startTime<b.startTime end)
    local deduped,lastByToken={},{};local window=(settings.collisionWindowMs or 2.5)/1000
    for _,n in ipairs(mapped)do
        local prev=lastByToken[n.token]
        if prev and math.abs((prev.startTime or 0)-(n.startTime or 0))<=window and prev.originalNote~=n.originalNote then
            stats.collisions+=1;stats.deduped+=1
            if priority(n)>priority(prev) then local idx=prev.__idx;n.__idx=idx;deduped[idx]=n;lastByToken[n.token]=n end
        else n.__idx=#deduped+1;deduped[#deduped+1]=n;lastByToken[n.token]=n end
    end
    for _,n in ipairs(deduped)do n.__idx=nil end
    stats.mapped=#deduped;stats.coverage=stats.total>0 and (#deduped/stats.total) or 1
    return deduped,stats
end
local function eventRank(e)if e.action=="up" then return 1 elseif e.action=="strike" or e.action=="tap" then return 2 else return 3 end end
local function normalizedVelocity(n)
    local v=n.expressiveVelocity or n.velocity or n.originalVelocity or .7
    if v>1 then v=v/127 end
    return math.clamp(v,0,1)
end
local function expressiveHold(n,expr)
    expr=expr or {};local v=normalizedVelocity(n)
    local lo=math.clamp(expr.minHoldMs or 24,8,180);local hi=math.clamp(expr.maxHoldMs or 92,lo,260)
    local velocityInfluence=math.clamp(expr.velocityInfluence or .8,0,1)
    local articulationInfluence=math.clamp(expr.articulationInfluence or .65,0,1)
    local durationInfluence=math.clamp(expr.durationInfluence or .25,0,1)
    local shaped=.5+(v-.5)*velocityInfluence
    local hold=lo+(hi-lo)*math.clamp(shaped,0,1)
    local art=1
    if n.articulation=="Staccato" then art=1-.50*articulationInfluence
    elseif n.articulation=="Legato" then art=1+.22*articulationInfluence
    elseif n.articulation=="Accent" then art=1+.10*articulationInfluence end
    local midiMs=math.clamp((n.duration or .08)*1000,12,240)
    hold=hold*art*(1-durationInfluence)+midiMs*durationInfluence
    return math.clamp(hold,8,260)
end
function Mapper.toEvents(mappedNotes,settings)
    settings=settings or {};local triggerMode=settings.triggerMode or "Tap";local expr=settings.expression or {};local events={}
    for _,n in ipairs(mappedNotes)do
        if triggerMode=="Hold" then
            events[#events+1]={time=n.startTime,action="down",token=n.token,note=n,velocity=normalizedVelocity(n)}
            events[#events+1]={time=n.endTime,action="up",token=n.token,note=n,velocity=normalizedVelocity(n)}
        else
            local action=(expr.enabled==false) and "tap" or "strike"
            events[#events+1]={time=n.startTime,action=action,token=n.token,note=n,velocity=normalizedVelocity(n),holdMs=expressiveHold(n,expr),nativeVelocity=expr.nativeVelocity~=false}
        end
    end
    table.sort(events,function(a,b)if a.time==b.time then local ar,br=eventRank(a),eventRank(b);if ar==br then return tostring(a.token)<tostring(b.token)end;return ar<br end;return a.time<b.time end)
    return events
end
return Mapper
