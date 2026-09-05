# MIDI to QWERTY Roblox Autoplayer

A mobile-first Luau MIDI player for configurable QWERTY pianos. It reads Standard MIDI Files from executor-accessible storage, builds a tempo-aware absolute timeline, separates playable musical parts, applies optional subtle musical humanization, maps notes to a QWERTY profile, and schedules keyboard input independently of frame-rate speed.

> Use only in experiences where automated keyboard input is permitted. The project intentionally does **not** contain anti-cheat bypass, anti-detection, moderation evasion, or automation-concealment logic.

## Quick start

Put MIDI files in an executor-accessible folder, preferably:

```text
Delta/Workspace/MIDI/
```

Then run:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Johnatafgfdgf/Midi-to-qwerty-roblox-autoplayer/main/loader.lua"))()
```

The scanner also checks `Delta/Workspace/Midis`, `Delta/Workspace/Songs`, `Delta/Workspace/Music`, `Delta/Workspace`, `Workspace/MIDI`, and `MIDI`.

## Current 0.1.0 implementation

The repository now contains working implementations for:

- SMF format 0/1/2 container parsing
- binary VLQ parsing and running status
- Note On/Off, Program Change, Control Change, pitch bend and common meta events
- PPQN tempo-map conversion with tempo changes and SMPTE time division support
- note pairing, duration calculation, track metadata, pedal-event collection and polyphony analysis
- automatic left/right hand classification with explicit track-name hints, pitch clustering and continuity scoring
- derived Melody, Bass and Accompaniment parts
- selectable Both / Left / Right / Melody / Accompaniment / Bass playback
- per-track include/exclude controls
- subtle deterministic humanization using correlated timing curves, separate hand tendencies, duration variation and bounded chord spreading
- per-Play performance seeds, plus exact-MIDI mode (`Humanization = 0`)
- Virtual Piano-style QWERTY mapping, transpose and Strict / Clamp / OctaveFold range modes
- executor key-event or `VirtualInputManager` input backends with capability diagnostics
- physical-key reference counting and emergency Release Keys
- monotonic scheduler using an absolute song clock, pause/resume, seek, speed control, looping hooks and late-event diagnostics
- mobile UI with Songs, Player, Parts, Humanize, Settings and Diagnostics pages
- Full / Mini / Hidden UI states and a draggable floating restore button
- persistent JSON configuration when filesystem writes are available
- parser/timing self tests in `tests/SelfTest.lua`

## Architecture

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
  Performance/
    Humanizer.lua
  Piano/
    Profiles.lua
    Mapper.lua
  Input/
    InputAdapter.lua
  Player/
    NoteManager.lua
    Scheduler.lua
  Storage/
    FileSystem.lua
  UI/
    App.lua
tests/
  SelfTest.lua
VERSION
```

`bootstrap.lua` implements a small cached remote module loader, so `loader.lua` remains tiny while the real code stays modular.

## Musical interpretation model

The original MIDI remains the composition ground truth. Humanization only nudges performance-level details such as microtiming, note duration and very small chord spreads. The `Natural` preset defaults to a low 22% strength. `Exact` sets humanization to zero. Correlated curves are used instead of independent random delay on every note, and faster/denser passages automatically receive smaller timing variation.

Each automatic performance gets a new seed when playback starts from the beginning. A fixed seed path is present in configuration for reproducible performances.

## Playable parts

A MIDI track is not assumed to equal one hand. The classifier first uses explicit names such as `LH`, `Left Hand`, `RH`, `Right Hand`, `Bass`, `Treble`, and `Melody` where available. Otherwise it estimates a split from pitch clusters and uses pitch/time continuity to avoid changing hands on every crossing note. Notes can simultaneously belong to categories such as `Right + Melody` or `Left + Bass`.

## Input compatibility

Keyboard injection depends on APIs exposed by the environment. The adapter currently detects executor-style `keypress`/`keyrelease` variants and falls back to `VirtualInputManager` when available. If no supported backend exists, the UI still loads and reports the missing capability instead of intentionally crashing the whole application.

## Important limitations / next engineering passes

This is a real functional foundation, but several advanced items from the full design still need deeper implementation and testing on actual Delta + target piano experiences. In particular: sustain reconstruction during arbitrary seek, richer voice separation, per-song override files, custom Piano Profile editor/import/export, playlist/favorites/history, true A-B looping UI, advanced articulation/phrase inference, piano-roll visualization, MIDI analysis export, cache files, channel/instrument toggles in the UI, and broader executor-specific key backend validation.

The code is deliberately structured so those features can be added without replacing the parser/player core.

## Safety and fair use

This project is for permitted automation and music playback. It does not attempt to hide that input is automated or circumvent experience protections.
