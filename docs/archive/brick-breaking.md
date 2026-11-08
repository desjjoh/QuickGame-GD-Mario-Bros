# Ordinary brick breaking — first pass

## 2026-11-08 — steps 1–2

Ordinary and alternate bricks select bounce for Small Mario and break for Mario forms whose can_break_bricks capability is true. Crouching does not disable this capability. Reward bricks inherit QuestionBlock instead of the ordinary-brick active state, so they dispense rewards; used blocks retain solid collision and reject additional hits.

BrickActiveState selects Broken for a capable Mario bonk and sets the block's optional bonk_velocity_y to -120 px/s (-2 pixels per 60Hz tick). Broken immediately clears the body's collision layer, hides the entity, and queues deletion. The terminal state rejects further hits; deferred deletion allows BaseBlock's existing BlockImpact delivery to finish safely. Both brick appearances inherit this behavior. persist_progress remains false, so existing area reload generation recreates ordinary bricks.

BonkAction captures the optional response only from an accepted hit and resets it before each delivery attempt. BasePlayer applies it during the ordinary short-body ceiling path; MarioTerrain preserves it during standing head contacts instead of overwriting it with bounce zero or solid +60. No player/FSM state is added. The block owns its reaction; the player owns applying the movement result. NAN retains the existing ordinary response. Shatter does not snap position or alter horizontal momentum; the removed block cannot continue blocking a side probe on the same step.

Verification: brick_break_test covers both forms, standing/crouched requests, both ordinary brick appearances, question/reward/alternate-reward blocks, used-block protection, immediate collision/visibility removal, rejected duplicate hits, deferred deletion, and the shared response preserving X and -120 Y. canvas_terrain_test now checks the actual break response under both canvas hierarchies; ordinary solid trajectory tests use an inactive question block so they do not reuse a freed brick.

Eight distinct focused scenes passed in their final runs without engine errors/warnings: brick_break_test, block_test, bonk_contact_test, canvas_terrain_test, super_mario_corner_test, super_mario_movement_test, reward_brick_test, koopa_block_bump_test. The first canvas run failed an obsolete assertion expecting a broken block to stop X; that assertion was updated to reflect immediate collision removal. Formatter/whitespace checks passed. No full suite, new Mesen capture, or interactive playtest was performed.

Deferred: four-fragment artwork/trajectories, shatter cue, 50 points without a popup, coin-above handling, and shatter-specific victim/reference edge cases. The existing shared bonk cue is still used in this first pass. Existing BlockImpact continues to deliver its current block_bump interaction; no new shatter-specific outcome is claimed. Assets/settings/imports were not changed.


## Follow-up — shatter continuation differs from the reference

The user reported extra ascent catching the adjacent brick. Compared seeded original-game shatters in Mesen (isolated brick and three-brick row, both directions) with the current CanvasLayer Godot row. Captures are reference/break-continuation-reference.lua/.csv and reference/break-continuation-godot.gd/.tscn/.csv. Godot initializes the jump origin to the equivalent established jump so bonk release selects falling gravity.

Mesen sets speed -2 on the break frame (feet Y171 in this fixture), moves up two pixels on the next tick to Y169, then reports speed +1. The broken cell contains temporary metatile $23 on the break frame and is replaced with $00 by the end of the next frame. The collision routines can still encounter the temporary solid marker during that interval. Both single-brick and row cases retain horizontal speed through these first continuation frames.

Godot currently removes the body immediately and lets normal gravity integrate -120. Captured feet Y171 →169 →167.5625 →166.6875 →166.375. The side probe then reaches the next brick, stopping X on tick 6 from the left and tick 5 from the right. This reproduces the reported extra-ascent/neighbor-stop interaction. The initial -2 speed is present in the NES, but applying it as unconstrained continuation was incomplete fidelity. The user's visual impression of a near-normal bump is consistent with the reference's rapid reversal rather than a prolonged rise.

