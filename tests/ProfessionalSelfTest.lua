return function(Require)
    local Parser=Require("MIDI/Parser")
    local TempoMap=Require("MIDI/TempoMap")
    local Analyzer=Require("MIDI/Analyzer")
    local Mapper=Require("Piano/Mapper")
    local Profiles=Require("Piano/Profiles")
    local Humanizer=Require("Performance/Humanizer")

    local passed,failed=0,0
    local function check(name,condition)
        if condition then
            passed+=1
            print("PASS",name)
        else
            failed+=1
            warn("FAIL",name)
        end
    end

    local function u16(n)
        return string.char(math.floor(n/256)%256,n%256)
    end

    local function u32(n)
        return string.char(
            math.floor(n/16777216)%256,
            math.floor(n/65536)%256,
            math.floor(n/256)%256,
            n%256
        )
    end

    local function vlq(n)
        local bytes={bit32.band(n,0x7F)}
        n=bit32.rshift(n,7)
        while n>0 do
            table.insert(bytes,1,bit32.bor(bit32.band(n,0x7F),0x80))
            n=bit32.rshift(n,7)
        end
        return string.char(table.unpack(bytes))
    end

    local track=table.concat({
        vlq(0),string.char(0xC0,40),
        vlq(0),string.char(0xFF,0x51,3,0x07,0xA1,0x20),
        vlq(0),string.char(0x90,60,100),
        vlq(240),string.char(0xB0,64,127),
        vlq(240),string.char(0x80,60,0),
        vlq(240),string.char(0xB0,64,0),
        vlq(0),string.char(0xFF,0x51,3,0x06,0x1A,0x80),
        vlq(240),string.char(0xFF,0x2F,0),
    })

    local data="MThd"..u32(6)..u16(0)..u16(1)..u16(480).."MTrk"..u32(#track)..track
    local midi=Parser.parse(data)

    check("parser format 0",midi.format==0 and #midi.tracks==1)
    check("parser warnings clean",#(midi.warnings or {})==0)

    local tempo=TempoMap.new(midi)
    check("tempo tick 480",math.abs(tempo:tickToSeconds(480)-.5)<1e-6)
    local sec=tempo:tickToSeconds(960)
    check("tempo inverse",math.abs(tempo:secondsToTick(sec)-960)<1e-5)

    local analysis=Analyzer.analyze(midi,tempo)
    check("analyzer one note",analysis.noteCount==1)
    check("program captured at note-on",analysis.notes[1].program==40)
    check("sustain extends note",analysis.notes[1].sustained==true and math.abs(analysis.notes[1].endTime-.75)<1e-6)
    check("finger release preserved",math.abs((analysis.notes[1].keyReleaseTime or 0)-.5)<1e-6)

    local profile=Profiles.get("RobloxVirtualPiano61")
    local collisionNotes={
        {note=60,startTime=0,endTime=.3,duration=.3,velocity=100,parts={melody=true}},
        {note=61,startTime=0,endTime=.3,duration=.3,velocity=80,parts={}},
    }
    local mapped,stats=Mapper.mapNotes(collisionNotes,profile,{
        transpose=0,
        rangeMode="SmartOctave",
        collisionWindowMs=3,
    })
    check("physical-key collision deduped",#mapped==1 and (stats.physicalCollisions or 0)==1)

    local exactPreset=Humanizer.getPreset("Exact")
    local exact,exactStats=Humanizer.generate(analysis.notes,exactPreset,{seed=42,bpm=120,chordWindowMs=10})
    check("exact humanizer remains exact",#exact==1 and math.abs(exact[1].startTime-analysis.notes[1].startTime)<1e-9 and exactStats.maxTimingMs==0)

    local pianist=Humanizer.getPreset("Pianist")
    local p1=Humanizer.generate(analysis.notes,pianist,{seed=777,bpm=120,chordWindowMs=10})
    local p2=Humanizer.generate(analysis.notes,pianist,{seed=777,bpm=120,chordWindowMs=10})
    check("humanizer fixed seed deterministic",math.abs(p1[1].startTime-p2[1].startTime)<1e-9)

    print(string.format("ProfessionalSelfTest: %d passed, %d failed",passed,failed))
    return failed==0,passed,failed
end
