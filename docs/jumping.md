# Jumping, passive falling, gravity, and weight

Mario's Jump state starts only after a successful grounded Jump action and retains mario-small-air.png through both ascent and descent until landing. Passive ledge falls and recovered tile-gap crossings remain in Move with the walk/run animation. Both paths share AirMovement and Gravity calculations, but only deliberate jumps activate the Jump action's impulse and variable-height gravity profile. Idle and Slide select Move when support is lost.

## Editable nodes

Mario's Actions/Jump assigns `assets/sfx/smb_jump-small.wav` to Sound Effect. Jump emits `jumped` only after a successful launch; BasePlayer plays the assigned clip through its existing body-relative one-shot helper. Ledge falls and rejected midair jumps do not emit it. The audio node frees itself when finished. Other characters may assign a different sound or leave it empty. Headless checks verify the selected stream and one trigger per jump, not audible hardware output.

This asset must import with Loop Mode Disabled: its embedded zero-length loop otherwise makes playback nearly silent. The approved override and diagnosis are in [settings](settings.md). Regression checks decode the imported stream and require a meaningful waveform, in addition to checking jump-triggered audio creation. A runtime bus-capture diagnostic confirmed non-silent output after reimport; speaker output was not directly heard by the agent.

BasePlayer/Actions contains Jump; BasePlayer/Motion contains Gravity and AirMovement. MotionValues exposes base_gravity (1575 pixels/s²), base_weight (1), and base_max_fall_speed (240 pixels/s), with named modifier support for gravity, weight, and max_fall_speed. Velocity remains a proxy to Body. Effective downward acceleration is gravity × weight. Weight is a gameplay gravity multiplier, not physical mass or an original-game parameter; it does not scale takeoff impulse. Zero weight removes gravitational acceleration. Higher weight shortens jumps with the same impulse.

Jump selects one profile at takeoff and applies a priority-250 gravity modifier. Other sources can still override weight or use higher priorities for gravity. Release switches the selected gravity permanently for the remainder of that jump; re-pressing cannot restore the lighter ascent. Jump exit removes its jump and air modifiers. Solid-ceiling contact sets the downward bump speed and switches immediately to falling gravity.

## Reference profiles