Proposed next correction: preserve the break response together with the transient broken-cell collision/next-tick reversal, with collision evaluated in the same order. Do not suppress adjacent-brick side collision or introduce broad collision immunity. Precise implementation remains to be agreed; no production changes were made in this follow-up.

These are seeded-state fixtures, not input-only recordings or a pixel comparison. The reference updater's temporary-cell timing is part of the observed behavior; it should not be reduced to a universal timed immunity window. A temporary Godot diagnostic initially tried to free its already auto-freed brick on the next case and caused a native crash; guarded the diagnostic lifetime before preserving successful results. Final Mesen/Godot captures completed successfully without reported errors/warnings. No regression suite was run for this investigation.


## Implemented correction — one-contact-tick collision marker

At the user's request, Broken now hides the brick immediately but retains its solid body through the next player contact pass. It records the break's physics tick, runs terminal-state retirement at physics priority 1000 (after normal player motion), and removes the body/deletes the entity after the following contact pass. This supersedes immediate collision removal described in steps 1–2. Broken still rejects all reward/hit attempts. The ordinary head path sees the temporary solid cell and reverses the -120 impulse to +60 on the next tick; no special immunity to neighboring blocks or forced position snap is added. The terminal state remains gameplay-paused with its owning block.

Added brick_neighbor_test with a three-brick row, both approach directions, default-canvas and CanvasLayer hierarchies. It verifies break-frame -120 speed and invisible solid marker, exactly one two-pixel upward step to feet Y169, next-tick +60 reversal, continued X movement, untouched neighbors, and marker retirement. Updated direct brick tests to expect temporary solidity and wait for physics retirement; canvas side checks again expect the still-solid marker to handle deep corner contact.

Five focused scenes passed without engine errors/warnings: brick_neighbor_test, brick_break_test, canvas_terrain_test, super_mario_corner_test, koopa_block_bump_test. The neighbor scene passed again after expansion to both canvas hierarchies; a test-local scope error introduced during that expansion was corrected before the final passing run. Formatter/whitespace checks passed. No full suite or interactive playtest was performed. Existing archived Mesen traces provide the reference sequence; exact variable VRAM update delays beyond the one-contact-tick case are not emulated.


## Full-jump investigation — prior marker verification was too narrow

The user reported continued neighbor catches after the marker change. Replaced the isolated near-apex seed with grounded jump initiation and held movement/Jump across 20 starting-position/direction cases, 48 frames each, in Mesen and Godot. Preserved break-full-jump-reference.lua/.csv and break-full-jump-godot.gd/.tscn/.csv. These still seed a flat court and initial grounded state, but jump force/profile selection and the complete approach run through normal movement instead of injecting a postulated hit-frame speed. No production changes in this follow-up.

The discrepancy is reproduced. Example rightward case 4: NES break feet Y168, following feet Y167 then Y168 with horizontal travel continuing. Godot break feet Y168.565216, next Y166.565216 then Y167.565216; the latter tick stops X on the adjacent solid. The old feet-Y172 fixture happened to keep side probes below neighboring tiles and could not establish general parity.

Two missing reference behaviors are now clear:

1. NES BrickShatter changes Player_Y_Speed's integer byte to -2 without clearing Player_Y_MoveForce or Player_YMF_Dummy. The fractional vertical state survives. A full-jump continuation therefore need not rise exactly two pixels; these traces rise only one integer screen pixel on the next step. Godot replaces the complete float velocity with -120, losing the original fractional component. Its floating Y coordinate and point sampling also differ from the reference's integer-coordinate samples.
2. The reference BlockBounceTimer suppresses another interactive head reaction for 16 ticks and routes contact through NYSpd instead. Godot has no equivalent cross-block gate: case 3 breaks the next brick on the following frame and reapplies -120, whereas Mesen reverses to +1. Keeping a marker for one tick does not prevent this second launch.

