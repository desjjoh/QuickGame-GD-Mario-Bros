# Deployment

## Windows export

1. Install export templates that match the Godot editor version.
2. Open **Project → Export** and select the existing **Windows Desktop** preset.
3. Choose the output path and export with **Export With Debug** cleared for a release build.
4. Launch the exported executable outside the editor. The current preset embeds the PCK in the executable; keep a separate PCK beside it if using a preset that produces one.

Verify title startup, keyboard and controller input, area transitions, audio, and return to title in the exported build. Check that both reward brick variants show their active brick artwork, emerging power-ups can be collected, and Super Mario descends after breaking a brick beside an intact neighbor.

## Regenerate audio assets

The game loads the WAVs in `assets/audio/music`. The generators are needed only when rebuilding those assets:

```powershell
python scripts/build_music_tracks.py
python scripts/build_area_music.py
```

Reimport the files in Godot and run the relevant audio and transition regressions before exporting. The generators share a PCM scale and preserve cue-specific envelopes.

The cached brick-shatter effect in `assets/audio/effects/brick_shatter.wav` is loaded directly by SoundHandler. The music generators do not rebuild this effect and should not be run for script-formatting changes. No live shared noise renderer is used.

## Source and release hygiene

Public project documentation consists of the README and the seven guides in `docs/`. Local walkthroughs, research captures, settings approvals, and history live in the top-level `.archive/`, ignored by Git and Godot. Do not copy that folder or `.godot/validation` into a release. Required regression datasets belong in `tests/fixtures/` so clean checkouts can run their tests.

Marker generators and audio generators are source tools, not disposable caches. Python `__pycache__` directories and `.pyc` / `.pyo` files are ignored. The obsolete level-wide shadow shader is kept only in the local reference archive; active presets use the shared compositor shaders.

Before exporting, run focused checks for the changed behavior and rendered tests when composition changes. Launch the export outside the editor and verify the normal title-to-ending flow. A full regression run or successful export must be reported separately from focused development checks.
