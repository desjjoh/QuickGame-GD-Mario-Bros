# Deployment

## Windows export

1. Install export templates that match the Godot editor version.
2. Open **Project → Export** and select the existing **Windows Desktop** preset.
3. Choose the output path and export with **Export With Debug** cleared for a release build.
4. Launch the exported executable outside the editor. Keep the exported PCK beside it if the preset produces one.

Verify title startup, keyboard and controller input, area transitions, audio, and return to title in the exported build.

## Regenerate audio assets

The game loads the WAVs in `assets/audio/music`. The generators are needed only when rebuilding those assets:

```powershell
python scripts/build_music_tracks.py
python scripts/build_area_music.py
```

Reimport the files in Godot and run the relevant audio and transition regressions before exporting. The generators share a PCM scale and preserve cue-specific envelopes.
