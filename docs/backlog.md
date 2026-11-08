# Backlog

## Gameplay


- Wire shells, fireballs, and star contact into the enemy hit contract as those mechanics are added.
- Extend climbable behavior to vines and add any vine-specific detach rules.
- Define standalone level restart behavior for isolated F6 testing.

## Brick breaking — deferred

The user deferred the remaining work to tackle something else first. Implemented: breaking physics, themed debris, the accepted cached shatter sound, delayed bonk on follow-up contact, and 50 points without a score popup. Keep the accepted audio; the live shared noise channel was reverted after causing stutter.

- Handle coins directly above a broken brick. Verify the reference behavior, then reuse the existing coin reward, persistence, sound, and popup path as appropriate.
- Audit reactions above a shattering brick against the reference: Goombas, Koopas, stationary/moving shells, and mushrooms. Breaking currently delivers the shared block-hit interaction; identify any shatter-specific differences before changing behavior.
- Complete focused integration checks for adjacent bricks, reward-brick protection, pause, debris/marker cleanup, and area reload.

Suggested first item when resuming: coins above bricks. See [brick-breaking notes](archive/brick-breaking.md) and [growth, damage, and bricks research](archive/growth-damage-bricks-research.md) for implementation history, reference evidence, and remaining checks. Additional power-up forms remain separate pending work.

## Audio and presentation

- Compare castle fireworks with Mesen, especially first-frame alignment, blast playback, and the final music/hold handoff.
- Compare generated cues and music against Mesen, including loop seams, pulse takeover, and voice balance.
- Add more area tracks as stages need them, including Castle and Water.
- Investigate occasional camera hitching at high refresh rates and reproduce it in a rendered build.

## Verification

- Investigate native engine shutdown failures if reproducible. Audio-only ObjectDB exit warnings were isolated to deferred mix-thread cleanup and addressed in regression teardown; the full suite has not been requalified. See [shutdown investigation](archive/shutdown-investigation.md).
- Investigate the game-over regression’s score and coin reset assertion on return to the title.


## Movement reference audit

- Phase 1 corrected ground reversal friction/facing order and same-tick low-speed reset/reverse acceleration; checked reversal velocity traces now match the reference.
- Phase 2 verified the landing/turn/re-jump profile in 20 Mesen-derived cases across both directions/forms; the previously wrong fast-jump selection is restored without changing jump constants. Rendered interactive movement comparison and broader terrain coverage remain open. See [base movement audit](archive/base-movement-audit.md).
