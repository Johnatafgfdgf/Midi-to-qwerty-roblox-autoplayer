# v0.4.3 — video-driven repair pass

This build was made after reviewing two real-device recordings from Android/Delta.

## Bugs confirmed from the videos

- The old UIGridLayout rows were fitting exactly to the parent width. Android pixel rounding could push the last cell to the next row.
- That caused `SOLTAR` to overlap the `Parte tocada` label in Player.
- `Transpose +1` could disappear from Settings.
- Humanization presets could wrap into the strength controls.
- Several controls looked like they were missing even though they had been created.
- The mini player still displayed an older version label.

## UI rebuild

`src/UI/AppMobileV043.lua` replaces the fragile grid-based control rows with manually positioned rows.

Improvements:

- Player transport has stable 5-button and 3-button rows.
- Hands/parts are split into two clean 3-button rows.
- A/B loop controls are separated from part selection.
- Humanization presets use explicit 2x2 rows and a strength meter.
- Settings has a dedicated fidelity section and a clear quantization warning.
- Piano mapping editor is collapsed by default and only expands when requested.
- Mini player shows the correct build number.
- Full window remains draggable; hidden state uses a compact floating button.
- Page ScrollingFrames are direct children of the content area, removing the hidden-parent bug entirely.

## MIDI fidelity fixes

- Scheduler v0.4.3 defaults to `CatchUp`, so frame stalls do not silently delete note attacks.
- Quantization is reset to `Off` once for existing v0.4.2 configs because the test recording showed `1/32`, which changes the original MIDI timing.
- New installs also default to Quantization Off.
- Maximum simultaneous notes defaults to 16 instead of 10.
- Humanization baseline was reduced to 5%, 3 ms timing and 2 ms chord spread.
- Smart octave shifting now requires a larger coverage improvement before moving the whole performance.
- If octave folding makes two different MIDI pitches land on the same physical QWERTY key at the same attack, the mapper keeps one musically important strike instead of double-triggering that key.
- Diagnostics now report catch-up bursts and corrected mapping collisions.

## Important

The Roblox piano and Delta keyboard backend still require real-device validation. Use `Exact` humanization and Quantization Off first when checking note correctness.
