# Mario growth and shrinking presentations

Current fidelity status: the [collision-driven audit](transformation-animation-audit.md) now has an implemented correction. Growth and injury entry/flicker/closing poses match all 174 visible sprite captures in its four running/jumping fixtures after palette normalization; see the audit's correction section for timing, regression evidence, and limits.

Implemented 2026-11-07: phases 1–2 of the [reference plan](growth-damage-bricks-research.md). Mario owns these presentations, as requested by the user during implementation. This replaces the earlier proposal for a level-owned sequence coordinator; level ownership remains limited to world/lifecycle coordination.

## Ownership and use

`Mario.grow()` requests Small → Super; `Mario.shrink()` requests Super → Small. Both return whether the request was accepted. `FormPresentation.finished` fires on normal completion, not cancellation. Repeated requests and incompatible forms are rejected. [Super damage](super-mario-damage.md) invokes shrinking and provides continuing injury protection/flashing and sound; [Super Mushroom](super-mushroom.md) invokes growth for a Small collector.

The `FormPresentation` child owns the sequence timer, pose index, visibility, and restoration. The existing `Form` child still configures artwork, animation mappings, and enemy-contact profiles. The same actor, body, camera target, and state-machine instance survive. Growth hands airborne control to the existing Move/falling state while retaining momentum. Session status changes on acceptance; the live collision form changes at the reference timer threshold. Cancellation settles the accepted target form, restores visibility/presentation, and releases only the suspensions this sequence acquired.

The sequence sets `BaseLevel.player_presentation`, making level physics return before reward timers, transport/camera updates, fall checks, and level timer advancement. Other entities use `set_gameplay_suspended`, preserving previously suspended entities and allowing cosmetic animation. The presentation itself remains an ordinary pausable Mario child. It does not pause SceneTree, audio, or the global animation clock. The existing pause controller and separate pause sound remain responsible for user pause.

Death cancels the transformation before LevelDeath acquires world suspension. Area loading/arrival, accepted level-ending handoff, and shutdown cancel it too. This prevents a late transformation release from undoing death's suspension. Scene teardown uses synchronous cancellation rather than an outstanding timer coroutine.

## Timing and artwork

The countdown begins at `$ff`. Growth changes the live profile at `$f8` and finishes at `$c4`; shrinking changes at `$f0` and finishes at `$c8`. The global animation clock's low two bits advance the ten-entry pose control on every fourth tick. Shrinking visibility alternates with the global clock. When initiated by damage, the independent Damage child continues protection flashing after the presentation finishes.

Growth uses Small idle, the supplied intermediate, and Super idle in the source sequence. Shrinking alternates the first Small and first Super swimming frames. Both sheets were inspected and compared with Mesen screenshots at fixture frames 481 and 485, using the existing routine-entry trace; these correspond to the source's `$88` Small and `$28` Super graphics offsets. Small has five 16×16 frames; Super has six 16×32 frames. Remaining frames are not consumed by this feature. Every selected texture uses its form's sprite offset, retaining the common bottom anchor at body Y + 1.

The sequence retains its closing draw on the cycle-ending update. Injury returns normal actor control on the next eligible player-control tick; `$c8` itself selects ordinary control for the following tick. Growth likewise resumes normal control on the tick after `$c4`, with standing/walking prelude and tail poses selected from reference walk history. The existing Move/falling state handles airborne growth, deferring its first vertical integration to preserve the reference ground-to-falling handoff. No headroom restriction or replacement player scene was added.

The implementation reuses the existing state machine and routes airborne growth into its Move/falling state. The collision-driven captures qualify entry/pose/closing and release timing for the four recorded fixtures; they do not establish every ceiling, input-speed, palette, or full-stage trajectory case. The original routine-entry trace remains historical evidence; the later collision comparison and source-backed regression are the current verification.

## Preview and verification

Open `tests/mario_form_preview.tscn` and press F6. It creates an isolated sandbox instance, clears painted entity/enemy markers in that instance, disables its timer, and cycles growth/shrinking with a one-second hold between sequences. It does not edit the sandbox scene or add controls. Start uses the existing pause binding.

`mario_form_presentation_test` checks both directions across all four clock phases, delayed live profile switches, pose textures/feet alignment, actor/state identity, frozen actor motion, retained velocity, higher-level suspension restoration, shrinking-tail movement, actual SceneTree pause, area-arrival cancellation, death handoff, and shutdown. Focused `mario_form_presentation_test`, `mario_form_test`, `super_mario_movement_test`, `pause_test`, `death_test`, `pipe_transfer_test`, and `flagpole_ending_test` passed without engine errors or warnings. The full suite was not run. A headless preview smoke check cannot replace the user's rendered visual review.

