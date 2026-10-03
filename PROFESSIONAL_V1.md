# MIDI QWERTY v1.0 Professional

This branch promotes the 0.7 RC architecture into a production-oriented v1 runtime while keeping the project's MIDI-first behavior and mobile interface.

## Reliability and compatibility

- v1 runtime modules are versioned separately from the stable 0.6.1 line.
- The v1 loader pins its runtime to an immutable commit.
- Parser failures include byte/track context.
- Unknown chunks are skipped with warnings instead of immediately invalidating an otherwise usable file.
- Non-standard realtime/system-common statuses are handled defensively.
- PPQN and SMPTE divisions are validated.
- Tempo mapping supports both tick-to-seconds and seconds-to-tick conversion.
- Program Change state is captured at Note On time.
- Sustain is interpreted at channel scope while preserving the original finger-release time.
- Cache schema v3 prevents stale analysis from older engines being reused.
- Config JSON keeps a backup and can recover from a valid .bak file.
- MIDI discovery supports recursive scanning with depth/file limits and path deduplication.
- Configuration migration is non-destructive: recognized old settings survive while new v1 fields receive defaults.

## Playback engine

- Configurable per-frame event budget protects the Roblox client from pathological dense files.
- Events sharing one timestamp are kept together when possible so an event budget does not arbitrarily split a chord.
- A hard cap still prevents a single frame from processing an unbounded event burst.
- Drift diagnostics include average, peak, EMA, late, skipped, failed, catch-up and over-budget counters.
- Input exceptions are isolated from the playback loop.
- Skipped events are no longer reported to the UI as successful notes.
- Hold-mode seek and A/B loop playback restore notes that should already be held.
- End-of-song waits for due-event backlog to drain.
- Quantization rebuilds the current performance in memory instead of reloading the song and incrementing play history.

## Input correctness

- Shift is pulsed only around the key-down event for shifted piano tokens.
- Long black-key notes no longer keep Shift globally held and alter overlapping white-key presses.
- Hold mode retriggers a physical key when a repeated note overlaps an older one.
- Older NoteOff events cannot prematurely release the newest retrigger.
- Expressive strikes support holds up to 15 seconds.
- Input diagnostics expose backend, sends, failures and the last error.

## Piano mapping

- Smart-octave selection searches a wider octave range and uses musical-importance weighting.
- Collision handling is based on the physical key, not only the text token.
- Impossible pairs such as q/Q or 1/! at the same instant are resolved deterministically.
- Melody, bass and velocity remain priority signals when a collision must be simplified.
- Repeated notes use physical-key identity when limiting a hold before the next strike.

## Humanization

- Same-hand neighboring notes constrain timing instead of unrelated notes from the opposite hand suppressing natural timing.
- Chord grouping uses original attack positions so humanization does not redefine which notes belonged to a chord.
- Timing statistics are recalculated after chord roll so diagnostics reflect the final performance.

## Validation

Run `tests/ProfessionalSelfTest.lua` through the project Require loader. It covers:

- parser validity;
- tempo conversion round-trip;
- Program Change capture;
- sustain extension and finger release;
- physical-key collision handling;
- exact-mode stability;
- deterministic fixed-seed humanization.

Real-device validation is still required for each executor because key-injection APIs differ. The project intentionally does not implement anti-cheat bypass, anti-detection or automation-evasion behavior.
