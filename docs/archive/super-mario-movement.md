# Super Mario movement and posture

Date: 2026-11-07. Implements standing upper-body terrain contact, crouching/crouch jumps, and form-aware transport/presentation integration. Growth, shrinking/damage, and brick breaking remain outside this pass.

## Collision ownership

Grounded crouching retains normal friction at higher speeds. Holding Down also requests the reference low-speed stop below 41.25 px/s, as holding Run already did; fully released input continues coasting. This corrects the extra low-speed slide without changing friction constants or airborne crouch behavior. The movement regression checks both travel directions, released-input coasting, low-speed crouch stopping, and momentum above the cutoff. Focused `super_mario_movement_test`, `run_release_test`, and `slide_test` passed without engine errors or warnings after the correction.

The user requested the approach closer to the NES after discussion of Godot overlap recovery. Mario keeps the existing 11x14 terrain body at (-0.5,-7) as floor/lower-side support. MarioTerrain supplies the standing center head at (0,-28), feet offsets (-5,0)/(4,0), and side samples (-6,-24), (-6,-8), (5,-24), (5,-8), relative to Body feet. Short posture uses head (0,-14) and lower side samples at Y=-8. Feet and short-body movement retain the existing Godot sweeps and corner/landing assistance; the constants document the reference probes rather than claiming the support body is an exact NES terrain rectangle.

A rising Super head ray checks above the short support body, clamps upward movement at contact, delivers a block hit, and uses BasePlayer's shared ceiling motion/audio response. BonkAction now asks the player for its head position, so hidden underside crossings also use the selected profile. Existing Small behavior is preserved through default BasePlayer hooks. Side queries check left before right, upper before lower; a solid sample applies one pixel away when stationary or moving into that side, then stops that update's side checks. Samples use a tiny positive coordinate epsilon so exact tile boundaries belong to the next tile. Sideways-pipe upper samples are skipped as in the reference. No full-height shape expansion or safe-fit gate is used on uncrouch.

This remains a hybrid with Godot's existing lower-body movement, not a replacement NES physics emulator. All original screen-coordinate/metatile special cases and exact subpixel collision sampling are not newly reproduced here. Existing shallow-landing assistance remains unchanged. This distinction matters for untested geometry and extreme motion.

## Posture, input, art, and contact

MarioFormController owns is_crouched independently of movement state. A grounded controllable Super samples Down with no horizontal buttons. Grounded Down+Left/Right clears effective directional input and crouch, matching PlayerCtrlRoutine. Momentum is reduced through the existing friction/run profile; entering crouch does not zero velocity or add crawling. The shared Jump state handles both standing and crouch jumps. Releasing Down in the air preserves crouch; new Down input during an ordinary jump does not create crouch. Landing allows sampling again on the next player update.

Standing uses the existing Super 12x24 contact box at (0,-12), crouching 12x12 at (0,-6). Body/feet position and Sprite2D offset are unchanged by posture. Idle/ground movement/jump/vertical pipe entry can use crouch artwork. Passive walk-off Move presentation follows the reference walk-pose path rather than automatically assigning a crouch-jump pose. Climb, scripted ending movement, and horizontal pipe travel clear crouch. Growth art remains configured data only. Super jumping now selects jump_big: PlayBigJump's frequency offset $18 resolves to divider $17c; Small uses offset $26/divider $fe. The same 3/5/32-tick envelope/control/sweep stages are reused. Playback stays non-positional at default gain/pitch; no listening-parity claim is made.

## Pipes, climbing, endings, and area initialization

The existing pipe state still owns travel, draw order, masking and duration. Its form-specific idle/walk textures come from the existing form library. Vertical entry preserves crouch through entry; side entry uses standing/walk art. Hidden depth uses the supplied frame canvas, so Super's full-height canvas remains potentially visible at depths where Small's is already hidden. Terrain covers its actually opaque pixels normally.

Mesen confirmed crouch is cleared during area initialization. BaseLevel._commit_area_arrival now calls the generic BasePlayer.on_area_arrival hook after stopping the old state; Mario clears transient posture and keeps its current form. The same actor, body, camera target, and form resources survive the trip. This is an area lifecycle hook, not a pipe-owned form replacement.

Climbing broad-phase bounds now come from a player hook rather than assuming the support body's height. Standing Super exposes both upper/lower reference side heights to FlagpoleEntity, while crouched/Small use the lower height. Existing capture_probe_offset_y remains the lower anchor. Climb poses use the selected form's two texture frames. The existing level-owned flagpole/castle movement remains its owner; scripted movement and death retain the correct selected-form or Small death artwork respectively. Full Super damage remains unimplemented.

## Mesen runtime evidence

