# Level camera

TestLevel uses LevelCamera on its Camera2D. BaseLevel calls follow_target after player state physics and before its horizontal screen clamp. It follows the moving Body, not the stationary entity root. Camera2D processes on physics ticks, has no smoothing, and receives an immediate scroll update. Follow and clamp calculations use the camera's authoritative global position, not its interpolated rendered screen center.

The requested behavior is original SMB right-only scrolling: no backward scrolling and no vertical tracking. It begins after the target's screen-relative sprite-left coordinate reaches 80 pixels; before 112 pixels, it scrolls at half the player displacement. At 112 pixels and beyond, it scrolls the full step. The camera cannot advance beyond the right world edge. Mario can move left within the current view but cannot return to areas that have scrolled away.

LevelCamera exposes Follow Enabled, World Left/Right, Scroll Start, Full Speed Start, and Target Origin Offset. Defaults are -128/768 world bounds and 80/112 thresholds. Target Origin Offset is 8 world pixels because Mario's Body origin is horizontally centered, while the reference tracks sprite-left position. These thresholds target the current 256-wide, 1x, unrotated camera. Zoom-aware width is used for world limits, but the NES threshold proportions are not automatically rescaled for other view sizes.

The camera uses fractional target displacement so a steady 2.5-pixel step remains 2.5 rather than alternating between 2 and 3. The early zone uses a continuous half-speed factor. These are deliberate smoothness adjustments to the reference's integer-step scrolling, preserving the 80/112 thresholds and right-only behavior. Rendering still uses the 256-by-240 pixel-art viewport and physics updates; physics interpolation now smooths rendered movement between these ticks, while frame pacing still depends on the display and renderer. It does not reproduce NES fractional integration, previous-frame rendering order, SideCollisionTimer scroll suppression, moving-platform scroll forces, or every game-mode lock. Reference: ScrollHandler in https://gist.github.com/1wErt3r/4048722 . Solid walls already cancel body movement in Godot. Keep the camera's transform and smoothing at the authored values for this mode.

TestLevel spans 59 columns: floor cells 0 through 58, rows Y=13/14, world X=0 through 944. Initial camera center is (128,120) and PlayerSpawn is (216,208). World Left/Right are 0/944; right-only thresholds and tracking behavior are unchanged. The scrolling test builds its own 896-pixel fixture. Existing block markers are unchanged. BaseLevel owns explicit Players/PlayerSpawn and Layouts/EntityLayout paths; preserve those paths when organizing scenes.

Camera follow tests cover thresholds, slowed/full fractional steps, no backward/vertical scrolling, the right limit, and a live run across the stage. Existing camera-boundary tests disable follow to isolate the clamp. Jump tests create their own floor gap for ledge behavior. There is still no automatic death or respawn.

## Lower test area

TestLevel/Areas/LowerArea begins at (0,512). Its Camera2D sits at local (128,120), uses LevelCamera with Follow Enabled false, world bounds 0/256, and starts disabled. The main stage camera remains current on startup. When future pipe travel activates the lower camera, the shared level clamp uses its view; physical walls, floor, and ceiling additionally enclose the room. Arrival is local (48,208), world (48,720). No automatic warp/camera-switch API is implemented yet.

The room uses GroundLayout columns 0..15 at global rows 32..46: ceiling row 32, floor rows 45/46, and side walls at columns 0/15. Edit its terrain through the shared layout rather than moving a separate TileMap off-grid. LowerArea has no separate background fill; its camera shows the existing viewport background.

## Physics interpolation

Project Settings physics/common/physics_interpolation is enabled with user approval. The physics tick rate remains at its default 60 Hz; camera and player presentation interpolate between ticks. Initial player placement resets interpolation after entering the tree, and LevelCamera.reset_target resets the camera history. Future teleport code must reset the moved player's interpolation history after repositioning it, then reset the destination camera target. Camera smoothing and scrolling thresholds are unchanged.

Do not feed get_screen_center_position back into LevelCamera physics follow or its player clamp: with interpolation enabled this is a presentation coordinate and can introduce feedback lag. The current unrotated, zero-offset LevelCamera uses global_position for those calculations. Camera and lower-room tests construct independent terrain fixtures so level painting does not redefine their expectations.

Jump takeoff must not skip body integration: grounded states now hand the same physics tick to Jump after entering it. A previous transition-only tick left horizontal displacement at zero, causing a visible one-tick camera pause despite nonzero player speed. This is covered by the air-movement takeoff regression; scrolling thresholds and interpolation settings are unchanged.
