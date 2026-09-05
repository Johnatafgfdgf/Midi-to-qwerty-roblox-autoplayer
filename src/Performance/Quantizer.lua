local Quantizer={}
local denominators={["1/4"]=4,["1/8"]=8,["1/16"]=16,["1/32"]=32}

function Quantizer.apply(notes,division,tempoMap,mode)
    local denom=denominators[mode]
    if not denom or division.type~="PPQN" then return notes end
    local step=division.ppqn*4/denom
    local out={}
    for _,n in ipairs(notes) do
        local c={}; for k,v in pairs(n) do c[k]=v end
        local st=math.floor(n.startTick/step+.5)*step
        local et=math.max(st+1,math.floor(n.endTick/step+.5)*step)
        c.startTime=tempoMap:tickToSeconds(st); c.endTime=tempoMap:tickToSeconds(et); c.duration=math.max(.001,c.endTime-c.startTime)
        out[#out+1]=c
    end
    table.sort(out,function(a,b) return a.startTime<b.startTime end)
    return out
end
return Quantizer
