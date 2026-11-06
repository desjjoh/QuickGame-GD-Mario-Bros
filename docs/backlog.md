# Backlog

## Gameplay

- Add enemy spawners and define activation, despawn, and return behavior.
- Add block rewards with per-placement configuration, breakable bricks, and power-up forms.
- Add fireworks scoring and presentation for level endings.
- Extend climbable behavior to vines and add any vine-specific detach rules.
- Define standalone level restart behavior for isolated F6 testing.

## Audio and presentation

- Compare generated cues and music against Mesen, including loop seams, pulse takeover, and voice balance.
- Add more area tracks as stages need them, including Castle and Water.
- Investigate occasional camera hitching at high refresh rates and reproduce it in a rendered build.

## Verification

- Investigate ObjectDB leak warnings and native engine shutdown failures in headless regressions.
- Investigate the game-over regression’s score and coin reset assertion on return to the title.