Affected paths: `scripts/player/mario_form_presentation.gd`, existing Mario form/controller/resources and scene, `scenes/levels/base/base_level.gd`, and the focused test/preview scenes. No project settings, Input Map bindings, import options, or audio gain/pitch were changed.

## 2026-11-08 airborne pickup audit — confirmed mismatch

After the user reported awkward airborne growth and normal poses continuing, a new [Mesen fixture](reference/airborne-growth-trace.lua) placed an airborne Small Mario and a live mushroom in RAM. Unlike the earlier routine-entry fixture, collection itself ran through the original collision handler. No ROM bytes were changed. [Selected rows](reference/airborne-growth-mesen.csv) record the original result: frame 341 accepted collection, set player state 0, and retained upward velocity −3; position stayed (41,117) through frame 400. The growth cycle ended on 387 with one final Small graphic; frame 388 used the normal Super walking graphic, not jumping. Control resumed on 401, terrain processing changed state to Falling (2), and upward movement continued from 402 with the retained velocity. Ground/falling posture after collection is distinct from continuing a held jump.

A live Godot physics diagnostic sampled after ordinary physics/animation callbacks with a playing walk clip and an airborne Jump state. All 37 sampled middle-cycle poses matched the growth table; none were overwritten in this reproduction. However, ticks 44–58 explicitly displayed Super's normal jump pose while the transformation pause remained active. `_restore_actor_presentation()` restores the current movement state's presentation as soon as the pose cycle ends. Normal Jump is also retained across collection, unlike the original status/state handoff. The manual-step regression did not expose the final-render/handoff mismatch, and its state-preservation assertion encoded this limitation.

The intermediate asset is 16×32 with opaque rows 8–31, consistent with the source's blank top row and 24-pixel intermediate artwork; no anchor change was established by this investigation. Exact pixel artwork parity was not requalified.

Proposed correction, not implemented by this audit: make growth's pre/post-cycle artwork follow the reference standing/walking presentation rather than the old jumping state; retain its final-cycle Small graphic for the correct tick; hand control back through the existing ground/falling movement route while preserving velocity. Do not create a replacement player or a duplicate movement state. Discuss this movement handoff with the user before changing it, and add live-frame grounded/airborne checks rather than asserting only immediately after manual presentation updates. This audit changed documentation/diagnostic fixtures only; the gameplay fix and rendered visual comparison remain pending.


## 2026-11-08 growth idle hold correction

At the user's explicit request, growth now retains Super idle after its pose cycle and throughout the remaining control pause. The normal Move/Jump presentation resumes only when control is released at `$c4`. Shrinking's earlier motion/art handoff remains unchanged. This replaces the early `_restore_actor_presentation()` call for growth; it does not change the countdown, movement state, stored velocity, or injury protection. The broader NES airborne movement-state handoff identified by the audit above remains a separate, unimplemented correction. Holding idle here is the user's requested presentation policy; the Mesen fixture with horizontal momentum showed walking artwork during this tail instead.

Focused growth_handoff_test, mario_form_presentation_test, and super_mushroom_test passed without engine errors or warnings. The new test observes live physics/AnimationPlayer frames for both running and jumping states, verifies the idle hold while controls remain suspended, and checks normal art restoration at completion. No full suite or project settings changes.

## 2026-11-08 growth Small-idle entry correction

The prior correction covered the final hold only. Growth entry still retained the collector's Move/Jump art during the seven-tick delay before the profile switch. At the user's request, growth now claims Small idle immediately on acceptance and pauses normal animation playback. It pauses playback again after form configuration, which may otherwise restore a movement clip. The source-derived middle pose table is unchanged: it uses only Small idle, intermediate, and Super idle. The final Super idle hold remains in place until control returns. No shrink timing or movement handoff changed.

The live-frame growth regression now runs ordinary Mario physics and checks the immediate Small idle, normal animation remaining paused, all three intended textures appearing during the sequence, and the final idle hold for both running and jumping collectors. growth_handoff_test, mario_form_presentation_test, and super_mushroom_test passed without engine errors or warnings. This checks runtime texture ownership through physics/animation processing; a rendered manual review remains useful.
