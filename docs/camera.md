# Level camera

1-1 uses LevelCamera on its Camera2D. BaseLevel calls follow_target after player state physics and before its horizontal screen clamp. It follows the moving Body, not the stationary entity root. Camera2D processes on physics ticks, has no smoothing, and receives an immediate scroll update. Follow and clamp calculations use the camera's authoritative global position, not its interpolated rendered screen center.

The requested behavior is original SMB right-only scrolling: no backward scrolling and no vertical tracking. It begins after the target's screen-relative sprite-left coordinate reaches 80 pixels; before 112 pixels, it scrolls at half the player displacement. At 112 pixels and beyond, it scrolls the full step. The camera cannot advance beyond the right world edge. Mario can move left within the current view but cannot return to areas that have scrolled away.

LevelCamera exposes Follow Enabled, World Left/Right, Scroll Start, Full Speed Start, and Target Origin Offset. Defaults are -128/768 world bounds and 80/112 thresholds. Target Origin Offset is 8 world pixels because Mario's Body origin is horizontally centered, while the reference tracks sprite-left position. These thresholds target the current 256-wide, 1x, unrotated camera. Zoom-aware width is used for world limits, but the NES threshold proportions are not automatically rescaled for other view sizes.

The camera counts only new rightward progress beyond the furthest target X seen since reset_target/snap_to_arrival. Moving left and then retracing the same ground does not add camera movement. This prevents tiny back-and-forth collision recovery at a wall from ratcheting a one-way camera forward. Fixed cameras still update their baseline while follow is disabled; explicit arrivals reset it. New progress retains fractional precision, so a steady 2.5-pixel step remains 2.5 rather than alternating between 2 and 3. The early zone uses a continuous half-speed factor. These are deliberate smoothness adjustments to the reference's integer-step scrolling, preserving the 80/112 thresholds and right-only behavior. Rendering still uses the 256-by-240 pixel-art viewport and physics updates; physics interpolation now smooths rendered movement between these ticks, while frame pacing still depends on the display and renderer. It does not reproduce NES fractional integration, previous-frame rendering order, SideCollisionTimer scroll suppression, moving-platform scroll forces, or every game-mode lock. Reference: ScrollHandler in https://gist.github.com/1wErt3r/4048722 . Solid walls already cancel body movement in Godot. Keep the camera's transform and smoothing at the authored values for this mode.

1-1's main area has world bounds X=0..1536 and an initial camera center of (128,120). Its authored layout includes platforms, pipes and pits; the player spawn remains (48,208). Camera regressions construct their own fixtures. BaseLevel owns Players/PlayerSpawn and Areas/MainArea/Layouts/EntityLayout paths; preserve those paths when organizing scenes.

camera_wall_jump_test holds walk/run into both sides of a pipe, repeats short hops without clearing it, checks no accumulated drift, and verifies that a full jump clearing the pipe resumes rightward scrolling. Camera follow tests also cover retracing old ground, thresholds, slowed/full fractional steps, no backward/vertical scrolling, the right limit, and a live run across the stage. Existing camera-boundary tests disable follow to isolate the clamp. Jump tests create their own floor gap for ledge behavior. Game-owned pit death and PlayerSpawn restart are covered in [death lifecycle](death.md).

## World boundary guides in the editor

LevelCamera is a tool script that draws labeled vertical guides at its actual global World Left and World Right X coordinates: green on the left, orange on the right. Each guide spans one configured logical viewport height at the camera's vertical position, adjusted for camera zoom. Both authored area cameras can show guides, including an inactive camera. These represent world scrolling edges, not the camera's current screen rectangle.

Select an area's Camera2D and edit World Left/World Right to update the guides. Editor Guides / Draw World Bounds defaults to enabled and can hide them per camera. Bounds changes and camera/parent transforms request a redraw; runtime camera movement, clamping, scene colors and Project Settings are unchanged. Drawing is guarded by Engine.is_editor_hint(), so it does not appear during play. If an already-open editor does not pick up the new tool annotation, reopen the scene or restart Godot.

## Area cameras

Cameras now live inside their owning area: Areas/MainArea/Camera2D and Areas/LowerArea/Camera2D. MainArea's camera remains enabled and scrolling; LowerArea's fixed camera remains disabled until future travel logic selects it. LowerArea currently sits at (896,240); its local camera center (128,120) gives world center (1024,360). Arrival is local (32,48), world (928,288). World bounds on the fixed camera are 896/1152. Its terrain and markers now belong to its own Layouts group, preserving all painted world positions. No background fill was added. See [area themes](level-themes.md).

## Physics interpolation

Project Settings physics/common/physics_interpolation is enabled with user approval. The physics tick rate remains at its default 60 Hz; camera and player presentation interpolate between ticks. Initial player placement resets interpolation after entering the tree, and LevelCamera.reset_target resets the camera history. Future teleport code must reset the moved player's interpolation history after repositioning it, then reset the destination camera target. Camera smoothing and scrolling thresholds are unchanged.

