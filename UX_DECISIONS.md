# UX decisions — Glass/dark RC

Chosen direction: Glass/dark, from the visual research approved in this conversation. No new visual research was substituted.

| Problem | Solution | Location | Why it does not crowd gameplay |
|---|---|---|---|
| Player hides the piano | Separate Full / Compact / Mini / Hidden compositions | Window modes | Only Compact has a small roll; Mini has transport only |
| Speed cycling takes many taps | Shared − / value / +, 0.05 steps, preset sheet, hold-to-repeat | All playback modes | Three reusable controls |
| Seeking accidentally drags the window | Single gesture owner, 8 px threshold, header-only drag | InputRouter | No extra controls |
| Seeking repeatedly rebuilds input | Preview position while dragging; commit on release | SeekBar | Replaces permanent ±5 s controls |
| Wrong notes remain visible after filtering | One final PerformanceTimeline for events and visualization | Engine | No extra controls |
| Notes align to an incorrect keyboard | White-key space geometry, narrow overlapping accidentals | PianoRoll | Only two note colors, matching hands |
| Game-specific settings get lost | Global → Game → Song resolution with isolated development config | Settings | Explicit save buttons outside gameplay |
| Need several songs in sequence | Play next / append queue / remove entry | Song context menu / Player tools | Queue hidden when unused |
| Users cannot configure piano mappings confidently | Manual C4/C5/C6 tests plus validated range | Calibration | No unverified automatic detection |
| Too much technical status | Transient toasts, diagnostics sheet | Settings | No permanent metrics in Player |
| Old song overrides bleed into new songs | Re-resolve defaults and game profile before every song | Main | Invisible state fix |
| Stable must remain recoverable | Immutable legacy stable plus independent dev/RC bundle | Loaders | No UI cost |

Presets apply complete parameter sets. Intensity blends the preset, not a second preset selection. Exact and intensity zero preserve the input timeline before explicit mapping/simplification. Velocity contours remain data unless a compatible game/backend supports them.

Deferred optional features: persistent playlists, pinned songs, favorite seeds, automatic latency calibration, adaptive device polyphony, custom speed preset editor, automatic piano detection. Queue, favorites, recents, folder scan, auto octave, melody priority, panic and input reinitialization address the immediate gameplay workflow.

Glass is simulated with dark tonal surfaces, restrained transparency, gradient and edge treatment. No world-wide blur is installed. Typography and GPU costs require Roblox/device validation.
