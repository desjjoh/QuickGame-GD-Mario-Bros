# Player vertical-movement component

## 2026-11-08 — behavior-preserving migration

User approved separate horizontal and vertical responsibilities under the existing Motion group. Inspection found Gravity already owns the vertical speed formula, so this migration replaces that component rather than adding a parallel calculator.

Current BasePlayer layout:

- Motion (MotionValues, proxying Body velocity and resolving modifiers)
- Motion/HorizontalMovement (ground acceleration/braking)
- Motion/AirMovement (airborne horizontal profile)
- Motion/VerticalMovement (VerticalMovementComponent)
- Motion/CornerCorrection and Motion/Climbing

Renamed scenes/components/motion/gravity.gd to vertical_movement.gd, preserving its script UID. Replaced BasePlayer's Motion/Gravity node and gravity_component reference with Motion/VerticalMovement and vertical_movement. Updated Idle, Move, Slide, and scripted walks to use apply_gravity. Removed the old script/node/API rather than retaining a compatibility alias unused by the project.

VerticalMovement exposes apply_gravity(values,delta), speed_after_gravity(values,delta), and finish_step(values,next_speed). The gravity formula, weight, cap, and timestep are unchanged. The last operation commits the prepared next speed and preserves floor-zero behavior. BasePlayer retains one move_and_slide per movement step and coordinates corrections and collision responses after that commit. Grounded paths retain pre-motion gravity; jump/passive-fall paths retain current-speed displacement followed by next-speed preparation. Growth's deferred fall step is unchanged.

There is no automatic physics callback, cached Y velocity, second body movement call, or duplicated Gravity component. Body.velocity remains authoritative. JumpAction and collision/presentation owners continue requesting/writing impulses through their existing paths. This migration intentionally does not introduce integer/fractional storage or claim that impulses have all moved into the component.

NES integer/fraction representation and collision-probe timing are future, separately reviewable changes. The user-confirmed no-ascent brick behavior and 16-tick reaction gate are unchanged by this pass.

Validation initially encountered Godot's stale global-class cache after the script/class rename. Refreshed generated editor/import metadata; this did not alter project/import settings. Focused final verification is recorded below; no full suite was requested.

Final verification: eight distinct focused scenes passed without engine errors/warnings in their final runs: jump_test, falling_gravity_test, landing_rejump_test, movement_handoff_test, growth_handoff_test, pipe_transfer_test, flagpole_ending_test, brick_neighbor_test. The initial combined runner failed only the pre-cache-refresh brick scene; that scene passed on the focused rerun. Existing landing/full-jump fixtures continue checking movement integration rather than mirroring the new helper. Formatter and whitespace checks passed; no full suite or interactive playtest performed. No project settings, Input Map, or import settings changed.


## 2026-11-08 — NES airborne fractional integration

Implemented the approved next phase. At 60Hz with representable byte-sized gravity and an integer-pixel speed cap, VerticalMovement stores integer_speed, speed_fraction (0–255), and position_fraction (0–255). It adds speed fraction to position fraction, consumes carry into integer displacement, then adds gravity to speed fraction and carries into integer speed. The NES maximum-speed fractional threshold/reset is retained; default published fall speed can briefly include the lower half of the cap's fraction before resetting to the cap. Body.velocity is the public composed-speed/impulse interface, not a second unsynchronized accumulator; externally changed speeds are encoded before the next step.

BasePlayer requests the prepared integer displacement as temporary motion velocity, performs its existing single move_and_slide, then publishes the calculated next speed. VerticalMovement preserves its integer target against sub-half-pixel Godot safe-margin recovery only when no actual floor/ceiling collision occurred. Genuine collisions and larger obstruction corrections retain authority. This removes residual ~0.06px Godot recovery from otherwise integer reference trajectories. Deliberate jump initialization clears the two initial fractions through reset_fraction, as InitJS does, and aligns the logical feet baseline to an integer. Area arrival resets fractional state through the existing arrival hook; Mario calls the base hook before form/posture restoration.

Grounded/support and scripted pre-gravity paths retain their previous ordering. Non-60Hz calls, non-byte gravity/weight effects, and non-integer-pixel caps use the previous float calculation rather than silently rounding custom values to NES parameters. This is a deliberate compatibility boundary, not exact emulation of arbitrary non-NES settings. Climbing, pipe animations, death/presentation trajectories are not claimed to use the NES airborne integrator.

### Exact reference verification

Added vertical_fraction_test and tests/fixtures/vertical_nes_writes.json: 313 integration steps extracted from the input-only normal and running/seam Mesen traces. Fixtures use the actual before-state and observed gravity fraction addition, and compare resulting integer Y, speed byte, speed fraction, and position fraction before subsequent collision responses. Extraction includes the final cap-reset writes rather than incorrectly treating the first intermediate fraction write as the final value. All four quantities match exactly without tolerance. These are independently seeded integration samples, not a claim of continuous whole-game replay parity.

Added vertical_jump_reference_test: normal state-driven stationary Super jump under a CanvasLayer, matching input-only frames 930–935 exactly after converting origin Y to feet (+32). Expected feet are 204,200,196,192,189,185; both fraction arrays also match exactly. The block is explicitly active because the fixture disables camera-follow activity updates. The final no-ascent response remains the user's selected behavior, rather than the original's following extra pixel.

Integer trajectories exposed an exact-underside boundary discrepancy: a Godot ray previously counted its endpoint on the block bottom as a bonk, while the reference tile lookup assigns that coordinate to the empty tile below. Standing head queries now offset Y by the same tiny boundary-ownership epsilon already used by side probes. The canvas regression explicitly checks that touching that boundary does not bonk until the next upward step. The full-jump neighbor regression retains strict captured break/no-break and hit-frame assertions; none were relaxed. Independent seeded scenarios clear fractional state as well as their reaction gate.

Initial integration runs exposed the boundary discrepancy, stale fixture fractional state, an inactive offscreen fixture block, and fixture extraction reading a pre-cap write instead of the final cap reset. These were corrected before the final passing checks. The previous zero-ascent brick behavior and 16-tick gate are retained; restoring original-game post-break movement remains a separately agreed gameplay change.

Final verification: all eleven selected scenes passed without engine errors/warnings: vertical_fraction_test, vertical_jump_reference_test, brick_neighbor_test, landing_rejump_test, canvas_terrain_test, super_mario_corner_test, super_mario_movement_test, pipe_transfer_test, growth_handoff_test, jump_test, falling_gravity_test. Formatter and whitespace checks passed. No full suite, new Mesen capture, or interactive visual playtest was performed for this implementation; existing read-only captures supplied the exact numerical oracle.
