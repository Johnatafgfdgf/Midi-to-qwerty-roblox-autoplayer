return {
    version=2,
    midiFolders={"Delta/Workspace/MIDI","Delta/Workspace/Midis","Delta/Workspace/Songs","Delta/Workspace/Music","Delta/Workspace","Workspace/MIDI","MIDI"},
    playback={
        speed=1.0,mode="Both",transpose=0,rangeMode="SmartOctave",lateMode="Adaptive",maxLateMs=85,
        chordWindowMs=10,loopSong=false,quantization="Off",maxSimultaneousKeys=10,maxNotesPerSecond=0,
        loopA=nil,loopB=nil,
    },
    parts={splitMode="Auto",splitNote=60,percussion=false,enabledTracks={},enabledChannels={}},
    humanize={
        preset="Natural",enabled=true,strength=.22,timingMs=9,chordSpreadMs=8,durationVariation=.018,
        handIndependence=.35,phraseExpression=.35,rubato=.12,seedMode="Auto",fixedSeed=12345,
    },
    ui={state="Full",floatingX=.88,floatingY=.55,performanceMode=false,songFilter="All"},
    pianoProfile="VirtualPiano61",
}