The reference also can stop horizontal speed in some leftward/seam cases; universal uninterrupted X is not a valid golden expectation. The screenshot's secondary AI summary is consistent with a rapid visible bonk but is not a replacement for these primary routine/frame results.

Proposed next correction: retain the integer/fraction distinction in shatter response, sample reference probes using their intended coordinate convention, and honor the block-bounce reaction gate so another block cannot immediately relaunch Mario. Replace the handpicked neighbor assertions with full-jump regression cases drawn from the captures. Do not add neighboring-block immunity or continue adjusting marker lifetime from a single seed. No full suite or screenshot-matched interactive playthrough was performed; both capture runners completed successfully without reported errors/warnings.


## Superseding behavior — no ascent after breaking, 16-tick reaction gate

The user clarified that “no -1 allowance” meant no upward movement after the break, not removal of a numerical test tolerance. Implemented that explicit gameplay choice, and the user subsequently confirmed the proper in-game feel. BrickActiveState now selects zero vertical speed; Broken removes collision, hides, and queues deletion immediately. Removed the temporary marker tick/priority machinery. This supersedes both the -120 continuation and marker-retirement decisions above. The isolated NES integer speed write is not claimed to explain the complete visible interaction; the remaining reference discrepancy is unresolved and must not be assigned to another cause without evidence.

BonkAction now gates accepted interactive block reactions for 16 physics ticks, starting from the accepted hit. It decrements once per running physics tick, resets the captured response for each delivery, and rejects further interactive reactions while the gate is active. Hidden-block delivery uses the same gate. The gate blocks reward/break reactions, not normal solid collision. It belongs to the active player's BonkAction, separate from block bounce animation and the global animation clock. Fractional continuation code is retained for optional negative responses but ordinary brick breaking no longer requests one; zero remains exactly zero. Follow-up solid reversal during an active reaction gate preserves its fractional component.

Replaced the handpicked neighbor regression with full grounded jumps: 20 starting-position/direction cases × 48 ticks, using archived Mesen data for break frame and break/no-break outcomes. Assertions require no ascent after breaking, no second reaction during the 16-tick gate, exact tick-based gate expiry, and no immediate neighbor catch when Mario retained approach speed. The tests intentionally do not assert NES post-break height equality or use a one-pixel allowance: no-ascent is the explicitly chosen behavior. Existing canvas fixtures cover both hierarchies. Independent teleported scenarios reset the gate so one fixture's accepted hit does not suppress the next scenario.

The capture file break-full-jump-godot.csv was regenerated during the fractional-response investigation before the final no-ascent decision; it is not a final no-ascent capture. The previous diagnostic sequence remains described above. tests/fixtures/brick_full_jump_reference.json preserves the original-game event data used by the new regression.

Final verification: six distinct focused scenes passed in their final runs without engine errors/warnings: brick_neighbor_test, brick_break_test, canvas_terrain_test, bonk_contact_test, super_mario_movement_test, super_mario_corner_test. Fixed stale-gate fixture isolation and a temporary indentation error before final passing reruns. No full suite was run. User performed the in-game feel check; no new agent-controlled rendered playthrough was performed after the no-ascent change.


## Normal-play reference trace completed

A controller-only boot-to-mushroom-to-brick run now establishes the actual write/update order for a normal straight-up break: the -2 integer speed is used once with retained fractions, producing one extra upward pixel, then a +1 reversal before the temporary cell is removed. This supersedes the statement that the ordinary encounter write sequence was unresolved. Current no-ascent project behavior remains unchanged. See [normal brick-break trace](normal-brick-break-trace.md) for CPU-write addresses, frames, visual captures, and scope limits.


## Running/seam reference coverage added

The input-only extension records 21 routes (14 shatters), including exact and near seams. Thirteen shatters rise one extra pixel and reverse next frame, leftward side contacts can legitimately stop X, and one row-edge escape rises five pixels because the head leaves the broken cell. Thus neither universal next-frame reversal nor universal preserved X is reference-correct. No project code changed. See [running/seam trace](normal-brick-break-trace.md) and reference/running-brick-summary.csv.


