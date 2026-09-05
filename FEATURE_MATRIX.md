# Feature matrix

Status legend: ✅ implemented, 🟡 implemented foundation / needs broader refinement or real-device validation, ⬜ not yet represented in the current UI/build.

## Core / parsing

| Area | Status |
|---|---|
| SMF 0/1 parsing | ✅ |
| SMF 2 container handling | ✅ |
| VLQ / running status | ✅ |
| tempo changes / absolute timeline | ✅ |
| SMPTE division | ✅ |
| Note On/Off / velocity | ✅ |
| CC64 sustain | ✅ |
| track/channel/program metadata | ✅ |
| malformed-file error containment | ✅ |
| huge-file cooperative parser yielding/cancellation | ⬜ |

## Playback

| Area | Status |
|---|---|
| Play/Pause/Stop | ✅ |
| seek / ±5s | ✅ |
| active-note rebuild after seek | ✅ |
| speed without pitch change | ✅ |
| A↔B loop | ✅ |
| scheduler late-event policy | ✅ |
| emergency Release Keys | ✅ |
| duplicate physical-key ref counting | ✅ |
| playlist previous/next | ✅ |
| shuffle/repeat controls in UI | ⬜ |
| live selectable full-song loop UI | 🟡 config/scheduler |

## Parts

| Area | Status |
|---|---|
| Both/LH/RH | ✅ |
| melody/accompaniment/bass | ✅ |
| track selection | ✅ |
| channel selection | ✅ |
| voice IDs | ✅ engine |
| hand confidence | ✅ |
| automatic pitch + continuity split | ✅ |
| fixed split infrastructure | ✅ config |
| manual per-track LH/RH reassignment UI | ⬜ |
| instrument-family filtering UI | ⬜ |
| arbitrary custom Boolean part expression | ⬜ |
| difficulty estimate per hand | ⬜ |

## Humanization

| Area | Status |
|---|---|
| new seed per performance | ✅ |
| fixed seed infrastructure | ✅ |
| correlated rather than note-by-note random timing | ✅ |
| global/phrase/hand/note layers | ✅ |
| chord spread | ✅ |
| BPM/density adaptation | ✅ |
| velocity-aware stability | ✅ |
| articulation-aware duration | ✅ |
| phrase detection | ✅ foundation |
| legato/staccato inference | ✅ |
| explicit beat/downbeat model | ⬜ |
| explicit swing/groove model | ⬜ |
| dedicated rubato curve wired to slider | 🟡 setting exists, deeper model pending |
| advanced two-hand synchronization constraints | 🟡 bounded correlated model |
| musical safety limits | ✅ bounded timing/chord/duration logic |

## MIDI → piano

| Area | Status |
|---|---|
| configurable profile | ✅ |
| mobile mapping editor | ✅ |
| transpose | ✅ |
| Strict/Clamp/OctaveFold | ✅ |
| SmartOctave | ✅ |
| max simultaneous notes | ✅ |
| notes-per-second limiter | ✅ engine/config |
| optional quantization | ✅ |
| profile file import/export buttons | ⬜ |
| guided auto-calibration flow | ⬜ |

## UI / storage

| Area | Status |
|---|---|
| mobile layout | ✅ |
| Full/Mini/Hidden | ✅ |
| draggable restore button | ✅ |
| search | ✅ |
| favorites/recent | ✅ |
| settings persistence | ✅ |
| per-song overrides | ✅ foundation |
| cache | ✅ |
| history | ✅ foundation |
| QWERTY/analysis export | ✅ |
| piano-roll visualization | ⬜ |
| first-run tutorial/wizard | ⬜ |
| advanced tooltips/reset-per-section | ⬜ |
| performance-mode toggle | ⬜ |
| MIDI event inspector UI | ⬜ |
| dry-run/preview UI | ⬜ |
| formal DEBUG/INFO/WARN/ERROR logger UI | ⬜ |

## Environment validation

| Area | Status |
|---|---|
| source wired end-to-end | ✅ |
| Delta filesystem runtime test | 🟡 needs device |
| Delta key-event runtime test | 🟡 needs device |
| target Roblox piano profile validation | 🟡 needs target experience |
| large-MIDI stress test on phone | 🟡 needs device |

This matrix is intentionally strict: a feature is not marked fully complete just because an API or config field exists.
