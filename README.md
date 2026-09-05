# MIDI to QWERTY Roblox Autoplayer

Mobile-first Luau MIDI player that turns local `.mid` files into configurable QWERTY piano performances inside Roblox-compatible environments.

The design goal is **MIDI fidelity first**: the notes and structure come from the MIDI, while optional humanization adds only small, musically correlated timing/duration/chord-spread differences between performances.

> Use only where automated keyboard input is permitted. The project intentionally does not implement anti-cheat bypass, anti-detection, or automation-evasion features.

## Run

Put MIDI files in:

```text
Delta/Workspace/MIDI/
```

Then execute:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Johnatafgfdgf/Midi-to-qwerty-roblox-autoplayer/main/loader.lua"))()
```

The scanner also checks `Delta/Workspace/Midis`, `Delta/Workspace/Songs`, `Delta/Workspace/Music`, `Delta/Workspace`, `Workspace/MIDI`, and `MIDI`.

## Version 0.2.0

### MIDI engine

- SMF formats 0/1/2 container parsing
- binary big-endian reader + VLQ
- running status
- Note On / Note Off including NoteOn velocity 0
- Program Change, Control Change, poly pressure, channel pressure, pitch bend
- SysEx skipping without corrupting the parser cursor
- common meta events: tempo, track name, instrument name, time signature, text, end-of-track
- PPQN tempo maps with tempo changes
- SMPTE time division
- absolute timestamp conversion
- note pairing and duration calculation
- CC64 sustain interpretation and sustained effective note durations
- track/channel metadata, note range, duration, BPM range, tempo-change count and peak polyphony
- cacheable analysis representation

### Playable musical parts

- Both hands
- Left hand only
- Right hand only
- Melody only
- Accompaniment only
- Bass only
- track enable/disable
- channel enable/disable
- percussion disabled by default through channel 10 classification
- explicit LH/RH track-name hints
- automatic pitch-cluster hand split
- continuity-aware hand assignment to reduce bad flips during crossings
- confidence score
- melody and bass voice heuristics
- greedy continuity-based voice IDs
- articulation annotation
- phrase IDs

### Human performance model

- Exact / Very Subtle / Natural / Expressive presets
- Exact mode with zero artificial timing variation
- automatic per-performance seed
- fixed-seed infrastructure
- correlated global, phrase, hand and note timing components
- BPM-adaptive timing limits
- density-adaptive timing limits
- velocity-aware stability
- articulation-aware duration variation
- bounded chord spread
- separate left/right timing tendencies
- deterministic output for a fixed seed
- no added or substituted composition notes

### Piano/QWERTY

- built-in Virtual Piano-style QWERTY profile
- editable MIDI-note → one-character token profile UI
- persistent custom profile overrides
- transpose -24..+24
- Strict range
- Clamp range
- Octave Fold
- Smart Octave global shift selection
- physical-key reference counting to avoid premature releases when mapped notes collide

### Playback

- absolute monotonic song clock based on `os.clock()`
- Play / Pause / Stop
- previous / next song
- ±5 second seek
- speed 0.5x..2x presets
- resume/seek reconstruction of notes that should still be held
- release-all panic control
- late-event diagnostics
- Adaptive / CatchUp / SkipLate scheduler policy support in config
- A↔B looping
- full-song loop support in scheduler/config
- optional quantization
- max simultaneous key simplifier that protects melody/bass/high-velocity notes first
- optional notes-per-second limiter in config

### Mobile UI

- touch-first layout
- responsive UIScale
- Songs / Player / Parts / Piano / Human / Settings / Diagnostics pages
- search
- All / Favorites / Recent song filters
- favorite stars
- Full UI
- Mini player
- Hidden UI
- draggable floating restore button
- live progress
- active QWERTY keys
- track/channel toggles
- humanization controls
- transpose/range/quantization/max-keys controls
- A↔B controls
- QWERTY profile editor
- diagnostics panel

### Storage and export

- persistent config JSON when filesystem APIs are available
- analysis cache keyed by a checksum + file size
- favorites
- recent songs
- basic play history
- per-song overrides for selected playback/part settings
- QWERTY timeline text export
- MIDI analysis text export

## Repository layout

```text
loader.lua
bootstrap.lua
src/
  Main.lua
  ConfigDefaults.lua
  MIDI/
    Parser.lua
    TempoMap.lua
    Analyzer.lua
  Parts/
    Separator.lua
    VoiceSeparator.lua
  Performance/
    Articulation.lua
    PhraseEngine.lua
    Quantizer.lua
    Simplifier.lua
    Humanizer.lua
  Piano/
    Profiles.lua
    ProfileStore.lua
    Mapper.lua
  Input/
    InputAdapter.lua
  Player/
    NoteManager.lua
    Scheduler.lua
  Storage/
    FileSystem.lua
    Cache.lua
    Library.lua
  Export/
    Exporter.lua
  UI/
    App.lua
tests/
  SelfTest.lua
VERSION
FEATURE_MATRIX.md
```

## Input compatibility

The input adapter detects executor-style `keypress`/`keyrelease` variants and falls back to `VirtualInputManager` if available. When no supported backend exists, the application reports the backend as unavailable instead of deliberately crashing the rest of the UI.

## Important validation status

The repository has been assembled and cross-checked at source level, but this conversation environment cannot execute Delta or a Roblox client. Therefore **0.2.0 should be treated as an implementation build, not a claim that every executor/piano combination has already passed device testing**.

The highest-priority real-device checks are:

1. exact filesystem path returned by Delta `listfiles()`;
2. whether Delta's key event function names/virtual-key expectations match the current adapter;
3. the exact QWERTY layout used by the target Roblox piano;
4. large MIDI timing under device load;
5. shifted QWERTY tokens in dense mixed chords;
6. seek + sustain behavior in the target piano.

See `FEATURE_MATRIX.md` for parity status against the full design brief.
