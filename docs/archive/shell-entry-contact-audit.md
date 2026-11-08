# Shell contact during enemy entry

## Investigation and correction — 2026-11-08

The user reported a moving shell passing through a Goomba pair while it enters at the right screen edge. Twelve temporary physical-overlap checks with existing enemies around either edge and 25 newly spawned pair-overlap phases all defeated the target. Those checks did not reproduce the natural encounter failure.

A separate confirmed flaw existed in koopa_shell_moving_state.gd: _on_enemy_contact recorded the target in _touching before receive_hit returned. A rejected attempt therefore suppressed all later attempts until separation, even when the target became hittable during the same overlap.

A new real-physics shell_spawn_contact_test creates a pair at the right edge, temporarily suspends the first Goomba, and releases it while the shell remains overlapping. Before the correction it failed: the first rejected attempt was latched and the shell passed through. After the correction only accepted reactions latch, allowing subsequent physics overlap polling to retry a rejected target. Accepted surviving reactions still latch once, and defeated targets do not grant duplicate chain rewards.

The forced suspension is an explicit fixture for the rejection path, not proof that a naturally entering Goomba becomes suspended. The precise cause of the user's natural encounter remains unconfirmed until reproduced or verified in play. No activation, height, cleanup, collision geometry, or immunity rules changed.

Verification: shell_spawn_contact_test, shell_interaction_test, enemy_boundary_test, and nested_entity_activity_test passed without engine errors or warnings. The new check asserts rejection does not latch, release permits defeat, and the first chain reward is exactly 500 with no duplicate award. No full regression suite or interactive visual playtest was performed.
