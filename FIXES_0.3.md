# v0.3.0 fidelity/mobile repair

This release is a corrective pass after real-device feedback that v0.2 produced wrong notes and an awkward mobile UI.

## Critical music fixes

- Replaced the incorrect `VirtualPiano61` table. The old profile accidentally contained 69 mapped pitches and extended to MIDI 104.
- Added the corrected Roblox/Virtual Piano 61-key profile covering C2-C7, MIDI 36-96.
- White keys follow `1234567890qwertyuiopasdfghjklzxcvbnm` in ascending order; valid chromatic black keys use the shifted form of the appropriate white key.
- Changed the default output model to `Tap`. Every MIDI Note On now causes an independent piano strike.
- Sustain pedal and long NoteOff durations no longer suppress later repeated strikes of the same QWERTY key in the default mode.
- Shift is scoped to one strike, reducing accidental black/white-note corruption in dense passages.
- SmartOctave now strongly prefers keeping the original MIDI octave. It only chooses a global octave shift when coverage improves by at least 8 percentage points.
- Corrected dropped-note statistics.
- Existing v0.2 configs are migrated automatically to the corrected profile and Tap mode.
- Default humanization was reduced from Natural 22% to Very Subtle 8% while conversion accuracy is being validated.

## Mobile UI rebuild

- Removed the global `UIScale` approach that could make controls tiny on phones.
- Window size now follows the actual viewport with a mobile-safe minimum/maximum.
- Primary touch targets are generally 48-56 px tall.
- Navigation is a two-row 4-column grid instead of seven tiny tabs squeezed onto one line.
- Every main page scrolls vertically.
- Full / Mini / Hidden states remain available.
- Piano page now includes C4, C5 and C6 mapping-test buttons for quick in-game profile validation.
- Song rows and playback controls have larger hit areas.

## Validation

`tests/MappingSelfTest.lua` checks the 61-note range, important anchor mappings, SmartOctave stability and repeated-note Tap generation.

The target Roblox piano and Delta keyboard backend still need real-device validation because those APIs cannot be executed inside the repository tooling environment.