Do not feed get_screen_center_position back into LevelCamera physics follow or its player clamp: with interpolation enabled this is a presentation coordinate and can introduce feedback lag. The current unrotated, zero-offset LevelCamera uses global_position for those calculations. Camera and lower-room tests construct independent terrain fixtures so level painting does not redefine their expectations.

Movement transitions must not skip body integration. Pre-movement handoffs from Idle, Move and Slide enter the next state and let it consume the same physics tick; transitions after movement do not integrate again. This prevents camera pauses on skid entry/cancellation and passive falls as well as jump takeoff. The 44-case movement_handoff regression checks exactly one body integration and matching camera displacement; existing air-movement takeoff coverage remains. Scrolling thresholds and interpolation settings are unchanged.

## Pipe camera selection

Pipe entrance requests are deferred by BaseLevel until the physics callback finishes. Destination selection uses area_id and endpoint_id, with arrival as the default. The level disables other area cameras, enables/makes current the destination camera, and snaps scrolling cameras to reveal the endpoint within world bounds before resetting tracking/interpolation history. Fixed cameras retain their authored position. The player Body is moved and its interpolation history reset first. active_area references the destination scene, while GameHandler stores current_area_id and current_endpoint_id. LowerArea retains its fixed camera. See [pipes](pipes.md).

Animated pipe entry freezes source-camera follow and bounds during the controlled descent. Once the player is hidden and the 0.8-second timer finishes, the existing deferred endpoint handoff moves/resets the body and selects the destination camera. No fade or camera smoothing change is involved. Invalidated routes cancel before camera selection.

Inactive cameras now unload with their area's runtime. Endpoint metadata remains available without a live camera; the destination camera is recreated at handoff and selected/reset before the source camera is freed. The local editor still contains both authored cameras. Never keep an old runtime camera reference across area transitions.

Entry draw-order changes only reorder the Players sibling group before/after Areas. Body positions, camera transforms, interpolation settings, and camera follow priorities are unchanged.

## Intermittent high-refresh pacing

An occasional hitch on a 240 Hz monitor remains under investigation. Opt-in normal-play and automatic timing capture instructions, measurements and limitations are in [frame pacing](frame-pacing.md). No camera behavior or Project Settings were changed by this investigation.

## Independent one-screen test level

scenes/levels/test_level.tscn inherits BaseLevel directly and has one MainArea. Its fixed camera sits at (128,120), with World Left/Right=0/256 and Follow Enabled=false. At 1x zoom the view is 256x240 (16x15 world grid cells). Ground fills columns 0..15 at rows 13/14. Its spawn is (48,208). TitleScreen now references it as its background, with Mario suspended by GameHandler. Use F6 for standalone inspection/testing with normal player controls. It has no transport routes. The connected stage is scenes/levels/worlds/world 1/1-1.tscn. Global camera/project settings were not changed.


## Screen-edge skids and wall presentation - 2026-11-04

The camera edge is a position clamp with the reference KeepOnscr input exception, not a solid wall. At the left edge, rightward input preserves outward leftward momentum; at the right edge, leftward input preserves outward rightward momentum. Reversal friction can then finish the skid while position remains clamped. Neutral or outward input clears outward velocity. Velocity already directed into the screen and vertical velocity remain unchanged. This applies in the air too; controls unavailable through the entity input gate count as neutral.

Solid walls remain different: BasePlayer.move_body explicitly clears horizontal velocity directed into a reported wall, including floor/wall contacts where Godot can otherwise retain velocity despite blocked displacement. Slide uses the pre-collision braking result for the collision frame's pose, then resolves stopped motion on the next physics tick without a second integration or an idle movement frame. Natural skid completion retains its existing threshold. No full-speed wall momentum or invented timed skid lock is retained. This follows ImpedePlayerMove and the reference's separately cached animation speed rather than treating wall and screen-edge contact identically.

camera_bounds_test covers both edges, zooms, all input signs and vertical speeds. slide_collision_test performs real physics contact, checks the single collision-frame skid pose, next-tick reversal and live edge skid retention in both directions. Existing wall-hop and lower-pipe landing regressions guard against camera ratcheting and lost ledge momentum.

## Flagpole ending lock

The level-owned presentation acquires a runtime owner-scoped scroll lock after consuming actual approach movement. While locked, LevelCamera consumes target history without scrolling, so attachment/dismount placements cannot push the view or accumulate a catch-up jump. The scripted walk releases this lock at the reference-derived vertical cue. Cancellation/shutdown release ownership. Authored Follow Enabled and bounds remain unchanged; unconfigured manual climbables do not acquire an ending lock.
