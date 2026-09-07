# MIDI → QWERTY · Glass/dark

Mobile autoplayer overlay for game pianos. MIDI → classify/filter → phrase performance → piano mapping → final timeline → keyboard execution and piano roll.

**0.7.0-rc.1 is a development candidate, not a device-validated stable release.** `loader.lua` remains the existing v0.6.1 stable loader.

## Run development

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Johnatafgfdgf/Midi-to-qwerty-roblox-autoplayer/dev/glass-autoplayer/loader_dev.lua"))()
```

MIDIs: `Delta/Workspace/MIDI/` or `MIDI/`. Use only where automated keyboard input is permitted. No anti-cheat bypass or evasion features.

Open Library → choose MIDI → Player → Play. Use Compact during gameplay, Mini for pause/seek/speed, and Hidden for a draggable restore bubble. Drag windows by their header. Speed: −/+ in 0.05 steps, hold to repeat, tap value for presets. Seek previews while dragging and commits on release. LH/RH filters both execution and the roll.

Performance has Exact/Subtle/Natural/Pianist/Expressive/Custom, intensity, new interpretation and Advanced parameters. Settings offers game profiles and manual piano calibration. Profiles resolve Global → Game → Song. Explicitly save the current game/song settings to remember them. Development settings are isolated in `MIDIQWERTY/settings-v070.json`.

Dodo Cloud is currently unavailable. Local MIDIs work independently. See [validation](docs/VALIDATION.md) for findings and unvalidated functionality.

## Architecture

- `src/Main.lua`: lifecycle, song/configuration resolution, playback actions.
- `src/State/PlayerState.lua`: one observable playback state.
- `src/Performance/PerformanceTimeline.lua`: shared final notes/events and CSV export.
- `src/Performance/Humanizer.lua`, `PhraseEngine.lua`: phrase, hand, chord, motif and microtiming layers.
- `src/UI/App.lua`: distinct Full/Compact/Mini/Hidden layouts.
- `src/UI/Components.lua`, `InputRouter.lua`, `KeyboardGeometry.lua`, `PianoRoll.lua`: reusable controls and visualization.
- `src/Profiles/GameProfile.lua`: settings precedence.
- `src/Cloud/CloudProvider.lua`: provider lifecycle; Dodo stays Unsupported without verified service access.
- `dist/autoplayer.lua`: generated, self-contained bundle. No nested legacy-version module downloads.

## Build / tests

```sh
npm ci
npm test
python scripts/build.py
```

Optional in-game development harness, with a MIDI loaded:

```lua
getgenv().MIDIQWERTY.runUITest()
```

The harness changes playback settings and can send keyboard input. Engine/UI model tests are not substitutes for Roblox/device validation. See [UX decisions](UX_DECISIONS.md), [validation and known limitations](docs/VALIDATION.md) and [changelog](CHANGELOG.md).
