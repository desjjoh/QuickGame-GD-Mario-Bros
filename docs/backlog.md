# Backlog

## Gameplay


- Wire shells, fireballs, and star contact into the enemy hit contract as those mechanics are added.
- Add breakable bricks and additional power-up forms.
  See [growth, damage, and bricks research](archive/growth-damage-bricks-research.md) for the agreed batches and remaining reference checks.
- Extend climbable behavior to vines and add any vine-specific detach rules.
- Define standalone level restart behavior for isolated F6 testing.

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