## Superseding implementation — reference shatter response using byte arithmetic

The user explicitly requested using the new VerticalMovement component to restore the recorded Mesen behavior. This supersedes the previous zero-ascent project choice. Ordinary/alternate bricks again select integer Y speed -2, but BonkAction composes that byte through VerticalMovement.speed_with_integer, retaining the exact speed fraction. Position fraction is not cleared. Standing solid rejection/reversal uses integer +1 with the fraction retained. The 16-tick interactive-reaction gate remains active.

Broken hides immediately and retains its solid collision through the following player contact pass. It then removes collision/queues deletion at physics priority 1000. Normal head/side collision determines the result, not an unconditional next-frame reversal: a head still sampling the temporary cell reverses to +1, while one beyond the row can escape and keep ascending. Pause retains the marker until physics resumes. This is a single-contact-pass replacement model; arbitrary original VRAM queue congestion is not emulated.

An additional missing behavior was found by exact fraction checks: a negative shatter impulse must not force JumpAction's release/falling-gravity selection. BasePlayer now retains the existing held/released jump selection for negative responses. In the normal capture, fraction192 advances by rising force32 to224 before reversal; forcing release would have used112 and produced the wrong speed fraction even when the first position happened to match.

### Verification

- vertical_jump_reference_test now compares the natural stationary Super jump through break and four following frames: feet185,184,186,188,191, with exact integer speed and both fractions. No pixel tolerance.
- brick_seam_reference_test uses 14 controller-only running/seam shatter captures and compares 13 frames each (182 frames): exact logical Y, integer speed, speed fraction and position fraction, including the five-pixel row-edge escape. It replays observed horizontal sample positions to isolate the real vertical/terrain interaction; it does not verify an independent horizontal integrator. Physical floor support uses Godot safe margin, so only on-floor Y is converted to its logical rounded pixel. Airborne comparisons are exact.
- brick_neighbor_test retains 20 full grounded-jump scenarios from the earlier controlled reference court, requiring exact break events and first three post-hit integer Y/speed results. It now checks reference-specific horizontal retention/stopping rather than the obsolete universal no-ascent/no-stop assertions. This is supporting coverage; those older fixture captures are not input-only stage runs.
- brick_break_test verifies both ordinary appearances, form capability/crouch selection, reward/used protection, one accepted hit, marker lifetime including pause, and cleanup. canvas_terrain_test verifies the response under both canvas hierarchies.

Nine distinct focused scenes passed in final runs without engine errors/warnings: brick_break_test, brick_neighbor_test, brick_seam_reference_test, vertical_fraction_test, vertical_jump_reference_test, canvas_terrain_test, super_mario_corner_test, super_mario_movement_test, bonk_contact_test. Initial runs exposed obsolete no-ascent assertions, a new-test bool inference error, floor safe-margin versus logical Y, and an insufficiently wide fixture floor; corrected those before final passing reruns. Formatter/whitespace checks passed. No full suite, new Mesen capture, or agent-controlled interactive playtest was performed. Debris, shatter audio, 50 points, and coin-above work remain deferred; the existing shared bonk cue remains in this first pass. Crouched trajectory parity is not claimed without its own capture.

## 2026-11-08 — Debris, shatter cue, and direct score

Broken entry now awards exactly 50 points through GameHandler.add_score and creates no score popup. It creates an area-owned BrickDebris sibling before hiding the brick; the temporary collision marker and reference player response are unchanged. The terminal state rejects duplicate hits. Debris is presentation only, with no physics body or spawn-cap slot, and follows area unload and tree pause naturally.

