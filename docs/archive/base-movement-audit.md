# Mario base movement audit

## Scope and status — 2026-11-08

Investigation only, as explicitly requested. No gameplay code, test code, scenes, settings, or movement tuning changed. Temporary diagnostics remain under ignored .godot/validation. This document and the accompanying CSV evidence describe current behavior; recommendations are not implemented.

Focus: landing, jumping, rapid reversal, and turning on landing before jumping again. Examined Mario Idle/Move/Slide/Jump, PlayerState handoffs, RunAction, SlideAction, JumpAction, AirMovement, and controller sampling; compared controlled frame sequences with the original game in Mesen and its [disassembly](https://gist.github.com/1wErt3r/4048722).

## Confirmed findings

### 1. Reversal applies doubled braking too early

Reference PlayerPhysicsSub/X_Physics selects friction using the existing facing and moving direction. OnGroundStateSub then runs GetPlayerAnimSpeed and updates facing before applying that already-selected friction. The first reversal tick therefore uses the undoubled rate. Our Move state enters Slide, whose enter method changes facing and whose apply method immediately doubles friction.

| Controlled right-to-left reversal | NES after first tick | Project after first tick |
| --- | --- | --- |
| Start 90 px/s, no Run | +87.773438 px/s | +85.546875 px/s |
| Start 150 px/s, Run held/history set | +146.953125 px/s | +143.906250 px/s |
| First ground tick after landing at +146.660156 px/s | +143.613281 px/s | +140.566406 px/s |

This is a tick-order difference, not evidence that the shared acceleration constants should simply be reduced. Grounded fixtures used facing right before Left was pressed. The new traces qualify right-to-left reversal; left-to-right reference parity is not yet independently traced.

### 2. The difference can change the next jump's strength

Highest-priority reproduction:

1. Small Mario falls toward level ground with horizontal speed +101.25 px/s and vertical speed +120 px/s.
2. Hold Left and Run while landing.
3. Allow one grounded reversal tick.
4. Press Jump; compare a tap and a 20-tick hold.

| Tick | NES | Project |
| --- | --- | --- |
| Landing contact | VX +97.910156; grounded | VX +97.910156; grounded |
| One ground turn tick | VX +95.683594 | VX +93.457031 |
| Re-jump | Selects -300 px/s takeoff (5 px/tick) | Selects -240 px/s takeoff (4 px/tick) |

The fast-jump threshold is 93.75 px/s. Earlier braking places the project just below it while the reference remains above it. Both accept the re-jump on step 3; the initial jump profile differs. With a 20-tick hold, normalized feet apex is Y=133 in Mesen versus Y≈145.659 in Godot: about 13 pixels lower in the project. With a one-tick tap, apex is Y=179 versus Y≈181.838. These are controlled fixtures, not a universal prediction for every reversal speed.

For an immediate first-ground-tick re-jump from a faster landing (+150 px/s initial), both select the fast jump and match the first horizontal velocity samples. The reported feel is therefore sensitive to speed and whether there is a ground-turn tick before Jump.

### 3. End-of-skid ordering differs

SlideAction.apply brakes, then forces velocity to zero as soon as the resulting speed falls below 41.25 px/s, and exits Slide. Reverse acceleration starts on the next tick. Reference GetPlayerAnimSpeed checks the prior speed before ImposeFriction; when the low-speed reset is taken, reverse acceleration is applied in that same tick.

Examples:

- 90 px/s reversal: project outputs zero on step 11 and negative velocity on step 12; reference remains positive on step 12 and becomes negative on step 13.
- 150 px/s reversal: project outputs zero on step 18 and negative velocity on step 19; reference remains positive on step 19 and becomes negative on step 20.
- Reversal after the +150 landing: both first become negative on step 20, but the project has a zero-speed step 19 and starts at -3.339844 px/s; reference retains +40.019531 on step 19 and starts at -6.093750 px/s.

The earlier braking and later separate acceleration step interact. Calling every turn uniformly faster or slower would be misleading. The speed curve and handoff should be corrected together rather than independently tuning the stop threshold.

## Behaviors that matched in the checked cases

- Initial landing-contact horizontal speed matched for the controlled +150 and +101.25 px/s descents.
- Low-speed ground reversal from +37.5 px/s immediately accelerated left in both games; first samples matched.
- Skid jumping while already facing left but still moving right at +75 px/s matched the first horizontal velocity samples and reversed sign on step 17 in both traces.
- Pressing Jump on the airborne tick that ends in floor contact did not jump in either game. Holding that press through landing did not automatically jump either. Both require a fresh press once the grounded state is available. Do not add jump buffering or automatic held re-jumping as a presumed fidelity fix.
- An immediate fresh press on the first grounded tick was accepted in both games.
- A held jump from rest was close: normalized feet apex Y=148 in the NES and Y≈148.300 in Godot. The project keeps continuous fractional positions and a small floor-contact margin; this difference alone does not establish incorrect gravity.

## Evidence and fixture boundaries

[Reference CSV](reference/movement-audit-nes.csv) and [project CSV](reference/movement-audit-godot.csv) contain 11 cases × 48 frame samples per engine. Cases cover walk/run reversals, landing reversals, immediate/delayed re-jumps, jumping out of an established skid, low-speed reversal, landing-contact press/hold, and held jumping from rest.

The reference uses the existing isolated Mesen runner and ROM documented in the Super movement investigation. Each case seeds size/status, position, state, velocity, facing/moving direction, friction fraction, run history, and jump flags in RAM. Original routines then execute with the prescribed controller inputs; ROM bytes are unchanged. This is controlled emulator evidence, not a natural uninterrupted playthrough. The grounded rest fixture uses the original ground at the initial 1-1 screen.

The Godot diagnostic uses a flat test-level floor, explicit Small form, disabled automatic controller/player stepping, and exactly one manual player physics call per scheduled physics callback. It warms up collision registration and clears stale floor flags before airborne cases. Run history is seeded consistently for each case. No diagnostic changes were applied to tracked gameplay or regression code.

CSV X/Y positions use a common sprite-left/feet convention: Godot body X minus 8; NES stored Y plus 32 for Small Mario. NES X/Y are integer observations. VX reconstructs the signed speed and friction fraction, converted at 60 ticks/s. Reference vy_integer_only excludes the vertical fractional byte and must not be directly compared to Godot's continuous post-step velocity. Jump-profile findings use source table selection and actual first-step displacement instead. A diagnostic friction-byte decoding error and initial fixture collision-registration issue were corrected before archiving the final evidence.

Frame alignment is based on corresponding prescribed input/landing states, not matching wall-clock seconds or an assumption of identical fractional integration. Comparisons here cover flat ground without enemies, slopes, moving platforms, or pipe presentation. Super crouch/growth/shrink and analog/opposing simultaneous horizontal inputs were not newly traced. No new rendered animation comparison was performed.

## Existing regression results

Eight focused scenes passed without engine errors or warnings: movement_handoff_test, held_run_landing_test, slide_test, slide_collision_test, run_release_test, jump_test, falling_gravity_test, and down_direction_test. This verifies existing contracts, including single integration across handoffs and keyboard/controller held-Run behavior; it does not certify reference parity for the newly identified turn/re-jump combinations. No full regression suite was run.

## Recommended order — not implemented

1. Correct ground-reversal friction/facing order, with explicit first-turn-tick samples.
2. Correct low-speed skid reset plus same-tick reverse acceleration, preserving exactly one movement integration.
3. Lock down the landing → one turn tick → re-jump threshold reproduction for tap and hold, in both directions and forms, before adjusting jump constants.
4. Repeat rendered play comparisons after those ordering fixes. Keep jump input semantics reference-based; modern buffering, coyote time, and other enhancements were not requested.


## Phase 1 — reversal ordering implemented, 2026-11-08

The user authorized two phases. Phase 1 corrects grounded reversal ordering and skid completion together; phase 2 remains pending for dedicated landing/re-jump profile verification and regression coverage.

Slide no longer changes facing in enter(). Each ground tick supplies its previous facing to SlideAction, so friction is selected from the old facing/movement relation before the new direction is displayed. The first turn tick receives the undoubled rate, followed by doubled braking while facing opposes momentum. Slide's selected friction also retains running history.

SlideAction now tests its low-speed threshold before braking. A qualifying low-speed tick resets momentum and applies direction acceleration immediately; it returns to Move after that one movement integration. It no longer forces an extra zero-speed tick after braking crosses the threshold. Neutral completion still stops, and collision-stopped skids retain their existing next-tick handoff. No jump constants, gravity, input bindings, or scene settings changed.

Verification: slide_test, slide_collision_test, movement_handoff_test, and run_release_test passed without engine errors or warnings. Unit assertions cover previous-facing friction and same-tick low-speed reset/acceleration; the neutral Slide-to-Idle fixture now starts below the reset threshold instead of expecting post-braking reset. The existing 44 handoff cases still integrate once. Replayed the original temporary audit and archived the [phase-1 project CSV](reference/movement-phase1-godot.csv), preserving the original baseline. All 48 VX samples for each of walk_reverse, run_reverse, and landing_reverse match the stored NES trace within 0.000001 px/s of CSV rounding; first-negative ticks are 13, 20, and 20 respectively. The delayed landing/turn/re-jump's first three VX samples also match, but dedicated takeoff-profile qualification belongs to phase 2.

No full regression suite or rendered interactive movement comparison was performed. Mesen was not rerun in this phase; comparisons use the audit's preserved reference data. The passing temporary replay is bounded evidence, not complete left/right/form parity certification.


## Phase 2 — landing/re-jump qualification completed, 2026-11-08

Phase 1's ordering changes restore the previously wrong jump-profile selection; no further production movement changes or jump/gravity tuning were needed in phase 2. Added landing_rejump_test, a scene using the existing body-integration probe, and a compact Mesen-derived golden JSON fixture.

A fresh [Mesen script](reference/landing-rejump-reference.lua) and [960-sample CSV](reference/landing-rejump-reference.csv) cover 20 scenarios: Small/Super × right-to-left/left-to-right × five input sequences. The sequences are a fast immediate re-jump, threshold-speed reversal followed by a delayed tap, the same delayed jump held 20 ticks, a press on landing contact, and holding that early press through contact. Each case records 48 frames. The fixture seeds an airborne descent onto flat ground, clears enemy slots, and supplies flat block-buffer terrain so renderer/parser history cannot introduce unrelated obstacles. ROM bytes are unchanged. Early attempts that retained parser terrain history produced spurious late collisions; the final trace uses the explicit flat court and validates expected takeoff eligibility before generating golden data.

The regression begins airborne and asserts that the first simulated step lands. It checks the first four horizontal velocity samples (80 values across the matrix, tolerance 0.00001 px/s), exact takeoff tick and initial speed, no duplicate jumps, exactly one body integration for each of 960 simulated ticks, and apex within 1.1 pixels of the integer reference sample. The tolerance accounts for the project's continuous fractional positions and floor-contact margin; it does not permit the former ~13-pixel deficit. JumpAction.jumped captures initial velocity before gravity prepares the following frame, avoiding invalid comparison against the reference's integer-only post-step velocity field.

All twelve re-jump cases select -300 px/s: immediate jumps take off on step 2, delayed jumps on step 3. The threshold-speed delayed fixture retains +95.683594 px/s before takeoff in the right-to-left reference case, safely above 93.75. Held-jump apex is around the reference Y=133 instead of the former project Y≈145.659. Contact-frame press and held-through-contact cases do not jump in either direction/form; no buffering or held auto-repeat was introduced.

Verification: landing_rejump_test, movement_handoff_test, held_run_landing_test, jump_test, and falling_gravity_test passed without engine errors or warnings. The new fixture was rerun after adding explicit airborne/contact assertions. A test-edit indentation error was corrected before the successful rerun. Formatter and diff checks passed. No full suite, exported build, or rendered interactive movement comparison was performed. Current coverage qualifies the flat-ground Small/Super cases above, not all terrain, analog inputs, or future forms. The original audit and phase-1 traces remain preserved.
