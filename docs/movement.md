# Movement and shared values

## Composition

BasePlayer groups HorizontalMovement, AirMovement, and Gravity under Motion; Run, Jump, and Slide under Actions; with the MotionValues script attached directly to Motion. Mario adds WalkAnimation under Presentation and owns Idle, Move, Slide, and Jump. States coordinate the components; their calculations and invocation order are unchanged by the folder split. See [architecture](architecture.md) for the full scene tree.

Mario adds a WalkAnimation component for its character-specific animation timing. It changes AnimationPlayer playback speed and does not alter movement values.

MotionValues owns editable defaults and effective values shared across states. Its velocity property forwards to Body's velocity instead of duplicating live physics data. Values are per entity, not global or shared resources. MotionValues also supplies gravity, weight, and fall-speed limits; see [jumping](jumping.md).

## Overrides

`set_modifier(source, values, priority)` supplies absolute overrides for named fields. Higher priority wins independently for each field. Equal priorities resolve by source-name ordering (lexicographically later wins); use distinct priorities for meaningful precedence. Removing a source reveals the remaining override or base value. Modifiers do not stack additively or alter velocity automatically.

Supported fields: max_speed, acceleration, deceleration, reversal_multiplier. Run uses source `run`, priority 100. A level can use priority 200, and a temporary state can use 300, for example:

```gdscript
player.motion_values.set_modifier(
	&"level", {&"max_speed": 60.0}, 200
)
# Remove only the level's contribution when it no longer applies.
player.motion_values.remove_modifier(&"level")
```

Modifier owners must remove their own contributions when they stop applying. New states that allow running must call the shared preparation helper or explicitly apply/clear the Run action. There is no automatic level-environment override system yet; the API provides the mechanism.

## Source-based starting coefficients