The Palette 1 atlas contains four flipped 8×8 fragment copies at (80,32) through (88,40). The effect selects (88,32,8,8), resolves the atlas through AreaTheme, and renders four copies. Two integer/fraction trajectories begin at Y offsets 0/8 with speeds -6/-4 pixels per tick, force $50/256, and cap 8. Horizontal speed is one pixel outward per tick; mirrored right sprites begin at offset 7, following DrawBrickChunks' carry-based projection. Global clock bits 2/3 flip the fragments. Arithmetic is local to this non-colliding presentation rather than borrowing the player's CharacterBody movement adapter. The effect frees once the upper pair falls below the visible bottom plus eight pixels; this camera-relative cleanup intentionally replaces the NES fixed $f0 screen threshold. A 60Hz accumulator keeps trajectory timing stable if physics tick duration differs.

SoundHandler registers brick_shatter from ContinueBrickShatter: 32 frames, writes on odd remaining counts, reversed BrickShatterFreqData/BrickShatterEnvData tables, and long-mode 15-bit noise feedback. The first frame has no noise write. BrickDebris owns a regular AudioStreamPlayer so deleting the brick cannot cut the cue short; gain remains 0 dB and pitch scale 1. Mario's existing bonk pulse remains separate, as the reference queues its head-hit pulse and shatter noise on separate channels. This is register-derived synthesis, not a new Mesen waveform capture or an auditory fidelity certification.

Verification: brick_debris_test checks four fragments, all three theme atlases, sound duration/routing/default gain/pitch, initial trajectories, tree pause, and eventual cleanup. brick_break_test checks exactly 50 added on each capable ordinary/alternate brick break and no duplicate award. The effect has only its four sprites and sound child, with no popup. Five focused scenes passed without engine errors or warnings: brick_debris_test, brick_break_test, brick_neighbor_test, brick_seam_reference_test, sound_mix_test. The existing full-jump and seam assertions stayed unchanged. No full suite, new Mesen capture, rendered playtest, or listening comparison was performed. No project/import settings changed. Coin-above handling and shatter-specific victim outcomes remain deferred.

### Follow-up — reported sound pitch and editor warning

The user reported that the first shatter cue sounded far off pitch and that brick_debris.gd emitted INTEGER_DIVISION in the editor. Replaced the sprite pair division with an explicit bit shift. The headless runner had not exposed that editor warning; its earlier clean logs did not certify editor diagnostics or audible fidelity.

Recorded a fresh input-only, read-only Mesen run with noise/pulse register writes in reference/brick-audio-input.lua and brick-audio-registers.csv. The noise table proceeds $0c/$06/$0d/$08/$0d/$03/$09/$0a/$0f/$0c/$06/$0b/$0d/$0e/$0e/$01 at alternating sound-engine updates. The final $15/$01 write is immediately followed by $f0 mute; the initial renderer incorrectly sounded that final frame. Music also writes the shared noise channel between effect updates, so this mixed-game trace is not an isolated waveform reference. The normal post-break contact queues the separate bump pulse.

The original renderer point-sampled a fast LFSR at 44.1kHz, allowing high-frequency components to alias into the audible range. Mesen instead routes timestamped channel deltas through blip_buf (https://github.com/SourMesen/Mesen2/blob/master/Core/NES/NesSoundMixer.cpp). Corrected our cue generation with 8x oversampling and a normalized 129-tap windowed-sinc anti-alias filter before returning to 44.1kHz; retained the hardware period table, envelope values, default playback gain, and pitch scale. This is a rendering correction, not an arbitrary pitch adjustment. It is a plausible contributor to the reported brightness; without a listening comparison it is not established as the complete cause. This filter is not claimed to reproduce Mesen's exact mixer, channel sharing, or LFSR phase.

The added signal check verifies that a 32kHz component does not fold into an audible 12.1kHz alias while constant input retains unity gain. Final brick_debris_test and sound_mix_test runs passed without engine errors/warnings; brick_break_test also passed after the renderer update. A listening comparison remains outstanding.
