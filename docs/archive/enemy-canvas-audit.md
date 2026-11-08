# Enemy collision canvas audit

## 2026-11-08

Investigated whether the terrain point-query CanvasLayer failure also affects enemy hurtboxes and interactions. No equivalent defect was reproduced, and no production behavior changed.

BaseEnemy checks PlayerContact.overlaps_area(player.enemy_hurtbox), with its established contact latch and every-other-tick gate. EnemyContact emits area_entered, and moving shells poll get_overlapping_areas for persistent overlaps. Terrain movement uses character-body collision. None of these paths use PhysicsPointQueryParameters2D or its default canvas filter. BlockImpact uses intersect_shape against BlockHitReceiver areas, rather than the problematic point query.

Added enemy_canvas_test: default-canvas and CanvasLayer fixtures each exercise Goomba and Green Koopa. It verifies real Area2D overlap with Super Mario's hurtbox and the actual block.receive_hit → BlockImpact shape query → BlockHitReceiver path. Expected outcomes are Goomba defeat and Koopa ShellStunned. All four cases pass without engine errors/warnings. Actors are stationary for this isolated check; the test is not an entire movement encounter.

Existing koopa_contact_test and shell_interaction_test inherit silent_game.tscn, which inherits the actual CanvasLayer-root Game scene. Both pass, covering real contact-driven stomps/damage and shell-to-enemy overlap, including one-time scoring. enemy_contract_test, mario_damage_test, and stomp_chain_test also pass; some of these inject hits directly, so they are supporting behavior checks rather than independent proof of every spatial detection path.

koopa_block_bump_test failed before its final real-query section: at line 62, its local enemy reference had already been freed during an earlier moving/stunned sequence. That run emitted two ObjectDB-instance exit leaks. The cause of that lifetime failure was not established in this audit; it must not be reported as a clean suite pass or silently bypassed. The isolated new test verifies the query path that the failed scene did not reach. No full suite or interactive playtest was performed.


## Follow-up — block-bump fixture lifetime failure resolved

Instrumented the failing sequence without changing cleanup. The fixture disables Mario processing, then teleports him from X24 to X240 to reverse the block-hit direction. The camera continues following that target independently and advances to X320. Its visible left edge becomes X192; the enemy cleanup boundary for its anchor is therefore X119. At physics frame 38 in the controlled trace, the block-stunned Koopa reaches Body (126,195.4414); its floor(X-8) anchor is 118. enemy_outside_cleanup returns true and the area queues it for removal before its landing. The test then dereferences a legitimately freed enemy.

Corrected only the fixture: disable camera following before scripted player placement. The actor still receives real movement/physics, pause, landing, repeated bumps, waking, and final block-shape-query checks; production cleanup boundaries are unchanged. koopa_block_bump_test and enemy_canvas_test both pass without engine errors/warnings after this change. The prior ObjectDB warnings did not recur in these reruns; this does not establish a broader shutdown fix.
