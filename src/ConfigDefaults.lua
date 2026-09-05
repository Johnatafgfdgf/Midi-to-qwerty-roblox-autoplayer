return {
    version = 1,
    midiFolders = {
        "Delta/Workspace/MIDI", "Delta/Workspace/Midis", "Delta/Workspace/Songs",
        "Delta/Workspace/Music", "Delta/Workspace", "Workspace/MIDI", "MIDI"
    },
    playback = {
        speed = 1.0,
        mode = "Both",
        transpose = 0,
        rangeMode = "OctaveFold",
        lateMode = "Adaptive",
        maxLateMs = 85,
        chordWindowMs = 10,
        loopSong = false,
    },
    parts = {
        splitMode = "Auto",
        splitNote = 60,
        percussion = false,
        enabledTracks = {},
        enabledChannels = {},
    },
    humanize = {
        preset = "Natural",
        enabled = true,
        strength = 0.22,
        timingMs = 9,
        chordSpreadMs = 8,
        durationVariation = 0.018,
        handIndependence = 0.35,
        phraseExpression = 0.35,
        rubato = 0.12,
        seedMode = "Auto",
        fixedSeed = 12345,
    },
    ui = {
        state = "Full",
        floatingX = 0.88,
        floatingY = 0.55,
        performanceMode = false,
    },
    pianoProfile = "VirtualPiano61",
}