From [SMBDIS.ASM](https://gist.github.com/1wErt3r/4048722): takeoff-speed boundaries are `09/10/19/1C` in hexadecimal. Vertical speed is signed pixels/frame; gravity is fractional pixels/frame². Nominal 60 Hz conversions:

| Horizontal speed band (pixels/s) | Upward speed | Held ascent gravity | Fall/release gravity |
| --- | --- | --- | --- |
| Below 33.75 | 240 | 450 | 1575 |
| 33.75–60 | 240 | 450 | 1575 |
| 60–93.75 | 240 | 421.875 | 1350 |
| 93.75–105 | 300 | 562.5 | 2025 |
| At least 105 | 300 | 562.5 | 2025 |

At each boundary the higher band applies. The reference checks held Jump while rising and delays release gravity until at least one pixel above takeoff. Our action follows that condition. Fall speed is capped at 240 pixels/s. These reproduce profile choices, not exact fixed-point trajectories, original terminal-fraction behavior, collision rules, or NTSC timing.

## Jump control and input

Jump uses the dedicated `primary` action through ControllerHandler: Space, Enter, keypad Enter, or the gamepad bottom face button (Xbox A), with any controller device ID accepted. This binding was explicitly approved after runtime inspection found only keyboard events in the original `ui_accept` action. A fresh press is sampled on physics ticks; holding Jump through landing does not jump again. Jumping requires floor contact. Coyote time, jump buffering, double jumps, and swimming are absent.

Jump retains horizontal momentum with neutral input. Directional input uses a dedicated AirMovement component, described below. It does not enter Slide in midair or reselect Run from the button while airborne. Facing is retained from takeoff; the same air sprite is used while rising and falling.

## AirMovement and skid jumps

Motion/AirMovement owns editable air acceleration, caps, and facing-mismatch multiplier. Grounded transition code captures facing and speed/history before Slide exits and removes its modifier. Jump installs its own priority-300 `air` modifier and removes it on landing/exit. It does not retain Slide's low-speed snap-to-zero rule in midair.

Source anchors: `X_Physics`, `ChkRFast`, `ExitPhy`, `LRAir`, and `ChkMoveDir` in the linked disassembly. At nominal 60 Hz, acceleration is 200.390625 pixels/s² at speeds of at least 93.75 pixels/s, otherwise 133.59375 or 182.8125 with fast history. Caps are 150/90 respectively. Facing/travel disagreement doubles the rate; neutral input applies no friction. The reference updates travel direction as velocity changes sign, so the multiplier ends when travel aligns with facing, regardless of held input direction.

Our fast-history capture uses entry speed at least 105 or the active fast-skid friction value as a proxy for the original RunningSpeed latch. That is an explicit approximation, not full latch emulation. Original per-byte velocity integration and fractional caps remain unqualified. Jump scales signed acceleration by input strength and clamps only in the requested direction, preserving existing opposite momentum. Shared higher-priority overrides remain effective. Effective deceleration is zero for neutral input; opposing input brakes through the facing-adjusted acceleration. Run-button state alone does not choose air rates.

`godot --headless --path . tests/air_movement_test.tscn --max-fps 60` covers normal/fast/history rates, facing-based braking, neutral coasting, sign changes, skid-jump capture in both directions, and cleanup on landing. Jump and controller-input regressions are run separately. These are numerical/runtime checks, not hardware feel or full original-frame traces.

The camera is still fixed and falling below the level does not respawn Mario. Restart with F8/F5. No horizontal tuning or project/global physics settings changed. BaseEntity itself does not apply gravity to every world object; specialized states call the action deliberately.

## Verification

`godot --headless --path . tests/jump_test.tscn --max-fps 60` checks short/held height difference, weight effect, landing/static restoration, air sprite, cleanup, falling off a ledge, and rejection of an air jump. Grounded movement tests extend their floor only in test instances to avoid leaving terrain during long horizontal runs. Visual feel and reference frame traces still need manual/trace qualification.

`godot --headless --path . tests/controller_primary_test.tscn --max-fps 60` checks preserved keyboard mappings and raw synthetic Xbox A press/release events on device IDs 0, 1, and 2 through the handler into an actual jump. Physical controller hardware is not exercised by this headless test.



## Solid ceiling contact

All Mario movement states call BasePlayer.move_body(). If the body was rising and move_and_slide reports ceiling contact, the player receives 3.75 pixels/second downward velocity (SMB1 SolidOrClimb/NYSpd sets Player_Y_Speed to 1 in 1/16-pixel-per-frame units). Jump gravity switches to the falling profile and a single ceiling_bump_sound plays. Mario assigns assets/sfx/smb_bump.wav. WAV playback uses a local nonlooping copy without changing import settings. Horizontal velocity remains governed by collision physics.

This implements solid-ceiling behavior, not interactive block bouncing, breaking, coin collection, climbing, or SMB's tile-specific head probe tolerances. Tests hold Jump against a ceiling and verify downward response, falling gravity, one bump playback, nonlooping decoded audio with meaningful amplitude, and eventual landing.


## Small Mario collision envelope

Small Mario overrides the generic BasePlayer shape with an 11-by-14 RectangleShape2D centered at (-0.5,-7). Relative to sprite-left, the sides lie at x=2/13, top at y=2, and bottom at y=16. The feet origin and 16-by-16 artwork remain unchanged. This approximates the small-player terrain envelope from BlockBuffer_X_Adder/BlockBuffer_Y_Adder (small-player offset 14): side probes x=2/13, head y=18, feet y=32 in the reference's logical 32-high player coordinates.

The NES does not use one rectangle for all collision: foot probes are x=3/12 and its object/enemy bounding box is separate. Godot still uses a swept rectangle, so this is not exact probe-based terrain or enemy-hitbox parity. Future player sizes should supply their own shape overrides. Focused regression verifies one-tile gap clearance and loss of ledge support when only artwork overlaps.


## Passive falling in Move

Move keeps its walk/run presentation while unsupported, selects AirMovement on entering a passive fall, integrates gravity and collision, then removes that modifier on landing or exit. No Jump impulse, sound, or jump animation is triggered by a ledge. Move refreshes the Run source each tick, while its higher-priority air profile controls airborne horizontal movement. Jump itself retains its takeoff facing and pose through descent; its exit removes the Jump and air modifiers. A fresh primary press while unsupported still cannot jump. This separates visual/behavior state from the geometric fact of being airborne.


Move freezes its current walk texture and animation phase whenever the body is unsupported, by setting AnimationPlayer speed_scale to zero. On landing, the velocity-based cadence is restored without restarting the loop. This also applies on the first support-loss tick; Jump retains its separate static pose. Move exit restores its previous animation speed as usual. Falling-animation regression verifies frozen texture/phase and resumed playback after landing.

