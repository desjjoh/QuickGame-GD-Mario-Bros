# Growth and injury animation comparison

Original investigation: 2026-11-08. Its correction is now implemented; see the implementation section below. The user requested comparison of running/jumping mushroom pickups and injury, then selected **Match Mesen's movement poses**, superseding the earlier requested growth idle holds for the forthcoming correction.

## Capture method

[Mesen script](reference/transformation-comparison.lua) runs four controlled fixtures in the original NTSC ROM: growth while running, growth while jumping, injury while running, and injury while jumping. RAM positions, initial velocities, forms, and one live item/enemy are prepared at fixture frame 340. The original mushroom/Goomba collision handlers accept collection/injury; neither transformation routine nor its timer is forced. Right/Run remain held, with Jump also held in the airborne cases. These are controlled collision encounters, not input-only stage playthroughs. ROM bytes were unchanged.

The [Godot capture scene](reference/transformation-godot-comparison.tscn) creates an isolated sandbox instance with explicit Small/Super start, clears its entity/enemy markers, and creates a live Super Mushroom/Goomba. Normal Mario movement, animation processing, pickup signals, and enemy contact polling run. Capture samples occur at physics priority 1000, after the actor/presentation/AnimationPlayer callbacks. Input variables are held to corresponding Right/Run/Jump values. The scene writes the actual selected sprite texture into a common 16×32 canvas and logs its state/visibility; these are CPU sprite captures, not desktop/GPU screenshots of the complete Godot viewport.

Godot clock starts are aligned separately for item and enemy contact so the transformation master timers and four-tick global phases can be compared. The seeded jump trajectories do not constitute a complete jump-physics equivalence test: both engines execute their own physics before accepting contact. Compare pose/state/hold transitions against timer/clock, rather than interpreting different initial world positions or speeds as artwork errors.

Mesen's eight-bit frame counter wraps during these captures. The builder unwraps it. Screenshot buffering was calibrated using frames 350–356: the Intermediate graphic first appeared in the PNG two capture events after its graphics offset changed in RAM. The comparison therefore uses screenshot frame + 2 for each RAM sample. NES OAM Y draws at Y + 1; crop origins include that pixel. Omitting either adjustment gives misleading timing/artwork differences.

Full logs are preserved for each case:

| Case | Mesen | Godot |
| --- | --- | --- |
| Running growth | [CSV](reference/transformation-mesen-growth_run.csv) | [CSV](reference/transformation-godot-growth_run.csv) |
| Jumping growth | [CSV](reference/transformation-mesen-growth_jump.csv) | [CSV](reference/transformation-godot-growth_jump.csv) |
| Running injury | [CSV](reference/transformation-mesen-damage_run.csv) | [CSV](reference/transformation-godot-damage_run.csv) |
| Jumping injury | [CSV](reference/transformation-mesen-damage_jump.csv) | [CSV](reference/transformation-godot-damage_jump.csv) |

Raw screenshots and generated contact sheets remain ignored under `.godot/validation/`. [Build helper](reference/build-transformation-comparison.ps1) produces `growth-comparison.png` and `damage-comparison.png`, with Mesen above Godot for each running/jumping case. Individual screenshots show the actual Mesen framebuffer, including background and score effects; Godot rows show isolated sprites.

## Confirmed growth behavior

Both moving fixtures collect on Mesen frame 341, clock 218, master timer `$ff`. Collection sets Player_State to grounded (0), including the airborne pickup, without discarding its upward velocity. Normal Small walking graphics appear during the initial hold because horizontal momentum remains. In this fixture the graphics offset changes from walk frame 0 to 1, then holds while ordinary animation timers are suspended.

At `$f8`, size changes and the ten-entry flicker control starts. Its source sequence is **Small idle, Intermediate, Small idle, Intermediate, Small idle, Intermediate, Super idle, Small idle, Intermediate, Super idle**. It advances on global frame counter modulo four, so the initial entry's duration depends on phase. On the cycle-ending update the control resets to zero and draws **Small idle once more**. This closing draw is part of the original routine, not another four-tick entry.

The next update uses normal Super walking graphics (frame 0 in these captures) while movement remains frozen. `$c4` completes the routine; ordinary control runs on the following engine frame. The airborne fixture then switches to Falling (2), retains its upward velocity, and uses ground/falling artwork rather than restoring the original held-jump presentation. Vertical movement resumes after the ground-to-falling handoff.

Current Godot differences:

- The initial Small idle hold was an explicit earlier user request; moving Mesen uses walking frames here. The latest user choice replaces that policy with reference movement poses.
- The middle three-artwork flicker sequence matches at aligned four-tick phases.
- At clock 264 / `$d1`, Godot goes straight to Super idle; Mesen renders the final Small-idle closing draw.
- The final Super idle hold was also explicitly requested earlier; Mesen uses its normal walking pose for these moving fixtures.
- Godot unlocks movement on the same physics tick that the countdown reaches `$c4`; Mesen runs ordinary control on the next engine frame.
- Airborne Godot restores Jump, unlike the original grounded/falling handoff. Preserving the old movement-state identity was an implementation limitation, not a verified reference behavior.

## Confirmed injury behavior

Both injury fixtures accept contact on Mesen frame 341 / clock 218. `ForceInjury` immediately sets Player_State to jumping (1), starts InjuryTimer at 8, requests the shared pipe/injury cue, and starts routine 10 at `$ff`. Its opening graphic is therefore **Super jump**, even for ground/running injury. Alternating-frame injury visibility begins immediately.

