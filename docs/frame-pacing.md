# Camera frame pacing investigation

The intermittent camera hitch reported on a 240 Hz monitor remains unconfirmed. Do not treat the diagnostic results below as a fix or proof of presentation on that monitor. Camera thresholds, VSync, physics tick rate, viewport resolution and renderer settings have not been changed.

## Current findings

Physics interpolation is enabled. LevelCamera follows authoritative physics positions, retaining fractional displacement and avoiding interpolated coordinates in physics feedback. SharedShadowComposer submits the final camera matrix to render-only world/player roots; HUD stays fixed. A temporary rendered probe found the viewport camera origin matched the expected interpolated physics camera position within approximately 0.000062 logical pixels during automated traversal.

The checked-in opt-in probe ran a ten-second automated flat-ground run with periodic jumps under Forward+ D3D12, capped at 240 FPS: 2,400 rendered samples, median 4.167 ms, p99 4.628 ms, maximum 4.888 ms. A five-second normal-game startup/playable-mode smoke check captured 1,200 frames without engine errors. These are host-side render completion intervals from an off-screen diagnostic window, not monitor scanout, input-to-display latency, GPU timestamp measurements, or a reproduction of the reported intermittent hitch. Longer interactive capture is still needed.

A 256x240 nearest-filtered viewport also has visible pixel-grid steps: smooth fractional transforms can produce repeated rasterized positions at high refresh rates. This differs from a delayed frame. Do not change the pixel-art presentation to address an unmeasured long-frame issue.

## Capture while playing

1. Open `tools/diagnostics/frame_pacing_probe.tscn` in Godot.
2. Press F6 to run that scene. It loads the normal Game with transitions enabled and accepts normal controls.
3. Play for sixty seconds, trying the actions where the hitch was noticed. Remember roughly when it happened.
4. Capture ends automatically and prints the absolute CSV path in Output. Closing the diagnostic window early also attempts to save the partial capture.
5. Find CSV files under `user://diagnostics`. In Godot, **Project > Open User Data Folder** opens the containing user-data directory. Capture filenames are unique per run.

Normal F5 gameplay does not instantiate this recorder. No Input Map bindings or Project Settings need editing. The recorder briefly warms up for sixty rendered frames before sampling, so the very earliest startup frames are not included. It buffers samples in memory and writes once at completion to avoid per-frame disk or console traffic; measurement still has some overhead.

For command-line capture, run from the project folder, replacing `<Godot console executable>` with your installed executable:

```powershell
& '<Godot console executable>' --path . res://tools/diagnostics/frame_pacing_probe.tscn -- --pacing-seconds=60
```

For a controlled traversal fixture with automatic movement and periodic jumping:

```powershell
& '<Godot console executable>' --path . res://tools/diagnostics/frame_pacing_probe.tscn --max-fps 240 -- --pacing-auto --pacing-seconds=10
```

The automatic fixture reuses camera_follow_test's flat scrolling scene, extends its floor/bounds, and disables transitions via that fixture. It does not reproduce all painted-stage interactions. The seconds argument is clamped to 1–600; default is sixty. A renderer is required; headless mode is rejected. The 240 FPS cap is per-process and is not a saved setting or a guarantee of 240 Hz presentation.

## Reading a capture

CSV records elapsed time, render-completion interval, physics frame number/interpolation fraction, previous/current camera X, viewport render-origin X, expected origin X, process/physics monitor times, draw calls and transition activity. Process/physics monitor values are engine aggregate samples rather than exact GPU work for that row. Expected camera origin assumes the current unrotated, zero-offset, 1x camera; exclude startup, camera changes and transitions when comparing it. The synthetic flat fixture provides the cleanest comparison.

Look for long render intervals near the reported time first, then compare camera progress and engine timing. Regular render intervals with an unexpected camera pause suggest follow/integration/interpolation behavior. A delayed render interval with otherwise correct camera positions points toward frame pacing or workload, requiring further profiling. Stable measurements alone cannot rule out OS scheduling, display synchronization or scanout issues.

Godot distinguishes jitter, stutter and input lag in its [rendering guidance](https://docs.godotengine.org/en/latest/tutorials/rendering/jitter_stutter.html). Any VSync, refresh-rate, viewport or physics-setting experiment should be discussed and approved separately.

## Pipe/block ledge follow-up

The reported hitch happens mostly while jumping around pipes and blocks. ledge_camera_test exercises 72 controlled Jump-state descending corner contacts across 16/32px surfaces, both directions, walk/run speeds, three subpixel overlaps and three vertical positions. Its rendered 240 FPS-cap run preserved one horizontal step and matching right-only camera advance. These contacts use static geometry matching block/pipe widths, not full animated entities; this checks the movement path, not every real-stage interaction or rendered monitor frame. Existing corner, wall-hop and stepped-gap regressions cover additional geometry. No movement/camera correction was made from these results.

Capture now also records player position/velocity, total physics body displacement, native move_and_slide displacement, floor contact and state code (0 absent, 1 Idle, 2 Move, 3 Slide, 4 Jump, 5 other). Manual landing correction intentionally consumes horizontal motion before move_and_slide, so native displacement alone can be zero while total displacement is correct. Compare total movement against camera movement and frame timing. Teleports and scene changes must be excluded. These fields help correlate the reported real-stage hitch; they do not classify a correction as a defect automatically.
