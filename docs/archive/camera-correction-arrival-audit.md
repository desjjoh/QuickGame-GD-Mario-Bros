# Camera corrections and pipe arrival audit

## Investigation — 2026-11-08

The user reported forward camera jumps during small positional corrections and left-of-center framing after returning from 1-1's underground room. No gameplay implementation or settings changed in this investigation.

## Position correction is currently counted as movement

LevelCamera.follow_position computes advance from the player's final global X and its previous furthest target X. BaseLevel calls follow_target after player physics. CornerCorrection can reposition the head sideways before move_and_slide; MarioTerrain can push Super Mario sideways after movement. These changes therefore enter the same final-X measurement as walking. The existing high-water mark prevents repeated wall oscillations over already-seen positions from ratcheting scroll, but does not exclude a correction that establishes a new furthest X.

A controlled Godot diagnostic after actual pipe travel reset the camera to left 0, put Mario at X=200 with zero velocity, then applied a four-pixel right placement and called follow_target. The camera advanced four pixels. This demonstrates the measurement path; it is not a newly captured natural corner-snap sequence.

Reference ScrollHandler reads Player_X_Scroll, written by the horizontal movement routine, plus platform scroll, and gates scrolling by screen position, scroll lock, and SideCollisionTimer. PlayerCtrlRoutine invokes scrolling before PlayerBGCollision positional corrections. A new Mesen RAM fixture placed a stationary Mario beyond the scroll threshold and applied +4 X while leaving movement at zero: player world X changed 448→452, screen-left remained 256, and Player_X_Scroll remained zero. [Script](reference/camera-correction.lua), [trace](reference/camera-correction.csv).

Proposed, not implemented: distinguish movement that may scroll from placement/collision correction, and reset/adjust follow tracking on placement so a correction does not become delayed scroll on the following tick. Preserve wall blocking, legitimate walking/landing displacement, existing limits, and transport authority. A natural corner/head/uncrouch correction matrix should verify the change.

## Pipe return framing is a separate policy

BaseLevel._commit_area_arrival places Mario, makes the destination camera current, then calls LevelCamera.snap_to_arrival. That function computes left = player_body_X - 8 - full_speed_start, clamped to world limits. With full_speed_start=112, an unconstrained arrival puts Mario's body at screen X=120 and sprite-left at X=112. It intentionally reuses the movement follow threshold; it does not center the body at X=128.

A controlled Game/actual 1-1 diagnostic transferred to the lower area, then used animated transport to main/secret_exit and waited for exit completion. Return body was (2608,176), camera-left 2488, body screen X=120, sprite-left X=112. The diagnostic completed without engine errors or warnings. The existing pipe-transfer regression checks camera switching and source-camera freezing but does not assert destination horizontal composition.

The original game is also not centered on this return. InitializeArea derives the screen page from EntrancePage; PlayerStarting_X_Pos uses alternate-entry index 2 to select $38 (56). A fresh Mesen run of the existing controlled underground/return fixture recorded return world X=2616, left 2560, sprite-origin screen X=56 throughout exit, continuing into normal player-control mode at frame 1206. [Script](reference/camera-arrival.lua), [trace](reference/camera-arrival.csv). This trace injects RAM terrain/player fixtures as documented in the earlier Super movement investigation; it is not an untouched playthrough.

The screen-X comparison uses the NES sprite-origin convention. Our body origin is eight pixels to the right of sprite-left. Thus current Godot is sprite-left 112/body 120; reference is sprite-origin 56 (equivalent body 64). Neither is a centered 16-pixel actor. Exact world pipe placement is a separate comparison and was not changed here.

Pending decision: reference-authored left-of-center framing versus deliberately centering Mario on return. Do not silently implement centering as a fidelity fix. Arrival framing should have its own rule rather than deriving from the normal full-speed follow threshold.

## Evidence limits

Read current LevelCamera, player motion/correction paths, BaseLevel transport commit, pipe geometry, and camera/transport regressions. Ran the controlled Godot transport/placement diagnostic and two Mesen fixtures. No full regression suite, natural corner-playthrough capture, or rendered camera-judder comparison was performed. No engine, scene, Input Map, interpolation, or audio settings changed. Reference source: [SMB disassembly](https://gist.github.com/1wErt3r/4048722), ScrollHandler, PlayerCtrlRoutine, InitializeArea, InitializePlayer, and PlayerStarting_X_Pos.


## Implementation — 2026-11-08

The user selected NES framing and authorized both corrections. BasePlayer now accumulates camera_correction_x separately from world position. Before move_and_slide, a head correction is recorded as placement, while a successful landing correction retains its already-integrated intended horizontal step. After the slide, displacement beyond the requested horizontal movement is recorded as recovery. A side-blocked/zero-horizontal-speed result contributes no scroll motion, matching the reference's side-collision scroll gating. Mario records additional Super terrain push-out after shared movement.

LevelCamera compares current world X minus the accumulated correction when tracking forward progress. reset_target establishes the same corrected baseline, preventing later scrolling from replaying an excluded correction. Real world X still controls the screen threshold. This retains the existing furthest-progress and early/full-speed follow behavior. Explicit lifecycle relocation remains paired with reset_target/snap_to_arrival; arbitrary external direct position writes do not identify themselves as corrections automatically.

TransportPlacement destinations now supply camera_sprite_x=56 in their resolved arrival descriptor. BaseLevel passes it to snap_to_arrival's optional framing argument. The default argument preserves ordinary endpoint/respawn behavior. Pipe arrival uses the authored pipe's world position and clamps the requested screen composition to area bounds; it does not shift stage geometry or force a fixed-page camera. The actual 1-1 return now has body X=64/sprite-left X=56. Its camera world-left differs from the original ROM's fixed page because existing project pipe world placement is unchanged.

Affected paths: scenes/player/base/base_player.gd, Mario's move_body override, scenes/components/presentation/level_camera.gd, scenes/levels/base/{base_level,area_transport}.gd, and focused camera/corner/Super regressions. No scene or project settings changed.

Verification: eight distinct focused scenes passed without engine errors or warnings: camera_arrival_test, camera_follow_test, camera_wall_jump_test, corner_correction_test, ledge_camera_test, pipe_transfer_test, camera_bounds_test, and super_mario_movement_test. Real head corrections preserve camera position over repeated follow calls; ordinary walking still scrolls two pixels for a 120 px/s step. Three stationary Super push-out fixtures account for the complete correction offset. The actual animated 1-1 return matches sprite-left X=56/body X=64 and remains stable at idle. The ledge matrix retains valid landing movement and now expects no scroll on blocked side contact. Initial runs exposed blocked recovery drift and an implicit Camera2D process-mode warning; both were corrected before successful reruns. Failed assertion exits included ObjectDB warnings and were not counted as clean passes.

No full suite, new Mesen capture beyond the preceding investigation, or interactive rendered camera-judder playthrough was performed. Moving-platform scroll contributions are not implemented by this change. Current guides record the implemented ownership; the preceding proposal section remains historical.