That Super jump pose is held until the `$f0` size-change point, about 15 engine ticks later. The change-size flag/profile may switch on a hidden frame; only visible graphics should be compared. The shrink cycle then alternates the first Small and Super swimming poses. On the final cycle update it draws Small swim once more before returning to ordinary artwork/control. In these captures this is clock 272 / `$c9`; `$c8` completes the routine on the following update, and ordinary movement starts at clock 274. Protection/flashing continue after routine completion.

Current Godot differences:

- Running injury preserves Super walk instead of selecting Super jump during the opening hold. Airborne injury happens to start with Super jump because Jump was already active.
- The visible middle swimming-pose cycle matches at aligned phases, and uses the correct supplied frames.
- Godot restores ordinary Small artwork on the cycle-ending draw, skipping the reference's last Small swim.
- Godot also releases actor movement at that cycle boundary, two ticks earlier than normal movement in the measured reference fixtures. Earlier notes calling this an intentional reference-matched shrink tail were overconfident and are superseded by this collision-driven comparison.

## Artwork check

Six relevant assets were compared pixel-by-pixel against corresponding Mesen sprite crops: Small idle, Intermediate, Super idle, Super jump, Small swim frame 1, and Super swim frame 1. All six had **zero geometry/color-index differences** after normalizing the three foreground palette classes and transparency. The supplied skin RGB differs slightly from Mesen's displayed palette; this audit does not claim exact RGB equality or change palette/import settings. The Intermediate sprite's blank top eight rows and full 16×32 canvas are correct. Replacing the supplied artwork is not the indicated fix.

## Correction plan

Use Mario's existing presentation owner for explicit entry, flicker, closing-draw, and handoff phases. Keep the existing actor and artwork. Growth should choose its reference standing/walking entry art from movement/animation history, freeze ordinary animation timers with the master pause, retain the final Small-idle draw, and use the normal Super standing/walking pose afterward. Injury should explicitly own Super jump at entry, retain its final Small-swim draw, and hold motion until the reference handoff. Release ordinary movement on the proper following tick; integrate airborne growth with the existing ground/falling route while preserving momentum.

Do not approximate the prelude by hardcoding one walk frame for every encounter: the source retains PlayerAnimCtrl/PlayerAnimTimer history until InitChangeSize. Add live running/jumping tests that compare timer/phase boundaries against these captured reference rows, including the final closing draw and first movement tick. Existing tests demonstrated that our selected pose contract ran; they did not establish complete NES entry/exit fidelity.

Verification in this investigation: all four Mesen captures exited successfully; all four Godot captures completed 66 samples without script/engine errors or warnings; frame-buffer calibration, visual contact sheets, six normalized artwork comparisons, and source labels were inspected. No gameplay code, settings, or artwork changes were made by this audit. No full regression suite was run.


## Implemented correction — 2026-11-08

MarioFormPresentation now explicitly owns entry, flicker, closing draw, and handoff. Growth selects standing/walking/skidding prelude artwork from movement and retained walk phase/timer history; InitChangeSize resets the walk control. Injury immediately selects Super jump, then keeps it until the size-change threshold. Both sequences retain their final control-zero draw (Small idle for growth, Small swim for injury). Completion selects ordinary control for the following physics tick instead of releasing movement in the selecting tick. Shrink phases that finish their flicker earlier may resume on the next eligible player-control tick, preserving any resumed animation phase through routine completion.

Airborne growth reuses MarioMoveState for the ground/falling handoff, retains body velocity, and defers the first vertical integration. The original body, camera target, and state-machine instance remain. Existing local injury protection advances on the first ordinary-control tick; the old extra release-tick suppression was removed because release itself is now delayed correctly. Sounds, collision-profile thresholds, pause rules, and project settings are unchanged.

The Small and Super walk sheets are cyclically ordered source frames **1, 2, 0**. The presentation converts between authored and reference indices without reordering the normal walking resources or changing their cadence. Direct comparisons of all three frames in each sheet confirmed this mapping.

The CPU capture helper also required an atlas correction: AtlasTexture.get_image() returned the backing atlas, so the helper must crop its selected region. Earlier contact sheets could therefore show the first atlas column for walking textures. They did not invalidate the directly checked six standalone/swimming shapes, but they were insufficient proof of the selected walking frame. The helper now crops the actual region before saving the sprite. The synthetic Godot fixture also seeds walk history/position to the counterpart ROM fixture, rather than comparing unrelated initial walk phases.

Verification: growth_handoff_test compares **180 visible pose/state boundary samples** directly against the preserved Mesen CSVs. The corrected live capture comparison checks **174/174 visible sprite shapes** through the four recorded transformation pauses, with zero differences after foreground palette normalization. [Verifier](reference/verify-transformation-frames.ps1) regenerates this check after captures; [saved results](reference/transformation-fixed-pixel-results.csv) preserve all comparisons. Corrected Godot traces are saved separately from the original failing evidence:

- [Running growth](reference/transformation-godot-fixed-growth_run.csv)
- [Jumping growth](reference/transformation-godot-fixed-growth_jump.csv)
- [Running injury](reference/transformation-godot-fixed-damage_run.csv)
- [Jumping injury](reference/transformation-godot-fixed-damage_jump.csv)

Focused growth_handoff_test, mario_form_presentation_test, mario_damage_test, super_mushroom_test, falling_animation_test, falling_gravity_test, pause_test, and death_test passed without engine errors or warnings. The final cancellation/animation-phase adjustment was followed by another clean run of the three directly affected presentation/damage scenes. The full suite was not run. These results qualify the captured pose/hold/release cases, not complete NES movement/physics or desktop-renderer parity across all scenarios.