Reference: [SMBDIS.ASM](https://gist.github.com/1wErt3r/4048722), especially `X_Physics`, `FrictionData`, `ImposeFriction`, and `MoveObjectHorizontally`.

The following are our conversions at a nominal 60 updates/s, not measured Godot trajectories:

| Mode | Source speed limit | Pixels/s | Source friction increment | Pixels/s² |
| --- | --- | --- | --- | --- |
| Walk | `0x18 / 16` pixels/frame | 90 | `0x98 / 4096` pixels/frame² | 133.59375 |
| Run | `0x28 / 16` pixels/frame | 150 | `0xE4 / 4096` pixels/frame² | 200.390625 |

Original code also selects friction by speed, doubles it for facing/movement disagreement, uses a running timer, and integrates fixed-point values. We use continuous Godot velocity, symmetric caps, and immediate run-profile selection/removal. Slide adds selected skid thresholds and friction, described below. Outside Slide, braking uses the selected walk/run profile. This is not frame-exact parity; timer retention, full friction/animation-latch rules, subpixel rounding, update order, and collision differences remain to qualify. Nominal 60 Hz is not exact NTSC timing. Jump and variable jumping are implemented separately; water behavior is not implemented.

## Slide state and action

Slide means direction-reversal skidding, not crouching. Hold the opposite horizontal direction at speed to enter. Source anchors are `ProcSkid`, `GetPlayerAnimSpeed`, and `ExitPhy` in the linked disassembly. Our nominal conversions are:

| Configuration | Value |
| --- | --- |
| Entry minimum / stop cutoff | 41.25 pixels/s (`0x0B / 16 × 60`) |
| Fast friction selection threshold | 105 pixels/s (`0x1C / 16 × 60`) |
| Normal friction × reversal multiplier | 133.59375 × 2 = 267.1875 pixels/s² |
| Fast friction × reversal multiplier | 182.8125 × 2 = 365.625 pixels/s² (`0xD0 / 4096 × 60² × 2`) |

These coefficients are not a full port of the original state/animation logic. Friction selection is latched from entry speed. We use one entry/stop cutoff; the original visual skid threshold is separate. Fixed-point traces are not verified.

The action applies source `slide`, priority 300, overriding max_speed (90), acceleration, deceleration, and reversal_multiplier. A higher-priority level/state modifier can still override individual fields. The velocity proxy retains incoming speed even above the overridden cap; Slide brakes toward zero rather than snapping to the cap or accelerating backward. When remaining speed drops below the cutoff, it clears X velocity without changing Y, then returns to Move. Below the entry minimum, Move clears opposing momentum and begins moving in the requested direction without entering Slide.

Releasing direction (including when controls are disabled) retains Slide, its facing, pose, and braking modifier until stopping, then enters Idle without an intervening walk pose. Releasing Run does not remove the Slide modifier. Actively pressing the original momentum direction cancels Slide and returns to Move. Exit removes only `slide`, revealing run/level values that still apply. Update ticks used exclusively for state transitions do not integrate movement.

Reference inspection confirms that neutral input does not itself reset facing or select walking graphics; the original visual skid has its own low-speed cutoff. Our retained Slide-to-stop behavior uses the existing stop cutoff and does not claim exact original low-speed graphics or fixed-point integration. This is not an unconditional input lock: resuming the original direction can cancel it.

Slide has standard animation/sprite/sound hooks. Idle uses `mario-small-idle.png` and Slide uses `mario-small-slide.png`, both under `assets/player/mario (small)/`; they stop animation playback and select frame 0. Move seeds walk-1 on entry, then plays the three-pose `walk` loop. Jump has a takeoff sound; these state enter/exit sound slots remain unassigned. Select Mario's state for presentation, Actions/Slide for skid thresholds, and Presentation/WalkAnimation for cadence.

## Walk/run animation

`scenes/player/mario (small)/animations/walk.tres` contains a looping discrete texture track targeting `Sprite2D:texture`, relative to AnimationPlayer's Body root. It cycles walk-1 → walk-2 → walk-3. At baseline its keys are at 0, 7/60, and 14/60 seconds, with a 21/60-second loop.

The reference's `GetPlayerAnimSpeed` selects timer reloads 7/4/2 using speed thresholds `0x0E`/`0x1C`. `DecTimers` decrements before `AnimationControl` reloads. At nominal 60 Hz our conversions give:

| Absolute horizontal velocity | Pose interval | Pose changes/second | Playback scale |
| --- | --- | --- | --- |
| Below 52.5 pixels/s | 7/60 seconds | ≈8.57 | 1 |
| 52.5 to below 105 pixels/s | 4/60 seconds | 15 | 1.75 |
| At least 105 pixels/s | 2/60 seconds | 30 | 3.5 |

See the [disassembly](https://gist.github.com/1wErt3r/4048722). This reproduces cadence bands, not exact timer phase: changing AnimationPlayer speed scales the remainder immediately; the original countdown retains its current reload until expiry. Velocity quantization, initial phase, and exact NTSC timing remain unqualified.

Move uses absolute Body velocity after movement, not Run input or maximum speed. It adjusts rate without replaying the animation, preserving loop position. Both travel directions use the same loop; existing facing code flips the sprite. AnimationPlayer processes on physics ticks for Mario only. Move restores the previous speed scale on exit; static states stop playback, preventing walking textures from overwriting a skid/standing pose.

To inspect or edit: open Mario's scene, select Body/AnimationPlayer, select `walk` in the Animation panel, and inspect the three discrete texture keys. The resource is external, so save it when editing. Do not key Body position or sprite flip/offset unless changing their ownership intentionally. The action assumes the authored baseline pose duration remains 7/60 seconds; retiming the resource requires updating that calibration too.

## Input and static Idle

Left/right use existing UI actions. The approved `secondary` action uses physical Left Shift and the gamepad left face button; Run reads `ControllerHandler.input_secondary`. Start and select remain unassigned. Controls Enabled gates state input; disabling controls removes the run modifier on the next state physics update and brakes through zero intent.

Idle has no animation. Its state configuration stops AnimationPlayer while keeping displayed properties, assigns the standing texture, then selects sprite frame 0. A future sheet should place the standing pose at frame 0 or change the state property to the appropriate pose. Move's Animation Name is `walk` and Stop Animation On Enter is disabled there.

The current test stage is one screen wide, while right-only scrolling remains available for larger stages. Moving beyond support falls within Move; there is no automatic respawn. Restart with F8/F5 if Mario leaves view.

## Verification

### Numerical audit — 2026-11-01

Inspected script defaults and scene overrides, then ran the loaded player through controller sampling and state physics. Runtime reported 60 physics ticks/s and time scale 1.0. Walk used cap 90 and acceleration/braking 133.59375; Run used cap 150 and acceleration/braking 200.390625. No additional scene tuning overrides were found. No tuning or settings were changed for this audit.

From rest with direction held, the first nonzero Godot velocity occurred on tick 2. Walk reached its cap on tick 42 (0.700 seconds), Run on tick 46 (0.767 seconds). A separate forward-only integer speed accumulator using the reference increments reaches its caps on ticks 41 and 45. That comparison checks arithmetic only: it is not an emulator trace and does not validate collisions, facing initialization, or the whole original update pipeline.

Idle currently spends one physics tick returning Move without applying movement. The same transition-only pattern exists when entering/leaving Slide. These are candidates for a separate update-order correction, not evidence that the baseline acceleration should be increased. Dynamic braking friction, running-timer retention, full skid/animation latch rules, and fixed-point positioning remain known differences. Playback rate/frame-phase limitations are documented above. Visual input latency and perceived sluggishness were not measured in this headless audit.

Run `godot --headless --path . tests/movement_test.tscn --max-fps 60`. Checks use synthetic actions through ControllerHandler and real physics callbacks. They cover walk/run speed selection, braking, reversal, static Idle, bindings, modifier precedence/removal, per-instance defaults, velocity forwarding, and timestep-independent velocity. The test prints PASS on completion; process exit alone is not evidence of passing. Original frame trajectories, audible effects, and visual animation remain unverified.

Run `godot --headless --path . tests/slide_test.tscn --max-fps 60` for numerical skid-rate checks and live Slide transitions, facing, cancellation, and modifier restoration. Release regressions cover both travel directions, walk/run entry speeds, and releasing direction with or without releasing Run. Each case starts on the flat surface so offscreen terrain-edge collisions do not confound the horizontal-only behavior.

Run `godot --headless --path . tests/walk_animation_test.tscn --max-fps 60` for loop order, cadence boundary checks in both directions, live three-pose progression, Run-button independence, braking slowdown, and static Idle restoration. These check playback state and texture changes, not visual feel.



