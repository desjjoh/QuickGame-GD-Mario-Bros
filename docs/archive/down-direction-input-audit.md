# Down plus direction input audit

## Findings — 2026-11-08

Investigation only; no gameplay implementation changed.

The reference PlayerCtrlRoutine splits raw controller bits into horizontal and vertical inputs. When Down and any horizontal direction are held in grounded Player_State 0, it clears both filtered fields. This runs before the size check and therefore applies to Small and Super Mario. PlayerMovementSubs then clears Super crouching on the ground because the filtered Down bit is zero. Airborne Super retains the previous crouch flag and directional control remains available.

GetPlayerAnimSpeed separately reads raw SavedJoypadBits. This matters at low speed: Down alone selects the stop path, but Down plus the current movement direction does not. Even though the filtered horizontal controls are neutral, Mario can coast with ordinary neutral friction. An opposite raw direction can select the low-speed stop path. Jump remains available because A/B bits are not cleared by the directional filter.

## Current implementation

Mario.get_movement_axis filters grounded Down plus direction only when current_form.can_crouch is true. Small therefore still walks under this combination, unlike the reference. Super's ground crouch selection already requires Down without Left/Right, and airborne posture is retained.

PlayerState.prepare_horizontal_motion passes raw Down as RunAction.prepare_ground_profile's stop_input_held. For a grounded Super moving right at 30 px/s with Down+Right, the axis is neutral but this raw flag clears velocity immediately. The reference continues coasting when raw direction agrees with movement. The existing low-speed Down-only stop should be preserved in any later correction.

Vertical pipe entry explicitly rejects horizontal holds, consistent with the filtered Down being cleared in the reference. Sideways pipe entry uses raw Right in our current implementation; this audit did not qualify its combined-direction behavior. Opposing-direction keyboard inputs and analog thresholds were not qualified.

## Evidence and limits

Reference: [SMB disassembly](https://gist.github.com/1wErt3r/4048722), PlayerCtrlRoutine, PlayerMovementSubs, OnGroundStateSub, GetPlayerAnimSpeed, and ImposeFriction.

A new Mesen run used the existing isolated local runner and reference ROM described in [Super movement](super-mario-movement.md). The [Lua fixture](reference/down-direction.lua) injects size, state, location, and initial speed into RAM, then supplies inputs while original routines execute. It does not modify ROM bytes. The [CSV](reference/down-direction.csv) captures six fixtures. Grounded Small/Super Down+Right both produce filtered horizontal/vertical bits 0, crouch 0, and continuing positive speed. Down-only produces the low-speed stop; only Super crouches. Airborne standing/crouched Super fixtures retain their respective posture while accelerating right. Horizontal input RAM may be consumed by later routines before end-frame logging; speed and source control flow establish air steering.

A temporary Godot audit used the existing Super movement fixture with grounded velocity 30 px/s and Down+Right. Small returned axis (1,1), retaining speed through profile preparation. Super returned (0,0) and profile preparation set speed to 0. The diagnostic completed without engine errors or warnings. This was a bounded mechanical audit, not full trajectory, visual, or controller parity certification.

## Proposed correction — not implemented

Apply grounded directional cancellation to both forms. Keep raw controller state intact, but make the low-speed stop decision respect raw direction relative to movement, rather than treating every Down hold as Down alone. Keep crouch persistence, airborne steering, and jump availability intact. Add focused cases for both directions, both forms, momentum, jump takeoff, and crouch release before calling the correction matched.


## Correction implemented — 2026-11-08

This section supersedes the implementation gaps and proposed status above. Mario now cancels grounded Down plus horizontal direction in both forms. PlayerState supplies raw horizontal direction alongside filtered movement to RunAction. The low-speed neutral stop path still accepts Down/B-only and opposing-direction holds, but preserves coasting when raw direction agrees with motion. No input bindings or project settings changed.

Added down_direction_test for both forms and directions, stationary holds, neutral friction with and without Run, opposite-direction stopping, Down-only stopping, crouch release, jump takeoff, and airborne steering. Seven focused scenes passed without engine errors or warnings: down_direction_test, held_run_landing_test, pipe_transfer_test, run_release_test, super_mario_movement_test, question_block_test, and bonk_contact_test. The first Super movement run failed at its hidden-block assertion, exposing a missed collider-parent lookup from the entity-grouping cleanup. BonkAction now finds the owning BaseBlock through ancestor groups; the affected rerun passed. No new Mesen run was needed for this correction; it uses the preceding audit's trace and source evidence. No manual controller playtest or full regression suite was run.
