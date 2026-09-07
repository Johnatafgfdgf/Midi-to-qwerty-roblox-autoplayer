# Validation and limitations — 0.7.0-rc.1

## Executed here

Luau code executes through luau-web 1.4.0. Roblox services, input functions and time are mocked. This is not a Roblox emulator.

- Original v0.6 hold regression: six checks for pedal finger release, same-key release gap, retrigger callback generation, panic, pause/seek, and capture of the old 260 ms cap.
- Engine: deterministic/automatic seeds, Exact, zero intensity, motif occurrence, phrase versus micro layers, selective chord rolls, moved pedal release, profile precedence, shared state, 900 ms holds, speed, restore active holds, A/B boundary, tempo changes, SMPTE, hand/track filters, key geometry, Cloud result/empty/error/cancel/timeout.
- Main boots the real new App and parses a generated MIDI fixture. The UI harness exercises tabs, modes, presets, hands, speed, Play/Pause and seek. Additional tests exercise modal creation, deferred seek, bubble tap/drag and gesture exclusivity.
- Layout model: 1280×720, 1920×864, 2400×1080, 390×844 and 844×390; four modes; window bounds and minimum interactive dimensions. Scrolling content may intentionally extend beyond the visible viewport.
- Rendered the actual layout-model instance bounds for Full/Compact/Mini/Hidden and visually inspected Full, Compact and Mini. These are synthetic layout renders, not Roblox screenshots. The model does not reproduce font metrics, safe-area engine behavior, GPU compositing or Roblox input bubbling.

Pianist fixture (48 notes, three repeated phrases, seed 123): mean absolute timing shift 8.248779 ms, maximum 16.721689 ms, standard deviation of absolute shift 4.910342 ms. Exact has zero shift. These numbers establish variation, not musical superiority or perceptual quality.

## Provided videos

- 1000222109.mp4: 160.914 s, 1920×864. Inspected frames around 16.1, 56.3, 104.6 and 144.8 s. Baseline full panel obscures the game; Mini lacks speed controls.
- 1000222110.mp4: 7.077 s, 1920×864. Inspected frames around 0.7, 2.5, 4.6 and 6.4 s. Baseline window crosses screen boundaries; piano keyboard renders accidentals with incorrect visual geometry.
- No captured new Roblox footage exists yet. No note-on/note-off timestamps or source MIDI were extracted from these videos. A measured audio A/B comparison with the new engine remains unvalidated.

## APK / Cloud

Read-only static inspection of Dodo-Music-Auto-Game-Clicker_2.3.0_FUSION.apk (an earlier modified artifact).
SHA-256: 3df08a5d853d9bf29dc79a201585819e89fd8824b7751ab7d4fdb79fa3e52f80.
Three DEX files were inspected for service strings; classes.dex was parsed with androguard. The APK contains api.dundunstudio.com/v1/ and api2.dodomusicstudio.com/v1/ plus Song and MusicModel API data classes. This alone does not establish a supported third-party API, authorization flow or download contract.
The old provider tried speculative route/parameter variants. Those requests are absent from the new execution path. DodoProvider is explicitly Unsupported until a legitimate integration can be validated. No credentials copied; no authentication bypass; no successful live Cloud integration is claimed.

## Known limitations / required RC gates

1. Real Roblox/Delta input delivery, hold timing, shifted-key combinations, pressure perception, mobile safe areas and gesture dispatch have not run here.
2. Game-independent QWERTY cannot guarantee velocity or pedal CC64 support. Original velocity/pedal data is retained; visual execution uses physical hold intervals. Existing Hold trigger mode still needs additional overlap/reconstruction testing; default expressive strike is the validated path.
3. Human phrasing/motif classification is heuristic (phrase-aligned interval/rhythm fingerprints), not a learned pianist. Polyphony limiting is chord-group based, not hardware-adaptive.
4. Layout tests do not prove absence of all text clipping or overlap under real Roblox fonts/localization. Full Player scrolls on short screens. Large library virtualization and very dense MIDI frame cost are unmeasured.
5. Calibration confirms C4/C5/C6 and range manually; it does not infer all intermediate keys or automatically recognize the piano. Full mapping editor, per-note correction UI, latency compensation UI and per-backend selection are deferred.
6. Saving song/game profiles is explicit. Persistent playlists, resume across launches and seed favorites are deferred. Existing stable files remain in history/source but are not loaded by the dev bundle.
7. Dodo Cloud unavailable; cancellation state machine tested with fixtures only. No live search/download result.
8. Extra gestures for ±5 s, visual FPS diagnostics, a comprehensive clipped-text detector and fully automated video comparison remain pending.

Stable must not be promoted until the user approves the RC after a real-device test. Run the dev UI harness only during development: it changes controls and can play the selected fixture/song.
