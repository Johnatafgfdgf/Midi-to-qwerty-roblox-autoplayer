# MIDI to QWERTY Roblox Autoplayer

Mobile-first Luau MIDI player for configurable QWERTY pianos. The project reads Standard MIDI Files from executor-accessible storage, builds an absolute tempo-aware timeline, separates playable musical parts, optionally applies subtle musical humanization, maps notes to a configurable QWERTY profile, and schedules input without tying song speed to frame rate.

> Use only in experiences where automated keyboard input is permitted. This project does not include anti-cheat bypass or automation-evasion logic.

## Default MIDI folders

The scanner checks these folders when the executor exposes filesystem APIs:

- `Delta/Workspace/MIDI/`
- `Delta/Workspace/Midis/`
- `Delta/Workspace/Songs/`
- `Delta/Workspace/Music/`
- `Delta/Workspace/`
- `MIDI/`
- `Workspace/MIDI/`

## Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Johnatafgfdgf/Midi-to-qwerty-roblox-autoplayer/main/loader.lua"))()
```

## Planned architecture

- `loader.lua` - tiny stable entry point
- `bootstrap.lua` - cached remote module loader
- `src/MIDI` - SMF parser, tempo map and analysis
- `src/Parts` - left/right hand, melody, bass and playable-part classification
- `src/Performance` - subtle deterministic humanization and safety limits
- `src/Piano` - QWERTY profile mapping and range adaptation
- `src/Player` - scheduler, active-note manager, playback state
- `src/Input` - capability-detected keyboard backend
- `src/Storage` - filesystem/config persistence
- `src/UI` - touch-first UI with Full / Mini / Hidden states
- `tests` - parser/timing/mapping self tests

## Core goals

- SMF format 0/1 parsing with running status, VLQ, tempo, time signature, note, control/program/pitch events
- tempo-map conversion to absolute seconds with tempo changes
- accurate monotonic scheduler with pause/resume/seek and late-event handling
- selectable Both / Left Hand / Right Hand / Melody / Accompaniment / Bass / custom track/channel parts
- configurable fixed or automatic hand split, track-name hints and continuity scoring
- subtle per-performance variation with deterministic seeds, phrase/hand/chord layers and musical safety limits
- mobile UI that can collapse to a mini-player or a draggable floating button
- persistent settings and per-song overrides when filesystem support exists
- diagnostic counters for drift, late/skipped events and active notes

This repository is being implemented incrementally; files should contain working behavior rather than placeholder buttons or fake parsers.