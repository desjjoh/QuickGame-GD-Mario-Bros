# Flagpole ending presentation plan

Status: reference investigation retained from 2026-11-05. The presentation foundation, scroll lock, descent/dismount/walk, endpoint cleanup and audio are now implemented; score/firework effects remain deferred behind no-op completion hooks. See [current implementation](flagpole-ending.md) for ownership, configuration and explicit timing limits. Proposed milestones below record the original plan.

## Ownership and agreed differences

Flagpole contact reports the player and contact height. BaseLevel accepts a single ending transaction and owns common lifecycle cleanup. A reusable level-owned flagpole presentation coordinates camera locking, scripted player motion, flag movement, score/time presentation and final stage progression. The flagpole exposes signals/visual movement capability; it does not own stage progression. Castles remain independently painted decorations so level authors can create small/large/custom variants. A future castle ending presentation uses the same level lifecycle with different choreography.

Two requested differences from the NES are intentional: use an authored endpoint rather than a hidden stopping brick, and shut down/remove the player at the entrance instead of changing background priority. The endpoint must be a reference on the presentation configuration, independent of castle art. Preserve GameHandler-owned player status when removing its scene object.

## Reference findings

Source: [SMB disassembly](https://gist.github.com/1wErt3r/4048722). Routine names below are the verification anchors; screen-space constants must be translated to our feet/body-origin convention and pole placement rather than copied into world coordinates.

1. FlagpoleCollision sets facing right and ScrollLock, clears horizontal momentum through PutPlayerOnVine, records contact Y for height-based scoring, queues flagpole audio and selects FlagpoleSlide. RunGameTimer skips this engine phase, so ordinary countdown stops. Scrolling already ran before background collision on the contact tick; preserve legitimate approach movement while excluding attachment snap from camera displacement.
2. FlagpoleSlide supplies Down automatically until player Y reaches $9e. Climb_Y_SpeedData/$ff and Climb_Y_MForceData/$ff produce nominal +1+$ff/256 pixels/tick. FlagpoleRoutine moves the flag by the corresponding fractional amount. Mario and the flag do not share a single duration.
3. FlagpoleRoutine advances out of descent when flag Y >= $aa OR player Y >= $a2. Mario's normal stop is $9e, allowing the flag to continue. Do not replace this with an unconditional wait-for-both rule. Height score is then awarded: 5000/2000/800/400/100, using FlagpoleYPosData and score tables. For the usual reference geometry, Mario's visible feet stop around two pixels above the solid base top; verify the exact pose/origin conversion during implementation.
4. PlayerEndLevel forces Right. ClimbingSub first moves him across the shaft, uses the $18 side timer, then moves him outward so collision stops reasserting climbing and falling/ground walking takes over. Preserve this short dismount hold rather than immediately switching to normal walking or adding a jump impulse.
5. During automatic walking, PlayerEndLevel starts EndOfLevelMusic and clears ScrollLock when player Y reaches $ae. The camera is not necessarily locked for the entire celebration. This condition is relative to reference geometry, not a universal world Y.
6. CastleObject contains PlayerStop, which inserts metatile $52 into MetatileBuffer+10 to stop the player. PlayerEndLevel detects blocked rightward movement, starts StarFlagTaskControl and sets sprite background priority. Replace those two mechanisms with reaching the configured endpoint and ordinary player lifecycle removal.
7. RunStarFlagObj records fireworks eligibility from the final TIME digit (1, 3 or 6), then AwardGameTimerPoints subtracts one TIME unit and adds 50 points per update until zero. Timer sound requests follow the reference frame-bit cadence. Next the castle star flag rises, optional fireworks award 500 each, and DelayToAreaEnd waits for its interval timer and event music to finish before stage progression. These later rewards/visuals/audio are still planned, not available.

## Implementation boundaries

Split accepting completion from its final stage replacement. Current BaseLevel.on_complete requires a valid player and immediately starts a transition; simply calling it after removing Mario would fail. Accept and retain level/Game ownership first, run the presentation, then finish that accepted transaction without requiring a surviving player. Reuse existing destination selection, stage progression, transitions, progress cleanup and stale-owner checks rather than creating a second progression path. Warp completion bypasses this presentation and keeps its destination intro.

The runtime camera lock is level/presentation-owned, separate from authored Follow Enabled. While locked, keep screen-edge policy intentional and tracking history current; release without accumulated catch-up. Player scripted states/components continue updating while controller intent and ordinary timer/death/transport requests are gated. Do not pause the entire FSM needed by the sequence.

At the endpoint, stop and shut down Mario, clear matching BaseLevel.player/GameHandler.current_player references, then queue_free. The presentation, its audio and time/score sequence remain level-owned and continue after removal. Cancellation, level replacement or shutdown must release owned resources safely and prevent a stale sequence from loading a stage.

## Suggested milestones

1. Completion claim/finish lifecycle plus camera lock ownership and cancellation tests.
2. Reference pole/flag descent and timed dismount, stopping at a test phase boundary without progression.
3. Scripted walk to an independently assigned endpoint, followed by player shutdown/removal.
4. Reference score/time/fanfare/castle-flag/firework phases as assets and scope are approved, then finish via existing stage progression.

Validate timing in physics ticks and rendered captures, including contact at multiple heights, small/large castle geometry, camera freedom before the pole, once-only contact, cleanup after player removal and no catch-up scroll. Do not claim exact presentation parity until the choreography and conversions have been implemented and compared.
