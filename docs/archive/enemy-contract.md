# Enemy hit and contact ownership

## Hits and permanent defeat

BaseEnemy.receive_hit(hit) returns whether the enemy accepted an interaction. It rejects null hits, shutdown/queued/defeated actors, gameplay/activity suspension, and nested requests during an existing hit response. It then delegates to the concrete enemy's _accept_hit(hit). Acceptance alone neither sets the defeated flag nor emits defeated.

An accepted hit may change state, consume health in a future enemy, or perform another nonterminal reaction. When the enemy chooses permanent defeat, it calls mark_defeated(hit). This sets the flag before emitting defeated(hit), rejects repeat notifications, and prevents ordinary later hits. A concrete enemy may opt into a post-defeat physical reaction without clearing the flag; squashed Goomba accepts a shell knock-out this way. Null/shutdown/queued requests cannot mark defeat. This method does not award points, free the entity, or choose artwork. Those remain concrete enemy/state responsibilities.

Goomba requires a successful transition into Squashed or KnockedOut, then explicitly marks defeat. Its existing stomp and block-bump scoring and popup path remain. Unsupported maneuvers are rejected. Squashed Goombas retain the existing partial enemy-contact behavior until removal; knocked-out Goombas do not block walkers. Mario's rebound and the every-other-tick contact checks are unchanged.

## Enemy contact

The EnemyContact Area2D still detects enemy overlap separately from terrain and Mario-contact geometry. BaseEnemy filters the callback using its existing lifecycle rules, rejects self-contact, checks whether the other enemy blocks contact, then emits enemy_contact(other: BaseEnemy).

Walking subscribes through an adapter accepting the other enemy and reverses exactly as before. Wall contact still calls its no-argument turn method. A future shell state can subscribe to the same signal and inspect/deliver a hit to the actual other actor. No shell attack, chain score, wake timer, health component, Koopa scene, or new collision shape is implemented by this refactor.

The contact signal describes overlap entry, not continuous damage or an automatic turn/attack policy. Future moving-shell work must handle sustained overlap and state changes deliberately; passing the other enemy does not by itself solve those mechanics.

## Verification - 2026-11-07

enemy_contract_test uses a test-only reactive enemy to verify repeated accepted nonterminal hits, unsupported/null rejection, nested-hit rejection, contact identity, self/suspended/defeated contact filtering, shutdown rejection, and exactly-once permanent defeat. No production health system is introduced by that fixture.

Enemy-contract, enemy-spawn, death, and pause regressions reached PASS in Godot 4.7.2 headless. Enemy-spawn covers actual walking reversals, squashed contact, stomp rebound, block hits, score, spawn limits, and cleanup. Enemy-spawn reported two ObjectDB leaks and death three. Formatting checks passed. Full suite and rendered playtesting were not performed. Assets, project settings, and scene collision configuration were unchanged.

ShellMoving now consumes the identified contact target to deliver shell hits. BaseEnemy separates contact eligibility from the default stomp/damage response so idle Koopa contact can kick instead. Contacts latch until player separation; moving shells separately track enemy overlap attempts. Accepted surviving hits never count as shell-chain defeats. See [Koopa shell interactions](koopa.md#kicking-stopping-and-shell-attacks---2026-11-07).
