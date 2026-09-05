return function(Require)
    local Profiles=Require("Piano/Profiles")
    local Mapper=Require("Piano/Mapper")
    local passed,failed=0,0
    local function check(name,condition)
        if condition then passed+=1;print("PASS",name)else failed+=1;warn("FAIL",name)end
    end

    local p=Profiles.get("RobloxVirtualPiano61")
    check("profile lowest C2",p.lowest==36)
    check("profile highest C7",p.highest==96)
    local count=0;for n=p.lowest,p.highest do if p.map[n] then count+=1 end end
    check("exactly 61 chromatic mappings",count==61)
    check("C2 -> 1",p.map[36]=="1")
    check("C#2 -> !",p.map[37]=="!")
    check("D2 -> 2",p.map[38]=="2")
    check("D#2 -> @",p.map[39]=="@")
    check("E2 -> 3",p.map[40]=="3")
    check("F2 -> 4",p.map[41]=="4")
    check("F#2 -> $",p.map[42]=="$")
    check("C4 -> t",p.map[60]=="t")
    check("C5 -> s",p.map[72]=="s")
    check("C6 -> l",p.map[84]=="l")
    check("C7 -> m",p.map[96]=="m")

    local notes={
        {note=60,startTime=0,endTime=2,duration=2},
        {note=60,startTime=.25,endTime=.5,duration=.25},
    }
    local mapped,stats=Mapper.mapNotes(notes,p,{transpose=0,rangeMode="SmartOctave"})
    local events=Mapper.toEvents(mapped,{triggerMode="Tap"})
    check("repeated MIDI notes remain two strikes",#events==2 and events[1].action=="tap" and events[2].action=="tap")
    check("in-range MIDI does not auto-shift octave",stats.smartTranspose==0)

    print(string.format("MappingSelfTest: %d passed, %d failed",passed,failed))
    return failed==0,passed,failed
end