Used Mesen 2.1.1 from the user's emulator installation and Super Mario Bros. (JU) [!].nes from their ROM archive. ROM SHA256: f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de. Mesen's database selected Famicom/NTSC, mapper 0. The sandbox could not run from the installed directory, so the executable/dependencies and ROM were copied into ignored .godot/validation. The installed emulator configuration and original ROM/archive were not modified. The temporary runner enabled Lua IO only for local trace/screenshot output; testRunner disables saving settings. No ROM/binary is included in source control.

The [trace script](reference/super-mario-trace.lua) and [selected CSV](reference/super-mario-mesen.csv) retain the non-ROM evidence. This is controlled emulator execution, not an unmodified-input-only playthrough: frame 340 writes Super size/status to RAM, frames 430/500/550 create in-RAM collision fixtures, frame 620 replaces two foot metatiles to trigger vertical entry, and frame 900 repositions the player past the underground brick platform. ROM bytes are unchanged. Subsequent movement/crouch, collision, and transport routines execute in the original game. Screenshots/full traces remain ignored diagnostics; an underground screenshot was visually inspected.

Observed frame-end samples:

| Scenario | Mesen result |
| --- | --- |
| Crouch jump | Frame 356 enters Jump with crouch=4/box=2; releasing Down retains the crouch flag throughout the airborne portion |
| Grounded Down+Right | Frames 381 onward have crouch=0/standing box with no directional movement |
| Right overhead obstruction | Frames 436-441 move NES X 56 to 50, one pixel left per update, with standing posture immediately active |
| Left overhead obstruction | Frames 506-511 move NES X 40 to 46, one pixel right per update |
| Enclosed overhead fixture | Frames 556-577 move NES X 56 to 78, left-side-first resolution |
| Vertical entry | Frame 621 starts routine 3 with crouch=4 and big size |
| Area initialization | Crouch clears by frame 670; the underground arrival uses standing big box |
| Underground side entry | Frame 924 enters routine 2 upright |
| Upward return | Frame 1110 begins emergence upright at NES Y=240; frame 1206 restores routine 8 at Y=144, retaining big size |

Godot tests recreate the three overhead fixtures using the +8 X/+32 Y coordinate conversion and verify the same final body X positions 58,54,86, as well as an immediate one-pixel uncrouch correction. These observations qualify the tested cases only. Every brick/pipe corner, both movement directions/speeds, airborne overlap, graphical occlusion pixel, and wall-jump geometry has not been exhaustively matched. Growth/shrink cases are intentionally deferred.

To rerun the script, provide a local ROM and an isolated Mesen runner with Lua IO enabled, set QUICKGAME_REFERENCE_OUTPUT to a writable diagnostic directory, and run Mesen.exe --testRunner --timeout=10 <ROM> <script>. The script exits after 1240 frames. Its title Start timing and selected CSV frame numbers are specific to this tested ROM/runtime. Do not add the ROM or temporary runner to Git.

## Focused verification

Super movement/posture: super_mario_movement_test covers actual crouch jump/release/landing, contact profiles, feet anchoring, retained momentum, grounded input filtering, run speed/art, one-pixel and three Mesen-comparable push-out fixtures, high regular/hidden bonks, short crouched ceiling clearance, and reference-derived jump cue selection. mario_form_test continues to cover identity, texture mappings, clip isolation, and death pose.

Existing pipe_entry, pipe_transfer, sideways_pipe, climbing, and flagpole_ending tests accept -- --super to run the same behavior assertions with Super. Climb checks now use configured frame resources rather than Small-only filename assumptions. Pipe transfer includes crouched entry, upright arrival, retained form/actor, and form-aware visibility depth. Existing Small variants and movement, jump, bonk_contact, corner_correction, climb_capture, death, pause, and sound_mix checks reached PASS during this pass. bonk_contact's measured Small hidden sweeps explicitly select Small instead of inheriting the sandbox's Super preview.

ObjectDB exit warnings remain across several runs; they are not treated as clean shutdowns. No full regression suite was run. No manual controller playthrough or full visual/pixel/audio parity qualification was performed. Mesen evidence above is a bounded RAM/input trace and should not be represented as complete fidelity certification. No project settings, Input Map bindings, import options, or audio gain/pitch settings changed.

## 2026-11-08 pipe-arrival posture cache correction

A reproduced Super pipe-transfer failure occurred after arrival had already cleared crouching: CharacterBody2D.is_on_floor still cached the source pipe's contact. If Down remained held, Mario's first ordinary movement tick sampled that old floor and started a new crouch at the airborne destination. The intended airborne crouch persistence then retained the short terrain probes and 12×12 contact profile.

