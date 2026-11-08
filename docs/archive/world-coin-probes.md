# Form-aware world-coin collection

Implemented 2026-11-08, following the user's request to use reference coin probes and revert the unrelated pipe-floor changes.

## Actual defect and ownership

In the actual 1-1 secret room, standing Super Mario had is_crouched=false, a 12×24 enemy hurtbox, and a head probe at −28. The coin's Area2D nevertheless listened only for the 11×14 terrain-support CharacterBody2D, so upper-body coins were missed. The pipe/posture fixes did not address this interaction. The earlier profile-only passing tests were not proof of correct coin collection.

MarioTerrain now checks world coins through head, left/right feet, and upper/lower side points after Mario's normal move. Standing Super uses the tall offsets; Small and crouched Super use the short offsets already defined by the terrain profile. This uses the disassembly's PlayerBGCollision coin-check approach rather than expanding the support body or borrowing the enemy hurtbox. Point checks operate even when Mario is stationary or not moving upward. They return after the first successful collection, with at most one probe pass per physics tick.

`WorldCoin.collect(player)` keeps the existing Active/Collected state transition, GameHandler reward, collected signal, and captured progress. It rejects repeat, dead, suspended, or shutdown contacts. Mario also skips coin probing when his body collision mask is zero during transport. Consumed coins remove their query layer through a deferred update; the immediate state guard prevents duplicate rewards before that update.

Only the coin Area2D participates in these area-only point queries. Its existing layer 1 category is queried with bodies excluded. The query explicitly targets Mario's current CanvasLayer, or canvas zero for standalone scenes. The real Game's CanvasLayer mattered: the first actual-level test correctly failed until this context was supplied. No new project collision-layer name/setting was introduced.

Scene properties changed within the requested coin work:

| Coin/Pickup property | Previous | Current |
| --- | --- | --- |
| collision_layer | 0 | 1 while Active, 0 when Collected |
| collision_mask | 1 | 0 |
| monitoring | true while Active (previous runtime behavior / scene engine default) | false |
| monitorable | false | false |

These are scene properties, not project settings or import options. Point queries do not require the area to monitor bodies. The support body, enemy hurtbox profiles, crouch input rules, audio gain/pitch, and pipe travel rules are unchanged by this implementation.

## Cleanup of the incorrect diagnosis

Removed MarioTerrain.has_floor_support, its KinematicCollision2D probe, and the two Mario crouch/input callers. The previously removed arrival-floor refresh flag remains absent. Removed the provisional held-Down/source-floor assertions and grown-start option added to pipe_transfer_test, plus the extra profile-only assertions added to sideways_pipe_test during that diagnosis. Existing pipe regression coverage remains.

Retained explicit form selection in the Super movement fixture because that test must not inherit the user's editable sandbox default. Kept earlier investigation entries as history and marked the actual coin diagnosis/correction separately. The artificially held-Down arrival fixture was a separate scenario; this coin change does not claim to requalify every crouch/transport edge case.

## Verification

`secret_coin_collection_test` uses the actual Game and authored 1-1, grows Mario, and positions him on its enabled secret pipe at cell (57,9). It presses Down to enter and releases it during travel, then follows the actual transport into LowerArea. At the original missed coin_6_7 it samples normal movement/probes with the support body outside the coin, verifies collection through Super's head, checks one reward per update, and keeps the 12×24 hurtbox. Positioning at the pipe and target coin is controlled setup; this is not an input-only stage playthrough. The test does not replace the level or destination with a fixture and does not edit authored placements.

`coin_probe_test` covers 17 head/upper-side/lower-side/left-foot/right-foot contacts across Small, standing Super, and crouched Super; upper coins missed by short profiles; head-before-feet priority and exactly-once awards; suspended/dead/transport guards; consumed-state restoration; and the 100-coin extra life with the existing 200-point coin reward.

Focused coin_probe_test, secret_coin_collection_test, area_theme_test, death_test, super_mario_movement_test, pipe_transfer_test, and animation_clock_test passed without engine errors or warnings across the relevant runs. The theme/death fixtures explicitly step movement/probing after positioning their frozen player; their original score, life, theme, and persistence expectations remain. An initial theme-test failure exposed its old body-event-only setup, which was updated before its clean rerun. The final four directly affected scenes passed together after cleanup. The full regression suite and rendered manual playthrough were not run.

This implements the existing land-profile probe locations and contact priority. It does not claim full equivalence for all NES vertical-screen guards, swimming, tile-obstruction ordering, or all movement/coin arrangements.
