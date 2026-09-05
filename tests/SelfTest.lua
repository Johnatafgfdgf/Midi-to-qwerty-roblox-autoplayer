-- Run from an environment that can load the repository modules, or adapt Require below.
return function(Require)
    local Parser=Require("MIDI/Parser")
    local TempoMap=Require("MIDI/TempoMap")
    local Analyzer=Require("MIDI/Analyzer")
    local passed,failed=0,0
    local function check(name,condition)
        if condition then passed+=1; print("PASS",name) else failed+=1; warn("FAIL",name) end
    end
    local function u16(n) return string.char(math.floor(n/256)%256,n%256) end
    local function u32(n) return string.char(math.floor(n/16777216)%256,math.floor(n/65536)%256,math.floor(n/256)%256,n%256) end

    local r=Parser.Reader.new(string.char(0x00,0x7F,0x81,0x00))
    check("VLQ zero",r:vlq()==0)
    check("VLQ 127",r:vlq()==127)
    check("VLQ 128",r:vlq()==128)

    local track=table.concat({
        string.char(0x00,0xFF,0x51,0x03,0x07,0xA1,0x20),
        string.char(0x00,0x90,60,100),
        string.char(0x83,0x60,0x80,60,0),
        string.char(0x00,0xFF,0x2F,0x00),
    })
    local midiData="MThd"..u32(6)..u16(0)..u16(1)..u16(480).."MTrk"..u32(#track)..track
    local midi=Parser.parse(midiData)
    check("SMF format",midi.format==0)
    check("Track count",#midi.tracks==1)
    local tempo=TempoMap.new(midi)
    check("480 ticks = 0.5 sec",math.abs(tempo:tickToSeconds(480)-0.5)<0.00001)
    local analysis=Analyzer.analyze(midi,tempo)
    check("One note",analysis.noteCount==1)
    check("Note duration",math.abs(analysis.notes[1].duration-0.5)<0.00001)
    print(string.format("SelfTest complete: %d passed, %d failed",passed,failed))
    return failed==0
end