Mario now marks floor contact as needing refresh on area arrival. Crouch sampling and grounded Down+horizontal filtering wait until the first ordinary movement update has refreshed the destination collisions. Pipe animation itself does not consume the refresh, and subsequent real grounded input continues to behave normally. This preserves the existing arrival-upright contract rather than changing crouch-jump rules. The 11×14 support body remains unchanged; standing Super uses its upper terrain probes and 12×24 enemy-contact profile.

The expanded pipe-transfer regression failed before the fix with Down held on the first post-arrival physics update. It now checks retained Super form, standing 12×24 contact shape, and the standing head probe after held-Down arrival and release. Focused checks passed for starting Super, growing into Super before transfer, and sideways entry/upward emergence. Small transfer also passed. The Super movement regression initially inherited the sandbox's current Small start; its fixture now explicitly selects Super, and its rerun passed. All successful checks completed without engine errors or warnings. No settings or input bindings changed.

## 2026-11-08 arrival-floor refresh removal

At the user's request, removed Mario's arrival-floor refresh flag, its first-movement crouch guard, and its grounded-axis filtering guard. Arrival still cancels a form presentation, reapplies injury visibility, and explicitly clears crouching. No replacement refresh mechanism was added.

Verification after removal: the held-Down Super transfer regression fails at its first post-arrival crouch assertion (pipe_transfer_test -- --super); the assertion remains intact. The failed scene exits on its frame limit and reports ObjectDB instances at that premature exit. Ordinary Small pipe transfer and the Super movement regression are checked separately. This supersedes the implementation described in the preceding correction entry; the held-Down arrival issue remains unresolved in this configuration.

## 2026-11-08 current floor support for crouch input

The arrival-specific refresh flag remains removed. The reproduced failure was a false crouch transition, not selection of a crouched profile while is_crouched was false: arrival cleared the flag, then held Down plus the source pipe's cached is_on_floor set it true again. Profile selection remains solely based on is_crouched.

MarioTerrain.has_floor_support now validates the cached grounded status with a short, non-moving downward test at the current body transform and a floor-normal check. Mario uses it only for grounded crouch input and Down+horizontal filtering. It does not choose contact-box sizes, move the player, resize the support body, clear a valid airborne crouch, or add an arrival timer/flag. Pipe arrival still explicitly clears posture through the existing form controller.

The pipe regression demonstrates both facts at the destination: cached is_on_floor is still true, while the current support query is false. Holding Down then leaves is_crouched false, the hurtbox at 12×24, and the standing head probe at −28. Focused starting-Super and grown-Super vertical transfers, Super sideways/upward travel, ordinary Small transfer, and Super movement passed without engine errors or warnings. The full suite was not run. This replaces the unresolved removal configuration described above; no project settings or input bindings changed.

## 2026-11-08 actual 1-1 secret-room coin diagnosis

The user clarified the persistent symptom was collecting coins in 1-1's secret room. The preceding posture fixes and tests did not verify that collision path and did not establish this reported issue was fixed. Do not describe their passing fixtures as proof of correct Super coin collection.

A [diagnostic using the actual Game/1-1 scene](reference/secret-coin-audit.tscn) grows Mario, positions him on the real enabled secret entrance at cell (57,9), presses the actual Down action, and follows real pipe travel into LowerArea. This is a controlled setup, not an input-only playthrough from the level start. It does not replace the level or destination with a test fixture. After arrival the trace reports is_crouched=false, enemy hurtbox 12×24, and head offset (0,−28).

The diagnostic then isolates upper-body contact with the actual generated coin_6_7 at global (992,352), positioning Mario's feet at (1000,384) and holding movement still. The coin intersects standing Super's upper profile, while Pickup.overlaps_body reports false because coin.gd listens to the 11×14 terrain-support CharacterBody2D. The target coin remains uncollected; a different lower coin collects, matching the reported apparent short collection profile. Moving Mario four pixels upward puts the support body into the target and collects it. Throughout, is_crouched remains false and the enemy hurtbox stays 12×24. No gameplay changes were made during this diagnosis.

The source's PlayerBGCollision calls CheckForCoinMTiles from head, both feet, and side-probe checks, choosing Super/short probe tables according to size and crouch. Our world-coin body_entered path does not use those form-aware probes. The indicated correction is coin-contact handling; changing crouch flags or the standing enemy hurtbox alone cannot fix it. Implementation of the coin-contact correction is pending. The current floor-support query addresses the separate cached-floor fixture but is not a fix for this clarified coin symptom.

## 2026-11-08 coin correction and rollback completed

The actual reported secret-room coin defect is corrected by [world-coin terrain probes](world-coin-probes.md). The speculative has_floor_support query/crouch callers and provisional cached-floor pipe tests were removed, with no replacement arrival flag. Previous passing posture fixtures are retained here only as historical observations, not evidence that the reported coin interaction had been fixed. The current coin implementation and actual-level regression are the relevant verification.
